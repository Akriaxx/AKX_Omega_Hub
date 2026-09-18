-- ============================================================
--  Character - Vue joueur compacte
--  /ocharview pour ouvrir
-- ============================================================

local C  = Character
local UI = C.RPGUI or OS2.UI

local W, PAD = 244, 6
local ROW_H = 32

-- Les commandes suivent la zone visible de la liste (huit alliés au maximum).
-- Leur hauteur inclut les deux menus côte à côte et les actions groupées.
local TOP_CHROME    = 26
local SEP_GAP       = 6
local CONTROLS_H    = 106
local BOTTOM_MARGIN = 6

local rows = {}
local selectedPlayers = {}
local selectedStat = "hp"
local selectedAction = "gain"
local viewport
local panel, content, valueEB, statusFS, multiCB, applyBtn
local ShowGroupStatus
local function FitFooter()
    if panel and viewport then
        local messageHeight = statusFS and statusFS:IsShown() and statusFS:GetText() ~= "" and 16 or 0
        panel:SetHeight(TOP_CHROME + viewport:GetHeight() + SEP_GAP * 2 + 1 + CONTROLS_H + BOTTOM_MARGIN + messageHeight)
    end
end

local ACTIONS = {
    gain = { label = "Gain" },
    buff = { label = "Buff temporaire" },
}

local function MyName()
    return UnitName("player") or ""
end

local function UnitNameShort(unit)
    local name = UnitName(unit)
    return name and name:match("^([^%-]+)") or name
end

-- Ne liste que les membres présents : un membre du groupe déconnecté n'a
-- aucune chance d'envoyer ses données, sa ligne resterait bloquée sur
-- "Profil en attente" indéfiniment et prendrait de la place pour rien.
local function GetVisibleMembers()
    local members, seen = {}, {}
    local function Add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            members[#members + 1] = name
        end
    end

    Add(MyName())

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local token = "raid" .. i
            if UnitIsConnected(token) then Add(UnitNameShort(token)) end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            local token = "party" .. i
            if UnitIsConnected(token) then Add(UnitNameShort(token)) end
        end
    end

    table.sort(members)
    return members
end

local function GetMemberData(name)
    if name == MyName() then return C:GetMyChar() end
    return C.groupData and C.groupData[name]
end

local function RefreshSelectionVisuals()
    for name, row in pairs(rows) do
        if row.SetSelected then row:SetSelected(selectedPlayers[name]) end
    end
end

local function CountSelected()
    local count = 0
    for _ in pairs(selectedPlayers) do count = count + 1 end
    return count
end

local function SelectPlayer(name)
    if not name or name == "" then return end

    if multiCB and multiCB:GetChecked() then
        selectedPlayers[name] = not selectedPlayers[name] or nil
    else
        selectedPlayers = {}
        selectedPlayers[name] = true
    end

    RefreshSelectionVisuals()
    if ShowGroupStatus then
        local count = CountSelected()
        if count > 0 then ShowGroupStatus(tostring(count) .. " cible(s)") end
    end
end

local function ApplyTargetAttribute(row, playerName)
    if not row or not playerName then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local token = C.GetUnitTokenForName and C:GetUnitTokenForName(playerName)
    if token and UnitExists and UnitExists(token) then
        row:SetAttribute("type1", "target")
        row:SetAttribute("unit", token)
        row:SetAttribute("*type1", "target")
        row:SetAttribute("*unit1", token)
    else
        row:SetAttribute("type1", nil)
        row:SetAttribute("unit", nil)
        row:SetAttribute("*type1", nil)
        row:SetAttribute("*unit1", nil)
    end
end

local function MakeRow(parent, name)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    row:SetHeight(ROW_H)
    row.playerName = name
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")
    ApplyTargetAttribute(row, name)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.rowBg))
    row.bg = bg

    local selectedTex = row:CreateTexture(nil, "BORDER")
    selectedTex:SetAllPoints()
    selectedTex:SetColorTexture(unpack(UI.colors.rowSelection))
    selectedTex:Hide()
    row.selectedTex = selectedTex

    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -5)
    nameFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -5)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    UI.ApplyBodyText(nameFS)

    -- Vue alliés : seulement la proportion de PV, jamais de valeurs chiffrées.
    local healthBar = UI.HealthMini(row, -20)
    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT")
    sep:SetPoint("BOTTOMRIGHT")
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)

    function row:Refresh(playerName)
        row.playerName = playerName
        ApplyTargetAttribute(row, playerName)
        local data = GetMemberData(playerName)
        nameFS:SetText(C.GetDisplayName and C:GetDisplayName(playerName, data) or playerName)
        healthBar:Refresh(data and data.hp)
        row:SetSelected(selectedPlayers[playerName])
    end

    function row:SetSelected(selected)
        if selected then
            selectedTex:Show()
            bg:SetColorTexture(unpack(UI.colors.rowBgSelected))
        else
            selectedTex:Hide()
            bg:SetColorTexture(unpack(UI.colors.rowBg))
        end
    end

    row:SetScript("PostClick", function(self, button)
        if button == "LeftButton" then
            SelectPlayer(self.playerName or name)
        end
    end)

    return row
