-- ============================================================
--  Zone Gate — Panel principal
--  /oche pour ouvrir
--  Colonne gauche : Pays › Régions › Lieux. Un pays ne sert qu'à
--  ranger ; une région porte ses lieux et ses passages ; un lieu
--  porte son nom, sa bannière, ses effets et sa découverte.
--  Colonne droite : fiche du pays, de la région (lieux, passages,
--  bannière et découverte) ou du lieu sélectionné.
-- ============================================================

local ZG = ZoneGate
local UI = ZG.EditorUI or OS2.UI

local function MyName() return UnitName("player") or "" end

local PANEL_W  = 1000
local PANEL_H  = 800
local PAD      = 16
local HEADER_H = 66
local LIST_W   = 264
local ROW_H    = 34
local FORM_W   = PANEL_W - LIST_W - PAD * 2 - 24
local PAGE_Y   = 150   -- haut des pages, sous l'en-tête et les onglets
local M        = 16    -- marge intérieure des fiches
local FIELD_H  = 32

local function Place(control, parent, x, y, w, h)
    control:SetParent(parent); control:ClearAllPoints()
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    if w then control:SetWidth(w) end
    if h then control:SetHeight(h) end
end

local function Caption(parent, text, x, y, w)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    Place(fs, parent, x, y, w); fs:SetText(text); fs:SetJustifyH("LEFT")
    UI.ApplyMutedText(fs); return fs
end

local function Label(parent, text, x, y, w)
    local fs = Caption(parent, text, x, y, w)
    UI.ApplyLabel(fs); return fs
end

local function Button(parent, label, x, y, w, h)
    local b = UI.CreatePanelButton(parent, w, h or FIELD_H, label)
    Place(b, parent, x, y); return b
end

local function EditBox(parent, x, y, w, h, maxLetters)
    local box = UI.CreateStyledEditBox(parent, w, h or FIELD_H, false)
    Place(box, parent, x, y); box:SetMaxLetters(maxLetters or 64)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    return box
end

local function Checkbox(parent, text, x, y)
    local cb, label = UI.CreateStyledCheckbox(parent, text)
    Place(cb, parent, x, y)
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    return cb, label
end

-- Menu déroulant maison (voir UI.CreateSelect) : dd.items() renvoie
-- { {text=, value=, title=} } et dd.onSelect(value) reçoit le choix.
local function Dropdown(parent, x, y, width)
    local dd = UI.CreateSelect(parent, width, FIELD_H)
    Place(dd, parent, x, y)
    return dd
end

local function SetDropdownEnabled(dd, enabled) dd:SetEnabled(enabled) end

-- Filet de séparation entre deux sections d'une fiche.
local function Rule(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", M, -y)
    t:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -M, -y)
    t:SetHeight(1)
    t:SetColorTexture(0.57, 0.46, 0.28, 0.25)
    return t
end

-- ── Panel racine ─────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "ZoneGatePanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetMovable(true)
panel:SetClampedToScreen(true)
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

local function Fit()
    panel:SetScale(math.min(1, (UIParent:GetWidth() - 32) / PANEL_W, (UIParent:GetHeight() - 32) / PANEL_H))
end
panel:HookScript("OnShow", Fit)
panel:RegisterEvent("DISPLAY_SIZE_CHANGED"); panel:SetScript("OnEvent", Fit)
Fit()

-- ── En-tête ──────────────────────────────────────────────────────────────────

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
titleText:SetPoint("TOPLEFT", header, "TOPLEFT", 16, -10)
titleText:SetText("Crossings")
UI.ApplyTitle(titleText)
Caption(header, "Pays, régions, lieux et passages", 16, 34, 400)

local themesBtn = UI.CreatePanelButton(header, 174, 22, "Atelier des bannières")
themesBtn:SetPoint("RIGHT", header, "RIGHT", -30, 0)
themesBtn:SetScript("OnClick", function()
    if ZoneGateThemePanel then ZoneGateThemePanel:Toggle() end
end)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sep1 = panel:CreateTexture(nil, "ARTWORK")
sep1:SetPoint("TOPLEFT",  4, -(HEADER_H - 2))
sep1:SetPoint("TOPRIGHT", -4, -(HEADER_H - 2))
sep1:SetHeight(1)
UI.ApplySeparator(sep1)

-- Au-dessus des caches de la minimap du tracé (voir UI_Radar.lua).
local footer = CreateFrame("Frame", nil, panel)
footer:SetAllPoints(); footer:SetFrameLevel(panel:GetFrameLevel() + 3)
Caption(footer, "Modifications enregistrées automatiquement", PAD, PANEL_H - 26, 380)

function panel:Toggle()
    if self.traceWindow and self.traceWindow:IsShown() then self:ExitTrace(); return end
    if self:IsShown() then
        self:Hide()
    else
        panel:RefreshAll()
        ZG:MaybeRequestSync()
        self:Show()
    end
end

-- ── État de sélection ──────────────────────────────────────────────────────
-- mode : "country" | "zone" | "place" | nil

panel.mode       = nil
panel.countryId  = nil
panel.zoneId     = nil
panel.placeId    = nil
panel.passageId  = nil
panel.zoneTab    = "places"
panel.placeTab   = "banner"

-- Accordéon : pays et régions repliés par défaut, « Sans pays » ouvert.
-- Mémorisé par personnage (ZoneGateCharDB.treeOpen[clé] = true / false).
local function OpenSet()
    ZoneGateCharDB = ZoneGateCharDB or {}
    ZoneGateCharDB.treeOpen = ZoneGateCharDB.treeOpen or {}
    return ZoneGateCharDB.treeOpen
end
local function IsOpen(key)
    local value = OpenSet()[key]
    if key == "loose" then return value ~= false end
    return value == true
end
local function SetOpen(key, open) if key then OpenSet()[key] = open and true or false end end

-- Ouvre les parents d'un élément sélectionné pour qu'il reste visible.
local function Reveal(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return end
    if ZG:GetCountry(zone.countryId) then SetOpen(zone.countryId, true) else SetOpen("loose", true) end
end

local function Select(mode, id, zoneId)
    panel.mode = mode
    if mode == "country" then panel.countryId = id; SetOpen(id, true)
    elseif mode == "zone" then panel.zoneId = id; Reveal(id); SetOpen(id, true)
    elseif mode == "place" then panel.placeId = id; panel.zoneId = zoneId; Reveal(zoneId); SetOpen(zoneId, true) end
    panel:RefreshAll()
end

local function ZoneKnown(zone) return zone.creator == MyName() or ZG:HasLearnedZoneName(zone.id) end
local function PlaceKnown(place, zone) return zone.creator == MyName() or ZG:KnowsPlaceName(place) end
local function ZoneTitle(zone) return ZoneKnown(zone) and (zone.name or "") or "Région inconnue" end
local function PlaceTitle(place, zone) return PlaceKnown(place, zone) and (place.name or "") or ZG:MaskText(place.name) end

-- ── Création : toujours confirmée, avec le nom à saisir ──────────────────
-- Évite de créer des dizaines de régions par des clics accidentels.

local prompt = CreateFrame("Frame", "ZoneGateCreatePrompt", panel)
local AskCreate
do
prompt:SetSize(420, 178); prompt:SetPoint("CENTER"); prompt:SetFrameStrata("DIALOG")
prompt:EnableMouse(true); UI.Surface(prompt); prompt:Hide()
local promptTitle = Label(prompt, "", M, 16, 388)
local promptHint = Caption(prompt, "", M, 38, 388)
local promptName = EditBox(prompt, M, 64, 388)
local promptError = Caption(prompt, "", M, 102, 388)
local promptCancel = Button(prompt, "Annuler", M, 128, 186)
local promptCreate = Button(prompt, "Créer", 218, 128, 186)
promptCancel:SetScript("OnClick", function() prompt:Hide() end)
promptCreate:SetScript("OnClick", function()
    local name = (promptName:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then promptError:SetText("|cffe6c94dDonnez un nom.|r"); return end
    local fn = prompt.onCreate
    prompt:Hide()
    if fn then fn(name) end
end)
promptName:SetScript("OnEnterPressed", function() promptCreate:GetScript("OnClick")(promptCreate) end)
promptName:SetScript("OnEscapePressed", function() prompt:Hide() end)

function AskCreate(title, hint, onCreate)
    promptTitle:SetText(title)
    promptHint:SetText(hint or "")
    promptError:SetText("")
    promptName:SetText("")
    prompt.onCreate = onCreate
    prompt:Show()
    if promptName.SetFocus then promptName:SetFocus() end
end
panel.createPrompt = prompt
end

-- ── Colonne gauche : Pays › Régions › Lieux ──────────────────────────────

Label(panel, "PAYS, RÉGIONS ET LIEUX", PAD, HEADER_H + 14, LIST_W)

local addCountryBtn = Button(panel, "+ Pays", PAD, HEADER_H + 36, (LIST_W - 10) / 2)
addCountryBtn:SetScript("OnClick", function()
    AskCreate("Créer un nouveau pays ?", "Un pays sert à ranger vos régions.", function(name)
        local country = ZG:CreateCountry(name)
        if country then
            if panel.searchBox then panel.searchBox:SetText("") end
            Select("country", country.id)
        end
    end)
end)

-- Nouvelle région : rangée dans le pays sélectionné (ou celui de la région).
local function CurrentCountryId()
    if panel.mode == "country" then return panel.countryId end
    local zone = ZG:GetZone(panel.zoneId)
    if zone and (panel.mode == "zone" or panel.mode == "place") then return zone.countryId end
end

local function CreateRegion(countryId)
    local country = ZG:GetCountry(countryId)
    if country and country.creator ~= MyName() then country = nil end
    AskCreate("Créer une nouvelle région ?", country and ("Dans le pays « " .. country.name .. " ».") or "Sans pays.", function(name)
        local zone = ZG:CreateZone(name, country and country.id or nil)
        if zone then
            panel.zoneTab = "places"
            if panel.searchBox then panel.searchBox:SetText("") end
            Select("zone", zone.id)
        end
    end)
end

local function CreatePlaceIn(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return end
    AskCreate("Créer un nouveau lieu ?", "Dans la région « " .. (zone.name or "") .. " ».", function(name)
        local place = ZG:CreatePlace(zoneId, name)
        if place then panel.placeTab = "banner"; Select("place", place.id, zoneId) end
    end)
end

local addZoneBtn = Button(panel, "+ Région", PAD + (LIST_W + 10) / 2, HEADER_H + 36, (LIST_W - 10) / 2)
addZoneBtn:SetScript("OnClick", function() CreateRegion(CurrentCountryId()) end)

local search = UI.CreateStyledEditBox(panel, LIST_W, FIELD_H, false)
Place(search, panel, PAD, HEADER_H + 80)
local searchHint = Caption(search, "Rechercher un pays, une région, un lieu", 10, 10, LIST_W - 20)
search:SetScript("OnTextChanged", function(self)
    panel.searchText = (self:GetText() or ""):lower()
    searchHint:SetShown(panel.searchText == "")
    panel:RefreshTree()
end)
panel.searchBox = search

local treeScroll = CreateFrame("ScrollFrame", nil, panel)
treeScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 128))
treeScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, 36)
treeScroll:SetWidth(LIST_W)
treeScroll:EnableMouseWheel(true)

local treeContent = CreateFrame("Frame", nil, treeScroll)
treeContent:SetWidth(LIST_W)
treeContent:SetHeight(1)
treeScroll:SetScrollChild(treeContent)

treeScroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, self:GetVerticalScroll() - delta * 24)))
end)

