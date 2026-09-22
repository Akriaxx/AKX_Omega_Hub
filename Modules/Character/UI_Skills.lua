-- ============================================================
--  Character - Base de données de compétences
--  4 catégories (Offensive / Défensive / Distance / Actions de
--  base), éditables via un builder (Paramètres -> Base de
--  données). Chaque compétence : nom, icône, description. La
--  description supporte des tags de couleur {{rouge}}...{{/}}
--  et des références croisées {{Catégorie : Nom}} qui affichent
--  une infobulle imbriquée au survol, partout où une description
--  est affichée (builder, bouton Action).
-- ============================================================
local C = Character
local UI = C.RPGUI or OS2.UI

C.SKILL_CATEGORIES = {
    { key = "offensive", label = "Compétence Offensive",  tag = "Offensive", aliases = { "offensive" } },
    { key = "defensive", label = "Compétence Défensive",  tag = "Défensive", aliases = { "defensive", "défensive" } },
    { key = "ranged",    label = "Compétence à Distance", tag = "Distance",  aliases = { "distance" } },
    { key = "base",      label = "Actions de base",       tag = "Action",    aliases = { "action" } },
}
local CATEGORIES = C.SKILL_CATEGORIES

local COLOR_TAGS = {
    rouge  = "ffe23c3c", bleu   = "ff3ca0e2", vert  = "ff3ce26b", jaune = "ffe2d33c",
    violet = "ffb03ce2", orange = "ffe27a3c", blanc = "ffffffff", gris  = "ffa0a0a0",
    ["or"] = "ffffd100",
}
local COLOR_ORDER = { "rouge", "bleu", "vert", "jaune", "violet", "orange", "blanc", "gris", "or" }

local function FindCategory(key)
    for _, cat in ipairs(CATEGORIES) do if cat.key == key then return cat end end
end

-- Le sélecteur d'icônes de Blizzard (GetMacroIcons) peut renvoyer des
-- FileID numériques selon le client, pas toujours un chemin texte. Le
-- champ de saisie ne stocke jamais que du texte (même pour un FileID,
-- ex. "134400") : cette fonction le reconvertit en nombre avant tout
-- SetTexture, pour que les deux formes marchent identiquement.
function C:ResolveIconValue(icon)
    if icon == nil or icon == "" then return nil end
    return tonumber(icon) or icon
end

local function ResolveCategoryByTag(tag)
    tag = (tag or ""):lower()
    for _, cat in ipairs(CATEGORIES) do
        for _, alias in ipairs(cat.aliases) do
            if alias == tag then return cat end
        end
    end
end

-- ── Stockage : une base par personnage, comme le reste de Character ────────
local function OwnerKey()
    return (UnitName("player") or "player") .. "-" .. (GetRealmName() or "")
end

local function GetSkillDB()
    CharacterDB = CharacterDB or {}
    CharacterDB.skills = CharacterDB.skills or {}
    local key = OwnerKey()
    CharacterDB.skills[key] = CharacterDB.skills[key] or {}
    local db = CharacterDB.skills[key]
    for _, cat in ipairs(CATEGORIES) do
        db[cat.key] = db[cat.key] or {}
    end
    return db
end

