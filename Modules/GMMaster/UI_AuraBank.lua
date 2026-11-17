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
    title:SetText("Banque d'auras")
    UI.ApplyTitle(title)
    UI.CreateCloseButton(bank, function() bank:Hide() end)
end

local function Label(text, x, y, parent)
    local fs = (parent or bank):CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    UI.ApplyLabel(fs)
    return fs
end

-- ── Ajout ─────────────────────────────────────────────────────────────────

Label("ID du sort", PAD, -50)
local idBox = UI.CreateStyledEditBox(bank, 90, 22)
idBox:SetPoint("TOPLEFT", PAD, -64)
idBox:SetNumeric(true)
bank.idBox = idBox

Label("Sur", PAD + 100, -50)
bank.newWho = "self"
local whoBtn = UI.CreatePanelButton(bank, 90, 22, "")
whoBtn:SetPoint("TOPLEFT", PAD + 100, -64)
bank.whoBtn = whoBtn

Label("Note (facultative)", PAD + 200, -50)
local noteBox = UI.CreateStyledEditBox(bank, 160, 22)
noteBox:SetPoint("TOPLEFT", PAD + 200, -64)
noteBox:SetMaxLetters(24)
bank.noteBox = noteBox

local addBtn = UI.CreatePanelButton(bank, 90, 22, "Ajouter")
addBtn:SetPoint("TOPLEFT", PAD + 370, -64)
bank.addBtn = addBtn

local preview = bank:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
    local id = tonumber(idBox:GetText())
    if not id then
        preview:SetText("Moi : interrupteur sur la barre  ·  Ma cible / PNJ ciblé : clic = poser, Alt + clic = retirer")
        return
    end
    local name, icon = GM.SpellInfo(id)
    preview:SetText(name and ((icon and ("|T" .. icon .. ":14|t ") or "") .. "|cffffffff" .. name .. "|r") or "|cff888888Sort inconnu|r")
end

local function DoAdd()
    local ok, err = GM:AddAura(idBox:GetText(), bank.newWho, noteBox:GetText())
    if ok then
        idBox:SetText(""); noteBox:SetText("")
        bank.offset = 0
        UpdatePreview()
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
    if GM.PreviewAuraSoon and tonumber(self:GetText()) then GM:PreviewAuraSoon(self:GetText()) end
end)

local sep = bank:CreateTexture(nil, "ARTWORK")
sep:SetPoint("TOPLEFT", 4, LIST_Y + 8)
sep:SetPoint("TOPRIGHT", bank, "TOPLEFT", LIST_W, LIST_Y + 8)
sep:SetHeight(1)
UI.ApplySeparator(sep, true)

-- ── Liste ─────────────────────────────────────────────────────────────────

bank.offset = 0
bank.rows = {}

local function EntryTooltip(owner, entry)
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
        if button == "LeftButton" and row.entry and GM.PreviewAura then GM:PreviewAura(row.entry.id) end
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
    row.apply  = Btn(56, "Poser", 324, function(entry) GM:ApplyAura(entry, false) end)
    row.remove = Btn(62, "Retirer", 384, function(entry) GM:ApplyAura(entry, true) end)
    row.toBar  = Btn(70, "Barre +", 450, function(entry) GM:AuraToBar(entry) end,
        { "Ajouter à la barre MJ", "Moi : interrupteur (l'état est lu sur vos auras).",
          "Ma cible / PNJ ciblé : clic = poser, Alt + clic = retirer." })
    row.delete = Btn(24, "×", 526, function(_, index)
        local now = GetTime and GetTime() or 0
        if row.armed and now - row.armed < 3 then
            row.armed = nil
            GM:RemoveAura(index)
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
    local list = GM.EnsureAuraBank()
    bank.offset = math.max(0, math.min(bank.offset, math.max(0, #list - ROWS)))
    for i, row in ipairs(bank.rows) do
        local index = bank.offset + i
        local entry = list[index]
        row.entry, row.index = entry, entry and index or nil
        if entry then
            local _, icon = GM.SpellInfo(entry.id)
            row.icon:SetTexture(icon or 134400)
            row.text:SetText(GM.AuraLabel(entry) .. "  |cff888888" .. entry.id .. "|r")
            row.who:SetText(GM.AuraTargetLabel(entry.who))
            local previewed = GM.PreviewedAura and GM.PreviewedAura() == entry.id
            row.bg:SetColorTexture(unpack(previewed and UI.colors.rowBgSelected or UI.colors.rowBg))
            row.delete:SetText("×")
            row.armed = nil
            row:Show()
        else
            row:Hide()
        end
    end
    empty:SetShown(#list == 0)
    if #list > ROWS then
        pager:SetText((bank.offset + 1) .. "–" .. math.min(#list, bank.offset + ROWS) .. " sur " .. #list .. "  ·  molette pour défiler")
    else
        pager:SetText(#list > 0 and (#list .. " aura" .. (#list > 1 and "s" or "")) or "")
    end
end
bank.Refresh = Refresh

bank:SetScript("OnMouseWheel", function(_, delta)
    bank.offset = bank.offset - delta * 3
    Refresh()
end)
bank:SetScript("OnShow", function() UpdatePreview(); Refresh() end)

GM:OnChange(Refresh)

function GM:ToggleAuraBank(show)
    if show == nil then show = not bank:IsShown() end
    bank:SetShown(show)
end
