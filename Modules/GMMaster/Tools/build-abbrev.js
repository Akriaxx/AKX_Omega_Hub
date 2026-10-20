// Génère Abbrev.generated.lua à partir de la liste des commandes du serveur
// fournie par EpsilonLib (CommandDefinitions/init.lua).
// Pour chaque mot de commande, l'abréviation retenue est le préfixe le plus
// court qu'aucune commande sœur ne partage : « .n s » est ambigu (say, scale,
// set, spawn…), « .n sp » ne l'est pas. Sans préfixe sûr, le mot reste entier.
// Usage (depuis la racine de l'addon) :
//   node Modules/GMMaster/Tools/build-abbrev.js ../EpsilonLib/CommandDefinitions/init.lua
const fs = require('fs'), path = require('path');
const src = process.argv[2]; if (!src) throw Error('Pass the EpsilonLib CommandDefinitions/init.lua path');
const text = fs.readFileSync(src, 'utf8');

// parseCommand("npc spawn", [==[Syntax: ...]==], ...) : un nœud par commande ;
// une syntaxe vide signale un simple groupe (il faut un sous-mot).
const root = { sub: {} };
const re = /parseCommand\("([^"]+)",\s*\[==\[(.*?)\]==\],\s*\[==\[(.*?)\]==\]/gs;
let m, count = 0;
while ((m = re.exec(text))) {
    let node = root;
    for (const word of m[1].trim().split(/\s+/)) {
        node.sub[word] = node.sub[word] || { sub: {} };
        node = node.sub[word];
    }
    node.syntax = node.syntax || m[2].trim() !== '';
    node.desc = node.desc || m[3].trim() !== '';
    count++;
}
// Exécutable : une syntaxe documentée, ou une feuille décrite (ex. « outfit
// add », sans ligne Syntax). Un groupe sans syntaxe exige un sous-mot.
(function mark(node) {
    for (const child of Object.values(node.sub)) {
        child.runnable = child.syntax || (child.desc && Object.keys(child.sub).length === 0);
        mark(child);
    }
})(root);

function shortest(word, siblings) {
    for (let k = 1; k < word.length; k++) {
        const p = word.slice(0, k);
        if (!siblings.some(s => s !== word && s.startsWith(p))) return p;
    }
    return word;
}

function emit(node, indent) {
    const names = Object.keys(node.sub).sort();
    const lines = [];
    for (const name of names) {
        const child = node.sub[name];
        const short = shortest(name, names);
        const kids = Object.keys(child.sub).length;
        let line = `${indent}[${JSON.stringify(name)}] = { s = ${JSON.stringify(short)}`;
        if (child.runnable) line += ', run = true';
        if (kids) line += ', sub = {\n' + emit(child, indent + '    ') + `\n${indent}} },`;
        else line += ' },';
        lines.push(line);
    }
    return lines.join('\n');
}

const out = `-- ============================================================
--  GM Master — Abréviations des commandes (FICHIER GÉNÉRÉ)
--  Ne pas modifier à la main : relancer Tools/build-abbrev.js.
--  Source : EpsilonLib/CommandDefinitions/init.lua (${count} commandes).
--  s = abréviation sans ambiguïté parmi les commandes sœurs ;
--  run = la commande s'exécute à ce niveau (sinon il faut un sous-mot).
-- ============================================================

GMMaster = GMMaster or {}
GMMaster.CommandTree = {
${emit(root, '    ')}
}
`;
fs.writeFileSync(path.join(__dirname, '..', 'Abbrev.generated.lua'), out);
console.log(`Abbrev.generated.lua : ${count} commandes`);
