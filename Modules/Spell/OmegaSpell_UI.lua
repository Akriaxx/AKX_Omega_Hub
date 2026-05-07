-- OmegaSpell - UI.lua
-- Atelier visuel : sorts, groupes d'émotes, fiche du sort.

OmegaSpell    = OmegaSpell or {}
OmegaSpell.UI = OmegaSpell.UI or {}

local OS  = OmegaSpell
local UI  = OmegaSpell.UI
local HUI = OS2.UI

-- ── Constantes layout ─────────────────────────────────────────────────────────

local W        = 940
local H        = 460
local PAD      = 10
local HEADER_H = 40
local FOOTER_H = 44
local ROW_H    = 24

-- Colonnes
local LEFT_W   = 192
local MID_X    = PAD + LEFT_W + PAD + 1 + PAD          -- 223
local MID_W    = 370
local DETAIL_X = MID_X + MID_W + PAD + 1 + PAD         -- 614
local DETAIL_W = W - DETAIL_X - PAD                     -- 316

-- Zone scrollable (sous le label de colonne)
local ACTION_Y = FOOTER_H + 8
local ACTION_H = 24
local LIST_H   = H - HEADER_H - FOOTER_H - ACTION_H - 40

local CHANNELS = {
    { key = "EMOTE",  label = "Émote"  },
    { key = "SAY",    label = "Say"    },
    { key = "YELL",   label = "Yell"   },
    { key = "RAID",   label = "Raid"   },
    { key = "PARTY",  label = "Party"  },
    { key = "GUILD",  label = "Guild"  },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function Trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$") or ""
end

local function TextToLines(text)
    local lines = {}
    for line in string.gmatch((text or "") .. "\n", "(.-)\n") do
        line = Trim(line)
        if line ~= "" then lines[#lines + 1] = line end
    end
    return lines
end

local function CreateChannelDropdown(parent, anchorParent, anchorX, anchorY, w)
    local ITEM_H = 20

    -- Popup ancré sur UIParent pour ne pas être clippé
    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(w, #CHANNELS * ITEM_H + 6)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(200)
    popup:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    popup:SetBackdropColor(0.07, 0.07, 0.07, 1)
    popup:SetBackdropBorderColor(unpack(HUI.colors.separator))
    popup:Hide()

    -- Bouton principal
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w, 22)
    btn:SetPoint("TOPLEFT", anchorParent, "TOPLEFT", anchorX, anchorY)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    btn:SetBackdropColor(0.06, 0.06, 0.06, 1)
    btn:SetBackdropBorderColor(unpack(HUI.colors.separator))

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("LEFT",  btn, "LEFT",  6, 0)
    lbl:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
    lbl:SetJustifyH("LEFT")
    HUI.ApplyBodyText(lbl)
    lbl:SetText(CHANNELS[1].label)

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
    arrow:SetText("v")
    HUI.ApplyMutedText(arrow)

    local currentKey = CHANNELS[1].key

    -- Items de la liste
    for i, ch in ipairs(CHANNELS) do
        local item = CreateFrame("Button", nil, popup)
        item:SetSize(w - 4, ITEM_H)
        item:SetPoint("TOPLEFT", popup, "TOPLEFT", 2, -(i - 1) * ITEM_H - 3)
        local hl = item:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints(); hl:SetColorTexture(0.85, 0.75, 0.40, 0.15)
        local ilbl = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ilbl:SetPoint("LEFT", item, "LEFT", 8, 0)
        ilbl:SetText(ch.label)
        HUI.ApplyBodyText(ilbl)
        local key, label = ch.key, ch.label
        item:SetScript("OnClick", function()
            currentKey = key
            lbl:SetText(label)
            popup:Hide()
            if btn.OnValueChanged then btn.OnValueChanged(key) end
        end)
    end

    btn:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
        else
            popup:ClearAllPoints()
            popup:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
            popup:Show()
        end
    end)

    -- Ferme le popup si on clique ailleurs
    btn:SetScript("OnHide", function() popup:Hide() end)

    btn.GetValue = function() return currentKey end
    btn.SetValue = function(key)
        currentKey = key or CHANNELS[1].key
        for _, ch in ipairs(CHANNELS) do
            if ch.key == currentKey then lbl:SetText(ch.label); return end
        end
        lbl:SetText(CHANNELS[1].label)
    end

    return btn
end

local function RowBg(parent, selected)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(
        selected and 0.18 or 0.08,
        selected and 0.15 or 0.08,
        selected and 0.05 or 0.08, 1)
    return bg
end

local function RowHL(parent)
    local hl = parent:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.85, 0.75, 0.40, 0.10)
