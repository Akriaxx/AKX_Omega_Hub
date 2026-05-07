-- OmegaSpell - IconBrowser.lua
-- Navigateur d'icones pour choisir l'icone d'un sort.
-- Source : LibRPMedia-1.0 (via SpellCreator / LibStub).

OmegaSpell           = OmegaSpell or {}
OmegaSpell.IconBrowser = OmegaSpell.IconBrowser or {}

local OS  = OmegaSpell
local Lib = OmegaSpell.IconBrowser
local HUI = OS2.UI

-- ── Constantes layout ─────────────────────────────────────────────────────────

local W        = 620
local H        = 480
local PAD      = 10
local HEADER_H = 40
local SEARCH_H = 26
local ICON_S   = 44
local ICON_GAP = 4

-- Grille : autant de colonnes que possible
local COLS = math.floor((W - PAD * 2 + ICON_GAP) / (ICON_S + ICON_GAP))  -- ~12
local ROWS = 7
local GRID_W = COLS * (ICON_S + ICON_GAP) - ICON_GAP
local GRID_Y = -(HEADER_H + 6 + SEARCH_H + 8)

local POOL_SIZE = COLS * ROWS

-- ── Panel principal ───────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "OmegaSpellIconBrowser", UIParent, "BackdropTemplate")
panel:SetSize(W, H)
panel:SetPoint("CENTER", UIParent, "CENTER", 60, 20)
panel:SetFrameStrata("DIALOG")
panel:SetFrameLevel(135)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:Hide()

do
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    HUI.ApplyWindowBackground(bg, 0.97)
    panel:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropBorderColor(unpack(HUI.colors.separator))
end

-- Header
local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT",  4, -4)
header:SetPoint("TOPRIGHT", -4, -4)
header:SetHeight(HEADER_H)
do
    local hBg = header:CreateTexture(nil, "BACKGROUND")
    hBg:SetAllPoints()
    HUI.ApplyWindowBackground(hBg, 0.70)
    local hAccent = header:CreateTexture(nil, "ARTWORK")
    hAccent:SetWidth(3)
    hAccent:SetPoint("TOPLEFT"); hAccent:SetPoint("BOTTOMLEFT")
    hAccent:SetColorTexture(unpack(HUI.colors.tabLine))
    local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("LEFT", header, "LEFT", PAD + 6, 0)
    titleFS:SetText("Icones")
    HUI.ApplyTitle(titleFS)
end
HUI.CreateCloseButton(panel, function() panel:Hide() end)

local hSep = panel:CreateTexture(nil, "ARTWORK")
hSep:SetHeight(1)
hSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  4, -(HEADER_H + 2))
hSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -(HEADER_H + 2))
HUI.ApplySeparator(hSep, true)

-- Barre de recherche
local searchBox = HUI.CreateStyledEditBox(panel, W - PAD * 2, SEARCH_H, false)
searchBox:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 6))
searchBox:SetMaxLetters(64)

local searchHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
searchHint:SetAllPoints(searchBox)
searchHint:SetJustifyH("LEFT")
searchHint:SetText("  Filtrer...")
HUI.ApplyMutedText(searchHint)
searchBox:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
searchBox:SetScript("OnEditFocusLost", function()
    if searchBox:GetText() == "" then searchHint:Show() end
end)

-- Status (bas)
local statusFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusFS:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  PAD + 4, 12)
statusFS:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD,    12)
statusFS:SetJustifyH("LEFT")
HUI.ApplyMutedText(statusFS)

-- Conteneur de la grille
local gridFrame = CreateFrame("Frame", nil, panel)
gridFrame:SetSize(GRID_W, ROWS * (ICON_S + ICON_GAP) - ICON_GAP)
gridFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, GRID_Y)
gridFrame:EnableMouseWheel(true)

-- ── Données ───────────────────────────────────────────────────────────────────

local allIcons     = nil   -- { "INV_Something", ... }  construit à la 1ère ouverture
local filtered     = nil   -- sous-ensemble filtré
local scrollOffset = 0     -- ligne courante (en index de ligne)
local onSelect     = nil   -- callback(iconPath, iconName)

