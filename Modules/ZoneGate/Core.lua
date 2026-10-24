-- ============================================================
--  Zone Gate — Core
--  Pays (classeur de rangement) › Région (= Zone) › Lieux.
--  Une région porte ses lieux (nom, bannière, effets, découverte)
--  et ses passages (zone.subZones) : de la géométrie seule —
--  passage droit ("line") ou périmètre ("polygon", voir
--  AddRegionPoint / FinishRegion ; les anciens cercles y sont
--  convertis, voir CircleToPerimeter). Un passage mène à un lieu
--  en entrant et, facultativement, à un autre lieu (de n'importe
--  quelle région) en sortant : la bannière affiche alors
--  "Région / Lieu" du lieu atteint. Les noms ne sont visibles que
--  pour l'auteur tant qu'il ne les a pas débloqués pour un joueur.
--  Diffusé en groupe/raid, en guilde, ET sur un canal global
--  "OmegaZoneGate" rejoint discrètement par tout client actif
--  (SendAddonMessage) — ce canal touche TOUT joueur ayant
--  l'addon, connecté ou non au même groupe/guilde (voir
--  BroadcastChannels).
-- ============================================================

ZoneGate = ZoneGate or {}
local ZG = ZoneGate
_G.ZoneGate = ZG

ZG.name = "ZoneGate"

local TICK_INTERVAL = 0.25   -- cohérent avec les tickers de Survive (Lantern/Torch)
local WIDTH_MARGIN   = 1.0   -- yards de tolérance (pas de poll / bord de la région)
local DEFAULT_WIDTH   = 6
local MAX_WIDTH        = 500  -- yards — de quoi couvrir l'entrée d'un village entier
local MAX_REGION_POINTS = 1500 -- grandes régions : jusqu'à ≈ 20 Ko par périmètre, envoyés au rythme toléré (voir PumpSend)

-- ── Thèmes de bannière ──────────────────────────────────────────────────────
-- Trois polices Blizzard natives ("classique", "abîmé/combat" Skurri,
-- "fantastique/parchemin" Morpheus — les seules du dossier Fonts\ du client
-- utilisables pour du texte français ; les autres fichiers sont des jeux de
-- glyphes cyrillique/chinois/coréen, inutilisables ici) + quatre polices
-- externes embarquées dans Modules/ZoneGate/Fonts/ (Google Fonts, licence
-- SIL Open Font License — voir les fichiers OFL-*.txt à côté), choisies pour
-- leur registre "épique RPG" et vérifiées "latin-ext" (couvre les accents
-- français). "custom" (voir customFont) permet en plus de pointer vers
-- n'importe quel autre fichier de police déjà présent chez vous.
local ADDON_FONT_DIR = "Interface\\AddOns\\Omega_Hub\\Modules\\ZoneGate\\Fonts\\"

ZG.FontPaths = {
    frizqt        = "Fonts\\FRIZQT__.TTF",
    skurri        = "Fonts\\SKURRI.TTF",
    morpheus      = "Fonts\\MORPHEUS.TTF",
    cinzel        = ADDON_FONT_DIR .. "Cinzel-Regular.ttf",
    metamorphous  = ADDON_FONT_DIR .. "Metamorphous-Regular.ttf",
    pirataone     = ADDON_FONT_DIR .. "PirataOne-Regular.ttf",
    medievalsharp = ADDON_FONT_DIR .. "MedievalSharp-Regular.ttf",
    marcellus     = ADDON_FONT_DIR .. "Marcellus-Regular.ttf",
    cormorantsc   = ADDON_FONT_DIR .. "CormorantSC-Regular.ttf",
    almendra      = ADDON_FONT_DIR .. "Almendra-Regular.ttf",
    amiri         = ADDON_FONT_DIR .. "Amiri-Regular.ttf",
    tajawal       = ADDON_FONT_DIR .. "Tajawal-Regular.ttf",
    rajdhani      = ADDON_FONT_DIR .. "Rajdhani-Regular.ttf",
    rye           = ADDON_FONT_DIR .. "Rye-Regular.ttf",
    forum         = ADDON_FONT_DIR .. "Forum-Regular.ttf",
    barlowcondensed = ADDON_FONT_DIR .. "BarlowCondensed-Regular.ttf",
    philosopher   = ADDON_FONT_DIR .. "Philosopher-Regular.ttf",
    caudex        = ADDON_FONT_DIR .. "Caudex-Regular.ttf",
}
ZG.FontLabels = {
    frizqt        = "Standard (FrizQT)",
    skurri        = "Rugueux (Skurri)",
    morpheus      = "Fantastique (Morpheus)",
    cinzel        = "Épique (Cinzel)",
    metamorphous  = "Runique (Metamorphous)",
    pirataone     = "Gothique (Pirata One)",
    medievalsharp = "Manuscrit (MedievalSharp)",
    marcellus     = "Sanctuaire (Marcellus)",
    cormorantsc   = "Poétique (Cormorant SC)",
    almendra      = "Conte ancien (Almendra)",
    amiri         = "Lettré (Amiri)",
    tajawal       = "Épuré (Tajawal)",
    rajdhani      = "Futuriste (Rajdhani)",
    rye           = "Western (Rye)",
    forum         = "Antique (Forum)",
    barlowcondensed = "Survie (Barlow Condensed)",
    philosopher   = "Voyage (Philosopher)",
    caudex        = "Chronique (Caudex)",
    custom        = "Personnalisée (chemin de fichier)",
}
ZG.FontOrder = {
    "frizqt", "skurri", "morpheus",
    "cinzel", "metamorphous", "pirataone", "medievalsharp",
    "marcellus", "cormorantsc", "almendra", "amiri", "tajawal",
    "rajdhani", "rye", "forum", "barlowcondensed", "philosopher", "caudex",
    "custom",
}

ZG.SepStyles = { "single", "double", "none" }
ZG.SepLabels = { single = "Simple", double = "Double", ["none"] = "Aucun" }

-- Cadre autour de toute la bannière — indépendant des séparateurs
-- (sepStyle/midSepEnabled) et du bandeau de fond (bgEnabled) : les trois se
-- cumulent librement. "box" = rectangle plein (aucune image, juste des
-- traits colorés — toujours disponible). "ornate" = coins en filigrane
-- (Media/FrameCorner.tga, dessiné pour ce thème — voir la section "Cadre"
-- dans UI_Theme.lua) reliés par les mêmes traits.
ZG.FrameStyles = { "none", "box", "ornate" }
ZG.FrameLabels = { ["none"] = "Aucun", box = "Simple", ornate = "Orné" }

-- ── Musiques (dossier Music/) ──────────────────────────────────────────────
-- WoW ne permet à aucun addon de lister le contenu d'un dossier au moment de
-- l'exécution (pas d'API Lua pour ça) — la liste vient donc d'un fichier
-- généré à l'avance, Music/Manifest.lua (ZoneGateMusicManifest, un nom de
-- fichier par entrée), à régénérer quand le contenu du dossier change (voir
-- Music/README.txt). GetMusicList() se contente d'y accoler le chemin.
ZG.MusicDir = "Interface\\AddOns\\Omega_Hub\\Modules\\ZoneGate\\Music\\"

function ZG:GetMusicList()
    local list = {}
    for _, fileName in ipairs(ZoneGateMusicManifest or {}) do
        local info=(ZoneGateSoundCatalog or {})[fileName]
        table.insert(list, { name = info and info.name or fileName, family = info and info.family,
            path = ZG.MusicDir .. fileName })
    end
    return list
end

-- Thème appliqué quand une Zone/Sous-zone n'a rien choisi — reproduit
-- exactement l'ancienne bannière codée en dur (aucune régression visuelle
-- pour qui n'utilise jamais les thèmes).
ZG.DefaultTheme = {
    design = "classic", motion = "fade", placement = "top", bannerWidth = 600,
    id = nil, name = "Défaut", creator = nil,
    font = "frizqt", customFont = "", titleSize = 28,
    titleColor = { 1.00, 0.90, 0.55 }, subColor = { 0.72, 0.68, 0.55 },
    outline = false, uppercase = false, letterSpacing = false,
    sepStyle = "single", sepColor = { 0.25, 0.25, 0.25, 1.00 }, midSepEnabled = false,
    bgEnabled = false, bgColor = { 0, 0, 0, 0.55 },
    frameStyle = "none", frameColor = { 0.82, 0.66, 0.20, 0.90 },
    fadeIn = 0.4, hold = 2.5, fadeOut = 0.8,
    soundEnter = "", soundExit = "",
}

local PREFIX     = "OmegaZoneGate"
local SEP        = ":"
local CHUNK_SIZE  = 200      -- comme INITIATIVE_CHUNK_SIZE dans Character/Core.lua

-- ── Identité / réseau (mêmes idiomes que Character/Core.lua et
--    Dice/Modules/Network.lua) ──────────────────────────────────────────────

local function MyName() return UnitName("player") or "" end

-- Un nom de personnage WoW ne contient jamais de "-" : celui-ci ne peut donc
-- provenir que d'un suffixe "-Royaume", qu'on retire pour comparer avec
-- MyName() qui n'en porte jamais.
local function StripRealm(name)
    return (name or ""):match("^([^%-]+)") or ""
end

local function GroupChat()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

