-- ============================================================
--  Tech — Coque de la tablette
--  Châssis + écran + écran d'accueil (grille d'apps + dock)
--  + verrouillage. Les apps s'enregistrent via T:RegisterApp().
-- ============================================================

local T  = Tech
local UI = OS2.UI
local C  = T.colors

local PANEL_W     = 420
local PANEL_H     = 700
local BEZEL_SIDE  = 16
local BEZEL_TOP   = 32
local BEZEL_BOTTOM = 58
local STATUS_H    = 26

local GRID_COLS  = 3
local ICON_SIZE  = 68
local CELL_W     = 110
local CELL_H     = 104

local DOCK_ICON_SIZE = 52
local DOCK_GAP       = 24

-- ── Châssis ────────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "TechMainPanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:Hide()

local bezelBg = panel:CreateTexture(nil, "BACKGROUND")
bezelBg:SetAllPoints()
bezelBg:SetColorTexture(unpack(C.bezel))

panel:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 14,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
panel:SetBackdropBorderColor(unpack(C.border))

-- Caméra frontale (petit disque au centre du bezel supérieur)
local camMask = panel:CreateMaskTexture()
camMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
local cam = panel:CreateTexture(nil, "ARTWORK")
cam:SetSize(6, 6)
cam:SetPoint("TOP", panel, "TOP", 0, -14)
cam:SetColorTexture(0.10, 0.55, 0.50, 0.9)
cam:AddMaskTexture(camMask)

-- Bouton fermeture (coin du châssis)
local closeBtn = UI.CreateCloseButton(panel, function() panel:Hide() end)
closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -5, -5)
closeBtn:SetFrameLevel(panel:GetFrameLevel() + 10)

-- Bouton latéral "verrouillage" (tranche droite du châssis)
local lockBtn = CreateFrame("Button", nil, panel)
lockBtn:SetSize(6, 46)
lockBtn:SetPoint("RIGHT", panel, "RIGHT", -2, 40)
local lockBtnBg = lockBtn:CreateTexture(nil, "ARTWORK")
lockBtnBg:SetAllPoints()
lockBtnBg:SetColorTexture(unpack(C.accentDim))
local lockBtnHL = lockBtn:CreateTexture(nil, "HIGHLIGHT")
lockBtnHL:SetAllPoints()
lockBtnHL:SetColorTexture(1, 1, 1, 0.3)

-- ── Écran ──────────────────────────────────────────────────────────────────

local screen = CreateFrame("Frame", nil, panel)
screen:SetPoint("TOPLEFT", panel, "TOPLEFT", BEZEL_SIDE, -BEZEL_TOP)
screen:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -BEZEL_SIDE, BEZEL_BOTTOM)
screen:EnableMouse(true) -- capture les clics : on ne fait glisser la tablette que par le châssis

local screenBg = screen:CreateTexture(nil, "BACKGROUND")
screenBg:SetAllPoints()
screenBg:SetColorTexture(unpack(C.bg))

-- Fines lignes de scan décoratives (ambiance holographique)
for i = 1, 8 do
    local line = screen:CreateTexture(nil, "BORDER")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", screen, "TOPLEFT", 0, -i * 74)
    line:SetPoint("TOPRIGHT", screen, "TOPRIGHT", 0, -i * 74)
    line:SetColorTexture(unpack(C.accent))
    line:SetAlpha(0.035)
end

-- ── Barre de statut ────────────────────────────────────────────────────────

local statusBar = CreateFrame("Frame", nil, screen)
statusBar:SetPoint("TOPLEFT", screen, "TOPLEFT")
statusBar:SetPoint("TOPRIGHT", screen, "TOPRIGHT")
statusBar:SetHeight(STATUS_H)

local clockFS = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
clockFS:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
clockFS:SetTextColor(unpack(C.title))

