# Crossings

Ouvrir `/crossings` (les anciennes commandes `/oche` et `/ocheck` restent valables). Les identifiants internes `ZoneGate` et le préfixe réseau restent inchangés.

## Pays, régions, lieux et passages

- **Pays** : un classeur qui range les régions dans la colonne de gauche. Il n’apparaît jamais dans la bannière. Supprimer un pays conserve ses régions, qui passent dans « Sans pays ».
- **Région** : la base de données de la zone. Elle porte son nom, sa bannière par défaut, la révélation de son nom, ses **lieux** et ses **passages**.
- **Lieu** : un nom (par exemple « Le bois des Anciens »), une bannière facultative (sinon celle de la région), une action au passage (message, commande ou aura, à l’arrivée et / ou au départ), un sort Arcanum et la révélation de son nom.
- **Passage** : uniquement de la géométrie, un **passage droit** ou un **périmètre libre**, posé à la position du personnage. On choisit le lieu atteint **en entrant** (côté vert, ou intérieur du périmètre). Un passage droit a aussi un lieu atteint **en sortant** (côté rouge), qui peut être **aucun** et appartenir à n’importe quelle autre de vos régions. Un périmètre n’en a pas : ce qu’on trouve en le quittant dépend du périmètre voisin, de l’autre côté de la frontière commune. La bannière affiche « Région / Lieu » du lieu atteint.

Un franchissement quitte le lieu de départ (action et sort Arcanum de départ), puis entre dans le lieu d’arrivée (bannière, son, action et sort d’arrivée). Sans lieu d’arrivée, seul le son de sortie du lieu quitté est joué. Plusieurs passages peuvent mener au même lieu : ses effets sont réglés une seule fois.

Dans la colonne de gauche, pays, régions et « Sans pays » se replient et se déplient comme un accordéon (bouton +/−, mémorisé par personnage) ; la recherche déplie tout. Glisser une région sur un pays l’y range, sur « Sans pays » la retire de son pays, sur une autre région la range dans le même pays.

Toute création (pays, région, lieu, passage) ouvre d’abord une fenêtre qui demande le nom ; rien n’est créé avant **Créer**. Un clic droit sur un pays, une région ou un lieu ouvre un menu : ouvrir, créer dedans, supprimer. Supprimer une région qui contient des lieux affiche un tableau : pour chaque lieu, une autre de vos régions où le ranger, ou « Ne pas garder » (avec « Tout affecter à » pour tout régler d’un coup). Rien ne change avant **Exécuter** ; les passages de la région sont supprimés, ceux d’autres régions qui menaient aux lieux déplacés continuent de fonctionner.

La fiche d’une région a trois onglets : **Lieux**, **Passages** (tracé en direct, largeur ou points du périmètre, lieux d’entrée et de sortie, déplacement, duplication) et **Bannière et découverte**. La fiche d’un lieu a quatre onglets : **Bannière**, **Effets**, **Sort Arcanum** et **Découverte**. La recherche ne porte que sur les noms connus du joueur. Les champs sont enregistrés automatiquement. Les suppressions demandent confirmation. Les paramètres d’un autre auteur restent en lecture seule. La fenêtre s’adapte à la taille de l’écran.

**Reprise de l’existant** : au chargement, chaque ancien checkpoint devient un lieu (son nom d’entrée, sinon son nom) et un passage « Passage vers … » qui y mène. Si un nom de sortie était rempli, il devient un second lieu atteint en sortant. Les checkpoints d’un même village (même nom, même bannière) partagent un seul lieu. Les noms déjà révélés aux joueurs restent connus. Les checkpoints reçus d’un auteur dont l’addon n’est pas à jour sont convertis de la même façon. En revanche, un joueur dont l’addon n’est pas à jour ne reçoit plus les passages : tout le monde doit passer à la version 1.7.0.

`Tests/panel-test.js` charge le vrai cœur et vérifie les pays, régions, lieux, passages, liens entre régions, la découverte, la recherche sans révélation de noms inconnus, les droits et la confirmation de suppression. `UI_Style.lua` applique une palette bleu-gris et bronze uniquement aux éditeurs de ce module.

