local OmegaDice = _G.OmegaDice

-- Message d'addon porteur d'un jet truque (/rdfdp). Meme principe que le
-- canal "OmegaChar" du module Character : invisible pour tout le monde
-- (les messages d'addon ne s'affichent jamais dans le chat), execute
-- automatiquement chez le destinataire vise par le champ <target> du
-- payload. Envoye a la fois en whisper direct ET en broadcast groupe/raid
-- (le destinataire filtre sur son propre nom, les autres l'ignorent) : le
-- whisper seul s'est avere pas fiable a 100% en jeu, le broadcast groupe
-- sert de filet de secours sans rien reveler puisque CHAT_MSG_ADDON n'est
-- jamais affiche a l'ecran, quel que soit le canal utilise.
local PREFIX = "OmegaDiceF"
local eventFrame = CreateFrame("Frame")

local function MyName() return UnitName("player") or "" end

local function GroupChat()
    if IsInRaid  and IsInRaid()  then return "RAID"  end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

-- Un nom de personnage WoW ne contient jamais de "-" : celui-ci ne peut donc
-- provenir que d'un suffixe "-Royaume" (cible cross-royaume), qu'on retire
-- pour comparer avec MyName() qui n'en porte jamais.
local function StripRealm(name)
    return (name or ""):match("^([^%-]+)") or ""
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

-- Payload : "F:<target>:<numRolls>:<dieSides>:<forcedValue>:<modifiers>:<description>"
-- La description est en dernier champ, sans limite de caracteres (peut
-- contenir des ":" ou des espaces).
function OmegaDice.SendForcedRoll(target, numRolls, dieSides, forcedValue, modifiers, description)
    if not target or target == "" then return false end
    local payload = string.format(
        "F:%s:%d:%d:%d:%s:%s",
        target, numRolls, dieSides, forcedValue, modifiers or "", description or ""
    )

    local sentWhisper = SendAddon(payload, "WHISPER", target)

    local groupChannel = GroupChat()
    local sentGroup = groupChannel and SendAddon(payload, groupChannel)

    return sentWhisper or sentGroup or false
end

local function HandlePayload(payload, sender)
    if not payload or sender == MyName() then return end
    local targetName, numRolls, dieSides, forcedValue, modifiers, description =
        payload:match("^F:([^:]*):(%d+):(%d+):(%d+):([^:]*):(.*)$")
    if not numRolls then return end
    if StripRealm(targetName):lower() ~= MyName():lower() then return end
    OmegaDice.ExecuteForcedRoll(tonumber(numRolls), tonumber(dieSides), tonumber(forcedValue), modifiers, description)
end

eventFrame:SetScript("OnEvent", function(_, event, prefix, payload, _, sender)
    if event == "CHAT_MSG_ADDON" and prefix == PREFIX then
        HandlePayload(payload, sender)
    end
end)

function OmegaDice.RegisterNetwork()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end
    eventFrame:RegisterEvent("CHAT_MSG_ADDON")
end

function OmegaDice.UnregisterNetwork()
    eventFrame:UnregisterEvent("CHAT_MSG_ADDON")
end
