-- ============================================================
--  Character - Bouton d'interface indépendant
--  Clic gauche : fiche personnage
--  Clic droit  : vue MJ
-- ============================================================

local C = Character

local BTN_SIZE       = 44
local DRAG_THRESHOLD = 4
local DEFAULT_POINT  = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }

local btn = CreateFrame("Button", "CharacterLauncherBtn", UIParent)
btn:SetSize(BTN_SIZE, BTN_SIZE)
btn:SetPoint(DEFAULT_POINT.point, UIParent, DEFAULT_POINT.relPoint, DEFAULT_POINT.x, DEFAULT_POINT.y)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(50)
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:Hide()

local bgMask = btn:CreateMaskTexture()
bgMask:SetAllPoints(btn)
bgMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(btn)
bg:SetColorTexture(0.04, 0.04, 0.04, 0.94)
bg:AddMaskTexture(bgMask)

local iconMask = btn:CreateMaskTexture()
iconMask:SetAllPoints(btn)
iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
icon:SetTexCoord(0, 1, 0, 1)
icon:AddMaskTexture(iconMask)

local portraitRetry = false
local function RefreshPortrait(forceRetry)
    if SetPortraitTexture and UnitExists and UnitExists("player") then
        icon:SetTexture(nil)
        local ok = pcall(SetPortraitTexture, icon, "player")
        if ok and icon:GetTexture() then
            icon:SetTexCoord(0, 1, 0, 1)
            portraitRetry = false
            return
        end
    end

    if C_Timer and C_Timer.After and not portraitRetry and forceRetry ~= false then
        portraitRetry = true
        C_Timer.After(0.35, function() RefreshPortrait(false) end)
    else
        icon:SetTexture("Interface\\Icons\\Achievement_Character_Human_Male")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local rim = btn:CreateTexture(nil, "OVERLAY")
rim:SetAllPoints(btn)
rim:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
rim:SetVertexColor(0.80, 0.70, 0.40, 0.16)

local hlMask = btn:CreateMaskTexture()
hlMask:SetAllPoints(btn)
hlMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints(btn)
hl:SetColorTexture(1, 1, 1, 0.18)
hl:AddMaskTexture(hlMask)

local dragging = false
local startX, startY = 0, 0

local function SavePosition(self)
    CharacterDB = CharacterDB or {}
    local point, _, relPoint, x, y = self:GetPoint()
    CharacterDB.launcher = { point = point, relPoint = relPoint, x = x, y = y }
end

function C:SetLauncherSize(size, save)
    size = math.max(28, math.min(72, math.floor((tonumber(size) or BTN_SIZE) + 0.5)))
    btn:SetSize(size, size)
    RefreshPortrait(false)

    if save ~= false then
        CharacterDB = CharacterDB or {}
        CharacterDB.settings = CharacterDB.settings or {}
        CharacterDB.settings.launcherSize = size
    end
end

function C:ResetLauncherPosition(showButton)
    CharacterDB = CharacterDB or {}
    CharacterDB.launcher = {
        point = DEFAULT_POINT.point,
        relPoint = DEFAULT_POINT.relPoint,
        x = DEFAULT_POINT.x,
        y = DEFAULT_POINT.y,
    }

    btn:ClearAllPoints()
    btn:SetPoint(DEFAULT_POINT.point, UIParent, DEFAULT_POINT.relPoint, DEFAULT_POINT.x, DEFAULT_POINT.y)

    if showButton then
        btn:Show()
    end
end

btn:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    dragging = false
    startX, startY = GetCursorPosition()

    self:SetScript("OnUpdate", function()
        local x, y = GetCursorPosition()
        if not dragging and (math.abs(x - startX) > DRAG_THRESHOLD or math.abs(y - startY) > DRAG_THRESHOLD) then
            dragging = true
            self:StartMoving()
        end
    end)
end)

btn:SetScript("OnMouseUp", function(self, button)
    self:SetScript("OnUpdate", nil)

    if dragging then
        self:StopMovingOrSizing()
        SavePosition(self)
        dragging = false
        return
    end

    if button == "LeftButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then
            if C.ToggleGroupView then C:ToggleGroupView() end
            return
        end
        if CharacterPlayerPanel then CharacterPlayerPanel:Toggle() end
    elseif button == "RightButton" then
        if IsShiftKeyDown and IsShiftKeyDown() then
            if C.ToggleSettings then C:ToggleSettings() end
            return
        end
        if CharacterMJPanel then CharacterMJPanel:Toggle() end
    end
end)

btn:SetScript("OnEnter", function(self)
    RefreshPortrait()
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Character", 0.80, 0.70, 0.40)
    GameTooltip:AddLine("Clic gauche : fiche personnage", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Shift + clic gauche : vue joueur", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Clic droit : vue MJ", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Shift + clic droit : paramètres", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Maintenir + glisser : déplacer", 0.55, 0.55, 0.55)
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

btn:SetScript("OnShow", function()
    RefreshPortrait()
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
initFrame:RegisterEvent("UNIT_MODEL_CHANGED")
initFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED" then
        if unit and unit ~= "player" then return end
    end

    RefreshPortrait()
    if C.ApplyDisplaySettings then C:ApplyDisplaySettings() end
    CharacterDB = CharacterDB or {}
    local p = CharacterDB.launcher
    if p then
        btn:ClearAllPoints()
        btn:SetPoint(p.point or DEFAULT_POINT.point, UIParent, p.relPoint or DEFAULT_POINT.relPoint, p.x or DEFAULT_POINT.x, p.y or DEFAULT_POINT.y)
    end
    if OmegaHub and OmegaHub.IsModuleEnabled and OmegaHub:IsModuleEnabled("Character") then
        btn:Show()
    end
    if event == "PLAYER_LOGIN" then
        initFrame:UnregisterEvent("PLAYER_LOGIN")
    end
end)

C.Launcher = btn
