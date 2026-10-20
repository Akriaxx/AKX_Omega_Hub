-- ============================================================
--  GM Master — Fenêtre
--  Colonne de gauche : les domaines (PNJ, Sorts...). En haut à
--  droite : un onglet par section du domaine. Dessous : les champs
--  de la section (saisis une fois, mémorisés), ses actions, et la
--  liste de ce qui a été appliqué. En bas : la dernière commande.
-- ============================================================

local GM = GMMaster
local UI = OS2.UI

local PANEL_W, PANEL_H = 700, 570
local HEADER_H  = 42
local FOOTER_H  = 58
local TAB_H     = 30
local TAB_W     = 100
local TABS_MAX  = 5
local SIDEBAR_W = 150
local PAD       = 12
local ROW_H     = 26
local LABEL_W   = 120
local CHIP_W, CHIP_H, CHIPS_MAX = 62, 18, 6
local ACTION_W, ACTION_H, ACTION_COLS = 156, 24, 3
local TRACK_ROW_H = 20

local COLOR_FAV    = { 1.00, 0.82, 0.30 }
local COLOR_ACTIVE = "|cff66dd66"

-- ── Panneau ───────────────────────────────────────────────────────────────

local panel = CreateFrame("Frame", "GMMasterPanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER")
panel:SetFrameStrata("HIGH")
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:Hide()
tinsert(UISpecialFrames, "GMMasterPanel")

local bg = panel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
UI.ApplyWindowBackground(bg, 0.97)
panel:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropBorderColor(unpack(UI.colors.separator))

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", PAD + 4, -14)
title:SetText("GM Master")
UI.ApplyTitle(title)

local version = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
version:SetPoint("LEFT", title, "RIGHT", 8, -1)
UI.ApplyMutedText(version)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sepTop = panel:CreateTexture(nil, "ARTWORK")
sepTop:SetPoint("TOPLEFT", 4, -HEADER_H)
sepTop:SetPoint("TOPRIGHT", -4, -HEADER_H)
sepTop:SetHeight(1)
UI.ApplySeparator(sepTop, true)

-- ── Barre latérale ────────────────────────────────────────────────────────

local sidebar = CreateFrame("Frame", nil, panel)
sidebar:SetPoint("TOPLEFT", 4, -(HEADER_H + 1))
sidebar:SetPoint("BOTTOMLEFT", 4, FOOTER_H + 1)
sidebar:SetWidth(SIDEBAR_W)
local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
sidebarBg:SetAllPoints()
UI.ApplyWindowBackground(sidebarBg, 0.45)

local sepSide = panel:CreateTexture(nil, "ARTWORK")
sepSide:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
sepSide:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
sepSide:SetWidth(1)
UI.ApplySeparator(sepSide, true)

local content = CreateFrame("Frame", nil, panel)
content:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", PAD, -PAD)
content:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, FOOTER_H + 6)

-- Onglets des sections du domaine, puis la zone des pages.
local tabBar = CreateFrame("Frame", nil, content)
tabBar:SetPoint("TOPLEFT", 0, 0)
tabBar:SetPoint("TOPRIGHT", 0, 0)
tabBar:SetHeight(TAB_H - 6)

local sepTabs = content:CreateTexture(nil, "ARTWORK")
sepTabs:SetPoint("TOPLEFT", 0, -(TAB_H - 6))
sepTabs:SetPoint("TOPRIGHT", 0, -(TAB_H - 6))
sepTabs:SetHeight(1)
UI.ApplySeparator(sepTabs, true)

local pageArea = CreateFrame("Frame", nil, content)
pageArea:SetPoint("TOPLEFT", 0, -(TAB_H + 4))
pageArea:SetPoint("BOTTOMRIGHT", 0, 0)

-- ── Pied : dernière commande + mode préparation ───────────────────────────

local sepBottom = panel:CreateTexture(nil, "ARTWORK")
sepBottom:SetPoint("BOTTOMLEFT", 4, FOOTER_H)
sepBottom:SetPoint("BOTTOMRIGHT", -4, FOOTER_H)
sepBottom:SetHeight(1)
UI.ApplySeparator(sepBottom, true)

local lastLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lastLabel:SetPoint("BOTTOMLEFT", PAD + 4, FOOTER_H - 20)
lastLabel:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
lastLabel:SetJustifyH("LEFT")
lastLabel:SetWordWrap(false)
UI.ApplyBodyText(lastLabel)

