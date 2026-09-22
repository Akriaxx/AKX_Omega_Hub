-- ============================================================
--  Character - Paramètres d'affichage
--  Clic molette sur le portrait permanent
-- ============================================================

local C  = Character
local UI = C.RPGUI or OS2.UI

local PANEL_W, PANEL_H = 260, 456
local WINDOW_SCALE_MIN, WINDOW_SCALE_MAX, WINDOW_SCALE_STEP = 0.60, 1.60, 0.05

local DEFAULTS = {
    windowOpacity    = 0.65,


    mjScale          = 1.00,
    groupScale       = 1.00,
    initiativeScale  = 1.00,

    resourceHUDScale = 1.00,
    -- Phrases farfelues par défaut : voir HandleRaidWarningTrigger dans
    -- Core.lua — chacun doit garder des phrases DIFFÉRENTES des autres pour
    -- que seul l'expéditeur d'un /rw démarre/termine le combat chez lui.
    rwTrigger        = "Akriax a un gros chibre",
    rwEndTrigger     = "Akriax a un petit chibre",
}

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, value))
end

function C:GetSettings()
    CharacterDB = CharacterDB or {}
    CharacterDB.settings = CharacterDB.settings or {}
    local s = CharacterDB.settings
    if s.windowOpacity   == nil then s.windowOpacity   = DEFAULTS.windowOpacity   end


    if s.mjScale         == nil then s.mjScale         = DEFAULTS.mjScale         end
    if s.groupScale      == nil then s.groupScale      = DEFAULTS.groupScale      end
    if s.initiativeScale == nil then s.initiativeScale = DEFAULTS.initiativeScale end
    if s.rwTrigger        == nil then s.rwTrigger        = DEFAULTS.rwTrigger        end
    if s.rwEndTrigger     == nil then s.rwEndTrigger     = DEFAULTS.rwEndTrigger     end
    s.resourceHUDEnabled = nil -- Permanent personal HUD replaces the optional display.
    if s.resourceHUDScale == nil then s.resourceHUDScale = s.playerScale or DEFAULTS.resourceHUDScale end
    return s
end

function C:SetRWTrigger(text)
    local s = C:GetSettings()
    s.rwTrigger = tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

function C:SetRWEndTrigger(text)
    local s = C:GetSettings()
    s.rwEndTrigger = tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

function C:SetWindowOpacity(value)
    local s = C:GetSettings()
    s.windowOpacity = Clamp(value, 0.05, 1.00)
    for _, frame in ipairs({
        CharacterMJPanel, CharacterMJImpactPanel, CharacterMJPnjPanel,
        CharacterGroupViewPanel, CharacterInitiativeBanner,
        CharacterInitiativeBanner and CharacterInitiativeBanner.roundBox,
    }) do
        if frame and frame.bg then UI.ApplyWindowBackground(frame.bg, s.windowOpacity) end
    end
end

function C:SetMJScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.mjScale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    if CharacterMJPanel       then CharacterMJPanel:SetScale(s.mjScale)       end
    if CharacterMJImpactPanel then CharacterMJImpactPanel:SetScale(s.mjScale) end
    if CharacterMJPnjPanel    then CharacterMJPnjPanel:SetScale(s.mjScale)    end
end

function C:SetGroupScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.groupScale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    if CharacterGroupViewPanel then CharacterGroupViewPanel:SetScale(s.groupScale) end
end

