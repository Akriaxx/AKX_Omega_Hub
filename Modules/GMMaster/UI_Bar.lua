-- ============================================================
--  GM Master — Barre MJ
--  Une barre de cases configurable : chaque case porte une macro
--  technique (une ou plusieurs commandes serveur). Clic : exécuter.
--  Clic droit : modifier. Maj + glisser : déplacer la case.
--  Poignée de gauche : glisser pour déplacer la barre, clic pour les
--  réglages, molette pour la taille des cases. Coin bas-droit : tirer
--  pour ajouter ou retirer des colonnes et des lignes.
-- ============================================================

local GM = GMMaster
local UI = OS2.UI

local HANDLE_W = 12
local GRIP_S   = 12

local ICON_READY = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t"
local ICON_ERROR = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12|t"
local ICON_WARN  = "|TInterface\\DialogFrame\\UI-Dialog-Icon-AlertNew:12|t"
GM.STATUS_ICONS = { ok = ICON_READY, warn = ICON_WARN, error = ICON_ERROR }

local function ShowTooltip(owner, lines, anchor)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_TOP")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:SetText(line, 1, 1, 1)
        else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

local function SetIcon(texture, icon)
    if not icon then texture:Hide() return false end
    local id = tonumber(icon)
    if id then texture:SetTexture(id)
    elseif icon:find("[/\\]") then texture:SetTexture(icon)
    else texture:SetTexture("Interface\\Icons\\" .. icon) end
    texture:Show()
    return true
end
GM.SetIconTexture = SetIcon

