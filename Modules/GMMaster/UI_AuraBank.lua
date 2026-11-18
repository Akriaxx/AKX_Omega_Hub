-- ============================================================
--  GM Master — Banque d'auras
--  Liste d'auras favorites, chacune avec sa cible (moi, ma cible,
--  PNJ ciblé). Poser / retirer en un clic, ou en faire une case de
--  la barre MJ : interrupteur pour « moi » (état lu sur vos auras),
--  clic = poser / Alt + clic = retirer pour une cible ou un PNJ.
--  À droite, l'aperçu (UI_AuraPreview.lua) joue l'aura saisie ou
--  cliquée sur le modèle de la race choisie.
-- ============================================================

local GM = GMMaster
local UI = OS2.UI

local LIST_W = 600    -- liste ; l'aperçu occupe le reste
local W, H   = LIST_W + 300, 530
local PAD    = 14
local ROW_H  = 26
local ROWS   = 13
local LIST_Y = -118

local function ShowTooltip(owner, lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:SetText(line, 1, 1, 1)
        else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end
local function HideTooltip() if GameTooltip then GameTooltip:Hide() end end

local bank = CreateFrame("Frame", "GMMasterAuraBank", UIParent, "BackdropTemplate")
bank:SetSize(W, H)
bank:SetPoint("CENTER", 120, 0)
bank:SetFrameStrata("HIGH")
bank:SetClampedToScreen(true)
bank:SetMovable(true)
bank:EnableMouse(true)
bank:EnableMouseWheel(true)
bank:RegisterForDrag("LeftButton")
bank:SetScript("OnDragStart", bank.StartMoving)
bank:SetScript("OnDragStop", bank.StopMovingOrSizing)
bank.listWidth, bank.previewWidth = LIST_W, W - LIST_W
bank:Hide()
tinsert(UISpecialFrames, "GMMasterAuraBank")
do
    local bg = bank:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.97)
    bank:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    bank:SetBackdropBorderColor(unpack(UI.colors.separator))
    local title = bank:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD + 2, -14)
    title:SetText("Banque MJ")
    UI.ApplyTitle(title)
    UI.CreateCloseButton(bank, function() bank:Hide() end)
end

bank.kind = "aura"
local tabs = {}
local kinds = { { "aura", "Auras" }, { "emote", "Émotes" }, { "anim", "Animations" }, { "cast", "Casts" } }
for i, item in ipairs(kinds) do
    local tab = UI.CreatePanelButton(bank, 94, 22, item[2])
    tab:SetPoint("TOPLEFT", PAD + 160 + (i - 1) * 98, -12)
    tab:SetScript("OnClick", function()
        bank.kind, bank.offset = item[1], 0
        if bank.Refresh then bank:Refresh() end
        if bank.UpdateInput then bank:UpdateInput() end
    end)
    tabs[item[1]] = tab
end
bank.tabs = tabs

local function Label(text, x, y, parent)
    local fs = (parent or bank):CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    UI.ApplyLabel(fs)
    return fs
end

-- ── Ajout ─────────────────────────────────────────────────────────────────

local idLabel = Label("ID du sort", PAD, -50)
local idBox = UI.CreateStyledEditBox(bank, 90, 22)
idBox:SetPoint("TOPLEFT", PAD, -64)
idBox:SetNumeric(true)
bank.idBox = idBox

local whoLabel = Label("Sur", PAD + 100, -50)
bank.newWho = "self"
local whoBtn = UI.CreatePanelButton(bank, 90, 22, "")
whoBtn:SetPoint("TOPLEFT", PAD + 100, -64)
bank.whoBtn = whoBtn
local testBtn = UI.CreatePanelButton(bank, 90, 22, "Tester ID")
testBtn:SetPoint("TOPLEFT", PAD + 100, -64)
testBtn:Hide()
testBtn:SetScript("OnClick", function()
    local id = tonumber(idBox:GetText())
    if not id or id <= 0 or id % 1 ~= 0 then return end
    GM:RunNpcAction(bank.kind, id)
end)
bank.testBtn = testBtn

