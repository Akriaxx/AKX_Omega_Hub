-- OmegaSpell - Launcher.lua
-- Bouton flottant indépendant pour ouvrir l'interface OmegaSpell.
-- Clic gauche : toggle UI sorts
-- Clic droit  : toggle gestionnaire de barres
-- Maintenir + glisser : repositionner

OmegaSpell = OmegaSpell or {}

local OS  = OmegaSpell
local HUI = OS2.UI

local BTN_SIZE  = 36
local ICON_TEX  = "Interface\\Icons\\Spell_Arcane_Blast"

-- ── Cadre ─────────────────────────────────────────────────────────────────────

local btn = CreateFrame("Button", "OmegaSpellLauncherBtn", UIParent)
btn:SetSize(BTN_SIZE, BTN_SIZE)
btn:SetPoint("CENTER", UIParent, "CENTER", 0, -300)
btn:SetFrameStrata("MEDIUM")
btn:SetFrameLevel(50)
btn:SetMovable(true)
btn:EnableMouse(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

-- Fond sombre circulaire
local bgMask = btn:CreateMaskTexture()
bgMask:SetAllPoints(btn)
bgMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local bg = btn:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(btn)
bg:SetColorTexture(0.05, 0.05, 0.05, 0.92)
bg:AddMaskTexture(bgMask)

-- Icône
local iconMask = btn:CreateMaskTexture()
iconMask:SetAllPoints(btn)
iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetPoint("TOPLEFT",     btn, "TOPLEFT",      2, -2)
icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2,  2)
icon:SetTexture(ICON_TEX)
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon:SetVertexColor(0.80, 0.70, 0.40, 1.0)   -- teinte #CCB366
icon:AddMaskTexture(iconMask)

-- Bordure dorée fine
local rim = btn:CreateTexture(nil, "OVERLAY")
rim:SetAllPoints(btn)
rim:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
rim:SetVertexColor(0.80, 0.70, 0.40, 0.35)

-- Highlight survol
local hlMask = btn:CreateMaskTexture()
hlMask:SetAllPoints(btn)
hlMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
    "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local hl = btn:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints(btn)
hl:SetColorTexture(1, 1, 1, 0.18)
hl:AddMaskTexture(hlMask)

-- ── Drag & Click ──────────────────────────────────────────────────────────────
-- Utilise le système natif OnDragStart/OnDragStop : la souris est capturée
-- au niveau moteur WoW, donc même si elle sort du bouton à grande vitesse,
-- StopMovingOrSizing() est toujours appelé à la remontée du bouton.

btn:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if OmegaSpellDB then
        OmegaSpellDB.launcher = { point = point, relPoint = relPoint, x = x, y = y }
    end
end)

btn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if OS.UI and OS.UI.Open then
            OS.UI.Open()
        end
    elseif button == "RightButton" then
        if OS.Bar and OS.Bar.OpenManager then
            OS.Bar.OpenManager()
        end
    end
end)

-- ── Tooltip ───────────────────────────────────────────────────────────────────

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Omega Spell", 0.80, 0.70, 0.40)
    GameTooltip:AddLine("Clic gauche : interface des sorts",   0.75, 0.75, 0.75)
    GameTooltip:AddLine("Clic droit : gestionnaire de barres", 0.75, 0.75, 0.75)
    GameTooltip:AddLine("Maintenir + glisser : déplacer",      0.55, 0.55, 0.55)
    GameTooltip:Show()
end)

btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ── Init : restaure la position sauvegardée ───────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if OmegaSpellDB and OmegaSpellDB.launcher then
        local p = OmegaSpellDB.launcher
        btn:ClearAllPoints()
        btn:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or -300)
    end
    initFrame:UnregisterAllEvents()
end)

OS.Launcher = btn
