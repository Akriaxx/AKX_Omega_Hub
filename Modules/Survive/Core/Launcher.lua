-- OmegaSurvive 2.0 — Launcher
local ADDON = "Omega_Hub"

local BTN_SIZE     = 36
local ICON_SIZE    = 36
local ICON_GAP     = 8
local LAUNCHER_ICON_OVERFLOW = 0.48   -- outward overflow fraction for the launcher icon texture
local ApplyLauncherIconSize           -- forward declaration (defined near the Launcher button block)
-- ICON_RADIUS is computed dynamically: launcherSize/2 + gap + iconSize/2,
-- so icons always clear the launcher edge and scale with both size settings.
-- Reads OS2DB directly (global SavedVariables) to avoid a forward-reference to EnsureDB.
local function GetIconRadius()
    local launcherSize = (OS2DB and OS2DB.launcherSize) or BTN_SIZE
    local iconSize     = (OS2DB and OS2DB.iconSize)     or ICON_SIZE
    return math.floor(launcherSize / 2 + ICON_GAP + iconSize / 2)
end

-- Returns the current menu layout type, reading OS2DB directly to avoid EnsureDB forward ref.
local function GetMenuType()
    return (OS2DB and OS2DB.menuType) or "bas"
end

-- Returns the (x, y) offset from the launcher CENTER for icon slot i out of total,
-- according to the current menuType setting.
local function GetButtonPos(i, total)
    local iconSize     = (OS2DB and OS2DB.iconSize)     or ICON_SIZE
    local launcherSize = (OS2DB and OS2DB.launcherSize) or BTN_SIZE
    local menuType     = GetMenuType()

    if menuType == "cercle" then
        local radius = GetIconRadius()
        local angle  = math.pi / 2 - (i - 1) * (2 * math.pi / math.max(1, total))
        return radius * math.cos(angle), radius * math.sin(angle)
    else
        -- Linear offset: each icon is one step further from the launcher edge.
        local offset = math.floor(launcherSize / 2) + ICON_GAP
                     + math.floor(iconSize / 2) + (i - 1) * (iconSize + ICON_GAP)
        if menuType == "droite" then return  offset,  0 end
        if menuType == "gauche" then return -offset,  0 end
        return 0, -offset  -- "bas" (default)
    end
end
local PANEL_W      = 240
local PANEL_H    = 250
local PANEL_GAP  = 8
local FADE_TIME  = 0.15
local PANEL_FADE = 0.11
local SLIDE_TIME = 0.18
local STAGGER    = 0.04

-- Arc animation: the menu icon traces a 3-segment chord approximation of a circular arc.
-- ARC_ANGLE controls the sweep (CCW, in radians). ARC_DUR is the total per-icon duration.
local ARC_ANGLE = math.pi * 0.75          -- 135° CW sweep
local ARC_DUR   = FADE_TIME * 2.0         -- total arc duration (0.30 s at default FADE_TIME)
local ARC_C1    = math.cos(ARC_ANGLE / 3)
local ARC_S1    = math.sin(ARC_ANGLE / 3)
local ARC_C2    = math.cos(ARC_ANGLE * 2 / 3)
local ARC_S2    = math.sin(ARC_ANGLE * 2 / 3)

------------------------------------------------------------------------
-- Namespace partagé
------------------------------------------------------------------------
OS2         = OS2 or {}
OS2.panels  = {}
OS2.windowFrames = OS2.windowFrames or {}
OS2.windowFrameBackgrounds = OS2.windowFrameBackgrounds or {}
OS2.PANEL_W = PANEL_W
OS2.PANEL_H = PANEL_H
OS2.Core    = OS2.Core or {}
OS2.LauncherFadeTime = FADE_TIME

local ITEMS = OS2.MenuItems or {}
local DEFAULT_LANTERN_EMOTES = OS2.DefaultLanternEmotes or {}
local DEFAULT_TORCH_EMOTES   = OS2.DefaultTorchEmotes   or {}
local DEFAULT_MODELS = OS2.Core.Models or {}
local DEFAULT_CRYSTALS = OS2.Core.Crystals or {}
local UI = OS2.UI or {}
local LEGACY_DEFAULT_PROFILE_NAME = "Personnage"
local PROFILE_FALLBACK_NAME = "Profil"

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$") or ""
end

local function NormalizeProfileName(name)
    name = Trim(name)
    if name == "" then
        return nil
    end

    if #name > 24 then
        name = name:sub(1, 24)
    end

    return name
end

local function NormalizeQuickActivationPosition(value, defaultValue)
    if value == "TOP" or value == "BOTTOM" or value == "RIGHT" or value == "LEFT" then
        return value
    end
    return defaultValue or "LEFT"
end

local function CopyKeyList(keys)
    local copied = {}
    for index, key in ipairs(keys or {}) do
        copied[index] = key
    end
    return copied
end

