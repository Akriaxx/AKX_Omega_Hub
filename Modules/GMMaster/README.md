# GM Master

Activer le module dans `/omh`, puis ouvrir la page d'accueil avec `/gmm` (ou `/gmmaster`) : une tuile par fenêtre du module (commandes MJ, barre MJ et ses réglages, displays, auras, émotes, animations, casts). Les raccourcis `/gmm <mot>` ci-dessous ouvrent directement la fenêtre voulue. Un raccourci clavier est aussi disponible dans les options de touches, rubrique Omega Hub.

La colonne de gauche liste les domaines. Chacun regroupe plusieurs sections, une par onglet :

| Domaine | Sections |
|---|---|
| PNJ | Créature (apparition, déplacement, échelle, émote, répliques…), Auras |
| Forge | PNJ forgé, Réglages (niveau, vie, faction, monture, flottement), Tenue, Dialogue (`.phase forge npc`, abrégé `.ph f n`) |
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

## Barre MJ

Une barre de cases à placer où l'on veut, chaque case portant une **macro technique** : une ou plusieurs commandes serveur, une par ligne (`mod speed 20`, `.ph f n scale 2`…). Elle s'affiche avec `/gmm barre` ou avec le bouton « Barre MJ » de la fenêtre.

- **Clic** sur une case : envoie ses commandes. **Clic droit** : la modifier. Sur une case vide, le clic ouvre aussi l'éditeur.
- **Maj + glisser** une case : l'échanger avec une autre.
- **Poignée de gauche** : glisser pour déplacer la barre, clic pour les réglages (colonnes, lignes, taille des cases, espacement, verrouillage, libellés), molette pour la taille des cases.
- **Coin bas-droit** : tirer pour ajouter ou retirer des colonnes et des lignes (jusqu'à 24 × 12). Les macros des cases masquées sont conservées.
- **Clic droit sur une action** de la fenêtre `/gmm` : elle est ajoutée à la barre avec les valeurs saisies (par exemple « Appliquer la vitesse 12 »).
- **Trois types de case** (bouton « Type » de l'éditeur) :
  - *Simple* : le clic envoie les commandes.
  - *Interrupteur on / off* : un seul bouton qui active ou désactive selon l'état **actuel**. Le plus simple : `cheat fly [on/off]`, où `[on/off]` est remplacé par `on` ou `off`. On peut aussi écrire deux jeux de commandes (« Pour activer » / « Pour désactiver »). La case affiche `ON` (liseré vert) ou `OFF`. L'état vient du serveur pour les triches (`.cheat fly`, `god`, `cooldown`, `casttime`, `power`, `duration`, `waterwalk`, `slowcast`, suivies par EpsilonLib, même si elles sont changées à la main dans le chat), de vos auras pour `aura <id> self`, et sinon du dernier état envoyé par la case (par personnage).
  - *Clic / Alt + clic* : deux commandes, comme la macro `/run SendChatMessage(IsAltKeyDown() and ".n se una 301895" or ".n se aur 301895", …)` : clic = `.n se aur 301895`, Alt + clic = `.n se una 301895`.
- **Maj + glisser une case** pour la déplacer : une vignette suit le curseur, la case visée est encadrée (vert : case vide, or : échange) et les deux cases clignotent au lâcher.
- Les 12 premières cases ont un raccourci clavier (options de touches, rubrique Omega Hub), et `/gmm case <n>` exécute la case n.

### Éditeur de case : les recettes

Pas besoin d'écrire les commandes : à gauche de l'éditeur, on choisit une **recette**, et on ne tape que l'ID ou la valeur. Le libellé et l'icône sont repris tout seuls (nom et icône du sort), et l'aperçu montre exactement ce qui partira au clic et à l'Alt + clic.

| Recette | Saisie | Clic | Alt + clic / état |
|---|---|---|---|
| Aura de PNJ | ID du sort | `.n se aur <id>` | `.n se u <id>` (retirer) |
| Aura sur moi | ID du sort | interrupteur : `.au <id> self` / `.una <id> self` | état lu sur vos auras |
| Aura sur ma cible | ID du sort | `.au <id>` | `.una <id>` |
| Lancer un sort | ID du sort | `.ca <id>` | — |
| Vitesse, Taille | valeur | `.mod sp <v>`, `.mod sc <v>` | — |
| Triche on / off | un clic (Vol, Invulnérable…) | interrupteur `.cheat … on/off` | état lu sur le serveur |
| Morph | ID d'affichage | `.mor <id>` | `.de` (démorpher) |
| Émote de PNJ | ID d'émote | `.n e <id>` | `.n e 0` (arrêter) |
| PNJ, Objet, Téléportation | ID ou lieu | apparition, pose, téléportation | — |
| PNJ ciblé, Forge, Phase et lieux | un clic sur l'action | infos, amener ici, forger, nom bleu, mode MJ… | selon l'action |
| Commande libre | une commande par ligne | type Simple, Interrupteur ou Clic / Alt + clic | |

- L'éditeur s'ouvre sur la **dernière recette utilisée**. Rouvrir une case (clic droit) la retrouve avec son ID : changer l'ID suffit.
- **Enregistrer + case suivante** enregistre puis ouvre la prochaine case vide avec la même recette : pour une série d'auras de PNJ, il ne reste qu'à taper chaque ID.
- Un libellé ou une icône modifiés à la main sont conservés ; sinon ils suivent l'ID.
- Une case dont l'aperçu est en erreur n'est pas enregistrée.

En commande libre, chaque ligne est vérifiée en direct par rapport à la liste des commandes du serveur : commande complète retrouvée, syntaxe officielle affichée, arguments manquants signalés. Une abréviation ambiguë (`n s` : say, scale, set, spawn…) ou une commande incomplète (`ph f n gossip` sans sous-commande) bloque l'envoi. Une commande absente de la liste est envoyée telle quelle, avec un avertissement. Le point initial est facultatif, `#` commence un commentaire, une ligne qui commence par `/` est une commande du client exécutée telle quelle (`/run print(1)`, `/reload`, `/dance`, commandes d'addons), jamais envoyée au serveur, `{cible}` est remplacé par le nom de la cible et `{moi}` par le vôtre. Dix lignes au plus par case.

| Commande | Effet |
|---|---|
| `/gmm` | Page d'accueil |
| `/gmm commandes` | Fenêtre des commandes MJ |
| `/gmm barre` | Afficher ou masquer la barre MJ |
| `/gmm réglages` | Réglages de la barre |
| `/gmm display` | Fenêtre Displays (onglet M2) ; `/gmm wmo`, `/gmm pnj` ouvrent l'onglet voulu |
| `/gmm auras` (ou `banque`) | Banque MJ, onglet Auras |
| `/gmm emotes`, `/gmm anim`, `/gmm casts` | Banque MJ, catégorie correspondante |
| `/gmm case <n>` | Exécuter la case n |

## Banque MJ

`/gmm auras`, ou le bouton « Banque d'auras » de la fenêtre et des réglages de la barre. On y range ses auras favorites (ID de sort, note facultative), chacune avec sa cible : **Moi** (`.aura <id> self`), **Ma cible** (`.aura <id>`) ou **PNJ ciblé** (`.npc set aura <id>`, aura permanente). Chaque ligne a ses boutons *Poser*, *Retirer* et *Barre +* :

- **Moi** : la case créée est un interrupteur dont l'état est lu sur vos auras ;
- **Ma cible / PNJ ciblé** : clic = poser, Alt + clic = retirer.

La banque est commune à tous vos personnages (200 auras au plus, molette pour défiler).

Les onglets **Émotes**, **Animations** et **Casts** conservent chacun jusqu'à 200 favoris. Saisir un nom dans « Note », puis **Chercher** lance `.lookup emote` ou `.lookup spell` ; les résultats et leurs IDs arrivent dans le chat. Saisir un ID affiche automatiquement l'action sur la poupée à droite, sans agir sur le PNJ ciblé. **Tester ID** l'essaie sur le PNJ ciblé ; **Ajouter** le range dans la liste. Cliquer un favori l'affiche aussi sur la poupée. Chaque favori a **Tester** et **Barre +**. Pour une émote, **Répéter** utilise `.npc emote <id> repeat` ; pour un cast, **Zone** utilise `.npc cast area <id>` à votre position. Les animations utilisent `.modify anim <id>` sur la cible. La barre MJ permet ensuite de rejouer les actions ; pour les émotes, Alt + clic arrête l'émote, et pour les casts il lance le sort à votre position.

### Aperçu sur un modèle

La colonne de droite de la banque montre un modèle 3D sur lequel l'aura, l'émote, l'animation ou les visuels du cast se jouent aussitôt, sans rien envoyer au serveur :

- **Saisir un ID** dans le champ « ID du sort » : l'aura se joue dès que la frappe s'arrête. **Cliquer une aura de la liste** la joue aussi (la ligne est alors surlignée).
- Dans **Émotes**, taper `1` affiche immédiatement l'émote sur la poupée et la répète en boucle tant que cet aperçu est sélectionné. L'ID d'émote est converti en ID d'animation du client (par exemple, émote `1` → animation `60`). Une émote sans animation connue est signalée. Dans **Animations**, l'ID saisi est joué directement. Dans **Casts**, les kits d'incantation et d'impact connus se jouent sur la poupée ; les sorts propres au serveur peuvent ne rien afficher.
- **Race** : menu déroulant avec les 23 races jouables, plus *Mon personnage* (votre apparence et votre tenue). **Homme / Femme** à côté. Certaines auras ne s'accrochent qu'à certains squelettes : changer de race rejoue l'aura sur le nouveau modèle.
- **Tenue** : *non* montre le modèle de base, sans équipement (le plus lisible) ; *oui* habille la race choisie avec votre tenue actuelle.
- **Rejouer** recharge le modèle et rejoue l'aura, effets ponctuels compris. **Face** remet le modèle de face, au centre. Sur le modèle : **clic droit** glissé pour le faire tourner, **clic gauche** glissé pour le déplacer dans sa case, **molette** pour zoomer.
- Sous le modèle : le nom du sort, les **kits visuels** joués (en boucle, ponctuels) et l'**animation** lancée. Un sort sans visuel d'aura montre à la place son effet d'incantation et d'impact, ce qui est signalé. Une aura de **transformation** remplace le modèle : l'aperçu ne peut pas la montrer. Un sort propre au serveur, absent des données du client, n'a pas d'aperçu.

La race, le sexe et la tenue choisis sont mémorisés.

Un modèle d'interface joue les objets et particules d'un kit, mais pas son animation : sans correction, un sort de portage affiche la caisse, bras ballants. L'aperçu lance donc lui-même l'animation du kit (AnimKit), et la pose de remplacement des auras de « remplacement d'animation » (aura 312).

Un modèle ne sait pas jouer un sort, seulement des kits visuels, et le client n'a aucune fonction pour passer de l'un à l'autre. La correspondance vient donc des tables DB2 du client 9.2.7 (`SpellXSpellVisual`, `SpellVisualEvent`, `SpellEffect`, `SpellVisualKitEffect`, `SpellVisualAnim`, `AnimReplacement`), réduite dans `AuraVisuals.generated.lua` (146 000 sorts, 3,1 Mo). Pour la régénérer, télécharger ces six tables en CSV sur wago.tools (build 9.2.7.45745, adresses en tête du script), puis :

```
node Modules/GMMaster/Tools/build-auravisuals.js <dossier des CSV>
```

La correspondance émote → animation vient de `Emotes.csv` du même client et se régénère avec :

```
node Modules/GMMaster/Tools/build-emoteanimations.js <Emotes.csv>
```

## Displays

`/gmm display`, ou la tuile « Displays » de l'accueil. Trois onglets : **M2**, **WMO** et **PNJ**. On tape un nom (`door`, ou plusieurs mots : `chair void`, tous doivent y figurer), la liste se remplit ; un clic affiche le résultat dans l'aperçu à droite, les **flèches haut / bas** passent au résultat précédent / suivant (la banque MJ fait de même), un clic droit ouvre le menu :

- **M2 / WMO** : *Spawn* (`.gobject spawn <display>`). La recherche passe par le client Epsilon (`C_Epsilon.GODI_Search`), qui connaît les displays du jeu **et** ceux ajoutés par le serveur (`eps_…`). Les objets connus pour faire planter le client à l'affichage (`alphabet_morpheus`…) sont écartés, comme dans Epsilon_Viewer. Pas d'aperçu 3D pour les WMO : le client 9.2.7 plante s'il doit en afficher un dans une fenêtre (vérifié en jeu, et EpsilonLib s'en protège aussi). *Spawn* pour le voir en jeu.
- **Aperçu en jeu** (M2 et WMO, bouton sous l'aperçu) : chaque objet choisi, au clic ou aux flèches, est posé devant vous à la distance réglée (10 par défaut) ; en choisir un autre retire le précédent. *Garder* le laisse en place, *Retirer* l'enlève, fermer la fenêtre ou changer d'onglet le retire aussi. Activé par défaut pour les WMO (l'onglet n'a alors plus de zone 3D), désactivé pour les M2. Passe par EpsilonLib pour connaître le GUID de l'objet posé.
- **PNJ** : *Morph* (`.morph <display>`) et *Démorph*. Tous les displays de créatures du client 9.2.7 (88 003), cherchables par nom de modèle, par nom du PNJ qui les porte (anglais ou français) ou par numéro. Un numéro inconnu du client (display ajouté par le serveur) reste proposé tel quel.

Les PNJ viennent de la table `Creature` du client, qui n'en connaît qu'une partie : environ 12 500 displays ont un nom de PNJ, les autres seulement leur nom de modèle. Les données sont dans `CreatureDisplays.generated.lua` ; pour les régénérer (sources indiquées en tête du script) :

```
node Modules/GMMaster/Tools/build-creaturedisplays.js <dossier des CSV>
```

## Commandes abrégées et vérifiées

Les commandes partent sous leur forme la plus courte **sans ambiguïté** : `.phase forge npc gossip text add` devient `.ph f n g t a`, `.npc spawn` devient `.n sp` (`.n s` serait ambigu : say, scale, set, spawn…). Seuls les mots de commande sont abrégés, jamais les valeurs saisies. Une commande de plus de 255 caractères est refusée avant l'envoi, avec le compte affiché en bas de la fenêtre.

Les abréviations viennent de `Abbrev.generated.lua`, généré à partir de la liste des commandes du serveur fournie par EpsilonLib. Après une mise à jour d'EpsilonLib, le régénérer :

```
node Modules/GMMaster/Tools/build-abbrev.js ../EpsilonLib/CommandDefinitions/init.lua
```

Le fichier généré contient aussi la syntaxe documentée de chaque commande et son nombre d'arguments obligatoires. Le test vérifie que chaque bouton et chaque modèle de la barre correspondent à une commande existante, **avec le bon nombre d'arguments**.

Le catalogue des commandes se trouve dans `Commands.lua` : une table par section, puis `GM.Groups` qui range les sections dans les domaines. Pour corriger une syntaxe ou ajouter une action, il suffit de modifier ou d'ajouter un modèle (`cmd = "npc spawn {id}"`).

`Tests/gmmaster-test.js` charge les vrais fichiers dans un faux client et vérifie la construction des commandes, la bascule appliquer/retirer, l'historique, les favoris, la fenêtre, la résolution des macros techniques, la barre MJ, la banque d'auras et son aperçu, l'accueil et la fenêtre Displays :

```
node Modules/GMMaster/Tests/gmmaster-test.js <chemin vers fengari-node-cli/src/lua-cli.js>
```
