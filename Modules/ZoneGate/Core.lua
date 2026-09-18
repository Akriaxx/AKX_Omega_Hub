-- ============================================================
--  Zone Gate — Core
--  Une Zone contient des Sous-zones ; chaque Sous-zone EST son
--  propre checkpoint (position/forme/largeur capturées à la
--  création, "ici") — pas de liaison manuelle séparée. La
--  franchir déclenche une bannière avec le nom de la Zone + le
--  nom de la Sous-zone, dans le sens "entrée" et/ou "retour".
--  Trois formes de checkpoint : "line" (porte), "circle" (village)
--  et "polygon" (région à N points — voir AddRegionPoint /
--  FinishRegion). Le nom n'est visible que pour l'auteur de la
--  Zone tant qu'il ne l'a pas débloqué pour un joueur donné.
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
local WIDTH_MARGIN   = 1.0   -- yards de tolérance (pas de poll / bord du cercle ou de la région)
local DEFAULT_WIDTH   = 6
local MAX_WIDTH        = 500  -- yards — de quoi couvrir l'entrée d'un village entier
local MAX_REGION_POINTS = 20  -- de quoi dessiner un contour détaillé sans payload réseau démesuré

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
    for _, zone in pairs(ZoneGateDB.zones) do
        zone.subZones = zone.subZones or {}
    end
    return ZoneGateDB
end

function ZG:GetDB() return EnsureDB() end

-- Connaissance des joueurs : par personnage, pas par compte (OS2DB sert de
-- modèle — voir Modules/Survive/Core/Launcher.lua:409-411 pour le même
-- principe de set "[clé] = true" débloqué au fil du jeu).
-- Deux connaissances INDÉPENDANTES par personnage : le nom de la Zone et le
-- nom de la Sous-zone. Elles se débloquent séparément (voir SendZoneGrant /
-- SendSubZoneGrant) — d'où les 4 combinaisons possibles à l'affichage (voir
-- ResolveBannerText) : aucune, Zone seule, Sous-zone seule, ou les deux.
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

-- ── CRUD Zones ───────────────────────────────────────────────────────────────