--- Lignes d'aide décrivant une macro (infobulle et éditeur).
function GM.DescribeMacro(text, withSyntax)
    local report, worst = GM.CheckMacro(text)
    local lines = {}
    for _, res in ipairs(report) do
        local line = GM.STATUS_ICONS[res.status] .. " |cffffffff" .. (res.slash and "" or ".") .. (res.short or res.raw) .. "|r"
        if withSyntax and res.node and res.node.syn then
            line = line .. "   |cff888888" .. res.node.syn .. "|r"
        end
        lines[#lines + 1] = line
        if res.problem then
            local color = res.status == "error" and "|cffdd5555" or "|cffddaa44"
            lines[#lines + 1] = "      " .. color .. res.problem .. "|r"
        end
    end
    if #report > GM.MACRO_LINES_MAX then
        lines[#lines + 1] = "|cffdd5555" .. GM.MACRO_LINES_MAX .. " lignes au plus|r"
    end
    return lines, worst
end

-- ── Cadre ─────────────────────────────────────────────────────────────────

local bar = CreateFrame("Frame", "GMMasterBar", UIParent, "BackdropTemplate")
bar:SetFrameStrata("MEDIUM")
bar:SetClampedToScreen(true)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:Hide()

local barBg = bar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints()
UI.ApplyWindowBackground(barBg, 0.80)
bar:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
bar:SetBackdropBorderColor(unpack(UI.colors.separator))

-- Poignée : déplacer (glisser), réglages (clic), taille (molette).
local handle = CreateFrame("Button", nil, bar)
handle:SetPoint("TOPLEFT", 1, -1)
handle:SetPoint("BOTTOMLEFT", 1, 1)
handle:SetWidth(HANDLE_W)
handle:RegisterForDrag("LeftButton")
handle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
handle:EnableMouseWheel(true)
local handleBg = handle:CreateTexture(nil, "ARTWORK")
handleBg:SetAllPoints()
handleBg:SetColorTexture(unpack(UI.colors.rowBgSelected))
local handleLine = handle:CreateTexture(nil, "OVERLAY")
handleLine:SetWidth(2)
handleLine:SetPoint("TOP", 0, -4)
handleLine:SetPoint("BOTTOM", 0, 4)
handleLine:SetColorTexture(unpack(UI.colors.tabLine))
local handleHl = handle:CreateTexture(nil, "HIGHLIGHT")
handleHl:SetAllPoints()
handleHl:SetColorTexture(unpack(UI.colors.tabHighlight))

-- Coin de redimensionnement
local grip = CreateFrame("Button", nil, bar)
grip:SetSize(GRIP_S, GRIP_S)
grip:SetPoint("BOTTOMRIGHT", 0, 0)
grip:SetFrameLevel((bar:GetFrameLevel() or 1) + 10)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

local buttons = {}
GM.barButtons = buttons

-- ── Placement ─────────────────────────────────────────────────────────────

local function SavePosition()
    local cfg = GM.EnsureBar()
    local left, top = bar:GetLeft(), bar:GetTop()
    if left and top then cfg.point = { x = math.floor(left + 0.5), y = math.floor(top + 0.5) } end
end

local function ApplyPosition()
    local cfg = GM.EnsureBar()
    bar:ClearAllPoints()
    if cfg.point then
        bar:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cfg.point.x, cfg.point.y)
    else
        bar:SetPoint("TOP", UIParent, "CENTER", 0, -180)
    end
end

-- ── Cases ─────────────────────────────────────────────────────────────────

local OpenEditor   -- défini plus bas

local function Flash(btn, ok)
    btn.flash:SetColorTexture(ok and 0.4 or 0.9, ok and 0.9 or 0.2, ok and 0.3 or 0.2, 0.45)
    btn.flash:Show()
    btn.flashUntil = (GetTime and GetTime() or 0) + 0.18
end

local function SlotTooltip(btn)
    if GM.dragSource then return end
    local slot = GM:GetSlot(btn.index)
    local tip
    if slot then
        tip = { GM.SlotLabel(slot) }
        local mode = GM.SlotMode(slot)
        if mode == "toggle" then
            local on, source = GM:SwitchState(slot)
            tip[#tip + 1] = "État : " .. (on and "|cff66dd66ON|r" or "|cff999999OFF|r")
                .. "  |cff888888(" .. GM.SWITCH_SOURCES[source] .. ")|r"
            tip[#tip + 1] = (on and "Clic : désactiver" or "Clic : activer")
            for _, line in ipairs((GM.DescribeMacro(GM.SwitchCommands(slot, not on)))) do tip[#tip + 1] = line end
        elseif mode == "alt" then
            tip[#tip + 1] = "Clic :"
            for _, line in ipairs((GM.DescribeMacro(slot.cmds))) do tip[#tip + 1] = line end
            tip[#tip + 1] = "Alt + clic :"
            for _, line in ipairs((GM.DescribeMacro(slot.cmdsAlt))) do tip[#tip + 1] = line end
        else
            for _, line in ipairs((GM.DescribeMacro(slot.cmds))) do tip[#tip + 1] = line end
        end
        tip[#tip + 1] = " "
        tip[#tip + 1] = "|cffAAAAAAClic : exécuter  ·  Clic droit : modifier|r"
        if not GM.EnsureBar().locked then tip[#tip + 1] = "|cffAAAAAAMaj + glisser : déplacer la case|r" end
    else
        tip = { "Case " .. btn.index .. " (vide)", "Clic : y mettre une macro technique." }
    end
    ShowTooltip(btn, tip)
end

local function SlotUnderCursor()
    for i, b in ipairs(buttons) do
        if b:IsShown() and b:IsMouseOver() then return i end
    end
end

-- ── Déplacement d'une case : retour visuel ────────────────────────────────
-- Pendant Maj + glisser, une vignette de la case suit le curseur, la case
-- visée est encadrée et une étiquette dit ce qui va se passer (déplacer
-- vers une case vide ou échanger). Au lâcher, les deux cases clignotent.

local ghost = CreateFrame("Frame", "GMMasterDragGhost", UIParent, "BackdropTemplate")
ghost:SetFrameStrata("TOOLTIP")
ghost:SetSize(36, 36)
ghost:EnableMouse(false)
ghost:SetAlpha(0.85)
ghost:Hide()
ghost:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
ghost:SetBackdropBorderColor(unpack(UI.colors.tabLine))
do
    local gbg = ghost:CreateTexture(nil, "BACKGROUND")
    gbg:SetAllPoints()
    gbg:SetColorTexture(unpack(UI.colors.panelButtonBg))
end
ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
ghost.icon:SetPoint("TOPLEFT", 1, -1)
ghost.icon:SetPoint("BOTTOMRIGHT", -1, 1)
ghost.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
ghost.label = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ghost.label:SetPoint("TOPLEFT", 2, -2)
ghost.label:SetPoint("BOTTOMRIGHT", -2, 2)
ghost.label:SetWordWrap(true)
ghost.label:SetJustifyH("CENTER")
UI.ApplyBodyText(ghost.label)
ghost.hint = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ghost.hint:SetPoint("TOPLEFT", ghost, "BOTTOMLEFT", 0, -3)
ghost.hint:SetShadowOffset(1, -1)
ghost.hint:SetShadowColor(0, 0, 0, 1)
GM.dragGhost = ghost

local function SetDropTarget(btn, mode)
    if not btn.drop then
        local drop = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        drop:SetAllPoints()
        drop:SetFrameLevel((btn:GetFrameLevel() or 1) + 5)
        drop:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
        local fill = drop:CreateTexture(nil, "OVERLAY")
        fill:SetAllPoints()
        drop.fill = fill
        btn.drop = drop
    end
    if not mode then btn.drop:Hide() return end
    local c = mode == "swap" and { 0.95, 0.75, 0.25 } or { 0.40, 0.90, 0.40 }
    btn.drop:SetBackdropBorderColor(c[1], c[2], c[3], 1)
    btn.drop.fill:SetColorTexture(c[1], c[2], c[3], 0.18)
    btn.drop:Show()
end

--- Met à jour la case visée et l'étiquette sous la vignette.
local function UpdateDrag()
    local from = GM.dragSource
    if not from then return end
    local to = SlotUnderCursor()
    if to == from then to = nil end
    if ghost.target ~= to then
        if ghost.target and buttons[ghost.target] then SetDropTarget(buttons[ghost.target], nil) end
        ghost.target = to
        if to then SetDropTarget(buttons[to], GM:GetSlot(to) and "swap" or "move") end
    end
    if not to then
        ghost.hint:SetText("|cffAAAAAALâcher sur une case|r")
    elseif GM:GetSlot(to) then
        ghost.hint:SetText("|cffF2C040Échanger avec la case " .. to .. "|r")
    else
        ghost.hint:SetText("|cff66dd66Déplacer vers la case " .. to .. "|r")
    end
end
GM.UpdateSlotDrag = UpdateDrag

ghost:SetScript("OnUpdate", function(self)
    if GetCursorPosition then
        local scale = UIParent:GetEffectiveScale() or 1
        local x, y = GetCursorPosition()
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale - 10)
    end
    UpdateDrag()
end)

local function StartSlotDrag(btn)
    local slot = GM:GetSlot(btn.index)
    GM.dragSource = btn.index
    btn:SetAlpha(0.35)
    local size = GM.EnsureBar().size
    ghost:SetSize(size, size)
    local hasIcon = SetIcon(ghost.icon, slot.icon)
    ghost.label:SetShown(not hasIcon)
    ghost.label:SetText(GM.SlotLabel(slot))
    ghost.target = nil
    ghost:Show()
    UpdateDrag()
end

--- Termine le glisser ; renvoie la case de départ et la case d'arrivée.
local function StopSlotDrag(btn)
    local from = GM.dragSource
    UpdateDrag()
    local to = ghost.target
    GM.dragSource = nil
    btn:SetAlpha(1)
    if to and buttons[to] then SetDropTarget(buttons[to], nil) end
    ghost.target = nil
    ghost:Hide()
    return from, to
end

local function CreateSlot(i)
    local btn = CreateFrame("Button", nil, bar)
    btn.index = i
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.panelButtonBg))
    btn.bg = bg

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icon:Hide()
    btn.icon = icon

    local accent = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    accent:SetHeight(1)
    accent:SetPoint("BOTTOMLEFT", 2, 1)
    accent:SetPoint("BOTTOMRIGHT", -2, 1)
    accent:SetColorTexture(unpack(UI.colors.panelButtonAccent))
    btn.accent = accent

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", 2, -2)
    label:SetPoint("BOTTOMRIGHT", -2, 2)
    label:SetWordWrap(true)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetShadowOffset(1, -1)
    label:SetShadowColor(0, 0, 0, 1)
    UI.ApplyBodyText(label)
    btn.label = label

    local key = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    key:SetPoint("TOPRIGHT", -2, -2)
    btn.key = key

    local badge = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    badge:SetPoint("BOTTOMRIGHT", -2, 2)
    badge:SetShadowOffset(1, -1)
    badge:SetShadowColor(0, 0, 0, 1)
    btn.badge = badge

    local status = btn:CreateTexture(nil, "OVERLAY")
    status:SetSize(10, 10)
    status:SetPoint("TOPLEFT", 1, -1)
    status:Hide()
    btn.status = status

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.12)

    local flash = btn:CreateTexture(nil, "OVERLAY", nil, 3)
    flash:SetAllPoints()
    flash:Hide()
    btn.flash = flash
    btn:SetScript("OnUpdate", function(self)
        if self.flashUntil and (GetTime and GetTime() or 0) > self.flashUntil then
            self.flash:Hide(); self.flashUntil = nil
        end
    end)

    btn:SetScript("OnClick", function(self, button)
        local now = GetTime and GetTime() or 0
        if self.dragged and now - self.dragged < 0.3 then self.dragged = nil return end
        self.dragged = nil
        local slot = GM:GetSlot(self.index)
        if button == "RightButton" or not slot then
            OpenEditor(self.index)
            return
        end
        local ok = GM:RunSlot(self.index, IsAltKeyDown and IsAltKeyDown())
        Flash(self, ok)
    end)
    btn:SetScript("OnDragStart", function(self)
        if GM.EnsureBar().locked or not (IsShiftKeyDown and IsShiftKeyDown()) then return end
        if not GM:GetSlot(self.index) then return end
        HideTooltip()
        StartSlotDrag(self)
    end)
    btn:SetScript("OnDragStop", function(self)
        if not GM.dragSource then return end
        local from, to = StopSlotDrag(self)
        self.dragged = GetTime and GetTime() or 0
        if to then
            GM:SwapSlots(from, to)
            Flash(buttons[from], true)
            Flash(buttons[to], true)
        end
    end)
    btn:SetScript("OnEnter", SlotTooltip)
    btn:SetScript("OnLeave", HideTooltip)
    return btn
end

local function BindingText(i)
    if i > 12 or not GetBindingKey then return "" end
    local k = GetBindingKey("OMEGA_GMMASTER_SLOT" .. i)
    if not k then return "" end
    if GetBindingText then k = GetBindingText(k, true) or k end
    return (k:gsub("SHIFT%-", "M"):gsub("CTRL%-", "C"):gsub("ALT%-", "A"))
end

local function Layout()
    local cfg = GM.EnsureBar()
    local size, gap = cfg.size, cfg.gap
    local count = cfg.cols * cfg.rows
    local pad = math.max(gap, 2)
    bar:SetSize(HANDLE_W + 1 + pad + cfg.cols * size + (cfg.cols - 1) * gap + pad,
                pad + cfg.rows * size + (cfg.rows - 1) * gap + pad)
    for i = 1, math.max(count, #buttons) do
        local btn = buttons[i]
        if i <= count then
            btn = btn or CreateSlot(i)
            buttons[i] = btn
            local col, row = (i - 1) % cfg.cols, math.floor((i - 1) / cfg.cols)
            btn:ClearAllPoints()
            btn:SetSize(size, size)
            btn:SetPoint("TOPLEFT", HANDLE_W + 1 + pad + col * (size + gap), -(pad + row * (size + gap)))
            btn:Show()
        elseif btn then
            btn:Hide()
        end
    end
    grip:SetShown(not cfg.locked)
end

local function RefreshSlots()
    local cfg = GM.EnsureBar()
    for i = 1, cfg.cols * cfg.rows do
        local btn = buttons[i]
        local slot = cfg.slots[i]
        if slot then
            local hasIcon = SetIcon(btn.icon, slot.icon)
            btn.label:SetShown(not hasIcon or cfg.labels)
            btn.label:SetText(GM.SlotLabel(slot))
            if hasIcon then
                btn.label:SetJustifyV("BOTTOM")
            else
                btn.label:SetJustifyV("MIDDLE")
            end
            local _, worst = GM.CheckMacro(slot.cmds)
            if worst == "error" then
                btn.status:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady"); btn.status:Show()
            elseif worst == "warn" then
                btn.status:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"); btn.status:Show()
            else
                btn.status:Hide()
            end
            btn.bg:SetColorTexture(unpack(UI.colors.panelButtonBg))
            btn.accent:Show()
            local mode = GM.SlotMode(slot)
            if mode == "toggle" then
                local on = GM:SwitchState(slot)
                btn.badge:SetText(on and "|cff66dd66ON|r" or "|cff999999OFF|r")
                btn.accent:SetHeight(on and 3 or 1)
                btn.accent:SetColorTexture(unpack(on and { 0.35, 0.85, 0.35, 1 } or UI.colors.panelButtonAccent))
                if btn.icon:IsShown() then btn.icon:SetDesaturated(not on) end
            else
                btn.badge:SetText(mode == "alt" and "|cffAAAAAAAlt|r" or "")
                btn.accent:SetHeight(1)
                btn.accent:SetColorTexture(unpack(UI.colors.panelButtonAccent))
                btn.icon:SetDesaturated(false)
            end
        else
            btn.badge:SetText("")
            btn.icon:Hide()
            btn.status:Hide()
            btn.label:Show()
            btn.label:SetJustifyV("MIDDLE")
            btn.label:SetText(cfg.locked and "" or "|cff555555+|r")
            btn.bg:SetColorTexture(0.06, 0.06, 0.06, cfg.locked and 0.35 or 0.8)
            btn.accent:Hide()
        end
        btn.key:SetText(BindingText(i))
    end
end

local function RefreshBar()
    if not bar:IsShown() then return end
    Layout()
    RefreshSlots()
end
GM.RefreshBar = RefreshBar

bar:SetScript("OnShow", function()
    ApplyPosition()
    Layout()
    RefreshSlots()
end)
bar:SetScript("OnHide", function()
    if GM.dragSource and buttons[GM.dragSource] then StopSlotDrag(buttons[GM.dragSource]) end
end)

-- ── Poignée ───────────────────────────────────────────────────────────────

local OpenSettings   -- défini plus bas

handle:SetScript("OnDragStart", function()
    if GM.EnsureBar().locked then return end
    bar:StartMoving()
end)
handle:SetScript("OnDragStop", function()
    bar:StopMovingOrSizing()
    SavePosition()
    ApplyPosition()
    handle.moved = GetTime and GetTime() or 0
end)
handle:SetScript("OnClick", function()
    local now = GetTime and GetTime() or 0
    if handle.moved and now - handle.moved < 0.3 then handle.moved = nil return end
    handle.moved = nil
    OpenSettings()
end)
handle:SetScript("OnMouseWheel", function(_, delta)
    local cfg = GM.EnsureBar()
    GM:SetBarOption("size", cfg.size + (delta > 0 and 2 or -2))
end)
handle:SetScript("OnEnter", function(self)
    local cfg = GM.EnsureBar()
    ShowTooltip(self, {
        "Barre MJ",
        cfg.locked and "Verrouillée." or "Glisser : déplacer la barre.",
        "Clic : réglages  ·  Molette : taille des cases (" .. cfg.size .. ")",
        cfg.locked and "" or "Coin bas-droit : tirer pour changer colonnes et lignes.",
    }, "ANCHOR_LEFT")
end)
handle:SetScript("OnLeave", HideTooltip)

-- ── Redimensionnement par le coin ─────────────────────────────────────────

local function GripUpdate()
    local cfg = GM.EnsureBar()
    local left, top = bar:GetLeft(), bar:GetTop()
    if not (left and top and GetCursorPosition) then return end
    local scale = bar:GetEffectiveScale() or 1
    local cx, cy = GetCursorPosition()
    cx, cy = cx / scale, cy / scale
    local pad = math.max(cfg.gap, 2)
    local step = cfg.size + cfg.gap
    local cols = math.floor((cx - left - HANDLE_W - 1 - pad + cfg.gap) / step + 0.5)
    local rows = math.floor((top - cy - pad + cfg.gap) / step + 0.5)
    local lc, lr = GM.BAR_LIMITS.cols, GM.BAR_LIMITS.rows
    cols = math.max(lc[1], math.min(lc[2], cols))
    rows = math.max(lr[1], math.min(lr[2], rows))
    if cols ~= cfg.cols or rows ~= cfg.rows then
        cfg.cols, cfg.rows = cols, rows
        GM.Notify()
    end
end

grip:SetScript("OnMouseDown", function(self)
    self:SetScript("OnUpdate", GripUpdate)
end)
grip:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
end)
grip:SetScript("OnEnter", function(self)
    local cfg = GM.EnsureBar()
    ShowTooltip(self, { "Redimensionner", cfg.cols .. " colonnes × " .. cfg.rows .. " lignes",
        "Les macros des cases masquées sont conservées." })
end)
grip:SetScript("OnLeave", HideTooltip)

-- ── Réglages ──────────────────────────────────────────────────────────────

local settings = CreateFrame("Frame", "GMMasterBarSettings", UIParent, "BackdropTemplate")
settings:SetSize(250, 296)
settings:SetFrameStrata("DIALOG")
settings:SetClampedToScreen(true)
settings:EnableMouse(true)
settings:Hide()
tinsert(UISpecialFrames, "GMMasterBarSettings")
do
    local sbg = settings:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    UI.ApplyWindowBackground(sbg, 0.97)
    settings:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    settings:SetBackdropBorderColor(unpack(UI.colors.separator))
    local t = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOPLEFT", 14, -12)
    t:SetText("Barre MJ — réglages")
    UI.ApplyTitle(t)
    UI.CreateCloseButton(settings, function() settings:Hide() end)
end

settings.steppers = {}
local function Stepper(y, key, label, step)
    local fs = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 16, y - 4)
    fs:SetText(label)
    UI.ApplyLabel(fs)
    local minus = UI.CreatePanelButton(settings, 22, 20, "-")
    minus:SetPoint("TOPLEFT", 130, y)
    local value = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    value:SetPoint("LEFT", minus, "RIGHT", 0, 0)
    value:SetWidth(44)
    value:SetJustifyH("CENTER")
    UI.ApplyBodyText(value)
    local plus = UI.CreatePanelButton(settings, 22, 20, "+")
    plus:SetPoint("LEFT", minus, "RIGHT", 44, 0)
    minus:SetScript("OnClick", function() GM:SetBarOption(key, GM.EnsureBar()[key] - step) end)
    plus:SetScript("OnClick", function() GM:SetBarOption(key, GM.EnsureBar()[key] + step) end)
    settings.steppers[key] = { value = value, minus = minus, plus = plus }
end
Stepper(-40, "cols", "Colonnes", 1)
Stepper(-66, "rows", "Lignes", 1)
Stepper(-92, "size", "Taille des cases", 2)
Stepper(-118, "gap", "Espacement", 1)

local function Check(y, key, label)
    local cb, lbl = UI.CreateStyledCheckbox(settings, label)
    cb:SetPoint("TOPLEFT", 16, y)
    lbl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    cb:SetScript("OnClick", function(self) GM:SetBarOption(key, self:GetChecked() and true or false) end)
    return cb
end
settings.lock   = Check(-150, "locked", "Verrouiller la barre")
settings.labels = Check(-176, "labels", "Libellés sur les icônes")

local openPanel = UI.CreatePanelButton(settings, 106, 22, "GM Master")
openPanel:SetPoint("TOPLEFT", 16, -206)
openPanel:SetScript("OnClick", function() if GMMasterPanel then GMMasterPanel:Show() end end)
local openBank = UI.CreatePanelButton(settings, 106, 22, "Banque MJ")
openBank:SetPoint("LEFT", openPanel, "RIGHT", 6, 0)
openBank:SetScript("OnClick", function() if GM.ToggleAuraBank then GM:ToggleAuraBank(true) end end)

local hideBar = UI.CreatePanelButton(settings, 106, 22, "Masquer")
hideBar:SetPoint("TOPLEFT", 16, -234)
hideBar:SetScript("OnClick", function() settings:Hide(); GM:ToggleBar(false) end)
hideBar:SetScript("OnEnter", function(self) ShowTooltip(self, { "Masquer la barre", "/gmm barre pour la réafficher." }) end)
hideBar:SetScript("OnLeave", HideTooltip)

local resetPos = UI.CreatePanelButton(settings, 106, 22, "Recentrer")
resetPos:SetPoint("LEFT", hideBar, "RIGHT", 6, 0)
resetPos:SetScript("OnClick", function() GM.EnsureBar().point = nil; ApplyPosition() end)

local clearAll = UI.CreatePanelButton(settings, 218, 22, "Vider toutes les cases")
clearAll:SetPoint("TOPLEFT", 16, -262)
clearAll:SetScript("OnClick", function(self)
    local now = GetTime and GetTime() or 0
    if self.armed and now - self.armed < 3 then
        GM.EnsureBar().slots = {}
        self.armed = nil
        self:SetText("Vider toutes les cases")
        GM.Notify()
    else
        self.armed = now
        self:SetText("|cffdd5555Cliquer encore pour confirmer|r")
    end
end)

local function RefreshSettings()
    if not settings:IsShown() then return end
    local cfg = GM.EnsureBar()
    for key, s in pairs(settings.steppers) do
        s.value:SetText(cfg[key])
    end
    settings.lock:SetChecked(cfg.locked)
    settings.labels:SetChecked(cfg.labels)
end

settings:SetScript("OnShow", function()
    clearAll.armed = nil
    clearAll:SetText("Vider toutes les cases")
    RefreshSettings()
end)

function OpenSettings()
    if settings:IsShown() then settings:Hide() return end
    settings:ClearAllPoints()
    settings:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 6)
    settings:Show()
end
GM.OpenBarSettings = OpenSettings

-- ── Éditeur de case ───────────────────────────────────────────────────────
-- À gauche : les recettes (Aura de PNJ, Vitesse, Triche on / off…). On
-- choisit, on tape seulement l'ID ou la valeur, la case se construit.
-- « Commande libre » garde l'écriture à la main pour le reste.

local EDIT_W, EDIT_H = 660, 540
local NAV_W = 180
local X = NAV_W + 24
local RW = EDIT_W - X - 16

local editor = CreateFrame("Frame", "GMMasterMacroEditor", UIParent, "BackdropTemplate")
editor:SetSize(EDIT_W, EDIT_H)
editor:SetPoint("CENTER", 0, 40)
editor:SetFrameStrata("DIALOG")
editor:SetFrameLevel(100)
editor:SetClampedToScreen(true)
editor:SetMovable(true)
editor:EnableMouse(true)
editor:RegisterForDrag("LeftButton")
editor:SetScript("OnDragStart", editor.StartMoving)
editor:SetScript("OnDragStop", editor.StopMovingOrSizing)
editor:Hide()
tinsert(UISpecialFrames, "GMMasterMacroEditor")
do
    local ebg = editor:CreateTexture(nil, "BACKGROUND")
    ebg:SetAllPoints()
    UI.ApplyWindowBackground(ebg, 0.98)
    editor:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    editor:SetBackdropBorderColor(unpack(UI.colors.separator))
    UI.CreateCloseButton(editor, function() editor:Hide() end)
    local nbg = editor:CreateTexture(nil, "BACKGROUND", nil, 1)
    nbg:SetPoint("TOPLEFT", 4, -42)
    nbg:SetPoint("BOTTOMLEFT", 4, 48)
    nbg:SetWidth(NAV_W + 8)
    UI.ApplyWindowBackground(nbg, 0.45)
    local sep = editor:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", 4, -42)
    sep:SetPoint("TOPRIGHT", -4, -42)
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)
end

local edTitle = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
edTitle:SetPoint("TOPLEFT", 16, -14)
UI.ApplyTitle(edTitle)

local function Text(x, y, template, color)
    local fs = editor:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetJustifyH("LEFT")
    if color then UI[color](fs) else UI.ApplyLabel(fs) end
    return fs
end

-- ── Liste des recettes ────────────────────────────────────────────────────

editor.navButtons = {}
for i, recipe in ipairs(GM.SlotRecipes) do
    local btn = CreateFrame("Button", nil, editor)
    btn:SetSize(NAV_W, 24)
    btn:SetPoint("TOPLEFT", 8, -48 - (i - 1) * 26)
    local active = btn:CreateTexture(nil, "BACKGROUND")
    active:SetAllPoints()
    active:SetColorTexture(unpack(UI.colors.rowBgSelected))
    btn.active = active
    local line = btn:CreateTexture(nil, "ARTWORK")
    line:SetWidth(3)
    line:SetPoint("TOPLEFT")
    line:SetPoint("BOTTOMLEFT")
    line:SetColorTexture(unpack(UI.colors.tabLine))
    btn.line = line
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.tabHighlight))
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", 12, 0)
    label:SetText(recipe.title)
    btn.label = label
    btn.recipe = recipe
    editor.navButtons[recipe.key] = btn
end

-- ── Zone de la recette ────────────────────────────────────────────────────

local recTitle = Text(X, -50, "GameFontNormalLarge", "ApplyTitle")
local recDesc = Text(X, -74, nil, "ApplySoftText")
recDesc:SetWidth(RW)
recDesc:SetWordWrap(true)

-- Champ unique (ID, valeur, lieu)
local fieldLabel = Text(X, -114)
local fieldBox = UI.CreateStyledEditBox(editor, 150, 22)
fieldBox:SetPoint("TOPLEFT", X + 110, -108)
editor.fieldBox = fieldBox
local spellFS = Text(X + 270, -114, nil, "ApplyBodyText")
spellFS:SetWidth(RW - 270)
spellFS:SetWordWrap(false)

-- Choix en boutons
local PICK_COLS, PICK_MAX = 3, 12
local PICK_W = math.floor((RW - (PICK_COLS - 1) * 6) / PICK_COLS)
editor.pickButtons = {}
for i = 1, PICK_MAX do
    local col, row = (i - 1) % PICK_COLS, math.floor((i - 1) / PICK_COLS)
    local b = UI.CreatePanelButton(editor, PICK_W, 24, "")
    b:SetPoint("TOPLEFT", X + col * (PICK_W + 6), -132 - row * 30)
    local sel = b:CreateTexture(nil, "ARTWORK", nil, 1)
    sel:SetPoint("TOPLEFT", 0, 0)
    sel:SetPoint("BOTTOMRIGHT", 0, 0)
    sel:SetColorTexture(unpack(UI.colors.rowSelection))
    b.sel = sel
    editor.pickButtons[i] = b
end

-- Commande libre : type + deux zones de saisie de taille fixe
local function CommandBox(h)
    local box = CreateFrame("Frame", nil, editor)
    box:SetSize(RW, h)
    box:EnableMouse(true)
    box:SetClipsChildren(true)
    local bg = box:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local accent = box:CreateTexture(nil, "ARTWORK")
    accent:SetHeight(1)
    accent:SetPoint("BOTTOMLEFT", 2, 1)
    accent:SetPoint("BOTTOMRIGHT", -2, 1)
    accent:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local eb = CreateFrame("EditBox", nil, box)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontNormalSmall")
    UI.ApplyBodyText(eb)
    eb:SetMaxLetters(1024)
    eb:SetPoint("TOPLEFT", 8, -6)
    eb:SetPoint("TOPRIGHT", -8, -6)
    eb:SetHeight(h - 12)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)
    box.eb = eb
    return box
end

editor.mode = "simple"
local modeBtn = UI.CreatePanelButton(editor, 220, 22, "")
modeBtn:SetPoint("TOPLEFT", X, -104)
modeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
editor.modeBtn = modeBtn
local freeHint = Text(X + 230, -110, nil, "ApplySoftText")
freeHint:SetText("Une ligne = une commande  ·  /run, /reload…  ·  {cible}  {moi}")
local box1Label = Text(X, -134)
local box1 = CommandBox(150)
box1:SetPoint("TOPLEFT", X, -148)
local box2Label = Text(X, -224)
local box2 = CommandBox(60)
box2:SetPoint("TOPLEFT", X, -238)
editor.cmdBox, editor.secondBox, editor.secondArea = box1.eb, box2.eb, box2

modeBtn:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Type de case",
        "|cffffffffSimple|r : le clic envoie les commandes.",
        "|cffffffffInterrupteur on / off|r : le clic active ou désactive selon l'état actuel. "
            .. "Écrire [on/off] dans une ligne (ex. cheat fly [on/off]) ou remplir la seconde zone.",
        "|cffffffffClic / Alt + clic|r : une commande au clic, une autre avec Alt." })
end)
modeBtn:SetScript("OnLeave", HideTooltip)