Label("Note (facultative)", PAD + 200, -50)
local noteBox = UI.CreateStyledEditBox(bank, 160, 22)
noteBox:SetPoint("TOPLEFT", PAD + 200, -64)
noteBox:SetMaxLetters(24)
bank.noteBox = noteBox

local addBtn = UI.CreatePanelButton(bank, 90, 22, "Ajouter")
addBtn:SetPoint("TOPLEFT", PAD + 370, -64)
bank.addBtn = addBtn
local preview
local lookupBtn = UI.CreatePanelButton(bank, 90, 22, "Chercher")
lookupBtn:SetPoint("TOPLEFT", PAD + 468, -64)
lookupBtn:Hide()
bank.lookupBtn = lookupBtn
lookupBtn:SetScript("OnClick", function()
    local query = noteBox:GetText()
    if query == "" then query = idBox:GetText() end
    if query == "" then preview:SetText("|cffdd5555Saisir un nom dans Note pour chercher.|r") return end
    local spec = GM.NPC_ACTIONS[bank.kind]
    if spec then GM:RunMacro(spec.lookup .. " " .. query) end
end)

preview = bank:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
preview:SetPoint("TOPLEFT", PAD, -92)
preview:SetPoint("RIGHT", bank, "LEFT", LIST_W - PAD, 0)
preview:SetJustifyH("LEFT")
preview:SetWordWrap(false)
UI.ApplyMutedText(preview)
bank.preview = preview

local function SyncWho()
    whoBtn:SetText(GM.AuraTargetLabel(bank.newWho))
end
whoBtn:SetScript("OnClick", function()
    local entry = { who = bank.newWho }
    for i, t in ipairs(GM.AURA_TARGETS) do
        if t.value == entry.who then bank.newWho = GM.AURA_TARGETS[i % #GM.AURA_TARGETS + 1].value break end
    end
    SyncWho()
end)

local function UpdatePreview()
    if bank.kind ~= "aura" then
        local spec = GM.NPC_ACTIONS[bank.kind]
        local id = tonumber(idBox:GetText())
        if id then
            local name = bank.kind == "cast" and GM.SpellInfo(id)
            preview:SetText((name and name .. "  ·  " or "") .. "." .. spec.command:format(id))
        else
            preview:SetText("Chercher : saisir un nom dans Note, puis consulter les résultats dans le chat. Tester avec l'ID trouvé.")
        end
        return
    end
    local id = tonumber(idBox:GetText())
    if not id then
        preview:SetText("Moi : interrupteur sur la barre  ·  Ma cible / PNJ ciblé : clic = poser, Alt + clic = retirer")
        return
    end
    local name, icon = GM.SpellInfo(id)
    preview:SetText(name and ((icon and ("|T" .. icon .. ":14|t ") or "") .. "|cffffffff" .. name .. "|r") or "|cff888888Sort inconnu|r")
end

local castListBtn = UI.CreatePanelButton(bank, 160, 22, "Casts du PNJ ciblé")
castListBtn:SetPoint("TOPLEFT", bank, "TOPLEFT", LIST_W + 14, -12)
castListBtn:Hide()
castListBtn:SetScript("OnClick", function() GM:RunMacro("npc cast list") end)
bank.castListBtn = castListBtn

local function DoAdd()
    local ok, err
    if bank.kind == "aura" then ok, err = GM:AddAura(idBox:GetText(), bank.newWho, noteBox:GetText())
    else ok, err = GM:AddNpcAction(bank.kind, idBox:GetText(), noteBox:GetText()) end
    if ok then
        idBox:SetText(""); noteBox:SetText("")
        bank.offset = 0
        UpdatePreview()
        if GM.PreviewAction then GM:PreviewAction(bank.kind, nil) end
    else
        preview:SetText("|cffdd5555" .. err .. "|r")
    end
end
addBtn:SetScript("OnClick", DoAdd)
idBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); DoAdd() end)
noteBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); DoAdd() end)
idBox:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    UpdatePreview()
    -- L'aura saisie se joue sur le modèle, sans attendre « Ajouter ».
    if GM.PreviewActionSoon then GM:PreviewActionSoon(bank.kind, self:GetText()) end
end)

