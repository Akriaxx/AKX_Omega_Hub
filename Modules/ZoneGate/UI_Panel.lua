-- ============================================================
--  Zone Gate — Panel principal
--  /oche pour ouvrir
--  Colonne gauche : arborescence Zones → Sous-zones. Chaque
--  Sous-zone EST son propre checkpoint (pas de liaison séparée) ;
--  le "+" sur une Zone capture la position courante et en crée
--  une directement dessous.
--  Colonne droite : formulaire contextuel (Zone ou Sous-zone).
-- ============================================================

local ZG = ZoneGate
local UI = OS2.UI

local function MyName() return UnitName("player") or "" end

local PANEL_W  = 700
local PANEL_H  = 760   -- assez haut pour région (points) + action perso + octroi sans se chevaucher
local PAD      = 12
local HEADER_H = 40
local LIST_W   = 220
local ROW_H    = 24

-- ── Panel racine ─────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "ZoneGatePanel", UIParent, "BackdropTemplate")
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
titleText:SetText("Zone Gate")
UI.ApplyTitle(titleText)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sep1 = panel:CreateTexture(nil, "ARTWORK")
sep1:SetPoint("TOPLEFT",  4, -(HEADER_H - 2))
sep1:SetPoint("TOPRIGHT", -4, -(HEADER_H - 2))
sep1:SetHeight(1)
UI.ApplySeparator(sep1)

function panel:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        panel:RefreshAll()
        ZG:MaybeRequestSync()
        self:Show()
    end
end

-- ── État de sélection ──────────────────────────────────────────────────────

panel.selectedZoneId    = nil
panel.selectedSubZoneId = nil
panel.formMode          = nil   -- "zone" | "subzone"

-- ── Colonne gauche : arborescence Zones → Sous-zones ──────────────────────

local zoneHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zoneHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 8))
zoneHeader:SetText("Zones")
UI.ApplyLabel(zoneHeader)

local addZoneBtn = UI.CreateAddButton(panel, function()
    local zone = ZG:CreateZone("Nouvelle zone")
    if zone then
        panel.selectedZoneId = zone.id
        panel.formMode = "zone"
        panel:RefreshAll()
    end
end)
addZoneBtn:SetPoint("LEFT", zoneHeader, "RIGHT", 6, 0)

local zoneScroll = CreateFrame("ScrollFrame", nil, panel)
zoneScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 28))
zoneScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, PAD)
zoneScroll:SetWidth(LIST_W)
zoneScroll:EnableMouseWheel(true)

local zoneContent = CreateFrame("Frame", nil, zoneScroll)
zoneContent:SetWidth(LIST_W)
zoneContent:SetHeight(1)
zoneScroll:SetScrollChild(zoneContent)

zoneScroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = self:GetVerticalScrollRange()
    local cur = self:GetVerticalScroll()
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 24)))
end)

local listSep = panel:CreateTexture(nil, "ARTWORK")
listSep:SetPoint("TOPLEFT",    panel, "TOPLEFT",    PAD + LIST_W + 8, -(HEADER_H + 4))
listSep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + LIST_W + 8, PAD)
listSep:SetWidth(1)
UI.ApplySeparator(listSep, true)

-- ── Rangées de l'arbre (zone ou sous-zone, réutilisées d'un rafraîchissement à l'autre) ──

local rows = {}

local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, zoneContent)
    row:SetSize(LIST_W, ROW_H)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.rowBg))

    local sel = row:CreateTexture(nil, "ARTWORK")
    sel:SetAllPoints()
    sel:SetColorTexture(unpack(UI.colors.rowSelection))
    sel:Hide()
    row.sel = sel

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    row.label = label

    -- "+" pour ajouter un checkpoint (= sous-zone) directement sous CETTE
    -- zone, capturé à la position courante — visible seulement sur une
    -- rangée de type "zone".
    local addBtn = UI.CreateAddButton(row, nil)
    addBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.addBtn = addBtn

    rows[index] = row
    return row
end

local function HideExtraRows(fromIndex)
    for i = fromIndex, #rows do rows[i]:Hide() end
end

