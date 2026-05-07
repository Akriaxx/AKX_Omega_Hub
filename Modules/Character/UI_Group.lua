-- ============================================================
--  Character - Vue joueur compacte
--  /ocharview pour ouvrir
-- ============================================================

local C  = Character
local UI = OS2.UI

local W, PAD = 118, 4
local ROW_H = 40
local BAR_H = 9

local rows = {}
local selectedPlayers = {}
local selectedStat = "hp"
local selectedAction = "gain"
local panel, content, valueEB, statusFS, multiCB, applyBtn
local ShowGroupStatus

local COLORS = {
    hp        = { fg = {0.85, 0.15, 0.15, 1}, bg = {0.20, 0.04, 0.04, 1}, label = "HP" },
    mana      = { fg = {0.18, 0.42, 0.90, 1}, bg = {0.04, 0.11, 0.27, 1}, label = "Mana" },
    endurance = { fg = {0.10, 0.70, 0.20, 1}, bg = {0.03, 0.16, 0.05, 1}, label = "End." },
}

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

local function GetVisibleMembers()
    local members, seen = {}, {}
    local function Add(name)
        if name and name ~= "" and not seen[name] then
            seen[name] = true
            members[#members + 1] = name
        end
    end

    Add(MyName())
    for name in pairs(C.groupData or {}) do Add(name) end

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do Add(UnitNameShort("raid" .. i)) end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do Add(UnitNameShort("party" .. i)) end
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
    bg:SetColorTexture(0.06, 0.06, 0.06, 0.92)
    row.bg = bg

    local selectedTex = row:CreateTexture(nil, "BORDER")
    selectedTex:SetAllPoints()
    selectedTex:SetColorTexture(0.78, 0.62, 0.24, 0.18)
    selectedTex:Hide()
    row.selectedTex = selectedTex

    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -5)
    nameFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -5)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetWordWrap(false)
    UI.ApplyBodyText(nameFS)

    local barBg = row:CreateTexture(nil, "BORDER")
    barBg:SetPoint("LEFT", row, "LEFT", 6, -9)
    barBg:SetPoint("RIGHT", row, "RIGHT", -6, -9)
    barBg:SetHeight(BAR_H)
    barBg:SetColorTexture(COLORS.hp.bg[1], COLORS.hp.bg[2], COLORS.hp.bg[3], 1)

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", barBg, "LEFT", 0, 0)
    fill:SetHeight(BAR_H)
    fill:SetColorTexture(COLORS.hp.fg[1], COLORS.hp.fg[2], COLORS.hp.fg[3], 1)
    fill:SetWidth(1)

    local tempFill = row:CreateTexture(nil, "ARTWORK")
    tempFill:SetHeight(BAR_H)
    tempFill:SetColorTexture(0.95, 0.74, 0.20, 0.88)
    tempFill:SetWidth(1)
    tempFill:Hide()

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
        local hp = data and data.hp
        if not hp then
            fill:SetWidth(1)
            tempFill:Hide()
            row:SetSelected(selectedPlayers[playerName])
            return
        end

        local cur = tonumber(hp.cur) or 0
        local max = math.max(1, tonumber(hp.max) or 1)
        local temp = math.max(0, tonumber(hp.temp) or 0)
        local total = math.max(1, max + temp)
        local width = math.max(1, barBg:GetWidth() or (W - 8))
        local curW = math.max(1, width * math.max(0, math.min(1, cur / total)))
        fill:SetWidth(curW)

        if temp > 0 then
            tempFill:ClearAllPoints()
            tempFill:SetPoint("LEFT", barBg, "LEFT", curW, 0)
            tempFill:SetWidth(math.max(1, width * math.max(0, math.min(1, temp / total))))
            tempFill:Show()
        else
            tempFill:Hide()
        end
        row:SetSelected(selectedPlayers[playerName])
    end

    function row:SetSelected(selected)
        if selected then
            selectedTex:Show()
            bg:SetColorTexture(0.10, 0.085, 0.045, 0.96)
        else
            selectedTex:Hide()
            bg:SetColorTexture(0.06, 0.06, 0.06, 0.92)
        end
    end

    row:SetScript("PostClick", function(self, button)
        if button == "LeftButton" then
            SelectPlayer(self.playerName or name)
        end
    end)

    return row
end

