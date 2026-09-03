-- ============================================================
--  Item Creator — Fiche d'équilibrage
--  Modifier les seuils de paliers et les coûts par stat
-- ============================================================

local IC = ItemCreator
local UI = OS2.UI

local PANEL_W  = 480
local PANEL_H  = 560
local PAD      = 12
local ROW_H    = 26
local HEADER_H = 40
local FOOTER_H = 40
local TAB_H    = 28

-- ── Panel ─────────────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "ItemBalancePanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER", UIParent, "CENTER", 260, 0)
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
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropBorderColor(unpack(UI.colors.separator))

function panel:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

-- ── Header ────────────────────────────────────────────────────────────────────

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT",  4, -4)
header:SetPoint("TOPRIGHT", -4, -4)
header:SetHeight(HEADER_H - 4)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints()
UI.ApplyWindowBackground(headerBg, 0.70)

local headerAccent = header:CreateTexture(nil, "ARTWORK")
headerAccent:SetWidth(3)
headerAccent:SetPoint("TOPLEFT")
headerAccent:SetPoint("BOTTOMLEFT")
headerAccent:SetColorTexture(0.50, 0.30, 0.95)

local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", header, "LEFT", PAD, 0)
titleText:SetText("Équilibrage")
UI.ApplyTitle(titleText)

local subtitleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
subtitleText:SetPoint("LEFT", titleText, "RIGHT", 10, -1)
subtitleText:SetText("Item Creator")
UI.ApplyMutedText(subtitleText)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sep1 = panel:CreateTexture(nil, "ARTWORK")
sep1:SetPoint("TOPLEFT",  4, -(HEADER_H - 2))
sep1:SetPoint("TOPRIGHT", -4, -(HEADER_H - 2))
sep1:SetHeight(1)
UI.ApplySeparator(sep1)

-- ── Onglets ───────────────────────────────────────────────────────────────────

local TAB_Y  = -(HEADER_H + 2)

local tabRow = CreateFrame("Frame", nil, panel)
tabRow:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD + 4, TAB_Y)
tabRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + 4), TAB_Y)
tabRow:SetHeight(TAB_H)

local TABS = {
    { id = "tiers", label = "Paliers de qualité" },
    { id = "costs", label = "Coûts des stats"    },
}

local tabBtns    = {}
local tabContent = {}
local activeTab  = 1

local function SelectTab(idx)
    activeTab = idx
    for i, btn in ipairs(tabBtns) do
        UI.ApplyTabState(btn, i == idx)
    end
    for i, c in pairs(tabContent) do
        c:SetShown(i == idx)
    end
end

local tabW = math.floor((PANEL_W - PAD * 2 - 8) / #TABS)
for i, tab in ipairs(TABS) do
    local btn = CreateFrame("Button", nil, tabRow)
    btn:SetSize(tabW, TAB_H)
    btn:SetPoint("LEFT", tabRow, "LEFT", (i - 1) * tabW, 0)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.06, 0.06, 0.06, 0.70)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetAllPoints()
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(tab.label)

    btn.line = btn:CreateTexture(nil, "ARTWORK")
    btn.line:SetHeight(2)
    btn.line:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  2, 0)
    btn.line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 0)
    btn.line:Hide()

    local hlTex = btn:CreateTexture(nil, "HIGHLIGHT")
    hlTex:SetAllPoints()
    hlTex:SetColorTexture(1, 1, 1, 0.05)

    btn:SetScript("OnClick", function() SelectTab(i) end)
    tabBtns[i] = btn
end

-- ── Zone de scroll ────────────────────────────────────────────────────────────

-- scrollTop = y depuis le haut du panel (valeur négative)
local SCROLL_Y = TAB_Y - TAB_H - 4
-- scrollH = hauteur réelle disponible entre le bas des onglets et le haut du footer
local SCROLL_H = PANEL_H - math.abs(SCROLL_Y) - FOOTER_H - 4

local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD + 4, SCROLL_Y)
scrollFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + 20), SCROLL_Y)
scrollFrame:SetHeight(SCROLL_H)

