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

-- Bibliothèque commune : toutes les bibliothèques fusionnées (lecture seule).
local COMMON = "*commune*"
C.COMMON_SKILL_LIBRARY = COMMON
local CommonSkillDB

local function GetSkillDB()
    if selectedOwner == COMMON then return CommonSkillDB() end
    if selectedOwner then
        local stores=CharacterDB.skillLibraries or {}
        local library=stores[selectedOwner]
        if library then return library.categories end
        selectedOwner=nil
    end
    return GetOwnedSkillDB()
end
function C:GetOwnedSkillLibrary() return GetOwnedSkillDB() end
function C:GetSkillLibraryOwner() return selectedOwner end

-- ── Droits d'édition ───────────────────────────────────────────────────────
-- Vos éditeurs : { ["Nom-Royaume"]=true }, envoyés avec votre bibliothèque.
function C:GetSkillEditors()
    CharacterDB = CharacterDB or {}
    CharacterDB.skillEditors = CharacterDB.skillEditors or {}
    CharacterDB.skillEditors[OwnerKey()] = CharacterDB.skillEditors[OwnerKey()] or {}
    return CharacterDB.skillEditors[OwnerKey()]
end
function C:SetSkillEditor(name, allowed)
    self:GetSkillEditors()[name] = allowed and true or nil
end

-- Modifiable : la vôtre, ou celle d'un créateur qui vous a nommé éditeur.
function C:CanEditSkillLibrary(owner)
    if owner == nil then return true end
    if owner == COMMON then return false end
    local library = CharacterDB.skillLibraries and CharacterDB.skillLibraries[owner]
    -- Même écriture que le protocole (royaume sans espaces).
    local me = OwnerKey():gsub("%s", "")
    return library and library.editors and library.editors[me] and true or false
end
function C:IsSkillLibraryReadOnly() return not self:CanEditSkillLibrary(selectedOwner) end

-- Oublie une bibliothèque reçue (elle reviendra si son créateur la renvoie).
function C:DeleteReceivedSkillLibrary(owner)
    if not owner or owner == COMMON or not (CharacterDB.skillLibraries and CharacterDB.skillLibraries[owner]) then return false end
    CharacterDB.skillLibraries[owner] = nil
    if selectedOwner == owner then selectedOwner = nil end
    if self.OnSkillsChanged then self.OnSkillsChanged() end
    return true
end

-- Votre bibliothèque, remplacée par la version d'un de vos éditeurs.
function C:ReplaceOwnedSkillLibrary(categories)
    CharacterDB.skills = CharacterDB.skills or {}
    CharacterDB.skills[OwnerKey()] = categories
    GetOwnedSkillDB()
end

-- ── CRUD ─────────────────────────────────────────────────────────────────────
-- Clé de tri alphabétique : le nom affiché (sans balises), sans majuscules
-- ni accents, pour que « Déplacement » se range avec les D et qu'un nom
-- coloré ne soit pas classé par sa balise de couleur.
local ACCENTS = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["ã"] = "a", ["å"] = "a",
    ["ç"] = "c", ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
    ["î"] = "i", ["ï"] = "i", ["í"] = "i", ["ì"] = "i",
    ["ô"] = "o", ["ö"] = "o", ["ó"] = "o", ["ò"] = "o", ["õ"] = "o",
    ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ú"] = "u", ["ÿ"] = "y", ["ñ"] = "n",
    ["œ"] = "oe", ["æ"] = "ae",
}
local function SortKey(name)
    local plain = C:StripSkillMarkup(tostring(name or "")):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    plain = plain:lower():gsub("[\195\197][\128-\191]", function(ch)
        -- Majuscule accentuée (É, À, Ç…) -> minuscule : même décalage qu'en Latin-1.
        local b1, b2 = ch:byte(1, 2)
        if b1 == 195 and b2 >= 128 and b2 <= 158 and b2 ~= 151 then ch = string.char(195, b2 + 32) end
        return ACCENTS[ch] or ch
    end)
    return plain
end
function C:SkillSortKey(name) return SortKey(name) end
local function Alphabetical(a, b)
    local ka, kb = SortKey(a), SortKey(b)
    if ka ~= kb then return ka < kb end
    return a < b
end

