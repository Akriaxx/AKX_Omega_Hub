-- OmegaSurvive 2.0 — Données Torche
OS2 = OS2 or {}
OS2.Core = OS2.Core or {}

OS2.Core.TorchModels = {
    { key = "RUSTIQUE", label = "Torche rustique",    mult = 1, desc = "" },
    { key = "GUERRIER", label = "Torche de guerrier", mult = 2, desc = "" },
    { key = "SACREE",   label = "Torche sacrée",      mult = 3, desc = "" },
}

OS2.Core.TorchFuels = {
    { key = "MECHE_SECHE",     label = "Mèche sèche",       time = 10,  desc = "" },
    { key = "MECHE_IMPREGNEE", label = "Mèche imprégnée",   time = 45,  desc = "" },
    { key = "HUILE_QUALITE",   label = "Huile de qualité",  time = 120, desc = "" },
    { key = "HUILE_BENIE",     label = "Huile bénie",       time = 360, desc = "" },
    { key = "ESSENCE_ETERN",   label = "Essence éternelle", time = 720, desc = "" },
}

local function BuildLookup(entries)
    local byKey = {}
    for _, entry in ipairs(entries) do
        byKey[entry.key] = entry
    end
    return byKey
end

OS2.Core.TorchModelByKey = BuildLookup(OS2.Core.TorchModels)
OS2.Core.TorchFuelByKey  = BuildLookup(OS2.Core.TorchFuels)