-- Libellé et icône
Text(X, -318):SetText("Libellé")
local labelBox = UI.CreateStyledEditBox(editor, 200, 22)
labelBox:SetPoint("TOPLEFT", X + 110, -312)
labelBox:SetMaxLetters(24)
editor.labelBox = labelBox
Text(X, -348):SetText("Icône")
local iconBox = UI.CreateStyledEditBox(editor, 150, 22)
iconBox:SetPoint("TOPLEFT", X + 110, -342)
editor.iconBox = iconBox
local iconPick = UI.CreatePanelButton(editor, 80, 22, "Choisir…")
iconPick:SetPoint("LEFT", iconBox, "RIGHT", 6, 0)
local iconPreview = editor:CreateTexture(nil, "ARTWORK")
iconPreview:SetSize(52, 52)
iconPreview:SetPoint("TOPRIGHT", -16, -312)
iconPreview:SetTexCoord(0.07, 0.93, 0.07, 0.93)

-- Aperçu
local previewTitle = Text(X, -380)
previewTitle:SetText("Ce que fera la case")
UI.ApplyStrongLabel(previewTitle)
local report = Text(X, -398, nil, "ApplyBodyText")
report:SetWidth(RW)
report:SetHeight(86)
report:SetJustifyV("TOP")
report:SetWordWrap(true)
editor.report = report

