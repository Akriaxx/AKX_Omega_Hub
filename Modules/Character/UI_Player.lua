-- ============================================================
--  Character - Fiche personnelle moderne
--  /ochar pour ouvrir
-- ============================================================

local C  = Character
local UI = OS2.UI

local COLORS = {
    hp   = { fg = {0.85, 0.15, 0.15, 1}, bg = {0.20, 0.04, 0.04, 1}, label = "HP" },
    mana = { fg = {0.12, 0.38, 0.95, 1}, bg = {0.03, 0.08, 0.22, 1}, label = "MP" },
    endurance = { fg = {0.10, 0.70, 0.20, 1}, bg = {0.03, 0.16, 0.05, 1}, label = "END" },
}

local PANEL_W, PANEL_H = 302, 78
local GAUGE_H = 16
local SIDE_PAD = 3

local function MakeTitleBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT")
    bar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -50, 0)  -- laisse la zone des boutons libre
    bar:SetHeight(26)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then parent:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function() parent:StopMovingOrSizing() end)
    return bar
end

local function MakeGauge(parent, key, y)
    local cfg = COLORS[key]
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDE_PAD, y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -SIDE_PAD, y)
    row:SetHeight(GAUGE_H)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(cfg.bg[1], cfg.bg[2], cfg.bg[3], 0.96)

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT")
    fill:SetPoint("BOTTOMLEFT")
    fill:SetWidth(1)
    fill:SetColorTexture(cfg.fg[1], cfg.fg[2], cfg.fg[3], 0.95)

    local tempFill = row:CreateTexture(nil, "ARTWORK")
    tempFill:SetPoint("TOPLEFT")
    tempFill:SetPoint("BOTTOMLEFT")
    tempFill:SetWidth(1)
    tempFill:SetColorTexture(0.95, 0.74, 0.20, 0.88)
    tempFill:Hide()

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 6, 0)
    label:SetWidth(34)
    label:SetJustifyH("LEFT")
    label:SetText(cfg.label)
    label:SetTextColor(0.95, 0.88, 0.56, 1)

    local rParen = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    rParen:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    rParen:SetText(")")
    UI.ApplyMutedText(rParen)

    local tempEB = UI.CreateStyledEditBox(row, 40, 14)
    tempEB:SetNumeric(true)
    tempEB:SetMaxLetters(5)
    tempEB:SetPoint("RIGHT", rParen, "LEFT", -1, 0)

    local lParen = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lParen:SetPoint("RIGHT", tempEB, "LEFT", -1, 0)
    lParen:SetText("(")
    UI.ApplyMutedText(lParen)

    local maxEB = UI.CreateStyledEditBox(row, 40, 14)
    maxEB:SetNumeric(true)
    maxEB:SetMaxLetters(7)
    maxEB:SetPoint("RIGHT", lParen, "LEFT", -4, 0)

    local slash = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slash:SetPoint("RIGHT", maxEB, "LEFT", -2, 0)
    slash:SetText("/")
    UI.ApplyMutedText(slash)

    local curEB = UI.CreateStyledEditBox(row, 40, 14)
    curEB:SetMaxLetters(7)
    curEB:SetPoint("RIGHT", slash, "LEFT", -2, 0)

    local function ApplyCurInput(self)
        local text = self:GetText() or ""
        local baseText, op, amountText = text:match("^%s*(%d+)%s*([%+%-])%s*(%d+)%s*$")
        if baseText and op and amountText then
            local base = tonumber(baseText) or 0
            local amount = tonumber(amountText) or 0
            if op == "-" then amount = -amount end
            local max = math.max(1, tonumber(row.maxValue) or 1)
            local nextValue = math.max(0, math.min(max, base + amount))
            C:SetCur(key, nextValue)
            self:SetText(tostring(nextValue))
            return
        end

        local sign, deltaText = text:match("^%s*([%+%-])%s*(%d+)%s*$")
        if sign and deltaText then
            local delta = tonumber(deltaText) or 0
            if sign == "-" then delta = -delta end
            local cur = tonumber(row.curValue) or 0
            local max = math.max(1, tonumber(row.maxValue) or 1)
            local nextValue = math.max(0, math.min(max, cur + delta))
            C:SetCur(key, nextValue)
            self:SetText(tostring(nextValue))
            return
        end

        local v = tonumber(text)
        if v then
            local max = math.max(1, tonumber(row.maxValue) or 1)
            local nextValue = math.max(0, math.min(max, v))
            C:SetCur(key, nextValue)
            self:SetText(tostring(nextValue))
        end
    end

    curEB:SetScript("OnEnterPressed", function(self)
        ApplyCurInput(self)
        self:ClearFocus()
    end)
    curEB:SetScript("OnEditFocusLost", function(self)
        ApplyCurInput(self)
    end)

    maxEB:SetScript("OnEnterPressed", function(self)
        C:SetMax(key, self:GetText())
        self:ClearFocus()
    end)
    maxEB:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText())
        if v then C:SetMax(key, v) end
    end)

    tempEB:SetScript("OnEnterPressed", function(self)
        C:SetTemp(key, self:GetText())
        self:ClearFocus()
    end)
    tempEB:SetScript("OnEditFocusLost", function(self)
        C:SetTemp(key, self:GetText())
    end)

    function row:Refresh(cur, max, temp)
        temp = math.max(0, tonumber(temp) or 0)
        row.curValue = cur
        row.maxValue = max
        if not curEB:HasFocus() then curEB:SetText(tostring(cur)) end
        if not maxEB:HasFocus() then maxEB:SetText(tostring(max)) end
        if not tempEB:HasFocus() then tempEB:SetText(temp > 0 and tostring(temp) or "") end
        local width = row:GetWidth() or 1
        local total = math.max(1, max + temp)
        local curRatio = math.max(0, math.min(1, cur / total))
        local tempRatio = math.max(0, math.min(1, temp / total))
        local curW = math.max(1, width * curRatio)
        fill:SetWidth(curW)

        if temp > 0 then
            tempFill:ClearAllPoints()
            tempFill:SetPoint("TOPLEFT", row, "TOPLEFT", curW, 0)
            tempFill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", curW, 0)
            tempFill:SetWidth(math.max(1, width * tempRatio))
            tempFill:Show()
        else
            tempFill:Hide()
        end
    end

    return row