end

local function CreateChoiceStrip(parent, width, labelText, items, getValue, setValue)
    return UI.CreateChoiceStrip(parent, width, labelText, items, getValue, setValue)
end

local function ApplyToSelected()
    local amount = math.max(0, math.floor(tonumber(valueEB:GetText() or "") or 0))
    if amount <= 0 then
        if ShowGroupStatus then ShowGroupStatus("Valeur ?") end
        return
    end

    local count = CountSelected()
    if count <= 0 then
        if ShowGroupStatus then ShowGroupStatus("Aucune cible") end
        return
    end

    for name in pairs(selectedPlayers) do
        if selectedAction == "buff" then
            if name == MyName() then
                C:AddTemp(selectedStat, amount, true)
            elseif C.SendTempCmd then
                C:SendTempCmd(name, selectedStat, amount)
            end
        else
            local delta = (selectedAction == "damage") and -amount or amount
            if name == MyName() then
                C:Delta(selectedStat, delta, true)
            elseif C.SendModCmd then
                C:SendModCmd(name, selectedStat, delta)
            end
        end
    end

    if not (multiCB and multiCB:GetChecked()) then
        selectedPlayers = {}
        RefreshSelectionVisuals()
    end

    if ShowGroupStatus then ShowGroupStatus("Envoyé") end
end

