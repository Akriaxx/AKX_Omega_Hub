# GM Master

Activer le module dans `/omh`, puis ouvrir la fenêtre avec `/gmm` (ou `/gmmaster`). Un raccourci clavier est aussi disponible dans les options de touches, rubrique Omega Hub.

La colonne de gauche liste les domaines. Chacun regroupe plusieurs sections, une par onglet :

| Domaine | Sections |
|---|---|
| PNJ | Créature (apparition, déplacement, échelle, émote, répliques…), Auras, Forge, Tenue, Dialogue (`.phase forge npc`) |
| Sorts | Auras, Lancer |
| Objets | Objets |
| Personnage | Morph, Modifier, Triches |
| Déplacement | Téléportation, Phase |

Un domaine se rouvre sur la dernière section consultée. Chaque section propose des champs à saisir une seule fois (ID, échelle, réplique…) et des boutons d'action. Les valeurs restent mémorisées d'une session à l'autre.

- **Entrée** dans un champ lance l'action principale de ce champ (par exemple, faire apparaître le PNJ).
- Sous chaque champ d'ID, les **pastilles** reprennent les dernières valeurs utilisées. Clic : reprendre la valeur. Double-clic : exécuter. Clic droit : oublier la valeur. L'étoile épingle la valeur en favori, en tête de liste.
- Les champs numériques ont des boutons **- / +**.
- **Auras** : *Appliquer*, *Retirer* ou *Basculer* sans retaper l'ID. La liste « Auras appliquées » garde la trace de ce qui a été posé (par personnage), avec un bouton *Retirer* par ligne. Le nom du sort s'affiche à côté de l'ID.
- Chaque clic envoie directement la commande, même en mouvement ou avec Maj enfoncée. Rien n'est jamais placé dans la saisie du chat.
- Le survol d'un bouton affiche la commande exacte qui sera envoyée.

## Commandes abrégées et vérifiées

Les commandes partent sous leur forme la plus courte **sans ambiguïté** : `.phase forge npc gossip text add` devient `.ph f n g t a`, `.npc spawn` devient `.n sp` (`.n s` serait ambigu : say, scale, set, spawn…). Seuls les mots de commande sont abrégés, jamais les valeurs saisies. Une commande de plus de 255 caractères est refusée avant l'envoi, avec le compte affiché en bas de la fenêtre.

Les abréviations viennent de `Abbrev.generated.lua`, généré à partir de la liste des commandes du serveur fournie par EpsilonLib. Après une mise à jour d'EpsilonLib, le régénérer :

```
node Modules/GMMaster/Tools/build-abbrev.js ../EpsilonLib/CommandDefinitions/init.lua
```

Le test vérifie que chaque bouton correspond à une commande existante de cette liste.

Le catalogue des commandes se trouve dans `Commands.lua` : une table par section, puis `GM.Groups` qui range les sections dans les domaines. Pour corriger une syntaxe ou ajouter une action, il suffit de modifier ou d'ajouter un modèle (`cmd = "npc spawn {id}"`).

`Tests/gmmaster-test.js` charge les vrais fichiers dans un faux client et vérifie la construction des commandes, la bascule appliquer/retirer, l'historique, les favoris et la fenêtre :

```
node Modules/GMMaster/Tests/gmmaster-test.js <chemin vers fengari-node-cli/src/lua-cli.js>
```
