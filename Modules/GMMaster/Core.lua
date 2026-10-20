-- ============================================================
--  GM Master — Core
--  Construction des commandes à partir du catalogue (Commands.lua),
--  envoi, historique et favoris des valeurs saisies, suivi de ce qui
--  a été appliqué (auras) pour pouvoir le retirer en un clic.
-- ============================================================

GMMaster = GMMaster or {}
local GM = GMMaster

local HISTORY_MAX   = 12
local FAVORITES_MAX = 24

BINDING_NAME_OMEGA_GMMASTER_TOGGLE = "Ouvrir / fermer GM Master"

-- ── Sauvegardes ───────────────────────────────────────────────────────────
-- GMMasterDB (compte)        : historique, favoris, valeurs saisies, réglages.
-- GMMasterCharDB (personnage): ce qui a été appliqué via le tracker.

local function EnsureDB()
    GMMasterDB = GMMasterDB or {}
    local db = GMMasterDB
    db.history   = db.history   or {}
    db.favorites = db.favorites or {}
    db.values    = db.values    or {}
    db.prepare = nil   -- ancien mode « préparer dans le chat », retiré
    return db
end

local function EnsureCharDB()
    GMMasterCharDB = GMMasterCharDB or {}
    GMMasterCharDB.tracked = GMMasterCharDB.tracked or {}
    return GMMasterCharDB
end

GM.EnsureDB, GM.EnsureCharDB = EnsureDB, EnsureCharDB

local function Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end
GM.Trim = Trim

-- ── Valeurs saisies (persistées par domaine) ──────────────────────────────

function GM:GetValues(domain)
    local db = EnsureDB()
    local values = db.values[domain.key]
    if not values then
        values = {}
        for _, field in ipairs(domain.fields) do
            if field.default ~= nil then values[field.key] = field.default end
            if field.kind == "choice" then values[field.key] = field.options[1].value end
        end
        db.values[domain.key] = values
    end
    return values
end

function GM:SetValue(domain, fieldKey, value)
    self:GetValues(domain)[fieldKey] = value
end

-- ── Construction ──────────────────────────────────────────────────────────

local function Validate(field, value)
    if field.kind == "choice" then
        -- Facultatif seulement si une des options est vide (ex. « Ma cible »).
        for _, opt in ipairs(field.options) do
            if opt.value == value then return true end
        end
        return false, "Choisir : " .. field.label
    end
    if value == "" then return false, "Renseigner : " .. field.label end
    if field.kind == "id" and not value:match("^%d+$") then
        return false, field.label .. " : nombre entier attendu"
    end
    if field.kind == "number" and not tonumber(value) then
        return false, field.label .. " : nombre attendu"
    end
    return true
end

local MAX_LENGTH = 255   -- limite d'une ligne de chat, point compris

