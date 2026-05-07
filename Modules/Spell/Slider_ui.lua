-- OmegaSpell - Slider_ui.lua
-- Poignée de redimensionnement : texture WoW native, teintée aux couleurs de l'addon.

OmegaSpell        = OmegaSpell or {}
OmegaSpell.SliderUI = OmegaSpell.SliderUI or {}

local SliderUI = OmegaSpell.SliderUI

function SliderUI.CreateResizeGrip(parent, size)
    size = size or 16
    local grip = CreateFrame("Button", nil, parent)
    grip:SetSize(size, size)
    grip:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)

    -- #CCB366
    local r, g, b = 0.80, 0.70, 0.40

    local tex = grip:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    tex:SetVertexColor(r, g, b, 1.0)
    grip:SetNormalTexture(tex)

    local texHL = grip:CreateTexture(nil, "HIGHLIGHT")
    texHL:SetAllPoints()
    texHL:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    texHL:SetVertexColor(1.0, 0.88, 0.50, 1.0)
    grip:SetHighlightTexture(texHL)

    return grip
end
