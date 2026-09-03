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
-- avant sa définition, d'où le forward-declare.
local OpenEventPopup

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
-- Core.lua) et décompte donc une fois par tour de table, jamais sur le tour
-- où il apparaît (contrairement au "+" d'une carte, lié directement aux
-- tours d'UN participant précis). Une fois ajouté, il s'affiche comme une
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

    -- "+" pour rajouter un évènement différé sur CE participant : visible
    -- seulement pendant son tour (c'est le principe demandé : on planifie
    -- l'évènement "dans N tours" à partir de maintenant) et seulement pour
    -- l'hôte du combat (seul C:AddEvent peut réellement l'enregistrer).
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
        GameTooltip:AddLine("Se déclenche (annoncé en /rw) après N tours de ce participant.", unpack(UI.colors.textMuted))
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

    function card:Refresh(p, isCurrent)
        card.participantId = p.id
        initFS:SetText(tostring(p.initiative or 0))
        for _, line in ipairs(glow) do line:SetShown(isCurrent) end

        addEventBtn:SetShown(isCurrent and C.initiative.isHost)

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