end

local function RowAccent(parent)
    local a = parent:CreateTexture(nil, "ARTWORK")
    a:SetWidth(2)
    a:SetPoint("TOPLEFT")
    a:SetPoint("BOTTOMLEFT")
    a:SetColorTexture(unpack(HUI.colors.tabLine))
end

local function HSep(parent, yOffset)
    local s = parent:CreateTexture(nil, "ARTWORK")
    s:SetHeight(1)
    s:SetPoint("TOPLEFT",  parent, "TOPLEFT",  PAD,  yOffset)
    s:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, yOffset)
    HUI.ApplySeparator(s, true)
    return s
end

local function VSep(parent, x)
    local s = parent:CreateTexture(nil, "ARTWORK")
    s:SetWidth(1)
    s:SetPoint("TOPLEFT",    parent, "TOPLEFT",    x, -(HEADER_H + 8))
    s:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, FOOTER_H + 8)
    HUI.ApplySeparator(s, true)
end

local function ColLabel(parent, text, x)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(HEADER_H + 8))
    fs:SetText(text)
    HUI.ApplyLabel(fs)
    return fs
end

local function FieldLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    HUI.ApplyLabel(fs)
    return fs
end

local function ScrollFrame(parent, x, y, w, h)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sf:SetSize(w, h)
    sf:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, sf)
    content:SetWidth(w)
    sf:SetScrollChild(content)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, (content:GetHeight() or 0) - self:GetHeight())
        local cur = self:GetVerticalScroll() or 0
        local next = math.max(0, math.min(max, cur - delta * ROW_H * 3))
        self:SetVerticalScroll(next)
    end)
    return sf, content
end

local function DeleteX(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints(); lbl:SetText("×")
    HUI.ApplyMutedText(lbl)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(0.75, 0.20, 0.20, 0.35)
    btn:SetScript("OnClick", onClick)
    return btn
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- PANEL PRINCIPAL
-- ═══════════════════════════════════════════════════════════════════════════════

local panel = CreateFrame("Frame", "OmegaSpellPanel", UIParent, "BackdropTemplate")
panel:SetSize(W, H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetFrameLevel(120)
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

-- ── Header ────────────────────────────────────────────────────────────────────

do
    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT",  4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(HEADER_H)

    local hBg = header:CreateTexture(nil, "BACKGROUND")
    hBg:SetAllPoints()
    HUI.ApplyWindowBackground(hBg, 0.70)

    local hAccent = header:CreateTexture(nil, "ARTWORK")
    hAccent:SetWidth(3)
    hAccent:SetPoint("TOPLEFT"); hAccent:SetPoint("BOTTOMLEFT")
    hAccent:SetColorTexture(unpack(HUI.colors.tabLine))

    local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("LEFT", header, "LEFT", PAD + 6, 0)
    titleFS:SetText("Omega Spell")
    HUI.ApplyTitle(titleFS)

    HUI.CreateCloseButton(panel, function() panel:Hide() end)
end

-- Séparateur sous le header
HSep(panel, -(HEADER_H + 2))

-- Séparateurs verticaux entre colonnes
VSep(panel, MID_X - PAD - 1)
VSep(panel, DETAIL_X - PAD - 1)

-- ── Labels de colonnes ────────────────────────────────────────────────────────

ColLabel(panel, "SORTS",           PAD + 4)
ColLabel(panel, "GROUPES D'ÉMOTES", MID_X + 4)
local dLabel = ColLabel(panel, "FICHE DU SORT", DETAIL_X + 4)

-- ── Colonne 1 : liste des sorts ───────────────────────────────────────────────

local listTop = -(HEADER_H + 24)

local groupSF, groupContent = ScrollFrame(panel, PAD, listTop, LEFT_W, LIST_H)

-- ── Colonne 2 : groupes d'émotes liés ────────────────────────────────────────

local phraseSF, phraseContent = ScrollFrame(panel, MID_X, listTop, MID_W, LIST_H)

-- ── Colonne 3 : fiche du sort ─────────────────────────────────────────────────

-- Icône + nom du sort
local iconPreview = CreateFrame("Frame", nil, panel)
iconPreview:SetSize(40, 40)
iconPreview:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 24))
do
    local ibg = iconPreview:CreateTexture(nil, "BACKGROUND")
    ibg:SetAllPoints(); ibg:SetColorTexture(0.08, 0.08, 0.08, 1)