function bank:UpdateInput()
    local aura = self.kind == "aura"
    idLabel:SetText((aura or self.kind == "cast") and "ID du sort" or "ID d'émote / animation")
    whoLabel:SetShown(aura)
    whoBtn:SetShown(aura)
    testBtn:SetShown(not aura)
    lookupBtn:SetShown(not aura)
    if self.previewColumn then self.previewColumn:Show() end
    castListBtn:SetShown(self.kind == "cast")
    UpdatePreview()
    if GM.PreviewAction then GM:PreviewAction(self.kind, idBox:GetText()) end
end

local sep = bank:CreateTexture(nil, "ARTWORK")
sep:SetPoint("TOPLEFT", 4, LIST_Y + 8)
sep:SetPoint("TOPRIGHT", bank, "TOPLEFT", LIST_W, LIST_Y + 8)
sep:SetHeight(1)
UI.ApplySeparator(sep, true)

-- ── Liste ─────────────────────────────────────────────────────────────────

bank.offset = 0
bank.rows = {}

local function EntryTooltip(owner, entry)
    if bank.kind ~= "aura" then
        local spec = GM.NPC_ACTIONS[bank.kind]
        local lines = { entry.note or (spec.label .. " " .. entry.id),
            "Essayer : ." .. spec.command:format(entry.id),
            "Chercher un ID : ." .. spec.lookup .. " <nom>" }
        if spec.alternate then lines[#lines + 1] = "Autre essai : ." .. spec.alternate:format(entry.id) end
        ShowTooltip(owner, lines)
        return
    end
    local on, off = GM.AuraCommands(entry)
    local name = GM.SpellInfo(entry.id)
    ShowTooltip(owner, {
        GM.AuraLabel(entry),
        (name and name ~= GM.AuraLabel(entry) and (name .. "  ") or "") .. "|cff888888ID " .. entry.id .. "|r",
        "Poser :  |cffffffff." .. (GM.ResolveLine(on).short or on) .. "|r",
        "Retirer :  |cffffffff." .. (GM.ResolveLine(off).short or off) .. "|r",
        "|cffAAAAAAClic : aperçu sur le modèle|r",
    })
end

for i = 1, ROWS do
    local row = CreateFrame("Frame", nil, bank)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT", PAD, LIST_Y - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", bank, "LEFT", LIST_W - PAD, 0)
    local rbg = row:CreateTexture(nil, "BACKGROUND")
    rbg:SetAllPoints()
    rbg:SetColorTexture(unpack(UI.colors.rowBg))
    row.bg = rbg

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", 2, 0)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.icon = icon

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    text:SetWidth(200)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    UI.ApplyBodyText(text)
    row.text = text

    local hover = CreateFrame("Frame", nil, row)
    hover:SetPoint("TOPLEFT", 0, 0)
    hover:SetPoint("BOTTOMLEFT", 0, 0)
    hover:SetWidth(230)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self) if row.entry then EntryTooltip(self, row.entry) end end)
    hover:SetScript("OnLeave", HideTooltip)
    hover:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and row.entry then
            if GM.PreviewAction then GM:PreviewAction(bank.kind, row.entry.id) end
            if bank.kind ~= "aura" then idBox:SetText(tostring(row.entry.id)); UpdatePreview() end
        end
    end)
    row.hover = hover

    local function Btn(w, label, x, onClick, tip)
        local b = UI.CreatePanelButton(row, w, 20, label)
        b:SetPoint("LEFT", x, 0)
        b:SetScript("OnClick", function() if row.entry then onClick(row.entry, row.index) end end)
        if tip then
            b:SetScript("OnEnter", function(self) ShowTooltip(self, tip) end)
            b:SetScript("OnLeave", HideTooltip)
        end
        return b
    end
    row.who = Btn(84, "", 236, function(entry) GM:CycleAuraTarget(entry) end,
        { "Cible de l'aura", "Clic : Moi > Ma cible > PNJ ciblé." })
    row.apply  = Btn(56, "Poser", 324, function(entry)
        if bank.kind == "aura" then GM:ApplyAura(entry, false) else GM:RunNpcAction(bank.kind, entry.id) end
    end)
    row.remove = Btn(62, "Retirer", 384, function(entry)
        if bank.kind == "aura" then GM:ApplyAura(entry, true) else GM:RunNpcAction(bank.kind, entry.id, true) end
    end)
    row.toBar  = Btn(70, "Barre +", 450, function(entry)
        if bank.kind == "aura" then GM:AuraToBar(entry) else GM:NpcActionToBar(bank.kind, entry) end
    end)
    row.delete = Btn(24, "×", 526, function(_, index)
        local now = GetTime and GetTime() or 0
        if row.armed and now - row.armed < 3 then
            row.armed = nil
            if bank.kind == "aura" then GM:RemoveAura(index) else GM:RemoveNpcAction(bank.kind, index) end
        else
            row.armed = now
            row.delete:SetText("|cffdd5555?|r")
        end
    end, { "Retirer de la banque", "Cliquer deux fois pour confirmer." })
    row.index = nil
    bank.rows[i] = row