local function GetOrderedItems(toggleableOnly)
    local source = {}
    local byKey = {}
    local ordered = {}
    local savedOrder = ((OS2DB or {}).moduleOrder) or {}

    for _, item in ipairs(ITEMS) do
        if (not toggleableOnly) or item.toggleable then
            source[#source + 1] = item
            byKey[item.key] = item
        end
    end

    for _, key in ipairs(savedOrder) do
        local item = byKey[key]
        if item then
            ordered[#ordered + 1] = item
            byKey[key] = nil
        end
    end

    for _, item in ipairs(source) do
        if byKey[item.key] then
            ordered[#ordered + 1] = item
        end
    end

    return ordered
end

local function GetDefaultToggleableOrderKeys()
    local keys = {}
    for _, item in ipairs(ITEMS) do
        if item.toggleable then
            keys[#keys + 1] = item.key
        end
    end
    return keys
end

local function GetCharacterProfileName()
    local name = UnitName and UnitName("player")
    return NormalizeProfileName(name)
        or NormalizeProfileName(OS2DB and OS2DB.activeProfile)
        or PROFILE_FALLBACK_NAME
end

local function CopyEntryList(entries)
    local copied = {}
    for _, entry in ipairs(entries or {}) do
        local newEntry = {}
        for key, value in pairs(entry) do
            newEntry[key] = value
        end
        copied[#copied + 1] = newEntry
    end
    return copied
end

local function BuildKeyLookup(entries)
    local byKey = {}
    for _, entry in ipairs(entries or {}) do
        if entry.key then
            byKey[entry.key] = entry
        end
    end
    return byKey
end

local DEFAULT_MODEL_BY_KEY = BuildKeyLookup(DEFAULT_MODELS)
local DEFAULT_CRYSTAL_BY_KEY = BuildKeyLookup(DEFAULT_CRYSTALS)

local function EnsureDatabaseTables(database)
    database = database or {}
    database.models         = database.models         or {}
    database.crystals       = database.crystals       or {}
    database.lanternModules = database.lanternModules or {}
    database.torchModels    = database.torchModels    or {}
    database.torchFuels     = database.torchFuels     or {}

    if database.torche and #database.torche > 0 and #database.torchModels == 0 then
        for _, entry in ipairs(database.torche) do
            local copied = {}
            for key, value in pairs(entry) do
                copied[key] = value
            end
            copied.mult = copied.mult or 1
            database.torchModels[#database.torchModels + 1] = copied
        end
    end

    for _, mi in ipairs(ITEMS) do
        if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
            database[mi.key] = database[mi.key] or {}
        end
    end

    return database
end

local function EnsureProfileRecord(sharedDb, profileName)
    sharedDb.profiles = sharedDb.profiles or {}
    profileName = NormalizeProfileName(profileName) or GetCharacterProfileName()
    sharedDb.profiles[profileName] = sharedDb.profiles[profileName] or {}
    sharedDb.profiles[profileName].database = EnsureDatabaseTables(sharedDb.profiles[profileName].database)
    return sharedDb.profiles[profileName], profileName
end

local function MergeProfileDatabase(targetDatabase, sourceDatabase)
    targetDatabase = EnsureDatabaseTables(targetDatabase)
    sourceDatabase = EnsureDatabaseTables(sourceDatabase)

    for _, entry in ipairs(sourceDatabase.models or {}) do
        EnsureEntryInList(targetDatabase.models, entry)
    end

    for _, entry in ipairs(sourceDatabase.crystals or {}) do
        EnsureEntryInList(targetDatabase.crystals, entry)
    end

    for _, entry in ipairs(sourceDatabase.torchModels or {}) do
        EnsureEntryInList(targetDatabase.torchModels, entry)
    end

    for _, entry in ipairs(sourceDatabase.torchFuels or {}) do
        EnsureEntryInList(targetDatabase.torchFuels, entry)
    end

    for _, entry in ipairs(sourceDatabase.lanternModules or {}) do
        EnsureEntryInList(targetDatabase.lanternModules, entry)
    end

    for _, mi in ipairs(ITEMS) do
        if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
            targetDatabase[mi.key] = targetDatabase[mi.key] or {}
            sourceDatabase[mi.key] = sourceDatabase[mi.key] or {}
            for _, entry in ipairs(sourceDatabase[mi.key]) do
                EnsureEntryInList(targetDatabase[mi.key], entry)
            end
        end
    end

    return targetDatabase
end

local function MigrateLegacyDefaultProfile(sharedDb, characterProfileName)
    local legacyProfile = sharedDb.profiles and sharedDb.profiles[LEGACY_DEFAULT_PROFILE_NAME]
    if not legacyProfile or characterProfileName == LEGACY_DEFAULT_PROFILE_NAME then
        return
    end

    local targetProfile = sharedDb.profiles[characterProfileName]
    if targetProfile then
        targetProfile.database = MergeProfileDatabase(targetProfile.database, legacyProfile.database)
    else
        sharedDb.profiles[characterProfileName] = legacyProfile
    end

    sharedDb.profiles[LEGACY_DEFAULT_PROFILE_NAME] = nil

    if OS2DB and OS2DB.activeProfile == LEGACY_DEFAULT_PROFILE_NAME then
        OS2DB.activeProfile = characterProfileName
    end
end

local function EnsureEntryInList(list, entry)
    if not list or not entry or not entry.key then
        return false
    end

    for _, existing in ipairs(list) do
        if existing.key == entry.key then
            return false
        end
    end

    local newEntry = {}
    for key, value in pairs(entry) do
        newEntry[key] = value
    end
    list[#list + 1] = newEntry
    return true
end

local function SyncDatabaseFromKnowledge(db)
    db = db or OS2DB or {}
    db.database = EnsureDatabaseTables(db.database)

    local lantern = db.lantern or {}

    for key in pairs((db.unlocked and db.unlocked.models) or {}) do
        EnsureEntryInList(db.database.models, DEFAULT_MODEL_BY_KEY[key])
    end

    for key in pairs((db.unlocked and db.unlocked.crystals) or {}) do
        EnsureEntryInList(db.database.crystals, DEFAULT_CRYSTAL_BY_KEY[key])
    end

    if lantern.modelKey then
        EnsureEntryInList(db.database.models, DEFAULT_MODEL_BY_KEY[lantern.modelKey])
    end

    if lantern.crystalKey then
        EnsureEntryInList(db.database.crystals, DEFAULT_CRYSTAL_BY_KEY[lantern.crystalKey])
    end

    OS2.Core.Models      = db.database.models
    OS2.Core.Crystals    = db.database.crystals
    OS2.Core.Modules     = db.database.lanternModules
    OS2.Core.TorchModels = db.database.torchModels
    OS2.Core.TorchFuels  = db.database.torchFuels
    OS2.Core.Categories  = OS2.Core.Categories or {}
    for _, mi in ipairs(ITEMS) do
        if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
            OS2.Core.Categories[mi.key] = db.database[mi.key]
        end
    end
    OS2.RebuildCoreLookups()
end

OS2.SyncDatabaseFromKnowledge = SyncDatabaseFromKnowledge

local function EnsureSharedDB()
    OS2SharedDB = OS2SharedDB or {}
    OS2SharedDB.profiles = OS2SharedDB.profiles or {}
    return OS2SharedDB
end

function OS2.RebuildCoreLookups()
    local modelByKey      = {}
    local crystalByKey    = {}
    local moduleByKey     = {}
    local torchModelByKey = {}
    local torchFuelByKey  = {}

    for _, entry in ipairs(OS2.Core.Models or {}) do
        modelByKey[entry.key] = entry
    end

    for _, entry in ipairs(OS2.Core.Crystals or {}) do
        crystalByKey[entry.key] = entry
    end

    for _, entry in ipairs(OS2.Core.Modules or {}) do
        moduleByKey[entry.key] = entry
    end

    for _, entry in ipairs(OS2.Core.TorchModels or {}) do
        torchModelByKey[entry.key] = entry
    end

    for _, entry in ipairs(OS2.Core.TorchFuels or {}) do
        torchFuelByKey[entry.key] = entry
    end

    OS2.Core.ModelByKey      = modelByKey
    OS2.Core.CrystalByKey    = crystalByKey
    OS2.Core.ModuleByKey     = moduleByKey
    OS2.Core.TorchModelByKey = torchModelByKey
    OS2.Core.TorchFuelByKey  = torchFuelByKey
end

local function NormalizeSavedOrder(savedKeys, allowedKeys)
    local allowed = {}
    local normalized = {}

    for _, key in ipairs(allowedKeys or {}) do
        allowed[key] = true
    end

    for _, key in ipairs(savedKeys or {}) do
        if allowed[key] then
            normalized[#normalized + 1] = key
            allowed[key] = nil
        end
    end

    for _, key in ipairs(allowedKeys or {}) do
        if allowed[key] then
            normalized[#normalized + 1] = key
        end
    end

    return normalized
end

local function EnsureDB()
    OS2DB = OS2DB or {}
    OS2DB.panelOpacity  = OS2DB.panelOpacity or 0.65
    OS2DB.windowScale   = OS2DB.windowScale or 1.0
    OS2DB.animations    = OS2DB.animations ~= false  -- default true
    OS2DB.launcherSize  = OS2DB.launcherSize or BTN_SIZE
    OS2DB.menuType      = OS2DB.menuType or "bas"
    OS2DB.modules = OS2DB.modules or {}
    OS2DB.moduleOrder = NormalizeSavedOrder(OS2DB.moduleOrder, GetDefaultToggleableOrderKeys())
    OS2DB.databaseTabOrder = NormalizeSavedOrder(OS2DB.databaseTabOrder, GetDefaultToggleableOrderKeys())
    OS2DB.unlocked = OS2DB.unlocked or {}
    OS2DB.unlocked.models = OS2DB.unlocked.models or {}
    OS2DB.unlocked.crystals = OS2DB.unlocked.crystals or {}
    OS2DB.lantern = OS2DB.lantern or {}
    OS2DB.torch   = OS2DB.torch   or {}
    local sharedDb = EnsureSharedDB()
    local characterProfileName = GetCharacterProfileName()
    local activeProfileName = NormalizeProfileName(OS2DB.activeProfile) or characterProfileName

    if next(sharedDb.profiles) == nil then
        local migratedDatabase = EnsureDatabaseTables(OS2DB.database)
        OS2DB.database = migratedDatabase
        SyncDatabaseFromKnowledge(OS2DB)

        local profileDb = {
            models = CopyEntryList(migratedDatabase.models),
            crystals = CopyEntryList(migratedDatabase.crystals),
            lanternModules = CopyEntryList(migratedDatabase.lanternModules),
            torchModels = CopyEntryList(migratedDatabase.torchModels),
            torchFuels = CopyEntryList(migratedDatabase.torchFuels),
        }
        for _, mi in ipairs(ITEMS) do
            if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
                profileDb[mi.key] = CopyEntryList(migratedDatabase[mi.key])
            end
        end
        sharedDb.profiles[characterProfileName] = {
            database = profileDb,
        }
    end

    MigrateLegacyDefaultProfile(sharedDb, characterProfileName)

    if activeProfileName == LEGACY_DEFAULT_PROFILE_NAME then
        activeProfileName = characterProfileName
    end

    EnsureProfileRecord(sharedDb, characterProfileName)
    local activeProfile, ensuredName = EnsureProfileRecord(sharedDb, activeProfileName)
    OS2DB.activeProfile = ensuredName
    OS2DB.database = activeProfile.database

    OS2.Core.Models      = OS2DB.database.models
    OS2.Core.Crystals    = OS2DB.database.crystals
    OS2.Core.Modules     = OS2DB.database.lanternModules
    OS2.Core.TorchModels = OS2DB.database.torchModels
    OS2.Core.TorchFuels  = OS2DB.database.torchFuels
    OS2.Core.Categories  = OS2.Core.Categories or {}
    for _, mi in ipairs(ITEMS) do
        if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
            OS2.Core.Categories[mi.key] = OS2DB.database[mi.key]
        end
    end
    OS2.RebuildCoreLookups()

    for _, item in ipairs(ITEMS) do
        if item.toggleable then
            if OS2DB.modules[item.key] == nil then
                OS2DB.modules[item.key] = item.enabled and true or false
            end
        end
    end

    local lantern = OS2DB.lantern
    if lantern.mode ~= "ON" and lantern.mode ~= "OFF" and lantern.mode ~= "PAUSE" then
        lantern.mode = "OFF"
    end

    lantern.mjPaused = lantern.mjPaused == true or lantern.mode == "PAUSE"
    lantern.resumeMode = lantern.resumeMode == "ON" and "ON" or "OFF"
    lantern.drainRate = lantern.drainRate or 1.0
    lantern.remaining = lantern.remaining or 0
    lantern.remainingCharge = lantern.remainingCharge or lantern.remaining or 0
    lantern.lastUpdate = lantern.lastUpdate or 0
    lantern.quickActivation = lantern.quickActivation == true
    lantern.quickActivationPosition = NormalizeQuickActivationPosition(lantern.quickActivationPosition, "LEFT")
    lantern.emoteChannel    = lantern.emoteChannel or "EMOTE"
    lantern.crystalCharges  = lantern.crystalCharges or {}

    -- bump this constant whenever default emote texts change
    local EMOTES_VERSION = 3
    if (lantern.emotesVersion or 0) < EMOTES_VERSION then
        lantern.emotes        = {}
        lantern.emotesVersion = EMOTES_VERSION
    else
        lantern.emotes = lantern.emotes or {}
    end

    -- sync current crystal live charge into per-crystal persistence on every reload
    if lantern.crystalKey and lantern.remainingCharge then
        lantern.crystalCharges[lantern.crystalKey] = lantern.remainingCharge
    end

    for key, value in pairs(DEFAULT_LANTERN_EMOTES) do
        if lantern.emotes[key] == nil then
            lantern.emotes[key] = value
        end
    end

    if lantern.mjPaused then
        lantern.mode = "PAUSE"
    end

    if lantern.modelKey and OS2.Core and OS2.Core.ModelByKey and OS2.Core.ModelByKey[lantern.modelKey] then
        OS2DB.unlocked.models[lantern.modelKey] = true
    end

    if lantern.crystalKey and OS2.Core and OS2.Core.CrystalByKey and OS2.Core.CrystalByKey[lantern.crystalKey] then
        OS2DB.unlocked.crystals[lantern.crystalKey] = true
    end

    -- ── Torch state ────────────────────────────────────────────────────────────
    local torch = OS2DB.torch
    if torch.mode ~= "ON" and torch.mode ~= "OFF" and torch.mode ~= "PAUSE" then
        torch.mode = "OFF"
    end

    torch.mjPaused       = torch.mjPaused == true or torch.mode == "PAUSE"
    torch.resumeMode     = torch.resumeMode == "ON" and "ON" or "OFF"
    torch.drainRate      = torch.drainRate or 1.0
    torch.remaining      = torch.remaining or 0
    torch.remainingCharge = torch.remainingCharge or torch.remaining or 0
    torch.lastUpdate     = torch.lastUpdate or 0
    torch.quickActivation = torch.quickActivation == true
    torch.quickActivationPosition = NormalizeQuickActivationPosition(torch.quickActivationPosition, "RIGHT")
    torch.emoteChannel   = torch.emoteChannel or "EMOTE"
    torch.crystalCharges = torch.crystalCharges or {}

    local TORCH_EMOTES_VERSION = 1
    if (torch.emotesVersion or 0) < TORCH_EMOTES_VERSION then
        torch.emotes        = {}
        torch.emotesVersion = TORCH_EMOTES_VERSION
    else
        torch.emotes = torch.emotes or {}
    end

    -- sync current fuel live charge into per-fuel persistence on every reload
    if torch.crystalKey and torch.remainingCharge then
        torch.crystalCharges[torch.crystalKey] = torch.remainingCharge
    end

    for key, value in pairs(DEFAULT_TORCH_EMOTES) do
        if torch.emotes[key] == nil then
            torch.emotes[key] = value
        end
    end

    if torch.mjPaused then
        torch.mode = "PAUSE"
    end

    local DATABASE_MIGRATION_VERSION = 3
    if (OS2DB.databaseVersion or 0) < DATABASE_MIGRATION_VERSION then
        OS2DB.databaseVersion = DATABASE_MIGRATION_VERSION
    end

    return OS2DB
end

OS2.EnsureDB = EnsureDB

function OS2.GetProfileNames()
    EnsureDB()
    local sharedDb = EnsureSharedDB()
    local names = {}

    for name in pairs(sharedDb.profiles or {}) do
        names[#names + 1] = name
    end

    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)

    return names
end

function OS2.GetActiveProfileName()
    local db = EnsureDB()
    return db.activeProfile or GetCharacterProfileName()
end

function OS2.SetActiveProfile(profileName)
    local db = EnsureDB()
    local sharedDb = EnsureSharedDB()
    profileName = NormalizeProfileName(profileName)
    if not profileName then
        return false
    end

    local _, ensuredName = EnsureProfileRecord(sharedDb, profileName)
    db.activeProfile = ensuredName
    db.database = sharedDb.profiles[ensuredName].database

    OS2.Core.Models      = db.database.models
    OS2.Core.Crystals    = db.database.crystals
    OS2.Core.Modules     = db.database.lanternModules
    OS2.Core.TorchModels = db.database.torchModels
    OS2.Core.TorchFuels  = db.database.torchFuels
    OS2.Core.Categories  = OS2.Core.Categories or {}
    for _, mi in ipairs(ITEMS) do
        if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
            OS2.Core.Categories[mi.key] = db.database[mi.key]
        end
    end
    OS2.RebuildCoreLookups()

    if OS2.RefreshDatabasePanel      then OS2.RefreshDatabasePanel()      end
    if OS2.RefreshLanternPanel       then OS2.RefreshLanternPanel()       end
    if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
    if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
    if OS2.RefreshTorchConfigPanel   then OS2.RefreshTorchConfigPanel()   end
    if OS2.RefreshSettingsProfileControl then OS2.RefreshSettingsProfileControl() end

    OS2.Notify("Profil actif : " .. ensuredName .. ".")
    return true
end

function OS2.CreateProfile(profileName)
    EnsureDB()
    local sharedDb = EnsureSharedDB()
    profileName = NormalizeProfileName(profileName)
    if not profileName then
        return false, "Le nom du profil est obligatoire."
    end
    if sharedDb.profiles[profileName] then
        return false, "Un profil portant ce nom existe déjà."
    end

    EnsureProfileRecord(sharedDb, profileName)
    if OS2.RefreshSettingsProfileControl then
        OS2.RefreshSettingsProfileControl()
    end
    return true, profileName
end

function OS2.DeleteProfile(profileName)
    local db = EnsureDB()
    local sharedDb = EnsureSharedDB()
    profileName = NormalizeProfileName(profileName)
    if not profileName or not sharedDb.profiles[profileName] then
        return false, "Ce profil n'existe pas."
    end

    local names = OS2.GetProfileNames()
    if #names <= 1 then
        return false, "Vous devez conserver au moins un profil."
    end

    local wasActive = (db.activeProfile == profileName)

    -- Trouve le prochain profil AVANT la suppression.
    -- On préfère le profil du personnage s'il existe parmi les autres.
    local nextProfile = nil
    if wasActive then
        local charName = GetCharacterProfileName()
        for _, name in ipairs(names) do
            if name ~= profileName then
                nextProfile = name
                break
            end
        end
        for _, name in ipairs(names) do
            if name ~= profileName and name == charName then
                nextProfile = name
                break
            end
        end
    end

    -- Supprime le profil.
    sharedDb.profiles[profileName] = nil

    if wasActive and nextProfile then
        -- Bascule inline — NE PAS passer par OS2.SetActiveProfile ni EnsureDB :
        -- ces fonctions appelleraient EnsureProfileRecord(sharedDb, characterProfileName)
        -- ce qui recrée immédiatement le profil qu'on vient de supprimer.
        EnsureProfileRecord(sharedDb, nextProfile)
        db.activeProfile = nextProfile
        db.database = sharedDb.profiles[nextProfile].database

        OS2.Core.Models      = db.database.models
        OS2.Core.Crystals    = db.database.crystals
        OS2.Core.Modules     = db.database.lanternModules
        OS2.Core.TorchModels = db.database.torchModels
        OS2.Core.TorchFuels  = db.database.torchFuels
        OS2.Core.Categories  = OS2.Core.Categories or {}
        for _, mi in ipairs(ITEMS) do
            if mi.toggleable and mi.key ~= "lanterne" and mi.key ~= "torche" then
                OS2.Core.Categories[mi.key] = db.database[mi.key]
            end
        end
        OS2.RebuildCoreLookups()

        if OS2.RefreshDatabasePanel      then OS2.RefreshDatabasePanel()      end
        if OS2.RefreshLanternPanel       then OS2.RefreshLanternPanel()       end
        if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
        if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
        if OS2.RefreshTorchConfigPanel   then OS2.RefreshTorchConfigPanel()   end

        OS2.Notify("Profil actif : " .. nextProfile .. ".")
    end

    if OS2.RefreshSettingsProfileControl then
        OS2.RefreshSettingsProfileControl()
    end

    return true
end

function OS2.AnimationsEnabled()
    return not OS2DB or OS2DB.animations ~= false
end

function OS2.SetAnimationsEnabled(enabled)
    EnsureDB().animations = enabled and true or false
end

function OS2.GetLauncherSize()
    return EnsureDB().launcherSize or BTN_SIZE
end

function OS2.SetLauncherSize(size)
    size = math.max(20, math.min(52, math.floor(size + 0.5)))
    EnsureDB().launcherSize = size
    local launcher = _G.OS2_Launcher
    if launcher then
        -- Re-anchor at the current center before resizing so the frame grows
        -- symmetrically in all directions (prevents diagonal drift).
        local cx, cy = launcher:GetCenter()
        if cx and cy then
            launcher:ClearAllPoints()
            launcher:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
            if OS2DB then
                OS2DB.launcher = { point = "CENTER", relPoint = "BOTTOMLEFT", x = cx, y = cy }
            end
        end
        launcher:SetSize(size, size)
        ApplyLauncherIconSize(size)
    end
    -- Reposition icon ring + open panels
    if OS2.RefreshLauncherModules then
        OS2.RefreshLauncherModules()
    end
end

function OS2.GetWindowScale()
    return EnsureDB().windowScale or 1.0
end

function OS2.Notify(message, r, g, b)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffd9c27aOmegaSurvive:|r " .. message, r or 1, g or 1, b or 1)
        return
    end

    print("OmegaSurvive: " .. message)
end

function OS2.GetUnlockedEntries(kind)
    EnsureDB()
    local entries

    if kind == "models" then
        entries = OS2.Core.Models
    else
        entries = OS2.Core.Crystals
    end

    local result = {}
    for _, entry in ipairs(entries) do
        result[#result + 1] = entry
    end

    return result
end

function OS2.GetUnlockedTorchEntries(kind)
    EnsureDB()
    local entries

    if kind == "models" then
        entries = OS2.Core.TorchModels
    else
        entries = OS2.Core.TorchFuels
    end

    local result = {}
    for _, entry in ipairs(entries or {}) do
        result[#result + 1] = entry
    end

    return result
end


function OS2.GetLanternDB()
    return EnsureDB().lantern
end

function OS2.GetTorchDB()
    return EnsureDB().torch
end

function OS2.GetToggleableModules()
    return GetOrderedItems(true)
end

function OS2.GetOrderedMenuItems()
    return GetOrderedItems(false)
end

function OS2.GetModuleOrder()
    return CopyKeyList(((OS2DB or {}).moduleOrder) or {})
end

function OS2.SetModuleOrder(orderKeys)
    local db = EnsureDB()
    db.moduleOrder = CopyKeyList(orderKeys)

    if OS2.RefreshLauncherModules then
        OS2.RefreshLauncherModules()
    end

    if OS2.RefreshSettingsModules then
        OS2.RefreshSettingsModules()
    end
end

function OS2.GetDatabaseTabOrder()
    return CopyKeyList(((OS2DB or {}).databaseTabOrder) or {})
end

function OS2.SetDatabaseTabOrder(orderKeys)
    local db = EnsureDB()
    db.databaseTabOrder = NormalizeSavedOrder(orderKeys, GetDefaultToggleableOrderKeys())
end

function OS2.IsModuleEnabled(key)
    local db = EnsureDB()

    for _, item in ipairs(ITEMS) do
        if item.key == key then
            if not item.toggleable then
                return true
            end

            return db.modules[key] == true
        end
    end

    return false
end

function OS2.SetModuleEnabled(key, enabled)
    local db = EnsureDB()
    db.modules[key] = enabled and true or false

    if OS2.RefreshLauncherModules then
        OS2.RefreshLauncherModules()
    end

    if OS2.RefreshSettingsModules then
        OS2.RefreshSettingsModules()
    end
end

function OS2.GetIconSize()
    return EnsureDB().iconSize or ICON_SIZE
end

function OS2.ResetLauncherPosition()
    local launcher = _G.OS2_Launcher
    if not launcher then
        return
    end

    launcher:ClearAllPoints()
    launcher:SetPoint("CENTER")

    local db = EnsureDB()
    db.launcher = nil

    OS2.Notify("Le lanceur a été recentré.")
end

function OS2.ResetAddonData()
    local db = EnsureDB()
    local sharedDb = EnsureSharedDB()
    local lantern = db.lantern or {}
    local torch   = db.torch   or {}
    local activeProfileName = NormalizeProfileName(db.activeProfile) or GetCharacterProfileName()
    local activeProfile = EnsureProfileRecord(sharedDb, activeProfileName)

    wipe(lantern)
    wipe(torch)
    wipe(db)

    db.activeProfile = activeProfileName
    db.unlocked = {
        models = {},
        crystals = {},
    }
    db.modules = {}
    -- Les profils partagés ne doivent jamais être supprimés par un reset usine.
    -- On réattache simplement le profil actif au runtime local du personnage.
    db.database = activeProfile.database
    db.databaseVersion = 2
    db.moduleOrder = nil
    db.databaseTabOrder = nil
    db.lantern = lantern
    db.torch   = torch
    db.panelOpacity  = 0.65
    db.windowScale   = 1.0
    db.iconSize      = ICON_SIZE
    db.launcherSize  = BTN_SIZE
    db.menuType      = "bas"

    for _, item in ipairs(ITEMS) do
        if item.toggleable then
            db.modules[item.key] = item.enabled and true or false
        end
    end

    lantern.mode = "OFF"
    lantern.drainRate = 1.0
    lantern.remaining = 0
    lantern.remainingCharge = 0
    lantern.lastUpdate = 0
    lantern.mjPaused = false
    lantern.resumeMode = "OFF"
    lantern.quickActivation = false
    lantern.quickActivationPosition = "LEFT"
    lantern.emoteChannel = "EMOTE"
    lantern.modelKey = nil
    lantern.crystalKey = nil
    lantern.emotes = {}

    for key, value in pairs(DEFAULT_LANTERN_EMOTES) do
        lantern.emotes[key] = value
    end

    torch.mode = "OFF"
    torch.drainRate = 1.0
    torch.remaining = 0
    torch.remainingCharge = 0
    torch.lastUpdate = 0
    torch.mjPaused = false
    torch.resumeMode = "OFF"
    torch.quickActivation = false
    torch.quickActivationPosition = "RIGHT"
    torch.emoteChannel = "EMOTE"
    torch.modelKey = nil
    torch.crystalKey = nil
    torch.crystalCharges = {}
    torch.emotes = {}

    for key, value in pairs(DEFAULT_TORCH_EMOTES) do
        torch.emotes[key] = value
    end

    OS2.Core.Models      = db.database.models
    OS2.Core.Crystals    = db.database.crystals
    OS2.Core.Modules     = db.database.lanternModules
    OS2.Core.TorchModels = db.database.torchModels
    OS2.Core.TorchFuels  = db.database.torchFuels
    OS2.RebuildCoreLookups()

    local launcher = _G.OS2_Launcher
    if launcher then
        launcher:ClearAllPoints()
        launcher:SetPoint("CENTER")
    end

    OS2.SetPanelOpacity(db.panelOpacity)
    if OS2.opacitySlider then
        OS2.opacitySlider:SetValue(db.panelOpacity)
    end

    OS2.SetWindowScale(db.windowScale)
    if OS2.RefreshWindowScaleControl then
        OS2.RefreshWindowScaleControl()
    end

    OS2.SetIconSize(db.iconSize)
    if OS2.iconSizeSlider then
        OS2.iconSizeSlider:SetValue(db.iconSize)
    end

    OS2.SetLauncherSize(db.launcherSize or BTN_SIZE)
    if OS2.launcherSizeSlider then
        OS2.launcherSizeSlider:SetValue(db.launcherSize or BTN_SIZE)
    end

    if OS2.RefreshLauncherModules then
        OS2.RefreshLauncherModules()
    end

    if OS2.RefreshSettingsModules then
        OS2.RefreshSettingsModules()
    end

    if OS2.RefreshLanternPanel then
        OS2.RefreshLanternPanel()
    end

    if OS2.RefreshTorchPanel       then OS2.RefreshTorchPanel()       end
    if OS2.RefreshTorchConfigPanel then OS2.RefreshTorchConfigPanel() end

    OS2.Notify("Réinitialisation terminée. Les paramètres d'usine ont été restaurés.")
end

function OS2.TotalReset()
    -- Supprime tous les profils partagés (tous les personnages).
    local sharedDb = EnsureSharedDB()
    wipe(sharedDb)

    -- Supprime toutes les données du personnage courant.
    if OS2DB then wipe(OS2DB) end

    -- Réinitialise tout depuis zéro.
    -- EnsureDB verra les profils vides → bloc migration → crée un profil frais pour ce personnage.
    local db = EnsureDB()

    -- Recentre le lanceur.
    local launcher = _G.OS2_Launcher
    if launcher then
        launcher:ClearAllPoints()
        launcher:SetPoint("CENTER")
        db.launcher = nil
    end

    -- Synchronise les contrôles UI sur les nouvelles valeurs par défaut.
    OS2.SetPanelOpacity(db.panelOpacity)
    if OS2.opacitySlider then
        OS2.opacitySlider:SetValue(db.panelOpacity)
    end

    OS2.SetWindowScale(db.windowScale)
    if OS2.RefreshWindowScaleControl then
        OS2.RefreshWindowScaleControl()
    end

    OS2.SetIconSize(db.iconSize)
    if OS2.iconSizeSlider then
        OS2.iconSizeSlider:SetValue(db.iconSize)
    end

    OS2.SetLauncherSize(db.launcherSize or BTN_SIZE)
    if OS2.launcherSizeSlider then
        OS2.launcherSizeSlider:SetValue(db.launcherSize or BTN_SIZE)
    end

    if OS2.RefreshLauncherModules    then OS2.RefreshLauncherModules()    end
    if OS2.RefreshSettingsModules    then OS2.RefreshSettingsModules()    end
    if OS2.RefreshSettingsProfileControl then OS2.RefreshSettingsProfileControl() end
    if OS2.RefreshLanternPanel       then OS2.RefreshLanternPanel()       end
    if OS2.RefreshLanternConfigPanel then OS2.RefreshLanternConfigPanel() end
    if OS2.RefreshTorchPanel         then OS2.RefreshTorchPanel()         end
    if OS2.RefreshTorchConfigPanel   then OS2.RefreshTorchConfigPanel()   end
    if OS2.RefreshDatabasePanel      then OS2.RefreshDatabasePanel()      end

    OS2.Notify("Réinitialisation totale effectuée. Tous les profils et données ont été supprimés.")
end

OS2.SetPanelOpacity = function(alpha)
    EnsureDB()
    alpha = math.max(0.05, math.min(1.0, alpha))
    for _, p in pairs(OS2.panels) do
        UI.ApplyWindowBackground(p.bg, alpha)
    end
    for _, bg in pairs(OS2.windowFrameBackgrounds) do
        UI.ApplyWindowBackground(bg, alpha)
    end
    OS2DB = OS2DB or {}
    OS2DB.panelOpacity = alpha
end

local function ApplyWindowScaleToFrame(frame, scale)
    if frame and frame.SetScale then
        frame:SetScale(scale)
    end
end

function OS2.RegisterWindowFrame(frame, background)
    if not frame then
        return
    end

    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(false)
    end

    OS2.windowFrames[frame] = true
    if background then
        OS2.windowFrameBackgrounds[frame] = background
        UI.ApplyWindowBackground(background, EnsureDB().panelOpacity or 0.65)
    end
    ApplyWindowScaleToFrame(frame, OS2.GetWindowScale())
end

function OS2.SetWindowScale(scale)
    EnsureDB()
    scale = math.max(0.60, math.min(1.60, tonumber(scale) or 1.0))

    for _, panel in pairs(OS2.panels) do
        ApplyWindowScaleToFrame(panel, scale)
    end

    for frame in pairs(OS2.windowFrames) do
        ApplyWindowScaleToFrame(frame, scale)
    end

    OS2DB.windowScale = scale
end

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function SetCircleMask(tex, parent)
    local mask = parent:CreateMaskTexture()
    mask:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask",
        "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local function BuildAlphaAnim(frame, fromA, toA, delay)
    local ag = frame:CreateAnimationGroup()
    ag:SetToFinalAlpha(true)
    local a = ag:CreateAnimation("Alpha")
    a:SetFromAlpha(fromA)
    a:SetToAlpha(toA)
    a:SetDuration(FADE_TIME)
    a:SetStartDelay(delay or 0)
    return ag
end

function OS2.AttachOverlayFade(frame, duration)
    duration = duration or PANEL_FADE

    frame:SetAlpha(0)
    frame:Hide()

    local showAG = frame:CreateAnimationGroup()
    showAG:SetToFinalAlpha(true)
    local showFade = showAG:CreateAnimation("Alpha")
    showFade:SetFromAlpha(0)
    showFade:SetToAlpha(1)
    showFade:SetDuration(duration)
    showAG:SetScript("OnPlay", function()
        frame:SetAlpha(0)
        frame:Show()
    end)

    local hideAG = frame:CreateAnimationGroup()
    hideAG:SetToFinalAlpha(true)
    local hideFade = hideAG:CreateAnimation("Alpha")
    hideFade:SetFromAlpha(1)
    hideFade:SetToAlpha(0)
    hideFade:SetDuration(duration)
    hideAG:SetScript("OnFinished", function()
        frame:Hide()
    end)

    frame.overlayShowAG = showAG
    frame.overlayHideAG = hideAG
end

function OS2.ShowOverlay(frame)
    if not frame.overlayShowAG or not frame.overlayHideAG then
        frame:Show()
        return
    end

    if not OS2.AnimationsEnabled() then
        frame.overlayHideAG:Stop()
        frame.overlayShowAG:Stop()
        frame:SetAlpha(1)
        frame:Show()
        return
    end

    frame.overlayHideAG:Stop()
    frame.overlayShowAG:Play()
end

function OS2.HideOverlay(frame)
    if not frame.overlayShowAG or not frame.overlayHideAG then
        frame:Hide()
        return
    end

    if not OS2.AnimationsEnabled() then
        frame.overlayShowAG:Stop()
        frame.overlayHideAG:Stop()
        frame:SetAlpha(0)
        frame:Hide()
        return
    end

    frame.overlayShowAG:Stop()
    frame.overlayHideAG:Play()
end

-- Rend `frame` déplaçable en le tirant depuis `handle` (toute la zone d'entête).
-- Si `handle` est nil, c'est le frame lui-même qui sert de poignée.
function OS2.MakeDraggable(frame, handle)
    handle = handle or frame
    frame:SetMovable(true)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function() frame:StartMoving() end)
    handle:SetScript("OnDragStop",  function() frame:StopMovingOrSizing() end)
end

local function CreateWindowCloseButton(parent)
    return UI.CreateCloseButton(parent)
end

function OS2.BuildModuleShell(panel, options)
    options = options or {}

    local shell = panel.os2ModuleShell
    if not shell then
        shell = {}

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        title:SetPoint("TOP", panel, "TOP", 0, -13)
        UI.ApplyTitle(title)
        shell.title = title

        local gear = CreateFrame("Button", nil, panel)
        gear:SetSize(20, 20)
        gear:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)

        local gearTex = gear:CreateTexture(nil, "ARTWORK")
        gearTex:SetAllPoints()
        gearTex:SetTexture("Interface/Icons/INV_Misc_Gear_01")
        gearTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        shell.gearTex = gearTex

        local gearHL = gear:CreateTexture(nil, "HIGHLIGHT")
        gearHL:SetTexture("Interface/Buttons/ButtonHilight-Square")
        gearHL:SetAllPoints()
        gearHL:SetBlendMode("ADD")
        shell.gearHL = gearHL

        gear:SetScript("OnClick", function()
            if panel.os2OpenSettings then
                panel.os2OpenSettings()
            end
        end)
        shell.gear = gear

        -- Bouton × fermer
        local closeBtn = CreateWindowCloseButton(panel)
        closeBtn:SetScript("OnClick", function()
            if OS2.TogglePanel then
                OS2.TogglePanel(panel.moduleKey)
            end
        end)
        shell.closeBtn = closeBtn

        local separator = panel:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(separator)
        separator:SetHeight(1)
        separator:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -36)
        separator:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -36)
        shell.separator = separator
        shell.contentTop = -52

        -- Entête draggable (zone titre, 0 → -34)
        local dragHandle = CreateFrame("Frame", nil, panel)
        dragHandle:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0,   0)
        dragHandle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0,   0)
        dragHandle:SetHeight(36)
        OS2.MakeDraggable(panel, dragHandle)
        shell.dragHandle = dragHandle

        -- Élever gear et closeBtn au-dessus du dragHandle (priorité clic)
        gear:SetFrameLevel(dragHandle:GetFrameLevel() + 1)
        shell.closeBtn:SetFrameLevel(dragHandle:GetFrameLevel() + 1)

        panel.os2ModuleShell = shell
    end

    shell.title:SetText(options.title or "")
    panel.os2OpenSettings = options.onSettings

    local showSettings = options.showSettings ~= false
    shell.gear:SetShown(showSettings)

    return shell
end

function OS2.SetPanelAutoHeight(panel, contentBottom, bottomPadding, minHeight)
    local padding = bottomPadding or 18
    local floor = minHeight or PANEL_H
    local target = math.max(floor, math.ceil(contentBottom + padding))
    panel:SetHeight(target)
    return target
end

function OS2.CreateSimpleSettingsPanel(titleText, bodyText, height, owner)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(PANEL_W, height or 160)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(((owner and owner:GetFrameLevel()) or 1) + 20)
    panel:Hide()
    OS2.AttachOverlayFade(panel)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, OS2.EnsureDB().panelOpacity or 0.65)
    if OS2.RegisterWindowFrame then
        OS2.RegisterWindowFrame(panel, bg)
    end

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", panel, "TOP", 0, -13)
    title:SetText(titleText or "")
    UI.ApplyTitle(title)

    local closeBtn = CreateWindowCloseButton(panel)
    closeBtn:SetScript("OnClick", function()
        OS2.HideSettingsPanel(panel)
    end)

    local sep = panel:CreateTexture(nil, "ARTWORK")
    UI.ApplySeparator(sep)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -36)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -36)

    -- Entête draggable
    local dragHandle = CreateFrame("Frame", nil, panel)
    dragHandle:SetPoint("TOPLEFT",  panel, "TOPLEFT",  0, 0)
    dragHandle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    dragHandle:SetHeight(36)
    OS2.MakeDraggable(panel, dragHandle)

    local body = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    body:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -56)
    body:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetText(bodyText or "")
    UI.ApplyBodyText(body)

    panel.os2BodyText = body
    panel.os2TitleText = title
    panel.os2CloseButton = closeBtn

    panel.os2AutoFit = function(minHeight)
        local contentBottom = 56 + body:GetStringHeight()
        OS2.SetPanelAutoHeight(panel, contentBottom, 22, minHeight or 132)
    end
    panel.os2AutoFit(height or 160)

    return panel
end

------------------------------------------------------------------------
-- Launcher button
------------------------------------------------------------------------
local Launcher = CreateFrame("Button", "OS2_Launcher", UIParent)
Launcher:SetSize(BTN_SIZE, BTN_SIZE)
Launcher:SetPoint("CENTER")
Launcher:SetMovable(true)
Launcher:EnableMouse(true)
Launcher:RegisterForDrag("LeftButton")
Launcher:RegisterForClicks("LeftButtonUp")
OS2.Launcher = Launcher

ApplyLauncherIconSize = function(size)
    local off = math.floor(size * LAUNCHER_ICON_OVERFLOW + 0.5)
    -- Icon texture
    Launcher.iconTex:ClearAllPoints()
    Launcher.iconTex:SetPoint("TOPLEFT",     Launcher, "TOPLEFT",     -off,  off - 1)
    Launcher.iconTex:SetPoint("BOTTOMRIGHT", Launcher, "BOTTOMRIGHT",  off, -off - 1)
    -- Black background: sits exactly on the button bounds (no overflow).
    -- The icon overflows around it; SetMask clips it to the icon's rounded shape.
    if Launcher.iconBg then
        Launcher.iconBg:ClearAllPoints()
        Launcher.iconBg:SetPoint("TOPLEFT",     Launcher, "TOPLEFT",      2, -3)
        Launcher.iconBg:SetPoint("BOTTOMRIGHT", Launcher, "BOTTOMRIGHT", -2,  1)
    end
end

do
    -- ── Black background ──────────────────────────────────────────────────────
    -- Layer order (back→front): BACKGROUND (highlight) → BORDER (black bg) → ARTWORK (icon)
    -- Dedicated rounded-square texture so the launcher background is neither
    -- a harsh square nor a full circle.
    local bg = Launcher:CreateTexture(nil, "BORDER")
    bg:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Survive\\Core\\Media\\Launcher_bg")
    bg:SetTexCoord(0, 1, 0, 1)
    Launcher.iconBg = bg

    -- ── Icon BLP ──────────────────────────────────────────────────────────────
    local tex = Launcher:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Survive\\Core\\Media\\Launcher_icon")
    tex:SetTexCoord(0, 1, 0, 1)
    Launcher.iconTex = tex

    -- ── Highlight (BACKGROUND so it sits behind both bg and icon) ────────────
    -- Manually toggled via OnEnter/OnLeave since the HIGHLIGHT layer always draws on top.
    local hl = Launcher:CreateTexture(nil, "BACKGROUND")
    hl:SetTexture("Interface/Buttons/ButtonHilight-Square")
    hl:SetPoint("TOPLEFT",     Launcher, "TOPLEFT",     -3,  3)
    hl:SetPoint("BOTTOMRIGHT", Launcher, "BOTTOMRIGHT",  3, -3)
    hl:SetBlendMode("ADD")
    hl:Hide()
    Launcher:SetScript("OnEnter", function() hl:Show() end)
    Launcher:SetScript("OnLeave", function() hl:Hide() end)
end

-- Apply at default size immediately; called again by SetLauncherSize on each resize.
ApplyLauncherIconSize(BTN_SIZE)
Launcher.iconTex:SetVertexColor(1, 1, 1, 1)  -- default: white (closed state)

------------------------------------------------------------------------
-- Stack de panels
------------------------------------------------------------------------
local panelStack = {}
local settingsPanelStack = {}

local function ApplyPosition(panel, idx)
    panel:ClearAllPoints()
    local menuType = GetMenuType()

    if idx == 1 then
        local iconSize = (OS2DB and OS2DB.iconSize) or ICON_SIZE
        if menuType == "cercle" then
            -- Below the icon ring (current circle behaviour)
            local yOff = -(ICON_GAP + iconSize + PANEL_GAP)
            panel:SetPoint("TOPRIGHT", Launcher, "BOTTOM", 0, yOff)
        elseif menuType == "bas" then
            local lSize  = (OS2DB and OS2DB.launcherSize) or BTN_SIZE
            local visOff = math.floor(lSize * LAUNCHER_ICON_OVERFLOW + 0.5)
            panel:SetPoint("TOPRIGHT", Launcher, "TOPLEFT", -(visOff + PANEL_GAP - 4), 0)
        else -- "droite" et "gauche" : placement identique, seul le sens des icônes diffère.
            -- extraDown descend les fenêtres quand les icônes débordent sous le launcher.
            local lSize     = (OS2DB and OS2DB.launcherSize) or BTN_SIZE
            local extraDown = math.max(0, math.floor((iconSize - lSize) / 2 + 0.5))
            panel:SetPoint("TOPRIGHT", Launcher, "BOTTOM", 0, -(PANEL_GAP + extraDown))
        end
    else
        -- Tous les modes : empilement vers la gauche du panneau précédent
        panel:SetPoint("TOPRIGHT", panelStack[idx - 1], "TOPLEFT", -PANEL_GAP, 0)
    end
end

local OpenPanel, ClosePanel
local ApplySettingsPanelPosition, HideSettingsPanel

ClosePanel = function(idx)
    local panel = panelStack[idx]
    panel.showAG:Stop()
    if panel.os2OnClosed then
        panel.os2OnClosed()
    end
    table.remove(panelStack, idx)

    local next = panelStack[idx]

    if OS2.AnimationsEnabled() then
        panel.hideAG:SetScript("OnFinished", function()
            panel:Hide()
            if next then
                next.slideAG:SetScript("OnFinished", function()
                    ApplyPosition(next, idx)
                end)
                next.slideAG:Play()
            end
        end)
        panel.hideAG:Play()
    else
        panel:SetAlpha(0)
        panel:Hide()
        if next then
            ApplyPosition(next, idx)
        end
    end
end

ApplySettingsPanelPosition = function(panel, idx)
    panel:ClearAllPoints()
    if idx == 1 then
        local anchor   = panel.settingsAnchor or Launcher
        local menuType = GetMenuType()

        if menuType == "bas" and anchor == Launcher then
            local lSize  = (OS2DB and OS2DB.launcherSize) or BTN_SIZE
            local visOff = math.floor(lSize * LAUNCHER_ICON_OVERFLOW + 0.5)
            panel:SetPoint("TOPLEFT", Launcher, "TOPRIGHT", visOff + PANEL_GAP - 4, 0)
        elseif anchor == Launcher and panelStack[1] then
            -- Cas général : colle à droite du premier panneau principal
            panel:SetPoint("TOPLEFT", panelStack[1], "TOPRIGHT", PANEL_GAP, 0)
        elseif anchor == Launcher then
            -- Aucun panneau principal ouvert : repli sous l'anneau d'icônes
            local iconSize = (OS2DB and OS2DB.iconSize) or ICON_SIZE
            local yOff = -(ICON_GAP + iconSize + PANEL_GAP)
            panel:SetPoint("TOPLEFT", Launcher, "BOTTOM", 0, yOff)
        else
            panel:SetPoint("TOPLEFT", anchor, "TOPRIGHT", PANEL_GAP, 0)
        end
    else
        panel:SetPoint("TOPLEFT", settingsPanelStack[idx - 1], "TOPRIGHT", PANEL_GAP, 0)
    end
end

local function FindSettingsPanelIndex(panel)
    for idx, entry in ipairs(settingsPanelStack) do
        if entry == panel then
            return idx
        end
    end

    return nil
end

HideSettingsPanel = function(panel)
    local idx = FindSettingsPanelIndex(panel)
    if not idx then
        OS2.HideOverlay(panel)
        return
    end

    table.remove(settingsPanelStack, idx)
    local next = settingsPanelStack[idx]

    if OS2.AnimationsEnabled() and panel.overlayHideAG then
        -- chain slide animation after fade-out, mirroring ClosePanel on the left side
        panel.overlayHideAG:SetScript("OnFinished", function()
            panel:Hide()
            if next and next.slideAG then
                next.slideAG:SetScript("OnFinished", function()
                    ApplySettingsPanelPosition(next, idx)
                end)
                next.slideAG:Play()
            else
                for stackIndex = idx, #settingsPanelStack do
                    ApplySettingsPanelPosition(settingsPanelStack[stackIndex], stackIndex)
                end
            end
        end)
        panel.overlayShowAG:Stop()
        panel.overlayHideAG:Play()
    else
        if panel.overlayShowAG then panel.overlayShowAG:Stop() end
        if panel.overlayHideAG then panel.overlayHideAG:Stop() end
        panel:SetAlpha(0)
        panel:Hide()
        for stackIndex = idx, #settingsPanelStack do
            ApplySettingsPanelPosition(settingsPanelStack[stackIndex], stackIndex)
        end
    end
end

function OS2.IsSettingsPanelOpen(panel)
    return FindSettingsPanelIndex(panel) ~= nil
end

function OS2.ShowSettingsPanel(panel, anchor)
    if OS2.IsSettingsPanelOpen(panel) then
        return
    end

    -- attach slide animation lazily (mirrored: settings panels slide left, main panels slide right)
    if not panel.slideAG then
        local slideAG = panel:CreateAnimationGroup()
        local slideTrans = slideAG:CreateAnimation("Translation")
        slideTrans:SetOffset(-(PANEL_W + PANEL_GAP), 0)
        slideTrans:SetDuration(SLIDE_TIME)
        panel.slideAG = slideAG
    end

    panel.settingsAnchor = anchor or panel.settingsAnchor or Launcher
    table.insert(settingsPanelStack, panel)
    ApplySettingsPanelPosition(panel, #settingsPanelStack)
    OS2.ShowOverlay(panel)
end

function OS2.HideSettingsPanel(panel)
    HideSettingsPanel(panel)
end

function OS2.ToggleSettingsPanel(panel, anchor)
    if OS2.IsSettingsPanelOpen(panel) then
        HideSettingsPanel(panel)
    else
        OS2.ShowSettingsPanel(panel, anchor)
    end
end

local function HideAllSettingsPanels()
    for idx = #settingsPanelStack, 1, -1 do
        OS2.HideOverlay(settingsPanelStack[idx])
        table.remove(settingsPanelStack, idx)
    end
end

OpenPanel = function(panel)
    for i, p in ipairs(panelStack) do
        if p == panel then
            ClosePanel(i)
            return
        end
    end
    table.insert(panelStack, panel)
    ApplyPosition(panel, #panelStack)
    panel.hideAG:Stop()
    panel.showAG:Stop()
    if panel.os2OnOpened then
        panel.os2OnOpened()
    end
    if OS2.AnimationsEnabled() then
        panel.showAG:Play()
    else
        panel:SetAlpha(1)
        panel:Show()
    end
end

function OS2.TogglePanel(key)
    local panel = OS2.panels[key]
    if panel then
        OpenPanel(panel)
    end
end

function OS2.GetMenuType()
    return EnsureDB().menuType or "bas"
end

function OS2.SetMenuType(menuType)
    local valid = { bas = true, droite = true, gauche = true, cercle = true }
    if not valid[menuType] then return end
    EnsureDB().menuType = menuType
    -- Re-layout icons + reposition any open panels
    if OS2.RefreshLauncherModules then OS2.RefreshLauncherModules() end
    for idx, p in ipairs(panelStack) do ApplyPosition(p, idx) end
    if OS2.RefreshMenuTypeButtons then OS2.RefreshMenuTypeButtons() end
end

local function CreatePanel()
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:SetSize(PANEL_W, PANEL_H)
    panel:SetAlpha(0)
    panel:Hide()
    panel:EnableMouse(true)
    if panel.SetPropagateMouseClicks then
        panel:SetPropagateMouseClicks(false)
    end

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, EnsureDB().panelOpacity or 0.65)
    panel.bg = bg

    -- Fade in
    local showAG = panel:CreateAnimationGroup()
    showAG:SetToFinalAlpha(true)
    local showFade = showAG:CreateAnimation("Alpha")
    showFade:SetFromAlpha(0)
    showFade:SetToAlpha(1)
    showFade:SetDuration(PANEL_FADE)
    showAG:SetScript("OnPlay", function()
        panel:SetAlpha(0)
        panel:Show()
    end)

    -- Fade out
    local hideAG = panel:CreateAnimationGroup()
    hideAG:SetToFinalAlpha(true)
    local hideFade = hideAG:CreateAnimation("Alpha")
    hideFade:SetFromAlpha(1)
    hideFade:SetToAlpha(0)
    hideFade:SetDuration(PANEL_FADE)
    hideAG:SetScript("OnFinished", function() panel:Hide() end)

    -- Slide droite (correction de position)
    local slideAG = panel:CreateAnimationGroup()
    local slideTrans = slideAG:CreateAnimation("Translation")
    slideTrans:SetOffset(PANEL_W + PANEL_GAP, 0)
    slideTrans:SetDuration(SLIDE_TIME)
    slideAG:SetScript("OnFinished", function() end)

    panel.showAG  = showAG
    panel.hideAG  = hideAG
    panel.slideAG = slideAG
    ApplyWindowScaleToFrame(panel, OS2.GetWindowScale())
    return panel
end

------------------------------------------------------------------------
-- Circular menu helpers
------------------------------------------------------------------------

-- Returns the (x, y) offset from the launcher CENTER for slot i out of total.
-- Slot 1 is at the top (12 o'clock), going clockwise.
local function GetCirclePos(i, total, radius)
    -- standard math angle: 90° = top; clockwise → subtract per step
    local angle = math.pi / 2 - (i - 1) * (2 * math.pi / math.max(1, total))
    return radius * math.cos(angle), radius * math.sin(angle)
end

-- Creates show/hide animation groups on a button (called once at creation).
-- Show uses THREE stacked Translations in the same group.
-- Each phase is a chord of the circle arc; together they approximate a smooth CCW curve
-- from the launcher center outward to the final slot position.
-- While the group is still active, completed phases keep their final offset → phases stack.
local function EnsureButtonAnimations(btn)
    if btn.showAG then return end

    local phase = ARC_DUR / 3

    local showAG = btn:CreateAnimationGroup()
    showAG:SetToFinalAlpha(true)
    -- Alpha fades in over the whole arc so the sweep is visible throughout
    local showAlpha = showAG:CreateAnimation("Alpha")
    showAlpha:SetFromAlpha(0)
    showAlpha:SetToAlpha(1)
    showAlpha:SetDuration(ARC_DUR)
    -- Phase 1: center → first arc waypoint
    local showArc1 = showAG:CreateAnimation("Translation")
    showArc1:SetDuration(phase)
    -- Phase 2: first → second arc waypoint
    local showArc2 = showAG:CreateAnimation("Translation")
    showArc2:SetDuration(phase)
    -- Phase 3: second waypoint → final slot
    local showArc3 = showAG:CreateAnimation("Translation")
    showArc3:SetDuration(phase)

    local hideAG = btn:CreateAnimationGroup()
    hideAG:SetToFinalAlpha(true)
    local hideAlpha = hideAG:CreateAnimation("Alpha")
    hideAlpha:SetFromAlpha(1)
    hideAlpha:SetToAlpha(0)
    hideAlpha:SetDuration(FADE_TIME)
    local hideTrans = hideAG:CreateAnimation("Translation")
    hideTrans:SetDuration(FADE_TIME)

    btn.showAG    = showAG
    btn.showAlpha = showAlpha
    btn.showArc1  = showArc1
    btn.showArc2  = showArc2
    btn.showArc3  = showArc3
    btn.hideAG    = hideAG
    btn.hideAlpha = hideAlpha
    btn.hideTrans = hideTrans
end

-- Updates stagger delays and arc chord offsets for the button's current circle slot.
-- The 3-waypoint arc is parameterised as: at fraction f, radius = R*f, angle = θ − arc*(1−f).
-- This traces a CCW spiral from the launcher center outward to the final position.
local function UpdateButtonAnimPos(btn, x, y, index, total)
    EnsureButtonAnimations(btn)

    local staggerIn  = (index - 1) * STAGGER
    local staggerOut = (total - index) * STAGGER
    local phase      = ARC_DUR / 3

    btn.showAlpha:SetStartDelay(staggerIn)

    if GetMenuType() == "cercle" then
        -- Three chord segments approximating a clockwise circular arc
        -- Waypoints at f=1/3, 2/3, 1 on the spiral arc toward (x,y).
        local w1x = (x * ARC_C2 - y * ARC_S2) / 3
        local w1y = (y * ARC_C2 + x * ARC_S2) / 3
        local w2x = 2 * (x * ARC_C1 - y * ARC_S1) / 3
        local w2y = 2 * (y * ARC_C1 + x * ARC_S1) / 3
        btn.showArc1:SetOffset(w1x,         w1y)
        btn.showArc2:SetOffset(w2x - w1x,   w2y - w1y)
        btn.showArc3:SetOffset(x   - w2x,   y   - w2y)
    else
        -- Straight line split into 3 equal segments
        btn.showArc1:SetOffset(x / 3, y / 3)
        btn.showArc2:SetOffset(x / 3, y / 3)
        btn.showArc3:SetOffset(x / 3, y / 3)
    end

    -- Show: three stacked chord offsets that together reach (x, y)
    btn.showArc1:SetStartDelay(staggerIn)
    btn.showArc2:SetStartDelay(staggerIn + phase)
    btn.showArc3:SetStartDelay(staggerIn + 2 * phase)
    btn.showAG:SetScript("OnPlay", function()
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Launcher, "CENTER", 0, 0)
        btn:SetAlpha(0)
        btn:Show()
    end)
    btn.showAG:SetScript("OnFinished", function()
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Launcher, "CENTER", x, y)
    end)

    -- Hide: straight slide back to launcher center + fade out
    btn.hideAlpha:SetStartDelay(staggerOut)
    btn.hideTrans:SetOffset(-x, -y)
    btn.hideTrans:SetStartDelay(staggerOut)
    btn.hideAG:SetScript("OnPlay", function()
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Launcher, "CENTER", x, y)
    end)
    btn.hideAG:SetScript("OnFinished", function()
        btn:Hide()
    end)

    btn.circleX = x
    btn.circleY = y
end

------------------------------------------------------------------------
-- Menu
------------------------------------------------------------------------
local menuOpen = false
local buttons  = {}
local N        = #ITEMS

function OS2.IsLauncherMenuOpen()
    return menuOpen
end

local function RefreshExternalControls()
    if OS2.RefreshLanternQuickControls then
        OS2.RefreshLanternQuickControls()
    end
    if OS2.RefreshTorchQuickControls then
        OS2.RefreshTorchQuickControls()
    end
end

local function GetActiveButtons()
    local active = {}
    local orderIndex = {}

    for index, item in ipairs(OS2.GetToggleableModules()) do
        orderIndex[item.key] = index
    end

    for _, btn in ipairs(buttons) do
        if OS2.IsModuleEnabled(btn.key) then
            active[#active + 1] = btn
        end
    end

    table.sort(active, function(a, b)
        return (orderIndex[a.key] or 999) < (orderIndex[b.key] or 999)
    end)

    return active
end

local function HidePanelForButton(btn)
    if btn.panel then
        HideAllSettingsPanels()
        if btn.panel:IsShown() and btn.panel.os2OnClosed then
            btn.panel.os2OnClosed()
        end
        btn.panel.showAG:Stop()
        btn.panel.hideAG:Stop()
        btn.panel.slideAG:Stop()
        btn.panel:SetAlpha(0)
        btn.panel:Hide()
    end
end

local function ApplyIconSize(size)
    size = math.max(24, math.min(64, math.floor((size or ICON_SIZE) + 0.5)))

    -- Save FIRST so GetIconRadius() reads the new value when computing positions
    EnsureDB().iconSize = size

    local activeButtons = GetActiveButtons()
    local total = #activeButtons
    for i, btn in ipairs(activeButtons) do
        btn:SetSize(size, size)
        local x, y = GetButtonPos(i, total)
        UpdateButtonAnimPos(btn, x, y, i, total)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Launcher, "CENTER", x, y)
    end

    -- Reposition any open panels to match the new icon ring clearance
    for idx, panel in ipairs(panelStack) do
        ApplyPosition(panel, idx)
    end
end

OS2.SetIconSize = ApplyIconSize

for i, data in ipairs(ITEMS) do
    local btn = CreateFrame("Button", nil, UIParent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetPoint("CENTER", Launcher, "CENTER", 0, 0)   -- overwritten by RefreshLauncherModules
    btn:SetAlpha(0)
    btn:Hide()

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(data.tex)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    SetCircleMask(tex, btn)

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface/CHARACTERFRAME/TempPortraitAlphaMask")
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0.2)

    EnsureButtonAnimations(btn)  -- positions assigned later by RefreshLauncherModules
    btn.key = data.key
    btn.panel  = CreatePanel()
    btn.panel.moduleKey = data.key

    OS2.panels[data.key] = btn.panel

    btn:SetScript("OnClick", function() OpenPanel(btn.panel) end)

    buttons[i] = btn
end

local function RefreshLauncherModules()
    local activeButtons = GetActiveButtons()
    local total = #activeButtons
    local activeLookup = {}

    for index, btn in ipairs(activeButtons) do
        activeLookup[btn] = true
        local x, y = GetButtonPos(index, total)
        UpdateButtonAnimPos(btn, x, y, index, total)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Launcher, "CENTER", x, y)

        if menuOpen then
            btn:Show()
            btn:SetAlpha(1)
        else
            btn:SetAlpha(0)
            btn:Hide()
        end
    end

    for _, btn in ipairs(buttons) do
        if not activeLookup[btn] then
            btn.showAG:Stop()
            btn.hideAG:Stop()
            btn:SetAlpha(0)
            btn:Hide()
            HidePanelForButton(btn)
        end
    end

    for idx = #panelStack, 1, -1 do
        local panel = panelStack[idx]
        if panel.moduleKey and not OS2.IsModuleEnabled(panel.moduleKey) then
            table.remove(panelStack, idx)
        end
    end

    for idx, panel in ipairs(panelStack) do
        ApplyPosition(panel, idx)
    end

    RefreshExternalControls()
