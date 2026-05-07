-- OmegaSpell - DB.lua
-- Couche données : sorts, groupes d'émotes, macros, barres.

OmegaSpell = OmegaSpell or {}
local OS = OmegaSpell

-- ── Defaults ──────────────────────────────────────────────────────────────────

local DEFAULT_EMOTE_GROUPS = {
    ["Taverne"] = {
        "tapote le comptoir pour appeler l'aubergiste.",
        "lève sa chope en direction de la salle.",
        "s'installe dans l'ombre, observant les allers-retours.",
    },
}

-- ── Helpers internes ──────────────────────────────────────────────────────────

local function Trim(s)
    return tostring(s or ""):match("^%s*(.-)%s*$") or ""
end

local function GenerateMacroID()
    local t = GetTime and math.floor(GetTime() * 1000) % 999999 or 0
    local r = math.random(10000, 99999)
    return string.format("omsp_%d_%d", t, r)
end

local function NewBarCfg(index)
    return {
        name   = "Barre Omega " .. index,
        shown  = false,
        cols   = 12,
        rows   = 1,
        point  = nil, relPoint = nil, x = nil, y = nil,
        w      = nil, h = nil,
        slots  = {},
    }
end

-- ── Init ──────────────────────────────────────────────────────────────────────

function OS.DB_Init()
    OmegaSpellDB = OmegaSpellDB or {}

    -- Groupes d'émotes
    if not OmegaSpellDB.emoteGroups then
        OmegaSpellDB.emoteGroups = {}
        for k, v in pairs(DEFAULT_EMOTE_GROUPS) do
            OmegaSpellDB.emoteGroups[k] = {}
            for i, p in ipairs(v) do OmegaSpellDB.emoteGroups[k][i] = p end
        end
    end

    -- Sorts
    if not OmegaSpellDB.spells then
        OmegaSpellDB.spells = {}
    end

    -- Macro IDs (reverse lookup macroID → spellName)
    if not OmegaSpellDB.macroIDs then
        OmegaSpellDB.macroIDs = {}
    end

    -- Macros Omega indépendantes des sorts.
    if not OmegaSpellDB.macros then
        OmegaSpellDB.macros = {}
    end

    -- Barres
    if not OmegaSpellDB.bars then
        OmegaSpellDB.bars = {}
    end

    -- Cache des macros WoW natives par profil.
    -- L'API WoW expose Global + personnage connecté ; les autres personnages
    -- deviennent disponibles ici après ouverture du module sur ces personnages.
    if not OmegaSpellDB.wowMacroProfiles then
        OmegaSpellDB.wowMacroProfiles = {
            global = {},
            characters = {},
        }
    end
    OmegaSpellDB.wowMacroProfiles.global = OmegaSpellDB.wowMacroProfiles.global or {}
    OmegaSpellDB.wowMacroProfiles.characters = OmegaSpellDB.wowMacroProfiles.characters or {}

    -- Migration : ancienne clé "groups" → "emoteGroups"
    if OmegaSpellDB.groups and not next(OmegaSpellDB.emoteGroups) then
        OmegaSpellDB.emoteGroups = OmegaSpellDB.groups
        OmegaSpellDB.groups = nil
    end

    -- Migration : ancien barSlots plat → bars[1].slots
    if OmegaSpellDB.barSlots and next(OmegaSpellDB.barSlots) then
        if not OmegaSpellDB.bars[1] then
            OmegaSpellDB.bars[1] = NewBarCfg(1)
        end
        OmegaSpellDB.bars[1].slots = OmegaSpellDB.barSlots
        OmegaSpellDB.barSlots = nil
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SORTS
-- ═══════════════════════════════════════════════════════════════════════════

function OS.GetSpell(name)
    if not name then return nil end
    for k, v in pairs(OmegaSpellDB.spells) do
        if k:lower() == name:lower() then return v, k end
    end
end

function OS.GetSpellByMacroID(macroID)
    if not macroID then return nil end
    local spellName = OmegaSpellDB.macroIDs[macroID]
    if spellName then
        local spell, realName = OS.GetSpell(spellName)
        if spell then return spell, realName end
    end
    local record = OmegaSpellDB.macros and OmegaSpellDB.macros[macroID]
    if record then
        return record, record.name or record.spellName or macroID
    end
    return nil
end

