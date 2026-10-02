#!/usr/bin/env python3
"""
Grimoire de Craft — régénère la database embarquée depuis la « Database Maître ».

Les mainteneurs éditent le classeur sur Google Drive ; ce script le télécharge
puis réécrit Modules/GrimoireCraft/ObjectDatabase.lua et RecipeDatabase.lua.

    python3 Tools/Update-GrimoireDatabase.py              # télécharge depuis Drive
    python3 Tools/Update-GrimoireDatabase.py fichier.xlsm # utilise un fichier local
    python3 Tools/Update-GrimoireDatabase.py --check      # n'écrit rien, signale un écart

Python 3 standard uniquement (pas d'openpyxl) : le .xlsm est lu comme un zip XML.
Les colonnes « ID » de l'onglet Recettes sont des formules que Google Sheets
n'exporte pas (#NOM ?) : les IDs sont donc résolus par nom depuis l'onglet Objets.
"""

import os
import re
import shutil
import sys
import unicodedata
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

DRIVE_FILE_ID = "1xvylh4pNRiEp8TNF2wV-tVCZRbRfLuhq"
DRIVE_URL = "https://drive.google.com/uc?export=download&id=" + DRIVE_FILE_ID

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODULE_DIR = os.path.join(ROOT, "Modules", "GrimoireCraft")
SNAPSHOT = os.path.join(MODULE_DIR, "DatabaseSource", "GrimoireCraft_Database_Maitre.xlsm")
OBJECT_LUA = os.path.join(MODULE_DIR, "ObjectDatabase.lua")
RECIPE_LUA = os.path.join(MODULE_DIR, "RecipeDatabase.lua")

# Libellés du tableur -> libellés utilisés par l'addon (icônes, filtres).
PROFESSIONS = {"Couture": "Couturier", "Forge": "Forgeron"}

# Outils requis par GrimoireCraft.lua mais absents du tableur.
EXTRA_OBJECTS = {
    14072810: {"name": "Carnet de Survie", "category": "Outil", "usage": "Outil"},
    14072841: {"name": "Mallette d’Ingénieur", "category": "Outil", "usage": "Outil"},
    14072844: {"name": "Mortier et Pilon", "category": "Outil", "usage": "Outil"},
}

# ── Lecture xlsm ────────────────────────────────────────────────────────────

