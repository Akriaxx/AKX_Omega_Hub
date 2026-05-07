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

local function CleanDisplayName(name)
    name = tostring(name or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
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

    if payload == "R" then
        if name ~= MyName() then C:Broadcast(true) end
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

-- ── Enable / Disable ──────────────────────────────────────────────────────────

function C:Enable()
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
    if CharacterSettingsPanel then CharacterSettingsPanel:Hide() end
    if CharacterLauncherBtn then CharacterLauncherBtn:Hide() end
    OmegaHub:SetModuleLoaded("Character", false)
    OmegaHub.Print("Character désactivé.")
end

-- ── Slash ─────────────────────────────────────────────────────────────────────

SLASH_OCHAR1 = "/ochar"
SlashCmdList["OCHAR"] = function()
    if CharacterPlayerPanel then CharacterPlayerPanel:Toggle() end
end

SLASH_OCHARMJ1 = "/ocharmj"
SlashCmdList["OCHARMJ"] = function()
    if CharacterMJPanel then CharacterMJPanel:Toggle() end
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
