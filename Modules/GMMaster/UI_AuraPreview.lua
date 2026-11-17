-- ============================================================
--  GM Master — Aperçu des auras
--  Colonne de droite de la banque d'auras : un modèle 3D sur lequel
--  l'aura saisie (ou cliquée dans la liste) se joue aussitôt. Toutes
--  les races jouables, homme ou femme, nues ou habillées : certaines
--  auras ne s'accrochent qu'à certains squelettes.
--
--  Un modèle ne joue pas un sort, seulement des kits visuels
--  (ApplySpellVisualKit). La correspondance sort → kits vient des DB2
--  du client : AuraVisuals.generated.lua (Tools/build-auravisuals.js).
-- ============================================================

local GM = GMMaster
local UI = OS2.UI
local bank = GMMasterAuraBank

local PAD     = 14
local LEFT    = bank.listWidth
local COL_W   = bank.previewWidth
local INNER_W = COL_W - 2 * PAD
local TOP     = -46
local MODEL_TOP, MODEL_BOTTOM = -76, 130
local TYPE_DELAY = 0.35   -- délai après la frappe avant de jouer l'aura

local function After(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end

local function ShowTooltip(owner, lines)
    if not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, line in ipairs(lines) do
        if i == 1 then GameTooltip:SetText(line, 1, 1, 1)
        else GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
    end
    GameTooltip:Show()
end
local function HideTooltip() if GameTooltip then GameTooltip:Hide() end end

-- ── Données : sort → kits ─────────────────────────────────────────────────

local cache = {}

local function KitList(field)
    local list = {}
    for kit in (field or ""):gmatch("%d+") do list[#list + 1] = tonumber(kit) end
    return list
end

--- Kits visuels d'un sort, ou nil s'il n'en a aucun de connu.
--- { loop = { kits en boucle tant que l'aura est là }, once = { à la pose },
---   cast = { canalisation / incantation, en boucle }, impact = { lancer, impact },
---   transform = aura de transformation,
---   animKit, animLoop = AnimKit à lancer (en boucle ou une fois), anim = animation simple,
---   stand = animation qui remplace la pose debout }
--- Le modèle joue les objets et particules d'un kit, mais pas son animation :
--- elle est lancée à part (PlayAnimKit / SetAnimation).
function GM.AuraVisualKits(id)
    id = tonumber(id)
    if not id or id <= 0 or id % 1 ~= 0 then return nil end
    local entry = cache[id]
    if entry == nil then
        entry = false
        local data, key = GM.AuraVisualData or "", "\n" .. string.format("%d", id) .. "="
        local s = data:find(key, 1, true)
        if s then
            local from = s + #key
            local line = data:sub(from, (data:find("\n", from, true) or (#data + 1)) - 1)
            local f = {}
            for part in (line .. "|"):gmatch("(.-)|") do f[#f + 1] = part end
            entry = { loop = KitList(f[1]), once = KitList(f[2]), cast = KitList(f[3]),
                impact = KitList(f[4]), transform = f[5] == "T", stand = tonumber(f[7] or "") }
            local kind, num = (f[6] or ""):match("^([koa])(%d+)$")
            if kind == "a" then entry.anim = tonumber(num)
            elseif kind then entry.animKit, entry.animLoop = tonumber(num), kind == "k" end
        end
        cache[id] = entry
    end
    return entry or nil
end

-- ── Races ─────────────────────────────────────────────────────────────────

-- ID de ChrRaces pour SetCustomRace ; 0 = le personnage tel qu'il est.
GM.PREVIEW_RACES = {
    { id = 0,  name = "Mon personnage" },
    { id = 1,  name = "Humain" },
    { id = 3,  name = "Nain" },
    { id = 4,  name = "Elfe de la nuit" },
    { id = 7,  name = "Gnome" },
    { id = 11, name = "Draeneï" },
    { id = 22, name = "Worgen" },
    { id = 29, name = "Elfe du Vide" },
    { id = 30, name = "Draeneï sancteforge" },
    { id = 34, name = "Nain sombrefer" },
    { id = 32, name = "Kultirassien" },
    { id = 37, name = "Mécagnome" },
    { id = 24, name = "Pandaren" },
    { id = 2,  name = "Orc" },
    { id = 5,  name = "Mort-vivant" },
    { id = 6,  name = "Tauren" },
    { id = 8,  name = "Troll" },
    { id = 10, name = "Elfe de sang" },
    { id = 9,  name = "Gobelin" },
    { id = 27, name = "Sacrenuit" },
    { id = 28, name = "Tauren de Haut-Roc" },
    { id = 36, name = "Orc mag'har" },
    { id = 31, name = "Troll zandalari" },
    { id = 35, name = "Vulpérin" },
}
local RACE_NAME = {}
for _, r in ipairs(GM.PREVIEW_RACES) do RACE_NAME[r.id] = r.name end

local function Settings()
    local db = GM.EnsureDB()
    db.auraPreview = db.auraPreview or {}
    local s = db.auraPreview
    if s.race == nil or not RACE_NAME[s.race] then s.race = 0 end
    if s.sex ~= 0 and s.sex ~= 1 then
        s.sex = (UnitSex and UnitSex("player") == 3) and 1 or 0
    end
    if s.dressed == nil then s.dressed = false end
    return s
end

-- ── Colonne ───────────────────────────────────────────────────────────────

local col = CreateFrame("Frame", nil, bank)
col:SetPoint("TOPLEFT", bank, "TOPLEFT", LEFT, 0)
col:SetPoint("BOTTOMRIGHT", bank, "BOTTOMRIGHT", 0, 0)
bank.previewColumn = col

do
    local vsep = bank:CreateTexture(nil, "ARTWORK")
    vsep:SetPoint("TOPLEFT", bank, "TOPLEFT", LEFT, -40)
    vsep:SetPoint("BOTTOMLEFT", bank, "BOTTOMLEFT", LEFT, 10)
    vsep:SetWidth(1)
    UI.ApplySeparator(vsep, true)
end

local preview = { kits = nil, id = nil, token = 0 }
bank.auraPreview = preview

-- Race (menu déroulant) et sexe
local raceBtn = UI.CreatePanelButton(col, INNER_W - 2 * 56 - 6, 22, "")
raceBtn:SetPoint("TOPLEFT", PAD, TOP)
preview.raceBtn = raceBtn
do
    local arrow = raceBtn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -4, 0)
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    raceBtn:GetFontString():SetPoint("BOTTOMRIGHT", raceBtn, "BOTTOMRIGHT", -20, 1)
    raceBtn:GetFontString():SetJustifyH("LEFT")
end

local function SexButton(label, sex, anchor)
    local b = UI.CreatePanelButton(col, 56, 22, label)
    b:SetPoint("LEFT", anchor, "RIGHT", anchor == raceBtn and 6 or 2, 0)
    b.sex = sex
    return b
end
local maleBtn = SexButton("Homme", 0, raceBtn)
local femaleBtn = SexButton("Femme", 1, maleBtn)
preview.maleBtn, preview.femaleBtn = maleBtn, femaleBtn

local function SetActive(btn, active)
    btn.bgN:SetColorTexture(unpack(active and UI.colors.rowBgSelected or UI.colors.panelButtonBg))
    btn.accent:SetShown(active)
    btn:GetFontString():SetTextColor(unpack(active and UI.colors.title or UI.colors.textSoft))
end

-- Liste des races : deux colonnes sous le bouton.
local RACE_ROW_H, RACE_COL_W = 19, 134
local raceList = CreateFrame("Frame", nil, col, "BackdropTemplate")
raceList:SetFrameStrata("DIALOG")
raceList:SetToplevel(true)
raceList:SetPoint("TOPLEFT", raceBtn, "BOTTOMLEFT", 0, -2)
local perCol = math.ceil(#GM.PREVIEW_RACES / 2)
raceList:SetSize(2 * RACE_COL_W + 12, perCol * RACE_ROW_H + 12)
raceList:EnableMouse(true)
raceList:Hide()
preview.raceList = raceList
do
    local lbg = raceList:CreateTexture(nil, "BACKGROUND")
    lbg:SetAllPoints()
    UI.ApplyWindowBackground(lbg, 0.98)
    raceList:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    raceList:SetBackdropBorderColor(unpack(UI.colors.separator))
end
preview.raceButtons = {}

-- Modèle
local model = CreateFrame("DressUpModel", nil, col)
model:SetPoint("TOPLEFT", PAD, MODEL_TOP)
model:SetPoint("BOTTOMRIGHT", -PAD, MODEL_BOTTOM)
model:EnableMouse(true)
model:EnableMouseWheel(true)
preview.model = model
do
    local mbg = col:CreateTexture(nil, "BACKGROUND", nil, 1)
    mbg:SetPoint("TOPLEFT", model, "TOPLEFT")
    mbg:SetPoint("BOTTOMRIGHT", model, "BOTTOMRIGHT")
    mbg:SetColorTexture(0.02, 0.02, 0.02, 0.85)
end

local hint = model:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("BOTTOM", model, "BOTTOM", 0, 6)
hint:SetText("Clic droit : tourner  ·  Clic gauche : déplacer  ·  Molette : zoom")
UI.ApplySoftText(hint)

-- État : nom du sort, kits joués, remarques
local status = col:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
status:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 0, -8)
status:SetPoint("RIGHT", col, "RIGHT", -PAD, 0)
status:SetJustifyH("LEFT")
status:SetJustifyV("TOP")
status:SetWordWrap(true)
status:SetHeight(MODEL_BOTTOM - 8 - 40)
UI.ApplyBodyText(status)
preview.status = status

local replayBtn = UI.CreatePanelButton(col, 80, 22, "Rejouer")
replayBtn:SetPoint("BOTTOMLEFT", PAD, 14)
preview.replayBtn = replayBtn

local dressBtn = UI.CreatePanelButton(col, 100, 22, "")
dressBtn:SetPoint("LEFT", replayBtn, "RIGHT", 6, 0)
preview.dressBtn = dressBtn

local resetBtn = UI.CreatePanelButton(col, 70, 22, "Face")
resetBtn:SetPoint("LEFT", dressBtn, "RIGHT", 6, 0)
preview.resetBtn = resetBtn

-- ── Rendu ─────────────────────────────────────────────────────────────────

local view = { facing = 0, zoom = 1, y = 0, z = 0 }
local PAN_RATIO = 0.008   -- mètres par pixel d'écran, au zoom d'origine

local function KitsText(list)
    local parts = {}
    for i, kit in ipairs(list) do parts[i] = tostring(kit) end
    return table.concat(parts, ", ")
end

--- Ce qui sera joué pour l'aura courante : kits en boucle, kits ponctuels,
--- et une remarque si l'aura n'a pas de visuel propre.
local function Plan(kits)
    if not kits then return {}, {}, nil end
    if #kits.loop > 0 or #kits.once > 0 then return kits.loop, kits.once, nil end
    if #kits.cast > 0 or #kits.impact > 0 then
        return kits.cast, kits.impact, "Pas de visuel d'aura : effet d'incantation et d'impact du sort."
    end
    return {}, {}, nil
end

local function UpdateStatus()
    local id = preview.id
    if not id then
        status:SetText("|cff888888Saisissez un ID de sort à gauche, ou cliquez une aura de la liste : "
            .. "elle se joue aussitôt sur le modèle.|r")
        return
    end
    local name, icon = GM.SpellInfo(id)
    local lines = { (icon and ("|T" .. icon .. ":14|t ") or "")
        .. (name and ("|cffffffff" .. name .. "|r") or "|cff888888Sort inconnu du client|r")
        .. "  |cff888888" .. id .. "|r" }
    local kits = preview.kits
    local loop, once, note = Plan(kits)
    if #loop > 0 then lines[#lines + 1] = "En boucle : |cffffffff" .. KitsText(loop) .. "|r" end
    if #once > 0 then lines[#lines + 1] = "Ponctuel : |cffffffff" .. KitsText(once) .. "|r" end
    if kits and (kits.animKit or kits.anim or kits.stand) then
        local parts = {}
        if kits.stand then parts[#parts + 1] = "pose " .. kits.stand end
        if kits.animKit then parts[#parts + 1] = "AnimKit " .. kits.animKit .. (kits.animLoop and "" or " (une fois)")
        elseif kits.anim then parts[#parts + 1] = "animation " .. kits.anim end
        lines[#lines + 1] = "Animation : |cffffffff" .. table.concat(parts, ", ") .. "|r"
    end
    if note then lines[#lines + 1] = "|cffd7b35f" .. note .. "|r" end
    if kits and kits.transform then
        lines[#lines + 1] = "|cffd7b35fAura de transformation : elle remplace le modèle, "
            .. "l'aperçu ne peut pas la montrer.|r"
    elseif #loop == 0 and #once == 0 then
        lines[#lines + 1] = "|cffd7b35fAucun visuel connu pour ce sort (sort sans effet visible, "
            .. "ou propre au serveur).|r"
    end
    status:SetText(table.concat(lines, "\n"))
end

local function ApplyView()
    if model.SetFacing then model:SetFacing(view.facing) end
    if model.SetCamDistanceScale then model:SetCamDistanceScale(view.zoom) end
    if model.SetPosition then model:SetPosition(0, view.y, view.z) end
end

--- Joue les kits de l'aura courante sur le modèle fraîchement chargé.
--- Deux déclencheurs : le chargement du modèle (OnModelLoaded), et un
--- filet de sécurité quand ce chargement est passé avant d'être attendu
--- (modèle en cache). Le filet ne joue que si rien n'a encore été joué ;
--- un chargement qui arrive après lui rejoue une fois, car les kits posés
--- sur un modèle pas encore chargé sont perdus.
local function ApplyKits(token, fromLoad)
    if token ~= preview.token then return end
    if fromLoad then
        if preview.armed ~= token or preview.loadApplied then return end
        preview.loadApplied = true
    elseif preview.applied then
        return
    end
    preview.applied = true
    local s = Settings()
    if s.race ~= 0 and not s.dressed then model:Undress() end
    ApplyView()
    local loop, once = Plan(preview.kits)
    for _, kit in ipairs(loop) do pcall(model.ApplySpellVisualKit, model, kit, false) end
    for _, kit in ipairs(once) do pcall(model.ApplySpellVisualKit, model, kit, true) end
    -- L'animation du kit (bras qui portent la caisse…) n'est pas jouée par
    -- ApplySpellVisualKit : on la lance nous-mêmes.
    local kits = preview.kits
    if kits then
        if kits.stand then pcall(model.SetAnimation, model, kits.stand) end
        if kits.animKit then pcall(model.PlayAnimKit, model, kits.animKit, kits.animLoop)
        elseif kits.anim then pcall(model.SetAnimation, model, kits.anim) end
    end
end

--- Recharge le modèle (ce qui efface les kits déjà joués), puis rejoue l'aura.
local function Reload()
    local s = Settings()
    preview.token = preview.token + 1
    preview.applied, preview.loadApplied, preview.armed = false, false, nil
    local token = preview.token
    if model.StopAnimKit then model:StopAnimKit() end
    if model.ClearModel then model:ClearModel() end
    model:SetUnit("player")
    if s.race ~= 0 then
        model:SetCustomRace(s.race, s.sex)
        if not s.dressed then model:Undress() end
    end
    ApplyView()
    -- Armé seulement maintenant : un chargement déclenché par SetUnit, avant
    -- le changement de race, ne doit pas recevoir les kits.
    preview.armed = token
    After(0.5, function() ApplyKits(token) end)
end
model:SetScript("OnModelLoaded", function() ApplyKits(preview.token, true) end)

local function SyncControls()
    local s = Settings()
    raceBtn:SetText(RACE_NAME[s.race])
    SetActive(maleBtn, s.sex == 0)
    SetActive(femaleBtn, s.sex == 1)
    -- « Mon personnage » garde son apparence et sa tenue : pas de sexe ni de tenue à choisir.
    local custom = s.race ~= 0
    maleBtn:SetEnabled(custom); femaleBtn:SetEnabled(custom); dressBtn:SetEnabled(custom)
    if not custom then
        local mine = (UnitSex and UnitSex("player") == 3) and femaleBtn or maleBtn
        SetActive(mine, true); SetActive(mine == maleBtn and femaleBtn or maleBtn, false)
    end
    dressBtn:SetText(custom and (s.dressed and "Tenue : oui" or "Tenue : non") or "Tenue : oui")
    for _, b in ipairs(preview.raceButtons) do SetActive(b, b.raceID == s.race) end
end

--- Joue une aura sur le modèle (nil : modèle seul).
function GM:PreviewAura(id)
    id = tonumber(id)
    if id and (id <= 0 or id % 1 ~= 0) then id = nil end
    preview.id = id
    preview.kits = id and GM.AuraVisualKits(id) or nil
    UpdateStatus()
    if bank.Refresh then bank.Refresh() end
    if bank:IsShown() then Reload() end
end

--- Même chose, après un court délai : pour la saisie au clavier.
function GM:PreviewAuraSoon(id)
    preview.typing = (preview.typing or 0) + 1
    local mine = preview.typing
    After(TYPE_DELAY, function()
        if mine == preview.typing then GM:PreviewAura(id) end
    end)
end

function GM.PreviewedAura() return preview.id end

local function SetRace(raceID)
    Settings().race = raceID
    raceList:Hide()
    SyncControls()
    Reload()
end

for i, race in ipairs(GM.PREVIEW_RACES) do
    local b = UI.CreatePanelButton(raceList, RACE_COL_W - 2, RACE_ROW_H - 1, race.name)
    local c, r = math.floor((i - 1) / perCol), (i - 1) % perCol
    b:SetPoint("TOPLEFT", 6 + c * RACE_COL_W, -6 - r * RACE_ROW_H)
    b:GetFontString():SetJustifyH("LEFT")
    b.raceID = race.id
    b:SetScript("OnClick", function() SetRace(race.id) end)
    preview.raceButtons[i] = b
end

raceBtn:SetScript("OnClick", function() raceList:SetShown(not raceList:IsShown()) end)
local function SetSex(sex)
    Settings().sex = sex
    SyncControls()
    Reload()
end
maleBtn:SetScript("OnClick", function() SetSex(0) end)
femaleBtn:SetScript("OnClick", function() SetSex(1) end)
dressBtn:SetScript("OnClick", function()
    local s = Settings()
    s.dressed = not s.dressed
    SyncControls()
    Reload()
end)
dressBtn:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Tenue", "Non : modèle de base, sans équipement (le plus lisible pour une aura).",
        "Oui : la race choisie porte votre tenue actuelle." })
end)
dressBtn:SetScript("OnLeave", HideTooltip)
replayBtn:SetScript("OnClick", function() Reload() end)
replayBtn:SetScript("OnEnter", function(self)
    ShowTooltip(self, { "Rejouer", "Recharge le modèle et rejoue l'aura, effets ponctuels compris." })
end)
replayBtn:SetScript("OnLeave", HideTooltip)
resetBtn:SetScript("OnClick", function()
    view.facing, view.zoom, view.y, view.z = 0, 1, 0, 0
    ApplyView()
end)
resetBtn:SetScript("OnEnter", function(self) ShowTooltip(self, { "Face", "Remet le modèle de face, au centre, zoom d'origine." }) end)
resetBtn:SetScript("OnLeave", HideTooltip)

-- Clic droit glissé : tourner. Clic gauche glissé : déplacer le modèle
-- dans sa case. Molette : zoom.
model:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    local x, y = 0, 0
    if GetCursorPosition then x, y = GetCursorPosition() end
    self.drag = { mode = button == "RightButton" and "rotate" or "pan", button = button,
        x = x, y = y, facing = view.facing, posY = view.y, posZ = view.z }
    raceList:Hide()
end)
model:SetScript("OnMouseUp", function(self, button)
    if self.drag and self.drag.button == button then self.drag = nil end
end)
model:SetScript("OnHide", function(self) self.drag = nil end)
model:SetScript("OnUpdate", function(self)
    local d = self.drag
    if not d or not GetCursorPosition then return end
    local x, y = GetCursorPosition()
    local scale = self:GetEffectiveScale() or 1
    local dx, dy = (x - d.x) / scale, (y - d.y) / scale
    if d.mode == "rotate" then
        view.facing = d.facing + dx / 80
        self:SetFacing(view.facing)
    else
        view.y = d.posY + dx * PAN_RATIO * view.zoom
        view.z = d.posZ + dy * PAN_RATIO * view.zoom
        self:SetPosition(0, view.y, view.z)
    end
end)
model:SetScript("OnMouseWheel", function(_, delta)
    view.zoom = math.max(0.35, math.min(2.5, view.zoom - delta * 0.1))
    ApplyView()
end)

bank:HookScript("OnShow", function()
    SyncControls()
    UpdateStatus()
    Reload()
end)
bank:HookScript("OnHide", function() raceList:Hide() end)

preview.Reload, preview.SyncControls = Reload, SyncControls