end
local iconTex = iconPreview:CreateTexture(nil, "ARTWORK")
iconTex:SetPoint("TOPLEFT",     iconPreview, "TOPLEFT",     3, -3)
iconTex:SetPoint("BOTTOMRIGHT", iconPreview, "BOTTOMRIGHT", -3,  3)

local selectedNameFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
selectedNameFS:SetPoint("TOPLEFT",  iconPreview, "TOPRIGHT", 8, -2)
selectedNameFS:SetPoint("TOPRIGHT", panel,       "TOPRIGHT", -PAD, -(HEADER_H + 24) - 2)
selectedNameFS:SetJustifyH("LEFT"); selectedNameFS:SetWordWrap(false)
HUI.ApplyTitle(selectedNameFS)

local selectedMetaFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
selectedMetaFS:SetPoint("TOPLEFT",  iconPreview, "TOPRIGHT", 8, -20)
selectedMetaFS:SetPoint("TOPRIGHT", panel,       "TOPRIGHT", -PAD, -(HEADER_H + 24) - 20)
selectedMetaFS:SetJustifyH("LEFT"); selectedMetaFS:SetWordWrap(false)
HUI.ApplyMutedText(selectedMetaFS)

-- Séparateur sous l'icône
local detailSep = panel:CreateTexture(nil, "ARTWORK")
detailSep:SetHeight(1)
detailSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  DETAIL_X,     -(HEADER_H + 70))
detailSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD,         -(HEADER_H + 70))
HUI.ApplySeparator(detailSep, true)

-- Nom de macro
FieldLabel(panel, "Nom de macro  (16 car. max)", DETAIL_X, -(HEADER_H + 76))
local macroNameInput = HUI.CreateStyledEditBox(panel, DETAIL_W, 22, false)
macroNameInput:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 90))
macroNameInput:SetMaxLetters(16)

-- Type
FieldLabel(panel, "Type", DETAIL_X, -(HEADER_H + 118))
local categoryInput = HUI.CreateStyledEditBox(panel, DETAIL_W, 22, false)
categoryInput:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 132))
categoryInput:SetMaxLetters(64)

-- Icône
FieldLabel(panel, "Icone", DETAIL_X, -(HEADER_H + 160))
local iconBrowseBtn = HUI.CreatePanelButton(panel, 30, 22, "...")
iconBrowseBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(HEADER_H + 160 + 14))
local iconInput = HUI.CreateStyledEditBox(panel, DETAIL_W - 36, 22, false)
iconInput:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 174))
iconInput:SetMaxLetters(128)

-- Canal
FieldLabel(panel, "Canal de diffusion de l'émote par défaut", DETAIL_X, -(HEADER_H + 202))
local channelDropdown = CreateChannelDropdown(panel, panel, DETAIL_X, -(HEADER_H + 216), DETAIL_W)

-- Texte de macro
FieldLabel(panel, "Contenu de la macro", DETAIL_X, -(HEADER_H + 244))
local macroInput = HUI.CreateStyledEditBox(panel, DETAIL_W, 80, true)
macroInput:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 258))
macroInput:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, ACTION_Y + ACTION_H + 8)
macroInput:SetMaxLetters(1024)
if macroInput.SetJustifyV then
    macroInput:SetJustifyV("TOP")
