-- OmegaSpell - Lien Arcaneum
-- Interface de chargement d'un profil Arcanum / SpellCreator.

OmegaSpell = OmegaSpell or {}
OmegaSpell.ArcaneumLink = OmegaSpell.ArcaneumLink or {}

local OS   = OmegaSpell
local Link = OmegaSpell.ArcaneumLink
local Arc  = OmegaSpell.Arcaneum
local HUI  = OS2.UI

local W         = 820
local H         = 460
local LEFT_W    = 210
local MID_W     = 310
local PAD       = 10
local HEADER_H  = 40
local FOOTER_H  = 48
local LIST_H    = H - HEADER_H - FOOTER_H - 20
local DETAIL_X  = PAD + LEFT_W + PAD + 1 + PAD + MID_W + PAD + 1 + PAD
local MID_X     = PAD + LEFT_W + PAD + 1 + PAD
local DETAIL_W  = W - DETAIL_X - PAD
local ROW_H     = 24

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

local function VerticalSeparator(parent, x)
    local s = parent:CreateTexture(nil, "ARTWORK")
    s:SetWidth(1)
    s:SetPoint("TOPLEFT",    parent, "TOPLEFT", x, -(HEADER_H + 8))
    s:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, FOOTER_H + 10)
    HUI.ApplySeparator(s, true)
end

local function Label(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    HUI.ApplyLabel(fs)
    return fs
end

local panel = CreateFrame("Frame", "OmegaSpellArcaneumLinkPanel", UIParent, "BackdropTemplate")
panel:SetSize(W, H)
panel:SetPoint("CENTER", UIParent, "CENTER", 48, -48)
panel:SetFrameStrata("HIGH")
panel:SetFrameLevel(126)
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
titleFS:SetText("Lien Arcaneum")
HUI.ApplyTitle(titleFS)

local refreshBtn = HUI.CreatePanelButton(header, 86, 22, "Actualiser")
refreshBtn:SetPoint("RIGHT", header, "RIGHT", -32, 0)

HUI.CreateCloseButton(panel, function() panel:Hide() end)
Separator(panel, "TOPLEFT", 4, -4, -(HEADER_H + 2))

Label(panel, "PROFILS", PAD + 4, -(HEADER_H + 12))
local profileSF = CreateFrame("ScrollFrame", nil, panel)
profileSF:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 26))
profileSF:SetSize(LEFT_W, LIST_H)
local profileContent = CreateFrame("Frame", nil, profileSF)
profileContent:SetWidth(LEFT_W)
profileSF:SetScrollChild(profileContent)

VerticalSeparator(panel, PAD + LEFT_W + PAD)

local spellLabel = Label(panel, "SORTS DU PROFIL", MID_X + 4, -(HEADER_H + 12))
local spellSF = CreateFrame("ScrollFrame", nil, panel)
spellSF:SetPoint("TOPLEFT", panel, "TOPLEFT", MID_X, -(HEADER_H + 26))
spellSF:SetSize(MID_W, LIST_H)
local spellContent = CreateFrame("Frame", nil, spellSF)
spellContent:SetWidth(MID_W)
spellSF:SetScrollChild(spellContent)

VerticalSeparator(panel, DETAIL_X - PAD)

Label(panel, "FICHE ARCANEUM", DETAIL_X + 4, -(HEADER_H + 12))

local iconPreview = CreateFrame("Frame", nil, panel)
iconPreview:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 34))
iconPreview:SetSize(40, 40)
local iconBg = iconPreview:CreateTexture(nil, "BACKGROUND")
iconBg:SetAllPoints()
iconBg:SetColorTexture(0.08, 0.08, 0.08, 1)
local iconTex = iconPreview:CreateTexture(nil, "ARTWORK")
iconTex:SetPoint("TOPLEFT", iconPreview, "TOPLEFT", 3, -3)
iconTex:SetPoint("BOTTOMRIGHT", iconPreview, "BOTTOMRIGHT", -3, 3)

local nameFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
nameFS:SetPoint("TOPLEFT", iconPreview, "TOPRIGHT", 8, -2)
nameFS:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
nameFS:SetJustifyH("LEFT")
nameFS:SetWordWrap(false)
HUI.ApplyTitle(nameFS)

local metaFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
metaFS:SetPoint("TOPLEFT", iconPreview, "TOPRIGHT", 8, -24)
metaFS:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
metaFS:SetJustifyH("LEFT")
metaFS:SetWordWrap(false)
HUI.ApplyMutedText(metaFS)

Label(panel, "Description", DETAIL_X, -(HEADER_H + 92))
local descFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
descFS:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 110))
descFS:SetSize(DETAIL_W, 96)
descFS:SetJustifyH("LEFT")
descFS:SetJustifyV("TOP")
descFS:SetWordWrap(true)
HUI.ApplyBodyText(descFS)

Label(panel, "Macro Omega", DETAIL_X, -(HEADER_H + 220))
local macroFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
macroFS:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 238))
macroFS:SetSize(DETAIL_W, 52)
macroFS:SetJustifyH("LEFT")
macroFS:SetJustifyV("TOP")
macroFS:SetWordWrap(true)
HUI.ApplyMutedText(macroFS)

local testBtn = HUI.CreatePanelButton(panel, 76, 22, "Tester")
testBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", DETAIL_X, 12)

local importBtn = HUI.CreatePanelButton(panel, 96, 22, "Importer")
importBtn:SetPoint("LEFT", testBtn, "RIGHT", 6, 0)

