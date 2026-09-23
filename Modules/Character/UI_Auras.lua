-- ============================================================
--  Character - Auras du jeu (buffs/debuffs réels, pas les états
--  de combat de l'addon)
--  - Une rangée sous le cadre principal : tes propres auras,
--    alignées à droite, au plus près du cadre.
--  - Une petite carte à droite du cadre principal, qui s'affiche dès que
--    tu as une cible : clone littéral du cadre principal (même fond, même
--    portrait 80px à l'anneau doré, même hauteur), mais inversé et réduit
--    de moitié en largeur. Le nom en haut, ses auras dessous, à droite.
--    Sans fiche Character pour cette cible (PNJ, joueur non suivi...), la
--    carte reste minimale : nom du jeu et portrait, rien de plus.
-- ============================================================
local C = Character
local hud = CharacterResourceHUD
if not hud then return end

local MEDIA = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\"
local ICON, GAP = 20, 2

-- Compat : C_UnitAuras est l'API actuelle, UnitAura reste un repli pour les
-- clients qui ne l'exposent pas encore.
local GetAura
if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    GetAura = function(unit, index, filter)
        local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if not data then return nil end
        return data.name, data.icon, data.applications, data.dispelName, data.duration, data.expirationTime, data.spellId
    end
else
    GetAura = function(unit, index, filter)
        local name, icon, count, dispelType, duration, expirationTime, _, _, _, spellId = UnitAura(unit, index, filter)
        if not name then return nil end
        return name, icon, count, dispelType, duration, expirationTime, spellId
    end
end

local function DebuffColor(dispelType)
    local c = DebuffTypeColor and DebuffTypeColor[dispelType or ""]
    if c then return c.r, c.g, c.b end
    return .8, .2, .2
end

-- Commandes GM déjà en place côté serveur pour les auras natives
-- (Epsilon_TargetSpells.lua, désormais masquées) : on les reproduit à
-- l'identique sur nos propres icônes, sinon clic droit/Ctrl+clic n'ont
-- plus aucun moyen de s'exprimer une fois le TargetFrame natif caché.
local function SendAuraCommand(msg)
    SendChatMessage(msg, "GUILD")
end

local function NewAuraIcon(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(ICON, ICON)
    -- Clic droit : retire l'aura (.unaura, +" self" sur ses propres
    -- auras). Ctrl+Clic gauche sur l'aura de quelqu'un d'autre (la cible,
    -- jamais soi-même) : se l'applique à soi (.aura ... self).
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", function(self, button)
        if not self.spellId then return end
        if button == "RightButton" then
            if self.unit == "player" then
                SendAuraCommand(".unaura " .. self.spellId .. " self")
            else
                SendAuraCommand(".unaura " .. self.spellId)
            end
        elseif button == "LeftButton" and IsControlKeyDown() and self.unit ~= "player" then
            SendAuraCommand(".aura " .. self.spellId .. " self")
        end
    end)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(0, 0, 0, 1)
    b.border = border
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(.08, .92, .08, .92)
    b.tex = tex
    local cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cooldown:SetAllPoints(tex)
    cooldown:SetDrawEdge(false)
    cooldown:SetHideCountdownNumbers(true)
    b.cooldown = cooldown
    local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", 1, 0)
    b.count = count
    -- Tooltip réel du jeu : c'est lui qui affiche "Vous êtes en feu…".
    b:SetScript("OnEnter", function(self)
        if not self.unit or not self.index then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetUnitAura(self.unit, self.index, self.filter)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- Grille d'icônes qui s'enroule sur la largeur du conteneur ; sa hauteur
-- suit le nombre de lignes réellement utilisées. `alignRight` fait partir
-- chaque ligne du bord droit du conteneur, icônes posées vers la gauche.
local function CreateAuraRow(parent, width, alignRight)
    local row = CreateFrame("Frame", nil, parent)
    row:SetWidth(width)
    row.icons = {}
    function row:Refresh(unit)
        if not unit or not UnitExists(unit) then
            for _, icon in ipairs(row.icons) do icon:Hide() end
            row:SetHeight(.01); row:Hide()
            return
        end
        local perLine = math.max(1, math.floor((width + GAP) / (ICON + GAP)))
        local n = 0
        local function Place(filter)
            local index = 1
            while true do
                local name, icon, count, dispelType, duration, expirationTime, spellId = GetAura(unit, index, filter)
                if not name then break end
                n = n + 1
                local b = row.icons[n]
                if not b then b = NewAuraIcon(row); row.icons[n] = b end
                b.unit, b.index, b.filter, b.spellId = unit, index, filter, spellId
                b.tex:SetTexture(icon)
                b.count:SetText((count and count > 1) and tostring(count) or "")
                if filter == "HARMFUL" then
                    -- DebuffColor doit rester le dernier appel de la liste :
                    -- ses trois retours (r,g,b) seraient tronqués au premier
                    -- si un argument le suivait.
                    b.border:SetColorTexture(DebuffColor(dispelType))
                else
                    b.border:SetColorTexture(0, 0, 0, 1)
                end
                if duration and duration > 0 then
                    b.cooldown:SetCooldown(expirationTime - duration, duration)
                    b.cooldown:Show()
                else
                    b.cooldown:Hide()
                end
                local cell = n - 1
                local col = cell % perLine
                local line = math.floor(cell / perLine)
                b:ClearAllPoints()
                if alignRight then
                    b:SetPoint("TOPRIGHT", row, "TOPRIGHT", -col * (ICON + GAP), -line * (ICON + GAP))
                else
                    b:SetPoint("TOPLEFT", row, "TOPLEFT", col * (ICON + GAP), -line * (ICON + GAP))
                end
                b:Show()
                index = index + 1
            end
        end
        Place("HELPFUL")
        Place("HARMFUL")
        for i = n + 1, #row.icons do row.icons[i]:Hide() end
        local lines = n > 0 and math.ceil(n / perLine) or 0
        row:SetHeight(lines > 0 and (lines * (ICON + GAP) - GAP) or .01)
        row:SetShown(n > 0)
    end
    return row
end

-- Portrait 3D animé, construit à l'identique de celui du cadre principal
-- (masque circulaire, liseré noir, anneau PortraitRing.tga) : mêmes
-- proportions, juste une taille de conteneur paramétrable. Fonctionne
-- aussi bien sur un joueur que sur un PNJ : SetUnit affiche le modèle réel
-- de l'unité, pas une icône statique. `noRing` omet l'anneau doré. `secure`
-- en fait un vrai bouton de ciblage (SecureActionButtonTemplate) : cliquer
-- dessus cible `secure` (le token d'unité, ex. "targettarget") — fixé une
-- fois pour toutes puisque c'est un token stable, pas un nom résolu, donc
-- aucun souci de verrouillage de combat à gérer à chaque rafraîchissement.
-- `withMenu` : le clic droit ouvre le menu natif de l'unité (Inspecter,
-- Chuchoter, Inviter, TRP3, Epsilon...), comme sur le TargetFrame natif
-- qu'on masque. Client 9.2.7 : même ouverture que Blizzard (menu de
-- TargetFrameDropDown) ; client récent : action sécurisée "togglemenu".
local function EnableUnitMenu(button)
    if TargetFrameDropDown and ToggleDropDownMenu then
        button:SetAttribute("type2", "menu")
        button.menu = function()
            ToggleDropDownMenu(1, nil, TargetFrameDropDown, "cursor", 0, 0)
        end
    else
        button:SetAttribute("type2", "togglemenu")
    end
