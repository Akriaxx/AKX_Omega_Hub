-- ============================================================
--  Character - Base de données de compétences
--  4 catégories (Actions de base / Offensive / Défensive /
--  Distance) + Index (hors du bouton Action), éditables via un builder (Paramètres -> Base de
--  données). Chaque compétence : nom, icône, description. Nom et
--  description acceptent la couleur [[#rrggbb]]...[[/]] ; la
--  description, des références croisées {{Catégorie : Nom}} qui
--  ouvrent la carte liée au survol, partout où une description
--  est affichée (builder, bouton Action).
-- ============================================================
local C = Character
local UI = C.RPGUI or OS2.UI

C.SKILL_CATEGORIES = {
    { key = "base",      label = "Actions de base",       tag = "Action",    aliases = { "action" } },
    { key = "offensive", label = "Compétence Offensive",  tag = "Offensive", aliases = { "offensive" } },
    { key = "defensive", label = "Compétence Défensive",  tag = "Défensive", aliases = { "defensive", "défensive" } },
    { key = "ranged",    label = "Compétence à Distance", tag = "Distance",  aliases = { "distance" } },
    -- Index : fiches consultables par référence {{Index : Nom}} et dans le
    -- builder, mais sans bouton dans le triangle du bouton Action.
    { key = "index",     label = "Index",                 tag = "Index",     aliases = { "index" }, hidden = true },
}
local CATEGORIES = C.SKILL_CATEGORIES

local COLOR_TAGS = {
    rouge  = "ffe23c3c", bleu   = "ff3ca0e2", vert  = "ff3ce26b", jaune = "ffe2d33c",
    violet = "ffb03ce2", orange = "ffe27a3c", blanc = "ffffffff", gris  = "ffa0a0a0",
    ["or"] = "ffffd100",
}

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

local selectedOwner
local function GetOwnedSkillDB()
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

local function GetSkillDB()
    if selectedOwner then
        local stores=CharacterDB.skillLibraries or {}
        local library=stores[selectedOwner]
        if library then return library.categories end
        selectedOwner=nil
    end
    return GetOwnedSkillDB()
end
function C:GetOwnedSkillLibrary() return GetOwnedSkillDB() end
function C:IsSkillLibraryReadOnly() return selectedOwner~=nil end
function C:GetSkillLibraryOwner() return selectedOwner end

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
    if selectedOwner then return false,"Lecture seule : seul le créateur peut modifier" end
    if not FindCategory(catKey) then return false, "Catégorie inconnue" end
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return false, "Nom requis" end
    if #name>128 or #tostring(icon or "")>512 or #tostring(description or "")>8000 then return false,"Texte trop long" end
    local db = GetSkillDB()
    if db[catKey][name] and oldName ~= name then return false, "Ce nom existe déjà dans cette catégorie" end
    if oldName and oldName ~= name then db[catKey][oldName] = nil end
    db[catKey][name] = {
        name = name,
        icon = (icon and icon ~= "") and icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        description = description or "",
    }
    if self.OnSkillsChanged then self.OnSkillsChanged() end
    return true
end

function C:DeleteSkill(catKey, name)
    if selectedOwner then return false,"Lecture seule : seul le créateur peut supprimer" end
    local db = GetSkillDB()
    if db[catKey] then db[catKey][name] = nil end
    if self.OnSkillsChanged then self.OnSkillsChanged() end
end

-- ── Rendu du texte : couleurs + références croisées ─────────────────────────
-- [[#ff8800]]texte[[/]] -> code couleur WoW, dans le nom comme dans la
-- description. {{rouge}}texte{{/}} reste rendu pour les anciens textes.
-- {{Catégorie : Nom}} -> lien survolable vers une autre compétence ; le
-- nom s'y écrit sans ses balises de couleur.
local function RenderColors(text)
    text = text:gsub("%[%[%s*#(%x%x%x%x%x%x)%s*%]%](.-)%[%[/%]%]", function(hex, inner)
        return "|cff" .. hex .. inner .. "|r"
    end)
    return (text:gsub("{{%s*(%a+)%s*}}(.-){{/}}", function(colorName, inner)
        local hex = COLOR_TAGS[colorName:lower()]
        if not hex then return "{{" .. colorName .. "}}" .. inner .. "{{/}}" end
        return "|c" .. hex .. inner .. "|r"
    end))
end

function C:StripSkillColors(text)
    return (tostring(text or ""):gsub("%[%[%s*#%x%x%x%x%x%x%s*%]%]", ""):gsub("%[%[/%]%]", ""))
end

-- Toutes les balises de mise en forme retirées (couleurs comprises).
function C:StripSkillMarkup(text)
    return self.RichText.Strip(text)
end

-- Nom sur une seule FontString (titres, listes) : couleurs rendues, les
-- autres balises (gras, taille…) retirées faute de pouvoir les afficher.
function C:RenderSkillName(name)
    return self.RichText.Strip(RenderColors(tostring(name or "")))
end

-- Options du moteur de texte enrichi : références et anciennes couleurs.
local skillTextOptions
function C:SkillTextOptions()
    skillTextOptions = skillTextOptions or {
        namedColors = COLOR_TAGS,
        resolveRef = function(tag, name)
            local cat = ResolveCategoryByTag(tag)
            if not cat then return end
            return cat.key, C:FindSkillRef(cat.key, name)
        end,
    }
    return skillTextOptions
end

-- Retrouve une compétence par son nom affiché (balises de couleur ignorées).
function C:FindSkillRef(catKey, name)
    local skill = self:GetSkill(catKey, name)
    if skill then return skill end
    name = self:StripSkillMarkup(name):lower()
    for _, candidate in ipairs(self:ListSkills(catKey)) do
        if self:StripSkillMarkup(candidate.name):lower() == name then return candidate end
    end
end

function C:RenderSkillText(text)
    text = RenderColors(tostring(text or ""))
    text = text:gsub("{{%s*([^:{}]-)%s*:%s*([^{}]-)%s*}}", function(tag, name)
        local cat = ResolveCategoryByTag(tag)
        if not cat then return "{{" .. tag .. " : " .. name .. "}}" end
        -- Le lien reprend la couleur du nom en base s'il en a une (la
        -- première, crochets compris), sinon le bleu des liens.
        local skill = C:FindSkillRef(cat.key, name)
        local hex = skill and tostring(skill.name):match("%[%[%s*#(%x%x%x%x%x%x)%s*%]%]")
        if hex then
            local color = "|cff" .. hex
            -- Chaque |c doit avoir son |r : le client empile les couleurs, et
            -- une couleur non refermée teinterait tout le texte qui suit.
            return "|Hcharskill:" .. cat.key .. ":" .. name .. "|h" .. color .. "[|r" .. RenderColors(skill.name) .. color .. "]|r|h"
        end
        return "|Hcharskill:" .. cat.key .. ":" .. name .. "|h|cff8fd6ff[" .. name .. "]|r|h"
    end)
    return text
end

-- ── Cartes de compétence (infobulles) ───────────────────────────────────────
-- Cadres propres au module plutôt que GameTooltip : même habillage que les
-- fenêtres Character (fond sombre, bandeau bronze pour le nom), et les
-- liens |Hcharskill:..|h de la description réagissent au survol.
-- Survoler une référence ouvre la carte suivante À CÔTÉ de la précédente,
-- un niveau au-dessus ; elle reste ouverte tant que la souris est sur le
-- lien ou sur elle, ce qui permet de suivre une référence dans une référence.
local CARD_MIN_W, CARD_MAX_W, CARD_PAD, CARD_HEAD = 150, 300, 8, 22
local MAX_CARDS = 5
local cards = {}
local ShowCard

local function CheckCards()
    for depth = #cards, 2, -1 do
        local card = cards[depth]
        local deeper = cards[depth + 1]
        if card:IsShown() and not card.linkHovered and not card:IsMouseOver()
            and not (deeper and deeper:IsShown()) then
            card:Hide()
        end
    end
end

local function OnSkillLinkEnter(self, link)
    local kind, catKey, name = link:match("^(%a+):([^:]+):(.+)$")
    if kind ~= "charskill" then return end
    local depth = (self.cardDepth or 1) + 1
    if depth > MAX_CARDS then return end
    local skill = C:FindSkillRef(catKey, name)
    ShowCard(depth, self, skill or { name = name, missing = true })
    cards[depth].linkHovered = true
end

local function OnSkillLinkLeave(self)
    local card = cards[(self.cardDepth or 1) + 1]
    if card then card.linkHovered = false end
    C_Timer.After(.15, CheckCards)
end

-- depth = profondeur de la carte que ce cadre représente (l'aperçu du
-- builder vaut 1 : ses références ouvrent la carte 2).
function C:EnableSkillLinks(frame, depth)
    frame.cardDepth = depth or frame.cardDepth or 1
    frame:EnableMouse(true)
    if frame.SetHyperlinksEnabled then frame:SetHyperlinksEnabled(true) end
    frame:SetScript("OnHyperlinkEnter", OnSkillLinkEnter)
    frame:SetScript("OnHyperlinkLeave", OnSkillLinkLeave)
end

local function GetCard(depth)
    if cards[depth] then return cards[depth] end
    local card = CreateFrame("Frame", "CharacterSkillCard" .. depth, UIParent)
    card:SetFrameStrata("TOOLTIP")
    card:SetClampedToScreen(true)
    card:Hide()
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); UI.ApplyWindowBackground(bg, .97)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOPLEFT", CARD_PAD, -4)
    card.title:SetJustifyH("LEFT"); card.title:SetWordWrap(false)
    UI.ApplyTitle(card.title)
    -- Corps : texte enrichi (C.RichText), blanc par défaut, posé dans la carte.
    C:EnableSkillLinks(card, depth)
    card:SetScript("OnHide", function()
        card.linkHovered = false
        if cards[depth + 1] then cards[depth + 1]:Hide() end
    end)
    if depth > 1 then card:SetScript("OnLeave", function() C_Timer.After(.15, CheckCards) end) end
    cards[depth] = card
    return card
end

local function TextWidth(fs)
    return fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
end

function ShowCard(depth, anchor, skill)
    local card = GetCard(depth)
    if cards[depth + 1] then cards[depth + 1]:Hide() end
    card.title:SetText(C:RenderSkillName(skill.name))
    local body
    if skill.missing then
        card.title:SetTextColor(1, .35, .3)
        body = "Compétence introuvable dans cette bibliothèque."
    else
        UI.ApplyTitle(card.title)
        body = skill.description or ""
    end
    local RT, opts = C.RichText, C:SkillTextOptions()
    local bodyWidth = RT.Measure(card, body, CARD_MAX_W - CARD_PAD * 2, opts)
    local inner = math.max(TextWidth(card.title), bodyWidth)
    local width = math.max(CARD_MIN_W, math.min(CARD_MAX_W, inner + CARD_PAD * 2))
    card.title:SetWidth(width - CARD_PAD * 2)
    local _, bodyHeight = RT.Render(card, body, width - CARD_PAD * 2, opts, CARD_PAD, CARD_HEAD + 6)
    card:SetSize(width, body ~= "" and (CARD_HEAD + 12 + bodyHeight) or CARD_HEAD + 2)

    -- Toujours au-dessus de la carte / du cadre qui l'ouvre.
    card:SetFrameLevel((anchor:GetFrameLevel() or 0) + 20)
    card:ClearAllPoints()
    if depth == 1 then
        card:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    else
        local right = anchor:GetRight() or 0
        local screen = UIParent:GetRight() or 0
        if right + 6 + width <= screen then
            card:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 0)
        else
            card:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 0)
        end
    end
    card:Show()
    return card
