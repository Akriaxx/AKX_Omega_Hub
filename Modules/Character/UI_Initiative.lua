-- ============================================================
--  Character — Bannière Initiative
--  Affichée automatiquement chez tous quand le MJ démarre un combat
-- ============================================================

local C  = Character
local UI = OS2.UI

local CARD_W, CARD_H = 52, 64
local CARD_GAP       = 4
local HEADER_H       = 20
local CONTENT_H      = CARD_H + 10
local BANNER_H       = HEADER_H + CONTENT_H
local INPUT_W        = 60
local EVENT_CARD_W   = 40

local cards      = {}
local eventCards = {}

-- Défini plus bas (popup "Ajouter un évènement") ; référencé depuis MakeCard
-- avant sa définition, d'où le forward-declare. Le popup "Ajouter un état",
-- lui, est exposé en méthode (C:OpenStatusPopup) : ouvert depuis d'autres
-- fichiers (UI_Group.lua — Vue joueur, UI_MJ.lua — Gestionnaire de
-- ressources), jamais depuis cette bannière elle-même.
local OpenEventPopup

-- Idem pour le panneau "Cibles" et le compteur de sélection du popup "État" :
-- référencés depuis MakeStatusTargetRow (une ligne cliquée doit ouvrir/fermer
-- l'un et rafraîchir l'autre) avant leur définition respective plus bas.
local ToggleTargetsPanel
local RefreshSelectedCount

-- Nom affiché d'un participant : nom brut pour un PNJ, nom/prénom RP (TRP3)
-- via GetDisplayName pour un joueur — même logique que AnnounceCurrentTurn
-- côté Core.lua (sans le nettoyage TRP3 des PNJ, ici purement pour un libellé
-- de popup, pas une annonce en chat).
local function ParticipantLabel(p)
    if not p then return "" end
    if p.kind == "npc" then return p.name or "" end
    local data = (p.id == UnitName("player")) and C:GetMyChar() or C.groupData[p.id]
    return (C.GetDisplayName and C:GetDisplayName(p.id, data)) or p.id
end

-- Icone d'un participant sur une texture donnée : portrait 3D du joueur (avec
-- repli sur une icone générique s'il n'est pas rendable, ex. hors zone), ou
-- l'icone choisie du PNJ. Partagé entre la carte de la bannière (MakeCard) et
-- la liste de cibles du popup "Ajouter un état" (MakeStatusTargetRow).
local function SetParticipantIcon(icon, p)
    if p.kind == "player" then
        local ok = false
        if SetPortraitTexture and UnitExists then
            local token = C.GetUnitTokenForName and C:GetUnitTokenForName(p.id)
            if token and UnitExists(token) then
                icon:SetTexture(nil)
                ok = pcall(SetPortraitTexture, icon, token)
            end
        end
        if not ok then
            icon:SetTexture("Interface\\Icons\\Achievement_Character_Human_Male")
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
    else
        icon:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

local function FindParticipantById(id)
    for _, p in ipairs(C.initiative.participants) do
        if p.id == id then return p end
    end
end

-- ── Bannière ──────────────────────────────────────────────────────────────────

local banner = CreateFrame("Frame", "CharacterInitiativeBanner", UIParent)
banner:SetSize(200, BANNER_H)
banner:SetPoint("TOP", UIParent, "TOP", 0, -6)
banner:SetFrameStrata("MEDIUM")
banner:SetMovable(true)
banner:SetClampedToScreen(true)
banner:Hide()

local bg = banner:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
UI.ApplyWindowBackground(bg)
banner.bg = bg

UI.ApplyBorder(banner)

-- ── Header draggable ──────────────────────────────────────────────────────────

local header = CreateFrame("Frame", nil, banner)
header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT")
header:SetHeight(HEADER_H)
header:EnableMouse(true)
header:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then banner:StartMoving() end
end)
header:SetScript("OnMouseUp", function() banner:StopMovingOrSizing() end)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints()
headerBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local headerTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerTitle:SetPoint("LEFT", header, "LEFT", 8, 0)
headerTitle:SetText("Initiative")
UI.ApplyTitle(headerTitle)

local headerSep = banner:CreateTexture(nil, "ARTWORK")
headerSep:SetPoint("TOPLEFT", header, "BOTTOMLEFT")
headerSep:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT")
headerSep:SetHeight(1)
UI.ApplySeparator(headerSep, true)

-- Bouton "+ Évt" (hôte uniquement) : ajoute un évènement GÉNÉRAL, dissocié
-- de tout participant — il est injecté dans la rotation d'initiative (ancré
-- au participant en cours à l'instant de la création, voir AddEvent côté
-- Core.lua). Le compteur descend de 1 à chaque tour de table complet comme
-- n'importe quel évènement, mais ne se déclenche qu'au retour du bandeau sur
-- cette ancre (voir TickEventsFor). Une fois ajouté, il s'affiche comme une
-- carte dédiée tout à droite de la rangée de participants — voir la boucle
-- sur `st.events` dans Rebuild plus bas. Voir OpenEventPopup(nil) plus bas /
-- C:AddEvent + TickEventsFor côté Core.lua.
local addGlobalEventBtn = UI.CreatePanelButton(header, 54, 16, "+ Évt")
addGlobalEventBtn:SetPoint("RIGHT", header, "RIGHT", -6, 0)
addGlobalEventBtn:SetFrameLevel(header:GetFrameLevel() + 2)
addGlobalEventBtn:SetScript("OnClick", function()
    if OpenEventPopup then OpenEventPopup(nil) end
end)
addGlobalEventBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Ajouter un évènement général", unpack(UI.colors.title))
    GameTooltip:AddLine("Dissocié de tout participant : décompte une fois par tour de table complet, peu importe qui joue en premier.", unpack(UI.colors.textMuted))
    GameTooltip:Show()
