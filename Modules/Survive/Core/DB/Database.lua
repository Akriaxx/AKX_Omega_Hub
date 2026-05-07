-- OmegaSurvive 2.0 — Base de donnée

-- ── Constantes layout ─────────────────────────────────────────────────
-- Mettre à true pour révéler la colonne Modules dans l'onglet Lanterne
local MODULES_ENABLED = false

local DB_H      = 380
local PAD       = 14
local ROW_H     = 26
local ROW_PL    = 10
local ROW_PV    = 5
local DEL_SZ    = 16
local LINK_W    = 36
local COL_GAP   = 10
local SB_W      = 10
local SB_GAP    = 3

-- Réserve droite : en édition [−](16) + [Éditer](36) + gaps = 64 px
local LABEL_RSV = 4 + DEL_SZ + 4 + LINK_W + 4   -- 64 px

-- Largeur et colonnes selon activation des modules
-- MODULES_ENABLED = false : 2 colonnes, 460 px  →  COL_W ≈ 211
-- MODULES_ENABLED = true  : 3 colonnes, 680 px  →  COL_W ≈ 210
local DB_W  = MODULES_ENABLED and 680 or 460
local COL_W = MODULES_ENABLED
    and math.floor((680 - PAD * 2 - COL_GAP * 2) / 3)   -- ~210
    or  math.floor((460 - PAD * 2 - COL_GAP)     / 2)   -- 211
local SF_W  = COL_W - SB_W - SB_GAP

local TAB_H_DB = 26
local CONT_Y   = 35 + TAB_H_DB + 1
local HDR_H    = 28
local BTN_H    = 8 + 22 + PAD
local LIST_H   = DB_H - CONT_Y - HDR_H - BTN_H

-- ── État ──────────────────────────────────────────────────────────────
local editMode      = false
local buttonPools   = {
    lantEdit = {},
    crystEdit = {},
    torchEdit = {},
    fuelEdit = {},
    lantLink = {},
    crystLink = {},
    torchLink = {},
    fuelLink = {},
    lantMod = {},
    crystMod = {},
    torchMod = {},
    fuelMod = {},
    modEdit = {},
    modLink = {},
    modMod = {},
    add = {},
}
local genericCatInfos   = {}   -- { key, editBtns, linkBtns, modBtns, rebuildFn } par catégorie générique
local rebuildFns = {}
local NormalizePhraseList
local NormalizeDisablePhraseEntries

local UI = OS2.UI or {}
local DBSchema = (OS2.DB and OS2.DB.Schema) or {}

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$") or ""
end

