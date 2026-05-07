OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

local UI = OS2.UI or {}

local PANEL_W = 220
local PANEL_H = 214
local PAD = 14
local ROW_H = 24

local function CopyItems(items)
    local copied = {}
    for index, item in ipairs(items or {}) do
        copied[index] = item
    end
    return copied
end

local function MoveEntry(items, fromIndex, toIndex)
    if fromIndex == toIndex or not items[fromIndex] or not items[toIndex] then
        return items
    end

    local moved = table.remove(items, fromIndex)
    table.insert(items, toIndex, moved)
    return items
end

local function GetItemLabel(item)
    return (item and (item.dbLabel or item.label)) or ""
end

function OS2.DB.CreateTabOrderPanel(deps)
    deps = deps or {}

    local getItems = deps.getItems
    local saveOrder = deps.saveOrder
    local onChanged = deps.onChanged
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(90)
    panel:Hide()

    if OS2.AttachOverlayFade then
        OS2.AttachOverlayFade(panel)
    end

    do
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        UI.ApplyWindowBackground(bg, (OS2.EnsureDB and OS2.EnsureDB().panelOpacity) or 0.65)
        if OS2.RegisterWindowFrame then
            OS2.RegisterWindowFrame(panel, bg)
        end
    end

    do
        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", panel, "TOP", 0, -13)
        title:SetText("Ordre des catégories")
        UI.ApplyTitle(title)
    end

    UI.CreateCloseButton(panel, function()
        if OS2.HideSettingsPanel then
            OS2.HideSettingsPanel(panel)
        else
            panel:Hide()
        end
    end)

    do
        local sep = panel:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(sep)
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -36)
        sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -36)
    end

    local help = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    help:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -48)
    help:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -48)
    help:SetJustifyH("LEFT")
    help:SetJustifyV("TOP")
    help:SetText("Glissez-déposez les catégories pour modifier leur ordre d'affichage.")
    UI.ApplySoftText(help)

    local listAnchor = CreateFrame("Frame", nil, panel)
    listAnchor:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -88)
    listAnchor:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -88)
    listAnchor:SetHeight(1)

    local rows = {}
    local dragIndex

    local function ApplyOrderFromRows(targetIndex)
        if not dragIndex or dragIndex == targetIndex then
            return
        end

        local items = CopyItems(getItems and getItems() or {})
        if not items[dragIndex] or not items[targetIndex] then
            return
        end

        MoveEntry(items, dragIndex, targetIndex)

        local orderedKeys = {}
        for _, item in ipairs(items) do
            orderedKeys[#orderedKeys + 1] = item.key
        end

        if saveOrder then
            saveOrder(orderedKeys)
        end

        if onChanged then
            onChanged(orderedKeys)
        end
    end

    local function RefreshRows()
        local items = CopyItems(getItems and getItems() or {})
        local visibleCount = 0

        for index, item in ipairs(items) do
            local row = rows[index]
            if not row then
                row = UI.CreatePanelButton(panel, PANEL_W - PAD * 2, ROW_H, "")
                row.label:ClearAllPoints()
                row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
                row.label:SetPoint("RIGHT", row, "RIGHT", -22, 0)
                row.label:SetJustifyH("LEFT")

                local grip = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                grip:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                grip:SetText("|||")
                UI.ApplyMutedText(grip)
                row.grip = grip

                row:RegisterForDrag("LeftButton")
                row:SetScript("OnDragStart", function(self)
                    dragIndex = self.index
                    self:SetAlpha(0.65)
                end)
                row:SetScript("OnDragStop", function(self)
                    local targetIndex
                    self:SetAlpha(1)

                    for _, other in ipairs(rows) do
                        if other:IsShown() and other:IsMouseOver() then
                            targetIndex = other.index
                            break
                        end
                    end

                    ApplyOrderFromRows(targetIndex)
                    dragIndex = nil
                    RefreshRows()
                end)

                rows[index] = row
            end

            row.index = index
            row:SetPoint("TOPLEFT", listAnchor, "TOPLEFT", 0, -visibleCount * (ROW_H + 6))
            row:SetText(GetItemLabel(item))
            row:SetShown(true)
            visibleCount = visibleCount + 1
        end

        for index = visibleCount + 1, #rows do
            rows[index]:Hide()
        end

        panel:SetHeight(math.max(PANEL_H, 102 + visibleCount * (ROW_H + 6)))
    end

    panel.Refresh = RefreshRows
    panel:HookScript("OnShow", RefreshRows)

    return panel
end
