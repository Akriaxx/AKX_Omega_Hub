-- ============================================================
--  Zone Gate — Effets Arcanum de région
--  Petit cadre visible tant que le joueur se trouve dans une
--  région liée à un sort Arcanum (voir ArcEnter dans Core.lua).
--  Il permet de retirer l'effet sur place, puis de le remettre ;
--  la sortie de la région le retire de toute façon.
-- ============================================================

local ZG = ZoneGate
local UI = ZG.EditorUI or OS2.UI

local ROW_H = 26
local W     = 260

local widget = CreateFrame("Frame", "ZoneGateArcWidget", UIParent)
widget:SetSize(W, 30)
widget:SetPoint("TOP", UIParent, "TOP", 0, -150)
widget:SetFrameStrata("MEDIUM")
widget:SetMovable(true)
widget:SetClampedToScreen(true)
widget:EnableMouse(true)
widget:RegisterForDrag("LeftButton")
widget:SetScript("OnDragStart", widget.StartMoving)
widget:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ZoneGateCharDB = ZoneGateCharDB or {}
    ZoneGateCharDB.arcWidgetPos = { point, relPoint, x, y }
end)
widget:Hide()
UI.Surface(widget, true)

local title = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
title:SetPoint("TOPLEFT", 10, -8)
title:SetText("Effet de région")
UI.ApplyLabel(title)

local rows = {}

local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, widget)
    row:SetSize(W - 16, ROW_H)
    row:SetPoint("TOPLEFT", 8, -24 - (i - 1) * ROW_H)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.label:SetPoint("LEFT", 2, 0)
    row.label:SetWidth(W - 112)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)

    row.button = UI.CreatePanelButton(row, 88, 22, "")
    row.button:SetPoint("RIGHT", 0, 0)
    row.button:SetScript("OnClick", function(self)
        if self.subId then ZG:ArcSetActive(self.subId, self.makeActive) end
    end)
    rows[i] = row
    return row
end

-- Avec un sort de sortie : Retirer ↔ Remettre. Sans : seulement Remettre
-- (relance l'effet si le joueur l'a retiré par un autre moyen).
function ZG:RefreshArcWidget()
    local shown = 0
    for _, effect in ipairs(ZG:GetArcEffects()) do
        if effect.canToggle then
            shown = shown + 1
            local row = GetRow(shown)
            local removable = effect.active and effect.applied and effect.canRemove
            row.label:SetText(effect.active and effect.name or ("|cff888888" .. effect.name .. "|r"))
            row.button:SetText(removable and "Retirer" or ((effect.active and effect.applied) and "Relancer" or "Remettre"))
            row.button.subId = effect.id
            row.button.makeActive = not removable
            row:Show()
        end
    end
    for i = shown + 1, #rows do rows[i]:Hide() end
    widget:SetHeight(30 + shown * ROW_H)
    widget:SetShown(shown > 0)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    local pos = ZoneGateCharDB and ZoneGateCharDB.arcWidgetPos
    if pos then
        widget:ClearAllPoints()
        widget:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
end)
