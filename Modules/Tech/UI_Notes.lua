-- ============================================================
--  Tech — App NOTES : journal RP
-- ============================================================

local T  = Tech
local UI = OS2.UI
local C  = T.colors

local PAD   = 14
local ROW_H = 30

local body = T:RegisterApp({
    key   = "notes",
    label = "Notes",
    icon  = "Interface\\Icons\\INV_Misc_Book_09",
    color = { 0.10, 0.42, 0.38 },
    dock  = true,
})

local LIST_H = 420

-- ── Sélecteur de type + saisie ─────────────────────────────────────────────

local KIND_COLORS = { log = C.logInfo, comm = C.logComm, alert = C.logAlert }
local KIND_ORDER  = { "log", "comm", "alert" }
local selectedKind = "log"

local kindRow = CreateFrame("Frame", nil, body)
kindRow:SetPoint("TOPLEFT", body, "TOPLEFT", PAD, -PAD)
kindRow:SetSize(#KIND_ORDER * 18, 16)

local kindButtons = {}
for i, kind in ipairs(KIND_ORDER) do
    local btn = CreateFrame("Button", nil, kindRow)
    btn:SetSize(14, 14)
    btn:SetPoint("LEFT", kindRow, "LEFT", (i - 1) * 18, 0)

    local sw = btn:CreateTexture(nil, "ARTWORK")
    sw:SetAllPoints()
    sw:SetColorTexture(unpack(KIND_COLORS[kind]))

    local ring = btn:CreateTexture(nil, "OVERLAY")
    ring:SetPoint("TOPLEFT", -2, 2)
    ring:SetPoint("BOTTOMRIGHT", 2, -2)
    ring:SetColorTexture(1, 1, 1, 0.9)
    ring:Hide()
    btn.ring = ring

    btn:SetScript("OnClick", function()
        selectedKind = kind
        for _, other in pairs(kindButtons) do other.ring:Hide() end
        btn.ring:Show()
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(kind:upper())
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    kindButtons[kind] = btn
end
kindButtons.log.ring:Show()

local noteInput = UI.CreateStyledEditBox(body, 220, 22, false)
noteInput:SetPoint("LEFT", kindRow, "RIGHT", 8, 0)
noteInput:SetPoint("TOP", kindRow, "TOP", 0, 3)

local function SubmitNote()
    if noteInput:GetText() ~= "" then
        T:AddLogEntry(selectedKind, noteInput:GetText())
        noteInput:SetText("")
    end
    noteInput:ClearFocus()
end

local addNoteBtn = UI.CreateAddButton(body, SubmitNote)
addNoteBtn:SetPoint("LEFT", noteInput, "RIGHT", 6, 0)
noteInput:SetScript("OnEnterPressed", SubmitNote)

-- ── Journal ────────────────────────────────────────────────────────────────

local logSep = body:CreateTexture(nil, "ARTWORK")
logSep:SetHeight(1)
logSep:SetPoint("TOPLEFT", kindRow, "BOTTOMLEFT", -2, -14)
logSep:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, 0)
logSep:SetColorTexture(unpack(C.accentDim))

local logLabel = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
logLabel:SetPoint("TOPLEFT", logSep, "BOTTOMLEFT", 2, -8)
logLabel:SetText("RP LOG - INC. DATA")
logLabel:SetTextColor(unpack(C.textMuted))

local logScroll, logContent = T.CreateScrollList(body, LIST_H)
logScroll:SetPoint("TOPLEFT", logLabel, "BOTTOMLEFT", 0, -6)
logScroll:SetPoint("RIGHT", body, "RIGHT", -PAD, 0)
logScroll:SetHeight(LIST_H)

local logRows = {}

local function BuildLogRow(index, entry)
    local row = logRows[index]
    if not row then
        row = CreateFrame("Frame", nil, logContent)
        row:SetHeight(ROW_H)

        local dot = row:CreateTexture(nil, "ARTWORK")
        dot:SetSize(8, 8)
        dot:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.dot = dot

        local timeFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeFS:SetPoint("LEFT", dot, "RIGHT", 6, 0)
        timeFS:SetWidth(36)
        timeFS:SetJustifyH("LEFT")
        row.timeFS = timeFS

        local delBtn = T.CreateDeleteButton(row)
        delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        row.delBtn = delBtn

        local textFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        textFS:SetPoint("LEFT", timeFS, "RIGHT", 6, 0)
        textFS:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
        textFS:SetJustifyH("LEFT")
        textFS:SetWordWrap(false)
        row.textFS = textFS

        logRows[index] = row
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", logContent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", logContent, "RIGHT", 0, 0)

    row.dot:SetColorTexture(unpack(KIND_COLORS[entry.kind] or C.logInfo))
    row.timeFS:SetText(entry.time or "")
    row.timeFS:SetTextColor(unpack(C.textMuted))
    row.textFS:SetText(entry.text or "")
    row.textFS:SetTextColor(unpack(C.text))
    row.delBtn:SetScript("OnClick", function() T:RemoveLogEntry(index) end)

    row:Show()
    return row
end

function T:RefreshNotes()
    local db = T:GetDB()
    local count = #db.log
    for i, entry in ipairs(db.log) do
        BuildLogRow(i, entry)
    end
    for i = count + 1, #logRows do
        logRows[i]:Hide()
    end
    logContent:SetHeight(math.max(LIST_H, count * ROW_H))
end

T:RefreshNotes()
