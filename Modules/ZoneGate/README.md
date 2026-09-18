# Atelier des entrées

Ouvrir `/oche`, puis **Atelier des entrées**. La galerie propose 42 modèles sur sept pages : six compositions initiales, douze paysages (dont les quatre saisons en forêt) et six univers de jeu originaux, puis huit thèmes sobres inspirés des ambiances de jeux vidéo, quatre thèmes asiatiques et six du Moyen-Orient. Les flèches de la galerie changent de page ; cliquer sur une vignette crée un thème indépendant. Les compositions sont propres à Omega ; les anciens thèmes restent disponibles.

Choisir un thème dans la bibliothèque, puis modifier sa typographie, ses couleurs, ses ornements, sa composition, sa largeur, son animation, sa position et ses sons. Les changements sont enregistrés automatiquement. Assigner ensuite le thème à une entrée de zone dans le panneau Zone Gate.

L'aperçu permet de changer le texte et le fond, de rejouer, de mettre en pause et de parcourir l'animation. **Voir en jeu** affiche la bannière à sa position réelle. L'aperçu n'émet pas de son ; les boutons de test sonore sont explicites. L'historique Annuler/Rétablir concerne le thème sélectionné pendant cette session ; Dupliquer crée une copie indépendante.

Les réglages supplémentaires sont transmis avec les thèmes. Les anciens messages restent lisibles ; tous les participants doivent disposer de la version 1.4.2 pour voir les nouvelles compositions.

Les 42 fichiers TGA de `Media/Designs` sont les textures utilisées en jeu. Les SVG sont leurs sources ; `Tools/designs.js` permet de les reconstruire avec Sharp. `Tools/gallery.js` produit la planche d'aperçu. Aucun atlas d'animation ni cache de génération n'est nécessaire.

Les tests de `Tests` vérifient les opérations sur les thèmes, l'aperçu indépendant, l'historique, le démarrage de l'éditeur et la compatibilité des échanges. La validation visuelle finale doit être faite dans le client de jeu.

Le bloc titre/sous-titre est centré verticalement. Le décor adapte sa hauteur au texte et sa largeur à partir du minimum choisi. Les paysages réservent leurs côtés aux arbres, reliefs et emblèmes. Les textures sont chargées à la demande.

