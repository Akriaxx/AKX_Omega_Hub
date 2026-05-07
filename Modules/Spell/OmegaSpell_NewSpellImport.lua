-- OmegaSpell - Nouveau sort / import de sources externes

OmegaSpell = OmegaSpell or {}
OmegaSpell.NewSpellImport = OmegaSpell.NewSpellImport or {}

local OS  = OmegaSpell
local Lib = OmegaSpell.NewSpellImport
local Arc = OmegaSpell.Arcaneum
local HUI = OS2.UI

local W        = 860
local H        = 500
local PAD      = 10
local HEADER_H = 40
local FOOTER_H = 42
local ROW_H    = 24

local LEFT_W   = 210
local MID_X    = PAD + LEFT_W + PAD + 1 + PAD
local MID_W    = 330
local DETAIL_X = MID_X + MID_W + PAD + 1 + PAD
local DETAIL_W = W - DETAIL_X - PAD
local LIST_TOP = -(HEADER_H + 62)
local LIST_H   = H - HEADER_H - FOOTER_H - 72

local panel
local profileSF
local entrySF
local profileContent
local entryContent
local titleFS
local wowTab
local arcTab
local profileLabel
local entryLabel
local statusFS
local iconTex
local nameFS
local metaFS
local bodyFS
local importBtn
local refreshBtn

local selectedSource = "wow"
local selectedProfile
local selectedEntry
local profileRows = {}
local entryRows = {}

local function ResetScroll(frame)
    if frame and frame.SetVerticalScroll then
        frame:SetVerticalScroll(0)
    end
end

local function Trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

local function SafeLower(text)
    return tostring(text or ""):lower()
end

local function BodyPreview(body)
    local text = tostring(body or ""):gsub("\n+$", ""):gsub("\n", " | ")
    if #text > 54 then text = text:sub(1, 51) .. "..." end
    return text
end

local function CurrentCharacterKey()
    local name, realm
    if UnitFullName then
        name, realm = UnitFullName("player")
    end
    name = Trim(name)
    realm = Trim((realm and realm ~= "" and realm) or (GetRealmName and GetRealmName()) or "")
    if name == "" then name = "Personnage" end
    if realm == "" then return name end
    return name .. " - " .. realm
end

local function CopyMacroRecord(record)
    return {
        index       = record.index,
        name        = record.name,
        displayName = record.displayName or record.name,
        icon        = record.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        body        = record.body or "",
        typeText    = record.typeText,
        isChar      = record.isChar,
    }
end

local function GetWTFMacroCache()
    if type(OmegaSpellWTFMacroCache) ~= "table" then return nil end
    if type(OmegaSpellWTFMacroCache.profiles) ~= "table" then return nil end
    return OmegaSpellWTFMacroCache
end

local function FindWTFProfile(profileKey)
    local cache = GetWTFMacroCache()
    if not cache then return nil end
    for _, profile in ipairs(cache.profiles or {}) do
        if profile.key == profileKey then return profile end
    end
    return nil
end

