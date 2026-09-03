-- ============================================================
--  Item Creator — Données statiques
--  Paliers de qualité et définitions des stats (coûts par défaut)
-- ============================================================

ItemCreator = ItemCreator or {}
local IC = ItemCreator

-- ── Paliers de qualité ────────────────────────────────────────────────────────
-- pts = nombre maximum de points pour ce palier
-- r/g/b = couleur d'affichage

IC.DEFAULT_TIERS = {
    { name = "Rose",   pts = 8,  r = 1.00, g = 0.55, b = 0.72 },
    { name = "Vert",   pts = 12, r = 0.30, g = 0.88, b = 0.30 },
    { name = "Bleu",   pts = 16, r = 0.30, g = 0.55, b = 1.00 },
    { name = "Orange", pts = 20, r = 1.00, g = 0.60, b = 0.15 },
    { name = "Rouge",  pts = 24, r = 1.00, g = 0.22, b = 0.22 },
    { name = "Violet", pts = 28, r = 0.75, g = 0.30, b = 1.00 },
    { name = "Noir",   pts = 32, r = 0.60, g = 0.60, b = 0.65 },
}

-- ── Groupes de stats ─────────────────────────────────────────────────────────
-- Chaque groupe correspond à un onglet dans le panel créateur.
-- id       : clé interne unique (sauvegardée en DB)
-- label    : texte de la stat affiché dans la liste
-- cost     : coût par +1 (positif = dépense des pts, négatif = malus qui rembourse)
-- allowNeg : true si la valeur peut descendre sous 0 (malus volontaire)