--- Raccourcit les mots de commande avec l'arbre généré depuis EpsilonLib
--- (Abbrev.generated.lua) : « phase forge npc gossip » → « ph f n g ».
--- words[i].cmd indique si le mot peut être un mot de commande (texte du
--- modèle ou valeur d'un champ choice) ; on s'arrête au premier argument
--- saisi, pour ne jamais abréger un nom ou une réplique.
--- Renvoie les mots raccourcis et true si la commande existe sur le serveur.
local function Shorten(words)
    local level, node = GM.CommandTree, nil
    if not level then return words, true end
    for _, word in ipairs(words) do
        local child = word.cmd and level and level[word.text:lower()]
        if not child then break end
        word.text = child.s
        node, level = child, child.sub
    end
    return words, node ~= nil and node.run == true
end
GM.Shorten = Shorten

--- Remplace {clé} par sa valeur. Les clés qui ne sont pas des champs du
--- domaine (ex. {target}) sont facultatives. Renvoie la commande abrégée
--- sans le point initial, ou nil + message d'erreur ; en troisième valeur,
--- false si la commande est absente de la liste du serveur.
function GM.Build(domain, template, values)
    local words = {}
    for token in template:gmatch("%S+") do
        local key = token:match("^{(%w+)}$")
        if key then
            local value = Trim(values[key])
            local field = domain.fieldByKey[key]
            if field then
                local ok, msg = Validate(field, value)
                if not ok then return nil, msg end
            end
            for word in value:gmatch("%S+") do
                words[#words + 1] = { text = word, cmd = field ~= nil and field.kind == "choice" }
            end
        else
            words[#words + 1] = { text = token, cmd = true }
        end
    end
    local _, known = Shorten(words)
    local parts = {}
    for i, word in ipairs(words) do parts[i] = word.text end
    local cmd = table.concat(parts, " ")
    if #cmd + 1 > MAX_LENGTH then
        return nil, "Commande trop longue : " .. (#cmd + 1) .. " / " .. MAX_LENGTH .. " caractères"
    end
    return cmd, nil, known
end

function GM.TemplateKeys(template)
    local keys = {}
    for key in template:gmatch("{(%w+)}") do keys[#keys + 1] = key end
    return keys
end

-- ── Envoi ─────────────────────────────────────────────────────────────────
-- Comme SpellCreator et EpsilonLib : SendChatMessage(".commande", "GUILD").
-- Le serveur intercepte toute ligne commençant par un point avant de la
-- traiter comme un message, le canal n'est donc jamais diffusé. La
-- fonction globale passe en priorité : EpsilonLib la remplace pour
-- journaliser les commandes, C_ChatInfo la contournerait.

function GM.SendRaw(text)
    local send = SendChatMessage or (C_ChatInfo and C_ChatInfo.SendChatMessage)
    send(text, "GUILD")
end

-- ── Historique et favoris ─────────────────────────────────────────────────

local function ListKey(domain, field) return domain.key .. "." .. field.key end

local function RemoveFrom(list, value)
    for i = #list, 1, -1 do
        if list[i] == value then table.remove(list, i) end
    end
end

function GM:GetHistory(domain, field)
    local db = EnsureDB()
    db.history[ListKey(domain, field)] = db.history[ListKey(domain, field)] or {}
    return db.history[ListKey(domain, field)]
end

function GM:GetFavorites(domain, field)
    local db = EnsureDB()
    db.favorites[ListKey(domain, field)] = db.favorites[ListKey(domain, field)] or {}
    return db.favorites[ListKey(domain, field)]
end

function GM:PushHistory(domain, field, value)
    value = Trim(value)
    if value == "" then return end
    local list = self:GetHistory(domain, field)
    RemoveFrom(list, value)
    table.insert(list, 1, value)
    while #list > HISTORY_MAX do table.remove(list) end
end

function GM:RemoveHistory(domain, field, value)
    RemoveFrom(self:GetHistory(domain, field), value)
end

function GM:IsFavorite(domain, field, value)
    for _, v in ipairs(self:GetFavorites(domain, field)) do
        if v == value then return true end
    end
    return false
end

function GM:ToggleFavorite(domain, field, value)
    value = Trim(value)
    if value == "" then return end
    local list = self:GetFavorites(domain, field)
    if self:IsFavorite(domain, field, value) then
        RemoveFrom(list, value)
    elseif #list < FAVORITES_MAX then
        table.insert(list, value)
    end
end

--- Favoris d'abord (dans l'ordre d'ajout), puis l'historique récent.
function GM:GetChips(domain, field)
    local chips, seen = {}, {}
    for _, v in ipairs(self:GetFavorites(domain, field)) do
        chips[#chips + 1] = { value = v, favorite = true }; seen[v] = true
    end
    for _, v in ipairs(self:GetHistory(domain, field)) do
        if not seen[v] then chips[#chips + 1] = { value = v } end
    end
    return chips
end

-- ── Noms de sorts ─────────────────────────────────────────────────────────

function GM.SpellInfo(id)
    id = tonumber(id)
    if not id then return nil end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        if info then return info.name, info.iconID end
    elseif GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return name, icon
    end
end

-- ── Tracker (ce qui a été appliqué) ───────────────────────────────────────

local function CurrentTarget()
    if not UnitExists or not UnitExists("target") then return "" end
    if UnitIsUnit and UnitIsUnit("target", "player") then return "" end
    return UnitName("target") or ""
end

local function TrackerValues(domain, values)
    local snapshot = {}
    for _, key in ipairs(GM.TemplateKeys(domain.tracker.key)) do
        snapshot[key] = Trim(values[key])
    end
    -- Une aura posée sur soi ne dépend pas de la cible du moment.
    if snapshot.who == "self" then snapshot.target = "" end
    return snapshot
end

function GM:GetTracked(domain)
    local db = EnsureCharDB()
    db.tracked[domain.key] = db.tracked[domain.key] or {}
    return db.tracked[domain.key]
end

local function TrackerKey(domain, values)
    return (domain.tracker.key:gsub("{(%w+)}", function(k) return values[k] or "" end))
end

function GM:FindTracked(domain, values)
    local key = TrackerKey(domain, TrackerValues(domain, values))
    for i, entry in ipairs(self:GetTracked(domain)) do
        if entry.key == key then return i, entry end
    end
end

function GM:TrackAdd(domain, values)
    if self:FindTracked(domain, values) then return end
    local snapshot = TrackerValues(domain, values)
    table.insert(self:GetTracked(domain), 1, { key = TrackerKey(domain, snapshot), values = snapshot })
end

function GM:TrackRemove(domain, values)
    local i = self:FindTracked(domain, values)
    if i then table.remove(self:GetTracked(domain), i) end
end

--- « Tout retirer » vise la cible du moment, ou soi-même sans cible.
function GM:TrackClear(domain, target)
    local list = self:GetTracked(domain)
    for i = #list, 1, -1 do
        if (list[i].values.target or "") == target then table.remove(list, i) end
    end
end

--- Libellé lisible d'une entrée : nom du sort, cible.
function GM:TrackedLabel(domain, entry)
    local v = entry.values
    local name = self.SpellInfo(v.id)
    local text = name and (name .. "  |cff888888" .. v.id .. "|r") or ("ID " .. (v.id or "?"))
    local who
    if v.target and v.target ~= "" then who = v.target
    elseif domain.fieldByKey.who then who = "moi"
    else who = "sans cible" end
    return text .. "  |cffAAAAAAsur " .. who .. "|r"
end

--- Retire une entrée : renvoie la commande inverse puis l'oublie.
function GM:UntrackEntry(domain, index)
    local entry = self:GetTracked(domain)[index]
    if not entry then return end
    local cmd, err = self.Build(domain, domain.tracker.off, entry.values)
    if not cmd then return false, err end
    self:Emit({ cmd })
    table.remove(self:GetTracked(domain), index)
    return true, cmd
end

-- ── Exécution d'une action ────────────────────────────────────────────────

GM.listeners = {}
function GM:OnChange(fn) self.listeners[#self.listeners + 1] = fn end
local function Notify() for _, fn in ipairs(GM.listeners) do fn() end end
GM.Notify = Notify

--- Envoie une liste de commandes déjà construites.
function GM:Emit(cmds)
    local texts = {}
    for i, cmd in ipairs(cmds) do
        texts[i] = "." .. cmd
        self.SendRaw(texts[i])
    end
    self.lastCommand = table.concat(texts, "  ·  ")
    Notify()
end

--- Exécute une action du catalogue avec les valeurs saisies.
--- Renvoie ok, texte (ou message d'erreur).
function GM:RunAction(domain, action, values)
    values = values or self:GetValues(domain)
    local templates = type(action.cmd) == "table" and action.cmd or { action.cmd }
    local track = action.track

    local scratch = setmetatable({ target = CurrentTarget() }, { __index = values })

    if action.toggle and domain.tracker then
        if self:FindTracked(domain, scratch) then
            templates, track = { action.toggle }, "remove"
        else
            track = "add"
        end
    end

    local cmds = {}
    for i, template in ipairs(templates) do
        local cmd, err = self.Build(domain, template, scratch)
        if not cmd then
            self.lastError = err
            Notify()
            return false, err
        end
        cmds[i] = cmd
    end
    self.lastError = nil

    -- Historique : chaque champ utilisé par l'action.
    for _, template in ipairs(templates) do
        for _, key in ipairs(self.TemplateKeys(template)) do
            local field = domain.fieldByKey[key]
            if field and field.history then self:PushHistory(domain, field, values[key]) end
        end
    end

    if domain.tracker then
        local snapshot = {}
        for _, key in ipairs(self.TemplateKeys(domain.tracker.key)) do snapshot[key] = scratch[key] end
        if track == "add" then self:TrackAdd(domain, snapshot)
        elseif track == "remove" then self:TrackRemove(domain, snapshot)
        elseif track == "clear" then self:TrackClear(domain, scratch.target) end
    end

    self:Emit(cmds)
    return true, self.lastCommand
end

-- ── Enable / Disable ──────────────────────────────────────────────────────

function GM:Toggle()
    if not self.enabled then return end
    if GMMasterPanel then GMMasterPanel:Toggle() end
end

function GM:Enable()
    self.enabled = true
    SLASH_OMEGAGMMASTER1 = "/gmm"
    SLASH_OMEGAGMMASTER2 = "/gmmaster"
    SlashCmdList["OMEGAGMMASTER"] = function() GM:Toggle() end

    OmegaHub:SetModuleLoaded("GMMaster", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("GM Master activé.  |cffAAAAAA/gmm|r")
    end
end

function GM:Disable()
    self.enabled = false
    SLASH_OMEGAGMMASTER1 = nil
    SLASH_OMEGAGMMASTER2 = nil
    SlashCmdList["OMEGAGMMASTER"] = nil
    if GMMasterPanel then GMMasterPanel:Hide() end

    OmegaHub:SetModuleLoaded("GMMaster", false)
    OmegaHub.Print("GM Master désactivé.")
end

-- ── Init ──────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({
        name    = "GMMaster",
        title   = "GM Master",
        desc    = "Commandes MJ en quelques clics — /gmm",
        version = GMMASTER_VERSION,
        module  = GM,
    })
    EnsureDB()
    EnsureCharDB()
    if OmegaHub:IsModuleEnabled("GMMaster") then GM:Enable() end
    f:UnregisterAllEvents()
end)
