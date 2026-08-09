-- ============================================================
--  Tech — App INVENTORY : objets par catégorie
-- ============================================================

local T  = Tech
local UI = OS2.UI
local C  = T.colors

local PAD    = 14
local ROW_H  = 30
local LIST_H = 340

local body = T:RegisterApp({
    key   = "inventory",
    label = "Inventory",
    icon  = "Interface\\Icons\\INV_Misc_Bag_10",
    color = { 0.42, 0.30, 0.10 },
})

local CATEGORIES = {
    { key = "heirlooms", label = "Heirlooms" },
    { key = "artifacts", label = "Artifacts" },
    { key = "tomes",     label = "Tomes"     },
}
local currentCategory = "heirlooms"

-- ── Onglets de catégorie ───────────────────────────────────────────────────

local catRow = CreateFrame("Frame", nil, body)
catRow:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -PAD)
catRow:SetSize(3 * 116, 24)

local catButtons = {}

local function CreateCatButton(label)
    local btn = CreateFrame("Button", nil, catRow)
    btn:SetSize(110, 24)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.10, 0.10, 0.9)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints()
    lbl:SetText(label)
    lbl:SetTextColor(unpack(C.text))

    local underline = btn:CreateTexture(nil, "ARTWORK")
    underline:SetHeight(2)
    underline:SetPoint("BOTTOMLEFT")
    underline:SetPoint("BOTTOMRIGHT")
    underline:SetColorTexture(unpack(C.active))
    underline:Hide()
    btn.underline = underline

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.06)

    return btn
end

for i, cat in ipairs(CATEGORIES) do
    local btn = CreateCatButton(cat.label)
    btn:SetPoint("LEFT", catRow, "LEFT", (i - 1) * 116, 0)
    btn:SetScript("OnClick", function()
        currentCategory = cat.key
        for k, b in pairs(catButtons) do b.underline:SetShown(k == cat.key) end
        T:RefreshInventoryList()
    end)
    catButtons[cat.key] = btn
end
catButtons[currentCategory].underline:Show()

-- ── Saisie ─────────────────────────────────────────────────────────────────

local input = UI.CreateStyledEditBox(body, 230, 22, false)
input:SetPoint("TOPLEFT", catRow, "BOTTOMLEFT", 0, -14)

local function SubmitItem()
    if input:GetText() ~= "" then
        T:AddInventoryItem(currentCategory, input:GetText())
        input:SetText("")
    end
    input:ClearFocus()
end

local addBtn = UI.CreateAddButton(body, SubmitItem)
addBtn:SetPoint("LEFT", input, "RIGHT", 6, 0)
input:SetScript("OnEnterPressed", SubmitItem)

local sep = body:CreateTexture(nil, "ARTWORK")
sep:SetHeight(1)
sep:SetPoint("TOPLEFT", input, "BOTTOMLEFT", -2, -12)
sep:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, 0)
sep:SetColorTexture(unpack(C.accentDim))

-- ── Liste ──────────────────────────────────────────────────────────────────

local scroll, content = T.CreateScrollList(body, LIST_H)
scroll:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 2, -10)
scroll:SetPoint("RIGHT", body, "RIGHT", -PAD, 0)
scroll:SetHeight(LIST_H)

local rows = {}

local function BuildRow(index, item)
    local row = rows[index]
    if not row then
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)

        local delBtn = T.CreateDeleteButton(row)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.delBtn = delBtn

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameFS:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
        nameFS:SetJustifyH("LEFT")
        row.nameFS = nameFS

        rows[index] = row
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    row.nameFS:SetText(item.name or "")
    row.nameFS:SetTextColor(unpack(C.text))
    row.delBtn:SetScript("OnClick", function()
        T:RemoveInventoryItem(currentCategory, index)
    end)
    row:Show()
    return row
end

function T:RefreshInventoryList()
    local db = T:GetDB()
    local list = db.inventory[currentCategory] or {}
    for i, item in ipairs(list) do
        BuildRow(i, item)
    end
    for i = #list + 1, #rows do
        rows[i]:Hide()
    end
    content:SetHeight(math.max(LIST_H, #list * ROW_H))
end

T:RefreshInventoryList()