function panel:RefreshZoneTree()
    local list = ZG:GetZoneList()
    local i = 0

    for _, zone in ipairs(list) do
        i = i + 1
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", zoneContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:Show()

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetPoint("RIGHT", row.addBtn, "LEFT", -4, 0)
        local zoneKnown = zone.creator == MyName() or ZG:HasLearnedZoneName(zone.id)
        local zoneShown = zoneKnown and zone.name or "Zone inconnue"
        row.label:SetText(zoneShown .. ((zone.creator ~= MyName()) and "  |cff888888(" .. zone.creator .. ")|r" or ""))
        if zoneKnown then UI.ApplyStrongLabel(row.label) else UI.ApplyMutedText(row.label) end
        row.sel:SetShown(panel.formMode == "zone" and panel.selectedZoneId == zone.id)

        row.addBtn:Show()
        row.addBtn:SetShown(zone.creator == MyName())
        row.addBtn:SetScript("OnClick", function()
            local sub = ZG:CreateSubZone(zone.id)
            if sub then
                panel.selectedSubZoneId = sub.id
                panel.formMode = "subzone"
                panel:RefreshAll()
            end
        end)

        row:SetScript("OnClick", function()
            panel.selectedZoneId = zone.id
            panel.formMode = "zone"
            panel:RefreshAll()
        end)

        local subIds = {}
        for sid in pairs(zone.subZones) do table.insert(subIds, sid) end
        table.sort(subIds)

        for _, sid in ipairs(subIds) do
            local sub = zone.subZones[sid]
            i = i + 1
            local subRow = GetRow(i)
            subRow:ClearAllPoints()
            subRow:SetPoint("TOPLEFT", zoneContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
            subRow:Show()
            subRow.addBtn:Hide()

            subRow.label:ClearAllPoints()
            subRow.label:SetPoint("LEFT", subRow, "LEFT", 18, 0)
            subRow.label:SetPoint("RIGHT", subRow, "RIGHT", -6, 0)

            local known = zone.creator == MyName() or ZG:HasLearnedSubZoneName(sub.id)
            local shown = known and sub.name or ZG:MaskText(sub.name)
            if not sub.enabled then shown = shown .. "  |cff88555555(inactif)|r" end
            subRow.label:SetText(shown)
            if known then UI.ApplyBodyText(subRow.label) else UI.ApplyMutedText(subRow.label) end

            subRow.sel:SetShown(panel.formMode == "subzone" and panel.selectedSubZoneId == sid)
            subRow:SetScript("OnClick", function()
                panel.selectedSubZoneId = sid
                panel.formMode = "subzone"
                panel:RefreshAll()
            end)
        end
    end

    HideExtraRows(i + 1)
    zoneContent:SetHeight(math.max(1, i * ROW_H))
end

-- ── Cadre de déblocage (inline, pas une fenêtre à part) ───────────────────
-- Réutilisé par le formulaire Zone (débloque le NOM DE LA ZONE) et
-- Sous-zone (débloque le NOM DE LA SOUS-ZONE) — deux connaissances
-- indépendantes, voir ZG:ResolveBannerText. Le champ se remplit tout seul
-- dès que la cible du joueur change (surveillance de
-- PLAYER_TARGET_CHANGED) — cibler quelqu'un en /raid ou en /groupe (simple
-- clic sur sa frame) suffit, pas besoin de cliquer sur un bouton "utiliser
-- ma cible". Reste éditable à la main.

local grantFrames = {}
local MAX_GRANT_ROWS = 5

-- showList=true : affiche aussi qui a déjà appris, avec un bouton pour
-- révoquer. titleText (optionnel) : précise ce qui se débloque ("le nom de
-- la zone" / "le nom de la sous-zone").
local function BuildGrantFrame(parent, width, showList, titleText)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, showList and 192 or 60)
    frame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    frame:SetBackdropBorderColor(unpack(UI.colors.separatorSoft))

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    title:SetText(titleText or "Débloquer pour :")
    UI.ApplyLabel(title)

    local nameEB = UI.CreateStyledEditBox(frame, 150, 20, false)
    nameEB:SetPoint("LEFT", title, "RIGHT", 8, 0)
    nameEB:SetMaxLetters(24)
    frame.nameEB = nameEB

    local confirmBtn = UI.CreatePanelButton(frame, 80, 20, "Débloquer")
    confirmBtn:SetPoint("LEFT", nameEB, "RIGHT", 8, 0)
    frame.confirmBtn = confirmBtn

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    hint:SetText("(le nom se remplit tout seul selon votre cible)")
    UI.ApplyMutedText(hint)

    if showList then
        local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        listLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -2, -10)
        UI.ApplyLabel(listLabel)
        frame.listLabel = listLabel

        local listRows, anchor = {}, listLabel
        for i = 1, MAX_GRANT_ROWS do
            local row = CreateFrame("Frame", nil, frame)
            row:SetSize(width - 16, 18)
            row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", (i == 1) and 2 or 0, -4)

            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", row, "LEFT", 0, 0)
            UI.ApplyBodyText(fs)
            row.fs = fs

            local revokeBtn = UI.CreatePanelButton(row, 22, 16, "×")
            revokeBtn:SetPoint("LEFT", fs, "RIGHT", 6, 0)
            row.revokeBtn = revokeBtn

            row:Hide()
            listRows[i] = row
            anchor = row
        end
        frame.listRows = listRows
    end

    table.insert(grantFrames, frame)
    return frame