-- ── Canal global (portée : TOUT joueur ayant l'addon, pas seulement groupe/
--    guilde) ──────────────────────────────────────────────────────────────
-- Un canal de discussion "custom" (comme utilisé par nombre d'addons —
-- Method Raid Tools, oQueue, etc. — pour leur propre bus de diffusion) que
-- CHAQUE client ZoneGate rejoint tout seul à l'activation, en silencieux
-- (hidden=true : pas d'onglet, pas de message système visible). C'est le
-- SEUL canal qui touche vraiment "tout le monde" sans connaître qui que ce
-- soit à l'avance et sans dépendre d'un groupe ou d'une guilde commune.
local BROADCAST_CHANNEL = "OmegaZoneGate"

local function EnsureBroadcastChannel()
    local id = GetChannelName and GetChannelName(BROADCAST_CHANNEL)
    if id and id > 0 then return id end
    if JoinChannelByName then
        JoinChannelByName(BROADCAST_CHANNEL, "", 0, true)
    end
    id = GetChannelName and GetChannelName(BROADCAST_CHANNEL)
    return (id and id > 0) and id or nil
end

-- Tous les canaux sur lesquels ce joueur peut diffuser SANS connaître la
-- cible à l'avance : groupe (RAID/PARTY), guilde, ET le canal global —
-- cumulés (pas un simple repli), chacun renvoyé comme { channel, target }
-- prêt à passer à SendAddon(payload, channel, target).
local function BroadcastChannels()
    local channels = {}
    local group = GroupChat()
    if group then table.insert(channels, { channel = group }) end
    if IsInGuild and IsInGuild() then table.insert(channels, { channel = "GUILD" }) end
    local chanId = EnsureBroadcastChannel()
    if chanId then table.insert(channels, { channel = "CHANNEL", target = chanId }) end
    return channels
end

local function SendAddon(payload, channel, target)
    if not payload or payload == "" or not channel then return false end
    if C_ChatInfo and C_ChatInfo.SendAddonMessage then
        return C_ChatInfo.SendAddonMessage(PREFIX, payload, channel, target)
    end
    if SendAddonMessage then
        return SendAddonMessage(PREFIX, payload, channel, target)
    end
    return false
end

-- Remplace les caractères qui serviraient de séparateurs dans le protocole.
local function Enc(s) return (tostring(s or ""):gsub("[:\n\r]", "_")) end

local netFrame = CreateFrame("Frame")

-- ── DB ───────────────────────────────────────────────────────────────────────

local function EnsureDB()
    ZoneGateDB = ZoneGateDB or {}
    ZoneGateDB.zones = ZoneGateDB.zones or {}
    ZoneGateDB.themes = ZoneGateDB.themes or {}
    ZoneGateDB.countries = ZoneGateDB.countries or {}
    for _, zone in pairs(ZoneGateDB.zones) do
        zone.subZones = zone.subZones or {}
        zone.places = zone.places or {}
    end
    return ZoneGateDB
end

function ZG:GetDB() return EnsureDB() end

-- Connaissance des joueurs : par personnage, pas par compte (OS2DB sert de
-- modèle — voir Modules/Survive/Core/Launcher.lua:409-411 pour le même
-- principe de set "[clé] = true" débloqué au fil du jeu).
-- Deux connaissances INDÉPENDANTES par personnage : le nom de la région et
-- le nom du lieu (learnedSubZones, clé = id du lieu). Elles se débloquent
-- séparément (voir SendZoneGrant / SendPlaceGrant) — d'où les 4 combinaisons
-- possibles à l'affichage (voir ResolveBannerText).
local function EnsureCharDB()
    ZoneGateCharDB = ZoneGateCharDB or {}
    ZoneGateCharDB.learnedZones    = ZoneGateCharDB.learnedZones or {}
    ZoneGateCharDB.learnedSubZones = ZoneGateCharDB.learnedSubZones or {}
    return ZoneGateCharDB
end

-- ── Position / facing joueur ───────────────────────────────────────────────

-- Renvoie x, y, facing (radians), instanceID — ou rien si indisponible.
-- Attention à l'ordre de retour de UnitPosition : y avant x.
function ZG:GetPlayerPose()
    local py, px, _, instanceID = UnitPosition("player")
    if not px then return nil end
    local facing = GetPlayerFacing() or 0
    return px, py, facing, instanceID
end

-- ── CRUD Pays (classeurs) ─────────────────────────────────────────────────
-- Un pays sert uniquement à ranger les régions dans le panneau : il
-- n'apparaît jamais dans la bannière.

local function NewId(prefix) return prefix .. time() .. "_" .. math.random(1000, 9999) end
local function Clean(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) or "" end

function ZG:CreateCountry(name)
    name = Clean(name)
    if name == "" then name = "Nouveau pays" end
    local db = EnsureDB()
    local id = NewId("c_")
    db.countries[id] = { id = id, name = name, creator = MyName() }
    ZG:ScheduleBroadcast()
    return db.countries[id]
end

function ZG:GetCountry(id)
    return id and EnsureDB().countries[id] or nil
end

function ZG:GetCountryList()
    local list = {}
    for _, country in pairs(EnsureDB().countries) do list[#list + 1] = country end
    table.sort(list, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    return list
end

function ZG:RenameCountry(id, name)
    local country = ZG:GetCountry(id)
    if not country or country.creator ~= MyName() then return end
    country.name = name or ""
    ZG:ScheduleBroadcast()
end

-- Les régions du pays supprimé restent intactes, simplement sans pays.
function ZG:RemoveCountry(id)
    local db = EnsureDB()
    local country = db.countries[id]
    if not country or country.creator ~= MyName() then return end
    db.countries[id] = nil
    for _, zone in pairs(db.zones) do
        if zone.countryId == id and zone.creator == MyName() then zone.countryId = nil end
    end
    ZG:ScheduleBroadcast()
end

-- ── CRUD Régions (= Zones) ───────────────────────────────────────────────────

function ZG:CreateZone(name, countryId)
    name = Clean(name)
    if name == "" then name = "Nouvelle région" end

    local db = EnsureDB()
    local id = NewId("z_")
    db.zones[id] = {
        id = id, name = name, creator = MyName(), subZones = {}, places = {},
        countryId = countryId,
        grantedTo = {},   -- [nom du joueur] = true — a appris le NOM DE LA RÉGION (local, jamais diffusé)
    }
    ZG:ScheduleBroadcast()
    return db.zones[id]
end

function ZG:RemoveZone(id)
    local db = EnsureDB()
    local zone = db.zones[id]
    if not zone or zone.creator ~= MyName() then return end
    db.zones[id] = nil
    -- Les passages d'autres régions qui menaient vers ses lieux mènent à "aucun".
    for placeId in pairs(zone.places) do ZG:ForgetPlaceLinks(placeId) end
    ZG:ScheduleBroadcast()
end

function ZG:RenameZone(id, name)
    local zone = ZG:GetZone(id)
    if not zone or zone.creator ~= MyName() then return end
    zone.name = name or ""
    ZG:ScheduleBroadcast()
end

function ZG:SetZoneCountry(zoneId, countryId)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return end
    local country = ZG:GetCountry(countryId)
    zone.countryId = (country and country.creator == MyName()) and countryId or nil
    ZG:ScheduleBroadcast()
end

function ZG:GetZoneList()
    local db = EnsureDB()
    local ids = {}
    for zid in pairs(db.zones) do table.insert(ids, zid) end
    table.sort(ids)

    local list = {}
    for _, zid in ipairs(ids) do table.insert(list, db.zones[zid]) end
    return list
end

function ZG:GetZone(id)
    return id and EnsureDB().zones[id] or nil
end

-- ── CRUD Lieux (= sous-zones) ────────────────────────────────────────────────
-- Un lieu appartient à une région : nom, bannière (sinon celle de la région),
-- effets (message / aura, sort Arcanum) et découverte de son nom. Il n'a
-- aucune géométrie : ce sont les passages qui y mènent.

local function NewPlace(id, zoneId, name)
    return {
        id = id, zoneId = zoneId, name = name,
        aliases = {},            -- anciens ids fusionnés (noms déjà appris par les joueurs)
        grantedTo = {},          -- [nom du joueur] = true — a appris le NOM DU LIEU (local, jamais diffusé)
        actionMessage = "",           -- texte imprimé localement (jamais visible d'autrui)
        actionCommand = "",           -- voir RunPlaceAction — ID d'aura (nombre) ou commande brute
        actionEnterEnabled = false,   -- action en arrivant dans le lieu (opt-in)
        actionLeaveEnabled = false,   -- action en quittant le lieu
        arcEnterSpell = "",      -- ArcSpell ID lancé en arrivant (voir ArcEnter)
        arcExitSpell  = "",      -- ArcSpell ID lancé en partant, pour défaire l'effet
        arcVault      = "phase", -- "phase" (partagé par la phase) ou "personal"
        arcToggle     = true,    -- le joueur peut retirer / remettre l'effet sur place
    }
end

-- Renvoie place, zone — cherche dans toutes les régions connues localement.
function ZG:FindPlace(placeId)
    if not placeId then return nil end
    for _, zone in pairs(EnsureDB().zones) do
        local place = zone.places and zone.places[placeId]
        if place then return place, zone end
    end
    return nil
end

local function MyPlace(id)
    local place, zone = ZG:FindPlace(id)
    if place and zone.creator == MyName() then return place, zone end
end

function ZG:GetPlaceList(zoneId)
    local zone = ZG:GetZone(zoneId)
    local list = {}
    if not zone then return list end
    for _, place in pairs(zone.places) do list[#list + 1] = place end
    table.sort(list, function(a, b)
        local x, y = (a.name or ""):lower(), (b.name or ""):lower()
        if x == y then return a.id < b.id end
        return x < y
    end)
    return list
end

function ZG:CreatePlace(zoneId, name)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return nil end
    name = Clean(name)
    if name == "" then
        local n = 0
        for _ in pairs(zone.places) do n = n + 1 end
        name = "Lieu " .. (n + 1)
    end
    local id = NewId("pl_")
    zone.places[id] = NewPlace(id, zoneId, name)
    ZG:ScheduleBroadcast()
    return zone.places[id]
end

function ZG:RenamePlace(id, name)
    local place = MyPlace(id)
    if not place then return end
    place.name = name or ""
    ZG:ScheduleBroadcast()
end

-- Retire un lieu des passages qui y menaient (mes régions uniquement).
function ZG:ForgetPlaceLinks(placeId)
    for _, zone in pairs(EnsureDB().zones) do
        if zone.creator == MyName() then
            for _, sub in pairs(zone.subZones) do
                if sub.enterPlace == placeId then sub.enterPlace = nil end
                if sub.leavePlace == placeId then sub.leavePlace = nil end
            end
        end
    end
end

function ZG:RemovePlace(id)
    local place, zone = MyPlace(id)
    if not place then return end
    zone.places[id] = nil
    ZG:ForgetPlaceLinks(id)
    ZG:ScheduleBroadcast()
end

-- Range un lieu dans une autre de mes régions. Son id ne change pas : les
-- passages qui y mènent et les noms déjà appris restent valables.
function ZG:MovePlace(id, targetZoneId)
    local place, zone = MyPlace(id)
    local target = ZG:GetZone(targetZoneId)
    if not place or not target or target.creator ~= MyName() or target.id == zone.id then return false end
    zone.places[id] = nil
    place.zoneId = target.id
    target.places[id] = place
    ZG:ScheduleBroadcast()
    return true
end

-- Passages (toutes régions) qui mènent à ce lieu : { sub, zone, which }.
function ZG:GetPlacePassages(placeId)
    local list = {}
    for _, zone in pairs(EnsureDB().zones) do
        for _, sub in pairs(zone.subZones) do
            if sub.enterPlace == placeId then list[#list + 1] = { sub = sub, zone = zone, which = "enter" } end
            if sub.leavePlace == placeId then list[#list + 1] = { sub = sub, zone = zone, which = "leave" } end
        end
    end
    table.sort(list, function(a, b) return a.sub.id < b.sub.id end)
    return list
end

-- ── Action au passage (aura / commande / message) ──────────────────────────
-- Portée par le lieu : jouée en y arrivant et / ou en le quittant, quel que
-- soit le passage emprunté — voir RunPlaceAction.

function ZG:SetPlaceActionMessage(id, text)
    local place = MyPlace(id)
    if not place then return end
    place.actionMessage = text or ""
    ZG:ScheduleBroadcast()
end

function ZG:SetPlaceActionCommand(id, text)
    local place = MyPlace(id)
    if not place then return end
    place.actionCommand = text or ""
    ZG:ScheduleBroadcast()
end

-- which = "enter" | "leave"
function ZG:SetPlaceActionEnabled(id, which, enabled)
    local place = MyPlace(id)
    if not place then return end
    if which == "leave" then place.actionLeaveEnabled = enabled and true or false
    else place.actionEnterEnabled = enabled and true or false end
    ZG:ScheduleBroadcast()
end

-- ── Sort Arcanum lié au lieu (voir ArcEnter / ArcLeave) ──────────────────
-- which = "enter" | "exit". Espaces retirés : un ArcSpell ID n'en contient pas.
function ZG:SetPlaceArcSpell(id, which, commID)
    local place = MyPlace(id)
    if not place then return end
    local field = (which == "exit") and "arcExitSpell" or "arcEnterSpell"
    place[field] = Clean(commID)
    ZG:ScheduleBroadcast()
end

function ZG:SetPlaceArcVault(id, vault)
    local place = MyPlace(id)
    if not place then return end
    place.arcVault = (vault == "personal") and "personal" or "phase"
    ZG:ScheduleBroadcast()
end

function ZG:SetPlaceArcToggle(id, enabled)
    local place = MyPlace(id)
    if not place then return end
    place.arcToggle = enabled and true or false
    ZG:ScheduleBroadcast()
end

-- ── CRUD Passages (= checkpoints, stockés dans zone.subZones) ────────────
-- Un passage n'est que de la géométrie (passage droit ou périmètre) posée
-- dans une région. Il mène à un lieu en entrant (côté vert / intérieur) et,
-- facultativement, à un autre lieu en sortant — de n'importe quelle région.

-- Renvoie sub, zone (ou rien si introuvable) — cherche dans toutes les
-- régions connues localement (les miennes + celles reçues par sync).
function ZG:FindSubZone(subZoneId)
    if not subZoneId then return nil end
    local db = EnsureDB()
    for _, zone in pairs(db.zones) do
        local sub = zone.subZones[subZoneId]
        if sub then return sub, zone end
    end
    return nil
end

function ZG:GetSubZone(id)
    local sub = ZG:FindSubZone(id)
    return sub
end

local function MyPassage(id)
    local sub, zone = ZG:FindSubZone(id)
    if sub and zone.creator == MyName() then return sub, zone end
end

function ZG:GetPassageList(zoneId)
    local zone = ZG:GetZone(zoneId)
    local list = {}
    if not zone then return list end
    for _, sub in pairs(zone.subZones) do list[#list + 1] = sub end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- enterPlace (facultatif) : lieu proposé d'office en entrant.
function ZG:CreateSubZone(zoneId, name, enterPlace)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return nil end

    local px, py, facing, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Crossings : position introuvable.")
        return nil
    end

    name = Clean(name)
    if name == "" then
        local n = 0
        for _ in pairs(zone.subZones) do n = n + 1 end
        name = "Passage " .. (n + 1)
    end

    local id = NewId("sz_")
    zone.subZones[id] = {
        id = id, zoneId = zoneId, name = name, creator = MyName(),
        passage = true,
        enabled = true,
        mapID = instanceID, x = px, y = py, facing = facing,
        width = DEFAULT_WIDTH,   -- largeur de porte (line), en yards
        shape = "line",
        points = {},             -- [i] = {x=,y=} — uniquement pour shape="polygon", voir AddRegionPoint
        regionReady = false,     -- polygone "fermé" (voir FinishRegion) — inerte tant que faux
        enterPlace = enterPlace, -- lieu atteint en entrant (côté vert / intérieur)
        leavePlace = nil,        -- lieu atteint en sortant, ou aucun
    }
    ZG:ScheduleBroadcast()
    return zone.subZones[id]
end

-- Clone un passage (mêmes lieux, largeur, forme) à la position / orientation
-- ACTUELLES du joueur — pratique pour les entrées multiples d'un village.
function ZG:CloneSubZone(id)
    local sub, zone = MyPassage(id)
    if not sub then return nil end

    local px, py, facing, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Crossings : position introuvable.")
        return nil
    end

    -- Un périmètre n'est pas UN point : ses points sont recopiés tels quels
    -- (non exposé dans l'UI pour cette forme).
    local points = {}
    for i, p in ipairs(sub.points or {}) do points[i] = { x = p.x, y = p.y } end

    local newId = NewId("sz_")
    zone.subZones[newId] = {
        id = newId, zoneId = zone.id, name = sub.name, creator = MyName(),
        passage = true, enabled = true,
        mapID = instanceID, x = px, y = py, facing = facing,
        width = sub.width, shape = sub.shape,
        points = points, regionReady = sub.regionReady or false,
        enterPlace = sub.enterPlace, leavePlace = sub.leavePlace,
    }
    ZG:ScheduleBroadcast()
    return zone.subZones[newId]
end

function ZG:RemoveSubZone(id)
    local sub, zone = MyPassage(id)
    if not sub then return end
    zone.subZones[id] = nil
    ZG.state[id] = nil
    ZG:ScheduleBroadcast()
end

function ZG:RenameSubZone(id, name)
    local sub = MyPassage(id)
    if not sub then return end
    sub.name = name or ""
    ZG:ScheduleBroadcast()
end

-- which = "enter" | "leave" ; placeId nil = aucun lieu. Seuls mes lieux
-- sont acceptés (n'importe laquelle de mes régions).
function ZG:SetPassagePlace(id, which, placeId)
    local sub = MyPassage(id)
    if not sub then return end
    if placeId and not MyPlace(placeId) then return end
    if which == "leave" then sub.leavePlace = placeId else sub.enterPlace = placeId end
    ZG:ScheduleBroadcast()
end

-- Recapture la position/orientation/instance courantes (déplace la porte là
-- où se trouve le joueur, sans toucher au reste).
function ZG:RecaptureSubZone(id)
    local sub = MyPassage(id)
    if not sub then return false end

    local px, py, facing, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Crossings : position introuvable.")
        return false
    end

    sub.x, sub.y, sub.facing, sub.mapID = px, py, facing, instanceID
    ZG.state[id] = nil
    ZG:ScheduleBroadcast()
    return true
end

function ZG:SetSubZoneWidth(id, width)
    local sub = MyPassage(id)
    if not sub then return end
    sub.width = math.max(1, math.min(MAX_WIDTH, tonumber(width) or DEFAULT_WIDTH))
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneShape(id, shape)
    local sub = MyPassage(id)
    if not sub then return end
    local newShape = (shape == "polygon") and "polygon" or "line"
    if newShape == "polygon" and sub.shape ~= "polygon" then
        -- Nouveau périmètre : il démarre vide. Le premier point est posé avec
        -- AddRegionPoint, ou repris d'une frontière voisine (AddBorderPath).
        sub.points = {}
        sub.regionReady = false
    end
    sub.shape = newShape
    ZG.state[id] = nil   -- la géométrie change, on réarme la détection
    ZG:ScheduleBroadcast()
end

-- ── Périmètre (shape="polygon") : N points posés autour du joueur ─────────
-- Le polygone est TOUJOURS traité comme fermé (dernier point relié au
-- premier) dès qu'il a au moins 3 points ET que regionReady est vrai.

local function RecomputeRegionCenter(sub)
    local points = sub.points
    if not points or #points == 0 then return end
    local sx, sy = 0, 0
    for _, p in ipairs(points) do sx, sy = sx + p.x, sy + p.y end
    sub.x, sub.y = sx / #points, sy / #points
end

-- Ajoute un point à la position actuelle du joueur. Le premier point fixe
-- aussi l'instance (mapID) — les suivants doivent rester dans la MÊME instance.
function ZG:AddRegionPoint(subZoneId)
    local sub = MyPassage(subZoneId)
    if not sub or sub.shape ~= "polygon" then return false end

    local px, py, _, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Crossings : position introuvable.")
        return false
    end

    sub.points = sub.points or {}
    if #sub.points == 0 then
        sub.mapID = instanceID
    elseif sub.mapID ~= instanceID then
        OmegaHub.Print("Crossings : restez dans la même zone/instance pour ce périmètre.")
        return false
    elseif #sub.points >= MAX_REGION_POINTS then
        OmegaHub.Print("Crossings : maximum " .. MAX_REGION_POINTS .. " points par périmètre.")
        return false
    end

    table.insert(sub.points, { x = px, y = py })
    RecomputeRegionCenter(sub)
    sub.regionReady = false   -- toute modif des points rouvre le périmètre
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

-- Frontières déclarées dont un point n'existe plus : retirées.
local function PruneBorders(sub)
    if not sub.borders then return end
    local n = sub.points and #sub.points or 0
    for i = #sub.borders, 1, -1 do
        local b = sub.borders[i]
        if b.from > n or b.to > n then table.remove(sub.borders, i) end
    end
end

function ZG:RemoveLastRegionPoint(subZoneId)
    local sub = MyPassage(subZoneId)
    if not sub or sub.shape ~= "polygon" or not sub.points or #sub.points == 0 then return false end
    table.remove(sub.points)
    PruneBorders(sub)
    RecomputeRegionCenter(sub)
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

-- ── Points de frontière ──────────────────────────────────────────────────
-- Tout sommet d'un périmètre est un point de frontière ; il peut porter un
-- nom (« Gué du Nord ») pour être retrouvé. Reprendre une frontière recopie
-- deux points d'un périmètre voisin aux coordonnées exactes : les deux
-- contours se touchent sans trou ni chevauchement.

local function CleanPointName(name)
    return (Clean(name):gsub("[;,:|\n\r]", " "))
end

function ZG:SetRegionPointName(subZoneId, index, name)
    local sub = MyPassage(subZoneId)
    local point = sub and sub.points and sub.points[index]
    if not point then return end
    name = CleanPointName(name)
    point.name = name ~= "" and name or nil
    ZG:ScheduleBroadcast()
end

-- Nom affiché d'un sommet : son nom, sinon « Point 4 de <passage> ».
function ZG:RegionPointLabel(sub, index)
    local point = sub.points and sub.points[index]
    if not point then return "" end
    return point.name or ("Point " .. index .. " de " .. (sub.name or "?"))
end

-- Mes autres périmètres de la même instance, sources d'une frontière à reprendre.
-- Contour encore vide : l'instance est celle où se trouve le joueur.
function ZG:GetBorderSources(subZoneId)
    local sub = MyPassage(subZoneId)
    local list = {}
    if not sub then return list end
    local mapID = sub.mapID
    if not sub.points or #sub.points == 0 then
        local _, _, _, instanceID = ZG:GetPlayerPose()
        mapID = instanceID or mapID
    end
    for _, zone in pairs(EnsureDB().zones) do
        if zone.creator == MyName() then
            for _, other in pairs(zone.subZones) do
                if other.id ~= sub.id and other.shape == "polygon" and other.mapID == mapID and other.points and #other.points >= 2 then
                    list[#list + 1] = { sub = other, zone = zone }
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.sub.id < b.sub.id end)
    return list
end

-- Sommets parcourus de "from" à "to" en suivant le contour, dans un sens ou
-- dans l'autre, y compris par la fermeture (47 → 1 → … → 6). nil si le
-- chemin n'existe pas.
function ZG:BorderPath(source, from, to, forward)
    local points = source.points or {}
    local n = #points
    if not points[from] or not points[to] or from == to then return nil end
    -- Un contour en cours sera refermé du dernier point au premier : dès 3
    -- points, on peut déjà passer par cette fermeture.
    local closed = n >= 3
    local path, i = {}, from
    while true do
        path[#path + 1] = i
        if i == to then return path end
        i = i + (forward and 1 or -1)
        if i > n or i < 1 then
            if not closed then return nil end
            i = (i > n) and 1 or n
        end
    end
end

-- Ajoute à la suite du contour en cours la frontière d'un périmètre voisin,
-- du point "from" au point "to", avec les noms des sommets.
function ZG:AddBorderPath(subZoneId, sourceId, from, to, forward)
    local sub = MyPassage(subZoneId)
    local source = MyPassage(sourceId)
    if not sub or not source or sub.shape ~= "polygon" or source.shape ~= "polygon" then return false end
    local path = ZG:BorderPath(source, from, to, forward)
    if not path then return false end
    sub.points = sub.points or {}
    if #sub.points == 0 then sub.mapID = source.mapID end
    if sub.mapID ~= source.mapID then
        OmegaHub.Print("Crossings : cette frontière est dans une autre zone/instance.")
        return false
    end
    if #sub.points + #path > MAX_REGION_POINTS then
        OmegaHub.Print("Crossings : maximum " .. MAX_REGION_POINTS .. " points par périmètre.")
        return false
    end
    for _, index in ipairs(path) do
        local p = source.points[index]
        table.insert(sub.points, { x = p.x, y = p.y, name = p.name })
    end
    RecomputeRegionCenter(sub)
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

function ZG:ClearRegionPoints(subZoneId)
    local sub = MyPassage(subZoneId)
    if not sub or sub.shape ~= "polygon" then return end
    sub.points = {}
    PruneBorders(sub)
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
end

-- ── Frontières déclarées ──────────────────────────────────────────────────
-- Un tronçon nommé de son propre contour (« Frontière Nord », du point 47 au
-- point 6), déclaré avant même qu'un voisin existe : le périmètre voisin le
-- reprendra ensuite tel quel (voir AddBorderPath).
function ZG:DeclareBorder(subZoneId, name, from, to, forward)
    local sub = MyPassage(subZoneId)
    if not sub or sub.shape ~= "polygon" then return false end
    name = CleanPointName(name)
    if name == "" or not ZG:BorderPath(sub, from, to, forward) then return false end
    sub.borders = sub.borders or {}
    table.insert(sub.borders, { name = name, from = from, to = to, forward = forward and true or false })
    ZG:ScheduleBroadcast()
    return true
end

function ZG:UpdateBorder(subZoneId, index, name, from, to, forward)
    local sub = MyPassage(subZoneId)
    local border = sub and sub.borders and sub.borders[index]
    if not border then return false end
    name = CleanPointName(name)
    if name == "" or not ZG:BorderPath(sub, from, to, forward) then return false end
    border.name, border.from, border.to, border.forward = name, from, to, forward and true or false
    ZG:ScheduleBroadcast()
    return true
end

function ZG:RemoveBorder(subZoneId, index)
    local sub = MyPassage(subZoneId)
    if not sub or not sub.borders or not sub.borders[index] then return end
    table.remove(sub.borders, index)
    ZG:ScheduleBroadcast()
end

-- Frontières déclarées sur mes autres périmètres de la même instance.
function ZG:GetDeclaredBorders(subZoneId)
    local list = {}
    for _, entry in ipairs(ZG:GetBorderSources(subZoneId)) do
        for _, border in ipairs(entry.sub.borders or {}) do
            if ZG:BorderPath(entry.sub, border.from, border.to, border.forward) then
                list[#list + 1] = { sub = entry.sub, zone = entry.zone, border = border }
            end
        end
    end
    return list
end

-- "Valide" le périmètre : au moins 3 points nécessaires (aire non nulle).
function ZG:FinishRegion(subZoneId)
    local sub = MyPassage(subZoneId)
    if not sub or sub.shape ~= "polygon" or not sub.points or #sub.points < 3 then return false end
    sub.regionReady = true
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

-- Rouvre l'édition (ajouter/retirer des points) sans perdre ceux déjà posés.
function ZG:ReopenRegion(subZoneId)
    local sub = MyPassage(subZoneId)
    if not sub or sub.shape ~= "polygon" then return end
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneEnabled(id, enabled)
    local sub = MyPassage(id)
    if not sub then return end
    sub.enabled = enabled and true or false
    ZG:ScheduleBroadcast()
end

-- ── CRUD Thèmes ──────────────────────────────────────────────────────────────
-- Un thème est autonome et réutilisable : posé sur une Zone (hérité par
-- TOUTES ses Sous-zones qui n'ont rien choisi elles-mêmes) et/ou sur une
-- Sous-zone précise (l'emporte alors sur celui de la Zone — voir
-- ResolveTheme). Personnel au créateur, comme les Zones — GetThemeList ne
-- renvoie que les miens, les autres arrivent par sync et restent utilisables
-- sur les Zones/Sous-zones qui les référencent déjà (voir ApplyStateLine).

function ZG:CreateTheme(name)
    name = (name or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then name = "Nouveau thème" end

    local db = EnsureDB()
    local id = "th_" .. time() .. "_" .. math.random(1000, 9999)
    local theme = {}
    for k, v in pairs(ZG.DefaultTheme) do
        theme[k] = (type(v) == "table") and { unpack(v) } or v
    end
    theme.id, theme.name, theme.creator = id, name, MyName()
    db.themes[id] = theme
    ZG:ScheduleBroadcast()
    return theme
end

function ZG:RemoveTheme(id)
    local db = EnsureDB()
    local theme = db.themes[id]
    if not theme or theme.creator ~= MyName() then return end
    db.themes[id] = nil
    ZG:ScheduleBroadcast()
    -- Pas de nettoyage en cascade des Zones/Sous-zones qui le référencent :
    -- ResolveTheme retombe proprement sur ZG.DefaultTheme si l'id ne
    -- résout plus rien (même logique que les checkpoints orphelins).
end

function ZG:GetTheme(id)
    if not id then return nil end
    return EnsureDB().themes[id]
end

function ZG:GetThemeList()
    local db = EnsureDB()
    local me = MyName()
    local ids = {}
    for tid, theme in pairs(db.themes) do
        if theme.creator == me then table.insert(ids, tid) end
    end
    table.sort(ids)

    local list = {}
    for _, tid in ipairs(ids) do table.insert(list, db.themes[tid]) end
    return list
end

function ZG:RenameTheme(id, name)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.name = (name or ""):match("^%s*(.-)%s*$") or theme.name
    self:ScheduleBroadcast()
end

function ZG:SetThemeFont(id, font)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.font = (ZG.FontPaths[font] or font == "custom") and font or "frizqt"
    self:ScheduleBroadcast()
end

-- Chemin utilisé quand font == "custom" — n'importe quel fichier de police
-- déjà présent chez vous (fourni par un autre addon, par exemple), voir le
-- commentaire sur ZG.FontPaths. Aucune vérification que le fichier existe
-- réellement : un chemin invalide retombe silencieusement sur la police par
-- défaut au rendu (voir ResolveFontPath dans UI_Banner.lua).
function ZG:SetThemeCustomFont(id, path)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.customFont = (path or ""):match("^%s*(.-)%s*$") or ""
    self:ScheduleBroadcast()
end

function ZG:SetThemeTitleSize(id, size)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.titleSize = math.max(10, math.min(60, math.floor((tonumber(size) or theme.titleSize) + 0.5)))
    self:ScheduleBroadcast()
end

-- which = "title" | "sub" | "sep" | "bg" | "frame" — un seul setter couleur
-- pour les 5 emplacements du thème plutôt que 5 fonctions quasi identiques.
-- sepColor/bgColor/frameColor ont un canal alpha (a peut être nil →
-- conservé tel quel).
local THEME_COLOR_FIELDS = {
    title = "titleColor", sub = "subColor", sep = "sepColor", bg = "bgColor", frame = "frameColor",
}
function ZG:SetThemeColor(id, which, r, g, b, a)
    local theme = self:GetTheme(id)
    local field = THEME_COLOR_FIELDS[which]
    if not theme or not field or theme.creator ~= MyName() then return end
    local c = theme[field] or {}
    c[1], c[2], c[3] = r or c[1] or 1, g or c[2] or 1, b or c[3] or 1
    if a ~= nil then c[4] = a end
    theme[field] = c
    self:ScheduleBroadcast()
end

function ZG:SetThemeOutline(id, enabled)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.outline = enabled and true or false
    self:ScheduleBroadcast()
end

function ZG:SetThemeUppercase(id, enabled)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.uppercase = enabled and true or false
    self:ScheduleBroadcast()
end

function ZG:SetThemeLetterSpacing(id, enabled)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.letterSpacing = enabled and true or false
    self:ScheduleBroadcast()
end

function ZG:SetThemeSeparatorStyle(id, style)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.sepStyle = ZG.SepLabels[style] and style or "single"
    self:ScheduleBroadcast()
end

function ZG:SetThemeFrameStyle(id, style)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.frameStyle = ZG.FrameLabels[style] and style or "none"
    self:ScheduleBroadcast()
end

-- Ligne entre le titre et le sous-titre (indépendante des lignes haut/bas,
-- qui restent gérées par sepStyle) — même couleur (sepColor), toujours en
-- trait simple quel que soit sepStyle.
function ZG:SetThemeMidSeparator(id, enabled)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.midSepEnabled = enabled and true or false
    self:ScheduleBroadcast()
end

function ZG:SetThemeBackgroundEnabled(id, enabled)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.bgEnabled = enabled and true or false
    self:ScheduleBroadcast()
end

function ZG:SetThemeTiming(id, fadeIn, hold, fadeOut)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    if fadeIn  then theme.fadeIn  = math.max(0, math.min(5,  tonumber(fadeIn)  or theme.fadeIn)) end
    if hold    then theme.hold    = math.max(0, math.min(30, tonumber(hold)    or theme.hold)) end
    if fadeOut then theme.fadeOut = math.max(0, math.min(5,  tonumber(fadeOut) or theme.fadeOut)) end
    self:ScheduleBroadcast()
end

-- value : soit un ID numérique (SoundKit Blizzard, via PlaySound), soit un
-- chemin de fichier ("Sound\..." natif OU un .ogg/.mp3 déposé par vous dans
-- le dossier de l'addon, via PlaySoundFile) — voir ResolveSoundValue.
-- direction : "enter" (franchissement "avant") ou "exit" ("arrière").
function ZG:SetThemeSound(id, direction, value)
    local theme = self:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    local field = (direction == "exit") and "soundExit" or "soundEnter"
    theme[field] = (value or ""):match("^%s*(.-)%s*$") or ""
    self:ScheduleBroadcast()
end

-- Zone/Sous-zone → thème choisi ("" ou nil = aucun/hérite, voir ResolveTheme).
function ZG:SetZoneTheme(zoneId, themeId)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return end
    zone.themeId = (themeId ~= "" and themeId) or nil
    ZG:ScheduleBroadcast()
end

function ZG:SetPlaceTheme(placeId, themeId)
    local place, zone = ZG:FindPlace(placeId)
    if not place or zone.creator ~= MyName() then return end
    place.themeId = (themeId ~= "" and themeId) or nil
    ZG:ScheduleBroadcast()
end

-- Résout le thème effectif d'un lieu : le sien s'il en a choisi un, sinon
-- celui de sa région (tous ses lieux en héritent), sinon le thème par défaut.
function ZG:ResolveTheme(place, zone)
    if place and place.themeId then
        local t = ZG:GetTheme(place.themeId)
        if t then return t end
    end
    if zone and zone.themeId then
        local t = ZG:GetTheme(zone.themeId)
        if t then return t end
    end
    return ZG.DefaultTheme
end

-- ── Migration de l'ancien schéma (checkpoints séparés + liaison manuelle) ──

-- Ancien schéma (une itération précédente) : Sous-zones "texte seul" liées
-- par id à des checkpoints séparés (ZoneGateDB.checkpoints). On fusionne
-- tout ça en Sous-zones autonomes, une par checkpoint lié (clone si une
-- même sous-zone avait plusieurs checkpoints — village à plusieurs entrées).
-- La forme "circle" a disparu : un ancien cercle devient un périmètre fermé
-- de même centre et de même rayon (16 points), détecté comme toute région.
local CIRCLE_POINTS = 16
local function CircleToPerimeter(sub)
    if sub.shape ~= "circle" then return end
    local radius = sub.width or DEFAULT_WIDTH
    local cx, cy = sub.x or 0, sub.y or 0
    sub.points = {}
    for i = 0, CIRCLE_POINTS - 1 do
        local a = i * 2 * math.pi / CIRCLE_POINTS
        sub.points[#sub.points + 1] = { x = cx + math.cos(a) * radius, y = cy + math.sin(a) * radius }
    end
    sub.shape, sub.regionReady = "polygon", true
    sub.x, sub.y = cx, cy
    sub.width = DEFAULT_WIDTH
end

local function MigrateCircles()
    for _, zone in pairs(EnsureDB().zones) do
        for _, sub in pairs(zone.subZones) do CircleToPerimeter(sub) end
    end
end

-- Ancien modèle : chaque checkpoint portait lui-même son nom, ses noms
-- d'entrée / de sortie, sa bannière et ses effets. Il devient un passage
-- qui mène à un lieu (nom d'entrée, sinon son nom) et, si un nom de sortie
-- était rempli, à un second lieu en sortant. Les checkpoints d'un même
-- village (même nom, même bannière) partagent un seul lieu ; les anciens
-- ids restent des alias pour ne pas perdre les noms déjà appris.
local function Filled(s) return (tostring(s or ""):match("^%s*(.-)%s*$") or "") ~= "" end

local function LegacyPlace(zone, id, name, themeId, grantedTo)
    for _, place in pairs(zone.places) do
        if place.name == name and place.themeId == themeId then
            if place.id ~= id then place.aliases[id] = true end
            for who in pairs(grantedTo or {}) do place.grantedTo[who] = true end
            return place
        end
    end
    local place = NewPlace(id, zone.id, name)
    place.themeId = themeId
    for who in pairs(grantedTo or {}) do place.grantedTo[who] = true end
    zone.places[id] = place
    return place
end

local function ConvertLegacySub(zone, sub)
    if sub.passage then return end
    zone.places = zone.places or {}
    local enterName = Filled(sub.forwardName) and sub.forwardName or (Filled(sub.name) and sub.name or "Lieu")
    local enter = LegacyPlace(zone, sub.id, enterName, sub.themeId, sub.grantedTo)
    if not Filled(enter.actionMessage) and not Filled(enter.actionCommand) then
        enter.actionMessage, enter.actionCommand = sub.actionMessage or "", sub.actionCommand or ""
        enter.actionEnterEnabled = sub.actionForwardEnabled or false
        enter.actionLeaveEnabled = sub.actionBackwardEnabled or false
    end
    if not Filled(enter.arcEnterSpell) and Filled(sub.arcEnterSpell) then
        enter.arcEnterSpell, enter.arcExitSpell = sub.arcEnterSpell, sub.arcExitSpell or ""
        enter.arcVault, enter.arcToggle = sub.arcVault or "phase", sub.arcToggle ~= false
    end
    local leave = Filled(sub.backwardName) and LegacyPlace(zone, sub.id .. "_b", sub.backwardName, sub.themeId) or nil
    sub.enterPlace, sub.leavePlace = enter.id, leave and leave.id or nil
    sub.name = "Passage vers " .. enter.name
    for _, key in ipairs({ "forwardName", "backwardName", "forwardEnabled", "backwardEnabled", "themeId", "grantedTo",
        "actionMessage", "actionCommand", "actionForwardEnabled", "actionBackwardEnabled",
        "arcEnterSpell", "arcExitSpell", "arcVault", "arcToggle" }) do sub[key] = nil end
    sub.passage = true
end

local function MigratePlaces()
    for _, zone in pairs(EnsureDB().zones) do
        local ids = {}
        for id in pairs(zone.subZones) do ids[#ids + 1] = id end
        table.sort(ids)   -- ordre stable : le plus ancien checkpoint donne son id au lieu
        for _, id in ipairs(ids) do ConvertLegacySub(zone, zone.subZones[id]) end
    end
end

-- Les modèles de l'Atelier imposaient "center" : les bannières déjà créées
-- remontent en haut de l'écran, une seule fois (l'auteur peut rechoisir ensuite).
local function MigrateBannerPlacement()
    local db = EnsureDB()
    if db.placementTopMigrated then return end
    db.placementTopMigrated = true
    for _, theme in pairs(db.themes) do
        if theme.placement == "center" and theme.creator == UnitName("player") then theme.placement = "top" end
    end
end

local function MigrateOldCheckpoints()
    local db = EnsureDB()
    local oldCheckpoints = ZoneGateDB.checkpoints
    if not oldCheckpoints then return end

    for _, zone in pairs(db.zones) do
        for subId, sub in pairs(zone.subZones) do
            if sub.x == nil then
                local links = {}
                for _, cp in pairs(oldCheckpoints) do
                    if cp.forward and cp.forward.subZoneId == subId then
                        table.insert(links, { cp = cp, direction = "forward" })
                    end
                    if cp.backward and cp.backward.subZoneId == subId then
                        table.insert(links, { cp = cp, direction = "backward" })
                    end
                end

                if #links > 0 then
                    local first = links[1].cp
                    sub.creator = first.creator or zone.creator
                    sub.enabled = first.enabled ~= false
                    sub.mapID, sub.x, sub.y, sub.facing = first.mapID, first.x, first.y, first.facing
                    sub.width = first.width or DEFAULT_WIDTH
                    sub.shape = first.shape or "line"
                    sub.forwardEnabled, sub.backwardEnabled = false, false
                    for _, link in ipairs(links) do
                        if link.direction == "forward" then sub.forwardEnabled = true
                        else sub.backwardEnabled = true end
                    end

                    for i = 2, #links do
                        local link = links[i]
                        local cp = link.cp
                        local newId = "sz_" .. time() .. "_" .. math.random(1000, 9999)
                        zone.subZones[newId] = {
                            id = newId, zoneId = zone.id, name = sub.name,
                            creator = cp.creator or zone.creator,
                            enabled = cp.enabled ~= false,
                            mapID = cp.mapID, x = cp.x, y = cp.y, facing = cp.facing,
                            width = cp.width or DEFAULT_WIDTH, shape = cp.shape or "line",
                            forwardEnabled  = link.direction == "forward",
                            backwardEnabled = link.direction == "backward",
                        }
                    end
                else
                    -- Jamais liée à un checkpoint : reste inerte tant qu'elle
                    -- n'est pas recapturée manuellement (pas de position).
                    sub.enabled = false
                    sub.forwardEnabled, sub.backwardEnabled = true, true
                end
            end
        end
    end

    ZoneGateDB.checkpoints = nil
end

-- ── Texte masqué / résolution de visibilité ───────────────────────────────

-- Remplace chaque caractère (hors espace/tiret/apostrophe) par "?", en
-- respectant la longueur des séquences UTF-8 (pas de librairie utf8.* en
-- Lua 5.1/WoW) — garde la silhouette du mot ("Le sous-bois" → "?? ????-????").
local MASK_KEEP = { [" "] = true, ["-"] = true, ["'"] = true, ["’"] = true, ["_"] = true }

function ZG:MaskText(text)
    if not text or text == "" then return text end
    local out = {}
    local i, len = 1, #text
    while i <= len do
        local b = text:byte(i)
        local n = 1
        if b >= 240 then n = 4
        elseif b >= 224 then n = 3
        elseif b >= 192 then n = 2
        end
        local ch = text:sub(i, i + n - 1)
        table.insert(out, MASK_KEEP[ch] and ch or "?")
        i = i + n
    end
    return table.concat(out)
end

-- Découpe en unités "un caractère affiché" en respectant les séquences
-- UTF-8 (même logique que MaskText ci-dessus — pas de librairie utf8.* en
-- Lua 5.1/WoW).
local function SplitChars(text)
    local out = {}
    local i, len = 1, #text
    while i <= len do
        local b = text:byte(i)
        local n = 1
        if b >= 240 then n = 4
        elseif b >= 224 then n = 3
        elseif b >= 192 then n = 2
        end
        table.insert(out, text:sub(i, i + n - 1))
        i = i + n
    end
    return out
end

-- Applique majuscule/espacement d'un thème à un texte de bannière. La
-- majuscule est un "best effort" : string.upper() de Lua 5.1 ne connaît que
-- l'ASCII, donc un caractère accentué (é, è, à…) reste inchangé au lieu
-- d'être cassé — visuellement imparfait sur du français, jamais corrompu.
function ZG:StyleThemeText(text, theme)
    if not text or text == "" then return text end
    if theme.uppercase then text = text:upper() end
    if theme.letterSpacing then
        text = table.concat(SplitChars(text), " ")
    end
    return text
end

-- Connaissance du NOM DE LA ZONE, indépendante de celle de la Sous-zone.
function ZG:HasLearnedZoneName(zoneId)
    return zoneId ~= nil and EnsureCharDB().learnedZones[zoneId] == true
end

function ZG:MarkLearnedZoneName(zoneId)
    if not zoneId or zoneId == "" then return end
    EnsureCharDB().learnedZones[zoneId] = true
end

-- Connaissance du NOM DE LA SOUS-ZONE, indépendante de celle de la Zone.
function ZG:HasLearnedSubZoneName(subZoneId)
    return subZoneId ~= nil and EnsureCharDB().learnedSubZones[subZoneId] == true
end

function ZG:MarkLearnedSubZoneName(subZoneId)
    if not subZoneId or subZoneId == "" then return end
    EnsureCharDB().learnedSubZones[subZoneId] = true
end

-- Un lieu fusionné garde ses anciens ids : un nom appris sous l'un d'eux reste connu.
function ZG:KnowsPlaceName(place)
    if not place then return false end
    if ZG:HasLearnedSubZoneName(place.id) then return true end
    for alias in pairs(place.aliases or {}) do
        if ZG:HasLearnedSubZoneName(alias) then return true end
    end
    return false
end

-- Renvoie title, subtitle prêts pour la bannière (et pour l'affichage dans
-- le panneau). Les deux noms sont débloqués INDÉPENDAMMENT l'un de l'autre
-- (voir SendZoneGrant / SendPlaceGrant), d'où 4 combinaisons possibles :
--   1. aucun connu      → "Zone inconnue"  / "?????"
--   2. Région seule     → "<région>"       / "??????"
--   3. Lieu seul        → "Zone inconnue"  / "<lieu>"
--   4. les deux connus  → "<région>"       / "<lieu>"
-- L'auteur de la région voit toujours tout en clair.
function ZG:ResolveBannerText(place, zone)
    if not place or not zone then return nil end
    local mine = zone.creator == MyName()
    local zoneKnown = mine or ZG:HasLearnedZoneName(zone.id)
    local placeKnown = mine or ZG:KnowsPlaceName(place)
    local title = zoneKnown and zone.name or "Zone inconnue"
    local subtitle = placeKnown and place.name or ZG:MaskText(place.name)
    return title, subtitle
end

-- ── Détection de franchissement ───────────────────────────────────────────

ZG.state = ZG.state or {}   -- [subZoneId] = -1 | 1 | nil (côté courant)

-- Après un écran de chargement, la position se rétablit en silence quelques secondes.
local QUIET_AFTER_LOADING = 5

function ZG:ResetState()
    wipe(ZG.state)
    ZG.quietUntil = GetTime() + QUIET_AFTER_LOADING
end

-- Ligne : distance signée le long de "facing" (along) + latérale (across).
local function Project(sub, px, py)
    local fx, fy = math.sin(sub.facing), math.cos(sub.facing)
    local rx, ry = -fy, fx
    local dx, dy = px - sub.x, py - sub.y
    local along  = dx * fx + dy * fy
    local across = dx * rx + dy * ry
    return along, across
end

-- Distance point → segment [a,b] (projection clampée sur le segment).
local function DistToSegment(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local lenSq = dx * dx + dy * dy
    if lenSq == 0 then
        return math.sqrt((px - ax) ^ 2 + (py - ay) ^ 2)
    end
    local t = math.max(0, math.min(1, ((px - ax) * dx + (py - ay) * dy) / lenSq))
    local cx, cy = ax + t * dx, ay + t * dy
    return math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
end

-- Ray casting standard : dedans/dehors par comptage d'intersections avec un
-- rayon horizontal. Le dernier point est TOUJOURS relié au premier (boucle
-- fermée implicite — pas besoin de dupliquer le point de départ en fin de
-- liste).
local function PointInPolygon(points, px, py)
    local inside = false
    local n = #points
    local j = n
    for i = 1, n do
        local xi, yi = points[i].x, points[i].y
        local xj, yj = points[j].x, points[j].y
        if ((yi > py) ~= (yj > py)) and
           (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function MinDistToPolygonEdges(points, px, py)
    local n = #points
    local minDist = math.huge
    local j = n
    for i = 1, n do
        local d = DistToSegment(px, py, points[j].x, points[j].y, points[i].x, points[i].y)
        if d < minDist then minDist = d end
        j = i
    end
    return minDist
end

-- Renvoie 1 (côté "avant"/dedans), -1 (côté "arrière"/dehors), ou nil si on
-- est hors de portée (hors bande pour une ligne, ou près du contour pour
-- une région).
local function ClassifySide(sub, px, py)
    if sub.shape == "polygon" then
        if not sub.regionReady or not sub.points or #sub.points < 3 then return nil end
        if MinDistToPolygonEdges(sub.points, px, py) < WIDTH_MARGIN then return nil end
        return PointInPolygon(sub.points, px, py) and 1 or -1
    end

    local along, across = Project(sub, px, py)
    local halfWidth = (sub.width or DEFAULT_WIDTH) / 2 + WIDTH_MARGIN
    if math.abs(across) > halfWidth then return nil end
    return (along >= 0) and 1 or -1
end

-- Exposé pour le radar d'édition (UI_Radar.lua) : où se trouve le joueur par
-- rapport à une sous-zone donnée, sans toucher à ZG.state / au ticker.
-- Renvoie inBand (bool), direction ("forward"/"backward"), ou nil si le
-- joueur n'est pas dans la même zone/instance.
function ZG:GetCheckpointStatus(sub)
    local px, py, _, instanceID = ZG:GetPlayerPose()
    if not px or sub.mapID ~= instanceID then return nil end

    local side = ClassifySide(sub, px, py)
    if side == nil then return false, nil end
    return true, (side == 1) and "forward" or "backward"
end

-- /crossings debug : ce que la détection voit à la position du joueur.
function ZG:DebugPosition()
    local px, py, _, instanceID = ZG:GetPlayerPose()
    if not px then OmegaHub.Print("Crossings : position indisponible."); return end
    OmegaHub.Print(string.format("Crossings : x %.1f, y %.1f, instance %s", px, py, tostring(instanceID)))
    local function name(placeId)
        local place = ZG:FindPlace(placeId)
        return place and place.name or "aucun"
    end
    local count = 0
    for _, zone in pairs(EnsureDB().zones) do
        for id, sub in pairs(zone.subZones) do
            if sub.mapID == instanceID then
                count = count + 1
                local side = ClassifySide(sub, px, py)
                OmegaHub.Print(string.format("  %s (%s, %s%s) : %s · mémorisé %s · entrée %s · sortie %s",
                    sub.name or id, sub.shape == "polygon" and "périmètre" or "passage droit",
                    sub.enabled and "actif" or "inactif",
                    sub.shape == "polygon" and (sub.regionReady and ", validé" or ", NON validé") or "",
                    side == 1 and "dedans" or side == -1 and "dehors" or "au bord",
                    tostring(ZG.state[id]), name(sub.enterPlace), name(sub.leavePlace)))
            end
        end
    end
    if count == 0 then OmegaHub.Print("  Aucun passage dans cette instance.") end
    local here = {}
    for placeId in pairs(ZG.here) do here[#here + 1] = name(placeId) end
    OmegaHub.Print("  Lieux actuels : " .. (#here > 0 and table.concat(here, ", ") or "aucun"))
end

-- ── Lieux où se trouve le joueur + sort Arcanum lié au lieu ──────────────
-- ZG.here[placeId] = id du passage qui y a mené. Un franchissement quitte le
-- lieu de départ et entre dans celui d'arrivée ; un périmètre fermé place
-- aussi le joueur dans son lieu s'il s'y trouve déjà (connexion, /reload).
-- Un passage désactivé, supprimé ou d'une autre instance libère ses lieux.
--
-- Tant que le joueur est DANS un lieu, son sort d'entrée est actif ; en le
-- quittant, le sort de sortie le défait. Arcanum n'a pas d'annulation
-- générique (ARC:STOP coupe aussi les reverts sans les jouer), d'où un sort
-- de sortie explicite. Indépendant de la bannière et de l'action.
-- ZG.arc[placeId] = { place, active (voulu), applied (lancé), name }.

ZG.here = ZG.here or {}
ZG.arc = ZG.arc or {}

local function Trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) or "" end

local function HasArc(place)
    return place ~= nil and Trim(place.arcEnterSpell) ~= ""
end

-- Sort introuvable ou coffre de phase encore en chargement : nil (pas de
-- message, SyncArc réessaie au tick suivant).
local function FindArcSpell(commID, vault)
    commID = Trim(commID)
    if commID == "" or type(ARC) ~= "table" or type(ARC.XAPI) ~= "table" or type(ARC.XAPI.GetArcSpell) ~= "function" then return nil end
    local ok, spell = pcall(ARC.XAPI.GetArcSpell, ARC.XAPI, commID, vault ~= "personal")
    if ok and spell then return spell end
end

function ZG:FindArcSpell(commID, vault) return FindArcSpell(commID, vault) end

local function CastArc(commID, vault)
    if not FindArcSpell(commID, vault) then return false end
    commID = Trim(commID)
    local ok, res
    if vault == "personal" then
        ok, res = pcall(ARC.CAST, ARC, commID)
    else
        ok, res = pcall(ARC.PHASE.CAST, ARC.PHASE, commID, true)
    end
    return ok and res ~= false
end

-- Test depuis l'éditeur (bouton "Tester") — même chemin que le jeu.
function ZG:CastArcSpell(commID, vault) return CastArc(commID, vault) end

local function NotifyArc()
    if ZG.RefreshArcWidget then ZG:RefreshArcWidget() end
end

local function ApplyArc(entry)
    local place = entry.place
    local spell = FindArcSpell(place.arcEnterSpell, place.arcVault)
    if not spell then return end
    entry.found = true   -- une seule tentative : un refus (conditions, recharge) n'est pas réessayé
    entry.name = Trim(spell.fullName) ~= "" and spell.fullName or Trim(place.arcEnterSpell)
    entry.applied = CastArc(place.arcEnterSpell, place.arcVault)
end

-- Défait l'effet : interrompt le sort d'entrée encore en cours (boucles,
-- délais) puis lance le sort de sortie. Sans sort de sortie, rien n'est
-- interrompu : l'effet suit sa propre durée / ses reverts.
local function RemoveArc(entry)
    local place = entry.place
    if not entry.applied or Trim(place.arcExitSpell) == "" then return end
    if type(ARC) == "table" and type(ARC.STOP) == "function" then
        pcall(ARC.STOP, ARC, Trim(place.arcEnterSpell))
    end
    CastArc(place.arcExitSpell, place.arcVault)
end

function ZG:ArcEnter(place)
    if ZG.arc[place.id] or not HasArc(place) then return end
    local entry = { place = place, active = true, applied = false, name = Trim(place.arcEnterSpell) }
    ZG.arc[place.id] = entry
    ApplyArc(entry)
    NotifyArc()
end

function ZG:ArcLeave(placeId)
    local entry = ZG.arc[placeId]
    if not entry then return end
    ZG.arc[placeId] = nil
    if entry.active then RemoveArc(entry) end
    NotifyArc()
end

function ZG:ArcLeaveAll()
    for id in pairs(ZG.arc) do ZG:ArcLeave(id) end
end

-- Choix du joueur sur place (voir UI_Arcanum.lua) : retirer l'effet, ou le
-- remettre. "Remettre" relance aussi un effet retiré par d'autres moyens.
function ZG:ArcSetActive(placeId, active)
    local entry = ZG.arc[placeId]
    if not entry or entry.place.arcToggle == false then return end
    if active then
        entry.active = true
        ApplyArc(entry)
    elseif entry.active then
        RemoveArc(entry)
        entry.active, entry.applied, entry.found = false, false, false
    end
    NotifyArc()
end

function ZG:GetArcEffects()
    local list = {}
    for id, entry in pairs(ZG.arc) do
        list[#list + 1] = {
            id = id, name = entry.name, active = entry.active, applied = entry.applied,
            canToggle = entry.place.arcToggle ~= false,
            canRemove = Trim(entry.place.arcExitSpell) ~= "",
        }
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

-- Aligne les effets Arcanum sur ZG.here.
local function SyncArc()
    for placeId in pairs(ZG.here) do
        local place = ZG:FindPlace(placeId)
        local entry = ZG.arc[placeId]
        if place and HasArc(place) then
            if not entry then
                ZG:ArcEnter(place)
            else
                entry.place = place   -- la synchro remplace la table du lieu
                -- Sort encore introuvable à l'entrée (coffre de phase en
                -- chargement, ID en cours de saisie) : on réessaie tant que voulu.
                if entry.active and not entry.found then
                    ApplyArc(entry)
                    if entry.applied then NotifyArc() end
                end
            end
        end
    end
    for id in pairs(ZG.arc) do
        if not ZG.here[id] or not HasArc(ZG:FindPlace(id)) then ZG:ArcLeave(id) end
    end
end

-- Lieux où se trouve le joueur, pour l'éditeur.
function ZG:IsInPlace(placeId)
    return ZG.here[placeId] ~= nil
end

local function IsClosed(sub)
    return sub.shape == "polygon" and sub.regionReady and sub.points and #sub.points >= 3
end

function ZG:Tick()
    local px, py, _, instanceID = ZG:GetPlayerPose()
    if not px then return end

    local live, crossings = {}, {}
    for _, zone in pairs(EnsureDB().zones) do
        for id, sub in pairs(zone.subZones) do
            if sub.enabled and sub.mapID == instanceID then
                live[id] = true
                local side = ClassifySide(sub, px, py)
                if side then
                    local prev = ZG.state[id]
                    if prev and prev ~= side then
                        -- Vers le côté vert / l'intérieur : on quitte le lieu de
                        -- sortie pour celui d'entrée ; l'inverse en revenant.
                        -- (pas de "a and b or c" : un lieu de sortie vide est un cas normal)
                        -- Périmètre : en sortir ne mène nulle part par lui-même ; le
                        -- lieu d'arrivée vient du périmètre voisin (frontière commune).
                        local from, to = sub.enterPlace, sub.shape ~= "polygon" and sub.leavePlace or nil
                        if prev < 0 and side > 0 then from, to = to, from end
                        if from and from ~= to then ZG.here[from] = nil end
                        if to then ZG.here[to] = id end
                        crossings[#crossings + 1] = { sub = sub, from = from, to = to }
                    elseif not prev and IsClosed(sub) and sub.enterPlace then
                        -- Se découvrir dedans (périmètre tout juste validé, survol) affiche
                        -- la bannière ; juste après un chargement ou une connexion, non.
                        if side > 0 then
                            local fresh = ZG.here[sub.enterPlace] == nil
                            ZG.here[sub.enterPlace] = id
                            if fresh and GetTime() > (ZG.quietUntil or 0) then
                                crossings[#crossings + 1] = { sub = sub, to = sub.enterPlace }
                            end
                        elseif ZG.here[sub.enterPlace] == id then
                            ZG.here[sub.enterPlace] = nil
                        end
                    end
                    ZG.state[id] = side
                elseif not IsClosed(sub) then
                    -- Keep the last stable side through the boundary deadband.
                    -- Otherwise slow crossings lose their origin before reaching
                    -- the opposite side and never trigger their effects.
                    ZG.state[id] = nil
                end
            else
                ZG.state[id] = nil
            end
        end
    end

    -- Frontière commune : sortir de A « vers rien » et entrer dans B « depuis
    -- rien » au même instant, c'est un seul passage direct A → B.
    local exits, entries = {}, {}
    for _, c in ipairs(crossings) do
        if c.from and not c.to then exits[#exits + 1] = c
        elseif c.to and not c.from then entries[#entries + 1] = c end
    end
    for i = 1, math.min(#exits, #entries) do
        local exit, entry = exits[i], entries[i]
        exit.merged, entry.merged = true, true
        ZG:TriggerCrossing(entry.sub, exit.from, entry.to)
    end
    for _, c in ipairs(crossings) do
        if not c.merged then ZG:TriggerCrossing(c.sub, c.from, c.to) end
    end

    for placeId, source in pairs(ZG.here) do
        if not live[source] then ZG.here[placeId] = nil end
    end
    SyncArc()
end

-- Action d'un lieu au passage : un message local (texte imprimé dans VOTRE
-- chat) et/ou une commande (aura ou brute — gérée via
-- OS2.ModuleRules.ExecuteServerCommand comme les règles d'aura de
-- Lantern/Torch : ça n'exécute pas de code, juste un message envoyé au
-- serveur qui décide seul quoi en faire). Inconditionnel pour TOUT joueur
-- qui passe, y compris dans un lieu créé par quelqu'un d'autre — volontaire,
-- pour qu'un MJ puisse forcer un message/une aura à un joueur sans que
-- celui-ci ait à autoriser quoi que ce soit.
-- mode = "enter" (arrivée dans le lieu) | "leave" (départ du lieu).
function ZG:RunPlaceAction(place, mode)
    local enabled = (mode == "enter" and place.actionEnterEnabled) or (mode == "leave" and place.actionLeaveEnabled)
    if not enabled then return end

    if place.actionMessage and place.actionMessage ~= "" then
        OmegaHub.Print(place.actionMessage)
    end

    if place.actionCommand and place.actionCommand ~= "" and OS2 and OS2.ModuleRules and OS2.ModuleRules.ExecuteServerCommand then
        -- Un ID numérique = raccourci "aura" : appliquée en arrivant, retirée
        -- en partant (ExecuteServerCommand préfixe .aura/.unaura tout seul si
        -- la commande n'est qu'un nombre).
        OS2.ModuleRules.ExecuteServerCommand(place.actionCommand, (mode == "enter") and "apply" or "remove")
    end
end

-- Son de passage : value est soit un ID SoundKit Blizzard (nombre), soit un
-- chemin de fichier ("Sound\..." natif ou un .ogg/.mp3 déposé par vous dans
-- le dossier de l'addon) — testé dans cet ordre, silencieux si vide ou si
-- rien ne joue. Toujours protégé (pcall) : un chemin invalide ne doit jamais
-- casser le passage.
local function ResolveSoundValue(value)
    value = (value or ""):match("^%s*(.-)%s*$") or ""
    if value == "" then return end

    local asId = tonumber(value)
    if asId and PlaySound then
        local ok, played = pcall(PlaySound, asId, "Master")
        if ok and played then return end
    end
    if PlaySoundFile then
        pcall(PlaySoundFile, value, "Master")
    end
end

-- direction = "forward" (arrivée : son d'entrée) | "backward" (départ : son de sortie).
function ZG:PlayCrossingSound(theme, direction)
    if not theme then return end
    local value = (direction == "forward") and theme.soundEnter or theme.soundExit
    ResolveSoundValue(value)
end

-- Bannière et son du lieu d'arrivée ; sans lieu d'arrivée, seulement le son
-- de sortie du lieu quitté. Puis les actions : départ, ensuite arrivée.
function ZG:TriggerCrossing(sub, fromId, toId)
    local from, fromZone = ZG:FindPlace(fromId)
    local to, toZone = ZG:FindPlace(toId)

    if to then
        local theme = ZG:ResolveTheme(to, toZone)
        local title, subtitle = ZG:ResolveBannerText(to, toZone)
        if title and ZG.ShowBanner then
            ZG:ShowBanner(title, subtitle, theme)
        end
        ZG:PlayCrossingSound(theme, "forward")
    elseif from then
        ZG:PlayCrossingSound(ZG:ResolveTheme(from, fromZone), "backward")
    end

    if from and from ~= to then ZG:RunPlaceAction(from, "leave") end
    if to and to ~= from then ZG:RunPlaceAction(to, "enter") end
end

-- ── Réseau : diffusion de l'état + rattrapage + octroi ────────────────────
-- Protocole texte, même esprit que Character/Core.lua et
-- Dice/Modules/Network.lua : "TAG|champ|champ|...". Un seul type de message
-- est chunké (l'état complet, potentiellement gros) — voir
-- BroadcastInitiative/HandleInitiativeChunk dans Character/Core.lua.

-- Points d'une région, encodés "x1,y1;x2,y2;..." — pas de Enc() nécessaire
-- (que des chiffres/points/tirets/virgules/points-virgules, jamais de ":").
local function PackPoints(points)
    if not points or #points == 0 then return "" end
    local parts = {}
    for _, p in ipairs(points) do
        local name = p.name and (p.name:gsub("[;,:|\n\r]", " ")) or nil
        table.insert(parts, string.format("%.1f,%.1f", p.x, p.y) .. (name and name ~= "" and ("," .. name) or ""))
    end
    return table.concat(parts, ";")
end

-- Frontières déclarées : "nom~de~à~sens;…" (noms sans ; ~ : ,).
local function PackBorders(borders)
    local parts = {}
    for _, b in ipairs(borders or {}) do
        parts[#parts + 1] = table.concat({ (b.name:gsub("[;~:,|]", " ")), b.from, b.to, b.forward and 1 or 0 }, "~")
    end
    return table.concat(parts, ";")
end

local function UnpackBorders(str)
    local borders = {}
    for chunk in (str or ""):gmatch("[^;]+") do
        local name, from, to, forward = chunk:match("^(.-)~(%d+)~(%d+)~([01])$")
        if name then borders[#borders + 1] = { name = name, from = tonumber(from), to = tonumber(to), forward = forward == "1" } end
    end
    return borders
end

local function UnpackPoints(str)
    local points = {}
    if not str or str == "" then return points end
    for chunk in str:gmatch("[^;]+") do
        local x, y, name = chunk:match("^(%-?[%d.]+),(%-?[%d.]+),?(.*)$")
        if x and y then
            table.insert(points, { x = tonumber(x), y = tonumber(y), name = name ~= "" and name or nil })
        end
    end
    return points
end

-- Une couleur, encodée "r,g,b" (ou "r,g,b,a" si withAlpha) — mêmes chiffres
-- que PackPoints, pas de Enc() nécessaire non plus.
local function PackColor(c, withAlpha)
    c = c or {}
    if withAlpha then
        return string.format("%.3f,%.3f,%.3f,%.3f", c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end
    return string.format("%.3f,%.3f,%.3f", c[1] or 1, c[2] or 1, c[3] or 1)
end

local function UnpackColor(str, withAlpha)
    local r, g, b, a
    if withAlpha then
        r, g, b, a = (str or ""):match("^([%-%d.]+),([%-%d.]+),([%-%d.]+),([%-%d.]+)$")
    else
        r, g, b = (str or ""):match("^([%-%d.]+),([%-%d.]+),([%-%d.]+)$")
    end
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not r then return { 1, 1, 1, 1 } end
    return { r, g, b, withAlpha and (tonumber(a) or 1) or nil }
end

-- Sérialise tout ce que CE personnage possède (thèmes, zones + leurs
-- sous-zones, dont il est l'auteur) en un seul bloc, une ligne par
-- enregistrement. Les thèmes d'abord : purement informatif pour l'ordre de
-- lecture (ResolveTheme ne résout qu'au moment du franchissement, donc
-- l'ordre d'arrivée des lignes n'a pas d'incidence réelle).
local function PackState()
    local me = MyName()
    local db = EnsureDB()
    local lines = {}

    for thid, theme in pairs(db.themes) do
        if theme.creator == me then
            table.insert(lines, table.concat({
                "THEME", Enc(thid), Enc(theme.name), Enc(theme.font), theme.titleSize,
                PackColor(theme.titleColor), PackColor(theme.subColor),
                theme.outline and 1 or 0, theme.uppercase and 1 or 0, theme.letterSpacing and 1 or 0,
                Enc(theme.sepStyle), PackColor(theme.sepColor, true),
                theme.bgEnabled and 1 or 0, PackColor(theme.bgColor, true),
                theme.fadeIn, theme.hold, theme.fadeOut,
                Enc(theme.soundEnter or ""), Enc(theme.soundExit or ""),
                Enc(theme.customFont or ""), theme.midSepEnabled and 1 or 0,
                Enc(theme.frameStyle or "none"), PackColor(theme.frameColor, true),
                Enc(theme.design or "classic"), Enc(theme.motion or "fade"),
                Enc(theme.placement or "top"), theme.bannerWidth or 600,
            }, SEP))
        end
    end

    for cid, country in pairs(db.countries) do
        if country.creator == me then
            table.insert(lines, table.concat({ "COUNTRY", Enc(cid), Enc(country.name) }, SEP))
        end
    end

    -- Ordre : la région, ses lieux, puis ses passages (qui les référencent).
    for zid, zone in pairs(db.zones) do
        if zone.creator == me then
            table.insert(lines, table.concat({ "ZONE", Enc(zid), Enc(zone.name), Enc(zone.themeId or ""), Enc(zone.countryId or "") }, SEP))
            for pid, place in pairs(zone.places) do
                local aliases = {}
                for alias in pairs(place.aliases or {}) do aliases[#aliases + 1] = Enc(alias) end
                table.sort(aliases)
                table.insert(lines, table.concat({
                    "PLACE", Enc(pid), Enc(zid), Enc(place.name), Enc(place.themeId or ""),
                    Enc(place.actionMessage or ""), Enc(place.actionCommand or ""),
                    place.actionEnterEnabled and 1 or 0, place.actionLeaveEnabled and 1 or 0,
                    Enc(place.arcEnterSpell or ""), Enc(place.arcExitSpell or ""),
                    Enc(place.arcVault or "phase"), (place.arcToggle == false) and 0 or 1,
                    table.concat(aliases, ","),
                }, SEP))
            end
            for sid, sub in pairs(zone.subZones) do
                table.insert(lines, table.concat({
                    "PASS", Enc(sid), Enc(zid), Enc(sub.name), sub.enabled and 1 or 0,
                    sub.mapID or 0, sub.x or 0, sub.y or 0, sub.facing or 0, sub.width or DEFAULT_WIDTH,
                    Enc(sub.shape or "line"), sub.regionReady and 1 or 0, PackPoints(sub.points),
                    Enc(sub.enterPlace or ""), Enc(sub.leavePlace or ""), PackBorders(sub.borders),
                }, SEP))
            end
        end
    end

    return table.concat(lines, "\n")
end

local function ApplyStateLine(line, sender)
    local fields = { strsplit(SEP, line) }
    local tag = fields[1]

    if tag == "THEME" then
        local id, name, font, titleSize = fields[2], fields[3], fields[4], fields[5]
        if id and id ~= "" then
            ZoneGateDB.themes[id] = {
                id = id, name = name, creator = sender,
                font = (ZG.FontPaths[font] or font == "custom") and font or "frizqt",
                titleSize = tonumber(titleSize) or ZG.DefaultTheme.titleSize,
                titleColor = UnpackColor(fields[6]), subColor = UnpackColor(fields[7]),
                outline = fields[8] == "1", uppercase = fields[9] == "1", letterSpacing = fields[10] == "1",
                sepStyle = ZG.SepLabels[fields[11]] and fields[11] or "single",
                sepColor = UnpackColor(fields[12], true),
                bgEnabled = fields[13] == "1",
                bgColor = UnpackColor(fields[14], true),
                fadeIn = tonumber(fields[15]) or ZG.DefaultTheme.fadeIn,
                hold = tonumber(fields[16]) or ZG.DefaultTheme.hold,
                fadeOut = tonumber(fields[17]) or ZG.DefaultTheme.fadeOut,
                soundEnter = fields[18] or "", soundExit = fields[19] or "",
                customFont = fields[20] or "", midSepEnabled = fields[21] == "1",
                frameStyle = ZG.FrameLabels[fields[22]] and fields[22] or "none",
                frameColor = UnpackColor(fields[23], true),
                design = fields[24] or "classic", motion = fields[25] or "fade",
                placement = fields[26] or "top",
                bannerWidth = math.max(400,math.min(900,tonumber(fields[27]) or 600)),
            }
        end
    elseif tag == "COUNTRY" then
        local id, name = fields[2], fields[3]
        if id and id ~= "" then
            ZoneGateDB.countries = ZoneGateDB.countries or {}
            ZoneGateDB.countries[id] = { id = id, name = name or "", creator = sender }
        end
    elseif tag == "ZONE" then
        local id, name, themeId, countryId = fields[2], fields[3], fields[4], fields[5]
        if id and id ~= "" then
            local zone = ZoneGateDB.zones[id]
            if not zone then
                zone = { id = id, subZones = {}, places = {} }
                ZoneGateDB.zones[id] = zone
            end
            zone.name, zone.creator = name, sender
            zone.themeId = (themeId and themeId ~= "") and themeId or nil
            zone.countryId = (countryId and countryId ~= "") and countryId or nil
            zone.subZones = zone.subZones or {}
            zone.places = zone.places or {}
        end
    elseif tag == "PLACE" then
        local id, zoneId = fields[2], fields[3]
        local zone = ZoneGateDB.zones[zoneId]
        if zone and id and id ~= "" then
            local place = NewPlace(id, zoneId, fields[4] or "")
            place.themeId = (fields[5] and fields[5] ~= "") and fields[5] or nil
            place.actionMessage, place.actionCommand = fields[6] or "", fields[7] or ""
            place.actionEnterEnabled, place.actionLeaveEnabled = fields[8] == "1", fields[9] == "1"
            place.arcEnterSpell, place.arcExitSpell = fields[10] or "", fields[11] or ""
            place.arcVault = (fields[12] == "personal") and "personal" or "phase"
            place.arcToggle = fields[13] ~= "0"
            for alias in (fields[14] or ""):gmatch("[^,]+") do place.aliases[alias] = true end
            zone.places[id] = place
        end
    elseif tag == "PASS" then
        local id, zoneId = fields[2], fields[3]
        local zone = ZoneGateDB.zones[zoneId]
        if zone and id and id ~= "" then
            zone.subZones[id] = {
                id = id, zoneId = zoneId, name = fields[4] or "", creator = sender, passage = true,
                enabled = fields[5] == "1",
                mapID = tonumber(fields[6]), x = tonumber(fields[7]), y = tonumber(fields[8]),
                facing = tonumber(fields[9]), width = tonumber(fields[10]),
                shape = (fields[11] == "polygon") and "polygon" or "line",
                regionReady = fields[12] == "1",
                points = UnpackPoints(fields[13]),
                enterPlace = (fields[14] and fields[14] ~= "") and fields[14] or nil,
                leavePlace = (fields[15] and fields[15] ~= "") and fields[15] or nil,
                borders = UnpackBorders(fields[16]),
            }
        end
    elseif tag == "SUB" then
        -- Auteur avec une version antérieure aux lieux : converti à la volée.
        local id, zoneId, name, enabled, mapID, x, y, facing, width, shape, fwdEn, backEn, regionReady, pointsStr,
              fwdName, backName, actionMessage, actionCommand, actFwdEn, actBackEn, themeId,
              arcEnter, arcExit, arcVault, arcToggle =
            fields[2], fields[3], fields[4], fields[5], fields[6],
            fields[7], fields[8], fields[9], fields[10], fields[11], fields[12], fields[13],
            fields[14], fields[15], fields[16], fields[17], fields[18], fields[19], fields[20], fields[21], fields[22],
            fields[23], fields[24], fields[25], fields[26]
        local zone = ZoneGateDB.zones[zoneId]
        if zone and id and id ~= "" then
            zone.subZones[id] = {
                id = id, zoneId = zoneId, name = name, creator = sender,
                enabled = enabled == "1",
                mapID = tonumber(mapID), x = tonumber(x), y = tonumber(y),
                facing = tonumber(facing), width = tonumber(width),
                shape = (shape == "circle" and "circle") or (shape == "polygon" and "polygon") or "line",
                -- "circle" : envoyé par un auteur plus ancien, converti ci-dessous.
                forwardEnabled  = fwdEn == "1",
                backwardEnabled = backEn == "1",
                forwardName = fwdName or "",
                backwardName = backName or "",
                regionReady = regionReady == "1",
                points = UnpackPoints(pointsStr),
                actionMessage = actionMessage or "",
                actionCommand = actionCommand or "",
                actionForwardEnabled  = actFwdEn == "1",
                actionBackwardEnabled = actBackEn == "1",
                themeId = (themeId and themeId ~= "") and themeId or nil,
                -- Absents chez un auteur plus ancien : aucun sort lié.
                arcEnterSpell = arcEnter or "", arcExitSpell = arcExit or "",
                arcVault = (arcVault == "personal") and "personal" or "phase",
                arcToggle = arcToggle ~= "0",
            }
            CircleToPerimeter(zone.subZones[id])
            zone.places = zone.places or {}
            ConvertLegacySub(zone, zone.subZones[id])
        end
    end
end

-- Resynchro complète : on retire d'abord tout ce que ce sender possédait
-- avant de réappliquer, pour que les suppressions se propagent aussi (pas
-- seulement les ajouts/modifs).
local function ApplyState(payload, sender)
    local db = EnsureDB()
    for zid, zone in pairs(db.zones) do
        if zone.creator == sender then db.zones[zid] = nil end
    end
    for thid, theme in pairs(db.themes) do
        if theme.creator == sender then db.themes[thid] = nil end
    end
    for cid, country in pairs(db.countries) do
        if country.creator == sender then db.countries[cid] = nil end
    end
    for line in payload:gmatch("[^\n]+") do
        ApplyStateLine(line, sender)
    end
    if ZoneGatePanel and ZoneGatePanel.RefreshAll then
        ZoneGatePanel:RefreshAll()
    end
end

local stateMsgSeq = 0

-- File d'envoi : le jeu limite le débit des messages d'extension (une
-- dizaine d'un coup, puis environ un par seconde). Un grand périmètre fait
-- une centaine de morceaux : on les expédie un par un, on réessaie un
-- morceau refusé, et un nouvel état remplace celui encore en attente pour
-- le même destinataire (inutile d'envoyer une version déjà dépassée).
local SEND_INTERVAL = 0.2
local SEND_RETRY    = 1.0
local sendQueue = {}   -- { key, channel, target, packets, part, failures }
local sendFrame, sendWait = nil, 0

local function Sent(result)
    if result == true or result == 0 then return true end
    return Enum and Enum.SendAddonMessageResult and result == Enum.SendAddonMessageResult.Success or false
end

local function PumpSend(_, elapsed)
    sendWait = sendWait - elapsed
    if sendWait > 0 then return end
    local job = sendQueue[1]
    if not job then sendFrame:SetScript("OnUpdate", nil); return end
    if Sent(SendAddon(job.packets[job.part], job.channel, job.target)) then
        job.part, job.failures, sendWait = job.part + 1, 0, SEND_INTERVAL
        if job.part > #job.packets then table.remove(sendQueue, 1) end
    else
        job.failures, sendWait = job.failures + 1, SEND_RETRY
        if job.failures >= 20 then table.remove(sendQueue, 1) end
    end
end

local function QueueSend(channel, target, packets)
    local key = channel .. ":" .. tostring(target or "")
    for i, job in ipairs(sendQueue) do
        if job.key == key then table.remove(sendQueue, i); break end
    end
    sendQueue[#sendQueue + 1] = { key = key, channel = channel, target = target, packets = packets, part = 1, failures = 0 }
    sendFrame = sendFrame or CreateFrame("Frame")
    sendFrame:SetScript("OnUpdate", PumpSend)
end

local function SendChunkedState(channel, target)
    if not channel then return end
    local payload = PackState()
    if payload == "" then return end

    stateMsgSeq = stateMsgSeq + 1
    local msgId = stateMsgSeq
    local total = math.max(1, math.ceil(#payload / CHUNK_SIZE))
    local packets = {}
    for i = 1, total do
        local chunk = payload:sub((i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
        packets[i] = string.format("Z|%d|%d|%d|%s", msgId, i, total, chunk)
    end
    QueueSend(channel, target, packets)
end

-- Diffusion débouncée (0.45s) pour ne pas spammer le groupe pendant qu'on
-- tape dans un champ — même principe que ScheduleBroadcast dans
-- Character/Core.lua.
local broadcastFrame
local pendingBroadcast = false
local broadcastAt = 0

function ZG:ScheduleBroadcast(delay)
    broadcastAt = GetTime() + (delay or 0.45)
    if pendingBroadcast then return end
    pendingBroadcast = true

    broadcastFrame = broadcastFrame or CreateFrame("Frame")
    broadcastFrame:SetScript("OnUpdate", function(self)
        if GetTime() >= broadcastAt then
            self:SetScript("OnUpdate", nil)
            pendingBroadcast = false
            for _, ct in ipairs(BroadcastChannels()) do
                SendChunkedState(ct.channel, ct.target)
            end
        end
    end)
end

local incomingBuffers = {}   -- [sender] = { msgId, total, chunks, count }

local function HandleStateChunk(sender, msgIdStr, indexStr, totalStr, chunk)
    local msgId, index, total = tonumber(msgIdStr), tonumber(indexStr), tonumber(totalStr)
    if not (msgId and index and total) then return end

    local buf = incomingBuffers[sender]
    if not buf or buf.msgId ~= msgId then
        buf = { msgId = msgId, total = total, chunks = {}, count = 0 }
        incomingBuffers[sender] = buf
    end
    if buf.chunks[index] == nil then
        buf.chunks[index] = chunk or ""
        buf.count = buf.count + 1
    end
    if buf.count >= buf.total then
        local parts = {}
        for i = 1, buf.total do parts[i] = buf.chunks[i] or "" end
        incomingBuffers[sender] = nil
        ApplyState(table.concat(parts), sender)
    end
end

-- Un client qui vient d'ouvrir le panneau demande le rattrapage ; on lui
-- répond directement en WHISPER (pas de rediffusion groupe, pour ne pas
-- spammer toute la table à chaque demande).
local function HandleSyncRequest(sender)
    if not sender or sender == MyName() then return end
    SendChunkedState("WHISPER", sender)
end

function ZG:RequestSync()
    for _, ct in ipairs(BroadcastChannels()) do
        SendAddon("SYNC", ct.channel, ct.target)
    end
end

local syncedThisSession = false
function ZG:MaybeRequestSync()
    if syncedThisSession then return end
    syncedThisSession = true
    ZG:RequestSync()
end

-- Octroi manuel : le créateur débloque, INDÉPENDAMMENT, le nom de la Zone
-- ou le nom d'une Sous-zone pour un joueur précis (voir ResolveBannerText
-- pour les 4 combinaisons résultantes). Envoyé en whisper direct + repli
-- groupe/guilde (le whisper seul n'est pas fiable à 100%). La liste "qui a appris quoi" est
-- tenue localement chez le créateur (pas diffusée) : elle n'a de sens que
-- pour lui, et n'a pas besoin d'un aller-retour réseau pour exister — ces
-- fonctions l'enregistrent au moment de l'envoi. Protocole : "G|<scope>|<id>|<cible>"
-- avec scope = "Z" (nom de zone) ou "S" (nom de sous-zone).
function ZG:SendZoneGrant(zoneId, targetName)
    targetName = (targetName or ""):match("^%s*(.-)%s*$") or ""
    if targetName == "" or not zoneId or zoneId == "" then return false end

    local payload = "G|Z|" .. Enc(zoneId) .. "|" .. Enc(targetName)
    local sentWhisper = SendAddon(payload, "WHISPER", targetName)
    local sentOther = false
    for _, ct in ipairs(BroadcastChannels()) do
        sentOther = SendAddon(payload, ct.channel, ct.target) or sentOther
    end
    local sent = sentWhisper or sentOther or false

    if sent then
        local zone = ZG:GetZone(zoneId)
        if zone then
            zone.grantedTo = zone.grantedTo or {}
            zone.grantedTo[StripRealm(targetName)] = true
        end
    end

    return sent
end

function ZG:SendPlaceGrant(placeId, targetName)
    targetName = (targetName or ""):match("^%s*(.-)%s*$") or ""
    if targetName == "" or not placeId or placeId == "" then return false end

    local payload = "G|S|" .. Enc(placeId) .. "|" .. Enc(targetName)
    local sentWhisper = SendAddon(payload, "WHISPER", targetName)
    local sentOther = false
    for _, ct in ipairs(BroadcastChannels()) do
        sentOther = SendAddon(payload, ct.channel, ct.target) or sentOther
    end
    local sent = sentWhisper or sentOther or false

    if sent then
        local place = ZG:FindPlace(placeId)
        if place then
            place.grantedTo = place.grantedTo or {}
            place.grantedTo[StripRealm(targetName)] = true
        end
    end

    return sent
end

-- Liste triée ({name=...}) des joueurs à qui CE personnage a débloqué le nom
-- de ce lieu (enregistrement local, jamais diffusé — voir SendPlaceGrant).
function ZG:GetPlaceGrantedList(placeId)
    local place = ZG:FindPlace(placeId)
    if not place or not place.grantedTo then return {} end
    local list = {}
    for name in pairs(place.grantedTo) do table.insert(list, { name = name }) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Même chose au niveau Zone : joueurs à qui le NOM DE LA ZONE elle-même a
-- été débloqué (indépendant des noms de sous-zones — voir SendZoneGrant).
function ZG:GetZoneGrantedList(zoneId)
    local zone = ZG:GetZone(zoneId)
    if not zone or not zone.grantedTo then return {} end
    local list = {}
    for name in pairs(zone.grantedTo) do table.insert(list, { name = name }) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- Révoque : retire l'entrée locale + prévient le client visé pour qu'il
-- oublie sa propre connaissance de ce nom. Protocole symétrique de
-- SendZoneGrant/SendPlaceGrant : "U|<scope>|<id>|<cible>".
function ZG:RevokePlaceGrant(placeId, targetName)
    local place, zone = ZG:FindPlace(placeId)
    if not place or zone.creator ~= MyName() then return false end

    if place.grantedTo then place.grantedTo[StripRealm(targetName)] = nil end

    local payload = "U|S|" .. Enc(placeId) .. "|" .. Enc(targetName)
    local sentWhisper = SendAddon(payload, "WHISPER", targetName)
    local sentOther = false
    for _, ct in ipairs(BroadcastChannels()) do
        sentOther = SendAddon(payload, ct.channel, ct.target) or sentOther
    end
    return sentWhisper or sentOther or false
end

function ZG:RevokeZoneGrant(zoneId, targetName)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return false end

    if zone.grantedTo then zone.grantedTo[StripRealm(targetName)] = nil end

    local payload = "U|Z|" .. Enc(zoneId) .. "|" .. Enc(targetName)
    local sentWhisper = SendAddon(payload, "WHISPER", targetName)
    local sentOther = false
    for _, ct in ipairs(BroadcastChannels()) do
        sentOther = SendAddon(payload, ct.channel, ct.target) or sentOther
    end
    return sentWhisper or sentOther or false
end

function ZG:ForgetLearnedZoneName(zoneId)
    if not zoneId then return end
    EnsureCharDB().learnedZones[zoneId] = nil
end

function ZG:ForgetLearnedSubZoneName(subZoneId)
    if not subZoneId then return end
    EnsureCharDB().learnedSubZones[subZoneId] = nil
end

local function HandleGrant(rest)
    local scope, id, targetName = rest:match("^([^|]*)|([^|]*)|(.*)$")
    if not scope or not id or id == "" then return end
    if StripRealm(targetName or ""):lower() ~= MyName():lower() then return end
    if scope == "Z" then
        ZG:MarkLearnedZoneName(id)
    elseif scope == "S" then
        ZG:MarkLearnedSubZoneName(id)
    else
        return
    end
    if ZoneGatePanel and ZoneGatePanel.RefreshAll then
        ZoneGatePanel:RefreshAll()
    end
end

local function HandleRevoke(rest)
    local scope, id, targetName = rest:match("^([^|]*)|([^|]*)|(.*)$")
    if not scope or not id or id == "" then return end
    if StripRealm(targetName or ""):lower() ~= MyName():lower() then return end
    if scope == "Z" then
        ZG:ForgetLearnedZoneName(id)
    elseif scope == "S" then
        ZG:ForgetLearnedSubZoneName(id)
    else
        return
    end
    if ZoneGatePanel and ZoneGatePanel.RefreshAll then
        ZoneGatePanel:RefreshAll()
    end
end

netFrame:SetScript("OnEvent", function(_, event, prefix, payload, _, sender)
    if event ~= "CHAT_MSG_ADDON" or prefix ~= PREFIX then return end
    sender = StripRealm(sender or "")
    if sender == "" or sender == MyName() then return end

    if payload == "SYNC" then
        HandleSyncRequest(sender)
        return
    end

    local tag, rest = payload:match("^(%a+)|(.*)$")
    if tag == "Z" then
        local msgId, index, total, chunk = rest:match("^(%d+)|(%d+)|(%d+)|(.*)$")
        if msgId then HandleStateChunk(sender, msgId, index, total, chunk) end
    elseif tag == "G" then
        HandleGrant(rest)
    elseif tag == "U" then
        HandleRevoke(rest)
    end
end)

function ZG:RegisterNetwork()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    elseif RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(PREFIX)
    end
    netFrame:RegisterEvent("CHAT_MSG_ADDON")
    -- Rejoint le canal global tout de suite (pas d'attente d'un premier
    -- broadcast) pour qu'il ait le temps d'être prêt côté serveur avant le
    -- premier SYNC (voir C_Timer.After dans Enable).
    EnsureBroadcastChannel()
end

function ZG:UnregisterNetwork()
    netFrame:UnregisterEvent("CHAT_MSG_ADDON")
end

-- ── Ticker ───────────────────────────────────────────────────────────────────

local ticker

function ZG:StartTicker()
    if ticker then return end
    ticker = C_Timer.NewTicker(TICK_INTERVAL, function() ZG:Tick() end)
end

function ZG:StopTicker()
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

-- ── Enable / Disable ──────────────────────────────────────────────────────────

function ZG:Enable()
    SLASH_OZONEGATE1 = "/oche"
    SLASH_OZONEGATE2 = "/ocheck"
    SLASH_OZONEGATE3 = "/crossings"
    SlashCmdList["OZONEGATE"] = function(msg)
        local arg=(msg or ""):match("^%s*(%S+)") or ""
        if arg=="debug" then
            ZG:DebugPosition()
        elseif arg=="clean" then
            local count=ZG.CleanPresetThemes and ZG:CleanPresetThemes() or 0
            OmegaHub.Print(count>0 and (count.." thème(s) de galerie supprimé(s).") or "Bibliothèque déjà propre.")
        else
            if ZoneGatePanel then ZoneGatePanel:Toggle() end
        end
    end

    ZG:ResetState()
    ZG:StartTicker()
    ZG:RegisterNetwork()
    -- Dès la connexion : je demande l'état de ceux déjà en ligne (SYNC,
    -- diffusé groupe + guilde + canal global — donc TOUT joueur avec
    -- l'addon actif) ET je pousse le mien (utile si c'est MOI le créateur
    -- qui viens de me connecter et que d'autres étaient déjà en ligne, sans
    -- SYNC à attendre de leur part). Pas de doublon si je n'ai aucune zone :
    -- PackState()/SendChunkedState n'envoient rien dans ce cas. Délai de 3s
    -- (pas 2) pour laisser le temps au canal global de se rejoindre côté
    -- serveur (voir EnsureBroadcastChannel dans RegisterNetwork).
    C_Timer.After(3, function()
        ZG:MaybeRequestSync()
        ZG:ScheduleBroadcast(0)
    end)

    OmegaHub:SetModuleLoaded("ZoneGate", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Crossings activé.  |cffAAAAAA/oche|r")
    end
end

function ZG:Disable()
    SLASH_OZONEGATE1 = nil
    SLASH_OZONEGATE2 = nil
    SlashCmdList["OZONEGATE"] = nil

    ZG:StopTicker()
    ZG:ArcLeaveAll()
    ZG:UnregisterNetwork()
    ZG:ResetState()
    if ZoneGatePanel then ZoneGatePanel:Hide() end
    if ZoneGateThemePanel then ZoneGateThemePanel:Hide() end
    if ZG.HideBanner then ZG:HideBanner() end

    OmegaHub:SetModuleLoaded("ZoneGate", false)
    OmegaHub.Print("Crossings désactivé.")
end

-- ── Réinitialisation d'état au changement de zone/instance ────────────────

local resetFrame = CreateFrame("Frame")
resetFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
resetFrame:SetScript("OnEvent", function()
    ZG:ResetState()
end)

-- ── Init ─────────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({
        name    = "ZoneGate",
        title   = "Crossings",
        desc    = "Pays, régions, lieux et passages",
        version = ZONEGATE_VERSION,
        module  = ZG,
    })
    EnsureDB()
    EnsureCharDB()
    MigrateOldCheckpoints()
    MigrateCircles()
    MigrateBannerPlacement()
    MigratePlaces()
    if OmegaHub:IsModuleEnabled("ZoneGate") then ZG:Enable() end
    f:UnregisterAllEvents()
end)
