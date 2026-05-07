-- ============================================================
--  Character - Paramètres d'affichage
--  Shift + clic droit sur le bouton Character
-- ============================================================

local C  = Character
local UI = OS2.UI

local PANEL_W, PANEL_H = 240, 214
local WINDOW_SCALE_MIN, WINDOW_SCALE_MAX, WINDOW_SCALE_STEP = 0.60, 1.60, 0.05

local DEFAULTS = {
    windowOpacity = 0.65,
    launcherSize  = 44,
    windowScale   = 1.00,
}

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, value))
end

function C:GetSettings()
    CharacterDB = CharacterDB or {}
    CharacterDB.settings = CharacterDB.settings or {}
    local s = CharacterDB.settings
    if s.windowOpacity == nil then s.windowOpacity = DEFAULTS.windowOpacity end
    if s.launcherSize  == nil then s.launcherSize  = DEFAULTS.launcherSize end
    if s.windowScale   == nil then s.windowScale   = DEFAULTS.windowScale end
    return s
end

local function EachCharacterWindow(callback)
    if CharacterPlayerPanel then callback(CharacterPlayerPanel) end
    if CharacterMJPanel then callback(CharacterMJPanel) end
    if CharacterMJImpactPanel then callback(CharacterMJImpactPanel) end
end

function C:SetWindowOpacity(value)
    local s = C:GetSettings()
    s.windowOpacity = Clamp(value, 0.05, 1.00)
    EachCharacterWindow(function(frame)
        if frame.bg then UI.ApplyWindowBackground(frame.bg, s.windowOpacity) end
    end)
end

function C:SetWindowScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.windowScale = WINDOW_SCALE_MIN + (steps * WINDOW_SCALE_STEP)
    EachCharacterWindow(function(frame)
        if frame.SetScale then frame:SetScale(s.windowScale) end
    end)
end

function C:ApplyDisplaySettings()
    local s = C:GetSettings()
    C:SetWindowOpacity(s.windowOpacity)
    C:SetWindowScale(s.windowScale)
    if C.SetLauncherSize then C:SetLauncherSize(s.launcherSize, false) end
end

local panel = CreateFrame("Frame", "CharacterSettingsPanel", UIParent)
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
panel:SetFrameStrata("DIALOG")
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:Hide()

local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
UI.ApplyWindowBackground(bg, 0.92)

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
title:SetText("Paramètres Character")
UI.ApplyTitle(title)

local closeBtn = UI.CreateCloseButton(panel, function() panel:Hide() end)
if closeBtn and closeBtn.SetFrameLevel then closeBtn:SetFrameLevel(panel:GetFrameLevel() + 20) end

local dragHandle = CreateFrame("Frame", nil, panel)
dragHandle:SetPoint("TOPLEFT")
dragHandle:SetPoint("TOPRIGHT")
dragHandle:SetHeight(34)
dragHandle:EnableMouse(true)
dragHandle:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then panel:StartMoving() end
end)
dragHandle:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

local sep = panel:CreateTexture(nil, "ARTWORK")
sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -34)
sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -34)
sep:SetHeight(1)
UI.ApplySeparator(sep)

local function MakeSlider(labelText, y, minValue, maxValue, step, formatter, onChanged)
    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y)
    label:SetText(labelText)
    UI.ApplyLabel(label)

    local slider = CreateFrame("Slider", nil, panel)
    slider:SetSize(PANEL_W - 28, 14)
    slider:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y - 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
    sliderBg:SetHeight(8)
    sliderBg:SetPoint("LEFT", slider)
    sliderBg:SetPoint("RIGHT", slider)

    slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    UI.ApplyBodyText(valueText)

    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(formatter(value))
        onChanged(value)
    end)

    slider.valueText = valueText
    return slider
end

local opacitySlider = MakeSlider(
    "Opacité des fenêtres",
    -50,
    0.05,
    1.00,
    0.05,
    function(value) return string.format("%.0f%%", value * 100) end,
    function(value) C:SetWindowOpacity(value) end
)

local launcherSlider = MakeSlider(
    "Taille de l'icône",
    -104,
    28,
    72,
    2,
    function(value) return string.format("%d px", math.floor(value + 0.5)) end,
    function(value)
        if C.SetLauncherSize then C:SetLauncherSize(value, true) end
    end
)

local scaleLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -158)
scaleLabel:SetText("Taille des fenêtres")
UI.ApplyLabel(scaleLabel)

local scaleDecBtn = UI.CreatePanelButton(panel, 26, 22, "<")
scaleDecBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -176)

local scaleValueBox = CreateFrame("Frame", nil, panel)
scaleValueBox:SetSize(PANEL_W - 96, 22)
scaleValueBox:SetPoint("LEFT", scaleDecBtn, "RIGHT", 4, 0)

local scaleValueBg = scaleValueBox:CreateTexture(nil, "BACKGROUND")
scaleValueBg:SetAllPoints()
scaleValueBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local scaleValueBorder = scaleValueBox:CreateTexture(nil, "BORDER")
scaleValueBorder:SetAllPoints()
scaleValueBorder:SetColorTexture(UI.colors.panelButtonAccent[1], UI.colors.panelButtonAccent[2], UI.colors.panelButtonAccent[3], 0.50)

local scaleValueText = scaleValueBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
scaleValueText:SetPoint("CENTER")
UI.ApplyBodyText(scaleValueText)

local scaleIncBtn = UI.CreatePanelButton(panel, 26, 22, ">")
scaleIncBtn:SetPoint("LEFT", scaleValueBox, "RIGHT", 4, 0)

local function SetScaleBtnState(btn, enabled)
    btn:SetEnabled(enabled)
    btn:SetAlpha(enabled and 1 or 0.35)
    btn:EnableMouse(enabled)
end

local function RefreshScaleControl()
    local scale = C:GetSettings().windowScale or DEFAULTS.windowScale
    scaleValueText:SetText(string.format("%.0f%%", scale * 100))
    SetScaleBtnState(scaleDecBtn, scale > WINDOW_SCALE_MIN)
    SetScaleBtnState(scaleIncBtn, scale < WINDOW_SCALE_MAX)
end

local function SetScaleFromControl(value)
    C:SetWindowScale(value)
    RefreshScaleControl()
end

scaleDecBtn:SetScript("OnClick", function()
    SetScaleFromControl((C:GetSettings().windowScale or DEFAULTS.windowScale) - WINDOW_SCALE_STEP)
end)

scaleIncBtn:SetScript("OnClick", function()
    SetScaleFromControl((C:GetSettings().windowScale or DEFAULTS.windowScale) + WINDOW_SCALE_STEP)
end)

local function SyncControls()
    local s = C:GetSettings()
    opacitySlider:SetValue(s.windowOpacity)
    launcherSlider:SetValue(s.launcherSize)
    RefreshScaleControl()
end

panel:SetScript("OnShow", function()
    SyncControls()
end)

function C:ToggleSettings()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:ClearAllPoints()
        if CharacterLauncherBtn then
            panel:SetPoint("TOPLEFT", CharacterLauncherBtn, "TOPRIGHT", 8, 0)
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        end
        C:ApplyDisplaySettings()
        panel:Show()
    end
end

C.SettingsPanel = panel
C:ApplyDisplaySettings()