-- ── CRUD ─────────────────────────────────────────────────────────────────────
function C:ListSkills(catKey)
    local db = GetSkillDB()
    local names = {}
    for name in pairs(db[catKey] or {}) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    local list = {}
    for _, name in ipairs(names) do list[#list + 1] = db[catKey][name] end
    return list
end

function C:GetSkill(catKey, name)
    local db = GetSkillDB()
    return db[catKey] and db[catKey][name]
end

-- oldName nil/absent = création ; renommage géré en retirant l'ancienne clé.
function C:SaveSkill(catKey, oldName, name, icon, description)
    if not FindCategory(catKey) then return false, "Catégorie inconnue" end
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return false, "Nom requis" end
    local db = GetSkillDB()
    if oldName and oldName ~= name then db[catKey][oldName] = nil end
    db[catKey][name] = {
        name = name,
        icon = (icon and icon ~= "") and icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        description = description or "",
    }
    return true
end

function C:DeleteSkill(catKey, name)
    local db = GetSkillDB()
    if db[catKey] then db[catKey][name] = nil end
end

-- ── Rendu du texte : couleurs + références croisées ─────────────────────────
-- {{rouge}}texte{{/}} -> code couleur WoW. {{Catégorie : Nom}} -> lien
-- hypertexte cliquable/survolable pointant vers une autre compétence.
function C:RenderSkillText(text)
    text = tostring(text or "")
    text = text:gsub("{{%s*(%a+)%s*}}(.-){{/}}", function(colorName, inner)
        local hex = COLOR_TAGS[colorName:lower()]
        if not hex then return "{{" .. colorName .. "}}" .. inner .. "{{/}}" end
        return "|c" .. hex .. inner .. "|r"
    end)
    text = text:gsub("{{%s*([^:{}]-)%s*:%s*([^{}]-)%s*}}", function(tag, name)
        local cat = ResolveCategoryByTag(tag)
        if not cat then return "{{" .. tag .. " : " .. name .. "}}" end
        return "|Hcharskill:" .. cat.key .. ":" .. name .. "|h|cff8fd6ff[" .. name .. "]|r|h"
    end)
    return text
end

-- ── Infobulle imbriquée pour les références {{Catégorie : Nom}} ─────────────
-- Un GameTooltip qui affiche du texte contenant nos liens |Hcharskill:..|h
-- déclenche OnHyperlinkEnter dessus ; on affiche une seconde infobulle avec
-- la compétence référencée. N'importe quel appelant qui utilise
-- GameTooltip:AddLine(C:RenderSkillText(desc), ..., true) profite de ce
-- comportement sans rien faire de plus.
local refTooltip = CreateFrame("GameTooltip", "CharacterSkillRefTooltip", UIParent, "GameTooltipTemplate")
GameTooltip:HookScript("OnHyperlinkEnter", function(self, link)
    local kind, catKey, name = link:match("^(%a+):([^:]+):(.+)$")
    if kind ~= "charskill" then return end
    local skill = C:GetSkill(catKey, name)
    if not skill then return end
    refTooltip:SetOwner(self, "ANCHOR_RIGHT")
    refTooltip:SetText(skill.name, 1, .82, 0)
    if skill.description ~= "" then
        refTooltip:AddLine(C:RenderSkillText(skill.description), .9, .9, .9, true)
    end
    refTooltip:Show()
end)
GameTooltip:HookScript("OnHyperlinkLeave", function() refTooltip:Hide() end)

-- ============================================================
--  Builder : Paramètres -> Base de données
-- ============================================================
local PANEL_W, PANEL_H = 560, 440
local LIST_W = 176

local panel, tabButtons, listContent, listViewport
local nameEB, iconEB, iconPreview, descEB, descPreview, statusFS
local activeCat, editingName
local RefreshList, RefreshForm

local function ClearForm()
    editingName = nil
    nameEB:SetText("")
    iconEB:SetText("")
    descEB:SetText("")
    iconPreview.tex:SetTexture(nil)
    descPreview:SetText("")
end

local function LoadIntoForm(skill)
    editingName = skill.name
    nameEB:SetText(skill.name)
    iconEB:SetText(skill.icon or "")
    descEB:SetText(skill.description or "")
    iconPreview.tex:SetTexture(C:ResolveIconValue(skill.icon))
    descPreview:SetText(C:RenderSkillText(skill.description or ""))
end

local function ShowStatus(text, isError)
    statusFS:SetText(text or "")
    statusFS:SetTextColor(isError and 1 or .6, isError and .3 or .9, isError and .3 or .5)
end

local skillRows = {}
local function MakeSkillRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(20)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(unpack(UI.colors.rowBg))
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16); icon:SetPoint("LEFT", 3, 0)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", icon, "RIGHT", 5, 0); text:SetPoint("RIGHT", -4, 0)
    text:SetJustifyH("LEFT"); text:SetWordWrap(false)
    UI.ApplyBodyText(text)
    row.icon, row.text, row.bg = icon, text, bg
    row:SetScript("OnEnter", function(self) bg:SetColorTexture(unpack(UI.colors.rowBgSelected)) end)
    row:SetScript("OnLeave", function(self) bg:SetColorTexture(unpack(UI.colors.rowBg)) end)
    row:SetScript("OnClick", function(self)
        LoadIntoForm(self.skill)
        ShowStatus("")
    end)
    return row
