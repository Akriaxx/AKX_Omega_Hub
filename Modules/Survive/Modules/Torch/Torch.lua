-- OmegaSurvive 2.0 — Torche
local panel = OS2.panels["torche"]
local PANEL_W = OS2.PANEL_W
local db
local isLoggingOut = false
local pendingRecharge = false
local emoteEditContext = {}
local UI = OS2.UI or {}
local ModuleRules = OS2.ModuleRules

local DEFAULT_EMOTES = OS2.DefaultTorchEmotes or {
    on       = "allume sa torche.",
    off      = "éteint sa torche.",
    recharge = "imbibe la mèche de sa torche de combustible frais.",
    swap     = "retire le combustible de sa torche et le remplace par un autre.",
    empty    = "n'a plus de torche active. Elle vient de s'éteindre.",
}

local QUICK_FADE_TIME = 0.15
local QUICK_SLIDE = 18
local BASE_PANEL_H = 330
local EMOTE_PANEL_H = 420
local SendTorchEmote  -- forward declaration (défini après SyncTorchState)
local UpdateSelectionDropdown
local TriggerAuraRules

local function CurrentDB()
    db = OS2.GetTorchDB()
    return db
end

local function GetSelectedRechargeFuel()
    local fuelKey = CurrentDB().crystalKey
    return fuelKey and OS2.Core.TorchFuelByKey and OS2.Core.TorchFuelByKey[fuelKey] or nil
end

local GetInventoryCount = ModuleRules.GetInventoryCount