end

function C:ShowSkillTooltip(owner, skill)
    GameTooltip:Hide()
    ShowCard(1, owner, skill)
end

function C:HideSkillTooltip() if cards[1] then cards[1]:Hide() end end

-- Survol d'un bouton de compétence : juste le nom, même habillage.
local nameTip
function C:ShowSkillName(owner, skill)
    if not nameTip then
        nameTip = CreateFrame("Frame", "CharacterSkillNameTip", UIParent)
        nameTip:SetFrameStrata("TOOLTIP"); nameTip:SetClampedToScreen(true)
        local bg = nameTip:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(); UI.ApplyWindowBackground(bg, .97)
        nameTip.title = nameTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameTip.title:SetPoint("LEFT", CARD_PAD, 0); nameTip.title:SetWordWrap(false)
        UI.ApplyTitle(nameTip.title)
    end
    GameTooltip:Hide()
    nameTip.title:SetText(C:RenderSkillName(skill.name))
    nameTip:SetSize(math.min(CARD_MAX_W, TextWidth(nameTip.title) + CARD_PAD * 2), CARD_HEAD + 2)
    nameTip:SetFrameLevel((owner:GetFrameLevel() or 0) + 40)
    nameTip:ClearAllPoints(); nameTip:SetPoint("BOTTOM", owner, "TOP", 0, 6)
    nameTip:Show()
end

function C:HideSkillName() if nameTip then nameTip:Hide() end end

-- ============================================================
--  Builder : Paramètres -> Base de données
-- ============================================================
local PANEL_W, PANEL_H = 660, 592
local LIST_W = 196

local panel, tabButtons, listContent, listViewport
local nameEB, iconEB, iconPreview, descEB, descPreview, statusFS, colorTarget
local searchEB, listCount, descViewport, previewViewport
local saveControl,deleteControl
local pendingDelete
local activeCat, editingName
local RefreshList, RefreshForm

