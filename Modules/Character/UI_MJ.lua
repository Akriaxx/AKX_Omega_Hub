-- ============================================================
--  Character — Vue MJ (compacte, groupe en temps réel)
--  /ocharmj pour ouvrir · clic sur le titre pour déplacer
-- ============================================================

local C  = Character
local UI = OS2.UI

-- Couleurs de barre (partagées depuis UI.lua)
local COL_HP  = { fg = UI.colors.statHP.fg,   dim = UI.colors.statHP.bg   }
local COL_MP  = { fg = UI.colors.statMana.fg,  dim = UI.colors.statMana.bg  }
local COL_END = { fg = UI.colors.statEnd.fg,   dim = UI.colors.statEnd.bg   }

local rows = {}
local selectedPlayers = {}
local impactState = { stat = "hp", mode = "damage" }
local impactPanel, impactValueEB, impactMultiCB, impactStatus
local ApplyImpactToPlayer, SelectPlayerForImpact, UpdateAllSelections
local UpdateScrollRange
local ShowImpactStatus

-- ── Barre de titre draggable ──────────────────────────────────────────────────

local function MakeTitleBar(parent, text)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:SetHeight(20)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function(_, b)
        if b == "LeftButton" then parent:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function() parent:StopMovingOrSizing() end)

    local bgTex = bar:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(unpack(UI.colors.panelButtonBg))

    local lbl = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyTitle(lbl)
    lbl:SetText(text)
    lbl:SetPoint("LEFT", bar, "LEFT", 8, 0)
    return bar
end

-- ── Mini-barre pour une stat (dans la liste MJ) ───────────────────────────────

local MBAR_W = 86

local function MiniStatRow(parent, col)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    local barBg = row:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("LEFT", 0, 0)
    barBg:SetSize(MBAR_W, 9)
    barBg:SetColorTexture(col.dim[1], col.dim[2], col.dim[3], 1)

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", barBg)
    fill:SetHeight(9)
    fill:SetColorTexture(col.fg[1], col.fg[2], col.fg[3], 1)
    fill:SetWidth(MBAR_W)

    local tempFill = row:CreateTexture(nil, "ARTWORK")
    tempFill:SetPoint("TOPLEFT", barBg)
    tempFill:SetHeight(9)
    tempFill:SetColorTexture(unpack(UI.colors.tempFill))
    tempFill:SetWidth(1)
    tempFill:Hide()

    local valTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyMutedText(valTxt)
    valTxt:SetText("—"); valTxt:SetWidth(82); valTxt:SetHeight(12)
    valTxt:SetWordWrap(false)
    valTxt:SetPoint("LEFT", barBg, "RIGHT", 3, 0)

    local function Fmt(n)
        if     n >= 10000 then return string.format("%.0fk", n / 1000)
        elseif n >= 1000  then return string.format("%.1fk", n / 1000)
        else return tostring(n) end
    end

    function row:Set(cur, max, temp)
        temp = math.max(0, tonumber(temp) or 0)
        valTxt:SetText(Fmt(cur) .. "/" .. Fmt(max) .. (temp > 0 and (" (" .. Fmt(temp) .. ")") or ""))
        local total = math.max(1, max + temp)
        local curW = math.max(1, MBAR_W * math.max(0, math.min(1, cur / total)))
        fill:SetWidth(curW)

        if temp > 0 then
            tempFill:ClearAllPoints()
            tempFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", curW, 0)
            tempFill:SetHeight(9)
            tempFill:SetWidth(math.max(1, MBAR_W * math.max(0, math.min(1, temp / total))))
            tempFill:Show()
        else
            tempFill:Hide()
        end
    end

    return row
end

-- ── Ligne de joueur ───────────────────────────────────────────────────────────

local ROW_H = 86
local PAD   = 8

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

