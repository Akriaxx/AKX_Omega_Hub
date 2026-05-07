-- OmegaSpell - Bibliotheque d'emote
-- Interface dediee aux groupes d'emotes et a leur contenu.

OmegaSpell = OmegaSpell or {}
OmegaSpell.EmoteLibrary = OmegaSpell.EmoteLibrary or {}

local OS  = OmegaSpell
local Lib = OmegaSpell.EmoteLibrary
local HUI = OS2.UI

local W         = 700
local H         = 430
local LEFT_W    = 210
local PAD       = 10
local HEADER_H  = 40
local FOOTER_H  = 56
local LIST_H    = H - HEADER_H - FOOTER_H - 20
local RIGHT_W   = W - LEFT_W - PAD * 3 - 1 - 8
local ROW_H     = 24

local function Trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

local function RowBg(parent, selected)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(selected and 0.18 or 0.08, selected and 0.15 or 0.08, selected and 0.05 or 0.08, 1)
    return bg
end

local function RowHL(parent)
    local hl = parent:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.85, 0.75, 0.40, 0.10)
end

local function Separator(parent, anchor, xL, xR, y)
    local s = parent:CreateTexture(nil, "ARTWORK")
    local rightAnchor = anchor:gsub("LEFT", "RIGHT")
    s:SetHeight(1)
    s:SetPoint("TOPLEFT",  parent, anchor, xL, y)
    s:SetPoint("TOPRIGHT", parent, rightAnchor, xR, y)
    HUI.ApplySeparator(s, true)
    return s
end

local function DeleteBtn(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints()
    lbl:SetText("×")
    HUI.ApplyMutedText(lbl)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.75, 0.20, 0.20, 0.35)
    btn:SetScript("OnClick", onClick)
    return btn
end

local panel = CreateFrame("Frame", "OmegaSpellEmoteLibraryPanel", UIParent, "BackdropTemplate")
panel:SetSize(W, H)
panel:SetPoint("CENTER", UIParent, "CENTER", 36, -36)
panel:SetFrameStrata("HIGH")
panel:SetFrameLevel(125)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:Hide()

local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
HUI.ApplyWindowBackground(panelBg, 0.97)
panel:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropBorderColor(unpack(HUI.colors.separator))

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT",  4, -4)
header:SetPoint("TOPRIGHT", -4, -4)
header:SetHeight(HEADER_H)

local hBg = header:CreateTexture(nil, "BACKGROUND")
hBg:SetAllPoints()
HUI.ApplyWindowBackground(hBg, 0.70)

local hAccent = header:CreateTexture(nil, "ARTWORK")
hAccent:SetWidth(3)
hAccent:SetPoint("TOPLEFT")
hAccent:SetPoint("BOTTOMLEFT")
hAccent:SetColorTexture(unpack(HUI.colors.tabLine))

local titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleFS:SetPoint("LEFT", header, "LEFT", PAD + 6, 0)
titleFS:SetText("Bibliothèque d'émote")
HUI.ApplyTitle(titleFS)

HUI.CreateCloseButton(panel, function() panel:Hide() end)
Separator(panel, "TOPLEFT", 4, -4, -(HEADER_H + 2))

local gLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
gLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, -(HEADER_H + 12))
gLabel:SetText("GROUPES")
HUI.ApplyLabel(gLabel)

local groupSF = CreateFrame("ScrollFrame", nil, panel)
groupSF:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 26))
groupSF:SetSize(LEFT_W, LIST_H)

local groupContent = CreateFrame("Frame", nil, groupSF)
groupContent:SetWidth(LEFT_W)
groupSF:SetScrollChild(groupContent)

local colSep = panel:CreateTexture(nil, "ARTWORK")
colSep:SetWidth(1)
colSep:SetPoint("TOPLEFT",    panel, "TOPLEFT", LEFT_W + PAD * 2 + 1, -(HEADER_H + 8))
colSep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", LEFT_W + PAD * 2 + 1, FOOTER_H + 10)
HUI.ApplySeparator(colSep, true)

local pLabelX = LEFT_W + PAD * 3 + 2

local pLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pLabel:SetPoint("TOPLEFT", panel, "TOPLEFT", pLabelX + 4, -(HEADER_H + 12))
pLabel:SetText("ÉMOTES")
HUI.ApplyLabel(pLabel)

local phraseSF = CreateFrame("ScrollFrame", nil, panel)
phraseSF:SetPoint("TOPLEFT", panel, "TOPLEFT", pLabelX, -(HEADER_H + 26))
phraseSF:SetSize(RIGHT_W, LIST_H)

local phraseContent = CreateFrame("Frame", nil, phraseSF)
phraseContent:SetWidth(RIGHT_W)
phraseSF:SetScrollChild(phraseContent)

Separator(panel, "BOTTOMLEFT", 4, -4, FOOTER_H + 8)

local fgLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
fgLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + 4, FOOTER_H - 4)
fgLabel:SetText("Nouveau groupe")
HUI.ApplyMutedText(fgLabel)

local groupInput = HUI.CreateStyledEditBox(panel, LEFT_W - 60, 22, false)
groupInput:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, 12)
groupInput:SetMaxLetters(64)