Separator(panel, "BOTTOMLEFT", 4, -4, FOOTER_H + 8)

local statusFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusFS:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + 4, 16)
statusFS:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
statusFS:SetJustifyH("LEFT")
statusFS:SetText("")
HUI.ApplyMutedText(statusFS)

local selectedProfile = nil
local selectedEntry = nil
local profileRows = {}
local spellRows = {}

local RefreshProfiles
local RefreshSpells
local RefreshDetails

local function ProfileExists(profiles, profileName)
    for _, profile in ipairs(profiles or {}) do
        if profile == profileName then return true end
    end
    return false
end

local function SetStatus(text)
    statusFS:SetText(text or "")
end

function RefreshDetails()
    if not selectedEntry then
        nameFS:SetText("Aucun sort sélectionné")
        metaFS:SetText("")
        descFS:SetText("")
        macroFS:SetText("")
        iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        return
    end

    nameFS:SetText(selectedEntry.name)
    metaFS:SetText((selectedEntry.profile or "") .. "  •  " .. (selectedEntry.vault or "personal") .. "  •  " .. (selectedEntry.commID or ""))
    descFS:SetText(selectedEntry.description or "")
    macroFS:SetText(Arc.BuildMacroLine(selectedEntry.commID, selectedEntry.vault))
    iconTex:SetTexture(selectedEntry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
end

function RefreshSpells()
    for _, row in ipairs(spellRows) do row:Hide() end
    wipe(spellRows)

    local spells = Arc.GetSpells(selectedProfile)
    spellLabel:SetText("SORTS DU PROFIL  -  " .. tostring(#spells))
    spellContent:SetHeight(math.max(LIST_H, #spells * ROW_H))

    if selectedEntry then
        local stillExists = false
        for _, entry in ipairs(spells) do
            if entry.commID == selectedEntry.commID then stillExists = true end
        end
        if not stillExists then selectedEntry = nil end
    end

    for i, entry in ipairs(spells) do
        local isSelected = selectedEntry and entry.commID == selectedEntry.commID
        local row = CreateFrame("Button", nil, spellContent)
        row:SetSize(MID_W, ROW_H)
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
        lbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(entry.name)
        if isSelected then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        row:SetScript("OnClick", function()
            selectedEntry = entry
            RefreshSpells()
            RefreshDetails()
        end)

        spellRows[i] = row
    end

    if #spells == 0 then
        local hint = spellContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText("Aucun sort dans ce profil.")
        HUI.ApplyMutedText(hint)
    end

    RefreshDetails()
end

function RefreshProfiles()
    for _, row in ipairs(profileRows) do row:Hide() end
    wipe(profileRows)

    if not Arc.IsAvailable() then
        profileContent:SetHeight(LIST_H)
        SetStatus("Arcaneum / SpellCreator n'est pas chargé, ou aucun sort personnel n'est encore sauvegardé.")
        selectedProfile = nil
        selectedEntry = nil
        RefreshSpells()
        return
    end

    local profiles = Arc.GetProfileNames()
    local savedProfile = Arc.GetSelectedProfile()
    if not ProfileExists(profiles, selectedProfile) then
        if savedProfile ~= "" and ProfileExists(profiles, savedProfile) then
            selectedProfile = savedProfile
        else
            selectedProfile = profiles[1]
        end
    end
    profileContent:SetHeight(math.max(LIST_H, #profiles * ROW_H))

    for i, profile in ipairs(profiles) do
        local isSelected = profile == selectedProfile
        local row = CreateFrame("Button", nil, profileContent)
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
        lbl:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(profile)
        if isSelected then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        row:SetScript("OnClick", function()
            selectedProfile = profile
            selectedEntry = nil
            Arc.SetSelectedProfile(profile)
            SetStatus("Profil chargé : " .. profile)
            RefreshProfiles()
            RefreshSpells()
        end)

        profileRows[i] = row
    end

    if #profiles == 0 then
        local hint = profileContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText("Aucun profil.")
        HUI.ApplyMutedText(hint)
        SetStatus("Aucun profil Arcaneum trouvé dans les sorts personnels.")
    else
        Arc.SetSelectedProfile(selectedProfile)
        SetStatus("Profil chargé : " .. selectedProfile)
    end

    RefreshSpells()
end

refreshBtn:SetScript("OnClick", RefreshProfiles)

testBtn:SetScript("OnClick", function()
    if not selectedEntry then
        SetStatus("Sélectionnez un sort Arcaneum d'abord.")
        return
    end

    local ok, err = Arc.Cast(selectedEntry.commID, selectedEntry.vault)
    SetStatus(ok and ("Test lancé : " .. selectedEntry.name) or (err or "Erreur Arcaneum."))
end)

importBtn:SetScript("OnClick", function()
    if not selectedEntry then
        SetStatus("Sélectionnez un sort Arcaneum d'abord.")
        return
    end

    local ok, result = Arc.CreateOmegaSpell(selectedEntry)
    if ok then
        SetStatus("Sort Omega créé : " .. result)
        if OmegaSpell.UI and OmegaSpell.UI.Refresh then
            OmegaSpell.UI.Refresh()
        end
    else
        SetStatus(result or "Import impossible.")
    end
end)

function Link.Open()
    if panel:IsShown() then
        panel:Hide()
        return
    end

    RefreshProfiles()
    panel:Show()
end

function Link.Close()
    panel:Hide()
end