-- Boutons du bas
local saveBtn = UI.CreatePanelButton(editor, 110, 24, "Enregistrer")
saveBtn:SetPoint("BOTTOMLEFT", 16, 14)
local saveNextBtn = UI.CreatePanelButton(editor, 180, 24, "Enregistrer + case suivante")
saveNextBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
local testBtn = UI.CreatePanelButton(editor, 90, 24, "Tester")
testBtn:SetPoint("LEFT", saveNextBtn, "RIGHT", 8, 0)
local clearBtn = UI.CreatePanelButton(editor, 110, 24, "Vider la case")
clearBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)
local cancelBtn = UI.CreatePanelButton(editor, 90, 24, "Annuler")
cancelBtn:SetPoint("LEFT", clearBtn, "RIGHT", 8, 0)
editor.saveBtn, editor.saveNextBtn, editor.testBtn, editor.clearBtn = saveBtn, saveNextBtn, testBtn, clearBtn

-- ── Logique ───────────────────────────────────────────────────────────────

editor.values = {}   -- [recette] = valeurs saisies

local function Values()
    local key = editor.recipe.key
    editor.values[key] = editor.values[key] or {}
    return editor.values[key]
end

local FREE_TEXT = {
    simple = { first = "Commandes" },
    toggle = { first = "Pour activer", second = "Pour désactiver  |cff888888(facultatif avec [on/off])|r" },
    alt    = { first = "Clic", second = "Avec Alt + clic" },
}