end)
addGlobalEventBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
addGlobalEventBtn:Hide()

-- ── Saisie "Initiative" (à gauche) ───────────────────────────────────────────

local inputLabel = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
inputLabel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -6)
inputLabel:SetText("Ma valeur")
UI.ApplyLabel(inputLabel)

local inputEB = UI.CreateStyledEditBox(banner, INPUT_W, 20)
inputEB:SetNumeric(true)
inputEB:SetMaxLetters(4)
inputEB:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -4)

inputEB:SetScript("OnEnterPressed", function(self)
    local v = self:GetText()
    if v and v ~= "" then C:SubmitMyInitiative(v) end
    self:ClearFocus()
end)

local inputSep = banner:CreateTexture(nil, "ARTWORK")
inputSep:SetPoint("TOPLEFT", header, "BOTTOMLEFT", INPUT_W + 12, -4)
inputSep:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", INPUT_W + 12, 4)
inputSep:SetWidth(1)
UI.ApplySeparator(inputSep, true)

-- ── Cartes participants ──────────────────────────────────────────────────────

local function MakeCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(CARD_W, CARD_H)

    local cbg = card:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    cbg:SetColorTexture(unpack(UI.colors.rowBg))

    -- Surbrillance légère quand ce participant est sélectionné dans le
    -- Gestionnaire de ressources (Vue MJ) : juste un repère visuel pour le
    -- MJ, distinct du cadre cyan "tour en cours".
    local spotlight = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    spotlight:SetAllPoints()
    spotlight:SetColorTexture(unpack(UI.colors.rowSelection))
    spotlight:Hide()
    card.spotlight = spotlight
    function card:SetSpotlight(isOn) spotlight:SetShown(isOn) end

    -- Juste un cadre (4 fines lignes), pas un pavé plein derrière la carte.
    local function GlowLine(p1, p1x, p1y, p2, p2x, p2y, isVert)
        local t = card:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(UI.colors.turnHighlight))
        t:SetPoint(p1, card, p1, p1x, p1y)
        t:SetPoint(p2, card, p2, p2x, p2y)
        if isVert then t:SetWidth(2) else t:SetHeight(2) end
        t:Hide()
        return t
    end
    local glow = {
        GlowLine("TOPLEFT",     -2,  2, "TOPRIGHT",    2,  2, false),
        GlowLine("BOTTOMLEFT",  -2, -2, "BOTTOMRIGHT", 2, -2, false),
        GlowLine("TOPLEFT",     -2,  2, "BOTTOMLEFT", -2, -2, true),
        GlowLine("TOPRIGHT",     2,  2, "BOTTOMRIGHT", 2, -2, true),
    }
    card.glow = glow

    local iconMask = card:CreateMaskTexture()
    iconMask:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    iconMask:SetSize(CARD_W - 8, CARD_W - 8)
    iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    icon:SetSize(CARD_W - 8, CARD_W - 8)
    icon:AddMaskTexture(iconMask)
    card.icon = icon

    -- Juste la valeur d'initiative suffit, pas besoin du nom.
    local initFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    initFS:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -(CARD_W - 4))
    initFS:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -(CARD_W - 4))
    initFS:SetJustifyH("CENTER")
    initFS:SetWordWrap(false)
    UI.ApplyBodyText(initFS)
    card.initFS = initFS

    local closeBtn = UI.CreateCloseButton(card, nil)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", 2, 2)
    closeBtn:SetSize(10, 10)
    if closeBtn.label then closeBtn.label:SetScale(0.7) end
    closeBtn:Hide()
    card.closeBtn = closeBtn

    -- "+" pour rajouter un évènement différé sur CE participant : visible en
    -- permanence, pas seulement pendant son tour (le compteur descend de 1 à
    -- chaque tour de table complet, peu importe qui joue — voir TickEventsFor
    -- côté Core.lua ; seul le DÉCLENCHEMENT, lui, attend que le bandeau
    -- revienne sur ce participant) et seulement pour l'hôte du combat (seul
    -- C:AddEvent peut réellement l'enregistrer).
    local addEventBtn = CreateFrame("Button", nil, card)
    addEventBtn:SetSize(12, 12)
    addEventBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", -2, -2)
    local aebBg = addEventBtn:CreateTexture(nil, "BACKGROUND")
    aebBg:SetAllPoints()
    aebBg:SetColorTexture(unpack(UI.colors.panelButtonBg))
    local aebLbl = addEventBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    aebLbl:SetAllPoints()
    aebLbl:SetText("+")
    UI.ApplyBodyText(aebLbl)
    local aebHl = addEventBtn:CreateTexture(nil, "HIGHLIGHT")
    aebHl:SetAllPoints()
    aebHl:SetColorTexture(unpack(UI.colors.panelButtonHighlight))
    addEventBtn:Hide()
    addEventBtn:SetScript("OnClick", function()
        if card.participantId and OpenEventPopup then OpenEventPopup(card.participantId) end
    end)
    addEventBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Ajouter un évènement", unpack(UI.colors.title))
        GameTooltip:AddLine("Le compteur descend de 1 à chaque tour de table ; se déclenche (annoncé en /rw) au tour de ce participant, une fois à 0.", unpack(UI.colors.textMuted))
        GameTooltip:Show()
    end)
    addEventBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.addEventBtn = addEventBtn

    -- Badge (nombre) en bas à droite DE CE PERSONNAGE tant qu'il a des
    -- évènements en attente accrochés à lui : ces évènements comptent comme
    -- s'ils étaient ce participant (décomptés sur ses tours, voir
    -- TickEventsFor côté Core.lua), donc affichés directement sur sa carte
    -- plutôt qu'en case séparée — contrairement à un évènement général (non
    -- affilié), lui affiché en case dédiée dans la rangée (voir
    -- MakeEventCard).
    local eventBadge = CreateFrame("Frame", nil, card)
    eventBadge:SetSize(14, 12)
    eventBadge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", 2, -2)
    eventBadge:EnableMouse(true)
    local ebBg = eventBadge:CreateTexture(nil, "BACKGROUND")
    ebBg:SetAllPoints()
    ebBg:SetColorTexture(unpack(UI.colors.panelButtonBg))
    local ebLbl = eventBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ebLbl:SetAllPoints()
    UI.ApplyBodyText(ebLbl)
    eventBadge.label = ebLbl
    eventBadge:SetScript("OnEnter", function(self)
        if not card.participantId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Évènements en attente", unpack(UI.colors.title))
        for _, e in ipairs(C.initiative.events or {}) do
            if e.participantId == card.participantId then
                local turnWord = (e.turnsLeft > 1) and "tours" or "tour"
                local line = e.description .. "  (" .. e.turnsLeft .. " " .. turnWord .. ")"
                if e.repeatable then line = line .. " [répétable]" end
                GameTooltip:AddLine(line, unpack(UI.colors.textMuted))
            end
        end
        GameTooltip:Show()
    end)
    eventBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    eventBadge:Hide()
    card.eventBadge = eventBadge

    -- Petit "E" en haut à gauche DE L'ICONE tant que ce participant a au
    -- moins un état actif (voir C.initiative.statuses, synchronisé à tout le
    -- monde contrairement aux évènements) : visible pour tous, pas seulement
    -- l'hôte. L'infobulle liste chaque état et qui l'a appliqué.
    local statusBadge = CreateFrame("Frame", nil, card)
    statusBadge:SetSize(14, 12)
    statusBadge:SetPoint("TOPLEFT", card, "TOPLEFT", -2, 2)
    statusBadge:EnableMouse(true)
    local sbBg = statusBadge:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints()
    sbBg:SetColorTexture(unpack(UI.colors.panelButtonBg))
    local sbLbl = statusBadge:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sbLbl:SetAllPoints()
    sbLbl:SetText("E")
    UI.ApplyBodyText(sbLbl)
    statusBadge:SetScript("OnEnter", function(self)
        if not card.participantId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("États actifs", unpack(UI.colors.title))
        for _, s in ipairs(C.initiative.statuses or {}) do
            if s.targetId == card.participantId then
                local sourceLabel = (C.GetDisplayName and C:GetDisplayName(s.source, C.groupData[s.source])) or s.source
                local turnWord = (s.turnsLeft > 1) and "tours" or "tour"
                GameTooltip:AddLine(s.text .. "  (" .. s.turnsLeft .. " " .. turnWord .. ")", unpack(UI.colors.textMuted))
                GameTooltip:AddLine("— par " .. sourceLabel, unpack(UI.colors.textMuted))
            end
        end
        GameTooltip:Show()
    end)
    statusBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    statusBadge:Hide()
    card.statusBadge = statusBadge

    function card:Refresh(p, isCurrent)
        card.participantId = p.id
        initFS:SetText(tostring(p.initiative or 0))
        for _, line in ipairs(glow) do line:SetShown(isCurrent) end

        addEventBtn:SetShown(C.initiative.isHost)

        local pendingN = 0
        for _, e in ipairs(C.initiative.events or {}) do
            if e.participantId == p.id then pendingN = pendingN + 1 end
        end
        if C.initiative.isHost and pendingN > 0 then
            ebLbl:SetText(tostring(pendingN))
            eventBadge:Show()
        else
            eventBadge:Hide()
        end

        local statusN = 0
        for _, s in ipairs(C.initiative.statuses or {}) do
            if s.targetId == p.id then statusN = statusN + 1 end
        end
        statusBadge:SetShown(statusN > 0)

        SetParticipantIcon(icon, p)

        if p.kind == "npc" and p.creator == UnitName("player") then
            closeBtn:Show()
        else
            closeBtn:Hide()
        end

        card:SetSpotlight(C.IsImpactSelected and C:IsImpactSelected(p.id))
    end

    closeBtn:SetScript("OnClick", function()
        if card.participantId then C:RemoveNPC(card.participantId) end
    end)

    return card