end
macroInput:SetTextInsets(8, 8, 7, 7)
if macroInput.bg then
    macroInput.bg:SetColorTexture(0.045, 0.045, 0.045, 0.92)
end
local macroInputTop = macroInput:CreateTexture(nil, "ARTWORK")
macroInputTop:SetHeight(1)
macroInputTop:SetPoint("TOPLEFT", macroInput, "TOPLEFT", 2, -1)
macroInputTop:SetPoint("TOPRIGHT", macroInput, "TOPRIGHT", -2, -1)
macroInputTop:SetColorTexture(unpack(HUI.colors.separator))
local macroInputLeft = macroInput:CreateTexture(nil, "ARTWORK")
macroInputLeft:SetWidth(1)
macroInputLeft:SetPoint("TOPLEFT", macroInput, "TOPLEFT", 1, -1)
macroInputLeft:SetPoint("BOTTOMLEFT", macroInput, "BOTTOMLEFT", 1, 1)
macroInputLeft:SetColorTexture(unpack(HUI.colors.separator))
local macroInputRight = macroInput:CreateTexture(nil, "ARTWORK")
macroInputRight:SetWidth(1)
macroInputRight:SetPoint("TOPRIGHT", macroInput, "TOPRIGHT", -1, -1)
macroInputRight:SetPoint("BOTTOMRIGHT", macroInput, "BOTTOMRIGHT", -1, 1)
macroInputRight:SetColorTexture(unpack(HUI.colors.separator))

-- Boutons d'action macro (dans la colonne, sous le texte)
local macroLibraryBtn = HUI.CreatePanelButton(panel, 10, ACTION_H, "Bibliothèque")
local castBtn = HUI.CreatePanelButton(panel, 72, ACTION_H, "Tester")

local macroBtn = HUI.CreatePanelButton(panel, 104, ACTION_H, "Créer macro")
macroBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, ACTION_Y)
castBtn:SetPoint("RIGHT", macroBtn, "LEFT", -6, 0)
macroLibraryBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", DETAIL_X, ACTION_Y)
macroLibraryBtn:SetPoint("RIGHT", castBtn, "LEFT", -6, 0)
macroLibraryBtn:SetHeight(ACTION_H)

-- Ligne d'action alignée par colonne
local newSpellBtn = HUI.CreatePanelButton(panel, LEFT_W, ACTION_H, "Nouveau sort")
newSpellBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, ACTION_Y)

local emoteLibraryBtn = HUI.CreatePanelButton(panel, MID_W, ACTION_H, "Bibliothèque")
emoteLibraryBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", MID_X, ACTION_Y)

-- Footer visuel : les boutons restent au-dessus, la zone basse reste propre.
HSep(panel, -(H - FOOTER_H - 2))
local footerFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
footerFS:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD - 4, 12)
footerFS:SetText("Omega Spell, module de création / gestion de sort V 1.0")
HUI.ApplyMutedText(footerFS)

-- ═══════════════════════════════════════════════════════════════════════════════
-- PANNEAU CRÉATION DE SORT
-- ═══════════════════════════════════════════════════════════════════════════════

local CREATE_W = 420
local CREATE_H = 180

local createPanel = CreateFrame("Frame", "OmegaSpellCreatePanel", UIParent, "BackdropTemplate")
createPanel:SetSize(CREATE_W, CREATE_H)
createPanel:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
createPanel:SetFrameStrata("DIALOG")
createPanel:SetFrameLevel(130)
createPanel:SetMovable(true)
createPanel:EnableMouse(true)
createPanel:RegisterForDrag("LeftButton")
createPanel:SetScript("OnDragStart", createPanel.StartMoving)
createPanel:SetScript("OnDragStop",  createPanel.StopMovingOrSizing)
createPanel:Hide()