local function GetSelectedActivationItems()
    local torchDB = CurrentDB()
    local items = {}

    local model = torchDB.modelKey and OS2.Core.TorchModelByKey and OS2.Core.TorchModelByKey[torchDB.modelKey] or nil
    local fuel = torchDB.crystalKey and OS2.Core.TorchFuelByKey and OS2.Core.TorchFuelByKey[torchDB.crystalKey] or nil

    if model then
        items[#items + 1] = { item = model, label = "Cette torche" }
    end
    if fuel then
        items[#items + 1] = { item = fuel, label = "Ce combustible" }
    end

    return items
end

local function HasRequiredInventoryItem(item, contextLabel)
    return ModuleRules.HasRequiredInventoryItem(item, contextLabel)
end

local function ValidateRechargeInventoryItem(item)
    return ModuleRules.ValidateRechargeInventoryItem(item, "combustible")
end

local function ConsumeInventoryItemAndThen(itemId, onConsumed)
    return ModuleRules.ConsumeInventoryItemAndThen(itemId, onConsumed, {
        isPending = function() return pendingRecharge end,
        setPending = function(value) pendingRecharge = value end,
        cancelMessage = "Le combustible n'a pas été consommé. La recharge est annulée.",
    })
end

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$") or ""
end

local function StripOuterAsterisks(text)
    text = Trim(text)
    return (text:gsub("^%*+", ""):gsub("%*+$", ""))
end

local ACCENTED_CASE_MAP = {
    { lower = "à", upper = "À" },
    { lower = "á", upper = "Á" },
    { lower = "â", upper = "Â" },
    { lower = "ã", upper = "Ã" },
    { lower = "ä", upper = "Ä" },
    { lower = "å", upper = "Å" },
    { lower = "ā", upper = "Ā" },
    { lower = "ă", upper = "Ă" },
    { lower = "ą", upper = "Ą" },
    { lower = "æ", upper = "Æ" },
    { lower = "ć", upper = "Ć" },
    { lower = "ĉ", upper = "Ĉ" },
    { lower = "ċ", upper = "Ċ" },
    { lower = "č", upper = "Č" },
    { lower = "ç", upper = "Ç" },
    { lower = "ď", upper = "Ď" },
    { lower = "đ", upper = "Đ" },
    { lower = "é", upper = "É" },
    { lower = "è", upper = "È" },
    { lower = "ê", upper = "Ê" },
    { lower = "ë", upper = "Ë" },
    { lower = "ē", upper = "Ē" },
    { lower = "ĕ", upper = "Ĕ" },
    { lower = "ė", upper = "Ė" },
    { lower = "ę", upper = "Ę" },
    { lower = "ě", upper = "Ě" },
    { lower = "ĝ", upper = "Ĝ" },
    { lower = "ğ", upper = "Ğ" },
    { lower = "ġ", upper = "Ġ" },
    { lower = "ģ", upper = "Ģ" },
    { lower = "ĥ", upper = "Ĥ" },
    { lower = "ħ", upper = "Ħ" },
    { lower = "ì", upper = "Ì" },
    { lower = "í", upper = "Í" },
    { lower = "î", upper = "Î" },
    { lower = "ï", upper = "Ï" },
    { lower = "ĩ", upper = "Ĩ" },
    { lower = "ī", upper = "Ī" },
    { lower = "ĭ", upper = "Ĭ" },
    { lower = "į", upper = "Į" },
    { lower = "ı", upper = "I" },
    { lower = "ĵ", upper = "Ĵ" },
    { lower = "ķ", upper = "Ķ" },
    { lower = "ĺ", upper = "Ĺ" },
    { lower = "ļ", upper = "Ļ" },
    { lower = "ľ", upper = "Ľ" },
    { lower = "ł", upper = "Ł" },
    { lower = "ñ", upper = "Ñ" },
    { lower = "ń", upper = "Ń" },
    { lower = "ņ", upper = "Ņ" },
    { lower = "ň", upper = "Ň" },
    { lower = "ŋ", upper = "Ŋ" },
    { lower = "ò", upper = "Ò" },
    { lower = "ó", upper = "Ó" },
    { lower = "ô", upper = "Ô" },
    { lower = "õ", upper = "Õ" },
    { lower = "ö", upper = "Ö" },
    { lower = "ø", upper = "Ø" },
    { lower = "ō", upper = "Ō" },
    { lower = "ŏ", upper = "Ŏ" },
    { lower = "ő", upper = "Ő" },
    { lower = "œ", upper = "Œ" },
    { lower = "ŕ", upper = "Ŕ" },
    { lower = "ŗ", upper = "Ŗ" },
    { lower = "ř", upper = "Ř" },
    { lower = "ś", upper = "Ś" },
    { lower = "ŝ", upper = "Ŝ" },
    { lower = "ş", upper = "Ş" },
    { lower = "š", upper = "Š" },
    { lower = "ß", upper = "ẞ" },
    { lower = "ţ", upper = "Ţ" },
    { lower = "ť", upper = "Ť" },
    { lower = "ŧ", upper = "Ŧ" },
    { lower = "ù", upper = "Ù" },
    { lower = "ú", upper = "Ú" },
    { lower = "û", upper = "Û" },
    { lower = "ü", upper = "Ü" },
    { lower = "ũ", upper = "Ũ" },
    { lower = "ū", upper = "Ū" },
    { lower = "ŭ", upper = "Ŭ" },
    { lower = "ů", upper = "Ů" },
    { lower = "ű", upper = "Ű" },
    { lower = "ų", upper = "Ų" },
    { lower = "ŵ", upper = "Ŵ" },
    { lower = "ý", upper = "Ý" },
    { lower = "ÿ", upper = "Ÿ" },
    { lower = "ŷ", upper = "Ŷ" },
    { lower = "ź", upper = "Ź" },
    { lower = "ż", upper = "Ż" },
    { lower = "ž", upper = "Ž" },
}

local function ReplaceLeadingAccentedChar(text, fromKey, toKey)
    for _, entry in ipairs(ACCENTED_CASE_MAP) do
        local fromChar = entry[fromKey]
        if text:sub(1, #fromChar) == fromChar then
            return entry[toKey] .. text:sub(#fromChar + 1)
        end
    end
    return nil
end

local function UppercaseFirstLetter(text)
    local replaced = ReplaceLeadingAccentedChar(text, "lower", "upper")
    if replaced then return replaced end
    return (text:gsub("^%l", string.upper, 1))
end

local function LowercaseFirstLetter(text)
    local replaced = ReplaceLeadingAccentedChar(text, "upper", "lower")
    if replaced then return replaced end
    return (text:gsub("^%u", string.lower, 1))
end

local function GetSelectedControlItems()
    local items = {}
    local torchDB = CurrentDB()
    local model = OS2.Core.TorchModelByKey and OS2.Core.TorchModelByKey[torchDB.modelKey]
    if model and model.disableEnabled then items[#items + 1] = model end
    local fuel = OS2.Core.TorchFuelByKey and OS2.Core.TorchFuelByKey[torchDB.crystalKey]
    if fuel and fuel.disableEnabled then items[#items + 1] = fuel end
    return items
end

local function GetSelectedAuraItems()
    local items = {}
    local torchDB = CurrentDB()
    local model = OS2.Core.TorchModelByKey and OS2.Core.TorchModelByKey[torchDB.modelKey]
    if model and model.auraEnabled then items[#items + 1] = model end
    local fuel = OS2.Core.TorchFuelByKey and OS2.Core.TorchFuelByKey[torchDB.crystalKey]
    if fuel and fuel.auraEnabled then items[#items + 1] = fuel end
    return items
end

local auraController = ModuleRules.CreateAuraController({
    getSelectedControlItems = GetSelectedControlItems,
    getSelectedAuraItems = GetSelectedAuraItems,
})

local function MatchesConfiguredControlMessage(event, message, phraseListKey, phraseKey)
    return auraController.MatchesConfiguredControlMessage(event, message, phraseListKey, phraseKey)
end

local function GetMatchedControlPhraseEntry(event, message, phraseListKey, phraseKey)
    return auraController.GetMatchedControlPhraseEntry(event, message, phraseListKey, phraseKey)
end

local function TriggerPhraseAuraRules(event, message, condition)
    return auraController.TriggerPhraseAuraRules(event, message, condition)
end

TriggerAuraRules = function(ruleSetKey, condition, message)
    return auraController.TriggerAuraRules(ruleSetKey, condition, message)
end

local function SetAuraActiveState(active)
    CurrentDB()
    db.auraActive = active == true
end

local function IsMJPaused()
    CurrentDB()
    return db.mjPaused or db.mode == "PAUSE"
end

local function IsPausedActive()
    CurrentDB()
    if not IsMJPaused() then
        return db.mode == "ON"
    end

    if db.pausedActive ~= nil then
        return db.pausedActive == true
    end

    return db.auraActive == true or db.resumeMode == "ON"
end

local function ResolveAuraStateAfterRules(wasAuraActive, removed, applied)
    return ModuleRules.ResolveAuraStateAfterRules(wasAuraActive, removed, applied)
end

local function FormatEmoteForChannel(text, channel)
    local cleaned = StripOuterAsterisks(text)
    if cleaned == "" then return "" end
    if channel == "EMOTE" then return LowercaseFirstLetter(cleaned) end
    return "*" .. UppercaseFirstLetter(cleaned) .. "*"
end

local function GetEmotes()
    local torchDB = CurrentDB()
    torchDB.emotes = torchDB.emotes or {}
    for key, value in pairs(DEFAULT_EMOTES) do
        if torchDB.emotes[key] == nil then
            torchDB.emotes[key] = value
        end
    end
    return torchDB.emotes
end

panel:SetHeight(BASE_PANEL_H)

local function CreatePanelButton(parent, width, height, text)
    return UI.CreatePanelButton(parent, width, height, text)
end

local function StyleDropdown(dd, textLeft, textYOffset, textRightPad)
    UI.StyleDropdown(dd, textLeft, textYOffset, textRightPad)
end

local function StyleQuickDropdown(dd)
    if dd.Left   then dd.Left:SetAlpha(1);   dd.Left:SetVertexColor(0.12, 0.12, 0.12)   end
    if dd.Middle then dd.Middle:SetAlpha(1); dd.Middle:SetVertexColor(0.12, 0.12, 0.12) end
    if dd.Right  then dd.Right:SetAlpha(1);  dd.Right:SetVertexColor(0.12, 0.12, 0.12)  end
    if dd.Icon   then dd.Icon:SetAlpha(1) end

    if dd.Button then
        dd.Button:ClearAllPoints()
        dd.Button:SetPoint("RIGHT", dd, "RIGHT", -15, 3)
        dd.Button:SetSize(22, 22)
        dd.Button:SetNormalTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
        dd.Button:SetPushedTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Down")
        dd.Button:SetDisabledTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Disabled")
        dd.Button:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
        if dd.Button.os2Border    then dd.Button.os2Border:Hide()    end
        if dd.Button.os2Bg        then dd.Button.os2Bg:Hide()        end
        if dd.Button.os2Highlight then dd.Button.os2Highlight:Hide() end
        if dd.Button.os2Arrow     then dd.Button.os2Arrow:Hide()     end
    end

    if dd.Text then
        UI.ApplyBodyText(dd.Text)
        dd.Text:SetJustifyH("LEFT")
        dd.Text:ClearAllPoints()
        dd.Text:SetPoint("LEFT",  dd, "LEFT", 20, 1)
        dd.Text:SetPoint("RIGHT", dd.Button, "LEFT", -3, 0)
    end

    if dd.os2Border then dd.os2Border:Hide() end
    if dd.os2Bg     then dd.os2Bg:Hide()     end
end

local function FormatRateLabel(value)
    if math.floor(value) == value then return string.format("x%d", value) end
    return string.format("x%.1f", value)
end

local function AttachQuickReveal(frame, slide)
    slide = slide or QUICK_SLIDE
    frame.quickSlide = slide
    frame:SetAlpha(0)
    frame:Hide()

    local showAG = frame:CreateAnimationGroup()
    showAG:SetToFinalAlpha(true)
    local showFade = showAG:CreateAnimation("Alpha")
    showFade:SetFromAlpha(0)
    showFade:SetToAlpha(1)
    showFade:SetDuration(QUICK_FADE_TIME)
    local showMove = showAG:CreateAnimation("Translation")
    showMove:SetOffset(0, 0)
    showMove:SetDuration(QUICK_FADE_TIME)
    showAG:SetScript("OnPlay", function()
        local offsetX, offsetY = 0, 0
        if frame.GetQuickRevealOffset then
            offsetX, offsetY = frame:GetQuickRevealOffset(slide)
        end
        showMove:SetOffset(offsetX, offsetY)
        if frame.ApplyQuickAnchor then
            frame:ClearAllPoints()
            frame:ApplyQuickAnchor(-offsetX, -offsetY)
        end
        frame:SetAlpha(0)
        frame:Show()
    end)
    showAG:SetScript("OnFinished", function()
        if frame.ApplyQuickAnchor then
            frame:ClearAllPoints()
            frame:ApplyQuickAnchor(0, 0)
        end
    end)

    local hideAG = frame:CreateAnimationGroup()
    hideAG:SetToFinalAlpha(true)
    local hideFade = hideAG:CreateAnimation("Alpha")
    hideFade:SetFromAlpha(1)
    hideFade:SetToAlpha(0)
    hideFade:SetDuration(QUICK_FADE_TIME)
    local hideMove = hideAG:CreateAnimation("Translation")
    hideMove:SetOffset(0, 0)
    hideMove:SetDuration(QUICK_FADE_TIME)
    hideAG:SetScript("OnPlay", function()
        local offsetX, offsetY = 0, 0
        if frame.GetQuickRevealOffset then
            offsetX, offsetY = frame:GetQuickRevealOffset(slide)
        end
        hideMove:SetOffset(-offsetX, -offsetY)
    end)
    hideAG:SetScript("OnFinished", function()
        if frame.ApplyQuickAnchor then
            frame:ClearAllPoints()
            frame:ApplyQuickAnchor(0, 0)
        end
        frame:SetAlpha(0)
        frame:Hide()
    end)

    frame.quickShowAG = showAG
    frame.quickHideAG = hideAG
end

local function ShowQuickFrame(frame)
    if frame:IsShown() and frame:GetAlpha() >= 1 then return end
    frame.quickHideAG:Stop()
    if OS2.AnimationsEnabled() then
        frame.quickShowAG:Play()
    else
        frame.quickShowAG:Stop()
        if frame.ApplyQuickAnchor then
            frame:ClearAllPoints()
            frame:ApplyQuickAnchor(0, 0)
        end
        frame:SetAlpha(1)
        frame:Show()
    end
end

local function HideQuickFrame(frame)
    if not frame:IsShown() then return end
    frame.quickShowAG:Stop()
    if OS2.AnimationsEnabled() then
        frame.quickHideAG:Play()
    else
        frame.quickHideAG:Stop()
        if frame.ApplyQuickAnchor then
            frame:ClearAllPoints()
            frame:ApplyQuickAnchor(0, 0)
        end
        frame:SetAlpha(0)
        frame:Hide()
    end
end

local QUICK_POSITION_OPTIONS = {
    { value = "LEFT", label = "À gauche" },
    { value = "RIGHT", label = "À droite" },
    { value = "TOP", label = "Au-dessus" },
    { value = "BOTTOM", label = "En dessous" },
}

local function NormalizeQuickActivationPosition(value)
    if value == "TOP" or value == "BOTTOM" or value == "RIGHT" or value == "LEFT" then
        return value
    end
    return "RIGHT"
end

local function GetQuickActivationPosition()
    CurrentDB()
    db.quickActivationPosition = NormalizeQuickActivationPosition(db.quickActivationPosition)
    return db.quickActivationPosition
end

local function GetQuickRevealVector(position, slide)
    if position == "LEFT" then
        return -slide, 0
    elseif position == "TOP" then
        return 0, slide
    elseif position == "BOTTOM" then
        return 0, -slide
    end
    return slide, 0
end

local RATE_OPTIONS = {
    0.5, 1.0, 1.5, 2.0, 2.5,
    3.0, 3.5, 4.0, 4.5, 5.0,
}

local DROPDOWN_NONE_VALUE = "__NONE__"
local EMOTE_CHANNEL_OPTIONS = {
    { value = "EMOTE", label = "/me"   },
    { value = "SAY",   label = "/s"    },
    { value = "RAID",  label = "/raid" },
}

local function BuildUnlockedTorchText(kind, emptyText)
    local entries = OS2.GetUnlockedTorchEntries(kind)
    if #entries == 0 then return "- " .. emptyText end
    local labels = {}
    for _, entry in ipairs(entries) do
        labels[#labels + 1] = "- " .. entry.label
    end
    return table.concat(labels, "\n")
end

local function GetModelOptions()
    CurrentDB()
    local options = { { key = nil, label = "Aucune torche" } }
    local selectedEntry
    if db.modelKey then selectedEntry = OS2.Core.TorchModelByKey[db.modelKey] end
    for _, entry in ipairs(OS2.GetUnlockedTorchEntries("models")) do
        options[#options + 1] = entry
    end
    if selectedEntry then
        local found = false
        for _, entry in ipairs(options) do
            if entry.key == selectedEntry.key then found = true; break end
        end
        if not found then options[#options + 1] = selectedEntry end
    end
    return options
end

local function GetFuelOptions()
    CurrentDB()
    local options = { { key = nil, label = "Insérez un combustible" } }
    local selectedEntry
    if db.crystalKey then selectedEntry = OS2.Core.TorchFuelByKey[db.crystalKey] end
    for _, entry in ipairs(OS2.GetUnlockedTorchEntries("fuels")) do
        options[#options + 1] = entry
    end
    if selectedEntry then
        local found = false
        for _, entry in ipairs(options) do
            if entry.key == selectedEntry.key then found = true; break end
        end
        if not found then options[#options + 1] = selectedEntry end
    end
    return options
end

local function FindOptionIndex(options, selectedKey)
    if not selectedKey then return 1 end
    for i, entry in ipairs(options) do
        if entry.key == selectedKey then return i end
    end
    return 1
end

local function GetCurrentModel()
    CurrentDB()
    return OS2.Core.TorchModelByKey[db.modelKey]
end

local function GetCurrentFuel()
    CurrentDB()
    return OS2.Core.TorchFuelByKey[db.crystalKey]
end

local function GetDrainFactor()
    CurrentDB()
    local model = GetCurrentModel()
    if not model then return 0 end
    return model.mult * (db.drainRate or 1.0)
end

local function GetMaxCharge()
    local fuel = GetCurrentFuel()
    if not fuel then return 0 end
    return fuel.time * 60
end

local function GetRemainingDuration()
    CurrentDB()
    local maxCharge  = GetMaxCharge()
    local drainFactor = GetDrainFactor()
    if maxCharge <= 0 or drainFactor <= 0 then return 0 end
    return (db.remainingCharge or 0) / drainFactor
end

local function ClampRemainingCharge()
    CurrentDB()
    local maxCharge = GetMaxCharge()
    if maxCharge <= 0 then
        db.remaining = 0
        db.remainingCharge = 0
        db.mode = "OFF"
        db.mjPaused = false
        db.resumeMode = "OFF"
        return
    end
    db.remainingCharge = math.max(0, math.min(db.remainingCharge or 0, maxCharge))
    db.remaining = GetRemainingDuration()
    if db.mode == "ON" and db.remainingCharge <= 0 then
        db.remaining = 0
        db.mode = "OFF"
    end
end

local function SyncTorchState(now)
    CurrentDB()
    now = now or GetTime()
    if db.mode == "ON" and not db.mjPaused and (db.remainingCharge or 0) > 0 and db.lastUpdate then
        local elapsed = math.max(0, now - db.lastUpdate)
        if elapsed > 0 then
            db.remainingCharge = math.max(0, db.remainingCharge - (elapsed * GetDrainFactor()))
            if db.remainingCharge <= 0 then
                db.remainingCharge = 0
                db.remaining = 0
                db.mode = "OFF"
                db.resumeMode = "OFF"
                TriggerAuraRules("auraRemoveRules", "RESOURCE_EMPTY")
                SetAuraActiveState(false)
                OS2.Notify("La torche s'est éteinte.", 1, 0.2, 0.2)
                SendTorchEmote("empty")
            end
        end
    end
    ClampRemainingCharge()
    db.lastUpdate = now
end

SendTorchEmote = function(kind)
    local emote = GetEmotes()[kind]
    if not emote or emote == "" or not SendChatMessage then return end
    local channel = CurrentDB().emoteChannel or "EMOTE"
    local formatted = FormatEmoteForChannel(emote, channel)
    if formatted == "" then return end
    SendChatMessage(formatted, channel)
end

------------------------------------------------------------------------
-- UI
------------------------------------------------------------------------
local R = 0

local modelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
modelLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -52)
modelLabel:SetText("Torche")
UI.ApplyLabel(modelLabel)

local torchDropdown = CreateFrame("Frame", "OS2_TorchModelDropdown", panel, "UIDropDownMenuTemplate")
torchDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 2, -66)
UIDropDownMenu_SetWidth(torchDropdown, PANEL_W - 46)
UIDropDownMenu_SetText(torchDropdown, "Aucune torche")
StyleDropdown(torchDropdown)

local fuelLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
fuelLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -114)
fuelLabel:SetText("Combustible")
UI.ApplyLabel(fuelLabel)

local fuelDropdown = CreateFrame("Frame", "OS2_TorchFuelDropdown", panel, "UIDropDownMenuTemplate")
fuelDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 2, -128)
UIDropDownMenu_SetWidth(fuelDropdown, PANEL_W - 46)
UIDropDownMenu_SetText(fuelDropdown, "Insérez un combustible")
StyleDropdown(fuelDropdown)

local rateLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rateLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -176)
rateLabel:SetText("Variateur de temps")
UI.ApplyLabel(rateLabel)

local rateDropdown = CreateFrame("Frame", "OS2_TorchRateDropdown", panel, "UIDropDownMenuTemplate")
rateDropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 2, -190)
UIDropDownMenu_SetWidth(rateDropdown, PANEL_W - 46)
UIDropDownMenu_SetText(rateDropdown, "x1.0")
StyleDropdown(rateDropdown)

local stateText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
stateText:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -236)
stateText:SetJustifyH("LEFT")
UI.ApplyStrongLabel(stateText)

local chargeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
chargeLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -250)
chargeLabel:SetText("Charge restante")
UI.ApplyLabel(chargeLabel)

local chargeBar = CreateFrame("StatusBar", nil, panel)
chargeBar:SetSize(PANEL_W - 28, 18)
chargeBar:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -266)
chargeBar:SetMinMaxValues(0, 100)
chargeBar:SetValue(0)
chargeBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
chargeBar:GetStatusBarTexture():SetHorizTile(false)
chargeBar:SetStatusBarColor(0.84, 0.72, 0.28, 1)

local chargeBarBg = chargeBar:CreateTexture(nil, "BACKGROUND")
chargeBarBg:SetAllPoints()
chargeBarBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local chargeBarText = chargeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
chargeBarText:SetPoint("CENTER", chargeBar, "CENTER", 0, 0)

local powerBtn = CreatePanelButton(panel, PANEL_W - 28, 22, "Allumer")
powerBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -298)

local rechargeBtn = CreatePanelButton(panel, PANEL_W - 28, 22, "Recharger")
rechargeBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", R + 14, -326)

OS2.SetPanelAutoHeight(panel, 348, 16, 352)

------------------------------------------------------------------------
-- Bouton activation rapide
------------------------------------------------------------------------
local quickToggleBtn = CreateFrame("Button", nil, UIParent)
quickToggleBtn:SetSize(30, 30)
quickToggleBtn:SetFrameStrata("DIALOG")
quickToggleBtn.GetQuickRevealOffset = function(self, slide)
    return GetQuickRevealVector(GetQuickActivationPosition(), slide)
end
quickToggleBtn.ApplyQuickAnchor = function(self, offsetX, offsetY)
    local launcher = OS2.Launcher or _G.OS2_Launcher
    if launcher then
        local position = GetQuickActivationPosition()
        if position == "LEFT" then
            self:SetPoint("RIGHT", launcher, "LEFT", -4 + (offsetX or 0), 0 + (offsetY or 0))
        elseif position == "TOP" then
            self:SetPoint("BOTTOM", launcher, "TOP", 0 + (offsetX or 0), 4 + (offsetY or 0))
        elseif position == "BOTTOM" then
            self:SetPoint("TOP", launcher, "BOTTOM", 0 + (offsetX or 0), -4 + (offsetY or 0))
        else
            self:SetPoint("LEFT", launcher, "RIGHT", 4 + (offsetX or 0), 0 + (offsetY or 0))
        end
    end
end

local quickToggleBg = quickToggleBtn:CreateTexture(nil, "BACKGROUND")
quickToggleBg:SetAllPoints()
UI.ApplyWindowBackground(quickToggleBg, 0.92)

local quickToggleIcon = quickToggleBtn:CreateTexture(nil, "ARTWORK")
quickToggleIcon:SetPoint("TOPLEFT",     quickToggleBtn, "TOPLEFT",     3,  -3)
quickToggleIcon:SetPoint("BOTTOMRIGHT", quickToggleBtn, "BOTTOMRIGHT", -3,   3)
quickToggleIcon:SetTexture("Interface/Icons/INV_Torch_Thrown")
quickToggleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local quickToggleBorder = quickToggleBtn:CreateTexture(nil, "OVERLAY")
quickToggleBorder:SetAllPoints()
quickToggleBorder:SetTexture("Interface/Buttons/UI-ActionButton-Border")
quickToggleBorder:SetBlendMode("ADD")

local quickToggleHL = quickToggleBtn:CreateTexture(nil, "HIGHLIGHT")
quickToggleHL:SetTexture("Interface/Buttons/ButtonHilight-Square")
quickToggleHL:SetAllPoints()
quickToggleHL:SetBlendMode("ADD")

AttachQuickReveal(quickToggleBtn)

local quickRateDropdown = CreateFrame("Frame", "OS2_TorchQuickRateDropdown", UIParent, "UIDropDownMenuTemplate")
quickRateDropdown:SetFrameStrata("DIALOG")
quickRateDropdown:ClearAllPoints()
quickRateDropdown.GetQuickRevealOffset = function(self, slide)
    return GetQuickRevealVector(GetQuickActivationPosition(), slide)
end
quickRateDropdown.ApplyQuickAnchor = function(self, offsetX, offsetY)
    local launcher = OS2.Launcher or _G.OS2_Launcher
    CurrentDB()
    local position = GetQuickActivationPosition()
    if db.quickActivation == true then
        if position == "LEFT" then
            self:SetPoint("RIGHT", quickToggleBtn, "LEFT", 2 + (offsetX or 0), -2 + (offsetY or 0))
        elseif position == "TOP" then
            self:SetPoint("BOTTOM", quickToggleBtn, "TOP", 0 + (offsetX or 0), 2 + (offsetY or 0))
        elseif position == "BOTTOM" then
            self:SetPoint("TOP", quickToggleBtn, "BOTTOM", 0 + (offsetX or 0), -2 + (offsetY or 0))
        else
            self:SetPoint("LEFT", quickToggleBtn, "RIGHT", 2 + (offsetX or 0), -2 + (offsetY or 0))
        end
    elseif launcher then
        if position == "LEFT" then
            self:SetPoint("RIGHT", launcher, "LEFT", -6 + (offsetX or 0), -2 + (offsetY or 0))
        elseif position == "TOP" then
            self:SetPoint("BOTTOM", launcher, "TOP", 0 + (offsetX or 0), 6 + (offsetY or 0))
        elseif position == "BOTTOM" then
            self:SetPoint("TOP", launcher, "BOTTOM", 0 + (offsetX or 0), -6 + (offsetY or 0))
        else
            self:SetPoint("LEFT", launcher, "RIGHT", 6 + (offsetX or 0), -2 + (offsetY or 0))
        end
    end
end
UIDropDownMenu_SetWidth(quickRateDropdown, 58)
UIDropDownMenu_SetText(quickRateDropdown, FormatRateLabel(1.0))
StyleQuickDropdown(quickRateDropdown)
AttachQuickReveal(quickRateDropdown)

------------------------------------------------------------------------
-- Panneau de configuration
------------------------------------------------------------------------
local configPanel = CreateFrame("Frame", nil, UIParent)
configPanel:SetSize(PANEL_W, BASE_PANEL_H)
configPanel:SetFrameStrata("DIALOG")
configPanel:SetFrameLevel(panel:GetFrameLevel() + 20)
configPanel:Hide()
OS2.AttachOverlayFade(configPanel)

local configBg = configPanel:CreateTexture(nil, "BACKGROUND")
configBg:SetAllPoints()
UI.ApplyWindowBackground(configBg, OS2.EnsureDB().panelOpacity or 0.65)
if OS2.RegisterWindowFrame then
    OS2.RegisterWindowFrame(configPanel, configBg)
end

local configTitle = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
configTitle:SetPoint("TOP", configPanel, "TOP", 0, -12)
configTitle:SetText("Paramètres Torche")
UI.ApplyTitle(configTitle)

local closeConfigBtn = UI.CreateCloseButton(configPanel)

local CONFIG_TAB_H      = 26
local CONFIG_TAB_W      = math.floor(PANEL_W / 4)
local CONFIG_TABS       = { "Torche", "Combustible", "Options", "Débug" }
local CONFIG_HEADER_H   = 35 + CONFIG_TAB_H + 1
local CONFIG_BOTTOM_PADDING = 18

local configTabButtons  = {}
local configTabContent  = {}
local selectedConfigTab = 1
local UpdateConfigPanelHeight

local function SelectConfigTab(index)
    selectedConfigTab = index
    for i, btn in ipairs(configTabButtons) do
        local active = (i == index)
        UI.ApplyTabState(btn, active)
        configTabContent[i]:SetShown(active)
    end
    if UpdateConfigPanelHeight then UpdateConfigPanelHeight() end
end

for i, name in ipairs(CONFIG_TABS) do
    local btn = CreateFrame("Button", nil, configPanel)
    btn:SetSize(CONFIG_TAB_W, CONFIG_TAB_H)
    btn:SetPoint("TOPLEFT", configPanel, "TOPLEFT", (i - 1) * CONFIG_TAB_W, -35)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints()
    label:SetText(name)
    UI.ApplyMutedText(label)
    btn.label = label

    local line = btn:CreateTexture(nil, "OVERLAY")
    line:SetHeight(2)
    line:SetColorTexture(unpack(UI.colors.tabLine))
    line:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 0)
    line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.line = line

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(unpack(UI.colors.tabHighlight))
    hl:SetAllPoints()

    local content = CreateFrame("Frame", nil, configPanel)
    content:SetPoint("TOPLEFT",     configPanel, "TOPLEFT",     0, -(35 + CONFIG_TAB_H + 1))
    content:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", 0, 0)
    content:Hide()
    configTabContent[i] = content

    btn:SetScript("OnClick", function() SelectConfigTab(i) end)
    configTabButtons[i] = btn
end

local configSep = configPanel:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(configSep)
configSep:SetHeight(1)
configSep:SetPoint("TOPLEFT",  configPanel, "TOPLEFT",  0, -(35 + CONFIG_TAB_H))
configSep:SetPoint("TOPRIGHT", configPanel, "TOPRIGHT", 0, -(35 + CONFIG_TAB_H))

local torchTab   = configTabContent[1]
local fuelTab    = configTabContent[2]
local optionsTab = configTabContent[3]
local debugTab   = configTabContent[4]

------------------------------------------------------------------------
-- Onglet 1 : Torche
------------------------------------------------------------------------
local unlockedTorchesText = torchTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
unlockedTorchesText:SetPoint("TOPLEFT", torchTab, "TOPLEFT", 14, -14)
unlockedTorchesText:SetPoint("RIGHT",   torchTab, "RIGHT",   -14, 0)
unlockedTorchesText:SetJustifyH("LEFT")
unlockedTorchesText:SetJustifyV("TOP")
UI.ApplyBodyText(unlockedTorchesText)

------------------------------------------------------------------------
-- Onglet 2 : Combustible
------------------------------------------------------------------------
local unlockedFuelsText = fuelTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
unlockedFuelsText:SetPoint("TOPLEFT", fuelTab, "TOPLEFT", 14, -14)
unlockedFuelsText:SetPoint("RIGHT",   fuelTab, "RIGHT",   -14, 0)
unlockedFuelsText:SetJustifyH("LEFT")
unlockedFuelsText:SetJustifyV("TOP")
UI.ApplyBodyText(unlockedFuelsText)

------------------------------------------------------------------------
-- Onglet 3 : Options
------------------------------------------------------------------------
local quickActivationHelp = optionsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
quickActivationHelp:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, -14)
quickActivationHelp:SetPoint("RIGHT",   optionsTab, "RIGHT",   -14, 0)
quickActivationHelp:SetJustifyH("LEFT")
quickActivationHelp:SetJustifyV("TOP")
quickActivationHelp:SetText("Permet d'allumer ou d'éteindre la torche sans rouvrir le menu.")
UI.ApplyBodyText(quickActivationHelp)

local quickActivationCheck, quickActivationLabel = UI.CreateStyledCheckbox(optionsTab, "Activation rapide")
quickActivationCheck:SetSize(18, 18)
quickActivationCheck:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, -52)
quickActivationLabel:SetPoint("LEFT", quickActivationCheck, "RIGHT", 6, 0)

