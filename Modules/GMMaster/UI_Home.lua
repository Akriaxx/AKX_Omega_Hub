-- ============================================================
--  GM Master — Accueil
--  /gmm ouvre cette page : une tuile par fenêtre du module (liste
--  GM.HOME dans Core.lua). Les raccourcis /gmm auras, /gmm barre…
--  ouvrent directement la fenêtre voulue.
-- ============================================================

local GM = GMMaster
local UI = OS2.UI

local PAD       = 14
local COLS      = 2
local TILE_W    = 220
local TILE_H    = 58
local GAP       = 8
local HEADER_H  = 64

local rows = math.ceil(#GM.HOME / COLS)
local W = PAD * 2 + COLS * TILE_W + (COLS - 1) * GAP
local H = HEADER_H + rows * TILE_H + (rows - 1) * GAP + PAD + 6

local home = CreateFrame("Frame", "GMMasterHome", UIParent, "BackdropTemplate")
home:SetSize(W, H)
home:SetPoint("CENTER", 0, 60)
home:SetFrameStrata("HIGH")
home:SetClampedToScreen(true)
home:SetMovable(true)
home:EnableMouse(true)
home:RegisterForDrag("LeftButton")
home:SetScript("OnDragStart", home.StartMoving)
home:SetScript("OnDragStop", home.StopMovingOrSizing)
home:Hide()
tinsert(UISpecialFrames, "GMMasterHome")

do
    local bg = home:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.97)
    home:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    home:SetBackdropBorderColor(unpack(UI.colors.separator))
    UI.CreateCloseButton(home, function() home:Hide() end)
end

local title = home:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", PAD + 2, -14)
title:SetText("GM Master")
UI.ApplyTitle(title)

local version = home:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
version:SetPoint("LEFT", title, "RIGHT", 8, -1)
UI.ApplyMutedText(version)

local subtitle = home:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitle:SetPoint("TOPLEFT", PAD + 2, -38)
subtitle:SetText("Que voulez-vous ouvrir ?")
UI.ApplySoftText(subtitle)

local tiles = {}
home.tiles = tiles

for i, entry in ipairs(GM.HOME) do
    local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
    local tile = CreateFrame("Button", nil, home)
    tile:SetSize(TILE_W, TILE_H)
    tile:SetPoint("TOPLEFT", PAD + col * (TILE_W + GAP), -(HEADER_H + row * (TILE_H + GAP)))
    tile.entry = entry

    local bg = tile:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.rowBg))

    local line = tile:CreateTexture(nil, "ARTWORK")
    line:SetWidth(3)
    line:SetPoint("TOPLEFT")
    line:SetPoint("BOTTOMLEFT")
    line:SetColorTexture(unpack(UI.colors.tabLine))

    local hl = tile:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.panelButtonHighlight))

    local name = tile:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", 12, -9)
    name:SetJustifyH("LEFT")
    UI.ApplyStrongLabel(name)
    tile.name = name

    local cmd = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cmd:SetPoint("TOPRIGHT", -8, -10)
    cmd:SetText("/gmm " .. entry.key)
    UI.ApplyPlaceholderText(cmd)

    local desc = tile:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 12, -28)
    desc:SetPoint("RIGHT", -8, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(entry.desc)
    UI.ApplyMutedText(desc)

    tile:SetScript("OnClick", function() GM:OpenHomeEntry(entry.key) end)
    tiles[i] = tile
end

function home:Refresh()
    if not self:IsShown() then return end
    for _, tile in ipairs(tiles) do
        local entry = tile.entry
        local state = entry.state and entry.state()
        tile.name:SetText(entry.title .. (state and ("  |cff888888(" .. state .. ")|r") or ""))
    end
end

home:SetScript("OnShow", function(self)
    version:SetText("v" .. (GMMASTER_VERSION or "?"))
    self:Refresh()
end)

function home:Toggle()
    self:SetShown(not self:IsShown())
end

GM:OnChange(function() home:Refresh() end)
