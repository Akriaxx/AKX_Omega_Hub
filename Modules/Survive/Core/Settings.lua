-- OmegaSurvive 2.0 — Paramètres
local panel = OS2.panels["parametres"]

local PANEL_W   = OS2.PANEL_W
local TAB_H     = 26
local TAB_W     = math.floor(PANEL_W / 4)
local TITLE_H   = 35           -- hauteur de l'entête titre (identique aux autres panels)
local HEADER_H  = TITLE_H + TAB_H + 1   -- entête + tab bar + separator
local PAD_BOT   = 20           -- bottom padding for each tab

local TABS = { "Affichage", "Options", "Module", "Crédit" }
local TEXT_SCALE_MIN, TEXT_SCALE_MAX, TEXT_SCALE_STEP = 0.60, 1.40, 0.05
local WINDOW_SCALE_MIN  = 0.60
local WINDOW_SCALE_MAX  = 1.60
local WINDOW_SCALE_STEP = 0.05
local UI = OS2.UI or {}

local tabBtns    = {}
local tabContent = {}
local selectedTab = 1

-- ── Texte scale (infrastructure) ─────────────────────────────────────────
OS2.textScaleFontStrings = OS2.textScaleFontStrings or {}

OS2.RegisterTextScaleFS = OS2.RegisterTextScaleFS or function(fs, baseSize)
    table.insert(OS2.textScaleFontStrings, { fs = fs, size = baseSize or 10 })
end

OS2.GetTextScale = OS2.GetTextScale or function()
    return (OS2DB and OS2DB.textScale) or 1.0
end

OS2.SetTextScale = OS2.SetTextScale or function(value)
    local scale = math.max(TEXT_SCALE_MIN, math.min(TEXT_SCALE_MAX, tonumber(value) or 1.0))
    if OS2DB then OS2DB.textScale = scale end
    local path = "Fonts\\FRIZQT__.TTF"
    for _, entry in ipairs(OS2.textScaleFontStrings) do
        if entry.fs and entry.fs.SetFont then
            entry.fs:SetFont(path, math.max(6, math.floor(entry.size * scale + 0.5)), "")
        end
    end
end

------------------------------------------------------------------------
-- Hauteur dynamique
------------------------------------------------------------------------
local function SetTabHeight(contentH)
    panel:SetHeight(HEADER_H + contentH + PAD_BOT)
end

------------------------------------------------------------------------
-- Onglets
------------------------------------------------------------------------
local function SelectTab(idx)
    selectedTab = idx
    for i, btn in ipairs(tabBtns) do
        local active = (i == idx)
        UI.ApplyTabState(btn, active)
        tabContent[i]:SetShown(active)
    end

    if idx == 1 then
        -- opacity, lanceur, texte, icônes, fenêtres, séparateur, animations, type de menu
        SetTabHeight(448)
    elseif idx == 2 then
        SetTabHeight(315)
    elseif idx == 3 then
        local moduleRowsRef = tabContent[3].moduleRows
        local N = moduleRowsRef and #moduleRowsRef or 0
        SetTabHeight(104 + math.max(0, N - 1) * 30 + 26)
    else
        -- creditsText(-16, ~36)
        SetTabHeight(52)
    end
end

local function CreatePanelButton(parent, width, height, text)
    return UI.CreatePanelButton(parent, width, height, text)
end

local function StyleDropdown(dd, textLeft, textYOffset, textRightPad)
    UI.StyleDropdown(dd, textLeft, textYOffset, textRightPad)
end

local function FormatDropdownItemLabel(label, isSelected)
    if isSelected then
        return "|cffd7b35f>  " .. label .. "|r"
    end

    return "    " .. label
end

-- ── Entête "Paramètres" ───────────────────────────────────────────────
do
    local titleStr = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", panel, "TOP", 0, -12)
    titleStr:SetText("Paramètres")
    UI.ApplyTitle(titleStr)

    local titleSep = panel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(titleSep)
    titleSep:SetHeight(1)
    titleSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -34)
    titleSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -34)

    -- Zone de drag couvrant toute l'entête titre
    local dragHandle = CreateFrame("Frame", nil, panel)
    dragHandle:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, 0)
    dragHandle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    dragHandle:SetHeight(TITLE_H)
    if OS2.MakeDraggable then OS2.MakeDraggable(panel, dragHandle) end

    -- Bouton fermer
    local closeBtn = UI.CreateCloseButton(panel)

    closeBtn:SetScript("OnClick", function()
        if OS2.TogglePanel then OS2.TogglePanel("parametres") end
    end)

    -- Élever closeBtn au-dessus du dragHandle (priorité clic)
    closeBtn:SetFrameLevel(dragHandle:GetFrameLevel() + 1)
end