end

OS2.RefreshLauncherModules = RefreshLauncherModules

local function OpenMenu()
    menuOpen = true
    -- Gold tint (#CCB366) when the menu is open
    if Launcher.iconTex then
        Launcher.iconTex:SetVertexColor(unpack(UI.colors.tabLine))
    end
    for _, btn in ipairs(GetActiveButtons()) do
        btn.hideAG:Stop()
        if OS2.AnimationsEnabled() then
            btn.showAG:Play()
        else
            btn.showAG:Stop()
            btn:SetAlpha(1)
            btn:Show()
        end
    end
    RefreshExternalControls()
end

local function CloseMenu()
    menuOpen = false
    -- Back to white when the menu is closed
    if Launcher.iconTex then
        Launcher.iconTex:SetVertexColor(1, 1, 1, 1)
    end
    HideAllSettingsPanels()
    for _, p in ipairs(panelStack) do
        if p.os2OnClosed then
            p.os2OnClosed()
        end
        p.showAG:Stop()
        p.slideAG:Stop()
        p.hideAG:Stop()
        p:SetAlpha(0)
        p:Hide()
    end
    wipe(panelStack)
    for _, btn in ipairs(GetActiveButtons()) do
        btn.showAG:Stop()
        if OS2.AnimationsEnabled() then
            btn.hideAG:Play()
        else
            btn.hideAG:Stop()
            btn:SetAlpha(0)
            btn:Hide()
        end
    end
    RefreshExternalControls()
end

------------------------------------------------------------------------
-- Scripts
------------------------------------------------------------------------
Launcher:SetScript("OnDragStart", Launcher.StartMoving)

Launcher:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    OS2DB = OS2DB or {}
    local point, _, relPoint, x, y = self:GetPoint()
    OS2DB.launcher = { point = point, relPoint = relPoint, x = x, y = y }
end)