local sb = scrollFrame.ScrollBar or _G[scrollFrame:GetName() and scrollFrame:GetName().."ScrollBar"]
if sb then sb:SetAlpha(0.35) end

-- ── Footer ────────────────────────────────────────────────────────────────────

local sep2 = panel:CreateTexture(nil, "ARTWORK")
sep2:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",   4, FOOTER_H - 2)
sep2:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, FOOTER_H - 2)
sep2:SetHeight(1)
UI.ApplySeparator(sep2)

local infoLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
infoLbl:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + 4, 14)
infoLbl:SetText("Modifications appliquées immédiatement.")
UI.ApplyMutedText(infoLbl)

-- ── Helpers ───────────────────────────────────────────────────────────────────

-- Mini editbox numérique, max 4 chars, centré.
-- Évite SetNumeric (problèmes avec "100") — validation manuelle.
local function MakeEB(parent, w, initialVal, onCommit)
    local eb = UI.CreateStyledEditBox(parent, w, 18)
    eb:SetMaxLetters(4)
    eb:SetJustifyH("CENTER")
    eb:SetText(tostring(initialVal or 0))
    eb:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v ~= nil and onCommit then onCommit(v) end
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return eb
end

-- Crée un frame-row qui peut être facilement caché/reaffiché.
local function MakeRow(parent, h)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(h or ROW_H)
    return row
end

-- ── Onglet 1 : Paliers ────────────────────────────────────────────────────────

local tiersChild = CreateFrame("Frame", nil, scrollFrame)
tiersChild:SetWidth(scrollFrame:GetWidth())
tabContent[1] = tiersChild

-- Pool de rows de palier (réutilisés à chaque rebuild)
local tierRows = {}