function C:SetInitiativeScale(value)
    local s = C:GetSettings()
    local steps = math.floor(((Clamp(value, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    s.initiativeScale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    if CharacterInitiativeBanner then CharacterInitiativeBanner:SetScale(s.initiativeScale) end
end

function C:ApplyDisplaySettings()
    local s = C:GetSettings()
    C:SetWindowOpacity(s.windowOpacity)

    C:SetMJScale(s.mjScale)
    C:SetGroupScale(s.groupScale)
    C:SetInitiativeScale(s.initiativeScale)

    if C.ApplyResourceHUD then C:ApplyResourceHUD() end
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
UI.ApplyBorder(panel)

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
    "Taille — Portrait et ressources", -104,
    function() return C:GetSettings().resourceHUDScale end,
    function(v) if C.SetResourceHUDScale then C:SetResourceHUDScale(v) end end
)

local refreshMJ = MakeScaleControl(
    "Taille — Vue MJ", -148,
    function() return C:GetSettings().mjScale end,
    function(v) C:SetMJScale(v) end
)

local refreshGroup = MakeScaleControl(
    "Taille — Vue Joueur", -192,
    function() return C:GetSettings().groupScale end,
    function(v) C:SetGroupScale(v) end
)

local refreshInitiative = MakeScaleControl(
    "Taille — Bandeau Initiative", -236,
    function() return C:GetSettings().initiativeScale end,
    function(v) C:SetInitiativeScale(v) end
)

-- ── Phrases déclencheuses /rw ────────────────────────────────────────────────
-- Envoyer ces textes en /rw démarre/termine le combat chez SOI (voir
-- HandleRaidWarningTrigger, Core.lua). Garder des phrases différentes des
-- autres joueurs pour ne pas déclencher leur combat en même temps.

local rwTriggerLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rwTriggerLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -280)
rwTriggerLbl:SetText("Phrase déclencheuse /rw")
UI.ApplyLabel(rwTriggerLbl)

local rwTriggerEB = UI.CreateStyledEditBox(panel, PANEL_W - 28, 22)
rwTriggerEB:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -296)
rwTriggerEB:SetScript("OnEnterPressed", function(self)
    C:SetRWTrigger(self:GetText())
    self:ClearFocus()
end)
rwTriggerEB:SetScript("OnEditFocusLost", function(self)
    C:SetRWTrigger(self:GetText())
end)

local rwEndTriggerLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rwEndTriggerLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -332)
rwEndTriggerLbl:SetText("Phrase de fin /rw")
UI.ApplyLabel(rwEndTriggerLbl)

local rwEndTriggerEB = UI.CreateStyledEditBox(panel, PANEL_W - 28, 22)
rwEndTriggerEB:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -348)
rwEndTriggerEB:SetScript("OnEnterPressed", function(self)
    C:SetRWEndTrigger(self:GetText())
    self:ClearFocus()
end)
rwEndTriggerEB:SetScript("OnEditFocusLost", function(self)
    C:SetRWEndTrigger(self:GetText())
end)

-- ── Base de données de compétences ───────────────────────────────────────────

local skillsDbBtn = UI.CreatePanelButton(panel, PANEL_W - 28, 24, "Base de données")
skillsDbBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -384)
skillsDbBtn:SetScript("OnClick", function()
    if C.ToggleSkillsBuilder then C:ToggleSkillsBuilder() end
end)

-- ── Sync & toggle ─────────────────────────────────────────────────────────────

local hudHint=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
hudHint:SetPoint("TOPLEFT",panel,"TOPLEFT",14,-422)
hudHint:SetText("Maintenir et glisser le portrait : déplacer")
hudHint:SetWidth(PANEL_W-28);hudHint:SetJustifyH("LEFT");hudHint:SetWordWrap(true)
UI.ApplyMutedText(hudHint)
local function SyncControls()
    local s = C:GetSettings()
    opacitySlider:SetValue(s.windowOpacity)

    refreshPlayer()
    refreshMJ()
    refreshGroup()
    refreshInitiative()


    rwTriggerEB:SetText(s.rwTrigger or "")
    rwEndTriggerEB:SetText(s.rwEndTrigger or "")
end

panel:SetScript("OnShow", SyncControls)

function C:ToggleSettings()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:ClearAllPoints()
        if CharacterResourceHUD then
            panel:SetPoint("TOPLEFT", CharacterResourceHUD, "TOPRIGHT", 8, 0)
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        end
        panel:Show()
    end
end

C.SettingsPanel = panel
C:ApplyDisplaySettings()
