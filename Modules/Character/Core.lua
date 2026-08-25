-- ============================================================
--  Character — Core
--  Fiches de personnage RP : HP / Mana / Endurance
--  Communication discrète via addon messages
-- ============================================================

Character = Character or {}
local C   = Character
_G.Character = C

C.name      = "Character"
C.groupData = {}  -- [playerName] => { nom, prenom, hp, mana, endurance }

local PREFIX     = "OmegaChar"
local TOKEN_STAT = "{CH:"
local TOKEN_CMD  = "{CHM:"
local TOKEN_REQ  = "{CHR}"
local SEP        = ":"
local broadcastFrame
local pendingBroadcast = false
local broadcastAt = 0

-- ── Helpers ──────────────────────────────────────────────────────────────────

local function MyName() return UnitName("player") or "" end

local function GroupChat()
    if IsInRaid  and IsInRaid()  then return "RAID"  end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function SendAddon(payload, channel, target)
    if not payload or payload == "" or not channel then return false end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(PREFIX, payload, channel, target)
    end
    if SendAddonMessage then
        return SendAddonMessage(PREFIX, payload, channel, target)
    end
    return false
end

local function IsGroupMember(name)
    if name == MyName() then return true end
    for i = 1, 4  do if UnitName("party"..i) == name then return true end end
    for i = 1, 40 do if UnitName("raid"..i)  == name then return true end end
    return false
end

local function UnitTokenForName(name)
    if not name or name == "" then return nil end
    if name == MyName() then return "player" end
    for i = 1, 4 do
        local token = "party" .. i
        if UnitName(token) == name then return token end
    end
    for i = 1, 40 do
        local token = "raid" .. i
        if UnitName(token) == name then return token end
    end
    return nil
end

function C:GetUnitTokenForName(name)
    return UnitTokenForName(name)
end

function C:TargetPlayer(name)
    -- Le ciblage est une action protégée Blizzard : il doit passer par
    -- SecureActionButtonTemplate côté UI, pas par un appel Lua direct.
    local token = UnitTokenForName(name)
    return false, token or "Ciblage sécurisé indisponible"
end

-- TRP3 concatène tel quel le contenu des champs Titre/Prénom/Nom (voir
-- TRP3_API.register.getCompleteName) : un joueur peut y taper des codes
-- couleurs bien formés (|cffRRGGBB...|r) pour un effet dégradé lettre par
-- lettre. Mais le getter "safe" qu'on utilise (getUnitIDCurrentProfileSafe)
-- assainit lui-même ce texte et bousille au passage les balises : le "|" et
-- un des deux "f" disparaissent, laissant un résidu du type "c fFFD300"
-- (espace parasite, 6 hexa au lieu de 8, sans pipe) directement collé à la
-- lettre suivante. Confirmé en comparant le texte source fourni par un
-- joueur avec ce que GetDisplayName renvoie réellement en jeu. On gère donc
-- les deux formes : la balise standard bien formée, et ce résidu assaini.
local function CleanDisplayName(name)
    name = tostring(name or "")
    -- Liens hypertexte RP (|Hxxx|htexte|h) : on garde le texte visible.
    -- Le "|" reste obligatoire ici (pattern trop générique sinon : "T...t"
    -- matcherait n'importe quel vrai nom contenant un T majuscule suivi
    -- plus loin d'un t minuscule, ex. "Tristan").
    name = name:gsub("|H.-|h(.-)|h", "%1")
    -- Textures / atlas embarqués (icônes) : aucun équivalent textuel, on retire
    name = name:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    -- 1) Code couleur standard bien formé : "|" optionnel + 8 hexa exacts
    name = name:gsub("|?c%x%x%x%x%x%x%x%x", "")
    -- 2) Résidu assaini par TRP3 : "|" et "f" optionnels, espace parasite
    -- optionnel, puis EXACTEMENT 6 hexa (pas de chiffre en plus : sinon ça
    -- mange la vraie lettre du nom quand elle vaut a-f, ex. le "d" de "Lydia")
    name = name:gsub("|?c ?f?%x%x%x%x%x%x", "")
    -- Couleurs nommées (cnNOM:), "|" optionnel
    name = name:gsub("|?cn[%w_]+:", "")
    -- Fermeture "|r" (uniquement avec le "|" : un simple "r" seul est trop
    -- courant dans un vrai nom pour le purger sans balise devant)
    name = name:gsub("|r", "")
    -- Filet de sécurité : toute pipe orpheline restante (code tronqué
    -- ou format non prévu) est purgée pour ne jamais laisser de markup brut
    name = name:gsub("|", "")
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" or name == UNKNOWN or name == UNKNOWNOBJECT then return nil end
    return name
