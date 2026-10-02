Cette copie XLSM est un instantané de « GrimoireCraft — Database Maître » (Google Drive).

La database embarquée (ObjectDatabase.lua / RecipeDatabase.lua) est générée depuis ce tableur :
  python3 Tools/Update-GrimoireDatabase.py          télécharge le tableur depuis Drive et régénère les .lua
  python3 Tools/Update-GrimoireDatabase.py --check  signale seulement un écart

Le workflow de release le lance automatiquement : éditer le tableur suffit, la release suivante l'embarque.
Les IDs de l'onglet Recettes sont résolus par nom depuis l'onglet Objets (seule la colonne ID objet compte).