local function AddProfileOnce(profiles, seen, profile)
    if not profile or not profile.key or seen[profile.key] then return end
    seen[profile.key] = true
    profiles[#profiles + 1] = profile
end

local function ReadNativeMacros()
    local global = {}
    local character = {}
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then
        return global, character
    end

    local globalCount, charCount = GetNumMacros()
    for i = 1, (globalCount or 0) do
        local name, icon, body = GetMacroInfo(i)
        if name and name ~= "" then
            global[#global + 1] = {
                index = i,
                name = name,
                displayName = name,
                icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                body = body or "",
                typeText = "Global",
                isChar = false,
            }
        end
    end

    local accountMax = MAX_ACCOUNT_MACROS or 120
    for i = 1, (charCount or 0) do
        local index = accountMax + i
        local name, icon, body = GetMacroInfo(index)
        if name and name ~= "" then
            character[#character + 1] = {
                index = index,
                name = name,
                displayName = name,
                icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                body = body or "",
                typeText = "Perso",
                isChar = true,
            }
        end
    end

    return global, character
end

local function CacheWoWMacros()
    OS.DB_Init()
    local db = OmegaSpellDB.wowMacroProfiles
    local global, character = ReadNativeMacros()
    db.global = global

    local key = CurrentCharacterKey()
    db.characters[key] = db.characters[key] or {}
    db.characters[key].label = key
    db.characters[key].lastSeen = time and time() or nil
    db.characters[key].macros = character
end

local function GetWoWProfiles()
    CacheWoWMacros()
    local profiles = {}
    local seen = {}
    local cache = GetWTFMacroCache()
    local wtfGlobal = FindWTFProfile("WTF:GLOBAL")

    AddProfileOnce(profiles, seen, {
        key = wtfGlobal and "WTF:GLOBAL" or "GLOBAL",
        label = "Global",
        count = wtfGlobal and #(wtfGlobal.macros or {}) or #(OmegaSpellDB.wowMacroProfiles.global or {}),
        isWTF = wtfGlobal ~= nil,
    })

    local chars = {}
    if not cache then
        for key, data in pairs(OmegaSpellDB.wowMacroProfiles.characters or {}) do
            chars[#chars + 1] = {
                key = key,
                label = data.label or key,
                count = #(data.macros or {}),
            }
        end
        table.sort(chars, function(a, b) return SafeLower(a.label) < SafeLower(b.label) end)
    end

    for _, profile in ipairs(chars) do
        AddProfileOnce(profiles, seen, profile)
    end

    local wtfProfiles = {}
    for _, profile in ipairs((cache and cache.profiles) or {}) do
        if profile.key == "WTF:GLOBAL" then
            -- Déjà représenté par le profil unique "Global" en tête de liste.
        else
            wtfProfiles[#wtfProfiles + 1] = {
                key = profile.key,
                label = profile.label or profile.key,
                count = #(profile.macros or {}),
                isWTF = true,
            }
        end
    end
    table.sort(wtfProfiles, function(a, b)
        if a.label == b.label then return SafeLower(a.key) < SafeLower(b.key) end
        return SafeLower(a.label) < SafeLower(b.label)
    end)

    for _, profile in ipairs(wtfProfiles) do
        AddProfileOnce(profiles, seen, profile)
    end
    return profiles
end

local function GetWoWEntries(profileKey)
    CacheWoWMacros()
    local rows
    local wtfProfile = FindWTFProfile(profileKey)
    if wtfProfile then
        rows = wtfProfile.macros or {}
    elseif profileKey == "GLOBAL" then
        rows = OmegaSpellDB.wowMacroProfiles.global or {}
    else
        local data = OmegaSpellDB.wowMacroProfiles.characters and OmegaSpellDB.wowMacroProfiles.characters[profileKey]
        rows = data and data.macros or {}
    end

    local entries = {}
    for _, record in ipairs(rows or {}) do
        local copy = CopyMacroRecord(record)
        copy.source = "wow"
        copy.typeText = copy.typeText or (wtfProfile and (wtfProfile.type == "global" and "Global" or "Perso")) or "Macro"
        copy.preview = BodyPreview(copy.body)
        entries[#entries + 1] = copy
    end
    table.sort(entries, function(a, b) return SafeLower(a.name) < SafeLower(b.name) end)
    return entries
end

local function GetArcProfiles()
    if not (Arc and Arc.IsAvailable and Arc.IsAvailable()) then return {} end
    local profiles = {}
    for _, profileName in ipairs(Arc.GetProfileNames and Arc.GetProfileNames() or {}) do
        local count = #(Arc.GetSpells and Arc.GetSpells(profileName) or {})
        profiles[#profiles + 1] = {
            key = profileName,
            label = profileName,
            count = count,
        }
    end
    return profiles
end

local function GetArcEntries(profileKey)
    if not (Arc and Arc.GetSpells) then return {} end
    local entries = {}
    for _, entry in ipairs(Arc.GetSpells(profileKey) or {}) do
        entry.source = "arcaneum"
        entry.body = Arc.BuildMacroLine and Arc.BuildMacroLine(entry.commID, entry.vault) or ""
        entry.preview = entry.commID or ""
        entries[#entries + 1] = entry
    end
    return entries
end

local function RowBg(parent, selected)
    local bg = parent:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(
        selected and 0.18 or 0.08,
        selected and 0.15 or 0.08,
        selected and 0.05 or 0.08,
        1)
end

local function RowHL(parent)
    local hl = parent:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.85, 0.75, 0.40, 0.10)
end

local function Accent(parent)
    local a = parent:CreateTexture(nil, "ARTWORK")
    a:SetWidth(2)
    a:SetPoint("TOPLEFT")
    a:SetPoint("BOTTOMLEFT")
    a:SetColorTexture(unpack(HUI.colors.tabLine))
end

local function Separator(parent, y)
    local s = parent:CreateTexture(nil, "ARTWORK")
    s:SetHeight(1)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, y)
    s:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y)
    HUI.ApplySeparator(s, true)
