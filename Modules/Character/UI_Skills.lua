-- ============================================================
--  Character - Base de données de compétences
--  Catégories (Actions de base / Offensive / Défensive /
--  Distance / Grimoire) + Index et États (hors du bouton Action), éditables via un builder (Paramètres -> Base de
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
    { key = "grimoire", label = "Grimoire", tag = "Grimoire", aliases = { "grimoire" } },
    -- Index : fiches consultables par référence {{Index : Nom}} et dans le
    -- builder, mais sans bouton dans le triangle du bouton Action.
    { key = "index",     label = "Index",                 tag = "Index",     aliases = { "index" }, hidden = true },
    -- États : fiches indicatives, comme l'Index (hors du bouton Action).
    -- ("É" n'est pas abaissé par lower() : les deux casses sont listées.)
    { key = "etats",     label = "États",                 tag = "États",     aliases = { "états", "état", "etats", "etat", "États", "État" }, hidden = true },
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
        if library then
            for _,cat in ipairs(CATEGORIES) do library.categories[cat.key]=library.categories[cat.key] or {} end
            return library.categories
        end
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
            local key = self:StripSkillMarkup(skill.name):lower() .. "\0" .. tostring(skill.icon) .. "\0" .. tostring(skill.description) .. "\0" .. tostring(skill.usable == true) .. self:SkillCostKey(skill)
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = { name = skill.name, icon = skill.icon, description = skill.description, usable = skill.usable == true, cost = skill.cost, owner = owner }
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
function C:ValidateSkillCost(cost)
    if cost==nil then return true end
    if type(cost)~="table" or (cost.resource~="hp" and cost.resource~="mana" and cost.resource~="endurance") then return false end
    local n=tonumber(cost.amount)
    return n and n>=1 and n<=1000000 and n%1==0 or false
end
function C:SkillCostKey(skill)
    local cost=skill.cost
    return cost and (":"..tostring(cost.resource)..":"..tostring(cost.amount)) or ""
end
function C:SaveSkill(catKey, oldName, name, icon, description, usable, cost)
    if self:IsSkillLibraryReadOnly() then return false,"Lecture seule : seuls le créateur et ses éditeurs peuvent modifier" end
    if not FindCategory(catKey) then return false, "Catégorie inconnue" end
    name = tostring(name or ""):match("^%s*(.-)%s*$")
    if name == "" then return false, "Nom requis" end
    if #name>128 or #tostring(icon or "")>512 or #tostring(description or "")>8000 then return false,"Texte trop long" end
    if not self:ValidateSkillCost(cost) then return false,"Coût : choisissez une ressource et un entier de 1 à 1 000 000." end
    local db = GetSkillDB()
    if db[catKey][name] and oldName ~= name then return false, "Ce nom existe déjà dans cette catégorie" end
    if oldName and oldName ~= name then
        db[catKey][oldName] = nil
        -- Une entrée renommée reste cochée pour le partage partiel.
        local picked = not selectedOwner and CharacterDB.skillShare and CharacterDB.skillShare.picked
        if picked and picked[catKey] and picked[catKey][oldName] then
            picked[catKey][oldName] = nil; picked[catKey][name] = true
        end
    end
    db[catKey][name] = {
        name = name,
        icon = (icon and icon ~= "") and icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        description = description or "",
        usable = usable == true,
        cost = cost and {resource=cost.resource,amount=tonumber(cost.amount)} or nil,
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
-- Un passage rapide peut aussi perdre le Leave alors que la souris reste dans
-- le cadre : le lien ne compte que tant que le curseur reste sur sa ligne.
local LINK_LINE_TOLERANCE = 9
local function CursorY()
    local _, y = GetCursorPosition()
    return y / UIParent:GetEffectiveScale()
end
-- Hauteur du lien à l'écran, recalculée depuis le haut de sa source : elle
-- suit la fenêtre quand on la déplace (une position figée laissait le flux
-- et la zone du lien derrière).
local function CardLinkY(card)
    local source, offset = card.source, card.linkOffset
    local top = source and offset and source:GetTop()
    if not top then return end
    return top * source:GetEffectiveScale() / UIParent:GetEffectiveScale() + offset
end
local function CheckCards()
    for depth = #cards, 2, -1 do
        local card = cards[depth]
        local deeper = cards[depth + 1]
        if card:IsShown() then
            local source = card.source
            local sourceGone = not source or not source:IsVisible()
            local onLink = card.linkHovered and source and source:IsMouseOver()
                and math.abs(CursorY() - (CardLinkY(card) or CursorY())) <= LINK_LINE_TOLERANCE
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

-- Bouton « Utiliser » grisé tant que la ressource ne couvre pas le coût.
local function UpdateUseButton(card)
    local use=card.useButton
    local blocked=card.skill and C.SkillCostBlockedText and C:SkillCostBlockedText(card.skill) or nil
    use.blocked=blocked
    use.emblem:SetDesaturated(blocked~=nil)
    use.emblem:SetAlpha(blocked and .5 or 1)
    use.glow:SetAlpha(blocked and 0 or .12)
    if blocked then use.label:SetTextColor(.5,.5,.5) else use.label:SetTextColor(.94,.81,.53) end
    if use:IsMouseOver() and use:IsVisible() then
        if blocked then C:ShowSkillNotice(use,blocked) else C:HideSkillName() end
    end
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
    -- Sibling of the clipped card so its corner ornament can protrude.
    local close=C:CreateRoundCloseButton(UIParent,function() card:Hide() end)
    close:SetFrameStrata("TOOLTIP")
    card.closeButton=close
    close:SetPoint("CENTER",card,"TOPRIGHT",-2,-2)
    card.closeButton:Hide()
    if depth==1 and UISpecialFrames then
        UISpecialFrames[#UISpecialFrames+1]="CharacterSkillCard1"
    end
    card.title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.title:SetPoint("TOP", 0, -11)
    card.title:SetJustifyH("CENTER"); card.title:SetWordWrap(false)
    UI.ApplyTitle(card.title)
    local rule = content:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", CARD_PAD, -CARD_HEAD); rule:SetPoint("TOPRIGHT", -CARD_PAD, -CARD_HEAD)
    rule:SetHeight(1); UI.ApplySeparator(rule, true)
    card.rule = rule
    local use=CreateFrame("Button",nil,content)
    card.useButton=use
    use:SetSize(132,32)
    use:SetPoint("BOTTOM",content,"BOTTOM",0,12)
    BuildCardFrame(use)
    use.gem:SetSize(7,18);use.gem:SetPoint("CENTER",use,"LEFT",1,0)
    local rightGem=use:CreateTexture(nil,"OVERLAY",nil,2)
    rightGem:SetTexture(CARD_GEM);rightGem:SetSize(7,18)
    rightGem:SetPoint("CENTER",use,"RIGHT",-1,0)
    local glow=use:CreateTexture(nil,"ARTWORK")
    use.glow=glow
    glow:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\Nexus\\NexusGlow")
    glow:SetBlendMode("ADD");glow:SetPoint("CENTER");glow:SetSize(122,30);glow:SetAlpha(.12)
    local emblem=use:CreateTexture(nil,"OVERLAY")
    emblem:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\Nexus\\IconActions")
    emblem:SetSize(20,20);emblem:SetPoint("LEFT",12,0)
    use.emblem=emblem
    local label=use:CreateFontString(nil,"OVERLAY","GameFontNormal")
    label:SetPoint("CENTER",9,0);label:SetText("Utiliser")
    label:SetTextColor(.94,.81,.53);label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1,-1)
    use.label=label
    local shine,target=.12,.12
    local function FadeTo(value)
        target=value
        use:SetScript("OnUpdate",function(self,dt)
            local step=dt*3
            if shine<target then shine=math.min(target,shine+step) else shine=math.max(target,shine-step) end
            glow:SetAlpha(shine)
            if shine==target then self:SetScript("OnUpdate",nil) end
        end)
    end
    -- Grisé (ressource insuffisante) : pas de lueur, la raison au survol.
    use:SetScript("OnEnter",function(self)
        if self.blocked then C:ShowSkillNotice(self,self.blocked);return end
        FadeTo(.6);label:SetTextColor(1,.93,.72)
    end)
    use:SetScript("OnLeave",function(self)
        C:HideSkillName()
        if self.blocked then return end
        FadeTo(.12);label:SetTextColor(.94,.81,.53)
    end)
    use:SetScript("OnMouseDown",function(self)
        if self.blocked then return end
        label:SetPoint("CENTER",9,-1);glow:SetAlpha(.8)
    end)
    use:SetScript("OnMouseUp",function(self)
        if self.blocked then return end
        label:SetPoint("CENTER",9,0);glow:SetAlpha(shine)
    end)
    use:SetScript("OnHide",function(self)
        self:SetScript("OnUpdate",nil);shine=.12;target=.12;glow:SetAlpha(self.blocked and 0 or .12)
        label:SetPoint("CENTER",9,0)
        if self.blocked then label:SetTextColor(.5,.5,.5) else label:SetTextColor(.94,.81,.53) end
    end)
    card.useButton:SetScript("OnClick",function(self)
        if self.blocked then return end
        if card.skill and C.OpenSkillUse then C:OpenSkillUse(card.skill) end
    end)
    card.useButton:Hide()
    -- Filet de balayage sur le bord qui avance pendant l'ouverture.
    card.edge = card:CreateTexture(nil, "OVERLAY")
    card.edge:SetColorTexture(.85, .70, .42, 1)
    card.edge:Hide()
    card.flux = FluxFrame()
    -- Corps : texte enrichi (C.RichText), blanc par défaut, posé dans le contenu.
    C:EnableSkillLinks(content, depth)
    card:SetScript("OnHide", function()
        card.closeButton:Hide()
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
        local y = CardLinkY(card) or select(2, ToUI(source, 0, sourceBottom or 0))
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
    local fromChat=depth==1 and anchor.isSkillChatAnchor
    card.closeButton:SetShown(fromChat or false)
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
    card.skill=skill
    local usable=skill.usable == true and not skill.missing
    card.useButton:SetShown(usable)
    UpdateUseButton(card)
    if usable then height=height+46 end
    if not card.costLabel then
        card.costLabel=content:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        UI.ApplyTitle(card.costLabel)
    end
    card.costLabel:ClearAllPoints()
    card.costLabel:SetPoint("BOTTOM",content,"BOTTOM",0,usable and 51 or 12)
    card.costLabel:SetShown(skill.cost~=nil)
    if skill.cost then
        card.costLabel:SetText("Coût : "..skill.cost.amount.." "..(({hp="Vie",mana="Mana",endurance="Endurance"})[skill.cost.resource] or ""))
        height=height+22
    end
    card.rule:SetShown(body ~= "")
    content:SetSize(width, height)

    -- Toujours au-dessus de la carte / du cadre qui l'ouvre (pour une
    -- référence, la carte précédente, pas son contenu).
    local below = depth > 1 and cards[depth - 1] or anchor
    card.source = anchor
    if depth > 1 then
        cardWatcher:Show()
        -- Hauteur du lien survolé (curseur), relative au haut de la source.
        local top = anchor:GetTop()
        card.linkOffset = top and (CursorY() - select(2, ToUI(anchor, 0, top))) or nil
    else
        card.linkOffset = nil
    end
    card:SetFrameLevel((below:GetFrameLevel() or 0) + 20)
    card.closeButton:SetFrameLevel(card:GetFrameLevel()+3)
    card:ClearAllPoints()
    local side = "UP"
    if depth == 1 then
        card:SetPoint("BOTTOM", anchor, "TOP", 0, LINK_GAP)
    else
        local right = anchor:GetRight() or 0
        local screen = UIParent:GetRight() or 0
        -- Centrée sur la hauteur du lien survolé : le flux arrive au milieu
        -- de son bord (l'écran la garde entière, SetClampedToScreen).
        local dy = card.linkOffset or -height / 2
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
-- Ressources modifiées : le bouton « Utiliser » affiché se regrise ou se ravive.
local previousDataChanged = C.OnMyDataChanged
C.OnMyDataChanged = function(...)
    if previousDataChanged then previousDataChanged(...) end
    local card = cards[1]
    if card and card:IsShown() and card.skill then UpdateUseButton(card) end
end
-- Vrai seulement si la carte principale est affichée pour ce cadre.
function C:IsSkillTooltipOpenFor(owner)
    local card = cards[1]
    return card ~= nil and card:IsShown() and card.source == owner
end

-- Survol d'un bouton de compétence : juste le nom, même habillage.
local nameTip
-- note : message en blanc (ex. raison d'un « Utiliser » grisé) au lieu d'un nom.
local function ShowNameTip(owner, text, note)
    if not nameTip then
        nameTip = CreateFrame("Frame", "CharacterSkillNameTip", UIParent)
        nameTip:SetFrameStrata("TOOLTIP"); nameTip:SetClampedToScreen(true)
        BuildCardFrame(nameTip)
        nameTip.gem:Hide()
        nameTip.title = nameTip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameTip.title:SetPoint("LEFT", CARD_PAD, 0); nameTip.title:SetWordWrap(false)
        nameTip.note = nameTip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameTip.note:SetPoint("LEFT", CARD_PAD, 0); nameTip.note:SetWordWrap(false)
        nameTip.note:SetTextColor(1, 1, 1)
        UI.ApplyTitle(nameTip.title)
    end
    GameTooltip:Hide()
    local fs = note and nameTip.note or nameTip.title
    nameTip.title:SetShown(not note); nameTip.note:SetShown(note or false)
    fs:SetText(text)
    nameTip:SetSize(math.min(CARD_MAX_W, TextWidth(fs) + CARD_PAD * 2), CARD_HEAD + 2)
    nameTip:SetFrameLevel((owner:GetFrameLevel() or 0) + 40)
    nameTip:ClearAllPoints(); nameTip:SetPoint("BOTTOM", owner, "TOP", 0, 6)
    nameTip:Show()
end
function C:ShowSkillName(owner, skill)
    ShowNameTip(owner, C:RenderSkillName(skill.name))
end
-- Même habillage, un message : raison du bouton « Utiliser » grisé.
function C:ShowSkillNotice(owner, text) ShowNameTip(owner, text, true) end

function C:HideSkillName() if nameTip then nameTip:Hide() end end

-- ============================================================
--  Builder : Paramètres -> Base de données
-- ============================================================
local PANEL_W, PANEL_H = 740, 650
local LIST_W = 196

local panel, tabButtons, listContent, listViewport
local nameEB, iconEB, iconPreview, descEB, descPreview, statusFS, colorTarget
local searchEB, listCount, descViewport, previewViewport
local costCB,costAmount,costHolder,costChoices
local usableCB
local costResource="mana"
-- A cost only exists on usable skills: the whole cost row follows the Usable box.
local function SyncCostVisibility()
    if not costCB then return end
    local usable=usableCB:GetChecked()
    costCB:SetShown(usable);costCB.label:SetShown(usable)
    costHolder:SetShown(usable and costCB:GetChecked())
end
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
    if usableCB then usableCB:SetChecked(false) end
    if costCB then costCB:SetChecked(false);costAmount:SetText("");costResource="mana";costChoices:Refresh();SyncCostVisibility() end
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
    if usableCB then usableCB:SetChecked(skill.usable == true) end
    if costCB then costCB:SetChecked(skill.cost~=nil);costResource=skill.cost and skill.cost.resource or "mana";costAmount:SetText(skill.cost and tostring(skill.cost.amount) or "");costChoices:Refresh();SyncCostVisibility() end
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
    -- Un filet entre deux onglets ; entre les catégories d'Action et les
    -- indicatives (Index, États), un losange à la place du filet (même
    -- espacement partout, seul l'ornement marque la séparation).
    tabButtons = {}
    local tabW = (PANEL_W - 20) / #CATEGORIES
    local tabX, reach = 10, 0
    for i, cat in ipairs(CATEGORIES) do
        if i > 1 and cat.hidden and not CATEGORIES[i - 1].hidden then
            local cx = tabX - 1
            for _, dy in ipairs({ -10, 10 }) do
                local line = panel:CreateTexture(nil, "ARTWORK")
                line:SetSize(1, 6); line:SetPoint("CENTER", panel, "TOPLEFT", cx, -41 + dy)
                UI.ApplySeparator(line)
            end
            local gem = panel:CreateTexture(nil, "OVERLAY")
            gem:SetTexture(CARD_GEM); gem:SetSize(7, 14)
            gem:SetPoint("CENTER", panel, "TOPLEFT", cx, -41)
            -- Le soulignage des deux onglets voisins s'arrête au bord du losange.
            tabButtons[i - 1].line:SetPoint("BOTTOMRIGHT", -3, 0)
            reach = -3
        elseif i > 1 then
            local line = panel:CreateTexture(nil, "ARTWORK")
            line:SetSize(1, 12); line:SetPoint("CENTER", panel, "TOPLEFT", tabX - 1, -41)
            UI.ApplySeparator(line, true)
        end
        local btn = CreateFrame("Button", nil, panel)
        btn:SetSize(tabW - 2, 22)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", tabX, -30)
        tabX = tabX + tabW
        btn.cat = cat
        local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints(); label:SetJustifyH("CENTER"); label:SetText(cat.tag=="Action" and "Actions de base" or cat.tag)
        local line = btn:CreateTexture(nil, "ARTWORK")
        line:SetPoint("BOTTOMLEFT", -reach, 0); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(2); reach = 0
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
    local function HeaderIcon(button,kind)
        local icon=CreateFrame("Frame",nil,button)
        icon:SetSize(22,22);icon:SetPoint("LEFT",8,0);icon:EnableMouse(false)
        local function Path(points)
            for i=1,#points-1 do
                local a,b=points[i],points[i+1]
                local dx,dy=b[1]-a[1],b[2]-a[2]
                local stroke=icon:CreateTexture(nil,"OVERLAY")
                stroke:SetColorTexture(.88,.74,.46,1)
                stroke:SetSize(math.sqrt(dx*dx+dy*dy),1.3)
                stroke:SetPoint("CENTER",icon,"CENTER",(a[1]+b[1])/2,(a[2]+b[2])/2)
                local angle=dx==0 and (dy>0 and math.pi/2 or -math.pi/2) or math.atan(dy/dx)+(dx<0 and math.pi or 0)
                stroke:SetRotation(angle)
            end
        end
        if kind=="books" then
            Path({{-9,-7},{-9,7},{-4,7},{-4,-7},{-9,-7}})
            Path({{-2,-7},{-2,9},{3,9},{3,-7},{-2,-7}})
            Path({{6,-7},{3,6},{7,7},{10,-6},{6,-7}})
            Path({{-8,-3},{-5,-3}});Path({{-1,5},{2,5}})
        elseif kind=="lock" then
            Path({{-7,-8},{-7,2},{7,2},{7,-8},{-7,-8}})
            Path({{-4,2},{-4,7},{-2,9},{2,9},{4,7},{4,2}})
            Path({{0,-1},{0,-5}})
        else
            Path({{-9,-6},{-9,6},{9,6},{9,-6},{-9,-6}})
            Path({{-9,6},{0,-1},{9,6}})
            Path({{-9,-6},{-3,-1}});Path({{9,-6},{3,-1}})
        end
        return icon
    end
    local ownerBtn=UI.CreatePanelButton(panel,PANEL_W-270,28,"Ma bibliothèque")
    ownerBtn:SetPoint("TOPLEFT",10,-60)
    ownerBtn.library=true
    local ownerText=ownerBtn:GetFontString()
    ownerText:ClearAllPoints();ownerText:SetPoint("LEFT",36,0);ownerText:SetPoint("RIGHT",-30,0);ownerText:SetJustifyH("CENTER")
    HeaderIcon(ownerBtn,"books")
    local arrow=ownerBtn:CreateTexture(nil,"OVERLAY")
    arrow:SetSize(12,12);arrow:SetPoint("RIGHT",-10,0)
    arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
    local sendBtn=UI.CreatePanelButton(panel,152,28,"Envoyer au raid")
    sendBtn:SetPoint("TOPRIGHT",-10,-60)
    local envelope=HeaderIcon(sendBtn,"envelope")
    sendBtn:GetFontString():SetPoint("LEFT",34,0)
    local function ResetEnvelope()
        envelope:SetScript("OnUpdate",nil);envelope:SetAlpha(1)
        envelope:ClearAllPoints();envelope:SetPoint("LEFT",sendBtn,"LEFT",8,0)
    end
    sendBtn:HookScript("OnHide",ResetEnvelope)
    local function FlyEnvelope()
        local elapsed=0
        envelope:SetScript("OnUpdate",function(_,dt)
            elapsed=elapsed+dt;local t=math.min(1,elapsed/.65)
            envelope:ClearAllPoints()
            envelope:SetPoint("LEFT",sendBtn,"LEFT",8+110*t*t,12*math.sin(t*math.pi/2))
            envelope:SetAlpha(1-t)
            if t>=1 then ResetEnvelope() end
        end)
    end
    local function OwnerName(owner)
        if owner==COMMON then return "Bibliothèque commune" end
        return owner:match("^[^-]+") or owner
    end
    local function LibraryCount(categories)
        local count=0
        for _,cat in ipairs(CATEGORIES) do for _ in pairs(categories and categories[cat.key] or {}) do count=count+1 end end
        return count
    end
    local rightsBtn=UI.CreatePanelButton(panel,86,28,"Droits")
    rightsBtn:SetPoint("RIGHT",sendBtn,"LEFT",-6,0)
    HeaderIcon(rightsBtn,"lock")
    rightsBtn:GetFontString():SetPoint("LEFT",32,0)
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
        if usableCB then usableCB:SetEnabled(editable) end
        if costCB then costCB:SetEnabled(editable) end
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
                row:SetSize(ownerBtn:GetWidth()-16,26);row:SetPoint("TOPLEFT",8,-8-(i-1)*26)
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
        libraryMenu:SetSize(ownerBtn:GetWidth(),#owners*26+16)
        libraryMenu:ClearAllPoints();libraryMenu:SetPoint("TOPLEFT",ownerBtn,"BOTTOMLEFT",0,-2)
        libraryMenu:Show()
    end
    panel.OpenLibraryMenu=OpenLibraryMenu
    ownerBtn:SetScript("OnClick",function()
        GameTooltip:Hide()
        if libraryMenu and libraryMenu:IsShown() then libraryMenu:Hide() else OpenLibraryMenu() end
    end)
    -- ── Partage : tout, ou seulement certaines entrées (votre bibliothèque).
    -- Le choix est retenu d'un envoi à l'autre (CharacterDB.skillShare).
    local sharePanel
    local function ShareState()
        CharacterDB.skillShare=CharacterDB.skillShare or {}
        local state=CharacterDB.skillShare
        state.mode=state.mode=="some" and "some" or "all"
        state.picked=state.picked or {}
        return state
    end
    local function Send(picked)
        local ok,message=C:SendSkillLibrary(picked)
        ShowStatus(message,not ok)
        if ok then FlyEnvelope();if sharePanel then sharePanel:Hide() end end
    end
    local SHARE_W,SHARE_LIST_TOP,SHARE_LIST_H,SHARE_ROW=280,76,240,20
    local shareRows={}
    local function RefreshShare()
        local state=ShareState()
        local some=state.mode=="some"
        sharePanel.choice:Refresh()
        sharePanel.viewport:SetShown(some);sharePanel.allBtn:SetShown(some);sharePanel.noneBtn:SetShown(some)
        local db,lines,picked=C:GetOwnedSkillLibrary(),{},0
        for _,cat in ipairs(CATEGORIES) do
            local skills={}
            for name,skill in pairs(db[cat.key] or {}) do skills[#skills+1]=skill end
            if #skills>0 then
                table.sort(skills,function(x,y) return C:SkillSortKey(x.name)<C:SkillSortKey(y.name) end)
                lines[#lines+1]={header=cat.label}
                for _,skill in ipairs(skills) do
                    local checked=state.picked[cat.key] and state.picked[cat.key][skill.name] or false
                    if checked then picked=picked+1 end
                    lines[#lines+1]={cat=cat.key,skill=skill,checked=checked}
                end
            end
        end
        for i,line in ipairs(lines) do
            local row=shareRows[i]
            if not row then
                row=CreateFrame("Button",nil,sharePanel.content);row:SetSize(SHARE_W-36,SHARE_ROW)
                row:SetPoint("TOPLEFT",8,-4-(i-1)*SHARE_ROW)
                row.header=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                row.header:SetPoint("LEFT",2,0);UI.ApplyTitle(row.header)
                row.check=UI.CreateStyledCheckbox(row,"");row.check:SetPoint("LEFT",10,0)
                row.check.label:SetPoint("RIGHT",row,"RIGHT",-4,0);row.check.label:SetJustifyH("LEFT");row.check.label:SetWordWrap(false)
                local function Toggle()
                    local entry=row.line;if not entry or entry.header then return end
                    local byCat=ShareState().picked
                    byCat[entry.cat]=byCat[entry.cat] or {}
                    byCat[entry.cat][entry.skill.name]=(not entry.checked) or nil
                    RefreshShare()
                end
                row.check:SetScript("OnClick",Toggle);row:SetScript("OnClick",Toggle)
                shareRows[i]=row
            end
            row.line=line
            row.header:SetShown(line.header~=nil);row.check:SetShown(line.header==nil);row.check.label:SetShown(line.header==nil)
            if line.header then row.header:SetText(line.header)
            else row.check.label:SetText(C:RenderSkillName(line.skill.name));row.check:SetChecked(line.checked) end
            row:Show()
        end
        for i=#lines+1,#shareRows do shareRows[i]:Hide() end
        sharePanel.content:SetHeight(#lines*SHARE_ROW+8)
        sharePanel.empty:SetShown(some and #lines==0)
        local total=0;for _,line in ipairs(lines) do if not line.header then total=total+1 end end
        sharePanel.hint:SetText(some and ("Le raid ne verra que les entrées cochées ("..picked.." / "..total..").")
            or "Toute votre bibliothèque est envoyée au raid.")
        -- Pile verticale : choix, (liste, cocher/décocher), aide, Envoyer.
        local hintTop=some and SHARE_LIST_TOP+SHARE_LIST_H+36 or SHARE_LIST_TOP
        sharePanel.hint:ClearAllPoints()
        sharePanel.hint:SetPoint("TOPLEFT",10,-hintTop);sharePanel.hint:SetPoint("RIGHT",-10,0)
        sharePanel.send:SetEnabled(not some or picked>0)
        sharePanel:SetHeight(hintTop+math.ceil(sharePanel.hint:GetStringHeight() or 12)+10+26+8)
    end
    local function BuildShare()
        sharePanel=CreateFrame("Frame","CharacterSkillShare",panel)
        sharePanel:SetFrameStrata("FULLSCREEN_DIALOG");sharePanel:SetFrameLevel(panel:GetFrameLevel()+60)
        sharePanel:SetWidth(SHARE_W);sharePanel:EnableMouse(true)
        sharePanel:SetPoint("TOPRIGHT",sendBtn,"BOTTOMRIGHT",0,-4)
        local bg=sharePanel:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();UI.ApplyWindowBackground(bg,.98);UI.ApplyBorder(sharePanel)
        local title=sharePanel:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("TOPLEFT",10,-8);title:SetText("Partager au raid");UI.ApplyTitle(title)
        sharePanel.choice=UI.CreateChoiceStrip(sharePanel,SHARE_W-16,"Entrées partagées",{
            {label="Tout",value="all"},{label="Certaines entrées",value="some"},
        },function() return ShareState().mode end,function(value) ShareState().mode=value;RefreshShare() end)
        sharePanel.choice:SetPoint("TOPLEFT",8,-30)
        local viewport=CreateFrame("ScrollFrame",nil,sharePanel)
        viewport:SetPoint("TOPLEFT",10,-SHARE_LIST_TOP);viewport:SetSize(SHARE_W-20,SHARE_LIST_H)
        UI.ApplyInputBorder(viewport)
        viewport:EnableMouseWheel(true)
        viewport:SetScript("OnMouseWheel",function(self,delta)
            self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*SHARE_ROW*2)))
        end)
        local content=CreateFrame("Frame",nil,viewport);content:SetSize(SHARE_W-20,1)
        viewport:SetScrollChild(content)
        sharePanel.viewport,sharePanel.content=viewport,content
        sharePanel.empty=sharePanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        sharePanel.empty:SetPoint("CENTER",viewport,"CENTER");sharePanel.empty:SetText("Votre bibliothèque est vide.")
        UI.ApplyMutedText(sharePanel.empty)
        local function SetAll(on)
            local state=ShareState();state.picked={}
            if on then
                local db=C:GetOwnedSkillLibrary()
                for _,cat in ipairs(CATEGORIES) do
                    for name in pairs(db[cat.key] or {}) do state.picked[cat.key]=state.picked[cat.key] or {};state.picked[cat.key][name]=true end
                end
            end
            RefreshShare()
        end
        sharePanel.allBtn=UI.CreatePanelButton(sharePanel,(SHARE_W-24)/2,22,"Tout cocher")
        sharePanel.allBtn:SetPoint("TOPLEFT",viewport,"BOTTOMLEFT",0,-6)
        sharePanel.allBtn:SetScript("OnClick",function() SetAll(true) end)
        sharePanel.noneBtn=UI.CreatePanelButton(sharePanel,(SHARE_W-24)/2,22,"Tout décocher")
        sharePanel.noneBtn:SetPoint("TOPRIGHT",viewport,"BOTTOMRIGHT",0,-6)
        sharePanel.noneBtn:SetScript("OnClick",function() SetAll(false) end)
        sharePanel.hint=sharePanel:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        sharePanel.hint:SetJustifyH("LEFT");UI.ApplyMutedText(sharePanel.hint)
        sharePanel.send=UI.CreatePanelButton(sharePanel,SHARE_W-16,26,"Envoyer au raid")
        sharePanel.send:SetPoint("BOTTOMLEFT",8,8)
        sharePanel.send:SetScript("OnClick",function()
            local state=ShareState()
            Send(state.mode=="some" and state.picked or nil)
        end)
        sharePanel:Hide()
    end
    sendBtn:SetScript("OnClick",function()
        -- Bibliothèque d'un créateur (éditeur) : toujours renvoyée entière.
        if selectedOwner then Send();return end
        if not sharePanel then BuildShare() end
        if sharePanel:IsShown() then sharePanel:Hide();return end
        if rightsPanel then rightsPanel:Hide() end
        RefreshShare();sharePanel:Show()
    end)
    panel:HookScript("OnHide",function() if sharePanel then sharePanel:Hide() end end)
    -- Changer de bibliothèque (menu du bouton) ferme le partage.
    ownerBtn:HookScript("OnClick",function() if sharePanel then sharePanel:Hide() end end)
    local previousSkillsChanged=C.OnSkillsChanged
    C.OnSkillsChanged=function(...)
        if previousSkillsChanged then previousSkillsChanged(...) end
        if sharePanel and sharePanel:IsShown() then RefreshShare() end
    end
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
        GameTooltip:Hide()
        if not rightsPanel then BuildRights() end
        if rightsPanel:IsShown() then rightsPanel:Hide() else
            if sharePanel then sharePanel:Hide() end
            RefreshRights();rightsPanel:Show()
        end
    end)
    rightsBtn:HookScript("OnEnter",function(self)
        -- Panneau ouvert : l'explication est déjà dedans.
        if rightsPanel and rightsPanel:IsShown() then return end
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
        GameTooltip:AddLine("Droits d'édition",unpack(UI.colors.title))
        GameTooltip:AddLine("Ciblez un joueur et donnez-lui le droit de modifier votre bibliothèque et de la renvoyer au raid sous votre nom.",1,1,1,true)
        GameTooltip:Show()
    end)
    rightsBtn:HookScript("OnLeave",function() GameTooltip:Hide() end)
    panel:HookScript("OnHide",function() if rightsPanel then rightsPanel:Hide() end end)
    ownerBtn:HookScript("OnEnter",function(self)
        if libraryMenu and libraryMenu:IsShown() then return end
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
    nameLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX + 62, -96)
    nameLbl:SetText("Nom de l’entrée"); UI.ApplyLabel(nameLbl)
    nameEB = UI.CreateStyledEditBox(panel, formW - 62, 24)
    nameEB:SetPoint("TOPLEFT", panel, "TOPLEFT", formX + 62, -112)
    nameEB:SetMaxLetters(128)

    iconPreview = CreateFrame("Button", nil, panel)
    iconPreview:SetSize(48, 48)
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

    usableCB = UI.CreateStyledCheckbox(panel,"Utilisable")
    usableCB:SetPoint("TOPLEFT",panel,"TOPLEFT",formX,-154)
    usableCB:SetChecked(false)
    panel.usableCB=usableCB
    costCB=UI.CreateStyledCheckbox(panel,"Coût")
    costCB:SetPoint("TOPLEFT",panel,"TOPLEFT",formX+110,-154)
    costHolder=CreateFrame("Frame",nil,panel)
    costHolder:SetPoint("TOPLEFT",panel,"TOPLEFT",formX+176,-152);costHolder:SetSize(formW-176,24)
    costChoices=UI.CreateChoiceStrip(costHolder,222,nil,{
        {label="Vie",value="hp"},{label="Mana",value="mana"},{label="End.",value="endurance"}
    },function() return costResource end,function(value) if not C:IsSkillLibraryReadOnly() then costResource=value end end)
    costChoices:SetPoint("LEFT",0,0)
    costAmount=UI.CreateStyledEditBox(costHolder,64,22)
    costAmount:SetPoint("LEFT",costChoices,"RIGHT",8,0);costAmount:SetNumeric(true);costAmount:SetMaxLetters(7)
    costCB:SetScript("OnClick",SyncCostVisibility)
    usableCB:SetScript("OnClick",SyncCostVisibility)
    SyncCostVisibility();panel.costCB=costCB;panel.costAmount=costAmount
    local descLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -184)
    descLbl:SetText("Description"); UI.ApplyLabel(descLbl)
    -- Barre d'outils : agit sur le texte sélectionné dans la description.
    local RT = C.RichText
    local NOTO = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\Fonts\\NotoSans-"
    local editor=CreateFrame("Frame",nil,panel)
    editor:SetPoint("TOPLEFT",panel,"TOPLEFT",formX,-204)
    editor:SetSize(formW,230);UI.ApplyInputBorder(editor)
    panel.descriptionEditor=editor
    local headerBg=editor:CreateTexture(nil,"ARTWORK")
    headerBg:SetPoint("TOPLEFT",1,-1);headerBg:SetPoint("TOPRIGHT",-1,-1)
    headerBg:SetHeight(37);headerBg:SetColorTexture(.035,.049,.071,1)
    local headerRule=editor:CreateTexture(nil,"OVERLAY")
    headerRule:SetPoint("TOPLEFT",1,-38);headerRule:SetPoint("TOPRIGHT",-1,-38)
    headerRule:SetHeight(1);headerRule:SetColorTexture(.62,.49,.28,.65)
    local toolbar = CreateFrame("Frame", nil, editor)
    toolbar:SetPoint("TOPLEFT",8,-6)
    toolbar:SetSize(formW-16, 26)
    panel.toolbar = toolbar
    local toolX,toolY = 0,0
    local function Tool(key, w, label, tip, onClick)
        w=math.max(w,24)
        local btn=CreateFrame("Button",nil,toolbar)
        btn:SetSize(w,26)
        local backing=btn:CreateTexture(nil,"BACKGROUND")
        backing:SetAllPoints();backing:SetColorTexture(.065,.083,.11,.9)
        local accent=btn:CreateTexture(nil,"BORDER")
        accent:SetPoint("BOTTOMLEFT",3,0);accent:SetPoint("BOTTOMRIGHT",-3,0)
        accent:SetHeight(1);accent:SetColorTexture(.65,.51,.29,.5)
        local text=btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        text:SetPoint("LEFT",4,0);text:SetPoint("RIGHT",-4,0)
        text:SetJustifyH("CENTER");text:SetWordWrap(false);text:SetText(label);UI.ApplyTitle(text)
        btn:SetFontString(text)
        local hover=btn:CreateTexture(nil,"HIGHLIGHT")
        hover:SetPoint("TOPLEFT",1,-1);hover:SetPoint("BOTTOMRIGHT",-1,1)
        hover:SetColorTexture(.7,.53,.25,.18)
        btn:SetPoint("TOPLEFT",toolbar,"TOPLEFT",toolX,toolY)
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
    local function Gap()
        local divider=toolbar:CreateTexture(nil,"ARTWORK")
        divider:SetPoint("TOPLEFT",toolX+1,toolY-5);divider:SetSize(1,16)
        divider:SetColorTexture(.62,.49,.28,.35)
        toolX=toolX+5
    end
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
    sizeLabel:SetPoint("TOPLEFT", toolbar, "TOPLEFT", toolX, -7); sizeLabel:SetWidth(22)
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

    -- Référence, couleur du texte, surlignage, effacer la mise en forme.
    Tool("lien", 50, "{{ Lien", "Insérer une référence (puis choisir dans la liste)", function() InsertReference(descEB) end)
    local colorBtn = Tool("couleur", 20, "A", "Couleur du texte", function() PickColor(colorTarget or descEB, "couleur") end)
    Glyph(colorBtn, "Bold.ttf", 12)
    local colorBar = colorBtn:CreateTexture(nil, "OVERLAY")
    colorBar:SetSize(12, 3); colorBar:SetPoint("BOTTOM", 0, 3)
    colorBar:SetColorTexture(lastColor.r, lastColor.g, lastColor.b)
    toolbarSwatches.couleur = colorBar
    local bgBtn = Tool("fond", 26, "ab", "Surligner", function() PickColor(colorTarget or descEB, "fond") end)
    Glyph(bgBtn, "Regular.ttf", 11)
    local bgSwatch = bgBtn:CreateTexture(nil, "ARTWORK")
    bgSwatch:SetPoint("TOPLEFT", 3, -4); bgSwatch:SetPoint("BOTTOMRIGHT", -3, 4)
    bgSwatch:SetColorTexture(lastBg.r, lastBg.g, lastBg.b)
    toolbarSwatches.fond = bgSwatch
    local clearBtn = Tool("effacer", 58, "Effacer", "Effacer la mise en forme de la sélection", function() ClearFormatting(colorTarget or descEB) end)
    local clearIcon = clearBtn:CreateTexture(nil, "OVERLAY")
    clearIcon:SetSize(12, 12); clearIcon:SetPoint("CENTER");clearIcon:Hide()
    clearIcon:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")

    descViewport=CreateFrame("ScrollFrame",nil,editor)
    descViewport:SetPoint("TOPLEFT",1,-39);descViewport:SetSize(formW-2,190)
    descEB=CreateFrame("EditBox",nil,descViewport)
    descEB:SetWidth(formW-2);descEB:SetHeight(190);descEB:SetMultiLine(true);descEB:SetAutoFocus(false)
    descEB:SetFontObject("GameFontHighlightSmall");descEB:SetTextInsets(6,6,6,6);descEB:SetMaxLetters(6000)
    descViewport:SetScrollChild(descEB);descViewport:EnableMouseWheel(true)
    -- Any click in the framed area focuses the editor, even below the last line.
    descViewport:EnableMouse(true)
    descViewport:SetScript("OnMouseDown",function() descEB:SetFocus();descEB:SetCursorPosition(#descEB:GetText()) end)
    descViewport:SetScript("OnMouseWheel",function(self,d) self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-d*18))) end)
    descEB:SetScript("OnCursorChanged",function(_,_,y,_,height)
        local top=math.abs(y);local scroll=descViewport:GetVerticalScroll()
        if top<scroll then descViewport:SetVerticalScroll(top)
        elseif top+height>scroll+190 then descViewport:SetVerticalScroll(math.max(0,top+height-190)) end
    end)

    local legend = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -444)
    legend:SetPoint("RIGHT", panel, "RIGHT", -10, 0)
    legend:SetJustifyH("LEFT"); legend:SetWordWrap(true)
    legend:SetText("Sélectionnez un texte pour le mettre en forme. Tapez {{ pour lier une fiche. Couleur et Effacer fonctionnent aussi sur le nom.")
    UI.ApplyMutedText(legend)

    local previewLbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    previewLbl:SetPoint("TOPLEFT", panel, "TOPLEFT", formX, -478)
    previewLbl:SetText("Aperçu de la fiche"); UI.ApplyLabel(previewLbl)
    previewViewport=CreateFrame("ScrollFrame",nil,panel)
    previewViewport:SetPoint("TOPLEFT",panel,"TOPLEFT",formX,-496);previewViewport:SetSize(formW,84)
    UI.ApplyInputBorder(previewViewport)
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

    local saveBtn = UI.CreatePanelButton(panel, 126, 28, "Enregistrer")
    saveControl=saveBtn
    saveBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -10, 32)
    saveBtn:SetScript("OnClick", function()
        local ok, err = C:SaveSkill(activeCat.key, editingName, nameEB:GetText(), iconEB:GetText(), descEB:GetText(), usableCB:GetChecked(), usableCB:GetChecked() and costCB:GetChecked() and {resource=costResource,amount=costAmount:GetText()} or nil)
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
    deleteBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", formX, 35)
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
