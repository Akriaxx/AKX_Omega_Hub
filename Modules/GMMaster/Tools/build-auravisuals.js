// Génère AuraVisuals.generated.lua : pour chaque sort, les kits visuels
// (SpellVisualKit) que le client joue quand l'aura est posée. Un modèle 3D
// ne sait jouer qu'un kit (Model:ApplySpellVisualKit), et le client n'expose
// aucune fonction pour passer d'un ID de sort à ses kits : d'où cette table.
//
// Chaîne lue dans les DB2 du client 9.2.7 :
//   SpellXSpellVisual (sort → SpellVisual) → SpellVisualEvent (SpellVisual →
//   kit, avec l'événement de début / fin et la cible du kit).
// Tables CSV à télécharger sur wago.tools (build 9.2.7.45745) :
//   https://wago.tools/db2/SpellXSpellVisual/csv?build=9.2.7.45745
//   https://wago.tools/db2/SpellVisualEvent/csv?build=9.2.7.45745
//   https://wago.tools/db2/SpellEffect/csv?build=9.2.7.45745
//   https://wago.tools/db2/SpellVisualKitEffect/csv?build=9.2.7.45745
//   https://wago.tools/db2/SpellVisualAnim/csv?build=9.2.7.45745
//   https://wago.tools/db2/AnimReplacement/csv?build=9.2.7.45745
//
// Un modèle d'interface joue les objets et particules d'un kit, mais pas
// son animation : un sort de portage montre la caisse, bras ballants. La
// table retient donc aussi l'animation à lancer à la main (PlayAnimKit,
// SetAnimation) : celle du kit, et la pose de remplacement des auras
// « remplacement d'animation » (312).
// Usage (depuis la racine de l'addon) :
//   node Modules/GMMaster/Tools/build-auravisuals.js <dossier des CSV>
const fs = require('fs'), path = require('path');
const dir = process.argv[2]; if (!dir) throw Error('Pass the folder holding the DB2 CSV files');
const BUILD = '9.2.7.45745';

function read(name) {
    const lines = fs.readFileSync(path.join(dir, name + '.csv'), 'utf8').trim().split(/\r?\n/);
    const head = lines.shift().split(',');
    const col = k => { const i = head.indexOf(k); if (i < 0) throw Error(name + ': colonne ' + k + ' absente'); return i; };
    return { rows: lines.map(l => l.split(',')), col };
}

// Événements (SpellVisualEvent.StartEvent / EndEvent)
const PRECAST_START = 1, PRECAST_END = 2, CAST = 3, IMPACT = 6, AURA_START = 7, AURA_END = 8,
      CHANNEL_START = 11, CHANNEL_END = 12, ONESHOT = 13;
// Cibles du kit : 1 lanceur, 2 cible, 4 cible principale. 3 (zone) et 5
// (projectile) ne s'accrochent pas à un modèle.
const ON_MODEL = new Set([1, 2, 4]);

// 1. Sort → SpellVisual : difficulté normale, sans condition de préférence,
//    la priorité la plus haute l'emporte.
const xsv = read('SpellXSpellVisual');
const X = { diff: xsv.col('DifficultyID'), vis: xsv.col('SpellVisualID'), prio: xsv.col('Priority'),
    spell: xsv.col('SpellID'), conds: ['ViewerUnitConditionID', 'ViewerPlayerConditionID',
        'CasterUnitConditionID', 'CasterPlayerConditionID'].map(xsv.col) };
const visualOf = new Map();
for (const r of xsv.rows) {
    if (r[X.diff] !== '0') continue;
    const spell = +r[X.spell], cand = { vis: +r[X.vis], prio: +r[X.prio],
        free: X.conds.every(i => r[i] === '0') };
    const cur = visualOf.get(spell);
    if (!cur || (cand.free && !cur.free) || (cand.free === cur.free && cand.prio > cur.prio)) visualOf.set(spell, cand);
}

// 2. SpellVisual → kits, rangés par usage.
const sve = read('SpellVisualEvent');
const E = { start: sve.col('StartEvent'), end: sve.col('EndEvent'), target: sve.col('TargetType'),
    kit: sve.col('SpellVisualKitID'), vis: sve.col('SpellVisualID') };
const kitsOf = new Map();
function push(vis, slot, kit) {
    let k = kitsOf.get(vis);
    if (!k) { k = [[], [], [], []]; kitsOf.set(vis, k); }
    if (!k[slot].includes(kit)) k[slot].push(kit);
}
for (const r of sve.rows) {
    const s = +r[E.start], e = +r[E.end], t = +r[E.target], kit = +r[E.kit], vis = +r[E.vis];
    if (!kit || !ON_MODEL.has(t)) continue;
    if (s === AURA_START && e === AURA_END) push(vis, 0, kit);                       // aura : en boucle
    else if (s === AURA_START) push(vis, 1, kit);                                    // aura : à la pose
    else if ((s === CHANNEL_START && e === CHANNEL_END)
          || (s === PRECAST_START && e === PRECAST_END)) push(vis, 2, kit);          // canalisation, incantation
    else if ((s === CAST || s === IMPACT) && e === ONESHOT) push(vis, 3, kit);       // lancer, impact
}

// 3. Auras de transformation (SPELL_AURA_TRANSFORM = 56) : le visuel est un
//    autre modèle, pas un kit. Signalé pour l'expliquer dans l'aperçu.
const eff = read('SpellEffect');
const F = { aura: eff.col('EffectAura'), spell: eff.col('SpellID') };
const transform = new Set();
for (const r of eff.rows) if (r[F.aura] === '56') transform.add(+r[F.spell]);

