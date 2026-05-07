OmegaSpeak = OmegaSpeak or {}
OmegaSpeak.UI = OmegaSpeak.UI or {}

local UI = OmegaSpeak.UI

UI.colors = {
    windowBg      = { 0.05, 0.05, 0.05 },
    panelButtonBg = { 0.10, 0.10, 0.10, 1.00 },
    panelButtonBgPressed = { 0.06, 0.06, 0.06, 1.00 },
    panelButtonAccent = { 0.65, 0.55, 0.28, 0.70 },
    panelButtonHighlight = { 0.85, 0.75, 0.40, 0.10 },
    separator     = { 0.25, 0.25, 0.25, 1.00 },
    separatorSoft = { 0.18, 0.18, 0.18, 1.00 },
    closeBg       = { 0.18, 0.18, 0.18, 1.00 },
    closeText     = { 0.65, 0.65, 0.65, 1.00 },
    closeHighlight = { 0.75, 0.20, 0.20, 0.35 },
    title         = { 0.95, 0.90, 0.78, 1.00 },
    text          = { 0.88, 0.82, 0.65, 1.00 },
    textMuted     = { 0.72, 0.68, 0.55, 1.00 },
    textSoft      = { 0.60, 0.58, 0.48, 1.00 },
    label         = { 0.70, 0.65, 0.50, 1.00 },
    labelStrong   = { 0.80, 0.70, 0.40, 1.00 },
    warning       = { 0.85, 0.35, 0.35, 1.00 },
    placeholder   = { 0.40, 0.40, 0.40, 1.00 },
    tabActive     = { 1.00, 1.00, 1.00, 1.00 },
    tabInactive   = { 0.50, 0.50, 0.50, 1.00 },
    tabLine       = { 0.80, 0.70, 0.40, 1.00 },
    tabHighlight  = { 1.00, 1.00, 1.00, 0.06 },
    checkboxGlow  = { 0.78, 0.62, 0.18, 0.25 },
    checkboxBorder = { 0.82, 0.66, 0.20, 1.00 },
    checkboxBox   = { 0.10, 0.10, 0.10, 1.00 },
    checkboxHighlight = { 0.90, 0.78, 0.30, 0.22 },
    editBoxBg     = { 0.08, 0.08, 0.08, 1.00 },
    editBoxAccent = { 0.45, 0.38, 0.18, 0.80 },
    addButtonBg   = { 0.12, 0.16, 0.10, 1.00 },
    addButtonText = { 0.50, 0.90, 0.30, 1.00 },
    addButtonHighlight = { 0.40, 0.80, 0.20, 0.25 },
}

local function ApplyTextColor(fontString, color)
    if fontString and color then
        fontString:SetTextColor(unpack(color))
    end
end

function UI.ApplyWindowBackground(texture, alpha)
    if texture then
        local color = UI.colors.windowBg
        texture:SetColorTexture(color[1], color[2], color[3], alpha or 0.65)
    end
end

function UI.ApplySeparator(texture, soft)
    if texture then
        texture:SetColorTexture(unpack(soft and UI.colors.separatorSoft or UI.colors.separator))
    end
end

function UI.ApplyTitle(fontString)
    ApplyTextColor(fontString, UI.colors.title)
end

function UI.ApplyBodyText(fontString)
    ApplyTextColor(fontString, UI.colors.text)
end

function UI.ApplyMutedText(fontString)
    ApplyTextColor(fontString, UI.colors.textMuted)
end

function UI.ApplySoftText(fontString)
    ApplyTextColor(fontString, UI.colors.textSoft)
end

function UI.ApplyLabel(fontString)
    ApplyTextColor(fontString, UI.colors.label)
end

function UI.ApplyWarningText(fontString)
    ApplyTextColor(fontString, UI.colors.warning)
end

function UI.CreatePanelButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height or 22)

    local bgN = btn:CreateTexture(nil, "BACKGROUND")
    bgN:SetAllPoints()
    bgN:SetColorTexture(unpack(UI.colors.panelButtonBg))
    btn.bgN = bgN

    local bgP = btn:CreateTexture(nil, "BACKGROUND")
    bgP:SetAllPoints()
    bgP:SetColorTexture(unpack(UI.colors.panelButtonBgPressed))
    bgP:Hide()
    btn.bgP = bgP

    local accent = btn:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(1)
    accent:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 1)
    accent:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)
    accent:SetColorTexture(unpack(UI.colors.panelButtonAccent))
    btn.accent = accent

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.panelButtonHighlight))
    btn.highlight = hl

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetAllPoints()
    UI.ApplyBodyText(lbl)
    btn:SetFontString(lbl)
    btn:SetText(text or "")

    btn:SetScript("OnMouseDown", function(self)
        self.bgN:Hide()
        self.bgP:Show()
    end)

    btn:SetScript("OnMouseUp", function(self)
        self.bgP:Hide()
        self.bgN:Show()
    end)

    return btn
end

function UI.CreateCloseButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.closeBg))

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints()
    lbl:SetText("×")
    UI.ApplyMutedText(lbl)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.closeHighlight))

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    btn.bg = bg
    btn.label = lbl
    btn.highlight = hl
    return btn
end

function UI.CreateStyledEditBox(parent, width, height, multiLine)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width, height or 22)
    eb:SetFontObject("GameFontNormalSmall")
    UI.ApplyBodyText(eb)
    eb:SetAutoFocus(false)
    eb:SetMultiLine(multiLine or false)
    eb:SetMaxLetters(multiLine and 4000 or 255)
    eb:SetTextInsets(6, 6, 4, 4)

    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.editBoxBg))
    eb.bg = bg

    local border = eb:CreateTexture(nil, "ARTWORK")
    border:SetHeight(1)
    border:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 2, 1)
    border:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", -2, 1)
    border:SetColorTexture(unpack(UI.colors.editBoxAccent))
    eb.border = border

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    if not multiLine then
        eb:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
    end

    return eb
end