do
    local bg = createPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    HUI.ApplyWindowBackground(bg, 0.98)
    createPanel:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets   = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    createPanel:SetBackdropBorderColor(unpack(HUI.colors.separator))

    local ch = CreateFrame("Frame", nil, createPanel)
    ch:SetPoint("TOPLEFT", 4, -4); ch:SetPoint("TOPRIGHT", -4, -4); ch:SetHeight(32)
    local chBg = ch:CreateTexture(nil, "BACKGROUND")
    chBg:SetAllPoints(); HUI.ApplyWindowBackground(chBg, 0.70)
    local chAccent = ch:CreateTexture(nil, "ARTWORK")
    chAccent:SetWidth(3); chAccent:SetPoint("TOPLEFT"); chAccent:SetPoint("BOTTOMLEFT")
    chAccent:SetColorTexture(unpack(HUI.colors.tabLine))
    local chTitle = ch:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chTitle:SetPoint("LEFT", ch, "LEFT", PAD + 4, 0)
    chTitle:SetText("Nouveau sort")
    HUI.ApplyTitle(chTitle)
    HUI.CreateCloseButton(createPanel, function() createPanel:Hide() end)
end

FieldLabel(createPanel, "Nom du sort *", PAD, -44)
local createNameInput = HUI.CreateStyledEditBox(createPanel, CREATE_W - PAD * 2, 22, false)
createNameInput:SetPoint("TOPLEFT", createPanel, "TOPLEFT", PAD, -60)
createNameInput:SetMaxLetters(255)

FieldLabel(createPanel, "Arc ID  (optionnel)", PAD, -90)
local createArcInput = HUI.CreateStyledEditBox(createPanel, (CREATE_W - PAD * 2 - 4) / 2, 22, false)
createArcInput:SetPoint("TOPLEFT", createPanel, "TOPLEFT", PAD, -106)
createArcInput:SetMaxLetters(255)

FieldLabel(createPanel, "Cooldown  (secondes)", PAD + (CREATE_W - PAD * 2 - 4) / 2 + 4, -90)
local createCooldownInput = HUI.CreateStyledEditBox(createPanel, (CREATE_W - PAD * 2 - 4) / 2, 22, false)
createCooldownInput:SetPoint("TOPLEFT", createArcInput, "TOPRIGHT", 4, 0)
createCooldownInput:SetMaxLetters(8)

local createStatus = createPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
createStatus:SetPoint("BOTTOMLEFT", createPanel, "BOTTOMLEFT", PAD + 2, 14)
createStatus:SetPoint("RIGHT", createPanel, "RIGHT", -106, 0)
createStatus:SetJustifyH("LEFT")
HUI.ApplyMutedText(createStatus)

local createOkBtn = HUI.CreatePanelButton(createPanel, 86, 24, "Créer")
createOkBtn:SetPoint("BOTTOMRIGHT", createPanel, "BOTTOMRIGHT", -PAD, 10)

-- ═══════════════════════════════════════════════════════════════════════════════
-- ÉTAT INTERNE
-- ═══════════════════════════════════════════════════════════════════════════════

local selectedSpell    = nil   -- nom du sort sélectionné
local groupRows        = {}
local phraseRows       = {}
local isLoadingDetails = false

-- ── Fiche ─────────────────────────────────────────────────────────────────────

local function GetSpell()
    if not selectedSpell then return nil end
    return OS.GetSpell(selectedSpell)
end

