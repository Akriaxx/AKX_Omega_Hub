# Portrait et ressources

Lorsque Character est actif, le portrait rond et les trois jauges RP (vie, mana, endurance) restent affichés sans ouvrir la fiche. Ils utilisent les mêmes données et les mêmes commandes que la fiche et la vue MJ. Les ressources temporaires dessinent un contour progressif : rose pour la vie, cyan pour le mana, vert clair pour l'endurance. Un bonus égal au maximum remplit le contour ; les bonus supérieurs restent indiqués exactement entre parenthèses. La jauge principale reste basée sur actuel / maximum.

- Chaque jauge affiche trois champs directement éditables : **actuel / maximum (temporaire)**. Le zéro temporaire reste visible.
- Cliquer sur un nombre, saisir une valeur ou un ajustement (`+5`, `-10`), puis Entrée ou cliquer ailleurs. Échap annule. Les pertes relatives de la valeur actuelle consomment d'abord les bonus temporaires.
- Maintenir le clic gauche et glisser le portrait pour déplacer l'ensemble ; le relâchement après déplacement n'ouvre pas les alliés.
- Clic gauche sur le portrait : vue des alliés (`/ochar`). Clic droit : vue MJ (`/ocharmj`).
- Clic molette sur le portrait : paramètres de taille. L'ancien bouton Character est retiré.

L'ATH remplace entièrement l'ancienne fiche personnelle et reste affiché tant que Character est actif, même si l'ancien réglage de visibilité était désactivé. Il disparaît lorsque Character est désactivé. Les jauges sont actualisées par les changements de données, sans boucle permanente de rafraîchissement. Elles représentent les ressources RP de Character, pas les points de vie du personnage WoW.

`Tests/hud-test.js` vérifie l'initialisation, les véritables setters de ressources, la consommation des bonus, les callbacks existants, la saisie, le masquage, la taille et les positions. Validation visuelle finale à effectuer en jeu après `/reload`.

## Vues RPG compactes

Les vues alliés, MJ, initiative et paramètres partagent un habillage sombre à bordures bronze, propre à Character. La vue des compagnons affiche uniquement une jauge de PV sans chiffres, sans bonus affichés et sans infobulle de valeurs, en deux colonnes avec huit membres visibles et un défilement à la molette pour les groupes plus grands. Les ressources et actions se sélectionnent directement dans deux rangées de boutons, sans menu déroulant. Le choix actif est coloré. La hauteur de la liste MJ suit son contenu jusqu’à la limite défilante. Les commandes de combat MJ sont incluses dans leur cadre. Les cartes d’initiative sont plus compactes, avec un repère doré pour le tour actif. Les réglages de taille et d’opacité restent disponibles.

`Tests/views-test.js` vérifie le chargement des vues, une liste de treize alliés, les limites du défilement et une action de ressource via les contrôles réels.

## Résolution des états entre deux tours

Après le dernier participant vivant, Joueur suivant avance le compteur et lance son animation. La résolution des états de début de tour apparaît ensuite : le MJ valide le E placé avant les participants pour reprendre le jeu. Il n’y a plus de résolution ni de validation en fin de tour. Les annonces de changement de tour sont affichées au centre de l’écran, sans RW. Les phases sont synchronisées avec le groupe et les clics pendant la transition sont bloqués.

`Tests/initiative-test.js` vérifie la résolution unique, l’incrément unique, le verrou pendant l’animation et les droits du MJ.

La frise utilise un sceau turquoise et bronze unique pour les états actifs (survol et clic inchangés), un sablier pour la résolution et un cerclage de portrait assorti à l’ATH. Le cadre du participant actif apparaît en fondu sur 0,22 seconde, sans animation permanente. Les deux symboles sont générés par `Tests/initiative-art.js` (environ 32 Ko au total).