end

local empty = bank:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
empty:SetPoint("TOPLEFT", PAD + 4, LIST_Y - 6)
empty:SetText("|cff888888Aucune aura. Saisissez un ID de sort ci-dessus, puis Ajouter.|r")

local pager = bank:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pager:SetPoint("BOTTOMLEFT", PAD + 2, 14)
UI.ApplySoftText(pager)

local function Refresh()
    if not bank:IsShown() then return end
    SyncWho()
    local list = bank.kind == "aura" and GM.EnsureAuraBank() or GM.EnsureNpcActionBank(bank.kind)
    for kind, tab in pairs(tabs) do tab:SetAlpha(kind == bank.kind and 1 or 0.55) end
    bank.offset = math.max(0, math.min(bank.offset, math.max(0, #list - ROWS)))
    for i, row in ipairs(bank.rows) do
        local index = bank.offset + i
        local entry = list[index]
        row.entry, row.index = entry, entry and index or nil
        if entry then
            local icon
            if bank.kind == "aura" or bank.kind == "cast" then
                local _, foundIcon = GM.SpellInfo(entry.id)
                icon = foundIcon
            end
            row.icon:SetTexture(icon or 134400)
            local spellName = bank.kind == "cast" and GM.SpellInfo(entry.id)
            local label = bank.kind == "aura" and GM.AuraLabel(entry)
                or entry.note or spellName or (GM.NPC_ACTIONS[bank.kind].label .. " " .. entry.id)
            row.text:SetText(label .. "  |cff888888" .. entry.id .. "|r")
            row.who:SetShown(bank.kind == "aura")
            if bank.kind == "aura" then row.who:SetText(GM.AuraTargetLabel(entry.who)) end
            row.apply:SetText(bank.kind == "aura" and "Poser" or "Tester")
            row.remove:SetShown(bank.kind == "aura" or GM.NPC_ACTIONS[bank.kind].alternate ~= nil)
            row.remove:SetText(bank.kind == "aura" and "Retirer" or bank.kind == "emote" and "Répéter" or "Zone")
            local previewed = bank.kind == "aura" and GM.PreviewedAura and GM.PreviewedAura() == entry.id
            row.bg:SetColorTexture(unpack(previewed and UI.colors.rowBgSelected or UI.colors.rowBg))
            row.delete:SetText("×")
            row.armed = nil
            row:Show()
        else
            row:Hide()
        end
    end
    empty:SetText("|cff888888Aucun favori. Cherchez un ID, saisissez-le puis cliquez Ajouter.|r")
    empty:SetShown(#list == 0)
    if #list > ROWS then
        pager:SetText((bank.offset + 1) .. "–" .. math.min(#list, bank.offset + ROWS) .. " sur " .. #list .. "  ·  molette pour défiler")
    else
        pager:SetText(#list > 0 and (#list .. " favori" .. (#list > 1 and "s" or "")) or "")
    end
end
bank.Refresh = Refresh

bank:SetScript("OnMouseWheel", function(_, delta)
    bank.offset = bank.offset - delta * 3
    Refresh()
end)
bank:SetScript("OnShow", function() bank:UpdateInput(); Refresh() end)

GM:OnChange(Refresh)

function GM:ToggleAuraBank(show)
    if show == nil then show = not bank:IsShown() end
    bank:SetShown(show)
end