end

local function VerticalSeparator(parent, x)
    local s = parent:CreateTexture(nil, "ARTWORK")
    s:SetWidth(1)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -(HEADER_H + 52))
    s:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x, FOOTER_H + 8)
    HUI.ApplySeparator(s, true)
end

local function Label(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    HUI.ApplyLabel(fs)
    return fs
end

local function CreateScroll(parent, x, y, w, h)
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
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)
    return sf, content
end

local RefreshAll
local RefreshProfiles
local RefreshEntries
local RefreshDetails

local function SourceAvailable(source)
    if source == "arcaneum" then
        return Arc and Arc.IsAvailable and Arc.IsAvailable()
    end
    return true
end

local function SetSource(source)
    if not SourceAvailable(source) then source = "wow" end
    selectedSource = source
    selectedProfile = nil
    selectedEntry = nil
    ResetScroll(profileSF)
    ResetScroll(entrySF)
    RefreshAll()
end

local function ApplyTabVisual()
    local active = selectedSource
    wowTab.bgN:SetColorTexture(active == "wow" and 0.16 or 0.08, active == "wow" and 0.13 or 0.08, active == "wow" and 0.04 or 0.08, 1)
    arcTab.bgN:SetColorTexture(active == "arcaneum" and 0.16 or 0.08, active == "arcaneum" and 0.13 or 0.08, active == "arcaneum" and 0.04 or 0.08, 1)
    if SourceAvailable("arcaneum") then
        arcTab:Show()
    else
        arcTab:Hide()
    end
end

local function GetProfiles()
    if selectedSource == "arcaneum" then return GetArcProfiles() end
    return GetWoWProfiles()
end

local function GetEntries()
    if selectedSource == "arcaneum" then return GetArcEntries(selectedProfile) end
    return GetWoWEntries(selectedProfile)
end

