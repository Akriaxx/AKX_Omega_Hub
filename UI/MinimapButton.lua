-- ============================================================
--  Omega Hub — Bouton Minimap
--  Bouton rond autour de la minimap pour ouvrir/fermer le Hub.
--  Maintenir clic gauche + déplacer : repositionner.
--  Clic gauche rapide : toggle du panneau.
-- ============================================================

local Hub = OmegaHub
local UI  = OS2.UI

local RADIUS         = 80
local DEFAULT_ANGLE  = 225
local DRAG_THRESHOLD = 4

-- ── Helpers ────────────────────────────────────────────────────────────────

local function positionFromAngle(angle)
    local rad = math.rad(angle)
    return RADIUS * math.cos(rad), RADIUS * math.sin(rad)
end

local function setAngle(angle)
    local x, y = positionFromAngle(angle)
    OmegaHubMinimapBtn:ClearAllPoints()
    OmegaHubMinimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    if OmegaHubDB then
        OmegaHubDB.minimapAngle = angle
    end
end

-- ── Création du bouton ─────────────────────────────────────────────────────

local btn = CreateFrame("Button", "OmegaHubMinimapBtn", Minimap)
btn:SetSize(32, 32)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(8)

-- ── Fond sombre circulaire ─────────────────────────────────────────────────

local bgMask = btn:CreateMaskTexture()
bgMask:SetAllPoints(btn)
bgMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
                  "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(btn)
bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
bg:AddMaskTexture(bgMask)

-- ── Icône ──────────────────────────────────────────────────────────────────

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -3,  3)
icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  3, -3)
icon:SetTexture("Interface\\AddOns\\Omega_Hub\\UI\\Media\\Omega_Hub")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
btn.icon = icon

-- ── Highlight survol ───────────────────────────────────────────────────────

local hlMask = btn:CreateMaskTexture()
hlMask:SetAllPoints(btn)
hlMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
                  "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints(btn)
hl:SetColorTexture(1, 1, 1, 0.15)
hl:AddMaskTexture(hlMask)

-- ── Drag & Click ───────────────────────────────────────────────────────────

local dragging   = false
local dragStartX = 0
local dragStartY = 0

btn:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    dragging   = false
    dragStartX, dragStartY = GetCursorPosition()

    self:SetScript("OnUpdate", function()
        local cx, cy = GetCursorPosition()
        if not dragging then
            local dx = cx - dragStartX
            local dy = cy - dragStartY
            if math.abs(dx) > DRAG_THRESHOLD or math.abs(dy) > DRAG_THRESHOLD then
                dragging = true
            end
        end
        if dragging then
            local mx, my = Minimap:GetCenter()
            local scale  = UIParent:GetEffectiveScale()
            local angle  = math.deg(math.atan2((cy / scale) - my, (cx / scale) - mx))
            setAngle(angle)
        end
    end)
end)

btn:SetScript("OnMouseUp", function(self, button)
    self:SetScript("OnUpdate", nil)
    if button == "LeftButton" and not dragging then
        OmegaHubPanel:Toggle()
    end
    dragging = false
end)

-- ── Tooltip ────────────────────────────────────────────────────────────────

btn:SetScript("OnEnter", function(self)
    local title = UI.colors.title
    local body  = UI.colors.text
    local muted = UI.colors.textMuted
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Omega Hub",                      title[1], title[2], title[3])
    GameTooltip:AddLine("Clic gauche : ouvrir / fermer",  body[1],  body[2],  body[3])
    GameTooltip:AddLine("Maintenir + glisser : déplacer", muted[1], muted[2], muted[3])
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ── Position initiale ──────────────────────────────────────────────────────

local posFrame = CreateFrame("Frame")
posFrame:RegisterEvent("PLAYER_LOGIN")
posFrame:SetScript("OnEvent", function()
    local angle = (OmegaHubDB and OmegaHubDB.minimapAngle) or DEFAULT_ANGLE
    setAngle(angle)
    posFrame:UnregisterAllEvents()
end)

Hub.minimapBtn = btn