end

local function NewAnimatedPortrait(parent, size, noRing, secure, withMenu)
    local holder = CreateFrame("Button", nil, parent, secure and "SecureActionButtonTemplate" or nil)
    holder:SetSize(size, size)
    if secure then
        holder:RegisterForClicks(withMenu and "AnyUp" or "LeftButtonUp")
        holder:SetAttribute("type1", "target")
        holder:SetAttribute("unit", secure)
        if withMenu then EnableUnitMenu(holder) end
    end
    local mask = holder:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local rim = holder:CreateTexture(nil, "BACKGROUND")
    rim:SetAllPoints(); rim:SetColorTexture(0, 0, 0, 1); rim:AddMaskTexture(mask)
    -- Une MaskTexture ne découpe que des Texture, jamais un rendu 3D : le
    -- modèle ne PEUT PAS être recadré en cercle comme le rim ou l'icône de
    -- repli juste en dessous. Le cadre principal contourne ça en gardant le
    -- modèle nettement plus petit que le cercle et centré (64 dans un
    -- portrait de 80, même ratio ici) : la tête déborde rarement du cercle
    -- tant que la marge reste généreuse, contrairement à un cadrage bord à
    -- bord où le moindre écart de recadrage fait sortir le crâne du rond.
    local model = CreateFrame("PlayerModel", nil, holder)
    model:SetSize(size * .8, size * .8); model:SetPoint("CENTER")
    model:EnableMouse(false)
    local fallback = holder:CreateTexture(nil, "ARTWORK")
    fallback:SetPoint("TOPLEFT", 3, -3); fallback:SetPoint("BOTTOMRIGHT", -3, 3)
    fallback:Hide()
    local fallbackMask = holder:CreateMaskTexture()
    fallbackMask:SetAllPoints(fallback)
    fallbackMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fallback:AddMaskTexture(fallbackMask)
    -- Anneau doré : parenté au modèle (pas au holder) pour rendre par-dessus
    -- lui, exactement comme "ornament" dans le cadre principal.
    if not noRing then
        local ornament = CreateFrame("Frame", nil, model)
        ornament:SetAllPoints(holder); ornament:EnableMouse(false)
        local pad = size * .125
        local medallion = ornament:CreateTexture(nil, "OVERLAY")
        medallion:SetPoint("TOPLEFT", holder, "TOPLEFT", -pad, pad)
        medallion:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", pad, -pad)
        medallion:SetTexture(MEDIA .. "PortraitRing.tga")
    end
    -- Recadrage tête/épaules : appliqué tout de suite après SetUnit (le
    -- cadre principal fait pareil) ET à chaque chargement réel du fichier
    -- modèle. Une cible retargetée souvent ne peut pas se permettre
    -- d'attendre uniquement OnModelLoaded : en cas de retard ou de non
    -- déclenchement, le modèle restait sur un cadrage par défaut cassé —
    -- souvent un rond noir tant que rien n'a de quoi s'afficher.
    local function ApplyFraming()
        model:SetPortraitZoom(1)
        if model.SetRotation then model:SetRotation(0) end
    end
    model:SetScript("OnModelLoaded", ApplyFraming)
    function holder:Refresh(unit)
        if unit and UnitExists(unit) and model.SetUnit then
            model:Show(); fallback:Hide()
            model:SetUnit(unit)
            ApplyFraming()
            -- Filet de sécurité : si le fichier modèle finit de streamer
            -- après ce point sans redéclencher OnModelLoaded, un second
            -- recadrage différé rattrape le cadrage sans rien casser s'il
            -- était déjà bon.
            if C_Timer and C_Timer.After then
                local token = (holder.refreshToken or 0) + 1
                holder.refreshToken = token
                C_Timer.After(.2, function()
                    if holder.refreshToken == token and model:IsShown() then ApplyFraming() end
                end)
            end
        else
            model:Hide(); fallback:Show()
            if SetPortraitTexture then SetPortraitTexture(fallback, unit or "target")
            else fallback:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
        end
    end
    return holder
