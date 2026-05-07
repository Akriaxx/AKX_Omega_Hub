-- Omega_Weather
-- Cycle rituel :
-- - Heures impaires à xx:55 : annonce de montée de tempête
-- - Heures paires à xx:00   : jets Tempête maudite (Visual + Audio concaténés)
-- - Heures paires à xx:05   : annonce de fin de tempête
-- Commandes de test :
-- - /omwe   : force immédiatement les jets et le résultat
-- - /omwesp : force immédiatement les jets entre 80 et 100

local ticker = nil
local lastTriggerKey = nil

-- //////////////////////////////////////////////////////////
-- Helpers généraux
-- //////////////////////////////////////////////////////////

local function Pad2(n)
    n = tonumber(n) or 0
    return (n < 10) and ("0" .. n) or tostring(n)
end

local function GetLocalTime()
    return date("*t")
end

local function GetTriggerKey(t)
    return string.format("%04d-%02d-%02d %02d:%02d",
        t.year, t.month, t.day, t.hour, t.min)
end

local function Trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function PickRandom(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then
        return nil
    end
    return tbl[math.random(1, #tbl)]
end

local function SendRaidOrPrint(text)
    if not text or text == "" then
        return
    end

    if IsInRaid() then
        SendChatMessage(text, "RAID")
    else
        print("|cff00bfff[Omega Weather]|r Hors raid : " .. text)
    end
end

local function JoinStormText(visualText, audioText)
    local v = Trim(visualText)
    local a = Trim(audioText)

    if v ~= "" and a ~= "" then
        return "-* " .. v .. " " .. a .. " *-"
    end

    if v ~= "" then
        return "-* " .. v .. " *-"
    end

    if a ~= "" then
        return "-* " .. a .. " *-"
    end

    return nil
end

local function CheckSpecialEvent(visualRoll, audioRoll)
    if visualRoll >= 96 and visualRoll <= 99
    and audioRoll  >= 96 and audioRoll  <= 99 then
        return "OverwhelmingAssault"
    end

    if visualRoll >= 80 and visualRoll <= 95
    and audioRoll  >= 80 and audioRoll  <= 95 then
        return "Assault"
    end

    return nil
end

-- //////////////////////////////////////////////////////////
-- Messages de cycle
-- //////////////////////////////////////////////////////////

local function SendStormWarning()
    local text = "-* Le vent se lève. Le sable commence à prendre vie. *-"
    SendRaidOrPrint(text)
end

local function SendStormEnd()
    local text = "-* La tempête cesse. Le calme reprend son cours. Tout ce qui vous entoure semble reprendre le cours de sa vie, comme si rien n'avait jamais eu lieu. *-"
    SendRaidOrPrint(text)
end

-- //////////////////////////////////////////////////////////
-- Tempête maudite
-- //////////////////////////////////////////////////////////

local function TriggerStorm(forceMin, forceMax)
    if not OmegaWeatherData then
        print("|cff00bfff[Omega Weather]|r OmegaWeatherData introuvable.")
        return
    end

    local minRoll = tonumber(forceMin) or 1
    local maxRoll = tonumber(forceMax) or 100

    if minRoll < 1 then minRoll = 1 end
    if maxRoll > 100 then maxRoll = 100 end
    if minRoll > maxRoll then
        minRoll, maxRoll = maxRoll, minRoll
    end

    local visualRoll = math.random(minRoll, maxRoll)
    local audioRoll  = math.random(minRoll, maxRoll)

    local visualEmote, visualEntry = OmegaWeatherData.GetVisualEmote(visualRoll)
    local audioEmote, audioEntry   = OmegaWeatherData.GetAudioEmote(audioRoll)

    -- DEBUG LOCAL
    print("|cff00bfff[Omega Weather]|r Jet Visuel : " .. visualRoll ..
          " (" .. (visualEntry and visualEntry.title or "Inconnu") .. ")")

    print("|cff00bfff[Omega Weather]|r Jet Auditif : " .. audioRoll ..
          " (" .. (audioEntry and audioEntry.title or "Inconnu") .. ")")

    local fullText = JoinStormText(visualEmote, audioEmote)
    if not fullText then
        print("|cff00bfff[Omega Weather]|r Aucun texte de tempête généré.")
        return
    end

    SendRaidOrPrint(fullText)

    -- Condition Titan purement narrative
    if visualRoll == 100 and audioRoll == 100 then
        local titanText = "-* Le sable se soulève en une masse impossible. Un élément émerge des profondeurs du désert. Il hurle. Son cri vous foudroie les timpans. Vous assourdi, ne serait-ce que temporairement. Vous tombez dans les pommes.*-"
        SendRaidOrPrint(titanText)
        print("|cff00bfff[Omega Weather]|r Titan déclenché.")
    end

    -- Événements spéciaux d'assaut
    local eventType = CheckSpecialEvent(visualRoll, audioRoll)

    if eventType
    and OmegaWeatherData.SpecialEvents
    and OmegaWeatherData.SpecialEvents[eventType] then
        local extra = PickRandom(OmegaWeatherData.SpecialEvents[eventType].emotes)

        if extra and extra ~= "" then
            SendRaidOrPrint("-*[ SPECIAL EVENT ] " .. extra .. " *-")
            print("|cff00bfff[Omega Weather]|r Événement spécial : " .. eventType)
        end
    end
end

-- //////////////////////////////////////////////////////////
-- Horloge
-- //////////////////////////////////////////////////////////

local function IsWarningTime(t)
    return t.min == 55 and (t.hour % 2 == 1)
end

local function IsStormTime(t)
    return t.min == 0 and (t.hour % 2 == 0)
end

local function IsCalmTime(t)
    return t.min == 5 and (t.hour % 2 == 0)
end

local function CheckClock()
    local t = GetLocalTime()

    if t.sec ~= 0 then
        return
    end

    if not IsWarningTime(t) and not IsStormTime(t) and not IsCalmTime(t) then
        return
    end

    local triggerKey = GetTriggerKey(t)
    if triggerKey == lastTriggerKey then
        return
    end

    lastTriggerKey = triggerKey

    if IsWarningTime(t) then
        SendStormWarning()
        return
    end

    if IsStormTime(t) then
        TriggerStorm()
        return
    end

    if IsCalmTime(t) then
        SendStormEnd()
        return
    end
end

-- //////////////////////////////////////////////////////////
-- Enable / Disable (API Hub)
-- //////////////////////////////////////////////////////////

OmegaWeather = OmegaWeather or {}
local OW = OmegaWeather

function OW:Enable()
    if not ticker then
        ticker = C_Timer.NewTicker(1, CheckClock)
    end

    SLASH_OMEGAWEATHER1 = "/omwe"
    SlashCmdList["OMEGAWEATHER"] = function(msg)
        msg = Trim(msg):lower()
        if msg == "" then
            print("|cff00bfff[Omega Weather]|r Test manuel de la tempête.")
            TriggerStorm()
        elseif msg == "warning" then
            SendStormWarning()
        elseif msg == "stop" or msg == "calm" then
            SendStormEnd()
        elseif msg == "debugtime" then
            local t = GetLocalTime()
            print("|cff00bfff[Omega Weather]|r Heure locale : " .. Pad2(t.hour) .. "h" .. Pad2(t.min) .. ":" .. Pad2(t.sec))
        else
            print("|cff00bfff[Omega Weather]|r /omwe | /omwe warning | /omwe stop | /omwe debugtime | /omwesp")
        end
    end

    SLASH_OMEGAWEATHERSP1 = "/omwesp"
    SlashCmdList["OMEGAWEATHERSP"] = function()
        print("|cff00bfff[Omega Weather]|r Test spécial : jets forcés entre 80 et 100.")
        TriggerStorm(80, 100)
    end

    OmegaHub:SetModuleLoaded("Omega_Weather", true)
end

function OW:Disable()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end

    SLASH_OMEGAWEATHER1   = nil
    SlashCmdList["OMEGAWEATHER"]   = nil
    SLASH_OMEGAWEATHERSP1 = nil
    SlashCmdList["OMEGAWEATHERSP"] = nil

    OmegaHub:SetModuleLoaded("Omega_Weather", false)
end

-- //////////////////////////////////////////////////////////
-- Bootstrap
-- //////////////////////////////////////////////////////////

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({ name = "Omega_Weather", module = OW })

    if OmegaHub:IsModuleEnabled("Omega_Weather") then
        OW:Enable()
    end

    frame:UnregisterAllEvents()
end)