end

function RefreshList()
    local skills = C:ListSkills(activeCat.key)
    for i, skill in ipairs(skills) do
        local row = skillRows[i]
        if not row then row = MakeSkillRow(listContent); skillRows[i] = row end
        row.skill = skill
        row.icon:SetTexture(C:ResolveIconValue(skill.icon))
        row.text:SetText(skill.name)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * 22)
        row:SetWidth(LIST_W)
        row:Show()
    end
    for i = #skills + 1, #skillRows do skillRows[i]:Hide() end
    listContent:SetHeight(math.max(1, #skills * 22))
end

function RefreshForm()
    ClearForm()
end

local function SelectTab(cat)
    activeCat = cat
    for _, btn in ipairs(tabButtons) do UI.ApplyTabState(btn, btn.cat == cat) end
    RefreshList()
    RefreshForm()
    ShowStatus("")
end

-- ── Sélecteur d'icônes : la grille standard de Blizzard (GetMacroIcons),
-- pas une saisie de chemin à la main. ───────────────────────────────────────
local iconPicker
local function BuildIconPicker()
    if iconPicker then return iconPicker end
    local PICKER_W, PICKER_H, COLS, CELL = 372, 420, 10, 34

    local p = CreateFrame("Frame", "CharacterIconPicker", UIParent)
    p:SetSize(PICKER_W, PICKER_H)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:SetFrameStrata("FULLSCREEN_DIALOG")
    p:SetToplevel(true)
    p:SetMovable(true)
    p:SetClampedToScreen(true)
    p:EnableMouse(true)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); UI.ApplyWindowBackground(bg, 0.97)
    UI.ApplyBorder(p)

    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -10)
    title:SetText("Choisir une icône")
    UI.ApplyTitle(title)

    local closeBtn = UI.CreateCloseButton(p, function() p:Hide() end)
    if closeBtn.SetFrameLevel then closeBtn:SetFrameLevel(p:GetFrameLevel() + 20) end

    local dragHandle = CreateFrame("Frame", nil, p)
    dragHandle:SetPoint("TOPLEFT"); dragHandle:SetPoint("TOPRIGHT"); dragHandle:SetHeight(28)
    dragHandle:EnableMouse(true)
    dragHandle:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then p:StartMoving() end end)
    dragHandle:SetScript("OnMouseUp", function() p:StopMovingOrSizing() end)

    local searchEB = UI.CreateStyledEditBox(p, PICKER_W - 20, 22)
    searchEB:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -32)

    local viewport = CreateFrame("ScrollFrame", nil, p)
    viewport:SetPoint("TOPLEFT", p, "TOPLEFT", 10, -60)
    viewport:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -28, 10)
    viewport:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(COLS * CELL, 1)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * CELL)))
    end)

    -- GetMacroIcons() renvoie TOUTES les icônes en valeurs multiples (pas
    -- une table) : {...} les capture toutes d'un coup.
    local allIcons = GetMacroIcons and { GetMacroIcons() } or {}
    local cells = {}
    local function Layout(filter)
        filter = filter ~= "" and filter:lower() or nil
        local shown = 0
        for _, value in ipairs(allIcons) do
            local asText = tostring(value)
            if not filter or asText:lower():find(filter, 1, true) then
                shown = shown + 1
                local cell = cells[shown]
                if not cell then
                    cell = CreateFrame("Button", nil, content)
                    cell:SetSize(CELL - 2, CELL - 2)
                    local tex = cell:CreateTexture(nil, "ARTWORK")
                    tex:SetAllPoints(); tex:SetTexCoord(.08, .92, .08, .92)
                    cell.tex = tex
                    local hl = cell:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, .3)
                    cell:SetScript("OnClick", function(self)
                        iconEB:SetText(tostring(self.value))
                        iconPreview.tex:SetTexture(C:ResolveIconValue(self.value))
                        p:Hide()
                    end)
                    cell:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_TOP")
                        GameTooltip:SetText(tostring(self.value))
                        GameTooltip:Show()
                    end)
                    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
                    cells[shown] = cell
                end
                cell.value = value
                cell.tex:SetTexture(C:ResolveIconValue(value))
                cell:ClearAllPoints()
                local col, rowIdx = (shown - 1) % COLS, math.floor((shown - 1) / COLS)
                cell:SetPoint("TOPLEFT", content, "TOPLEFT", col * CELL, -rowIdx * CELL)
                cell:Show()
            end
        end
        for i = shown + 1, #cells do cells[i]:Hide() end
        content:SetHeight(math.max(1, math.ceil(shown / COLS) * CELL))
    end
    searchEB:SetScript("OnTextChanged", function(self) Layout(self:GetText()) end)
    p.Layout = Layout

    iconPicker = p
    return p