end

-- ── Rangée sous le cadre principal : tes propres auras ─────────────────────
-- Alignée à droite (comme le reste du cadre) et au plus près du bord
-- inférieur, pas flottante à distance.
local selfRow = CreateAuraRow(hud, 358, true)
selfRow:SetPoint("TOPRIGHT", hud, "BOTTOMRIGHT", -4, -2)
local function RefreshSelfAuras()
    if hud:IsShown() then selfRow:Refresh("player") else selfRow:Hide() end
end

-- ── Petite carte de cible, à droite du cadre principal ──────────────────────
-- Clone du cadre principal (366 de large, réduit de 50px sur demande) et
-- même hauteur (114), même fond ResourcePanelRounded.tga, même portrait
-- 80px à l'anneau doré — inversé (portrait à droite au lieu de la gauche,
-- via un simple miroir horizontal de la texture). À l'intérieur : le nom
-- en haut, ses auras dessous, de droite à gauche.
local CARD_W, CARD_H = 366 - 50, 114
local CARD_PORTRAIT = 80

local card = CreateFrame("Frame", "CharacterTargetCard", hud)
card:SetSize(CARD_W, CARD_H)
card:SetPoint("LEFT", hud, "RIGHT", 10, 0)
card:Hide()

-- Toute la carte réagit comme le portrait (clic droit = menu natif), au
-- niveau de la carte elle-même : les auras et portraits, créés ensuite
-- comme enfants, restent au-dessus et gardent leurs propres clics.
local cardClick = CreateFrame("Button", nil, card, "SecureActionButtonTemplate")
cardClick:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -8)
cardClick:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_PORTRAIT, 8)
cardClick:SetFrameLevel(card:GetFrameLevel())
cardClick:RegisterForClicks("AnyUp")
cardClick:SetAttribute("unit", "target")
cardClick:SetAttribute("type1", "target")
EnableUnitMenu(cardClick)

