-- OmegaSurvive 2.0 — Gourde (gameplay)
local UI    = OS2.UI or {}
local panel = OS2.panels["gourde"]

local PAD = 14
local IW  = panel:GetWidth() - PAD * 2

-- ── Accès aux définitions faites dans le Builder ───────────────────────
local function GetSystems()
    return (OS2.Core.Systems and OS2.Core.Systems.hydratation) or {}
end

local function FindByKey(list, key)
    for _, entry in ipairs(list or {}) do
        if entry.key == key then return entry end
    end
    return nil
end

local function GetSystem(db)     return FindByKey(GetSystems(), db.systemKey) end
local function GetGourde(system, db) return system and FindByKey(system.gourdes, db.gourdeKey) end
local function GetSource(system, db) return system and FindByKey(system.sources, db.sourceKey) end
local function GetFiltre(system, key) return system and FindByKey(system.filtres, key) end

-- ── Configuration (placeholder, gear du module) ─────────────────────────
local configPanel = OS2.CreateSimpleSettingsPanel(
    "Paramètres Gourde",
    "Les réglages avancés de la gourde seront disponibles prochainement.",
    140,
    panel
)

OS2.BuildModuleShell(panel, {
    title = "Hydratation",
    onSettings = function()
        OS2.ToggleSettingsPanel(configPanel, OS2.Launcher)
    end,
})

-- ── Widgets ──────────────────────────────────────────────────────────────
local y = 52

local lblSystem = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblSystem:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); lblSystem:SetText("Système"); UI.ApplyLabel(lblSystem)
local systemDD = CreateFrame("Frame", "OS2_CanteenSystemDD", panel, "UIDropDownMenuTemplate")
systemDD:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - 16, -(y + 12))
UIDropDownMenu_SetWidth(systemDD, IW - 12)
UI.StyleDropdown(systemDD)
y = y + 44

local lblGourde = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblGourde:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); lblGourde:SetText("Gourde"); UI.ApplyLabel(lblGourde)
local gourdeDD = CreateFrame("Frame", "OS2_CanteenGourdeDD", panel, "UIDropDownMenuTemplate")
gourdeDD:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - 16, -(y + 12))
UIDropDownMenu_SetWidth(gourdeDD, IW - 12)
UI.StyleDropdown(gourdeDD)
y = y + 44

local lblHydra = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblHydra:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); UI.ApplyStrongLabel(lblHydra)
y = y + 16

local hydraBar = CreateFrame("StatusBar", nil, panel)
hydraBar:SetSize(IW, 14)
hydraBar:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
hydraBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
hydraBar:SetStatusBarColor(0.30, 0.55, 0.85, 1)
hydraBar:SetMinMaxValues(0, 1)
local hydraBarBg = hydraBar:CreateTexture(nil, "BACKGROUND"); hydraBarBg:SetAllPoints(); hydraBarBg:SetColorTexture(0.08, 0.08, 0.08, 1)
y = y + 22

do
    local sep = panel:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, -y)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    y = y + 10
end

local lblContenance = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblContenance:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); UI.ApplySoftText(lblContenance)
y = y + 18

local lblQualite = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblQualite:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); UI.ApplySoftText(lblQualite)
y = y + 18

local lblFiltre = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblFiltre:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); UI.ApplyLabel(lblFiltre)
y = y + 16
local filtreBtn = UI.CreatePanelButton(panel, IW, 22, "Changer de filtre")
filtreBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
y = y + 30

do
    local sep = panel:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  panel, "TOPLEFT",  PAD, -y)
    sep:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD, -y)
    y = y + 10
end

local lblSource = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lblSource:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y); lblSource:SetText("Source (pour remplir)"); UI.ApplyLabel(lblSource)
local sourceDD = CreateFrame("Frame", "OS2_CanteenSourceDD", panel, "UIDropDownMenuTemplate")
sourceDD:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD - 16, -(y + 12))
UIDropDownMenu_SetWidth(sourceDD, IW - 12)
UI.StyleDropdown(sourceDD)
y = y + 44