end

local panel = CreateFrame("Frame", "CharacterPlayerPanel", UIParent)
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:EnableMouse(true)
panel:SetFrameStrata("MEDIUM")
panel:Hide()

local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
UI.ApplyWindowBackground(bg)
panel.bg = bg

local function MakeBorder(edge)
    local tex = panel:CreateTexture(nil, "BORDER")
    tex:SetColorTexture(0.80, 0.70, 0.40, 0.22)
    if edge == "TOP" then
        tex:SetPoint("TOPLEFT")
        tex:SetPoint("TOPRIGHT")
        tex:SetHeight(1)
    elseif edge == "BOTTOM" then
        tex:SetPoint("BOTTOMLEFT")
        tex:SetPoint("BOTTOMRIGHT")
        tex:SetHeight(1)
    elseif edge == "LEFT" then
        tex:SetPoint("TOPLEFT")
        tex:SetPoint("BOTTOMLEFT")
        tex:SetWidth(1)
    else
        tex:SetPoint("TOPRIGHT")
        tex:SetPoint("BOTTOMRIGHT")
        tex:SetWidth(1)
    end
    return tex
end

MakeBorder("TOP")
MakeBorder("BOTTOM")
MakeBorder("LEFT")
MakeBorder("RIGHT")

MakeTitleBar(panel)
UI.CreateCloseButton(panel, function() panel:Hide() end)

-- Bouton paramètres (à gauche du bouton fermeture)
local gearBtn = CreateFrame("Button", nil, panel)
gearBtn:SetSize(16, 16)
gearBtn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -28, -8)
gearBtn:SetFrameLevel(panel:GetFrameLevel() + 10)
gearBtn:EnableMouse(true)
gearBtn:RegisterForClicks("AnyButtonUp")

local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
gearTex:SetAllPoints()
gearTex:SetTexture("Interface/Icons/INV_Misc_Gear_01")
gearTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

local gearHL = gearBtn:CreateTexture(nil, "HIGHLIGHT")
gearHL:SetTexture("Interface/Buttons/ButtonHilight-Square")
gearHL:SetAllPoints()
gearHL:SetBlendMode("ADD")

gearBtn:SetScript("OnClick", function()
    if C.ToggleSettings then C:ToggleSettings() end
end)

local nameText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
nameText:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
nameText:SetPoint("RIGHT", panel, "RIGHT", -48, 0)
nameText:SetJustifyH("LEFT")
nameText:SetWordWrap(false)
UI.ApplyTitle(nameText)

local titleSep = panel:CreateTexture(nil, "ARTWORK")
titleSep:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -25)
titleSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -25)
titleSep:SetHeight(1)
UI.ApplySeparator(titleSep, true)

local hpRow  = MakeGauge(panel, "hp", -29)
local mpRow  = MakeGauge(panel, "mana", -45)
local endRow = MakeGauge(panel, "endurance", -61)

local function Refresh()
    local ch = C:GetMyChar()
    nameText:SetText(C.GetDisplayName and C:GetDisplayName(UnitName("player"), ch) or UnitName("player") or "Personnage")
    hpRow:Refresh(ch.hp.cur, ch.hp.max, ch.hp.temp)
    mpRow:Refresh(ch.mana.cur, ch.mana.max, ch.mana.temp)
    endRow:Refresh(ch.endurance.cur, ch.endurance.max, ch.endurance.temp)
end

C.OnMyDataChanged = Refresh
panel:SetScript("OnShow", Refresh)

function panel:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        Refresh()
        self:Show()
    end
end