-- Sur son propre cadre, au-dessus des caches du tracé (voir UI_Radar.lua).
local sepHolder = CreateFrame("Frame", nil, panel)
sepHolder:SetAllPoints(); sepHolder:SetFrameLevel(panel:GetFrameLevel() + 3)
local listSep = sepHolder:CreateTexture(nil, "ARTWORK")
listSep:SetPoint("TOPLEFT",    panel, "TOPLEFT",    PAD + LIST_W + 12, -(HEADER_H + 4))
listSep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + LIST_W + 12, PAD)
listSep:SetWidth(1)
UI.ApplySeparator(listSep, true)

local treeRows = {}
local treeEmpty = treeContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
treeEmpty:SetPoint("TOPLEFT", 8, -8); treeEmpty:SetWidth(LIST_W - 16)
treeEmpty:SetJustifyH("LEFT"); UI.ApplyMutedText(treeEmpty)

-- ── Glisser-déposer : une région sur un pays, sur « Sans pays », ou sur une
-- autre région pour la ranger dans le même pays. row.dropCountry : id du pays
-- visé, "" pour aucun, nil si la ligne n'accepte rien.
local ghost = CreateFrame("Frame", nil, UIParent)
ghost:SetSize(LIST_W, 26); ghost:SetFrameStrata("TOOLTIP"); UI.Surface(ghost); ghost:Hide()
local ghostText = Caption(ghost, "", 8, 7, LIST_W - 16)

local function DropTarget()
    for _, row in ipairs(treeRows) do
        if row:IsShown() and row.dropCountry and row:IsMouseOver() then return row end
    end
end

ghost:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x / scale + 14, y / scale - 14)
    local target = DropTarget()
    for _, row in ipairs(treeRows) do row.drop:SetShown(row == target) end
end)

local function StartDrag(row)
    if not row.dragZone then return end
    panel.dragZoneId = row.dragZone
    ghostText:SetText(row.label:GetText())
    ghost:Show()
    panel:RefreshTree()   -- fait apparaître « Sans pays » comme cible
end

local function StopDrag()
    local zoneId = panel.dragZoneId
    if not zoneId then return end
    local target = DropTarget()
    panel.dragZoneId = nil
    ghost:Hide()
    for _, row in ipairs(treeRows) do row.drop:Hide() end
    if target then ZG:SetZoneCountry(zoneId, target.dropCountry ~= "" and target.dropCountry or nil) end
    panel:RefreshAll()
end

-- Apparence de chaque catégorie : hauteur, fond, liseré gauche, texte.
-- Pays : bronze doré ; Sans pays : gris ; région : bleu acier ; lieu : vert.
local TREE_STYLE = {
    country = { h = 38, bg = { 0.110, 0.085, 0.040, 0.95 }, accent = { 0.86, 0.68, 0.30 }, text = { 0.95, 0.80, 0.46 } },
    loose   = { h = 34, bg = { 0.070, 0.070, 0.080, 0.95 }, accent = { 0.48, 0.48, 0.52 }, text = { 0.72, 0.72, 0.75 } },
    zone    = { h = 34, bg = { 0.035, 0.075, 0.105, 0.95 }, accent = { 0.40, 0.64, 0.84 }, text = { 0.82, 0.90, 0.97 } },
    place   = { h = 28, bg = { 0.020, 0.030, 0.040, 0.55 }, dot = { 0.52, 0.82, 0.62 }, text = { 0.84, 0.86, 0.80 } },
    -- Ligne de création : pas de carte, texte vert discret, jamais comptée.
    create  = { h = 28, bg = { 0, 0, 0, 0 }, text = { 0.46, 0.74, 0.50 } },
}
local TREE_GAP   = 10   -- espace entre deux pays (et avant « Sans pays »)
local TREE_NEST  = 12   -- retrait de la carte d'un niveau à l'autre

local function TreeRow(index)
    local row = treeRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, treeContent)
    row:SetSize(LIST_W, ROW_H)

    -- Carte : fond et liseré démarrent au retrait du niveau.
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.accent = row:CreateTexture(nil, "BORDER")
    row.accent:SetWidth(3)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(5, 5)
    -- Filet entre deux éléments du même type.
    row.rule = row:CreateTexture(nil, "BORDER")
    row.rule:SetHeight(1)
    row.rule:SetColorTexture(0.57, 0.46, 0.28, 0.22)

    row.sel = row:CreateTexture(nil, "ARTWORK")
    row.sel:SetColorTexture(unpack(UI.colors.rowSelection))
    row.sel:Hide()

    local hover = row:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints(row.bg)
    hover:SetColorTexture(1, 1, 1, 0.04)

    -- Cible survolée pendant un glisser-déposer.
    row.drop = row:CreateTexture(nil, "ARTWORK")
    row.drop:SetColorTexture(0.90, 0.78, 0.30, 0.25)
    row.drop:Hide()

    -- Clic gauche : action de la ligne ; clic droit : menu contextuel.
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if self.context then UI.OpenContextMenu(self, self.context) end
        elseif self.leftClick then
            self.leftClick()
        end
    end)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", StartDrag)
    row:SetScript("OnDragStop", StopDrag)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    -- Nombre d'enfants (régions d'un pays, lieux d'une région).
    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.count:SetJustifyH("RIGHT")
    UI.ApplyMutedText(row.count)

    -- +/− : déplie ou replie un pays, une région ou « Sans pays ».
    -- Carré sombre au liseré bronze (palette de l'éditeur), distinct du "+" vert de création.
    row.toggle = CreateFrame("Button", nil, row)
    row.toggle:SetSize(16, 16)
    UI.Surface(row.toggle)
    local toggleHover = row.toggle:CreateTexture(nil, "HIGHLIGHT")
    toggleHover:SetAllPoints()
    toggleHover:SetColorTexture(0.90, 0.78, 0.30, 0.18)
    row.toggle.sign = row.toggle:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.toggle.sign:SetPoint("CENTER", 0, 1)
    UI.ApplyLabel(row.toggle.sign)

    -- "+" : une région dans ce pays, ou un lieu dans cette région.
    row.addBtn = UI.CreateAddButton(row, nil)
    row.addBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)

    treeRows[index] = row
    return row
end

-- Met en forme une ligne selon sa catégorie. inset : retrait de la carte.
local function StyleRow(row, kind, inset, ruled)
    local style = TREE_STYLE[kind]
    row:SetHeight(style.h)
    row.bg:ClearAllPoints()
    row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", inset, 0)
    row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.bg:SetColorTexture(unpack(style.bg))
    for _, overlay in ipairs({ row.sel, row.drop }) do
        overlay:ClearAllPoints(); overlay:SetAllPoints(row.bg)
    end
    row.accent:ClearAllPoints()
    row.accent:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 0, 0)
    row.accent:SetPoint("BOTTOMLEFT", row.bg, "BOTTOMLEFT", 0, 0)
    row.accent:SetShown(style.accent ~= nil)
    if style.accent then row.accent:SetColorTexture(style.accent[1], style.accent[2], style.accent[3], 1) end
    row.dot:SetShown(style.dot ~= nil)
    if style.dot then
        row.dot:ClearAllPoints()
        row.dot:SetPoint("LEFT", row.bg, "LEFT", 14, 0)
        row.dot:SetColorTexture(style.dot[1], style.dot[2], style.dot[3], 1)
    end
    row.rule:ClearAllPoints()
    row.rule:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 10, 0)
    row.rule:SetPoint("TOPRIGHT", row.bg, "TOPRIGHT", -10, 0)
    row.rule:SetShown(ruled)
    row.label:SetTextColor(unpack(style.text))
end

local function Matches(text, query)
    return query == "" or ((text or ""):lower():find(query, 1, true) ~= nil)
end

