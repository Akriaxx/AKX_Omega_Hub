-- OmegaSpell — Paramètres
OmegaSpell = OmegaSpell or {}
local OS  = OmegaSpell
local HUI = OS2.UI

local PANEL_W = 240
local WINDOW_SCALE_MIN, WINDOW_SCALE_MAX, WINDOW_SCALE_STEP = 0.60, 1.60, 0.05
local SLOT_MIN, SLOT_MAX, SLOT_STEP = 20, 80, 1
local GAP_MIN,  GAP_MAX,  GAP_STEP  = 0,  20, 1

local DEFAULTS = {
    launcherSize  = 36,
    windowScale   = 1.0,
    windowOpacity = 0.92,
    slotSize      = 41,
    gapH          = 1,
    gapV          = 1,
}

local function Clamp(v, lo, hi)
    return math.max(lo, math.min(hi, tonumber(v) or lo))
end

-- //////////////////////////////////////////////////////////
-- API publique : getters / setters
-- //////////////////////////////////////////////////////////

function OS:GetSettings()
    OmegaSpellDB = OmegaSpellDB or {}
    OmegaSpellDB.settings = OmegaSpellDB.settings or {}
    local s = OmegaSpellDB.settings
    if s.launcherSize  == nil then s.launcherSize  = DEFAULTS.launcherSize  end
    if s.windowScale   == nil then s.windowScale   = DEFAULTS.windowScale   end
    if s.windowOpacity == nil then s.windowOpacity = DEFAULTS.windowOpacity end
    if s.slotSize      == nil then s.slotSize      = DEFAULTS.slotSize      end
    if s.gapH          == nil then s.gapH          = DEFAULTS.gapH          end
    if s.gapV          == nil then s.gapV          = DEFAULTS.gapV          end
    return s
end

function OS:SetLauncherSize(size)
    size = Clamp(size, 20, 72)
    OS:GetSettings().launcherSize = size
    if OmegaSpellLauncherBtn then
        OmegaSpellLauncherBtn:SetSize(size, size)
    end
end

