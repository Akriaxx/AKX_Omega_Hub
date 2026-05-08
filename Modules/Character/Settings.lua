-- ============================================================
--  Character - Paramètres d'affichage
--  Shift + clic droit sur le bouton Character
-- ============================================================

local C  = Character
local UI = OS2.UI

local PANEL_W, PANEL_H = 240, 302
local WINDOW_SCALE_MIN, WINDOW_SCALE_MAX, WINDOW_SCALE_STEP = 0.60, 1.60, 0.05

local DEFAULTS = {
    windowOpacity = 0.65,
    launcherSize  = 44,
    playerScale   = 1.00,
    mjScale       = 1.00,
    groupScale    = 1.00,
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
    if s.launcherSize  == nil then s.launcherSize  = DEFAULTS.launcherSize  end
    if s.playerScale   == nil then s.playerScale   = DEFAULTS.playerScale   end
    if s.mjScale       == nil then s.mjScale       = DEFAULTS.mjScale       end
    if s.groupScale    == nil then s.groupScale    = DEFAULTS.groupScale    end
    return s
end

function C:SetWindowOpacity(value)
    local s = C:GetSettings()
    s.windowOpacity = Clamp(value, 0.05, 1.00)
    for _, frame in ipairs({
        CharacterPlayerPanel, CharacterMJPanel,
        CharacterMJImpactPanel, CharacterGroupViewPanel,
    }) do
        if frame and frame.bg then UI.ApplyWindowBackground(frame.bg, s.windowOpacity) end
    end
end

function C:SetPlayerScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.playerScale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    if CharacterPlayerPanel then CharacterPlayerPanel:SetScale(s.playerScale) end
end

function C:SetMJScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.mjScale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    if CharacterMJPanel       then CharacterMJPanel:SetScale(s.mjScale)       end
    if CharacterMJImpactPanel then CharacterMJImpactPanel:SetScale(s.mjScale) end
end

function C:SetGroupScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.groupScale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    if CharacterGroupViewPanel then CharacterGroupViewPanel:SetScale(s.groupScale) end
end

function C:ApplyDisplaySettings()
    local s = C:GetSettings()
    C:SetWindowOpacity(s.windowOpacity)
    C:SetPlayerScale(s.playerScale)
    C:SetMJScale(s.mjScale)
    C:SetGroupScale(s.groupScale)
    if C.SetLauncherSize then C:SetLauncherSize(s.launcherSize, false) end
end

-- ── Panneau ──────────────────────────────────────────────────────────────────

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

-- ── Sliders ───────────────────────────────────────────────────────────────────

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
    "Opacité des fenêtres", -50,
    0.05, 1.00, 0.05,
    function(v) return string.format("%.0f%%", v * 100) end,
    function(v) C:SetWindowOpacity(v) end
)

local launcherSlider = MakeSlider(
    "Taille de l'icône", -104,
    28, 72, 2,
    function(v) return string.format("%d px", math.floor(v + 0.5)) end,
    function(v) if C.SetLauncherSize then C:SetLauncherSize(v, true) end end
)

-- ── Contrôles de taille (3 fenêtres séparées) ────────────────────────────────

local function MakeScaleControl(labelText, y, getScale, setScale)
    local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y)
    lbl:SetText(labelText)
    UI.ApplyLabel(lbl)

    local decBtn = UI.CreatePanelButton(panel, 26, 22, "<")
    decBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, y - 16)

    local valueBox = CreateFrame("Frame", nil, panel)
    valueBox:SetSize(PANEL_W - 96, 22)
    valueBox:SetPoint("LEFT", decBtn, "RIGHT", 4, 0)

    local vBg = valueBox:CreateTexture(nil, "BACKGROUND")
    vBg:SetAllPoints()
    vBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

    local vBorder = valueBox:CreateTexture(nil, "BORDER")
    vBorder:SetAllPoints()
    vBorder:SetColorTexture(
        UI.colors.panelButtonAccent[1],
        UI.colors.panelButtonAccent[2],
        UI.colors.panelButtonAccent[3], 0.50)

    local valueText = valueBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("CENTER")
    UI.ApplyBodyText(valueText)

    local incBtn = UI.CreatePanelButton(panel, 26, 22, ">")
    incBtn:SetPoint("LEFT", valueBox, "RIGHT", 4, 0)

    local function Refresh()
        local scale = getScale()
        valueText:SetText(string.format("%.0f%%", scale * 100))
        decBtn:SetEnabled(scale > WINDOW_SCALE_MIN)
        decBtn:SetAlpha(scale > WINDOW_SCALE_MIN and 1 or 0.35)
        incBtn:SetEnabled(scale < WINDOW_SCALE_MAX)
        incBtn:SetAlpha(scale < WINDOW_SCALE_MAX and 1 or 0.35)
    end

    decBtn:SetScript("OnClick", function()
        setScale(getScale() - WINDOW_SCALE_STEP)
        Refresh()
    end)
    incBtn:SetScript("OnClick", function()
        setScale(getScale() + WINDOW_SCALE_STEP)
        Refresh()
    end)

    return Refresh
end

local refreshPlayer = MakeScaleControl(
    "Taille — Fiche personnage", -158,
    function() return C:GetSettings().playerScale end,
    function(v) C:SetPlayerScale(v) end
)

local refreshMJ = MakeScaleControl(
    "Taille — Vue MJ", -202,
    function() return C:GetSettings().mjScale end,
    function(v) C:SetMJScale(v) end
)

local refreshGroup = MakeScaleControl(
    "Taille — Vue Joueur", -246,
    function() return C:GetSettings().groupScale end,
    function(v) C:SetGroupScale(v) end
)

-- ── Sync & toggle ─────────────────────────────────────────────────────────────

local function SyncControls()
    local s = C:GetSettings()
    opacitySlider:SetValue(s.windowOpacity)
    launcherSlider:SetValue(s.launcherSize)
    refreshPlayer()
    refreshMJ()
    refreshGroup()
end

panel:SetScript("OnShow", SyncControls)

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
        panel:Show()
    end
end

C.SettingsPanel = panel
C:ApplyDisplaySettings()