function RefreshDetails()
    if not selectedEntry then
        iconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        nameFS:SetText("Aucune macro sélectionnée")
        metaFS:SetText("")
        bodyFS:SetText("")
        return
    end

    iconTex:SetTexture(selectedEntry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    nameFS:SetText(selectedEntry.name or selectedEntry.displayName or "Macro")
    if selectedSource == "arcaneum" then
        metaFS:SetText("Arcaneum  •  " .. tostring(selectedEntry.profile or "") .. "  •  " .. tostring(selectedEntry.commID or ""))
        bodyFS:SetText(selectedEntry.description or selectedEntry.body or "")
    else
        metaFS:SetText("World of Warcraft  •  " .. tostring(selectedEntry.typeText or "Macro"))
        bodyFS:SetText(selectedEntry.body or "")
    end
end

function RefreshEntries()
    for _, row in ipairs(entryRows) do row:Hide() end
    wipe(entryRows)

    local entries = selectedProfile and GetEntries() or {}
    entryLabel:SetText(selectedSource == "arcaneum" and "SORTS DU PROFIL" or "MACROS DU PROFIL")
    entryContent:SetHeight(math.max(LIST_H, #entries * ROW_H))

    if selectedEntry then
        local stillExists = false
        for _, entry in ipairs(entries) do
            if selectedSource == "arcaneum" then
                stillExists = entry.commID == selectedEntry.commID
            else
                stillExists = entry.name == selectedEntry.name and entry.body == selectedEntry.body
            end
            if stillExists then break end
        end
        if not stillExists then selectedEntry = nil end
    end

    for i, entry in ipairs(entries) do
        local isSelected = selectedEntry and (
            (selectedSource == "arcaneum" and entry.commID == selectedEntry.commID)
            or (selectedSource == "wow" and entry.name == selectedEntry.name and entry.body == selectedEntry.body)
        )
        local row = CreateFrame("Button", nil, entryContent)
        row:SetSize(MID_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        RowBg(row, isSelected)
        RowHL(row)
        if isSelected then Accent(row) end

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -84, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(entry.name or entry.displayName or "Macro")
        if isSelected then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        local preview = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        preview:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        preview:SetWidth(76)
        preview:SetJustifyH("RIGHT")
        preview:SetWordWrap(false)
        preview:SetText(entry.preview or "")
        HUI.ApplyMutedText(preview)

        row:SetScript("OnClick", function()
            selectedEntry = entry
            RefreshEntries()
            RefreshDetails()
        end)
        entryRows[i] = row
    end

    if #entries == 0 then
        local hint = entryContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText(selectedProfile and "Aucune macro dans ce profil." or "Sélectionnez un profil.")
        HUI.ApplyMutedText(hint)
    end

    RefreshDetails()
end

function RefreshProfiles()
    for _, row in ipairs(profileRows) do row:Hide() end
    wipe(profileRows)

    local profiles = GetProfiles()
    profileLabel:SetText(selectedSource == "arcaneum" and "PROFILS ARCANEUM" or "PROFILS WOW")
    if not selectedProfile and profiles[1] then
        selectedProfile = profiles[1].key
    end

    local exists = false
    for _, profile in ipairs(profiles) do
        if profile.key == selectedProfile then exists = true end
    end
    if not exists then selectedProfile = profiles[1] and profiles[1].key or nil end

    profileContent:SetHeight(math.max(LIST_H, #profiles * ROW_H))

    for i, profile in ipairs(profiles) do
        local isSelected = profile.key == selectedProfile
        local row = CreateFrame("Button", nil, profileContent)
        row:SetSize(LEFT_W, ROW_H)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        RowBg(row, isSelected)
        RowHL(row)
        if isSelected then Accent(row) end

        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("LEFT", row, "LEFT", 6, 0)
        lbl:SetPoint("RIGHT", row, "RIGHT", -34, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false)
        lbl:SetText(profile.label)
        if isSelected then HUI.ApplyStrongLabel(lbl) else HUI.ApplyBodyText(lbl) end

        local count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        count:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        count:SetText(tostring(profile.count or 0))
        HUI.ApplyMutedText(count)

        row:SetScript("OnClick", function()
            selectedProfile = profile.key
            selectedEntry = nil
            ResetScroll(entrySF)
            if selectedSource == "arcaneum" and Arc and Arc.SetSelectedProfile then
                Arc.SetSelectedProfile(profile.key)
            end
            RefreshProfiles()
            RefreshEntries()
        end)

        profileRows[i] = row
    end

    if #profiles == 0 then
        local hint = profileContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", 6, -8)
        hint:SetText(selectedSource == "arcaneum" and "Arcaneum indisponible." or "Aucun profil.")
        HUI.ApplyMutedText(hint)
    end
end

function RefreshAll()
    if selectedSource == "arcaneum" and not SourceAvailable("arcaneum") then
        selectedSource = "wow"
    end
    titleFS:SetText("Nouveau sort")
    ApplyTabVisual()
    RefreshProfiles()
    RefreshEntries()
    statusFS:SetText("")
end

local function ImportSelected()
    if not selectedEntry then
        statusFS:SetText("Sélectionnez une macro d'abord.")
        return
    end

    local ok, result
    if selectedSource == "arcaneum" then
        if not (Arc and Arc.CreateOmegaSpell) then
            statusFS:SetText("Import Arcaneum indisponible.")
            return
        end
        ok, result = Arc.CreateOmegaSpell(selectedEntry)
    else
        if not (OS.MacroInterface and OS.MacroInterface.ImportWoWMacroAsSpell) then
            statusFS:SetText("Import Macro WoW indisponible.")
            return
        end
        ok, result = OS.MacroInterface.ImportWoWMacroAsSpell(selectedEntry)
    end

    if ok then
        statusFS:SetText("Sort créé : " .. tostring(result))
        if OS.UI and OS.UI.Refresh then OS.UI.Refresh() end
        if OS.UI and OS.UI.SelectSpell then
            local spellName = selectedSource == "arcaneum" and result or selectedEntry.name
            OS.UI.SelectSpell(spellName)
        end
    else
        statusFS:SetText(result or "Import impossible.")
    end
end

local function Build()
    if panel then return panel end

    panel = CreateFrame("Frame", "OmegaSpellNewSpellImportPanel", UIParent, "BackdropTemplate")
    panel:SetSize(W, H)
    panel:SetPoint("CENTER", UIParent, "CENTER", 40, -30)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(130)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    HUI.ApplyWindowBackground(bg, 0.97)
    panel:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:SetBackdropBorderColor(unpack(HUI.colors.separator))

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT", 4, -4)
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

    titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleFS:SetPoint("LEFT", header, "LEFT", PAD + 6, 0)
    HUI.ApplyTitle(titleFS)

    refreshBtn = HUI.CreatePanelButton(header, 86, 22, "Actualiser")
    refreshBtn:SetPoint("RIGHT", header, "RIGHT", -32, 0)
    HUI.CreateCloseButton(panel, function() panel:Hide() end)

    Separator(panel, -(HEADER_H + 2))

    wowTab = HUI.CreatePanelButton(panel, 150, 24, "World Of Warcraft")
    wowTab:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 14))
    arcTab = HUI.CreatePanelButton(panel, 110, 24, "Arcaneum")
    arcTab:SetPoint("LEFT", wowTab, "RIGHT", 6, 0)

    profileLabel = Label(panel, "PROFILS WOW", PAD + 4, -(HEADER_H + 46))
    local psf, pc = CreateScroll(panel, PAD, LIST_TOP, LEFT_W, LIST_H)
    profileSF = psf
    profileContent = pc

    VerticalSeparator(panel, MID_X - PAD - 1)

    entryLabel = Label(panel, "MACROS DU PROFIL", MID_X + 4, -(HEADER_H + 46))
    local esf, ec = CreateScroll(panel, MID_X, LIST_TOP, MID_W, LIST_H)
    entrySF = esf
    entryContent = ec

    VerticalSeparator(panel, DETAIL_X - PAD - 1)
    Label(panel, "FICHE D'IMPORT", DETAIL_X + 4, -(HEADER_H + 46))

    local iconFrame = CreateFrame("Frame", nil, panel)
    iconFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 70))
    iconFrame:SetSize(40, 40)
    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetAllPoints()
    iconBg:SetColorTexture(0.08, 0.08, 0.08, 1)
    iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 3, -3)
    iconTex:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -3, 3)

    nameFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameFS:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 8, -2)
    nameFS:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    HUI.ApplyTitle(nameFS)

    metaFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    metaFS:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 8, -22)
    metaFS:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    metaFS:SetJustifyH("LEFT")
    metaFS:SetWordWrap(false)
    HUI.ApplyMutedText(metaFS)

    Label(panel, "Contenu", DETAIL_X, -(HEADER_H + 126))
    bodyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bodyFS:SetPoint("TOPLEFT", panel, "TOPLEFT", DETAIL_X, -(HEADER_H + 144))
    bodyFS:SetSize(DETAIL_W, 220)
    bodyFS:SetJustifyH("LEFT")
    bodyFS:SetJustifyV("TOP")
    bodyFS:SetWordWrap(true)
    HUI.ApplyBodyText(bodyFS)

    importBtn = HUI.CreatePanelButton(panel, 116, 24, "Importer")
    importBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, FOOTER_H + 10)

    Separator(panel, -(H - FOOTER_H - 2))
    statusFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + 4, 14)
    statusFS:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    statusFS:SetJustifyH("LEFT")
    HUI.ApplyMutedText(statusFS)

    wowTab:SetScript("OnClick", function() SetSource("wow") end)
    arcTab:SetScript("OnClick", function() SetSource("arcaneum") end)
    refreshBtn:SetScript("OnClick", function()
        ResetScroll(profileSF)
        ResetScroll(entrySF)
        RefreshAll()
    end)
    importBtn:SetScript("OnClick", ImportSelected)

    return panel
end

function Lib.Open()
    Build()
    selectedSource = SourceAvailable(selectedSource) and selectedSource or "wow"
    ResetScroll(profileSF)
    ResetScroll(entrySF)
    RefreshAll()
    panel:Show()
end

function Lib.Close()
    if panel then panel:Hide() end
end

function Lib.Refresh()
    if panel and panel:IsShown() then RefreshAll() end
end