end

local function GetTRP3Name(playerName)
    if not TRP3_API or not TRP3_API.register or not TRP3_API.utils or not TRP3_API.utils.str then return nil end
    local token = UnitTokenForName(playerName)
    if not token then return nil end

    local okID, unitID = pcall(TRP3_API.utils.str.getUnitID, token)
    if not okID or not unitID then return nil end

    local profile
    if TRP3_API.register.getUnitIDCurrentProfileSafe then
        local okProfile, data = pcall(TRP3_API.register.getUnitIDCurrentProfileSafe, unitID)
        if okProfile then profile = data end
    elseif TRP3_API.register.getUnitIDCurrentProfile then
        local okProfile, data = pcall(TRP3_API.register.getUnitIDCurrentProfile, unitID)
        if okProfile then profile = data end
    end

    local characteristics = profile and profile.characteristics
    if not characteristics then return nil end

    if TRP3_API.register.getCompleteName then
        local okName, rpName = pcall(TRP3_API.register.getCompleteName, characteristics, "", true)
        rpName = okName and CleanDisplayName(rpName)
        if rpName then return rpName end
    end

    local first = CleanDisplayName(characteristics.FN)
    local last  = CleanDisplayName(characteristics.LN)
    if first or last then return (first or "") .. (last and (" " .. last) or "") end
    return nil
end

function C:GetDisplayName(playerName, data)
    data = data or C.groupData[playerName]
    local trpName = GetTRP3Name(playerName)
    if trpName then return trpName end

    local first = data and CleanDisplayName(data.prenom)
    if first then return first end

    return "Profil en attente"
end

-- ── DB ───────────────────────────────────────────────────────────────────────

local function NewChar()
    return {
        nom = "", prenom = "",
        hp        = { cur = 100, max = 100, temp = 0 },
        mana      = { cur = 100, max = 100, temp = 0 },
        endurance = { cur = 100, max = 100, temp = 0 },
    }
end

local function NormalizeStat(s)
    s = s or {}
    s.cur = tonumber(s.cur) or 0
    s.max = math.max(1, tonumber(s.max) or 100)
    s.temp = math.max(0, math.floor(tonumber(s.temp) or 0))
    s.cur = math.max(0, math.min(s.cur, s.max))
    return s
end

local function NormalizeChar(ch)
    ch.hp = NormalizeStat(ch.hp)
    ch.mana = NormalizeStat(ch.mana)
    ch.endurance = NormalizeStat(ch.endurance)
    return ch
end

local function MyChar()
    CharacterDB.myChar = CharacterDB.myChar or NewChar()
    NormalizeChar(CharacterDB.myChar)
    return CharacterDB.myChar
end

function C:GetMyChar() return MyChar() end

function C:SetMeta(nom, prenom)
    local ch = MyChar()
    local changed = false
    if nom ~= nil and ch.nom ~= nom then ch.nom = nom; changed = true end
    if prenom ~= nil and ch.prenom ~= prenom then ch.prenom = prenom; changed = true end
    if not changed then return end
    C:Broadcast()
    if C.OnMyDataChanged then C.OnMyDataChanged() end
end

function C:Delta(stat, delta, broadcastNow)
    local s = MyChar()[stat]; if not s then return end
    NormalizeStat(s)
    delta = tonumber(delta) or 0
    local changed = false
    if delta < 0 and (s.temp or 0) > 0 then
        local loss = math.abs(delta)
        local absorbed = math.min(s.temp, loss)
        if absorbed > 0 then
            s.temp = s.temp - absorbed
            changed = true
        end
        loss = loss - absorbed
        if loss <= 0 then
            C:Broadcast(broadcastNow)
            if C.OnMyDataChanged then C.OnMyDataChanged() end
            return
        end
        delta = -loss
    end
    local nextValue = math.max(0, math.min(s.cur + delta, s.max))
    if s.cur == nextValue and not changed then return end
    s.cur = nextValue
    C:Broadcast(broadcastNow)
    if C.OnMyDataChanged then C.OnMyDataChanged() end
end