for i, name in ipairs(TABS) do
    local btn = CreateFrame("Button", nil, panel)
    btn:SetSize(TAB_W, TAB_H)
    btn:SetPoint("TOPLEFT", panel, "TOPLEFT", (i - 1) * TAB_W, -TITLE_H)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetAllPoints()
    label:SetText(name)
    UI.ApplyMutedText(label)
    btn.label = label

    local line = btn:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(unpack(UI.colors.tabLine))
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  0, 0)
    line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.line = line

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetColorTexture(unpack(UI.colors.tabHighlight))
    hl:SetAllPoints()

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -HEADER_H)
    content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0,  0)
    content:Hide()
    tabContent[i] = content

    btn:SetScript("OnClick", function() SelectTab(i) end)
    tabBtns[i] = btn
end

-- Séparateur sous les onglets
local sep = panel:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(sep)
sep:SetHeight(1)
sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, -(TITLE_H + TAB_H))
sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -(TITLE_H + TAB_H))

------------------------------------------------------------------------
-- Onglet 1 : Affichage
------------------------------------------------------------------------
local affichage = tabContent[1]

local opacityLabel = affichage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
opacityLabel:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -16)
opacityLabel:SetText("Opacité des fenêtres")
UI.ApplyLabel(opacityLabel)

local slider = CreateFrame("Slider", nil, affichage)
slider:SetSize(PANEL_W - 28, 14)
slider:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -32)
slider:SetOrientation("HORIZONTAL")
slider:SetMinMaxValues(0.05, 1.0)
slider:SetValueStep(0.05)
slider:SetObeyStepOnDrag(true)

local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
sliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
sliderBg:SetHeight(8)
sliderBg:SetPoint("LEFT",  slider)
sliderBg:SetPoint("RIGHT", slider)

slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

local valText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
valText:SetPoint("TOP", slider, "BOTTOM", 0, -4)
UI.ApplyBodyText(valText)

slider:SetScript("OnValueChanged", function(self, value)
    valText:SetText(string.format("%.0f%%", value * 100))
    OS2.SetPanelOpacity(value)
end)

slider:SetValue(0.65)
OS2.opacitySlider = slider

local launcherSizeLabel = affichage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
launcherSizeLabel:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -82)
launcherSizeLabel:SetText("Taille du lanceur")
UI.ApplyLabel(launcherSizeLabel)

local launcherSizeSlider = CreateFrame("Slider", nil, affichage)
launcherSizeSlider:SetSize(PANEL_W - 28, 14)
launcherSizeSlider:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -98)
launcherSizeSlider:SetOrientation("HORIZONTAL")
launcherSizeSlider:SetMinMaxValues(20, 52)
launcherSizeSlider:SetValueStep(2)
launcherSizeSlider:SetObeyStepOnDrag(true)

local launcherSizeSliderBg = launcherSizeSlider:CreateTexture(nil, "BACKGROUND")
launcherSizeSliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
launcherSizeSliderBg:SetHeight(8)
launcherSizeSliderBg:SetPoint("LEFT",  launcherSizeSlider)
launcherSizeSliderBg:SetPoint("RIGHT", launcherSizeSlider)

launcherSizeSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

local launcherSizeValueText = launcherSizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
launcherSizeValueText:SetPoint("TOP", launcherSizeSlider, "BOTTOM", 0, -4)
UI.ApplyBodyText(launcherSizeValueText)

launcherSizeSlider:SetScript("OnValueChanged", function(self, value)
    local size = math.floor(value + 0.5)
    launcherSizeValueText:SetText(string.format("%d px", size))
    if OS2.SetLauncherSize then
        OS2.SetLauncherSize(size)
    end
end)

launcherSizeSlider:SetValue(OS2.GetLauncherSize and OS2.GetLauncherSize() or 36)
OS2.launcherSizeSlider = launcherSizeSlider

local textSizeLabel = affichage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textSizeLabel:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -148)
textSizeLabel:SetText("Taille du texte")
UI.ApplyLabel(textSizeLabel)

local textSizeSlider = CreateFrame("Slider", nil, affichage)
textSizeSlider:SetSize(PANEL_W - 28, 14)
textSizeSlider:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -164)
textSizeSlider:SetOrientation("HORIZONTAL")
textSizeSlider:SetMinMaxValues(TEXT_SCALE_MIN, TEXT_SCALE_MAX)
textSizeSlider:SetValueStep(TEXT_SCALE_STEP)
textSizeSlider:SetObeyStepOnDrag(true)

local textSizeSliderBg = textSizeSlider:CreateTexture(nil, "BACKGROUND")
textSizeSliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
textSizeSliderBg:SetHeight(8)
textSizeSliderBg:SetPoint("LEFT",  textSizeSlider)
textSizeSliderBg:SetPoint("RIGHT", textSizeSlider)
textSizeSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

local textSizeValueText = textSizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
textSizeValueText:SetPoint("TOP", textSizeSlider, "BOTTOM", 0, -4)
UI.ApplyBodyText(textSizeValueText)

textSizeSlider:SetScript("OnValueChanged", function(self, value)
    textSizeValueText:SetText(string.format("%.0f%%", value * 100))
    OS2.SetTextScale(value)
end)

textSizeSlider:SetValue(OS2.GetTextScale())
OS2.textSizeSlider = textSizeSlider

local iconSizeLabel = affichage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
iconSizeLabel:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -200)
iconSizeLabel:SetText("Taille des icônes du menu")
UI.ApplyLabel(iconSizeLabel)