local function ApplyMode(mode)
    editor.mode = mode
    modeBtn:SetText("Type : " .. GM.SLOT_MODE_LABELS[mode])
    box1Label:SetText(FREE_TEXT[mode].first)
    local two = mode ~= "simple"
    box1:SetHeight(two and 66 or 150)
    box1.eb:SetHeight(two and 54 or 138)
    box2Label:SetText(FREE_TEXT[mode].second or "")
    box2Label:SetShown(two)
    box2:SetShown(two)
end

--- Résultat courant : { mode, cmds, second, label, icon } ou nil + erreur.
local function Current()
    if editor.recipe.free then
        local cmds = box1.eb:GetText()
        if GM.Trim(cmds) == "" then return nil, "Écrire au moins une commande" end
        local second = box2.eb:GetText()
        if editor.mode == "simple" then second = nil end
        return { mode = editor.mode, cmds = cmds, second = second, label = GM.SlotLabel({ cmds = cmds }) }
    end
    return GM.BuildRecipe(editor.recipe, Values())
end

local function Describe(title, text, lines)
    lines[#lines + 1] = "|cffAAAAAA" .. title .. "|r"
    local more, worst = GM.DescribeMacro(text, editor.recipe.free)
    for _, l in ipairs(more) do lines[#lines + 1] = l end
    return worst
end

local RANK = { ok = 1, warn = 2, error = 3, empty = 3 }

function editor:Validate()
    local recipe = self.recipe
    -- Nom du sort à côté de l'ID
    local field = recipe.fields[1]
    if field and field.spell then
        local id = Values()[field.key]
        local name, icon, spellID = GM.SpellInfo(id)
        local caption = tonumber(id) and name or (spellID and tostring(spellID))
        spellFS:SetText(caption and ((icon and ("|T" .. icon .. ":16|t ") or "") .. caption)
            or (GM.Trim(id) ~= "" and "|cff888888Sort inconnu|r" or ""))
    else
        spellFS:SetText("")
    end

    local built, err = Current()
    self.built = built
    local lines, worst = {}, "ok"
    if not built then
        lines[1] = ICON_ERROR .. " |cffdd5555" .. err .. "|r"
        worst = "error"
    else
        -- Libellé et icône suivent la saisie tant qu'on ne les a pas changés
        if self.labelAuto then labelBox:SetText(built.label or "") end
        if self.iconAuto then iconBox:SetText(built.icon or "") end
        local function Merge(w) if RANK[w] > RANK[worst] then worst = w end end
        if built.mode == "toggle" then
            Merge(Describe("Clic quand OFF : active", GM.ApplySwitchToken(built.cmds, true), lines))
            local off = (built.second and GM.Trim(built.second) ~= "") and built.second or GM.ApplySwitchToken(built.cmds, false)
            Merge(Describe("Clic quand ON : désactive", off, lines))
        elseif built.mode == "alt" then
            Merge(Describe("Clic :", built.cmds, lines))
            Merge(Describe("Alt + clic :", built.second or "", lines))
        else
            Merge(Describe("Clic :", built.cmds, lines))
        end
        local problem = recipe.free and GM.SlotModeProblem(built.mode, built.cmds, built.second)
        if problem then
            lines[#lines + 1] = ICON_ERROR .. " |cffdd5555" .. problem .. "|r"
            worst = "error"
        end
    end
    report:SetText(table.concat(lines, "\n"))
    local hasIcon = SetIcon(iconPreview, GM.Trim(iconBox:GetText()) ~= "" and GM.Trim(iconBox:GetText()) or nil)
    iconPreview:SetShown(hasIcon)
    self.worst = worst
end

local function RenderRecipe()
    local recipe = editor.recipe
    for key, btn in pairs(editor.navButtons) do
        local on = key == recipe.key
        btn.active:SetShown(on)
        btn.line:SetShown(on)
        btn.label:SetTextColor(unpack(on and UI.colors.title or UI.colors.textMuted))
    end
    recTitle:SetText(recipe.title)
    recDesc:SetText(recipe.desc or "")

    local free = recipe.free and true or false
    modeBtn:SetShown(free); freeHint:SetShown(free); box1Label:SetShown(free); box1:SetShown(free)
    if free then ApplyMode(editor.mode) else box2Label:Hide(); box2:Hide() end

    local field = recipe.fields[1]
    local isPick = field and field.kind == "pick"
    fieldLabel:SetShown(field ~= nil and not free)
    fieldLabel:SetText(field and field.label or "")
    fieldBox:SetShown(field ~= nil and not isPick)
    spellFS:SetShown(field ~= nil and not isPick)
    if field and not isPick then
        fieldBox:SetNumeric(field.kind == "id" and not field.spell)
        fieldBox:SetWidth(field.kind == "text" and 260 or 150)
        local v = Values()[field.key]
        if v == nil then v = field.default or ""; Values()[field.key] = v end
        fieldBox:SetText(v)
    end
    for i, b in ipairs(editor.pickButtons) do
        local opt = isPick and field.options[i]
        b.value = opt and opt.value or nil
        if opt then
            b:SetText(opt.label)
            b.sel:SetShown(Values()[field.key] == opt.value)
            b:Show()
        else
            b:Hide()
        end
    end
    editor:Validate()
end

local function SelectRecipe(key, keepLabel)
    editor.recipe = GM.RecipeByKey[key] or GM.SlotRecipes[1]
    if not keepLabel then
        editor.labelAuto, editor.iconAuto = true, true
        if editor.recipe.free then labelBox:SetText(""); iconBox:SetText("") end
    end
    RenderRecipe()
end
editor.SelectRecipe = SelectRecipe

for key, btn in pairs(editor.navButtons) do
    btn:SetScript("OnClick", function() SelectRecipe(key) end)
end
for _, b in ipairs(editor.pickButtons) do
    b:SetScript("OnClick", function(self)
        local field = editor.recipe.fields[1]
        if not (field and self.value) then return end
        Values()[field.key] = self.value
        RenderRecipe()
    end)
end
fieldBox:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local field = editor.recipe.fields[1]
    if field then Values()[field.key] = self:GetText() end
    editor:Validate()
end)
modeBtn:SetScript("OnClick", function(_, button)
    local list, idx = GM.SLOT_MODES, 1
    for i, m in ipairs(list) do if m == editor.mode then idx = i end end
    idx = button == "RightButton" and ((idx - 2) % #list + 1) or (idx % #list + 1)
    ApplyMode(list[idx])
    editor:Validate()
end)
box1.eb:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    if GM.HasSwitchToken(self:GetText()) and editor.mode ~= "toggle" then ApplyMode("toggle") end
    editor:Validate()
end)
box2.eb:SetScript("OnTextChanged", function(_, user) if user then editor:Validate() end end)
labelBox:SetScript("OnTextChanged", function(self, user)
    if user then editor.labelAuto = GM.Trim(self:GetText()) == "" end
end)
iconBox:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    editor.iconAuto = GM.Trim(self:GetText()) == ""
    editor:Validate()
end)
iconPick:SetScript("OnClick", function()
    local browser = OmegaSpell and OmegaSpell.IconBrowser
    if browser and browser.Open then
        browser.Open(function(path)
            iconBox:SetText(path or "")
            editor.iconAuto = false
            editor:Validate()
        end)
    end
end)
iconPick:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Choisir une icône", "Facultatif : l'icône du sort est reprise toute seule. "
        .. "Accepte aussi un nom (INV_Misc_Gear_01), un chemin ou un ID de fichier." })