end

-- Rafraîchit la liste "a appris" d'un cadre (uniquement ceux créés avec
-- showList=true). `getListFn(id)` renvoie des entrées {name=..., count=...}
-- (count optionnel), `revokeFn(id, name)` révoque une entrée. Générique pour
-- réutiliser le même cadre côté Sous-zone (ZG:GetGrantedList/RevokeGrant,
-- nom de la sous-zone) et côté Zone (ZG:GetZoneGrantedList/RevokeZoneGrant,
-- nom de la zone) — deux connaissances indépendantes, voir ResolveBannerText.
local function RefreshGrantList(frame, id, getListFn, revokeFn)
    if not frame.listRows then return end
    local list = id and getListFn(id) or {}

    for i = 1, MAX_GRANT_ROWS do
        local row = frame.listRows[i]
        local entry = list[i]
        if entry then
            row.fs:SetText(entry.name .. (entry.count and ("  |cff888888(" .. entry.count .. " sous-zone(s))|r") or ""))
            row.revokeBtn:SetScript("OnClick", function()
                revokeFn(id, entry.name)
                RefreshGrantList(frame, id, getListFn, revokeFn)
            end)
            row:Show()
        else
            row:Hide()
        end
    end

    frame.listLabel:SetText(#list == 0
        and "Ont appris : personne pour l'instant"
        or "Ont appris :")
end

local function GetSubGrantList(id) return ZG:GetGrantedList(id) end
local function RevokeSubGrant(id, name) return ZG:RevokeGrant(id, name) end
local function GetZoneGrantList(id) return ZG:GetZoneGrantedList(id) end
local function RevokeZoneGrantFn(id, name) return ZG:RevokeZoneGrant(id, name) end

local targetWatcher = CreateFrame("Frame")
targetWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
targetWatcher:SetScript("OnEvent", function()
    if not (UnitExists("target") and UnitIsPlayer("target")) then return end
    local name = UnitName("target")
    for _, frame in ipairs(grantFrames) do
        frame.nameEB:SetText(name)
    end
end)

-- ── Colonne droite : formulaires ───────────────────────────────────────────

local form = CreateFrame("Frame", nil, panel)
form:SetPoint("TOPLEFT",     panel, "TOPLEFT",     PAD + LIST_W + 16, -(HEADER_H + 10))
form:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)

local placeholder = form:CreateFontString(nil, "OVERLAY", "GameFontNormal")
placeholder:SetPoint("TOPLEFT", form, "TOPLEFT", 4, -6)
placeholder:SetText("Sélectionnez une Zone ou une Sous-zone à gauche.\n\nCliquez \"+\" en haut pour créer une Zone, puis le\n\"+\" sur une Zone pour y planter un checkpoint\n(sous-zone) à votre position actuelle.")
placeholder:SetJustifyH("LEFT")
UI.ApplyMutedText(placeholder)

-- ── Formulaire Zone ──────────────────────────────────────────────────────

local zoneForm = CreateFrame("Frame", nil, form)
zoneForm:SetAllPoints()

local zfNameEB = UI.CreateStyledEditBox(zoneForm, 260, 22, false)
zfNameEB:SetPoint("TOPLEFT", zoneForm, "TOPLEFT", 4, -4)
zfNameEB:SetMaxLetters(64)
zfNameEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedZoneId then return end
    local zone = ZG:GetZone(panel.selectedZoneId)
    if zone and zone.creator == MyName() then
        zone.name = self:GetText()
        ZG:ScheduleBroadcast()
        panel:RefreshZoneTree()
    end
end)

local zfAuthorFS = zoneForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zfAuthorFS:SetPoint("TOPLEFT", zfNameEB, "BOTTOMLEFT", 2, -8)
UI.ApplyMutedText(zfAuthorFS)

local zfHintFS = zoneForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zfHintFS:SetPoint("TOPLEFT", zfAuthorFS, "BOTTOMLEFT", 0, -10)
zfHintFS:SetText("Utilisez le \"+\" sur cette zone dans la liste de\ngauche pour y planter un checkpoint ici.")
zfHintFS:SetJustifyH("LEFT")
UI.ApplyMutedText(zfHintFS)

