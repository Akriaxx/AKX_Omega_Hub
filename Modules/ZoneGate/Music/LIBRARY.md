# Bibliothèque sonore Omega

72 créations originales par synthèse, sans enregistrement ni échantillon externe. Les noms d'instruments désignent les timbres recherchés : ils sont stylisés, pas des captations acoustiques.

Chaque famille possède trois intentions (Paisible, Mystérieux, Menaçant), chacune en deux formats : Accent (1,25 seconde) et Phrase (2,9 secondes).

| Famille | Timbres |
| --- | --- |
| Désert / Moyen-Orient | Oud pincé et souffle de ney |
| Asiatique | Cordes pincées et flûte |
| Bambou / Bois | Bambou creux et petites percussions |
| Cordes / Médiéval | Luth et lyre |
| Tambours / Percussions | Peaux et résonances |
| Forêt / Nature | Feuillage et chant bref |
| Montagne / Neige | Vent froid et clochette |
| Mer / Port | Vague, bois et cloche |
| Magie / Sanctuaire | Cristal et halo harmonique |
| Ruines / Sombre | Pierre et corde frottée |
| Ville / Auberge | Luth chaleureux et clochette |
| Danger / Combat | Tambour et tension métallique |

Dans l'Atelier, ouvrir **Rythme & son**, puis **Sons**, choisir une famille et une variation. **Tester** permet d'écouter le choix. Entrée et Retour se règlent séparément. Aucun thème existant n'est modifié automatiquement.

Format OGG Vorbis mono à 44,1 kHz, qualité 3. Environ 0,93 Mio pour les 72 fichiers. Les fichiers sont joués à la demande, sans décodage préalable par l'addon. Les autres joueurs doivent posséder ces fichiers pour entendre les thèmes partagés.

`Tools/sound-library.py` permet de reconstruire les sons avec NumPy et imageio-ffmpeg. Il encode directement en OGG sans conserver de WAV intermédiaires, vérifie chaque décodage (durée, niveau, absence de saturation et fermeture des extrémités), régénère le catalogue et conserve les fichiers musicaux personnels dans le manifeste. Ces dépendances ne sont pas nécessaires en jeu.

Le catalogue JSON décrit les durées et tailles exactes. Les tests Lua couvrent le classement, les 72 choix, l'enregistrement dans le thème, l'option Aucun et la conservation des musiques personnelles. L'écoute et la validation finale dans le client de jeu restent à faire.