NS = {
    "m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}
M = "{%s}" % NS["m"]


def column_index(ref):
    n = 0
    for ch in re.match(r"[A-Z]+", ref).group():
        n = n * 26 + ord(ch) - 64
    return n - 1


def read_workbook(path):
    z = zipfile.ZipFile(path)
    shared = []
    if "xl/sharedStrings.xml" in z.namelist():
        for si in ET.fromstring(z.read("xl/sharedStrings.xml")).findall("m:si", NS):
            shared.append("".join(t.text or "" for t in si.iter(M + "t")))
    rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
    targets = {r.get("Id"): r.get("Target") for r in rels}
    sheets = {}
    for sheet in ET.fromstring(z.read("xl/workbook.xml")).find("m:sheets", NS):
        target = targets[sheet.get("{%s}id" % NS["r"])].lstrip("/")
        if not target.startswith("xl/"):
            target = "xl/" + target
        rows = []
        for row in ET.fromstring(z.read(target)).iter(M + "row"):
            cells = {}
            for c in row.findall("m:c", NS):
                v = c.find("m:v", NS)
                kind = c.get("t")
                if kind == "s" and v is not None:
                    value = shared[int(v.text)]
                elif kind == "inlineStr":
                    value = "".join(t.text or "" for t in c.iter(M + "t"))
                else:
                    value = v.text if v is not None else None
                cells[column_index(c.get("r"))] = value
            width = max(cells) + 1 if cells else 0
            rows.append([cells.get(i) for i in range(width)])
        sheets[sheet.get("name")] = rows
    return sheets


# ── Normalisation ───────────────────────────────────────────────────────────

def text(row, i):
    if i >= len(row) or row[i] is None:
        return None
    value = str(row[i]).strip()
    if value == "" or value.startswith("#"):  # #NOM ?, #N/D… : formules non exportées
        return None
    return value


def integer(row, i):
    value = text(row, i)
    if value is None:
        return None
    try:
        return int(float(value.replace(",", ".")))
    except ValueError:
        return None


def name_key(name):
    name = unicodedata.normalize("NFKD", name.replace("’", "'"))
    name = "".join(ch for ch in name if not unicodedata.combining(ch))
    return re.sub(r"\s+", " ", name).strip().lower()


def lua_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


# ── Conversion ──────────────────────────────────────────────────────────────

def merge_usage(a, b):
    if not a or a == b:
        return b or a
    if not b:
        return a
    parts = []
    for usage in (a + " + " + b).split(" + "):
        if usage not in parts:
            parts.append(usage)
    return " + ".join(parts)


def build_objects(rows, warnings):
    objects = {}
    aliases = {}
    for row in rows[1:]:
        name = text(row, 1)
        if not name:
            continue
        item_id = integer(row, 0)
        if item_id is None:
            warnings.append("Objet sans ID ignoré : " + name)
            continue
        aliases.setdefault(name_key(name), item_id)
        entry = {
            "name": name,
            "category": text(row, 2),
            "profession": text(row, 3),
            "usage": text(row, 4),
            "notes": text(row, 5),
        }
        if item_id in objects:
            # Doublon d'ID (variantes d'orthographe) : une seule entrée, usages fusionnés.
            kept = objects[item_id]
            kept["usage"] = merge_usage(kept["usage"], entry["usage"])
            for key in ("category", "profession", "notes"):
                kept[key] = kept[key] or entry[key]
        else:
            objects[item_id] = entry
    for item_id, extra in EXTRA_OBJECTS.items():
        objects.setdefault(item_id, dict(extra))
        aliases.setdefault(name_key(extra["name"]), item_id)
    return objects, aliases


def build_difficulty_minimums(rows):
    """Onglet Listes : Difficulté (col. D) -> Rand minimum (col. E)."""
    minimums = {}
    for row in rows[1:]:
        difficulty, minimum = text(row, 3), integer(row, 4)
        if difficulty and minimum is not None:
            minimums[difficulty] = minimum
    return minimums


def build_recipes(rows, ids_by_name, difficulty_minimums, warnings):
    def resolve(name, context):
        item_id = ids_by_name.get(name_key(name))
        if item_id is None:
            warnings.append("ID introuvable pour « %s » (%s)" % (name, context))
        return item_id

    recipes = []
    for row in rows[1:]:
        key = text(row, 0)
        name = text(row, 1)
        if not key or not name:
            continue
        profession = text(row, 2)
        difficulty = text(row, 3)
        minimum = integer(row, 4)
        if minimum is None:
            minimum = difficulty_minimums.get(difficulty)
        output_name = text(row, 5) or name
        recipe = {
            "officialKey": key,
            "name": name,
            "outputItemID": resolve(output_name, key),
            "outputQuantity": integer(row, 7) or 1,
            "profession": PROFESSIONS.get(profession, profession),
            "difficulty": difficulty,
            "difficultyMinimum": minimum,
            "materials": [],
        }
        for slot in range(6):
            col = 8 + slot * 3
            component = text(row, col)
            if not component:
                continue
            recipe["materials"].append({
                "itemID": resolve(component, key),
                "quantity": integer(row, col + 2) or 1,
                "name": component,
            })
        recipes.append(recipe)
    return recipes


# ── Écriture Lua ────────────────────────────────────────────────────────────

OBJECT_FIELDS = ("name", "category", "profession", "usage", "notes")


def render_objects(objects):
    out = [
        "-- GrimoireCraft - Base officielle des objets",
        "-- Généré par Tools/Update-GrimoireDatabase.py depuis « GrimoireCraft — Database Maître » (Google Drive).",
        "-- Ne pas éditer à la main : modifier le tableur puis relancer le script.",
        "",
        "GrimoireCraftOfficialObjects = {",
    ]
    for item_id in sorted(objects):
        obj = objects[item_id]
        fields = ", ".join("%s=%s" % (k, lua_string(obj[k])) for k in OBJECT_FIELDS if obj.get(k))
        out.append("    [%d] = { %s }," % (item_id, fields))
    out.append("}")
    return "\n".join(out) + "\n"


def render_recipes(recipes):
    out = [
        "-- GrimoireCraft - Base officielle des recettes",
        "-- Généré par Tools/Update-GrimoireDatabase.py depuis « GrimoireCraft — Database Maître » (Google Drive).",
        "-- Les recettes sans ID de sortie restent visibles mais ne sont pas fabricables tant que l’ID n’est pas renseigné.",
        "GrimoireCraftOfficialRecipes = {",
    ]
    for r in recipes:
        out.append("    {")
        out.append("        officialKey=%s," % lua_string(r["officialKey"]))
        out.append("        name=%s," % lua_string(r["name"]))
        if r["outputItemID"]:
            out.append("        outputItemID=%d," % r["outputItemID"])
        out.append("        outputQuantity=%d," % r["outputQuantity"])
        if r["profession"]:
            out.append("        profession=%s," % lua_string(r["profession"]))
        if r["difficulty"]:
            out.append("        difficulty=%s," % lua_string(r["difficulty"]))
        if r["difficultyMinimum"] is not None:
            out.append("        difficultyMinimum=%d," % r["difficultyMinimum"])
        out.append("        materials={")
        for m in r["materials"]:
            parts = []
            if m["itemID"]:
                parts.append("itemID=%d" % m["itemID"])
            parts.append("quantity=%d" % m["quantity"])
            out.append("            {%s}, -- %s" % (", ".join(parts), m["name"]))
        out.append("        },")
        out.append("    },")
    out.append("}")
    return "\n".join(out) + "\n"


# ── Main ────────────────────────────────────────────────────────────────────

def download(dest):
    print("Téléchargement de la Database Maître depuis Google Drive…")
    with urllib.request.urlopen(DRIVE_URL) as resp:
        data = resp.read()
    if not data.startswith(b"PK"):
        sys.exit("Le téléchargement n'est pas un classeur (partage Drive désactivé ?).")
    with open(dest, "wb") as fh:
        fh.write(data)


def write_if_changed(path, content, check):
    try:
        with open(path, encoding="utf-8") as fh:
            current = fh.read()
    except FileNotFoundError:
        current = None
    if current == content:
        return False
    if not check:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(content)
    return True


def main(argv):
    check = "--check" in argv
    args = [a for a in argv if not a.startswith("--")]
    if args:
        source = args[0]
        if not check and os.path.abspath(source) != SNAPSHOT:
            shutil.copyfile(source, SNAPSHOT)
    else:
        source = SNAPSHOT + ".download"
        download(source)

    try:
        sheets = read_workbook(source)
    finally:
        if source.endswith(".download"):
            if not check:
                shutil.copyfile(source, SNAPSHOT)
            os.remove(source)

    warnings = []
    objects, ids_by_name = build_objects(sheets["Objets"], warnings)
    minimums = build_difficulty_minimums(sheets["Listes"])
    recipes = build_recipes(sheets["Recettes"], ids_by_name, minimums, warnings)

    changed = [
        os.path.basename(path)
        for path, content in ((OBJECT_LUA, render_objects(objects)), (RECIPE_LUA, render_recipes(recipes)))
        if write_if_changed(path, content, check)
    ]

    print("%d objets, %d recettes." % (len(objects), len(recipes)))
    for w in warnings:
        print("  ! " + w)
    if not changed:
        print("Database déjà à jour.")
    elif check:
        print("Écart avec le tableur : " + ", ".join(changed))
        return 1
    else:
        print("Mis à jour : " + ", ".join(changed))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