function C:ListSkills(catKey)
    local db = GetSkillDB()
    local names = {}
    for name in pairs(db[catKey] or {}) do names[#names + 1] = name end
    table.sort(names, Alphabetical)
    local list = {}
    for _, name in ipairs(names) do list[#list + 1] = db[catKey][name] end
    return list
end

function C:GetSkill(catKey, name)
    local db = GetSkillDB()
    return db[catKey] and db[catKey][name]
end

-- Consultation (bouton Action, références) : toutes les bibliothèques
-- fusionnées, la vôtre et celles reçues, sans avoir à en changer dans le
-- builder. Copies en lecture seule, avec leur créateur (nil = la vôtre) ;
-- une compétence identique reçue de plusieurs sources n'apparaît qu'une fois.
function C:ListAllSkills(catKey)
    local list, seen = {}, {}
    local function add(categories, owner)
        for _, skill in pairs(categories and categories[catKey] or {}) do
            local key = self:StripSkillMarkup(skill.name):lower() .. "\0" .. tostring(skill.icon) .. "\0" .. tostring(skill.description)
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = { name = skill.name, icon = skill.icon, description = skill.description, owner = owner }
            end
        end
    end
    add(GetOwnedSkillDB(), nil)
    local owners = {}
    for owner in pairs(CharacterDB.skillLibraries or {}) do owners[#owners + 1] = owner end
    table.sort(owners)
    for _, owner in ipairs(owners) do add(CharacterDB.skillLibraries[owner].categories, owner) end
    table.sort(list, function(a, b)
        local an, bn = SortKey(a.name), SortKey(b.name)
        if an ~= bn then return an < bn end
        if (a.owner == nil) ~= (b.owner == nil) then return a.owner == nil end
        return (a.owner or "") < (b.owner or "")
    end)
    return list
end

-- Vue "commune" au format d'une bibliothèque : { catégorie = { clé = compétence } }.
-- Deux versions d'un même nom (créateurs différents) gardent chacune leur clé.
function CommonSkillDB()
    local db = {}
    for _, cat in ipairs(CATEGORIES) do
        db[cat.key] = {}
        for _, skill in ipairs(C:ListAllSkills(cat.key)) do
            local key = skill.name
            if db[cat.key][key] then key = skill.name .. "\0" .. (skill.owner or "") end
            db[cat.key][key] = skill
        end
    end
    return db
end

-- ── Disposition du bouton Action (par personnage) ──────────────────────────
-- Pour chaque catégorie : l'ordre choisi (clés) et les compétences masquées.
-- Clé stable = nom sans balises + créateur ("" = vous). Une compétence
-- jamais rangée s'ajoute à la fin, affichée, dans l'ordre alphabétique.
local function LayoutKey(skill)
    return C:StripSkillMarkup(skill.name):lower() .. "@" .. (skill.owner or "")
end

local function GetActionLayout(catKey)
    CharacterDB = CharacterDB or {}
    CharacterDB.actionLayout = CharacterDB.actionLayout or {}
    local mine = CharacterDB.actionLayout[OwnerKey()] or {}
    CharacterDB.actionLayout[OwnerKey()] = mine
    mine[catKey] = mine[catKey] or { order = {}, hidden = {} }
    return mine[catKey]
end

-- Toutes les compétences (bibliothèque commune) dans l'ordre choisi :
-- { { skill, key, shown }, … }
function C:ListActionEntries(catKey)
    local layout = GetActionLayout(catKey)
    local byKey, entries, placed = {}, {}, {}
    for _, skill in ipairs(self:ListAllSkills(catKey)) do byKey[LayoutKey(skill)] = skill end
    for _, key in ipairs(layout.order) do
        if byKey[key] and not placed[key] then
            placed[key] = true
            entries[#entries + 1] = { skill = byKey[key], key = key, shown = not layout.hidden[key] }
        end
    end
    for _, skill in ipairs(self:ListAllSkills(catKey)) do
        local key = LayoutKey(skill)
        if not placed[key] then
            placed[key] = true
            entries[#entries + 1] = { skill = skill, key = key, shown = not layout.hidden[key] }
        end
    end
    return entries
end

-- Compétences affichées dans la bande du bouton Action, dans l'ordre choisi.
function C:ListActionSkills(catKey)
    local list = {}
    for _, entry in ipairs(self:ListActionEntries(catKey)) do
        if entry.shown then list[#list + 1] = entry.skill end
    end
    return list
end

-- Déplace l'entrée n° from à la place n° to (indices de ListActionEntries).
function C:MoveActionEntry(catKey, from, to)
    local entries = self:ListActionEntries(catKey)
    local moved = table.remove(entries, from)
    if not moved then return end
    to = math.max(1, math.min(#entries + 1, to))
    table.insert(entries, to, moved)
    local layout = GetActionLayout(catKey)
    layout.order = {}
    for i, entry in ipairs(entries) do layout.order[i] = entry.key end
    if self.OnSkillsChanged then self.OnSkillsChanged() end
end

function C:SetActionEntryShown(catKey, key, shown)
    GetActionLayout(catKey).hidden[key] = (not shown) or nil
    if self.OnSkillsChanged then self.OnSkillsChanged() end
end

-- " · Créateur" discret après le nom d'une compétence reçue.
function C:SkillOwnerSuffix(skill)
    if not skill or not skill.owner then return "" end
    return "  |cff8a8a8a· " .. (skill.owner:match("^[^-]+") or skill.owner) .. "|r"
end

-- oldName nil/absent = création ; renommage géré en retirant l'ancienne clé.
function C:SaveSkill(catKey, oldName, name, icon, description)
    if self:IsSkillLibraryReadOnly() then return false,"Lecture seule : seuls le créateur et ses éditeurs peuvent modifier" end
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
    if self:IsSkillLibraryReadOnly() then return false,"Lecture seule : seuls le créateur et ses éditeurs peuvent supprimer" end
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

-- Retrouve une compétence par son nom affiché (balises ignorées) : d'abord
-- dans la bibliothèque affichée, puis dans toutes les bibliothèques.
function C:FindSkillRef(catKey, name)
    local skill = self:GetSkill(catKey, name)
    if skill then return skill end
    name = self:StripSkillMarkup(name):lower()
    for _, candidate in ipairs(self:ListSkills(catKey)) do
        if self:StripSkillMarkup(candidate.name):lower() == name then return candidate end
    end
    for _, candidate in ipairs(self:ListAllSkills(catKey)) do
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
local CARD_MIN_W, CARD_MAX_W, CARD_PAD, CARD_HEAD = 150, 300, 13, 31
local MAX_CARDS = 5
local cards = {}
local ShowCard

-- Une carte liée se ferme quand la souris n'est plus ni sur son lien, ni sur
-- elle, ni sur une carte plus profonde — ou quand le cadre qui l'a ouverte
-- disparaît. "Sur son lien" exige aussi la souris sur ce cadre : un
-- OnHyperlinkLeave peut ne jamais arriver (aperçu du builder redessiné sous
-- la souris, builder fermé), et la carte restait alors ouverte.
local function CheckCards()
    for depth = #cards, 2, -1 do
        local card = cards[depth]
        local deeper = cards[depth + 1]
        if card:IsShown() then
            local source = card.source
            local sourceGone = not source or not source:IsVisible()
            local onLink = card.linkHovered and source and source:IsMouseOver()
            if sourceGone or (not onLink and not card:IsMouseOver() and not (deeper and deeper:IsShown())) then
                card:Hide()
            end
        end
    end
end

-- Surveillance légère tant qu'une carte liée est ouverte.
local cardWatcher = CreateFrame("Frame")
cardWatcher:Hide()
local watchElapsed = 0
cardWatcher:SetScript("OnUpdate", function(self, elapsed)
    watchElapsed = watchElapsed + elapsed
    if watchElapsed < .2 then return end
    watchElapsed = 0
    CheckCards()
    if not (cards[2] and cards[2]:IsShown()) then self:Hide() end
end)

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

local OPEN_TIME = .24
local LINK_GAP = 24   -- espace entre une carte et sa source, occupé par le flux

-- Flux de pixels qui relie une carte à sa source (« je viens de là ») :
-- des pixels bronze et or montent de l'icône vers la carte, ou filent du
-- lien survolé vers la carte liée, en s'évasant à l'arrivée. Hors de la
-- carte (qui rogne ses enfants), dans un cadre plein écran sans souris.
local FLUX_DOTS = 26
local FLUX_COLORS = { { .85, .70, .42 }, { .47, .38, .26 }, { .91, .80, .57 }, { .62, .48, .25 } }

-- Position d'un point d'un cadre, ramenée à l'échelle de UIParent (le
-- bouton Action a sa propre échelle).
local function ToUI(frame, x, y)
    local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    return x * ratio, y * ratio
end

local function FluxFrame()
    local flux = CreateFrame("Frame", nil, UIParent)
    flux:SetFrameStrata("TOOLTIP")
    flux:SetAllPoints(UIParent)
    flux:EnableMouse(false)
    flux:Hide()
    flux.dots, flux.clock, flux.fade = {}, 0, 0
    for i = 1, FLUX_DOTS do
        local dot = flux:CreateTexture(nil, "OVERLAY")
        local color = FLUX_COLORS[(i - 1) % #FLUX_COLORS + 1]
        dot:SetColorTexture(color[1], color[2], color[3], 1)
        local size = (i % 3 == 0) and 3 or 2
        dot:SetSize(size, size)
        dot.seed = i * 1.618
        flux.dots[i] = dot
    end
    flux:SetScript("OnUpdate", function(self, elapsed)
        self.clock = self.clock + elapsed
        local sx, sy, tx, ty, vertical = self.Geometry()
        if not sx then return end
        for i, dot in ipairs(self.dots) do
            local phase = (self.clock * .9 + i / FLUX_DOTS + dot.seed * .07) % 1
            local spread = math.sin(dot.seed * 7 + self.clock * 2.4) * (vertical and 11 or 8) * (.2 + .8 * phase)
            local x, y
            if vertical then
                x, y = sx + spread, sy + (ty - sy) * phase
            else
                x, y = sx + (tx - sx) * phase, sy + spread
            end
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
            dot:SetAlpha(math.sin(phase * math.pi) * .9 * self.fade)
        end
    end)
    return flux
end

-- Cadre des cartes : même facture que le cadre de ressources (métal doré,
-- filet bronze, fond sombre), en 9 parts pour s'étirer sans déformer les
-- coins (Media/SkillCard.tga, coins 24/128 ; Tests/hud-art.js).
local CARD_FRAME = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\SkillCard"
local CARD_GEM = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\SkillCardGem"
local CORNER, CORNER_TEX = 12, 24 / 128

local function BuildCardFrame(card)
    local parts = {}
    local cuts = { 0, CORNER_TEX, 1 - CORNER_TEX, 1 }
    for row = 1, 3 do
        for col = 1, 3 do
            local tex = card:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture(CARD_FRAME)
            tex:SetTexCoord(cuts[col], cuts[col + 1], cuts[row], cuts[row + 1])
            parts[(row - 1) * 3 + col] = tex
        end
    end
    -- Coins réduits tant que la carte est plus petite qu'eux (ouverture).
    local function Layout()
        local w, h = card:GetWidth() or 0, card:GetHeight() or 0
        local k = math.max(1, math.min(CORNER, w / 2, h / 2))
        local xs, ys = { 0, k, w - k, w }, { 0, k, h - k, h }
        for i, tex in ipairs(parts) do
            local row, col = math.floor((i - 1) / 3) + 1, (i - 1) % 3 + 1
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", card, "TOPLEFT", xs[col], -ys[row])
            tex:SetPoint("BOTTOMRIGHT", card, "TOPLEFT", xs[col + 1], -ys[row + 1])
        end
    end
    card:SetScript("OnSizeChanged", Layout)
    Layout()
    -- Losange : là où le flux arrive (placé par PlayOpen).
    card.gem = card:CreateTexture(nil, "OVERLAY", nil, 2)
    card.gem:SetTexture(CARD_GEM)
end

local function GetCard(depth)
    if cards[depth] then return cards[depth] end
    local card = CreateFrame("Frame", "CharacterSkillCard" .. depth, UIParent)
    card:SetFrameStrata("TOOLTIP")
    card:SetClampedToScreen(true)
    -- Ouverture animée : la carte grandit et ne montre que ce qu'elle couvre.
    card:SetClipsChildren(true)
    card:Hide()
    BuildCardFrame(card)
    -- Contenu à sa taille finale, posé contre le bord d'où la carte s'ouvre :
    -- la carte grandit par-dessus et le dévoile (panneau de données).
    local content = CreateFrame("Frame", nil, card)
    card.content = content
    card.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOP", 0, -11)
    card.title:SetJustifyH("CENTER"); card.title:SetWordWrap(false)
    UI.ApplyTitle(card.title)
    local rule = content:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", CARD_PAD, -CARD_HEAD); rule:SetPoint("TOPRIGHT", -CARD_PAD, -CARD_HEAD)
    rule:SetHeight(1); UI.ApplySeparator(rule, true)
    card.rule = rule
    -- Filet de balayage sur le bord qui avance pendant l'ouverture.
    card.edge = card:CreateTexture(nil, "OVERLAY")
    card.edge:SetColorTexture(.85, .70, .42, 1)
    card.edge:Hide()
    card.flux = FluxFrame()
    -- Corps : texte enrichi (C.RichText), blanc par défaut, posé dans le contenu.
    C:EnableSkillLinks(content, depth)
    card:SetScript("OnHide", function()
        card.linkHovered = false
        card:SetScript("OnUpdate", nil)
        card.flux:Hide()
        if cards[depth + 1] then cards[depth + 1]:Hide() end
    end)
    if depth > 1 then card:SetScript("OnLeave", function() C_Timer.After(.15, CheckCards) end) end
    cards[depth] = card
    return card
end

local function TextWidth(fs)
    return fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
end

-- side : "UP" (carte d'une compétence, du bas vers le haut) ou "RIGHT" /
-- "LEFT" (carte liée, vers l'extérieur de la carte active).
local function PlayOpen(card, width, height, side)
    local content, edge, gem = card.content, card.edge, card.gem
    content:ClearAllPoints()
    edge:ClearAllPoints()
    gem:ClearAllPoints()
    if side == "UP" then
        gem:SetSize(10, 26); gem:SetRotation(math.pi / 2)
        gem:SetPoint("CENTER", card, "BOTTOM", 0, 2)
    else
        gem:SetSize(10, 26); gem:SetRotation(0)
        gem:SetPoint("CENTER", card, side == "RIGHT" and "LEFT" or "RIGHT", side == "RIGHT" and 2 or -2, 0)
    end
    if side == "UP" then
        content:SetPoint("BOTTOM", card, "BOTTOM")
        edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
    elseif side == "RIGHT" then
        content:SetPoint("LEFT", card, "LEFT")
        edge:SetPoint("TOPRIGHT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetWidth(1)
    else
        content:SetPoint("RIGHT", card, "RIGHT")
        edge:SetPoint("TOPLEFT"); edge:SetPoint("BOTTOMLEFT"); edge:SetWidth(1)
    end
    local elapsed = 0
    local function Draw(p)
        local ease = 1 - (1 - p) ^ 3
        if side == "UP" then card:SetSize(width, math.max(1, height * ease))
        else card:SetSize(math.max(1, width * ease), height) end
        edge:SetAlpha(1 - p)
        edge:SetShown(p < 1)
        card.flux.fade = ease
    end
    -- Flux : de la source (haut de l'icône, ou bord de la carte active à la
    -- hauteur du lien) vers le bord de la carte qui s'ouvre.
    local source = card.source
    card.flux.Geometry = function()
        if not source or not source:IsVisible() then return end
        if side == "UP" then
            local cx, top = source:GetCenter(), source:GetTop()
            local bottom = card:GetBottom()
            if not (cx and top and bottom) then return end
            local sx, sy = ToUI(source, cx, top)
            return sx, sy, sx, bottom, true
        end
        local edge = side == "RIGHT" and source:GetRight() or source:GetLeft()
        local target = side == "RIGHT" and card:GetLeft() or card:GetRight()
        local _, sourceBottom = source:GetCenter()
        if not (edge and target) then return end
        local sx = ToUI(source, edge, 0)
        local y = card.linkY or select(2, ToUI(source, 0, sourceBottom or 0))
        return sx, y, target, y, false
    end
    card.flux:Show()
    Draw(0)
    card:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        local p = math.min(1, elapsed / OPEN_TIME)
        Draw(p)
        if p >= 1 then self:SetScript("OnUpdate", nil) end
    end)
end

function ShowCard(depth, anchor, skill)
    local card = GetCard(depth)
    if cards[depth + 1] then cards[depth + 1]:Hide() end
    local content = card.content
    -- Fiche de consultation : le nom seul, sans son créateur.
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
    local bodyWidth = RT.Measure(content, body, CARD_MAX_W - CARD_PAD * 2, opts)
    local inner = math.max(TextWidth(card.title), bodyWidth)
    local width = math.max(CARD_MIN_W, math.min(CARD_MAX_W, inner + CARD_PAD * 2))
    card.title:SetWidth(width - CARD_PAD * 2)
    local _, bodyHeight = RT.Render(content, body, width - CARD_PAD * 2, opts, CARD_PAD, CARD_HEAD + 6)
    local height = body ~= "" and (CARD_HEAD + 18 + bodyHeight) or CARD_HEAD + 8
    card.rule:SetShown(body ~= "")
    content:SetSize(width, height)

    -- Toujours au-dessus de la carte / du cadre qui l'ouvre (pour une
    -- référence, la carte précédente, pas son contenu).
    local below = depth > 1 and cards[depth - 1] or anchor
    card.source = anchor
    if depth > 1 then
        cardWatcher:Show()
        -- Hauteur du lien survolé (curseur), pour la pointe de l'accolade.
        local cy = GetCursorPosition and select(2, GetCursorPosition())
        card.linkY = cy and cy / UIParent:GetEffectiveScale() or nil
    end
    card:SetFrameLevel((below:GetFrameLevel() or 0) + 20)
    card:ClearAllPoints()
    local side = "UP"
    if depth == 1 then
        card:SetPoint("BOTTOM", anchor, "TOP", 0, LINK_GAP)
    else
        local right = anchor:GetRight() or 0
        local screen = UIParent:GetRight() or 0
        -- Centrée sur la hauteur du lien survolé : le flux arrive au milieu
        -- de son bord (l'écran la garde entière, SetClampedToScreen).
        local anchorTop = anchor:GetTop()
        local dy = (card.linkY and anchorTop) and (card.linkY - anchorTop) or -height / 2
        if right + LINK_GAP + width <= screen then
            card:SetPoint("LEFT", anchor, "TOPRIGHT", LINK_GAP, dy); side = "RIGHT"
        else
            card:SetPoint("RIGHT", anchor, "TOPLEFT", -LINK_GAP, dy); side = "LEFT"
        end
    end
    card:Show()
    PlayOpen(card, width, height, side)
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
        BuildCardFrame(nameTip)
        nameTip.gem:Hide()
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
local formFrame, formHint

-- Le formulaire n'apparaît que pendant une création ou une modification ;
-- sinon, une invite à choisir une compétence ou à en créer une.
local function SetFormShown(shown)
    if formFrame then formFrame:SetShown(shown) end
    if formHint then formHint:SetShown(not shown) end
end

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
    SetFormShown(true)
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
    text:SetPoint("LEFT", icon, "RIGHT", 5, 4); text:SetPoint("RIGHT", -4, 4)
    text:SetJustifyH("LEFT"); text:SetWordWrap(false)
    UI.ApplyBodyText(text)
    -- Créateur de l'entrée, discret, en bas à droite.
    local creator = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    creator:SetPoint("BOTTOMRIGHT", -5, 3)
    creator:SetFont(C.RichText.GetFont("noto").regular, 9, "")
    creator:SetJustifyH("RIGHT"); creator:SetWordWrap(false)
    creator:SetTextColor(.55, .55, .55)
    row.icon, row.text, row.bg, row.creator = icon, text, bg, creator
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
        -- Commune : chaque copie porte son créateur (nil = vous) ; bibliothèque
        -- reçue : son créateur ; la vôtre : « Vous ».
        local owner = skill.owner or (selectedOwner ~= COMMON and selectedOwner) or nil
        row.creator:SetText("Créé par : " .. (owner and (owner:match("^[^-]+") or owner) or "Vous"))
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
    SetFormShown(false)
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
    -- Bibliothèque affichée : menu déroulant (la vôtre, puis chaque créateur).
    local ownerBtn=UI.CreatePanelButton(panel,LIST_W,22,"Ma bibliothèque")
    ownerBtn:SetPoint("TOPLEFT",10,-60)
    ownerBtn.library=true
    local ownerText=ownerBtn:GetFontString()
    ownerText:ClearAllPoints();ownerText:SetPoint("LEFT",8,0);ownerText:SetPoint("RIGHT",-22,0);ownerText:SetJustifyH("LEFT")
    local arrow=ownerBtn:CreateTexture(nil,"OVERLAY")
    arrow:SetSize(14,14);arrow:SetPoint("RIGHT",-5,-1)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    local sendBtn=UI.CreatePanelButton(panel,102,22,"Envoyer au raid")
    sendBtn:SetPoint("TOPRIGHT",-10,-60)
    local function OwnerName(owner)
        if owner==COMMON then return "Bibliothèque commune" end
        local name,realm=owner:match("^([^-]+)%-(.+)$")
        return name and (name.."|cff8a8a8a-"..realm.."|r") or owner
    end
    local function LibraryCount(categories)
        local count=0
        for _,cat in ipairs(CATEGORIES) do for _ in pairs(categories and categories[cat.key] or {}) do count=count+1 end end
        return count
    end
    local rightsBtn=UI.CreatePanelButton(panel,70,22,"Droits")
    rightsBtn:SetPoint("RIGHT",sendBtn,"LEFT",-6,0)
    local rightsPanel
    local function OwnerLabel()
        local editable=C:CanEditSkillLibrary(selectedOwner)
        local label=selectedOwner and OwnerName(selectedOwner) or "Ma bibliothèque"
        if selectedOwner and editable then label=label.."  |cff8a8a8a(édition)|r" end
        ownerBtn:SetText(label)
        sendBtn:SetEnabled(editable and selectedOwner~=COMMON)
        rightsBtn:SetShown(selectedOwner==nil)
        if rightsPanel and selectedOwner then rightsPanel:Hide() end
        if saveControl then saveControl:SetEnabled(editable);deleteControl:SetEnabled(editable) end
    end
    local libraryMenu
    local libraryRows={}
    local function SelectLibrary(owner)
        if libraryMenu then libraryMenu:Hide() end
        selectedOwner=owner or nil
        OwnerLabel();SelectTab(activeCat)
        if C.OnSkillsChanged then C.OnSkillsChanged() end
    end
    local function OpenLibraryMenu()
        if not libraryMenu then
            libraryMenu=CreateFrame("Frame",nil,panel)
            libraryMenu:SetFrameStrata("FULLSCREEN_DIALOG")
            libraryMenu:SetFrameLevel(panel:GetFrameLevel()+60)
            local bg=libraryMenu:CreateTexture(nil,"BACKGROUND")
            bg:SetAllPoints();UI.ApplyWindowBackground(bg,.98);UI.ApplyBorder(libraryMenu)
            libraryMenu:SetScript("OnShow",function(menu)
                menu:SetScript("OnUpdate",function()
                    if IsMouseButtonDown and IsMouseButtonDown() and not menu:IsMouseOver() and not ownerBtn:IsMouseOver() then menu:Hide() end
                end)
            end)
            libraryMenu:Hide()
        end
        local owners={}
        for owner in pairs(CharacterDB.skillLibraries or {}) do owners[#owners+1]=owner end
        table.sort(owners)
        table.insert(owners,1,COMMON);table.insert(owners,1,false)
        for i,owner in ipairs(owners) do
            local row=libraryRows[i]
            if not row then
                row=CreateFrame("Button",nil,libraryMenu)
                row:SetSize(LIST_W-8,22);row:SetPoint("TOPLEFT",4,-4-(i-1)*22)
                row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                row.label:SetPoint("LEFT",8,0);row.label:SetPoint("RIGHT",-40,0);row.label:SetJustifyH("LEFT");row.label:SetWordWrap(false)
                row.count=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                row.count:SetPoint("RIGHT",-24,0);UI.ApplyMutedText(row.count)
                -- Oublier une bibliothèque reçue : second clic pour confirmer.
                local del=CreateFrame("Button",nil,row)
                del:SetSize(18,18);del:SetPoint("RIGHT",-2,0)
                del.text=del:CreateFontString(nil,"OVERLAY","GameFontNormal")
                del.text:SetAllPoints();del.text:SetText("×");del.text:SetTextColor(.65,.68,.64)
                del:SetScript("OnClick",function(self)
                    local owner=row.owner
                    if self.armed~=owner then
                        self.armed=owner;self.text:SetTextColor(1,.3,.3)
                        ShowStatus("Recliquez sur × pour supprimer la bibliothèque de "..OwnerName(owner),true)
                        return
                    end
                    self.armed=nil
                    C:DeleteReceivedSkillLibrary(owner)
                    ShowStatus("Bibliothèque de "..OwnerName(owner).." supprimée (elle reviendra si son créateur la renvoie)")
                    OwnerLabel();SelectTab(activeCat);OpenLibraryMenu()
                end)
                del:SetScript("OnEnter",function(self)
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                    GameTooltip:SetText("Supprimer cette bibliothèque de chez vous",1,1,1)
                    GameTooltip:Show()
                end)
                del:SetScript("OnLeave",function() GameTooltip:Hide() end)
                row.del=del
                row.mark=row:CreateTexture(nil,"ARTWORK")
                row.mark:SetPoint("TOPLEFT",0,-3);row.mark:SetPoint("BOTTOMLEFT",0,3);row.mark:SetWidth(2)
                row.mark:SetColorTexture(.85,.70,.42,1)
                local hl=row:CreateTexture(nil,"HIGHLIGHT");hl:SetAllPoints();hl:SetColorTexture(1,1,1,.12)
                row:SetScript("OnClick",function(self) SelectLibrary(self.owner) end)
                libraryRows[i]=row
            end
            row.owner=owner
            local current=(selectedOwner or false)==owner
            row.label:SetText(owner and OwnerName(owner) or "Ma bibliothèque")
            if current then row.label:SetTextColor(.91,.80,.57) else row.label:SetTextColor(1,1,1) end
            row.mark:SetShown(current)
            local categories=owner==COMMON and CommonSkillDB() or owner and CharacterDB.skillLibraries[owner].categories or C:GetOwnedSkillLibrary()
            row.count:SetText(LibraryCount(categories))
            local received=owner and owner~=COMMON
            row.del:SetShown(received and true or false)
            if row.del.armed~=owner then row.del.armed=nil;row.del.text:SetTextColor(.65,.68,.64) end
            row:Show()
        end
        for i=#owners+1,#libraryRows do libraryRows[i]:Hide() end
        libraryMenu:SetSize(LIST_W,#owners*22+8)
        libraryMenu:ClearAllPoints();libraryMenu:SetPoint("TOPLEFT",ownerBtn,"BOTTOMLEFT",0,-2)
        libraryMenu:Show()
    end
    panel.OpenLibraryMenu=OpenLibraryMenu
    ownerBtn:SetScript("OnClick",function()
        if libraryMenu and libraryMenu:IsShown() then libraryMenu:Hide() else OpenLibraryMenu() end
    end)
    sendBtn:SetScript("OnClick",function()
        local ok,message=C:SendSkillLibrary()
        ShowStatus(message,not ok)
    end)
    -- ── Droits d'édition : les éditeurs peuvent modifier votre bibliothèque
    -- reçue et la renvoyer au raid sous votre nom.
    local editorRows={}
    local function RefreshRights()
        local names={};for name in pairs(C:GetSkillEditors()) do names[#names+1]=name end;table.sort(names)
        for i,name in ipairs(names) do
            local row=editorRows[i]
            if not row then
                row=CreateFrame("Frame",nil,rightsPanel);row:SetSize(224,22)
                row.label=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                row.label:SetPoint("LEFT",4,0);row.label:SetTextColor(1,1,1)
                row.remove=UI.CreatePanelButton(row,64,18,"Retirer");row.remove:SetPoint("RIGHT",0,0)
                row.remove:SetScript("OnClick",function()
                    C:SetSkillEditor(row.name,false);RefreshRights()
                    ShowStatus("Droits retirés à "..OwnerName(row.name)..". Envoyez la bibliothèque pour le transmettre.")
                end)
                editorRows[i]=row
            end
            row.name=name;row.label:SetText(OwnerName(name))
            row:ClearAllPoints();row:SetPoint("TOPLEFT",rightsPanel,"TOPLEFT",8,-58-(i-1)*24);row:Show()
        end
        for i=#names+1,#editorRows do editorRows[i]:Hide() end
        rightsPanel.empty:SetShown(#names==0)
        rightsPanel:SetHeight(92+math.max(1,#names)*24)
    end
    local function BuildRights()
        rightsPanel=CreateFrame("Frame","CharacterSkillRights",panel)
        rightsPanel:SetFrameStrata("FULLSCREEN_DIALOG");rightsPanel:SetFrameLevel(panel:GetFrameLevel()+60)
        rightsPanel:SetWidth(240);rightsPanel:EnableMouse(true)
        rightsPanel:SetPoint("TOPRIGHT",sendBtn,"BOTTOMRIGHT",0,-4)
        local bg=rightsPanel:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();UI.ApplyWindowBackground(bg,.98);UI.ApplyBorder(rightsPanel)
        local title=rightsPanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("TOPLEFT",10,-8);title:SetText("Droits d'édition");UI.ApplyTitle(title)
        local add=UI.CreatePanelButton(rightsPanel,224,22,"Ajouter les droits d'édition (cible)")
        add:SetPoint("TOPLEFT",8,-28)
        add:SetScript("OnClick",function()
            if not UnitExists("target") or not UnitIsPlayer("target") then ShowStatus("Ciblez un joueur",true);return end
            local name,realm=UnitFullName("target")
            realm=(realm and realm~="") and realm or GetRealmName()
            local id=name.."-"..realm:gsub("%s","")
            if id==OwnerKey():gsub("%s","") then ShowStatus("Vous êtes déjà le créateur de cette bibliothèque",true);return end
            C:SetSkillEditor(id,true);RefreshRights()
            ShowStatus("Droits d'édition donnés à "..OwnerName(id)..". Envoyez la bibliothèque pour les transmettre.")
        end)
        rightsPanel.empty=rightsPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        rightsPanel.empty:SetPoint("TOPLEFT",12,-62);rightsPanel.empty:SetText("Aucun éditeur.");UI.ApplyMutedText(rightsPanel.empty)
        local hint=rightsPanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        hint:SetPoint("BOTTOMLEFT",10,8);hint:SetPoint("RIGHT",-10,0);hint:SetJustifyH("LEFT")
        hint:SetText("Un éditeur modifie et renvoie votre bibliothèque sous votre nom.");UI.ApplyMutedText(hint)
        rightsPanel:Hide()
    end
    rightsBtn:SetScript("OnClick",function()
        if not rightsPanel then BuildRights() end
        if rightsPanel:IsShown() then rightsPanel:Hide() else RefreshRights();rightsPanel:Show() end
    end)
    rightsBtn:HookScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Droits d'édition",unpack(UI.colors.title))
        GameTooltip:AddLine("Ciblez un joueur et donnez-lui le droit de modifier votre bibliothèque et de la renvoyer au raid sous votre nom.",1,1,1,true)
        GameTooltip:Show()
    end)
    rightsBtn:HookScript("OnLeave",function() GameTooltip:Hide() end)
    panel:HookScript("OnHide",function() if rightsPanel then rightsPanel:Hide() end end)
    ownerBtn:HookScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Bibliothèque affichée",unpack(UI.colors.title))
        GameTooltip:AddLine("La vôtre, la bibliothèque commune (tout ce qui existe, fusionné) ou celle d'un créateur reçue du raid. Seules la vôtre et celles dont vous êtes éditeur se modifient ; × supprime une bibliothèque reçue.",1,1,1,true)
        GameTooltip:Show()
    end)
    ownerBtn:HookScript("OnLeave",function() GameTooltip:Hide() end)
    panel:HookScript("OnHide",function() if libraryMenu then libraryMenu:Hide() end end)
    panel:HookScript("OnShow",OwnerLabel)
    panel:HookScript("OnHide",function() if iconPicker then iconPicker:Hide() end;if autocomplete then autocomplete:Hide() end end)
    local newBtn = UI.CreatePanelButton(panel, LIST_W, 22, "+ Nouvelle")
    -- Même ligne de départ que le formulaire (icône et « Nom » à -96).
    newBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -96)
    newBtn:SetScript("OnClick", function() ClearForm(); SetFormShown(true); ShowStatus("") end)

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
    vsep:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + LIST_W + 8, -96)
    vsep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10 + LIST_W + 8, 10)
    vsep:SetWidth(1)
    UI.ApplySeparator(vsep)

    -- Colonne droite : formulaire
    local formX = 10 + LIST_W + 8 + 10
    -- Tout ce qui est créé jusqu'au bouton Supprimer appartient au
    -- formulaire : on le rattache ensuite à formFrame pour le masquer d'un bloc.
    formFrame = CreateFrame("Frame", nil, panel)
    formFrame:SetAllPoints(panel)
    panel.form = formFrame
    local existingChildren, existingRegions = {}, {}
    for _, child in ipairs({ panel:GetChildren() }) do existingChildren[child] = true end
    for _, region in ipairs({ panel:GetRegions() }) do existingRegions[region] = true end
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
        if C:IsSkillLibraryReadOnly() then ShowStatus("Lecture seule : seuls le créateur et ses éditeurs peuvent supprimer",true);return end
        if not editingName then ShowStatus("Rien à supprimer", true); return end
        if pendingDelete ~= editingName then
            pendingDelete=editingName;ShowStatus("Recliquez sur Supprimer pour confirmer",true);return
        end
        C:DeleteSkill(activeCat.key, editingName)
        ClearForm()
        SetFormShown(false)
        RefreshList()
        ShowStatus("Supprimé")
    end)

    for _, child in ipairs({ panel:GetChildren() }) do
        if not existingChildren[child] then child:SetParent(formFrame) end
    end
    for _, region in ipairs({ panel:GetRegions() }) do
        if not existingRegions[region] then region:SetParent(formFrame) end
    end
    formHint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    formHint:SetPoint("CENTER", panel, "TOPLEFT", formX + formW / 2, -PANEL_H / 2)
    formHint:SetWidth(formW - 40); formHint:SetJustifyH("CENTER")
    formHint:SetText("Choisissez une compétence dans la liste pour la consulter ou la modifier,\nou créez-en une avec « + Nouvelle ».")
    UI.ApplyMutedText(formHint)
    SetFormShown(false)

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