-- Même texture que le fond du cadre principal, retournée horizontalement :
-- le bord arrondi et le petit joyau qui ornaient son bord droit se
-- retrouvent à gauche, loin du portrait — le miroir exact de l'original.
-- Le panneau étant plus étroit (250px visibles) que celui du cadre
-- principal (300px), étirer toute la texture (512px source) compressait le
-- joyau ~1.6× plus fort horizontalement que l'original — mesuré au pixel
-- sur une capture (bulle de 10px de large contre 16px à gauche, pour une
-- hauteur identique de 44px des deux côtés). On ne prélève donc qu'une
-- tranche resserrée (320 sur 512, gardant le mur plat + le coin + le
-- joyau intacts) pour retrouver le même ratio d'étirement que l'original.
local cardBg = card:CreateTexture(nil, "BACKGROUND")
cardBg:SetPoint("TOPLEFT", card, "TOPLEFT", 24, -8)
cardBg:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -42, 8)
cardBg:SetTexture(MEDIA .. "ResourcePanelRounded.tga")
cardBg:SetTexCoord(1, 192 / 512, 0, 1)

local cardPortrait = NewAnimatedPortrait(card, CARD_PORTRAIT, false, "target", true)
cardPortrait:SetPoint("RIGHT", card, "RIGHT", 0, 0)

-- Cible de la cible : même anneau que les cadres classiques, cliquable
-- pour la cibler directement (SecureActionButtonTemplate sur le token
-- stable "targettarget").
local TOT_SIZE = 44
-- Fond noir pur sous le portrait et son anneau, pour cacher proprement le
-- morceau du grand portrait qu'il chevauche plutôt que de le laisser
-- transparaître ; l'anneau doré, opaque, recouvre son bord.
local totBacking = CreateFrame("Frame", nil, cardPortrait)
-- L'anneau du grand portrait est deux niveaux au-dessus de lui (holder ->
-- modèle -> anneau) : sans ce saut, il repasse par-dessus le petit
-- portrait. Fixé AVANT de créer le petit portrait pour que son modèle 3D
-- et son anneau héritent de ce niveau (voir plus bas).
totBacking:SetFrameLevel(cardPortrait:GetFrameLevel() + 10)
-- Le cercle doré de PortraitRing.tga fait ~90 % de la texture, elle-même
-- 1,25 × le portrait : ~50 px ici. Le fond reste en dessous (48 px), sinon
-- son bord noir dépasse de l'anneau.
totBacking:SetSize(TOT_SIZE + 4, TOT_SIZE + 4)
totBacking:SetPoint("CENTER", cardPortrait, "BOTTOMRIGHT", -4, 4)
local totBackingMask = totBacking:CreateMaskTexture()
totBackingMask:SetAllPoints()
totBackingMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
local totBackingTex = totBacking:CreateTexture(nil, "BACKGROUND")
totBackingTex:SetAllPoints(); totBackingTex:SetColorTexture(0, 0, 0, 1)
totBackingTex:AddMaskTexture(totBackingMask)
totBacking:Hide()

-- Parenté à totBacking (pas à cardPortrait) : ses propres enfants (modèle
-- 3D, anneau) héritent alors du bon niveau dès leur création et passent
-- automatiquement devant le fond noir et le coin qu'il chevauche. Un
-- simple SetFrameLevel après coup ne suffit pas ici — il ne remonte que ce
-- portrait-ci, pas son modèle 3D interne (déjà figé à son propre niveau à
-- la création).
local totPortrait = NewAnimatedPortrait(totBacking, TOT_SIZE, false, "targettarget")
totPortrait:SetPoint("CENTER", totBacking, "CENTER", 0, 0)
totPortrait:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetUnit("targettarget")
    GameTooltip:Show()