local function CreateMiniDropdown(parent, width, labelText, items, getValue, setValue)
    return UI.CreateDropdown(parent, width, labelText, items, getValue, setValue)
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
    local y = -4
    for _, name in ipairs(members) do
        local row = rows[name] or MakeRow(content, name)
        rows[name] = row
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        row:Show()
        row:Refresh(name)
        y = y - ROW_H - 2
    end

    local listH = #members * (ROW_H + 2) + 2
    content:SetHeight(listH)
    panel:SetHeight(math.max(386, listH + 276))
end

local function Build()
    if panel then return panel end

    panel = CreateFrame("Frame", "CharacterGroupViewPanel", UIParent)
    panel:SetSize(W, 386)
    panel:SetPoint("CENTER", UIParent, "CENTER", -260, 0)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetFrameStrata("MEDIUM")
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg)

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
    titleFS:SetText("Vue joueur")
    UI.ApplyTitle(titleFS)

    local refreshBtn = UI.CreatePanelButton(panel, 18, 15, "R")
    refreshBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -22, -2)
    refreshBtn:SetFrameLevel(panel:GetFrameLevel() + 40)
    refreshBtn:SetScript("OnClick", function()
        C:RequestAll()
        Rebuild()
        if ShowGroupStatus then ShowGroupStatus("Maj") end
    end)

    local closeBtn = UI.CreateCloseButton(panel, function() panel:Hide() end)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -2)
    closeBtn:SetSize(18, 15)
    closeBtn:EnableMouse(true)
    closeBtn:RegisterForClicks("LeftButtonUp")
    closeBtn:SetFrameLevel(panel:GetFrameLevel() + 50)
    if closeBtn.label then
        closeBtn.label:SetText("x")
        closeBtn.label:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
        closeBtn.label:ClearAllPoints()
        closeBtn.label:SetAllPoints(closeBtn)
        closeBtn.label:SetJustifyH("CENTER")
        closeBtn.label:SetJustifyV("MIDDLE")
    end

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -19)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -19)
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)

    content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -26)
    content:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -26)

    local controls = CreateFrame("Frame", nil, panel)
    controls:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, 8)
    controls:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 8)
    controls:SetHeight(238)

    local controlSep = panel:CreateTexture(nil, "ARTWORK")
    controlSep:SetPoint("BOTTOMLEFT", controls, "TOPLEFT", 0, 6)
    controlSep:SetPoint("BOTTOMRIGHT", controls, "TOPRIGHT", 0, 6)
    controlSep:SetHeight(1)
    UI.ApplySeparator(controlSep, true)

    local valueLabel = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueLabel:SetPoint("TOPLEFT", controls, "TOPLEFT", 2, -2)
    valueLabel:SetText("Valeur")
    UI.ApplyLabel(valueLabel)

    valueEB = UI.CreateStyledEditBox(controls, W - PAD * 2, 22)
    valueEB:SetNumeric(true)
    valueEB:SetMaxLetters(5)
    valueEB:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -18)
    valueEB:SetText("8")

    local statDropdown = CreateMiniDropdown(controls, W - PAD * 2, "Ressource", {
        { value = "hp", label = "HP" },
        { value = "mana", label = "Mana" },
        { value = "endurance", label = "Endurance" },
    }, function() return selectedStat end, function(value) selectedStat = value end)
    statDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -58)

    local actionDropdown = CreateMiniDropdown(controls, W - PAD * 2, "Action", {
        { value = "damage", label = "Retrait" },
        { value = "gain", label = "Gain" },
        { value = "buff", label = "Buff temp." },
    }, function() return selectedAction end, function(value) selectedAction = value end)
    actionDropdown:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -118)

    multiCB = UI.CreateStyledCheckbox(controls, "Multicible")
    multiCB:SetPoint("TOPLEFT", controls, "TOPLEFT", 0, -174)
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

    applyBtn = UI.CreatePanelButton(controls, W - PAD * 2, 20, "Appliquer")
    applyBtn:SetPoint("BOTTOMLEFT", controls, "BOTTOMLEFT", 0, 18)
    applyBtn:SetPoint("BOTTOMRIGHT", controls, "BOTTOMRIGHT", 0, 18)
    applyBtn:SetScript("OnClick", ApplyToSelected)

    statusFS = controls:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 2, -2)
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
        if C_Timer and C_Timer.After then
            C_Timer.After(3, function()
                if token == statusToken and statusFS then
                    statusFS:SetText("")
                    statusFS:Hide()
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