function ZG:CreateZone(name)
    name = (name or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then name = "Nouvelle zone" end

    local db = EnsureDB()
    local id = "z_" .. time() .. "_" .. math.random(1000, 9999)
    db.zones[id] = {
        id = id, name = name, creator = MyName(), subZones = {},
        grantedTo = {},   -- [nom du joueur] = true — a appris le NOM DE LA ZONE (local, jamais diffusé)
    }
    ZG:ScheduleBroadcast()
    return db.zones[id]
end

function ZG:RemoveZone(id)
    local db = EnsureDB()
    local zone = db.zones[id]
    if not zone or zone.creator ~= MyName() then return end
    db.zones[id] = nil
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
    return EnsureDB().zones[id]
end

-- ── CRUD Sous-zones (= checkpoints) ───────────────────────────────────────
-- Une Sous-zone EST son propre checkpoint : position/orientation/forme sont
-- capturées à la création, "ici", comme avant pour un checkpoint seul — plus
-- besoin d'un objet séparé à lier manuellement.

-- Renvoie sub, zone (ou rien si introuvable) — cherche dans toutes les
-- zones connues localement (les miennes + celles reçues par sync).
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

function ZG:CreateSubZone(zoneId, name)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return nil end

    local px, py, facing, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Zone Gate : position introuvable.")
        return nil
    end

    name = (name or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then
        local n = 0
        for _ in pairs(zone.subZones) do n = n + 1 end
        name = "Sous-zone " .. (n + 1)
    end

    local id = "sz_" .. time() .. "_" .. math.random(1000, 9999)
    zone.subZones[id] = {
        id = id, zoneId = zoneId, name = name, creator = MyName(),
        enabled = true,
        mapID = instanceID, x = px, y = py, facing = facing,
        width = DEFAULT_WIDTH,   -- largeur de porte (line) ou rayon (circle), en yards
        shape = "line",
        points = {},             -- [i] = {x=,y=} — uniquement pour shape="polygon", voir AddRegionPoint
        regionReady = false,     -- polygone "fermé" (voir FinishRegion) — inerte tant que faux
        forwardEnabled  = true,  -- bannière en entrant
        backwardEnabled = true,  -- bannière en sortant
        actionMessage = "",           -- texte imprimé localement (jamais visible d'autrui)
        actionCommand = "",           -- voir RunCrossingAction — ID d'aura (nombre) ou commande brute
        actionForwardEnabled  = false, -- action en entrant — décoché par défaut (opt-in)
        actionBackwardEnabled = false, -- action en sortant
        grantedTo = {},          -- [nom du joueur] = true — a appris le NOM DE LA SOUS-ZONE (local, jamais diffusé)
    }
    ZG:ScheduleBroadcast()
    return zone.subZones[id]
end

-- Clone une sous-zone existante (même nom/largeur/forme) à la
-- position/orientation ACTUELLES du joueur, dans la MÊME zone — pratique
-- pour poser plusieurs entrées d'un même village qui déclenchent toutes la
-- même bannière.
function ZG:CloneSubZone(id)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return nil end

    local px, py, facing, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Zone Gate : position introuvable.")
        return nil
    end

    -- Pour une région (polygon), cloner "ici" n'a pas de sens géométrique
    -- simple (ce n'est pas UN point) — les points sont recopiés tels quels
    -- (mêmes coordonnées absolues), pas recentrés sur px/py. Pas exposé dans
    -- l'UI pour ce shape (voir cloneBtn:SetShown dans UI_Panel.lua).
    local points = nil
    if sub.points then
        points = {}
        for i, p in ipairs(sub.points) do points[i] = { x = p.x, y = p.y } end
    end

    local newId = "sz_" .. time() .. "_" .. math.random(1000, 9999)
    zone.subZones[newId] = {
        id = newId, zoneId = zone.id, name = sub.name, creator = MyName(),
        enabled = true,
        mapID = instanceID, x = px, y = py, facing = facing,
        width = sub.width, shape = sub.shape,
        points = points or {}, regionReady = sub.regionReady or false,
        forwardEnabled = sub.forwardEnabled, backwardEnabled = sub.backwardEnabled,
        actionMessage = sub.actionMessage or "", actionCommand = sub.actionCommand or "",
        actionForwardEnabled = sub.actionForwardEnabled or false,
        actionBackwardEnabled = sub.actionBackwardEnabled or false,
        grantedTo = {},   -- nouvelle sous-zone (nouvel id) : déblocages à refaire
    }
    ZG:ScheduleBroadcast()
    return zone.subZones[newId]
end

function ZG:RemoveSubZone(id)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    zone.subZones[id] = nil
    ZG.state[id] = nil
    ZG:ScheduleBroadcast()
end

-- Recapture la position/orientation/instance courantes (déplace la porte là
-- où se trouve le joueur, sans toucher au reste).
function ZG:RecaptureSubZone(id)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return false end

    local px, py, facing, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Zone Gate : position introuvable.")
        return false
    end

    sub.x, sub.y, sub.facing, sub.mapID = px, py, facing, instanceID
    ZG.state[id] = nil
    ZG:ScheduleBroadcast()
    return true
end

function ZG:SetSubZoneWidth(id, width)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    sub.width = math.max(1, math.min(MAX_WIDTH, tonumber(width) or DEFAULT_WIDTH))
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneShape(id, shape)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    local newShape = (shape == "circle" and "circle") or (shape == "polygon" and "polygon") or "line"
    if newShape == "polygon" and sub.shape ~= "polygon" then
        -- Nouvelle région : le point de départ, c'est "ici" — la position déjà
        -- capturée pour ce checkpoint (création ou dernière recapture). Les
        -- points suivants s'ajoutent avec AddRegionPoint.
        sub.points = { { x = sub.x, y = sub.y } }
        sub.regionReady = false
    end
    sub.shape = newShape
    ZG.state[id] = nil   -- la géométrie change, on réarme la détection
    ZG:ScheduleBroadcast()
end

-- ── Région (shape="polygon") : N points posés autour du joueur ───────────
-- Le polygone est TOUJOURS traité comme fermé (dernier point relié au
-- premier) dès qu'il a au moins 3 points ET que regionReady est vrai —
-- FinishRegion se contente de lever ce drapeau, rien d'autre à stocker pour
-- "relier" le dernier point au point de départ.

local function RecomputeRegionCenter(sub)
    local points = sub.points
    if not points or #points == 0 then return end
    local sx, sy = 0, 0
    for _, p in ipairs(points) do sx, sy = sx + p.x, sy + p.y end
    sub.x, sub.y = sx / #points, sy / #points
end

-- Ajoute un point à la position actuelle du joueur. Le premier point d'une
-- région fixe aussi son instance (mapID) — les suivants doivent rester dans
-- la MÊME instance, sinon rejetés (une région ne peut pas enjamber un
-- changement de carte).
function ZG:AddRegionPoint(subZoneId)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() or sub.shape ~= "polygon" then return false end

    local px, py, _, instanceID = ZG:GetPlayerPose()
    if not px then
        OmegaHub.Print("Zone Gate : position introuvable.")
        return false
    end

    sub.points = sub.points or {}
    if #sub.points == 0 then
        sub.mapID = instanceID
    elseif sub.mapID ~= instanceID then
        OmegaHub.Print("Zone Gate : restez dans la même zone/instance pour cette région.")
        return false
    elseif #sub.points >= MAX_REGION_POINTS then
        OmegaHub.Print("Zone Gate : maximum " .. MAX_REGION_POINTS .. " points par région.")
        return false
    end

    table.insert(sub.points, { x = px, y = py })
    RecomputeRegionCenter(sub)
    sub.regionReady = false   -- toute modif des points rouvre la région (on rerevalide avec Valider)
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

function ZG:RemoveLastRegionPoint(subZoneId)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() or sub.shape ~= "polygon" then return false end
    if not sub.points or #sub.points == 0 then return false end

    table.remove(sub.points)
    RecomputeRegionCenter(sub)
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

function ZG:ClearRegionPoints(subZoneId)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() or sub.shape ~= "polygon" then return end
    sub.points = {}
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
end

-- "Valide" la région : au moins 3 points nécessaires (aire non nulle).
function ZG:FinishRegion(subZoneId)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() or sub.shape ~= "polygon" then return false end
    if not sub.points or #sub.points < 3 then return false end
    sub.regionReady = true
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
    return true
end

-- Rouvre l'édition (ajouter/retirer des points) sans perdre ceux déjà posés.
function ZG:ReopenRegion(subZoneId)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() or sub.shape ~= "polygon" then return end
    sub.regionReady = false
    ZG.state[subZoneId] = nil
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneEnabled(id, enabled)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    sub.enabled = enabled and true or false
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneDirectionEnabled(id, direction, enabled)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    if direction == "forward" then sub.forwardEnabled = enabled and true or false
    else sub.backwardEnabled = enabled and true or false end
    ZG:ScheduleBroadcast()
end

-- ── Action personnalisée au franchissement (aura / commande / message) ────
-- Indépendante de la bannière (SetSubZoneDirectionEnabled ci-dessus) : une
-- sous-zone peut avoir une bannière sans action, une action sans bannière,
-- ou les deux — voir RunCrossingAction pour ce qui se passe vraiment.

function ZG:SetSubZoneActionMessage(id, text)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    sub.actionMessage = text or ""
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneActionCommand(id, text)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    sub.actionCommand = text or ""
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneActionDirectionEnabled(id, direction, enabled)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    if direction == "forward" then sub.actionForwardEnabled = enabled and true or false
    else sub.actionBackwardEnabled = enabled and true or false end
    ZG:ScheduleBroadcast()
end

function ZG:RenameSubZone(id, name)
    local sub, zone = ZG:FindSubZone(id)
    if not sub or not zone or zone.creator ~= MyName() then return end
    sub.name = name
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
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.name = (name or ""):match("^%s*(.-)%s*$") or theme.name
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeFont(id, font)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.font = (ZG.FontPaths[font] or font == "custom") and font or "frizqt"
    ZG:ScheduleBroadcast()
end

-- Chemin utilisé quand font == "custom" — n'importe quel fichier de police
-- déjà présent chez vous (fourni par un autre addon, par exemple), voir le
-- commentaire sur ZG.FontPaths. Aucune vérification que le fichier existe
-- réellement : un chemin invalide retombe silencieusement sur la police par
-- défaut au rendu (voir ResolveFontPath dans UI_Banner.lua).
function ZG:SetThemeCustomFont(id, path)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.customFont = (path or ""):match("^%s*(.-)%s*$") or ""
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeTitleSize(id, size)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.titleSize = math.max(10, math.min(60, math.floor((tonumber(size) or theme.titleSize) + 0.5)))
    ZG:ScheduleBroadcast()
end

-- which = "title" | "sub" | "sep" | "bg" | "frame" — un seul setter couleur
-- pour les 5 emplacements du thème plutôt que 5 fonctions quasi identiques.
-- sepColor/bgColor/frameColor ont un canal alpha (a peut être nil →
-- conservé tel quel).
local THEME_COLOR_FIELDS = {
    title = "titleColor", sub = "subColor", sep = "sepColor", bg = "bgColor", frame = "frameColor",
}
function ZG:SetThemeColor(id, which, r, g, b, a)
    local theme = ZG:GetTheme(id)
    local field = THEME_COLOR_FIELDS[which]
    if not theme or not field or theme.creator ~= MyName() then return end
    local c = theme[field] or {}
    c[1], c[2], c[3] = r or c[1] or 1, g or c[2] or 1, b or c[3] or 1
    if a ~= nil then c[4] = a end
    theme[field] = c
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeOutline(id, enabled)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.outline = enabled and true or false
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeUppercase(id, enabled)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.uppercase = enabled and true or false
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeLetterSpacing(id, enabled)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.letterSpacing = enabled and true or false
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeSeparatorStyle(id, style)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.sepStyle = ZG.SepLabels[style] and style or "single"
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeFrameStyle(id, style)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.frameStyle = ZG.FrameLabels[style] and style or "none"
    ZG:ScheduleBroadcast()
end

-- Ligne entre le titre et le sous-titre (indépendante des lignes haut/bas,
-- qui restent gérées par sepStyle) — même couleur (sepColor), toujours en
-- trait simple quel que soit sepStyle.
function ZG:SetThemeMidSeparator(id, enabled)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.midSepEnabled = enabled and true or false
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeBackgroundEnabled(id, enabled)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    theme.bgEnabled = enabled and true or false
    ZG:ScheduleBroadcast()
end

function ZG:SetThemeTiming(id, fadeIn, hold, fadeOut)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    if fadeIn  then theme.fadeIn  = math.max(0, math.min(5,  tonumber(fadeIn)  or theme.fadeIn)) end
    if hold    then theme.hold    = math.max(0, math.min(30, tonumber(hold)    or theme.hold)) end
    if fadeOut then theme.fadeOut = math.max(0, math.min(5,  tonumber(fadeOut) or theme.fadeOut)) end
    ZG:ScheduleBroadcast()
end

-- value : soit un ID numérique (SoundKit Blizzard, via PlaySound), soit un
-- chemin de fichier ("Sound\..." natif OU un .ogg/.mp3 déposé par vous dans
-- le dossier de l'addon, via PlaySoundFile) — voir ResolveSoundValue.
-- direction : "enter" (franchissement "avant") ou "exit" ("arrière").
function ZG:SetThemeSound(id, direction, value)
    local theme = ZG:GetTheme(id)
    if not theme or theme.creator ~= MyName() then return end
    local field = (direction == "exit") and "soundExit" or "soundEnter"
    theme[field] = (value or ""):match("^%s*(.-)%s*$") or ""
    ZG:ScheduleBroadcast()
end

-- Zone/Sous-zone → thème choisi ("" ou nil = aucun/hérite, voir ResolveTheme).
function ZG:SetZoneTheme(zoneId, themeId)
    local zone = ZG:GetZone(zoneId)
    if not zone or zone.creator ~= MyName() then return end
    zone.themeId = (themeId ~= "" and themeId) or nil
    ZG:ScheduleBroadcast()
end

function ZG:SetSubZoneTheme(subZoneId, themeId)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() then return end
    sub.themeId = (themeId ~= "" and themeId) or nil
    ZG:ScheduleBroadcast()
end

-- Résout le thème effectif d'un franchissement : la Sous-zone l'emporte si
-- elle a choisi le sien, sinon celui de la Zone (tous ses enfants en
-- héritent), sinon le thème par défaut (comportement d'avant les thèmes).
function ZG:ResolveTheme(sub, zone)
    if sub and sub.themeId then
        local t = ZG:GetTheme(sub.themeId)
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

-- Renvoie title, subtitle prêts pour la bannière (et pour l'affichage dans
-- le panneau). Les deux noms sont débloqués INDÉPENDAMMENT l'un de l'autre
-- (voir SendZoneGrant / SendSubZoneGrant), d'où 4 combinaisons possibles :
--   1. aucun connu      → "Zone inconnue"  / "?????"
--   2. Zone seule       → "<nom de zone>"  / "??????"
--   3. Sous-zone seule  → "Zone inconnue"  / "<nom de sous-zone>"
--   4. les deux connus  → "<nom de zone>"  / "<nom de sous-zone>"
-- L'auteur de la Zone voit toujours tout en clair, quel que soit ce qu'il
-- s'est débloqué à lui-même (il connaît forcément déjà les deux noms).
function ZG:ResolveBannerText(sub, zone)
    if not sub or not zone then return nil end
    local mine = zone.creator == MyName()
    local zoneKnown = mine or ZG:HasLearnedZoneName(zone.id)
    local subKnown  = mine or ZG:HasLearnedSubZoneName(sub.id)
    local title    = zoneKnown and zone.name or "Zone inconnue"
    local subtitle = subKnown  and sub.name  or ZG:MaskText(sub.name)
    return title, subtitle
end

-- ── Détection de franchissement ───────────────────────────────────────────

ZG.state = ZG.state or {}   -- [subZoneId] = -1 | 1 | nil (côté courant)

function ZG:ResetState()
    wipe(ZG.state)
end

-- Ligne : distance signée le long de "facing" (along) + latérale (across).
local function Project(sub, px, py)
    local fx, fy = math.cos(sub.facing), math.sin(sub.facing)
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
-- est hors de portée (hors bande pour une ligne, dans la marge de
-- tolérance autour du rayon pour un cercle, ou près du contour pour une
-- région).
local function ClassifySide(sub, px, py)
    if sub.shape == "circle" then
        local radius = sub.width or DEFAULT_WIDTH
        local dist = math.sqrt((px - sub.x) ^ 2 + (py - sub.y) ^ 2)
        if dist <= radius - WIDTH_MARGIN then return 1 end
        if dist >= radius + WIDTH_MARGIN then return -1 end
        return nil
    end

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

function ZG:Tick()
    local px, py, _, instanceID = ZG:GetPlayerPose()
    if not px then return end

    local db = EnsureDB()
    for _, zone in pairs(db.zones) do
        for id, sub in pairs(zone.subZones) do
            if sub.enabled and sub.mapID == instanceID then
                local side = ClassifySide(sub, px, py)
                if side then
                    local prev = ZG.state[id]
                    if prev and prev ~= side then
                        local direction = (prev < 0 and side > 0) and "forward" or "backward"
                        ZG:TriggerCrossing(sub, zone, direction)
                    end
                    ZG.state[id] = side
                else
                    -- Hors bande (ligne) / dans la marge de tolérance (cercle,
                    -- ou près du contour d'une région) / région pas encore
                    -- validée : on réarme proprement (évite les faux déclenchements).
                    ZG.state[id] = nil
                end
            end
        end
    end
end

-- Action personnalisée d'une sous-zone au franchissement : un message local
-- (texte imprimé dans VOTRE chat) et/ou une commande (aura ou brute — gérée
-- via OS2.ModuleRules.ExecuteServerCommand comme les règles d'aura de
-- Lantern/Torch : ça n'exécute pas de code, juste un message envoyé au
-- serveur qui décide seul quoi en faire). Inconditionnel pour TOUT joueur
-- qui franchit, y compris une sous-zone créée par quelqu'un d'autre —
-- volontaire, pour qu'un MJ puisse forcer un message/une aura à un joueur
-- sans que celui-ci ait à autoriser quoi que ce soit ; au créateur de la
-- zone de ne pas se planter dans sa config.
function ZG:RunCrossingAction(sub, zone, direction)
    local enabled = (direction == "forward") and sub.actionForwardEnabled or sub.actionBackwardEnabled
    if not enabled then return end

    if sub.actionMessage and sub.actionMessage ~= "" then
        OmegaHub.Print(sub.actionMessage)
    end

    if sub.actionCommand and sub.actionCommand ~= "" and OS2 and OS2.ModuleRules and OS2.ModuleRules.ExecuteServerCommand then
        -- Un ID numérique = raccourci "aura" : appliquée en entrant, retirée
        -- en sortant (mêmes conventions que les règles d'aura de Lantern —
        -- ExecuteServerCommand préfixe .aura/.unaura tout seul si la
        -- commande n'est qu'un nombre).
        local auraMode = (direction == "forward") and "apply" or "remove"
        OS2.ModuleRules.ExecuteServerCommand(sub.actionCommand, auraMode)
    end
end

-- Son de franchissement : value est soit un ID SoundKit Blizzard (nombre),
-- soit un chemin de fichier ("Sound\..." natif ou un .ogg/.mp3 déposé par
-- vous dans le dossier de l'addon) — testé dans cet ordre, silencieux si
-- vide ou si rien ne joue. Toujours protégé (pcall) : un chemin invalide ne
-- doit jamais casser le franchissement.
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

function ZG:PlayCrossingSound(theme, direction)
    if not theme then return end
    local value = (direction == "forward") and theme.soundEnter or theme.soundExit
    ResolveSoundValue(value)
end

function ZG:TriggerCrossing(sub, zone, direction)
    local theme = ZG:ResolveTheme(sub, zone)

    if (direction == "forward" and sub.forwardEnabled) or (direction == "backward" and sub.backwardEnabled) then
        local title, subtitle = ZG:ResolveBannerText(sub, zone)
        if title and ZG.ShowBanner then
            ZG:ShowBanner(title, subtitle, theme)
        end
        ZG:PlayCrossingSound(theme, direction)
    end

    ZG:RunCrossingAction(sub, zone, direction)
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
        table.insert(parts, string.format("%.2f,%.2f", p.x, p.y))
    end
    return table.concat(parts, ";")
end

local function UnpackPoints(str)
    local points = {}
    if not str or str == "" then return points end
    for chunk in str:gmatch("[^;]+") do
        local x, y = chunk:match("^(%-?[%d.]+),(%-?[%d.]+)$")
        if x and y then
            table.insert(points, { x = tonumber(x), y = tonumber(y) })
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

    for zid, zone in pairs(db.zones) do
        if zone.creator == me then
            table.insert(lines, table.concat({ "ZONE", Enc(zid), Enc(zone.name), Enc(zone.themeId or "") }, SEP))
            for sid, sub in pairs(zone.subZones) do
                table.insert(lines, table.concat({
                    "SUB", Enc(sid), Enc(zid), Enc(sub.name), sub.enabled and 1 or 0,
                    sub.mapID or 0, sub.x or 0, sub.y or 0, sub.facing or 0, sub.width or DEFAULT_WIDTH,
                    Enc(sub.shape or "line"),
                    sub.forwardEnabled and 1 or 0, sub.backwardEnabled and 1 or 0,
                    sub.regionReady and 1 or 0, PackPoints(sub.points),
                    Enc(sub.actionMessage or ""), Enc(sub.actionCommand or ""),
                    sub.actionForwardEnabled and 1 or 0, sub.actionBackwardEnabled and 1 or 0,
                    Enc(sub.themeId or ""),
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
    elseif tag == "ZONE" then
        local id, name, themeId = fields[2], fields[3], fields[4]
        if id and id ~= "" then
            local zone = ZoneGateDB.zones[id]
            if not zone then
                zone = { id = id, subZones = {} }
                ZoneGateDB.zones[id] = zone
            end
            zone.name, zone.creator = name, sender
            zone.themeId = (themeId and themeId ~= "") and themeId or nil
            zone.subZones = zone.subZones or {}
        end
    elseif tag == "SUB" then
        local id, zoneId, name, enabled, mapID, x, y, facing, width, shape, fwdEn, backEn, regionReady, pointsStr,
              actionMessage, actionCommand, actFwdEn, actBackEn, themeId =
            fields[2], fields[3], fields[4], fields[5], fields[6],
            fields[7], fields[8], fields[9], fields[10], fields[11], fields[12], fields[13],
            fields[14], fields[15], fields[16], fields[17], fields[18], fields[19], fields[20]
        local zone = ZoneGateDB.zones[zoneId]
        if zone and id and id ~= "" then
            zone.subZones[id] = {
                id = id, zoneId = zoneId, name = name, creator = sender,
                enabled = enabled == "1",
                mapID = tonumber(mapID), x = tonumber(x), y = tonumber(y),
                facing = tonumber(facing), width = tonumber(width),
                shape = (shape == "circle" and "circle") or (shape == "polygon" and "polygon") or "line",
                forwardEnabled  = fwdEn == "1",
                backwardEnabled = backEn == "1",
                regionReady = regionReady == "1",
                points = UnpackPoints(pointsStr),
                actionMessage = actionMessage or "",
                actionCommand = actionCommand or "",
                actionForwardEnabled  = actFwdEn == "1",
                actionBackwardEnabled = actBackEn == "1",
                themeId = (themeId and themeId ~= "") and themeId or nil,
            }
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
    for line in payload:gmatch("[^\n]+") do
        ApplyStateLine(line, sender)
    end
    if ZoneGatePanel and ZoneGatePanel.RefreshAll then
        ZoneGatePanel:RefreshAll()
    end
end

local stateMsgSeq = 0

local function SendChunkedState(channel, target)
    if not channel then return end
    local payload = PackState()
    if payload == "" then return end

    stateMsgSeq = stateMsgSeq + 1
    local msgId = stateMsgSeq
    local total = math.max(1, math.ceil(#payload / CHUNK_SIZE))
    for i = 1, total do
        local chunk = payload:sub((i - 1) * CHUNK_SIZE + 1, i * CHUNK_SIZE)
        SendAddon(string.format("Z|%d|%d|%d|%s", msgId, i, total, chunk), channel, target)
    end
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
-- groupe/guilde (comme SendForcedRoll dans Dice/Modules/Network.lua : le
-- whisper seul n'est pas fiable à 100%). La liste "qui a appris quoi" est
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

function ZG:SendSubZoneGrant(subZoneId, targetName)
    targetName = (targetName or ""):match("^%s*(.-)%s*$") or ""
    if targetName == "" or not subZoneId or subZoneId == "" then return false end

    local payload = "G|S|" .. Enc(subZoneId) .. "|" .. Enc(targetName)
    local sentWhisper = SendAddon(payload, "WHISPER", targetName)
    local sentOther = false
    for _, ct in ipairs(BroadcastChannels()) do
        sentOther = SendAddon(payload, ct.channel, ct.target) or sentOther
    end
    local sent = sentWhisper or sentOther or false

    if sent then
        local sub = ZG:FindSubZone(subZoneId)
        if sub then
            sub.grantedTo = sub.grantedTo or {}
            sub.grantedTo[StripRealm(targetName)] = true
        end
    end

    return sent
end

-- Liste triée ({name=...}) des joueurs à qui CE personnage a débloqué le nom
-- de cette sous-zone (enregistrement local, jamais diffusé — voir
-- SendSubZoneGrant ci-dessus).
function ZG:GetGrantedList(subZoneId)
    local sub = ZG:FindSubZone(subZoneId)
    if not sub or not sub.grantedTo then return {} end
    local list = {}
    for name in pairs(sub.grantedTo) do table.insert(list, { name = name }) end
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
-- SendZoneGrant/SendSubZoneGrant : "U|<scope>|<id>|<cible>".
function ZG:RevokeGrant(subZoneId, targetName)
    local sub, zone = ZG:FindSubZone(subZoneId)
    if not sub or not zone or zone.creator ~= MyName() then return false end

    if sub.grantedTo then sub.grantedTo[StripRealm(targetName)] = nil end

    local payload = "U|S|" .. Enc(subZoneId) .. "|" .. Enc(targetName)
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
    SlashCmdList["OZONEGATE"] = function()
        if ZoneGatePanel then ZoneGatePanel:Toggle() end
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
        OmegaHub.Print("Zone Gate activé.  |cffAAAAAA/oche|r")
    end
end

function ZG:Disable()
    SLASH_OZONEGATE1 = nil
    SLASH_OZONEGATE2 = nil
    SlashCmdList["OZONEGATE"] = nil

    ZG:StopTicker()
    ZG:UnregisterNetwork()
    ZG:ResetState()
    if ZoneGatePanel then ZoneGatePanel:Hide() end
    if ZoneGateThemePanel then ZoneGateThemePanel:Hide() end
    if ZG.HideBanner then ZG:HideBanner() end

    OmegaHub:SetModuleLoaded("ZoneGate", false)
    OmegaHub.Print("Zone Gate désactivé.")
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
        title   = "Zone Gate",
        desc    = "Bannières d'entrée/sortie de zone (checkpoints RP)",
        version = ZONEGATE_VERSION,
        module  = ZG,
    })
    EnsureDB()
    EnsureCharDB()
    MigrateOldCheckpoints()
    if OmegaHub:IsModuleEnabled("ZoneGate") then ZG:Enable() end
    f:UnregisterAllEvents()
end)
