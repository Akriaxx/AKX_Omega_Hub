-- Survive-only widget factory and RPG skin. Shared OS2.UI stays unchanged.
-- OmegaSurvive 2.0 — UI
OS2 = OS2 or {}
OS2.SurviveUI = OS2.SurviveUI or {}

local UI = OS2.SurviveUI

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
    -- Surbrillance "tour en cours" (Character, initiative)
    turnHighlight      = { 0.25, 0.90, 0.95, 1.00 },
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
    btn:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    btn:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)

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

-- Character-only skin: never changes the shared UI used by other modules.
local Base=OS2.SurviveUI
local UI=setmetatable({}, {__index=Base})
OS2.SurviveUI=UI
UI.colors=setmetatable({
    windowBg={.025,.035,.05},panelButtonBg={.028,.039,.055,1},
    panelButtonBgPressed={.06,.075,.095,1},separator={.58,.46,.26,.65},
    separatorSoft={.58,.46,.26,.32},label={.78,.71,.55,1},
    labelStrong={.91,.80,.57,1},textSoft={.52,.57,.64,1},
    tabActive={.95,.82,.56,1},tabInactive={.63,.66,.71,1},
    editBoxBg={.012,.019,.028,1},editBoxAccent={.58,.46,.26,1},
    rowBg={.028,.039,.055,.95},rowBgSelected={.075,.095,.125,.98},
    rowSelection={.72,.53,.22,.16},title={.91,.80,.57,1},
    text={.89,.88,.80,1},textMuted={.63,.66,.71,1},
    turnHighlight={.95,.76,.35,1},
    -- Vie en vert, Endurance en rouge dans tout Character (les autres
    -- modules gardent les couleurs partagées d'OS2.UI).
    statHP={fg={0.10,0.70,0.20,1},bg={0.03,0.16,0.05,1},label="HP"},
    statEnd={fg={0.85,0.15,0.15,1},bg={0.20,0.04,0.04,1},label="END"},
}, {__index=Base.colors})
local MEDIA="Interface\\AddOns\\Omega_Hub\\Modules\\Survive\\Core\\Media\\"
-- Shared nine-slice frame, matching the HUD and skill cards. Corners never stretch.
function UI.ApplyBorder(frame)
    if frame.rpgBorder then return end
    frame.rpgBorder=true
    local cuts={0,24/128,104/128,1}
    local parts={};frame.rpgSkin=parts
    for row=1,3 do for col=1,3 do
        local tex=frame:CreateTexture(nil,"BACKGROUND",nil,2)
        tex:SetTexture(MEDIA.."SkillCard")
        tex:SetTexCoord(cuts[col],cuts[col+1],cuts[row],cuts[row+1])
        parts[#parts+1]=tex
    end end
    local function Layout()
        local w,h=frame:GetWidth() or 0,frame:GetHeight() or 0
        local k=math.max(1,math.min(12,w/2,h/2))
        local xs,ys={0,k,w-k,w},{0,k,h-k,h}
        for i,tex in ipairs(parts) do
            local row,col=math.floor((i-1)/3)+1,(i-1)%3+1
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT",frame,"TOPLEFT",xs[col],-ys[row])
            tex:SetPoint("BOTTOMRIGHT",frame,"TOPLEFT",xs[col+1],-ys[row+1])
        end
    end
    frame:HookScript("OnSizeChanged",Layout);Layout()
end
-- Case de joueur / PNJ : le même cadre arrondi que les fenêtres, en plus
-- petit (coins de 10 px), fond opaque compris. Discret au repos, plein une
-- fois sélectionnée ; le tour en cours ajoute une lueur dorée intérieure.
function UI.ApplyRowCard(frame)
    local cuts,parts={0,24/128,104/128,1},{}
    for row=1,3 do for col=1,3 do
        local tex=frame:CreateTexture(nil,"BACKGROUND")
        tex:SetTexture(MEDIA.."SkillCard")
        tex:SetTexCoord(cuts[col],cuts[col+1],cuts[row],cuts[row+1])
        parts[#parts+1]=tex
    end end
    local function Layout()
        local w,h=frame:GetWidth() or 0,frame:GetHeight() or 0
        local k=math.max(1,math.min(10,w/2,h/2))
        local xs,ys={0,k,w-k,w},{0,k,h-k,h}
        for i,tex in ipairs(parts) do
            local row,col=math.floor((i-1)/3)+1,(i-1)%3+1
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT",frame,"TOPLEFT",xs[col],-ys[row])
            tex:SetPoint("BOTTOMRIGHT",frame,"TOPLEFT",xs[col+1],-ys[row+1])
        end
    end
    frame:HookScript("OnSizeChanged",Layout);Layout()
    -- Teinte et lueur restent à l'intérieur du filet bronze.
    local tint=frame:CreateTexture(nil,"BORDER")
    tint:SetPoint("TOPLEFT",4,-4);tint:SetPoint("BOTTOMRIGHT",-4,4)
    tint:SetColorTexture(unpack(UI.colors.rowSelection))
    local glow=frame:CreateTexture(nil,"BORDER",nil,1)
    glow:SetPoint("TOPLEFT",4,-4);glow:SetPoint("BOTTOMRIGHT",-4,4)
    glow:SetTexture(MEDIA.."Nexus\\NexusGlow");glow:SetBlendMode("ADD")
    local hl=UI.colors.turnHighlight;glow:SetVertexColor(hl[1],hl[2],hl[3],1);glow:SetAlpha(.35)
    local selected,turn=false,false
    local function Paint()
        local lit=(selected or turn) and 1 or .72
        for _,tex in ipairs(parts) do tex:SetVertexColor(lit,lit,lit,1) end
        tint:SetShown(selected);glow:SetShown(turn)
    end
    function frame:SetCardSelected(value) selected=value and true or false;Paint() end
    function frame:SetCardTurn(value) turn=value and true or false;Paint() end
    Paint()
end
UI.windowSkins=setmetatable({}, {__mode="k"})
function UI.SetWindowSkinOpacity(frame,alpha)
    for _,part in ipairs(frame.rpgSkin or {}) do part:SetAlpha(alpha) end
end
function UI.RegisterWindowSkin(frame)
    UI.ApplyBorder(frame)
    UI.windowSkins[frame]=true
    local saved=OS2DB and OS2DB.panelOpacity
    UI.SetWindowSkinOpacity(frame,saved or .95)
end
function UI.ApplyWindowBackground(texture,alpha)
    texture:SetColorTexture(0,0,0,0)
    local frame=texture:GetParent()
    UI.RegisterWindowSkin(frame)
    local saved=OS2DB and OS2DB.panelOpacity
    UI.SetWindowSkinOpacity(frame,math.max(0,math.min(1,alpha or saved or .95)))
end
function UI.ApplyTitle(text) text:SetTextColor(.91,.80,.57,1) end
function UI.ApplySeparator(texture,soft) texture:SetColorTexture(.58,.46,.26,soft and .32 or .65) end
function UI.CreatePanelButton(parent,w,h,label)
    local button=CreateFrame("Button",nil,parent)
    button:SetSize(w,h)
    UI.ApplyBorder(button)
    local bg=button:CreateTexture(nil,"ARTWORK")
    bg:SetPoint("TOPLEFT",5,-4);bg:SetPoint("BOTTOMRIGHT",-5,4)
    bg:SetTexture(MEDIA.."Nexus\\NexusGlow");bg:SetBlendMode("ADD");bg:SetAlpha(.06)
    local text=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetPoint("LEFT",7,0);text:SetPoint("RIGHT",-7,0);text:SetJustifyH("CENTER")
    text:SetWordWrap(false);text:SetText(label);text:SetTextColor(.92,.84,.67,1)
    button:SetFontString(text)
    local surface=button:CreateTexture(nil,"BACKGROUND")
    surface:SetPoint("TOPLEFT",5,-4);surface:SetPoint("BOTTOMRIGHT",-5,4)
    surface:SetColorTexture(.028,.039,.055,1);button.bgN=surface
    local accent=button:CreateTexture(nil,"BORDER");accent:SetPoint("BOTTOMLEFT",2,0);accent:SetPoint("BOTTOMRIGHT",-2,0);accent:SetHeight(1)
    accent:SetColorTexture(.65,.51,.29,0);button.accent=accent
    button:HookScript("OnEnter",function() bg:SetAlpha(.38) end)
    button:HookScript("OnLeave",function() bg:SetAlpha(.06) end)
    button:SetScript("OnDisable",function() text:SetAlpha(.35);bg:SetAlpha(0) end)
    button:SetScript("OnEnable",function() text:SetAlpha(1);bg:SetAlpha(.06) end)
    return button
end
function UI.CreateStyledCheckbox(parent,labelText)
    local button=CreateFrame("CheckButton",nil,parent)
    button:SetSize(18,18)
    local background=button:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints();background:SetColorTexture(0,0,0,0)
    UI.ApplyInputBorder(button)
    local check=button:CreateTexture(nil,"OVERLAY")
    check:SetPoint("CENTER");check:SetSize(16,16)
    check:SetTexture("Interface/Buttons/UI-CheckBox-Check")
    check:SetVertexColor(.95,.80,.48,1)
    button:SetCheckedTexture(check)
    local hover=button:CreateTexture(nil,"HIGHLIGHT")
    hover:SetAllPoints();hover:SetColorTexture(.65,.51,.29,.18)
    button:SetHighlightTexture(hover)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    label:SetText(labelText or "");label:SetTextColor(.89,.85,.74,1)
    label:SetPoint("LEFT",button,"RIGHT",5,0)
    button.label=label
    return button,label
end
function UI.ApplyInputBorder(frame)
    if frame.rpgInputBorder then return end
    frame.rpgInputBorder=true
    local bg=frame:CreateTexture(nil,"BACKGROUND",nil,2)
    bg:SetAllPoints();bg:SetColorTexture(.012,.019,.028,.97)
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local line=frame:CreateTexture(nil,"BORDER")
        line:SetColorTexture(.62,.49,.28,.9)
        if edge=="TOP" or edge=="BOTTOM" then
            line:SetPoint(edge.."LEFT");line:SetPoint(edge.."RIGHT");line:SetHeight(1)
        else
            line:SetPoint("TOP"..edge);line:SetPoint("BOTTOM"..edge);line:SetWidth(1)
        end
    end
end
function UI.CreateStyledEditBox(parent,w,h,multiLine)
    local box=CreateFrame("EditBox",nil,parent)
    box:SetSize(w,h or 22);box:SetFontObject("GameFontNormalSmall")
    box:SetTextColor(.91,.9,.84,1);box:SetAutoFocus(false);box:SetMultiLine(multiLine or false)
    box:SetMaxLetters(multiLine and 512 or 128);box:SetTextInsets(8,8,multiLine and 6 or 0,multiLine and 6 or 0)
    box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    if not multiLine then box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end) end
    UI.ApplyInputBorder(box)
    return box
end
function UI.ApplyTabState(button,active)
    if button.label then button.label:SetTextColor(active and .96 or .60,active and .82 or .66,active and .54 or .73) end
    if button.line then button.line:SetShown(active);button.line:SetColorTexture(.85,.68,.36,1) end
end
-- Every option remains visible; selecting one preserves the existing setters.
function UI.CreateChoiceStrip(parent,width,label,items,getValue,setValue)
    local holder=CreateFrame("Frame",nil,parent);holder:SetSize(width,label and 38 or 22)
    local title=holder:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    title:SetPoint("TOPLEFT",2,0);title:SetText(label or "");UI.ApplyTitle(title)
    local buttons={}
    local colors={hp={.43,.79,.48},mana={.30,.64,.95},endurance={.85,.28,.32}}
    function holder:Refresh()
        for i,button in ipairs(buttons) do
            local selected=getValue()==items[i].value
            button.selected:SetShown(selected)
            local col=colors[items[i].value] or {.95,.78,.45}
            button:GetFontString():SetTextColor(selected and col[1] or .65,selected and col[2] or .67,selected and col[3] or .65,1)
        end
    end
    for i,item in ipairs(items) do
        local button=UI.CreatePanelButton(holder,(width-8)/#items,22,item.label)
        button:SetPoint("TOPLEFT",(i-1)*((width-8)/#items+4),label and -16 or 0)
        -- Même retrait que le fond du bouton : rien ne dépasse de ses coins arrondis.
        local selected=button:CreateTexture(nil,"ARTWORK");selected:SetPoint("TOPLEFT",5,-4);selected:SetPoint("BOTTOMRIGHT",-5,4)
        selected:SetColorTexture(.58,.44,.19,.25)
        button.selected=selected;buttons[i]=button
        button:SetScript("OnClick",function() setValue(item.value);holder:Refresh() end)
    end
    holder:Refresh()
    return holder
end
-- No resource labels, values or tooltips: ally health is intentionally private.
function UI.HealthMini(parent,y)
    local bar=CreateFrame("Frame",nil,parent)
    bar:SetPoint("TOPLEFT",parent,"TOPLEFT",6,y);bar:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-6,y);bar:SetHeight(10)
    local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.025,.03,.03,1)
    local fill=bar:CreateTexture(nil,"ARTWORK");fill:SetPoint("TOPLEFT");fill:SetPoint("BOTTOMLEFT")
    fill:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Survive\\Core\\Media\\ResourceFill.tga");fill:SetVertexColor(.24,.65,.40,1)
    function bar:Refresh(stat)
        local width=math.max(1,self:GetWidth())
        local cur=stat and tonumber(stat.cur) or 0
        local maximum=math.max(1,stat and tonumber(stat.max) or 1)
        fill:SetWidth(math.max(.01,width*math.max(0,math.min(1,cur/maximum))));fill:SetShown(cur>0)
    end
    return bar
end

-- Bouton de fermeture rond (anneau doré, croix fine) : cartes ouvertes
-- depuis le chat et fenêtre « Utiliser ».
function UI.CreateCloseButton(parent,onClick)
    local close=CreateFrame("Button",nil,parent)
    close:SetSize(20,20)
    -- Default corner like the shared OS2.UI button; callers may re-anchor.
    close:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-8,-8)
    local closeMask=close:CreateMaskTexture()
    closeMask:SetAllPoints()
    closeMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    local closeBg=close:CreateTexture(nil,"BACKGROUND")
    closeBg:SetAllPoints();closeBg:SetColorTexture(.025,.035,.055,1);closeBg:AddMaskTexture(closeMask)
    local closeRim=close:CreateTexture(nil,"ARTWORK")
    closeRim:SetAllPoints()
    closeRim:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Survive\\Core\\Media\\InitiativeRing.tga")
    closeRim:SetVertexColor(.75,.64,.43,.85)
    local strokes={}
    for i=1,2 do
        local stroke=close:CreateTexture(nil,"OVERLAY")
        stroke:SetSize(9,1.4);stroke:SetPoint("CENTER")
        stroke:SetColorTexture(.88,.76,.52,1)
        stroke:SetRotation(i==1 and math.pi/4 or -math.pi/4)
        strokes[i]=stroke
    end
    close:SetScript("OnClick",onClick)
    local function CloseStyle(hover,pressed)
        closeBg:SetColorTexture(hover and .15 or .025,hover and .12 or .035,hover and .07 or .055,1)
        closeRim:SetVertexColor(hover and 1 or .75,hover and .9 or .64,hover and .65 or .43,1)
        for _,stroke in ipairs(strokes) do
            stroke:SetColorTexture(hover and 1 or .88,hover and .92 or .76,hover and .72 or .52,1)
            stroke:SetSize(pressed and 7 or 9,1.4)
        end
    end
    close:SetScript("OnEnter",function() CloseStyle(true,false) end)
    close:SetScript("OnLeave",function() CloseStyle(false,false) end)
    close:SetScript("OnMouseDown",function() CloseStyle(true,true) end)
    close:SetScript("OnMouseUp",function() CloseStyle(true,false) end)
    close:SetScript("OnHide",function() CloseStyle(false,false) end)
    return close
end



-- Legacy factories (dropdowns, labels) use the same palette as the RPG controls.
local previousColors=Base.colors
setmetatable(UI.colors,{__index=previousColors})
Base.colors=UI.colors


-- One unified clickable dropdown surface, retaining Blizzard's menu logic.
local StyleLegacyDropdown=UI.StyleDropdown
function UI.StyleDropdown(dd,...)
    StyleLegacyDropdown(dd,...)
    for _,part in ipairs({dd.Left,dd.Middle,dd.Right}) do part:SetAlpha(0) end
    local button=dd.Button
    if not button then return end
    button:SetNormalTexture("");button:SetPushedTexture("")
    button:SetDisabledTexture("");button:SetHighlightTexture("")
    local surface=dd.surviveSurface
    if not surface then
        surface=CreateFrame("Frame",nil,dd)
        dd.surviveSurface=surface
        surface:SetPoint("TOPLEFT",16,-4)
        surface:SetPoint("BOTTOMRIGHT",-16,4)
        surface:SetFrameLevel(math.max(0,dd:GetFrameLevel()-1))
        UI.ApplyBorder(surface)
        local fill=surface:CreateTexture(nil,"BACKGROUND",nil,3)
        fill:SetPoint("TOPLEFT",5,-5);fill:SetPoint("BOTTOMRIGHT",-5,5)
        fill:SetColorTexture(.025,.039,.055,1)
        local divider=button:CreateTexture(nil,"ARTWORK")
        divider:SetSize(1,12);divider:SetPoint("RIGHT",-31,0)
        divider:SetColorTexture(.65,.51,.29,.4)
        local strokes={}
        for i=1,2 do
            local t=button:CreateTexture(nil,"OVERLAY")
            t:SetSize(7,1.5);t:SetPoint("RIGHT",i==1 and -17 or -12,0)
            t:SetRotation(i==1 and -math.pi/4 or math.pi/4)
            t:SetColorTexture(.91,.78,.5,1);strokes[i]=t
        end
        local function paint(hover)
            local enabled=button:IsEnabled()
            fill:SetColorTexture(hover and .09 or .025,hover and .085 or .039,hover and .065 or .055,1)
            for _,t in ipairs(strokes) do t:SetAlpha(enabled and 1 or .3) end
            if dd.Text then dd.Text:SetAlpha(enabled and 1 or .4) end
        end
        button:HookScript("OnEnter",function() paint(true) end)
        button:HookScript("OnLeave",function() paint(false) end)
        button:HookScript("OnEnable",function() paint(false) end)
        button:HookScript("OnDisable",function() paint(false) end)
    end
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT",surface,"TOPLEFT",0,0)
    button:SetPoint("BOTTOMRIGHT",surface,"BOTTOMRIGHT",0,0)
    if dd.Text then
        dd.Text:ClearAllPoints()
        dd.Text:SetPoint("LEFT",surface,"LEFT",12,0)
        dd.Text:SetPoint("RIGHT",surface,"RIGHT",-38,0)
        dd.Text:SetJustifyH("LEFT")
        UI.ApplyBodyText(dd.Text)
    end
end
Base.StyleDropdown=UI.StyleDropdown