end)
-- TRP3 ne ferme sa fiche que si la souris ne survole plus aucune unité ou
-- si "targettarget" change : glisser vers la carte de cible (elle-même une
-- unité survolée) la laissait ouverte, aperçus compris. On ferme tout.
totPortrait:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if TRP3_CharacterTooltip then TRP3_CharacterTooltip:Hide() end
    if TRP3_CompanionTooltip then TRP3_CompanionTooltip:Hide() end
    -- Les aperçus ("Au premier coup d'œil") ont leurs propres infobulles.
    for i = 1, 5 do
        local glance = _G["TRP3_FirstGlanceTooltip" .. i]
        if glance then glance:Hide() end
    end
end)

-- Nom ancré à DROITE, juste au-dessus des auras (même bord droit), et qui
-- s'écrit vers la gauche — comme les auras en dessous, pas collé au bord
-- gauche du panneau. Retrait identique des deux côtés (nom et auras),
-- calculé sur le cadre principal : portrait à hud+0..80, jauges à partir
-- de hud+96, donc 96-80=16px entre le portrait et les jauges. Même 16px
-- ici entre le portrait et le nom/les auras.
-- Hauteur FIXE de 20px, comme le nom du cadre principal (SetSize(265,20)) :
-- le texte se centre verticalement dedans, ce qui le pousse ~10px sous son
-- ancre brute — sans ça il colle pile à l'ancre et semble "trop haut".
local RIGHT_GAP = 16
local cardName = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cardName:SetPoint("TOPLEFT", card, "TOPLEFT", 24 + 48, -17)
cardName:SetPoint("TOPRIGHT", cardPortrait, "TOPLEFT", -RIGHT_GAP, -17)
cardName:SetHeight(20)
cardName:SetJustifyH("RIGHT"); cardName:SetWordWrap(false)
cardName:SetTextColor(.91, .83, .65)

-- Chaîné au nom : même bord droit que lui (donc même retrait que les
-- jauges/cadre principal), juste en dessous.
local cardAuras = CreateAuraRow(card, CARD_W - (24 + 48) - CARD_PORTRAIT - RIGHT_GAP, true)
cardAuras:SetPoint("TOPRIGHT", cardName, "BOTTOMRIGHT", 0, -6)

-- GetDisplayName interroge TRP3 pour N'IMPORTE QUEL joueur, pas seulement
-- les membres suivis par Character (C.groupData) — donc on la tente pour
-- toute cible, groupe ou pas. Elle ne retombe sur "Profil en attente" que
-- faute de TRP3 ET de fiche Character : dans ce cas seulement (PNJ, joueur
-- sans TRP3 et non suivi), on garde le nom brut du jeu plutôt que ce texte
-- d'attente qui n'a rien à faire sur une cible qu'on ne connaît pas.
local function ResolveCardName()
    if UnitIsUnit("target", "player") then
        return C.GetDisplayName and C:GetDisplayName(UnitName("player"), C:GetMyChar()) or UnitName("player")
    end
    local rawName = UnitName("target")
    local shortName = rawName and rawName:match("^([^%-]+)") or rawName
    if shortName and C.GetDisplayName then
        local data = C.groupData and C.groupData[shortName]
        local display = C:GetDisplayName(shortName, data)
        if display and display ~= "Profil en attente" then return display end
    end
    return rawName or UNKNOWN
end

local function RefreshCard()
    if not hud:IsShown() or not UnitExists("target") then
        card:Hide()
        return
    end
    cardName:SetText(ResolveCardName())
    cardPortrait:Refresh("target")
    cardAuras:Refresh("target")
    -- Rien si la cible se cible elle-même : dupliquer le même portrait en
    -- plus petit n'apporterait rien.
    if C:GetSettings().showTargetOfTarget and UnitExists("targettarget")
        and not UnitIsUnit("targettarget", "target") then
        totPortrait:Refresh("targettarget")
        totBacking:Show()
    else
        totBacking:Hide()
    end
    card:Show()
end

C.RefreshTargetCard = RefreshCard