## Atelier des bannières

Ouvrir `/crossings`, puis **Atelier des bannières**. La galerie propose 42 modèles sur sept pages : six compositions initiales, douze paysages (dont les quatre saisons en forêt) et six univers de jeu originaux, puis huit thèmes sobres inspirés des ambiances de jeux vidéo, quatre thèmes asiatiques et six du Moyen-Orient. Les flèches de la galerie changent de page ; cliquer sur une vignette ouvre un brouillon dans le builder. Le bouton « + » et « Dupliquer » ouvrent aussi un brouillon, sans création automatique. Personnaliser et nommer le thème, puis cliquer sur **Créer le thème** pour l’enregistrer dans la bibliothèque. **Abandonner le brouillon** ou fermer l’atelier ne crée rien. Les brouillons ne sont ni sauvegardés ni synchronisés ; sélectionner un thème existant quitte également le brouillon. Les compositions sont propres à Omega ; les anciens thèmes restent disponibles.

Choisir un thème dans la bibliothèque, puis modifier sa typographie, ses couleurs, ses ornements, sa composition, sa largeur, son animation, sa position et ses sons. Les changements sont enregistrés automatiquement. Assigner ensuite le thème à une région ou à un lieu dans le panneau Crossings.

L'aperçu permet de changer le texte et le fond, de rejouer, de mettre en pause et de parcourir l'animation. **Voir en jeu** affiche une démonstration agrandie au centre de l’écran, au-dessus de l’éditeur (strate TOOLTIP), sans modifier les bannières de franchissement ni le thème enregistré. L'aperçu n'émet pas de son ; les boutons de test sonore sont explicites. L'historique Annuler/Rétablir concerne le thème ou le brouillon sélectionné pendant cette session ; Dupliquer prépare une copie indépendante à valider.

Les réglages supplémentaires sont transmis avec les thèmes. Les anciens messages restent lisibles ; tous les participants doivent disposer de la version 1.4.2 pour voir les nouvelles compositions.

Les 42 fichiers TGA de `Media/Designs` sont les textures utilisées en jeu. Les SVG sont leurs sources ; `Tools/designs.js` permet de les reconstruire avec Sharp. `Tools/gallery.js` produit la planche d'aperçu. Aucun atlas d'animation ni cache de génération n'est nécessaire.

Les tests de `Tests` vérifient les opérations sur les thèmes, l'aperçu indépendant, l'historique, le démarrage de l'éditeur et la compatibilité des échanges. La validation visuelle finale doit être faite dans le client de jeu.

Le bloc titre/sous-titre est centré verticalement. Le décor adapte sa hauteur au texte et sa largeur à partir du minimum choisi. Les paysages réservent leurs côtés aux arbres, reliefs et emblèmes. Les textures sont chargées à la demande.


Le tracé en direct garde le personnage au centre, flèche toujours vers le haut : c’est le décor qui tourne. Tant que le tracé est affiché, la minimap du jeu sert de fond à la même échelle (zoom choisi pour montrer tout le passage) et pivote avec le personnage ; elle reprend sa place et ses réglages à la fermeture. Un passage droit montre une flèche verte « ENTRÉE » et une flèche rouge « SORTIE ». Les sommets d’un périmètre sont numérotés et le prochain segment apparaît en pointillés pendant la construction. La distance est calculée jusqu’au segment ou au contour, avec un statut de position.

Dans Découverte, **Débloquer pour…** ouvre la liste des autres membres connectés du raid (ou du groupe). Les noms déjà révélés sont précochés. **Tout cocher**, **Tout décocher** et la molette permettent de gérer toute la liste. Seul **Valider** applique les ajouts et retraits ; Annuler ou fermer ne change rien. Les joueurs absents sont préservés et un membre qui quitte le groupe avant validation est ignoré. Le personnage auteur connaît toujours les noms.

