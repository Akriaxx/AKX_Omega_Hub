-- ============================================================
--  Item Creator — Panel principal
--  /oitem pour ouvrir
-- ============================================================

local IC = ItemCreator
local UI = OS2.UI

local PANEL_W   = 500
local PANEL_H   = 700
local PAD       = 12
local TAB_H     = 26
local ROW_H     = 26
local HEADER_H  = 40
local FOOTER_H  = 36
local COUNTER_H = 52

-- ── Panel racine ─────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "ItemCreatorPanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
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
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropBorderColor(unpack(UI.colors.separator))

function panel:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

-- ── Header ───────────────────────────────────────────────────────────────────

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
headerAccent:SetColorTexture(unpack(UI.colors.tabLine))

local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", header, "LEFT", PAD, 0)
titleText:SetText("Créateur d'Item")
UI.ApplyTitle(titleText)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sep1 = panel:CreateTexture(nil, "ARTWORK")
sep1:SetPoint("TOPLEFT",  4, -(HEADER_H - 2))
sep1:SetPoint("TOPRIGHT", -4, -(HEADER_H - 2))
sep1:SetHeight(1)
UI.ApplySeparator(sep1)

-- ── Champ nom de l'item ───────────────────────────────────────────────────────

local nameLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, -(HEADER_H + 10))
nameLabel:SetText("Nom :")
UI.ApplyLabel(nameLabel)

local nameEB = UI.CreateStyledEditBox(panel, PANEL_W - PAD * 2 - 44, 20, false)
nameEB:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
nameEB:SetMaxLetters(64)
nameEB:SetText(ItemCreatorDB and ItemCreatorDB.currentName or "")
nameEB:SetScript("OnTextChanged", function(self)
    ItemCreatorDB = ItemCreatorDB or {}
    ItemCreatorDB.currentName = self:GetText()
end)

-- ── Compteur de points ────────────────────────────────────────────────────────

local counterY = -(HEADER_H + 40)

local counterFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
counterFrame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD + 4, counterY)
counterFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + 4), counterY)
counterFrame:SetHeight(COUNTER_H)
counterFrame:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
counterFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
counterFrame:SetBackdropBorderColor(unpack(UI.colors.separatorSoft))

-- Barre de progression (remplissage coloré)
local progressBar = counterFrame:CreateTexture(nil, "BACKGROUND")
progressBar:SetPoint("TOPLEFT",    counterFrame, "TOPLEFT",    3, -3)
progressBar:SetPoint("BOTTOMLEFT", counterFrame, "BOTTOMLEFT", 3,  3)
progressBar:SetWidth(1)
progressBar:SetColorTexture(0.80, 0.70, 0.40, 0.12)

-- Texte principal : X pts
local ptsText = counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
ptsText:SetPoint("LEFT", counterFrame, "LEFT", 14, 4)
ptsText:SetText("0 pts")
UI.ApplyTitle(ptsText)

-- Palier / couleur
local tierText = counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tierText:SetPoint("LEFT", counterFrame, "LEFT", 14, -12)
UI.ApplyMutedText(tierText)

-- Max pts (à droite)
local maxText = counterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
maxText:SetPoint("RIGHT", counterFrame, "RIGHT", -12, 0)
UI.ApplyMutedText(maxText)

local function RefreshCounter()
    local total  = IC:ComputeTotal()
    local tier   = IC:GetTierForTotal(total)
    local maxT   = IC:GetMaxTier()

    -- Texte points
    ptsText:SetText(total .. " pts")
    if tier then
        ptsText:SetTextColor(tier.r, tier.g, tier.b)
    else
        ptsText:SetTextColor(unpack(UI.colors.warning))
    end

    -- Texte palier
    if tier then
        tierText:SetText("→  " .. tier.name .. "  (max " .. tier.pts .. " pts)")
        tierText:SetTextColor(tier.r, tier.g, tier.b)
    else
        tierText:SetText("→  Hors palier")
        tierText:SetTextColor(unpack(UI.colors.warning))
    end

    -- Max (palier max disponible)
    maxText:SetText("/ " .. maxT.pts .. " max")

    -- Barre de progression
    local ratio = math.min(1, total / math.max(1, maxT.pts))
    local barW  = math.max(0, (counterFrame:GetWidth() - 6) * ratio)
    progressBar:SetWidth(math.max(1, barW))
    if tier then
        progressBar:SetColorTexture(tier.r, tier.g, tier.b, 0.18)
    else
        progressBar:SetColorTexture(1, 0.2, 0.2, 0.22)
    end
end