function C:SetCur(stat, val)
    local s = MyChar()[stat]; if not s then return end
    local nextValue = math.max(0, math.min(math.floor(tonumber(val) or 0), s.max))
    if s.cur == nextValue then return end
    s.cur = nextValue
    C:Broadcast()
    if C.OnMyDataChanged then C.OnMyDataChanged() end
end

function C:SetMax(stat, val)
    local s = MyChar()[stat]; if not s then return end
    local nextMax = math.max(1, math.floor(tonumber(val) or 1))
    if s.max == nextMax and s.cur <= nextMax then return end
    s.max = nextMax
    s.cur = math.min(s.cur, s.max)
    C:Broadcast()
    if C.OnMyDataChanged then C.OnMyDataChanged() end
end

function C:SetTemp(stat, val)
    local s = MyChar()[stat]; if not s then return end
    local nextValue = math.max(0, math.floor(tonumber(val) or 0))
    if s.temp == nextValue then return end
    s.temp = nextValue
    C:Broadcast()
    if C.OnMyDataChanged then C.OnMyDataChanged() end
end

function C:AddTemp(stat, amount, broadcastNow)
    local s = MyChar()[stat]; if not s then return end
    local delta = math.floor(tonumber(amount) or 0)
    if delta == 0 then return end
    local nextValue = math.max(0, (tonumber(s.temp) or 0) + delta)
    if s.temp == nextValue then return end
    s.temp = nextValue
    C:Broadcast(broadcastNow)
    if C.OnMyDataChanged then C.OnMyDataChanged() end
end

-- ── Serialisation ─────────────────────────────────────────────────────────────

local function Enc(s) return (tostring(s or ""):gsub("[:{}\r\n]", "_")) end

local function Pack(ch)
    NormalizeChar(ch)
    return Enc(ch.nom)..SEP..Enc(ch.prenom)..SEP..
           ch.hp.cur..SEP..ch.hp.max..SEP..(ch.hp.temp or 0)..SEP..
           ch.mana.cur..SEP..ch.mana.max..SEP..(ch.mana.temp or 0)..SEP..
           ch.endurance.cur..SEP..ch.endurance.max..SEP..(ch.endurance.temp or 0)
end

local function Unpack(payload, sender)
    local t = { strsplit(SEP, payload) }
    if #t < 8 then return end
    local e = C.groupData[sender] or NewChar()
    e.nom       = t[1] or ""
    e.prenom    = t[2] or ""
    if #t >= 11 then
        e.hp        = { cur = tonumber(t[3]) or 0, max = tonumber(t[4])  or 100, temp = tonumber(t[5]) or 0 }
        e.mana      = { cur = tonumber(t[6]) or 0, max = tonumber(t[7])  or 100, temp = tonumber(t[8]) or 0 }
        e.endurance = { cur = tonumber(t[9]) or 0, max = tonumber(t[10]) or 100, temp = tonumber(t[11]) or 0 }
    else
        e.hp        = { cur = tonumber(t[3]) or 0, max = tonumber(t[4])  or 100, temp = 0 }
        e.mana      = { cur = tonumber(t[5]) or 0, max = tonumber(t[6])  or 100, temp = 0 }
        e.endurance = { cur = tonumber(t[7]) or 0, max = tonumber(t[8])  or 100, temp = 0 }
    end
    NormalizeChar(e)
    C.groupData[sender] = e
end

-- ── Réseau ────────────────────────────────────────────────────────────────────

local function SendBroadcastNow()
    local ct = GroupChat(); if not ct then return end
    SendAddon("S|" .. Pack(MyChar()), ct)
end

local function ScheduleBroadcast(delay)
    pendingBroadcast = true
    broadcastAt = GetTime() + (delay or 0.45)
    if broadcastFrame then broadcastFrame:Show() end
end

function C:Broadcast(now)
    if now then
        pendingBroadcast = false
        SendBroadcastNow()
        return
    end
    ScheduleBroadcast(0.45)
end

function C:RequestAll()
    local ct = GroupChat(); if not ct then return end
    SendAddon("R", ct)
    C:Broadcast(true)

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = UnitName("raid" .. i)
            if name and name ~= MyName() then SendAddon("R", "WHISPER", name) end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            local name = UnitName("party" .. i)
            if name and name ~= MyName() then SendAddon("R", "WHISPER", name) end
        end
    end
end