local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("BOTTOMRIGHT", -PAD - 2, 13)
hint:SetText("Entrée dans un champ : lance son action  ·  Survol : commande envoyée")
UI.ApplySoftText(hint)

local function UpdateFooter()
    if GM.lastError then
        lastLabel:SetText("|cffdd5555" .. GM.lastError .. "|r")
    elseif GM.lastCommand then
        lastLabel:SetText("Envoyée :  |cffffffff" .. GM.lastCommand .. "|r")
    else
        lastLabel:SetText("|cff888888Aucune commande envoyée pour l'instant.|r")
    end
end

-- ── Petits constructeurs ──────────────────────────────────────────────────

local function Label(parent, text, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

local function ShowTooltip(owner, lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:SetText(line, 1, 1, 1)
        else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end

local function HideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

-- ── Pages de domaine ──────────────────────────────────────────────────────

local pages = {}

local function BuildPage(domain)
    local page = CreateFrame("Frame", nil, pageArea)
    page:SetAllPoints()
    page:Hide()
    page.domain = domain
    page.editors = {}     -- [fieldKey] = editbox (ou bouton pour choice)
    page.chipRows = {}    -- [fieldKey] = { chips }
    page.spellLabels = {} -- [fieldKey] = fontstring
    page.actionButtons = {}

    local values = GM:GetValues(domain)
    local y = 0

    local heading = Label(page, domain.title, "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 0, y)
    UI.ApplyTitle(heading)
    local prefix = Label(page, domain.prefix)
    prefix:SetPoint("LEFT", heading, "RIGHT", 10, -1)
    UI.ApplyMutedText(prefix)
    y = y - 24

    local desc = Label(page, domain.desc)
    desc:SetPoint("TOPLEFT", 0, y)
    desc:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    desc:SetWordWrap(true)
    UI.ApplySoftText(desc)
    y = y - 34

    local function RunByKey(actionKey)
        local action = domain.actionByKey[actionKey]
        if action then GM:RunAction(domain, action, values) end
    end

    -- Champs
    for _, field in ipairs(domain.fields) do
        local label = Label(page, field.label)
        label:SetPoint("TOPLEFT", 0, y - 6)
        UI.ApplyLabel(label)
        local x = LABEL_W

        if field.kind == "choice" then
            local btn = UI.CreatePanelButton(page, field.width or 120, 22, "")
            btn:SetPoint("TOPLEFT", x, y)
            local function Sync()
                for _, opt in ipairs(field.options) do
                    if opt.value == (values[field.key] or "") then btn:SetText(opt.label) end
                end
            end
            btn:SetScript("OnClick", function()
                local idx = 1
                for i, opt in ipairs(field.options) do
                    if opt.value == (values[field.key] or "") then idx = i end
                end
                local nextOpt = field.options[idx % #field.options + 1]
                GM:SetValue(domain, field.key, nextOpt.value)
                GM.Notify()
            end)
            btn.Sync = Sync
            page.editors[field.key] = btn
        else
            local width = field.width or (field.kind == "text" and 300) or (field.kind == "player" and 170)
                or (field.kind == "number" and 70) or 110
            local eb = UI.CreateStyledEditBox(page, width, 22)
            if field.kind == "number" then
                local minus = UI.CreatePanelButton(page, 22, 22, "-")
                minus:SetPoint("TOPLEFT", x, y)
                eb:SetPoint("LEFT", minus, "RIGHT", 4, 0)
                local plus = UI.CreatePanelButton(page, 22, 22, "+")
                plus:SetPoint("LEFT", eb, "RIGHT", 4, 0)
                local function Step(dir)
                    local n = tonumber(eb:GetText()) or tonumber(field.default) or 0
                    n = n + dir * field.step
                    -- arrondi au pas, pour éviter 1.0000000002
                    local decimals = #(tostring(field.step):match("%.(%d+)") or "")
                    eb:SetText(string.format("%." .. decimals .. "f", n))
                    GM:SetValue(domain, field.key, eb:GetText())
                end
                minus:SetScript("OnClick", function() Step(-1) end)
                plus:SetScript("OnClick", function() Step(1) end)
            else
                eb:SetPoint("TOPLEFT", x, y)
            end
            eb:SetText(values[field.key] or "")
            if field.kind == "id" then eb:SetNumeric(true) end
            if field.maxLetters then eb:SetMaxLetters(field.maxLetters) end
            eb:SetScript("OnTextChanged", function(self, userInput)
                if userInput then
                    GM:SetValue(domain, field.key, self:GetText())
                    if page.Refresh then page:Refresh() end
                end
            end)
            eb:SetScript("OnEnterPressed", function(self)
                GM:SetValue(domain, field.key, self:GetText())
                self:ClearFocus()
                if field.enter then RunByKey(field.enter) end
            end)
            page.editors[field.key] = eb

            local anchor = eb
            if field.kind == "player" then
                local targetBtn = UI.CreatePanelButton(page, 60, 22, "Cible")
                targetBtn:SetPoint("LEFT", eb, "RIGHT", 6, 0)
                targetBtn:SetScript("OnClick", function()
                    local name = UnitExists("target") and UnitIsPlayer("target") and GetUnitName("target", true)
                    if name then
                        eb:SetText(name)
                        GM:SetValue(domain, field.key, name)
                    end
                end)
                anchor = targetBtn
            end

            if field.history then
                local star = UI.CreatePanelButton(page, 22, 22, "")
                local icon = star:CreateTexture(nil, "OVERLAY")
                icon:SetSize(14, 14)
                icon:SetPoint("CENTER")
                icon:SetAtlas("auctionhouse-icon-favorite")
                star.icon = icon
                star:SetPoint("LEFT", anchor or eb, "RIGHT", 6, 0)
                star:SetScript("OnClick", function()
                    GM:ToggleFavorite(domain, field, values[field.key])
                    GM.Notify()
                end)
                star:SetScript("OnEnter", function(self)
                    ShowTooltip(self, { "Favori", "Épingle cette valeur en tête de liste. Clic droit sur une pastille pour l'oublier." })
                end)
                star:SetScript("OnLeave", HideTooltip)
                page.editors[field.key].star = star
                anchor = star
            end

            if field.spell then
                local spellFS = Label(page, "")
                spellFS:SetPoint("LEFT", anchor or eb, "RIGHT", 8, 0)
                spellFS:SetPoint("RIGHT", page, "RIGHT", 0, 0)
                spellFS:SetWordWrap(false)
                UI.ApplyMutedText(spellFS)
                page.spellLabels[field.key] = spellFS
            end
        end
        y = y - ROW_H

        -- Pastilles : favoris puis historique
        if field.history then
            local chips = {}
            for i = 1, CHIPS_MAX do
                local chip = CreateFrame("Button", nil, page)
                chip:SetSize(CHIP_W, CHIP_H)
                chip:SetPoint("TOPLEFT", LABEL_W + (i - 1) * (CHIP_W + 4), y + 2)
                chip:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                local chipBg = chip:CreateTexture(nil, "BACKGROUND")
                chipBg:SetAllPoints()
                chipBg:SetColorTexture(unpack(UI.colors.panelButtonBg))
                local hl = chip:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints()
                hl:SetColorTexture(unpack(UI.colors.panelButtonHighlight))
                local fs = chip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetPoint("TOPLEFT", 3, 0)
                fs:SetPoint("BOTTOMRIGHT", -3, 0)
                fs:SetWordWrap(false)
                chip.text = fs
                chip:SetScript("OnClick", function(self, button)
                    if not self.value then return end
                    if button == "RightButton" then
                        if self.favorite then GM:ToggleFavorite(domain, field, self.value)
                        else GM:RemoveHistory(domain, field, self.value) end
                    else
                        GM:SetValue(domain, field.key, self.value)
                        page.editors[field.key]:SetText(self.value)
                        -- Double-clic sur une pastille : exécute directement.
                        local now = GetTime and GetTime() or 0
                        if self.lastClick and now - self.lastClick < 0.35 and field.enter then
                            RunByKey(field.enter)
                        end
                        self.lastClick = now
                    end
                    GM.Notify()
                end)
                chip:SetScript("OnEnter", function(self)
                    if not self.value then return end
                    local name = field.spell and GM.SpellInfo(self.value)
                    ShowTooltip(self, {
                        name or self.value,
                        (self.favorite and "Favori · " or "") .. "Clic : reprendre  ·  Double-clic : exécuter  ·  Clic droit : oublier",
                    })
                end)
                chip:SetScript("OnLeave", HideTooltip)
                chips[i] = chip
            end
            page.chipRows[field.key] = chips
            y = y - CHIP_H - 6
        end
    end

    -- Actions
    if #domain.fields > 0 then y = y - 6 end
    local actionsTitle = Label(page, "Actions")
    actionsTitle:SetPoint("TOPLEFT", 0, y)
    UI.ApplyStrongLabel(actionsTitle)
    y = y - 18

    for i, action in ipairs(domain.actions) do
        local col = (i - 1) % ACTION_COLS
        local row = math.floor((i - 1) / ACTION_COLS)
        local btn = UI.CreatePanelButton(page, ACTION_W, ACTION_H, action.label)
        btn:SetPoint("TOPLEFT", col * (ACTION_W + 6), y - row * (ACTION_H + 6))
        btn:SetScript("OnClick", function()
            GM:RunAction(domain, action, values)
        end)
        btn:SetScript("OnEnter", function(self)
            local templates = type(action.cmd) == "table" and action.cmd or { action.cmd }
            local lines = { action.label }
            for _, template in ipairs(templates) do
                local cmd, err = GM.Build(domain, template, values)
                lines[#lines + 1] = cmd and ("|cffffffff." .. cmd .. "|r") or ("|cffdd5555" .. err .. "|r")
            end
            if action.toggle then lines[#lines + 1] = "Applique, ou retire si déjà appliquée." end
            if action.tip then lines[#lines + 1] = action.tip end
            ShowTooltip(self, lines)
        end)
        btn:SetScript("OnLeave", HideTooltip)
        page.actionButtons[action.key] = btn
    end
    y = y - math.ceil(#domain.actions / ACTION_COLS) * (ACTION_H + 6) - 6

    -- Tracker
    if domain.tracker then
        local trackTitle = Label(page, domain.tracker.title)
        trackTitle:SetPoint("TOPLEFT", 0, y)
        UI.ApplyStrongLabel(trackTitle)
        page.trackTitle = trackTitle
        y = y - 18

        local available = PANEL_H - HEADER_H - FOOTER_H - 2 * PAD - TAB_H - 4 + y
        local rows = math.max(1, math.floor(available / TRACK_ROW_H))
        page.trackRows = {}
        for i = 1, rows do
            local row = CreateFrame("Frame", nil, page)
            row:SetHeight(TRACK_ROW_H)
            row:SetPoint("TOPLEFT", 0, y - (i - 1) * TRACK_ROW_H)
            row:SetPoint("RIGHT", page, "RIGHT", 0, 0)
            local fs = Label(row, "")
            fs:SetPoint("LEFT", 4, 0)
            fs:SetPoint("RIGHT", row, "RIGHT", -84, 0)
            fs:SetWordWrap(false)
            UI.ApplyBodyText(fs)
            row.text = fs
            local remove = UI.CreatePanelButton(row, 76, 18, "Retirer")
            remove:SetPoint("RIGHT", 0, 0)
            remove:SetScript("OnClick", function()
                if row.index then GM:UntrackEntry(domain, row.index) end
                GM.Notify()
            end)
            row.remove = remove
            page.trackRows[i] = row
        end
        local empty = Label(page, "|cff888888Rien pour l'instant.|r")
        empty:SetPoint("TOPLEFT", 4, y - 3)
        page.trackEmpty = empty
    end

    function page:Refresh()
        for _, field in ipairs(domain.fields) do
            local editor = self.editors[field.key]
            if field.kind == "choice" then
                editor:Sync()
            else
                if not editor:HasFocus() and editor:GetText() ~= (values[field.key] or "") then
                    editor:SetText(values[field.key] or "")
                end
                if editor.star then
                    local fav = GM:IsFavorite(domain, field, values[field.key] or "")
                    editor.star.icon:SetDesaturated(not fav)
                    editor.star.icon:SetAlpha(fav and 1 or 0.45)
                end
            end

            local spellFS = self.spellLabels[field.key]
            if spellFS then
                local name = GM.SpellInfo(values[field.key])
                local text = name or ((values[field.key] or "") ~= "" and "|cff888888Sort inconnu|r" or "")
                if domain.tracker and name then
                    local scratch = setmetatable({ target = UnitExists("target") and not UnitIsUnit("target", "player")
                        and UnitName("target") or "" }, { __index = values })
                    if GM:FindTracked(domain, scratch) then text = text .. "  " .. COLOR_ACTIVE .. "· appliquée|r" end
                end
                spellFS:SetText(text)
            end

            local chips = self.chipRows[field.key]
            if chips then
                local list = GM:GetChips(domain, field)
                for i, chip in ipairs(chips) do
                    local item = list[i]
                    if item then
                        chip.value, chip.favorite = item.value, item.favorite
                        chip.text:SetText(item.value)
                        chip.text:SetTextColor(unpack(item.favorite and COLOR_FAV or UI.colors.text))
                        chip:Show()
                    else
                        chip.value = nil
                        chip:Hide()
                    end
                end
            end
        end

        if self.trackRows then
            local list = GM:GetTracked(domain)
            for i, row in ipairs(self.trackRows) do
                local entry = list[i]
                if entry then
                    row.index = i
                    row.text:SetText(GM:TrackedLabel(domain, entry))
                    row:Show()
                else
                    row.index = nil
                    row:Hide()
                end
            end
            local hidden = #list - #self.trackRows
            self.trackTitle:SetText(domain.tracker.title .. (hidden > 0 and ("  |cff888888(+" .. hidden .. ")|r") or ""))
            self.trackEmpty:SetShown(#list == 0)
        end
    end

    return page
end

-- ── Navigation ────────────────────────────────────────────────────────────

local navButtons = {}
local tabs = {}
local current

local function SelectDomain(key)
    local domain = GM.DomainByKey[key] or GM.DomainByKey[GM.Groups[1].sections[1]]
    local group = domain.group
    if current then current:Hide() end
    pages[domain.key] = pages[domain.key] or BuildPage(domain)
    current = pages[domain.key]
    current:Refresh()
    current:Show()

    local db = GM.EnsureDB()
    db.lastDomain = domain.key
    db.lastSection = db.lastSection or {}
    db.lastSection[group.key] = domain.key

    for k, btn in pairs(navButtons) do
        local active = (k == group.key)
        btn.line:SetShown(active)
        btn.activeBg:SetShown(active)
        btn.label:SetTextColor(unpack(active and UI.colors.title or UI.colors.textMuted))
    end
    for i, tab in ipairs(tabs) do
        local sectionKey = group.sections[i]
        if sectionKey then
            tab.sectionKey = sectionKey
            tab:SetText(GM.DomainByKey[sectionKey].tab)
            UI.ApplyTabState(tab, sectionKey == domain.key)
            tab:Show()
        else
            tab.sectionKey = nil
            tab:Hide()
        end
    end
end

--- Ouvre un domaine sur la dernière section consultée.
local function SelectGroup(groupKey)
    local group = GM.GroupByKey[groupKey]
    local last = GM.EnsureDB().lastSection
    SelectDomain(last and last[groupKey] or group.sections[1])
end

for i = 1, TABS_MAX do
    local tab = CreateFrame("Button", nil, tabBar)
    tab:SetSize(TAB_W, TAB_H - 6)
    tab:SetPoint("BOTTOMLEFT", (i - 1) * (TAB_W + 4), 0)
    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    tab:SetFontString(label)
    tab.label = label
    local line = tab:CreateTexture(nil, "ARTWORK")
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT", 6, 0)
    line:SetPoint("BOTTOMRIGHT", -6, 0)
    tab.line = line
    local hl = tab:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.tabHighlight))
    tab:SetScript("OnClick", function(self)
        if self.sectionKey then SelectDomain(self.sectionKey) end
    end)
    tabs[i] = tab
end

for i, group in ipairs(GM.Groups) do
    local btn = CreateFrame("Button", nil, sidebar)
    btn:SetHeight(28)
    btn:SetPoint("TOPLEFT", 0, -6 - (i - 1) * 30)
    btn:SetPoint("RIGHT", sidebar, "RIGHT", 0, 0)
    local activeBg = btn:CreateTexture(nil, "BACKGROUND")
    activeBg:SetAllPoints()
    activeBg:SetColorTexture(unpack(UI.colors.rowBgSelected))
    btn.activeBg = activeBg
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.tabHighlight))
    local line = btn:CreateTexture(nil, "ARTWORK")
    line:SetWidth(3)
    line:SetPoint("TOPLEFT")
    line:SetPoint("BOTTOMLEFT")
    line:SetColorTexture(unpack(UI.colors.tabLine))
    btn.line = line
    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", 14, 0)
    label:SetText(group.title)
    btn.label = label
    btn:SetScript("OnClick", function() SelectGroup(group.key) end)
    navButtons[group.key] = btn
end

-- ── Rafraîchissement ──────────────────────────────────────────────────────

local function RefreshAll()
    if not panel:IsShown() then return end
    if current then current:Refresh() end
    UpdateFooter()
end

GM:OnChange(RefreshAll)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", RefreshAll)

panel:SetScript("OnShow", function()
    version:SetText("v" .. (GMMASTER_VERSION or "?"))
    SelectDomain(GM.EnsureDB().lastDomain)
    UpdateFooter()
end)

function panel:Toggle()
    self:SetShown(not self:IsShown())
end

GM.SelectDomain = SelectDomain
GM.SelectGroup = SelectGroup
GM.tabs = tabs
GM.pages = pages
