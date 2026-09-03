-- ============================================================
--  Item Creator — Core
--  Logique métier, DB, Enable/Disable
-- ============================================================

local IC = ItemCreator

-- ── Helpers DB ───────────────────────────────────────────────────────────────

-- Retourne les paliers actifs (depuis la DB si customisés, sinon défauts)
function IC:GetTiers()
    ItemCreatorDB = ItemCreatorDB or {}
    ItemCreatorDB.tiers = ItemCreatorDB.tiers or {}
    if #ItemCreatorDB.tiers == 0 then
        -- Copie des défauts
        for _, t in ipairs(IC.DEFAULT_TIERS) do
            table.insert(ItemCreatorDB.tiers, { name = t.name, pts = t.pts, r = t.r, g = t.g, b = t.b })
        end
    end
    return ItemCreatorDB.tiers
end

-- Retourne le coût effectif d'une stat (custom ou défaut)
function IC:GetCost(statId)
    ItemCreatorDB = ItemCreatorDB or {}
    ItemCreatorDB.costs = ItemCreatorDB.costs or {}
    if ItemCreatorDB.costs[statId] ~= nil then
        return ItemCreatorDB.costs[statId]
    end
    local def = IC.STAT_BY_ID[statId]
    return def and def.cost or 1
end

-- Retourne les valeurs de l'item en cours d'édition
function IC:GetCurrentValues()
    ItemCreatorDB = ItemCreatorDB or {}
    ItemCreatorDB.current = ItemCreatorDB.current or {}
    return ItemCreatorDB.current
end

-- Remet toutes les valeurs à zéro
function IC:ResetCurrent()
    ItemCreatorDB = ItemCreatorDB or {}
    ItemCreatorDB.current = {}
    ItemCreatorDB.currentName = ""
    if IC.OnCurrentChanged then IC.OnCurrentChanged() end
end

-- Lit la valeur d'une stat
function IC:GetValue(statId)
    local vals = IC:GetCurrentValues()
    return tonumber(vals[statId]) or 0
end

-- Modifie la valeur d'une stat (clamp si pas allowNeg)
function IC:SetValue(statId, val)
    local def = IC.STAT_BY_ID[statId]
    val = math.floor(tonumber(val) or 0)
    if def and not def.allowNeg then
        val = math.max(0, val)
    end
    local vals = IC:GetCurrentValues()
    vals[statId] = (val ~= 0) and val or nil
    if IC.OnCurrentChanged then IC.OnCurrentChanged() end
end

function IC:IncrementValue(statId, delta)
    IC:SetValue(statId, IC:GetValue(statId) + (delta or 1))
end

-- ── Calcul du total de points ─────────────────────────────────────────────────

-- Retourne le total de points dépensés pour l'item courant
function IC:ComputeTotal()
    local total = 0
    local vals  = IC:GetCurrentValues()
    for statId, val in pairs(vals) do
        local v = tonumber(val) or 0
        if v ~= 0 then
            local cost = IC:GetCost(statId)
            total = total + v * cost
        end
    end
    return total
end

-- Retourne le palier correspondant à un nombre de points dépensés
-- Renvoie nil si aucun palier ne couvre ce total (item trop puissant)
function IC:GetTierForTotal(total)
    local tiers = IC:GetTiers()
    local best  = nil
    for _, t in ipairs(tiers) do
        if total <= t.pts then
            if not best or t.pts < best.pts then
                best = t
            end
        end
    end
    return best
end

-- Retourne le palier maximum (pour l'affichage de la barre)
function IC:GetMaxTier()
    local tiers = IC:GetTiers()
    local max = tiers[1]
    for _, t in ipairs(tiers) do
        if t.pts > max.pts then max = t end
    end
    return max
end

-- ── Enable / Disable ──────────────────────────────────────────────────────────

function IC:Enable()
    SLASH_OITEM1 = "/oitem"
    SLASH_OITEM2 = "/omitem"
    SlashCmdList["OITEM"] = function()
        if ItemCreatorPanel then ItemCreatorPanel:Toggle() end
    end
    OmegaHub:SetModuleLoaded("ItemCreator", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Item Creator activé.  |cffAAAAAA/oitem|r")
    end
end

function IC:Disable()
    SLASH_OITEM1 = nil
    SLASH_OITEM2 = nil
    SlashCmdList["OITEM"] = nil
    if ItemCreatorPanel    then ItemCreatorPanel:Hide()    end
    if ItemBalancePanel    then ItemBalancePanel:Hide()    end
    OmegaHub:SetModuleLoaded("ItemCreator", false)
    OmegaHub.Print("Item Creator désactivé.")
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({ name = "ItemCreator", module = IC, version = ITEM_CREATOR_VERSION })
    ItemCreatorDB = ItemCreatorDB or {}
    -- Activé par défaut si jamais configuré (premier chargement)
    if OmegaHubDB and OmegaHubDB.modules and OmegaHubDB.modules["ItemCreator"] == nil then
        OmegaHub:SetModuleEnabled("ItemCreator", true)
    end
    if OmegaHub:IsModuleEnabled("ItemCreator") then IC:Enable() end
    f:UnregisterAllEvents()
end)
