# Omega Dice — dés fantasy en BLP

Les D4, D6, D8, D10, D12, D20 et D100 ont des faces sombres, des bordures dorées en relief et des chiffres Georgia centrés.

Chaque résultat possède désormais **une animation complète de 144 poses**, sur 2,4 secondes. La rotation est intégrée à partir de la pose finale avec une vitesse angulaire qui diminue sur toute la durée. Les axes changent pendant la culbute ; il n’existe plus de raccord entre un lancer commun et un mouvement de présentation du résultat.

Quatre profils de culbute sont répartis entre les résultats. De petites variations de cadence sont choisies aléatoirement à chaque jet, sans répétition immédiate ni cadence identique sur deux dés voisins. Le résultat aléatoire lui-même est inchangé.

Les fichiers actifs sont dans `Media/Flight/Atlas`. Chaque résultat utilise trois planches BLP2 DXT5 : 64 + 64 + 16 poses, soit deux images de 2048 × 2048 et une de 2048 × 512. Ces limites servent uniquement au stockage ; le lecteur avance sur une seule séquence de 0 à 143. Les trois planches sont chargées avant le lancement.

La dernière pose montre la vraie face du résultat, exactement face caméra, chiffre droit et centré. Les sommes et modificateurs restent sous les dés. Les dés multiples commencent avec 0,4 seconde de décalage.

## Régénération

Depuis la racine de l’addon, pour chacun des côtés 4, 6, 8, 10, 12, 20 et 100 :

1. `blender -b --python-exit-code 1 --python Modules/Dice/Tools/blender_dice.py -- --sides 20 --flight --batch`
2. `python Modules/Dice/Tools/pack_flight.py --sides 20`
3. Consulter `Media/Flight/d20-full-roll.gif`, puis `/reload` dans Epsilon.

Remplacer 20 par le type de dé voulu. Les options `--first-value` et `--last-value` permettent de répartir le rendu. `--batch` conserve le moteur de rendu entre les poses pour accélérer la génération. `--resume` ne convient que pour reprendre un calcul interrompu sans modification des trajectoires ou des matériaux.

`solid_geometry.json` fournit les maillages ; `C:/Windows/Fonts/georgia.ttf` fournit la police. Les anciens dossiers `BLP`, `Numbered`, `Smooth`, `Continuous` et `Tumble` ne sont plus utilisés par le lecteur.

## Vérification

`blender -b --python-exit-code 1 --python Modules/Dice/Tools/blender_dice.py -- --sides 20 --flight --validate-only` vérifie la décroissance de vitesse, la rotation sur plusieurs axes, la très faible vitesse à la dernière pose et le centrage du résultat.

`fengari Modules/Dice/Tests/BLP_test.lua` couvre les sept dés, les résultats, les bonus, les jets multiples, les annulations, les 144 poses réparties sur trois planches et l’attente d’un chargement lent. Le ressenti en jeu reste à vérifier avec `/rd 1d20`, `/rd 3d6+2` et un jet séparé.
