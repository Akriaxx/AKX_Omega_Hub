-- Bundled dans Omega_Hub — on ne peut pas utiliser `...` pour récupérer
-- le nom de l'addon. On initialise OmegaDice directement en global.
OmegaDice = OmegaDice or {}
local OmegaDice = OmegaDice
_G.OmegaDice = OmegaDice

OmegaDice.name        = "Omega_Dice"
OmegaDice.printPrefix = "|cff00ff00[Omega Dice]:|r"

function OmegaDice.Trim(value)
    if not value then return "" end
    return tostring(value):match("^%s*(.-)%s*$") or ""
end

function OmegaDice.SumModifiers(modifiers)
    local total = 0
    local text = OmegaDice.Trim(modifiers)
    if text == "" then return total, text end
    for number in string.gmatch(text, "[%+%-]?%d+") do
        total = total + tonumber(number)
    end
    return total, text
end

function OmegaDice.EscapeChatMessage(message)
    return tostring(message or ""):gsub("|", "||")
end

function OmegaDice.SendResult(message)
    local escapedMessage = OmegaDice.EscapeChatMessage(message)
    if IsInRaid and IsInRaid() then
        SendChatMessage(escapedMessage, "RAID")
        return
    end
    print(OmegaDice.printPrefix, escapedMessage)
end

function OmegaDice.PrintError(message)
    print("|cffff0000" .. message .. "|r")
end

-- ── Enable / Disable (API Hub) ─────────────────────────────────────────────

function OmegaDice:Enable()
    OmegaDice.RegisterCommands()
    if OmegaDice.RegisterNetwork then OmegaDice.RegisterNetwork() end
    OmegaHub:SetModuleLoaded("Omega_Dice", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Omega Dice activé.  |cffAAAAAA/rd <NdM[±X]>   /rd <NxdM[±X][!±X ou !D±X...]> (jets séparés, !D cible le dé D)   /rnd [min-max]   /rdfdp <joueur> <NdM>=<résultat>[±X] (jet truqué, discret)|r")
    end
end

function OmegaDice:Disable()
    OmegaDice.UnregisterCommands()
    if OmegaDice.UnregisterNetwork then OmegaDice.UnregisterNetwork() end
    OmegaHub:SetModuleLoaded("Omega_Dice", false)
    OmegaHub.Print("Omega Dice désactivé.")
end

-- ── Init ───────────────────────────────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({ name = "Omega_Dice", module = OmegaDice })

    if OmegaHub:IsModuleEnabled("Omega_Dice") then
        OmegaDice:Enable()
    end

    initFrame:UnregisterAllEvents()
end)