local zfGrantFrame = BuildGrantFrame(zoneForm, 400, true, "Débloquer le NOM DE LA ZONE pour :")
zfGrantFrame:SetPoint("TOPLEFT", zfHintFS, "BOTTOMLEFT", -2, -14)
zfGrantFrame.confirmBtn:SetScript("OnClick", function()
    local zone = panel.selectedZoneId and ZG:GetZone(panel.selectedZoneId)
    if not zone then return end
    local target = (zfGrantFrame.nameEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if target == "" then
        OmegaHub.Print("Zone Gate : ciblez un joueur ou tapez un nom.")
        return
    end
    if ZG:SendZoneGrant(zone.id, target) then
        OmegaHub.Print("Zone Gate : nom de la zone débloqué pour " .. target .. ".")
        RefreshGrantList(zfGrantFrame, zone.id, GetZoneGrantList, RevokeZoneGrantFn)
    else
        OmegaHub.Print("Zone Gate : impossible d'envoyer le déblocage (pas en groupe/raid ni en guilde avec lui ?).")
    end
end)

local zfDeleteBtn = UI.CreatePanelButton(zoneForm, 140, 22, "Supprimer la zone")
zfDeleteBtn:SetPoint("TOPLEFT", zfGrantFrame, "BOTTOMLEFT", 2, -10)
zfDeleteBtn:SetScript("OnClick", function()
    if panel.selectedZoneId then
        ZG:RemoveZone(panel.selectedZoneId)
        panel.selectedZoneId = nil
        panel.formMode = nil
        panel:RefreshAll()
    end
end)

-- ── Formulaire Sous-zone (= checkpoint) ────────────────────────────────────

local subForm = CreateFrame("Frame", nil, form)
subForm:SetAllPoints()

local sfZoneFS = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sfZoneFS:SetPoint("TOPLEFT", subForm, "TOPLEFT", 4, -4)
UI.ApplyLabel(sfZoneFS)

local sfNameEB = UI.CreateStyledEditBox(subForm, 220, 22, false)
sfNameEB:SetPoint("TOPLEFT", sfZoneFS, "BOTTOMLEFT", -2, -6)
sfNameEB:SetMaxLetters(64)
sfNameEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedSubZoneId then return end
    local sub, zone = ZG:FindSubZone(panel.selectedSubZoneId)
    if sub and zone and zone.creator == MyName() then
        sub.name = self:GetText()
        ZG:ScheduleBroadcast()
        panel:RefreshZoneTree()
    end
end)

local sfActiveCB, sfActiveLabel = UI.CreateStyledCheckbox(subForm, "Actif")
sfActiveCB:SetPoint("LEFT", sfNameEB, "RIGHT", 16, 0)
sfActiveLabel:SetPoint("LEFT", sfActiveCB, "RIGHT", 4, 0)
sfActiveCB:SetScript("OnClick", function(self)
    if panel.selectedSubZoneId then
        ZG:SetSubZoneEnabled(panel.selectedSubZoneId, self:GetChecked())
        panel:RefreshZoneTree()
    end
end)

local sfStatusFS = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sfStatusFS:SetPoint("TOPLEFT", sfNameEB, "BOTTOMLEFT", 2, -8)

-- Forme : ligne (porte), cercle (village) ou région (N points, zone fermée)
local shapeLineBtn = UI.CreatePanelButton(subForm, 50, 20, "Ligne")
shapeLineBtn:SetPoint("TOPLEFT", sfStatusFS, "BOTTOMLEFT", -2, -10)
local shapeCircleBtn = UI.CreatePanelButton(subForm, 50, 20, "Cercle")
shapeCircleBtn:SetPoint("LEFT", shapeLineBtn, "RIGHT", 4, 0)
local shapeRegionBtn = UI.CreatePanelButton(subForm, 60, 20, "Région")
shapeRegionBtn:SetPoint("LEFT", shapeCircleBtn, "RIGHT", 4, 0)
shapeLineBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        ZG:SetSubZoneShape(panel.selectedSubZoneId, "line")
        panel:RefreshSubZoneForm()
    end
end)
shapeCircleBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        ZG:SetSubZoneShape(panel.selectedSubZoneId, "circle")
        panel:RefreshSubZoneForm()
    end
end)
shapeRegionBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        ZG:SetSubZoneShape(panel.selectedSubZoneId, "polygon")
        panel:RefreshSubZoneForm()
    end
end)

local recaptureBtn = UI.CreatePanelButton(subForm, 150, 22, "Recapturer ma position")
recaptureBtn:SetPoint("TOPLEFT", shapeLineBtn, "BOTTOMLEFT", 0, -10)
recaptureBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        ZG:RecaptureSubZone(panel.selectedSubZoneId)
    end
end)

local cloneBtn = UI.CreatePanelButton(subForm, 80, 22, "Cloner ici")
cloneBtn:SetPoint("LEFT", recaptureBtn, "RIGHT", 8, 0)
cloneBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        local clone = ZG:CloneSubZone(panel.selectedSubZoneId)
        if clone then
            panel.selectedSubZoneId = clone.id
            panel:RefreshAll()
        end
    end
