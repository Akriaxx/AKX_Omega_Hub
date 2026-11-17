-- ============================================================
--  GM Master — Macros techniques et barre MJ
--  Une macro technique = une ou plusieurs commandes serveur, une par
--  ligne, écrites librement (« mod speed 20 », « .ph f n scale 2 »).
--  Chaque ligne est résolue avec la liste des commandes du serveur
--  (Abbrev.generated.lua, issue d'EpsilonLib) : on retrouve la
--  commande complète, sa syntaxe documentée et le nombre d'arguments
--  attendus, puis on l'envoie sous sa forme abrégée sans ambiguïté.
--
--  Variables : {cible} / {target} = nom de la cible, {moi} / {me} =
--  votre nom. Une ligne qui commence par # est un commentaire.
-- ============================================================

GMMaster = GMMaster or {}
local GM = GMMaster
local Trim = function(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local MACRO_LINES_MAX = 10
GM.MACRO_LINES_MAX = MACRO_LINES_MAX

-- ── Résolution d'une ligne ────────────────────────────────────────────────
-- Même règle que le serveur : un mot désigne la commande dont le nom est
-- identique, sinon l'unique commande sœur qui commence par ce mot.
-- Renvoie une table :
--   path      = { "modify", "speed" }     (mots complets reconnus)
--   args      = { "20" }                  (le reste, jamais abrégé)
--   node      = nœud de l'arbre (syn, req, run)
--   short     = « mod sp 20 »             (forme envoyée, sans point)
--   status    = "ok" | "warn" | "error"
--   problem   = message lisible si status ~= "ok"

local function Candidates(level, word)
    local list = {}
    for name in pairs(level) do
        if name:sub(1, #word) == word then list[#list + 1] = name end
    end
    table.sort(list)
    return list
end

function GM.ResolveLine(line)
    local text = Trim(line):gsub("^%.+", "")
    local words = {}
    for w in text:gmatch("%S+") do words[#words + 1] = w end
    local res = { path = {}, args = {}, raw = text }
    if #words == 0 then
        res.status, res.problem = "error", "Ligne vide"
        return res
    end

    local level, node, i = GM.CommandTree or {}, nil, 1
    local shortWords = {}
    while i <= #words and level do
        local word = words[i]:lower()
        local key = level[word] and word
        if not key then
            local list = Candidates(level, word)
            if #list == 1 then
                key = list[1]
            elseif #list > 1 then
                -- Comme le serveur : un mot qui commence plusieurs
                -- sous-commandes est refusé (« .n s » : say, scale, set…),
                -- même après une commande qui accepte des arguments.
                res.ambiguous = { word = words[i], options = list }
                break
            else
                break
            end
        end
        node = level[key]
        res.path[#res.path + 1] = key
        shortWords[#shortWords + 1] = node.s
        level = node.sub
        i = i + 1
    end
    for j = i, #words do
        res.args[#res.args + 1] = words[j]
        shortWords[#shortWords + 1] = words[j]
    end
    res.node = node

    if res.ambiguous then
        local opts = table.concat(res.ambiguous.options, ", ", 1, math.min(6, #res.ambiguous.options))
        if #res.ambiguous.options > 6 then opts = opts .. "…" end
        res.status, res.problem = "error", "« " .. res.ambiguous.word .. " » est ambigu : " .. opts
        res.short = text
    elseif not node then
        res.status, res.problem = "warn", "Commande absente de la doc EpsilonLib : envoyée telle quelle"
        res.short = text
    elseif not node.run then
        local subs = {}
        for name in pairs(node.sub or {}) do subs[#subs + 1] = name end
        table.sort(subs)
        local list = table.concat(subs, ", ", 1, math.min(6, #subs))
        if #subs > 6 then list = list .. "…" end
        res.status, res.problem = "error", "Sous-commande attendue : " .. list
        res.short = table.concat(shortWords, " ")
    else
        res.short = table.concat(shortWords, " ")
        if (node.req or 0) > #res.args then
            res.status = "warn"
            res.problem = "La doc attend " .. node.req .. " argument" .. (node.req > 1 and "s" or "")
                .. " (" .. #res.args .. " fourni" .. (#res.args > 1 and "s" or "") .. ")"
        else
            res.status = "ok"
        end
    end
    res.full = table.concat(res.path, " ")
    if #res.args > 0 then res.full = (res.full ~= "" and res.full .. " " or "") .. table.concat(res.args, " ") end
    if #res.short + 1 > 255 then
        res.status, res.problem = "error", "Commande trop longue : " .. (#res.short + 1) .. " / 255 caractères"
    end
    return res
end

-- ── Variables ─────────────────────────────────────────────────────────────

local function TargetName()
    if UnitExists and UnitExists("target") then
        return GetUnitName and GetUnitName("target", true) or UnitName("target")
    end
end

--- Remplace {cible} et {moi}. Renvoie le texte ou nil + erreur.
function GM.ExpandVariables(line)
    local err
    local out = line:gsub("{(%a+)}", function(name)
        name = name:lower()
        if name == "cible" or name == "target" then
            local t = TargetName()
            if not t then err = "Aucune cible pour {" .. name .. "}" return "" end
            return t
        elseif name == "moi" or name == "me" then
            return UnitName("player") or ""
        end
    end)
    if err then return nil, err end
    return out
end

--- Lignes utiles d'une macro (sans vides ni commentaires).
function GM.MacroLines(text)
    local lines = {}
    for line in (tostring(text or "") .. "\n"):gmatch("([^\n]*)\n") do
        line = Trim(line)
        if line ~= "" and not line:match("^#") then lines[#lines + 1] = line end
    end
    return lines
end

-- ── Interrupteurs ─────────────────────────────────────────────────────────
-- « [on/off] » dans une ligne est remplacé par on ou off selon l'état.

local SWITCH_TOKEN = "%[[oO][nN]/[oO][fF][fF]%]"

function GM.HasSwitchToken(text)
    return tostring(text or ""):find(SWITCH_TOKEN) ~= nil
end

function GM.ApplySwitchToken(text, on)
    return (tostring(text or ""):gsub(SWITCH_TOKEN, on and "on" or "off"))
end

--- Analyse complète d'une macro, sans rien envoyer (variables non
--- remplacées : la cible du moment n'est pas connue à l'édition).
function GM.CheckMacro(text)
    local report, worst = {}, "ok"
    local lines = GM.MacroLines(text)
    if #lines == 0 then return report, "empty" end
    for i, line in ipairs(lines) do
        local res = GM.ResolveLine(GM.ApplySwitchToken(line, true))
        report[i] = res
        if res.status == "error" then worst = "error"
        elseif res.status == "warn" and worst == "ok" then worst = "warn" end
    end
    if #lines > MACRO_LINES_MAX then worst = "error" end
    return report, worst
end

--- Exécute une macro technique. Renvoie ok, message.
function GM:RunMacro(text)
    local lines = GM.MacroLines(text)
    if #lines == 0 then return false, "Case vide" end
    if #lines > MACRO_LINES_MAX then
        self.lastError = "Macro trop longue : " .. MACRO_LINES_MAX .. " lignes au plus"
        self.Notify()
        return false, self.lastError
    end
    local cmds = {}
    for i, line in ipairs(lines) do
        local expanded, err = GM.ExpandVariables(line)
        if not expanded then
            self.lastError = err; self.Notify()
            return false, err
        end
        local res = GM.ResolveLine(expanded)
        if res.status == "error" then
            self.lastError = res.problem; self.Notify()
            return false, res.problem
        end
        cmds[i] = res.short
    end
    self.lastError = nil
    self:Emit(cmds)
    return true, self.lastCommand
end

-- ── Recettes de case ──────────────────────────────────────────────────────
-- Une recette = un type de case tout prêt : on choisit « Aura de PNJ »,
-- on tape l'ID, et la case se construit (commandes, libellé, icône).
-- Les modèles utilisent les mots complets ; l'envoi les abrège.
--   fields : id (entier), number, text, ou pick (liste de boutons ; une
--            option peut porter ses propres cmds / second / mode).
--   mode   : simple | toggle | alt (second = désactivation ou Alt + clic).
-- Toutes les commandes sont vérifiées par le test contre la doc EpsilonLib.

local SPELL = { key = "id", label = "ID du sort", kind = "id", spell = true }

GM.SlotRecipes = {
    { key = "npcaura", title = "Aura de PNJ",
      desc = "Clic : pose l'aura sur le PNJ ciblé (permanente). Alt + clic : la retire.",
      fields = { SPELL }, mode = "alt",
      cmds = "npc set aura {id}", second = "npc set unaura {id}", label = "{spell}" },
    { key = "selfaura", title = "Aura sur moi",
      desc = "Interrupteur : pose l'aura sur vous, ou la retire si vous l'avez déjà.",
      fields = { SPELL }, mode = "toggle",
      cmds = "aura {id} self", second = "unaura {id} self", label = "{spell}" },
    { key = "targetaura", title = "Aura sur ma cible",
      desc = "Clic : pose l'aura sur votre cible. Alt + clic : la retire.",
      fields = { SPELL }, mode = "alt",
      cmds = "aura {id}", second = "unaura {id}", label = "{spell}" },
    { key = "cast", title = "Lancer un sort",
      desc = "Lance le sort sur votre cible (sur vous sans cible).",
      fields = { SPELL }, cmds = "cast {id}", label = "{spell}" },
    { key = "speed", title = "Vitesse",
      desc = "Fixe votre vitesse (1 = normale).",
      fields = { { key = "value", label = "Vitesse", kind = "number", default = "20" } },
      cmds = "modify speed {value}", label = "Vitesse {value}" },
    { key = "scale", title = "Taille",
      desc = "Fixe votre taille, ou celle de la cible (1 = normale).",
      fields = { { key = "value", label = "Taille", kind = "number", default = "1" } },
      cmds = "modify scale {value}", label = "Taille {value}" },
    { key = "cheat", title = "Triche on / off",
      desc = "Interrupteur : l'état réel est lu sur le serveur (EpsilonLib).",
      fields = { { key = "cheat", label = "Triche", kind = "pick", options = {
          { value = "fly",       label = "Vol" },
          { value = "god",       label = "Invulnérable" },
          { value = "cooldown",  label = "Sans recharge" },
          { value = "casttime",  label = "Sort instant" },
          { value = "power",     label = "Sans coût" },
          { value = "duration",  label = "Auras infinies" },
          { value = "waterwalk", label = "Marche sur l'eau" },
      } } },
      mode = "toggle", cmds = "cheat {cheat} [on/off]", label = "{pick}" },
    { key = "morph", title = "Morph",
      desc = "Clic : prendre l'apparence. Alt + clic : démorpher.",
      fields = { { key = "id", label = "ID d'affichage", kind = "id" } }, mode = "alt",
      cmds = "morph {id}", second = "demorph", label = "Morph {id}" },
    { key = "npcemote", title = "Émote de PNJ",
      desc = "Clic : le PNJ ciblé joue l'émote. Alt + clic : l'arrête.",
      fields = { { key = "id", label = "ID d'émote", kind = "id" } }, mode = "alt",
      cmds = "npc emote {id}", second = "npc emote 0", label = "Émote {id}" },
    { key = "npcspawn", title = "Faire apparaître un PNJ",
      desc = "Fait apparaître la créature devant vous.",
      fields = { { key = "id", label = "ID créature", kind = "id" } },
      cmds = "npc spawn {id}", label = "PNJ {id}" },
    { key = "gobspawn", title = "Poser un objet",
      desc = "Pose l'objet de décor à votre position.",
      fields = { { key = "id", label = "ID objet", kind = "id" } },
      cmds = "gobject spawn {id}", label = "Objet {id}" },
    { key = "tele", title = "Téléportation",
      desc = "Vous téléporte au lieu indiqué.",
      fields = { { key = "text", label = "Lieu", kind = "text" } },
      cmds = "tele {text}", label = "{text}" },
    { key = "npc", title = "PNJ ciblé",
      desc = "Une action sur le PNJ ciblé, sans rien taper.",
      fields = { { key = "act", label = "Action", kind = "pick", options = {
          { value = "info",      label = "Infos",       cmds = "npc info" },
          { value = "move",      label = "Amener ici",  cmds = "npc move" },
          { value = "turn",      label = "Vers moi",    cmds = "npc turn here" },
          { value = "follow",    label = "Me suit",     cmds = "npc follow", second = "npc follow stop", mode = "alt" },
          { value = "delete",    label = "Supprimer",   cmds = "npc delete" },
          { value = "near",      label = "PNJ proches", cmds = "npc near 20" },
          { value = "stopemote", label = "Stop émote",  cmds = "npc emote 0" },
      } } } },
    { key = "forge", title = "Forge (.ph f n)",
      desc = "Une action de forge sur le PNJ forgé ciblé.",
      fields = { { key = "act", label = "Action", kind = "pick", options = {
          { value = "create",   label = "Forger",      cmds = "phase forge npc create" },
          { value = "copy",     label = "Dupliquer",   cmds = "phase forge npc copy" },
          { value = "list",     label = "Mes forgés",  cmds = "phase forge npc list" },
          { value = "click",    label = "Cliquable",   cmds = "phase forge npc clickable on", second = "phase forge npc clickable off", mode = "alt" },
          { value = "blue",     label = "Nom bleu",    cmds = "phase forge npc fakeplayer on", second = "phase forge npc fakeplayer off", mode = "alt" },
          { value = "gossip",   label = "Dialogue",    cmds = "phase forge npc gossip enable", second = "phase forge npc gossip disable", mode = "alt" },
          { value = "debug",    label = "Débogage",    cmds = "phase forge npc gossip debug" },
          { value = "outfit",   label = "Tenue +",     cmds = "phase forge npc outfit add" },
          { value = "strip",    label = "Déshabiller", cmds = "phase forge npc outfit unequip all" },
          { value = "displays", label = "Displays",    cmds = "phase forge npc displays list" },
      } } } },
    { key = "phase", title = "Phase et lieux",
      desc = "Mode MJ, sortie de phase, position, joueurs.",
      fields = { { key = "act", label = "Action", kind = "pick", options = {
          { value = "dm",     label = "Mode MJ",     cmds = "phase dm [on/off]", mode = "toggle" },
          { value = "exit",   label = "Quitter",     cmds = "phase exit" },
          { value = "gps",    label = "Ma position", cmds = "gps" },
          { value = "appear", label = "Rejoindre",   cmds = "appear {cible}" },
          { value = "summon", label = "Invoquer",    cmds = "summon {cible}" },
          { value = "normal", label = "Tout normal", cmds = "modify scale 1\nmodify speed 1\ndemorph" },
          { value = "combat", label = "Fin combat",  cmds = "combatstop" },
      } } } },
    { key = "free", title = "Commande libre", free = true,
      desc = "Écrire soi-même une ou plusieurs commandes." },
}

GM.RecipeByKey = {}
for _, recipe in ipairs(GM.SlotRecipes) do
    GM.RecipeByKey[recipe.key] = recipe
    recipe.fields = recipe.fields or {}
end

--- Construit une case à partir d'une recette et des valeurs saisies.
--- Renvoie { mode, cmds, second, label, icon } ou nil + message.
function GM.BuildRecipe(recipe, values)
    values = values or {}
    local subs, out = {}, { mode = recipe.mode or "simple" }
    local cmds, second = recipe.cmds, recipe.second
    for _, f in ipairs(recipe.fields) do
        local v = Trim(values[f.key] or f.default or "")
        if f.kind == "pick" then
            local opt
            for _, o in ipairs(f.options) do if o.value == v then opt = o end end
            if not opt then return nil, "Choisir : " .. f.label end
            subs.pick = opt.label
            if opt.cmds then
                cmds, second, out.mode = opt.cmds, opt.second, opt.mode or "simple"
            end
        elseif v == "" then
            return nil, "Renseigner : " .. f.label
        elseif f.kind == "id" and not v:match("^%d+$") then
            return nil, f.label .. " : nombre entier attendu"
        elseif f.kind == "number" and not tonumber(v) then
            return nil, f.label .. " : nombre attendu"
        end
        subs[f.key] = v
        if f.spell then
            local name, icon = GM.SpellInfo(v)
            subs.spell = name or ("Sort " .. v)
            out.icon = icon and tostring(icon) or nil
        end
    end
    local function Fill(t)
        return t and (t:gsub("{(%w+)}", function(k) return subs[k] end)) or nil
    end
    out.cmds, out.second = Fill(cmds), Fill(second)
    out.label = GM.Utf8Cut(Fill(recipe.label or "{pick}") or recipe.title, 24)
    return out
end

--- Options de SetSlot correspondant au résultat d'une recette.
function GM.RecipeSlotOptions(recipe, values, built)
    local params = {}
    for _, f in ipairs(recipe.fields) do params[f.key] = Trim(values[f.key] or f.default or "") end
    return { mode = built.mode, cmdsOff = built.second, cmdsAlt = built.second,
             recipe = recipe.key, params = params }
end

-- ── Barre ─────────────────────────────────────────────────────────────────

GM.BAR_LIMITS = {
    cols = { 1, 24 }, rows = { 1, 12 }, size = { 24, 72 }, gap = { 0, 12 },
}

local DEFAULT_SLOTS = {
    { label = "Vitesse 1",  cmds = "mod speed 1" },
    { label = "Vitesse 20", cmds = "mod speed 20" },
    { label = "Vitesse 50", cmds = "mod speed 50" },
    { label = "Vol",        cmds = "cheat fly [on/off]" },
    { label = "Invulnérable", cmds = "cheat god [on/off]" },
    { label = "Normal",     cmds = "mod scale 1\nmod speed 1\ndemorph" },
}

function GM.EnsureBar()
    local db = GM.EnsureDB()
    if not db.bar then
        db.bar = { cols = 6, rows = 2, size = 40, gap = 4, shown = true, locked = false,
                   labels = true, slots = {} }
        for i, slot in ipairs(DEFAULT_SLOTS) do
            db.bar.slots[i] = { label = slot.label, cmds = slot.cmds }
        end
    end
    local bar = db.bar
    bar.slots = bar.slots or {}
    for i, slot in pairs(bar.slots) do
        if GM.IsSwitch(slot) and not slot.id then slot.id = "slot" .. i .. "-" .. math.random(100000, 999999) end
    end
    for key, lim in pairs(GM.BAR_LIMITS) do
        bar[key] = math.max(lim[1], math.min(lim[2], math.floor(tonumber(bar[key]) or lim[1])))
    end
    return bar
end

function GM:GetSlot(i) return self.EnsureBar().slots[i] end

local function TrimBlock(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

--- Types de case :
---   simple : le clic envoie les commandes ;
---   toggle : interrupteur on / off (opts.cmdsOff, ou [on/off] dans les lignes) ;
---   alt    : clic = commandes, Alt + clic = opts.cmdsAlt (poser / retirer).
GM.SLOT_MODES = { "simple", "toggle", "alt" }
GM.SLOT_MODE_LABELS = { simple = "Simple", toggle = "Interrupteur on / off", alt = "Clic / Alt + clic" }

function GM.SlotMode(slot)
    if not slot then return "simple" end
    if slot.toggle or GM.HasSwitchToken(slot.cmds) then return "toggle" end
    if slot.cmdsAlt then return "alt" end
    return "simple"
end

function GM:SetSlot(i, label, cmds, icon, opts)
    local bar = self.EnsureBar()
    label, cmds, icon = Trim(label), TrimBlock(cmds), Trim(icon)
    opts = opts or {}
    if cmds == "" then
        bar.slots[i] = nil
    else
        local old = bar.slots[i]
        local slot = { label = label ~= "" and label or nil, cmds = cmds, icon = icon ~= "" and icon or nil }
        local mode = opts.mode or (opts.toggle and "toggle") or "simple"
        if GM.HasSwitchToken(cmds) then mode = "toggle" end
        if mode == "toggle" then
            local off = TrimBlock(opts.cmdsOff)
            slot.toggle = true
            slot.cmdsOff = off ~= "" and off or nil
            slot.id = old and old.id or (tostring(time and time() or 0) .. "-" .. math.random(100000, 999999))
        elseif mode == "alt" then
            local alt = TrimBlock(opts.cmdsAlt)
            slot.cmdsAlt = alt ~= "" and alt or nil
        end
        if opts.recipe and GM.RecipeByKey[opts.recipe] then
            slot.recipe = opts.recipe
            slot.params = {}
            for k, v in pairs(opts.params or {}) do slot.params[k] = v end
        end
        bar.slots[i] = slot
    end
    self.Notify()
end

-- ── État d'un interrupteur ────────────────────────────────────────────────

function GM.IsSwitch(slot)
    return slot ~= nil and (slot.toggle or GM.HasSwitchToken(slot.cmds)) and true or false
end

--- Commandes qui mènent à l'état voulu (on = true : activer).
function GM.SwitchCommands(slot, on)
    if not on and slot.cmdsOff and slot.cmdsOff ~= "" then return slot.cmdsOff end
    return GM.ApplySwitchToken(slot.cmds, on)
end

local function SwitchMemory()
    local db = GM.EnsureCharDB()
    db.switches = db.switches or {}
    return db.switches
end

--- Seconde partie manquante selon le type de case (nil si tout va bien).
function GM.SlotModeProblem(mode, cmds, second)
    if mode == "toggle" and not GM.HasSwitchToken(cmds) and TrimBlock(second) == "" then
        return "Interrupteur : écrire [on/off] dans une ligne, ou les commandes pour désactiver"
    elseif mode == "alt" and TrimBlock(second) == "" then
        return "Écrire les commandes envoyées avec Alt + clic"
    end
end

--- État actuel : true (activé) / false, et sa source :
---   "server" : triche suivie par EpsilonLib (réponses du serveur) ;
---   "aura"   : « aura <id> self », lue sur vos auras ;
---   "memory" : dernier état envoyé par cette case, pour ce personnage.
function GM:SwitchState(slot)
    local first = GM.MacroLines(GM.ApplySwitchToken(slot.cmds, true))[1]
    if first then
        local res = GM.ResolveLine(first)
        local cheat = EpsilonLib and EpsilonLib.Cheat
        if res.path[1] == "cheat" and res.path[2] and cheat and cheat.GetCheatStatus then
            local state = cheat.GetCheatStatus(res.path[2])
            if type(state) == "boolean" then return state, "server" end
        end
        local spell = tonumber(res.args[1])
        if res.full and res.path[1] == "aura" and #res.path == 1 and spell
            and (res.args[2] or ""):lower() == "self"
            and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            return C_UnitAuras.GetPlayerAuraBySpellID(spell) ~= nil, "aura"
        end
    end
    return SwitchMemory()[slot.id or ""] == true, "memory"
end

GM.SWITCH_SOURCES = {
    server = "d'après le serveur (EpsilonLib)",
    aura   = "d'après vos auras",
    memory = "dernier état envoyé par cette case",
}

--- Bascule : envoie les commandes de l'état inverse.
function GM:RunSwitch(slot)
    local on = self:SwitchState(slot)
    local ok, msg = self:RunMacro(GM.SwitchCommands(slot, not on))
    if ok and slot.id then SwitchMemory()[slot.id] = not on end
    if ok then self.Notify() end
    return ok, msg
end

function GM:SwapSlots(a, b)
    local slots = self.EnsureBar().slots
    slots[a], slots[b] = slots[b], slots[a]
    self.Notify()
end

--- Première case vide visible (ou au-delà si la barre est pleine).
function GM:FirstFreeSlot()
    local bar = self.EnsureBar()
    for i = 1, bar.cols * bar.rows do
        if not bar.slots[i] then return i end
    end
end

--- Libellé affiché : le nom choisi, sinon la première commande.
function GM.SlotLabel(slot)
    if not slot then return "" end
    if slot.label then return slot.label end
    return (GM.MacroLines(slot.cmds)[1] or "")
end

--- alt = true : Alt était enfoncée au clic.
function GM:RunSlot(i, alt)
    local slot = self:GetSlot(i)
    if not slot then return false, "Case vide" end
    if GM.IsSwitch(slot) then return self:RunSwitch(slot) end
    if alt and slot.cmdsAlt then return self:RunMacro(slot.cmdsAlt) end
    return self:RunMacro(slot.cmds)
end

function GM:SetBarOption(key, value)
    local bar = self.EnsureBar()
    bar[key] = value
    self.EnsureBar()
    self.Notify()
end

function GM:ToggleBar(show)
    local bar = self.EnsureBar()
    if show == nil then show = not bar.shown end
    bar.shown = show and true or false
    if GMMasterBar then GMMasterBar:SetShown(self.enabled and bar.shown) end
end

-- ── Banque d'auras ────────────────────────────────────────────────────────
-- Auras favorites, chacune avec sa cible : vous, votre cible, ou le PNJ
-- ciblé (aura permanente de PNJ). Chaque aura peut devenir une case :
--   sur moi        : interrupteur (l'état est lu sur vos auras) ;
--   cible / PNJ    : clic = poser, Alt + clic = retirer.

GM.AURA_TARGETS = {
    { value = "self",   label = "Moi" },
    { value = "target", label = "Ma cible" },
    { value = "npc",    label = "PNJ ciblé" },
}
local AURA_CMDS = {
    self   = { on = "aura %d self",     off = "unaura %d self" },
    target = { on = "aura %d",          off = "unaura %d" },
    npc    = { on = "npc set aura %d",  off = "npc set unaura %d" },
}
local AURA_BANK_MAX = 200

--- Coupe une chaîne UTF-8 sans couper un caractère.
function GM.Utf8Cut(s, max)
    s = tostring(s or "")
    if #s <= max then return s end
    s = s:sub(1, max)
    -- retire un caractère multioctet incomplet en fin de chaîne
    local i = #s
    while i > 0 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do i = i - 1 end
    if i > 0 and s:byte(i) >= 0xC0 then
        local need = s:byte(i) >= 0xF0 and 4 or s:byte(i) >= 0xE0 and 3 or 2
        if #s - i + 1 < need then s = s:sub(1, i - 1) end
    end
    return s
end

function GM.EnsureAuraBank()
    local db = GM.EnsureDB()
    db.auraBank = db.auraBank or {}
    return db.auraBank
end

function GM:FindAura(id)
    for i, entry in ipairs(GM.EnsureAuraBank()) do
        if entry.id == id then return i, entry end
    end
end

--- Ajoute une aura en tête de la banque. Renvoie ok, message.
function GM:AddAura(id, who, note)
    id = tonumber(Trim(id))
    if not id or id <= 0 or id % 1 ~= 0 then return false, "ID de sort : nombre entier attendu" end
    if self:FindAura(id) then return false, "Déjà dans la banque : " .. id end
    local bank = GM.EnsureAuraBank()
    if #bank >= AURA_BANK_MAX then return false, "Banque pleine (" .. AURA_BANK_MAX .. ")" end
    note = Trim(note)
    table.insert(bank, 1, { id = id, who = AURA_CMDS[who] and who or "self", note = note ~= "" and note or nil })
    self.Notify()
    return true
end

function GM:RemoveAura(index)
    table.remove(GM.EnsureAuraBank(), index)
    self.Notify()
end

function GM:CycleAuraTarget(entry)
    for i, t in ipairs(GM.AURA_TARGETS) do
        if t.value == entry.who then
            entry.who = GM.AURA_TARGETS[i % #GM.AURA_TARGETS + 1].value
            break
        end
    end
    self.Notify()
end

function GM.AuraTargetLabel(who)
    for _, t in ipairs(GM.AURA_TARGETS) do if t.value == who then return t.label end end
    return "?"
end

--- Commandes de pose et de retrait d'une entrée.
function GM.AuraCommands(entry)
    local c = AURA_CMDS[entry.who] or AURA_CMDS.self
    return c.on:format(entry.id), c.off:format(entry.id)
end

--- Nom affiché : la note, sinon le nom du sort, sinon l'ID.
function GM.AuraLabel(entry)
    if entry.note then return entry.note end
    local name = GM.SpellInfo and GM.SpellInfo(entry.id)
    return name or ("Aura " .. entry.id)
end

function GM:ApplyAura(entry, remove)
    local on, off = GM.AuraCommands(entry)
    return self:RunMacro(remove and off or on)
end

--- Crée une case de la barre pour cette aura. Renvoie l'index de la case.
local AURA_RECIPES = { self = "selfaura", target = "targetaura", npc = "npcaura" }

function GM:AuraToBar(entry)
    local recipe = GM.RecipeByKey[AURA_RECIPES[entry.who] or "selfaura"]
    local values = { id = tostring(entry.id) }
    local built = GM.BuildRecipe(recipe, values)
    local label = GM.Utf8Cut(GM.AuraLabel(entry), 24)
    return self:AddToBar(label, built.cmds, built.icon, GM.RecipeSlotOptions(recipe, values, built))
end

-- Raccourcis clavier des 12 premières cases (Bindings.xml).
for i = 1, 12 do
    _G["BINDING_NAME_OMEGA_GMMASTER_SLOT" .. i] = "GM Master : case " .. i .. " de la barre"
end
