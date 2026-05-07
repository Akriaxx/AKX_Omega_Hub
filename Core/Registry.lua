-- ============================================================
--  Omega Hub — Registry
--  Registre central des modules + gestion de leur état
--  (chargé / activé) sans dépendre de l'API WoW EnableAddOn.
-- ============================================================

OmegaHub = OmegaHub or {}
local Hub = OmegaHub

Hub.modules     = {}   -- { [name] = moduleData }
Hub.moduleOrder = {}   -- ordre d'affichage
Hub.moduleState = {}   -- { [name] = { loaded = bool } }  (runtime uniquement)

-- ── Enregistrement ─────────────────────────────────────────────────────────

--- Enregistre (ou met à jour) un module.
-- data = { name, title, desc, version, [hidden] }
function Hub:RegisterModule(data)
    if type(data) ~= "table" or not data.name then return end

    if self.modules[data.name] then
        for k, v in pairs(data) do self.modules[data.name][k] = v end
    else
        self.modules[data.name] = data
        table.insert(self.moduleOrder, data.name)
    end

    -- Initialise l'entrée d'état runtime si absente
    self.moduleState[data.name] = self.moduleState[data.name] or { loaded = false }
end

-- ── Requêtes ───────────────────────────────────────────────────────────────

--- Liste ordonnée pour l'affichage.
function Hub:GetModules(includeHidden)
    local list = {}
    for _, name in ipairs(self.moduleOrder) do
        local mod = self.modules[name]
        if mod and (includeHidden or not mod.hidden) then
            table.insert(list, mod)
        end
    end
    return list
end

function Hub:HasModule(name)
    return self.modules[name] ~= nil
end

-- ── État d'activation (persisté dans OmegaHubDB) ──────────────────────────

--- Retourne true si le module doit s'initialiser.
--- Par défaut (pas encore dans la DB) : désactivé.
function Hub:IsModuleEnabled(name)
    if not OmegaHubDB or not OmegaHubDB.modules then return false end
    local entry = OmegaHubDB.modules[name]
    if entry == nil then return false end
    return entry.enabled == true
end

function Hub:SetModuleEnabled(name, enabled)
    OmegaHubDB.modules         = OmegaHubDB.modules or {}
    OmegaHubDB.modules[name]   = OmegaHubDB.modules[name] or {}
    OmegaHubDB.modules[name].enabled = enabled
end

-- ── État de chargement (runtime) ───────────────────────────────────────────

--- Appelé par chaque module une fois qu'il a fini de s'initialiser.
function Hub:SetModuleLoaded(name, loaded)
    if not self.moduleState[name] then self.moduleState[name] = {} end
    self.moduleState[name].loaded = loaded and true or false
end

--- Retourne : loaded (bool), enabled (bool)
function Hub:GetModuleStatus(name)
    local loaded  = self.moduleState[name] and self.moduleState[name].loaded or false
    local enabled = self:IsModuleEnabled(name)
    return loaded, enabled
end