local function PlayerRow(parent, playerName)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    row:SetHeight(ROW_H)
    row.playerName = playerName
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")
    ApplyTargetAttribute(row, playerName)

    -- Fond
    local bgTex = row:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(unpack(UI.colors.rowBg))
    row.bgTex = bgTex

    local selectedTex = row:CreateTexture(nil, "BORDER")
    selectedTex:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    selectedTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    selectedTex:SetColorTexture(unpack(UI.colors.rowSelection))
    selectedTex:Hide()
    row.selectedTex = selectedTex

    -- Séparateur bas
    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT")
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)

    -- Nom du joueur
    local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyBodyText(nameTxt)
    nameTxt:SetText(playerName)
    nameTxt:SetPoint("TOPLEFT", PAD, -4)

    -- Labels des stats
    local function StatLabel(txt, col, yOff)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetTextColor(col.fg[1], col.fg[2], col.fg[3], 1)
        lbl:SetText(txt); lbl:SetWidth(28); lbl:SetJustifyH("LEFT")
        lbl:SetPoint("TOPLEFT", PAD, yOff)
        return lbl
    end

    local lHP  = StatLabel("HP",   COL_HP,  -20)
    local lMP  = StatLabel("MP",   COL_MP,  -38)
    local lEN  = StatLabel("End.", COL_END, -56)

    -- Mini-barres
    local barHP  = MiniStatRow(row, COL_HP)
    local barMP  = MiniStatRow(row, COL_MP)
    local barEN  = MiniStatRow(row, COL_END)

    local function SetBarLayout(bar, lbl, yOff)
        bar:SetPoint("LEFT",   lbl, "RIGHT", 2, 0)
        bar:SetPoint("RIGHT",  row, "RIGHT", -PAD, 0)
        bar:SetPoint("TOP",    row, "TOP",    0, yOff)
    end
    SetBarLayout(barHP, lHP, -17)
    SetBarLayout(barMP, lMP, -35)
    SetBarLayout(barEN, lEN, -53)

    -- "Pas de données" placeholder
    local noData = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.ApplySoftText(noData)
    noData:SetText("En attente de données...")
    noData:SetPoint("LEFT", PAD, 0); noData:Hide()

    function row:SetSelected(selected)
        if selected then
            selectedTex:Show()
            bgTex:SetColorTexture(unpack(UI.colors.rowBgSelected))
        else
            selectedTex:Hide()
            bgTex:SetColorTexture(unpack(UI.colors.rowBg))
        end
    end

    row:SetScript("PostClick", function()
        if SelectPlayerForImpact then SelectPlayerForImpact(playerName) end
    end)

    function row:Refresh(data)
        ApplyTargetAttribute(row, playerName)
        nameTxt:SetText(C.GetDisplayName and C:GetDisplayName(playerName, data) or "Profil en attente")
        if not data then
            lHP:Hide(); lMP:Hide(); lEN:Hide()
            barHP:Hide(); barMP:Hide(); barEN:Hide()
            noData:Show()
            row:SetSelected(selectedPlayers[playerName])
            return
        end
        noData:Hide()
        lHP:Show(); lMP:Show(); lEN:Show()
        barHP:Show(); barMP:Show(); barEN:Show()

        barHP:Set(data.hp.cur,        data.hp.max,        data.hp.temp)
        barMP:Set(data.mana.cur,      data.mana.max,      data.mana.temp)
        barEN:Set(data.endurance.cur, data.endurance.max, data.endurance.temp)
        row:SetSelected(selectedPlayers[playerName])
    end

    return row
end

-- ── Panneau MJ ────────────────────────────────────────────────────────────────

local MJ_W, MJ_H = 340, 380

local mjPanel = CreateFrame("Frame", "CharacterMJPanel", UIParent)
mjPanel:SetSize(MJ_W, MJ_H)
mjPanel:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
mjPanel:SetMovable(true)
mjPanel:SetClampedToScreen(true)
mjPanel:EnableMouse(true)
mjPanel:SetFrameStrata("MEDIUM")
mjPanel:Hide()

-- Fond style OS2
local bgTex = mjPanel:CreateTexture(nil, "BACKGROUND")
bgTex:SetAllPoints()
UI.ApplyWindowBackground(bgTex)
mjPanel.bg = bgTex

-- Barre de titre draggable
local titleBar = MakeTitleBar(mjPanel, "Vue MJ — Groupe")
titleBar:SetFrameLevel(mjPanel:GetFrameLevel() + 1)

-- Bouton fermer
local closeBtn = UI.CreateCloseButton(mjPanel, function() mjPanel:Hide() end)
closeBtn:ClearAllPoints()
closeBtn:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT", -3, -3)
closeBtn:SetSize(18, 16)

if closeBtn and closeBtn.SetFrameLevel then
    closeBtn:SetFrameLevel(mjPanel:GetFrameLevel() + 50)
