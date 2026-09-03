-- ============================================================
--  Omega Hub — Core
--  Pré-enregistrement des modules + commandes slash
-- ============================================================

OmegaHub = OmegaHub or {}
local Hub = OmegaHub

Hub.pendingReload = false
Hub._startingUp   = true 

-- ── Print helper ───────────────────────────────────────────────────────────

function Hub.Print(msg)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFFCC00[Omega Hub]|r " .. (msg or ""))
    else
        print("|cffFFCC00[Omega Hub]|r " .. (msg or ""))
    end
end

-- ── Pré-enregistrement des modules ─────────────────────────────────────────
-- Juste de quoi peupler la liste du panneau (nom/titre/description) avant
-- même que chaque module ait fini de charger. PAS de "version" ici : chaque
-- module a son propre Modules\<X>\Version.lua (une constante style
-- FOO_VERSION, chargée en tout premier dans son bloc du .toc) et se
-- l'attribue lui-même au moment de son VRAI enregistrement (voir la fin de
-- son Core.lua/Launcher.lua, à l'événement PLAYER_LOGIN) — RegisterModule
-- fusionne les champs, donc ce second appel écrase proprement celui-ci.
-- Versionner chaque module séparément évite qu'un changement dans l'un
-- (ex. Character) ne fasse gonfler le numéro de tous les autres.

Hub:RegisterModule({
    name    = "Omega_Dice",
    title   = "Omega Dice",
    desc    = "Lanceur de dés pour le JDR",
})

Hub:RegisterModule({
    name    = "Omega_Speak",
    title   = "Omega Speak",
    desc    = "Assistant de discours PNJ",
})

Hub:RegisterModule({
    name    = "Omega_Spell",
    title   = "Omega Spell",
    desc    = "Tables d'émotes pour SpellCreator",
})

Hub:RegisterModule({
    name    = "Omega_Survive",
    title   = "Omega Survive",
    desc    = "Système de survie RP",
})

Hub:RegisterModule({
    name    = "Character",
    title   = "Character",
    desc    = "Fiches de personnage RP (HP / Mana / Endurance)",
})

Hub:RegisterModule({
    name    = "Tech",
    title   = "Omega Tech",
    desc    = "Tablette RP : notes, inventaire, store et communications",
})

Hub:RegisterModule({
    name    = "ItemCreator",
    title   = "Item Creator",
    desc    = "Créateur d'items RP avec calcul de points et paliers de qualité",
})

Hub:RegisterModule({
    name    = "ZoneGate",
    title   = "Zone Gate",
    desc    = "Bannières d'entrée/sortie de zone (checkpoints RP)",
})

-- Omega_Weather est commenté dans le TOC (usage privé, non chargé)
-- Hub:RegisterModule({ name = "Omega_Weather", ... })

-- ── Enable / Disable (DB, pas l'API WoW) ──────────────────────────────────

function Hub:EnableAddon(name)
    self:SetModuleEnabled(name, true)
    -- Reload seulement si le module ne gère pas Enable/Disable lui-même
    local mod = self.modules[name]
    if not (mod and mod.module) then
        self.pendingReload = true
    end
end

function Hub:DisableAddon(name)
    self:SetModuleEnabled(name, false)
    local mod = self.modules[name]
    if not (mod and mod.module) then
        self.pendingReload = true
    end
end

-- ── Commandes slash ────────────────────────────────────────────────────────

SLASH_OMEGAHUB1 = "/omh"
SLASH_OMEGAHUB2 = "/omhub"
SLASH_OMEGAHUB3 = "/omegahub"
SlashCmdList["OMEGAHUB"] = function()
    OmegaHubPanel:Toggle()
end

-- ── Message de démarrage ───────────────────────────────────────────────────

local startupFrame = CreateFrame("Frame")
startupFrame:RegisterEvent("PLAYER_LOGIN")
startupFrame:SetScript("OnEvent", function()
    -- Différé d'une frame : tous les handlers PLAYER_LOGIN des modules ont déjà tourné
    C_Timer.After(0, function()
        Hub._startingUp = false

        local allOk = true
        for _, addonData in ipairs(Hub:GetModules(false)) do
            local loaded, enabled = Hub:GetModuleStatus(addonData.name)
            if enabled and not loaded then
                allOk = false
            end
        end

        if allOk then
            Hub.Print("|cff33ff33Tous les modules sont opérationnels.|r")
        end
    end)
    startupFrame:UnregisterAllEvents()
end)

-- ── Init SavedVariables ────────────────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(_, _, addonName)
    if addonName == "Omega_Hub" then
        OmegaHubDB     = OmegaHubDB     or { showHidden = false, modules = {} }
        OmegaHubDB.modules = OmegaHubDB.modules or {}
        ItemCreatorDB  = ItemCreatorDB  or {}
        ZoneGateDB     = ZoneGateDB     or {}
        initFrame:UnregisterAllEvents()
    end
end)