function OS:SetWindowScale(scale)
    local steps = math.floor(((Clamp(scale, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    scale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    OS:GetSettings().windowScale = scale
    if OmegaSpellPanel then
        OmegaSpellPanel:SetScale(scale)
    end
end

function OS:SetWindowOpacity(value)
    value = Clamp(value, 0.05, 1.0)
    OS:GetSettings().windowOpacity = value
    if OmegaSpellPanel and OmegaSpellPanel.bg then
        HUI.ApplyWindowBackground(OmegaSpellPanel.bg, value)
    end
end

function OS:SetSlotSize(size)
    size = Clamp(size, SLOT_MIN, SLOT_MAX)
    OS:GetSettings().slotSize = size
    if OS.Bar and OS.Bar.Refresh then
        OS.Bar.Refresh()
    end
end

function OS:SetGapH(gap)
    gap = Clamp(gap, GAP_MIN, GAP_MAX)
    OS:GetSettings().gapH = gap
    if OS.Bar and OS.Bar.Refresh then
        OS.Bar.Refresh()
    end
end

function OS:SetGapV(gap)
    gap = Clamp(gap, GAP_MIN, GAP_MAX)
    OS:GetSettings().gapV = gap
    if OS.Bar and OS.Bar.Refresh then
        OS.Bar.Refresh()
    end
end

function OS:ApplyBarSettings()
    local s = OS:GetSettings()
    if OS.Bar and OS.Bar.Refresh then
        OS.Bar.Refresh()
    end
end

function OS:ApplySettings()
    if not OmegaSpellDB or not OmegaSpellDB.settings then return end
    local s = OS:GetSettings()
    OS:SetLauncherSize(s.launcherSize)
    OS:SetWindowScale(s.windowScale)
    OS:SetWindowOpacity(s.windowOpacity)
end

-- //////////////////////////////////////////////////////////
-- Panneau paramètres
-- //////////////////////////////////////////////////////////

local settingsPanel = CreateFrame("Frame", "OmegaSpellSettingsPanel", UIParent)
settingsPanel:SetSize(PANEL_W, 414)
settingsPanel:SetFrameStrata("DIALOG")
settingsPanel:SetMovable(true)
settingsPanel:SetClampedToScreen(true)
settingsPanel:EnableMouse(true)
settingsPanel:Hide()

do
    local sBg = settingsPanel:CreateTexture(nil, "BACKGROUND")
    sBg:SetAllPoints()
    HUI.ApplyWindowBackground(sBg, 0.92)
    HUI.ApplyBorder(settingsPanel)

    local sTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 10, -10)
    sTitle:SetText("Paramètres — Spell")
    HUI.ApplyTitle(sTitle)

    HUI.CreateCloseButton(settingsPanel, function() settingsPanel:Hide() end)

    local sDrag = CreateFrame("Frame", nil, settingsPanel)
    sDrag:SetPoint("TOPLEFT"); sDrag:SetPoint("TOPRIGHT"); sDrag:SetHeight(30)
    sDrag:EnableMouse(true)
    sDrag:SetScript("OnMouseDown", function() settingsPanel:StartMoving() end)
    sDrag:SetScript("OnMouseUp",   function() settingsPanel:StopMovingOrSizing() end)

    local sSep = settingsPanel:CreateTexture(nil, "ARTWORK")
    sSep:SetPoint("TOPLEFT",  settingsPanel, "TOPLEFT",  0, -30)
    sSep:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", 0, -30)
    sSep:SetHeight(1)
    HUI.ApplySeparator(sSep)
end

local function MakeSlider(labelText, yTop, minV, maxV, step, formatter, onChanged)
    local label = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, yTop)
    label:SetText(labelText)
    HUI.ApplyLabel(label)

    local slider = CreateFrame("Slider", nil, settingsPanel)
    slider:SetSize(PANEL_W - 28, 14)
    slider:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, yTop - 16)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
    sliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
    sliderBg:SetHeight(8)
    sliderBg:SetPoint("LEFT",  slider)
    sliderBg:SetPoint("RIGHT", slider)
    slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
    HUI.ApplyBodyText(valueText)

    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(formatter(value))
        onChanged(value)
    end)

    slider.valueText = valueText
    return slider
end

-- Section : Fenêtre / Lanceur
local opacitySlider = MakeSlider(
    "Opacité des fenêtres", -46,
    0.05, 1.00, 0.05,
    function(v) return string.format("%.0f%%", v * 100) end,
    function(v) OS:SetWindowOpacity(v) end
)

local launcherSlider = MakeSlider(
    "Taille du lanceur", -100,
    20, 72, 2,
    function(v) return string.format("%d px", math.floor(v + 0.5)) end,
    function(v) OS:SetLauncherSize(v) end
)

-- Taille des fenêtres (boutons +/-)
local wsLabel = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsLabel:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, -154)
wsLabel:SetText("Taille des fenêtres")
HUI.ApplyLabel(wsLabel)

local wsDecBtn = HUI.CreatePanelButton(settingsPanel, 26, 22, "<")
wsDecBtn:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, -170)

local wsValueBox = CreateFrame("Frame", nil, settingsPanel)
wsValueBox:SetSize(PANEL_W - 96, 22)
wsValueBox:SetPoint("LEFT", wsDecBtn, "RIGHT", 4, 0)

local wsValueBg = wsValueBox:CreateTexture(nil, "BACKGROUND")
wsValueBg:SetAllPoints()
wsValueBg:SetColorTexture(unpack(HUI.colors.panelButtonBg))

local wsValueBorder = wsValueBox:CreateTexture(nil, "BORDER")
wsValueBorder:SetAllPoints()
wsValueBorder:SetColorTexture(HUI.colors.panelButtonAccent[1], HUI.colors.panelButtonAccent[2], HUI.colors.panelButtonAccent[3], 0.50)

local wsValueText = wsValueBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsValueText:SetPoint("CENTER")
HUI.ApplyBodyText(wsValueText)

local wsIncBtn = HUI.CreatePanelButton(settingsPanel, 26, 22, ">")
wsIncBtn:SetPoint("LEFT", wsValueBox, "RIGHT", 4, 0)

