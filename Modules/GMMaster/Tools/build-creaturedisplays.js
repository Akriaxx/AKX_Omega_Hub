// Génère CreatureDisplays.generated.lua : chaque display de créature du
// client 9.2.7 (CreatureDisplayInfo), avec le nom de son modèle et les PNJ
// du client qui l'utilisent, pour l'onglet PNJ de la fenêtre Displays.
//
// Chaîne :
//   CreatureDisplayInfo.ModelID → CreatureModelData.FileDataID → listfile
//   Creature.DisplayID_0..3 → noms des PNJ (anglais, et français s'il diffère)
// Tables CSV à télécharger sur wago.tools (build 9.2.7.45745) :
//   https://wago.tools/db2/CreatureDisplayInfo/csv?build=9.2.7.45745
//   https://wago.tools/db2/CreatureModelData/csv?build=9.2.7.45745
//   https://wago.tools/db2/Creature/csv?build=9.2.7.45745            → Creature.csv
//   https://wago.tools/db2/Creature/csv?build=9.2.7.45745&locale=frFR → Creature_frFR.csv
// Liste des fichiers : https://github.com/wowdev/wow-listfile/releases/latest/download/community-listfile.csv
//   → listfile.csv
// La table Creature du client ne connaît qu'une partie des PNJ : les autres
// displays n'ont que le nom du modèle (le serveur reste interrogeable avec
// .lookup displayid creature <nom>).
// Usage (depuis la racine de l'addon) :
//   node Modules/GMMaster/Tools/build-creaturedisplays.js <dossier des CSV>
const fs = require('fs'), path = require('path');
const dir = process.argv[2]; if (!dir) throw Error('Pass the folder holding the CSV files');
const BUILD = '9.2.7.45745';
const NAMES_MAX = 4;

// CSV avec champs entre guillemets (les noms peuvent contenir des virgules).
function parseLine(line) {
    const out = []; let cur = '', quoted = false;
    for (let i = 0; i < line.length; i++) {
        const c = line[i];
        if (quoted) {
            if (c === '"' && line[i + 1] === '"') { cur += '"'; i++; }
            else if (c === '"') quoted = false;
            else cur += c;
        } else if (c === '"') quoted = true;
        else if (c === ',') { out.push(cur); cur = ''; }
        else cur += c;
    }
    out.push(cur);
    return out;
}
function read(name) {
    const lines = fs.readFileSync(path.join(dir, name + '.csv'), 'utf8').trim().split(/\r?\n/);
    const head = parseLine(lines.shift());
    const col = k => { const i = head.indexOf(k); if (i < 0) throw Error(name + ': colonne ' + k + ' absente'); return i; };
    return { rows: lines.map(parseLine), col };
}

// FileDataID → nom du fichier .m2 (sans dossier ni extension)
const files = new Map();
for (const line of fs.readFileSync(path.join(dir, 'listfile.csv'), 'utf8').split(/\r?\n/)) {
    const sep = line.indexOf(';');
    if (sep < 0 || !line.endsWith('.m2')) continue;
    files.set(Number(line.slice(0, sep)), line.slice(sep + 1).replace(/^.*\//, '').replace(/\.m2$/, ''));
}

const models = new Map();
{ const t = read('CreatureModelData'); const id = t.col('ID'), fid = t.col('FileDataID');
  for (const r of t.rows) models.set(Number(r[id]), Number(r[fid])); }

// Display → noms des PNJ
const names = new Map();
function addNames(file) {
    const t = read(file);
    const id = t.col('ID'), name = t.col('Name_lang');
    const cols = [0, 1, 2, 3].map(i => t.col('DisplayID_' + i));
    for (const r of t.rows) {
        const n = (r[name] || '').replace(/[\t\n|;]/g, ' ').trim();
        if (!n) continue;
        for (const c of cols) {
            const d = Number(r[c]);
            if (!d) continue;
            if (!names.has(d)) names.set(d, []);
            const list = names.get(d);
            if (!list.includes(n) && list.length < NAMES_MAX * 2) list.push(n);
        }
    }
}
addNames('Creature');
if (fs.existsSync(path.join(dir, 'Creature_frFR.csv'))) addNames('Creature_frFR');

const out = [];
let named = 0, unknownModel = 0;
{ const t = read('CreatureDisplayInfo'); const id = t.col('ID'), model = t.col('ModelID');
  const rows = t.rows.map(r => [Number(r[id]), Number(r[model])]).sort((a, b) => a[0] - b[0]);
  for (const [d, m] of rows) {
      if (!d) continue;
      const file = files.get(models.get(m));
      if (!file) unknownModel++;
      const list = (names.get(d) || []).slice(0, NAMES_MAX);
      if (list.length) named++;
      out.push(d + '\t' + (file || '') + '\t' + list.join(';'));
  } }

const lua = [
    '-- Displays de créatures du client ' + BUILD + ' : « display<TAB>modèle<TAB>PNJ;PNJ ».',
    '-- Généré par Tools/build-creaturedisplays.js — ne pas modifier à la main.',
    'GMMaster = GMMaster or {}',
    'GMMaster.CreatureDisplaysRaw = [==[',
    out.join('\n'),
    ']==]',
    '',
].join('\n');
fs.writeFileSync(path.join(__dirname, '..', 'CreatureDisplays.generated.lua'), lua);
console.log(`${out.length} displays, ${named} avec PNJ, ${unknownModel} sans fichier de modèle connu, ${(lua.length / 1048576).toFixed(1)} Mo`);
