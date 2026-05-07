OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

local types = {
    lanterne = {
        key = "lanterne",
        categoryLabel = "Lanterne",
        pluralLabel = "Lanternes",
        createTitle = "Nouvelle lanterne",
        editTitle = "Modifier la lanterne",
        valueMode = "multiplier",
        valueLabel = "Multiplicateur de temps",
        coreList = "Models",
    },
    cristal = {
        key = "cristal",
        categoryLabel = "Réactif",
        pluralLabel = "Réactifs",
        createTitle = "Nouveau réactif",
        editTitle = "Modifier le réactif",
        valueMode = "duration",
        valueLabel = "Durée d'activation (minutes)",
        coreList = "Crystals",
    },
    torche = {
        key = "torche",
        categoryLabel = "Torche",
        pluralLabel = "Torches",
        createTitle = "Nouvelle torche",
        editTitle = "Modifier la torche",
        valueMode = "multiplier",
        valueLabel = "Multiplicateur de temps",
        coreList = "TorchModels",
    },
    combustible = {
        key = "combustible",
        categoryLabel = "Combustible",
        pluralLabel = "Combustibles",
        createTitle = "Nouveau combustible",
        editTitle = "Modifier le combustible",
        valueMode = "duration",
        valueLabel = "Durée d'activation (minutes)",
        coreList = "TorchFuels",
    },
    lanternModule = {
        key = "lanternModule",
        categoryLabel = "Module",
        pluralLabel = "Modules",
        createTitle = "Nouveau module",
        editTitle = "Modifier le module",
        valueMode = nil,
        valueLabel = nil,
        coreList = "Modules",
    },
}

local pairedTabs = {
    lanterne = {
        tabKey = "lanterne",
        columns = {
            { type = "lanterne", label = "Lanternes" },
            { type = "cristal", label = "Réactifs" },
        },
    },
    torche = {
        tabKey = "torche",
        columns = {
            { type = "torche", label = "Torches" },
            { type = "combustible", label = "Combustibles" },
        },
    },
}

local auraConditions = {
    { value = "ACTIVATE", label = "Si le joueur active l'élément" },
    { value = "DEACTIVATE", label = "Si le joueur désactive l'élément" },
    { value = "RESOURCE_EMPTY", label = "Si l'élément n'a plus de ressource" },
    { value = "DISABLE_PHRASE", label = "Si une phrase de désactivation est reçue" },
    { value = "ENABLE_PHRASE", label = "Si une phrase d'activation est reçue" },
}

local disablePhraseEffects = {
    { value = "PAUSE", label = "Pause uniquement" },
    { value = "PAUSE_FORCE_OFF", label = "Pause + forcer OFF" },
}

local Schema = {}
Schema.types = types
Schema.pairedTabs = pairedTabs
Schema.auraConditions = auraConditions
Schema.disablePhraseEffects = disablePhraseEffects

function Schema.GetType(itemType)
    return types[itemType]
end

function Schema.UsesMultiplier(itemType)
    local item = types[itemType]
    return item and item.valueMode == "multiplier" or false
end

function Schema.UsesDuration(itemType)
    local item = types[itemType]
    return item and item.valueMode == "duration" or false
end

function Schema.UsesTimedControls(itemType)
    local item = types[itemType]
    return item and item.valueMode ~= nil or false
end

function Schema.GetValueLabel(itemType)
    local item = types[itemType]
    return item and item.valueLabel or nil
end

function Schema.GetCreateTitle(itemType)
    local item = types[itemType]
    return item and item.createTitle or nil
end

function Schema.GetEditTitle(itemType)
    local item = types[itemType]
    return item and item.editTitle or nil
end

function Schema.GetCategoryLabel(itemType)
    local item = types[itemType]
    return item and item.categoryLabel or nil
end

function Schema.GetPluralLabel(itemType)
    local item = types[itemType]
    return item and item.pluralLabel or nil
end

function Schema.GetCoreListKey(itemType)
    local item = types[itemType]
    return item and item.coreList or nil
end

function Schema.GetAuraConditions(itemType)
    local item = types[itemType]
    if item and item.valueMode ~= nil then
        return auraConditions
    end
    return auraConditions
end

function Schema.GetDisablePhraseEffects()
    return disablePhraseEffects
end

OS2.DB.Schema = Schema