local iconSizeSlider = CreateFrame("Slider", nil, affichage)
iconSizeSlider:SetSize(PANEL_W - 28, 14)
iconSizeSlider:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -216)
iconSizeSlider:SetOrientation("HORIZONTAL")
iconSizeSlider:SetMinMaxValues(24, 64)
iconSizeSlider:SetValueStep(2)
iconSizeSlider:SetObeyStepOnDrag(true)

local iconSizeSliderBg = iconSizeSlider:CreateTexture(nil, "BACKGROUND")
iconSizeSliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
iconSizeSliderBg:SetHeight(8)
iconSizeSliderBg:SetPoint("LEFT",  iconSizeSlider)
iconSizeSliderBg:SetPoint("RIGHT", iconSizeSlider)

iconSizeSlider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

local iconSizeValueText = iconSizeSlider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
iconSizeValueText:SetPoint("TOP", iconSizeSlider, "BOTTOM", 0, -4)
UI.ApplyBodyText(iconSizeValueText)

iconSizeSlider:SetScript("OnValueChanged", function(self, value)
    local size = math.floor(value + 0.5)
    iconSizeValueText:SetText(string.format("%d px", size))
    if OS2.SetIconSize then
        OS2.SetIconSize(size)
    end
end)

iconSizeSlider:SetValue(OS2.GetIconSize and OS2.GetIconSize() or 36)
OS2.iconSizeSlider = iconSizeSlider

local windowSizeLabel = affichage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
windowSizeLabel:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -266)
windowSizeLabel:SetText("Taille des fenêtres")
UI.ApplyLabel(windowSizeLabel)

local function NormalizeWindowScale(value)
    local steps = math.floor((((tonumber(value) or 1.0) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    local scale = WINDOW_SCALE_MIN + (steps * WINDOW_SCALE_STEP)
    return math.max(WINDOW_SCALE_MIN, math.min(WINDOW_SCALE_MAX, scale))
end

local windowScaleDecBtn = CreatePanelButton(affichage, 26, 22, "<")
windowScaleDecBtn:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -284)

local windowScaleValueBox = CreateFrame("Frame", nil, affichage)
windowScaleValueBox:SetSize(PANEL_W - 96, 22)
windowScaleValueBox:SetPoint("LEFT", windowScaleDecBtn, "RIGHT", 4, 0)

local windowScaleValueBg = windowScaleValueBox:CreateTexture(nil, "BACKGROUND")
windowScaleValueBg:SetAllPoints()
windowScaleValueBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local windowScaleValueBorder = windowScaleValueBox:CreateTexture(nil, "BORDER")
windowScaleValueBorder:SetAllPoints()
windowScaleValueBorder:SetColorTexture(UI.colors.panelButtonAccent[1], UI.colors.panelButtonAccent[2], UI.colors.panelButtonAccent[3], 0.50)

local windowScaleValueText = windowScaleValueBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
windowScaleValueText:SetPoint("CENTER", windowScaleValueBox, "CENTER", 0, 0)
UI.ApplyBodyText(windowScaleValueText)

local windowScaleIncBtn = CreatePanelButton(affichage, 26, 22, ">")
windowScaleIncBtn:SetPoint("LEFT", windowScaleValueBox, "RIGHT", 4, 0)

local function SetScaleBtnState(btn, enabled)
    btn:SetEnabled(enabled)
    btn:SetAlpha(enabled and 1 or 0.35)
    btn:EnableMouse(enabled)
end

local function SetWindowScaleFromControl(value)
    local scale = NormalizeWindowScale(value)
    windowScaleValueText:SetText(string.format("%.0f%%", scale * 100))
    SetScaleBtnState(windowScaleDecBtn, scale > WINDOW_SCALE_MIN)
    SetScaleBtnState(windowScaleIncBtn, scale < WINDOW_SCALE_MAX)
    if OS2.SetWindowScale then
        OS2.SetWindowScale(scale)
    end
end

windowScaleDecBtn:SetScript("OnClick", function()
    SetWindowScaleFromControl((OS2.GetWindowScale and OS2.GetWindowScale() or 1.0) - WINDOW_SCALE_STEP)
end)

windowScaleIncBtn:SetScript("OnClick", function()
    SetWindowScaleFromControl((OS2.GetWindowScale and OS2.GetWindowScale() or 1.0) + WINDOW_SCALE_STEP)
end)

OS2.RefreshWindowScaleControl = function()
    local scale = NormalizeWindowScale(OS2.GetWindowScale and OS2.GetWindowScale() or 1.0)
    windowScaleValueText:SetText(string.format("%.0f%%", scale * 100))
    SetScaleBtnState(windowScaleDecBtn, scale > WINDOW_SCALE_MIN)
    SetScaleBtnState(windowScaleIncBtn, scale < WINDOW_SCALE_MAX)
end

OS2.RefreshWindowScaleControl()

-- Séparateur
local animSep = affichage:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(animSep)
animSep:SetHeight(1)
animSep:SetPoint("TOPLEFT",  affichage, "TOPLEFT",  14, -324)
animSep:SetPoint("TOPRIGHT", affichage, "TOPRIGHT", -14, -324)

-- Checkbox animations
local animCheck, animLabel = UI.CreateStyledCheckbox(affichage, "Activer les animations")
animCheck:SetSize(18, 18)
animCheck:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -338)
animLabel:SetPoint("LEFT", animCheck, "RIGHT", 6, 0)

animCheck:SetScript("OnClick", function(self)
    OS2.SetAnimationsEnabled(self:GetChecked())
end)

-- sync checkbox state on panel open
panel:HookScript("OnShow", function()
    animCheck:SetChecked(OS2.AnimationsEnabled())
    if OS2.textSizeSlider then OS2.textSizeSlider:SetValue(OS2.GetTextScale()) end
end)

OS2.animCheck = animCheck

------------------------------------------------------------------------
-- Séparateur + sélecteur Type de menu
------------------------------------------------------------------------
local menuTypeSep = affichage:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(menuTypeSep)
menuTypeSep:SetHeight(1)
menuTypeSep:SetPoint("TOPLEFT",  affichage, "TOPLEFT",  14, -368)
menuTypeSep:SetPoint("TOPRIGHT", affichage, "TOPRIGHT", -14, -368)

local menuTypeLabel = affichage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
menuTypeLabel:SetPoint("TOPLEFT", affichage, "TOPLEFT", 14, -382)
menuTypeLabel:SetText("Type de menu")
UI.ApplyLabel(menuTypeLabel)

local MENU_TYPE_OPTIONS = {
    { key = "bas",    label = "Vers le bas"    },
    { key = "droite", label = "Vers la droite" },
    { key = "gauche", label = "Vers la gauche" },
    { key = "cercle", label = "Cercle"         },
}

-- 2 boutons par rangée, avec 4 px de gouttière entre eux
local HALF_BTN_W = math.floor((PANEL_W - 28 - 4) / 2)
local menuTypeButtons = {}

for i, opt in ipairs(MENU_TYPE_OPTIONS) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    local xOff = 14 + col * (HALF_BTN_W + 4)
    local yOff = -400 - row * 26

    local btn = CreatePanelButton(affichage, HALF_BTN_W, 22, opt.label)
    btn:SetPoint("TOPLEFT", affichage, "TOPLEFT", xOff, yOff)

    -- Indicateur de sélection active : ligne colorée en bas du bouton
    local activeLine = btn:CreateTexture(nil, "OVERLAY")
    activeLine:SetHeight(2)
    activeLine:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  2, 1)
    activeLine:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)
    activeLine:SetColorTexture(unpack(UI.colors.tabLine))
    activeLine:Hide()
    btn.activeLine = activeLine

    btn.menuKey = opt.key
    btn:SetScript("OnClick", function()
        if OS2.SetMenuType then OS2.SetMenuType(btn.menuKey) end
    end)

    menuTypeButtons[i] = btn