local fillBtn = UI.CreatePanelButton(panel, IW, 22, "Remplir")
fillBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
y = y + 26

local drinkBtn = UI.CreatePanelButton(panel, IW, 22, "Boire")
drinkBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
y = y + 26

local purifyBtn = UI.CreatePanelButton(panel, IW, 22, "Purifier l'eau")
purifyBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -y)
y = y + 30

-- ── Logique ──────────────────────────────────────────────────────────────
local RefreshPanel

local function EnsureValidSelection(db, system)
    if system then
        if not GetGourde(system, db) then
            db.gourdeKey = system.gourdes[1] and system.gourdes[1].key or nil
        end
        if not GetSource(system, db) then
            db.sourceKey = system.sources[1] and system.sources[1].key or nil
        end
    else
        db.gourdeKey = nil
        db.sourceKey = nil
    end
end

RefreshPanel = function()
    local db     = OS2.GetHydrationDB()
    local system = GetSystem(db)
    EnsureValidSelection(db, system)
    local gourde = GetGourde(system, db)
    local source = GetSource(system, db)
    if gourde and not db.filtreKey and gourde.filtreEquipe then
        db.filtreKey = gourde.filtreEquipe
    end

    UIDropDownMenu_SetText(systemDD, system and system.label or "Aucun système")
    UIDropDownMenu_SetText(gourdeDD, gourde and gourde.label or "Aucune gourde")
    UIDropDownMenu_SetText(sourceDD, source and source.label or "Aucune source")

    local capacite = 0
    if system then
        local evalResult = OS2.DB.EvaluateHydrationSystem(system.key)
        capacite = (evalResult and evalResult.capacite) or 0
    end
    local hydra = math.min(capacite, db.hydratation or 0)
    hydraBar:SetMinMaxValues(0, math.max(1, capacite))
    hydraBar:SetValue(hydra)
    lblHydra:SetText(string.format("Hydratation : %d / %d", math.floor(hydra), math.floor(capacite)))

    local maxContenance = gourde and (tonumber(gourde.contenance) or 0) or 0
    local amount = (db.eau and db.eau.amount) or 0
    lblContenance:SetText(string.format("Contenance : %d / %d mL", amount, maxContenance))

    if not db.eau then
        lblQualite:SetText("Eau : gourde vide")
    else
        local src = system and FindByKey(system.sources, db.eau.sourceKey)
        local propre = src and (src.proprete or 100) >= 50
        lblQualite:SetText("Eau : " .. (propre and "propre" or "sale"))
    end

    local acceptsFiltre = gourde and gourde.filtreActif
    lblFiltre:SetShown(acceptsFiltre and true or false)
    filtreBtn:SetShown(acceptsFiltre and true or false)
    if acceptsFiltre then
        local filtre = GetFiltre(system, db.filtreKey)
        lblFiltre:SetText("Filtre : " .. (filtre and filtre.label or "Aucun"))
        local canChange = gourde.filtreModifiable
        filtreBtn:SetEnabled(canChange and true or false)
    end

    fillBtn:SetEnabled((system and gourde and source) and true or false)
    drinkBtn:SetEnabled((db.eau and (db.eau.amount or 0) > 0) and true or false)
    -- TEMPORAIRE : reste cliquable sans gourde/eau pour tester la détection
    -- du feu de camp. Remettre "(db.eau and not db.eau.purified)" une fois
    -- qu'un système/gourde de test existe.
    purifyBtn:SetEnabled(not (db.eau and db.eau.purified))

    OS2.SetPanelAutoHeight(panel, y, 18, 170)
end