local groupAddBtn = HUI.CreatePanelButton(panel, 50, 22, "Ajouter")
groupAddBtn:SetPoint("LEFT", groupInput, "RIGHT", 4, 0)

local fpLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
fpLabel:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", pLabelX + 4, FOOTER_H - 4)
fpLabel:SetText("Nouvelle émote")
HUI.ApplyMutedText(fpLabel)

local phraseInput = HUI.CreateStyledEditBox(panel, RIGHT_W - 60, 22, false)
phraseInput:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", pLabelX, 12)
phraseInput:SetMaxLetters(512)

local phraseAddBtn = HUI.CreatePanelButton(panel, 50, 22, "Ajouter")
phraseAddBtn:SetPoint("LEFT", phraseInput, "RIGHT", 4, 0)

local selectedGroup = nil
local groupRows = {}
local phraseRows = {}

local function RefreshSpellAtelier()
    if OmegaSpell.UI and OmegaSpell.UI.Refresh then
        OmegaSpell.UI.Refresh()
    end
end

local function RefreshPhrases()
    for _, row in ipairs(phraseRows) do row:Hide() end
    wipe(phraseRows)

    if not selectedGroup then
        pLabel:SetText("EMOTES  -  selectionnez un groupe")
        phraseContent:SetHeight(LIST_H)
        return
    end

    pLabel:SetText("EMOTES  -  " .. selectedGroup)

    local phrases = OS.GetEmoteGroups()[selectedGroup] or {}
    phraseContent:SetHeight(math.max(LIST_H, #phrases * ROW_H))

    for i, text in ipairs(phrases) do
        local row = CreateFrame("Button", nil, phraseContent)
        row:SetSize(RIGHT_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)

        RowBg(row, false)
        RowHL(row)

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -24, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(text)
        HUI.ApplyBodyText(lbl)

        local phraseIndex = i
        DeleteBtn(row, function()
            OS.DeleteEmotePhrase(selectedGroup, phraseIndex)
            RefreshPhrases()
            RefreshSpellAtelier()
        end):SetPoint("RIGHT", row, "RIGHT", -4, 0)

        phraseRows[i] = row
    end

    if #phrases == 0 then
        local hint = phraseContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText("Aucune émote. Ajoutez-en ci-dessous.")
        HUI.ApplyMutedText(hint)
    end
end

local function RefreshGroups()
    for _, row in ipairs(groupRows) do row:Hide() end
    wipe(groupRows)

    local names = OS.GetSortedEmoteGroupNames()
    groupContent:SetHeight(math.max(LIST_H, #names * ROW_H))

    for i, name in ipairs(names) do
        local isSelected = name == selectedGroup
        local row = CreateFrame("Button", nil, groupContent)
        row:SetSize(LEFT_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)

        RowBg(row, isSelected)
        RowHL(row)

        if isSelected then
            local accent = row:CreateTexture(nil, "ARTWORK")
            accent:SetWidth(2)
            accent:SetPoint("TOPLEFT")
            accent:SetPoint("BOTTOMLEFT")
            accent:SetColorTexture(unpack(HUI.colors.tabLine))
        end

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT",  row, "LEFT",  6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -22, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(name)
        if isSelected then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        local groupName = name
        DeleteBtn(row, function()
            OS.DeleteEmoteGroup(groupName)
            if selectedGroup == groupName then selectedGroup = nil end
            RefreshGroups()
            RefreshPhrases()
            RefreshSpellAtelier()
        end):SetPoint("RIGHT", row, "RIGHT", -2, 0)

        row:SetScript("OnClick", function()
            selectedGroup = name
            RefreshGroups()
            RefreshPhrases()
        end)

        groupRows[i] = row
    end

    if #names == 0 then
        local hint = groupContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText("Aucun groupe.")
        HUI.ApplyMutedText(hint)
    end
end

groupAddBtn:SetScript("OnClick", function()
    local name = groupInput:GetText()
    local ok, err = OS.AddEmoteGroup(name)
    if ok then
        selectedGroup = Trim(name)
        groupInput:SetText("")
        RefreshGroups()
        RefreshPhrases()
        RefreshSpellAtelier()
    else
        print("|cff66ccffOmegaSpell|r: " .. (err or "Erreur"))
    end
end)

phraseAddBtn:SetScript("OnClick", function()
    if not selectedGroup then
        print("|cff66ccffOmegaSpell|r: Sélectionnez un groupe d'abord.")
        return
    end

    local ok, err = OS.AddEmotePhrase(selectedGroup, phraseInput:GetText())
    if ok then
        phraseInput:SetText("")
        RefreshPhrases()
        RefreshSpellAtelier()
    else
        print("|cff66ccffOmegaSpell|r: " .. (err or "Erreur"))
    end
end)

function Lib.Open()
    if panel:IsShown() then
        panel:Hide()
        return
    end

    if not selectedGroup then
        local names = OS.GetSortedEmoteGroupNames()
        selectedGroup = names[1]
    end

    RefreshGroups()
    RefreshPhrases()
    panel:Show()
end

function Lib.Close()
    panel:Hide()
end