local quickPositionLabel = optionsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
quickPositionLabel:SetText("Position du raccourci")
UI.ApplyLabel(quickPositionLabel)
quickPositionLabel:Hide()

local quickPositionDropdown = CreateFrame("Frame", "OS2_TorchQuickPositionDropdown", optionsTab, "UIDropDownMenuTemplate")
UIDropDownMenu_SetWidth(quickPositionDropdown, PANEL_W - 46)
UIDropDownMenu_SetText(quickPositionDropdown, "À droite")
StyleDropdown(quickPositionDropdown)
quickPositionDropdown:Hide()

local emoteConfigHelp = optionsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
emoteConfigHelp:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, -88)
emoteConfigHelp:SetPoint("RIGHT",   optionsTab, "RIGHT",   -14, 0)
emoteConfigHelp:SetJustifyH("LEFT")
emoteConfigHelp:SetJustifyV("TOP")
emoteConfigHelp:SetText("Personnalisez les émotes envoyées lors de l'utilisation de la torche.")
UI.ApplyBodyText(emoteConfigHelp)

local emoteConfigBtn = CreatePanelButton(optionsTab, PANEL_W - 28, 22, "Émotes")
emoteConfigBtn:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, -118)

local emoteChannelLabel = optionsTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
emoteChannelLabel:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, -156)
emoteChannelLabel:SetText("Canal de sortie")
UI.ApplyLabel(emoteChannelLabel)