end

local function GetCard(i)
    if not cards[i] then cards[i] = MakeCard(banner) end
    return cards[i]
end

-- ── Cartes évènement (généraux uniquement) ──────────────────────────────────
-- Une "case propre" par évènement GÉNÉRAL en attente (participantId nil,
-- dissocié de tout participant), affichée tout à droite de la rangée — voir
-- Rebuild. Un évènement accroché à un participant précis, lui, reste un
-- badge sur SA carte (voir eventBadge dans MakeCard) puisqu'il compte comme
-- s'il était ce participant. Un coup d'œil suffit ici pour voir qu'il y a un
-- évènement, combien de tours de table il reste, et s'il est répétable ; la
-- description complète reste en infobulle (rarement plus de quelques mots,
-- mais la carte est trop étroite pour l'afficher en clair sans wordwrap
-- illisible).

local function MakeEventCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(EVENT_CARD_W, CARD_H)
    card:EnableMouse(true)

    local cbg = card:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    cbg:SetColorTexture(unpack(UI.colors.rowBg))

    -- Simple bandeau d'accent en haut, pour distinguer une carte évènement
    -- d'une carte participant au premier coup d'œil.
    local accent = card:CreateTexture(nil, "BORDER")
    accent:SetPoint("TOPLEFT"); accent:SetPoint("TOPRIGHT")
    accent:SetHeight(3)
    accent:SetColorTexture(unpack(UI.colors.warning))

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOP", card, "TOP", 0, -7)
    icon:SetSize(18, 18)
    icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Nombre de tours de table restants avant déclenchement.
    local turnsFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    turnsFS:SetPoint("TOP", icon, "BOTTOM", 0, -2)
    turnsFS:SetPoint("LEFT", card, "LEFT", 1, 0)
    turnsFS:SetPoint("RIGHT", card, "RIGHT", -1, 0)
    turnsFS:SetJustifyH("CENTER")
    turnsFS:SetWordWrap(false)
    UI.ApplyBodyText(turnsFS)
    card.turnsFS = turnsFS

    -- Icône "répétition" tant que l'évènement est répétable (se relance
    -- après déclenchement au lieu d'être retiré) : une texture plutôt qu'un
    -- symbole Unicode ("↻"), que la police par défaut de WoW n'a pas et qui
    -- s'affichait comme un carré vide.
    local repeatIcon = card:CreateTexture(nil, "OVERLAY")
    repeatIcon:SetPoint("BOTTOM", card, "BOTTOM", 0, 4)
    repeatIcon:SetSize(10, 10)
    repeatIcon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
    card.repeatIcon = repeatIcon

    -- Retire manuellement l'évènement (seul moyen d'arrêter un répétable
    -- avant terme, ex. une fois le boss vaincu).
    local closeBtn = UI.CreateCloseButton(card, nil)
    closeBtn:ClearAllPoints()
    closeBtn:SetPoint("TOPRIGHT", card, "TOPRIGHT", 2, 2)
    closeBtn:SetSize(10, 10)
    if closeBtn.label then closeBtn.label:SetScale(0.7) end
    closeBtn:SetScript("OnClick", function()
        if card.eventId and C.RemoveEvent then C:RemoveEvent(card.eventId) end
    end)
    card.closeBtn = closeBtn

    card:SetScript("OnEnter", function(self)
        if not card.eventId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(card.description or "", unpack(UI.colors.title))
        local turnWord = (card.turnsLeft > 1) and "tours" or "tour"
        GameTooltip:AddLine(card.turnsLeft .. " " .. turnWord .. " de table restant" .. ((card.turnsLeft > 1) and "s" or ""), unpack(UI.colors.textMuted))
        if card.repeatable then
            GameTooltip:AddLine("Répétable : se relance toutes les " .. (card.interval or "?") .. " tours de table.", unpack(UI.colors.textMuted))
        end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)

    function card:Refresh(e)
        card.eventId     = e.id
        card.description = e.description
        card.turnsLeft   = e.turnsLeft
        card.repeatable  = e.repeatable
        card.interval    = e.interval
        turnsFS:SetText(tostring(e.turnsLeft))
        repeatIcon:SetShown(e.repeatable and true or false)
    end

    return card
