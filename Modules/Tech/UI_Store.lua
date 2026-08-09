-- ============================================================
--  Tech — App STORE : faux App Store décoratif
-- ============================================================

local T  = Tech
local UI = OS2.UI
local C  = T.colors

local PAD    = 14
local ROW_H  = 56
local LIST_H = 440

local store = T:RegisterApp({
    key   = "store",
    label = "Store",
    icon  = "Interface\\Icons\\INV_Misc_Coin_01",
    color = { 0.28, 0.20, 0.46 },
    dock  = true,
})

local sub = store:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sub:SetPoint("TOPLEFT", store, "TOPLEFT", PAD, -PAD)
sub:SetPoint("RIGHT", store, "RIGHT", -PAD, 0)
sub:SetJustifyH("LEFT")
sub:SetText("Catalogue d'applications compatibles NEO-DATAPAD.")
sub:SetTextColor(unpack(C.textMuted))

local scroll, content = T.CreateScrollList(store, LIST_H)
scroll:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", -4, -12)
scroll:SetPoint("RIGHT", store, "RIGHT", -PAD, 0)
scroll:SetHeight(LIST_H)

local rows = {}

local function BuildRow(index, app)
    local row = rows[index]
    if not row then
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)

        local iconBg = row:CreateTexture(nil, "BACKGROUND")
        iconBg:SetSize(40, 40)
        iconBg:SetPoint("LEFT", row, "LEFT", 2, 0)
        iconBg:SetColorTexture(0.03, 0.08, 0.08, 0.9)

        local iconTex = row:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", iconBg, "TOPLEFT", 2, -2)
        iconTex:SetPoint("BOTTOMRIGHT", iconBg, "BOTTOMRIGHT", -2, 2)
        row.iconTex = iconTex

        local installBtn = UI.CreatePanelButton(row, 84, 22, "Install")
        installBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.installBtn = installBtn

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", iconBg, "TOPRIGHT", 8, -2)
        nameFS:SetPoint("RIGHT", installBtn, "LEFT", -8, 0)
        nameFS:SetJustifyH("LEFT")
        row.nameFS = nameFS

        local descFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -2)
        descFS:SetPoint("RIGHT", installBtn, "LEFT", -8, 0)
        descFS:SetJustifyH("LEFT")
        descFS:SetWordWrap(false)
        row.descFS = descFS

        rows[index] = row
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    row.iconTex:SetTexture(app.icon)
    row.nameFS:SetText(app.name)
    row.nameFS:SetTextColor(unpack(C.text))
    row.descFS:SetText(app.desc)
    row.descFS:SetTextColor(unpack(C.textMuted))

    local installed = T:IsAppInstalled(app.id)
    row.installBtn:SetText(installed and "Uninstall" or "Install")
    row.installBtn:SetScript("OnClick", function()
        T:SetAppInstalled(app.id, not installed)
    end)

    row:Show()
    return row
end

function T:RefreshStore()
    local apps = T.StoreApps or {}
    for i, app in ipairs(apps) do
        BuildRow(i, app)
    end
    for i = #apps + 1, #rows do
        rows[i]:Hide()
    end
    content:SetHeight(math.max(LIST_H, #apps * ROW_H))
end

T:RefreshStore()
