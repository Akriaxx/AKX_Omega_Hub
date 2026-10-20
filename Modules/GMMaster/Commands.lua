-- ============================================================
--  GM Master — Catalogue des commandes
--  Chaque section regroupe les commandes d'une même famille
--  (.npc, .gobject, .aura...) ; GM.Groups (plus bas) range les
--  sections dans les domaines de la barre latérale, un onglet par
--  section. Une section déclare :
--    fields  : les valeurs à saisir une seule fois (ID, échelle...)
--    actions : les boutons ; cmd est un modèle sans le point initial,
--              {clé} y est remplacé par la valeur du champ.
--    tracker : (facultatif) liste de ce qui a été appliqué, avec un
--              bouton « Retirer » par ligne.
--
--  Types de champ : id (entier, historique + favoris), number
--  (décimal, boutons - / +), text, player (bouton « Cible ») et
--  choice (bouton qui fait défiler les options).
--  Une action peut porter track = "add" | "remove" | "clear" pour
--  tenir le tracker à jour, ou toggle = "<modèle inverse>" pour
--  basculer selon l'état suivi.
--
--  La syntaxe suit les macros Epsilon déjà utilisées dans l'addon
--  (Spell/OmegaSpell_WTFMacroCache.generated.lua). Pour corriger une
--  commande, il suffit de modifier son modèle ici.
-- ============================================================

GMMaster = GMMaster or {}
local GM = GMMaster

local WHO = {
    { value = "",     label = "Ma cible" },
    { value = "self", label = "Moi" },
}