local function GetDatabaseTabItems()
    local items = {}
    for _, menuItem in ipairs(OS2.MenuItems or {}) do
        if menuItem.toggleable then
            items[#items + 1] = menuItem
        end
    end
    return items
end

local function CopyKeyList(keys)
    local copied = {}
    for index, key in ipairs(keys or {}) do
        copied[index] = key
    end
    return copied
end

local function GetSavedDatabaseTabOrder()
    if OS2.GetDatabaseTabOrder then
        return OS2.GetDatabaseTabOrder()
    end
    local db = (OS2.EnsureDB and OS2.EnsureDB()) or OS2DB or {}
    return db.databaseTabOrder or {}
end

local function GetOrderedDatabaseTabItems()
    local source = GetDatabaseTabItems()
    local byKey = {}
    local ordered = {}

    for _, item in ipairs(source) do
        byKey[item.key] = item
    end

    for _, key in ipairs(GetSavedDatabaseTabOrder()) do
        local item = byKey[key]
        if item then
            ordered[#ordered + 1] = item
            byKey[key] = nil
        end
    end

    for _, item in ipairs(source) do
        if byKey[item.key] then
            ordered[#ordered + 1] = item
        end
    end

    return ordered
end

local function SaveDatabaseTabOrder(keys)
    if OS2.SetDatabaseTabOrder then
        OS2.SetDatabaseTabOrder(keys)
        return
    end
    local db = (OS2.EnsureDB and OS2.EnsureDB()) or OS2DB or {}
    db.databaseTabOrder = CopyKeyList(keys)
end

-- ── Clé auto-générée ──────────────────────────────────────────────────
local _keySeq = 0
local function EntryKeyExists(itemType, key)
    local list
    if itemType == "lanterne" then
        list = OS2.Core.Models or {}
    elseif itemType == "cristal" then
        list = OS2.Core.Crystals or {}
    elseif itemType == "lanternModule" then
        list = OS2.Core.Modules or {}
    else
        list = (OS2.Core.Categories and OS2.Core.Categories[itemType]) or {}
    end
    for _, entry in ipairs(list) do
        if entry.key == key then return true end
    end
    return false
end

local function GenerateKey(label, itemType)
    local base = (label or ""):upper():gsub("[^A-Z0-9]", ""):sub(1, 4)
    if #base == 0 then base = "ITEM" end

    repeat
        _keySeq = _keySeq + 1
    until not EntryKeyExists(itemType, base .. string.format("%04d", _keySeq % 10000))

    return base .. string.format("%04d", _keySeq % 10000)
end

local function ItemUsesMultiplier(itemType)
    return DBSchema.UsesMultiplier and DBSchema.UsesMultiplier(itemType) or false
end

local function ItemUsesDuration(itemType)
    return DBSchema.UsesDuration and DBSchema.UsesDuration(itemType) or false
end

local function ItemUsesTimedControls(itemType)
    return DBSchema.UsesTimedControls and DBSchema.UsesTimedControls(itemType)
        or ItemUsesMultiplier(itemType)
        or ItemUsesDuration(itemType)
end

local chatShare = OS2.DB.CreateChatShare({
    ItemUsesMultiplier = ItemUsesMultiplier,
    ItemUsesDuration = ItemUsesDuration,
})

local InsertLinkToChat = chatShare.InsertLinkToChat

-- ── Helper : CreatePanelButton ─────────────────────────────────────────
local function CreatePanelButton(parent, width, height, text)
    return UI.CreatePanelButton(parent, width, height, text)
end

-- ── Helper : EditBox stylisé ───────────────────────────────────────────
local function CreateStyledEditBox(parent, width, height, multiLine)
    return UI.CreateStyledEditBox(parent, width, height, multiLine)
end

local function CreateStyledCheckbox(parent, labelText)
    local btn, label = UI.CreateStyledCheckbox(parent, labelText)
    btn.label = label

    btn:SetScript("OnClick", function(self)
        if self.OnValueChanged then
            self:OnValueChanged(self:GetChecked())
        end
    end)

    return btn, label
end

local function ParseChannelList(text)
    local selected = {}
    local source = tostring(text or "")

    for token in source:gmatch("[^,%s]+") do
        selected[token:upper()] = true
    end

    return selected
end

local function BuildChannelListFromChecks(checks)
    local selected = {}

    for _, entry in ipairs(checks or {}) do
        if entry.check:GetChecked() then
            selected[#selected + 1] = entry.value
        end
    end

    return table.concat(selected, ",")
end

NormalizePhraseList = function(value)
    local phrases = {}

    if type(value) == "table" then
        for _, entry in ipairs(value) do
            local phrase = Trim(entry)
            if phrase ~= "" then
                phrases[#phrases + 1] = phrase
            end
        end
    else
        local text = tostring(value or "")
        for entry in text:gmatch("[^\n]+") do
            local phrase = Trim(entry)
            if phrase ~= "" then
                phrases[#phrases + 1] = phrase
            end
        end
    end

    return phrases
end

local function NormalizeDisablePhraseEffect(value)
    return value == "PAUSE_FORCE_OFF" and "PAUSE_FORCE_OFF" or "PAUSE"
end

NormalizeDisablePhraseEntries = function(value)
    local entries = {}

    if type(value) == "table" then
        for _, entry in ipairs(value) do
            local text
            local effect = "PAUSE"

            if type(entry) == "table" then
                text = Trim(entry.text or entry.phrase or entry.label or "")
                effect = NormalizeDisablePhraseEffect(entry.effect)
            else
                text = Trim(entry)
            end

            if text ~= "" then
                entries[#entries + 1] = {
                    text = text,
                    effect = effect,
                }
            end
        end
    else
        for entry in tostring(value or ""):gmatch("[^\n]+") do
            local text = Trim(entry)
            if text ~= "" then
                entries[#entries + 1] = {
                    text = text,
                    effect = "PAUSE",
                }
            end
        end
    end

    return entries
end

local function NormalizeAuraRules(value)
    local rules = {}
    if type(value) ~= "table" then
        return rules
    end

    for _, entry in ipairs(value) do
        if type(entry) == "table" then
            local condition = Trim(entry.condition or "")
            local command = Trim(entry.command or "")
            local phrase = Trim(entry.phrase or "")
            if condition ~= "" and command ~= "" then
                rules[#rules + 1] = {
                    condition = condition,
                    command = command,
                    phrase = phrase,
                }
            end
        end
    end

    return rules
end

local function ConditionNeedsPhrase(condition)
    return condition == "DISABLE_PHRASE" or condition == "ENABLE_PHRASE"
end

local function GetAuraConditionOptions(itemType)
    return (DBSchema.GetAuraConditions and DBSchema.GetAuraConditions(itemType)) or {}
end

local function GetAuraConditionLabel(itemType, value)
    for _, option in ipairs(GetAuraConditionOptions(itemType)) do
        if option.value == value then
            return option.label
        end
    end
    return value or ""
end

local function FormatDropdownItemLabel(label, isSelected)
    local prefix = isSelected and ">  " or "   "
    return prefix .. (label or "")
end

-- ── Propriétés affichées dans l'info panel (clé exclue) ───────────────
local function GetDatabaseList(itemType)
    if itemType == "lanterne" then
        return OS2.Core.Models
    elseif itemType == "cristal" then
        return OS2.Core.Crystals
    elseif itemType == "torche" then
        return OS2.Core.TorchModels or {}
    elseif itemType == "combustible" then
        return OS2.Core.TorchFuels or {}
    elseif itemType == "lanternModule" then
        return OS2.Core.Modules
    else
        return (OS2.Core.Categories and OS2.Core.Categories[itemType]) or {}
    end
end

local function AddItemToDatabase(item, itemType)
    local list = GetDatabaseList(itemType)
    for _, existing in ipairs(list) do
        if existing.key == item.key then
            return false, existing
        end
    end

    local newItem = {}
    for key, value in pairs(item) do
        newItem[key] = value
    end
    list[#list + 1] = newItem

    if OS2.RebuildCoreLookups then
        OS2.RebuildCoreLookups()
    end

    if itemType == "lanterne" then
        if rebuildFns.lantern then rebuildFns.lantern() end
    elseif itemType == "cristal" then
        if rebuildFns.crystal then rebuildFns.crystal() end
    elseif itemType == "torche" then
        if rebuildFns.torch then rebuildFns.torch() end
    elseif itemType == "combustible" then
        if rebuildFns.fuel then rebuildFns.fuel() end
    elseif itemType == "lanternModule" then
        if rebuildFns.module then rebuildFns.module() end
    else
        for _, cat in ipairs(genericCatInfos) do
            if cat.key == itemType then cat.rebuildFn() end
        end
    end

    if OS2.RefreshLanternPanel then
        OS2.RefreshLanternPanel()
    end
    if OS2.RefreshLanternConfigPanel then
        OS2.RefreshLanternConfigPanel()
    end
    if OS2.RefreshTorchPanel then
        OS2.RefreshTorchPanel()
    end
    if OS2.RefreshTorchConfigPanel then
        OS2.RefreshTorchConfigPanel()
    end

    return true, newItem
end

local infoPanelState = OS2.DB.CreateInfoPanel({
    UI = UI,
    CreatePanelButton = CreatePanelButton,
    AddItemToDatabase = AddItemToDatabase,
    Trim = Trim,
    GetCategoryLabel = function(itemType)
        return DBSchema.GetCategoryLabel and DBSchema.GetCategoryLabel(itemType) or nil
    end,
    MenuItems = OS2.MenuItems or {},
})

local itemInfoPanel = infoPanelState.panel
local ShowItemInfo = infoPanelState.ShowItemInfo

chatShare.InstallHooks(ShowItemInfo)

local editPanelState = OS2.DB.CreateEditPanel({
    UI = UI,
    DBSchema = DBSchema,
    Trim = Trim,
    CreatePanelButton = CreatePanelButton,
    CreateStyledEditBox = CreateStyledEditBox,
    CreateStyledCheckbox = CreateStyledCheckbox,
    ParseChannelList = ParseChannelList,
    BuildChannelListFromChecks = BuildChannelListFromChecks,
    NormalizePhraseList = NormalizePhraseList,
    NormalizeDisablePhraseEntries = NormalizeDisablePhraseEntries,
    NormalizeDisablePhraseEffect = NormalizeDisablePhraseEffect,
    NormalizeAuraRules = NormalizeAuraRules,
    ConditionNeedsPhrase = ConditionNeedsPhrase,
    GetAuraConditionOptions = GetAuraConditionOptions,
    GetAuraConditionLabel = GetAuraConditionLabel,
    FormatDropdownItemLabel = FormatDropdownItemLabel,
    ItemUsesTimedControls = ItemUsesTimedControls,
    ItemUsesMultiplier = ItemUsesMultiplier,
    ItemUsesDuration = ItemUsesDuration,
    MenuItems = OS2.MenuItems or {},
})

local editPanel = editPanelState.panel
local OpenEditPanel = editPanelState.OpenEditPanel

-- ── Helper : ScrollList ────────────────────────────────────────────────
local function CreateScrollList(parent, x, y)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    sf:SetSize(SF_W, LIST_H)
    sf:EnableMouseWheel(true)

    local track = parent:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.07, 0.07, 0.07, 1); track:SetWidth(SB_W)
    track:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    SB_GAP,  0)
    track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", SB_GAP,  0)

    local sb = CreateFrame("Slider", nil, parent)
    sb:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    SB_GAP,  0)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", SB_GAP,  0)
    sb:SetWidth(SB_W); sb:SetOrientation("VERTICAL")
    sb:SetMinMaxValues(0, 0); sb:SetValue(0)

    local thumb = sb:CreateTexture(nil, "THUMB")
    thumb:SetSize(SB_W - 2, 30); thumb:SetColorTexture(0.50, 0.42, 0.22, 0.85)
    sb:SetThumbTexture(thumb)

    sf:SetScript("OnMouseWheel", function(self, delta)
        local cur = sb:GetValue(); local _, max = sb:GetMinMaxValues()
        sb:SetValue(math.max(0, math.min(max, cur - delta * ROW_H * 3)))
    end)
    sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
    return sf, sb
end

local function RefreshSB(sb, totalH)
    local maxS = math.max(0, totalH - LIST_H)
    sb:SetMinMaxValues(0, maxS)
    sb:SetAlpha(maxS > 0 and 1 or 0.20)
end

-- ── Helper : BuildRows ─────────────────────────────────────────────────
local function BuildRows(sf, sb, dataTable, itemType, editBtnList, linkBtnList, modBtnList, onDelete, onEdit)
    if sf._content then sf._content:Hide() end
    wipe(editBtnList); wipe(linkBtnList); wipe(modBtnList)

    local contentW = math.max(SF_W, math.floor(sf:GetWidth()))
    local newC = CreateFrame("Frame", nil, sf)
    newC:SetSize(contentW, 1); sf:SetScrollChild(newC); sf:SetVerticalScroll(0); sf._content = newC

    local y = 0
    for i, item in ipairs(dataTable) do
        local even = (math.floor(y / ROW_H) % 2 == 0)

        local rowBg = newC:CreateTexture(nil, "BACKGROUND")
        rowBg:SetHeight(ROW_H)
        rowBg:SetPoint("TOPLEFT",  newC, "TOPLEFT",  0, -y)
        rowBg:SetPoint("TOPRIGHT", newC, "TOPRIGHT", 0, -y)
        rowBg:SetColorTexture(even and 0.09 or 0.06, even and 0.09 or 0.06, even and 0.09 or 0.06, 1)

        local lbl = newC:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT",  newC, "TOPLEFT",  ROW_PL,     -(y + ROW_PV))
        lbl:SetPoint("TOPRIGHT", newC, "TOPRIGHT", -LABEL_RSV, -(y + ROW_PV))
        lbl:SetJustifyH("LEFT"); lbl:SetText(item.label); lbl:SetTextColor(0.85, 0.80, 0.65, 1)

        local infoBtn = CreateFrame("Button", nil, newC)
        infoBtn:SetPoint("TOPLEFT",  newC, "TOPLEFT",  0, -y)
        infoBtn:SetPoint("TOPRIGHT", newC, "TOPRIGHT", -LABEL_RSV, -y)
        infoBtn:SetHeight(ROW_H)
        local capturedItemInfo = item
        local capturedTypeInfo = itemType
        infoBtn:SetScript("OnClick", function()
            ShowItemInfo(capturedItemInfo, capturedTypeInfo)
        end)
        infoBtn:SetScript("OnEnter", function()
            lbl:SetTextColor(0.95, 0.90, 0.70, 1)
        end)
        infoBtn:SetScript("OnLeave", function()
            lbl:SetTextColor(0.85, 0.80, 0.65, 1)
        end)

        local btnY = y + math.floor((ROW_H - DEL_SZ) / 2)

        -- [Link] mode normal
        local linkBtn = CreateFrame("Button", nil, newC)
        linkBtn:SetSize(LINK_W, DEL_SZ)
        linkBtn:SetPoint("TOPRIGHT", newC, "TOPRIGHT", -4, -btnY)
        local lkBg = linkBtn:CreateTexture(nil, "BACKGROUND"); lkBg:SetAllPoints(); lkBg:SetColorTexture(0.10,0.14,0.20,1)
        local lkLbl = linkBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lkLbl:SetAllPoints(); lkLbl:SetText("Link"); lkLbl:SetTextColor(0.50,0.75,1.00,1)
        local lkHl = linkBtn:CreateTexture(nil, "HIGHLIGHT"); lkHl:SetAllPoints(); lkHl:SetColorTexture(0.40,0.65,1.00,0.20)
        local capturedItem = item; local capturedType = itemType
        linkBtn:SetScript("OnClick", function() InsertLinkToChat(capturedItem, capturedType) end)
        linkBtn:SetShown(not editMode)
        linkBtnList[#linkBtnList + 1] = linkBtn

        -- [Éditer] mode édition
        local modBtn = CreateFrame("Button", nil, newC)
        modBtn:SetSize(LINK_W, DEL_SZ)
        modBtn:SetPoint("TOPRIGHT", newC, "TOPRIGHT", -(4 + DEL_SZ + 4), -btnY)
        local mBg = modBtn:CreateTexture(nil, "BACKGROUND"); mBg:SetAllPoints(); mBg:SetColorTexture(0.18,0.14,0.04,1)
        local mLbl = modBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mLbl:SetAllPoints(); mLbl:SetText("Éditer"); mLbl:SetTextColor(0.95,0.80,0.20,1)
        local mHl = modBtn:CreateTexture(nil, "HIGHLIGHT"); mHl:SetAllPoints(); mHl:SetColorTexture(1.00,0.85,0.20,0.20)
        local capturedI = i
        modBtn:SetScript("OnClick", function()
            onEdit(capturedI)
        end)
        modBtn:SetShown(editMode)
        modBtnList[#modBtnList + 1] = modBtn

        -- [−] mode édition
        local delBtn = CreateFrame("Button", nil, newC)
        delBtn:SetSize(DEL_SZ, DEL_SZ)
        delBtn:SetPoint("TOPRIGHT", newC, "TOPRIGHT", -4, -btnY)
        local dBg = delBtn:CreateTexture(nil, "BACKGROUND"); dBg:SetAllPoints(); dBg:SetColorTexture(0.20,0.07,0.07,1)
        local dLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        dLbl:SetAllPoints(); dLbl:SetText("−"); dLbl:SetTextColor(0.80,0.30,0.30,1)
        local dHl = delBtn:CreateTexture(nil, "HIGHLIGHT"); dHl:SetAllPoints(); dHl:SetColorTexture(0.75,0.20,0.20,0.40)
        delBtn:SetScript("OnClick", function()
            onDelete(capturedI)
        end)
        delBtn:SetShown(editMode)
        editBtnList[#editBtnList + 1] = delBtn

        y = y + ROW_H
    end

    newC:SetHeight(math.max(1, y)); RefreshSB(sb, y)
end

-- ── Panel principal ────────────────────────────────────────────────────
local dbPanel = CreateFrame("Frame", nil, UIParent)
dbPanel:SetSize(DB_W, DB_H)
dbPanel:SetFrameStrata("DIALOG"); dbPanel:SetFrameLevel(60); dbPanel:Hide()
OS2.AttachOverlayFade(dbPanel)

do
    local bg = dbPanel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, OS2.EnsureDB().panelOpacity or 0.65)
    OS2.RegisterWindowFrame(dbPanel, bg)
end

do
    local title = dbPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", dbPanel, "TOP", 0, -13)
    title:SetText("Base de donnée")
    UI.ApplyTitle(title)
end

UI.CreateCloseButton(dbPanel, function()
    OS2.HideSettingsPanel(dbPanel)
end)

do
    local sep = dbPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(sep)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", dbPanel, "TOPLEFT", 0, -36)
    sep:SetPoint("TOPRIGHT", dbPanel, "TOPRIGHT", 0, -36)
end

do  -- Drag
    local d = CreateFrame("Frame", nil, dbPanel)
    d:SetPoint("TOPLEFT",dbPanel,"TOPLEFT",0,0); d:SetPoint("TOPRIGHT",dbPanel,"TOPRIGHT",0,0)
    d:SetHeight(36); OS2.MakeDraggable(dbPanel, d)
end

-- ── Onglets : générés depuis OS2.MenuItems (toggleable uniquement) ─────
local TABS_ITEMS = GetOrderedDatabaseTabItems()
local tabBtnsDB, tabCDB = {}, {}
local tabIndexByKey = {}
local currentTabKey = TABS_ITEMS[1] and TABS_ITEMS[1].key

local function LayoutDatabaseTabButtons()
    for index, button in ipairs(tabBtnsDB) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", dbPanel, "TOPLEFT", (index - 1) * 80, -35)
    end
end

local function SelectTabDB(idx)
    for i, btn in ipairs(tabBtnsDB) do
        local a = (i == idx)
        UI.ApplyTabState(btn, a)
        tabCDB[i]:SetShown(a)
        if a and TABS_ITEMS[i] then
            currentTabKey = TABS_ITEMS[i].key
        end
    end
end

local function SelectTabByKey(key)
    if key and tabIndexByKey[key] then
        SelectTabDB(tabIndexByKey[key])
        return
    end

    SelectTabDB(1)
end

local function ApplyDatabaseTabOrder(keys)
    local entriesByKey = {}
    local orderedEntries = {}
    local activeKey = currentTabKey or (TABS_ITEMS[1] and TABS_ITEMS[1].key)

    for index, item in ipairs(TABS_ITEMS) do
        entriesByKey[item.key] = {
            item = item,
            button = tabBtnsDB[index],
            content = tabCDB[index],
        }
    end

    for _, key in ipairs(keys or {}) do
        local entry = entriesByKey[key]
        if entry then
            orderedEntries[#orderedEntries + 1] = entry
            entriesByKey[key] = nil
        end
    end

    for _, item in ipairs(TABS_ITEMS) do
        local entry = entriesByKey[item.key]
        if entry then
            orderedEntries[#orderedEntries + 1] = entry
        end
    end

    wipe(TABS_ITEMS)
    wipe(tabBtnsDB)
    wipe(tabCDB)
    wipe(tabIndexByKey)

    for index, entry in ipairs(orderedEntries) do
        local selectedIndex = index
        TABS_ITEMS[index] = entry.item
        tabBtnsDB[index] = entry.button
        tabCDB[index] = entry.content
        tabIndexByKey[entry.item.key] = index
        entry.button:SetScript("OnClick", function()
            SelectTabDB(selectedIndex)
        end)
    end

    LayoutDatabaseTabButtons()
    SelectTabByKey(activeKey)
end

local function ReorderDatabaseTabs(fromKey, toKey)
    if not fromKey or not toKey or fromKey == toKey then
        return
    end

    local orderedKeys = {}
    local fromIndex
    local toIndex

    for index, item in ipairs(TABS_ITEMS) do
        orderedKeys[index] = item.key
        if item.key == fromKey then
            fromIndex = index
        elseif item.key == toKey then
            toIndex = index
        end
    end

    if not fromIndex or not toIndex then
        return
    end

    local movedKey = table.remove(orderedKeys, fromIndex)
    table.insert(orderedKeys, toIndex, movedKey)
    SaveDatabaseTabOrder(orderedKeys)
    ApplyDatabaseTabOrder(orderedKeys)
end

for i, mi in ipairs(TABS_ITEMS) do
    local tabLabel = mi.dbLabel or mi.label
    local btn = CreateFrame("Button", nil, dbPanel); btn:SetSize(80, TAB_H_DB)
    btn:SetPoint("TOPLEFT", dbPanel, "TOPLEFT", (i-1)*80, -35)
    local lbl = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); lbl:SetAllPoints(); lbl:SetText(tabLabel); btn.label = lbl
    UI.ApplyMutedText(lbl)
    local line = btn:CreateTexture(nil,"OVERLAY"); line:SetHeight(2)
    line:SetColorTexture(unpack(UI.colors.tabLine))
    line:SetPoint("BOTTOMLEFT",btn,"BOTTOMLEFT",0,0); line:SetPoint("BOTTOMRIGHT",btn,"BOTTOMRIGHT",0,0); btn.line = line
    local hl = btn:CreateTexture(nil,"HIGHLIGHT"); hl:SetColorTexture(unpack(UI.colors.tabHighlight)); hl:SetAllPoints()
    local c = CreateFrame("Frame", nil, dbPanel)
    c:SetPoint("TOPLEFT",dbPanel,"TOPLEFT",0,-CONT_Y); c:SetPoint("BOTTOMRIGHT",dbPanel,"BOTTOMRIGHT",0,0)
    c:Hide(); tabCDB[i] = c
    btn.itemKey = mi.key
    c.itemKey = mi.key
    tabIndexByKey[mi.key] = i
    do
        local selectedIndex = i
        btn:SetScript("OnClick", function()
            SelectTabDB(selectedIndex)
        end)
    end
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetAlpha(0.65)
    end)
    btn:SetScript("OnDragStop", function(self)
        local targetButton
        self:SetAlpha(1)

        for _, other in ipairs(tabBtnsDB) do
            if other ~= self and other:IsMouseOver() then
                targetButton = other
                break
            end
        end

        if targetButton then
            ReorderDatabaseTabs(self.itemKey, targetButton.itemKey)
        end
    end)
    tabBtnsDB[i] = btn
end

do
    local sep = dbPanel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(sep)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", dbPanel, "TOPLEFT", 0, -(35 + TAB_H_DB))
    sep:SetPoint("TOPRIGHT", dbPanel, "TOPRIGHT", 0, -(35 + TAB_H_DB))
end

local dbTabOrderPanel

-- ── Onglet 1 : Lanterne ────────────────────────────────────────────────
local lantTab = tabCDB[tabIndexByKey["lanterne"] or 1]
local X_LEFT  = PAD
local X_MID   = PAD + COL_W + COL_GAP
local X_RIGHT = PAD + (COL_W + COL_GAP) * 2

local function CreateAddButton(parent, x, y, onClick)
    local btn = UI.CreateAddButton(parent, onClick)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    btn:SetShown(editMode)
    buttonPools.add[#buttonPools.add + 1] = btn
    return btn
end

local databaseTabContext = {
    UI = UI,
    DBSchema = DBSchema,
    MODULES_ENABLED = MODULES_ENABLED,
    lantTab = lantTab,
    tabCDB = tabCDB,
    tabIndexByKey = tabIndexByKey,
    TABS_ITEMS = TABS_ITEMS,
    X_LEFT = X_LEFT,
    X_MID = X_MID,
    X_RIGHT = X_RIGHT,
    COL_W = COL_W,
    COL_GAP = COL_GAP,
    BTN_H = BTN_H,
    HDR_H = HDR_H,
    PAD = PAD,
    DB_W = DB_W,
    SB_W = SB_W,
    SB_GAP = SB_GAP,
    LIST_H = LIST_H,
    ROW_H = ROW_H,
    CAT_SF_W = DB_W - PAD * 2 - SB_W - SB_GAP,
    CreateAddButton = CreateAddButton,
    CreateScrollList = CreateScrollList,
    BuildRows = BuildRows,
    OpenEditPanel = OpenEditPanel,
    GenerateKey = GenerateKey,
    lantEditBtns = buttonPools.lantEdit,
    crystEditBtns = buttonPools.crystEdit,
    torchEditBtns = buttonPools.torchEdit,
    fuelEditBtns = buttonPools.fuelEdit,
    lantLinkBtns = buttonPools.lantLink,
    crystLinkBtns = buttonPools.crystLink,
    torchLinkBtns = buttonPools.torchLink,
    fuelLinkBtns = buttonPools.fuelLink,
    lantModBtns = buttonPools.lantMod,
    crystModBtns = buttonPools.crystMod,
    torchModBtns = buttonPools.torchMod,
    fuelModBtns = buttonPools.fuelMod,
    modEditBtns = buttonPools.modEdit,
    modLinkBtns = buttonPools.modLink,
    modModBtns = buttonPools.modMod,
    genericCatInfos = genericCatInfos,
    setRebuildLantList = function(fn) rebuildFns.lantern = fn end,
    setRebuildCrystList = function(fn) rebuildFns.crystal = fn end,
    setRebuildTorchList = function(fn) rebuildFns.torch = fn end,
    setRebuildFuelList = function(fn) rebuildFns.fuel = fn end,
    setRebuildModList = function(fn) rebuildFns.module = fn end,
    RebuildLantList = function(...)
        if rebuildFns.lantern then return rebuildFns.lantern(...) end
    end,
    RebuildCrystList = function(...)
        if rebuildFns.crystal then return rebuildFns.crystal(...) end
    end,
    RebuildTorchList = function(...)
        if rebuildFns.torch then return rebuildFns.torch(...) end
    end,
    RebuildFuelList = function(...)
        if rebuildFns.fuel then return rebuildFns.fuel(...) end
    end,
    RebuildModList = function(...)
        if rebuildFns.module then return rebuildFns.module(...) end
    end,
}

if OS2.DB.BuildLanternDatabaseTab then
    OS2.DB.BuildLanternDatabaseTab(databaseTabContext)
end

if OS2.DB.BuildTorchDatabaseTab then
    OS2.DB.BuildTorchDatabaseTab(databaseTabContext)
end

do  -- Onglet Survie : Hydratation (haut) + Alimentation (bas)
    local survieTabIndex = databaseTabContext.tabIndexByKey and databaseTabContext.tabIndexByKey["gourde"]
    if survieTabIndex then
        local survieTab  = databaseTabContext.tabCDB[survieTabIndex]
        local SEC_GAP    = 6
        local SEC_LIST_H = math.floor((LIST_H - (HDR_H + SEC_GAP)) / 2)

        if OS2.DB.BuildHydratationSection then
            OS2.DB.BuildHydratationSection(databaseTabContext, 0, SEC_LIST_H)
        end

        if survieTab then
            local sep  = survieTab:CreateTexture(nil, "ARTWORK")
            local sfW  = DB_W - PAD * 2 - SB_W - SB_GAP
            local sepY = HDR_H + SEC_LIST_H + 3
            UI.ApplySeparator(sep); sep:SetHeight(1)
            sep:SetPoint("TOPLEFT",  survieTab, "TOPLEFT", PAD,                        -sepY)
            sep:SetPoint("TOPRIGHT", survieTab, "TOPLEFT", PAD + sfW + SB_GAP + SB_W, -sepY)
        end

        if OS2.DB.BuildAlimentationSection then
            local offsetY2 = HDR_H + SEC_LIST_H + SEC_GAP
            OS2.DB.BuildAlimentationSection(databaseTabContext, offsetY2, SEC_LIST_H)
        end
    end
end

if OS2.DB.BuildGenericDatabaseTabs then
    OS2.DB.BuildGenericDatabaseTabs(databaseTabContext)
end

-- ── Bouton Édition (sur dbPanel, actif pour tous les onglets) ───────────
local editionBtn = CreateFrame("Button", nil, dbPanel)
editionBtn:SetSize(80, 22); editionBtn:SetPoint("BOTTOMRIGHT", dbPanel, "BOTTOMRIGHT", -PAD, PAD)

local eBg = editionBtn:CreateTexture(nil, "BACKGROUND")
eBg:SetAllPoints(); eBg:SetColorTexture(0.10,0.10,0.10,1); editionBtn.bgN = eBg
local eLine = editionBtn:CreateTexture(nil, "ARTWORK"); eLine:SetHeight(2)
eLine:SetPoint("BOTTOMLEFT",editionBtn,"BOTTOMLEFT",2,1); eLine:SetPoint("BOTTOMRIGHT",editionBtn,"BOTTOMRIGHT",-2,1)
eLine:SetColorTexture(0.80,0.70,0.40,1); eLine:Hide(); editionBtn.activeLine = eLine
local eHl = editionBtn:CreateTexture(nil, "HIGHLIGHT"); eHl:SetAllPoints(); eHl:SetColorTexture(0.85,0.75,0.40,0.10)
local eLbl = editionBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
eLbl:SetAllPoints(); eLbl:SetTextColor(0.88,0.82,0.65,1); eLbl:SetText("Édition")

local function SetEditMode(active)
    editMode = active
    editionBtn.activeLine:SetShown(active)
    editionBtn.bgN:SetColorTexture(active and 0.18 or 0.10, active and 0.15 or 0.10, active and 0.08 or 0.10, 1)

    for _, b in ipairs(buttonPools.add)       do b:SetShown(active) end
    for _, b in ipairs(buttonPools.lantEdit)  do b:SetShown(active) end
    for _, b in ipairs(buttonPools.crystEdit) do b:SetShown(active) end
    for _, b in ipairs(buttonPools.torchEdit) do b:SetShown(active) end
    for _, b in ipairs(buttonPools.fuelEdit)  do b:SetShown(active) end
    for _, b in ipairs(buttonPools.lantMod)   do b:SetShown(active) end
    for _, b in ipairs(buttonPools.crystMod)  do b:SetShown(active) end
    for _, b in ipairs(buttonPools.torchMod)  do b:SetShown(active) end
    for _, b in ipairs(buttonPools.fuelMod)   do b:SetShown(active) end
    for _, b in ipairs(buttonPools.modEdit)   do b:SetShown(active) end
    for _, b in ipairs(buttonPools.modMod)    do b:SetShown(active) end
    for _, b in ipairs(buttonPools.lantLink)  do b:SetShown(not active) end
    for _, b in ipairs(buttonPools.crystLink) do b:SetShown(not active) end
    for _, b in ipairs(buttonPools.torchLink) do b:SetShown(not active) end
    for _, b in ipairs(buttonPools.fuelLink)  do b:SetShown(not active) end
    for _, b in ipairs(buttonPools.modLink)   do b:SetShown(not active) end

    -- Catégories génériques
    for _, cat in ipairs(genericCatInfos) do
        for _, b in ipairs(cat.editBtns) do b:SetShown(active)      end
        for _, b in ipairs(cat.modBtns)  do b:SetShown(active)      end
        for _, b in ipairs(cat.linkBtns) do b:SetShown(not active)  end
    end

    if not active then editPanel:Hide() end
end

editionBtn:SetScript("OnClick", function() SetEditMode(not editMode) end)

dbPanel:HookScript("OnHide", function()
    if editMode then SetEditMode(false) end
end)

-- ── Init ───────────────────────────────────────────────────────────────
local function RefreshDatabasePanel()
    if OS2.EnsureDB then
        OS2.EnsureDB()
    end
    ApplyDatabaseTabOrder(GetSavedDatabaseTabOrder())
    itemInfoPanel:Hide()
    editPanel:Hide()
    if rebuildFns.lantern then rebuildFns.lantern() end
    if rebuildFns.crystal then rebuildFns.crystal() end
    if rebuildFns.torch then rebuildFns.torch() end
    if rebuildFns.fuel then rebuildFns.fuel() end
    if rebuildFns.module then rebuildFns.module() end
    for _, cat in ipairs(genericCatInfos) do
        cat.rebuildFn()
    end
    SelectTabDB(1)
end

RefreshDatabasePanel()

-- ── API ────────────────────────────────────────────────────────────────
OS2.dbPanel = dbPanel
OS2.RefreshDatabasePanel = RefreshDatabasePanel

function OS2.ToggleDBPanel(replacePanel)
    RefreshDatabasePanel()

    if OS2.IsSettingsPanelOpen and OS2.IsSettingsPanelOpen(dbPanel) then
        OS2.HideSettingsPanel(dbPanel)
        return
    end

    if replacePanel and OS2.IsSettingsPanelOpen and OS2.IsSettingsPanelOpen(replacePanel) then
        OS2.HideSettingsPanel(replacePanel)
    end

    OS2.ShowSettingsPanel(dbPanel, OS2.Launcher)
end

do
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:SetScript("OnEvent", function(_, _, addonName)
        if addonName ~= "Omega_Hub" then
            return
        end

        RefreshDatabasePanel()
        initFrame:UnregisterEvent("ADDON_LOADED")
    end)
end