end

local function Build()
    if panel then return panel end

    panel = CreateFrame("Frame", "CharacterSkillsBuilder", UIParent)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    -- Au-dessus du panneau Paramètres (DIALOG) qui l'ouvre : sinon les
    -- deux se mélangent à l'écran au lieu que le builder passe devant.
    panel:SetFrameStrata("FULLSCREEN_DIALOG")
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.94)
    UI.ApplyBorder(panel)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    title:SetText("Base de données — Compétences")
    UI.ApplyTitle(title)

    local closeBtn = UI.CreateCloseButton(panel, function() panel:Hide() end)
    if closeBtn.SetFrameLevel then closeBtn:SetFrameLevel(panel:GetFrameLevel() + 20) end

    local dragHandle = CreateFrame("Frame", nil, panel)
    dragHandle:SetPoint("TOPLEFT"); dragHandle:SetPoint("TOPRIGHT"); dragHandle:SetHeight(30)
    dragHandle:EnableMouse(true)
    dragHandle:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then panel:StartMoving() end end)
    dragHandle:SetScript("OnMouseUp", function() panel:StopMovingOrSizing() end)

    -- Onglets
    tabButtons = {}
    local tabW = (PANEL_W - 20) / #CATEGORIES
    for i, cat in ipairs(CATEGORIES) do
        local btn = CreateFrame("Button", nil, panel)
        btn:SetSize(tabW - 2, 22)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + (i - 1) * tabW, -30)
        btn.cat = cat
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints(); label:SetJustifyH("CENTER"); label:SetText(cat.label)
        local line = btn:CreateTexture(nil, "ARTWORK")
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(2)
        btn.label, btn.line = label, line
        btn:SetScript("OnClick", function() SelectTab(cat) end)
        tabButtons[i] = btn
    end

    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -54)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -54)
    sep:SetHeight(1)
    UI.ApplySeparator(sep)

    -- Colonne gauche : liste + bouton nouvelle compétence
    local newBtn = UI.CreatePanelButton(panel, LIST_W, 22, "+ Nouvelle")
    newBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -62)
    newBtn:SetScript("OnClick", function() ClearForm(); ShowStatus("") end)

    listViewport = CreateFrame("ScrollFrame", nil, panel)
    listViewport:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -6)
    listViewport:SetSize(LIST_W, PANEL_H - 62 - 22 - 6 - 12)
    listViewport:EnableMouseWheel(true)
    listViewport:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 22)))
    end)
    listContent = CreateFrame("Frame", nil, listViewport)
    listContent:SetSize(LIST_W, 1)
    listViewport:SetScrollChild(listContent)

    local vsep = panel:CreateTexture(nil, "ARTWORK")
    vsep:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + LIST_W + 8, -62)
    vsep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10 + LIST_W + 8, 10)
    vsep:SetWidth(1)
    UI.ApplySeparator(vsep)

    -- Colonne droite : formulaire
    local formX = 10 + LIST_W + 8 + 10
    local formW = PANEL_W - formX - 10

    local nameLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -66)
    nameLbl:SetText("Nom"); UI.ApplyLabel(nameLbl)
    nameEB = UI.CreateStyledEditBox(panel, formW, 22)
    nameEB:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -82)

    local iconLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    iconLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -110)
    iconLbl:SetText("Icône — clique l'aperçu pour choisir"); UI.ApplyLabel(iconLbl)
    -- L'aperçu est un vrai bouton : clic = ouvre la grille d'icônes de
    -- Blizzard (GetMacroIcons), pas une saisie de chemin à la main.
    iconPreview = CreateFrame("Button", nil, panel)
    iconPreview:SetSize(22, 22)
    iconPreview:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -126)
    local iconPreviewTex = iconPreview:CreateTexture(nil, "ARTWORK")
    iconPreviewTex:SetAllPoints(); iconPreviewTex:SetTexCoord(.08, .92, .08, .92)
    iconPreview.tex = iconPreviewTex
    local iconPreviewHl = iconPreview:CreateTexture(nil, "HIGHLIGHT")
    iconPreviewHl:SetAllPoints(); iconPreviewHl:SetColorTexture(1, 1, 1, .3)
    iconPreview:SetScript("OnClick", function()
        local picker = BuildIconPicker()
        picker:Show()
        picker.Layout("")
    end)
    iconEB = UI.CreateStyledEditBox(panel, formW - 28, 22)
    iconEB:SetPoint("LEFT", iconPreview, "RIGHT", 6, 0)
    iconEB:SetScript("OnTextChanged", function(self) iconPreview.tex:SetTexture(C:ResolveIconValue(self:GetText())) end)

    local descLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -156)
    descLbl:SetText("Description"); UI.ApplyLabel(descLbl)
    descEB = UI.CreateStyledEditBox(panel, formW, 150, true)
    descEB:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -172)
    descEB:SetMaxLetters(2000)
    descEB:SetScript("OnTextChanged", function(self) descPreview:SetText(C:RenderSkillText(self:GetText())) end)

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -328)
    legend:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    legend:SetJustifyH("LEFT"); legend:SetWordWrap(true)
    legend:SetText("Couleurs : {{rouge}}texte{{/}} (" .. table.concat(COLOR_ORDER, ", ") ..
        ").  Référence : {{Offensive : Nom}}, {{Défensive : Nom}}, {{Distance : Nom}}, {{Action : Nom}}.")
    UI.ApplyMutedText(legend)

    local previewLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -366)
    previewLbl:SetText("Aperçu"); UI.ApplyLabel(previewLbl)
    descPreview = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descPreview:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -382)
    descPreview:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    descPreview:SetJustifyH("LEFT"); descPreview:SetWordWrap(true)
    UI.ApplyBodyText(descPreview)

    local saveBtn = UI.CreatePanelButton(panel, 90, 22, "Enregistrer")
    saveBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", formX, 10)
    saveBtn:SetScript("OnClick", function()
        local ok, err = C:SaveSkill(activeCat.key, editingName, nameEB:GetText(), iconEB:GetText(), descEB:GetText())
        if ok then
            ShowStatus("Enregistré")
            editingName = nameEB:GetText():match("^%s*(.-)%s*$")
            RefreshList()
        else
            ShowStatus(err, true)
        end
    end)

    local deleteBtn = UI.CreatePanelButton(panel, 90, 22, "Supprimer")
    deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    deleteBtn:SetScript("OnClick", function()
        if not editingName then ShowStatus("Rien à supprimer", true); return end
        C:DeleteSkill(activeCat.key, editingName)
        ClearForm()
        RefreshList()
        ShowStatus("Supprimé")
    end)

    statusFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("LEFT", deleteBtn, "RIGHT", 10, 0)
    UI.ApplyMutedText(statusFS)

    return panel
end

function C:ToggleSkillsBuilder()
    Build()
    if panel:IsShown() then
        panel:Hide()
    else
        SelectTab(CATEGORIES[1])
        panel:Show()
    end
end