end

local function GetEventCard(i)
    if not eventCards[i] then eventCards[i] = MakeEventCard(banner) end
    return eventCards[i]
end

-- ── Popup "Ajouter un évènement" ─────────────────────────────────────────────
-- Ouverte soit via le "+" d'une carte (évènement accroché à ce participant,
-- décompté sur SES tours), soit via le "+ Évt" du header (évènement général,
-- décompté une fois par tour de table complet peu importe qui joue) : décrit
-- un évènement annoncé en /rw une fois le compte à rebours écoulé (voir
-- C:AddEvent / TickEventsFor côté Core.lua). "Répétable" : au lieu d'être
-- retiré au déclenchement, il se relance pour le même nombre de tours (ex.
-- une bourrasque récurrente qu'on retire manuellement une fois le boss
-- vaincu) — sinon c'est un évènement ponctuel (ex. une bombe qui explose une
-- fois).

local eventPopupTarget = nil    -- id du participant visé, ou nil si évènement général
local eventPopupOpen   = false  -- distingue "pas de popup ouvert" de "cible générale (nil)"

local eventPopup = CreateFrame("Frame", nil, banner)
eventPopup:SetSize(220, 234)
eventPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
eventPopup:SetFrameStrata("DIALOG")
eventPopup:SetMovable(true)
eventPopup:SetClampedToScreen(true)
eventPopup:EnableMouse(true)
eventPopup:Hide()

local eventPopupBg = eventPopup:CreateTexture(nil, "BACKGROUND")
eventPopupBg:SetAllPoints()
UI.ApplyWindowBackground(eventPopupBg, 0.95)
UI.ApplyBorder(eventPopup)

local eventPopupBar = CreateFrame("Frame", nil, eventPopup)
eventPopupBar:SetPoint("TOPLEFT"); eventPopupBar:SetPoint("TOPRIGHT")
eventPopupBar:SetHeight(20)
eventPopupBar:EnableMouse(true)
eventPopupBar:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then eventPopup:StartMoving() end end)
eventPopupBar:SetScript("OnMouseUp", function() eventPopup:StopMovingOrSizing() end)

local eventPopupBarBg = eventPopupBar:CreateTexture(nil, "BACKGROUND")
eventPopupBarBg:SetAllPoints()
eventPopupBarBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local eventPopupTitle = eventPopupBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
eventPopupTitle:SetPoint("LEFT", eventPopupBar, "LEFT", 8, 0)
eventPopupTitle:SetText("Ajouter un évènement")
UI.ApplyTitle(eventPopupTitle)

local eventForLbl = eventPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
eventForLbl:SetPoint("TOPLEFT", eventPopupBar, "BOTTOMLEFT", 10, -8)
eventForLbl:SetPoint("RIGHT", eventPopup, "RIGHT", -10, 0)
eventForLbl:SetJustifyH("LEFT")
eventForLbl:SetWordWrap(false)
UI.ApplyMutedText(eventForLbl)

local eventDescLbl = eventPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
eventDescLbl:SetPoint("TOPLEFT", eventForLbl, "BOTTOMLEFT", 0, -8)
eventDescLbl:SetText("Description")
UI.ApplyLabel(eventDescLbl)