function OS.GetSortedSpellNames()
    local names = {}
    for k in pairs(OmegaSpellDB.spells) do names[#names + 1] = k end
    table.sort(names)
    return names
end

function OS.AddSpell(name)
    name = Trim(name)
    if name == "" then return false, "Nom vide." end
    if OmegaSpellDB.spells[name] then return false, "Sort déjà existant." end
    OmegaSpellDB.spells[name] = {
        name     = name,
        category = "",
        icon     = "Interface\\Icons\\INV_Misc_QuestionMark",
        channel  = "EMOTE",
        variants = {},
        macroName    = name:sub(1, 16),
        macroLines   = {},
        macroID      = nil,
        macroCreatedName = nil,
        arcID        = "",
        description  = "",
        cooldown     = 0,
    }
    return true
end

function OS.DeleteSpell(name)
    local spell = OmegaSpellDB.spells[name]
    if spell and spell.macroID and spell.macroID ~= "" and not (OmegaSpellDB.macros and OmegaSpellDB.macros[spell.macroID]) then
        OS.SaveAddonMacro(name)
    end
    OmegaSpellDB.spells[name] = nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VARIANTS (groupes d'émotes liés à un sort)
-- ═══════════════════════════════════════════════════════════════════════════

-- Retourne le nom de groupe quelque soit le format stocké
-- (string "Taverne" ou table hérité {group="Taverne", type="emoteGroup", weight=1})
local function VariantGroupName(v)
    if type(v) == "table" then return v.group or "" end
    return v or ""
end

function OS.IsSpellUsingEmoteGroup(spellName, groupName)
    local spell = OS.GetSpell(spellName)
    if not spell then return false end
    for _, v in ipairs(spell.variants or {}) do
        if VariantGroupName(v) == groupName then return true end
    end
    return false
end

function OS.ToggleSpellEmoteGroupVariant(spellName, groupName)
    local spell = OS.GetSpell(spellName)
    if not spell then return end
    spell.variants = spell.variants or {}
    for i, v in ipairs(spell.variants) do
        if VariantGroupName(v) == groupName then
            table.remove(spell.variants, i)
            return
        end
    end
    -- Toujours stocker en string désormais (migration silencieuse)
    table.insert(spell.variants, groupName)
end

function OS.GetRandomVariant(spell)
    if not spell then return nil end
    local v = spell.variants or {}
    if #v == 0 then return nil end
    local raw = v[math.random(1, #v)]
    -- Support format hérité (table) et format courant (string)
    local groupName = VariantGroupName(raw)
    return { type = "emoteGroup", group = groupName }
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MACROS
-- ═══════════════════════════════════════════════════════════════════════════

function OS.GetSpellMacroName(spellName)
    local spell = OS.GetSpell(spellName)
    if not spell then return (spellName or ""):sub(1, 16) end
    return spell.macroName or (spellName or ""):sub(1, 16)
end

function OS.SetSpellMacroName(spellName, macroName)
    local spell = OS.GetSpell(spellName)
    if not spell then return end
    spell.macroName = Trim(macroName):sub(1, 16)
end

function OS.SetSpellMacroLines(spellName, lines)
    local spell = OS.GetSpell(spellName)
    if not spell then return end
    spell.macroLines = lines or {}
end

local function CopyArray(src)
    local out = {}
    for i, v in ipairs(src or {}) do out[i] = v end
    return out
end

local function TextToLines(text)
    local lines = {}
    for line in string.gmatch((text or "") .. "\n", "(.-)\n") do
        line = Trim(line)
        if line ~= "" then lines[#lines + 1] = line end
    end
    return lines
end

local function BuildStoredMacroBody(spell)
    if not spell then return "" end
    local lines = {}
    if spell.macroLines and #spell.macroLines > 0 then
        for _, line in ipairs(spell.macroLines) do
            line = Trim(line)
            if line ~= "" and not line:match("^/omsp%s+id%s+") then
                lines[#lines + 1] = line
            end
        end
    end
    if spell.variants and #spell.variants > 0 then
        local ch = (spell.channel or "EMOTE"):lower()
        if ch == "emote" then ch = "e" end
        for _, g in ipairs(spell.variants) do
            local groupName = VariantGroupName(g)
            if groupName ~= "" then
                lines[#lines + 1] = "/omsp " .. ch .. " " .. groupName
            end
        end
    end
    if #lines > 0 then return table.concat(lines, "\n") end
    return "/omsp cast " .. (spell.name or "")
end

function OS.EnsureSpellMacroID(spellName)
    local spell, realName = OS.GetSpell(spellName)
    if not spell then return nil end
    if spell.macroID and spell.macroID ~= "" then
        OmegaSpellDB.macroIDs[spell.macroID] = realName
        return spell.macroID
    end
    local id = GenerateMacroID()
    spell.macroID = id
    OmegaSpellDB.macroIDs[id] = realName
    return id
end

function OS.SaveAddonMacro(spellName)
    local spell, realName = OS.GetSpell(spellName)
    if not spell then return false, "Sort introuvable." end
    local id = OS.EnsureSpellMacroID(realName)
    local stored = BuildStoredMacroBody(spell)
    spell.macroStored = stored
    OmegaSpellDB.macros[id] = {
        macroID     = id,
        name        = realName,
        spellName   = realName,
        category    = spell.category or "",
        icon        = spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        channel     = spell.channel or "EMOTE",
        source      = spell.source,
        macroName   = spell.macroName or realName:sub(1, 16),
        macroLines  = CopyArray(spell.macroLines),
        macroStored = stored,
        variants    = CopyArray(spell.variants),
        arcaneum    = type(spell.arcaneum) == "table" and {
            profile = spell.arcaneum.profile,
            commID  = spell.arcaneum.commID,
            vault   = spell.arcaneum.vault,
        } or nil,
    }
    OmegaSpellDB.macroIDs[id] = realName
    return true, id
end

function OS.RestoreSpellFromMacroID(macroID)
    OS.DB_Init()
    local record = OmegaSpellDB.macros and OmegaSpellDB.macros[macroID]
    if not record then return false, "Macro Omega introuvable." end

    local name = Trim(record.spellName or record.name or "")
    if name == "" then name = tostring(macroID or "Macro Omega") end

    local spell = OS.GetSpell(name)
    if not spell then
        OmegaSpellDB.spells[name] = {
            name     = name,
            category = record.category or "",
            icon     = record.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
            channel  = record.channel or "EMOTE",
            variants = CopyArray(record.variants),
            macroName = record.macroName or name:sub(1, 16),
            macroLines = CopyArray(record.macroLines),
            macroID = macroID,
            macroCreatedName = nil,
            macroStored = record.macroStored or "",
            source = record.source,
            arcID = "",
            description = "",
            cooldown = 0,
            arcaneum = type(record.arcaneum) == "table" and {
                profile = record.arcaneum.profile,
                commID  = record.arcaneum.commID,
                vault   = record.arcaneum.vault,
            } or nil,
        }
        spell = OmegaSpellDB.spells[name]
    end

    spell.macroID = macroID
    spell.macroStored = record.macroStored or spell.macroStored
    spell.macroName = record.macroName or spell.macroName or name:sub(1, 16)
    spell.category = record.category or spell.category or ""
    spell.icon = record.icon or spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    spell.channel = record.channel or spell.channel or "EMOTE"
    spell.source = record.source or spell.source
    spell.variants = CopyArray(record.variants)
    spell.macroLines = CopyArray(record.macroLines)
    if (#(spell.macroLines or {}) == 0) and record.macroStored and record.macroStored ~= "" then
        spell.macroLines = TextToLines(record.macroStored)
    end
    if type(record.arcaneum) == "table" then
        spell.arcaneum = {
            profile = record.arcaneum.profile,
            commID  = record.arcaneum.commID,
            vault   = record.arcaneum.vault,
        }
    end
    OmegaSpellDB.macroIDs[macroID] = name
    return true, name
end

function OS.BuildMacroText(spell)
    if not spell then return "" end
    if spell.macroID and spell.macroID ~= "" then
        return "/omsp id " .. spell.macroID
    end
    if spell.macroLines and #spell.macroLines > 0 then
        return table.concat(spell.macroLines, "\n")
    end
    if spell.variants and #spell.variants > 0 then
        local ch = (spell.channel or "EMOTE"):lower()
        if ch == "emote" then ch = "e" end
        local lines = {}
        for _, g in ipairs(spell.variants) do
            lines[#lines + 1] = "/omsp " .. ch .. " " .. VariantGroupName(g)
        end
        return table.concat(lines, "\n")
    end
    return "/omsp cast " .. (spell.name or "")
end

-- Liste triée de toutes les macros ayant un macroID (pour MacroLibrary)
function OS.GetSortedMacroRecords()
    local records = {}
    for id, record in pairs(OmegaSpellDB.macros or {}) do
        records[#records + 1] = {
            id        = id,
            name      = record.name or record.spellName or id,
            spellName = record.spellName or record.name or "",
            macroName = record.macroName or "",
            category  = record.category or "",
            icon      = record.icon,
            orphaned  = OS.GetSpell(record.spellName or record.name or "") == nil,
            record    = record,
        }
    end
    for name, spell in pairs(OmegaSpellDB.spells) do
        if spell.macroID and spell.macroID ~= "" and not (OmegaSpellDB.macros and OmegaSpellDB.macros[spell.macroID]) then
            records[#records + 1] = {
                id        = spell.macroID,
                name      = name,
                spellName = name,
                macroName = spell.macroName or "",
                category  = spell.category or "",
                icon      = spell.icon,
            }
        end
    end
    table.sort(records, function(a, b) return a.name < b.name end)
    return records
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GROUPES D'ÉMOTES (bibliothèque)
-- ═══════════════════════════════════════════════════════════════════════════

-- Retourne la table complète (pour EmoteLibrary)
function OS.GetEmoteGroups()
    return OmegaSpellDB.emoteGroups
end

function OS.GetEmoteGroup(name)
    name = VariantGroupName(name)
    if name == "" then return nil end
    for k, v in pairs(OmegaSpellDB.emoteGroups) do
        if k:lower() == name:lower() then return v, k end
    end
end

function OS.GetSortedEmoteGroupNames()
    local names = {}
    for k in pairs(OmegaSpellDB.emoteGroups) do names[#names + 1] = k end
    table.sort(names)
    return names
end

-- Alias /omsp [canal] [groupe]
function OS.GetGroup(name)      return OS.GetEmoteGroup(name) end
function OS.GetSortedGroupNames() return OS.GetSortedEmoteGroupNames() end

function OS.AddEmoteGroup(name)
    name = Trim(name)
    if name == "" then return false, "Nom vide." end
    if OmegaSpellDB.emoteGroups[name] then return false, "Groupe déjà existant." end
    OmegaSpellDB.emoteGroups[name] = {}
    return true
end

function OS.DeleteEmoteGroup(name)
    OmegaSpellDB.emoteGroups[name] = nil
    -- Nettoyage des variants orphelins
    for _, spell in pairs(OmegaSpellDB.spells) do
        local v = spell.variants or {}
        for i = #v, 1, -1 do
            if v[i] == name then table.remove(v, i) end
        end
    end
end

function OS.AddEmotePhrase(groupName, text)
    text = Trim(text)
    if text == "" then return false, "Texte vide." end
    local group = OmegaSpellDB.emoteGroups[groupName]
    if not group then return false, "Groupe introuvable." end
    table.insert(group, text)
    return true
end

function OS.DeleteEmotePhrase(groupName, index)
    local group = OmegaSpellDB.emoteGroups[groupName]
    if group then table.remove(group, index) end
end

-- Alias anciens noms (Core + ancienne UI)
function OS.AddPhrase(groupName, text)   return OS.AddEmotePhrase(groupName, text) end
function OS.DeletePhrase(groupName, idx) return OS.DeleteEmotePhrase(groupName, idx) end

-- ═══════════════════════════════════════════════════════════════════════════
-- BARRES D'ACTION
-- ═══════════════════════════════════════════════════════════════════════════

function OS.GetBar(barIndex)
    if not OmegaSpellDB.bars[barIndex] then
        OmegaSpellDB.bars[barIndex] = NewBarCfg(barIndex)
    end
    return OmegaSpellDB.bars[barIndex]
end

function OS.GetBars()
    return OmegaSpellDB.bars
end

function OS.CreateBar()
    local index = #OmegaSpellDB.bars + 1
    OmegaSpellDB.bars[index] = NewBarCfg(index)
    return true, index
end

function OS.SetBarName(barIndex, name)
    name = Trim(name)
    if name == "" then return false, "Nom vide." end
    name = name:sub(1, 32)
    local cfg = OS.GetBar(barIndex)
    cfg.name = name
    return true, name
end

function OS.GetBarSlot(slotIndex, barIndex)
    local cfg = OS.GetBar(barIndex or 1)
    return cfg.slots[slotIndex]
end

function OS.SetBarSlot(slotIndex, macroID, barIndex)
    local cfg = OS.GetBar(barIndex or 1)
    cfg.slots[slotIndex] = (macroID and macroID ~= "") and macroID or nil
end

function OS.ClearBarSlot(slotIndex, barIndex)
    local cfg = OS.GetBar(barIndex or 1)
    cfg.slots[slotIndex] = nil
end

function OS.AssignMacroToBar(macroID, barIndex)
    barIndex = barIndex or 1
    local cfg = OS.GetBar(barIndex)
    -- Cherche le premier slot libre
    for i = 1, 64 do
        if not cfg.slots[i] then
            cfg.slots[i] = macroID
            return true, i, barIndex
        end
    end
    return false, "Barre pleine."
end

-- Alias legacy (Bar.lua utilise GetBarSlots pour rien de critique)
function OS.GetBarSlots()    return (OmegaSpellDB.bars[1] or {}).slots or {} end
function OS.GetBarSlotCount() return 1000 end