local function RefreshWsControl()
    local scale = OS:GetSettings().windowScale
    wsValueText:SetText(string.format("%.0f%%", scale * 100))
    wsDecBtn:SetEnabled(scale > WINDOW_SCALE_MIN)
    wsDecBtn:SetAlpha(scale > WINDOW_SCALE_MIN and 1 or 0.35)
    wsIncBtn:SetEnabled(scale < WINDOW_SCALE_MAX)
    wsIncBtn:SetAlpha(scale < WINDOW_SCALE_MAX and 1 or 0.35)
end

wsDecBtn:SetScript("OnClick", function()
    OS:SetWindowScale(OS:GetSettings().windowScale - WINDOW_SCALE_STEP)
    RefreshWsControl()
end)
wsIncBtn:SetScript("OnClick", function()
    OS:SetWindowScale(OS:GetSettings().windowScale + WINDOW_SCALE_STEP)
    RefreshWsControl()
end)

-- Séparateur section Barres
local barSep = settingsPanel:CreateTexture(nil, "ARTWORK")
barSep:SetPoint("TOPLEFT",  settingsPanel, "TOPLEFT",  14, -206)
barSep:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -14, -206)
barSep:SetHeight(1)
HUI.ApplySeparator(barSep)

local barTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
barTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, -218)
barTitle:SetText("Barres d'action")
HUI.ApplyLabel(barTitle)

-- Sliders barres
local slotSlider   -- forward reference for auto-gap logic
local gapHSlider
local gapVSlider

slotSlider = MakeSlider(
    "Taille des boutons de sort", -236,
    SLOT_MIN, SLOT_MAX, SLOT_STEP,
    function(v) return string.format("%d px", math.floor(v + 0.5)) end,
    function(v)
        -- Auto-ajuste le gap minimum pour éviter tout chevauchement visuel
        local minGap = math.max(1, math.floor(v / 30 + 0.5))
        local s = OS:GetSettings()
        if s.gapH < minGap then
            s.gapH = minGap
            if gapHSlider then gapHSlider:SetValue(minGap) end
        end
        if s.gapV < minGap then
            s.gapV = minGap
            if gapVSlider then gapVSlider:SetValue(minGap) end
        end
        OS:SetSlotSize(v)
    end
)

gapHSlider = MakeSlider(
    "Espacement horizontal", -290,
    GAP_MIN, GAP_MAX, GAP_STEP,
    function(v) return string.format("%d px", math.floor(v + 0.5)) end,
    function(v) OS:SetGapH(v) end
)

gapVSlider = MakeSlider(
    "Espacement vertical", -344,
    GAP_MIN, GAP_MAX, GAP_STEP,
    function(v) return string.format("%d px", math.floor(v + 0.5)) end,
    function(v) OS:SetGapV(v) end
)

local function SyncControls()
    local s = OS:GetSettings()
    opacitySlider:SetValue(s.windowOpacity)
    launcherSlider:SetValue(s.launcherSize)
    slotSlider:SetValue(s.slotSize)
    gapHSlider:SetValue(s.gapH)
    gapVSlider:SetValue(s.gapV)
    RefreshWsControl()
end

settingsPanel:SetScript("OnShow", SyncControls)

-- //////////////////////////////////////////////////////////
-- API toggle
-- //////////////////////////////////////////////////////////

function OS:ToggleSettings()
    if settingsPanel:IsShown() then
        settingsPanel:Hide()
    else
        settingsPanel:ClearAllPoints()
        if OmegaSpellPanel and OmegaSpellPanel:IsShown() then
            settingsPanel:SetPoint("TOPLEFT", OmegaSpellPanel, "TOPRIGHT", 8, 0)
        elseif OmegaSpellLauncherBtn then
            settingsPanel:SetPoint("BOTTOMLEFT", OmegaSpellLauncherBtn, "TOPRIGHT", 8, 0)
        else
            settingsPanel:SetPoint("CENTER", UIParent, "CENTER", 500, 0)
        end
        settingsPanel:Show()
    end
end

OS.SettingsPanel = settingsPanel