local battery = CreateFrame("Frame", nil, statusBar)
battery:SetSize(20, 10)
battery:SetPoint("RIGHT", statusBar, "RIGHT", -10, 0)

local battNub = battery:CreateTexture(nil, "ARTWORK")
battNub:SetSize(2, 4)
battNub:SetPoint("LEFT", battery, "RIGHT", 0, 0)
battNub:SetColorTexture(unpack(C.textMuted))

local battBorder = battery:CreateTexture(nil, "BORDER")
battBorder:SetAllPoints()
battBorder:SetColorTexture(unpack(C.textMuted))

local battFill = battery:CreateTexture(nil, "ARTWORK")
battFill:SetPoint("TOPLEFT", battery, "TOPLEFT", 1, -1)
battFill:SetPoint("BOTTOMLEFT", battery, "BOTTOMLEFT", 1, 1)
battFill:SetWidth((20 - 2) * 0.82)
battFill:SetColorTexture(unpack(C.logInfo))

local battLabel = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
battLabel:SetPoint("RIGHT", battery, "LEFT", -6, 0)
battLabel:SetText("82%")
battLabel:SetTextColor(unpack(C.textMuted))

local signal = CreateFrame("Frame", nil, statusBar)
signal:SetSize(18, 10)
signal:SetPoint("RIGHT", battLabel, "LEFT", -10, 0)
for i = 1, 4 do
    local bar = signal:CreateTexture(nil, "ARTWORK")
    bar:SetWidth(3)
    bar:SetHeight(4 + i * 2)
    bar:SetPoint("BOTTOMLEFT", signal, "BOTTOMLEFT", (i - 1) * 5, 0)
    bar:SetColorTexture(unpack(C.accent))
end

local statusSep = screen:CreateTexture(nil, "ARTWORK")
statusSep:SetHeight(1)
statusSep:SetPoint("TOPLEFT", statusBar, "BOTTOMLEFT")
statusSep:SetPoint("TOPRIGHT", statusBar, "BOTTOMRIGHT")
statusSep:SetColorTexture(unpack(C.accentDim))
statusSep:SetAlpha(0.5)

local function RefreshClock()
    clockFS:SetText(date("%H:%M"))
end

-- ── Zone d'écran (accueil + apps) ──────────────────────────────────────────

local screenStack = CreateFrame("Frame", nil, screen)
screenStack:SetPoint("TOPLEFT", statusSep, "BOTTOMLEFT")
screenStack:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT")

T.screens = {}
T.currentApp = nil

local homeScreen = CreateFrame("Frame", nil, screenStack)
homeScreen:SetAllPoints()
T.homeScreen = homeScreen

local gridArea = CreateFrame("Frame", nil, homeScreen)
gridArea:SetPoint("TOP", homeScreen, "TOP", 0, -18)
gridArea:SetSize(GRID_COLS * CELL_W, 3 * CELL_H)

local dock = CreateFrame("Frame", nil, homeScreen)
dock:SetPoint("BOTTOM", homeScreen, "BOTTOM", 0, 16)
dock:SetSize(3 * DOCK_ICON_SIZE + 2 * DOCK_GAP, DOCK_ICON_SIZE + 22)

local dockBg = dock:CreateTexture(nil, "BACKGROUND")
dockBg:SetPoint("TOPLEFT", 0, -8)
dockBg:SetPoint("BOTTOMRIGHT", 0, 0)
dockBg:SetColorTexture(1, 1, 1, 0.03)

local dockSep = homeScreen:CreateTexture(nil, "ARTWORK")
dockSep:SetHeight(1)
dockSep:SetPoint("BOTTOMLEFT", dock, "TOPLEFT", 0, 14)
dockSep:SetPoint("BOTTOMRIGHT", dock, "TOPRIGHT", 0, 14)
dockSep:SetColorTexture(unpack(C.accentDim))
dockSep:SetAlpha(0.4)

-- ── Écran de verrouillage ──────────────────────────────────────────────────