local eventDescEB = UI.CreateStyledEditBox(eventPopup, 200, 44, true)
eventDescEB:SetPoint("TOPLEFT", eventDescLbl, "BOTTOMLEFT", 0, -4)
eventDescEB:SetMaxLetters(200)

local eventTurnsLbl = eventPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
eventTurnsLbl:SetPoint("TOPLEFT", eventDescEB, "BOTTOMLEFT", 0, -8)
eventTurnsLbl:SetText("Dans combien de tours")
UI.ApplyLabel(eventTurnsLbl)

local eventTurnsEB = UI.CreateStyledEditBox(eventPopup, 50, 22)
eventTurnsEB:SetNumeric(true)
eventTurnsEB:SetMaxLetters(3)
eventTurnsEB:SetPoint("TOPLEFT", eventTurnsLbl, "BOTTOMLEFT", 0, -4)

local eventRepeatCB = UI.CreateStyledCheckbox(eventPopup, "Répétable (se relance)")
eventRepeatCB:SetPoint("TOPLEFT", eventTurnsEB, "BOTTOMLEFT", 2, -12)
eventRepeatCB.label:SetPoint("LEFT", eventRepeatCB, "RIGHT", 5, 0)
eventRepeatCB:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Une fois déclenché, l'évènement se relance pour le même nombre de tours au lieu d'être retiré.", unpack(UI.colors.textMuted))
    GameTooltip:AddLine("Ex. une bourrasque toutes les 3 tours jusqu'à ce que vous le retiriez (bouton × sur sa carte).", unpack(UI.colors.textMuted))
    GameTooltip:Show()
end)
eventRepeatCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

local eventConfirmBtn = UI.CreatePanelButton(eventPopup, 200, 20, "Ajouter")
eventConfirmBtn:SetPoint("TOPLEFT", eventRepeatCB, "BOTTOMLEFT", -2, -16)

local function CloseEventPopup()
    eventPopup:Hide()
    eventDescEB:SetText("")
    eventTurnsEB:SetText("")
    eventRepeatCB:SetChecked(false)
    eventPopupTarget = nil
    eventPopupOpen   = false
end

local eventPopupCloseBtn = UI.CreateCloseButton(eventPopup, function() CloseEventPopup() end)
eventPopupCloseBtn:ClearAllPoints()
eventPopupCloseBtn:SetPoint("TOPRIGHT", eventPopup, "TOPRIGHT", -3, -3)
eventPopupCloseBtn:SetSize(18, 16)
eventPopupCloseBtn:SetFrameLevel(eventPopup:GetFrameLevel() + 50)

eventConfirmBtn:SetScript("OnClick", function()
    local desc  = eventDescEB:GetText()
    local turns = eventTurnsEB:GetText()
    if eventPopupOpen and desc and desc:match("%S") and turns and turns ~= "" then
        if C:AddEvent(eventPopupTarget, desc, turns, eventRepeatCB:GetChecked()) then
            CloseEventPopup()
        end
    end
end)

-- participantId nil => évènement général, dissocié de tout participant
-- (bouton "+ Évt" du header) ; sinon accroché aux tours de ce participant
-- précis (bouton "+" de sa carte, visible seulement pendant son tour).
-- Rien n'empêche de rouvrir ce popup plusieurs fois pour la même cible :
-- chaque validation empile un évènement de plus (badge sur la carte pour un
-- participant, carte dédiée de plus pour un général — voir Rebuild).
OpenEventPopup = function(participantId)
    if not C.initiative.isHost or not C.initiative.active then return end
    local label
    if participantId then
        local p = FindParticipantById(participantId)
        if not p then return end
        label = ParticipantLabel(p)
    else
        label = "Tout le monde (par tour de table)"
    end
    eventPopupTarget = participantId
    eventPopupOpen   = true
    eventForLbl:SetText("Pour : " .. label)
    eventDescEB:SetText("")
    eventTurnsEB:SetText("")
    eventRepeatCB:SetChecked(false)
    eventPopup:Show()
    eventDescEB:SetFocus()
end

-- ── Popup "Ajouter un état" ──────────────────────────────────────────────────
-- Contrairement à "Ajouter un évènement" (hôte uniquement), accessible à
-- TOUT LE MONDE depuis le "+ État" du header : n'importe qui applique un
-- effet à une ou plusieurs cibles (voir C:RequestAddStatus côté Core.lua),
-- annoncé en privé à chacune seulement quand le bandeau arrive sur son tour
-- (jamais un message de groupe, contrairement à un évènement). La liste de
-- cibles ne montre que nom + icone, jamais plus : les joueurs ne voyant déjà
-- pas le détail des PNJ ailleurs, ce panneau reste volontairement minimal
-- pour tout le monde, MJ compris.

local statusSelected = {}  -- targetId => true, cibles cochées dans le popup ouvert

local STATUS_ROW_H, STATUS_ROW_GAP = 16, 2

local function MakeStatusTargetRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(STATUS_ROW_H)
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")

    local bgTex = row:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(unpack(UI.colors.rowBg))
    row.bgTex = bgTex

    local selectedTex = row:CreateTexture(nil, "BORDER")
    selectedTex:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    selectedTex:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    selectedTex:SetColorTexture(unpack(UI.colors.rowSelection))
    selectedTex:Hide()
    row.selectedTex = selectedTex

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.icon = icon

    local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameTxt:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameTxt:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    nameTxt:SetJustifyH("LEFT")
    nameTxt:SetWordWrap(false)
    UI.ApplyBodyText(nameTxt)
    row.nameTxt = nameTxt

    function row:SetSelected(isOn)
        if isOn then
            selectedTex:Show()
            bgTex:SetColorTexture(unpack(UI.colors.rowBgSelected))
        else
            selectedTex:Hide()
            bgTex:SetColorTexture(unpack(UI.colors.rowBg))
        end
    end

    row:SetScript("OnClick", function()
        if not row.participantId then return end
        statusSelected[row.participantId] = not statusSelected[row.participantId] or nil
        row:SetSelected(statusSelected[row.participantId])
        if RefreshSelectedCount then RefreshSelectedCount() end
    end)

    function row:Refresh(p)
        row.participantId = p.id
        nameTxt:SetText(ParticipantLabel(p))
        SetParticipantIcon(icon, p)
        row:SetSelected(statusSelected[p.id])
    end

    return row
