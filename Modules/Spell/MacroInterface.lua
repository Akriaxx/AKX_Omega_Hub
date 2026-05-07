-- OmegaSpell - MacroInterface.lua
-- Ancienne interface Macro WoW, rendue commune aux bibliotheques Omega et WoW.

OmegaSpell = OmegaSpell or {}
OmegaSpell.MacroInterface = OmegaSpell.MacroInterface or {}

local OS  = OmegaSpell
local MI  = OmegaSpell.MacroInterface
local HUI = OS2.UI

local W        = 520
local H        = 480
local PAD      = 10
local HEADER_H = 40
local FOOTER_H = 34
local ROW_H    = 36
local ICON_S   = 26
local LIST_H   = H - HEADER_H - FOOTER_H - 64

local function Trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$") or ""
end

local function TextToLines(text)
    local lines = {}
    for line in string.gmatch((text or "") .. "\n", "(.-)\n") do
        line = Trim(line)
        if line ~= "" then lines[#lines + 1] = line end
    end
    return lines
end

local function Preview(body)
    local text = tostring(body or ""):gsub("\n+$", ""):gsub("\n", " | ")
    if #text > 60 then text = text:sub(1, 57) .. "..." end
    return text
end

function MI.Create(opts)
    opts = opts or {}
    local Lib = {}
    local rows = {}
    local sortCol = "NOM"
    local sortDir = 1
    local headerBtns = {}
    local activeMode = opts.defaultMode
    local deleteMode = false
    if opts.modes and not activeMode then
        for key in pairs(opts.modes) do activeMode = key; break end
    end

    local function CurrentOpts()
        if opts.modes and activeMode and opts.modes[activeMode] then
            return opts.modes[activeMode]
        end
        return opts
    end

    local panel = CreateFrame("Frame", opts.frameName or nil, UIParent, "BackdropTemplate")
    panel:SetSize(W, H)
    panel:SetPoint("CENTER", UIParent, "CENTER", opts.x or 80, opts.y or 40)
    panel:SetFrameStrata("HIGH")
    panel:SetFrameLevel(opts.frameLevel or 128)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
    panel:Hide()

    local titleFS
    do
        local bg = panel:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        HUI.ApplyWindowBackground(bg, 0.97)
        panel:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 16,
            insets   = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        panel:SetBackdropBorderColor(unpack(HUI.colors.separator))
    end

    local header = CreateFrame("Frame", nil, panel)
    header:SetPoint("TOPLEFT",  4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(HEADER_H)

    do
        local hBg = header:CreateTexture(nil, "BACKGROUND")
        hBg:SetAllPoints()
        HUI.ApplyWindowBackground(hBg, 0.70)

        local hAccent = header:CreateTexture(nil, "ARTWORK")
        hAccent:SetWidth(3)
        hAccent:SetPoint("TOPLEFT")
        hAccent:SetPoint("BOTTOMLEFT")
        hAccent:SetColorTexture(0.40, 0.60, 1.0, 1.0)

        titleFS = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        titleFS:SetPoint("LEFT", header, "LEFT", PAD + 6, 0)
        titleFS:SetText(opts.title or "Macros")
        HUI.ApplyTitle(titleFS)
    end

    HUI.CreateCloseButton(panel, function()
        panel:Hide()
        if opts.onClose then opts.onClose(panel) end
    end)

    local hSep = panel:CreateTexture(nil, "ARTWORK")
    hSep:SetHeight(1)
    hSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  2, -(HEADER_H + 5))
    hSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -(HEADER_H + 5))
    HUI.ApplySeparator(hSep, true)

    local filterBox = HUI.CreateStyledEditBox(panel, W - PAD * 2, 22, false)
    filterBox:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 8))
    filterBox:SetMaxLetters(64)

    local filterHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterHint:SetAllPoints(filterBox)
    filterHint:SetJustifyH("LEFT")
    filterHint:SetText("  Rechercher...")
    HUI.ApplyMutedText(filterHint)
    filterBox:SetScript("OnEditFocusGained", function() filterHint:Hide() end)
    filterBox:SetScript("OnEditFocusLost", function()
        if filterBox:GetText() == "" then filterHint:Show() end
    end)
    filterBox:SetScript("OnTextChanged", function() Lib.Refresh() end)

    local fSep = panel:CreateTexture(nil, "ARTWORK")
    fSep:SetHeight(1)
    fSep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, -(HEADER_H + 34))
    fSep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -(HEADER_H + 34))
    HUI.ApplySeparator(fSep, true)

    local COL_Y  = -(HEADER_H + 38)
    local XTYPE  = PAD + 36
    local XNOM   = PAD + 82
    local XCORPS = PAD + 246

    local function MakeVSep(x)
        local s = panel:CreateTexture(nil, "ARTWORK")
        s:SetWidth(1)
        s:SetPoint("TOPLEFT",    panel, "TOPLEFT", x, -(HEADER_H + 36))
        s:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", x, -(HEADER_H + 52))
        s:SetColorTexture(1, 1, 1, 0.07)
    end
    MakeVSep(XTYPE - 2)
    MakeVSep(XNOM - 2)
    MakeVSep(XCORPS - 2)

    local function MakeSortHeader(col, label, x, w)
        local btn = CreateFrame("Button", nil, panel)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", x, COL_Y)
        btn:SetSize(w, 14)

        local hl = btn:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.85, 0.75, 0.40, 0.08)

        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetAllPoints()
        fs:SetJustifyH("LEFT")

        local function UpdateLabel()
            if sortCol == col then
                fs:SetText(label .. (sortDir == 1 and " ++" or " --"))
                fs:SetTextColor(0.90, 0.80, 0.45, 1)
            else
                fs:SetText(label)
                HUI.ApplyLabel(fs)
            end
        end

        UpdateLabel()
        btn:SetScript("OnClick", function()
            if sortCol == col then sortDir = -sortDir else sortCol = col; sortDir = 1 end
            for _, hb in pairs(headerBtns) do hb.UpdateLabel() end
            Lib.Refresh()
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine("Trier par " .. label, 1, 0.86, 0.45)
            GameTooltip:AddLine("Clic : croissant / décroissant", 0.55, 0.55, 0.55)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn.UpdateLabel = UpdateLabel
        headerBtns[col] = btn
    end

    MakeSortHeader("TYPE",  "TYPE",  XTYPE,  46)
    MakeSortHeader("NOM",   "NOM",   XNOM,   158)
    MakeSortHeader("CORPS", "CORPS", XCORPS, 120)

    local listSF = CreateFrame("ScrollFrame", nil, panel)
    listSF:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 54))
    listSF:SetSize(W - PAD * 2, LIST_H)
    listSF:EnableMouseWheel(true)

    local listContent = CreateFrame("Frame", nil, listSF)
    listContent:SetWidth(W - PAD * 2)
    listSF:SetScrollChild(listContent)

    listSF:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, (listContent:GetHeight() or 0) - self:GetHeight())
        local cur = self:GetVerticalScroll() or 0
        local nextValue = math.max(0, math.min(max, cur - delta * ROW_H * 3))
        self:SetVerticalScroll(nextValue)
    end)

    local footSep = panel:CreateTexture(nil, "ARTWORK")
    footSep:SetHeight(1)
    footSep:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  4, FOOTER_H)
    footSep:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, FOOTER_H)
    HUI.ApplySeparator(footSep, true)

    local statusFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("BOTTOMLEFT",  panel, "BOTTOMLEFT",  PAD + 4, 14)
    statusFS:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", opts.modes and -170 or -PAD, 14)
    statusFS:SetJustifyH("LEFT")
    HUI.ApplyMutedText(statusFS)

    function Lib.SetStatus(text)
        statusFS:SetText(text or "")
    end
    panel.SetStatus = function(_, text) Lib.SetStatus(text) end

    local switchBtn
    local deleteBtn
    if opts.modes then
        switchBtn = HUI.CreatePanelButton(panel, 62, 22, "")
        deleteBtn = HUI.CreatePanelButton(panel, 92, 22, "Suppression")
        deleteBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, 6)
        switchBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -6, 0)
    end

    local function UpdateModeVisual()
        local current = CurrentOpts()
        titleFS:SetText(current.title or opts.title or "Macros")
        if switchBtn then
            if activeMode == "omega" then
                switchBtn:SetText("WoW")
            else
                switchBtn:SetText("Omega")
            end
        end
        if deleteBtn then
            deleteBtn:SetText(deleteMode and "Retour" or "Suppression")
        end
    end

    local function ApplySort(macros)
        table.sort(macros, function(a, b)
            local va, vb
            if sortCol == "TYPE" then
                va = tostring(a.typeText or ""):lower()
                vb = tostring(b.typeText or ""):lower()
            elseif sortCol == "CORPS" then
                va = tostring(a.body or ""):lower()
                vb = tostring(b.body or ""):lower()
            else
                va = tostring(a.name or ""):lower()
                vb = tostring(b.name or ""):lower()
            end
            if va == vb then return tostring(a.name or ""):lower() < tostring(b.name or ""):lower() end
            if sortDir == 1 then return va < vb else return va > vb end
        end)
    end

    local function RowBg(parent, shade)
        local bg = parent:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(shade, shade, shade, 1)
    end

    local function RowHL(parent)
        local hl = parent:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(0.40, 0.60, 1.0, 0.10)
    end

    function Lib.Refresh()
        for _, r in ipairs(rows) do r:Hide() end
        wipe(rows)

        local filter = filterBox:GetText() or ""
        local current = CurrentOpts()
        UpdateModeVisual()
        local macros = current.collect and current.collect(filter) or {}
        ApplySort(macros)
        listContent:SetHeight(math.max(LIST_H, #macros * ROW_H))

        for i, m in ipairs(macros) do
            local row = CreateFrame("Frame", nil, listContent)
            row:SetSize(W - PAD * 2, ROW_H)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            RowBg(row, i % 2 == 0 and 0.10 or 0.07)
            RowHL(row)

            local iconF = row:CreateTexture(nil, "ARTWORK")
            iconF:SetSize(ICON_S, ICON_S)
            iconF:SetPoint("LEFT", row, "LEFT", 0, 0)
            iconF:SetTexture(m.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            iconF:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            if m.isIconMask then
                local maskRing = row:CreateTexture(nil, "OVERLAY")
                maskRing:SetSize(9, 9)
                maskRing:SetPoint("TOPRIGHT", iconF, "TOPRIGHT", 2, 2)
                maskRing:SetColorTexture(0.05, 0.04, 0.02, 0.85)

                local maskDot = row:CreateTexture(nil, "OVERLAY")
                maskDot:SetSize(7, 7)
                maskDot:SetPoint("CENTER", maskRing, "CENTER", 0, 0)
                maskDot:SetColorTexture(1.00, 0.48, 0.08, 1)
            end

            local badge = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            badge:SetPoint("LEFT", iconF, "RIGHT", 4, 0)
            badge:SetWidth(46)
            badge:SetJustifyH("CENTER")
            badge:SetText(m.typeText or "")
            badge:SetTextColor(m.typeColorR or 0.80, m.typeColorG or 0.70, m.typeColorB or 0.40, 1)

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameFS:SetPoint("LEFT", badge, "RIGHT", 6, 0)
            nameFS:SetWidth(158)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetWordWrap(false)
            nameFS:SetText(m.displayName or m.name or "")
            HUI.ApplyBodyText(nameFS)

            local bodyFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            bodyFS:SetPoint("LEFT", nameFS, "RIGHT", 6, 0)
            bodyFS:SetPoint("RIGHT", row, "RIGHT", deleteMode and -88 or (current.bodyRightOffset or -124), 0)
            bodyFS:SetJustifyH("LEFT")
            bodyFS:SetWordWrap(false)
            bodyFS:SetText(m.preview or Preview(m.body))
            HUI.ApplyMutedText(bodyFS)

            local rightOffset = -2
            local actions
            if deleteMode then
                actions = current.deleteAction and { current.deleteAction } or {}
            else
                actions = current.actions
                if not actions then
                    actions = { current.secondaryAction, current.primaryAction }
                end
            end

            for _, action in ipairs(actions or {}) do
                if action then
                    local btn = HUI.CreatePanelButton(row, action.width or 58, 22, action.label or "Action")
                    btn:SetPoint("RIGHT", row, "RIGHT", rightOffset, 0)
                    btn:SetScript("OnClick", function()
                        local ok, msg = action.onClick and action.onClick(m, panel)
                        Lib.SetStatus(msg or "")
                        if action.refresh then Lib.Refresh() end
                    end)
                    rightOffset = rightOffset - (action.width or 58) - 6
                end
            end

            rows[i] = row
        end

        if #macros == 0 then
            local hint = listContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hint:SetPoint("TOPLEFT", 6, -10)
            hint:SetText(filter ~= "" and "Aucune macro correspondante." or (current.emptyText or opts.emptyText or "Aucune macro créée."))
            HUI.ApplyMutedText(hint)
            rows[1] = { Hide = function() hint:Hide() end }
        end
    end

    if switchBtn then
        switchBtn:SetScript("OnClick", function()
            activeMode = activeMode == "omega" and "wow" or "omega"
            deleteMode = false
            Lib.SetStatus("")
            Lib.Refresh()
        end)
    end

    if deleteBtn then
        deleteBtn:SetScript("OnClick", function()
            deleteMode = not deleteMode
            Lib.SetStatus(deleteMode and "Mode suppression actif." or "")
            Lib.Refresh()
        end)
    end

    function Lib.Open(mode)
        if panel:IsShown() then
            if mode and opts.modes and opts.modes[mode] and mode ~= activeMode then
                activeMode = mode
                deleteMode = false
                Lib.SetStatus("")
                Lib.Refresh()
                return
            end
            panel:Hide()
            if opts.onClose then opts.onClose(panel) end
            return
        end
        if mode and opts.modes and opts.modes[mode] then activeMode = mode end
        deleteMode = false
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", opts.x or 80, opts.y or 40)
        filterBox:SetText("")
        filterHint:Show()
        Lib.SetStatus("")
        UpdateModeVisual()
        Lib.Refresh()
        panel:Show()
        if opts.onOpen then opts.onOpen(panel) end
    end

    function Lib.SetMode(mode)
        if mode and opts.modes and opts.modes[mode] then
            activeMode = mode
            deleteMode = false
            Lib.SetStatus("")
            Lib.Refresh()
        end
    end

    function Lib.Close()
        panel:Hide()
        if opts.onClose then opts.onClose(panel) end
    end

    panel.Open = Lib.Open
    panel.Refresh = Lib.Refresh
    panel.Close = Lib.Close
    panel.SetMode = Lib.SetMode
    return panel
end

function MI.ImportWoWMacroAsSpell(macro)
    if not macro or not macro.name or macro.name == "" then return false, "Macro WoW invalide." end
    local spellName = macro.name
    local exists = OS.GetSpell and OS.GetSpell(spellName)
    if not exists then
        local ok, err = OS.AddSpell(spellName)
        if not ok then return false, err or "Impossible de créer le sort." end
    end

    local spell = OS.GetSpell(spellName)
    if not spell then return false, "Sort introuvable après import." end

    spell.category = "Macro WoW"
    spell.icon = macro.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    spell.source = "wowMacro"
    spell.wowMacroName = macro.name
    spell.wowMacroIndex = macro.index
    spell.macroName = (macro.name or spellName):sub(1, 16)
    spell.macroLines = TextToLines(macro.body or "")
    spell.macroStored = macro.body or ""

    return true, (exists and "Macro WoW mise à jour : " or "Macro WoW importée : ") .. spellName
end
