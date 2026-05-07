-- ============================================================
--  Omega Hub — Panel principal
-- ============================================================

local Hub = OmegaHub
local UI  = OS2.UI

local STATUS = {
    loaded   = { 0.20, 0.82, 0.32 },
    pending  = { 0.90, 0.70, 0.10 },
    disabled = { 0.55, 0.12, 0.12 },
}

local PANEL_W  = 400
local ROW_H    = 64
local HEADER_H = 46
local PADDING  = 16
local ACCENT_W = 3

local function panelHeight(rowCount)
    return HEADER_H + rowCount * ROW_H + 4
end

-- ── Panneau ────────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "OmegaHubPanel", UIParent, "BackdropTemplate")
panel:SetWidth(PANEL_W)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:Hide()

local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
UI.ApplyWindowBackground(panelBg, 0.97)

panel:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left=4, right=4, top=4, bottom=4 },
})
panel:SetBackdropBorderColor(unpack(UI.colors.separator))

-- ── Header ─────────────────────────────────────────────────────────────────

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT",  4, -4)
header:SetPoint("TOPRIGHT", -4, -4)
header:SetHeight(HEADER_H - 6)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints()
UI.ApplyWindowBackground(headerBg, 0.70)

-- Accent doré sur le bord gauche du header
local headerAccent = header:CreateTexture(nil, "ARTWORK")
headerAccent:SetWidth(ACCENT_W)
headerAccent:SetPoint("TOPLEFT")
headerAccent:SetPoint("BOTTOMLEFT")
headerAccent:SetColorTexture(unpack(UI.colors.tabLine))

local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", header, "LEFT", PADDING, 0)
titleText:SetText("Omega Hub")
UI.ApplyTitle(titleText)

local versionText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionText:SetPoint("RIGHT", header, "RIGHT", -32, 0)
versionText:SetText("v1.0.0")
UI.ApplyMutedText(versionText)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sepTop = panel:CreateTexture(nil, "ARTWORK")
sepTop:SetPoint("TOPLEFT",  4, -(HEADER_H - 2))
sepTop:SetPoint("TOPRIGHT", -4, -(HEADER_H - 2))
sepTop:SetHeight(1)
UI.ApplySeparator(sepTop, true)

-- ── Zone de contenu ────────────────────────────────────────────────────────

local content = CreateFrame("Frame", nil, panel)
content:SetPoint("TOPLEFT",     4,  -(HEADER_H - 1))
content:SetPoint("BOTTOMRIGHT", -4,  4)

-- ── Rangées ────────────────────────────────────────────────────────────────

panel.rows = {}

local function createRow(addonData, index)
    local row = CreateFrame("Frame", nil, content)
    row:SetPoint("TOPLEFT",  0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:SetHeight(ROW_H - 1)

    -- Fond alterné subtil
    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints()
    UI.ApplyWindowBackground(rowBg, index % 2 == 0 and 0.22 or 0.08)

    -- Barre de statut colorée (gauche)
    local accent = row:CreateTexture(nil, "ARTWORK")
    accent:SetWidth(ACCENT_W)
    accent:SetPoint("TOPLEFT",    0,  -2)
    accent:SetPoint("BOTTOMLEFT", 0,   2)
    accent:SetColorTexture(0.3, 0.3, 0.3)
    row.accent = accent

    -- Nom du module
    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameFS:SetPoint("TOPLEFT", ACCENT_W + PADDING, -13)
    nameFS:SetText(addonData.title)
    UI.ApplyBodyText(nameFS)
    row.nameFS = nameFS

    -- Version
    local verFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    verFS:SetPoint("LEFT", nameFS, "RIGHT", 8, -1)
    verFS:SetText("v" .. addonData.version)
    UI.ApplyMutedText(verFS)

    -- Description
    local descFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descFS:SetPoint("BOTTOMLEFT", ACCENT_W + PADDING, 13)
    descFS:SetText(addonData.desc)
    UI.ApplySoftText(descFS)

    -- Bouton toggle
    local btn = UI.CreatePanelButton(row, 90, 22, "...")
    btn:SetPoint("RIGHT", -PADDING, 0)
    btn:SetScript("OnClick", function()
        local _, enabled = Hub:GetModuleStatus(addonData.name)
        if enabled then
            Hub:DisableAddon(addonData.name)
            if addonData.module and addonData.module.Disable then
                addonData.module:Disable()
            end
        else
            Hub:EnableAddon(addonData.name)
            if addonData.module and addonData.module.Enable then
                addonData.module:Enable()
            end
        end
        panel:Refresh()
    end)
    row.btn = btn

    row.addonData = addonData
    return row
end

-- Pas de footer fixe — le panel se termine après la dernière rangée

-- ── Rafraîchissement ───────────────────────────────────────────────────────

local function updateRow(row)
    local loaded, enabled = Hub:GetModuleStatus(row.addonData.name)

    if loaded then
        row.accent:SetColorTexture(unpack(STATUS.loaded))
        UI.ApplyBodyText(row.nameFS)
    elseif enabled then
        row.accent:SetColorTexture(unpack(STATUS.pending))
        UI.ApplyStrongLabel(row.nameFS)
    else
        row.accent:SetColorTexture(unpack(STATUS.disabled))
        UI.ApplyMutedText(row.nameFS)
    end

    row.btn:SetText(enabled and "Désactiver" or "Activer")
end

function panel:Refresh()
    for _, r in ipairs(self.rows) do r:Hide() end
    wipe(self.rows)

    -- Les modules hidden (Weather) ne sont jamais affichés
    for i, addonData in ipairs(Hub:GetModules(false)) do
        local row = createRow(addonData, i)
        self.rows[i] = row
        updateRow(row)
    end

    self:SetHeight(panelHeight(#self.rows))
end

function panel:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        self:Refresh()
        self:Show()
    end
end
