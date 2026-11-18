// Génère la correspondance Emotes.ID -> AnimationData.ID pour le client 9.2.7.
// Source : https://wago.tools/db2/Emotes/csv?build=9.2.7.45745
// Usage : node Modules/GMMaster/Tools/build-emoteanimations.js <Emotes.csv>
const fs = require('fs');
const path = require('path');

const source = process.argv[2];
if (!source) throw Error('Pass the Emotes.csv path');
const lines = fs.readFileSync(source, 'utf8').trim().split(/\r?\n/);
const columns = lines.shift().split(',');
const idCol = columns.indexOf('ID');
const animCol = columns.indexOf('AnimID');
if (idCol < 0 || animCol < 0) throw Error('Emotes.csv needs ID and AnimID columns');
const entries = [];
for (const line of lines) {
    const row = line.split(',');
    const id = Number(row[idCol]);
    const anim = Number(row[animCol]);
    if (Number.isInteger(id) && id > 0 && Number.isInteger(anim) && anim >= 0) {
        entries.push(`    [${id}] = ${anim},`);
    }
}
const output = [
    '-- Emotes.ID -> AnimID, client 9.2.7.45745.',
    '-- Régénérer avec Tools/build-emoteanimations.js après une mise à jour du client.',
    'GMMaster = GMMaster or {}',
    'GMMaster.EmoteAnimations = {',
    ...entries,
    '}',
    '',
].join('\n');
fs.writeFileSync(path.join(__dirname, '..', 'EmoteAnimations.generated.lua'), output);
console.log(`Generated ${entries.length} emote animations`);
