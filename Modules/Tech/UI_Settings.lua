-- ============================================================
--  Tech — App SETTINGS : luminosité de l'écran + données
-- ============================================================

local T  = Tech
local UI = OS2.UI
local C  = T.colors

local PAD = 16

local body = T:RegisterApp({
    key   = "settings",
    label = "Settings",
    icon  = "Interface\\Icons\\INV_Misc_Gear_01",
    color = { 0.22, 0.22, 0.26 },
})

-- ── Affichage ──────────────────────────────────────────────────────────────

local dispTitle = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dispTitle:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -PAD)
dispTitle:SetText("Affichage")
dispTitle:SetTextColor(unpack(C.title))

local brightLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
brightLabel:SetPoint("TOPLEFT", dispTitle, "BOTTOMLEFT", 0, -16)
brightLabel:SetText("Luminosité de l'écran")
brightLabel:SetTextColor(unpack(C.textMuted))

local slider = CreateFrame("Slider", nil, body)
slider:SetOrientation("HORIZONTAL")
slider:SetSize(320, 14)
slider:SetPoint("TOPLEFT", brightLabel, "BOTTOMLEFT", 2, -16)
slider:SetMinMaxValues(0.4, 1.0)
slider:SetValueStep(0.05)
slider:SetObeyStepOnDrag(true)

local sliderBg = slider:CreateTexture(nil, "BACKGROUND")
sliderBg:SetTexture("Interface/Buttons/UI-SliderBar-Background")
sliderBg:SetAllPoints()
slider:SetThumbTexture("Interface/Buttons/UI-SliderBar-Button-Horizontal")

local sliderValue = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sliderValue:SetPoint("TOP", slider, "BOTTOM", 0, -4)
sliderValue:SetTextColor(unpack(C.text))

slider:SetScript("OnValueChanged", function(_, value)
    sliderValue:SetText(string.format("%.0f%%", value * 100))
    T:SetBrightness(value)
end)

-- ── Données ────────────────────────────────────────────────────────────────

local sep = body:CreateTexture(nil, "ARTWORK")
sep:SetHeight(1)
sep:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -2, -40)
sep:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, 0)
sep:SetColorTexture(unpack(C.accentDim))

local dataTitle = body:CreateFontString(nil, "OVERLAY", "GameFontNormal")
dataTitle:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 2, -16)
dataTitle:SetText("Données")
dataTitle:SetTextColor(unpack(C.title))

local resetDesc = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resetDesc:SetPoint("TOPLEFT", dataTitle, "BOTTOMLEFT", 0, -6)
resetDesc:SetPoint("RIGHT", body, "RIGHT", -PAD, 0)
resetDesc:SetJustifyH("LEFT")
resetDesc:SetText("Efface les notes, l'inventaire, le store et le journal COMM.")
resetDesc:SetTextColor(unpack(C.textMuted))

local resetBtn = UI.CreatePanelButton(body, 160, 24, "Réinitialiser")
resetBtn:SetPoint("TOPLEFT", resetDesc, "BOTTOMLEFT", 0, -12)
resetBtn:SetScript("OnClick", function()
    StaticPopup_Show("TECH_RESET_DATA")
end)

StaticPopupDialogs["TECH_RESET_DATA"] = {
    text = "Réinitialiser toutes les données de la tablette Tech ?",
    button1 = "Réinitialiser",
    button2 = "Annuler",
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    OnAccept = function()
        T:ResetData()
    end,
}

-- ── Synchronisation ────────────────────────────────────────────────────────

local function SyncControls()
    slider:SetValue(T:GetDB().settings.brightness or 1.0)
end

body:SetScript("OnShow", SyncControls)
SyncControls()
