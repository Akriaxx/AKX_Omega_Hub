-- ============================================================
--  Tech — App COMM : journal des transmissions reçues
-- ============================================================

local T  = Tech
local UI = OS2.UI
local C  = T.colors

local PAD    = 14
local ROW_H  = 34
local LIST_H = 380

local comm = T:RegisterApp({
    key   = "comm",
    label = "Comm",
    icon  = "Interface\\Icons\\INV_Misc_Bell_01",
    color = { 0.12, 0.32, 0.50 },
    dock  = true,
})

local senderInput = UI.CreateStyledEditBox(comm, 100, 22, false)
senderInput:SetPoint("TOPLEFT", comm, "TOPLEFT", PAD, -PAD)

local msgInput = UI.CreateStyledEditBox(comm, 170, 22, false)
msgInput:SetPoint("LEFT", senderInput, "RIGHT", 6, 0)

local function SubmitComm()
    if msgInput:GetText() ~= "" then
        T:AddCommEntry(senderInput:GetText(), msgInput:GetText())
        senderInput:SetText("")
        msgInput:SetText("")
    end
    senderInput:ClearFocus()
    msgInput:ClearFocus()
end

local addBtn = UI.CreateAddButton(comm, SubmitComm)
addBtn:SetPoint("LEFT", msgInput, "RIGHT", 6, 0)
msgInput:SetScript("OnEnterPressed", SubmitComm)

local sep = comm:CreateTexture(nil, "ARTWORK")
sep:SetHeight(1)
sep:SetPoint("TOPLEFT", senderInput, "BOTTOMLEFT", -2, -12)
sep:SetPoint("TOPRIGHT", comm, "TOPRIGHT", -PAD, 0)
sep:SetColorTexture(unpack(C.accentDim))

local label = comm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
label:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 2, -8)
label:SetText("INC. TRANSMISSIONS")
label:SetTextColor(unpack(C.textMuted))

local scroll, content = T.CreateScrollList(comm, LIST_H)
scroll:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
scroll:SetPoint("RIGHT", comm, "RIGHT", -PAD, 0)
scroll:SetHeight(LIST_H)

local rows = {}

local function BuildRow(index, entry)
    local row = rows[index]
    if not row then
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)

        local timeFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        timeFS:SetPoint("TOPLEFT", row, "TOPLEFT", 2, 0)
        row.timeFS = timeFS

        local delBtn = T.CreateDeleteButton(row)
        delBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, 0)
        row.delBtn = delBtn

        local senderFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        senderFS:SetPoint("TOPLEFT", timeFS, "TOPRIGHT", 6, 0)
        senderFS:SetPoint("RIGHT", delBtn, "LEFT", -4, 0)
        senderFS:SetJustifyH("LEFT")
        row.senderFS = senderFS

        local textFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        textFS:SetPoint("TOPLEFT", timeFS, "BOTTOMLEFT", 0, -2)
        textFS:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        textFS:SetJustifyH("LEFT")
        textFS:SetWordWrap(false)
        row.textFS = textFS

        rows[index] = row
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("RIGHT", content, "RIGHT", 0, 0)

    row.timeFS:SetText("[" .. (entry.time or "") .. "]")
    row.timeFS:SetTextColor(unpack(C.textMuted))
    row.senderFS:SetText("COMM_SYS // " .. (entry.sender or ""))
    row.senderFS:SetTextColor(unpack(C.logComm))
    row.textFS:SetText(entry.text or "")
    row.textFS:SetTextColor(unpack(C.text))
    row.delBtn:SetScript("OnClick", function() T:RemoveCommEntry(index) end)

    row:Show()
    return row
end

function T:RefreshComm()
    local db = T:GetDB()
    local count = #db.comm
    for i, entry in ipairs(db.comm) do
        BuildRow(i, entry)
    end
    for i = count + 1, #rows do
        rows[i]:Hide()
    end
    content:SetHeight(math.max(LIST_H, count * ROW_H))
end

T:RefreshComm()
