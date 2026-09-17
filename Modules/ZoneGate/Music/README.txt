Zone Gate — dossier Music
==========================

Déposez ici vos fichiers .ogg / .mp3 / .wav : ils apparaîtront comme choix
dans le menu "Musique" de l'éditeur de thèmes (bouton "Thèmes...").

IMPORTANT — pourquoi ce n'est pas automatique en jeu :
WoW ne permet à AUCUN addon de lister le contenu d'un dossier au moment de
l'exécution (aucune API Lua pour ça, pour des raisons de sécurité). La liste
qui apparaît dans le jeu vient donc d'un fichier généré à l'avance,
Manifest.lua, qui liste simplement les noms de fichiers présents ici au
moment où il a été (re)généré.

Comment rafraîchir la liste après avoir ajouté/retiré des fichiers :
  - Dans Claude Code, demandez "régénère la liste Music de Zone Gate".
  - Ou manuellement : Manifest.lua doit contenir
        ZoneGateMusicManifest = { "fichier1.ogg", "fichier2.mp3", ... }
    avec un nom exact par fichier présent dans ce dossier (sensible à la
    casse), séparés par des virgules.

Formats supportés par le client : .ogg (Vorbis), .mp3, .wav.
