-- ============================================================
--  GM Master — Displays
--  Trois onglets : M2 et WMO (objets), PNJ (displays de créatures).
--  On cherche par nom (« door », « chair void »), clic : aperçu à
--  droite, clic droit : Spawn (objets) ou Morph (PNJ). Flèches haut /
--  bas : résultat précédent / suivant.
--
--  Aperçu en jeu (M2 et WMO) : chaque objet choisi est posé devant soi,
--  à la distance réglée ; en choisir un autre retire le précédent. Le
--  client plante s'il doit dessiner un WMO dans une fenêtre : c'est le
--  seul vrai aperçu possible pour eux.
--
--  Objets : la recherche passe par le client Epsilon
--  (C_Epsilon.GODI_Search), qui connaît les displays du jeu ET ceux
--  ajoutés par le serveur (eps_…).
--  PNJ : CreatureDisplays.generated.lua (Tools/build-creaturedisplays.js),
--  tous les displays de créatures du client avec les PNJ qui les portent.
-- ============================================================

local GM = GMMaster
local UI = OS2.UI

local LIST_W = 500
local W, H   = LIST_W + 380, 560
local PAD    = 14
local ROW_H  = 24
local ROWS   = 16
local LIST_Y = -112
local H_COMPACT = H + 70   -- onglet WMO : liste seule, commandes dessous
local SEARCH_MIN   = 2
local RESULTS_MAX  = 2000
local TYPE_DELAY   = 0.3
local PLACEHOLDER_FILE = 130738   -- interface/buttons/talktomequestionmark.m2

-- Objets connus pour faire planter le client à l'affichage (comme Epsilon_Viewer).
local HIDDEN = { "alphabet_caligo", "alphabet_futhark", "alphabet_mechanical", "alphabet_morpheus",
                 "alphabet_romansd", "alphabet_suastornad", "collections_" }