end)

local sfDeleteBtn = UI.CreatePanelButton(subForm, 90, 22, "Supprimer")
sfDeleteBtn:SetPoint("LEFT", cloneBtn, "RIGHT", 8, 0)
sfDeleteBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        ZG:RemoveSubZone(panel.selectedSubZoneId)
        panel.selectedSubZoneId = nil
        panel.formMode = nil
        panel:RefreshAll()
    end
end)

-- Radar + distance + largeur/rayon
local radarRow = CreateFrame("Frame", nil, subForm)
radarRow:SetPoint("TOPLEFT", recaptureBtn, "BOTTOMLEFT", 0, -16)
radarRow:SetSize(1, 192)   -- radar (160) + distance + statut sous le radar

local radar = ZG.CreateRadar(radarRow, function()
    return panel.selectedSubZoneId and ZG:FindSubZone(panel.selectedSubZoneId) or nil
end)
radar:SetPoint("TOPLEFT", radarRow, "TOPLEFT", 0, 0)

local widthLabel = radarRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
widthLabel:SetPoint("TOPLEFT", radar, "TOPRIGHT", 20, 0)
widthLabel:SetText("Largeur du checkpoint")
UI.ApplyLabel(widthLabel)

local widthEB = UI.CreateStyledEditBox(radarRow, 60, 20, false)
widthEB:SetPoint("TOPLEFT", widthLabel, "BOTTOMLEFT", 0, -6)
widthEB:SetMaxLetters(4)

local SLIDER_MIN, SLIDER_MAX = 1, 500

local sliderTrack = CreateFrame("Frame", nil, radarRow)
sliderTrack:SetSize(150, 4)
sliderTrack:SetPoint("TOPLEFT", widthEB, "BOTTOMLEFT", 2, -14)

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
    widthEB:SetText(tostring(value))

    if not silent and panel.selectedSubZoneId then
        ZG:SetSubZoneWidth(panel.selectedSubZoneId, value)
    end
end

sliderHandle:SetScript("OnMouseDown", function()
    sliderHandle:SetScript("OnUpdate", function()
        local x = GetCursorPosition() / UIParent:GetEffectiveScale()
        local left = sliderTrack:GetLeft()
        if not left then return end
        local ratio = math.max(0, math.min(1, (x - left) / sliderTrack:GetWidth()))
        SetSliderValue(SLIDER_MIN + ratio * (SLIDER_MAX - SLIDER_MIN))
    end)
end)
sliderHandle:SetScript("OnMouseUp", function()
    sliderHandle:SetScript("OnUpdate", nil)
end)

widthEB:SetScript("OnEnterPressed", function(self)
    SetSliderValue(tonumber(self:GetText()) or SLIDER_MIN)
    self:ClearFocus()
end)
widthEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- ── Région (shape="polygon") : mêmes emplacements que le bloc largeur/rayon
-- ci-dessus (mutuellement exclusifs — un seul des deux visible à la fois),
-- donc l'ancrage de fwdEnabledCB sur sliderTrack reste valable dans tous les cas.
local regionLabel = radarRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
regionLabel:SetPoint("TOPLEFT", radar, "TOPRIGHT", 20, 0)
regionLabel:SetWidth(160)
regionLabel:SetJustifyH("LEFT")
UI.ApplyLabel(regionLabel)

local addPointBtn = UI.CreatePanelButton(radarRow, 150, 20, "+ Point ici")
addPointBtn:SetPoint("TOPLEFT", regionLabel, "BOTTOMLEFT", 0, -8)
addPointBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId and ZG:AddRegionPoint(panel.selectedSubZoneId) then
        panel:RefreshSubZoneForm()
    end
end)

local undoPointBtn = UI.CreatePanelButton(radarRow, 72, 20, "Annuler pt.")
undoPointBtn:SetPoint("TOPLEFT", addPointBtn, "BOTTOMLEFT", 0, -6)
undoPointBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId and ZG:RemoveLastRegionPoint(panel.selectedSubZoneId) then
        panel:RefreshSubZoneForm()
    end
end)

local clearPointsBtn = UI.CreatePanelButton(radarRow, 72, 20, "Effacer tout")
clearPointsBtn:SetPoint("LEFT", undoPointBtn, "RIGHT", 6, 0)
clearPointsBtn:SetScript("OnClick", function()
    if panel.selectedSubZoneId then
        ZG:ClearRegionPoints(panel.selectedSubZoneId)
        panel:RefreshSubZoneForm()
    end
end)