local function RefreshDetails()
    isLoadingDetails = true
    local spell = GetSpell()

    if not spell then
        dLabel:SetText("FICHE DU SORT")
        selectedNameFS:SetText("Aucun sort sélectionné")
        selectedMetaFS:SetText("")
        iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        categoryInput:SetText("")
        iconInput:SetText("")
        channelDropdown.SetValue("EMOTE")
        macroNameInput:SetText("")
        macroInput:SetText("")
        macroBtn:SetText("Créer macro")
        isLoadingDetails = false
        return
    end

    selectedNameFS:SetText(spell.name or selectedSpell)
    selectedMetaFS:SetText(tostring(#(spell.variants or {})) .. " groupe(s) lié(s)")
    iconTex:SetTexture(spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    categoryInput:SetText(spell.category or "")
    iconInput:SetText(tostring(spell.icon or ""))
    channelDropdown.SetValue(spell.channel or "EMOTE")
    macroNameInput:SetText(OS.GetSpellMacroName and OS.GetSpellMacroName(spell.name or selectedSpell) or (spell.name or selectedSpell))
    macroInput:SetText(OS.BuildMacroText(spell))
    macroBtn:SetText((spell.macroID and spell.macroID ~= "") and "Modifier" or "Créer macro")
    isLoadingDetails = false
end

local function SaveDetails()
    if isLoadingDetails then return end
    local spell = GetSpell()
    if not spell then return end

    spell.category = Trim(categoryInput:GetText())
    spell.channel  = channelDropdown.GetValue()
    local iconText = Trim(iconInput:GetText())
    spell.icon = tonumber(iconText) or (iconText ~= "" and iconText or "Interface\\Icons\\INV_Misc_QuestionMark")

    if OS.SetSpellMacroName then
        OS.SetSpellMacroName(spell.name, macroNameInput:GetText())
    end
    OS.SetSpellMacroLines(spell.name, TextToLines(macroInput:GetText()))
    RefreshDetails()
end

-- ── Colonne 2 : groupes d'émotes ─────────────────────────────────────────────

local function RefreshPhrases()
    for _, r in ipairs(phraseRows) do r:Hide() end
    wipe(phraseRows)

    if not selectedSpell then
        phraseContent:SetHeight(LIST_H)
        RefreshDetails()
        return
    end

    local names = OS.GetSortedEmoteGroupNames()
    phraseContent:SetHeight(math.max(LIST_H, #names * ROW_H))

    for i, groupName in ipairs(names) do
        local phrases    = OS.GetEmoteGroup(groupName) or {}
        local isLinked   = OS.IsSpellUsingEmoteGroup(selectedSpell, groupName)
        local row = CreateFrame("Button", nil, phraseContent)
        row:SetSize(MID_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        RowBg(row, isLinked)
        RowHL(row)
        if isLinked then RowAccent(row) end

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -44, 0)
        lbl:SetJustifyH("LEFT"); lbl:SetWordWrap(false)
        lbl:SetText(groupName)
        if isLinked then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        local countFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countFS:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        countFS:SetText(tostring(#phrases) .. " phr.")
        HUI.ApplyMutedText(countFS)

        row:SetScript("OnClick", function()
            OS.ToggleSpellEmoteGroupVariant(selectedSpell, groupName)
            RefreshPhrases()
        end)
        phraseRows[i] = row
    end

    if #names == 0 then
        local hint = phraseContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText("Aucun groupe dans la bibliothèque.")
        HUI.ApplyMutedText(hint)
    end

    RefreshDetails()
end

-- ── Colonne 1 : liste des sorts ───────────────────────────────────────────────

local function RefreshGroups()
    for _, r in ipairs(groupRows) do r:Hide() end
    wipe(groupRows)

    local names = OS.GetSortedSpellNames()
    groupContent:SetHeight(math.max(LIST_H, #names * ROW_H))

    for i, name in ipairs(names) do
        local isSelected = (name == selectedSpell)
        local row = CreateFrame("Button", nil, groupContent)
        row:SetSize(LEFT_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        RowBg(row, isSelected)
        RowHL(row)
        if isSelected then RowAccent(row) end

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -22, 0)
        lbl:SetJustifyH("LEFT"); lbl:SetWordWrap(false)
        lbl:SetText(name)
        if isSelected then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        local n = name
        DeleteX(row, function()
            OS.DeleteSpell(n)
            if selectedSpell == n then selectedSpell = nil end
            RefreshGroups()
            RefreshPhrases()
        end):SetPoint("RIGHT", row, "RIGHT", -2, 0)

        row:SetScript("OnClick", function()
            selectedSpell = name
            RefreshGroups()
            RefreshPhrases()
        end)
        groupRows[i] = row
    end

    if #names == 0 then
        local hint = groupContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText("Aucun sort.")
        HUI.ApplyMutedText(hint)
    end
end

-- ── Création de sort ──────────────────────────────────────────────────────────

local function OpenCreatePanel()
    createNameInput:SetText("")
    createArcInput:SetText("")
    createCooldownInput:SetText("")
    createStatus:SetText("")
    createPanel:Show()
    createNameInput:SetFocus()
end

local function CreateSpell()
    local name = Trim(createNameInput:GetText())
    if name == "" then createStatus:SetText("Nom requis."); return end
    if #name > 255 then name = name:sub(1, 255) end

    local ok, err = OS.AddSpell(name)
    if not ok then createStatus:SetText(err or "Impossible."); return end

    local spell = OS.GetSpell(name)
    if spell then
        spell.arcID    = Trim(createArcInput:GetText())
        spell.cooldown = tonumber(createCooldownInput:GetText()) or 0
    end

    selectedSpell = name
    RefreshGroups()
    RefreshPhrases()
    createPanel:Hide()
end

-- ── Câblage des scripts ───────────────────────────────────────────────────────

newSpellBtn:SetScript("OnClick", function()
    if OmegaSpell.NewSpellImport and OmegaSpell.NewSpellImport.Open then
        OmegaSpell.NewSpellImport.Open()
    else
        OpenCreatePanel()
    end
end)

emoteLibraryBtn:SetScript("OnClick", function()
    if OmegaSpell.EmoteLibrary and OmegaSpell.EmoteLibrary.Open then
        OmegaSpell.EmoteLibrary.Open()
    end
end)

createOkBtn:SetScript("OnClick", CreateSpell)
createNameInput:SetScript("OnEnterPressed", function(self) self:ClearFocus(); CreateSpell() end)

macroLibraryBtn:SetScript("OnClick", function()
    if OmegaSpell.MacroLibrary and OmegaSpell.MacroLibrary.Open then
        OmegaSpell.MacroLibrary.Open()
    end
end)

iconBrowseBtn:SetScript("OnClick", function()
    if OmegaSpell.IconBrowser and OmegaSpell.IconBrowser.Open then
        OmegaSpell.IconBrowser.Open(function(iconPath, iconName)
            iconInput:SetText(iconPath)
            local spell = GetSpell()
            if spell then
                spell.icon = iconPath
                iconTex:SetTexture(iconPath)
            end
        end)
    end
end)

categoryInput:SetScript("OnEnterPressed",  function(self) self:ClearFocus(); SaveDetails() end)
iconInput:SetScript("OnEnterPressed",      function(self) self:ClearFocus(); SaveDetails() end)
macroNameInput:SetScript("OnEnterPressed", function(self) self:ClearFocus(); SaveDetails() end)
macroNameInput:SetScript("OnEditFocusLost", SaveDetails)
macroInput:SetScript("OnEditFocusLost",    SaveDetails)
channelDropdown.OnValueChanged = SaveDetails

castBtn:SetScript("OnClick", function()
    SaveDetails()
    if selectedSpell and OS.CastSpell then OS.CastSpell(selectedSpell) end
end)

macroBtn:SetScript("OnClick", function()
    SaveDetails()
    if selectedSpell and OS.CreateOrUpdateMacro then
        OS.CreateOrUpdateMacro(selectedSpell)
        RefreshDetails()
        if OmegaSpell.MacroLibrary and OmegaSpell.MacroLibrary.Refresh then
            OmegaSpell.MacroLibrary.Refresh()
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- API PUBLIQUE
-- ═══════════════════════════════════════════════════════════════════════════════

function UI.Open()
    if panel:IsShown() then panel:Hide(); return end
    panel:ClearAllPoints()
    panel:SetPoint("CENTER")
    selectedSpell = nil
    RefreshGroups()
    RefreshPhrases()
    panel:Show()
end

function UI.Refresh()
    RefreshGroups()
    RefreshPhrases()
end

function UI.SelectSpell(spellName)
    selectedSpell = spellName
    RefreshGroups()
    RefreshPhrases()
    if not panel:IsShown() then
        panel:ClearAllPoints()
        panel:SetPoint("CENTER")
        panel:Show()
    end
end

function UI.Close()
    panel:Hide()
end