local function After(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

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

local function Tokens(query)
    local list = {}
    for word in query:lower():gmatch("%S+") do list[#list + 1] = word end
    return list
end

local function MatchesAll(text, tokens)
    for _, token in ipairs(tokens) do
        if not text:find(token, 1, true) then return false end
    end
    return true
end

-- ── Recherche : objets (client Epsilon) ───────────────────────────────────

local function IsHidden(name)
    for _, part in ipairs(HIDDEN) do
        if name:find(part, 1, true) then return true end
    end
    return false
end

--- Objets dont le nom contient tous les mots ; ext = "m2" ou "wmo". Comme
--- Epsilon_Viewer, tout ce qui n'est pas un .wmo compte comme M2.
--- Renvoie la liste, ou nil + message si le client n'est pas celui d'Epsilon.
--- En troisième valeur, ce que le client a renvoyé : { count, other, sample }
--- (pour expliquer une liste vide).
function GM.SearchObjects(query, ext)
    local api = C_Epsilon
    if not (api and api.GODI_Search and api.GODI_RetrieveSearch) then
        return nil, "Recherche d'objets indisponible : client Epsilon requis (C_Epsilon)."
    end
    local tokens = Tokens(query)
    if #tokens == 0 then return {} end
    -- Le client cherche un seul fragment : le plus long, les autres sont
    -- vérifiés ici.
    local longest = tokens[1]
    for _, token in ipairs(tokens) do if #token > #longest then longest = token end end
    local results, seen = {}, {}
    -- Epsilon_Viewer interroge GODI_Count avant toute recherche : il
    -- prépare peut-être la base des objets côté client.
    if api.GODI_Count then api.GODI_Count() end
    local raw = { count = tonumber(api.GODI_Search(longest)) or 0, other = 0 }
    for i = 0, raw.count - 1 do
        local r = api.GODI_RetrieveSearch(i)
        local name = r and r.name and tostring(r.name):lower()
        if name then
            raw.sample = raw.sample or tostring(r.name)
            local isWmo = name:find(".wmo", 1, true) ~= nil
            if isWmo ~= (ext == "wmo") then
                raw.other = raw.other + 1
            elseif not IsHidden(name) and MatchesAll(name, tokens) then
                local key = tostring(r.displayid) .. ":" .. tostring(r.fileid)
                if not seen[key] then
                    seen[key] = true
                    local short = tostring(r.name):gsub("^.*[/\\]", ""):gsub("eps_secret", "eps"):gsub("secret_eps", "eps")
                    results[#results + 1] = { kind = ext, id = r.displayid, fileid = r.fileid,
                                              name = short, path = tostring(r.name) }
                    if #results >= RESULTS_MAX then break end
                end
            end
        end
    end
    table.sort(results, function(a, b) return a.name < b.name end)
    return results, nil, raw
end

-- ── Recherche : PNJ (données du client) ───────────────────────────────────

-- Deux listes parallèles de lignes « display<TAB>modèle<TAB>PNJ;PNJ »
-- (telles quelles et en minuscules), construites au premier usage : bien
-- plus léger qu'une table par display. Les fiches ne sont créées que pour
-- les résultats.
local lines, lowered

local function Load()
    if lines then return end
    lines, lowered = {}, {}
    for line in (GM.CreatureDisplaysRaw or ""):gmatch("[^\n]+") do
        if line:find("^%d") then
            lines[#lines + 1] = line
            lowered[#lowered + 1] = line:lower()
        end
    end
    GM.CreatureDisplaysRaw = nil   -- les listes suffisent, libère la chaîne
end

local function Entry(line)
    local id, model, names = line:match("^(%d+)\t([^\t]*)\t?(.*)$")
    return { kind = "npc", id = tonumber(id), name = model or "", npcs = names or "" }
end

--- Nombre de displays de créatures connus du client.
function GM.CreatureDisplayCount() Load() return #lines end

--- Displays de créatures : un nombre seul cherche ce display précis,
--- sinon tous les mots doivent figurer dans le modèle ou les noms de PNJ.
function GM.SearchCreatures(query)
    Load()
    local tokens = Tokens(query)
    local results = {}
    if #tokens == 0 then return results end
    local exact = #tokens == 1 and tonumber(tokens[1])
    if exact then
        local prefix = tostring(exact) .. "\t"
        for i, line in ipairs(lines) do
            if line:sub(1, #prefix) == prefix then return { Entry(lines[i]) } end
        end
        -- Display absent du client (ajout du serveur) : on peut quand même essayer.
        return { { kind = "npc", id = exact, name = "display " .. exact, npcs = "" } }
    end
    for i, low in ipairs(lowered) do
        if MatchesAll(low, tokens) then
            results[#results + 1] = Entry(lines[i])
            if #results >= RESULTS_MAX then break end
        end
    end
    return results
end

-- ── Fenêtre ───────────────────────────────────────────────────────────────

local win = CreateFrame("Frame", "GMMasterDisplay", UIParent, "BackdropTemplate")
win:SetSize(W, H)
win:SetPoint("CENTER", 60, 0)
win:SetFrameStrata("HIGH")
win:SetClampedToScreen(true)
win:SetMovable(true)
win:EnableMouse(true)
win:EnableMouseWheel(true)
win:RegisterForDrag("LeftButton")
win:SetScript("OnDragStart", win.StartMoving)
win:SetScript("OnDragStop", win.StopMovingOrSizing)
win:Hide()
tinsert(UISpecialFrames, "GMMasterDisplay")
win.kind, win.offset, win.results = "m2", 0, {}
do
    local bg = win:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.97)
    win:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    win:SetBackdropBorderColor(unpack(UI.colors.separator))
    local title = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD + 2, -14)
    title:SetText("Displays")
    UI.ApplyTitle(title)
    UI.CreateCloseButton(win, function() win:Hide() end)
    local sep = win:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", LIST_W, -46)
    sep:SetPoint("BOTTOMLEFT", LIST_W, 8)
    win.sep = sep
    sep:SetWidth(1)
    UI.ApplySeparator(sep, true)
end

local KINDS = { { "m2", "M2" }, { "wmo", "WMO" }, { "npc", "PNJ" } }
local HINTS = {
    m2  = "Objets .m2 du jeu et du serveur (eps_…). Plusieurs mots : tous doivent y être.",
    wmo = "Bâtiments et grandes structures .wmo. Pas d'aperçu 3D : « Aperçu en jeu » les pose devant vous.",
    npc = "Nom du modèle, nom du PNJ (anglais ou français) ou numéro de display.",
}
local tabs = {}
win.tabs = tabs

local searchBox = UI.CreateStyledEditBox(win, LIST_W - 2 * PAD, 24)
searchBox:SetPoint("TOPLEFT", PAD, -52)
win.searchBox = searchBox

local hint = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", PAD, -82)
hint:SetWidth(LIST_W - 2 * PAD)
hint:SetJustifyH("LEFT")
UI.ApplySoftText(hint)
win.hint = hint

local pager = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pager:SetPoint("BOTTOMLEFT", PAD, 14)
pager:SetWidth(LIST_W - 2 * PAD)
pager:SetJustifyH("LEFT")
UI.ApplyMutedText(pager)
win.pager = pager

-- ── Aperçu ────────────────────────────────────────────────────────────────

local previewLeft = LIST_W + PAD
local scene = CreateFrame("ModelScene", nil, win, "ModelSceneMixinTemplate")
scene:SetPoint("TOPLEFT", previewLeft, -46)
scene:SetPoint("BOTTOMRIGHT", -PAD, 124)
win.scene = scene
do
    local sbg = win:CreateTexture(nil, "BACKGROUND", nil, 1)
    sbg:SetPoint("TOPLEFT", scene, "TOPLEFT")
    sbg:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT")
    sbg:SetColorTexture(0.02, 0.02, 0.02, 0.85)
    win.sceneBg = sbg
end

local actor
--- Cadre la caméra sur le modèle chargé (même calcul qu'Epsilon_Viewer).
local function FitCamera(self)
    if not self.GetActiveBoundingBox then return end
    local x1, y1, z1, x2, y2, z2 = self:GetActiveBoundingBox()
    if not x2 then return end
    local lx, ly, lz = x2 - x1, y2 - y1, z2 - z1
    if lx == 0 then lx = 12 end
    if ly == 0 then ly = 12 end
    if lz == 0 then lz = 12 end
    local size = math.sqrt(lx ^ 2 + ly ^ 2 + lz ^ 2) * 1.5
    local camera = scene.Camera
    if not camera then return end
    camera:SetPitch(math.rad(math.max(lx, ly) < lz and 15 or 22.5))
    camera:SetYaw(0)
    camera:SetRoll(0)
    camera:SetTarget(0, 0, 0)
    camera:SetMinZoomDistance(size * 0.3)
    camera:SetMaxZoomDistance(size * 3)
    camera:SetZoomDistance(size * 1.1)
    camera:SnapAllInterpolatedValues()
    self:SetYaw(math.pi / 1.2)
    self:SetPosition(0, 0, 0)
end

actor = scene.CreateActor and scene:CreateActor(nil, "ModelSceneActorTemplate")
if actor then
    actor.onModelLoadedCallback = FitCamera
    actor:SetUseCenterForOrigin(true, true, true)
    scene:SetCameraNearClip(0.01)
    scene:SetCameraFarClip(2 ^ 64)
    scene.Camera = scene:CreateCameraFromScene(114)
    if scene.Camera then
        scene.Camera:SetPitch(0)
        scene.Camera:SetLeftMouseButtonYMode(ORBIT_CAMERA_MOUSE_MODE_PITCH_ROTATION, true)
        scene.Camera:SetRightMouseButtonXMode(ORBIT_CAMERA_MOUSE_PAN_HORIZONTAL, true)
        scene.Camera:SetRightMouseButtonYMode(ORBIT_CAMERA_MOUSE_PAN_VERTICAL, true)
    end
end
win.actor = actor

local sceneHint = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sceneHint:SetPoint("BOTTOM", scene, "BOTTOM", 0, 6)
sceneHint:SetText("Clic gauche : tourner  ·  Clic droit : déplacer  ·  Molette : zoom")
UI.ApplySoftText(sceneHint)

local wmoNote = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
wmoNote:SetPoint("CENTER", scene, "CENTER")
wmoNote:SetWidth(340)
local WMO_NOTE_OFF = "Pas d'aperçu 3D pour les WMO :\nle client plante s'il doit en afficher un\ndans une fenêtre (vérifié en jeu).\n\nActivez « Aperçu en jeu » ci-dessous."
local WMO_NOTE_ON = "Aperçu en jeu : le WMO est posé devant vous.\n\nChoisir un autre WMO retire celui-ci."
wmoNote:SetText(WMO_NOTE_OFF)
UI.ApplyMutedText(wmoNote)
wmoNote:Hide()

local info = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
info:SetPoint("TOPLEFT", scene, "BOTTOMLEFT", 0, -8)
info:SetPoint("RIGHT", win, "RIGHT", -PAD, 0)
info:SetJustifyH("LEFT")
info:SetJustifyV("TOP")
info:SetWordWrap(true)
info:SetHeight(44)
UI.ApplyBodyText(info)
win.info = info

local actionBtn = UI.CreatePanelButton(win, 110, 22, "")
actionBtn:SetPoint("BOTTOMLEFT", previewLeft, 14)
win.actionBtn = actionBtn

-- ── Aperçu en jeu ─────────────────────────────────────────────────────────
-- Passe par EpsilonLib (AddonCommands) pour lire la réponse du serveur et
-- connaître le GUID de l'objet posé : sans lui, impossible de le retirer.
-- Une seule demande à la fois ; si l'on fait défiler vite, seule la
-- dernière est posée.

local WORLD_DELAY = 0.35
local world = { token = 0 }
win.world = world

local function WorldSettings()
    local db = GM.EnsureDB()
    db.displayWorld = db.displayWorld or { m2 = false, wmo = true, distance = 10 }
    return db.displayWorld
end

local sendCommand
local function SendCommand(text, callback)
    local lib = EpsilonLib and EpsilonLib.AddonCommands
    if not sendCommand and lib and lib.Register then
        local ok, fn = pcall(lib.Register, "Omega GM Master")
        if ok and fn then sendCommand = fn
        elseif lib.Get and lib.Get("Omega GM Master") then sendCommand = lib.Get("Omega GM Master").SendAddonCommand end
    end
    if not sendCommand then return false end
    sendCommand(text, callback)
    return true
end

local function LastObject()
    local objects = EpsilonLib and EpsilonLib.GameObject
    return objects and objects.GetLast and objects:GetLast() or nil
end

local function GuidFromMessages(messages)
    for _, message in ipairs(messages or {}) do
        local guid = tostring(message):match("gameobject_GUID:(%d+)")
        if guid then return tonumber(guid) end
    end
end

local SetWorldStatus   -- défini avec les boutons, plus bas

--- Pose la dernière demande, après avoir retiré l'objet précédent.
local function Pump()
    if world.busy or not world.want then return end
    local entry = world.want
    world.want = nil
    world.busy = true
    local distance = tonumber(WorldSettings().distance) or 10

    local function Done(text)
        world.busy = false
        if SetWorldStatus then SetWorldStatus(text) end
        Pump()
    end

    local function Spawn()
        local before = LastObject()
        SetWorldStatus("Pose de " .. entry.name .. "…")
        local sent = SendCommand("gobject spawn " .. entry.id, function(ok, messages)
            if not ok then
                Done("|cffdd5555Échec : " .. tostring(messages and messages[1] or "refus du serveur") .. "|r")
                return
            end
            local tries = 0
            local function Settle()
                local guid = GuidFromMessages(messages)
                if not guid then
                    local last = LastObject()
                    if last and last ~= before then guid = tonumber(last.guid) end
                end
                if not guid and tries < 10 then
                    tries = tries + 1
                    After(0.1, Settle)
                    return
                end
                if not guid then
                    Done("|cffddaa44Posé, mais GUID inconnu : à retirer à la main.|r")
                    return
                end
                world.guid, world.entry = guid, entry
                if world.cancel then
                    world.cancel = nil
                    SendCommand("gobject delete " .. guid, function() end)
                    world.guid, world.entry = nil, nil
                    Done(nil)
                    return
                end
                SendCommand(("gobject move %d forwards %s"):format(guid, distance), function()
                    Done("Devant vous : |cffffffff" .. entry.name .. "|r  |cff888888(GUID " .. guid .. ")|r")
                end)
            end
            Settle()
        end)
        if not sent then Done("|cffdd5555Aperçu en jeu indisponible : EpsilonLib requis.|r") end
    end

    if world.guid then
        local old = world.guid
        world.guid, world.entry = nil, nil
        SendCommand("gobject delete " .. old, function() Spawn() end)
    else
        Spawn()
    end
end

--- Demande l'aperçu en jeu d'un objet (après un court délai : flèches).
function GM:PreviewInWorld(entry)
    world.cancel = nil
    world.token = world.token + 1
    local mine = world.token
    world.want = nil
    After(WORLD_DELAY, function()
        if mine ~= world.token then return end
        world.want = entry
        Pump()
    end)
end

--- Retire l'objet posé par l'aperçu (et annule une pose en cours).
function GM:ClearWorldPreview()
    world.token = world.token + 1
    world.want = nil
    if world.busy then world.cancel = true end
    if world.guid then
        SendCommand("gobject delete " .. world.guid, function() end)
        world.guid, world.entry = nil, nil
    end
    if SetWorldStatus then SetWorldStatus(nil) end
end

--- Garde l'objet posé : l'aperçu ne le retirera plus.
function GM:KeepWorldPreview()
    if not world.guid then return end
    local name = world.entry and world.entry.name or "objet"
    world.guid, world.entry = nil, nil
    if SetWorldStatus then SetWorldStatus("Gardé : |cffffffff" .. name .. "|r") end
end

local function WorldEnabled(kind)
    return (kind == "m2" or kind == "wmo") and WorldSettings()[kind] == true
end
win.WorldEnabled = WorldEnabled

local worldToggle = UI.CreatePanelButton(win, 150, 22, "")
worldToggle:SetPoint("BOTTOMLEFT", previewLeft, 42)
win.worldToggle = worldToggle

local distLabel = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
distLabel:SetPoint("LEFT", worldToggle, "RIGHT", 10, 0)
distLabel:SetText("Distance")
UI.ApplyLabel(distLabel)

local distBox = UI.CreateStyledEditBox(win, 46, 22)
distBox:SetPoint("LEFT", distLabel, "RIGHT", 6, 0)
win.distBox = distBox

local worldStatus = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
worldStatus:SetPoint("LEFT", distBox, "RIGHT", 8, 0)
worldStatus:SetPoint("RIGHT", win, "RIGHT", -PAD, 0)
worldStatus:SetJustifyH("LEFT")
worldStatus:SetWordWrap(false)
UI.ApplyMutedText(worldStatus)
win.worldStatus = worldStatus

local keepBtn = UI.CreatePanelButton(win, 80, 22, "Garder")
keepBtn:SetPoint("LEFT", actionBtn, "RIGHT", 6, 0)
keepBtn:SetScript("OnClick", function() GM:KeepWorldPreview() end)
win.keepBtn = keepBtn

local clearBtn = UI.CreatePanelButton(win, 80, 22, "Retirer")
clearBtn:SetPoint("LEFT", keepBtn, "RIGHT", 6, 0)
clearBtn:SetScript("OnClick", function() GM:ClearWorldPreview() end)
win.clearBtn = clearBtn

local function UpdateWorldControls()
    local kind = win.kind
    local objects = kind == "m2" or kind == "wmo"
    local on = WorldEnabled(kind)
    worldToggle:SetShown(objects)
    distLabel:SetShown(objects)
    distBox:SetShown(objects)
    worldStatus:SetShown(objects)
    worldToggle:SetText("Aperçu en jeu : " .. (on and "|cff66dd66oui|r" or "|cff999999non|r"))
    keepBtn:SetShown(objects and world.guid ~= nil)
    clearBtn:SetShown(objects and (world.guid ~= nil or world.busy == true))
    -- Onglet WMO : pas de 3D possible. La colonne d'aperçu disparaît, la
    -- fenêtre se resserre sur la liste, et le nom de l'objet, l'aperçu en
    -- jeu et les boutons passent sous la liste, au-dessus du compteur.
    local wmo = kind == "wmo"
    if win.compact ~= wmo then
        win.compact = wmo
        win:SetSize(wmo and LIST_W or W, wmo and H_COMPACT or H)
        win.sep:SetShown(not wmo)
        scene:SetShown(not wmo)
        win.sceneBg:SetShown(not wmo)
        sceneHint:SetShown(not wmo)
        local left = wmo and PAD or previewLeft
        info:ClearAllPoints()
        if wmo then
            info:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", PAD, 96)
            info:SetHeight(28)
        else
            info:SetPoint("TOPLEFT", scene, "BOTTOMLEFT", 0, -8)
            info:SetHeight(44)
        end
        info:SetPoint("RIGHT", win, "RIGHT", -PAD, 0)
        worldToggle:ClearAllPoints()
        worldToggle:SetPoint("BOTTOMLEFT", left, wmo and 68 or 42)
        actionBtn:ClearAllPoints()
        actionBtn:SetPoint("BOTTOMLEFT", left, wmo and 40 or 14)
    end
end

SetWorldStatus = function(text)
    world.status = text
    worldStatus:SetText(text or "")
    UpdateWorldControls()
end

worldToggle:SetScript("OnClick", function()
    local settings = WorldSettings()
    settings[win.kind] = not settings[win.kind]
    if settings[win.kind] then
        if win.selected and win.selected.kind == win.kind then GM:PreviewInWorld(win.selected) end
    else
        GM:ClearWorldPreview()
    end
    UpdateWorldControls()
end)
worldToggle:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Aperçu en jeu",
        "Chaque objet choisi (clic ou flèches) est posé devant vous, à la distance indiquée. En choisir un autre retire le précédent.",
        "Garder : laisser l'objet en place.  Retirer : l'enlever.",
        "Fermer la fenêtre retire l'objet en aperçu." })
end)
worldToggle:SetScript("OnLeave", HideTooltip)

distBox:SetScript("OnTextChanged", function(self, user)
    if not user then return end
    local value = tonumber(self:GetText())
    if value and value >= 0 then WorldSettings().distance = value end
end)
distBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

local function EntryLines(entry)
    if entry.kind == "npc" then
        local lines = { "|cffffffff" .. (entry.name ~= "" and entry.name or "?") .. "|r  |cff888888display " .. entry.id .. "|r" }
        if entry.npcs and entry.npcs ~= "" then
            lines[#lines + 1] = "PNJ : |cffd7b35f" .. entry.npcs:gsub(";", ", ") .. "|r"
        else
            lines[#lines + 1] = "|cff888888Aucun PNJ du client ne porte ce display.|r"
        end
        return lines
    end
    local lines = { "|cffffffff" .. entry.name .. "|r",
                    "|cff888888display " .. tostring(entry.id) .. "  ·  fichier " .. tostring(entry.fileid) .. "|r" }
    -- Le chemin seulement s'il apprend quelque chose (le client donne
    -- souvent le nom du fichier seul).
    if entry.path and entry.path ~= entry.name then lines[#lines + 1] = "|cff888888" .. entry.path .. "|r" end
    return lines
end

--- select = true : choix de l'utilisateur (clic, flèches), qui déclenche
--- l'aperçu en jeu ; false : simple réaffichage.
local function ShowPreview(entry, select)
    win.selected = entry
    if select and entry and WorldEnabled(entry.kind) then GM:PreviewInWorld(entry) end
    wmoNote:Hide()
    if actor then
        if not entry or entry.kind == "wmo" then
            actor:SetModelByFileID(PLACEHOLDER_FILE)
            actor:Hide()
        else
            actor:Show()
            if entry.kind == "npc" then actor:SetModelByCreatureDisplayID(entry.id)
            else actor:SetModelByFileID(entry.fileid) end
        end
    end
    if entry then
        info:SetText(table.concat(EntryLines(entry), "\n"))
        actionBtn:SetText(entry.kind == "npc" and "Morph" or "Spawn")
        actionBtn:Show()
    else
        info:SetText(win.kind == "wmo"
            and "|cff888888Choisissez un WMO (clic ou flèches). Clic droit : Spawn définitif.|r"
            or ("|cff888888Cliquez un résultat pour l'afficher ici. Clic droit : "
                .. (win.kind == "npc" and "Morph" or "Spawn") .. ".|r"))
        actionBtn:Hide()
    end
    UpdateWorldControls()
    if win.Refresh then win:Refresh() end
end
GM.PreviewDisplay = ShowPreview

-- ── Actions ───────────────────────────────────────────────────────────────

function GM:SpawnDisplay(entry)
    if not entry or not entry.id then return false end
    return self:RunMacro("gobject spawn " .. entry.id)
end

function GM:MorphDisplay(entry)
    if not entry or not entry.id then return false end
    return self:RunMacro("morph " .. entry.id)
end

local function MainAction(entry)
    if entry.kind == "npc" then GM:MorphDisplay(entry) else GM:SpawnDisplay(entry) end
end
actionBtn:SetScript("OnClick", function() if win.selected then MainAction(win.selected) end end)

local menu = CreateFrame("Frame", nil, win, "BackdropTemplate")
menu:SetSize(138, 64)
menu:SetFrameStrata("TOOLTIP")
menu:SetClampedToScreen(true)
menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
menu:SetBackdropColor(0.06, 0.06, 0.06, 1)
menu:EnableMouse(true)
menu:Hide()
win.menu = menu
win:HookScript("OnHide", function() menu:Hide() end)

local MENU = {
    m2  = { { "Spawn", function(e) GM:SpawnDisplay(e) end } },
    wmo = { { "Spawn", function(e) GM:SpawnDisplay(e) end } },
    npc = { { "Morph", function(e) GM:MorphDisplay(e) end },
            { "Démorph", function() GM:RunMacro("demorph") end } },
}
menu.buttons = {}
for i = 1, 2 do
    local b = UI.CreatePanelButton(menu, 122, 22, "")
    b:SetPoint("TOPLEFT", 8, -8 - (i - 1) * 25)
    b:SetScript("OnClick", function(self)
        local entry = menu.entry
        menu:Hide()
        if entry and self.action then self.action(entry) end
    end)
    menu.buttons[i] = b
end

local function OpenMenu(owner, entry)
    HideTooltip()
    local actions = MENU[entry.kind]
    for i, b in ipairs(menu.buttons) do
        local action = actions[i]
        b:SetShown(action ~= nil)
        if action then b:SetText(action[1]); b.action = action[2] end
    end
    menu:SetHeight(16 + #actions * 25)
    menu.entry = entry
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
    menu:Show()
end

-- ── Liste ─────────────────────────────────────────────────────────────────

local rows = {}
win.rows = rows
for i = 1, ROWS do
    local row = CreateFrame("Button", nil, win)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT", PAD, LIST_Y - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", win, "LEFT", LIST_W - PAD, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local rbg = row:CreateTexture(nil, "BACKGROUND")
    rbg:SetAllPoints()
    row.bg = rbg
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(unpack(UI.colors.tabHighlight))
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", 8, 0)
    text:SetPoint("RIGHT", -70, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    UI.ApplyBodyText(text)
    row.text = text
    local id = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    id:SetPoint("RIGHT", -8, 0)
    UI.ApplyPlaceholderText(id)
    row.id = id
    row:SetScript("OnClick", function(self, button)
        if not self.entry then return end
        if button == "RightButton" then OpenMenu(self, self.entry) return end
        menu:Hide()
        win.cursor = win.offset + self.slot
        ShowPreview(self.entry, true)
    end)
    row:SetScript("OnEnter", function(self)
        if not self.entry then return end
        local lines = EntryLines(self.entry)
        lines[#lines + 1] = "|cffAAAAAAClic : aperçu  ·  Clic droit : "
            .. (self.entry.kind == "npc" and "Morph" or "Spawn") .. "|r"
        ShowTooltip(self, lines)
    end)
    row:SetScript("OnLeave", HideTooltip)
    row.slot = i
    rows[i] = row
end

function win:Refresh()
    for kind, tab in pairs(tabs) do tab:SetAlpha(kind == self.kind and 1 or 0.55) end
    hint:SetText(self.message or HINTS[self.kind])
    local list = self.results
    self.offset = math.max(0, math.min(self.offset, math.max(0, #list - ROWS)))
    for i, row in ipairs(rows) do
        local entry = list[self.offset + i]
        row.entry = entry
        row:SetShown(entry ~= nil)
        if entry then
            local selected = self.cursor == self.offset + i
            row.bg:SetColorTexture(unpack(selected and UI.colors.rowBgSelected or UI.colors.rowBg))
            if entry.kind == "npc" then
                local npcs = entry.npcs ~= "" and ("  |cffd7b35f" .. entry.npcs:gsub(";", ", ") .. "|r") or ""
                row.text:SetText(entry.name .. npcs)
            else
                row.text:SetText(entry.name)
            end
            row.id:SetText(tostring(entry.id or ""))
        end
    end
    local query = GM.Trim(searchBox:GetText())
    if #list == 0 then
        pager:SetText(#query < SEARCH_MIN and "" or "Aucun résultat.")
    else
        pager:SetText((self.offset + 1) .. "–" .. math.min(#list, self.offset + ROWS) .. " sur " .. #list
            .. (#list >= RESULTS_MAX and "+" or "") .. "  ·  molette pour défiler")
    end
end

--- Lance la recherche de l'onglet courant avec le texte saisi.
function win:Search()
    local query = GM.Trim(searchBox:GetText())
    self.offset, self.message, self.cursor = 0, nil, nil
    if #query < SEARCH_MIN and not (self.kind == "npc" and tonumber(query)) then
        self.results = {}
    elseif self.kind == "npc" then
        self.results = GM.SearchCreatures(query)
    else
        local results, err, raw = GM.SearchObjects(query, self.kind)
        self.results, self.message = results or {}, err
        if results and #results == 0 and raw then
            -- Liste vide : dire ce que le client a renvoyé, pour comprendre.
            if raw.count == 0 then
                self.message = "Le client Epsilon ne trouve aucun objet pour « " .. query .. " »."
            else
                self.message = "Le client a trouvé " .. raw.count .. " objet(s), dont " .. raw.other
                    .. (self.kind == "wmo" and " hors WMO" or " en WMO") .. ". Exemple : " .. (raw.sample or "?")
            end
        end
    end
    self:Refresh()
end

searchBox:SetScript("OnTextChanged", function(_, userInput)
    if not userInput then return end
    win.typing = (win.typing or 0) + 1
    local mine = win.typing
    After(TYPE_DELAY, function() if mine == win.typing then win:Search() end end)
end)
searchBox:SetScript("OnEnterPressed", function(self) win:Search(); self:ClearFocus() end)
searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

win:SetScript("OnMouseWheel", function(_, delta)
    if menu:IsShown() then menu:Hide() end
    win.offset = win.offset - delta * 3
    win:Refresh()
end)

--- Change d'onglet ; la recherche saisie est rejouée dans le nouvel onglet.
function win:SetKind(kind)
    self.kind = kind
    menu:Hide()
    GM:ClearWorldPreview()
    ShowPreview(nil)
    self:Search()
end

--- Flèches : résultat suivant / précédent, aperçu aussitôt.
function win:Step(delta)
    local index, offset = GM.StepCursor(self.cursor, delta, #self.results, self.offset, ROWS)
    if not index then return false end
    if index == self.cursor then return true end   -- déjà au bout de la liste
    self.cursor, self.offset = index, offset
    menu:Hide()
    ShowPreview(self.results[index], true)
    return true
end
GM.BindArrowKeys(win, function(delta) return win:Step(delta) end, { searchBox })

for i, item in ipairs(KINDS) do
    local tab = UI.CreatePanelButton(win, 70, 22, item[2])
    tab:SetPoint("TOPLEFT", PAD + 110 + (i - 1) * 74, -12)
    tab:SetScript("OnClick", function() win:SetKind(item[1]) end)
    tabs[item[1]] = tab
end

win:HookScript("OnHide", function() GM:ClearWorldPreview() end)

win:SetScript("OnShow", function(self)
    distBox:SetText(tostring(WorldSettings().distance))
    ShowPreview(self.selected)
    self:Refresh()
end)

function GM:OpenDisplays(kind)
    win:Show()
    if kind and kind ~= win.kind then win:SetKind(kind) end
end
