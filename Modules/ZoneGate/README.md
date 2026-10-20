# Crossings

Ouvrir `/crossings` (les anciennes commandes `/oche` et `/ocheck` restent valables). Créer une région, puis cliquer sur **Placer un checkpoint ici** depuis sa fiche pour capturer la position du personnage. La recherche ne porte que sur les noms connus du joueur. Les identifiants internes `ZoneGate`, les sauvegardes et le protocole réseau restent inchangés.

L’éditeur sépare **Placement** (passage droit ou périmètre libre, assistant de franchissement, dimensions et déplacement), **Déclenchement** (bannière, entrée/sortie, message et action) et **Découverte** (révélation du nom à un joueur). Le thème d’une région est hérité par ses checkpoints ; chacun peut le remplacer. Les champs sont enregistrés automatiquement. La suppression demande confirmation. Les paramètres d’un autre auteur restent en lecture seule. La fenêtre s’adapte à la taille de l’écran.

`Tests/panel-test.js` vérifie le parcours de création, les onglets, les formes, la recherche sans révélation de noms inconnus, les droits et la confirmation de suppression. `UI_Style.lua` applique une palette bleu-gris et bronze uniquement aux éditeurs de ce module.

## Atelier des bannières

Ouvrir `/crossings`, puis **Atelier des bannières**. La galerie propose 42 modèles sur sept pages : six compositions initiales, douze paysages (dont les quatre saisons en forêt) et six univers de jeu originaux, puis huit thèmes sobres inspirés des ambiances de jeux vidéo, quatre thèmes asiatiques et six du Moyen-Orient. Les flèches de la galerie changent de page ; cliquer sur une vignette ouvre un brouillon dans le builder. Le bouton « + » et « Dupliquer » ouvrent aussi un brouillon, sans création automatique. Personnaliser et nommer le thème, puis cliquer sur **Créer le thème** pour l’enregistrer dans la bibliothèque. **Abandonner le brouillon** ou fermer l’atelier ne crée rien. Les brouillons ne sont ni sauvegardés ni synchronisés ; sélectionner un thème existant quitte également le brouillon. Les compositions sont propres à Omega ; les anciens thèmes restent disponibles.

Choisir un thème dans la bibliothèque, puis modifier sa typographie, ses couleurs, ses ornements, sa composition, sa largeur, son animation, sa position et ses sons. Les changements sont enregistrés automatiquement. Assigner ensuite le thème à une entrée de zone dans le panneau Zone Gate.

L'aperçu permet de changer le texte et le fond, de rejouer, de mettre en pause et de parcourir l'animation. **Voir en jeu** affiche une démonstration agrandie au centre de l’écran, au-dessus de l’éditeur (strate TOOLTIP), sans modifier les bannières de franchissement ni le thème enregistré. L'aperçu n'émet pas de son ; les boutons de test sonore sont explicites. L'historique Annuler/Rétablir concerne le thème ou le brouillon sélectionné pendant cette session ; Dupliquer prépare une copie indépendante à valider.

Les réglages supplémentaires sont transmis avec les thèmes. Les anciens messages restent lisibles ; tous les participants doivent disposer de la version 1.4.2 pour voir les nouvelles compositions.

Les 42 fichiers TGA de `Media/Designs` sont les textures utilisées en jeu. Les SVG sont leurs sources ; `Tools/designs.js` permet de les reconstruire avec Sharp. `Tools/gallery.js` produit la planche d'aperçu. Aucun atlas d'animation ni cache de génération n'est nécessaire.

Les tests de `Tests` vérifient les opérations sur les thèmes, l'aperçu indépendant, l'historique, le démarrage de l'éditeur et la compatibilité des échanges. La validation visuelle finale doit être faite dans le client de jeu.

Le bloc titre/sous-titre est centré verticalement. Le décor adapte sa hauteur au texte et sa largeur à partir du minimum choisi. Les paysages réservent leurs côtés aux arbres, reliefs et emblèmes. Les textures sont chargées à la demande.


La vue de placement montre le tracé en direct, nord fixe en haut. Le cadrage inclut le checkpoint et le joueur à toute distance ; les proportions du contour sont conservées. Les sommets sont numérotés et le prochain segment apparaît en pointillés pendant la construction. La distance est calculée jusqu’au segment ou au contour, avec un statut de position. Le zoom caméra ne modifie pas la vue.

Dans Découverte, **Débloquer pour…** ouvre la liste des autres membres connectés du raid (ou du groupe). Les noms déjà révélés sont précochés. **Tout cocher**, **Tout décocher** et la molette permettent de gérer toute la liste. Seul **Valider** applique les ajouts et retraits ; Annuler ou fermer ne change rien. Les joueurs absents sont préservés et un membre qui quitte le groupe avant validation est ignoré. Le personnage auteur connaît toujours les noms.

La détection conserve le dernier côté stable dans la marge du bord des périmètres : une traversée lente déclenche désormais les effets une seule fois. Sortir latéralement d’une ligne, changer d’instance ou désactiver un checkpoint réinitialise son état. `Tests/crossing-test.js` vérifie les bannières, sons et actions dans les deux sens, les hésitations au bord et les contrôles de direction.

## Sort Arcanum de région

Dans la fiche d’un checkpoint, l’onglet **Sort Arcanum** lie un sort Arcanum (SpellCreator) à la région. Il est lancé dès que le joueur entre (périmètre : intérieur, y compris à la connexion ou après un `/reload` ; passage droit : franchissement dans le sens de l’entrée). Il est retiré quand le joueur sort, change d’instance, ou quand le checkpoint est désactivé ou supprimé. Cela sert par exemple à changer le ciel ou l’ambiance d’une région.

Arcanum ne sait pas annuler un sort en général : renseignez un **sort de sortie** qui défait l’effet. À la sortie, le sort d’entrée encore en cours est interrompu, puis le sort de sortie est lancé. Sans sort de sortie, l’effet suit sa propre durée. Utilisez de préférence le **coffre de phase** : un sort du coffre personnel n’existe que chez son auteur. Si le coffre de phase n’est pas encore chargé, le sort est relancé automatiquement dès qu’il devient disponible. **Tester** lance le sort immédiatement.

Pendant que le joueur est dans la région, un petit cadre déplaçable « Effet de région » propose **Retirer**, puis **Remettre**. Sans sort de sortie, il propose seulement **Relancer**. L’auteur peut désactiver ce choix. Les réglages sont synchronisés ; un client plus ancien ignore simplement le sort. `Tests/arcanum-test.js` vérifie l’entrée, le retrait, la remise, la sortie, le changement d’instance, le chargement du coffre, les passages droits et la synchronisation.

## Formes

Deux formes restent disponibles : **passage droit** et **périmètre libre**. Le cercle a été retiré. Au chargement, chaque ancien cercle devient un périmètre fermé de 16 points, avec le même centre et le même rayon. Un cercle reçu d’un auteur dont l’addon n’est pas à jour est converti de la même façon.