local function BuildTiersContent()
    -- Masque toutes les rows existantes
    for _, r in ipairs(tierRows) do r:Hide() end
    tierRows = {}

    local tiers = IC:GetTiers()

    -- Hauteur du child : header (28px) + rows + reset btn (34px)
    local contentH = 28 + #tiers * ROW_H + 10 + 28
    tiersChild:SetHeight(math.max(contentH, SCROLL_H))

    -- ── En-têtes de colonnes (une seule fois, sur tiersChild directement)
    -- On les crée une fois dans tiersChild et on les garde
    if not tiersChild._headers then
        local hPalier = tiersChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hPalier:SetPoint("TOPLEFT", tiersChild, "TOPLEFT", 28, -6)
        hPalier:SetText("Palier")
        UI.ApplyLabel(hPalier)

        local hPts = tiersChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hPts:SetPoint("TOPLEFT", tiersChild, "TOPLEFT", 220, -6)
        hPts:SetText("Pts max")
        UI.ApplyLabel(hPts)

        local hRgb = tiersChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hRgb:SetPoint("TOPLEFT", tiersChild, "TOPLEFT", 308, -6)
        hRgb:SetText("R   G   B  (0-100)")
        UI.ApplyLabel(hRgb)

        local sepH = tiersChild:CreateTexture(nil, "ARTWORK")
        sepH:SetPoint("TOPLEFT",  tiersChild, "TOPLEFT",  0, -22)
        sepH:SetPoint("TOPRIGHT", tiersChild, "TOPRIGHT", 0, -22)
        sepH:SetHeight(1)
        UI.ApplySeparator(sepH, true)

        tiersChild._headers = true
    end

    -- ── Rows de paliers
    for i, tier in ipairs(tiers) do
        local y = -(22 + (i - 1) * ROW_H + 4)

        local row = MakeRow(tiersChild, ROW_H)
        row:SetPoint("TOPLEFT",  tiersChild, "TOPLEFT",  0, y)
        row:SetPoint("TOPRIGHT", tiersChild, "TOPRIGHT", 0, y)
        row:Show()
        table.insert(tierRows, row)

        -- Pastille couleur
        local dot = row:CreateTexture(nil, "ARTWORK")
        dot:SetSize(12, 12)
        dot:SetPoint("LEFT", row, "LEFT", 8, 0)
        dot:SetColorTexture(tier.r, tier.g, tier.b)

        -- Nom
        local nameLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLbl:SetPoint("LEFT", row, "LEFT", 26, 0)
        nameLbl:SetWidth(170)
        nameLbl:SetJustifyH("LEFT")
        nameLbl:SetText(tier.name)
        nameLbl:SetTextColor(tier.r, tier.g, tier.b)

        -- Pts max
        MakeEB(row, 46, tier.pts, function(v)
            tier.pts = math.max(1, math.floor(v))
        end):SetPoint("LEFT", row, "LEFT", 220, 0)

        -- R G B  (valeurs 0-100 = pourcentages ×100 de 0.0-1.0)
        local rEB = MakeEB(row, 38, math.floor(tier.r * 100 + 0.5), function(v)
            tier.r = math.max(0, math.min(1, v / 100))
            dot:SetColorTexture(tier.r, tier.g, tier.b)
            nameLbl:SetTextColor(tier.r, tier.g, tier.b)
        end)
        rEB:SetPoint("LEFT", row, "LEFT", 308, 0)

        local gEB = MakeEB(row, 38, math.floor(tier.g * 100 + 0.5), function(v)
            tier.g = math.max(0, math.min(1, v / 100))
            dot:SetColorTexture(tier.r, tier.g, tier.b)
            nameLbl:SetTextColor(tier.r, tier.g, tier.b)
        end)
        gEB:SetPoint("LEFT", rEB, "RIGHT", 4, 0)

        local bEB = MakeEB(row, 38, math.floor(tier.b * 100 + 0.5), function(v)
            tier.b = math.max(0, math.min(1, v / 100))
            dot:SetColorTexture(tier.r, tier.g, tier.b)
            nameLbl:SetTextColor(tier.r, tier.g, tier.b)
        end)
        bEB:SetPoint("LEFT", gEB, "RIGHT", 4, 0)
    end

    -- ── Bouton réinitialiser
    if not tiersChild._resetBtn then
        local btn = UI.CreatePanelButton(tiersChild, 190, 22, "Réinitialiser les paliers")
        btn:SetPoint("TOPLEFT", tiersChild, "TOPLEFT", 8, -(22 + #tiers * ROW_H + 14))
        tiersChild._resetBtn = btn
        btn:SetScript("OnClick", function()
            ItemCreatorDB.tiers = {}
            IC:GetTiers()
            BuildTiersContent()
            if IC.OnCurrentChanged then IC.OnCurrentChanged() end
        end)
    else
        local tiers2 = IC:GetTiers()
        tiersChild._resetBtn:SetPoint("TOPLEFT", tiersChild, "TOPLEFT", 8, -(22 + #tiers2 * ROW_H + 14))
    end
end

-- ── Onglet 2 : Coûts ─────────────────────────────────────────────────────────

local costsChild = CreateFrame("Frame", nil, scrollFrame)
costsChild:SetWidth(scrollFrame:GetWidth())
costsChild:Hide()
tabContent[2] = costsChild

local costRows = {}

local function BuildCostsContent()
    for _, r in ipairs(costRows) do r:Hide() end
    costRows = {}

    -- Hauteur totale : en-tête + (groupes × (titre + stats))
    local totalLines = 2  -- en-tête + sep
    for _, group in ipairs(IC.STAT_GROUPS) do
        totalLines = totalLines + 1 + #group.stats + 1  -- titre + stats + séparateur
    end
    costsChild:SetHeight(math.max(totalLines * ROW_H + 30, SCROLL_H))

    local y = -6

    -- En-tête
    if not costsChild._hStat then
        local hStat = costsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hStat:SetPoint("TOPLEFT", costsChild, "TOPLEFT", 20, y)
        hStat:SetText("Stat")
        UI.ApplyLabel(hStat)

        local hCost = costsChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hCost:SetPoint("TOPLEFT", costsChild, "TOPLEFT", PANEL_W - PAD * 2 - 80, y)
        hCost:SetText("Coût/+1")
        UI.ApplyLabel(hCost)

        costsChild._hStat = true
    end
    y = y - 18

    local function MakeSep(yPos)
        local s = costsChild:CreateTexture(nil, "ARTWORK")
        s:SetPoint("TOPLEFT",  costsChild, "TOPLEFT",  4, yPos)
        s:SetPoint("TOPRIGHT", costsChild, "TOPRIGHT", -4, yPos)
        s:SetHeight(1)
        UI.ApplySeparator(s, true)
    end
    MakeSep(y)
    y = y - 4

    for _, group in ipairs(IC.STAT_GROUPS) do
        -- Titre de groupe
        local groupRow = MakeRow(costsChild, ROW_H)
        groupRow:SetPoint("TOPLEFT",  costsChild, "TOPLEFT",  0, y)
        groupRow:SetPoint("TOPRIGHT", costsChild, "TOPRIGHT", 0, y)
        groupRow:Show()
        table.insert(costRows, groupRow)

        local groupLbl = groupRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        groupLbl:SetPoint("LEFT", groupRow, "LEFT", 8, 0)
        groupLbl:SetText(group.label)
        UI.ApplyStrongLabel(groupLbl)
        y = y - ROW_H

        -- Rows de stats
        for _, stat in ipairs(group.stats) do
            local row = MakeRow(costsChild, ROW_H)
            row:SetPoint("TOPLEFT",  costsChild, "TOPLEFT",  0, y)
            row:SetPoint("TOPRIGHT", costsChild, "TOPRIGHT", 0, y)
            row:Show()
            table.insert(costRows, row)

            -- Fond alterné
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.05, 0.05, 0.05, 0.45)

            -- Label stat
            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", row, "LEFT", 20, 0)
            lbl:SetWidth(PANEL_W - PAD * 2 - 120)
            lbl:SetJustifyH("LEFT")
            lbl:SetText(stat.label)
            UI.ApplySoftText(lbl)

            if stat.allowNeg then
                local negNote = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                negNote:SetPoint("RIGHT", row, "RIGHT", -60, 0)
                negNote:SetText("malus OK")
                negNote:SetTextColor(0.30, 0.88, 0.45, 0.70)
            end

            -- EditBox coût
            local currentCost = IC:GetCost(stat.id)
            local costEB = MakeEB(row, 46, currentCost, function(v)
                ItemCreatorDB.costs = ItemCreatorDB.costs or {}
                ItemCreatorDB.costs[stat.id] = v
                if IC.OnCurrentChanged then IC.OnCurrentChanged() end
            end)
            costEB:SetPoint("RIGHT", row, "RIGHT", -8, 0)

            y = y - ROW_H
        end

        -- Séparateur de fin de groupe
        MakeSep(y + 2)
        y = y - 6
    end

    -- Bouton réinitialiser les coûts
    if not costsChild._resetBtn then
        local btn = UI.CreatePanelButton(costsChild, 170, 22, "Réinitialiser les coûts")
        costsChild._resetBtn = btn
        btn:SetScript("OnClick", function()
            ItemCreatorDB.costs = {}
            for _, r in ipairs(costRows) do r:Hide() end
            costRows = {}
            -- Recrée les sections (séparateurs non réutilisables)
            costsChild._hStat = nil
            BuildCostsContent()
            if IC.OnCurrentChanged then IC.OnCurrentChanged() end
        end)
    end
    costsChild._resetBtn:SetPoint("TOPLEFT", costsChild, "TOPLEFT", 8, y - 6)
    costsChild._resetBtn:Show()
end

-- ── Init différé (ItemCreatorDB pas encore chargé au load time) ───────────────

local _built = false
panel:SetScript("OnShow", function()
    if not _built then
        _built = true
        BuildTiersContent()
        BuildCostsContent()
    end
    -- Active l'onglet 1 à chaque ouverture
    scrollFrame:SetScrollChild(tiersChild)
    tiersChild:SetWidth(scrollFrame:GetWidth())
    SelectTab(1)
    scrollFrame:SetVerticalScroll(0)
end)

-- Synchronise le scrollChild au changement d'onglet
local origSelect = SelectTab
SelectTab = function(idx)
    origSelect(idx)
    local child = tabContent[idx]
    if child then
        child:SetWidth(scrollFrame:GetWidth())
        scrollFrame:SetScrollChild(child)
        scrollFrame:SetVerticalScroll(0)
    end
end
