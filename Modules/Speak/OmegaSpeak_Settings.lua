-- OmegaSpeak — Paramètres
OmegaSpeak = OmegaSpeak or {}
local OS = OmegaSpeak
local UI = OmegaSpeak.UI

local PANEL_W = 240
local WINDOW_SCALE_MIN, WINDOW_SCALE_MAX, WINDOW_SCALE_STEP = 0.60, 1.60, 0.05

local DEFAULTS = {
    launcherSize  = 36,
    windowScale   = 1.0,
    windowOpacity = 0.92,
}

local function Clamp(v, lo, hi)
    return math.max(lo, math.min(hi, tonumber(v) or lo))
end

-- //////////////////////////////////////////////////////////
-- API publique : getters / setters
-- //////////////////////////////////////////////////////////

function OS:GetSettings()
    OmegaSpeakDB = OmegaSpeakDB or {}
    OmegaSpeakDB.settings = OmegaSpeakDB.settings or {}
    local s = OmegaSpeakDB.settings
    if s.launcherSize  == nil then s.launcherSize  = DEFAULTS.launcherSize  end
    if s.windowScale   == nil then s.windowScale   = DEFAULTS.windowScale   end
    if s.windowOpacity == nil then s.windowOpacity = DEFAULTS.windowOpacity end
    return s
end

function OS:SetLauncherSize(size)
    size = Clamp(size, 20, 72)
    OS:GetSettings().launcherSize = size
    if OS.Launcher then
        OS.Launcher:SetSize(size, size)
    end
end

function OS:SetWindowScale(scale)
    local steps = math.floor(((Clamp(scale, WINDOW_SCALE_MIN, WINDOW_SCALE_MAX) - WINDOW_SCALE_MIN) / WINDOW_SCALE_STEP) + 0.5)
    scale = WINDOW_SCALE_MIN + steps * WINDOW_SCALE_STEP
    OS:GetSettings().windowScale = scale
    if OS.panel then
        OS.panel:SetScale(scale)
    end
end

function OS:SetWindowOpacity(value)
    value = Clamp(value, 0.05, 1.0)
    OS:GetSettings().windowOpacity = value
    if OS.panel and OS.panel.bg then
        UI.ApplyWindowBackground(OS.panel.bg, value)
    end
end

function OS:ApplySettings()
    if not OmegaSpeakDB or not OmegaSpeakDB.settings then return end
    local s = OS:GetSettings()
    OS:SetLauncherSize(s.launcherSize)
    OS:SetWindowScale(s.windowScale)
    OS:SetWindowOpacity(s.windowOpacity)
end

-- //////////////////////////////////////////////////////////
-- Panneau paramètres
-- //////////////////////////////////////////////////////////

local settingsPanel = CreateFrame("Frame", "OmegaSpeakSettingsPanel", UIParent)
settingsPanel:SetSize(PANEL_W, 208)
settingsPanel:SetFrameStrata("DIALOG")
settingsPanel:SetMovable(true)
settingsPanel:SetClampedToScreen(true)
settingsPanel:EnableMouse(true)
settingsPanel:Hide()

local sBg = settingsPanel:CreateTexture(nil, "BACKGROUND")
sBg:SetAllPoints()
UI.ApplyWindowBackground(sBg, 0.92)

for _, pts in ipairs({
    { {"TOPLEFT","TOPLEFT",1,-1},    {"TOPRIGHT","TOPRIGHT",-1,-1}    },
    { {"BOTTOMLEFT","BOTTOMLEFT",1,1},{"BOTTOMRIGHT","BOTTOMRIGHT",-1,1}},
    { {"TOPLEFT","TOPLEFT",1,-1},    {"BOTTOMLEFT","BOTTOMLEFT",1,1}  },
    { {"TOPRIGHT","TOPRIGHT",-1,-1}, {"BOTTOMRIGHT","BOTTOMRIGHT",-1,1}},
}) do
    local t = settingsPanel:CreateTexture(nil, "ARTWORK")
    t:SetPoint(pts[1][1], settingsPanel, pts[1][2], pts[1][3], pts[1][4])
    t:SetPoint(pts[2][1], settingsPanel, pts[2][2], pts[2][3], pts[2][4])
    t:SetColorTexture(0.60, 0.52, 0.28, 1)
    if pts[1][1] == "TOPLEFT" and pts[2][1] == "BOTTOMLEFT" then
        t:SetWidth(1)
    elseif pts[1][1] == "TOPRIGHT" then
        t:SetWidth(1)
    else
        t:SetHeight(1)
    end
end

local sTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 10, -10)
sTitle:SetText("Paramètres — Speak")
UI.ApplyTitle(sTitle)

UI.CreateCloseButton(settingsPanel, function() settingsPanel:Hide() end)

local sDragHandle = CreateFrame("Frame", nil, settingsPanel)
sDragHandle:SetPoint("TOPLEFT")
sDragHandle:SetPoint("TOPRIGHT")
sDragHandle:SetHeight(30)
sDragHandle:EnableMouse(true)
sDragHandle:SetScript("OnMouseDown", function() settingsPanel:StartMoving() end)
sDragHandle:SetScript("OnMouseUp",   function() settingsPanel:StopMovingOrSizing() end)

local sSep = settingsPanel:CreateTexture(nil, "ARTWORK")
sSep:SetPoint("TOPLEFT",  settingsPanel, "TOPLEFT",  0, -30)
sSep:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", 0, -30)
sSep:SetHeight(1)
UI.ApplySeparator(sSep)

local function MakeSlider(labelText, yTop, minV, maxV, step, formatter, onChanged)
    local label = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, yTop)
    label:SetText(labelText)
    UI.ApplyLabel(label)

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
    UI.ApplyBodyText(valueText)

    slider:SetScript("OnValueChanged", function(_, value)
        valueText:SetText(formatter(value))
        onChanged(value)
    end)

    slider.valueText = valueText
    return slider
end

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
UI.ApplyLabel(wsLabel)

local wsDecBtn = UI.CreatePanelButton(settingsPanel, 26, 22, "<")
wsDecBtn:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 14, -170)

local wsValueBox = CreateFrame("Frame", nil, settingsPanel)
wsValueBox:SetSize(PANEL_W - 96, 22)
wsValueBox:SetPoint("LEFT", wsDecBtn, "RIGHT", 4, 0)

local wsValueBg = wsValueBox:CreateTexture(nil, "BACKGROUND")
wsValueBg:SetAllPoints()
wsValueBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local wsValueBorder = wsValueBox:CreateTexture(nil, "BORDER")
wsValueBorder:SetAllPoints()
wsValueBorder:SetColorTexture(UI.colors.panelButtonAccent[1], UI.colors.panelButtonAccent[2], UI.colors.panelButtonAccent[3], 0.50)

local wsValueText = wsValueBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
wsValueText:SetPoint("CENTER")
UI.ApplyBodyText(wsValueText)

local wsIncBtn = UI.CreatePanelButton(settingsPanel, 26, 22, ">")
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

local function SyncControls()
    local s = OS:GetSettings()
    opacitySlider:SetValue(s.windowOpacity)
    launcherSlider:SetValue(s.launcherSize)
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
        if OS.panel and OS.panel:IsShown() then
            settingsPanel:SetPoint("TOPLEFT", OS.panel, "TOPRIGHT", 8, 0)
        elseif OS.Launcher and OS.Launcher:IsShown() then
            settingsPanel:SetPoint("BOTTOMLEFT", OS.Launcher, "TOPRIGHT", 8, 0)
        else
            settingsPanel:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
        end
        settingsPanel:Show()
    end
end

OS.SettingsPanel = settingsPanel
