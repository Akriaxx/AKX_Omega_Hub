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
local UI = ZG.EditorUI or OS2.UI

local function MyName() return UnitName("player") or "" end

local PANEL_W  = 860
local PANEL_H  = 700
local PAD      = 12
local HEADER_H = 66
local LIST_W   = 248
local ROW_H    = 32

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
titleText:SetText("Crossings")
UI.ApplyTitle(titleText)

local themesBtn = UI.CreatePanelButton(header, 150, 22, "Atelier des entrées")
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
zoneHeader:SetText("RÉGIONS ET CHECKPOINTS")
UI.ApplyLabel(zoneHeader)

local addZoneBtn = UI.CreatePanelButton(panel, LIST_W, 28, "+ Créer une région")
addZoneBtn:SetScript("OnClick", function()
    local zone = ZG:CreateZone("Nouvelle région")
    if zone then
        panel.selectedZoneId = zone.id
        panel.formMode = "zone"
        if panel.searchBox then panel.searchBox:SetText("") end
        panel:RefreshAll()
    end
end)
addZoneBtn:SetPoint("TOPLEFT",panel,"TOPLEFT",PAD,-(HEADER_H+28))

local zoneScroll = CreateFrame("ScrollFrame", nil, panel)
zoneScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 100))
zoneScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, 32)
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
local treeEmpty=zoneContent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
treeEmpty:SetPoint("TOPLEFT",8,-8);treeEmpty:SetWidth(LIST_W-16)
treeEmpty:SetJustifyH("LEFT");UI.ApplyMutedText(treeEmpty)

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
    label:SetWordWrap(false)
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
        local query=panel.searchText or ""
        local known=zone.creator==MyName() or ZG:HasLearnedZoneName(zone.id)
        local display=known and zone.name or "Région inconnue"
        local matches=query=="" or display:lower():find(query,1,true)
        if not matches then
            for _,sub in pairs(zone.subZones) do
                local subKnown=zone.creator==MyName() or ZG:HasLearnedSubZoneName(sub.id)
                if subKnown and sub.name:lower():find(query,1,true) then matches=true;break end
            end
        end
        if matches then
        i = i + 1
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", zoneContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:Show()

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 6, 0)
        row.label:SetPoint("RIGHT", row.addBtn, "LEFT", -4, 0)
        local zoneKnown = zone.creator == MyName() or ZG:HasLearnedZoneName(zone.id)
        local zoneShown = zoneKnown and zone.name or "Région inconnue"
        row.label:SetText(zoneShown .. ((zone.creator ~= MyName()) and "  |cff888888(" .. zone.creator .. ")|r" or ""))
        if zoneKnown then UI.ApplyStrongLabel(row.label) else UI.ApplyMutedText(row.label) end
        row.sel:SetShown(panel.formMode == "zone" and panel.selectedZoneId == zone.id)

        row.addBtn:Show()
        row.addBtn:SetShown(zone.creator == MyName())
        row.addBtn:SetScript("OnClick", function()
            local sub = ZG:CreateSubZone(zone.id)
            if sub then
                panel.selectedZoneId = zone.id
                panel.selectedSubZoneId = sub.id
                panel.checkpointTab = "placement"
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
            if not sub.enabled then shown = shown .. "  |cffaa7777(inactif)|r" end
            subRow.label:SetText(shown)
            if known then UI.ApplyBodyText(subRow.label) else UI.ApplyMutedText(subRow.label) end

            subRow.sel:SetShown(panel.formMode == "subzone" and panel.selectedSubZoneId == sid)
            subRow:SetScript("OnClick", function()
                panel.selectedZoneId = zone.id
                panel.selectedSubZoneId = sid
                panel.formMode = "subzone"
                panel:RefreshAll()
            end)
        end
        end
    end

    HideExtraRows(i + 1)
    zoneContent:SetHeight(math.max(1, i * ROW_H))
    treeEmpty:SetText(#list==0 and "Aucune région.\nCréez votre première région ci-dessus." or "Aucun résultat.")
    treeEmpty:SetShown(i==0)
    zoneScroll:SetVerticalScroll(math.min(zoneScroll:GetVerticalScroll(),math.max(0,i*ROW_H-zoneScroll:GetHeight())))
end

-- ── Cadre de déblocage (inline, pas une fenêtre à part) ───────────────────
-- Réutilisé par le formulaire Zone (débloque le NOM DE LA ZONE) et
-- Sous-zone (débloque le NOM DE LA SOUS-ZONE) — deux connaissances
-- indépendantes, voir ZG:ResolveBannerText. Le champ se remplit tout seul
-- dès que la cible du joueur change (surveillance de
-- PLAYER_TARGET_CHANGED) — cibler quelqu'un en /raid ou en /groupe (simple
-- clic sur sa frame) suffit, pas besoin de cliquer sur un bouton "utiliser
-- ma cible". Reste éditable à la main.

local MAX_GRANT_ROWS = 5

-- showList=true : affiche aussi qui a déjà appris, avec un bouton pour
-- révoquer. titleText (optionnel) : précise ce qui se débloque ("le nom de
-- la zone" / "le nom du checkpoint").
local function BuildGrantFrame(parent, width, showList, titleText)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, showList and 232 or 98)
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
    title:SetText(titleText or "Débloquer pour :")
    UI.ApplyLabel(title)

    local confirmBtn = UI.CreatePanelButton(frame, 220, 26, "Débloquer pour…")
    confirmBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -32)
    frame.confirmBtn = confirmBtn

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -68)
    hint:SetText("Sélectionnez les joueurs du raid, puis validez.")
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

            row:Hide()
            listRows[i] = row
            anchor = row
        end
        frame.listRows = listRows
    end

    return frame