local MAX_FILTERED = 6000

local function BuildIconList()
    if allIcons then return end
    allIcons = {}
    local LibRPM = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true)
    if LibRPM and LibRPM.FindAllIcons then
        for _, name in LibRPM:FindAllIcons() do
            allIcons[#allIcons + 1] = name
        end
    end
end

local function GetList()
    return filtered or allIcons or {}
end

local function MaxScroll()
    local list = GetList()
    return math.max(0, math.ceil(#list / COLS) - ROWS)
end

-- ── Pool de boutons (réutilisés) ──────────────────────────────────────────────

local btnPool = {}

local function RefreshGrid()
    local list = GetList()
    local base = scrollOffset * COLS
    local total = #list

    if total == 0 and allIcons and #allIcons == 0 then
        statusFS:SetText("LibRPMedia non disponible — SpellCreator requis.")
    elseif filtered then
        statusFS:SetText(tostring(total) .. " icone(s) filtree(s)")
    else
        statusFS:SetText(tostring(total) .. " icone(s) disponibles  |  molette pour defiler")
    end

    for i = 1, POOL_SIZE do
        local btn = btnPool[i]
        local idx = base + i
        local iconName = list[idx]
        if iconName then
            local texPath
            if iconName:find("Interface", 1, true) then
                texPath = iconName
            elseif iconName:find("AddOns", 1, true) then
                texPath = "Interface/" .. iconName
            else
                texPath = "Interface/Icons/" .. iconName
            end
            btn:GetNormalTexture():SetTexture(texPath)
            btn.iconPath = texPath
            btn.iconName = iconName
            btn:Show()
        else
            btn:GetNormalTexture():SetTexture("")
            btn.iconPath = nil
            btn.iconName = nil
            btn:Hide()
        end
    end
end

-- Création du pool de boutons
for i = 1, POOL_SIZE do
    local col = (i - 1) % COLS
    local row = math.floor((i - 1) / COLS)

    local btn = CreateFrame("Button", nil, gridFrame)
    btn:SetSize(ICON_S, ICON_S)
    btn:SetPoint("TOPLEFT", gridFrame, "TOPLEFT",
        col * (ICON_S + ICON_GAP),
        -row * (ICON_S + ICON_GAP))

    -- Texture normale
    local ntex = btn:CreateTexture(nil, "ARTWORK")
    ntex:SetAllPoints()
    ntex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn:SetNormalTexture(ntex)

    -- Bordure hover
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.85, 0.75, 0.40, 0.30)
    btn:SetHighlightTexture(hl)

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        if self.iconName then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("|T" .. (self.iconPath or "") .. ":48|t", 1, 1, 1)
            GameTooltip:AddLine(self.iconName, 1, 0.82, 0, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Clic = sélection
    btn:SetScript("OnClick", function(self)
        if self.iconPath and onSelect then
            onSelect(self.iconPath, self.iconName)
        end
        panel:Hide()
    end)

    btnPool[i] = btn
end

-- Scroll à la molette
gridFrame:SetScript("OnMouseWheel", function(self, delta)
    scrollOffset = math.max(0, math.min(MaxScroll(), scrollOffset - delta))
    RefreshGrid()
end)

-- Filtre en temps réel
searchBox:SetScript("OnTextChanged", function()
    local filter = (searchBox:GetText() or ""):lower()
    scrollOffset = 0
    if filter == "" then
        filtered = nil
    else
        filtered = {}
        local list = allIcons or {}
        for _, name in ipairs(list) do
            if name:lower():find(filter, 1, true) then
                filtered[#filtered + 1] = name
                if #filtered >= MAX_FILTERED then break end
            end
        end
    end
    RefreshGrid()
end)

-- ── API publique ──────────────────────────────────────────────────────────────

-- callback : function(iconPath, iconName)
function Lib.Open(callback)
    onSelect = callback
    if panel:IsShown() then panel:Hide(); return end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", 60, 20)
    BuildIconList()
    filtered      = nil
    scrollOffset  = 0
    searchBox:SetText("")
    searchHint:Show()
    RefreshGrid()
    panel:Show()
end

function Lib.Close()
    panel:Hide()
end