UIDropDownMenu_Initialize(systemDD, function(self, level)
    local db = OS2.GetHydrationDB()
    for _, system in ipairs(GetSystems()) do
        local info = UIDropDownMenu_CreateInfo()
        local isSel = (db.systemKey == system.key)
        info.text = isSel and ("|cffd7b35f>  " .. system.label .. "|r") or ("    " .. system.label)
        info.notCheckable = true
        info.func = function()
            db.systemKey = system.key
            db.gourdeKey, db.sourceKey, db.filtreKey, db.eau = nil, nil, nil, nil
            RefreshPanel()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_Initialize(gourdeDD, function(self, level)
    local db = OS2.GetHydrationDB()
    local system = GetSystem(db)
    for _, gourde in ipairs(system and system.gourdes or {}) do
        local info = UIDropDownMenu_CreateInfo()
        local isSel = (db.gourdeKey == gourde.key)
        info.text = isSel and ("|cffd7b35f>  " .. gourde.label .. "|r") or ("    " .. gourde.label)
        info.notCheckable = true
        info.func = function()
            db.gourdeKey = gourde.key
            db.filtreKey, db.eau = nil, nil
            RefreshPanel()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

UIDropDownMenu_Initialize(sourceDD, function(self, level)
    local db = OS2.GetHydrationDB()
    local system = GetSystem(db)
    for _, source in ipairs(system and system.sources or {}) do
        local info = UIDropDownMenu_CreateInfo()
        local isSel = (db.sourceKey == source.key)
        info.text = isSel and ("|cffd7b35f>  " .. source.label .. "|r") or ("    " .. source.label)
        info.notCheckable = true
        info.func = function()
            db.sourceKey = source.key
            RefreshPanel()
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

-- Menu contextuel dédié au bouton "Changer de filtre" (compatibles uniquement)
local filtreMenu = CreateFrame("Frame", "OS2_CanteenFiltreMenu", panel, "UIDropDownMenuTemplate")
filtreMenu:Hide()
UIDropDownMenu_Initialize(filtreMenu, function(self, level)
    local db = OS2.GetHydrationDB()
    local system = GetSystem(db)
    local gourde = GetGourde(system, db)
    if not (system and gourde) then return end

    local infoNone = UIDropDownMenu_CreateInfo()
    infoNone.text = (db.filtreKey == nil) and "|cffd7b35f>  Aucun|r" or "    Aucun"
    infoNone.notCheckable = true
    infoNone.func = function() db.filtreKey = nil; RefreshPanel() end
    UIDropDownMenu_AddButton(infoNone, level)

    for _, key in ipairs(gourde.filtresCompatibles or {}) do
        local filtre = GetFiltre(system, key)
        if filtre then
            local info = UIDropDownMenu_CreateInfo()
            local isSel = (db.filtreKey == filtre.key)
            info.text = isSel and ("|cffd7b35f>  " .. filtre.label .. "|r") or ("    " .. filtre.label)
            info.notCheckable = true
            info.func = function() db.filtreKey = filtre.key; RefreshPanel() end
            UIDropDownMenu_AddButton(info, level)
        end
    end
end, "MENU")

filtreBtn:SetScript("OnClick", function()
    ToggleDropDownMenu(1, nil, filtreMenu, filtreBtn, 0, 0)
end)

fillBtn:SetScript("OnClick", function()
    local db = OS2.GetHydrationDB()
    local system = GetSystem(db)
    local gourde = GetGourde(system, db)
    local source = GetSource(system, db)
    if not (system and gourde and source) then return end

    local filtre = gourde.filtreActif and GetFiltre(system, db.filtreKey)
    local filteredEtats = {}
    if filtre then
        for _, k in ipairs(filtre.etatsFiltres or {}) do filteredEtats[k] = true end
    end

    db.eau = {
        sourceKey     = source.key,
        etats         = { unpack(source.etats or {}) },
        filteredEtats = filteredEtats,
        purified      = false,
        amount        = tonumber(gourde.contenance) or 0,
    }
    OS2.Notify("Gourde remplie avec : " .. source.label, 0.6, 0.9, 0.5)
    RefreshPanel()
end)

drinkBtn:SetScript("OnClick", function()
    local db = OS2.GetHydrationDB()
    local system = GetSystem(db)
    local gourde = GetGourde(system, db)
    if not (system and gourde and db.eau) or (db.eau.amount or 0) <= 0 then return end

    local fonct  = system.fonctionnement or {}
    local gorgee = fonct.gorgee or {}
    local ml     = gorgee.ml or 0
    local points = gorgee.points or 0

    db.eau.amount = math.max(0, (db.eau.amount or 0) - ml)

    local evalResult = OS2.DB.EvaluateHydrationSystem(system.key)
    local capacite    = (evalResult and evalResult.capacite) or 0
    db.hydratation     = math.min(capacite, (db.hydratation or 0) + points)

    for _, etatKey in ipairs(db.eau.etats or {}) do
        local neutralized = db.eau.purified or db.eau.filteredEtats[etatKey]
        if not neutralized then
            OS2.DB.ApplyEtatToPlayer(system.key, etatKey)
        end
    end

    if db.eau.amount <= 0 then
        db.eau = nil
    end

    RefreshPanel()
end)

-- ── Vérification « feu de camp à proximité » (GameObject en jeu) ────────
-- Aucune aura n'est posée par défaut ; on utilise la commande GM
-- ".gob near <rayon> campfire" et on lit la réponse système du serveur :
--   "Found nearby gameobjects with name/id campfire (distance: 3.000000): 0"
-- Opération discrète : un filtre de chat intercepte et masque cette réponse
-- système avant qu'elle ne s'affiche dans la fenêtre de discussion du joueur.
local CAMPFIRE_RADIUS   = 3
local pendingCampfireCB = nil

local function CheckNearbyCampfire(callback)
    if pendingCampfireCB then return end
    pendingCampfireCB = callback
    if not (OS2.ModuleRules and OS2.ModuleRules.ExecuteServerCommand) then
        pendingCampfireCB = nil
        callback(nil)
        return
    end
    OS2.ModuleRules.ExecuteServerCommand(".gob near " .. CAMPFIRE_RADIUS .. " campfire")
    C_Timer.After(2, function()
        if pendingCampfireCB == callback then
            pendingCampfireCB = nil
            callback(nil) -- pas de réponse du serveur dans le délai
        end
    end)
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, message)
    local count = message and message:match("with name/id%s+%S+%s+%(distance:%s*[%d%.]+%):%s*(%d+)")
    if not count then return false end

    if pendingCampfireCB then
        local cb = pendingCampfireCB
        pendingCampfireCB = nil
        cb(tonumber(count))
    end
    return true -- masqué : ne s'affiche pas dans le chat du joueur
end)

purifyBtn:SetScript("OnClick", function()
    local db = OS2.GetHydrationDB()
    if db.eau and db.eau.purified then return end

    purifyBtn:SetEnabled(false)
    OS2.Notify("Recherche d'un feu de camp à proximité...", 0.8, 0.8, 0.8)
    CheckNearbyCampfire(function(count)
        if count and count > 0 then
            if db.eau then db.eau.purified = true end
            OS2.Notify("Feu de camp détecté — l'eau serait purifiée.", 0.6, 0.9, 0.5)
        elseif count == 0 then
            OS2.Notify("Aucun feu de camp à proximité — impossible de purifier l'eau.", 1, 0.5, 0.3)
        else
            OS2.Notify("Impossible de vérifier la présence d'un feu de camp (pas de réponse du serveur).", 1, 0.6, 0.2)
        end
        RefreshPanel()
    end)
end)

-- ── Décroissance périodique de l'hydratation (Vitesse de descente, en points/min) ─
local hydrationTicker = C_Timer.NewTicker(5, function()
    local db = OS2.GetHydrationDB()
    local system = GetSystem(db)
    local now = GetTime()
    if system and db.lastUpdate then
        local elapsedMin = math.max(0, now - db.lastUpdate) / 60
        local evalResult = OS2.DB.EvaluateHydrationSystem(system.key)
        local vitesse = (evalResult and evalResult.vitesse) or 0
        db.hydratation = math.max(0, (db.hydratation or 0) - vitesse * elapsedMin)
    end
    db.lastUpdate = now
    if panel:IsShown() then RefreshPanel() end
end)

panel:HookScript("OnShow", RefreshPanel)
RefreshPanel()
