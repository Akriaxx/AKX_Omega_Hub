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

function ZG:TriggerCrossing(sub, zone, direction)
    if (direction == "forward" and sub.forwardEnabled) or (direction == "backward" and sub.backwardEnabled) then
        local title, subtitle = ZG:ResolveBannerText(sub, zone)
        if title and ZG.ShowBanner then
            ZG:ShowBanner(title, subtitle)
        end
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

-- Sérialise tout ce que CE personnage possède (zones + leurs sous-zones,
-- dont il est l'auteur) en un seul bloc, une ligne par enregistrement.
local function PackState()
    local me = MyName()
    local db = EnsureDB()
    local lines = {}

    for zid, zone in pairs(db.zones) do
        if zone.creator == me then
            table.insert(lines, table.concat({ "ZONE", Enc(zid), Enc(zone.name) }, SEP))
            for sid, sub in pairs(zone.subZones) do
                table.insert(lines, table.concat({
                    "SUB", Enc(sid), Enc(zid), Enc(sub.name), sub.enabled and 1 or 0,
                    sub.mapID or 0, sub.x or 0, sub.y or 0, sub.facing or 0, sub.width or DEFAULT_WIDTH,
                    Enc(sub.shape or "line"),
                    sub.forwardEnabled and 1 or 0, sub.backwardEnabled and 1 or 0,
                    sub.regionReady and 1 or 0, PackPoints(sub.points),
                    Enc(sub.actionMessage or ""), Enc(sub.actionCommand or ""),
                    sub.actionForwardEnabled and 1 or 0, sub.actionBackwardEnabled and 1 or 0,
                }, SEP))
            end
        end
    end

    return table.concat(lines, "\n")
end

local function ApplyStateLine(line, sender)
    local fields = { strsplit(SEP, line) }
    local tag = fields[1]

    if tag == "ZONE" then
        local id, name = fields[2], fields[3]
        if id and id ~= "" then
            local zone = ZoneGateDB.zones[id]
            if not zone then
                zone = { id = id, subZones = {} }
                ZoneGateDB.zones[id] = zone
            end
            zone.name, zone.creator = name, sender
            zone.subZones = zone.subZones or {}
        end
    elseif tag == "SUB" then
        local id, zoneId, name, enabled, mapID, x, y, facing, width, shape, fwdEn, backEn, regionReady, pointsStr,
              actionMessage, actionCommand, actFwdEn, actBackEn =
            fields[2], fields[3], fields[4], fields[5], fields[6],
            fields[7], fields[8], fields[9], fields[10], fields[11], fields[12], fields[13],
            fields[14], fields[15], fields[16], fields[17], fields[18], fields[19]
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