end

OS2.RefreshMenuTypeButtons = function()
    local current = OS2.GetMenuType and OS2.GetMenuType() or "bas"
    for _, btn in ipairs(menuTypeButtons) do
        local active = (btn.menuKey == current)
        btn.activeLine:SetShown(active)
        btn.bgN:SetColorTexture(
            active and 0.18 or 0.10,
            active and 0.15 or 0.10,
            active and 0.08 or 0.10, 1)
    end
end

panel:HookScript("OnShow", function()
    if OS2.RefreshMenuTypeButtons then OS2.RefreshMenuTypeButtons() end
    -- Resynchronise les cases Module à chaque ouverture (OS2DB est chargé à ce stade)
    if OS2.RefreshSettingsModules then OS2.RefreshSettingsModules() end
    if OS2.RefreshSettingsProfileControl then OS2.RefreshSettingsProfileControl() end
end)

------------------------------------------------------------------------
-- Onglet 2 : Options
------------------------------------------------------------------------
local options = tabContent[2]

-- ── Section Profil ─────────────────────────────────────────────────────
local profileTitle = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profileTitle:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -16)
profileTitle:SetText("Profil")
UI.ApplyLabel(profileTitle)

local profileHelp = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
profileHelp:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -32)
profileHelp:SetPoint("RIGHT",   options, "RIGHT",   -14, 0)
profileHelp:SetJustifyH("LEFT")
profileHelp:SetJustifyV("TOP")
profileHelp:SetText("Changez de profil pour consulter une base de donnée différente et faciliter les échanges entre MJ et personnage.")
UI.ApplyBodyText(profileHelp)

local profileDropdown = CreateFrame("Frame", "OS2_ProfileDropdown", options, "UIDropDownMenuTemplate")
profileDropdown:SetPoint("TOPLEFT", options, "TOPLEFT", 2, -70)
UIDropDownMenu_SetWidth(profileDropdown, PANEL_W - 46)
UIDropDownMenu_SetText(profileDropdown, OS2.GetActiveProfileName and OS2.GetActiveProfileName() or "Profil")
StyleDropdown(profileDropdown)