local lockScreen = CreateFrame("Button", nil, screen)
lockScreen:SetAllPoints()
lockScreen:SetFrameLevel(screen:GetFrameLevel() + 30)
lockScreen:Hide()
T.LockScreen = lockScreen

local lockBg = lockScreen:CreateTexture(nil, "BACKGROUND")
lockBg:SetAllPoints()
lockBg:SetColorTexture(0.01, 0.02, 0.02, 0.97)

local lockClock = lockScreen:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockClock:SetPoint("CENTER", lockScreen, "CENTER", 0, 30)
lockClock:SetFont("Fonts\\FRIZQT__.TTF", 40, "OUTLINE")
lockClock:SetTextColor(unpack(C.title))

local lockDate = lockScreen:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lockDate:SetPoint("TOP", lockClock, "BOTTOM", 0, -6)
lockDate:SetTextColor(unpack(C.textMuted))

local lockHint = lockScreen:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lockHint:SetPoint("BOTTOM", lockScreen, "BOTTOM", 0, 46)
lockHint:SetText("Touchez l'écran pour déverrouiller")
lockHint:SetTextColor(unpack(C.accent))

local function RefreshLockClock()
    lockClock:SetText(date("%H:%M"))
    lockDate:SetText(date("%A %d %B"))
end

lockScreen:SetScript("OnClick", function() lockScreen:Hide() end)

lockBtn:SetScript("OnClick", function()
    if lockScreen:IsShown() then
        lockScreen:Hide()
    else
        RefreshLockClock()
        lockScreen:Show()
    end
end)

-- ── Bouton d'accueil (bezel inférieur) ─────────────────────────────────────

local homeBtnMask = panel:CreateMaskTexture()
homeBtnMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local homeBtn = CreateFrame("Button", nil, panel)
homeBtn:SetSize(34, 34)
homeBtn:SetPoint("BOTTOM", panel, "BOTTOM", 0, 12)

local homeBtnBg = homeBtn:CreateTexture(nil, "ARTWORK")
homeBtnBg:SetAllPoints()
homeBtnBg:SetColorTexture(0.03, 0.08, 0.08, 1)
homeBtnBg:AddMaskTexture(homeBtnMask)

local homeBtnHL = homeBtn:CreateTexture(nil, "HIGHLIGHT")
homeBtnHL:SetAllPoints()
homeBtnHL:SetColorTexture(1, 1, 1, 0.25)
homeBtnHL:AddMaskTexture(homeBtnMask)

homeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Accueil")
    GameTooltip:Show()
end)
homeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ── Navigation ─────────────────────────────────────────────────────────────

function T:GoHome()
    T.currentApp = nil
    homeScreen:Show()
    for _, s in pairs(T.screens) do s:Hide() end
end

function T:OpenApp(key)
    local target = T.screens[key]
    if not target then return end
    T.currentApp = key
    homeScreen:Hide()
    for k, s in pairs(T.screens) do s:SetShown(k == key) end
end

homeBtn:SetScript("OnClick", function()
    if lockScreen:IsShown() then lockScreen:Hide() end
    T:GoHome()
end)

-- ── Enregistrement des apps ────────────────────────────────────────────────

local nextIconIndex = 0
local nextDockIndex = 0