end

-- ── Panneau d'impact MJ ──────────────────────────────────────────────────────

impactPanel = CreateFrame("Frame", "CharacterMJImpactPanel", UIParent)
impactPanel:SetSize(220, 284)
impactPanel:SetPoint("TOPRIGHT", mjPanel, "TOPLEFT", -2, 0)
impactPanel:SetFrameStrata("MEDIUM")
impactPanel:SetFrameLevel(mjPanel:GetFrameLevel() + 5)
impactPanel:SetMovable(true)
impactPanel:SetClampedToScreen(true)
impactPanel:EnableMouse(true)
impactPanel:Hide()

local impactBg = impactPanel:CreateTexture(nil, "BACKGROUND")
impactBg:SetAllPoints()
UI.ApplyWindowBackground(impactBg)
impactPanel.bg = impactBg

local impactTitleBar = MakeTitleBar(impactPanel, "Gestionnaire de ressources")
impactTitleBar:SetFrameLevel(impactPanel:GetFrameLevel() + 1)

local function ImpactLabel(text, x, y)
    local fs = impactPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", x, y)
    fs:SetText(text)
    UI.ApplyLabel(fs)
    return fs
end

local function ImpactSeparator(y)
    local sep = impactPanel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, y)
    sep:SetPoint("TOPRIGHT", impactPanel, "TOPRIGHT", -10, y)
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)
    return sep
end

local function CreateImpactDropdown(parent, width, labelText, items, getValue, setValue)
    return UI.CreateDropdown(parent, width, labelText, items, getValue, setValue)
end

ImpactLabel("Valeur", 10, -34)
impactValueEB = UI.CreateStyledEditBox(impactPanel, 198, 22)
impactValueEB:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -50)
impactValueEB:SetNumeric(true)
impactValueEB:SetMaxLetters(7)
impactValueEB:SetText("1")
ImpactSeparator(-80)

local statDropdown = CreateImpactDropdown(impactPanel, 198, "Ressource", {
    { value = "hp", label = "HP" },
    { value = "mana", label = "Mana" },
    { value = "endurance", label = "Endurance" },
}, function() return impactState.stat end, function(value) impactState.stat = value end)
statDropdown:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -92)
ImpactSeparator(-138)

local actionDropdown = CreateImpactDropdown(impactPanel, 198, "Action", {
    { value = "damage", label = "Retrait" },
    { value = "heal", label = "Ajout" },
    { value = "buff", label = "Buff Temp" },
}, function() return impactState.mode end, function(value) impactState.mode = value end)
actionDropdown:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -150)
ImpactSeparator(-196)

impactMultiCB = UI.CreateStyledCheckbox(impactPanel, "Multicible")
impactMultiCB:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -208)
impactMultiCB.label:SetPoint("LEFT", impactMultiCB, "RIGHT", 6, 0)
impactMultiCB:SetScript("OnClick", function(self)
    if not self:GetChecked() then
        selectedPlayers = {}
        if UpdateAllSelections then UpdateAllSelections() end
    end
end)

local applyBtn = UI.CreatePanelButton(impactPanel, 72, 20, "Appliquer")
applyBtn:SetPoint("BOTTOMLEFT", impactPanel, "BOTTOMLEFT", 10, 28)
applyBtn:SetScript("OnClick", function()
    local count = 0
    for name in pairs(selectedPlayers) do
        count = count + 1
        if ApplyImpactToPlayer then ApplyImpactToPlayer(name, true) end
    end
    selectedPlayers = {}
    if UpdateAllSelections then UpdateAllSelections() end
    if ShowImpactStatus then ShowImpactStatus(count > 0 and "Envoyé" or "Aucune cible") end
end)

impactStatus = impactPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
impactStatus:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 2, -2)
impactStatus:SetPoint("RIGHT", impactPanel, "RIGHT", -10, 0)
impactStatus:SetJustifyH("LEFT")
impactStatus:SetText("")
UI.ApplyMutedText(impactStatus)

local impactStatusToken = 0
ShowImpactStatus = function(text)
    if not impactStatus then return end
    impactStatusToken = impactStatusToken + 1
    local token = impactStatusToken
    impactStatus:SetText(text or "")
    impactStatus:Show()
    if C_Timer and C_Timer.After then
        C_Timer.After(3, function()
            if token == impactStatusToken and impactStatus then
                impactStatus:SetText("")
                impactStatus:Hide()
            end
        end)
    end