local HALF_OPT_BTN_W = math.floor((PANEL_W - 28 - 6) / 2)
local createProfileBtn = CreatePanelButton(options, HALF_OPT_BTN_W, 22, "Nouveau profil")
createProfileBtn:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -103)

local deleteProfileBtn = CreatePanelButton(options, HALF_OPT_BTN_W, 22, "Supprimer")
deleteProfileBtn:SetPoint("TOPRIGHT", options, "TOPRIGHT", -14, -103)

local profileSep = options:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(profileSep)
profileSep:SetHeight(1)
profileSep:SetPoint("TOPLEFT",  options, "TOPLEFT",  14, -132)
profileSep:SetPoint("TOPRIGHT", options, "TOPRIGHT", -14, -132)

-- ── Section Base de donnée ────────────────────────────────────────────
local optionsText = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
optionsText:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -146)
optionsText:SetPoint("RIGHT",   options, "RIGHT",   -14, 0)
optionsText:SetJustifyH("LEFT")
optionsText:SetJustifyV("TOP")
optionsText:SetText("Consultez et gérez les données sauvegardées du profil actif.")
UI.ApplyBodyText(optionsText)

local dbBtn = CreatePanelButton(options, PANEL_W - 28, 22, "Base de donnée")
dbBtn:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -174)
dbBtn:SetScript("OnClick", function()
    if OS2.ToggleDBPanel then OS2.ToggleDBPanel(panel) end
end)
OS2.dbBtn = dbBtn

local function SetProfileDeleteState(enabled)
    deleteProfileBtn:SetEnabled(enabled)
    deleteProfileBtn.bgN:SetColorTexture(
        enabled and 0.10 or 0.05,
        enabled and 0.10 or 0.05,
        enabled and 0.10 or 0.05,
        enabled and 1.00 or 0.85
    )
    local label = deleteProfileBtn:GetFontString()
    if label then
        label:SetTextColor(
            enabled and UI.colors.text[1] or UI.colors.textSoft[1],
            enabled and UI.colors.text[2] or UI.colors.textSoft[2],
            enabled and UI.colors.text[3] or UI.colors.textSoft[3],
            1
        )
    end
end

StaticPopupDialogs["OS2_CREATE_PROFILE"] = {
    text = "Nom du nouveau profil",
    button1 = "Créer",
    button2 = "Annuler",
    hasEditBox = true,
    maxLetters = 24,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnShow = function(self)
        self.editBox:SetText("")
        self.editBox:SetFocus()
    end,
    OnAccept = function(self)
        local value = self.editBox:GetText()
        local ok, result = OS2.CreateProfile and OS2.CreateProfile(value)
        if not ok then
            if OS2.Notify then
                OS2.Notify(result or "Impossible de créer ce profil.", 1, 0.85, 0.35)
            end
            return
        end
        if OS2.SetActiveProfile then
            OS2.SetActiveProfile(result)
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        parent.button1:Click()
    end,
}

StaticPopupDialogs["OS2_DELETE_PROFILE"] = {
    text = "Supprimer le profil actif ?",
    button1 = "Supprimer",
    button2 = "Annuler",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        local profileName = OS2.GetActiveProfileName and OS2.GetActiveProfileName()
        local ok, message = OS2.DeleteProfile and OS2.DeleteProfile(profileName)
        if not ok and OS2.Notify then
            OS2.Notify(message or "Impossible de supprimer ce profil.", 1, 0.85, 0.35)
        end
    end,
}