-- Un seul bouton qui bascule Valider ↔ Modifier selon regionReady.
local finishRegionBtn = UI.CreatePanelButton(radarRow, 150, 20, "Valider la région")
finishRegionBtn:SetPoint("TOPLEFT", undoPointBtn, "BOTTOMLEFT", 0, -6)
finishRegionBtn:SetScript("OnClick", function()
    local id = panel.selectedSubZoneId
    if not id then return end
    local sub = ZG:FindSubZone(id)
    if not sub then return end
    if sub.regionReady then
        ZG:ReopenRegion(id)
    else
        if not ZG:FinishRegion(id) then
            OmegaHub.Print("Zone Gate : il faut au moins 3 points pour fermer une région.")
        end
    end
    panel:RefreshSubZoneForm()
end)

local fwdEnabledCB, fwdEnabledLabel = UI.CreateStyledCheckbox(radarRow, "Bannière en ENTRÉE")
fwdEnabledCB:SetPoint("TOPLEFT", sliderTrack, "BOTTOMLEFT", -2, -16)
fwdEnabledLabel:SetPoint("LEFT", fwdEnabledCB, "RIGHT", 4, 0)
fwdEnabledCB:SetScript("OnClick", function(self)
    if panel.selectedSubZoneId then
        ZG:SetSubZoneDirectionEnabled(panel.selectedSubZoneId, "forward", self:GetChecked())
    end
end)

local backEnabledCB, backEnabledLabel = UI.CreateStyledCheckbox(radarRow, "Bannière en RETOUR")
backEnabledCB:SetPoint("TOPLEFT", fwdEnabledCB, "BOTTOMLEFT", 0, -6)
backEnabledLabel:SetPoint("LEFT", backEnabledCB, "RIGHT", 4, 0)
backEnabledCB:SetScript("OnClick", function(self)
    if panel.selectedSubZoneId then
        ZG:SetSubZoneDirectionEnabled(panel.selectedSubZoneId, "backward", self:GetChecked())
    end
end)

-- ── Action personnalisée au franchissement (aura / commande / message) ────
-- Indépendante de la bannière ci-dessus (ENTRÉE/RETOUR séparés). Le message
-- s'imprime dans le chat local de QUICONQUE franchit. La commande passe par
-- OS2.ModuleRules.ExecuteServerCommand (même mécanique que les règles
-- d'aura de Lantern/Torch — un ID numérique devient ".aura"/".unaura",
-- sinon la commande est envoyée telle quelle en /raid, /g ou /s). S'applique
-- à TOUT joueur qui franchit, y compris une sous-zone créée par quelqu'un
-- d'autre — volontaire (outil MJ : forcer un message/une aura à un joueur
-- sans qu'il ait à autoriser quoi que ce soit), voir RunCrossingAction.
local actionTitle = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
actionTitle:SetPoint("TOPLEFT", radarRow, "BOTTOMLEFT", 2, -12)
actionTitle:SetText("Action personnalisée au franchissement")
UI.ApplyLabel(actionTitle)

local actionMsgLabel = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
actionMsgLabel:SetPoint("TOPLEFT", actionTitle, "BOTTOMLEFT", 0, -8)
actionMsgLabel:SetText("Message local :")
UI.ApplyMutedText(actionMsgLabel)

local actionMsgEB = UI.CreateStyledEditBox(subForm, 260, 20, false)
actionMsgEB:SetPoint("LEFT", actionMsgLabel, "RIGHT", 8, 0)
actionMsgEB:SetMaxLetters(120)
actionMsgEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedSubZoneId then return end
    ZG:SetSubZoneActionMessage(panel.selectedSubZoneId, self:GetText())
end)

local actionCmdLabel = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
actionCmdLabel:SetPoint("TOPLEFT", actionMsgLabel, "BOTTOMLEFT", 0, -8)
actionCmdLabel:SetText("Commande / ID aura :")
UI.ApplyMutedText(actionCmdLabel)

local actionCmdEB = UI.CreateStyledEditBox(subForm, 260, 20, false)
actionCmdEB:SetPoint("LEFT", actionCmdLabel, "RIGHT", 8, 0)
actionCmdEB:SetMaxLetters(120)
actionCmdEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedSubZoneId then return end
    ZG:SetSubZoneActionCommand(panel.selectedSubZoneId, self:GetText())
end)

local actionCmdHint = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
actionCmdHint:SetPoint("TOPLEFT", actionCmdLabel, "BOTTOMLEFT", 0, -4)
actionCmdHint:SetText("(un nombre = ID de sort → aura appliquée/retirée ; sinon la commande part telle quelle en /raid, /g ou /s)")
actionCmdHint:SetJustifyH("LEFT")
UI.ApplyMutedText(actionCmdHint)