local function ClearForm()
    editingName = nil
    pendingDelete=nil
    nameEB:SetText("")
    iconEB:SetText("")
    descEB:SetText("")
    iconPreview.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    if descViewport then descViewport:SetVerticalScroll(0) end
    if previewViewport then previewViewport:SetVerticalScroll(0) end
end

local function LoadIntoForm(skill)
    editingName = skill.name
    pendingDelete=nil
    if descViewport then descViewport:SetVerticalScroll(0) end
    if previewViewport then previewViewport:SetVerticalScroll(0) end
    nameEB:SetText(skill.name)
    iconEB:SetText(skill.icon or "")
    descEB:SetText(skill.description or "")
    iconPreview.tex:SetTexture(C:ResolveIconValue(skill.icon))
end

local function ShowStatus(text, isError)
    statusFS:SetText(text or "")
    statusFS:SetTextColor(isError and 1 or .6, isError and .3 or .9, isError and .3 or .5)
end

local skillRows = {}
local function MakeSkillRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(32)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(unpack(UI.colors.rowBg))
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24); icon:SetPoint("LEFT", 3, 0)
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
    local all=C:ListSkills(activeCat.key)
    local filter=searchEB and searchEB:GetText():lower() or ""
    local skills={}
    for _,skill in ipairs(all) do if filter=="" or C:StripSkillMarkup(skill.name):lower():find(filter,1,true) then skills[#skills+1]=skill end end
    if listCount then listCount:SetText(#skills.." / "..#all.." compétences") end
    for i, skill in ipairs(skills) do
        local row = skillRows[i]
        if not row then row = MakeSkillRow(listContent); skillRows[i] = row end
        row.skill = skill
        row.icon:SetTexture(C:ResolveIconValue(skill.icon))
        row.text:SetText(C:RenderSkillName(skill.name))
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * 34)
        row:SetWidth(LIST_W)
        row:Show()
    end
    for i = #skills + 1, #skillRows do skillRows[i]:Hide() end
    listContent:SetHeight(math.max(1, #skills * 34))
    listViewport:SetVerticalScroll(math.min(listViewport:GetVerticalScroll(),listViewport:GetVerticalScrollRange()))
end

function RefreshForm()
    ClearForm()
end

local function SelectTab(cat)
    activeCat = cat
    pendingDelete=nil
    if searchEB then searchEB:SetText("") end
    for _, btn in ipairs(tabButtons) do UI.ApplyTabState(btn, btn.cat == cat) end
    RefreshList()
    RefreshForm()
    ShowStatus("")
end

-- ── Sélecteur d'icônes : grille de la banque LibRPMedia (comme Spell),
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
    viewport:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -22, 12)
    viewport:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(COLS * CELL, 1)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * CELL)))
    end)

    -- Même banque que le navigateur d'icônes de Spell : LibRPMedia (fournie
    -- par EpsilonLib / SpellCreator), qui inclut les icônes custom Epsilon
    -- (bg3_, lol_…). GetMacroIcons() ne connaît que celles de Blizzard :
    -- il ne sert plus que de secours si la bibliothèque est absente.
    local allIcons = {}
    local LibRPM = LibStub and LibStub:GetLibrary("LibRPMedia-1.0", true)
    if LibRPM and LibRPM.FindAllIcons then
        -- La base a des index sans nom : on les saute.
        for _, name in LibRPM:FindAllIcons() do
            if type(name) ~= "string" or name == "" then
                -- entrée vide
            elseif name:find("Interface", 1, true) then
                allIcons[#allIcons + 1] = name
            elseif name:find("AddOns", 1, true) then
                allIcons[#allIcons + 1] = "Interface/" .. name
            else
                allIcons[#allIcons + 1] = "Interface/Icons/" .. name
            end
        end
    end
    if #allIcons == 0 and GetMacroIcons then
        -- GetMacroIcons() renvoie les icônes en valeurs multiples (pas une table).
        allIcons = { GetMacroIcons() }
        if type(allIcons[1])=="table" then allIcons=allIcons[1] end
    end
    local cells = {}
    local filtered={}
    local function RenderVisible()
        GameTooltip:Hide()
        local firstRow=math.floor(viewport:GetVerticalScroll()/CELL)
        local rowCount=math.ceil(viewport:GetHeight()/CELL)+1
        local shown=0
        for index=firstRow*COLS+1,math.min(#filtered,(firstRow+rowCount)*COLS) do
            local value=filtered[index]
            shown=shown+1
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
                local col, rowIdx = (index - 1) % COLS, math.floor((index - 1) / COLS)
                cell:SetPoint("TOPLEFT", content, "TOPLEFT", col * CELL, -rowIdx * CELL)
                cell:Show()
        end
        for i = shown + 1, #cells do cells[i]:Hide() end
    end
    local function Layout(filter)
        filter=(filter or ""):lower()
        filtered={}
        for _,value in ipairs(allIcons) do
            if filter=="" or tostring(value):lower():find(filter,1,true) then filtered[#filtered+1]=value end
        end
        content:SetHeight(math.max(1,math.ceil(#filtered/COLS)*CELL))
        viewport:SetVerticalScroll(0)
        RenderVisible()
    end
    viewport:SetScript("OnVerticalScroll",RenderVisible)
    viewport:SetScript("OnSizeChanged",RenderVisible)
    viewport:SetScript("OnMouseWheel",function(self,delta)
        self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*CELL)))
        RenderVisible()
    end)
    searchEB:SetScript("OnTextChanged",function(self) Layout(self:GetText()) end)
    p.Layout = Layout

    iconPicker = p
    return p
end

-- ── Autocomplétion des références dans la description ──────────────────────
-- "{{Act" propose les catégories ; "{{Action : " (ou "{{Action:") propose
-- les compétences de la catégorie, filtrées par ce qui est tapé après les
-- deux-points. Clic ou Tab insère "{{Action : Nom}}". Échap ferme la liste.
local AC_ROWS, AC_ROW_H, AC_W = 8, 22, 240
local autocomplete

local function MatchesTag(cat, typed)
    typed = typed:lower()
    if typed == "" then return true end
    if cat.tag:lower():sub(1, #typed) == typed then return true end
    for _, alias in ipairs(cat.aliases) do
        if alias:sub(1, #typed) == typed then return true end
    end
end

-- Ce qui précède le curseur depuis le dernier "{{" encore ouvert, ou nil.
local function ReadRefContext(editBox)
    local text = editBox:GetText()
    local cursor = editBox:GetCursorPosition()
    local before = text:sub(1, cursor)
    local start = before:match(".*(){{")
    if not start then return end
    local fragment = before:sub(start + 2)
    if fragment:find("[{}\n]") then return end
    local tag, partial = fragment:match("^%s*([^:]-)%s*:%s*(.*)$")
    if tag then
        local cat = ResolveCategoryByTag(tag)
        if not cat then return end
        return { start = start, cursor = cursor, cat = cat, partial = partial }
    end
    return { start = start, cursor = cursor, partial = fragment:match("^%s*(.*)$") }
end

local function BuildAutocomplete(editBox, owner)
    local ac = CreateFrame("Frame", nil, owner)
    ac:SetFrameStrata("FULLSCREEN_DIALOG")
    ac:SetFrameLevel(owner:GetFrameLevel() + 50)
    ac:SetWidth(AC_W)
    ac:EnableMouse(true)
    ac:Hide()
    local bg = ac:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); UI.ApplyWindowBackground(bg, 0.98)
    UI.ApplyBorder(ac)

    local rows, entries, selected = {}, {}, 1
    local context, cursorX, cursorY, cursorH, dismissedStart = nil, 0, 0, 14, nil

    local function Paint()
        for i, row in ipairs(rows) do
            row.bg:SetColorTexture(unpack(i == selected and UI.colors.rowBgSelected or UI.colors.rowBg))
        end
    end

    local function Accept(entry)
        if not context or not entry then return end
        local text = editBox:GetText()
        local after = text:sub(context.cursor + 1)
        local insert
        if entry.skill then
            insert = "{{" .. context.cat.tag .. " : " .. C:StripSkillMarkup(entry.skill.name) .. "}}"
            -- Remplace aussi la fin d'une référence déjà fermée ("...Nom}}").
            local tail = after:match("^[^{}\n]*}}")
            if tail then after = after:sub(#tail + 1) end
        else
            insert = "{{" .. entry.cat.tag .. " : "
        end
        local head = text:sub(1, context.start - 1) .. insert
        editBox:SetText(head .. after)
        editBox:SetCursorPosition(#head)
        editBox:SetFocus()
        ac.Refresh()
    end

    for i = 1, AC_ROWS do
        local row = CreateFrame("Button", nil, ac)
        row:SetHeight(AC_ROW_H)
        row:SetPoint("TOPLEFT", ac, "TOPLEFT", 3, -3 - (i - 1) * AC_ROW_H)
        row:SetPoint("RIGHT", ac, "RIGHT", -3, 0)
        row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18); row.icon:SetPoint("LEFT", 2, 0)
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.text:SetPoint("LEFT", row.icon, "RIGHT", 5, 0); row.text:SetPoint("RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
        UI.ApplyBodyText(row.text)
        row:SetScript("OnEnter", function() selected = i; Paint() end)
        row:SetScript("OnClick", function() Accept(entries[i]) end)
        rows[i] = row
    end

    local function Collect()
        local list = {}
        local partial = context.partial:lower()
        if context.cat then
            for _, skill in ipairs(C:ListSkills(context.cat.key)) do
                if partial == "" or C:StripSkillMarkup(skill.name):lower():find(partial, 1, true) then
                    list[#list + 1] = { skill = skill }
                end
            end
        else
            for _, cat in ipairs(CATEGORIES) do
                if MatchesTag(cat, partial) then list[#list + 1] = { cat = cat } end
            end
        end
        return list
    end

    function ac.Refresh()
        context = editBox:HasFocus() and ReadRefContext(editBox) or nil
        if not context or context.start ~= dismissedStart then dismissedStart = nil end
        entries = context and not dismissedStart and Collect() or {}
        if #entries == 0 then ac:Hide(); return end
        if selected > math.min(#entries, AC_ROWS) then selected = 1 end
        for i, row in ipairs(rows) do
            local entry = entries[i]
            if entry then
                if entry.skill then
                    row.icon:SetTexture(C:ResolveIconValue(entry.skill.icon))
                    row.text:SetText(C:RenderSkillName(entry.skill.name))
                else
                    row.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
                    row.text:SetText(entry.cat.tag .. "  |cff808080" .. entry.cat.label .. "|r")
                end
                row:Show()
            else
                row:Hide()
            end
        end
        ac:SetHeight(6 + math.min(#entries, AC_ROWS) * AC_ROW_H)
        ac:ClearAllPoints()
        ac:SetPoint("TOPLEFT", editBox, "TOPLEFT", math.min(cursorX, editBox:GetWidth() - AC_W), cursorY - cursorH - 2)
        Paint()
        ac:Show()
    end

    function ac.SetCursor(x, y, h) cursorX, cursorY, cursorH = x or 0, y or 0, h or 14 end
    function ac.Dismiss() dismissedStart = context and context.start; ac:Hide() end
    function ac.AcceptSelected() Accept(entries[selected]) end
    return ac
end

-- ── Sélecteur de couleur (outils Couleur et Surligner) ────────────────────
local PLACEHOLDER = "TEXTE"
local lastColor = { r = 1, g = .82, b = 0 }
local lastBg = { r = .55, g = .40, b = .10 }
local toolbarSwatches = {}
local colorSession

local function ToHex(value) return math.floor(math.max(0, math.min(1, value)) * 255 + .5) end

local function FinishColorSession()
    local session = colorSession
    colorSession = nil
    ColorPickerFrame:SetFrameStrata(session.strata)
    ColorPickerFrame:SetFrameLevel(session.level)
    if session.cancelled then return end
    local r, g, b = ColorPickerFrame:GetColorRGB()
    local last = session.kind == "fond" and lastBg or lastColor
    last.r, last.g, last.b = r, g, b
    for kind, swatch in pairs(toolbarSwatches) do
        local c = kind == "fond" and lastBg or lastColor
        swatch:SetColorTexture(c.r, c.g, c.b)
    end
    -- Applique à la sélection mémorisée au clic, seulement si le texte
    -- n'a pas changé entre-temps.
    if session.editBox:GetText() == session.text then
        session.onPick(("%02x%02x%02x"):format(ToHex(r), ToHex(g), ToHex(b)))
    end
end

-- pick = { text, kind = "couleur"|"fond", onPick(hex) }
local function OpenColorPicker(editBox, pick)
    if not ColorPickerFrame then return end
    if not ColorPickerFrame.characterSkillsHooked then
        ColorPickerFrame.characterSkillsHooked = true
        ColorPickerFrame:HookScript("OnHide", function() if colorSession then FinishColorSession() end end)
    end
    if colorSession then colorSession.cancelled = true; FinishColorSession() end
    colorSession = {
        editBox = editBox, text = pick.text, kind = pick.kind, onPick = pick.onPick,
        strata = ColorPickerFrame:GetFrameStrata(), level = ColorPickerFrame:GetFrameLevel(),
    }
    local session = colorSession
    local start = session.kind == "fond" and lastBg or lastColor
    local function Cancel() session.cancelled = true end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = start.r, g = start.g, b = start.b,
            swatchFunc = function() end, cancelFunc = Cancel,
        })
    else
        -- Client Epsilon (9.2.7) : ancienne API du sélecteur.
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.func = function() end
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.cancelFunc = Cancel
        ColorPickerFrame.previousValues = { r = start.r, g = start.g, b = start.b }
        ColorPickerFrame:SetColorRGB(start.r, start.g, start.b)
        ShowUIPanel(ColorPickerFrame)
    end
    -- Le builder est en FULLSCREEN_DIALOG : sans ça le sélecteur passe derrière.
    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:SetFrameLevel((panel and panel:GetFrameLevel() or 0) + 100)
    ColorPickerFrame:Raise()
end

-- Une EditBox WoW n'expose pas sa sélection : Insert("") l'efface, et la
-- différence avec le texte d'avant donne ses bornes. On restaure ensuite
-- le texte et la sélection (même astuce que l'éditeur HTML d'Arcanum).
local function GetSelection(editBox)
    local text, cursor = editBox:GetText(), editBox:GetCursorPosition()
    editBox:Insert("")
    local after, afterCursor = editBox:GetText(), editBox:GetCursorPosition()
    if after == text then return cursor, cursor, text end
    editBox:SetText(text)
    editBox:SetCursorPosition(cursor)
    local start, stop = afterCursor, #text - (#after - afterCursor)
    editBox:HighlightText(start, stop)
    return start, stop, text
end

-- ── Barre d'outils de la description ───────────────────────────────────────
-- Chaque outil lit la sélection, pose ses balises autour et resélectionne
-- le texte. Sans sélection, "TEXTE" est inséré au curseur, sélectionné.
local function Esc(text) return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

local function Select(editBox, text, from, to)
    editBox:SetText(text)
    editBox:SetFocus()
    editBox:SetCursorPosition(to)
    editBox:HighlightText(from, to)
end

-- kind = { open = motif Lua d'une balise ouvrante, close = balise fermante }.
-- Remplace la balise du même type qui encadre directement la sélection,
-- sinon retire celles du même type à l'intérieur et encadre.
local function ApplyWrap(editBox, sel, kind, open)
    local start, stop, text = sel.start, sel.stop, sel.text
    local inner = text:sub(start + 1, stop)
    local before, after = text:sub(1, start), text:sub(stop + 1)
    local head = before:match("^(.-)" .. kind.open .. "$")
    if head and after:sub(1, #kind.close) == kind.close then
        before, after = head, after:sub(#kind.close + 1)
    end
    inner = inner:gsub(kind.open, ""):gsub(Esc(kind.close), "")
    if inner == "" then inner = PLACEHOLDER end
    if not open then
        Select(editBox, before .. inner .. after, #before, #before + #inner)
        return
    end
    Select(editBox, before .. open .. inner .. kind.close .. after, #before + #open, #before + #open + #inner)
end

local KINDS = {
    b = { open = "%[%[b%]%]", close = "[[/b]]" },
    i = { open = "%[%[i%]%]", close = "[[/i]]" },
    u = { open = "%[%[u%]%]", close = "[[/u]]" },
    s = { open = "%[%[s%]%]", close = "[[/s]]" },
    couleur = { open = "%[%[%s*#%x%x%x%x%x%x%s*%]%]", close = "[[/]]" },
    fond = { open = "%[%[fond%s*#%x%x%x%x%x%x%]%]", close = "[[/fond]]" },
    taille = { open = "%[%[taille%s+%d+%]%]", close = "[[/taille]]" },
    police = { open = "%[%[police%s+%w+%]%]", close = "[[/police]]" },
}

-- Gras / italique / souligné / barré : bascule. Si la sélection est déjà
-- encadrée (ou contient ses propres balises aux deux bouts), on les retire.
local function ToggleStyle(editBox, key)
    local start, stop, text = GetSelection(editBox)
    local kind, open = KINDS[key], "[[" .. key .. "]]"
    local inner = text:sub(start + 1, stop)
    local enclosed = text:sub(1, start):sub(-#open) == open and text:sub(stop + 1, stop + #kind.close) == kind.close
    local contains = inner:sub(1, #open) == open and inner:sub(-#kind.close) == kind.close
    if contains then
        inner = inner:sub(#open + 1, -#kind.close - 1)
        Select(editBox, text:sub(1, start) .. inner .. text:sub(stop + 1), start, start + #inner)
    else
        ApplyWrap(editBox, { start = start, stop = stop, text = text }, kind, not enclosed and open or nil)
    end
end

local function PickColor(editBox, key)
    local start, stop, text = GetSelection(editBox)
    local sel = { start = start, stop = stop, text = text }
    OpenColorPicker(editBox, { text = text, kind = key, onPick = function(hex)
        ApplyWrap(editBox, sel, KINDS[key], key == "fond" and ("[[fond #" .. hex .. "]]") or ("[[#" .. hex .. "]]"))
    end })
end

-- Taille : +/- 1 sur la taille qui encadre la sélection (12 par défaut).
local function StepSize(editBox, delta)
    local start, stop, text = GetSelection(editBox)
    local current = tonumber(text:sub(1, start):match("%[%[taille%s+(%d+)%]%]$") or "") or C.RichText.DEFAULT_SIZE
    local size = math.max(C.RichText.MIN_SIZE, math.min(C.RichText.MAX_SIZE, current + delta))
    ApplyWrap(editBox, { start = start, stop = stop, text = text }, KINDS.taille,
        size ~= C.RichText.DEFAULT_SIZE and ("[[taille " .. size .. "]]") or nil)
    return size
end

local function SetFontFor(editBox, sel, fontKey)
    ApplyWrap(editBox, sel, KINDS.police, fontKey ~= C.RichText.DEFAULT_FONT and ("[[police " .. fontKey .. "]]") or nil)
end

-- Alignement : balise en tête de chaque ligne touchée par la sélection.
local function SetAlign(editBox, align)
    local start, stop, text = GetSelection(editBox)
    local out, pos, from, to = {}, 1, nil, nil
    while pos <= #text + 1 do
        local lineEnd = text:find("\n", pos, true) or (#text + 1)
        local line = text:sub(pos, lineEnd - 1)
        local lineStart0 = pos - 1
        if lineEnd - 1 >= start and lineStart0 <= stop then
            local changed = true
            while changed do
                changed = false
                for _, tag in ipairs({ "centre", "droite", "gauche" }) do
                    local rest = line:match("^%[%[" .. tag .. "%]%](.*)$")
                    if rest then line, changed = rest, true end
                end
            end
            if align ~= "gauche" then line = "[[" .. align .. "]]" .. line end
            local offset = #table.concat(out)
            from = from or offset
            to = offset + #line
        end
        out[#out + 1] = line
        if lineEnd > #text then break end
        out[#out + 1] = "\n"
        pos = lineEnd + 1
    end
    local result = table.concat(out)
    Select(editBox, result, from or 0, to or 0)
end

-- Efface toute mise en forme de la sélection, balises qui l'encadrent
-- directement comprises.
local function ClearFormatting(editBox)
    local start, stop, text = GetSelection(editBox)
    if start == stop then return end
    local before, after = text:sub(1, start), text:sub(stop + 1)
    local stripped = true
    while stripped do
        stripped = false
        local head, tag = before:match("^(.-)%[%[([^%[%]\n]-)%]%]$")
        local closeTag, tail = after:match("^%[%[(/[^%[%]\n]-)%]%](.*)$")
        if head and closeTag and C.RichText.Strip("[[" .. tag .. "]]") == "" and C.RichText.Strip("[[" .. closeTag .. "]]") == ""
            and not tag:match("^%s*centre") and not tag:match("^%s*droite") and not tag:match("^%s*gauche") then
            before, after, stripped = head, tail, true
        end
    end
    local plain = C.RichText.Strip(text:sub(start + 1, stop))
    Select(editBox, before .. plain .. after, #before, #before + #plain)
end

local function InsertReference(editBox)
    local _, stop = GetSelection(editBox)
    editBox:SetFocus()
    editBox:SetCursorPosition(stop)
    editBox:Insert("{{")
    if autocomplete then autocomplete.Refresh() end
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
    title:SetText("Bibliothèque de compétences")
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
        label:SetAllPoints(); label:SetJustifyH("CENTER"); label:SetText(cat.tag=="Action" and "Actions de base" or cat.tag)
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
    local ownerBtn=UI.CreatePanelButton(panel,PANEL_W-132,22,"Ma bibliothèque")
    ownerBtn:SetPoint("TOPLEFT",10,-60)
    local sendBtn=UI.CreatePanelButton(panel,102,22,"Envoyer au raid")
    sendBtn:SetPoint("TOPRIGHT",-10,-60)
    local function OwnerLabel()
        ownerBtn:SetText(selectedOwner and ("Bibliothèque : "..selectedOwner.." (lecture seule)  »") or "Bibliothèque : la mienne  »")
        sendBtn:SetEnabled(not selectedOwner)
        if saveControl then saveControl:SetEnabled(not selectedOwner);deleteControl:SetEnabled(not selectedOwner) end
    end
    ownerBtn:SetScript("OnClick",function()
        local owners={false}
        for owner in pairs(CharacterDB.skillLibraries or {}) do owners[#owners+1]=owner end
        table.sort(owners,function(a,b) if a==false then return true elseif b==false then return false else return a<b end end)
        local nextIndex=1
        for i,owner in ipairs(owners) do if owner==(selectedOwner or false) then nextIndex=i%#owners+1;break end end
        selectedOwner=owners[nextIndex] or nil
        OwnerLabel();SelectTab(activeCat)
        if C.OnSkillsChanged then C.OnSkillsChanged() end
    end)
    sendBtn:SetScript("OnClick",function()
        if selectedOwner then return end
        local ok,message=C:SendSkillLibrary()
        ShowStatus(message,not ok)
    end)
    ownerBtn:HookScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Bibliothèque affichée",unpack(UI.colors.title))
        GameTooltip:AddLine("Clic : passer à la bibliothèque suivante (la vôtre, puis celles reçues du raid, par créateur).",1,1,1,true)
        GameTooltip:AddLine("Les bibliothèques reçues sont en lecture seule.",.65,.68,.64,true)
        GameTooltip:Show()
    end)
    ownerBtn:HookScript("OnLeave",function() GameTooltip:Hide() end)
    panel:HookScript("OnShow",OwnerLabel)
    panel:HookScript("OnHide",function() if iconPicker then iconPicker:Hide() end;if autocomplete then autocomplete:Hide() end end)
    local newBtn = UI.CreatePanelButton(panel, LIST_W, 22, "+ Nouvelle")
    newBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -92)
    newBtn:SetScript("OnClick", function() ClearForm(); ShowStatus("") end)

    listViewport = CreateFrame("ScrollFrame", nil, panel)
    searchEB=UI.CreateStyledEditBox(panel,LIST_W,22)
    searchEB:SetPoint("TOPLEFT",newBtn,"BOTTOMLEFT",0,-22)
    local searchLabel=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    searchLabel:SetPoint("BOTTOMLEFT",searchEB,"TOPLEFT",0,3);searchLabel:SetText("Rechercher");UI.ApplyMutedText(searchLabel)
    searchEB:SetScript("OnTextChanged",function() if activeCat and listContent then listViewport:SetVerticalScroll(0);RefreshList() end end)
    listViewport:SetPoint("TOPLEFT",searchEB,"BOTTOMLEFT",0,-8)
    listViewport:SetSize(LIST_W, PANEL_H-198)
    listCount=panel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    listCount:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",10,12);UI.ApplyMutedText(listCount)
    listViewport:EnableMouseWheel(true)
    listViewport:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 22)))
    end)
    listContent = CreateFrame("Frame", nil, listViewport)
    listContent:SetSize(LIST_W, 1)
    listViewport:SetScrollChild(listContent)

    local vsep = panel:CreateTexture(nil, "ARTWORK")
    vsep:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + LIST_W + 8, -92)
    vsep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10 + LIST_W + 8, 10)
    vsep:SetWidth(1)
    UI.ApplySeparator(vsep)

    -- Colonne droite : formulaire
    local formX = 10 + LIST_W + 8 + 10
    local formW = PANEL_W - formX - 10

    local nameLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX + 50, -96)
    nameLbl:SetText("Nom"); UI.ApplyLabel(nameLbl)
    nameEB = UI.CreateStyledEditBox(panel, formW - 50, 24)
    nameEB:SetPoint("TOPLEFT", panel, "TOPLEFT", formX + 50, -112)
    nameEB:SetMaxLetters(128)

    iconPreview = CreateFrame("Button", nil, panel)
    iconPreview:SetSize(40, 40)
    iconPreview:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -96)
    local iconPreviewTex = iconPreview:CreateTexture(nil, "ARTWORK")
    iconPreviewTex:SetAllPoints(); iconPreviewTex:SetTexCoord(.08, .92, .08, .92)
    iconPreview.tex = iconPreviewTex
    local mask=iconPreview:CreateMaskTexture()
    mask:SetAllPoints();mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    iconPreviewTex:AddMaskTexture(mask)
    local rim=iconPreview:CreateTexture(nil,"OVERLAY")
    rim:SetAllPoints();rim:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\InitiativeRing.tga")
    iconPreview:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Choisir une icône");GameTooltip:Show()
    end)
    iconPreview:SetScript("OnLeave",function() GameTooltip:Hide() end)
    local iconPreviewHl = iconPreview:CreateTexture(nil, "HIGHLIGHT")
    iconPreviewHl:SetAllPoints(); iconPreviewHl:SetColorTexture(1, 1, 1, .3)
    iconPreview:SetScript("OnClick", function()
        local picker = BuildIconPicker()
        picker:Show()
        picker.Layout("")
    end)
    -- Keep the icon value private; the circular picker is the only visible control.
    iconEB = CreateFrame("EditBox",nil,panel)
    iconEB:SetAutoFocus(false);iconEB:Hide()
    iconEB:SetScript("OnTextChanged",function(self)
        iconPreview.tex:SetTexture(C:ResolveIconValue(self:GetText()) or "Interface\\Icons\\INV_Misc_QuestionMark")
    end)

    local descLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -150)
    descLbl:SetText("Description"); UI.ApplyLabel(descLbl)
    -- Barre d'outils : agit sur le texte sélectionné dans la description.
    local RT = C.RichText
    local NOTO = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\Fonts\\NotoSans-"
    local toolbar = CreateFrame("Frame", nil, panel)
    toolbar:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -168)
    toolbar:SetSize(formW, 20)
    panel.toolbar = toolbar
    local toolX = 0
    local function Tool(key, w, label, tip, onClick)
        local btn = UI.CreatePanelButton(toolbar, w, 20, label)
        btn:SetPoint("LEFT", toolbar, "LEFT", toolX, 0)
        toolX = toolX + w + 2
        btn.toolKey = key
        btn:SetScript("OnClick", onClick)
        btn:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        toolbar[key] = btn
        return btn
    end
    local function Gap() toolX = toolX + 5 end
    local function Glyph(btn, file, size)
        local fs = btn:GetFontString()
        if fs and fs.SetFont then fs:SetFont(NOTO .. file, size or 12, "") end
        return fs
    end

    -- Police : menu déroulant, chaque nom écrit dans sa police.
    local fontMenu, fontSel, fontBtn
    fontBtn = Tool("police", 96, "Noto Sans", "Police du texte sélectionné", function(self)
        local start, stop, text = GetSelection(descEB)
        fontSel = { start = start, stop = stop, text = text }
        if not fontMenu then
            fontMenu = CreateFrame("Frame", nil, panel)
            fontMenu:SetFrameStrata("FULLSCREEN_DIALOG")
            fontMenu:SetFrameLevel(panel:GetFrameLevel() + 60)
            local bg = fontMenu:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(); UI.ApplyWindowBackground(bg, .98); UI.ApplyBorder(fontMenu)
            fontMenu:SetSize(150, #RT.FONTS * 20 + 8)
            for index, font in ipairs(RT.FONTS) do
                local row = CreateFrame("Button", nil, fontMenu)
                row:SetSize(142, 20)
                row:SetPoint("TOPLEFT", 4, -4 - (index - 1) * 20)
                local label = row:CreateFontString(nil, "OVERLAY")
                label:SetFont(font.regular, 13, "")
                label:SetPoint("LEFT", 6, 0); label:SetText(font.label); label:SetTextColor(1, 1, 1)
                local hl = row:CreateTexture(nil, "HIGHLIGHT")
                hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, .15)
                row:SetScript("OnClick", function()
                    fontMenu:Hide()
                    if descEB:GetText() ~= fontSel.text then return end
                    fontBtn:SetText(font.label)
                    SetFontFor(descEB, fontSel, font.key)
                end)
            end
            fontMenu:SetScript("OnShow", function(menu)
                menu:SetScript("OnUpdate", function()
                    if not menu:IsMouseOver() and not fontBtn:IsMouseOver() and IsMouseButtonDown and IsMouseButtonDown() then menu:Hide() end
                end)
            end)
            fontMenu:Hide()
        end
        fontMenu:ClearAllPoints()
        fontMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        fontMenu:SetShown(not fontMenu:IsShown())
    end)
    Gap()

    -- Taille : - [12] +
    local sizeLabel
    local function Step(delta) sizeLabel:SetText(StepSize(descEB, delta)) end
    Tool("tailleMoins", 18, "-", "Réduire la taille", function() Step(-1) end)
    sizeLabel = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sizeLabel:SetPoint("LEFT", toolbar, "LEFT", toolX, 0); sizeLabel:SetWidth(22)
    sizeLabel:SetJustifyH("CENTER"); sizeLabel:SetText(RT.DEFAULT_SIZE)
    toolX = toolX + 24
    Tool("taillePlus", 18, "+", "Augmenter la taille", function() Step(1) end)
    Gap()

    -- Gras / italique / souligné / barré
    Glyph(Tool("b", 20, "B", "Gras", function() ToggleStyle(descEB, "b") end), "Bold.ttf", 13)
    Glyph(Tool("i", 20, "I", "Italique", function() ToggleStyle(descEB, "i") end), "Italic.ttf", 13)
    local underlineBtn = Tool("u", 20, "U", "Souligné", function() ToggleStyle(descEB, "u") end)
    Glyph(underlineBtn, "Regular.ttf", 13)
    local rule = underlineBtn:CreateTexture(nil, "OVERLAY")
    rule:SetSize(8, 1); rule:SetPoint("CENTER", 0, -6); rule:SetColorTexture(.92, .84, .67, 1)
    local strikeBtn = Tool("s", 20, "S", "Barré", function() ToggleStyle(descEB, "s") end)
    Glyph(strikeBtn, "Regular.ttf", 13)
    local strike = strikeBtn:CreateTexture(nil, "OVERLAY")
    strike:SetSize(10, 1); strike:SetPoint("CENTER", 0, 0); strike:SetColorTexture(.92, .84, .67, 1)
    Gap()

    -- Alignement : trois petits paragraphes dessinés.
    for _, align in ipairs({ { "gauche", "LEFT", "Aligner à gauche" }, { "centre", "CENTER", "Centrer" }, { "droite", "RIGHT", "Aligner à droite" } }) do
        local btn = Tool(align[1], 20, "", align[3], function() SetAlign(descEB, align[1]) end)
        for row, width in ipairs({ 10, 6, 10, 6 }) do
            local line = btn:CreateTexture(nil, "OVERLAY")
            line:SetSize(width, 1); line:SetColorTexture(.92, .84, .67, 1)
            local y = 5 - (row - 1) * 3
            if align[2] == "LEFT" then line:SetPoint("LEFT", btn, "CENTER", -5, y)
            elseif align[2] == "RIGHT" then line:SetPoint("RIGHT", btn, "CENTER", 5, y)
            else line:SetPoint("CENTER", btn, "CENTER", 0, y) end
        end
    end
    Gap()

    -- Référence, couleur du texte, surlignage, effacer la mise en forme.
    Tool("lien", 22, "{{", "Insérer une référence (puis choisir dans la liste)", function() InsertReference(descEB) end)
    local colorBtn = Tool("couleur", 20, "A", "Couleur du texte", function() PickColor(colorTarget or descEB, "couleur") end)
    Glyph(colorBtn, "Bold.ttf", 12)
    local colorBar = colorBtn:CreateTexture(nil, "OVERLAY")
    colorBar:SetSize(12, 3); colorBar:SetPoint("BOTTOM", 0, 3)
    colorBar:SetColorTexture(lastColor.r, lastColor.g, lastColor.b)
    toolbarSwatches.couleur = colorBar
    local bgBtn = Tool("fond", 20, "ab", "Surligner", function() PickColor(colorTarget or descEB, "fond") end)
    Glyph(bgBtn, "Regular.ttf", 11)
    local bgSwatch = bgBtn:CreateTexture(nil, "ARTWORK")
    bgSwatch:SetPoint("TOPLEFT", 3, -4); bgSwatch:SetPoint("BOTTOMRIGHT", -3, 4)
    bgSwatch:SetColorTexture(lastBg.r, lastBg.g, lastBg.b)
    toolbarSwatches.fond = bgSwatch
    local clearBtn = Tool("effacer", 20, "", "Effacer la mise en forme de la sélection", function() ClearFormatting(colorTarget or descEB) end)
    local clearIcon = clearBtn:CreateTexture(nil, "OVERLAY")
    clearIcon:SetSize(12, 12); clearIcon:SetPoint("CENTER")
    clearIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")

    descViewport=CreateFrame("ScrollFrame",nil,panel)
    descViewport:SetPoint("TOPLEFT",panel,"TOPLEFT",formX,-192);descViewport:SetSize(formW,162)
    local editorBg=descViewport:CreateTexture(nil,"BACKGROUND");editorBg:SetAllPoints();editorBg:SetColorTexture(.015,.02,.023,1);UI.ApplyBorder(descViewport)
    descEB=CreateFrame("EditBox",nil,descViewport)
    descEB:SetWidth(formW);descEB:SetHeight(162);descEB:SetMultiLine(true);descEB:SetAutoFocus(false)
    descEB:SetFontObject("GameFontHighlightSmall");descEB:SetTextInsets(6,6,6,6);descEB:SetMaxLetters(6000)
    descViewport:SetScrollChild(descEB);descViewport:EnableMouseWheel(true)
    -- Any click in the framed area focuses the editor, even below the last line.
    descViewport:EnableMouse(true)
    descViewport:SetScript("OnMouseDown",function() descEB:SetFocus();descEB:SetCursorPosition(#descEB:GetText()) end)
    descViewport:SetScript("OnMouseWheel",function(self,d) self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-d*18))) end)
    descEB:SetScript("OnCursorChanged",function(_,_,y,_,height)
        local top=math.abs(y);local scroll=descViewport:GetVerticalScroll()
        if top<scroll then descViewport:SetVerticalScroll(top)
        elseif top+height>scroll+162 then descViewport:SetVerticalScroll(math.max(0,top+height-162)) end
    end)

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -362)
    legend:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    legend:SetJustifyH("LEFT"); legend:SetWordWrap(true)
    legend:SetText("Sélectionnez du texte puis un outil de la barre (couleur et effacer marchent aussi sur le nom).  Référence : tapez {{ puis choisissez dans la liste (clic ou Tab).")
    UI.ApplyMutedText(legend)

    local previewLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -420)
    previewLbl:SetText("Aperçu"); UI.ApplyLabel(previewLbl)
    previewViewport=CreateFrame("ScrollFrame",nil,panel)
    previewViewport:SetPoint("TOPLEFT",panel,"TOPLEFT",formX,-438);previewViewport:SetSize(formW,90)
    previewViewport:EnableMouseWheel(true)
    local previewContent=CreateFrame("Frame",nil,previewViewport);previewContent:SetSize(formW-8,90)
    previewViewport:SetScrollChild(previewContent)
    C:EnableSkillLinks(previewContent)
    descPreview=previewContent
    -- Aperçu = infobulle finale : nom coloré en tête, puis la description.
    local function UpdatePreview()
        -- Aperçu = carte finale : nom doré en tête (ses propres couleurs gardées), puis la description.
        local source=nameEB:GetText()~="" and ("[[#ffd100]]"..nameEB:GetText().."[[/]]"..(descEB:GetText()~="" and "\n"..descEB:GetText() or "")) or descEB:GetText()
        local _,height=C.RichText.Render(previewContent,source,formW-16,C:SkillTextOptions(),4,4)
        previewContent:SetHeight(math.max(90,height+8))
    end
    descEB:SetScript("OnTextChanged",UpdatePreview)
    nameEB:HookScript("OnTextChanged",UpdatePreview)
    -- Couleur, surlignage et effacer agissent sur le dernier champ utilisé
    -- (nom ou description) ; les autres outils, sur la description.
    nameEB:HookScript("OnEditFocusGained",function() colorTarget=nameEB end)
    descEB:HookScript("OnEditFocusGained",function() colorTarget=descEB end)
    autocomplete=BuildAutocomplete(descEB,panel)
    descEB:HookScript("OnTextChanged",autocomplete.Refresh)
    descEB:HookScript("OnCursorChanged",function(_,x,y,_,height) autocomplete.SetCursor(x,y,height);autocomplete.Refresh() end)
    descEB:HookScript("OnEditFocusGained",autocomplete.Refresh)
    descEB:HookScript("OnEditFocusLost",function() C_Timer.After(0,function() if not autocomplete:IsMouseOver() then autocomplete:Hide() end end) end)
    descEB:SetScript("OnTabPressed",function() if autocomplete:IsShown() then autocomplete.AcceptSelected() end end)
    descEB:SetScript("OnEscapePressed",function(self) if autocomplete:IsShown() then autocomplete.Dismiss() else self:ClearFocus() end end)
    previewViewport:SetScript("OnMouseWheel",function(self,d) self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-d*18))) end)

    local saveBtn = UI.CreatePanelButton(panel, 90, 22, "Enregistrer")
    saveControl=saveBtn
    saveBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", formX, 32)
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
    deleteControl=deleteBtn
    deleteBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    deleteBtn:SetScript("OnClick", function()
        if selectedOwner then ShowStatus("Lecture seule : seul le créateur peut supprimer",true);return end
        if not editingName then ShowStatus("Rien à supprimer", true); return end
        if pendingDelete ~= editingName then
            pendingDelete=editingName;ShowStatus("Recliquez sur Supprimer pour confirmer",true);return
        end
        C:DeleteSkill(activeCat.key, editingName)
        ClearForm()
        RefreshList()
        ShowStatus("Supprimé")
    end)

    statusFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusFS:SetPoint("BOTTOMLEFT",panel,"BOTTOMLEFT",formX,12)
    statusFS:SetWidth(formW);statusFS:SetJustifyH("LEFT")
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

function C:OpenSkillInBuilder(catKey,name)
    local cat=FindCategory(catKey);local skill=self:GetSkill(catKey,name)
    if not cat or not skill then return end
    Build();SelectTab(cat);LoadIntoForm(skill);panel:Show()
end

local beforeLibraryRefresh=C.OnSkillsChanged
C.OnSkillsChanged=function(...)
    if beforeLibraryRefresh then beforeLibraryRefresh(...) end
    if panel and panel:IsShown() and activeCat then RefreshList() end
end

C.OnSkillTransferStatus=function(message) if statusFS then ShowStatus(message) end end