end

-- Rafraîchit la liste "a appris" d'un cadre (uniquement ceux créés avec
-- showList=true). `getListFn(id)` renvoie des entrées {name=..., count=...}
-- (count optionnel), `revokeFn(id, name)` révoque une entrée. Générique pour
-- réutiliser le même cadre côté Sous-zone (ZG:GetGrantedList/RevokeGrant,
-- nom du checkpoint) et côté Zone (ZG:GetZoneGrantedList/RevokeZoneGrant,
-- nom de la région) — deux connaissances indépendantes, voir ResolveBannerText.
local function RefreshGrantList(frame, id, getListFn, revokeFn)
    if not frame.listRows then return end
    local list = id and getListFn(id) or {}

    for i = 1, MAX_GRANT_ROWS do
        local row = frame.listRows[i]
        local entry = list[i]
        if entry then
            row.fs:SetText(entry.name .. (entry.count and ("  |cff888888(" .. entry.count .. " checkpoint(s))|r") or ""))
            row:Show()
        else
            row:Hide()
        end
    end

    frame.listLabel:SetText(#list == 0
        and "Ont appris : personne pour l'instant"
        or string.format("Ont appris : %d joueur(s)%s",#list,#list>MAX_GRANT_ROWS and " — cinq premiers noms affichés" or ""))
end

local function GetSubGrantList(id) return ZG:GetGrantedList(id) end
local function RevokeSubGrant(id, name) return ZG:RevokeGrant(id, name) end
local function GetZoneGrantList(id) return ZG:GetZoneGrantedList(id) end
local function RevokeZoneGrantFn(id, name) return ZG:RevokeZoneGrant(id, name) end

-- ── Colonne droite : formulaires ───────────────────────────────────────────

local form = CreateFrame("Frame", nil, panel)
form:SetPoint("TOPLEFT",     panel, "TOPLEFT",     PAD + LIST_W + 16, -(HEADER_H + 10))
form:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 32)

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

-- Thème hérité par TOUTES les Sous-zones de cette Zone qui n'ont rien
-- choisi elles-mêmes (voir ZG:ResolveTheme). "" = thème par défaut.
local zfThemeLabel = zoneForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zfThemeLabel:SetPoint("TOPLEFT", zfAuthorFS, "BOTTOMLEFT", -2, -12)
zfThemeLabel:SetText("Thème (hérité par les sous-zones) :")
UI.ApplyLabel(zfThemeLabel)

local zfThemeDropdown = CreateFrame("Frame", "ZoneGateZoneThemeDropdown", zoneForm, "UIDropDownMenuTemplate")
zfThemeDropdown:SetPoint("TOPLEFT", zfThemeLabel, "BOTTOMLEFT", -16, -4)
UIDropDownMenu_SetWidth(zfThemeDropdown, 200)
UI.StyleDropdown(zfThemeDropdown)

local zfEditThemeBtn = UI.CreatePanelButton(zoneForm, 60, 22, "Éditer")
zfEditThemeBtn:SetPoint("LEFT", zfThemeDropdown, "RIGHT", 26, 2)
zfEditThemeBtn:SetScript("OnClick", function()
    local zone = panel.selectedZoneId and ZG:GetZone(panel.selectedZoneId)
    if zone and ZoneGateThemePanel then
        if zone.themeId then ZoneGateThemePanel:EditTheme(zone.themeId)
        else ZoneGateThemePanel:Toggle() end
    end
end)

UIDropDownMenu_Initialize(zfThemeDropdown, function(self, level)
    local zone = panel.selectedZoneId and ZG:GetZone(panel.selectedZoneId)
    if not zone then return end

    local info = UIDropDownMenu_CreateInfo()
    info.text = "(Thème par défaut)"
    info.notCheckable = true
    info.func = function()
        ZG:SetZoneTheme(zone.id, "")
        UIDropDownMenu_SetText(zfThemeDropdown, "(Thème par défaut)")
    end
    UIDropDownMenu_AddButton(info, level)

    for _, theme in ipairs(ZG:GetThemeList()) do
        local themeInfo = UIDropDownMenu_CreateInfo()
        themeInfo.text = theme.name
        themeInfo.notCheckable = true
        themeInfo.func = function()
            ZG:SetZoneTheme(zone.id, theme.id)
            UIDropDownMenu_SetText(zfThemeDropdown, theme.name)
        end
        UIDropDownMenu_AddButton(themeInfo, level)
    end
end)

local zfHintFS = zoneForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
zfHintFS:SetPoint("TOPLEFT", zfThemeDropdown, "BOTTOMLEFT", 16, -12)
zfHintFS:SetText("Utilisez le \"+\" sur cette zone dans la liste de\ngauche pour y planter un checkpoint ici.")
zfHintFS:SetJustifyH("LEFT")
UI.ApplyMutedText(zfHintFS)

local zfGrantFrame = BuildGrantFrame(zoneForm, 400, true, "Révéler le nom de la région")
zfGrantFrame:SetPoint("TOPLEFT", zfHintFS, "BOTTOMLEFT", -2, -14)
zfGrantFrame.confirmBtn:SetScript("OnClick", function()
    local id=panel.selectedZoneId
    ZG:OpenDiscoveryPicker("zone",id,function()
        RefreshGrantList(zfGrantFrame,id,GetZoneGrantList,RevokeZoneGrantFn)
    end)
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

-- Thème de CETTE sous-zone précisément : l'emporte sur celui de la Zone si
-- choisi (voir ZG:ResolveTheme). "" = hérite du thème de la Zone.
local sfThemeLabel = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sfThemeLabel:SetPoint("TOPLEFT", sfNameEB, "BOTTOMLEFT", 2, -10)
sfThemeLabel:SetText("Thème de cette sous-zone :")
UI.ApplyLabel(sfThemeLabel)

local sfThemeDropdown = CreateFrame("Frame", "ZoneGateSubThemeDropdown", subForm, "UIDropDownMenuTemplate")
sfThemeDropdown:SetPoint("TOPLEFT", sfThemeLabel, "BOTTOMLEFT", -16, -4)
UIDropDownMenu_SetWidth(sfThemeDropdown, 180)
UI.StyleDropdown(sfThemeDropdown)

local sfEditThemeBtn = UI.CreatePanelButton(subForm, 60, 22, "Éditer")
sfEditThemeBtn:SetPoint("LEFT", sfThemeDropdown, "RIGHT", 26, 2)
sfEditThemeBtn:SetScript("OnClick", function()
    local sub = panel.selectedSubZoneId and ZG:FindSubZone(panel.selectedSubZoneId)
    if sub and ZoneGateThemePanel then
        if sub.themeId then ZoneGateThemePanel:EditTheme(sub.themeId)
        else ZoneGateThemePanel:Toggle() end
    end
end)

UIDropDownMenu_Initialize(sfThemeDropdown, function(self, level)
    local sub = panel.selectedSubZoneId and ZG:FindSubZone(panel.selectedSubZoneId)
    if not sub then return end

    local info = UIDropDownMenu_CreateInfo()
    info.text = "(Bannière de la région)"
    info.notCheckable = true
    info.func = function()
        ZG:SetSubZoneTheme(sub.id, "")
        UIDropDownMenu_SetText(sfThemeDropdown, "(Bannière de la région)")
    end
    UIDropDownMenu_AddButton(info, level)

    for _, theme in ipairs(ZG:GetThemeList()) do
        local themeInfo = UIDropDownMenu_CreateInfo()
        themeInfo.text = theme.name
        themeInfo.notCheckable = true
        themeInfo.func = function()
            ZG:SetSubZoneTheme(sub.id, theme.id)
            UIDropDownMenu_SetText(sfThemeDropdown, theme.name)
        end
        UIDropDownMenu_AddButton(themeInfo, level)
    end
end)

local sfStatusFS = subForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sfStatusFS:SetPoint("TOPLEFT", sfThemeDropdown, "BOTTOMLEFT", 16, -10)

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

local radar = ZG.CreatePassageGuide(radarRow, function()
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
            OmegaHub.Print("Crossings : il faut au moins 3 points pour fermer une région.")
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
local sfGrantFrame = BuildGrantFrame(subForm, 400, true, "Révéler le nom du checkpoint")
sfGrantFrame:SetPoint("TOPLEFT", actionFwdCB, "BOTTOMLEFT", -2, -14)
sfGrantFrame.confirmBtn:SetScript("OnClick", function()
    local id=panel.selectedSubZoneId
    ZG:OpenDiscoveryPicker("subzone",id,function()
        RefreshGrantList(sfGrantFrame,id,GetSubGrantList,RevokeSubGrant)
    end)
end)

function panel:RefreshSubZoneForm()
    local sub, zone = ZG:FindSubZone(panel.selectedSubZoneId)
    if not sub or not zone then return end

    local mine = zone.creator == MyName()

    local subKnownForDisplay = mine or ZG:HasLearnedSubZoneName(sub.id)
    sfZoneFS:SetText("Région : " .. (mine and zone.name or ZG:ResolveBannerText(sub, zone)))
    panel.suppressEvents = true
    sfNameEB:SetText(subKnownForDisplay and (sub.name or "") or ZG:MaskText(sub.name))
    panel.suppressEvents = false

    sfActiveCB:SetChecked(sub.enabled)

    sfThemeLabel:SetShown(mine)
    sfThemeDropdown:SetShown(mine)
    sfEditThemeBtn:SetShown(mine)
    if mine then
        local subTheme = sub.themeId and ZG:GetTheme(sub.themeId)
        UIDropDownMenu_SetText(sfThemeDropdown, subTheme and subTheme.name or "(Bannière de la région)")
    end

    if mine then
        sfStatusFS:SetText("|cff66e673Vous êtes l'auteur — texte toujours visible pour vous.|r")
    else
        local title, subtitle = ZG:ResolveBannerText(sub, zone)
        local zoneKnown = ZG:HasLearnedZoneName(zone.id)
        local subKnown  = ZG:HasLearnedSubZoneName(sub.id)
        local state
        if zoneKnown and subKnown then
            state = "|cff66e673Vous connaissez le nom de la région ET de la sous-zone.|r"
        elseif zoneKnown then
            state = "|cffe6c94dVous connaissez le nom de la région seulement.|r"
        elseif subKnown then
            state = "|cffe6c94dVous connaissez le nom du checkpoint seulement.|r"
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
        zfNameEB:SetText(zoneKnown and (zone.name or "") or "Région inconnue")
        panel.suppressEvents = false
        zfAuthorFS:SetText(mine and "Auteur : vous" or ("Auteur : " .. zone.creator))
        zfThemeLabel:SetShown(mine)
        zfThemeDropdown:SetShown(mine)
        zfEditThemeBtn:SetShown(mine)
        if mine then
            local zoneTheme = zone.themeId and ZG:GetTheme(zone.themeId)
            UIDropDownMenu_SetText(zfThemeDropdown, zoneTheme and zoneTheme.name or "(Thème par défaut)")
        end
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

-- Compact editor: one checkpoint, three tasks; all setters above stay shared.
local FORM_W=PANEL_W-LIST_W-PAD*2-16
local function Place(control,parent,x,y,w,h)
    control:SetParent(parent);control:ClearAllPoints()
    control:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    if w then control:SetWidth(w) end
    if h then control:SetHeight(h) end
end
local function Caption(parent,text,x,y,w)
    local fs=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    Place(fs,parent,x,y,w);fs:SetText(text);fs:SetJustifyH("LEFT")
    UI.ApplyMutedText(fs);return fs
end
local function Fit()
    panel:SetScale(math.min(1,(UIParent:GetWidth()-32)/PANEL_W,(UIParent:GetHeight()-32)/PANEL_H))
end
panel:HookScript("OnShow",Fit)
panel:RegisterEvent("DISPLAY_SIZE_CHANGED");panel:SetScript("OnEvent",Fit)
Fit()
titleText:ClearAllPoints();titleText:SetPoint("TOPLEFT",header,"TOPLEFT",16,-10)
Caption(header,"Checkpoints d'entrée et de sortie de région",16,34,400)
themesBtn:SetText("Atelier des bannières");themesBtn:SetWidth(174)
Caption(panel,"Modifications enregistrées automatiquement",PAD,PANEL_H-23,380)

local search=UI.CreateStyledEditBox(panel,LIST_W,26,false)
Place(search,panel,PAD,HEADER_H+64)
local searchHint=Caption(search,"Rechercher une région ou un checkpoint",8,7,LIST_W-16)
search:SetScript("OnTextChanged",function(self)
    panel.searchText=(self:GetText() or ""):lower()
    searchHint:SetShown(panel.searchText=="")
    panel:RefreshZoneTree()
end)
panel.searchBox=search

placeholder:SetWidth(FORM_W-32)
placeholder:SetText("VOS PASSAGES ENTRE RÉGIONS\n\n1. Créez une région dans la colonne de gauche.\n\n2. Placez-vous en jeu à l'endroit du passage, puis ajoutez un checkpoint.\n\n3. Réglez sa forme, ses effets d'entrée et de sortie et les noms connus des joueurs.")
Place(placeholder,form,16,24,FORM_W-32)

-- Region overview: identity, inherited banner, primary creation action, discovery.
Caption(zoneForm,"RÉGION",12,6,FORM_W-24)
Place(zfNameEB,zoneForm,12,26,FORM_W-24,28)
Place(zfAuthorFS,zoneForm,14,63,FORM_W-28)
Place(zfThemeLabel,zoneForm,12,91,FORM_W-24)
zfThemeLabel:SetText("Bannière par défaut des checkpoints")
Place(zfThemeDropdown,zoneForm,-4,111)
UIDropDownMenu_SetWidth(zfThemeDropdown,FORM_W-140)
Place(zfEditThemeBtn,zoneForm,FORM_W-96,113,84,24)
Place(zfHintFS,zoneForm,12,151,FORM_W-24,28)
zfHintFS:SetText("Placez-vous au passage souhaité, puis capturez votre position.")
local addCheckpoint=UI.CreatePanelButton(zoneForm,FORM_W-24,30,"+ Placer un checkpoint ici")
Place(addCheckpoint,zoneForm,12,188)
addCheckpoint:SetScript("OnClick",function()
    local sub=panel.selectedZoneId and ZG:CreateSubZone(panel.selectedZoneId)
    if sub then
        panel.selectedSubZoneId=sub.id;panel.formMode="subzone"
        panel.checkpointTab="placement";panel:RefreshAll()
    end
end)
Place(zfGrantFrame,zoneForm,12,232,FORM_W-24)
Place(zfDeleteBtn,zoneForm,12,476,170,26)
zfDeleteBtn:SetText("Supprimer la région")

-- Consistent discovery cards with labels above inputs, bounded to the card.
for _,grant in ipairs({zfGrantFrame,sfGrantFrame}) do
    grant:SetWidth(FORM_W-24)
    for _,row in ipairs(grant.listRows or {}) do row:SetWidth(FORM_W-40) end
end

Place(sfZoneFS,subForm,12,6,FORM_W-24)
Place(sfNameEB,subForm,12,28,FORM_W-126,28)
Place(sfActiveCB,subForm,FORM_W-99,32)
Place(sfStatusFS,subForm,12,66,FORM_W-24,30)
sfStatusFS:SetJustifyH("LEFT")
local pages,tabs={},{ }
for i,entry in ipairs({{"placement","Placement"},{"effects","Déclenchement"},{"discovery","Découverte"}}) do
    local key,label=entry[1],entry[2]
    local page=CreateFrame("Frame",nil,subForm)
    Place(page,subForm,0,144,FORM_W,430)
    pages[key]=page
    local tab=UI.CreatePanelButton(subForm,(FORM_W-32)/3,28,label)
    Place(tab,subForm,12+(i-1)*(FORM_W-20)/3,108)
    tabs[key]=tab
    tab:SetScript("OnClick",function() panel.checkpointTab=key;panel:RefreshForm() end)
end
panel.checkpointPages=pages
panel.checkpointTabs=tabs
Place(shapeLineBtn,pages.placement,12,8,100,26);shapeLineBtn:SetText("Passage droit")
Place(shapeCircleBtn,pages.placement,120,8,100,26)
Place(shapeRegionBtn,pages.placement,228,8,112,26);shapeRegionBtn:SetText("Périmètre libre")
Caption(pages.placement,"Ligne : sens de votre regard. Cercle / périmètre : intérieur et extérieur.",12,44,FORM_W-24)
Place(radarRow,pages.placement,12,80,FORM_W-24,284)
Place(recaptureBtn,pages.placement,12,374,190,28);recaptureBtn:SetText("Déplacer à ma position")
Place(cloneBtn,pages.placement,210,374,110,28);cloneBtn:SetText("Dupliquer ici")
Place(sfDeleteBtn,pages.placement,FORM_W-126,374,114,28)
Place(regionLabel,radarRow,320,0,FORM_W-356,28)
Place(widthLabel,radarRow,320,0,FORM_W-356)
Place(widthEB,radarRow,320,25,76,26)
Place(sliderTrack,radarRow,322,64,FORM_W-368,4)
Place(addPointBtn,radarRow,320,36,200,24)
Place(undoPointBtn,radarRow,320,68,96,24)
Place(clearPointsBtn,radarRow,424,68,96,24)
Place(finishRegionBtn,radarRow,320,100,200,26)

Place(sfThemeLabel,pages.effects,12,8,FORM_W-24);sfThemeLabel:SetText("Bannière de ce checkpoint")
Place(sfThemeDropdown,pages.effects,-4,28)
UIDropDownMenu_SetWidth(sfThemeDropdown,FORM_W-140)
Place(sfEditThemeBtn,pages.effects,FORM_W-96,30,84,24)
for _,control in ipairs({fwdEnabledCB,fwdEnabledLabel,backEnabledCB,backEnabledLabel}) do control:SetParent(pages.effects) end
Place(fwdEnabledCB,pages.effects,12,70)
Place(backEnabledCB,pages.effects,FORM_W/2,70)
fwdEnabledLabel:SetText("Bannière à l'entrée");backEnabledLabel:SetText("Bannière à la sortie")
Place(actionTitle,pages.effects,12,112,FORM_W-24)
Place(actionMsgLabel,pages.effects,12,140,FORM_W-24)
Place(actionMsgEB,pages.effects,12,158,FORM_W-24,26)
Place(actionCmdLabel,pages.effects,12,196,FORM_W-24)
Place(actionCmdEB,pages.effects,12,214,FORM_W-24,26)
Place(actionCmdHint,pages.effects,12,250,FORM_W-24,38)
actionCmdHint:SetText("Un nombre applique / retire une aura. Une commande est envoyée dans le canal de groupe disponible.")
for _,control in ipairs({actionFwdCB,actionFwdLabel,actionBackCB,actionBackLabel}) do control:SetParent(pages.effects) end
Place(actionFwdCB,pages.effects,12,300);Place(actionBackCB,pages.effects,FORM_W/2,300)
actionFwdLabel:SetText("Action à l'entrée");actionBackLabel:SetText("Action à la sortie")
Place(sfGrantFrame,pages.discovery,12,8,FORM_W-24)
Caption(pages.discovery,"Le nom de la région et celui du checkpoint se révèlent séparément. Les autres joueurs voient des noms masqués tant qu'ils ne les ont pas appris.",12,262,FORM_W-24)

local refreshForm=panel.RefreshForm
function panel:RefreshForm()
    refreshForm(self)
    local zone=self.selectedZoneId and ZG:GetZone(self.selectedZoneId)
    local mine=zone and zone.creator==MyName()
    addCheckpoint:SetShown(self.formMode=="zone" and mine)
    zfNameEB:SetEnabled(mine and true or false)
    if self.formMode=="subzone" then
        local sub,parent=ZG:FindSubZone(self.selectedSubZoneId)
        local own=parent and parent.creator==MyName()
        sfNameEB:SetEnabled(own and true or false);sfActiveCB:SetEnabled(own and true or false)
        widthEB:SetEnabled(own and true or false);sliderHandle:EnableMouse(own and true or false)
        fwdEnabledCB:SetEnabled(own and true or false);backEnabledCB:SetEnabled(own and true or false)
        local key=self.checkpointTab or "placement"
        for id,page in pairs(pages) do page:SetShown(id==key);tabs[id].accent:SetShown(id==key) end
    end
end
-- Destructive actions require a second, explicit click in a small confirmation card.
local confirm=CreateFrame("Frame","ZoneGateDeleteConfirm",panel)
confirm:SetSize(360,132);confirm:SetPoint("CENTER");confirm:SetFrameStrata("DIALOG")
confirm:EnableMouse(true);UI.Surface(confirm);confirm:Hide()
local confirmText=Caption(confirm,"",16,16,328)
local cancel=UI.CreatePanelButton(confirm,146,28,"Annuler");Place(cancel,confirm,16,86)
local accept=UI.CreatePanelButton(confirm,174,28,"Confirmer la suppression");Place(accept,confirm,170,86)
cancel:SetScript("OnClick",function() confirm:Hide() end)
accept:SetScript("OnClick",function() local fn=confirm.action;confirm:Hide();if fn then fn() end end)
for _,button in ipairs({zfDeleteBtn,sfDeleteBtn}) do
    local remove=button:GetScript("OnClick")
    button:SetScript("OnClick",function()
        local zid,sid=panel.selectedZoneId,panel.selectedSubZoneId
        confirmText:SetText(button==zfDeleteBtn and "Supprimer cette région et tous ses checkpoints ?" or "Supprimer ce checkpoint ?")
        confirm.action=function() if zid==panel.selectedZoneId and sid==panel.selectedSubZoneId then remove() end end
        confirm:Show()
    end)
end
panel:HookScript("OnHide",function() confirm:Hide();sliderHandle:SetScript("OnUpdate",nil) end)
UISpecialFrames=UISpecialFrames or {}
table.insert(UISpecialFrames,"ZoneGatePanel")
table.insert(UISpecialFrames,"ZoneGateDeleteConfirm")
panel:RefreshForm()