local actionFwdCB, actionFwdLabel = UI.CreateStyledCheckbox(subForm, "Action en ENTRÉE")
actionFwdCB:SetPoint("TOPLEFT", actionCmdHint, "BOTTOMLEFT", -2, -8)
actionFwdLabel:SetPoint("LEFT", actionFwdCB, "RIGHT", 4, 0)
actionFwdCB:SetScript("OnClick", function(self)
    if panel.selectedSubZoneId then
        ZG:SetSubZoneActionDirectionEnabled(panel.selectedSubZoneId, "forward", self:GetChecked())
    end
end)

local actionBackCB, actionBackLabel = UI.CreateStyledCheckbox(subForm, "Action en RETOUR")
actionBackCB:SetPoint("LEFT", actionFwdLabel, "RIGHT", 16, 0)
actionBackLabel:SetPoint("LEFT", actionBackCB, "RIGHT", 4, 0)
actionBackCB:SetScript("OnClick", function(self)
    if panel.selectedSubZoneId then
        ZG:SetSubZoneActionDirectionEnabled(panel.selectedSubZoneId, "backward", self:GetChecked())
    end
end)

-- Octroi (uniquement si je suis l'auteur de la zone) — en dessous du radar,
-- pleine largeur (pas coincé dans la colonne étroite à droite du radar).
local sfGrantFrame = BuildGrantFrame(subForm, 400, true, "Débloquer le NOM DE LA SOUS-ZONE pour :")
sfGrantFrame:SetPoint("TOPLEFT", actionFwdCB, "BOTTOMLEFT", -2, -14)
sfGrantFrame.confirmBtn:SetScript("OnClick", function()
    local sub = panel.selectedSubZoneId and ZG:FindSubZone(panel.selectedSubZoneId)
    if not sub then return end
    local target = (sfGrantFrame.nameEB:GetText() or ""):match("^%s*(.-)%s*$") or ""
    if target == "" then
        OmegaHub.Print("Zone Gate : ciblez un joueur ou tapez un nom.")
        return
    end
    if ZG:SendSubZoneGrant(sub.id, target) then
        OmegaHub.Print("Zone Gate : nom de la sous-zone débloqué pour " .. target .. ".")
        RefreshGrantList(sfGrantFrame, sub.id, GetSubGrantList, RevokeSubGrant)
    else
        OmegaHub.Print("Zone Gate : impossible d'envoyer le déblocage (pas en groupe/raid ni en guilde avec lui ?).")
    end
end)

function panel:RefreshSubZoneForm()
    local sub, zone = ZG:FindSubZone(panel.selectedSubZoneId)
    if not sub or not zone then return end

    local mine = zone.creator == MyName()

    local subKnownForDisplay = mine or ZG:HasLearnedSubZoneName(sub.id)
    sfZoneFS:SetText("Zone : " .. (mine and zone.name or ZG:ResolveBannerText(sub, zone)))
    panel.suppressEvents = true
    sfNameEB:SetText(subKnownForDisplay and (sub.name or "") or ZG:MaskText(sub.name))
    panel.suppressEvents = false

    sfActiveCB:SetChecked(sub.enabled)

    if mine then
        sfStatusFS:SetText("|cff66e673Vous êtes l'auteur — texte toujours visible pour vous.|r")
    else
        local title, subtitle = ZG:ResolveBannerText(sub, zone)
        local zoneKnown = ZG:HasLearnedZoneName(zone.id)
        local subKnown  = ZG:HasLearnedSubZoneName(sub.id)
        local state
        if zoneKnown and subKnown then
            state = "|cff66e673Vous connaissez le nom de la zone ET de la sous-zone.|r"
        elseif zoneKnown then
            state = "|cffe6c94dVous connaissez le nom de la zone seulement.|r"
        elseif subKnown then
            state = "|cffe6c94dVous connaissez le nom de la sous-zone seulement.|r"
        else
            state = "|cff888888Rien appris encore.|r"
        end
        sfStatusFS:SetText(state .. string.format("  |cffffffffAperçu : \"%s\" / \"%s\"|r", title, subtitle))
    end

    local isCircle  = sub.shape == "circle"
    local isPolygon = sub.shape == "polygon"
    shapeLineBtn.accent:SetShown(not isCircle and not isPolygon)
    shapeCircleBtn.accent:SetShown(isCircle)
    shapeRegionBtn.accent:SetShown(isPolygon)

    -- Largeur/rayon (ligne/cercle) et contrôles de région (polygone) occupent
    -- le même emplacement, mutuellement exclusifs.
    widthLabel:SetShown(not isPolygon)
    widthEB:SetShown(not isPolygon)
    sliderTrack:SetShown(not isPolygon)
    sliderHandle:SetShown(not isPolygon)
    if not isPolygon then
        widthLabel:SetText(isCircle and "Rayon du checkpoint" or "Largeur du checkpoint")
        SetSliderValue(sub.width or 6, true)
    end

    regionLabel:SetShown(isPolygon)
    addPointBtn:SetShown(isPolygon and mine)
    undoPointBtn:SetShown(isPolygon and mine)
    clearPointsBtn:SetShown(isPolygon and mine)
    finishRegionBtn:SetShown(isPolygon and mine)
    if isPolygon then
        local n = sub.points and #sub.points or 0
        if sub.regionReady then
            regionLabel:SetText(string.format("|cff66e673Région fermée — %d points.|r", n))
            finishRegionBtn:SetText("Modifier la région")
            addPointBtn:SetShown(false)
            undoPointBtn:SetShown(false)
            clearPointsBtn:SetShown(false)
        elseif n < 3 then
            regionLabel:SetText(string.format("|cffe6c94d%d point(s) — il en faut au moins 3.|r", n))
            finishRegionBtn:SetText("Valider la région")
        else
            regionLabel:SetText(string.format("|cffe6c94d%d points — prêt à valider.|r", n))
            finishRegionBtn:SetText("Valider la région")
        end
    end

    fwdEnabledCB:SetChecked(sub.forwardEnabled)
    backEnabledCB:SetChecked(sub.backwardEnabled)

    -- Recapturer/Cloner déplacent UN point unique (ligne/cercle) — pas de
    -- sens simple pour une région à N points, donc masqués pour "polygon".
    recaptureBtn:SetShown(mine and not isPolygon)
    cloneBtn:SetShown(mine and not isPolygon)
    sfDeleteBtn:SetShown(mine)
    shapeLineBtn:SetShown(mine)
    shapeCircleBtn:SetShown(mine)
    shapeRegionBtn:SetShown(mine)

    -- Action personnalisée : édition réservée à l'auteur (comme le reste de
    -- la configuration du checkpoint).
    actionTitle:SetShown(mine)
    actionMsgLabel:SetShown(mine); actionMsgEB:SetShown(mine)
    actionCmdLabel:SetShown(mine); actionCmdEB:SetShown(mine)
    actionCmdHint:SetShown(mine)
    actionFwdCB:SetShown(mine); actionFwdLabel:SetShown(mine)
    actionBackCB:SetShown(mine); actionBackLabel:SetShown(mine)
    if mine then
        panel.suppressEvents = true
        actionMsgEB:SetText(sub.actionMessage or "")
        actionCmdEB:SetText(sub.actionCommand or "")
        panel.suppressEvents = false
        actionFwdCB:SetChecked(sub.actionForwardEnabled)
        actionBackCB:SetChecked(sub.actionBackwardEnabled)
    end

    sfGrantFrame:SetShown(mine)
    if mine then RefreshGrantList(sfGrantFrame, sub.id, GetSubGrantList, RevokeSubGrant) end