UIDropDownMenu_Initialize(profileDropdown, function(self, level)
    local currentProfile = OS2.GetActiveProfileName and OS2.GetActiveProfileName() or ""
    for _, profileName in ipairs(OS2.GetProfileNames and OS2.GetProfileNames() or {}) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = FormatDropdownItemLabel(profileName, profileName == currentProfile)
        info.value = profileName
        info.notCheckable = true
        info.func = function()
            UIDropDownMenu_SetSelectedValue(profileDropdown, profileName)
            UIDropDownMenu_SetText(profileDropdown, profileName)
            if OS2.SetActiveProfile then
                OS2.SetActiveProfile(profileName)
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

createProfileBtn:SetScript("OnClick", function()
    StaticPopup_Show("OS2_CREATE_PROFILE")
end)

deleteProfileBtn:SetScript("OnClick", function()
    if (OS2.GetProfileNames and #OS2.GetProfileNames() or 0) <= 1 then
        if OS2.Notify then
            OS2.Notify("Vous devez conserver au moins un profil.", 1, 0.85, 0.35)
        end
        return
    end
    StaticPopup_Show("OS2_DELETE_PROFILE")
end)

OS2.RefreshSettingsProfileControl = function()
    local current = OS2.GetActiveProfileName and OS2.GetActiveProfileName() or "Profil"
    UIDropDownMenu_SetSelectedValue(profileDropdown, current)
    UIDropDownMenu_SetText(profileDropdown, current)
    SetProfileDeleteState((OS2.GetProfileNames and #OS2.GetProfileNames() or 0) > 1)
end

OS2.RefreshSettingsProfileControl()

-- ── Séparateur + Section Réinitialisation ─────────────────────────────
-- Layout top-down, directement sous "Base de donnée" (bottom ≈ -196).
local optionsSep = options:CreateTexture(nil, "ARTWORK")
UI.ApplySeparator(optionsSep)
optionsSep:SetHeight(1)
optionsSep:SetPoint("TOPLEFT",  options, "TOPLEFT",   14, -210)
optionsSep:SetPoint("TOPRIGHT", options, "TOPRIGHT", -14, -210)

local resetDesc = options:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resetDesc:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -222)
resetDesc:SetPoint("RIGHT",   options, "RIGHT",   -14, 0)
resetDesc:SetJustifyH("LEFT")
resetDesc:SetJustifyV("TOP")
resetDesc:SetText("Réinitialise le personnage, ou supprime tous les profils et toutes les données.")
UI.ApplyBodyText(resetDesc)

-- Bouton réinitialisation totale (tous les profils + toutes les données).
local totalResetBtn = CreatePanelButton(options, PANEL_W - 28, 22, "Réinit. totale")
totalResetBtn:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -262)

-- Bouton réinitialisation personnage uniquement.
local resetAllBtn = CreatePanelButton(options, PANEL_W - 28, 22, "Réinitialisation")
resetAllBtn:SetPoint("TOPLEFT", options, "TOPLEFT", 14, -290)

-- ── Panneau de confirmation (style addon) ─────────────────────────────
local confirmPanel = CreateFrame("Frame", nil, UIParent)
confirmPanel:SetSize(292, 148)
confirmPanel:SetFrameStrata("TOOLTIP")
confirmPanel:SetFrameLevel(100)
confirmPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
confirmPanel:Hide()

do
    local cpBg = confirmPanel:CreateTexture(nil, "BACKGROUND")
    cpBg:SetAllPoints(); UI.ApplyWindowBackground(cpBg, 0.98)
    if OS2.RegisterWindowFrame then
        OS2.RegisterWindowFrame(confirmPanel, cpBg)
    else
        confirmPanel:EnableMouse(true)
        if confirmPanel.SetPropagateMouseClicks then
            confirmPanel:SetPropagateMouseClicks(false)
        end
    end

    -- Titre
    local cpTitle = confirmPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cpTitle:SetPoint("TOP", confirmPanel, "TOP", 0, -12)
    cpTitle:SetText("Réinitialisation")
    UI.ApplyTitle(cpTitle)

    -- Séparateur titre
    local cpSep = confirmPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(cpSep); cpSep:SetHeight(1)
    cpSep:SetPoint("TOPLEFT",  confirmPanel, "TOPLEFT",  0, -34)
    cpSep:SetPoint("TOPRIGHT", confirmPanel, "TOPRIGHT", 0, -34)

    -- Drag depuis l'entête
    local cpDrag = CreateFrame("Frame", nil, confirmPanel)
    cpDrag:SetPoint("TOPLEFT",  confirmPanel, "TOPLEFT",  0, 0)
    cpDrag:SetPoint("TOPRIGHT", confirmPanel, "TOPRIGHT", 0, 0)
    cpDrag:SetHeight(34)
    OS2.MakeDraggable(confirmPanel, cpDrag)

    -- Texte question
    local cpText = confirmPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpText:SetPoint("TOPLEFT", confirmPanel, "TOPLEFT", 14, -44)
    cpText:SetPoint("RIGHT",   confirmPanel, "RIGHT",   -14, 0)
    cpText:SetJustifyH("LEFT"); cpText:SetJustifyV("TOP")
    cpText:SetText("Réinitialiser OmegaSurvive pour ce personnage ?")
    UI.ApplyBodyText(cpText)

    -- Texte avertissement
    local cpWarn = confirmPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpWarn:SetPoint("TOPLEFT", confirmPanel, "TOPLEFT", 14, -66)
    cpWarn:SetPoint("RIGHT",   confirmPanel, "RIGHT",   -14, 0)
    cpWarn:SetJustifyH("LEFT"); cpWarn:SetJustifyV("TOP")
    cpWarn:SetText("Attention, cette action entraînera une suppression de toutes les données de l'addon.")
    UI.ApplyWarningText(cpWarn)

    -- Séparateur bas
    local cpSep2 = confirmPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(cpSep2); cpSep2:SetHeight(1)
    cpSep2:SetPoint("BOTTOMLEFT",  confirmPanel, "BOTTOMLEFT",  0, 14 + 22 + 6)
    cpSep2:SetPoint("BOTTOMRIGHT", confirmPanel, "BOTTOMRIGHT", 0, 14 + 22 + 6)

    local HALF = math.floor((292 - 28 - 6) / 2)

    local cpConfirm = CreatePanelButton(confirmPanel, HALF, 22, "Confirmer")
    cpConfirm:SetPoint("BOTTOMLEFT", confirmPanel, "BOTTOMLEFT", 14, 14)
    cpConfirm:SetScript("OnClick", function()
        confirmPanel:Hide()
        if OS2.ResetAddonData then OS2.ResetAddonData() end
    end)

    local cpCancel = CreatePanelButton(confirmPanel, HALF, 22, "Annuler")
    cpCancel:SetPoint("BOTTOMRIGHT", confirmPanel, "BOTTOMRIGHT", -14, 14)
    cpCancel:SetScript("OnClick", function() confirmPanel:Hide() end)
end

resetAllBtn:SetScript("OnClick", function()
    confirmPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    confirmPanel:Show()
end)

-- ── Panneau de confirmation : réinitialisation totale ─────────────────
local totalConfirmPanel = CreateFrame("Frame", nil, UIParent)
totalConfirmPanel:SetSize(292, 148)
totalConfirmPanel:SetFrameStrata("TOOLTIP")
totalConfirmPanel:SetFrameLevel(100)
totalConfirmPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
totalConfirmPanel:Hide()

do
    local cpBg = totalConfirmPanel:CreateTexture(nil, "BACKGROUND")
    cpBg:SetAllPoints(); UI.ApplyWindowBackground(cpBg, 0.98)
    if OS2.RegisterWindowFrame then
        OS2.RegisterWindowFrame(totalConfirmPanel, cpBg)
    else
        totalConfirmPanel:EnableMouse(true)
        if totalConfirmPanel.SetPropagateMouseClicks then
            totalConfirmPanel:SetPropagateMouseClicks(false)
        end
    end

    local cpTitle = totalConfirmPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cpTitle:SetPoint("TOP", totalConfirmPanel, "TOP", 0, -12)
    cpTitle:SetText("Réinitialisation totale")
    UI.ApplyTitle(cpTitle)

    local cpSep = totalConfirmPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(cpSep); cpSep:SetHeight(1)
    cpSep:SetPoint("TOPLEFT",  totalConfirmPanel, "TOPLEFT",  0, -34)
    cpSep:SetPoint("TOPRIGHT", totalConfirmPanel, "TOPRIGHT", 0, -34)

    local cpDrag = CreateFrame("Frame", nil, totalConfirmPanel)
    cpDrag:SetPoint("TOPLEFT",  totalConfirmPanel, "TOPLEFT",  0, 0)
    cpDrag:SetPoint("TOPRIGHT", totalConfirmPanel, "TOPRIGHT", 0, 0)
    cpDrag:SetHeight(34)
    OS2.MakeDraggable(totalConfirmPanel, cpDrag)

    local cpText = totalConfirmPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpText:SetPoint("TOPLEFT", totalConfirmPanel, "TOPLEFT", 14, -44)
    cpText:SetPoint("RIGHT",   totalConfirmPanel, "RIGHT",   -14, 0)
    cpText:SetJustifyH("LEFT"); cpText:SetJustifyV("TOP")
    cpText:SetText("Supprimer TOUS les profils et toutes les données ?")
    UI.ApplyBodyText(cpText)

    local cpWarn = totalConfirmPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cpWarn:SetPoint("TOPLEFT", totalConfirmPanel, "TOPLEFT", 14, -66)
    cpWarn:SetPoint("RIGHT",   totalConfirmPanel, "RIGHT",   -14, 0)
    cpWarn:SetJustifyH("LEFT"); cpWarn:SetJustifyV("TOP")
    cpWarn:SetText("Supprime tous les profils de tous les personnages. Irréversible.")
    UI.ApplyWarningText(cpWarn)

    local cpSep2 = totalConfirmPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(cpSep2); cpSep2:SetHeight(1)
    cpSep2:SetPoint("BOTTOMLEFT",  totalConfirmPanel, "BOTTOMLEFT",  0, 14 + 22 + 6)
    cpSep2:SetPoint("BOTTOMRIGHT", totalConfirmPanel, "BOTTOMRIGHT", 0, 14 + 22 + 6)

    local HALF = math.floor((292 - 28 - 6) / 2)

    local cpConfirm = CreatePanelButton(totalConfirmPanel, HALF, 22, "Confirmer")
    cpConfirm:SetPoint("BOTTOMLEFT", totalConfirmPanel, "BOTTOMLEFT", 14, 14)
    cpConfirm:SetScript("OnClick", function()
        totalConfirmPanel:Hide()
        if OS2.TotalReset then OS2.TotalReset() end
    end)

    local cpCancel = CreatePanelButton(totalConfirmPanel, HALF, 22, "Annuler")
    cpCancel:SetPoint("BOTTOMRIGHT", totalConfirmPanel, "BOTTOMRIGHT", -14, 14)
    cpCancel:SetScript("OnClick", function() totalConfirmPanel:Hide() end)
end

totalResetBtn:SetScript("OnClick", function()
    totalConfirmPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    totalConfirmPanel:Show()
end)

------------------------------------------------------------------------
-- Onglet 3 : Module
------------------------------------------------------------------------
local modules = tabContent[3]

local modulesText = modules:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
modulesText:SetPoint("TOPLEFT", modules, "TOPLEFT", 14, -16)
modulesText:SetPoint("RIGHT",   modules, "RIGHT",   -14, 0)
modulesText:SetJustifyH("LEFT")
modulesText:SetJustifyV("TOP")
modulesText:SetText("Activez ou désactivez les modules visibles dans le menu principal.")
UI.ApplyBodyText(modulesText)

local modulesHelp = modules:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
modulesHelp:SetPoint("TOPLEFT", modules, "TOPLEFT", 14, -44)
modulesHelp:SetPoint("RIGHT",   modules, "RIGHT",   -14, 0)
modulesHelp:SetJustifyH("LEFT")
modulesHelp:SetJustifyV("TOP")
modulesHelp:SetText("Glissez-déposez une ligne pour changer l'ordre d'affichage des modules.")
UI.ApplySoftText(modulesHelp)

local moduleRows = {}
tabContent[3].moduleRows = moduleRows

local function SaveModuleOrderFromRows()
    local keys = {}
    for _, row in ipairs(moduleRows) do
        keys[#keys + 1] = row.moduleKey
    end
    if OS2.SetModuleOrder then
        OS2.SetModuleOrder(keys)
    end
end

local function LayoutModuleRows()
    for index, row in ipairs(moduleRows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", modules, "TOPLEFT", 14, -74 - ((index - 1) * 30))
    end
end

local dragRow

local function CreateModuleRow(parent, moduleInfo)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANEL_W - 28, 24)
    row:EnableMouse(true)
    row.moduleKey = moduleInfo.key

    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints()
    rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.65)
    row.bg = rowBg

    local rowAccent = row:CreateTexture(nil, "ARTWORK")
    rowAccent:SetHeight(1)
    rowAccent:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 1)
    rowAccent:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 1)
    rowAccent:SetColorTexture(unpack(UI.colors.panelButtonAccent))

    local rowHl = row:CreateTexture(nil, "HIGHLIGHT")
    rowHl:SetAllPoints()
    rowHl:SetColorTexture(unpack(UI.colors.panelButtonHighlight))

    local check, label = UI.CreateStyledCheckbox(row, moduleInfo.label)
    check:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetPoint("LEFT", check, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -22, 0)
    label:SetJustifyH("LEFT")
    check.moduleKey = moduleInfo.key
    row.check = check
    row.label = label

    check:SetScript("OnClick", function(self)
        if OS2.SetModuleEnabled then
            OS2.SetModuleEnabled(self.moduleKey, self:GetChecked())
        end
    end)

    local grip = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    grip:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    grip:SetText("|||")
    UI.ApplyMutedText(grip)
    row.grip = grip

    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function(self)
        dragRow = self
        self:SetAlpha(0.65)
    end)
    row:SetScript("OnDragStop", function(self)
        local targetIndex
        self:SetAlpha(1)

        for index, other in ipairs(moduleRows) do
            if other ~= self and other:IsShown() and other:IsMouseOver() then
                targetIndex = index
                break
            end
        end

        if targetIndex then
            local fromIndex
            for index, other in ipairs(moduleRows) do
                if other == self then
                    fromIndex = index
                    break
                end
            end

            if fromIndex and fromIndex ~= targetIndex then
                table.remove(moduleRows, fromIndex)
                table.insert(moduleRows, targetIndex, self)
                LayoutModuleRows()
                SaveModuleOrderFromRows()
            end
        end

        dragRow = nil
    end)

    return row
