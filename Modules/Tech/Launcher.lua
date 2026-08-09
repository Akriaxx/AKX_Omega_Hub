-- ============================================================
--  Tech — Bouton d'interface indépendant
--  Clic gauche : ouvre/ferme la tablette
-- ============================================================

local T = Tech
local C = T.colors

local BTN_SIZE       = 40
local DRAG_THRESHOLD = 4
local DEFAULT_POINT  = { point = "CENTER", relPoint = "CENTER", x = 60, y = -40 }
local ICON           = "Interface\\Icons\\INV_Misc_Gizmo_01"

local btn = CreateFrame("Button", "TechLauncherBtn", UIParent)
btn:SetSize(BTN_SIZE, BTN_SIZE)
btn:SetPoint(DEFAULT_POINT.point, UIParent, DEFAULT_POINT.relPoint, DEFAULT_POINT.x, DEFAULT_POINT.y)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(50)
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:Hide()

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.02, 0.05, 0.05, 0.94)

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
icon:SetTexture(ICON)

local border = CreateFrame("Frame", nil, btn, "BackdropTemplate")
border:SetAllPoints()
border:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
})
border:SetBackdropBorderColor(unpack(C.accent))

local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints()
hl:SetColorTexture(1, 1, 1, 0.15)

local dragging = false
local startX, startY = 0, 0

local function SavePosition(self)
    TechDB = TechDB or {}
    local point, _, relPoint, x, y = self:GetPoint()
    TechDB.launcher = { point = point, relPoint = relPoint, x = x, y = y }
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
        if TechMainPanel then TechMainPanel:Toggle() end
    end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Omega Tech", 0.55, 0.98, 0.85)
    GameTooltip:AddLine("Clic gauche : ouvrir la tablette", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Maintenir + glisser : déplacer", 0.55, 0.55, 0.55)
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

function T:ResetLauncherPosition(showButton)
    TechDB = TechDB or {}
    TechDB.launcher = {
        point    = DEFAULT_POINT.point,
        relPoint = DEFAULT_POINT.relPoint,
        x        = DEFAULT_POINT.x,
        y        = DEFAULT_POINT.y,
    }

    btn:ClearAllPoints()
    btn:SetPoint(DEFAULT_POINT.point, UIParent, DEFAULT_POINT.relPoint, DEFAULT_POINT.x, DEFAULT_POINT.y)

    if showButton then
        btn:Show()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    TechDB = TechDB or {}
    local p = TechDB.launcher
    if p then
        btn:ClearAllPoints()
        btn:SetPoint(p.point or DEFAULT_POINT.point, UIParent, p.relPoint or DEFAULT_POINT.relPoint, p.x or DEFAULT_POINT.x, p.y or DEFAULT_POINT.y)
    end
    if OmegaHub and OmegaHub.IsModuleEnabled and OmegaHub:IsModuleEnabled("Tech") then
        btn:Show()
    end
    initFrame:UnregisterEvent("PLAYER_LOGIN")
end)

T.Launcher = btn