end)
iconPick:SetScript("OnLeave", HideTooltip)

--- Enregistre la case. Renvoie true si c'est fait.
local function Save()
    editor:Validate()
    local built = editor.built
    if not built or editor.worst == "error" then return false end
    local opts
    if editor.recipe.free then
        opts = { mode = built.mode, cmdsOff = built.second, cmdsAlt = built.second }
    else
        opts = GM.RecipeSlotOptions(editor.recipe, Values(), built)
    end
    GM:SetSlot(editor.index, labelBox:GetText(), built.cmds, iconBox:GetText(), opts)
    GM.EnsureBar().lastRecipe = editor.recipe.key
    return true
end

saveBtn:SetScript("OnClick", function() if Save() then editor:Hide() end end)
saveNextBtn:SetScript("OnClick", function()
    if not Save() then return end
    local cfg = GM.EnsureBar()
    local nextIndex = GM:FirstFreeSlot()
    if not nextIndex and cfg.rows < GM.BAR_LIMITS.rows[2] then
        GM:SetBarOption("rows", cfg.rows + 1)
        nextIndex = GM:FirstFreeSlot()
    end
    if not nextIndex then editor:Hide() return end
    -- Même recette, même choix : seul l'ID (ou la valeur) est à retaper.
    local field = editor.recipe.fields[1]
    if field and field.kind ~= "pick" then Values()[field.key] = field.default or "" end
    OpenEditor(nextIndex, true)
end)
saveNextBtn:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Enregistrer + case suivante",
        "Enregistre, puis ouvre la prochaine case vide avec la même recette : il ne reste qu'à taper le nouvel ID." })