-- ── Onglets ───────────────────────────────────────────────────────────────────

local tabY    = counterY - COUNTER_H - 8
local tabW    = math.floor((PANEL_W - PAD * 2 - 8) / #IC.STAT_GROUPS)
local tabRow  = CreateFrame("Frame", nil, panel)
tabRow:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD + 4, tabY)
tabRow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + 4), tabY)
tabRow:SetHeight(TAB_H)

local tabBtns    = {}
local tabContent = {}   -- [groupIndex] = scrollChild frame
local activeTab  = 1

local function SelectTab(idx)
    activeTab = idx
    for i, btn in ipairs(tabBtns) do
        UI.ApplyTabState(btn, i == idx)
    end
    for i, content in pairs(tabContent) do
        content:SetShown(i == idx)
    end
end

-- ── Zone de scroll (contenu des onglets) ─────────────────────────────────────

local scrollTop    = tabY - TAB_H - 2
local scrollBottom = FOOTER_H + 8
local scrollH      = PANEL_H - math.abs(scrollTop) - scrollBottom

local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD + 4, scrollTop)
scrollFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(PAD + 20), scrollTop)
scrollFrame:SetHeight(scrollH)

-- Cache la scrollbar native et utilise une version stylisée
local sb = scrollFrame.ScrollBar or _G[scrollFrame:GetName() and scrollFrame:GetName().."ScrollBar"]
if sb then
    sb:SetAlpha(0.35)
end

-- ── Séparateur bas + Footer ───────────────────────────────────────────────────

local sep2 = panel:CreateTexture(nil, "ARTWORK")
sep2:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",   4, FOOTER_H + 2)
sep2:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, FOOTER_H + 2)
sep2:SetHeight(1)
UI.ApplySeparator(sep2)

local resetBtn = UI.CreatePanelButton(panel, 130, 22, "Réinitialiser")
resetBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + 4, 8)
resetBtn:SetScript("OnClick", function()
    IC:ResetCurrent()
    nameEB:SetText("")
end)

local balanceBtn = UI.CreatePanelButton(panel, 130, 22, "⚖  Équilibrage")
balanceBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -(PAD + 4), 8)
balanceBtn:SetScript("OnClick", function()
    if ItemBalancePanel then ItemBalancePanel:Toggle() end
end)

-- ── Construction des rows de stats ────────────────────────────────────────────

-- Crée une ligne de stat dans le scrollChild donné
local function MakeStatRow(parent, stat, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, yOffset)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, yOffset)
    row:SetHeight(ROW_H)

    -- Fond alterné
    local rowBg = row:CreateTexture(nil, "BACKGROUND")
    rowBg:SetAllPoints()
    rowBg:SetColorTexture(0.06, 0.06, 0.06, 0.50)

    -- Label
    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT", row, "LEFT", 8, 0)
    lbl:SetWidth(190)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(stat.label)
    UI.ApplyBodyText(lbl)

    -- Bouton "−"
    local btnMinus = CreateFrame("Button", nil, row)
    btnMinus:SetSize(20, 20)
    btnMinus:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    local minusBg = btnMinus:CreateTexture(nil, "BACKGROUND")
    minusBg:SetAllPoints()
    minusBg:SetColorTexture(0.10, 0.10, 0.10, 0.90)
    local minusLbl = btnMinus:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minusLbl:SetAllPoints()
    minusLbl:SetText("−")
    UI.ApplyMutedText(minusLbl)
    local minusHl = btnMinus:CreateTexture(nil, "HIGHLIGHT")
    minusHl:SetAllPoints()
    minusHl:SetColorTexture(1, 1, 1, 0.10)

    -- EditBox valeur
    local eb = UI.CreateStyledEditBox(row, 44, 18)
    eb:SetNumeric(false)
    eb:SetMaxLetters(5)
    eb:SetPoint("LEFT", btnMinus, "RIGHT", 4, 0)
    eb:SetJustifyH("CENTER")
    eb:SetText("0")

    -- Bouton "+"
    local btnPlus = CreateFrame("Button", nil, row)
    btnPlus:SetSize(20, 20)
    btnPlus:SetPoint("LEFT", eb, "RIGHT", 4, 0)
    local plusBg = btnPlus:CreateTexture(nil, "BACKGROUND")
    plusBg:SetAllPoints()
    plusBg:SetColorTexture(0.10, 0.10, 0.10, 0.90)
    local plusLbl = btnPlus:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    plusLbl:SetAllPoints()
    plusLbl:SetText("+")
    UI.ApplyMutedText(plusLbl)
    local plusHl = btnPlus:CreateTexture(nil, "HIGHLIGHT")
    plusHl:SetAllPoints()
    plusHl:SetColorTexture(1, 1, 1, 0.10)

    -- Coût affiché à droite
    local costLbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    costLbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    costLbl:SetJustifyH("RIGHT")
    UI.ApplyMutedText(costLbl)

    -- Mise à jour de l'affichage de cette row
    local function Refresh()
        local val  = IC:GetValue(stat.id)
        local cost = IC:GetCost(stat.id)
        eb:SetText(tostring(val))
        local spent = val * cost
        if spent > 0 then
            costLbl:SetText(spent .. " pt" .. (math.abs(spent) > 1 and "s" or ""))
            costLbl:SetTextColor(unpack(UI.colors.textMuted))
        elseif spent < 0 then
            costLbl:SetText(spent .. " pt" .. (math.abs(spent) > 1 and "s" or ""))
            costLbl:SetTextColor(0.30, 0.88, 0.45)
        else
            costLbl:SetText(cost .. "/niv")
            costLbl:SetTextColor(unpack(UI.colors.textSoft))
        end
        RefreshCounter()
    end

    -- Interactions
    btnMinus:SetScript("OnClick", function()
        IC:IncrementValue(stat.id, -1)
        Refresh()
    end)
    btnPlus:SetScript("OnClick", function()
        IC:IncrementValue(stat.id, 1)
        Refresh()
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local raw = self:GetText()
        local v = tonumber(raw)
        if v then
            IC:SetValue(stat.id, v)
        end
        Refresh()
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self)
        Refresh()
        self:ClearFocus()
    end)

    row.Refresh = Refresh
    return row