-- Le MJ envoie une commande de modification en whisper au joueur cible
function C:SendModCmd(target, stat, delta)
    SendAddon("M|" .. stat .. SEP .. tostring(delta), "WHISPER", target)
end

function C:SendTempCmd(target, stat, amount)
    SendAddon("T|" .. stat .. SEP .. tostring(amount), "WHISPER", target)
end

-- ── Initiative (Combat) ─────────────────────────────────────────────────────
-- Pas de rôle MJ formel : quiconque clique "Début de combat" devient l'hôte
-- pour son client, maintient la liste triée et rediffuse l'état complet à
-- chaque changement. Les autres clients appliquent l'état reçu tel quel.

C.initiative = {
    active       = false,
    isHost       = false,
    currentIndex = 1,
    participants = {},  -- { {kind="player"|"npc", id, name, initiative, creator}, ... } déjà trié
}

local nextNpcSeq = 0

local function SortParticipants(list)
    table.sort(list, function(a, b)
        if a.initiative ~= b.initiative then return a.initiative > b.initiative end
        return (a.name or "") < (b.name or "")
    end)
end

-- Les PNJ portent un bloc HP/Mana/Endurance + icone (comme une fiche perso,
-- en plus léger) pour s'afficher dans la Vue MJ — PNJ / la bannière.
-- Les joueurs n'en ont pas besoin (leurs vraies stats viennent de
-- C.groupData / GetMyChar, leur nom d'affichage de GetDisplayName) : on ne
-- les empaquette QUE pour les PNJ. Avec beaucoup de participants, un format
-- à largeur fixe pour tout le monde (15 champs chacun, PNJ comme joueurs)
-- a fait dépasser la limite de taille d'un message addon sur ce serveur et
-- tronquait le payload en cours de route — d'où des valeurs à 0 côté
-- réception. D'où aussi l'icone raccourcie (sans le préfixe "Interface\Icons\").
local ICON_PREFIX = "Interface\\Icons\\"

local function EncodeIcon(icon)
    if not icon or icon == "" then return "-" end
    if icon:sub(1, #ICON_PREFIX) == ICON_PREFIX then
        return Enc(icon:sub(#ICON_PREFIX + 1))
    end
    return Enc(icon)
end

local function DecodeIcon(raw)
    if not raw or raw == "" or raw == "-" then return nil end
    if raw:find("[/\\]") then return raw end  -- déjà un chemin complet
    return ICON_PREFIX .. raw
end

local function PackInitiative()
    local st = C.initiative
    local parts = { st.active and 1 or 0, st.currentIndex, #st.participants }
    for _, p in ipairs(st.participants) do
        table.insert(parts, p.kind)
        table.insert(parts, Enc(p.id))
        table.insert(parts, p.initiative)
        if p.kind == "npc" then
            local hp   = p.hp or {}
            local mana = p.mana or {}
            local endu = p.endurance or {}
            table.insert(parts, Enc(p.name))
            table.insert(parts, Enc(p.creator))
            table.insert(parts, math.floor(hp.cur or 0))
            table.insert(parts, math.floor(hp.max or 0))
            table.insert(parts, math.floor(hp.temp or 0))
            table.insert(parts, math.floor(mana.cur or 0))
            table.insert(parts, math.floor(mana.max or 0))
            table.insert(parts, math.floor(mana.temp or 0))
            table.insert(parts, math.floor(endu.cur or 0))
            table.insert(parts, math.floor(endu.max or 0))
            table.insert(parts, math.floor(endu.temp or 0))
            table.insert(parts, EncodeIcon(p.icon))
        end
    end
    return table.concat(parts, SEP)
end

local function UnpackInitiative(payload)
    local t = { strsplit(SEP, payload) }
    local active       = tonumber(t[1]) == 1
    local currentIndex = tonumber(t[2]) or 1
    local n             = tonumber(t[3]) or 0
    local participants = {}
    local idx = 4
    for i = 1, n do
        local kind = t[idx]
        local entry = {
            kind       = kind,
            id         = t[idx + 1],
            initiative = tonumber(t[idx + 2]) or 0,
        }
        idx = idx + 3
        if kind == "npc" then
            entry.name      = t[idx]
            entry.creator   = t[idx + 1]
            entry.hp        = { cur = tonumber(t[idx + 2]) or 0, max = tonumber(t[idx + 3]) or 0, temp = tonumber(t[idx + 4]) or 0 }
            entry.mana      = { cur = tonumber(t[idx + 5]) or 0, max = tonumber(t[idx + 6]) or 0, temp = tonumber(t[idx + 7]) or 0 }
            entry.endurance = { cur = tonumber(t[idx + 8]) or 0, max = tonumber(t[idx + 9]) or 0, temp = tonumber(t[idx + 10]) or 0 }
            entry.icon      = DecodeIcon(t[idx + 11])
            idx = idx + 12
        else
            entry.name = entry.id
        end
        participants[i] = entry
    end
    C.initiative.active       = active
    C.initiative.currentIndex = currentIndex
    C.initiative.participants = participants
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
end

local function FindNPC(id)
    for _, p in ipairs(C.initiative.participants) do
        if p.kind == "npc" and p.id == id then return p end
    end
end

local function BroadcastInitiative()
    local ct = GroupChat(); if not ct then return end
    SendAddon("IC|" .. PackInitiative(), ct)
end

function C:StartCombat()
    C.initiative.isHost       = true
    C.initiative.active       = true
    C.initiative.currentIndex = 1
    C.initiative.participants = {}
    nextNpcSeq = 0
    BroadcastInitiative()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
end

function C:EndCombat()
    if not C.initiative.isHost then return false end
    C.initiative.active       = false
    C.initiative.participants = {}
    C.initiative.currentIndex = 1
    BroadcastInitiative()
    C.initiative.isHost = false
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
    return true
end

local DEFAULT_NPC_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

function C:AddNPC(name, initiative, hp, mana, endurance, icon)
    if not C.initiative.isHost or not C.initiative.active then return false end
    name = tostring(name or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then return false end
    nextNpcSeq = nextNpcSeq + 1
    local hpMax  = math.max(0, math.floor(tonumber(hp) or 0))
    local mpMax  = math.max(0, math.floor(tonumber(mana) or 0))
    local endMax = math.max(0, math.floor(tonumber(endurance) or 0))
    icon = (icon and icon ~= "" and icon) or DEFAULT_NPC_ICON
    table.insert(C.initiative.participants, {
        kind       = "npc",
        id         = "npc" .. nextNpcSeq,
        name       = name,
        initiative = math.floor(tonumber(initiative) or 0),
        creator    = MyName(),
        icon       = icon,
        hp         = { cur = hpMax,  max = hpMax,  temp = 0 },
        mana       = { cur = mpMax,  max = mpMax,  temp = 0 },
        endurance  = { cur = endMax, max = endMax, temp = 0 },
    })
    SortParticipants(C.initiative.participants)
    BroadcastInitiative()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
    return true
end

-- Même mécanique que C:Delta / C:AddTemp pour un joueur, mais appliquée
-- directement au bloc de stats d'un PNJ (l'hôte est la seule autorité :
-- pas de PNJ "réel" à qui envoyer une commande en whisper).
function C:ApplyNPCDelta(id, stat, delta)
    if not C.initiative.isHost then return end
    local p = FindNPC(id); if not p then return end
    local s = p[stat]; if not s then return end
    delta = tonumber(delta) or 0
    if delta < 0 and (s.temp or 0) > 0 then
        local loss = math.abs(delta)
        local absorbed = math.min(s.temp, loss)
        s.temp = s.temp - absorbed
        loss = loss - absorbed
        if loss <= 0 then
            BroadcastInitiative()
            if C.OnInitiativeChanged then C.OnInitiativeChanged() end
            return
        end
        delta = -loss
    end
    s.cur = math.max(0, math.min((s.cur or 0) + delta, s.max or 0))
    BroadcastInitiative()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
end

function C:ApplyNPCTemp(id, stat, amount)
    if not C.initiative.isHost then return end
    local p = FindNPC(id); if not p then return end
    local s = p[stat]; if not s then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount == 0 then return end
    s.temp = math.max(0, (s.temp or 0) + amount)
    BroadcastInitiative()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
end

function C:RemoveNPC(id)
    if not C.initiative.isHost or not id then return end
    for i, p in ipairs(C.initiative.participants) do
        if p.kind == "npc" and p.id == id then
            table.remove(C.initiative.participants, i)
            if C.initiative.currentIndex > i then
                C.initiative.currentIndex = C.initiative.currentIndex - 1
            end
            break
        end
    end
    BroadcastInitiative()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
end

-- Annonce en /rw (raid warning, ou /p si pas en raid) le nom/prénom RP (TRP3)
-- du joueur dont c'est le tour, ou juste son nom brut si c'est un PNJ.
function C:AnnounceCurrentTurn()
    local p = C.initiative.participants[C.initiative.currentIndex]
    if not p then return end

    local label
    if p.kind == "npc" then
        label = CleanDisplayName(p.name) or p.name
    else
        local data = (p.id == MyName()) and MyChar() or C.groupData[p.id]
        label = C:GetDisplayName(p.id, data)
    end
    if not label or label == "" then return end

    local text = "Au tour de " .. label .. " !"
    if IsInRaid and IsInRaid() then
        SendChatMessage(text, "RAID_WARNING")
    elseif IsInGroup and IsInGroup() then
        SendChatMessage(text, "PARTY")
    end
end

function C:NextTurn()
    if not C.initiative.isHost or not C.initiative.active then return false end
    if #C.initiative.participants == 0 then return false end
    C.initiative.currentIndex = (C.initiative.currentIndex % #C.initiative.participants) + 1
    BroadcastInitiative()
    C:AnnounceCurrentTurn()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
    return true
end

function C:_ApplyInitiativeInput(name, value)
    if not C.initiative.isHost or not C.initiative.active then return end
    if not name or name == "" then return end
    value = math.floor(tonumber(value) or 0)
    local found
    for _, p in ipairs(C.initiative.participants) do
        if p.kind == "player" and p.id == name then found = p; break end
    end
    if found then
        found.initiative = value
    else
        table.insert(C.initiative.participants, {
            kind = "player", id = name, name = name, initiative = value, creator = name,
        })
    end
    SortParticipants(C.initiative.participants)
    BroadcastInitiative()
    if C.OnInitiativeChanged then C.OnInitiativeChanged() end
end

function C:SubmitMyInitiative(value)
    value = math.floor(tonumber(value) or 0)
    local ct = GroupChat()
    if ct then SendAddon("II|" .. tostring(value), ct) end
    if C.initiative.isHost then
        C:_ApplyInitiativeInput(MyName(), value)
    end
end

-- ── Réception ─────────────────────────────────────────────────────────────────

local function HandlePayload(payload, sender)
    if not payload then return false end
    local name = sender and sender:match("^([^%-]+)") or sender
    if not name or name == "" then return false end

    local kind, body = payload:match("^(%u)%|(.*)$")
    if kind == "S" and body then
        if name ~= MyName() then
            Unpack(body, name)
            if C.OnGroupDataChanged then C.OnGroupDataChanged(name) end
        end
        return true
    end

    local icBody = payload:match("^IC%|(.*)$")
    if icBody then
        if name ~= MyName() then UnpackInitiative(icBody) end
        return true
    end

    local iiBody = payload:match("^II%|(.*)$")
    if iiBody then
        if IsGroupMember(name) then C:_ApplyInitiativeInput(name, tonumber(iiBody) or 0) end
        return true
    end

    if payload == "R" then
        if name ~= MyName() then
            C:Broadcast(true)
            if C.initiative.isHost then BroadcastInitiative() end
        end
        return true
    end

    if kind == "M" and body then
        if IsGroupMember(name) then
            local stat, delta = strsplit(SEP, body, 2)
            if stat and delta then C:Delta(stat, tonumber(delta) or 0, true) end
        end
        return true
    end

    if kind == "T" and body then
        if IsGroupMember(name) then
            local stat, amount = strsplit(SEP, body, 2)
            if stat and amount then C:AddTemp(stat, tonumber(amount) or 0, true) end
        end
        return true
    end

    return false
end

-- ── Filtre de chat legacy ─────────────────────────────────────────────────────

local function Handle(msg, sender)
    if not msg then return false end
    local name = sender and sender:match("^([^%-]+)") or sender

    -- Broadcast de stats {CH:...}
    local d = msg:match("{CH:([^}]+)}")
    if d then
        if name ~= MyName() then
            Unpack(d, name)
            if C.OnGroupDataChanged then C.OnGroupDataChanged(name) end
        end
        return true  -- toujours supprimer du chat
    end

    -- Demande de rafraîchissement {CHR}
    if msg:find("{CHR}", 1, true) then
        if name ~= MyName() then C:Broadcast() end
        return true
    end

    -- Commande MJ {CHM:stat:delta}
    local cmd = msg:match("{CHM:([^}]+)}")
    if cmd then
        if IsGroupMember(name) then
            local stat, delta = strsplit(SEP, cmd, 2)
            if stat and delta then C:Delta(stat, tonumber(delta) or 0, true) end
        end
        return true
    end

    return false
end

local function Filter(_, _, msg, sender)
    if Handle(msg, sender) then return true end
end

local EVENTS = {
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_PARTY",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
}
local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function(_, event, prefix, payload, channel, sender)
    if event == "CHAT_MSG_ADDON" and prefix == PREFIX then
        HandlePayload(payload, sender)
    end
end)

-- ── Slash ─────────────────────────────────────────────────────────────────────
-- Enregistrées/désenregistrées dans Enable()/Disable() : sinon /ochar et /ocharmj
-- restent fonctionnelles même quand le module est désactivé.

local function RegisterSlash()
    SLASH_OCHAR1 = "/ochar"
    SlashCmdList["OCHAR"] = function()
        if CharacterPlayerPanel then CharacterPlayerPanel:Toggle() end
    end

    SLASH_OCHARMJ1 = "/ocharmj"
    SlashCmdList["OCHARMJ"] = function()
        if CharacterMJPanel then CharacterMJPanel:Toggle() end
    end
end

-- ── Enable / Disable ──────────────────────────────────────────────────────────

function C:Enable()
    RegisterSlash()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
    for _, ev in ipairs(EVENTS) do ChatFrame_AddMessageEventFilter(ev, Filter) end
    if C._resetLauncherOnNextEnable and C.ResetLauncherPosition then
        C:ResetLauncherPosition(true)
    elseif CharacterLauncherBtn then
        CharacterLauncherBtn:Show()
    end
    C._resetLauncherOnNextEnable = nil
    if C.ApplyDisplaySettings then C:ApplyDisplaySettings() end
    OmegaHub:SetModuleLoaded("Character", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Character activé.  |cffAAAAAA/ochar · /ocharmj|r")
    end
end

function C:Disable()
    eventFrame:UnregisterEvent("CHAT_MSG_ADDON")
    for _, ev in ipairs(EVENTS) do ChatFrame_RemoveMessageEventFilter(ev, Filter) end
    C._resetLauncherOnNextEnable = true
    -- Si je suis l'hôte du combat, le clore proprement referme la bannière
    -- d'initiative chez tout le monde plutôt que de la laisser bloquée active.
    if C.initiative.isHost then C:EndCombat() end
    -- Referme toutes les fenêtres du module : sinon elles restent ouvertes et
    -- pleinement fonctionnelles (HP/Mana/Endurance modifiables, broadcast envoyé)
    -- alors que le module est censé être désactivé.
    if CharacterSettingsPanel      then CharacterSettingsPanel:Hide()      end
    if CharacterPlayerPanel        then CharacterPlayerPanel:Hide()        end
    if CharacterMJPanel            then CharacterMJPanel:Hide()            end
    if CharacterMJImpactPanel      then CharacterMJImpactPanel:Hide()      end
    if CharacterMJPnjPanel         then CharacterMJPnjPanel:Hide()         end
    if CharacterGroupViewPanel     then CharacterGroupViewPanel:Hide()     end
    if CharacterInitiativeBanner   then CharacterInitiativeBanner:Hide()   end
    if CharacterLauncherBtn        then CharacterLauncherBtn:Hide()        end
    SLASH_OCHAR1   = nil
    SLASH_OCHARMJ1 = nil
    SlashCmdList["OCHAR"]   = nil
    SlashCmdList["OCHARMJ"] = nil
    OmegaHub:SetModuleLoaded("Character", false)
    OmegaHub.Print("Character désactivé.")
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({ name = "Character", module = C })
    CharacterDB = CharacterDB or {}
    if C.ApplyDisplaySettings then C:ApplyDisplaySettings() end
    broadcastFrame = CreateFrame("Frame")
    broadcastFrame:Hide()
    broadcastFrame:SetScript("OnUpdate", function(self)
        if pendingBroadcast and GetTime() >= broadcastAt then
            pendingBroadcast = false
            self:Hide()
            SendBroadcastNow()
        end
    end)
    if OmegaHub:IsModuleEnabled("Character") then C:Enable() end
    f:UnregisterAllEvents()
end)