end
impactStatus:Hide()

-- Bouton Actualiser (à gauche du bouton fermer)
local refreshBtn = UI.CreatePanelButton(mjPanel, 88, 16, "Actualiser")
refreshBtn:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT", -28, -3)
refreshBtn:SetFrameLevel(mjPanel:GetFrameLevel() + 40)
refreshBtn:SetScript("OnClick", function()
    C:RequestAll()
    local myName = UnitName("player")
    if myName then C.groupData[myName] = C:GetMyChar() end
    if CharacterMJPanel._rebuild then CharacterMJPanel._rebuild() end
end)

-- Séparateur sous le titre
local titleSep = mjPanel:CreateTexture(nil, "ARTWORK")
titleSep:SetPoint("TOPLEFT",  mjPanel, "TOPLEFT",   8, -21)
titleSep:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT",  -8, -21)
titleSep:SetHeight(1)
UI.ApplySeparator(titleSep, true)

-- ── ScrollFrame ───────────────────────────────────────────────────────────────

local scrollFrame = CreateFrame("ScrollFrame", nil, mjPanel)
scrollFrame:SetPoint("TOPLEFT",     mjPanel, "TOPLEFT",     2,  -24)
scrollFrame:SetPoint("BOTTOMRIGHT", mjPanel, "BOTTOMRIGHT", -18,  4)
scrollFrame:EnableMouseWheel(true)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(scrollFrame:GetWidth())
content:SetHeight(1)
scrollFrame:SetScrollChild(content)

local scrollSlider = CreateFrame("Slider", nil, mjPanel)
scrollSlider:SetOrientation("VERTICAL")
scrollSlider:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT", -7, -30)
scrollSlider:SetPoint("BOTTOMRIGHT", mjPanel, "BOTTOMRIGHT", -7, 10)
scrollSlider:SetWidth(8)
scrollSlider:SetMinMaxValues(0, 0)
scrollSlider:SetValueStep(1)
scrollSlider:SetValue(0)

local track = scrollSlider:CreateTexture(nil, "BACKGROUND")
track:SetPoint("TOP", scrollSlider, "TOP", 0, 0)
track:SetPoint("BOTTOM", scrollSlider, "BOTTOM", 0, 0)
track:SetWidth(4)
track:SetColorTexture(0.10, 0.10, 0.10, 0.82)

local thumb = scrollSlider:CreateTexture(nil, "ARTWORK")
thumb:SetSize(10, 28)
thumb:SetColorTexture(0.46, 0.42, 0.32, 0.95)
scrollSlider:SetThumbTexture(thumb)
scrollSlider:Hide()

UpdateScrollRange = function()
    local viewportH = math.max(1, scrollFrame:GetHeight())
    local contentH = math.max(1, content:GetHeight())
    local maxScroll = math.max(0, contentH - viewportH)
    scrollSlider:SetMinMaxValues(0, maxScroll)
    scrollSlider:SetValueStep(20)

    if maxScroll <= 0 then
        scrollFrame:SetVerticalScroll(0)
        scrollSlider:SetValue(0)
        scrollSlider:Hide()
    else
        scrollSlider:Show()
        if scrollSlider:GetValue() > maxScroll then scrollSlider:SetValue(maxScroll) end
    end
end

scrollSlider:SetScript("OnValueChanged", function(_, value)
    scrollFrame:SetVerticalScroll(value or 0)
end)

scrollFrame:SetScript("OnMouseWheel", function(_, delta)
    local _, maxScroll = scrollSlider:GetMinMaxValues()
    if maxScroll <= 0 then return end
    local nextValue = scrollSlider:GetValue() - (delta * 34)
    scrollSlider:SetValue(math.max(0, math.min(maxScroll, nextValue)))
end)

-- ── Gestion des lignes ────────────────────────────────────────────────────────

local function GetImpactAmount()
    local amount = math.floor(tonumber(impactValueEB and impactValueEB:GetText() or "") or 0)
    if amount < 0 then amount = math.abs(amount) end
    return amount
end