end

local statusPopup = CreateFrame("Frame", nil, banner)
statusPopup:SetSize(220, 215)
statusPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
statusPopup:SetFrameStrata("DIALOG")
statusPopup:SetMovable(true)
statusPopup:SetClampedToScreen(true)
statusPopup:EnableMouse(true)
statusPopup:Hide()

local statusPopupBg = statusPopup:CreateTexture(nil, "BACKGROUND")
statusPopupBg:SetAllPoints()
UI.ApplyWindowBackground(statusPopupBg, 0.95)
UI.ApplyBorder(statusPopup)

local statusPopupBar = CreateFrame("Frame", nil, statusPopup)
statusPopupBar:SetPoint("TOPLEFT"); statusPopupBar:SetPoint("TOPRIGHT")
statusPopupBar:SetHeight(20)
statusPopupBar:EnableMouse(true)
statusPopupBar:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then statusPopup:StartMoving() end end)
statusPopupBar:SetScript("OnMouseUp", function() statusPopup:StopMovingOrSizing() end)

local statusPopupBarBg = statusPopupBar:CreateTexture(nil, "BACKGROUND")
statusPopupBarBg:SetAllPoints()
statusPopupBarBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local statusPopupTitle = statusPopupBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusPopupTitle:SetPoint("LEFT", statusPopupBar, "LEFT", 8, 0)
statusPopupTitle:SetText("Ajouter un état")
UI.ApplyTitle(statusPopupTitle)

local statusTargetsLbl = statusPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusTargetsLbl:SetPoint("TOPLEFT", statusPopupBar, "BOTTOMLEFT", 10, -6)
statusTargetsLbl:SetText("Cible(s)")
UI.ApplyLabel(statusTargetsLbl)

-- Ouvre/ferme le panneau "Cibles" à droite (voir plus bas) : la sélection
-- elle-même se fait là-bas (nom + icone seulement, joueurs et PNJ), ce popup-
-- ci ne montre que le résultat (voir statusCountFS).
local chooseTargetsBtn = UI.CreatePanelButton(statusPopup, 200, 20, "Choisir vos cibles...")
chooseTargetsBtn:SetPoint("TOPLEFT", statusTargetsLbl, "BOTTOMLEFT", 0, -3)
chooseTargetsBtn:SetScript("OnClick", function()
    if ToggleTargetsPanel then ToggleTargetsPanel() end
end)

local statusCountFS = statusPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusCountFS:SetPoint("TOPLEFT", chooseTargetsBtn, "BOTTOMLEFT", 2, -4)
statusCountFS:SetJustifyH("LEFT")
UI.ApplyMutedText(statusCountFS)

RefreshSelectedCount = function()
    local n = 0
    for _ in pairs(statusSelected) do n = n + 1 end
    statusCountFS:SetText(n == 0 and "Aucune cible sélectionnée" or (tostring(n) .. " cible(s) sélectionnée(s)"))
end
RefreshSelectedCount()

local statusDescLbl = statusPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusDescLbl:SetPoint("TOPLEFT", statusCountFS, "BOTTOMLEFT", -2, -6)
statusDescLbl:SetText("État")
UI.ApplyLabel(statusDescLbl)

local statusDescEB = UI.CreateStyledEditBox(statusPopup, 200, 36, true)
statusDescEB:SetPoint("TOPLEFT", statusDescLbl, "BOTTOMLEFT", 0, -3)
statusDescEB:SetMaxLetters(200)

local statusTurnsLbl = statusPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusTurnsLbl:SetPoint("TOPLEFT", statusDescEB, "BOTTOMLEFT", 0, -6)
statusTurnsLbl:SetText("Pendant combien de tours")
UI.ApplyLabel(statusTurnsLbl)

local statusTurnsEB = UI.CreateStyledEditBox(statusPopup, 50, 22)
statusTurnsEB:SetNumeric(true)
statusTurnsEB:SetMaxLetters(3)
statusTurnsEB:SetPoint("TOPLEFT", statusTurnsLbl, "BOTTOMLEFT", 0, -3)

local statusConfirmBtn = UI.CreatePanelButton(statusPopup, 200, 20, "Valider")
statusConfirmBtn:SetPoint("TOPLEFT", statusTurnsEB, "BOTTOMLEFT", -2, -10)

-- ── Panneau "Cibles" (à droite du popup ci-dessus) ───────────────────────────
-- Ouvert/fermé via "Choisir vos cibles..." : liste TOUTES les cibles
-- disponibles, nom + icone seulement, réparties en deux groupes (joueurs,
-- PNJ). La sélection (statusSelected, partagée) se fait directement ici en
-- cliquant une ligne — voir MakeStatusTargetRow.

local statusTargetsPanel = CreateFrame("Frame", nil, banner)
statusTargetsPanel:SetSize(180, 60)
statusTargetsPanel:SetPoint("TOPLEFT", statusPopup, "TOPRIGHT", 4, 0)
statusTargetsPanel:SetFrameStrata("DIALOG")
statusTargetsPanel:SetMovable(true)
statusTargetsPanel:SetClampedToScreen(true)
statusTargetsPanel:EnableMouse(true)
statusTargetsPanel:Hide()

local statusTargetsPanelBg = statusTargetsPanel:CreateTexture(nil, "BACKGROUND")
statusTargetsPanelBg:SetAllPoints()
UI.ApplyWindowBackground(statusTargetsPanelBg, 0.95)
UI.ApplyBorder(statusTargetsPanel)

