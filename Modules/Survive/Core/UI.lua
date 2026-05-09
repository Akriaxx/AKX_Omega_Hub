-- OmegaSurvive 2.0 — UI
OS2 = OS2 or {}
OS2.UI = OS2.UI or {}

local UI = OS2.UI

UI.colors = {
    -- Fenêtres
    windowBg           = { 0.05, 0.05, 0.05 },
    border             = { 0.60, 0.52, 0.28, 1.00 },
    -- Boutons
    panelButtonBg      = { 0.10, 0.10, 0.10, 1.00 },
    panelButtonBgPressed = { 0.06, 0.06, 0.06, 1.00 },
    panelButtonAccent  = { 0.65, 0.55, 0.28, 0.70 },
    panelButtonHighlight = { 0.85, 0.75, 0.40, 0.10 },
    -- Séparateurs
    separator          = { 0.25, 0.25, 0.25, 1.00 },
    separatorSoft      = { 0.18, 0.18, 0.18, 1.00 },
    -- Bouton fermer
    closeBg            = { 0.18, 0.18, 0.18, 1.00 },
    closeText          = { 0.65, 0.65, 0.65, 1.00 },
    closeHighlight     = { 0.75, 0.20, 0.20, 0.35 },
    -- Texte
    title              = { 0.95, 0.90, 0.78, 1.00 },
    text               = { 0.88, 0.82, 0.65, 1.00 },
    textMuted          = { 0.72, 0.68, 0.55, 1.00 },
    textSoft           = { 0.60, 0.58, 0.48, 1.00 },
    label              = { 0.70, 0.65, 0.50, 1.00 },
    labelStrong        = { 0.80, 0.70, 0.40, 1.00 },
    warning            = { 0.85, 0.35, 0.35, 1.00 },
    placeholder        = { 0.40, 0.40, 0.40, 1.00 },
    -- Onglets
    tabActive          = { 1.00, 1.00, 1.00, 1.00 },
    tabInactive        = { 0.50, 0.50, 0.50, 1.00 },
    tabLine            = { 0.80, 0.70, 0.40, 1.00 },
    tabHighlight       = { 1.00, 1.00, 1.00, 0.06 },
    -- Checkbox
    checkboxGlow       = { 0.78, 0.62, 0.18, 0.25 },
    checkboxBorder     = { 0.82, 0.66, 0.20, 1.00 },
    checkboxBox        = { 0.10, 0.10, 0.10, 1.00 },
    checkboxHighlight  = { 0.90, 0.78, 0.30, 0.22 },
    -- Champs de saisie
    editBoxBg          = { 0.08, 0.08, 0.08, 1.00 },
    editBoxAccent      = { 0.45, 0.38, 0.18, 0.80 },
    -- Bouton ajout
    addButtonBg        = { 0.12, 0.16, 0.10, 1.00 },
    addButtonText      = { 0.50, 0.90, 0.30, 1.00 },
    addButtonHighlight = { 0.40, 0.80, 0.20, 0.25 },
    -- Lignes de joueur (listes)
    rowBg              = { 0.06, 0.06, 0.06, 0.92 },
    rowBgSelected      = { 0.10, 0.085, 0.045, 0.96 },
    rowSelection       = { 0.78, 0.62, 0.24, 0.18 },
    -- Barre temporaire
    tempFill           = { 0.95, 0.74, 0.20, 0.88 },
    -- Stats (partagées entre tous les modules Character)
    statHP   = { fg = {0.85, 0.15, 0.15, 1}, bg = {0.20, 0.04, 0.04, 1}, label = "HP"  },
    statMana = { fg = {0.18, 0.42, 0.90, 1}, bg = {0.04, 0.11, 0.27, 1}, label = "MP"  },
    statEnd  = { fg = {0.10, 0.70, 0.20, 1}, bg = {0.03, 0.16, 0.05, 1}, label = "END" },
}

local function ApplyVertexColor(region, color)
    if region and color then
        region:SetVertexColor(unpack(color))
    end
end

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

function UI.ApplyStrongLabel(fontString)
    ApplyTextColor(fontString, UI.colors.labelStrong)
end

function UI.ApplyWarningText(fontString)
    ApplyTextColor(fontString, UI.colors.warning)
end

function UI.ApplyPlaceholderText(fontString)
    ApplyTextColor(fontString, UI.colors.placeholder)
end

function UI.ApplyTabState(button, active)
    if not button then
        return
    end

    if button.label then
        ApplyTextColor(button.label, active and UI.colors.tabActive or UI.colors.tabInactive)
    end
    if button.line then
        button.line:SetShown(active)
        UI.ApplySeparator(button.line)
        button.line:SetColorTexture(unpack(UI.colors.tabLine))
    end
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
    lbl:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -1)
    lbl:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -8, 1)
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