local function SendImpact(playerName)
    local amount = GetImpactAmount()
    if amount <= 0 then
        if ShowImpactStatus then ShowImpactStatus("Valeur ?") end
        return false
    end

    if impactState.mode == "buff" then
        if playerName == UnitName("player") then
            C:AddTemp(impactState.stat, amount, true)
        elseif C.SendTempCmd then
            C:SendTempCmd(playerName, impactState.stat, amount)
        end
        return true
    end

    local delta = (impactState.mode == "damage") and -amount or amount
    if playerName == UnitName("player") then
        C:Delta(impactState.stat, delta, true)
    else
        C:SendModCmd(playerName, impactState.stat, delta)
    end
    return true
end

UpdateAllSelections = function()
    for name, row in pairs(rows) do
        if row.SetSelected then row:SetSelected(selectedPlayers[name]) end
    end
end

ApplyImpactToPlayer = function(playerName, forceApply)
    if not playerName or playerName == "" then return end

    if impactMultiCB and impactMultiCB:GetChecked() and not forceApply then
        selectedPlayers[playerName] = not selectedPlayers[playerName] or nil
        UpdateAllSelections()
        if ShowImpactStatus then
            local count = 0
            for _ in pairs(selectedPlayers) do count = count + 1 end
            ShowImpactStatus(tostring(count) .. " cible(s)")
        end
        return
    end

    if SendImpact(playerName) and ShowImpactStatus then
        ShowImpactStatus("Envoyé")
    end
end

SelectPlayerForImpact = function(playerName)
    if not playerName or playerName == "" then return end

    if impactMultiCB and impactMultiCB:GetChecked() then
        selectedPlayers[playerName] = not selectedPlayers[playerName] or nil
    else
        selectedPlayers = {}
        selectedPlayers[playerName] = true
    end

    UpdateAllSelections()

    if ShowImpactStatus then
        local count = 0
        for _ in pairs(selectedPlayers) do count = count + 1 end
        ShowImpactStatus(count > 0 and (tostring(count) .. " cible(s)") or "Aucune cible")
    end
end

local function GetVisibleMembers()
    local members, seen = {}, {}
    local myName = UnitName("player")

    local function Add(n)
        if n and n ~= "" and not seen[n] then seen[n] = true; table.insert(members, n) end
    end

    Add(myName)
    for name in pairs(C.groupData) do Add(name) end

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do Add(UnitName("raid"..i)) end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do Add(UnitName("party"..i)) end
    end

    table.sort(members)
    return members
end

local function Rebuild()
    local members = GetVisibleMembers()
    local myName  = UnitName("player")

    content:SetWidth(math.max(1, scrollFrame:GetWidth()))
    for _, row in pairs(rows) do row:Hide() end

    local totalH = 0
    for _, name in ipairs(members) do
        if not rows[name] then
            rows[name] = PlayerRow(content, name)
        end
        local row = rows[name]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -totalH)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -totalH)
        row:Show()

        local data = (name == myName) and C:GetMyChar() or C.groupData[name]
        row:Refresh(data)
        totalH = totalH + ROW_H + 2
    end

    content:SetHeight(math.max(1, totalH))
    UpdateScrollRange()
end

mjPanel._rebuild = Rebuild

-- ── Callbacks Core ────────────────────────────────────────────────────────────

local prevGroup = C.OnGroupDataChanged
C.OnGroupDataChanged = function(name)
    if prevGroup then prevGroup(name) end
    if not mjPanel:IsShown() then return end
    if rows[name] then
        rows[name]:Refresh(C.groupData[name])
    else
        Rebuild()
    end
end

local prevMine = C.OnMyDataChanged
C.OnMyDataChanged = function()
    if prevMine then prevMine() end
    if not mjPanel:IsShown() then return end
    local myName = UnitName("player")
    if rows[myName] then
        rows[myName]:Refresh(C:GetMyChar())
    else
        Rebuild()
    end
end

-- ── Toggle ────────────────────────────────────────────────────────────────────

mjPanel:SetScript("OnShow", function()
    local myName = UnitName("player")
    if myName then C.groupData[myName] = C:GetMyChar() end
    if impactPanel then
        impactPanel:ClearAllPoints()
        impactPanel:SetPoint("TOPRIGHT", mjPanel, "TOPLEFT", -2, 0)
        impactPanel:Show()
    end
    Rebuild()
end)

mjPanel:SetScript("OnHide", function()
    if impactPanel then impactPanel:Hide() end
end)

function mjPanel:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end