end

-- ── Création des onglets et leur contenu ──────────────────────────────────────

local allRows = {}   -- { statId = row }

for i, group in ipairs(IC.STAT_GROUPS) do
    -- Bouton d'onglet
    local btn = CreateFrame("Button", nil, tabRow)
    btn:SetSize(tabW, TAB_H)
    btn:SetPoint("LEFT", tabRow, "LEFT", (i - 1) * tabW, 0)

    local btnBg = btn:CreateTexture(nil, "BACKGROUND")
    btnBg:SetAllPoints()
    btnBg:SetColorTexture(0.06, 0.06, 0.06, 0.70)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetAllPoints()
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(group.label)

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

    -- ScrollChild pour ce groupe
    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetWidth(scrollFrame:GetWidth())
    child:SetHeight(#group.stats * ROW_H)
    child:Hide()
    tabContent[i] = child

    -- Rows de stats
    for j, stat in ipairs(group.stats) do
        local row = MakeStatRow(child, stat, -(j - 1) * ROW_H)
        allRows[stat.id] = row
    end
end

-- Le premier scrollChild est le contenu actif par défaut
scrollFrame:SetScrollChild(tabContent[1])

-- Quand on change d'onglet, on change aussi le scrollChild
local origSelectTab = SelectTab
SelectTab = function(idx)
    origSelectTab(idx)
    scrollFrame:SetScrollChild(tabContent[idx])
    scrollFrame:SetVerticalScroll(0)
    for i, content in pairs(tabContent) do
        if i == idx then
            content:SetWidth(scrollFrame:GetWidth())
        end
    end
end

-- Initialisation tabs
SelectTab(1)

-- ── Callback de mise à jour global ────────────────────────────────────────────

IC.OnCurrentChanged = function()
    for statId, row in pairs(allRows) do
        if row.Refresh then row.Refresh() end
    end
    RefreshCounter()
end

-- ── Affichage initial ─────────────────────────────────────────────────────────

panel:SetScript("OnShow", function()
    -- Synchronise le champ nom
    nameEB:SetText(ItemCreatorDB and ItemCreatorDB.currentName or "")
    -- Rafraîchit toutes les rows
    if IC.OnCurrentChanged then IC.OnCurrentChanged() end
end)

-- ── Position sauvegardée ─────────────────────────────────────────────────────

local posFrame = CreateFrame("Frame")
posFrame:RegisterEvent("PLAYER_LOGIN")
posFrame:SetScript("OnEvent", function()
    ItemCreatorDB = ItemCreatorDB or {}
    local p = ItemCreatorDB.creatorPos
    if p then
        panel:ClearAllPoints()
        panel:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
    end
    posFrame:UnregisterAllEvents()
end)

panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ItemCreatorDB = ItemCreatorDB or {}
    local point, _, relPoint, x, y = self:GetPoint()
    ItemCreatorDB.creatorPos = { point = point, relPoint = relPoint, x = x, y = y }
end)