local function Rebuild()
    if not panel then return end
    for _, row in pairs(rows) do row:Hide() end

    local members = GetVisibleMembers()
    local columns = #members > 1 and 2 or 1
    local cellW = (W - PAD * 2 - (columns - 1) * 6) / columns
    for index, name in ipairs(members) do
        local row = rows[name] or MakeRow(content, name)
        rows[name] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", ((index-1)%columns)*(cellW+6), -4-math.floor((index-1)/columns)*(ROW_H+2))
        row:SetWidth(cellW)
        row:Show()
        row:Refresh(name)
    end

    local listH = math.ceil(#members/columns) * (ROW_H + 2) + 4
    content:SetHeight(listH)
    local visibleH=math.min(listH,4*(ROW_H+2)+4)
    viewport:SetHeight(visibleH)
    viewport:SetVerticalScroll(math.min(viewport:GetVerticalScroll(),math.max(0,listH-visibleH)))
    -- Somme directe des mêmes constantes qui positionnent `controls` (voir
    -- Build) : ne peut plus diverger de sa position réelle, donc plus jamais
    -- d'espace mort entre la liste et les contrôles, ni sous "Appliquer".
    FitFooter()
end

local function Build()
    if panel then return panel end

    panel = CreateFrame("Frame", "CharacterGroupViewPanel", UIParent)
    -- Taille de secours avant le premier Rebuild (qui la recalcule aussitôt
    -- à l'ouverture, voir ToggleGroupView) : un seul membre, juste pour
    -- éviter un flash à une taille absurde.
    panel:SetSize(W, TOP_CHROME + (ROW_H + 2 + 2) + SEP_GAP + 1 + SEP_GAP + CONTROLS_H + BOTTOM_MARGIN)
    panel:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(100)
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg)
    panel.bg = bg

    -- Applique les réglages sauvegardés dès la création lazy du panel
    if C.GetSettings then
        local s = C:GetSettings()
        if s.groupScale    then panel:SetScale(s.groupScale) end
        if s.windowOpacity then UI.ApplyWindowBackground(bg, s.windowOpacity) end
    end

    local title = CreateFrame("Frame", nil, panel)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -44, 0)
    title:SetHeight(18)
    title:EnableMouse(true)
    title:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then panel:StartMoving() end
    end)
    title:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

    local titleFS = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleFS:SetPoint("LEFT", title, "LEFT", 5, 0)
    titleFS:SetText("Compagnons")
    UI.ApplyTitle(titleFS)

    local refreshBtn = UI.CreatePanelButton(panel, 18, 15, "A")
    refreshBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -2)
    refreshBtn:SetFrameLevel(panel:GetFrameLevel() + 40)
    local refreshLbl = refreshBtn:GetFontString()
    if refreshLbl then
        refreshLbl:ClearAllPoints()
        refreshLbl:SetAllPoints(refreshBtn)
        refreshLbl:SetJustifyH("CENTER")
        refreshLbl:SetJustifyV("MIDDLE")
    end
    refreshBtn:SetScript("OnClick", function()
        C:RequestAll()
        Rebuild()
        if ShowGroupStatus then ShowGroupStatus("Maj") end
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Actualisé", unpack(UI.colors.title))
        GameTooltip:AddLine("Recharge les données du groupe.", unpack(UI.colors.textMuted))
        GameTooltip:Show()
    end)
    refreshBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local closeBtn = UI.CreateCloseButton(panel, function() panel:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -2)
    closeBtn:SetSize(18, 15)
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 50)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -19)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -19)
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)

    viewport=CreateFrame("ScrollFrame",nil,panel)
    viewport:SetPoint("TOPLEFT",panel,"TOPLEFT",PAD,-26)
    viewport:SetPoint("TOPRIGHT",panel,"TOPRIGHT",-PAD,-26)
    viewport:SetHeight(60);viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel",function(self,delta)
        self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*(ROW_H+2))))
    end)
    content=CreateFrame("Frame",nil,viewport)
    content:SetWidth(W-PAD*2);content:SetHeight(1);viewport:SetScrollChild(content)
    -- Ancré au bas de la LISTE (pas du panneau) : sa position suit donc
    -- directement `content`, quelle que soit la taille du groupe — voir
    -- TOP_CHROME/SEP_GAP/CONTROLS_H/BOTTOM_MARGIN plus haut.
    local controlSep = panel:CreateTexture(nil, "ARTWORK")
    controlSep:SetPoint("TOPLEFT", viewport, "BOTTOMLEFT", 0, -SEP_GAP)
    controlSep:SetPoint("TOPRIGHT", viewport, "BOTTOMRIGHT", 0, -SEP_GAP)
    controlSep:SetHeight(1)
    UI.ApplySeparator(controlSep, true)

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetPoint("TOPLEFT", controlSep, "BOTTOMLEFT", 0, -SEP_GAP)
    controls:SetPoint("TOPRIGHT", controlSep, "BOTTOMRIGHT", 0, -SEP_GAP)
    controls:SetHeight(CONTROLS_H)

    local valueLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueLabel:SetPoint("LEFT", controls, "TOPLEFT", 2, -11)
    valueLabel:SetText("Valeur")
    UI.ApplyLabel(valueLabel)

    valueEB = UI.CreateStyledEditBox(controls, 50, 22)
    valueEB:SetNumeric(true)
    valueEB:SetMaxLetters(5)
    valueEB:SetPoint("TOPLEFT", controls, "TOPLEFT", 46, 0)
    valueEB:SetText("8")

    local statDropdown = CreateChoiceStrip(controls, W - PAD * 2, nil, {
        { value = "hp", label = "Vie" },
        { value = "mana", label = "Mana" },
        { value = "endurance", label = "End." },
    }, function() return selectedStat end, function(value) selectedStat = value end)
    statDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -30)

    local actionDropdown = CreateChoiceStrip(controls, W - PAD * 2, nil, {
        { value = "damage", label = "Retrait" },
        { value = "gain", label = "Gain" },
        { value = "buff", label = "Bonus" },
    }, function() return selectedAction end, function(value) selectedAction = value end)
    actionDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -56)

    multiCB = UI.CreateStyledCheckbox(controls, "Multicible")
    multiCB:SetPoint("LEFT", valueEB, "RIGHT", 12, 0)
    multiCB.label:SetPoint("LEFT", multiCB, "RIGHT", 5, 0)
    multiCB:SetScript("OnClick", function(self)
        if not self:GetChecked() then
            local keep
            for name in pairs(selectedPlayers) do keep = name; break end
            selectedPlayers = {}
            if keep then selectedPlayers[keep] = true end
            RefreshSelectionVisuals()
        end
    end)

    -- "+ État" et Appliquer enchaînés depuis Multicible (TOP-anchorés, pas
    -- ancrés depuis le bas de `controls`) : leur position ne dépend donc que
    -- de ce qui est réellement au-dessus, jamais d'une hauteur de `controls`
    -- à recaler à la main (voir CONTROLS_H plus haut, qui ne sert plus qu'au
    -- calcul de la hauteur du panneau, pas à leur position).

    -- Ouvre le popup partagé "Ajouter un état" (UI_Initiative.lua) : liste
    -- TOUTES les cibles disponibles (joueurs ET PNJ), nom + icone seulement —
    -- contrairement à la liste ci-dessus qui ne montre que les joueurs (les
    -- joueurs ne voient pas le détail des PNJ), c'est la seule façon pour un
    -- joueur normal de viser aussi un PNJ.
    local addStatusBtn = UI.CreatePanelButton(controls, (W-PAD*2-8)/2, 20, "+ État")
    addStatusBtn:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -86)
    addStatusBtn:SetScript("OnClick", function()
        if not C.initiative.active then
            if ShowGroupStatus then ShowGroupStatus("Combat non démarré") end
            return
        end
        if C.OpenStatusPopup then C:OpenStatusPopup() end
    end)

    applyBtn = UI.CreatePanelButton(controls, (W-PAD*2-8)/2, 20, "Appliquer")
    applyBtn:SetPoint("TOPLEFT", addStatusBtn, "TOPRIGHT", 8, 0)
    applyBtn:SetScript("OnClick", ApplyToSelected)

    statusFS = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("TOPLEFT", addStatusBtn, "BOTTOMLEFT", 2, -4)
    statusFS:SetPoint("RIGHT", controls, "RIGHT", -2, 0)
    statusFS:SetJustifyH("LEFT")
    UI.ApplyMutedText(statusFS)

    local statusToken = 0
    ShowGroupStatus = function(text)
        if not statusFS then return end
        statusToken = statusToken + 1
        local token = statusToken
        statusFS:SetText(text or "")
        statusFS:Show()
        FitFooter()
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                if token == statusToken and statusFS then
                    statusFS:SetText("")
                    statusFS:Hide()
                    FitFooter()
                end
            end)
        end
    end
    statusFS:Hide()

    return panel
end

local function Refresh()
    if panel and panel:IsShown() then Rebuild() end
end

local prevGroup = C.OnGroupDataChanged
C.OnGroupDataChanged = function(name)
    if prevGroup then prevGroup(name) end
    Refresh()
end

local prevMine = C.OnMyDataChanged
C.OnMyDataChanged = function()
    if prevMine then prevMine() end
    Refresh()
end

function C:ToggleGroupView()
    Build()
    if panel:IsShown() then
        panel:Hide()
    else
        C:RequestAll()
        Rebuild()
        panel:Show()
    end
end

SLASH_OCHARVIEW1 = "/ocharview"
SlashCmdList["OCHARVIEW"] = function()
    C:ToggleGroupView()
end
