-- OmegaSpell - Arcaneum.lua
-- Lien de lecture vers Arcanum / SpellCreator.

OmegaSpell = OmegaSpell or {}
OmegaSpell.Arcaneum = OmegaSpell.Arcaneum or {}

local OS  = OmegaSpell
local Arc = OmegaSpell.Arcaneum

local DEFAULT_PROFILE = "Sans profil"

local function Trim(text)
    return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

local function EscapeLuaString(text)
    return tostring(text or ""):gsub("\\", "\\\\"):gsub("\"", "\\\"")
end

local function GetVault()
    if type(SpellCreatorSavedSpells) == "table" then
        return SpellCreatorSavedSpells
    end
    return nil
end

local function SpellProfile(spell)
    local profile = type(spell) == "table" and Trim(spell.profile) or ""
    if profile == "" then return DEFAULT_PROFILE end
    return profile
end

local function SpellName(spell, commID)
    if type(spell) ~= "table" then return tostring(commID or "Sort Arcaneum") end
    local name = Trim(spell.fullName or spell.name or spell.commID or commID)
    if name == "" then return "Sort Arcaneum" end
    return name
end

local function UniqueSpellName(baseName)
    local name = Trim(baseName)
    if name == "" then name = "Sort Arcaneum" end
    if not OS.GetSpell(name) then return name end

    local i = 2
    while OS.GetSpell(name .. " " .. i) do
        i = i + 1
    end
    return name .. " " .. i
end

function Arc.IsAvailable()
    return GetVault() ~= nil
end

function Arc.GetSelectedProfile()
    OS.DB_Init()
    return OmegaSpellDB.arcaneumProfile
end

function Arc.SetSelectedProfile(profileName)
    OS.DB_Init()
    OmegaSpellDB.arcaneumProfile = Trim(profileName)
end

function Arc.GetProfileNames()
    local vault = GetVault()
    local names = {}
    local found = {}
    if not vault then return names end

    for _, spell in pairs(vault) do
        local profile = SpellProfile(spell)
        if not found[profile] then
            names[#names + 1] = profile
            found[profile] = true
        end
    end

    table.sort(names)
    return names
end

function Arc.GetSpells(profileName)
    local vault = GetVault()
    local spells = {}
    if not vault then return spells end

    profileName = Trim(profileName)
    for key, spell in pairs(vault) do
        local commID = Trim(type(spell) == "table" and (spell.commID or key) or key)
        local profile = SpellProfile(spell)
        if commID ~= "" and (profileName == "" or profile == profileName) then
            spells[#spells + 1] = {
                commID      = commID,
                vault       = "personal",
                profile     = profile,
                name        = SpellName(spell, commID),
                icon        = type(spell) == "table" and spell.icon or nil,
                description = type(spell) == "table" and spell.description or nil,
                spell       = spell,
            }
        end
    end

    table.sort(spells, function(a, b)
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    return spells
end

function Arc.BuildMacroLine(commID, vault)
    commID = Trim(commID)
    if commID == "" then return "" end
    if vault == "phase" then
        return "/run ARC.PHASE:CAST(\"" .. EscapeLuaString(commID) .. "\")"
    end
    return "/run ARC:CAST(\"" .. EscapeLuaString(commID) .. "\")"
end

local function HasArcSpell(commID, isPhase)
    if type(ARC) == "table" and type(ARC.XAPI) == "table" and type(ARC.XAPI.GetArcSpell) == "function" then
        return ARC.XAPI:GetArcSpell(commID, isPhase) ~= nil
    end

    if not isPhase and type(SpellCreatorSavedSpells) == "table" then
        return SpellCreatorSavedSpells[commID] ~= nil
    end

    return false
end

function Arc.Cast(commID, vault)
    commID = Trim(commID)
    if commID == "" then return false, "Sort Arcaneum introuvable." end
    if type(ARC) ~= "table" then
        return false, "Arcaneum n'est pas charge."
    end

    if vault == "phase" then
        if not HasArcSpell(commID, true) then
            return false, "Sort Arcaneum absent du coffre de phase: " .. commID
        end
        if type(ARC.PHASE) == "table" and type(ARC.PHASE.CAST) == "function" then
            ARC.PHASE:CAST(commID, true)
            return true
        end
        if type(ARC.CASTP) == "function" then
            ARC:CASTP(commID, true)
            return true
        end
        return false, "Arcaneum phase indisponible."
    end

    if HasArcSpell(commID, false) and type(ARC.CAST) == "function" then
        return ARC:CAST(commID) ~= false
    end

    if HasArcSpell(commID, true) and type(ARC.PHASE) == "table" and type(ARC.PHASE.CAST) == "function" then
        ARC.PHASE:CAST(commID, true)
        return true
    end

    if HasArcSpell(commID, true) and type(ARC.CASTP) == "function" then
        ARC:CASTP(commID, true)
        return true
    end

    return false, "Sort Arcaneum introuvable."
end

function Arc.CreateOmegaSpell(entry)
    if type(entry) ~= "table" or Trim(entry.commID) == "" then
        return false, "Sort Arcaneum invalide."
    end

    local name = UniqueSpellName(entry.name)
    local ok, err = OS.AddSpell(name)
    if not ok then return false, err end

    local spell = OS.GetSpell(name)
    if not spell then return false, "Import incomplet." end

    spell.category = "Arcaneum"
    spell.icon = entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    spell.channel = "EMOTE"
    spell.macroLines = { Arc.BuildMacroLine(entry.commID, entry.vault) }
    spell.arcaneum = {
        profile = entry.profile,
        commID  = entry.commID,
        vault   = entry.vault or "personal",
    }

    return true, name
end