local statusTargetsPanelBar = CreateFrame("Frame", nil, statusTargetsPanel)
statusTargetsPanelBar:SetPoint("TOPLEFT"); statusTargetsPanelBar:SetPoint("TOPRIGHT")
statusTargetsPanelBar:SetHeight(20)
statusTargetsPanelBar:EnableMouse(true)
statusTargetsPanelBar:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then statusTargetsPanel:StartMoving() end end)
statusTargetsPanelBar:SetScript("OnMouseUp", function() statusTargetsPanel:StopMovingOrSizing() end)

local statusTargetsPanelBarBg = statusTargetsPanelBar:CreateTexture(nil, "BACKGROUND")
statusTargetsPanelBarBg:SetAllPoints()
statusTargetsPanelBarBg:SetColorTexture(unpack(UI.colors.panelButtonBg))

local statusTargetsPanelTitle = statusTargetsPanelBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusTargetsPanelTitle:SetPoint("LEFT", statusTargetsPanelBar, "LEFT", 8, 0)
statusTargetsPanelTitle:SetText("Cibles")
UI.ApplyTitle(statusTargetsPanelTitle)

local statusTargetsPanelCloseBtn = UI.CreateCloseButton(statusTargetsPanel, function() statusTargetsPanel:Hide() end)
statusTargetsPanelCloseBtn:ClearAllPoints()
statusTargetsPanelCloseBtn:SetPoint("TOPRIGHT", statusTargetsPanel, "TOPRIGHT", -3, -3)
statusTargetsPanelCloseBtn:SetSize(18, 16)
statusTargetsPanelCloseBtn:SetFrameLevel(statusTargetsPanel:GetFrameLevel() + 50)

local playersHeaderFS = statusTargetsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
playersHeaderFS:SetText("Groupe de joueurs")
UI.ApplyLabel(playersHeaderFS)

local npcHeaderFS = statusTargetsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
npcHeaderFS:SetText("Groupe de PNJ")
UI.ApplyLabel(npcHeaderFS)