GM.Domains = {
    -- ── PNJ ────────────────────────────────────────────────────────────
    {
        key = "npc", title = "Créatures", tab = "Créature", prefix = ".npc",
        desc = "Faire apparaître, placer et animer une créature. Les actions sans ID visent le PNJ ciblé.",
        fields = {
            { key = "id",    label = "ID créature", kind = "id", enter = "spawn" },
            { key = "scale", label = "Échelle",     kind = "number", step = 0.1, default = "1", enter = "scale" },
            { key = "emote", label = "Émote",       kind = "id", enter = "emote" },
            { key = "text",  label = "Réplique",    kind = "text", enter = "say" },
        },
        actions = {
            { key = "spawn",  label = "Faire apparaître", cmd = "npc spawn {id}" },
            { key = "delete", label = "Supprimer",        cmd = "npc delete", tip = "Supprime le PNJ ciblé." },
            { key = "move",   label = "Amener ici",       cmd = "npc move",   tip = "Déplace le PNJ ciblé à votre position." },
            { key = "info",   label = "Infos",            cmd = "npc info" },
            { key = "near",   label = "PNJ proches",      cmd = "npc near" },
            { key = "turn",   label = "Tourner vers moi", cmd = "npc turn here" },
            { key = "scale",  label = "Appliquer l'échelle", cmd = "npc scale {scale}" },
            { key = "emote",  label = "Jouer l'émote",    cmd = "npc emote {emote}" },
            { key = "emoteloop", label = "Émote permanente", cmd = "npc emote {emote} repeat", tip = "L'émote persiste après un redémarrage du serveur." },
            { key = "stopemote", label = "Stopper l'émote", cmd = "npc emote 0" },
            { key = "say",    label = "Dire",             cmd = "npc say {text}" },
            { key = "yell",   label = "Crier",            cmd = "npc yell {text}" },
            { key = "follow", label = "Me suivre",        cmd = "npc follow" },
            { key = "unfollow", label = "Ne plus suivre", cmd = "npc follow stop" },
        },
    },

    -- ── Auras de PNJ ───────────────────────────────────────────────────
    {
        key = "npcaura", title = "Auras de PNJ", tab = "Auras", prefix = ".npc set aura",
        desc = "Poser et retirer une aura sur le PNJ ciblé. Pour retirer une aura de la liste, ciblez d'abord le PNJ concerné.",
        fields = {
            { key = "id", label = "ID du sort", kind = "id", spell = true, enter = "toggle" },
        },
        actions = {
            { key = "apply",  label = "Appliquer", cmd = "npc set aura {id}",   track = "add" },
            { key = "remove", label = "Retirer",   cmd = "npc set unaura {id}", track = "remove" },
            { key = "toggle", label = "Basculer",  cmd = "npc set aura {id}",   toggle = "npc set unaura {id}" },
        },
        tracker = {
            title = "Auras posées",
            key   = "{id}|{target}",
            off   = "npc set unaura {id}",
            target = true,
        },
    },

    -- ── Forge de PNJ ───────────────────────────────────────────────────
    -- Syntaxe : EpsilonLib/CommandDefinitions/init.lua. Les commandes
    -- visent le PNJ forgé ciblé (son modèle : tous ceux qui l'utilisent).
    {
        key = "forge", title = "Forge de PNJ", tab = "Forge", prefix = ".phase forge npc",
        desc = "Créer et personnaliser un PNJ forgé de la phase. Ciblez le PNJ forgé avant d'agir.",
        fields = {
            { key = "name",    label = "Nom",        kind = "text", enter = "name" },
            { key = "subname", label = "Sous-titre", kind = "text", enter = "subname" },
            { key = "display", label = "Display ID", kind = "id", enter = "adddisplay" },
            { key = "scale",   label = "Échelle",    kind = "number", step = 0.1, default = "1", enter = "scale" },
            { key = "aura",    label = "Aura",       kind = "id", spell = true, enter = "aura" },
            { key = "option",  label = "Option",     kind = "choice", width = 170, options = {
                { value = "clickable",      label = "Cliquable" },
                { value = "fakeplayer",     label = "Nom bleu (joueur)" },
                { value = "regen",          label = "Régénère / prend des dégâts" },
                { value = "flyable",        label = "Peut voler" },
                { value = "displayfaction", label = "Affiche sa faction" },
                { value = "vehicle",        label = "Véhicule" },
            } },
        },
        actions = {
            { key = "create",     label = "Créer",               cmd = "phase forge npc create", tip = "Crée un modèle forgé à partir du PNJ ciblé." },
            { key = "copy",       label = "Dupliquer",           cmd = "phase forge npc copy" },
            { key = "list",       label = "PNJ forgés",          cmd = "phase forge npc list" },
            { key = "name",       label = "Renommer",            cmd = "phase forge npc name {name}" },
            { key = "subname",    label = "Changer le sous-titre", cmd = "phase forge npc subname {subname}" },
            { key = "scale",      label = "Appliquer l'échelle", cmd = "phase forge npc scale {scale}" },
            { key = "adddisplay", label = "Ajouter le display",  cmd = "phase forge npc displays add {display} 1 1",
              tip = "Ajoute l'apparence à la liste des apparences possibles (échelle 1, poids 1)." },
            { key = "deldisplay", label = "Retirer le display",  cmd = "phase forge npc displays remove {display}" },
            { key = "aura",       label = "Poser l'aura",        cmd = "phase forge npc aura {aura}" },
            { key = "unaura",     label = "Retirer l'aura",      cmd = "phase forge npc unaura {aura}" },
            { key = "on",         label = "Option : oui",        cmd = "phase forge npc {option} on" },
            { key = "off",        label = "Option : non",        cmd = "phase forge npc {option} off" },
        },
    },

    -- ── Tenue du PNJ forgé ─────────────────────────────────────────────
    {
        key = "forgeoutfit", title = "Forge : tenue", tab = "Tenue", prefix = ".phase forge npc outfit",
        desc = "Habiller et modeler le PNJ forgé ciblé. Les boutons - / + du trait permettent de faire défiler les styles.",
        fields = {
            { key = "item",   label = "ID objet", kind = "id", enter = "equip" },
            { key = "slot",   label = "Main",     kind = "choice", options = {
                { value = "0", label = "Main droite" },
                { value = "1", label = "Main gauche" },
                { value = "2", label = "Distance" },
            } },
            { key = "race",   label = "Race (ID)", kind = "id", enter = "race" },
            { key = "gender", label = "Genre",     kind = "choice", options = {
                { value = "male",   label = "Masculin" },
                { value = "female", label = "Féminin" },
            } },
            { key = "part",   label = "Trait",     kind = "choice", options = {
                { value = "hair",       label = "Coiffure" },
                { value = "haircolor",  label = "Couleur des cheveux" },
                { value = "face",       label = "Visage" },
                { value = "skin",       label = "Peau" },
                { value = "facialhair", label = "Pilosité / bijoux" },
            }, width = 170 },
            { key = "value",  label = "Style",     kind = "number", step = 1, default = "1", enter = "feature" },
        },
        actions = {
            { key = "equip",    label = "Équiper",            cmd = "phase forge npc outfit equip {item}" },
            { key = "weapon",   label = "Équiper l'arme",     cmd = "phase forge npc weapon {item} {slot}" },
            { key = "unequip",  label = "Tout déséquiper",    cmd = "phase forge npc outfit unequip all", tip = "Retire tout sauf les armes." },
            { key = "race",     label = "Changer la race",    cmd = "phase forge npc outfit race {race}" },
            { key = "gender",   label = "Changer le genre",   cmd = "phase forge npc outfit gender {gender}" },
            { key = "feature",  label = "Appliquer le trait", cmd = "phase forge npc outfit {part} {value}" },
            { key = "guild",    label = "Tabard de ma guilde", cmd = "phase forge npc outfit guild" },
            { key = "add",      label = "Nouvelle tenue",     cmd = "phase forge npc outfit add" },
            { key = "copyfit",  label = "Copier la tenue",    cmd = "phase forge npc outfit copy" },
            { key = "listfit",  label = "Tenues",             cmd = "phase forge npc outfit list" },
        },
    },

    -- ── Dialogue du PNJ forgé ──────────────────────────────────────────
    {
        key = "gossip", title = "Forge : dialogue", tab = "Dialogue", prefix = ".phase forge npc gossip",
        desc = "Écrire la fenêtre de dialogue du PNJ forgé ciblé : textes, pages et options qui renvoient vers une page.",
        fields = {
            { key = "text",   label = "Texte",          kind = "text", width = 380, maxLetters = 255, enter = "textadd" },
            { key = "block",  label = "Bloc de texte",  kind = "id", history = false, enter = "overwrite" },
            { key = "optnum", label = "N° d'option",    kind = "id", history = false },
            { key = "page",   label = "N° de page",     kind = "id", history = false },
        },
        actions = {
            { key = "enable",    label = "Activer le dialogue",    cmd = "phase forge npc gossip enable" },
            { key = "disable",   label = "Désactiver",             cmd = "phase forge npc gossip disable", tip = "Les données du dialogue sont conservées." },
            { key = "debug",     label = "Mode débogage",          cmd = "phase forge npc gossip debug", tip = "Affiche les numéros de blocs, d'options et de pages dans la fenêtre." },
            { key = "textadd",   label = "Ajouter le texte",       cmd = "phase forge npc gossip text add {text}" },
            { key = "overwrite", label = "Remplacer le bloc",      cmd = "phase forge npc gossip text overwrite {block} {text}" },
            { key = "textdel",   label = "Retirer le bloc",        cmd = "phase forge npc gossip text remove {block}" },
            { key = "pageadd",   label = "Nouvelle page",          cmd = "phase forge npc gossip page add {text}", tip = "Crée une page dont le premier bloc est le texte saisi." },
            { key = "pagedel",   label = "Retirer la page",        cmd = "phase forge npc gossip page remove {page}" },
            { key = "pages",     label = "Lister les pages",       cmd = "phase forge npc gossip page list" },
            { key = "optadd",    label = "Ajouter une option",     cmd = "phase forge npc gossip option add {text}", tip = "Le texte saisi devient le libellé de l'option." },
            { key = "optlink",   label = "Relier option > page",   cmd = "phase forge npc gossip option link {optnum} {page}" },
            { key = "opttext",   label = "Renommer l'option",      cmd = "phase forge npc gossip option text {optnum} {text}" },
            { key = "optdel",    label = "Retirer l'option",       cmd = "phase forge npc gossip option remove {optnum}" },
        },
    },

    -- ── Objets ─────────────────────────────────────────────────────────
    {
        key = "gobject", title = "Objets", tab = "Objets", prefix = ".gobject",
        desc = "Poser et ajuster des objets de décor. Les actions sans ID visent l'objet sélectionné.",
        fields = {
            { key = "id",    label = "ID objet", kind = "id", enter = "spawn" },
            { key = "scale", label = "Échelle",  kind = "number", step = 0.1, default = "1", enter = "scale" },
            { key = "angle", label = "Rotation (Z)", kind = "number", step = 15, default = "0", enter = "turn" },
            { key = "range", label = "Rayon",    kind = "number", step = 5, default = "10", enter = "near" },
        },
        actions = {
            { key = "spawn",  label = "Poser",          cmd = "gobject spawn {id}" },
            { key = "select", label = "Sélectionner",   cmd = "gobject select", tip = "Sélectionne l'objet le plus proche." },
            { key = "unselect", label = "Désélectionner", cmd = "gobject unselect" },
            { key = "replace", label = "Remplacer par l'ID", cmd = "gobject replace {id}", tip = "Remplace l'objet sélectionné par l'objet de l'ID saisi." },
            { key = "delete", label = "Supprimer",      cmd = "gobject delete", tip = "Supprime l'objet sélectionné." },
            { key = "move",   label = "Amener ici",     cmd = "gobject move" },
            { key = "turn",   label = "Appliquer la rotation", cmd = "gobject turn {angle}" },
            { key = "info",   label = "Infos",          cmd = "gobject info" },
            { key = "scale",  label = "Appliquer l'échelle", cmd = "gobject scale {scale}" },
            { key = "near",   label = "Objets proches", cmd = "gobject near {range}" },
        },
    },

    -- ── Auras ──────────────────────────────────────────────────────────
    {
        key = "aura", title = "Auras", tab = "Auras", prefix = ".aura / .unaura",
        desc = "Appliquer puis retirer une aura sans retaper l'ID. La liste garde la trace de ce qui a été posé.",
        fields = {
            { key = "id",  label = "ID du sort", kind = "id", spell = true, enter = "toggle" },
            { key = "who", label = "Sur",        kind = "choice", options = WHO },
        },
        actions = {
            { key = "apply",  label = "Appliquer", cmd = "aura {id} {who}",   track = "add" },
            { key = "remove", label = "Retirer",   cmd = "unaura {id} {who}", track = "remove" },
            { key = "toggle", label = "Basculer",  cmd = "aura {id} {who}",   toggle = "unaura {id} {who}" },
            { key = "all",    label = "Tout retirer", cmd = "unaura all", track = "clear",
              tip = "Retire toutes les auras de la cible (ou les vôtres sans cible)." },
        },
        tracker = {
            title = "Auras appliquées",
            key   = "{id}|{who}|{target}",
            off   = "unaura {id} {who}",
            target = true,
        },
    },

    -- ── Morph ──────────────────────────────────────────────────────────
    {
        key = "morph", title = "Morph", tab = "Morph", prefix = ".morph / .demorph",
        desc = "Changer d'apparence et revenir à la normale en un clic.",
        fields = {
            { key = "id", label = "ID d'affichage", kind = "id", enter = "morph" },
        },
        actions = {
            { key = "morph",   label = "Morpher",   cmd = "morph {id}" },
            { key = "demorph", label = "Démorpher", cmd = "demorph" },
        },
    },

    -- ── Sorts ──────────────────────────────────────────────────────────
    {
        key = "cast", title = "Lancer un sort", tab = "Lancer", prefix = ".cast",
        desc = "Lancer un sort par son ID, sur votre cible, sur vous-même ou depuis le PNJ ciblé.",
        fields = {
            { key = "id", label = "ID du sort", kind = "id", spell = true, enter = "cast" },
        },
        actions = {
            { key = "cast",    label = "Lancer",          cmd = "cast {id}" },
            { key = "self",    label = "Sur moi",         cmd = "cast self {id}" },
            { key = "npccast", label = "Lancé par le PNJ", cmd = "npc cast {id}" },
        },
    },

    -- ── Modifier ───────────────────────────────────────────────────────
    {
        key = "modify", title = "Modifier", tab = "Modifier", prefix = ".modify",
        desc = "Ajuster taille, vitesse, points de vie et posture avec les boutons - / +.",
        fields = {
            { key = "scale", label = "Taille",  kind = "number", step = 0.05, default = "1", enter = "scale" },
            { key = "speed", label = "Vitesse", kind = "number", step = 0.1,  default = "1", enter = "speed" },
            { key = "hp",    label = "Points de vie", kind = "number", step = 10, default = "100", enter = "hp" },
            { key = "stand", label = "Posture (émote)", kind = "id", enter = "stand" },
        },
        actions = {
            { key = "scale",  label = "Appliquer la taille",   cmd = "modify scale {scale}" },
            { key = "speed",  label = "Appliquer la vitesse",  cmd = "modify speed {speed}" },
            { key = "hp",     label = "Appliquer les PV",      cmd = "modify hp {hp}" },
            { key = "stand",  label = "Prendre la posture",    cmd = "modify standstate {stand}" },
            { key = "sit",    label = "S'asseoir (haut)",      cmd = "modify sitstate high", tip = "Assis sur un siège invisible." },
            { key = "sithelp", label = "Aide : hauteurs",      cmd = "help modify sitstate", tip = "Affiche dans le chat les hauteurs d'assise possibles." },
            { key = "reset",  label = "Taille et vitesse à 1", cmd = { "modify scale 1", "modify speed 1" } },
        },
    },

    -- ── Phase ──────────────────────────────────────────────────────────
    {
        key = "phase", title = "Phase", tab = "Phase", prefix = ".phase",
        desc = "Entrer dans une phase, en sortir et gérer le mode MJ.",
        fields = {
            { key = "id",   label = "ID de phase", kind = "id", enter = "enter" },
            { key = "name", label = "Point de téléportation", kind = "text", enter = "tele", history = true },
        },
        actions = {
            { key = "enter",  label = "Entrer",           cmd = "phase enter {id}" },
            { key = "here",   label = "Entrer ici",       cmd = "phase enter {id} here", tip = "Entre dans la phase en gardant votre position." },
            { key = "exit",   label = "Quitter la phase", cmd = "phase exit" },
            { key = "tele",   label = "Aller au point",   cmd = "phase tele {name}" },
            { key = "dmon",   label = "Mode MJ : oui",    cmd = "phase dm on" },
            { key = "dmoff",  label = "Mode MJ : non",    cmd = "phase dm off" },
        },
    },

    -- ── Téléportation ──────────────────────────────────────────────────
    {
        key = "tele", title = "Téléportation", tab = "Téléportation", prefix = ".tele / .appear / .summon",
        desc = "Rejoindre un lieu ou un joueur, ou faire venir un joueur à vous.",
        fields = {
            { key = "name",   label = "Lieu",   kind = "text", enter = "tele", history = true },
            { key = "player", label = "Joueur", kind = "player", enter = "appear", history = true },
        },
        actions = {
            { key = "tele",   label = "Aller au lieu",   cmd = "tele {name}" },
            { key = "appear", label = "Rejoindre",       cmd = "appear {player}" },
            { key = "summon", label = "Invoquer",        cmd = "summon {player}" },
            { key = "gps",    label = "Ma position",     cmd = "gps" },
        },
    },

    -- ── Triches ────────────────────────────────────────────────────────
    {
        key = "cheat", title = "Triches", tab = "Triches", prefix = ".cheat",
        desc = "Interrupteurs de session : vol, invulnérabilité et recharges.",
        fields = {},
        actions = {
            { key = "flyon",   label = "Vol : oui",              cmd = "cheat fly on" },
            { key = "flyoff",  label = "Vol : non",              cmd = "cheat fly off" },
            { key = "godon",   label = "Invulnérable : oui",     cmd = "cheat god on" },
            { key = "godoff",  label = "Invulnérable : non",     cmd = "cheat god off" },
            { key = "cdon",    label = "Sans recharge : oui",    cmd = "cheat cooldown on" },
            { key = "cdoff",   label = "Sans recharge : non",    cmd = "cheat cooldown off" },
        },
    },
}

-- ── Domaines de la barre latérale ─────────────────────────────────────────
-- Chaque domaine regroupe plusieurs sections (les tables ci-dessus), une
-- par onglet. Les sections gardent leur propre clé : historique, favoris
-- et auras suivies sont rangés par section.

GM.Groups = {
    { key = "npc",    title = "PNJ",         sections = { "npc", "npcaura", "forge", "forgeoutfit", "gossip" } },
    { key = "spell",  title = "Sorts",       sections = { "aura", "cast" } },
    { key = "object", title = "Objets",      sections = { "gobject" } },
    { key = "self",   title = "Personnage",  sections = { "morph", "modify", "cheat" } },
    { key = "travel", title = "Déplacement", sections = { "tele", "phase" } },
}

-- ── Index ─────────────────────────────────────────────────────────────────

GM.DomainByKey = {}
for _, domain in ipairs(GM.Domains) do
    GM.DomainByKey[domain.key] = domain
    domain.fieldByKey, domain.actionByKey = {}, {}
    for _, field in ipairs(domain.fields) do
        domain.fieldByKey[field.key] = field
        if field.history == nil then field.history = (field.kind == "id") end
    end
    for _, action in ipairs(domain.actions) do
        domain.actionByKey[action.key] = action
    end
end

GM.GroupByKey = {}
for _, group in ipairs(GM.Groups) do
    GM.GroupByKey[group.key] = group
    for _, key in ipairs(group.sections) do
        local domain = assert(GM.DomainByKey[key], "section inconnue : " .. key)
        domain.group = group
    end
end