-- opts = { key, label, icon, color, dock }
-- Crée l'icône sur l'écran d'accueil (+ dans le dock si demandé) et l'écran
-- plein cadre de l'app (en-tête avec retour + zone de contenu). Retourne la
-- zone de contenu ("body") dans laquelle le fichier appelant construit son UI.
function T:RegisterApp(opts)
    nextIconIndex = nextIconIndex + 1
    local idx = nextIconIndex
    local col = (idx - 1) % GRID_COLS
    local row = math.floor((idx - 1) / GRID_COLS)

    local gridBtn = T.CreateIconButton(gridArea, ICON_SIZE, opts.icon, opts.color)
    gridBtn:SetPoint("TOPLEFT", gridArea, "TOPLEFT",
        col * CELL_W + (CELL_W - ICON_SIZE) / 2,
        -(row * CELL_H))
    gridBtn:SetScript("OnClick", function() T:OpenApp(opts.key) end)

    local gridLabel = gridArea:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    gridLabel:SetPoint("TOP", gridBtn, "BOTTOM", 0, -6)
    gridLabel:SetText(opts.label)
    gridLabel:SetTextColor(unpack(C.text))

    if opts.dock then
        nextDockIndex = nextDockIndex + 1
        local dockBtn = T.CreateIconButton(dock, DOCK_ICON_SIZE, opts.icon, opts.color)
        dockBtn:SetPoint("LEFT", dock, "LEFT", (nextDockIndex - 1) * (DOCK_ICON_SIZE + DOCK_GAP), 0)
        dockBtn:SetScript("OnClick", function() T:OpenApp(opts.key) end)
    end

    -- Écran plein cadre de l'app
    local appScreen = CreateFrame("Frame", nil, screenStack)
    appScreen:SetAllPoints()
    appScreen:Hide()

    local header = CreateFrame("Frame", nil, appScreen)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(30)

    local backBtn = CreateFrame("Button", nil, header)
    backBtn:SetSize(26, 26)
    backBtn:SetPoint("LEFT", header, "LEFT", 6, 0)
    local backLbl = backBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    backLbl:SetAllPoints()
    backLbl:SetText("‹")
    backLbl:SetTextColor(unpack(C.accent))
    local backHL = backBtn:CreateTexture(nil, "HIGHLIGHT")
    backHL:SetAllPoints()
    backHL:SetColorTexture(1, 1, 1, 0.1)
    backBtn:SetScript("OnClick", function() T:GoHome() end)

    local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("LEFT", backBtn, "RIGHT", 4, 0)
    titleFS:SetText((opts.label or ""):upper())
    titleFS:SetTextColor(unpack(C.title))

    local headerSep = appScreen:CreateTexture(nil, "ARTWORK")
    headerSep:SetHeight(1)
    headerSep:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
    headerSep:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
    headerSep:SetColorTexture(unpack(C.accentDim))

    local body = CreateFrame("Frame", nil, appScreen)
    body:SetPoint("TOPLEFT", headerSep, "BOTTOMLEFT")
    body:SetPoint("BOTTOMRIGHT", appScreen, "BOTTOMRIGHT")

    T.screens[opts.key] = appScreen
    return body
end

-- ── Voile de luminosité ────────────────────────────────────────────────────
-- Cadre dédié (pas juste une texture sur `screen`) placé au-dessus de
-- screenStack par niveau de cadre : une texture posée sur `screen` serait
-- masquée par les cadres enfants (accueil/apps), quel que soit son "layer".

local dimOverlay = CreateFrame("Frame", nil, screen)
dimOverlay:SetAllPoints()
dimOverlay:SetFrameLevel(screenStack:GetFrameLevel() + 10)

local dimTex = dimOverlay:CreateTexture(nil, "OVERLAY")
dimTex:SetAllPoints()
dimTex:SetColorTexture(0, 0, 0, 1)
dimOverlay:SetAlpha(0)
T.dimOverlay = dimOverlay

-- ── Horloge : ne tourne que pendant que la tablette est affichée ──────────

local clockTicker
panel:SetScript("OnShow", function()
    RefreshClock()
    if not clockTicker then
        clockTicker = C_Timer.NewTicker(20, function()
            RefreshClock()
            if lockScreen:IsShown() then RefreshLockClock() end
        end)
    end
end)

panel:SetScript("OnHide", function()
    if clockTicker then
        clockTicker:Cancel()
        clockTicker = nil
    end
end)

function panel:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

T:SetBrightness(T:GetDB().settings.brightness or 1.0)
