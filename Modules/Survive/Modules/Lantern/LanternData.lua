-- OmegaSurvive 2.0 -- Donnees Lanterne
OS2 = OS2 or {}
OS2.Core = OS2.Core or {}

OS2.Core.Models = {
    { key = "ASPECTA",   label = "Lanterne d'aspecta",            mult = 1, desc = "" },
    { key = "FREMAS",    label = "Lanterne d'aspecta des Fremas", mult = 2, desc = "" },
    { key = "GENERATOR", label = "Générateur d'aspecta",          mult = 2, desc = "" },
}

OS2.Core.Crystals = {
    { key = "POOR",      label = "Cristaux d'aspecta raffinés de mauvaise facture",  time = 5,   desc = "" },
    { key = "REFINED",   label = "Cristaux d'aspecta raffinés",                      time = 120, desc = "" },
    { key = "EXCELLENT", label = "Cristaux d'aspecta raffinés d'excellente qualité", time = 240, desc = "" },
    { key = "ANCIENT",   label = "Cristaux d'aspecta raffinés d'ancien temps",       time = 600, desc = "" },
}

local function BuildLookup(entries)
    local byKey = {}
    for _, entry in ipairs(entries) do
        byKey[entry.key] = entry
    end
    return byKey
end

OS2.Core.Modules      = {}

OS2.Core.ModelByKey   = BuildLookup(OS2.Core.Models)
OS2.Core.CrystalByKey = BuildLookup(OS2.Core.Crystals)
OS2.Core.ModuleByKey  = {}