local emoteChannelDropdown = CreateFrame("Frame", "OS2_TorchEmoteChannelDropdown", optionsTab, "UIDropDownMenuTemplate")
emoteChannelDropdown:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 2, -170)
UIDropDownMenu_SetWidth(emoteChannelDropdown, PANEL_W - 46)
UIDropDownMenu_SetText(emoteChannelDropdown, "/me")
StyleDropdown(emoteChannelDropdown)

------------------------------------------------------------------------
-- Onglet 4 : Débug
------------------------------------------------------------------------
local debugTabInfo = debugTab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
debugTabInfo:SetPoint("TOPLEFT", debugTab, "TOPLEFT", 14, -14)
debugTabInfo:SetPoint("RIGHT",   debugTab, "RIGHT",   -14, 0)
debugTabInfo:SetJustifyH("LEFT")
debugTabInfo:SetJustifyV("TOP")
debugTabInfo:SetText("Si votre torche rencontre un problème, si le temps ne s'écoule plus correctement ou si elle reste bloquée, utilisez le bouton ci-dessous.")
UI.ApplyBodyText(debugTabInfo)

local resetTorchBtn = CreatePanelButton(debugTab, PANEL_W - 28, 20, "Débug")
resetTorchBtn:SetPoint("TOPLEFT", debugTab, "TOPLEFT", 14, -96)