-- Un seul point d'accroche pour les deux : hud:Refresh() est déjà appelé
-- par ApplyResourceHUD, OnMyDataChanged et les events portrait existants.
local previousHudRefresh = hud.Refresh
function hud:Refresh(...)
    previousHudRefresh(self, ...)
    RefreshSelfAuras()
    RefreshCard()
end

hud:RegisterEvent("PLAYER_TARGET_CHANGED")
hud:RegisterEvent("UNIT_AURA")
-- La cible peut changer QUI ELLE cible sans que notre propre cible change :
-- UNIT_TARGET sur "target" est le seul événement qui le signale.
hud:RegisterEvent("UNIT_TARGET")
hud:HookScript("OnEvent", function(_, event, unit)
    if not hud:IsShown() then return end
    if event == "PLAYER_TARGET_CHANGED" then
        RefreshCard()
    elseif event == "UNIT_AURA" then
        if unit == "player" then RefreshSelfAuras()
        elseif unit == "target" then RefreshCard() end
    elseif event == "UNIT_TARGET" and unit == "target" then
        RefreshCard()
    end
end)

-- ── Masquage des auras natives (joueur ET cible) ────────────────────────────
-- Sur ce client, les icônes natives ne sont PAS des globales à plat
-- (BuffButton1, TargetFrameBuff1…) — le premier essai les visait et n'a
-- rien masqué du tout puisqu'elles n'existent pas sous cette forme. Le vrai
-- rendu passe par des tables imbriquées (confirmé en lisant
-- Epsilon_AuraManager.lua, qui les peuple lui-même) : BuffFrame.BuffButton
-- / BuffFrame.DebuffButton côté joueur, TargetFrame.Buff / TargetFrame.Debuff
-- côté cible. Blizzard peut créer nouveaux boutons à la volée (plus
-- d'auras que jamais vues) : on ne fige pas la liste une fois pour toutes,
-- on la reconstruit à chaque passage pour attraper les nouveaux.
local function CollectNativeAuraIcons()
    local icons = {}
    local function AddArray(t)
        if not t then return end
        for _, icon in pairs(t) do
            if icon and icon.Hide then icons[#icons + 1] = icon end
        end
    end
    if BuffFrame then AddArray(BuffFrame.BuffButton); AddArray(BuffFrame.DebuffButton) end
    if TargetFrame then AddArray(TargetFrame.Buff); AddArray(TargetFrame.Debuff) end
    if PlayerFrame then AddArray(PlayerFrame.Buff); AddArray(PlayerFrame.Debuff) end
    return icons
end
local function SetNativeAurasSuppressed(suppressed)
    for _, icon in ipairs(CollectNativeAuraIcons()) do
        if suppressed then
            if icon.omegaOriginalOnShow == nil then
                icon.omegaOriginalOnShow = icon:GetScript("OnShow") or false
            end
            icon:SetScript("OnShow", icon.Hide)
            icon:Hide()
        elseif icon.omegaOriginalOnShow ~= nil then
            icon:SetScript("OnShow", icon.omegaOriginalOnShow or nil)
            icon.omegaOriginalOnShow = nil
        end
    end
end
hud:HookScript("OnShow", function() SetNativeAurasSuppressed(true) end)
hud:HookScript("OnHide", function() SetNativeAurasSuppressed(false) end)
-- Repasse aussi à chaque changement d'auras pendant que Character est actif :
-- un bouton natif tout juste créé pour une nouvelle aura doit être masqué
-- dès son apparition, pas seulement au prochain Show/Hide du cadre.
hud:HookScript("OnEvent", function(_, event)
    if hud:IsShown() and (event == "UNIT_AURA" or event == "PLAYER_TARGET_CHANGED") then
        SetNativeAurasSuppressed(true)
    end
end)
if hud:IsShown() then SetNativeAurasSuppressed(true) end

-- ── Masquage des cadres natifs du joueur et de la cible ─────────────────────
-- Le cadre principal et la carte de cible font doublon avec PlayerFrame et
-- TargetFrame de Blizzard : on les masque tant que Character est actif,
-- même mécanisme réversible (OnShow -> Hide) que pour les auras juste
-- au-dessus. Les auras qu'Epsilon accroche sous ces cadres sont leurs
-- enfants et disparaissent avec eux. PlayerFrame ne se réaffiche pas
-- seul (il n'a pas de "changement de cible") : on le remontre au retour.
local function SetNativeFrameSuppressed(frame, suppressed, reshow)
    if suppressed then
        if frame.omegaOriginalOnShow == nil then
            frame.omegaOriginalOnShow = frame:GetScript("OnShow") or false
        end
        frame:SetScript("OnShow", frame.Hide)
        frame:Hide()
    elseif frame.omegaOriginalOnShow ~= nil then
        frame:SetScript("OnShow", frame.omegaOriginalOnShow or nil)
        frame.omegaOriginalOnShow = nil
        if reshow then frame:Show() end
    end
end
local function SetNativeFramesSuppressed(suppressed)
    -- Cadres sécurisés : Show/Hide interdits en combat. On réessaie à la
    -- sortie du combat (PLAYER_REGEN_ENABLED, plus bas).
    if InCombatLockdown and InCombatLockdown() then return end
    if PlayerFrame then SetNativeFrameSuppressed(PlayerFrame, suppressed, true) end
    if TargetFrame then SetNativeFrameSuppressed(TargetFrame, suppressed, false) end
end
hud:HookScript("OnShow", function() SetNativeFramesSuppressed(true) end)
hud:HookScript("OnHide", function() SetNativeFramesSuppressed(false) end)
hud:RegisterEvent("PLAYER_REGEN_ENABLED")
hud:HookScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then SetNativeFramesSuppressed(hud:IsShown()) end
end)
if hud:IsShown() then SetNativeFramesSuppressed(true) end

-- ── Correctif TRP3 : position des aperçus ("Au premier coup d'œil") ───────
-- TRP3 ne place ses infobulles d'aperçu que pour les ancrages curseur et
-- haut/bas-droite de sa fiche ; pour les autres, elles gardent une position
-- arbitraire et s'empilent les unes sur les autres. Si elles se chevauchent
-- (entre elles ou avec la fiche), on les range en colonne à côté de la
-- fiche, du côté où il reste de la place. Sinon, on ne touche à rien.
local function Overlaps(a, b)
    local al, ar, at, ab = a:GetLeft(), a:GetRight(), a:GetTop(), a:GetBottom()
    local bl, br, bt, bb = b:GetLeft(), b:GetRight(), b:GetTop(), b:GetBottom()
    if not (al and ar and at and ab and bl and br and bt and bb) then return true end
    return al < br - 1 and bl < ar - 1 and ab < bt - 1 and bb < at - 1
end

local function FixGlanceLayout()
    local main = TRP3_CharacterTooltip
    if not main or not main:IsShown() then return end
    local shown = {}
    for i = 1, 5 do
        local glance = _G["TRP3_FirstGlanceTooltip" .. i]
        if glance and glance:IsShown() then shown[#shown + 1] = glance end
    end
    local overlapping = false
    for i, glance in ipairs(shown) do
        if Overlaps(glance, main) then overlapping = true end
        for j = i + 1, #shown do
            if Overlaps(glance, shown[j]) then overlapping = true end
        end
    end
    if not overlapping then return end
    local widest = 0
    for _, glance in ipairs(shown) do widest = math.max(widest, glance:GetWidth() or 0) end
    local toRight = (main:GetRight() or 0) + widest + 2 <= (UIParent:GetRight() or 0)
    for i, glance in ipairs(shown) do
        glance:ClearAllPoints()
        if i == 1 then
            if toRight then glance:SetPoint("TOPLEFT", main, "TOPRIGHT", 2, 0)
            else glance:SetPoint("TOPRIGHT", main, "TOPLEFT", -2, 0) end
        elseif toRight then
            glance:SetPoint("TOPLEFT", shown[i - 1], "BOTTOMLEFT", 0, -2)
        else
            glance:SetPoint("TOPRIGHT", shown[i - 1], "BOTTOMRIGHT", 0, -2)
        end
    end
end

-- TRP3 peut se charger après nous : branchement à la connexion.
local glanceHook = CreateFrame("Frame")
glanceHook:RegisterEvent("PLAYER_LOGIN")
glanceHook:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    for i = 1, 5 do
        local glance = _G["TRP3_FirstGlanceTooltip" .. i]
        -- Au prochain rendu : TRP3 finit de remplir et d'ancrer après le Show.
        if glance then glance:HookScript("OnShow", function() C_Timer.After(0, FixGlanceLayout) end) end
    end
end)