Launcher:SetScript("OnClick", function(_, btn)
    if btn == "LeftButton" then
        if menuOpen then CloseMenu() else OpenMenu() end
    end
end)

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
-- ── Enable / Disable (API Hub) ─────────────────────────────────────────────

function OS2:Enable()
    Launcher:Show()
    OmegaHub:SetModuleLoaded("Omega_Survive", true)
    OmegaHub.Print("Omega Survive activé.")
end

function OS2:Disable()
    -- Ferme tous les panneaux ouverts
    for _, panel in pairs(OS2.panels or {}) do
        if panel.Hide then panel:Hide() end
    end
    Launcher:Hide()
    OmegaHub:SetModuleLoaded("Omega_Survive", false)
    OmegaHub.Print("Omega Survive désactivé.")
end

-- ── Init ───────────────────────────────────────────────────────────────────

local init = CreateFrame("Frame")
init:RegisterEvent("ADDON_LOADED")
init:SetScript("OnEvent", function(_, _, addon)
    if addon ~= ADDON then return end
    init:UnregisterEvent("ADDON_LOADED")

    -- Lie le module au Hub
    OmegaHub:RegisterModule({ name = "Omega_Survive", module = OS2 })

    if not OmegaHub:IsModuleEnabled("Omega_Survive") then
        Launcher:Hide()
        return
    end

    EnsureDB()

    if OS2DB.launcher then
        local p = OS2DB.launcher
        Launcher:ClearAllPoints()
        Launcher:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    end

    local opacity = OS2DB.panelOpacity or 0.65
    OS2.SetPanelOpacity(opacity)
    if OS2.opacitySlider then OS2.opacitySlider:SetValue(opacity) end

    local windowScale = OS2DB.windowScale or 1.0
    OS2.SetWindowScale(windowScale)
    if OS2.RefreshWindowScaleControl then OS2.RefreshWindowScaleControl() end

    local iconSize = OS2DB.iconSize or ICON_SIZE
    OS2.SetIconSize(iconSize)
    if OS2.iconSizeSlider then OS2.iconSizeSlider:SetValue(iconSize) end

    RefreshLauncherModules()

    if OS2.InitLanternPersistence then OS2.InitLanternPersistence() end
    if OS2.InitTorchPersistence   then OS2.InitTorchPersistence()   end

    RefreshExternalControls()
    OmegaHub:SetModuleLoaded("Omega_Survive", true)
end)