end)
saveNextBtn:SetScript("OnLeave", HideTooltip)
testBtn:SetScript("OnClick", function()
    local built = editor.built
    if not built then return end
    local alt = IsAltKeyDown and IsAltKeyDown()
    local text
    if alt and built.mode == "alt" then text = built.second
    elseif alt and built.mode == "toggle" then
        text = (built.second and GM.Trim(built.second) ~= "") and built.second or GM.ApplySwitchToken(built.cmds, false)
    else text = GM.ApplySwitchToken(built.cmds, true) end
    GM:RunMacro(text or "")
    local msg = GM.lastError and ("|cffdd5555" .. GM.lastError .. "|r") or ("Envoyée :  |cffffffff" .. (GM.lastCommand or "") .. "|r")
    report:SetText(report:GetText() .. "\n" .. msg)
end)
testBtn:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Tester sans enregistrer", "Clic : la première commande (activer).",
        "Alt + clic : la seconde (retirer, désactiver)." })
end)
testBtn:SetScript("OnLeave", HideTooltip)
clearBtn:SetScript("OnClick", function()
    GM:SetSlot(editor.index, "", "", "")
    editor:Hide()
end)
cancelBtn:SetScript("OnClick", function() editor:Hide() end)

--- Ouvre l'éditeur sur une case. keepRecipe : garder la recette en cours
--- (enchaînement « case suivante »).
function OpenEditor(index, keepRecipe)
    editor.index = index
    local slot = GM:GetSlot(index)
    edTitle:SetText("Case " .. index .. (slot and "" or "  |cff888888(vide)|r"))
    iconPick:SetShown(OmegaSpell and OmegaSpell.IconBrowser and OmegaSpell.IconBrowser.Open and true or false)
    editor:Show()

    if slot and slot.recipe and GM.RecipeByKey[slot.recipe] then
        local recipe = GM.RecipeByKey[slot.recipe]
        editor.values[recipe.key] = {}
        for k, v in pairs(slot.params or {}) do editor.values[recipe.key][k] = v end
        local built = GM.BuildRecipe(recipe, editor.values[recipe.key])
        editor.labelAuto = not slot.label or (built and slot.label == built.label)
        editor.iconAuto = not slot.icon or (built and slot.icon == built.icon)
        labelBox:SetText(slot.label or "")
        iconBox:SetText(slot.icon or "")
        SelectRecipe(recipe.key, true)
    elseif slot then
        box1.eb:SetText(slot.cmds or "")
        box2.eb:SetText(slot.cmdsAlt or slot.cmdsOff or "")
        editor.mode = GM.SlotMode(slot)
        labelBox:SetText(slot.label or "")
        iconBox:SetText(slot.icon or "")
        editor.labelAuto, editor.iconAuto = false, false
        SelectRecipe("free", true)
    else
        local key = keepRecipe and editor.recipe and editor.recipe.key or GM.EnsureBar().lastRecipe or "npcaura"
        if GM.RecipeByKey[key] and not GM.RecipeByKey[key].free then
            local field = GM.RecipeByKey[key].fields[1]
            editor.values[key] = editor.values[key] or {}
            if field and field.kind ~= "pick" and not keepRecipe then editor.values[key][field.key] = field.default or "" end
        else
            box1.eb:SetText(""); box2.eb:SetText(""); editor.mode = "simple"
        end
        labelBox:SetText(""); iconBox:SetText("")
        editor.labelAuto, editor.iconAuto = true, true
        SelectRecipe(key, true)
        if not GM.RecipeByKey[key].free and fieldBox:IsShown() then fieldBox:SetFocus() end
    end