------------------------------------------------------------------------
-- Panneau d'émotes
------------------------------------------------------------------------
local emotePanel = CreateFrame("Frame", nil, UIParent)
emotePanel:SetSize(PANEL_W, EMOTE_PANEL_H)
emotePanel:SetFrameStrata("DIALOG")
emotePanel:SetFrameLevel(configPanel:GetFrameLevel() + 10)
emotePanel:Hide()
OS2.AttachOverlayFade(emotePanel)

local emoteBg = emotePanel:CreateTexture(nil, "BACKGROUND")
emoteBg:SetAllPoints()
UI.ApplyWindowBackground(emoteBg, OS2.EnsureDB().panelOpacity or 0.65)
if OS2.RegisterWindowFrame then
    OS2.RegisterWindowFrame(emotePanel, emoteBg)
end

local emoteTitle = emotePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
emoteTitle:SetPoint("TOP", emotePanel, "TOP", 0, -12)
emoteTitle:SetText("Émotes Torche")
UI.ApplyTitle(emoteTitle)

local closeEmoteBtn = UI.CreateCloseButton(emotePanel)

local emoteTitleSep = emotePanel:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(emoteTitleSep)
emoteTitleSep:SetHeight(1)
emoteTitleSep:SetPoint("TOPLEFT",  emotePanel, "TOPLEFT",  0, -34)
emoteTitleSep:SetPoint("TOPRIGHT", emotePanel, "TOPRIGHT", 0, -34)

local emoteInfo = emotePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
emoteInfo:SetPoint("TOPLEFT", emotePanel, "TOPLEFT", 14, -44)
emoteInfo:SetPoint("RIGHT",   emotePanel, "RIGHT",   -14, 0)
emoteInfo:SetJustifyH("LEFT")
emoteInfo:SetJustifyV("TOP")
emoteInfo:SetText("Personnalisez les émotes envoyées quand vous utilisez votre torche.")
UI.ApplyBodyText(emoteInfo)

------------------------------------------------------------------------
-- Lignes d'émotes
------------------------------------------------------------------------
local EMOTE_ROW_BTN_W  = 72
local EMOTE_ROW_BTN_H  = 18
local EMOTE_ROW_VAL_H  = 28
local EMOTE_ROW_H      = EMOTE_ROW_BTN_H + 4 + EMOTE_ROW_VAL_H
local EMOTE_ROW_GAP    = 16
local EMOTE_ROWS_START = -82
local EMOTE_FOOTER_H   = 50

local function CreateEmoteRow(parent, labelText, key, rowIndex)
    local y = EMOTE_ROWS_START - (rowIndex - 1) * (EMOTE_ROW_H + EMOTE_ROW_GAP)

    if rowIndex > 1 then
        local sep = parent:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(sep, true)
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  parent, "TOPLEFT",  14, y + EMOTE_ROW_GAP / 2)
        sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, y + EMOTE_ROW_GAP / 2)
    end

    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  14, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, y)
    row:SetHeight(EMOTE_ROW_H)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    UI.ApplyStrongLabel(label)
    label:SetText(labelText)

    local button = CreatePanelButton(row, EMOTE_ROW_BTN_W, EMOTE_ROW_BTN_H, "Modifier")
    button:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

    local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("TOPLEFT",  row, "TOPLEFT",  0, -(EMOTE_ROW_BTN_H + 4))
    value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -(EMOTE_ROW_BTN_H + 4))
    value:SetJustifyH("LEFT")
    value:SetJustifyV("TOP")
    UI.ApplyMutedText(value)

    row.key       = key
    row.labelText = labelText
    row.button    = button
    row.valueText = value

    return row
end

local EMOTE_DEFS = {
    { label = "Allumer",               key = "on"       },
    { label = "Éteindre",             key = "off"      },
    { label = "Recharger",            key = "recharge" },
    { label = "Changer de combustible", key = "swap"   },
    { label = "Éteinte",             key = "empty"    },
}

local emoteRows = {}
for i, def in ipairs(EMOTE_DEFS) do
    emoteRows[i] = CreateEmoteRow(emotePanel, def.label, def.key, i)
end

local EMOTE_FOOTER_H = 78
local computedEmoteH = -EMOTE_ROWS_START
    + #EMOTE_DEFS * (EMOTE_ROW_H + EMOTE_ROW_GAP)
    - EMOTE_ROW_GAP
    + EMOTE_FOOTER_H
emotePanel:SetHeight(computedEmoteH)

local emoteResetBtn = CreatePanelButton(emotePanel, PANEL_W - 28, 22, "Restaurer les valeurs par défaut")
emoteResetBtn:SetPoint("BOTTOMLEFT", emotePanel, "BOTTOMLEFT", 14, 42)

local emoteBackBtn = CreatePanelButton(emotePanel, PANEL_W - 28, 22, "Retour")
emoteBackBtn:SetPoint("BOTTOMLEFT", emotePanel, "BOTTOMLEFT", 14, 14)

------------------------------------------------------------------------
-- Hauteur dynamique du panneau de config
------------------------------------------------------------------------
local function GetFrameBottom(frame, fallbackHeight)
    local _, _, _, _, y = frame:GetPoint(1)
    local topOffset = math.abs(y or 0)
    local height = fallbackHeight or 0
    if frame.GetStringHeight then height = math.max(height, frame:GetStringHeight() or 0) end
    if frame.GetHeight       then height = math.max(height, frame:GetHeight()       or 0) end
    return topOffset + height
end

local function GetConfigTabHeight(index)
    local contentBottom = 0
    if index == 1 then
        contentBottom = GetFrameBottom(unlockedTorchesText)
    elseif index == 2 then
        contentBottom = GetFrameBottom(unlockedFuelsText)
    elseif index == 3 then
        contentBottom = math.max(
            GetFrameBottom(quickActivationHelp),
            GetFrameBottom(quickActivationCheck, 24),
            quickPositionLabel:IsShown() and GetFrameBottom(quickPositionLabel) or 0,
            quickPositionDropdown:IsShown() and GetFrameBottom(quickPositionDropdown, 32) or 0,
            GetFrameBottom(emoteConfigHelp),
            GetFrameBottom(emoteConfigBtn),
            GetFrameBottom(emoteChannelLabel),
            GetFrameBottom(emoteChannelDropdown, 32)
        )
    else
        contentBottom = math.max(
            GetFrameBottom(debugTabInfo),
            GetFrameBottom(resetTorchBtn)
        )
    end
    return math.min(BASE_PANEL_H, math.ceil(CONFIG_HEADER_H + contentBottom + CONFIG_BOTTOM_PADDING))
end

UpdateConfigPanelHeight = function()
    configPanel:SetHeight(GetConfigTabHeight(selectedConfigTab))
end

SelectConfigTab(1)

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
local function RefreshEmotePanel()
    local emotes = GetEmotes()
    for _, row in ipairs(emoteRows) do
        row.valueText:SetText(emotes[row.key] or "")
    end
end

local function RefreshConfigPanel()
    CurrentDB()
    quickActivationCheck:SetChecked(db.quickActivation == true)
    db.quickActivationPosition = NormalizeQuickActivationPosition(db.quickActivationPosition)
    local showQuickPosition = db.quickActivation == true
    quickPositionLabel:SetShown(showQuickPosition)
    quickPositionDropdown:SetShown(showQuickPosition)
    if showQuickPosition then
        quickPositionLabel:ClearAllPoints()
        quickPositionLabel:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, -82)
        quickPositionDropdown:ClearAllPoints()
        quickPositionDropdown:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 2, -96)
    end
    local emoteHelpY = showQuickPosition and -136 or -88
    local emoteButtonY = showQuickPosition and -166 or -118
    local emoteChannelLabelY = showQuickPosition and -204 or -156
    local emoteChannelDropdownY = showQuickPosition and -218 or -170
    emoteConfigHelp:ClearAllPoints()
    emoteConfigHelp:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, emoteHelpY)
    emoteConfigHelp:SetPoint("RIGHT", optionsTab, "RIGHT", -14, 0)
    emoteConfigBtn:ClearAllPoints()
    emoteConfigBtn:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, emoteButtonY)
    emoteChannelLabel:ClearAllPoints()
    emoteChannelLabel:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 14, emoteChannelLabelY)
    emoteChannelDropdown:ClearAllPoints()
    emoteChannelDropdown:SetPoint("TOPLEFT", optionsTab, "TOPLEFT", 2, emoteChannelDropdownY)
    if not ((UIDROPDOWNMENU_OPEN_MENU == quickPositionDropdown)
        or (quickPositionDropdown.Button and UIDROPDOWNMENU_OPEN_MENU == quickPositionDropdown.Button)
        or (UIDROPDOWNMENU_INIT_MENU == quickPositionDropdown)
        or (quickPositionDropdown.Button and UIDROPDOWNMENU_INIT_MENU == quickPositionDropdown.Button)) then
        UIDropDownMenu_SetSelectedValue(quickPositionDropdown, db.quickActivationPosition)
        for _, option in ipairs(QUICK_POSITION_OPTIONS) do
            if option.value == db.quickActivationPosition then
                UIDropDownMenu_SetText(quickPositionDropdown, option.label)
                break
            end
        end
    end
    if not ((UIDROPDOWNMENU_OPEN_MENU == emoteChannelDropdown)
        or (emoteChannelDropdown.Button and UIDROPDOWNMENU_OPEN_MENU == emoteChannelDropdown.Button)
        or (UIDROPDOWNMENU_INIT_MENU == emoteChannelDropdown)
        or (emoteChannelDropdown.Button and UIDROPDOWNMENU_INIT_MENU == emoteChannelDropdown.Button)) then
        UIDropDownMenu_SetSelectedValue(emoteChannelDropdown, db.emoteChannel or "EMOTE")
        UIDropDownMenu_SetText(emoteChannelDropdown,
            (db.emoteChannel == "SAY" and "/s") or (db.emoteChannel == "RAID" and "/raid") or "/me")
    end
    unlockedTorchesText:SetText("Torches débloquées :\n"     .. BuildUnlockedTorchText("models", "Aucune"))
    unlockedFuelsText:SetText("Combustibles débloqués :\n"   .. BuildUnlockedTorchText("fuels",  "Aucun"))
    RefreshEmotePanel()
    UpdateConfigPanelHeight()