// 4. Animations. Kit → SpellVisualKitEffect de type 6 (SpellVisualAnim) →
//    AnimKit, ou à défaut une animation simple (boucle, sinon initiale).
const kfx = read('SpellVisualKitEffect');
const K = { type: kfx.col('EffectType'), effect: kfx.col('Effect'), kit: kfx.col('ParentSpellVisualKitID') };
const sva = read('SpellVisualAnim');
const A = { id: sva.col('ID'), initial: sva.col('InitialAnimID'), loop: sva.col('LoopAnimID'), kit: sva.col('AnimKitID') };
const animRow = new Map(sva.rows.map(r => [+r[A.id], r]));
const animOfKit = new Map();
for (const r of kfx.rows) {
    if (r[K.type] !== '6' || animOfKit.has(+r[K.kit])) continue;
    const a = animRow.get(+r[K.effect]); if (!a) continue;
    if (+a[A.kit] > 0) animOfKit.set(+r[K.kit], { animKit: +a[A.kit] });
    else if (+a[A.loop] >= 0) animOfKit.set(+r[K.kit], { anim: +a[A.loop] });
    else if (+a[A.initial] >= 0) animOfKit.set(+r[K.kit], { anim: +a[A.initial] });
}
//    Aura 312 (remplacement d'animation) : EffectMiscValue_0 = jeu de
//    remplacements ; on retient ce qui remplace la pose debout (0).
const rep = read('AnimReplacement');
const R = { src: rep.col('SrcAnimID'), dst: rep.col('DstAnimID'), set: rep.col('ParentAnimReplacementSetID') };
const standOfSet = new Map();
for (const r of rep.rows) if (r[R.src] === '0' && !standOfSet.has(+r[R.set])) standOfSet.set(+r[R.set], +r[R.dst]);
const FM = eff.col('EffectMiscValue_0');
const standOf = new Map();
for (const r of eff.rows) {
    if (r[F.aura] !== '312') continue;
    const dst = standOfSet.get(+r[FM]);
    if (dst !== undefined && !standOf.has(+r[F.spell])) standOf.set(+r[F.spell], dst);
}

/** Animation du premier kit qui en a une : « kID » en boucle, « oID » une fois, « aID » animation simple. */
function animField(loopKits, onceKits) {
    for (const [list, loop] of [[loopKits, true], [onceKits, false]]) {
        for (const kit of list) {
            const a = animOfKit.get(kit); if (!a) continue;
            return a.animKit ? (loop ? 'k' : 'o') + a.animKit : 'a' + a.anim;
        }
    }
    return '';
}

// 5. Une ligne par sort : « id=boucle|pose|canalisation|impact|T|animation|pose debout ».
const lines = [];
const spells = new Set([...visualOf.keys(), ...transform, ...standOf.keys()]);
let withAura = 0, withAnim = 0;
for (const spell of [...spells].sort((a, b) => a - b)) {
    const v = visualOf.get(spell), k = v && kitsOf.get(v.vis);
    const fields = k ? k.map(list => list.join(',')) : ['', '', '', ''];
    fields.push(transform.has(spell) ? 'T' : '');
    // Même choix que l'aperçu : les kits d'aura, sinon incantation / impact.
    const aura = k && (k[0].length || k[1].length);
    fields.push(k ? (aura ? animField(k[0], k[1]) : animField(k[2], k[3])) : '');
    fields.push(standOf.has(spell) ? String(standOf.get(spell)) : '');
    if (fields[5] || fields[6]) withAnim++;
    while (fields.length && fields[fields.length - 1] === '') fields.pop();
    if (!fields.length) continue;
    if (fields[0] || fields[1]) withAura++;
    lines.push(spell + '=' + fields.join('|'));
}

const out = `-- ============================================================
--  GM Master — Kits visuels des sorts (FICHIER GÉNÉRÉ)
--  Ne pas modifier à la main : relancer Tools/build-auravisuals.js.
--  Source : DB2 du client ${BUILD} (SpellXSpellVisual, SpellVisualEvent,
--  SpellEffect). ${lines.length} sorts, dont ${withAura} avec un visuel d'aura
--  et ${withAnim} avec une animation.
--  Une ligne par sort : id=boucle|pose|canalisation|impact|T|animation|debout
--    boucle       : kits joués tant que l'aura est là (début → fin d'aura)
--    pose         : kits joués une fois, quand l'aura est posée
--    canalisation : kits en boucle pendant l'incantation ou la canalisation
--    impact       : kits joués une fois au lancer ou à l'impact
--    T            : aura de transformation (le visuel est un autre modèle)
--    animation    : animation des kits, que le modèle ne joue pas seul :
--                   kID = AnimKit en boucle, oID = AnimKit une fois,
--                   aID = animation simple
--    debout       : animation qui remplace la pose debout (aura 312)
--  Lecture : GMMaster.AuraVisualKits(id), dans UI_AuraPreview.lua.
-- ============================================================

GMMaster = GMMaster or {}
GMMaster.AuraVisualData = [[

${lines.join('\n')}
]]
`;
const dest = path.join(__dirname, '..', 'AuraVisuals.generated.lua');
fs.writeFileSync(dest, out);
console.log(`${lines.length} sorts (${withAura} avec visuel d'aura, ${withAnim} avec animation, ${transform.size} transformations), ${(out.length / 1048576).toFixed(2)} Mo → ${dest}`);