end
GM.OpenMacroEditor = OpenEditor
GM.macroEditor = editor
GM.barSettings = settings

--- Ajoute une macro dans la première case libre ; agrandit la barre
--- d'une ligne si elle est pleine. Renvoie l'index ou nil.
function GM:AddToBar(label, cmds, icon, opts)
    local cfg = self.EnsureBar()
    local i = self:FirstFreeSlot()
    if not i and cfg.rows < GM.BAR_LIMITS.rows[2] then
        cfg.rows = cfg.rows + 1
        i = self:FirstFreeSlot()
    end
    if not i then
        self.lastError = "Barre MJ pleine"
        self.Notify()
        return nil
    end
    self:SetSlot(i, label, cmds, icon, opts)
    self.lastError = nil
    self.lastNotice = "Ajoutée à la barre MJ, case " .. i .. " : " .. (label or "")
    if not cfg.shown then self:ToggleBar(true) end
    self.Notify()
    return i
end

-- ── Rafraîchissement ──────────────────────────────────────────────────────

GM:OnChange(function()
    RefreshBar()
    RefreshSettings()
end)

-- État des interrupteurs : bindings, auras du joueur, réponses du serveur.
local ev = CreateFrame("Frame")
ev:RegisterEvent("UPDATE_BINDINGS")
ev:RegisterEvent("UNIT_AURA")
ev:RegisterEvent("CHAT_MSG_SYSTEM")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then return end
    if event == "CHAT_MSG_SYSTEM" and C_Timer then
        -- après le filtre d'EpsilonLib, qui met à jour l'état des triches
        C_Timer.After(0, RefreshBar)
        return
    end
    if event == "PLAYER_LOGIN" and EpsilonLib and EpsilonLib.Cheat and hooksecurefunc then
        hooksecurefunc(EpsilonLib.Cheat, "SetCheatStatus", function() RefreshBar() end)
    end
    RefreshBar()
end)