function UI.StyleDropdown(dd, textLeft, textYOffset, textRightPad)
    local function raiseLists()
        local parent = dd:GetParent()
        local level = math.max(200, ((parent and parent.GetFrameLevel and parent:GetFrameLevel()) or dd:GetFrameLevel() or 1) + 80)

        for i = 1, 2 do
            local list = _G["DropDownList" .. i]
            if list then
                list:SetFrameStrata("TOOLTIP")
                list:SetToplevel(true)
                list:SetFrameLevel(level)
            end
        end
    end

    if dd.SetFrameStrata then
        local parent = dd:GetParent()
        if parent and parent.GetFrameStrata then
            dd:SetFrameStrata(parent:GetFrameStrata())
        end
    end

    if dd.Button and not dd.Button.os2DropdownRaised then
        dd.Button:HookScript("OnClick", raiseLists)
        dd.Button.os2DropdownRaised = true
    end

    for i = 1, 2 do
        local list = _G["DropDownList" .. i]
        if list and not list.os2DropdownRaised then
            list:HookScript("OnShow", raiseLists)
            list.os2DropdownRaised = true
        end
    end

    if dd.Left then dd.Left:SetVertexColor(0.12, 0.12, 0.12) end
    if dd.Middle then dd.Middle:SetVertexColor(0.12, 0.12, 0.12) end
    if dd.Right then dd.Right:SetVertexColor(0.12, 0.12, 0.12) end
    if dd.Icon then
        dd.Icon:SetAlpha(1)
    end
    if dd.Button then
        dd.Button:ClearAllPoints()
        dd.Button:SetPoint("RIGHT", dd, "RIGHT", -15, 3)
        dd.Button:SetSize(22, 22)
        dd.Button:SetNormalTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
        dd.Button:SetPushedTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Down")
        dd.Button:SetDisabledTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Disabled")
        dd.Button:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight")
    end
    if dd.Text then
        UI.ApplyBodyText(dd.Text)
        dd.Text:SetJustifyH("LEFT")
        dd.Text:ClearAllPoints()
        dd.Text:SetPoint("LEFT", dd, "LEFT", textLeft or 18, textYOffset or 1)
        dd.Text:SetPoint("RIGHT", dd.Button, "LEFT", textRightPad or -6, 0)
    end
end

function UI.CreateDropdown(parent, width, labelText, items, getValue, setValue)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 40)

    local label = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, 0)
    label:SetText(labelText or "")
    UI.ApplyLabel(label)

    local dropdown = CreateFrame("Frame", nil, holder, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", holder, "TOPLEFT", -16, -12)
    UIDropDownMenu_SetWidth(dropdown, math.max(40, width - 22))
    UI.StyleDropdown(dropdown)
    holder.dropdown = dropdown

    local function FormatDropdownItemLabel(text, selected)
        if selected then
            return "|cffd7b35f>  " .. (text or "") .. "|r"
        end
        return "    " .. (text or "")
    end

    local function GetSelectedItem()
        local value = getValue and getValue()
        for index, item in ipairs(items or {}) do
            if item.value == value then
                return item, index
            end
        end
        return items and items[1], 1
    end

    local function RefreshText()
        local item, index = GetSelectedItem()
        UIDropDownMenu_SetSelectedID(dropdown, index)
        UIDropDownMenu_SetSelectedValue(dropdown, item and item.value or nil)
        UIDropDownMenu_SetText(dropdown, item and item.label or "")
    end

    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local currentValue = getValue and getValue()
        for index, item in ipairs(items or {}) do
            local selected = item.value == currentValue
            local info = UIDropDownMenu_CreateInfo()
            info.text = FormatDropdownItemLabel(item.label, selected)
            info.value = item.value
            info.notCheckable = true
            info.func = function()
                if setValue then setValue(item.value) end
                UIDropDownMenu_SetSelectedID(dropdown, index)
                UIDropDownMenu_SetSelectedValue(dropdown, item.value)
                UIDropDownMenu_SetText(dropdown, item.label)
                if holder.OnValueChanged then holder.OnValueChanged(item.value) end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    holder.Refresh = RefreshText
    holder.Close = function() CloseDropDownMenus() end
    RefreshText()
    return holder
end

function UI.CreateStyledCheckbox(parent, labelText)
    local btn = CreateFrame("CheckButton", nil, parent)
    btn:SetSize(18, 18)

    local glow = btn:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)
    glow:SetColorTexture(unpack(UI.colors.checkboxGlow))

    local border = btn:CreateTexture(nil, "BORDER")
    border:SetAllPoints()
    border:SetColorTexture(unpack(UI.colors.checkboxBorder))

    local box = btn:CreateTexture(nil, "ARTWORK")
    box:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    box:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -1, 1)
    box:SetColorTexture(unpack(UI.colors.checkboxBox))

    local check = btn:CreateTexture(nil, "OVERLAY")
    check:SetPoint("CENTER", btn, "CENTER", 0, 0)
    check:SetSize(14, 14)
    check:SetTexture("Interface/Buttons/UI-CheckBox-Check")
    check:SetVertexColor(1.0, 0.88, 0.40, 1)
    btn:SetCheckedTexture(check)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.checkboxHighlight))
    btn:SetHighlightTexture(hl)
    btn:SetNormalTexture("")

    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetText(labelText or "")
    UI.ApplyBodyText(label)

    btn.label = label
    return btn, label
end

function UI.CreateStyledEditBox(parent, width, height, multiLine)
    local eb = CreateFrame("EditBox", nil, parent)
    eb:SetSize(width, height or 22)
    eb:SetFontObject("GameFontNormalSmall")
    UI.ApplyBodyText(eb)
    eb:SetAutoFocus(false)
    eb:SetMultiLine(multiLine or false)
    eb:SetMaxLetters(multiLine and 512 or 128)
    eb:SetTextInsets(8, 8, 5, 5)

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

function UI.CreateAddButton(parent, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.addButtonBg))
    btn.bg = bg

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints()
    lbl:SetText("+")
    lbl:SetTextColor(unpack(UI.colors.addButtonText))
    btn.label = lbl

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.addButtonHighlight))
    btn.highlight = hl

    if onClick then
        btn:SetScript("OnClick", onClick)
    end

    return btn
end