-- Deux pools de lignes distincts (une par groupe) : positionnées à la volée
-- en y absolu (pas de chaînage d'ancres) puisque le nombre de joueurs et de
-- PNJ varie indépendamment d'un combat à l'autre — voir RefreshTargetsPanel.
local statusPlayerRows = {}
local statusNpcRows    = {}

local function GetPooledRow(pool, i)
    if not pool[i] then pool[i] = MakeStatusTargetRow(statusTargetsPanel) end
    return pool[i]
end

local function RefreshTargetsPanel()
    local players, npcs = {}, {}
    for _, p in ipairs(C.initiative.participants or {}) do
        table.insert(p.kind == "npc" and npcs or players, p)
    end

    local y = -26
    playersHeaderFS:SetShown(#players > 0)
    if #players > 0 then
        playersHeaderFS:ClearAllPoints()
        playersHeaderFS:SetPoint("TOPLEFT", statusTargetsPanel, "TOPLEFT", 8, y)
        y = y - 14
        for i, p in ipairs(players) do
            local row = GetPooledRow(statusPlayerRows, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", statusTargetsPanel, "TOPLEFT", 8, y)
            row:SetPoint("RIGHT", statusTargetsPanel, "RIGHT", -8, 0)
            row:Refresh(p)
            row:Show()
            y = y - (STATUS_ROW_H + STATUS_ROW_GAP)
        end
        y = y - 6
    end
    for i = #players + 1, #statusPlayerRows do statusPlayerRows[i]:Hide() end

    npcHeaderFS:SetShown(#npcs > 0)
    if #npcs > 0 then
        npcHeaderFS:ClearAllPoints()
        npcHeaderFS:SetPoint("TOPLEFT", statusTargetsPanel, "TOPLEFT", 8, y)
        y = y - 14
        for i, p in ipairs(npcs) do
            local row = GetPooledRow(statusNpcRows, i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", statusTargetsPanel, "TOPLEFT", 8, y)
            row:SetPoint("RIGHT", statusTargetsPanel, "RIGHT", -8, 0)
            row:Refresh(p)
            row:Show()
            y = y - (STATUS_ROW_H + STATUS_ROW_GAP)
        end
    end
    for i = #npcs + 1, #statusNpcRows do statusNpcRows[i]:Hide() end

    statusTargetsPanel:SetHeight(math.max(50, -y + 8))
end

ToggleTargetsPanel = function()
    if statusTargetsPanel:IsShown() then
        statusTargetsPanel:Hide()
        return
    end
    RefreshTargetsPanel()
    statusTargetsPanel:Show()
end

local function CloseStatusPopup()
    statusPopup:Hide()
    statusTargetsPanel:Hide()
    statusDescEB:SetText("")
    statusTurnsEB:SetText("")
    statusSelected = {}
    for _, row in ipairs(statusPlayerRows) do row:SetSelected(false) end
    for _, row in ipairs(statusNpcRows) do row:SetSelected(false) end
    RefreshSelectedCount()
end

local statusPopupCloseBtn = UI.CreateCloseButton(statusPopup, function() CloseStatusPopup() end)
statusPopupCloseBtn:ClearAllPoints()
statusPopupCloseBtn:SetPoint("TOPRIGHT", statusPopup, "TOPRIGHT", -3, -3)
statusPopupCloseBtn:SetSize(18, 16)
statusPopupCloseBtn:SetFrameLevel(statusPopup:GetFrameLevel() + 50)

statusConfirmBtn:SetScript("OnClick", function()
    local targets = {}
    for id in pairs(statusSelected) do table.insert(targets, id) end
    local text  = statusDescEB:GetText()
    local turns = statusTurnsEB:GetText()
    if #targets > 0 and text and text:match("%S") and turns and turns ~= "" then
        if C:RequestAddStatus(targets, text, turns) then
            CloseStatusPopup()
        end
    end
end)

-- Point d'entrée public (bouton "+ État" dans la Vue joueur — UI_Group.lua —
-- et le Gestionnaire de ressources de la Vue MJ — UI_MJ.lua). Renvoie false
-- sans rien ouvrir si le combat n'est pas actif, pour que l'appelant puisse
-- afficher son propre message ("Combat non démarré") dans son propre panneau.
function C:OpenStatusPopup()
    if not C.initiative.active then return false end
    statusSelected = {}
    statusDescEB:SetText("")
    statusTurnsEB:SetText("")
    RefreshSelectedCount()
    statusTargetsPanel:Hide()
    statusPopup:Show()
    statusDescEB:SetFocus()
    return true
end

-- ── Rendu ─────────────────────────────────────────────────────────────────────

-- HP courants d'un participant : lus directement sur le PNJ (hp embarqué
-- dans l'initiative), ou sur la fiche du joueur (MyChar / groupData — les
-- joueurs ne portent pas leur bloc HP dans C.initiative.participants).
-- HP inconnu (pas encore synchronisé) => on ne masque pas, par défaut visible.
local function GetHP(p)
    if p.kind == "npc" then
        return p.hp and p.hp.cur
    end
    local data = (p.id == UnitName("player")) and C:GetMyChar() or C.groupData[p.id]
    return data and data.hp and data.hp.cur
end

local function IsAlive(p)
    local hp = GetHP(p)
    return not hp or hp > 0
end

local function Rebuild()
    local st = C.initiative
    local participants = st.participants or {}
    local current = participants[st.currentIndex]

    addGlobalEventBtn:SetShown(st.isHost)

    for _, card in ipairs(cards) do card:Hide() end
    for _, ec in ipairs(eventCards) do ec:Hide() end

    -- À 0 HP, le participant disparaît de la bannière (mais reste dans
    -- C.initiative.participants — l'ordre du tour n'est pas affecté) ; il
    -- réapparaît dès que ses HP repassent au-dessus de 0. L'index de carte
    -- (cardIndex) est donc distinct de l'index dans la liste complète : la
    -- surbrillance "tour en cours" compare directement les participants
    -- (référence de table), pas leur position, pour rester correcte même
    -- quand des cartes sont sautées.
    local x = INPUT_W + 20
    local cardIndex = 0
    for _, p in ipairs(participants) do
        if IsAlive(p) then
            cardIndex = cardIndex + 1
            local card = GetCard(cardIndex)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", header, "BOTTOMLEFT", x, -5)
            card:Refresh(p, p == current)
            card:Show()
            x = x + CARD_W + CARD_GAP
        end
    end

    -- Évènements généraux (dissociés de tout participant) uniquement : une
    -- carte par évènement en attente, tout à droite de la rangée, après tous
    -- les joueurs/PNJ. Un évènement accroché à un participant précis, lui,
    -- reste un badge sur SA carte (voir eventBadge dans MakeCard). Local à
    -- l'hôte (seul lui gère C.initiative.events) : les autres clients ne
    -- voient tout simplement aucune carte évènement.
    if st.isHost then
        local eventCardIndex = 0
        for _, e in ipairs(st.events or {}) do
            if e.participantId == nil then
                eventCardIndex = eventCardIndex + 1
                local ec = GetEventCard(eventCardIndex)
                ec:ClearAllPoints()
                ec:SetPoint("TOPLEFT", header, "BOTTOMLEFT", x, -5)
                ec:Refresh(e)
                ec:Show()
                x = x + EVENT_CARD_W + CARD_GAP
            end
        end
    end

    banner:SetWidth(math.max(200, x + 6))
end

-- Appelé depuis UI_MJ.lua quand la sélection du Gestionnaire de ressources
-- change (clic sur une ligne joueur/PNJ) : pas de Rebuild complet, juste la
-- surbrillance légère des cartes déjà affichées.
function C:RefreshBannerSelection()
    for _, card in ipairs(cards) do
        if card:IsShown() and card.participantId then
            card:SetSpotlight(C.IsImpactSelected and C:IsImpactSelected(card.participantId))
        end
    end
end

local function Refresh()
    if C.initiative.active then
        Rebuild()
        banner:Show()
    else
        -- Sinon un popup laissé ouvert en fin de combat resurgirait tel
        -- quel (visible, ciblant un participant qui n'existe plus) au
        -- prochain combat démarré.
        CloseEventPopup()
        CloseStatusPopup()
        banner:Hide()
    end
end

local prevInit = C.OnInitiativeChanged
C.OnInitiativeChanged = function()
    if prevInit then prevInit() end
    Refresh()
end

-- Les PNJ portent leurs HP directement dans C.initiative.participants, donc
-- OnInitiativeChanged (déjà déclenché par ApplyNPCDelta/ApplyNPCTemp) suffit
-- pour eux. Les joueurs, eux, ont leurs HP dans MyChar()/C.groupData : il
-- faut aussi rafraîchir sur ces deux évènements pour que la carte
-- disparaisse/réapparaisse en combat sans attendre un autre changement
-- d'initiative.
local prevMine = C.OnMyDataChanged
C.OnMyDataChanged = function()
    if prevMine then prevMine() end
    Refresh()
end

local prevGroup = C.OnGroupDataChanged
C.OnGroupDataChanged = function(name)
    if prevGroup then prevGroup(name) end
    Refresh()
end

banner:SetScript("OnShow", function()
    if C.GetSettings then
        local s = C:GetSettings()
        if s.initiativeScale then banner:SetScale(s.initiativeScale) end
    end
    if not inputEB:HasFocus() then inputEB:SetText("") end
end)