end

for _, moduleInfo in ipairs(OS2.GetToggleableModules()) do
    moduleRows[#moduleRows + 1] = CreateModuleRow(modules, moduleInfo)
end

local function RefreshModuleTab()
    local orderedModules = OS2.GetToggleableModules()
    local rowsByKey = {}
    local newRows = {}

    for _, row in ipairs(moduleRows) do
        rowsByKey[row.moduleKey] = row
    end

    for _, moduleInfo in ipairs(orderedModules) do
        local row = rowsByKey[moduleInfo.key]
        if row then
            row.label:SetText(moduleInfo.label)
            row.check:SetChecked(OS2.IsModuleEnabled and OS2.IsModuleEnabled(moduleInfo.key))
            newRows[#newRows + 1] = row
        end
    end

    wipe(moduleRows)
    for index, row in ipairs(newRows) do
        moduleRows[index] = row
    end

    LayoutModuleRows()

    if selectedTab == 3 then
        SetTabHeight(104 + math.max(0, #moduleRows - 1) * 30 + 26)
    end
end

OS2.RefreshSettingsModules = RefreshModuleTab
RefreshModuleTab()

------------------------------------------------------------------------
-- Onglet 4 : Crédit
------------------------------------------------------------------------
local credits = tabContent[4]

local creditsText = credits:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
creditsText:SetPoint("TOPLEFT", credits, "TOPLEFT", 14, -16)
creditsText:SetPoint("RIGHT",   credits, "RIGHT",   -14, 0)
creditsText:SetJustifyH("LEFT")
creditsText:SetText("Omega Survive\nVersion : 2.0\nSystème de survie RP.\n \nCréer par Akriax")
UI.ApplyBodyText(creditsText)

------------------------------------------------------------------------
-- Sélection initiale
------------------------------------------------------------------------
SelectTab(1)