IC.STAT_GROUPS = {
    -- ── Onglet 1 : Stats de base ─────────────────────────────────────────────
    {
        id = "base", label = "Base",
        stats = {
            { id = "armure",           label = "Armure",        cost = 1 },
            { id = "force",            label = "Force",         cost = 1 },
            { id = "mystique",         label = "Mystique",      cost = 1 },
            { id = "perception",       label = "Perception",    cost = 1 },
            { id = "adresse",          label = "Adresse",       cost = 1 },
            { id = "esprit",           label = "Esprit",        cost = 1 },
            { id = "constitution",     label = "Constitution",  cost = 1 },
            { id = "bonus_pa",         label = "PA",            cost = 2 },
            { id = "bonus_fatigue",    label = "Fatigue",       cost = 2 },
            { id = "bonus_terrestre",  label = "Terrestre",     cost = 2 },
            { id = "bonus_initiative", label = "Initiative",    cost = 3 },
        },
    },

    -- ── Onglet 2 : Pénétration ───────────────────────────────────────────────
    {
        id = "pen", label = "PEN",
        stats = {
            { id = "pen_tranchant",   label = "Tranchant",   cost = 2, allowNeg = true },
            { id = "pen_contendant",  label = "Contendant",  cost = 2, allowNeg = true },
            { id = "pen_perforant",   label = "Perforant",   cost = 2, allowNeg = true },
            { id = "pen_poison",      label = "Poison",      cost = 2, allowNeg = true },
            { id = "pen_hemoragie",   label = "Hémorragie",  cost = 2, allowNeg = true },
            { id = "pen_malediction", label = "Malédiction", cost = 2, allowNeg = true },
            { id = "pen_feu",         label = "Feu",         cost = 2, allowNeg = true },
            { id = "pen_eau",         label = "Eau",         cost = 2, allowNeg = true },
            { id = "pen_terre",       label = "Terre",       cost = 2, allowNeg = true },
            { id = "pen_air",         label = "Air",         cost = 2, allowNeg = true },
            { id = "pen_esprit",      label = "Esprit",      cost = 2, allowNeg = true },
            { id = "pen_pourriture",  label = "Pourriture",  cost = 2, allowNeg = true },
            { id = "pen_vie",         label = "Vie",         cost = 2, allowNeg = true },
            { id = "pen_mort",        label = "Mort",        cost = 2, allowNeg = true },
            { id = "pen_ordre",       label = "Ordre",       cost = 2, allowNeg = true },
            { id = "pen_desordre",    label = "Désordre",    cost = 2, allowNeg = true },
            { id = "pen_ombre",       label = "Ombre",       cost = 2, allowNeg = true },
            { id = "pen_lumiere",     label = "Lumière",     cost = 2, allowNeg = true },
        },
    },

    -- ── Onglet 3 : Résistances ───────────────────────────────────────────────
    {
        id = "resi", label = "RESI",
        stats = {
            { id = "resi_tranchant",   label = "Tranchant",   cost = 2 },
            { id = "resi_contendant",  label = "Contendant",  cost = 2 },
            { id = "resi_perforant",   label = "Perforant",   cost = 2 },
            { id = "resi_poison",      label = "Poison",      cost = 2 },
            { id = "resi_hemoragie",   label = "Hémorragie",  cost = 2 },
            { id = "resi_malediction", label = "Malédiction", cost = 2 },
            { id = "resi_feu",         label = "Feu",         cost = 2 },
            { id = "resi_eau",         label = "Eau",         cost = 2 },
            { id = "resi_terre",       label = "Terre",       cost = 2 },
            { id = "resi_air",         label = "Air",         cost = 2 },
            { id = "resi_esprit",      label = "Esprit",      cost = 2 },
            { id = "resi_pourriture",  label = "Pourriture",  cost = 2 },
            { id = "resi_vie",         label = "Vie",         cost = 2 },
            { id = "resi_mort",        label = "Mort",        cost = 2 },
            { id = "resi_ordre",       label = "Ordre",       cost = 2 },
            { id = "resi_desordre",    label = "Désordre",    cost = 2 },
            { id = "resi_ombre",       label = "Ombre",       cost = 2 },
            { id = "resi_lumiere",     label = "Lumière",     cost = 2 },
        },
    },

    -- ── Onglet 4 : Capacités ─────────────────────────────────────────────────
    {
        id = "cap", label = "Capacités",
        stats = {
            { id = "atk_force",       label = "Attaque  · Force",         cost = 2 },
            { id = "atk_mystique",    label = "Attaque  · Mystique",      cost = 2 },
            { id = "atk_perception",  label = "Attaque  · Perception",    cost = 2 },
            { id = "def_consti",      label = "Défense  · Constitution",  cost = 2 },
            { id = "def_bouclier",    label = "Défense  · Bouclier",      cost = 2 },
            { id = "exp_force",       label = "Expertise · Force",        cost = 2 },
            { id = "exp_mystique",    label = "Expertise · Mystique",     cost = 2 },
            { id = "exp_consti",      label = "Expertise · Constitution", cost = 2 },
            { id = "soin_mystique",   label = "Soin · Mystique",          cost = 2 },
            { id = "soin_consti",     label = "Soin · Constitution",      cost = 2 },
            { id = "buff_mystique",   label = "Buff · Mystique",          cost = 2 },
            { id = "buff_consti",     label = "Buff · Constitution",      cost = 2 },
            { id = "buff_force",      label = "Buff · Force",             cost = 2 },
            { id = "buff_percep",     label = "Buff · Perception",        cost = 2 },
            { id = "debuff_mystique", label = "Debuff · Mystique",        cost = 2 },
            { id = "debuff_consti",   label = "Debuff · Constitution",    cost = 2 },
            { id = "debuff_force",    label = "Debuff · Force",           cost = 2 },
            { id = "debuff_percep",   label = "Debuff · Perception",      cost = 2 },
            { id = "camou_adresse",   label = "Camouflage · Adresse",     cost = 2 },
            { id = "camou_mystique",  label = "Camouflage · Mystique",    cost = 2 },
            { id = "camou_percep",    label = "Camouflage · Perception",  cost = 2 },
            { id = "pa_force",        label = "Perce-Armure · Force",     cost = 2 },
            { id = "pa_mystique",     label = "Perce-Armure · Mystique",  cost = 2 },
            { id = "pa_percep",       label = "Perce-Armure · Percep.",   cost = 2 },
            { id = "prov_force",      label = "Provocation · Force",      cost = 2 },
            { id = "prov_esprit",     label = "Provocation · Esprit",     cost = 2 },
            { id = "prov_consti",     label = "Provocation · Constit.",   cost = 2 },
            { id = "prov_mystique",   label = "Provocation · Mystique",   cost = 2 },
            { id = "intim_force",     label = "Intimidation · Force",     cost = 2 },
            { id = "intim_esprit",    label = "Intimidation · Esprit",    cost = 2 },
            { id = "intim_consti",    label = "Intimidation · Constit.",  cost = 2 },
            { id = "intim_mystique",  label = "Intimidation · Mystique",  cost = 2 },
            { id = "saig_force",      label = "Saignement · Force",       cost = 2 },
            { id = "saig_mystique",   label = "Saignement · Mystique",    cost = 2 },
            { id = "saig_percep",     label = "Saignement · Perception",  cost = 2 },
            { id = "empoison_myst",   label = "Empoisonn. · Mystique",    cost = 2 },
            { id = "empoison_consti", label = "Empoisonn. · Constit.",    cost = 2 },
            { id = "empoison_percep", label = "Empoisonn. · Perception",  cost = 2 },
        },
    },
}

-- ── Lookup rapide par id de stat ─────────────────────────────────────────────
IC.STAT_BY_ID = {}
for _, group in ipairs(IC.STAT_GROUPS) do
    for _, stat in ipairs(group.stats) do
        IC.STAT_BY_ID[stat.id] = stat
    end
end