end

-- ── Bascule entre formulaires ──────────────────────────────────────────────

function panel:RefreshForm()
    zoneForm:Hide()
    subForm:Hide()
    placeholder:Hide()

    if panel.formMode == "zone" and panel.selectedZoneId and ZG:GetZone(panel.selectedZoneId) then
        local zone = ZG:GetZone(panel.selectedZoneId)
        local mine = zone.creator == MyName()
        local zoneKnown = mine or ZG:HasLearnedZoneName(zone.id)
        panel.suppressEvents = true
        zfNameEB:SetText(zoneKnown and (zone.name or "") or "Zone inconnue")
        panel.suppressEvents = false
        zfAuthorFS:SetText(mine and "Auteur : vous" or ("Auteur : " .. zone.creator))
        zfHintFS:SetShown(mine)
        zfGrantFrame:SetShown(mine)
        if mine then RefreshGrantList(zfGrantFrame, zone.id, GetZoneGrantList, RevokeZoneGrantFn) end
        zfDeleteBtn:SetShown(mine)
        zoneForm:Show()
    elseif panel.formMode == "subzone" and panel.selectedSubZoneId and ZG:FindSubZone(panel.selectedSubZoneId) then
        panel:RefreshSubZoneForm()
        subForm:Show()
    else
        placeholder:Show()
    end
end

function panel:RefreshAll()
    if panel.selectedZoneId and not ZG:GetZone(panel.selectedZoneId) then panel.selectedZoneId = nil end
    if panel.selectedSubZoneId and not ZG:FindSubZone(panel.selectedSubZoneId) then panel.selectedSubZoneId = nil end

    panel:RefreshZoneTree()
    panel:RefreshForm()
end

panel:RefreshForm()