end

OS2.RefreshTorchConfigPanel = RefreshConfigPanel

------------------------------------------------------------------------
-- Shell
------------------------------------------------------------------------
local shell = OS2.BuildModuleShell(panel, {
    title = "Torche",
    onSettings = function()
        local configOpen = OS2.IsSettingsPanelOpen and OS2.IsSettingsPanelOpen(configPanel)
        local emoteOpen  = OS2.IsSettingsPanelOpen and OS2.IsSettingsPanelOpen(emotePanel)
        if configOpen or emoteOpen then
            if emoteOpen  then OS2.HideSettingsPanel(emotePanel)  end
            if configOpen then OS2.HideSettingsPanel(configPanel) end
            return
        end
        RefreshConfigPanel()
        OS2.ShowSettingsPanel(configPanel, OS2.Launcher)
    end,
})

if shell then
    shell.title:ClearAllPoints()
    shell.title:SetPoint("TOP", panel, "TOP", 0, -12)
    shell.gear:ClearAllPoints()
    shell.gear:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    shell.separator:ClearAllPoints()
    shell.separator:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -34)
    shell.separator:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -34)
end

------------------------------------------------------------------------
-- Popup d'édition d'émote
------------------------------------------------------------------------
StaticPopupDialogs["OS2_EDIT_TORCH_EMOTE"] = {
    text = "%s",
    button1 = "Valider",
    button2 = CANCEL,
    hasEditBox = 1,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
    OnShow = function(self)
        local emotes = GetEmotes()
        self.editBox:SetText(emotes[emoteEditContext.key] or "")
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    OnAccept = function(self)
        local emotes = GetEmotes()
        local value = Trim(self.editBox:GetText())
        emotes[emoteEditContext.key] = value
        RefreshConfigPanel()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

------------------------------------------------------------------------
-- Initialisations dropdowns
------------------------------------------------------------------------
UIDropDownMenu_Initialize(emoteChannelDropdown, function(self, level)
    local currentValue = CurrentDB().emoteChannel or "EMOTE"
    for _, option in ipairs(EMOTE_CHANNEL_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        info.text    = option.label
        info.value   = option.value
        info.func    = function()
            CurrentDB().emoteChannel = option.value
            UIDropDownMenu_SetSelectedValue(emoteChannelDropdown, option.value)
            UIDropDownMenu_SetText(emoteChannelDropdown, option.label)
        end
        info.checked = (currentValue == option.value)
        UIDropDownMenu_AddButton(info, level)
    end
end)

local function GetSelectedEntry(options, selectedKey)
    return options[FindOptionIndex(options, selectedKey)]
end

local function IsAnyDropdownListVisible()
    return (_G.DropDownList1 and _G.DropDownList1:IsShown())
        or (_G.DropDownList2 and _G.DropDownList2:IsShown())
end

local function IsDropdownOpen(dropdown)
    if IsAnyDropdownListVisible() then return true end
    return UIDROPDOWNMENU_OPEN_MENU == dropdown
        or (dropdown.Button and UIDROPDOWNMENU_OPEN_MENU == dropdown.Button)
        or UIDROPDOWNMENU_INIT_MENU == dropdown
        or (dropdown.Button and UIDROPDOWNMENU_INIT_MENU == dropdown.Button)
end

local function IsAnyTorchDropdownOpen()
    return IsDropdownOpen(torchDropdown)
        or IsDropdownOpen(fuelDropdown)
        or IsDropdownOpen(rateDropdown)
        or IsDropdownOpen(quickRateDropdown)
        or IsDropdownOpen(emoteChannelDropdown)
end

local function NormalizeDropdownValue(value)
    return value or DROPDOWN_NONE_VALUE
end

------------------------------------------------------------------------
-- Logique d'état
------------------------------------------------------------------------
local function RefreshStatus()
    CurrentDB()
    local maxCharge = GetMaxCharge()
    local percent = 0
    if maxCharge > 0 then
        percent = math.max(0, math.min(100, ((db.remainingCharge or 0) / maxCharge) * 100))
    end
    if IsMJPaused() then
        stateText:SetText("État : Pause (MJ) - " .. (IsPausedActive() and "ON" or "OFF"))
    else
        stateText:SetText("État : " .. (db.mode or "OFF"))
    end
    chargeBar:SetValue(percent)
    chargeBarText:SetText(string.format("%.0f%%", percent))
end

local function RefreshPowerButton()
    CurrentDB()
    if IsMJPaused() then
        powerBtn:SetText(IsPausedActive() and "Éteindre" or "Allumer")
        powerBtn:SetAlpha(1)
        powerBtn:EnableMouse(true)
        return
    end
    if db.mode == "ON" then
        powerBtn:SetText("Éteindre")
        powerBtn:SetAlpha(1)
        powerBtn:EnableMouse(true)
    elseif (db.remainingCharge or 0) <= 0 and (GetMaxCharge and GetMaxCharge() or 0) > 0 then
        powerBtn:SetText("Recharger d'abord")
        powerBtn:SetAlpha(0.4)
        powerBtn:EnableMouse(false)
    else
        powerBtn:SetText("Allumer")
        powerBtn:SetAlpha(1)
        powerBtn:EnableMouse(true)
    end
end

local function RefreshQuickToggleButton()
    CurrentDB()
    if quickToggleIcon.SetDesaturated then
        quickToggleIcon:SetDesaturated(not IsPausedActive())
    end
    if IsMJPaused() then
        if IsPausedActive() then
            quickToggleIcon:SetAlpha(1)
            quickToggleBorder:SetVertexColor(1.0, 0.82, 0.2, 0.9)
        else
            quickToggleIcon:SetAlpha(0.7)
            quickToggleBorder:SetVertexColor(0.8, 0.7, 0.4, 0.35)
        end
        return
    end
    if db.mode == "ON" then
        quickToggleIcon:SetAlpha(1)
        quickToggleBorder:SetVertexColor(0.35, 0.95, 0.45, 0.85)
    else
        quickToggleIcon:SetAlpha(0.7)
        quickToggleBorder:SetVertexColor(0.8, 0.7, 0.4, 0.35)
    end
end

local function ShouldShowQuickToggle()
    CurrentDB()
    return db.quickActivation == true
        and OS2.IsModuleEnabled("torche")
        and not (OS2.IsLauncherMenuOpen and OS2.IsLauncherMenuOpen())
end

local function ShouldShowQuickRate()
    CurrentDB()
    return OS2.IsModuleEnabled("torche")
        and not (OS2.IsLauncherMenuOpen and OS2.IsLauncherMenuOpen())
        and (db.mode == "ON" or (IsMJPaused() and IsPausedActive()))
end

local function UpdateRateDropdown(value)
    UIDropDownMenu_SetSelectedValue(rateDropdown, value)
    UIDropDownMenu_SetText(rateDropdown, FormatRateLabel(value))
    UIDropDownMenu_SetSelectedValue(quickRateDropdown, value)
    UIDropDownMenu_SetText(quickRateDropdown, FormatRateLabel(value))
end

function OS2.RefreshTorchQuickControls()
    RefreshQuickToggleButton()
    if ShouldShowQuickToggle() then
        ShowQuickFrame(quickToggleBtn)
    else
        HideQuickFrame(quickToggleBtn)
    end
    if ShouldShowQuickRate() then
        ShowQuickFrame(quickRateDropdown)
    else
        HideQuickFrame(quickRateDropdown)
    end
end

local function ResetTorchState()
    CurrentDB()
    db.modelKey      = nil
    db.crystalKey    = nil
    db.mode          = "OFF"
    db.mjPaused      = false
    db.resumeMode    = "OFF"
    db.pausedActive  = nil
    db.remaining     = 0
    db.remainingCharge = 0
    db.drainRate     = 1.0
    db.lastUpdate    = GetTime()
end

local function SetDrainRate(value)
    CurrentDB()
    SyncTorchState()
    db.drainRate = value
    ClampRemainingCharge()
    RefreshStatus()
    UpdateRateDropdown(value)
    RefreshPowerButton()
    RefreshQuickToggleButton()
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
end

local function PauseTorchByMJ(message, effect)
    CurrentDB()
    SyncTorchState()
    effect = (effect == "PAUSE_FORCE_OFF") and "PAUSE_FORCE_OFF" or "PAUSE"
    if db.mjPaused or db.mode == "PAUSE" then
        local wasAuraActive = db.auraActive
        local removed = TriggerAuraRules("auraRemoveRules", "DISABLE_PHRASE", message)
        local applied = TriggerAuraRules("auraApplyRules", "DISABLE_PHRASE", message)
        SetAuraActiveState(ResolveAuraStateAfterRules(wasAuraActive, removed, applied))
        if effect == "PAUSE_FORCE_OFF" then
            TriggerAuraRules("auraRemoveRules", "DEACTIVATE")
            SetAuraActiveState(false)
        end
        db.pausedActive = db.auraActive == true
        db.resumeMode = db.pausedActive and "ON" or "OFF"
        RefreshQuickToggleButton()
        if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
        if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
        return
    end
    db.resumeMode = (db.mode == "ON") and "ON" or "OFF"
    db.mjPaused   = true
    db.mode       = "PAUSE"
    db.lastUpdate = GetTime()
    local wasAuraActive = db.auraActive
    local removed = TriggerAuraRules("auraRemoveRules", "DISABLE_PHRASE", message)
    local applied = TriggerAuraRules("auraApplyRules", "DISABLE_PHRASE", message)
    SetAuraActiveState(ResolveAuraStateAfterRules(wasAuraActive, removed, applied))
    if effect == "PAUSE_FORCE_OFF" then
        TriggerAuraRules("auraRemoveRules", "DEACTIVATE")
        SetAuraActiveState(false)
    end
    db.pausedActive = db.auraActive == true
    db.resumeMode = db.pausedActive and "ON" or "OFF"
    OS2.Notify("L'écoulement du temps de votre torche a été arrêté par le MJ.")
    RefreshQuickToggleButton()
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
    if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
end

local function ResumeTorchAfterMJ(message)
    CurrentDB()
    if not db.mjPaused and db.mode ~= "PAUSE" then
        local wasAuraActive = db.auraActive
        local removed = TriggerAuraRules("auraRemoveRules", "ENABLE_PHRASE", message)
        local applied = TriggerAuraRules("auraApplyRules", "ENABLE_PHRASE", message)
        SetAuraActiveState(ResolveAuraStateAfterRules(wasAuraActive, removed, applied))
        return
    end
    db.mjPaused   = false
    db.mode       = (db.resumeMode == "ON") and "ON" or "OFF"
    db.pausedActive = nil
    db.lastUpdate = GetTime()
    ClampRemainingCharge()
    local wasAuraActive = db.auraActive
    local removed = TriggerAuraRules("auraRemoveRules", "ENABLE_PHRASE", message)
    local applied = TriggerAuraRules("auraApplyRules", "ENABLE_PHRASE", message)
    SetAuraActiveState(ResolveAuraStateAfterRules(wasAuraActive, removed, applied))
    OS2.Notify("L'écoulement du temps de votre torche a été remis en fonctionnement par le MJ.")
    RefreshQuickToggleButton()
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
    if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
end

UpdateSelectionDropdown = function(dropdown, options, selectedKey, defaultLabel)
    local entry = GetSelectedEntry(options, selectedKey)
    local selectedIndex = FindOptionIndex(options, selectedKey)
    UIDropDownMenu_SetSelectedID(dropdown, selectedIndex)
    UIDropDownMenu_SetSelectedValue(dropdown, NormalizeDropdownValue(entry and entry.key or nil))
    UIDropDownMenu_SetText(dropdown, (entry and entry.label) or defaultLabel)
end

local function SelectOption(field, options, index)
    CurrentDB()
    SyncTorchState()
    local entry = options[index] or options[1]

    local swapEmote = false
    if field == "crystalKey" then
        local oldKey = db.crystalKey
        if oldKey then
            db.crystalCharges = db.crystalCharges or {}
            db.crystalCharges[oldKey] = db.remainingCharge or 0
            if entry.key and entry.key ~= oldKey then swapEmote = true end
        end
    end

    db[field] = entry.key

    if not entry.key then
        db.mode       = "OFF"
        db.mjPaused   = false
        db.resumeMode = "OFF"
        db.pausedActive = nil
        db.lastUpdate = GetTime()
        if field == "crystalKey" then
            db.remaining      = 0
            db.remainingCharge = 0
        end
    elseif field == "crystalKey" then
        db.crystalCharges = db.crystalCharges or {}
        local fuel      = OS2.Core.TorchFuelByKey[entry.key]
        local maxCharge = fuel and (fuel.time * 60) or 0
        local saved     = db.crystalCharges[entry.key]
        db.remainingCharge = (saved ~= nil)
            and math.max(0, math.min(saved, maxCharge))
            or  maxCharge
        db.lastUpdate = GetTime()
    end

    ClampRemainingCharge()

    if field == "modelKey" then
        UpdateSelectionDropdown(torchDropdown, options, db.modelKey,   "Aucune torche")
    elseif field == "crystalKey" then
        UpdateSelectionDropdown(fuelDropdown,  options, db.crystalKey, "Insérez un combustible")
    end

    if swapEmote then SendTorchEmote("swap") end
    if OS2.RefreshTorchPanel then OS2.RefreshTorchPanel() end
end

local function FormatDropdownItemLabel(label, isSelected)
    if isSelected then return "|cffd7b35f>  " .. label .. "|r" end
    return "    " .. label
end

UIDropDownMenu_Initialize(torchDropdown, function(self, level)
    local options = GetModelOptions()
    local selectedIndex = FindOptionIndex(options, CurrentDB().modelKey)
    for index, entry in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        local isSelected = (index == selectedIndex)
        info.text = FormatDropdownItemLabel(entry.label, isSelected)
        info.value = NormalizeDropdownValue(entry.key)
        info.notCheckable = true
        info.func = function() SelectOption("modelKey", options, index) end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_Initialize(fuelDropdown, function(self, level)
    local options = GetFuelOptions()
    local selectedIndex = FindOptionIndex(options, CurrentDB().crystalKey)
    for index, entry in ipairs(options) do
        local info = UIDropDownMenu_CreateInfo()
        local isSelected = (index == selectedIndex)
        info.text = FormatDropdownItemLabel(entry.label, isSelected)
        info.value = NormalizeDropdownValue(entry.key)
        info.notCheckable = true
        info.func = function() SelectOption("crystalKey", options, index) end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_Initialize(rateDropdown, function(self, level)
    local currentRate = (CurrentDB().drainRate or 1.0)
    for _, value in ipairs(RATE_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        local isSelected = (currentRate == value)
        info.text = FormatDropdownItemLabel(FormatRateLabel(value), isSelected)
        info.value = value
        info.notCheckable = true
        info.func = function() SetDrainRate(value) end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_Initialize(quickRateDropdown, function(self, level)
    local currentRate = (CurrentDB().drainRate or 1.0)
    for _, value in ipairs(RATE_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        local isSelected = (currentRate == value)
        info.text = FormatDropdownItemLabel(FormatRateLabel(value), isSelected)
        info.value = value
        info.notCheckable = true
        info.func = function() SetDrainRate(value) end
        UIDropDownMenu_AddButton(info, level)
    end
end)

------------------------------------------------------------------------
-- Boutons principaux
------------------------------------------------------------------------
local function TriggerTorchPowerToggle()
    CurrentDB()
    SyncTorchState()
    if IsMJPaused() then
        if IsPausedActive() then
            db.pausedActive = false
            db.resumeMode = "OFF"
            local removed = TriggerAuraRules("auraRemoveRules", "DEACTIVATE")
            SetAuraActiveState(false)
            if removed > 0 then
                OS2.Notify("L'aura de votre torche a été désactivée sans reprendre le timer.")
            end
            SendTorchEmote("off")
        else
            local maxCharge = GetMaxCharge()
            if maxCharge <= 0 or GetDrainFactor() <= 0 then
                OS2.Notify("Sélectionnez une torche et un combustible avant de lancer le système.", 1, 0.2, 0.2)
                return
            end

            for _, entry in ipairs(GetSelectedActivationItems()) do
                if not HasRequiredInventoryItem(entry.item, entry.label) then
                    return
                end
            end

            if (db.remainingCharge or 0) <= 0 then
                OS2.Notify("La torche est vide. Rechargez-la avant de l'allumer.", 1, 0.5, 0.1)
                RefreshPowerButton()
                return
            end

            db.pausedActive = true
            db.resumeMode = "ON"
            db.remaining = GetRemainingDuration()
            local applied = TriggerAuraRules("auraApplyRules", "ACTIVATE")
            if applied > 0 then
                SetAuraActiveState(true)
                OS2.Notify("L'aura de votre torche a été relancée sans reprendre le timer.")
            end
            SendTorchEmote("on")
        end
        db.lastUpdate = GetTime()
        RefreshStatus()
        RefreshPowerButton()
        RefreshQuickToggleButton()
        if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
        return
    end
    if db.mode == "ON" then
        db.mode       = "OFF"
        db.resumeMode = "OFF"
        db.lastUpdate = GetTime()
        RefreshStatus()
        RefreshPowerButton()
        RefreshQuickToggleButton()
        if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
        TriggerAuraRules("auraRemoveRules", "DEACTIVATE")
        SetAuraActiveState(false)
        SendTorchEmote("off")
        return
    end
    local maxCharge = GetMaxCharge()
    if maxCharge <= 0 or GetDrainFactor() <= 0 then
        OS2.Notify("Sélectionnez une torche et un combustible avant de lancer le système.", 1, 0.2, 0.2)
        return
    end

    for _, entry in ipairs(GetSelectedActivationItems()) do
        if not HasRequiredInventoryItem(entry.item, entry.label) then
            return
        end
    end

    if (db.remainingCharge or 0) <= 0 then
        OS2.Notify("La torche est vide. Rechargez-la avant de l'allumer.", 1, 0.5, 0.1)
        RefreshPowerButton()
        return
    end
    db.mode       = "ON"
    db.resumeMode = "ON"
    db.remaining  = GetRemainingDuration()
    db.lastUpdate = GetTime()
    RefreshStatus()
    RefreshPowerButton()
    RefreshQuickToggleButton()
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
    TriggerAuraRules("auraApplyRules", "ACTIVATE")
    SetAuraActiveState(true)
    SendTorchEmote("on")
end

powerBtn:SetScript("OnClick",       function() TriggerTorchPowerToggle() end)
quickToggleBtn:SetScript("OnClick", function() TriggerTorchPowerToggle() end)

rechargeBtn:SetScript("OnClick", function()
    CurrentDB()
    SyncTorchState()
    local maxCharge = GetMaxCharge()
    if maxCharge <= 0 or GetDrainFactor() <= 0 then
        OS2.Notify("Sélectionnez une torche et un combustible avant de recharger.", 1, 0.2, 0.2)
        return
    end
    local selectedFuel = GetSelectedRechargeFuel()
    local ok, requiresConsume, itemId = ValidateRechargeInventoryItem(selectedFuel)
    if not ok then
        return
    end

    local function ApplyRecharge()
        db.remainingCharge = maxCharge
        if db.crystalKey then
            db.crystalCharges = db.crystalCharges or {}
            db.crystalCharges[db.crystalKey] = nil
        end
        db.remaining  = GetRemainingDuration()
        db.lastUpdate = GetTime()
        if not db.mjPaused and db.mode ~= "PAUSE" then
            db.mode       = "OFF"
            db.resumeMode = "OFF"
        end
        RefreshStatus()
        RefreshPowerButton()
        SendTorchEmote("recharge")
    end

    if requiresConsume then
        ConsumeInventoryItemAndThen(itemId, ApplyRecharge)
        return
    end

    ApplyRecharge()
end)

quickActivationCheck:SetScript("OnClick", function(self)
    CurrentDB()
    db.quickActivation = self:GetChecked() and true or false
    RefreshConfigPanel()
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
end)

UIDropDownMenu_Initialize(quickPositionDropdown, function(self, level)
    for _, option in ipairs(QUICK_POSITION_OPTIONS) do
        local info = UIDropDownMenu_CreateInfo()
        local isSelected = (GetQuickActivationPosition() == option.value)
        info.text = FormatDropdownItemLabel(option.label, isSelected)
        info.value = option.value
        info.notCheckable = true
        info.func = function()
            CurrentDB()
            db.quickActivationPosition = option.value
            UIDropDownMenu_SetSelectedValue(quickPositionDropdown, option.value)
            UIDropDownMenu_SetText(quickPositionDropdown, option.label)
            RefreshConfigPanel()
            if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

emoteConfigBtn:SetScript("OnClick", function()
    RefreshEmotePanel()
    OS2.ShowSettingsPanel(emotePanel, OS2.Launcher)
end)

resetTorchBtn:SetScript("OnClick", function()
    ResetTorchState()
    if OS2.RefreshTorchPanel then OS2.RefreshTorchPanel() end
end)

closeConfigBtn:SetScript("OnClick",  function() OS2.HideSettingsPanel(configPanel) end)

for _, row in ipairs(emoteRows) do
    row.button:SetScript("OnClick", function()
        emoteEditContext.key = row.key
        StaticPopup_Show("OS2_EDIT_TORCH_EMOTE", "Émote " .. row.labelText)
    end)
end

emoteResetBtn:SetScript("OnClick", function()
    CurrentDB()
    wipe(db.emotes)
    for key, value in pairs(DEFAULT_EMOTES) do
        db.emotes[key] = value
    end
    RefreshEmotePanel()
end)

emoteBackBtn:SetScript("OnClick",  function() OS2.HideSettingsPanel(emotePanel) end)
closeEmoteBtn:SetScript("OnClick", function() OS2.HideSettingsPanel(emotePanel) end)

------------------------------------------------------------------------
-- API publique
------------------------------------------------------------------------
function OS2.RefreshTorchPanel()
    CurrentDB()
    SyncTorchState()
    local modelOptions = GetModelOptions()
    local fuelOptions  = GetFuelOptions()

    if db.modelKey  and not OS2.Core.TorchModelByKey[db.modelKey]  then db.modelKey  = nil end
    if db.crystalKey and not OS2.Core.TorchFuelByKey[db.crystalKey] then db.crystalKey = nil end

    ClampRemainingCharge()

    if not IsAnyTorchDropdownOpen() then
        UpdateSelectionDropdown(torchDropdown, modelOptions, db.modelKey,   "Aucune torche")
        UpdateSelectionDropdown(fuelDropdown,  fuelOptions,  db.crystalKey, "Insérez un combustible")
        UpdateRateDropdown(db.drainRate or 1.0)
    end

    RefreshStatus()
    RefreshPowerButton()
    RefreshQuickToggleButton()
    RefreshConfigPanel()
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
end

------------------------------------------------------------------------
-- Callbacks d'ouverture / fermeture du panneau principal
------------------------------------------------------------------------
panel.os2OnOpened = nil
panel.os2OnClosed = nil

------------------------------------------------------------------------
-- Tick léger : refresh complet seulement quand le panneau est visible.
------------------------------------------------------------------------
do
    local elapsedSinceRuntimeRefresh = 0

    local function IsSurviveEnabled()
        return OmegaHub and OmegaHub.IsModuleEnabled and OmegaHub:IsModuleEnabled("Omega_Survive")
    end

    local function RefreshTorchRuntime()
        CurrentDB()
        if db.mode ~= "ON" and not db.mjPaused then
            return
        end

        SyncTorchState()
        RefreshQuickToggleButton()
        if OS2.RefreshTorchQuickControls then
            OS2.RefreshTorchQuickControls()
        end
    end

    C_Timer.NewTicker(0.25, function()
        if not IsSurviveEnabled() then
            elapsedSinceRuntimeRefresh = 0
            return
        end

        if panel and panel:IsShown() then
            if OS2.RefreshTorchPanel then OS2.RefreshTorchPanel() end
            elapsedSinceRuntimeRefresh = 0
            return
        end

        elapsedSinceRuntimeRefresh = elapsedSinceRuntimeRefresh + 0.25
        if elapsedSinceRuntimeRefresh >= 1 then
            elapsedSinceRuntimeRefresh = 0
            RefreshTorchRuntime()
        end
    end)
end

------------------------------------------------------------------------
-- Initialisation à l'ADDON_LOADED
------------------------------------------------------------------------
OS2.InitTorchPersistence = function()
    CurrentDB()
    if db.mjPaused then db.mode = "PAUSE" end
    db.lastUpdate = GetTime()
    ClampRemainingCharge()
    RefreshConfigPanel()
    RefreshQuickToggleButton()
    UpdateRateDropdown(db.drainRate or 1.0)
    if OS2.RefreshTorchQuickControls then OS2.RefreshTorchQuickControls() end
    if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
end

------------------------------------------------------------------------
-- Événements (contrôle MJ + sauvegarde au logout)
------------------------------------------------------------------------
do
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
    eventFrame:RegisterEvent("CHAT_MSG_RAID")
    eventFrame:RegisterEvent("CHAT_MSG_RAID_LEADER")
    eventFrame:RegisterEvent("CHAT_MSG_PARTY")
    eventFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
    eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT")
    eventFrame:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER")
    eventFrame:RegisterEvent("PLAYER_LOGOUT")
    eventFrame:SetScript("OnEvent", function(_, event, message)
        if event == "PLAYER_LOGOUT" then
            isLoggingOut = true
            SyncTorchState(GetTime())
            return
        end
        local disablePhraseEntry = GetMatchedControlPhraseEntry(event, message, "disablePhrases", "disablePhrase")
        local isDisablePhrase = disablePhraseEntry ~= nil
        local isEnablePhrase = MatchesConfiguredControlMessage(event, message, "enablePhrases", "enablePhrase")

        if not isDisablePhrase then
            local wasAuraActive = CurrentDB().auraActive
            local removed, applied = TriggerPhraseAuraRules(event, message, "DISABLE_PHRASE")
            SetAuraActiveState(ResolveAuraStateAfterRules(wasAuraActive, removed, applied))
        end
        if not isEnablePhrase then
            local wasAuraActive = CurrentDB().auraActive
            local removed, applied = TriggerPhraseAuraRules(event, message, "ENABLE_PHRASE")
            SetAuraActiveState(ResolveAuraStateAfterRules(wasAuraActive, removed, applied))
        end

        if isDisablePhrase then
            PauseTorchByMJ(message, disablePhraseEntry and disablePhraseEntry.effect)
        end
        if isEnablePhrase then
            ResumeTorchAfterMJ(message)
        end
    end)
end

------------------------------------------------------------------------
-- Largeur du panneau
------------------------------------------------------------------------
panel:SetWidth(PANEL_W)

CurrentDB()
RefreshConfigPanel()
RefreshQuickToggleButton()
UpdateRateDropdown(CurrentDB().drainRate or 1.0)