-- Entrées visibles : { kind, depth, country?, zone?, place? }.
local function BuildTree(query)
    local entries = {}
    local searching = query ~= ""
    local function addZone(zone, depth, parentMatched)
        -- Sans recherche, tout s'affiche, y compris les régions au nom encore inconnu.
        local zoneMatched = parentMatched or not searching or (ZoneKnown(zone) and Matches(zone.name, query))
        local places = {}
        for _, place in ipairs(ZG:GetPlaceList(zone.id)) do
            if zoneMatched or (PlaceKnown(place, zone) and Matches(place.name, query)) then places[#places + 1] = place end
        end
        if not zoneMatched and #places == 0 then return end
        local own = zone.creator == MyName()
        local open = searching or IsOpen(zone.id)
        -- Une région à moi se déplie toujours : elle porte au moins « + Nouveau lieu ».
        entries[#entries + 1] = { kind = "zone", zone = zone, depth = depth, key = zone.id, open = open,
            parent = #places > 0 or own, count = #ZG:GetPlaceList(zone.id) }
        if not open then return end
        for _, place in ipairs(places) do
            entries[#entries + 1] = { kind = "place", zone = zone, place = place, depth = depth + 1 }
        end
        if own and not searching then
            entries[#entries + 1] = { kind = "create", what = "place", zone = zone, depth = depth + 1 }
        end
    end

    local countries = ZG:GetCountryList()
    local byCountry, loose = {}, {}
    for _, zone in ipairs(ZG:GetZoneList()) do
        if zone.countryId and ZG:GetCountry(zone.countryId) then
            byCountry[zone.countryId] = byCountry[zone.countryId] or {}
            table.insert(byCountry[zone.countryId], zone)
        else
            loose[#loose + 1] = zone
        end
    end

    for _, country in ipairs(countries) do
        local matched = Matches(country.name, query)
        local start = #entries + 1
        local zones = byCountry[country.id] or {}
        local own = country.creator == MyName()
        local open = searching or IsOpen(country.id)
        entries[start] = { kind = "country", country = country, depth = 0, key = country.id, open = open,
            parent = #zones > 0 or own, count = #zones }
        if open then
            for _, zone in ipairs(zones) do addZone(zone, 1, matched and searching) end
            if own and not searching then
                entries[#entries + 1] = { kind = "create", what = "zone", countryId = country.id, depth = 1 }
            end
        end
        if not matched and #entries == start then entries[start] = nil end
    end

    -- Pendant un glisser-déposer, « Sans pays » reste visible comme cible.
    if #loose > 0 or (panel.dragZoneId and #countries > 0) then
        local depth = 0
        local open = true
        if #countries > 0 then
            open = searching or IsOpen("loose")
            entries[#entries + 1] = { kind = "loose", depth = 0, key = "loose", open = open, parent = #loose > 0, count = #loose }
            depth = 1
        end
        local start = #entries
        if open then
            for _, zone in ipairs(loose) do addZone(zone, depth, false) end
            if depth == 1 and #loose > 0 and not searching then
                entries[#entries + 1] = { kind = "create", what = "zone", depth = 1 }
            end
        end
        if depth == 1 and #entries == start and not panel.dragZoneId and (searching or #loose == 0) then entries[start] = nil end
    end
    return entries
end

-- Lâcher sur une région (ou un de ses lieux) range dans le même pays.
local function ZoneDropCountry(zone)
    local country = ZG:GetCountry(zone.countryId)
    if not country then return "" end
    return country.creator == MyName() and country.id or nil
end

function panel:RefreshTree()
    local query = panel.searchText or ""
    local entries = BuildTree(query)
    local y = 0
    local zonesSeen = {}   -- [groupe] = true : une région a déjà été posée dans ce groupe

    for i, entry in ipairs(entries) do
        local row = TreeRow(i)
        local previous = entries[i - 1]

        -- Respiration entre deux blocs, filet entre deux éléments identiques.
        if (entry.kind == "country" or entry.kind == "loose") and i > 1 then y = y + TREE_GAP end
        local group = entry.zone and (entry.zone.countryId or "loose")
        local ruled = (entry.kind == "zone" and zonesSeen[group])
            or (entry.kind == "place" and previous and previous.kind == "place")
        if entry.kind == "zone" then zonesSeen[group] = true end

        local inset = entry.depth * TREE_NEST
        StyleRow(row, entry.kind, inset, ruled and true or false)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", treeContent, "TOPLEFT", 0, -y)
        row:Show()
        y = y + row:GetHeight()

        local textX = inset + 12
        row.toggle:ClearAllPoints()
        row.toggle:SetPoint("LEFT", row, "LEFT", textX, 0)
        -- Pendant une recherche, tout est déplié : pas de +/−.
        row.toggle:SetShown(entry.parent == true and query == "")
        row.toggle.sign:SetText(entry.open and "−" or "+")
        row.toggle:SetScript("OnClick", function() SetOpen(entry.key, not entry.open); panel:RefreshTree() end)
        if entry.kind == "place" then textX = textX + 14 elseif entry.kind ~= "create" then textX = textX + 24 end

        row.addBtn:Hide()
        row.leftClick, row.context = nil, nil
        row.dragZone, row.dropCountry = nil, nil
        -- En toutes lettres : « 2 régions », « 1 lieu ».
        local n = entry.count or 0
        local noun = entry.kind == "zone" and (n > 1 and "lieux" or "lieu") or (n > 1 and "régions" or "région")
        row.count:SetText(n > 0 and (n .. " " .. noun) or "")

        if entry.kind == "country" then
            local country = entry.country
            local own = country.creator == MyName()
            row.label:SetText(string.upper(country.name or "") .. (own and "" or "  |cff888888(" .. country.creator .. ")|r"))
            row.sel:SetShown(panel.mode == "country" and panel.countryId == country.id)
            row.dropCountry = own and country.id or nil
            row.leftClick = function() Select("country", country.id) end
            if own then
                row.context = {
                    { text = country.name, title = true },
                    { text = "Ouvrir", func = row.leftClick },
                    { text = "Nouvelle région ici", func = function() CreateRegion(country.id) end },
                    { text = "Supprimer le pays…", func = function() panel:DeleteCountry(country.id) end },
                }
            end
        elseif entry.kind == "loose" then
            row.label:SetText("SANS PAYS")
            row.sel:Hide()
            row.dropCountry = ""
            row.leftClick = function() SetOpen("loose", not entry.open); panel:RefreshTree() end
        elseif entry.kind == "zone" then
            local zone = entry.zone
            local own = zone.creator == MyName()
            row.label:SetText(ZoneTitle(zone) .. (own and "" or "  |cff888888(" .. zone.creator .. ")|r"))
            if not ZoneKnown(zone) then row.label:SetTextColor(0.55, 0.55, 0.57) end
            row.sel:SetShown(panel.mode == "zone" and panel.zoneId == zone.id)
            row.leftClick = function() Select("zone", zone.id) end
            row.dragZone = own and zone.id or nil
            row.dropCountry = ZoneDropCountry(zone)
            if own then
                row.context = {
                    { text = zone.name, title = true },
                    { text = "Ouvrir", func = row.leftClick },
                    { text = "Nouveau lieu ici", func = function() CreatePlaceIn(zone.id) end },
                    { text = "Supprimer la région…", func = function() panel:DeleteRegion(zone.id) end },
                }
            end
        elseif entry.kind == "create" then
            row.sel:Hide()
            if entry.what == "zone" then
                row.label:SetText("+  Nouvelle région")
                row.leftClick = function() CreateRegion(entry.countryId) end
            else
                row.label:SetText("+  Nouveau lieu")
                row.leftClick = function() CreatePlaceIn(entry.zone.id) end
            end
        else
            local place, zone = entry.place, entry.zone
            local text = PlaceTitle(place, zone)
            if ZG:IsInPlace(place.id) then text = text .. "  |cff66e673(vous y êtes)|r" end
            row.label:SetText(text)
            if not PlaceKnown(place, zone) then row.label:SetTextColor(0.55, 0.55, 0.57) end
            row.sel:SetShown(panel.mode == "place" and panel.placeId == place.id)
            row.leftClick = function() Select("place", place.id, zone.id) end
            row.dropCountry = ZoneDropCountry(zone)
            if zone.creator == MyName() then
                row.context = {
                    { text = place.name, title = true },
                    { text = "Ouvrir", func = row.leftClick },
                    { text = "Supprimer le lieu…", func = function() panel:DeletePlace(place.id) end },
                }
            end
        end

        row.count:ClearAllPoints()
        row.count:SetPoint("RIGHT", row, "RIGHT", row.addBtn:IsShown() and -32 or -10, 0)
        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", textX, 0)
        row.label:SetPoint("RIGHT", row.count, "LEFT", -8, 0)
    end

    for i = #entries + 1, #treeRows do treeRows[i]:Hide() end
    treeContent:SetHeight(math.max(1, y))
    local empty = #ZG:GetZoneList() == 0 and #ZG:GetCountryList() == 0
    treeEmpty:SetText(empty and "Rien pour l'instant.\nCréez un pays ou une région ci-dessus." or "Aucun résultat.")
    treeEmpty:SetShown(#entries == 0)
    treeScroll:SetVerticalScroll(math.min(treeScroll:GetVerticalScroll(), math.max(0, y - treeScroll:GetHeight())))
end
panel.RefreshZoneTree = panel.RefreshTree

-- ── Cadre de découverte (réutilisé par la région et le lieu) ─────────────

local MAX_GRANT_ROWS = 5

local function BuildGrantFrame(parent, width, titleText)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 232)
    frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.025, 0.038, 0.052, 0.95)
    frame:SetBackdropBorderColor(unpack(UI.colors.separatorSoft))

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    title:SetText(titleText)
    UI.ApplyLabel(title)

    frame.confirmBtn = UI.CreatePanelButton(frame, 220, 26, "Débloquer pour…")
    frame.confirmBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    hint:SetText("Sélectionnez les joueurs du raid, puis validez.")
    UI.ApplyMutedText(hint)

    frame.listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.listLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -2, -10)
    UI.ApplyLabel(frame.listLabel)

    frame.listRows = {}
    local anchor = frame.listLabel
    for i = 1, MAX_GRANT_ROWS do
        local row = CreateFrame("Frame", nil, frame)
        row:SetSize(width - 16, 18)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i == 1) and 2 or 0, -4)
        row.fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.fs:SetPoint("LEFT", row, "LEFT", 0, 0)
        UI.ApplyBodyText(row.fs)
        row:Hide()
        frame.listRows[i] = row
        anchor = row
    end
    return frame
end

local function RefreshGrantList(frame, list)
    for i = 1, MAX_GRANT_ROWS do
        local row, entry = frame.listRows[i], list[i]
        if entry then row.fs:SetText(entry.name); row:Show() else row:Hide() end
    end
    frame.listLabel:SetText(#list == 0
        and "Ont appris : personne pour l'instant"
        or string.format("Ont appris : %d joueur(s)%s", #list, #list > MAX_GRANT_ROWS and " — cinq premiers noms affichés" or ""))
end

-- ── Onglets ──────────────────────────────────────────────────────────────

local function Tabs(parent, entries, getter, setter)
    local tabs, pages = {}, {}
    local w = (FORM_W - 2 * M - (#entries - 1) * 10) / #entries
    for i, entry in ipairs(entries) do
        local key = entry[1]
        local page = CreateFrame("Frame", nil, parent)
        Place(page, parent, 0, PAGE_Y, FORM_W, PANEL_H - HEADER_H - 42 - PAGE_Y)
        pages[key] = page
        local tab = Button(parent, entry[2], M + (i - 1) * (w + 10), 100, w)
        tab:SetScript("OnClick", function() setter(key); panel:RefreshForm() end)
        tabs[key] = tab
    end
    local function show()
        local current = getter()
        for key, page in pairs(pages) do
            page:SetShown(key == current)
            if tabs[key].accent then tabs[key].accent:SetShown(key == current) end
        end
    end
    return pages, tabs, show
end

-- ── Colonne droite ──────────────────────────────────────────────────────────

local form = CreateFrame("Frame", nil, panel)
form:SetPoint("TOPLEFT",     panel, "TOPLEFT",     PAD + LIST_W + 24, -(HEADER_H + 14))
form:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 36)

local placeholder = Caption(form, "VOS PASSAGES ENTRE LIEUX\n\n" ..
    "1. Créez un pays pour ranger vos régions (facultatif), puis une région.\n\n" ..
    "2. Dans la région, créez ses lieux : leur nom, leur bannière et leurs effets.\n\n" ..
    "3. Placez-vous en jeu et posez un passage : choisissez le lieu atteint en entrant et, si vous voulez, celui atteint en sortant.",
    16, 24, FORM_W - 32)

-- Confirmation des suppressions : un second clic explicite.
local confirm = CreateFrame("Frame", "ZoneGateDeleteConfirm", UIParent)
confirm:SetSize(360, 132); confirm:SetPoint("CENTER"); confirm:SetFrameStrata("DIALOG")
confirm:EnableMouse(true); UI.Surface(confirm); confirm:Hide()
local confirmText = Caption(confirm, "", 16, 16, 328)
local cancel = Button(confirm, "Annuler", 16, 86, 146, 28)
local accept = Button(confirm, "Confirmer la suppression", 170, 86, 174, 28)
cancel:SetScript("OnClick", function() confirm:Hide() end)
accept:SetScript("OnClick", function() local fn = confirm.action; confirm:Hide(); if fn then fn() end end)
local function Confirm(text, action)
    confirmText:SetText(text); confirm.action = action; confirm:Show()
end

-- ── Suppressions ──────────────────────────────────────────────────────────

function panel:DeleteCountry(id)
    Confirm("Supprimer ce pays ? Ses régions sont conservées, sans pays.", function()
        ZG:RemoveCountry(id)
        if panel.mode == "country" and panel.countryId == id then panel.mode = nil end
        panel:RefreshAll()
    end)
end

function panel:DeletePlace(id)
    Confirm("Supprimer ce lieu ? Les passages qui y menaient ne mèneront plus nulle part.", function()
        local _, zone = ZG:FindPlace(id)
        ZG:RemovePlace(id)
        if panel.mode == "place" and panel.placeId == id then
            panel.mode = zone and "zone" or nil; panel.zoneTab = "places"
        end
        panel:RefreshAll()
    end)
end

-- Supprimer une région qui a des lieux : un tableau, une ligne par lieu,
-- pour choisir où le ranger (une autre de mes régions) ou ne pas le garder.
-- Rien ne change avant « Exécuter ».
local reassign = CreateFrame("Frame", "ZoneGateRegionDelete", panel)
do
local KEEP_NONE = "Ne pas garder"
local DELETE_ROWS = 7
reassign:SetSize(600, 150 + DELETE_ROWS * 40 + 60); reassign:SetPoint("CENTER")
reassign:SetFrameStrata("DIALOG"); reassign:EnableMouse(true); reassign:EnableMouseWheel(true)
UI.Surface(reassign); reassign:Hide()
local reassignTitle = Label(reassign, "", M, 16, 568)
local reassignHint = Caption(reassign, "", M, 38, 568)
reassignHint:SetHeight(30)
Label(reassign, "Tout affecter à", M, 80, 200)
local reassignAll = Dropdown(reassign, 200, 72, 384)
Rule(reassign, 116)
local reassignRows = {}
for i = 1, DELETE_ROWS do
    local y = 128 + (i - 1) * 40
    local name = Caption(reassign, "", M + 4, y + 9, 170)
    UI.ApplyBodyText(name)
    local choice = Dropdown(reassign, 200, y, 384)
    reassignRows[i] = { name = name, choice = choice }
end
local reassignMore = Caption(reassign, "", M, 128 + DELETE_ROWS * 40, 568)
local reassignCancel = Button(reassign, "Annuler", M, 128 + DELETE_ROWS * 40 + 24, 270)
local reassignRun = Button(reassign, "Exécuter", 600 - M - 270, 128 + DELETE_ROWS * 40 + 24, 270)
reassignCancel:SetScript("OnClick", function() reassign:Hide() end)
panel.reassign = reassign

-- Mes autres régions, cibles possibles.
local function TargetItems(zoneId)
    local items = { { text = KEEP_NONE, value = "" } }
    for _, zone in ipairs(ZG:GetZoneList()) do
        if zone.id ~= zoneId and zone.creator == MyName() then
            local country = ZG:GetCountry(zone.countryId)
            items[#items + 1] = { text = (country and (country.name .. " > ") or "") .. zone.name, value = zone.id }
        end
    end
    return items
end

local function TargetText(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone then return KEEP_NONE end
    local country = ZG:GetCountry(zone.countryId)
    return (country and (country.name .. " > ") or "") .. zone.name
end

function reassign:Render()
    for i, row in ipairs(reassignRows) do
        local place = self.places[i + self.offset]
        row.name:SetShown(place ~= nil); row.choice:SetShown(place ~= nil)
        if place then
            row.name:SetText(place.name or "")
            row.choice:SetText(TargetText(self.targets[place.id]))
            row.choice.items = function() return TargetItems(self.zoneId) end
            row.choice.onSelect = function(value) self.targets[place.id] = value ~= "" and value or nil end
        end
    end
    local total = #self.places
    reassignMore:SetText(total > DELETE_ROWS and string.format("Molette pour faire défiler · %d lieux", total) or "")
end

reassign:SetScript("OnMouseWheel", function(self, delta)
    self.offset = math.max(0, math.min(math.max(0, #self.places - DELETE_ROWS), self.offset - delta))
    self:Render()
end)

reassignAll.onSelect = function(value)
    for _, place in ipairs(reassign.places) do reassign.targets[place.id] = value ~= "" and value or nil end
    reassign:Render()
end

reassignRun:SetScript("OnClick", function()
    local zoneId, targets = reassign.zoneId, reassign.targets
    reassign:Hide()
    for placeId, target in pairs(targets) do ZG:MovePlace(placeId, target) end
    ZG:RemoveZone(zoneId)
    if panel.zoneId == zoneId then panel.mode = nil end
    panel:RefreshAll()
end)

function panel:DeleteRegion(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return end
    local places = ZG:GetPlaceList(zoneId)
    local passages = #ZG:GetPassageList(zoneId)
    if #places == 0 then
        Confirm(string.format("Supprimer la région « %s » et ses %d passage(s) ?", zone.name or "", passages), function()
            ZG:RemoveZone(zoneId)
            if panel.zoneId == zoneId then panel.mode = nil end
            panel:RefreshAll()
        end)
        return
    end
    reassign.zoneId, reassign.places, reassign.targets, reassign.offset = zoneId, places, {}, 0
    reassignTitle:SetText("Supprimer la région « " .. (zone.name or "") .. " »")
    reassignHint:SetText(string.format("Ses %d passage(s) seront supprimés. Choisissez où ranger chaque lieu, ou ne pas le garder, puis « Exécuter ».", passages))
    reassignAll.items = function() return TargetItems(zoneId) end
    reassignAll:SetText("Choisir pour tous les lieux…")
    reassign:Render()
    reassign:Show()
end
end

-- Liste des thèmes pour un menu de bannière.
local function ThemeItems(inherit)
    local items = { { text = inherit, value = "" } }
    for _, theme in ipairs(ZG:GetThemeList()) do items[#items + 1] = { text = theme.name, value = theme.id } end
    return items
end

local function EditTheme(themeId)
    if not ZoneGateThemePanel then return end
    if themeId then ZoneGateThemePanel:EditTheme(themeId) else ZoneGateThemePanel:Toggle() end
end

-- ── Fiche Pays ──────────────────────────────────────────────────────────────

local countryForm = CreateFrame("Frame", nil, form)
countryForm:SetAllPoints()
Label(countryForm, "PAYS", M, 4, FORM_W - 2 * M)
local countryName = EditBox(countryForm, M, 24, FORM_W - 2 * M)
countryName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "country" then return end
    ZG:RenameCountry(panel.countryId, self:GetText())
    panel:RefreshTree()
end)
local countryInfo = Caption(countryForm, "", M + 2, 74, FORM_W - 2 * M)
local countryAdd = Button(countryForm, "+ Nouvelle région dans ce pays", M, 140, 300)
countryAdd:SetScript("OnClick", function() CreateRegion(panel.countryId) end)
local countryDelete = Button(countryForm, "Supprimer le pays", M, 196, 200)
countryDelete:SetScript("OnClick", function() panel:DeleteCountry(panel.countryId) end)

local function RefreshCountryForm()
    local country = ZG:GetCountry(panel.countryId)
    local own = country.creator == MyName()
    panel.suppressEvents = true
    countryName:SetText(country.name or "")
    panel.suppressEvents = false
    countryName:SetEnabled(own)
    local n = 0
    for _, zone in ipairs(ZG:GetZoneList()) do if zone.countryId == country.id then n = n + 1 end end
    countryInfo:SetText(string.format("%d région(s). Un pays sert seulement à ranger vos régions : il n'apparaît pas dans la bannière.\nGlissez une région de la liste de gauche sur un pays pour l'y ranger.%s",
        n, own and "" or "\nAuteur : " .. country.creator))
    countryAdd:SetShown(own)
    countryDelete:SetShown(own)
end

-- ── Fiche Région ────────────────────────────────────────────────────────────

local zoneForm = CreateFrame("Frame", nil, form)
zoneForm:SetAllPoints()
Label(zoneForm, "RÉGION", M, 4, 200)
local zoneName = EditBox(zoneForm, M, 24, FORM_W - 2 * M - 268)
zoneName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "zone" then return end
    ZG:RenameZone(panel.zoneId, self:GetText())
    panel:RefreshTree()
end)
Label(zoneForm, "Pays", FORM_W - M - 252, 4, 252)
local zoneCountry = Dropdown(zoneForm, FORM_W - M - 252, 24, 252)
zoneCountry.items = function()
    local items = { { text = "(Sans pays)", value = "" } }
    for _, country in ipairs(ZG:GetCountryList()) do
        if country.creator == MyName() then items[#items + 1] = { text = country.name, value = country.id } end
    end
    return items
end
zoneCountry.onSelect = function(value)
    ZG:SetZoneCountry(panel.zoneId, value ~= "" and value or nil)
    panel:RefreshTree()
end
local zoneStatus = Caption(zoneForm, "", M + 2, 70, FORM_W - 2 * M)

local zonePages, zoneTabs, ShowZoneTab = Tabs(zoneForm,
    { { "places", "Lieux" }, { "passages", "Passages" }, { "settings", "Bannière et découverte" } },
    function() return panel.zoneTab end, function(key) panel.zoneTab = key end)
panel.zonePages = zonePages

-- Onglet Lieux : la base de données de la région.
local placesPage = zonePages.places
Caption(placesPage, "Chaque lieu porte son nom, sa bannière et ses effets. Les passages de l'onglet suivant y mènent.", M, 0, FORM_W - 2 * M)
local addPlaceBtn = Button(placesPage, "+ Nouveau lieu", M, 30, 220)
addPlaceBtn:SetScript("OnClick", function()
    CreatePlaceIn(panel.zoneId)
end)
local placesEmpty = Caption(placesPage, "Aucun lieu. Créez-en un, par exemple « Le bois des Anciens ».", M, 92, FORM_W - 2 * M)
local placeButtons = {}
local MAX_PLACE_ROWS = 9
for i = 1, MAX_PLACE_ROWS do
    local b = Button(placesPage, "", M, 84 + (i - 1) * 42, FORM_W - 2 * M, 34)
    b:Hide(); placeButtons[i] = b
end
local placesMore = Caption(placesPage, "", M, 84 + MAX_PLACE_ROWS * 42, FORM_W - 2 * M)

-- Onglet Passages : la géométrie et ses deux côtés.
local passagesPage = zonePages.passages
Label(passagesPage, "Passage", M, 0, 200)
local passagePicker = Dropdown(passagesPage, M, 20, 340)
passagePicker.items = function()
    local items = {}
    for _, sub in ipairs(ZG:GetPassageList(panel.zoneId)) do
        items[#items + 1] = { text = (sub.name or "") .. (sub.enabled and "" or " (inactif)"), value = sub.id }
    end
    return items
end
passagePicker.onSelect = function(id) panel.passageId = id; panel:RefreshForm() end
local addPassageBtn = Button(passagesPage, "+ Passage ici", FORM_W - M - 220, 20, 220)
addPassageBtn:SetScript("OnClick", function()
    local zoneId = panel.zoneId
    AskCreate("Poser un nouveau passage ?", "Il sera placé à votre position et orienté selon votre regard.", function(name)
        local places = ZG:GetPlaceList(zoneId)
        local sub = ZG:CreateSubZone(zoneId, name, places[1] and places[1].id or nil)
        if sub then panel.passageId = sub.id; panel:RefreshAll() end
    end)
end)
local passagesEmpty = Caption(passagesPage, "Aucun passage. Placez-vous en jeu à l'endroit voulu, puis « + Passage ici ».\n\n" ..
    "Passage droit : une porte, entrée par le côté vert, sortie par le côté rouge.\nPérimètre libre : un contour, l'intérieur est l'entrée.", M, 84, FORM_W - 2 * M)

Rule(passagesPage, 68)
local editor = CreateFrame("Frame", nil, passagesPage)
Place(editor, passagesPage, 0, 82, FORM_W, 460)
Label(editor, "Nom du passage", M, 0, 280)
local passageName = EditBox(editor, M, 18, 280)
passageName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.passageId then return end
    ZG:RenameSubZone(panel.passageId, self:GetText())
    passagePicker:SetText(self:GetText())
end)
local passageActive = Checkbox(editor, "Actif", M + 296, 25)
passageActive:SetScript("OnClick", function(self)
    if panel.passageId then ZG:SetSubZoneEnabled(panel.passageId, self:GetChecked()) end
end)
Label(editor, "Forme", FORM_W - M - 282, 0, 280)
local shapeLineBtn = Button(editor, "Passage droit", FORM_W - M - 282, 18, 136)
local shapeRegionBtn = Button(editor, "Périmètre libre", FORM_W - M - 136, 18, 136)
shapeLineBtn:SetScript("OnClick", function()
    if panel.passageId then ZG:SetSubZoneShape(panel.passageId, "line"); panel:RefreshForm() end
end)
shapeRegionBtn:SetScript("OnClick", function()
    if not panel.passageId then return end
    ZG:SetSubZoneShape(panel.passageId, "polygon")
    local sub = ZG:FindSubZone(panel.passageId)
    if sub and not sub.regionReady then panel:EnterTrace(sub.id) else panel:RefreshForm() end
end)

-- Lieux proposés : ceux de la région d'abord, puis ceux de mes autres régions.
local function PlaceItems(noneText)
    local items = { { text = noneText, value = "" } }
    for _, place in ipairs(ZG:GetPlaceList(panel.zoneId)) do items[#items + 1] = { text = place.name, value = place.id } end
    for _, zone in ipairs(ZG:GetZoneList()) do
        if zone.id ~= panel.zoneId and zone.creator == MyName() then
            local places = ZG:GetPlaceList(zone.id)
            if #places > 0 then
                items[#items + 1] = { text = zone.name, title = true }
                for _, place in ipairs(places) do
                    items[#items + 1] = { text = zone.name .. " > " .. place.name, value = place.id }
                end
            end
        end
    end
    return items
end

local function PlaceText(placeId, noneText)
    local place, zone = ZG:FindPlace(placeId)
    if not place then return noneText end
    if zone.id == panel.zoneId then return PlaceTitle(place, zone) end
    return ZoneTitle(zone) .. " > " .. PlaceTitle(place, zone)
end

local enterCaption = Label(editor, "", M, 68, FORM_W / 2 - M - 8)
local leaveCaption = Label(editor, "", FORM_W / 2 + 8, 68, FORM_W / 2 - M - 8)
local enterPicker = Dropdown(editor, M, 86, FORM_W / 2 - M - 8)
enterPicker.items = function() return PlaceItems("(Aucun lieu)") end
enterPicker.onSelect = function(value)
    ZG:SetPassagePlace(panel.passageId, "enter", value ~= "" and value or nil); panel:RefreshAll()
end
local leavePicker = Dropdown(editor, FORM_W / 2 + 8, 86, FORM_W / 2 - M - 8)
leavePicker.items = function() return PlaceItems("(Aucun — rien ne s'affiche)") end
leavePicker.onSelect = function(value)
    ZG:SetPassagePlace(panel.passageId, "leave", value ~= "" and value or nil); panel:RefreshAll()
end
panel.pickers = { passage = passagePicker, enter = enterPicker, leave = leavePicker }

local radarRow = CreateFrame("Frame", nil, editor)
Place(radarRow, editor, M, 140, FORM_W - 2 * M, 284)
local radar = ZG.CreatePassageGuide(radarRow, function()
    return panel.mode == "zone" and panel.zoneTab == "passages" and ZG:FindSubZone(panel.passageId) or nil
end)
radar:SetPoint("TOPLEFT", radarRow, "TOPLEFT", 0, 0)

local SIDE_X, SIDE_W = 328, 240
local widthLabel = Label(radarRow, "Largeur du passage", SIDE_X, 0, SIDE_W)
local widthEB = EditBox(radarRow, SIDE_X, 20, 90, FIELD_H, 4)

local SLIDER_MIN, SLIDER_MAX = 1, 500
local sliderTrack = CreateFrame("Frame", nil, radarRow)
Place(sliderTrack, radarRow, SIDE_X + 2, 72, FORM_W - 2 * M - SIDE_X - 8, 4)
local sliderBg = sliderTrack:CreateTexture(nil, "BACKGROUND")
sliderBg:SetAllPoints()
sliderBg:SetColorTexture(0.18, 0.18, 0.18, 1)
local sliderFill = sliderTrack:CreateTexture(nil, "ARTWORK")
sliderFill:SetPoint("LEFT")
sliderFill:SetHeight(4)
sliderFill:SetColorTexture(unpack(UI.colors.panelButtonAccent))
local sliderHandle = CreateFrame("Button", nil, sliderTrack)
sliderHandle:SetSize(14, 14)
sliderHandle:SetPoint("CENTER", sliderTrack, "LEFT", 0, 0)
local sliderHandleTex = sliderHandle:CreateTexture(nil, "OVERLAY")
sliderHandleTex:SetAllPoints()
sliderHandleTex:SetColorTexture(0.90, 0.78, 0.30, 1)

local function SetSliderValue(value, silent)
    value = math.max(SLIDER_MIN, math.min(SLIDER_MAX, math.floor(value + 0.5)))
    local ratio = (value - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
    sliderHandle:SetPoint("CENTER", sliderTrack, "LEFT", ratio * sliderTrack:GetWidth(), 0)
    sliderFill:SetWidth(math.max(0.01, ratio * sliderTrack:GetWidth()))
    panel.suppressEvents = true
    widthEB:SetText(tostring(value))
    panel.suppressEvents = false
    if not silent and panel.passageId then ZG:SetSubZoneWidth(panel.passageId, value) end
end

sliderHandle:SetScript("OnMouseDown", function()
    sliderHandle:SetScript("OnUpdate", function()
        local x = GetCursorPosition() / sliderTrack:GetEffectiveScale()
        local left = sliderTrack:GetLeft()
        if not left then return end
        local ratio = math.max(0, math.min(1, (x - left) / sliderTrack:GetWidth()))
        SetSliderValue(SLIDER_MIN + ratio * (SLIDER_MAX - SLIDER_MIN))
    end)
end)
sliderHandle:SetScript("OnMouseUp", function() sliderHandle:SetScript("OnUpdate", nil) end)
widthEB:SetScript("OnEnterPressed", function(self)
    SetSliderValue(tonumber(self:GetText()) or SLIDER_MIN)
    self:ClearFocus()
end)

-- Périmètre : mêmes emplacements que la largeur (un seul des deux visible).
local regionLabel = Label(radarRow, "", SIDE_X, 0, SIDE_W)
local addPointBtn = Button(radarRow, "+ Point ici", SIDE_X, 22, SIDE_W)
addPointBtn:SetScript("OnClick", function()
    if panel.passageId and ZG:AddRegionPoint(panel.passageId) then panel:RefreshForm() end
end)
local undoPointBtn = Button(radarRow, "Annuler le point", SIDE_X, 62, (SIDE_W - 8) / 2)
undoPointBtn:SetScript("OnClick", function()
    if panel.passageId and ZG:RemoveLastRegionPoint(panel.passageId) then panel:RefreshForm() end
end)
local clearPointsBtn = Button(radarRow, "Effacer tout", SIDE_X + (SIDE_W + 8) / 2, 62, (SIDE_W - 8) / 2)
clearPointsBtn:SetScript("OnClick", function()
    if panel.passageId then ZG:ClearRegionPoints(panel.passageId); panel:RefreshForm() end
end)
local borderBtn = Button(radarRow, "Reprendre une frontière…", SIDE_X, 102, SIDE_W)
local finishRegionBtn = Button(radarRow, "Valider le périmètre", SIDE_X, 142, SIDE_W)
finishRegionBtn:SetScript("OnClick", function()
    local sub = ZG:FindSubZone(panel.passageId)
    if not sub then return end
    if sub.regionReady then
        ZG:ReopenRegion(sub.id)
        panel:EnterTrace(sub.id)
        return
    elseif not ZG:FinishRegion(sub.id) then
        OmegaHub.Print("Crossings : il faut au moins 3 points pour fermer un périmètre.")
    end
    panel:RefreshForm()
end)

-- Nommer un sommet : il devient un point de frontière facile à retrouver.
local vertexLabel = Label(radarRow, "Nommer un sommet", SIDE_X, 186, SIDE_W)
local vertexPicker = Dropdown(radarRow, SIDE_X, 204, 96)
local vertexName = EditBox(radarRow, SIDE_X + 104, 204, SIDE_W - 104, FIELD_H, 40)
vertexPicker.items = function()
    local sub = ZG:FindSubZone(panel.passageId)
    local items = {}
    for i, point in ipairs(sub and sub.points or {}) do
        items[#items + 1] = { text = point.name and (i .. " · " .. point.name) or ("Point " .. i), value = i }
    end
    return items
end
vertexPicker.onSelect = function(index) panel.vertexIndex = index; panel:RefreshForm() end
vertexName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.passageId or not panel.vertexIndex then return end
    ZG:SetRegionPointName(panel.passageId, panel.vertexIndex, self:GetText())
end)

-- Reprendre une frontière : deux points d'un périmètre voisin, recopiés à
-- l'identique à la suite du contour en cours.
local border = CreateFrame("Frame", "ZoneGateBorderPick", UIParent)
do
-- Reprendre une frontière : un périmètre voisin, un point de départ, un point
-- d'arrivée, et le chemin suivi le long de son contour (deux sens possibles).
local BW = 560
border:SetSize(BW, 360); border:SetPoint("CENTER"); border:SetFrameStrata("DIALOG")
border:EnableMouse(true); UI.Surface(border); border:Hide()
border.title = Label(border, "Reprendre une frontière", M, 16, BW - 2 * M)
local hint = Caption(border, "Choisissez un périmètre voisin, puis le tronçon de son contour à reprendre. Ses points sont ajoutés à la suite de votre tracé, aux mêmes coordonnées : les deux zones se touchent sans trou ni chevauchement.", M, 38, BW - 2 * M)
hint:SetHeight(44)
Label(border, "Périmètre voisin", M, 92, BW - 2 * M)
local sourcePick = Dropdown(border, M, 110, BW - 2 * M)
local half = (BW - 2 * M - 16) / 2
Label(border, "Du point", M, 156, half)
local fromPick = Dropdown(border, M, 174, half)
Label(border, "Au point", M + half + 16, 156, half)
local toPick = Dropdown(border, M + half + 16, 174, half)
Label(border, "Chemin", M, 220, BW - 2 * M)
local pathPick = Dropdown(border, M, 238, BW - 2 * M - 140)
-- Partir de l'autre extrémité : même tronçon, parcouru à l'envers.
local flipBtn = Button(border, "Inverser", BW - M - 130, 238, 130)
local info = Caption(border, "", M, 280, BW - 2 * M)
local cancelBtn = Button(border, "Annuler", M, 308, half)
local addBtn = Button(border, "Ajouter", M + half + 16, 308, half)
cancelBtn:SetScript("OnClick", function() border:Hide() end)
panel.borderPick = border

local function PointText(sub, index)
    local point = sub.points[index]
    return point.name and (index .. " · " .. point.name) or ("Point " .. index)
end

-- Aperçu d'un chemin : « 47 > 1 > … > 6 (7 points) » (la police du jeu n'a pas de flèche).
local function PathText(path)
    local shown = {}
    for i, index in ipairs(path) do
        if i <= 3 or i == #path then shown[#shown + 1] = tostring(index)
        elseif i == 4 then shown[#shown + 1] = "…" end
    end
    return table.concat(shown, " > ") .. string.format("  (%d points)", #path)
end

local function Reset(level)
    if level <= 1 then border.from = nil; fromPick:SetText("Choisir…") end
    if level <= 2 then border.to = nil; toPick:SetText("Choisir…") end
    border.forward = nil; pathPick:SetText("Choisir…")
    info:SetText("")
end

sourcePick.items = function()
    local items = {}
    local declared = ZG:GetDeclaredBorders(panel.passageId)
    if #declared > 0 then
        items[#items + 1] = { text = "Frontières déclarées", title = true }
        for _, entry in ipairs(declared) do
            items[#items + 1] = { text = string.format("%s  (%s > %s)", entry.border.name, entry.zone.name or "", entry.sub.name or ""), value = entry }
        end
        items[#items + 1] = { text = "Périmètres entiers", title = true }
    end
    for _, entry in ipairs(ZG:GetBorderSources(panel.passageId)) do
        items[#items + 1] = { text = string.format("%s > %s  (%d points)", entry.zone.name or "", entry.sub.name or "", #entry.sub.points), value = entry.sub }
    end
    if #items == 0 then items[1] = { text = "Aucun autre de vos périmètres dans cette instance", title = true } end
    return items
end
-- Une frontière déclarée préremplit les deux points et le chemin.
sourcePick.onSelect = function(value)
    if value.border then
        local b = value.border
        border.source = value.sub
        Reset(1)
        border.from, border.to = b.from, b.to
        fromPick:SetText(PointText(value.sub, b.from)); toPick:SetText(PointText(value.sub, b.to))
        pathPick.onSelect(b.forward)
        pathPick:SetText(PathText(ZG:BorderPath(value.sub, b.from, b.to, b.forward)))
    else
        border.source = value; Reset(1)
    end
end

local function PointItems(exclude)
    local sub = border.source
    if not sub then return { { text = "Choisissez d'abord le périmètre", title = true } } end
    local items = {}
    for index in ipairs(sub.points) do
        if index ~= exclude then items[#items + 1] = { text = PointText(sub, index), value = index } end
    end
    return items
end
fromPick.items = function() return PointItems(border.to) end
fromPick.onSelect = function(index) border.from = index; border.forward = nil; pathPick:SetText("Choisir…"); info:SetText("") end
toPick.items = function() return PointItems(border.from) end
toPick.onSelect = function(index) border.to = index; border.forward = nil; pathPick:SetText("Choisir…"); info:SetText("") end

pathPick.items = function()
    local sub, from, to = border.source, border.from, border.to
    if not sub or not from or not to then return { { text = "Choisissez d'abord les deux points", title = true } } end
    local items = {}
    for _, forward in ipairs({ true, false }) do
        local path = ZG:BorderPath(sub, from, to, forward)
        if path then items[#items + 1] = { text = PathText(path), value = forward } end
    end
    return items
end
flipBtn:SetScript("OnClick", function()
    if not border.source or not border.from or not border.to then return end
    border.from, border.to = border.to, border.from
    fromPick:SetText(PointText(border.source, border.from)); toPick:SetText(PointText(border.source, border.to))
    if border.forward ~= nil then
        pathPick.onSelect(not border.forward)
        pathPick:SetText(PathText(ZG:BorderPath(border.source, border.from, border.to, border.forward)))
    end
end)
pathPick.onSelect = function(forward)
    border.forward = forward
    local path = ZG:BorderPath(border.source, border.from, border.to, forward)
    addBtn:SetText(path and string.format("Ajouter %d points", #path) or "Ajouter")
end

addBtn:SetScript("OnClick", function()
    if not border.source or not border.from or not border.to or border.forward == nil then
        info:SetText("|cffe6c94dChoisissez le périmètre, les deux points et le chemin.|r"); return
    end
    if ZG:AddBorderPath(panel.passageId, border.source.id, border.from, border.to, border.forward) then
        border:Hide()
        panel:RefreshForm()
        if panel.traceWindow and panel.traceWindow:IsShown() then panel.traceWindow.Refresh() end
    else
        info:SetText("|cffe6c94dImpossible d'ajouter ce tronçon (autre instance ou limite atteinte).|r")
    end
end)

borderBtn:SetScript("OnClick", function()
    -- Contour vide : la frontière reprise devient le début du tracé (son premier point = point 1).
    local current = ZG:FindSubZone(panel.passageId)
    border.title:SetText((current and current.points and #current.points == 0) and "Partir d'une frontière" or "Reprendre une frontière")
    border.source = nil
    sourcePick:SetText("Choisir…"); addBtn:SetText("Ajouter")
    Reset(1)
    local sources = ZG:GetBorderSources(panel.passageId)
    if #sources == 0 then
        info:SetText("Aucun autre de vos périmètres dans cette instance pour l'instant.")
    elseif #sources == 1 then
        sourcePick.onSelect(sources[1].sub)
        sourcePick:SetText(sourcePick.items()[1].text)
    end
    border:Show()
end)
end


-- Déclarer une frontière : un tronçon nommé de son propre contour, que les
-- périmètres voisins reprendront ensuite (même sans voisin pour l'instant).
local declare = CreateFrame("Frame", "ZoneGateBorderDeclare", UIParent)
do
-- Frontières de ce contour : en déclarer une nouvelle, ou modifier / supprimer
-- une frontière existante (choisie dans le premier menu).
local DW = 560
declare:SetSize(DW, 420); declare:SetPoint("CENTER"); declare:SetFrameStrata("DIALOG")
declare:EnableMouse(true); UI.Surface(declare); declare:Hide()
Label(declare, "Frontières de ce contour", M, 16, DW - 2 * M)
local hint = Caption(declare, "Nommez un tronçon de ce contour. Les périmètres voisins pourront le reprendre à l'identique avec « Reprendre une frontière… ».", M, 38, DW - 2 * M)
hint:SetHeight(30)
Label(declare, "Frontière", M, 76, DW - 2 * M)
local borderPick = Dropdown(declare, M, 94, DW - 2 * M - 140)
local deleteBtn = Button(declare, "Supprimer", DW - M - 130, 94, 130)
Label(declare, "Nom", M, 140, DW - 2 * M)
local nameBox = EditBox(declare, M, 158, DW - 2 * M, FIELD_H, 40)
local half = (DW - 2 * M - 16) / 2
Label(declare, "Du point", M, 202, half)
local fromPick = Dropdown(declare, M, 220, half)
Label(declare, "Au point", M + half + 16, 202, half)
local toPick = Dropdown(declare, M + half + 16, 220, half)
Label(declare, "Chemin", M, 266, DW - 2 * M)
local pathPick = Dropdown(declare, M, 284, DW - 2 * M)
local info = Caption(declare, "", M, 330, DW - 2 * M)
local cancelBtn = Button(declare, "Fermer", M, 364, half)
local okBtn = Button(declare, "Déclarer", M + half + 16, 364, half)
cancelBtn:SetScript("OnClick", function() declare:Hide() end)
panel.borderDeclare = declare

local NEW = "Nouvelle frontière"
local function Sub() return ZG:FindSubZone(panel.passageId) end
local function PointText(sub, index)
    local point = sub.points[index]
    return point.name and (index .. " · " .. point.name) or ("Point " .. index)
end
local function PathText(path)
    local shown = {}
    for i, index in ipairs(path) do
        if i <= 3 or i == #path then shown[#shown + 1] = tostring(index) elseif i == 4 then shown[#shown + 1] = "…" end
    end
    return table.concat(shown, " > ") .. string.format("  (%d points)", #path)
end
local function PointItems(exclude)
    local sub, items = Sub(), {}
    for index in ipairs(sub and sub.points or {}) do
        if index ~= exclude then items[#items + 1] = { text = PointText(sub, index), value = index } end
    end
    return items
end

-- Charge une frontière existante (index) dans le formulaire, ou le vide (nil).
local function Load(index)
    local sub = Sub()
    local b = index and sub and sub.borders and sub.borders[index]
    declare.editing = b and index or nil
    declare.from, declare.to, declare.forward = b and b.from, b and b.to, b and b.forward
    nameBox:SetText(b and b.name or "")
    borderPick:SetText(b and b.name or NEW)
    fromPick:SetText(b and PointText(sub, b.from) or "Choisir…")
    toPick:SetText(b and PointText(sub, b.to) or "Choisir…")
    local path = b and ZG:BorderPath(sub, b.from, b.to, b.forward)
    pathPick:SetText(path and PathText(path) or "Choisir…")
    okBtn:SetText(b and "Enregistrer" or "Déclarer")
    deleteBtn:SetShown(b ~= nil)
    info:SetText("")
end

borderPick.items = function()
    local items = { { text = NEW, value = 0 } }
    local sub = Sub()
    for index, b in ipairs(sub and sub.borders or {}) do
        items[#items + 1] = { text = string.format("%s  (%d > %d)", b.name, b.from, b.to), value = index }
    end
    return items
end
borderPick.onSelect = function(index) Load(index ~= 0 and index or nil) end

fromPick.items = function() return PointItems(declare.to) end
fromPick.onSelect = function(index) declare.from, declare.forward = index, nil; pathPick:SetText("Choisir…") end
toPick.items = function() return PointItems(declare.from) end
toPick.onSelect = function(index) declare.to, declare.forward = index, nil; pathPick:SetText("Choisir…") end
pathPick.items = function()
    local sub = Sub()
    if not sub or not declare.from or not declare.to then return { { text = "Choisissez d'abord les deux points", title = true } } end
    local items = {}
    for _, forward in ipairs({ true, false }) do
        local path = ZG:BorderPath(sub, declare.from, declare.to, forward)
        if path then items[#items + 1] = { text = PathText(path), value = forward } end
    end
    return items
end
pathPick.onSelect = function(forward) declare.forward = forward end

local function Done()
    if panel.traceWindow and panel.traceWindow:IsShown() then panel.traceWindow.Refresh() end
end

okBtn:SetScript("OnClick", function()
    local name = (nameBox:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if name == "" or not declare.from or not declare.to or declare.forward == nil then
        info:SetText("|cffe6c94dDonnez un nom, les deux points et le chemin.|r"); return
    end
    local ok
    if declare.editing then
        ok = ZG:UpdateBorder(panel.passageId, declare.editing, name, declare.from, declare.to, declare.forward)
    else
        ok = ZG:DeclareBorder(panel.passageId, name, declare.from, declare.to, declare.forward)
    end
    if ok then
        declare:Hide(); Done()
    else
        info:SetText("|cffe6c94dCe tronçon n'existe pas sur ce contour.|r")
    end
end)

deleteBtn:SetScript("OnClick", function()
    if not declare.editing then return end
    ZG:RemoveBorder(panel.passageId, declare.editing)
    Load(nil); Done()
    info:SetText("Frontière supprimée.")
end)

function panel:OpenDeclareBorder()
    Load(nil)
    declare:Show()
end
end

-- ── Fenêtre de tracé : pendant la construction d'un périmètre, seuls le
-- tracé et ses commandes restent à l'écran, jusqu'à « Valider le périmètre ».
do
-- Marges larges autour du tracé : la minimap qui pivote déborde du cadre
-- et ses caches doivent rester dans la fenêtre.
local W, H = 598, 352
local X, CW = 342, 240
local trace = CreateFrame("Frame", "ZoneGateTraceWindow", UIParent)
trace:SetSize(W, H); trace:SetFrameStrata("HIGH"); trace:SetClampedToScreen(true)
trace:SetMovable(true); trace:EnableMouse(true); trace:RegisterForDrag("LeftButton")
trace:SetScript("OnDragStart", trace.StartMoving)
trace:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ZoneGateCharDB = ZoneGateCharDB or {}
    ZoneGateCharDB.tracePos = { point, relPoint, x, y }
end)
UI.Surface(trace); trace:Hide()
-- Même teinte que les caches de la minimap : aucune démarcation visible.
if trace.surfaceBg then trace.surfaceBg:SetColorTexture(unpack(ZG.RadarCoverColor)) end
-- Contenu au-dessus de la minimap et de ses caches.
local content = CreateFrame("Frame", nil, trace)
content:SetAllPoints(); content:SetFrameLevel(trace:GetFrameLevel() + 3)
trace.content = content
local title = Label(content, "", M, 20, 380)
local back = Button(content, "Panneau complet", W - M - 150, 14, 150, 26)
local guide = ZG.CreatePassageGuide(content, function() return ZG:FindSubZone(panel.tracingId) end)
guide:SetPoint("TOPLEFT", content, "TOPLEFT", 26, -46)
local count = Label(content, "", X, 50, CW)
local add = Button(content, "+ Point ici", X, 74, CW)
local undo = Button(content, "Annuler le point", X, 114, (CW - 8) / 2)
local clear = Button(content, "Effacer tout", X + (CW + 8) / 2, 114, (CW - 8) / 2)
local borderPick = Button(content, "Reprendre une frontière…", X, 154, CW)
local declareBtn = Button(content, "Gérer les frontières…", X, 252, CW)
declareBtn:SetScript("OnClick", function() panel:OpenDeclareBorder() end)
local finish = Button(content, "Valider le périmètre", X, 292, CW, 38)

local function Refresh()
    local sub = ZG:FindSubZone(panel.tracingId)
    if not sub then return end
    title:SetText("TRACÉ DU PÉRIMÈTRE  ·  " .. string.upper(sub.name or ""))
    local n = sub.points and #sub.points or 0
    count:SetText(string.format(n < 3 and "|cffe6c94d%d point(s) — il en faut au moins 3.|r" or "|cffe6c94d%d points — prêt à valider.|r", n))
end
trace.Refresh = Refresh

add:SetScript("OnClick", function()
    if ZG:AddRegionPoint(panel.tracingId) then Refresh() end
end)
undo:SetScript("OnClick", function()
    if ZG:RemoveLastRegionPoint(panel.tracingId) then Refresh() end
end)
clear:SetScript("OnClick", function()
    local sub = ZG:FindSubZone(panel.tracingId)
    local n = sub and sub.points and #sub.points or 0
    if n == 0 then return end
    Confirm(string.format("Effacer les %d points de ce périmètre ?", n), function()
        ZG:ClearRegionPoints(panel.tracingId); Refresh()
    end)
end)
borderPick:SetScript("OnClick", function() borderBtn:GetScript("OnClick")(borderBtn) end)
finish:SetScript("OnClick", function()
    if ZG:FinishRegion(panel.tracingId) then
        panel:ExitTrace()
    else
        count:SetText("|cffe6c94dIl faut au moins 3 points pour fermer le périmètre.|r")
    end
end)
back:SetScript("OnClick", function() panel:ExitTrace() end)

function panel:EnterTrace(id)
    local sub = ZG:FindSubZone(id)
    if not sub or sub.shape ~= "polygon" then return end
    panel.tracingId, panel.passageId = id, id
    panel:Hide()   -- libère la minimap du tracé du panneau avant de la prendre ici
    trace:ClearAllPoints()
    local pos = ZoneGateCharDB and ZoneGateCharDB.tracePos
    if pos then trace:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4]) else trace:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 180) end
    Refresh()
    trace:Show()
    -- Contour vide et frontières déclarées à proximité : on propose d'en partir.
    if #(sub.points or {}) == 0 and #ZG:GetDeclaredBorders(id) > 0 then
        borderPick:GetScript("OnClick")(borderPick)
    end
end

function panel:ExitTrace()
    trace:Hide()
    local sub, zone = ZG:FindSubZone(panel.tracingId)
    panel.tracingId = nil
    if sub then panel.mode, panel.zoneId, panel.zoneTab, panel.passageId = "zone", zone.id, "passages", sub.id end
    panel:RefreshAll()
    panel:Show()
end
panel.traceWindow = trace
end

-- Dans le panneau complet, un périmètre en cours se reprend dans la fenêtre de tracé.
local traceBtn = Button(radarRow, "Reprendre le tracé", SIDE_X, 22, SIDE_W)
traceBtn:SetScript("OnClick", function() panel:EnterTrace(panel.passageId) end)
-- Déclarer une frontière ne touche pas à la géométrie : inutile de rouvrir le périmètre.
local declareBorderBtn = Button(radarRow, "Gérer les frontières…", SIDE_X, 102, SIDE_W)
declareBorderBtn:SetScript("OnClick", function() panel:OpenDeclareBorder() end)

local recaptureBtn = Button(radarRow, "Déplacer à ma position", SIDE_X, 168, SIDE_W)
recaptureBtn:SetScript("OnClick", function()
    if panel.passageId then ZG:RecaptureSubZone(panel.passageId) end
end)
local cloneBtn = Button(radarRow, "Dupliquer ici", SIDE_X, 210, SIDE_W)
cloneBtn:SetScript("OnClick", function()
    local clone = panel.passageId and ZG:CloneSubZone(panel.passageId)
    if clone then panel.passageId = clone.id; panel:RefreshAll() end
end)
local deletePassageBtn = Button(radarRow, "Supprimer le passage", SIDE_X, 252, SIDE_W)
deletePassageBtn:SetScript("OnClick", function()
    local id = panel.passageId
    Confirm("Supprimer ce passage ? Les lieux sont conservés.", function()
        ZG:RemoveSubZone(id); panel.passageId = nil; panel:RefreshAll()
    end)
end)

-- Onglet Bannière et découverte de la région.
local settingsPage = zonePages.settings
Label(settingsPage, "Bannière par défaut des lieux", M, 0, FORM_W - 2 * M)
local zoneTheme = Dropdown(settingsPage, M, 20, FORM_W - 2 * M - 130)
zoneTheme.items = function() return ThemeItems("(Thème par défaut)") end
zoneTheme.onSelect = function(value) ZG:SetZoneTheme(panel.zoneId, value) end
local zoneEditTheme = Button(settingsPage, "Éditer", FORM_W - M - 116, 20, 116)
zoneEditTheme:SetScript("OnClick", function()
    local zone = ZG:GetZone(panel.zoneId)
    if zone then EditTheme(zone.themeId) end
end)
Rule(settingsPage, 72)
local zoneGrant = BuildGrantFrame(settingsPage, FORM_W - 2 * M, "Révéler le nom de la région")
Place(zoneGrant, settingsPage, M, 88, FORM_W - 2 * M)
zoneGrant.confirmBtn:SetScript("OnClick", function()
    local id = panel.zoneId
    ZG:OpenDiscoveryPicker("zone", id, function() RefreshGrantList(zoneGrant, ZG:GetZoneGrantedList(id)) end)
end)
local zoneDelete = Button(settingsPage, "Supprimer la région", M, 350, 220)
zoneDelete:SetScript("OnClick", function() panel:DeleteRegion(panel.zoneId) end)

local function RefreshPassageEditor(zone, own)
    local passages = ZG:GetPassageList(zone.id)
    local sub = ZG:FindSubZone(panel.passageId)
    if not sub or not zone.subZones[sub.id] then
        sub = passages[1]
        panel.passageId = sub and sub.id or nil
    end
    addPassageBtn:SetShown(own)
    passagePicker:SetShown(sub ~= nil)
    passagesEmpty:SetShown(sub == nil)
    editor:SetShown(sub ~= nil)
    if not sub then return end

    passagePicker:SetText(sub.name or "")
    panel.suppressEvents = true
    passageName:SetText(sub.name or "")
    panel.suppressEvents = false
    passageName:SetEnabled(own)
    passageActive:SetChecked(sub.enabled)
    passageActive:SetEnabled(own)

    local isPolygon = sub.shape == "polygon"
    shapeLineBtn.accent:SetShown(not isPolygon)
    shapeRegionBtn.accent:SetShown(isPolygon)
    shapeLineBtn:SetShown(own); shapeRegionBtn:SetShown(own)

    enterCaption:SetText(isPolygon and "À l'intérieur, on entre dans :" or "En entrant (côté vert), on arrive à :")
    leaveCaption:SetText(isPolygon and "En sortant, on arrive à :" or "En sortant (côté rouge), on arrive à :")
    enterPicker:SetText(PlaceText(sub.enterPlace, "(Aucun lieu)"))
    leavePicker:SetText(PlaceText(sub.leavePlace, "(Aucun — rien ne s'affiche)"))
    SetDropdownEnabled(enterPicker, own); SetDropdownEnabled(leavePicker, own)
    -- Périmètre : ce qu'on trouve en sortant dépend du périmètre voisin (frontière).
    leaveCaption:SetShown(not isPolygon); leavePicker:SetShown(not isPolygon)

    widthLabel:SetShown(not isPolygon); widthEB:SetShown(not isPolygon)
    sliderTrack:SetShown(not isPolygon); sliderHandle:SetShown(not isPolygon)
    widthEB:SetEnabled(own); sliderHandle:EnableMouse(own)
    if not isPolygon then SetSliderValue(sub.width or 6, true) end

    regionLabel:SetShown(isPolygon)
    local editing = isPolygon and own and not sub.regionReady
    addPointBtn:Hide(); undoPointBtn:Hide(); clearPointsBtn:Hide(); borderBtn:Hide()
    traceBtn:SetShown(editing)
    declareBorderBtn:SetShown(isPolygon and own and sub.points ~= nil and #sub.points >= 3)
    finishRegionBtn:SetShown(isPolygon and own)
    -- Nommer un sommet : possible même périmètre fermé (la géométrie ne change pas).
    local count = isPolygon and sub.points and #sub.points or 0
    local naming = isPolygon and own and count > 0
    vertexLabel:SetShown(naming); vertexPicker:SetShown(naming); vertexName:SetShown(naming)
    if naming then
        if not panel.vertexIndex or panel.vertexIndex > count or panel.vertexPassage ~= sub.id then
            panel.vertexIndex, panel.vertexPassage = count, sub.id
        end
        local point = sub.points[panel.vertexIndex]
        vertexPicker:SetText("Point " .. panel.vertexIndex)
        panel.suppressEvents = true
        vertexName:SetText(point.name or "")
        panel.suppressEvents = false
    end
    if isPolygon then
        local n = sub.points and #sub.points or 0
        if sub.regionReady then
            regionLabel:SetText(string.format("|cff66e673Périmètre fermé — %d points.|r", n))
            finishRegionBtn:SetText("Modifier le périmètre")
        else
            regionLabel:SetText(string.format(n < 3 and "|cffe6c94d%d point(s) — il en faut au moins 3.|r" or "|cffe6c94d%d points — prêt à valider.|r", n))
            finishRegionBtn:SetText("Valider le périmètre")
        end
    end

    -- Déplacer / dupliquer n'ont de sens que pour un passage droit (UN point).
    recaptureBtn:SetShown(own and not isPolygon)
    cloneBtn:SetShown(own and not isPolygon)
    deletePassageBtn:SetShown(own)
end

local function RefreshZoneForm()
    local zone = ZG:GetZone(panel.zoneId)
    local own = zone.creator == MyName()
    panel.suppressEvents = true
    zoneName:SetText(ZoneTitle(zone))
    panel.suppressEvents = false
    zoneName:SetEnabled(own)
    local country = ZG:GetCountry(zone.countryId)
    zoneCountry:SetText(country and country.name or "(Sans pays)")
    SetDropdownEnabled(zoneCountry, own)
    local places, passages = ZG:GetPlaceList(zone.id), ZG:GetPassageList(zone.id)
    zoneStatus:SetText(string.format("%s · %d lieu(x) · %d passage(s)",
        own and "|cff66e673Vous êtes l'auteur|r" or ("Auteur : " .. zone.creator), #places, #passages))

    -- Lieux
    addPlaceBtn:SetShown(own)
    placesEmpty:SetShown(#places == 0)
    for i, b in ipairs(placeButtons) do
        local place = places[i]
        b:SetShown(place ~= nil)
        if place then
            local count = #ZG:GetPlacePassages(place.id)
            b:SetText(PlaceTitle(place, zone) .. string.format("   |cff888888· %d passage(s)|r", count))
            b:SetScript("OnClick", function() Select("place", place.id, zone.id) end)
        end
    end
    placesMore:SetText(#places > MAX_PLACE_ROWS and string.format("… et %d autre(s) : voir la liste à gauche.", #places - MAX_PLACE_ROWS) or "")

    RefreshPassageEditor(zone, own)

    -- Bannière et découverte
    local theme = zone.themeId and ZG:GetTheme(zone.themeId)
    zoneTheme:SetText(theme and theme.name or "(Thème par défaut)")
    SetDropdownEnabled(zoneTheme, own)
    zoneEditTheme:SetShown(own)
    zoneGrant:SetShown(own)
    if own then RefreshGrantList(zoneGrant, ZG:GetZoneGrantedList(zone.id)) end
    zoneDelete:SetShown(own)
    ShowZoneTab()
end

-- ── Fiche Lieu ──────────────────────────────────────────────────────────────

local placeForm = CreateFrame("Frame", nil, form)
placeForm:SetAllPoints()
local placeHeader = Label(placeForm, "", M, 4, FORM_W - 2 * M)
local placeName = EditBox(placeForm, M, 24, FORM_W - 2 * M)
placeName:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "place" then return end
    ZG:RenamePlace(panel.placeId, self:GetText())
    panel:RefreshTree()
end)
local placeStatus = Caption(placeForm, "", M + 2, 70, FORM_W - 2 * M)

local placePages, placeTabs, ShowPlaceTab = Tabs(placeForm,
    { { "banner", "Bannière" }, { "effects", "Effets" }, { "arcanum", "Sort Arcanum" }, { "discovery", "Découverte" } },
    function() return panel.placeTab end, function(key) panel.placeTab = key end)
panel.placePages = placePages

-- Bannière
local bannerPage = placePages.banner
Label(bannerPage, "Bannière de ce lieu", M, 0, FORM_W - 2 * M)
local placeTheme = Dropdown(bannerPage, M, 20, FORM_W - 2 * M - 130)
placeTheme.items = function() return ThemeItems("(Bannière de la région)") end
placeTheme.onSelect = function(value) ZG:SetPlaceTheme(panel.placeId, value) end
local placeEditTheme = Button(bannerPage, "Éditer", FORM_W - M - 116, 20, 116)
placeEditTheme:SetScript("OnClick", function()
    local place = ZG:FindPlace(panel.placeId)
    if place then EditTheme(place.themeId) end
end)
Caption(bannerPage, "Quand un passage mène ici, la bannière affiche « Région / Lieu ».", M, 64, FORM_W - 2 * M)
Rule(bannerPage, 94)
Label(bannerPage, "Passages qui mènent ici", M, 110, FORM_W - 2 * M)
local linkLines = {}
for i = 1, 8 do linkLines[i] = Caption(bannerPage, "", M + 2, 110 + i * 24, FORM_W - 2 * M) end
local placeDelete = Button(bannerPage, "Supprimer le lieu", M, 350, 220)
placeDelete:SetScript("OnClick", function() panel:DeletePlace(panel.placeId) end)

-- Effets
local effectsPage = placePages.effects
Label(effectsPage, "Action quand le joueur arrive ou part", M, 0, FORM_W - 2 * M)
local actionMsgLabel = Caption(effectsPage, "Message local", M, 36, FORM_W - 2 * M)
local actionMsg = EditBox(effectsPage, M, 54, FORM_W - 2 * M, FIELD_H, 120)
actionMsg:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "place" then return end
    ZG:SetPlaceActionMessage(panel.placeId, self:GetText())
end)
local actionCmdLabel = Caption(effectsPage, "Commande ou ID d'aura", M, 104, FORM_W - 2 * M)
local actionCmd = EditBox(effectsPage, M, 122, FORM_W - 2 * M, FIELD_H, 120)
actionCmd:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or panel.mode ~= "place" then return end
    ZG:SetPlaceActionCommand(panel.placeId, self:GetText())
end)
local actionHint = Caption(effectsPage, "Un nombre applique l'aura à l'arrivée et la retire au départ. Une commande est envoyée dans le canal de groupe disponible.", M, 164, FORM_W - 2 * M)
actionHint:SetHeight(30)
Rule(effectsPage, 206)
local actionEnter, actionEnterLabel = Checkbox(effectsPage, "À l'arrivée dans le lieu", M, 222)
actionEnter:SetScript("OnClick", function(self) ZG:SetPlaceActionEnabled(panel.placeId, "enter", self:GetChecked()) end)
local actionLeave, actionLeaveLabel = Checkbox(effectsPage, "Au départ du lieu", FORM_W / 2, 222)
actionLeave:SetScript("OnClick", function(self) ZG:SetPlaceActionEnabled(panel.placeId, "leave", self:GetChecked()) end)
local effectsReadOnly = Caption(effectsPage, "Réglé par l'auteur de la région.", M, 36, FORM_W - 2 * M)

-- Sort Arcanum : lancé en arrivant dans le lieu, défait en le quittant.
local arcPage = placePages.arcanum
local arc = {}
arc.intro = Caption(arcPage, "Lance un sort Arcanum tant que le joueur est dans ce lieu, quel que soit le passage emprunté. En le quittant, le sort de sortie défait l'effet — ciel, brouillard, aura…", M, 0, FORM_W - 2 * M)
arc.intro:SetHeight(40)
arc.readOnly = Caption(arcPage, "Réglé par l'auteur de la région.", M, 60, FORM_W - 2 * M)
local function ArcSpellField(y, label, which)
    local field = {}
    field.caption = Caption(arcPage, label, M, y, FORM_W - 2 * M)
    field.box = EditBox(arcPage, M, y + 18, FORM_W - 2 * M - 130, FIELD_H, 80)
    field.test = Button(arcPage, "Tester", FORM_W - M - 116, y + 18, 116)
    field.status = Caption(arcPage, "", M, y + 56, FORM_W - 2 * M)
    field.box:SetScript("OnTextChanged", function(self)
        if panel.suppressEvents or panel.mode ~= "place" then return end
        ZG:SetPlaceArcSpell(panel.placeId, which, self:GetText())
        panel:RefreshArcStatus()
    end)
    field.test:SetScript("OnClick", function()
        local place = ZG:FindPlace(panel.placeId)
        if place then ZG:CastArcSpell(field.box:GetText(), place.arcVault) end
    end)
    return field
end
arc.enter = ArcSpellField(56, "Sort à l'arrivée (ArcSpell ID)", "enter")
arc.exit = ArcSpellField(140, "Sort au départ — retire l'effet (facultatif)", "exit")
arc.rule = Rule(arcPage, 222)
arc.phaseCB, arc.phaseLabel = Checkbox(arcPage, "Coffre de phase (recommandé : disponible pour tous les joueurs de la phase)", M, 238)
arc.phaseCB:SetScript("OnClick", function(self)
    ZG:SetPlaceArcVault(panel.placeId, self:GetChecked() and "phase" or "personal")
    panel:RefreshArcStatus()
end)
arc.toggleCB, arc.toggleLabel = Checkbox(arcPage, "Le joueur peut retirer puis remettre l'effet sur place", M, 272)
arc.toggleCB:SetScript("OnClick", function(self) ZG:SetPlaceArcToggle(panel.placeId, self:GetChecked()) end)
arc.hint = Caption(arcPage, "Un sort du coffre personnel n'existe que chez vous : les autres joueurs ne le recevront pas. Au départ, le sort d'arrivée encore en cours est interrompu avant le sort de départ. Sans sort de départ, l'effet suit sa propre durée.", M, 314, FORM_W - 2 * M)
arc.hint:SetHeight(58)

local function ArcStatusText(commID, vault)
    commID = (commID or ""):match("^%s*(.-)%s*$") or ""
    if commID == "" then return "" end
    if type(ARC) ~= "table" then return "|cffe6c94dArcanum n'est pas chargé.|r" end
    local spell = ZG:FindArcSpell(commID, vault)
    if spell then return "|cff66e673Trouvé : " .. (spell.fullName or commID) .. "|r" end
    return "|cffe6c94dIntrouvable dans le coffre " .. (vault == "personal" and "personnel" or "de phase") .. ".|r"
end

function panel:RefreshArcStatus()
    local place = ZG:FindPlace(self.placeId)
    if not place then return end
    arc.enter.status:SetText(ArcStatusText(place.arcEnterSpell, place.arcVault))
    arc.exit.status:SetText(ArcStatusText(place.arcExitSpell, place.arcVault))
end

-- Découverte
local discoveryPage = placePages.discovery
local placeGrant = BuildGrantFrame(discoveryPage, FORM_W - 2 * M, "Révéler le nom du lieu")
Place(placeGrant, discoveryPage, M, 0, FORM_W - 2 * M)
placeGrant.confirmBtn:SetScript("OnClick", function()
    local id = panel.placeId
    ZG:OpenDiscoveryPicker("place", id, function() RefreshGrantList(placeGrant, ZG:GetPlaceGrantedList(id)) end)
end)
Caption(discoveryPage, "Le nom de la région et celui du lieu se révèlent séparément. Les autres joueurs voient des noms masqués tant qu'ils ne les ont pas appris.", M, 250, FORM_W - 2 * M)

local function RefreshPlaceForm()
    local place, zone = ZG:FindPlace(panel.placeId)
    local own = zone.creator == MyName()
    placeHeader:SetText("LIEU · " .. ZoneTitle(zone))
    panel.suppressEvents = true
    placeName:SetText(PlaceTitle(place, zone))
    panel.suppressEvents = false
    placeName:SetEnabled(own)
    local links = ZG:GetPlacePassages(place.id)
    placeStatus:SetText(string.format("%s · atteint par %d passage(s)%s",
        own and "|cff66e673Vous êtes l'auteur|r" or ("Auteur : " .. zone.creator), #links,
        ZG:IsInPlace(place.id) and " · |cff66e673vous y êtes|r" or ""))

    local theme = place.themeId and ZG:GetTheme(place.themeId)
    placeTheme:SetText(theme and theme.name or "(Bannière de la région)")
    SetDropdownEnabled(placeTheme, own)
    placeEditTheme:SetShown(own)
    for i, line in ipairs(linkLines) do
        local link = links[i]
        if link then
            line:SetText(string.format("%s  |cff888888(%s) — %s|r", link.sub.name or "", ZoneTitle(link.zone),
                link.which == "enter" and "en entrant" or "en sortant"))
        else
            line:SetText(i == 1 and "Aucun pour l'instant : choisissez ce lieu dans l'onglet Passages de la région." or "")
        end
    end
    placeDelete:SetShown(own)

    for _, control in ipairs({ actionMsgLabel, actionCmdLabel, actionHint, actionMsg, actionCmd, actionEnter, actionEnterLabel, actionLeave, actionLeaveLabel }) do control:SetShown(own) end
    effectsReadOnly:SetShown(not own)
    if own then
        panel.suppressEvents = true
        actionMsg:SetText(place.actionMessage or "")
        actionCmd:SetText(place.actionCommand or "")
        panel.suppressEvents = false
        actionEnter:SetChecked(place.actionEnterEnabled)
        actionLeave:SetChecked(place.actionLeaveEnabled)
    end

    for _, field in ipairs({ arc.enter, arc.exit }) do
        for _, control in pairs(field) do control:SetShown(own) end
    end
    for _, control in ipairs({ arc.rule, arc.phaseCB, arc.phaseLabel, arc.toggleCB, arc.toggleLabel, arc.hint }) do control:SetShown(own) end
    arc.readOnly:SetShown(not own)
    if own then
        panel.suppressEvents = true
        arc.enter.box:SetText(place.arcEnterSpell or "")
        arc.exit.box:SetText(place.arcExitSpell or "")
        panel.suppressEvents = false
        arc.phaseCB:SetChecked(place.arcVault ~= "personal")
        arc.toggleCB:SetChecked(place.arcToggle ~= false)
        panel:RefreshArcStatus()
    end

    placeGrant:SetShown(own)
    if own then RefreshGrantList(placeGrant, ZG:GetPlaceGrantedList(place.id)) end
    ShowPlaceTab()
end

-- ── Bascule entre fiches ──────────────────────────────────────────────────

function panel:RefreshForm()
    countryForm:Hide(); zoneForm:Hide(); placeForm:Hide(); placeholder:Hide()
    if self.mode == "country" and ZG:GetCountry(self.countryId) then
        RefreshCountryForm(); countryForm:Show()
    elseif self.mode == "zone" and ZG:GetZone(self.zoneId) then
        RefreshZoneForm(); zoneForm:Show()
    elseif self.mode == "place" and ZG:FindPlace(self.placeId) then
        RefreshPlaceForm(); placeForm:Show()
    else
        placeholder:Show()
    end
end

function panel:RefreshAll()
    if self.mode == "country" and not ZG:GetCountry(self.countryId) then self.mode = nil end
    if self.mode == "zone" and not ZG:GetZone(self.zoneId) then self.mode = nil end
    if self.mode == "place" then
        local place, zone = ZG:FindPlace(self.placeId)
        if not place then self.mode = nil else self.zoneId = zone.id end
    end
    self:RefreshTree()
    self:RefreshForm()
end

panel:HookScript("OnHide", function()
    confirm:Hide(); prompt:Hide(); reassign:Hide(); border:Hide(); sliderHandle:SetScript("OnUpdate", nil)
    panel.dragZoneId = nil; ghost:Hide()
end)
UISpecialFrames = UISpecialFrames or {}
table.insert(UISpecialFrames, "ZoneGatePanel")
table.insert(UISpecialFrames, "ZoneGateDeleteConfirm")
table.insert(UISpecialFrames, "ZoneGateCreatePrompt")
table.insert(UISpecialFrames, "ZoneGateRegionDelete")
table.insert(UISpecialFrames, "ZoneGateBorderPick")
table.insert(UISpecialFrames, "ZoneGateBorderDeclare")
panel:RefreshForm()