La détection conserve le dernier côté stable dans la marge du bord des périmètres : une traversée lente déclenche désormais les effets une seule fois. Sortir latéralement d’une ligne, changer d’instance ou désactiver un passage réinitialise son état et libère ses lieux. `Tests/crossing-test.js` vérifie les bannières, sons et actions dans les deux sens, la sortie vers un autre lieu ou vers aucun, les passages enchaînés, les hésitations au bord et les contrôles de direction.

## Sort Arcanum du lieu

Dans la fiche d’un lieu, l’onglet **Sort Arcanum** lie un sort Arcanum (SpellCreator) au lieu. Il est lancé dès que le joueur y arrive, quel que soit le passage emprunté (y compris à la connexion ou après un `/reload` à l’intérieur d’un périmètre). Il est retiré quand le joueur quitte le lieu, change d’instance, ou quand le passage qui l’y a mené est désactivé ou supprimé. Cela sert par exemple à changer le ciel ou l’ambiance d’un lieu.

Arcanum ne sait pas annuler un sort en général : renseignez un **sort de départ** qui défait l’effet. Au départ, le sort d’arrivée encore en cours est interrompu, puis le sort de départ est lancé. Sans sort de départ, l’effet suit sa propre durée. Utilisez de préférence le **coffre de phase** : un sort du coffre personnel n’existe que chez son auteur. Si le coffre de phase n’est pas encore chargé, le sort est relancé automatiquement dès qu’il devient disponible. **Tester** lance le sort immédiatement.

Pendant que le joueur est dans le lieu, un petit cadre déplaçable « Effet de région » propose **Retirer**, puis **Remettre**. Sans sort de départ, il propose seulement **Relancer**. L’auteur peut désactiver ce choix. `Tests/arcanum-test.js` vérifie l’arrivée, le retrait, la remise, le départ, le changement d’instance, le chargement du coffre, les passages droits, les passages vers un autre lieu, la synchronisation et la conversion des anciens checkpoints.

## Frontières entre périmètres

Un périmètre compte jusqu’à 1500 sommets. Chaque sommet est un point de frontière ; **Nommer un sommet** lui donne un nom facultatif (« Gué du Nord »), affiché en bleu sur le tracé. Pendant la construction d’un périmètre, **Reprendre une frontière…** propose vos autres périmètres de la même instance, puis un point de départ, un point d’arrivée et le chemin à suivre le long de leur contour : dans un sens ou dans l’autre, y compris par la fermeture d’un contour validé (47 → 1 → … → 6). Tout le tronçon est ajouté à la suite du tracé, aux coordonnées exactes et avec les noms des sommets : les deux zones se touchent sans trou ni chevauchement. **Gérer les frontières…** (panneau et fenêtre de tracé) nomme un tronçon de son propre contour (« Frontière Nord », du point 47 au point 6, par l’un ou l’autre chemin) avant même qu’un voisin existe ; il apparaît en bleu clair sur le tracé, est transmis aux autres joueurs, et figure en tête de « Reprendre une frontière… », qui préremplit alors les deux points et le chemin. Un nouveau périmètre libre démarre vide. S’il existe des frontières déclarées dans l’instance, la fenêtre de tracé propose aussitôt d’en **partir** : le tronçon devient le début du contour, renuméroté à partir de 1 (47 → 1 → … → 7 devient 1 → 2 → … → 8), et **Inverser** permet de partir de l’autre extrémité. On poursuit ensuite le tracé à la main. Franchir cette frontière commune est un passage direct de A vers B : une seule bannière (celle de B), un seul son, l’action de départ de A puis l’action d’arrivée de B.

Le tracé crée ses sommets à la demande, n’affiche les numéros que jusqu’à 30 points (les noms toujours) et ne dessine pas les segments hors du cadre. L’état est envoyé morceau par morceau au rythme toléré par le jeu : un grand périmètre peut mettre une à deux minutes à arriver chez les autres joueurs ; une modification plus récente remplace un envoi encore en attente.

## Formes

Deux formes restent disponibles : **passage droit** et **périmètre libre**. Le cercle a été retiré. Au chargement, chaque ancien cercle devient un périmètre fermé de 16 points, avec le même centre et le même rayon. Un cercle reçu d’un auteur dont l’addon n’est pas à jour est converti de la même façon.
