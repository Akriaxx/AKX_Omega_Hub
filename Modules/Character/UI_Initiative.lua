-- ============================================================
--  Character — Bannière Initiative
--  Affichée automatiquement chez tous quand le MJ démarre un combat
-- ============================================================

local C  = Character
local UI = C.RPGUI or OS2.UI

local CARD_W, CARD_H = 48, 60
local CARD_GAP       = 5
local HEADER_H       = 20
local CONTENT_H      = CARD_H + 10
local BANNER_H       = HEADER_H + CONTENT_H
local INPUT_W        = 60
local EVENT_CARD_W   = 40

local cards      = {}
local eventCards = {}

-- Même texture en neuf parties que les cartes de compétences : les coins
-- gardent leur forme quelle que soit la longueur de la frise.
local function ApplyInitiativeFrame(frame)
    UI.RegisterWindowSkin(frame)
end

-- Défini plus bas (popup "Ajouter un évènement") ; référencé depuis MakeCard
-- avant sa définition, d'où le forward-declare. Le popup "Ajouter un état",
-- lui, est exposé en méthode (C:OpenStatusPopup) : ouvert depuis d'autres
-- fichiers (UI_Group.lua — Vue joueur, UI_MJ.lua — Gestionnaire de
-- ressources), jamais depuis cette bannière elle-même.
local OpenEventPopup

-- Idem pour le popup "États actifs" (retirer un état) : référencé depuis le
-- OnClick du badge "E" d'une carte (MakeCard), avant sa définition plus bas.
local OpenStatusManagePopup

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

-- Texte de décompte d'un état pour l'infobulle du badge "E" / le popup
-- "États actifs" : "(terminé)" une fois `expired` (voir TickStatusesFor côté
-- Core.lua — l'état reste affiché jusqu'à la fin du tour de sa cible plutôt
-- que d'être retiré instantanément à 0), sinon "(N tour[s])".
local function StatusCountdownText(s)
    if s.expired then return "(terminé)" end
    local turnWord = (s.turnsLeft > 1) and "tours" or "tour"
    return "(" .. s.turnsLeft .. " " .. turnWord .. ")"
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
bg:SetColorTexture(0,0,0,0)
banner.bg = bg

ApplyInitiativeFrame(banner)

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
headerBg:SetColorTexture(0,0,0,0)

local headerTitle = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerTitle:SetPoint("LEFT", header, "LEFT", 8, 0)
headerTitle:SetText("Initiative")
UI.ApplyTitle(headerTitle)

local headerSep = banner:CreateTexture(nil, "ARTWORK")
headerSep:SetPoint("TOPLEFT", header, "BOTTOMLEFT",10,0)
headerSep:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT",-10,0)
headerSep:SetHeight(1)
UI.ApplySeparator(headerSep, true)

function C:OpenGlobalEventPopup()
    if OpenEventPopup then OpenEventPopup(nil) end
end

-- The start-of-round resolution precedes the participant row.
local function MakeResolutionStep(phase,label)
    local button=CreateFrame("Button",nil,banner)
    button:SetSize(44,BANNER_H)
    ApplyInitiativeFrame(button)
    local symbol=button:CreateTexture(nil,"OVERLAY")
    symbol:SetSize(34,34);symbol:SetPoint("CENTER",0,-2)
    symbol:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\ResolutionHourglass.tga")
    local elapsed=0
    local function DrawHourglass(frame)
        local col,row=frame%8,math.floor(frame/8)
        symbol:SetTexCoord(col/8,(col+1)/8,row/8,(row+1)/8)
    end
    DrawHourglass(0)
    local function AnimateHourglass(_,dt)
        elapsed=(elapsed+dt)%3.2
        DrawHourglass(math.floor(elapsed/3.2*64))
    end
    local validate=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    validate:SetPoint("BOTTOM",0,10);validate:SetText("Valider")
    UI.ApplyTitle(validate);validate:Hide()
    local selected=button:CreateTexture(nil,"ARTWORK")
    selected:SetPoint("TOPLEFT",8,-22);selected:SetPoint("BOTTOMRIGHT",-8,8)
    selected:SetColorTexture(.78,.59,.24,.10)
    selected:Hide()
    button:SetScript("OnClick",function()
        if C.initiative.isHost and C.initiative.phase==phase then C:NextTurn() end
    end)
    button:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:AddLine("Résolution d'états — "..label,unpack(UI.colors.title))
        if C.initiative.phase==phase then
            GameTooltip:AddLine(C.initiative.isHost and "Cliquer pour valider." or "En attente de la validation du MJ.",unpack(UI.colors.text))
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave",function() GameTooltip:Hide() end)
    function button:Refresh()
        local active=C.initiative.phase==phase
        selected:SetShown(active)
        validate:SetShown(active and C.initiative.isHost)
        self:SetScript("OnUpdate",active and AnimateHourglass or nil)
        if not active then elapsed=0;DrawHourglass(0) end
        self:SetAlpha(active and 1 or .55)
    end
    button:SetScript("OnHide",function(self) self:SetScript("OnUpdate",nil);elapsed=0;DrawHourglass(0) end)
    button:SetScript("OnShow",function(self) self:Refresh() end)
    return button
end
local startResolution=MakeResolutionStep("resolve_start","entre deux tours")
startResolution:SetSize(44,BANNER_H)
startResolution:SetPoint("TOPLEFT",banner,"TOPRIGHT",6,0)
local stateHeading=startResolution:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
stateHeading:SetPoint("CENTER",startResolution,"TOP",0,-HEADER_H/2)
stateHeading:SetText("États");UI.ApplyTitle(stateHeading)

-- ── Saisie "Initiative" (à gauche) ───────────────────────────────────────────

local inputLabel = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
inputLabel:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 8, -16)
inputLabel:SetWidth(INPUT_W)
inputLabel:SetHeight(12)
inputLabel:SetJustifyH("CENTER")
inputLabel:SetText("Ma valeur")
UI.ApplyLabel(inputLabel)

local inputEB = UI.CreateStyledEditBox(banner, INPUT_W, 22)
inputEB:SetNumeric(true)
inputEB:SetMaxLetters(4)
inputEB:SetPoint("TOPLEFT", inputLabel, "BOTTOMLEFT", 0, -6)
inputEB:SetJustifyH("CENTER")

inputEB:SetScript("OnEnterPressed", function(self)
    local v = self:GetText()
    if v and v ~= "" then C:SubmitMyInitiative(v) end
    self:ClearFocus()
end)

local inputSep = banner:CreateTexture(nil, "ARTWORK")
inputSep:SetPoint("TOPLEFT", header, "BOTTOMLEFT", INPUT_W + 16, -8)
inputSep:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", INPUT_W + 16, 8)
inputSep:SetWidth(1)
UI.ApplySeparator(inputSep, true)

-- ── Cartes participants ──────────────────────────────────────────────────────

local function MakeCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(CARD_W, CARD_H)

    local cbg = card:CreateTexture(nil, "BACKGROUND")
    cbg:SetAllPoints()
    cbg:SetColorTexture(0,0,0,0)
    ApplyInitiativeFrame(card)

    -- Surbrillance légère quand ce participant est sélectionné dans le
    -- Gestionnaire de ressources (Vue MJ) : juste un repère visuel pour le
    -- MJ, distinct du cadre cyan "tour en cours".
    local spotlight = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    spotlight:SetAllPoints()
    spotlight:SetColorTexture(unpack(UI.colors.rowSelection))
    spotlight:Hide()
    card.spotlight = spotlight
    function card:SetSpotlight(isOn) spotlight:SetShown(isOn) end

    local iconMask = card:CreateMaskTexture()
    iconMask:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    iconMask:SetSize(CARD_W - 8, CARD_W - 8)
    iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", card, "TOPLEFT", 4, -4)
    icon:SetSize(CARD_W - 8, CARD_W - 8)
    icon:AddMaskTexture(iconMask)
    card.icon = icon
    local portraitRim=card:CreateTexture(nil,"OVERLAY")
    portraitRim:SetSize(CARD_W-5,CARD_W-5)
    portraitRim:SetPoint("CENTER",icon,"CENTER",0,0)
    portraitRim:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\InitiativeRing.tga")

    local valuePlate=card:CreateTexture(nil,"ARTWORK")
    valuePlate:SetPoint("BOTTOMLEFT",12,4);valuePlate:SetPoint("BOTTOMRIGHT",-12,4)
    valuePlate:SetHeight(15);valuePlate:SetColorTexture(.018,.026,.039,.96)
    local valueRule=card:CreateTexture(nil,"ARTWORK")
    valueRule:SetPoint("BOTTOMLEFT",valuePlate,"BOTTOMLEFT",2,0)
    valueRule:SetPoint("BOTTOMRIGHT",valuePlate,"BOTTOMRIGHT",-2,0)
    valueRule:SetHeight(1);valueRule:SetColorTexture(.72,.57,.32,.8)

    -- Juste la valeur d'initiative suffit, pas besoin du nom.
    local initFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    initFS:SetPoint("TOPLEFT", card, "TOPLEFT", 2, -(CARD_W - 4))
    initFS:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -(CARD_W - 4))
    initFS:SetJustifyH("CENTER")
    initFS:SetWordWrap(false)
    UI.ApplyTitle(initFS)
    initFS:SetShadowColor(0,0,0,1);initFS:SetShadowOffset(1,-1)
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
    addEventBtn:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 2)
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
    eventBadge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -1, 2)
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
    -- l'hôte. L'infobulle liste chaque état et qui l'a appliqué ; un clic
    -- ouvre le popup "États actifs" (voir OpenStatusManagePopup plus bas) qui
    -- permet, si on y est autorisé, de les retirer (bouton × sur chaque
    -- ligne) : la cible elle-même peut se "soigner", l'hôte du combat peut
    -- retirer l'état de n'importe qui.
    local statusBadge = CreateFrame("Frame", nil, card)
    statusBadge:SetSize(19, 19)
    statusBadge:SetPoint("TOPLEFT", card, "TOPLEFT", -2, 2)
    statusBadge:EnableMouse(true)
    local sbBg = statusBadge:CreateTexture(nil, "BACKGROUND")
    sbBg:SetAllPoints()
    sbBg:SetColorTexture(unpack(UI.colors.panelButtonBg))
    local stateIcon=statusBadge:CreateTexture(nil,"OVERLAY")
    stateIcon:SetAllPoints()
    stateIcon:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\StateSigil.tga")
    statusBadge:SetScript("OnEnter", function(self)
        if not card.participantId then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("États actifs", unpack(UI.colors.title))
        for _, s in ipairs(C.initiative.statuses or {}) do
            if s.targetId == card.participantId then
                local sourceLabel = (C.GetDisplayName and C:GetDisplayName(s.source, C.groupData[s.source])) or s.source
                GameTooltip:AddLine(s.text .. "  " .. StatusCountdownText(s), unpack(UI.colors.textMuted))
                GameTooltip:AddLine("— par " .. sourceLabel, unpack(UI.colors.textMuted))
            end
        end
        GameTooltip:AddLine("Clic pour retirer un état", unpack(UI.colors.textMuted))
        GameTooltip:Show()
    end)
    statusBadge:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Simple Frame (pas un Button) : OnMouseUp plutôt que OnClick, qui n'a
    -- d'effet que sur les widgets de type Button.
    statusBadge:SetScript("OnMouseUp", function(self)
        if not card.participantId then return end
        if OpenStatusManagePopup then OpenStatusManagePopup(card.participantId, self) end
    end)
    statusBadge:Hide()
    card.statusBadge = statusBadge

    function card:Refresh(p, isCurrent)
        card.participantId = p.id
        initFS:SetText(tostring(p.initiative or 0))
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

-- ── Cadre "Tour" ──────────────────────────────────────────────────────────────
-- Nombre de tours de table complets écoulés depuis le début du combat
-- (C.initiative.round, synchronisé — voir NextTurn côté Core.lua). Affiché
-- chez tout le monde, pas seulement l'hôte. Panneau à PART ENTIÈRE, en dehors
-- du bandeau, accroché à sa droite (pas une carte de plus dans la rangée) —
-- suit donc automatiquement la largeur variable du bandeau (SetWidth dans
-- Rebuild) via son ancre TOPRIGHT. Enfant de `banner` : se montre/cache et se
-- redimensionne (SetScale, voir Settings.lua) avec lui automatiquement.

local ROUND_BOX_W = 54

local roundBox = CreateFrame("Frame", nil, banner)
roundBox:SetSize(ROUND_BOX_W, BANNER_H)
roundBox:SetPoint("TOPLEFT", startResolution, "TOPRIGHT", 6, 0)

local roundBoxBg = roundBox:CreateTexture(nil, "BACKGROUND")
roundBoxBg:SetAllPoints()
roundBoxBg:SetColorTexture(0,0,0,0)
roundBox.bg = roundBoxBg
ApplyInitiativeFrame(roundBox)
banner.roundBox = roundBox

local roundLabel = roundBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
roundLabel:SetPoint("CENTER", roundBox, "TOP", 0, -HEADER_H / 2)
roundLabel:SetText("Tour")
UI.ApplyLabel(roundLabel)

local roundValue = roundBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
roundValue:SetPoint("CENTER", roundBox, "CENTER", 0, -HEADER_H / 2)
roundValue:SetFontObject("GameFontNormalLarge")
UI.ApplyBodyText(roundValue)

-- Two-number rolling counter. Only runs while changing rounds.
local outgoingRound=roundBox:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
UI.ApplyBodyText(outgoingRound)
outgoingRound:Hide()
local lastKnownRound
local function PlaceRound(text,offset)
    text:ClearAllPoints()
    text:SetPoint("CENTER",roundBox,"CENTER",0,-HEADER_H/2+offset)
end
local function FinishRoundMotion()
    roundBox:SetScript("OnUpdate",nil)
    outgoingRound:Hide()
    roundValue:SetAlpha(1)
    PlaceRound(roundValue,0)
end
function roundBox:Refresh()
    local newRound=C.initiative.round or 0
    if newRound==lastKnownRound then return end
    local previous=lastKnownRound
    lastKnownRound=newRound
    FinishRoundMotion()
    roundValue:SetText(tostring(newRound))
    if previous==nil then return end
    outgoingRound:SetText(tostring(previous))
    outgoingRound:SetAlpha(1);PlaceRound(outgoingRound,0);outgoingRound:Show()
    roundValue:SetAlpha(0);PlaceRound(roundValue,24)
    local elapsed=-.28
    self:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        if elapsed<0 then return end
        local t=math.min(1,elapsed/.55)
        -- Ease-out back: a small overshoot below the resting position.
        local u=t-1
        local progress=1+2.1*u*u*u+1.1*u*u
        PlaceRound(roundValue,24*(1-progress))
        roundValue:SetAlpha(math.min(1,t*3))
        local exit=math.min(1,elapsed/.30)
        PlaceRound(outgoingRound,-22*exit*exit)
        outgoingRound:SetAlpha(1-exit)
        if t>=1 then FinishRoundMotion() end
    end)
end
function roundBox:ResetTracking()
    lastKnownRound=nil
    FinishRoundMotion()
end
roundBox:SetScript("OnHide",function() roundBox:ResetTracking() end)

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
eventPopup:SetSize(240, 202)
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
eventPopupBarBg:SetColorTexture(0,0,0,0)

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

-- A fixed viewport keeps the multiline editor from collapsing when empty.
local eventDescArea=CreateFrame("ScrollFrame",nil,eventPopup)
eventDescArea:SetSize(220,56)
eventDescArea:SetPoint("TOPLEFT",eventPopup,"TOPLEFT",10,-64)
eventDescArea:EnableMouseWheel(true)
local descBackground=eventDescArea:CreateTexture(nil,"BACKGROUND")
descBackground:SetAllPoints();descBackground:SetColorTexture(.015,.02,.023,.95)
UI.ApplyInputBorder(eventDescArea)
local eventDescEB=CreateFrame("EditBox",nil,eventDescArea)
eventDescEB:SetWidth(208);eventDescEB:SetHeight(44)
eventDescEB:SetMultiLine(true);eventDescEB:SetAutoFocus(false)
eventDescEB:SetFontObject("GameFontHighlightSmall")
eventDescEB:SetTextInsets(6,6,5,5)
eventDescEB:SetMaxLetters(200)
eventDescArea:SetScrollChild(eventDescEB)
eventDescEB:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
eventDescEB:SetScript("OnCursorChanged",function(_,_,y,_,height)
    local top=math.abs(y)
    local scroll=eventDescArea:GetVerticalScroll()
    if top<scroll then eventDescArea:SetVerticalScroll(top)
    elseif top+height>scroll+56 then eventDescArea:SetVerticalScroll(math.max(0,top+height-56)) end
end)
eventDescArea:SetScript("OnMouseWheel",function(self,delta)
    self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*14)))
end)

local eventTurnsLbl = eventPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
eventTurnsLbl:SetPoint("TOPLEFT", eventDescArea, "BOTTOMLEFT", 0, -8)
eventTurnsLbl:SetText("Dans combien de tours")
UI.ApplyLabel(eventTurnsLbl)

local eventTurnsEB = UI.CreateStyledEditBox(eventPopup, 50, 22)
eventTurnsEB:SetNumeric(true)
eventTurnsEB:SetMaxLetters(3)
eventTurnsEB:SetPoint("TOPLEFT", eventTurnsLbl, "BOTTOMLEFT", 0, -4)

local eventRepeatCB = UI.CreateStyledCheckbox(eventPopup, "Répétable (se relance)")
eventRepeatCB:SetPoint("LEFT", eventTurnsEB, "RIGHT", 12, 0)
eventRepeatCB.label:SetPoint("LEFT", eventRepeatCB, "RIGHT", 5, 0)
eventRepeatCB:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Une fois déclenché, l'évènement se relance pour le même nombre de tours au lieu d'être retiré.", unpack(UI.colors.textMuted))
    GameTooltip:AddLine("Ex. une bourrasque toutes les 3 tours jusqu'à ce que vous le retiriez (bouton × sur sa carte).", unpack(UI.colors.textMuted))
    GameTooltip:Show()
end)
eventRepeatCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

local eventConfirmBtn = UI.CreatePanelButton(eventPopup, 220, 22, "Ajouter")
eventConfirmBtn:SetPoint("BOTTOMLEFT", eventPopup, "BOTTOMLEFT", 10, 10)

local function CloseEventPopup()
    eventPopup:Hide()
    eventDescEB:SetText("")
    eventDescArea:SetVerticalScroll(0)
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
    eventDescArea:SetVerticalScroll(0)
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
statusPopup:SetSize(220, 232)
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
statusPopupBarBg:SetColorTexture(0,0,0,0)

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

local statusDescArea=CreateFrame("ScrollFrame",nil,statusPopup)
statusDescArea:SetSize(200,48)
statusDescArea:SetPoint("TOPLEFT",statusPopup,"TOPLEFT",10,-98)
statusDescArea:EnableMouseWheel(true)
local statusDescBackground=statusDescArea:CreateTexture(nil,"BACKGROUND")
statusDescBackground:SetAllPoints();statusDescBackground:SetColorTexture(.015,.02,.023,.95)
UI.ApplyInputBorder(statusDescArea)
local statusDescEB=CreateFrame("EditBox",nil,statusDescArea)
statusDescEB:SetWidth(200);statusDescEB:SetHeight(48)
statusDescEB:SetMultiLine(true);statusDescEB:SetAutoFocus(false)
statusDescEB:SetFontObject("GameFontHighlightSmall")
statusDescEB:SetTextInsets(6,6,5,5)
statusDescEB:SetMaxLetters(200)
statusDescArea:SetScrollChild(statusDescEB)
statusDescEB:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
-- Tout le cadre donne le focus (sinon seule la ligne de texte réagit).
statusDescArea:EnableMouse(true)
statusDescArea:SetScript("OnMouseDown",function() statusDescEB:SetFocus() end)
statusDescEB:SetScript("OnCursorChanged",function(_,_,y,_,height)
    local top=math.abs(y)
    local scroll=statusDescArea:GetVerticalScroll()
    if top<scroll then statusDescArea:SetVerticalScroll(top)
    elseif top+height>scroll+48 then statusDescArea:SetVerticalScroll(math.max(0,top+height-48)) end
end)
statusDescArea:SetScript("OnMouseWheel",function(self,delta)
    self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*14)))
end)

local statusTurnsLbl = statusPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusTurnsLbl:SetPoint("TOPLEFT", statusDescArea, "BOTTOMLEFT", 0, -6)
statusTurnsLbl:SetText("Pendant combien de tours")
UI.ApplyLabel(statusTurnsLbl)

local statusTurnsEB = UI.CreateStyledEditBox(statusPopup, 50, 22)
statusTurnsEB:SetNumeric(true)
statusTurnsEB:SetMaxLetters(3)
statusTurnsEB:SetPoint("TOPLEFT", statusTurnsLbl, "BOTTOMLEFT", 0, -3)

local statusConfirmBtn = UI.CreatePanelButton(statusPopup, 200, 20, "Valider")
statusConfirmBtn:SetPoint("BOTTOMLEFT", statusPopup, "BOTTOMLEFT", 10, 10)

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
statusTargetsPanelBarBg:SetColorTexture(0,0,0,0)

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
    statusDescArea:SetVerticalScroll(0)
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
    statusDescArea:SetVerticalScroll(0)
    statusTurnsEB:SetText("")
    RefreshSelectedCount()
    statusTargetsPanel:Hide()
    statusPopup:Show()
    statusDescEB:SetFocus()
    return true
end

-- ── Popup "États actifs" (retirer un état) ──────────────────────────────────
-- Ouvert en cliquant le badge "E" d'une carte : liste les états accrochés à
-- CE participant, avec un bouton × pour les retirer — visible seulement si on
-- y est autorisé (voir C:RemoveStatus côté Core.lua) : la cible elle-même
-- peut se "soigner" (ex. retirer un -5 Défense Physique), et l'hôte du combat
-- peut retirer n'importe quel état à n'importe qui. Un simple spectateur voit
-- la liste (comme l'infobulle du badge) mais aucun bouton ×.

local statusManagePopup = CreateFrame("Frame", nil, banner)
statusManagePopup:SetSize(190, 50)
statusManagePopup:SetFrameStrata("DIALOG")
statusManagePopup:SetMovable(true)
statusManagePopup:SetClampedToScreen(true)
statusManagePopup:EnableMouse(true)
statusManagePopup:Hide()

local statusManageBg = statusManagePopup:CreateTexture(nil, "BACKGROUND")
statusManageBg:SetAllPoints()
UI.ApplyWindowBackground(statusManageBg, 0.95)
UI.ApplyBorder(statusManagePopup)

local statusManageBar = CreateFrame("Frame", nil, statusManagePopup)
statusManageBar:SetPoint("TOPLEFT"); statusManageBar:SetPoint("TOPRIGHT")
statusManageBar:SetHeight(20)
statusManageBar:EnableMouse(true)
statusManageBar:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then statusManagePopup:StartMoving() end end)
statusManageBar:SetScript("OnMouseUp", function() statusManagePopup:StopMovingOrSizing() end)

local statusManageBarBg = statusManageBar:CreateTexture(nil, "BACKGROUND")
statusManageBarBg:SetAllPoints()
statusManageBarBg:SetColorTexture(0,0,0,0)

local statusManageTitle = statusManageBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusManageTitle:SetPoint("LEFT", statusManageBar, "LEFT", 8, 0)
statusManageTitle:SetText("États actifs")
UI.ApplyTitle(statusManageTitle)

local statusManageCloseBtn = UI.CreateCloseButton(statusManagePopup, function() statusManagePopup:Hide() end)
statusManageCloseBtn:ClearAllPoints()
statusManageCloseBtn:SetPoint("TOPRIGHT", statusManagePopup, "TOPRIGHT", -3, -3)
statusManageCloseBtn:SetSize(18, 16)
statusManageCloseBtn:SetFrameLevel(statusManagePopup:GetFrameLevel() + 50)

local STATUS_MANAGE_ROW_H = 26

local function MakeStatusManageRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(STATUS_MANAGE_ROW_H)

    local removeBtn = UI.CreateCloseButton(row, nil)
    removeBtn:ClearAllPoints()
    removeBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    removeBtn:SetSize(14, 14)
    row.removeBtn = removeBtn

    local textFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    textFS:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    textFS:SetPoint("RIGHT", removeBtn, "LEFT", -2, 0)
    textFS:SetJustifyH("LEFT")
    textFS:SetWordWrap(false)
    UI.ApplyBodyText(textFS)

    local sourceFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sourceFS:SetPoint("TOPLEFT", textFS, "BOTTOMLEFT", 0, -1)
    sourceFS:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    sourceFS:SetJustifyH("LEFT")
    UI.ApplyMutedText(sourceFS)

    function row:Refresh(st, canRemove)
        textFS:SetText(st.text .. "  " .. StatusCountdownText(st))
        local sourceLabel = (C.GetDisplayName and C:GetDisplayName(st.source, C.groupData[st.source])) or st.source
        sourceFS:SetText("— par " .. sourceLabel)
        removeBtn:SetShown(canRemove)
        removeBtn:SetScript("OnClick", function() C:RequestRemoveStatus(st.id) end)
    end

    return row
end

local statusManageRows   = {}
local statusManageTarget = nil  -- id du participant actuellement affiché

local function GetStatusManageRow(i)
    if not statusManageRows[i] then statusManageRows[i] = MakeStatusManageRow(statusManagePopup) end
    return statusManageRows[i]
end

local function RefreshStatusManagePopup()
    if not statusManageTarget or not statusManagePopup:IsShown() then return end

    local list = {}
    for _, st in ipairs(C.initiative.statuses or {}) do
        if st.targetId == statusManageTarget then table.insert(list, st) end
    end

    -- Plus aucun état sur cette cible (tous retirés/expirés pendant que le
    -- popup était ouvert) : on ferme, sinon une fenêtre vide resterait là.
    if #list == 0 then
        statusManagePopup:Hide()
        return
    end

    local canRemove = C.initiative.isHost or statusManageTarget == UnitName("player")
    local y = -24
    for i, st in ipairs(list) do
        local row = GetStatusManageRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", statusManagePopup, "TOPLEFT", 8, y)
        row:SetPoint("RIGHT", statusManagePopup, "RIGHT", -8, 0)
        row:Refresh(st, canRemove)
        row:Show()
        y = y - (STATUS_MANAGE_ROW_H + 2)
    end
    for i = #list + 1, #statusManageRows do statusManageRows[i]:Hide() end

    statusManagePopup:SetHeight(math.max(50, -y + 8))
end

-- Appelé depuis le OnClick du badge "E" (voir MakeCard) : `anchorFrame` est
-- le badge lui-même, pour ouvrir le popup juste en dessous.
OpenStatusManagePopup = function(participantId, anchorFrame)
    if not participantId then return end
    statusManageTarget = participantId
    statusManagePopup:ClearAllPoints()
    if anchorFrame then
        statusManagePopup:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -4)
    else
        statusManagePopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    statusManagePopup:Show()
    RefreshStatusManagePopup()
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

-- One marker travels continuously between player, resolution and round counter.
local turnMarker=CreateFrame("Frame",nil,banner)
turnMarker:SetFrameLevel(banner:GetFrameLevel()+20)
turnMarker:EnableMouse(false)
-- Open corner accents preserve the sliding marker without boxing in portraits.
for _,corner in ipairs({"TOPLEFT","TOPRIGHT","BOTTOMLEFT","BOTTOMRIGHT"}) do
    for _,horizontal in ipairs({true,false}) do
    local line=turnMarker:CreateTexture(nil,"OVERLAY")
    line:SetColorTexture(unpack(UI.colors.turnHighlight))
    line:SetPoint(corner,turnMarker,corner,0,0)
    line:SetSize(horizontal and 9 or 2,horizontal and 2 or 9)
    end
end
turnMarker:Hide()
-- Three reusable echoes: no allocations of UI objects during movement.
local markerGhosts={}
for i=1,3 do
    local ghost=CreateFrame("Frame",nil,turnMarker)
    ghost:SetFrameLevel(turnMarker:GetFrameLevel()-1)
    ghost:EnableMouse(false)
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local line=ghost:CreateTexture(nil,"OVERLAY")
        line:SetColorTexture(unpack(UI.colors.turnHighlight))
        if edge=="TOP" or edge=="BOTTOM" then
            line:SetPoint(edge.."LEFT");line:SetPoint(edge.."RIGHT");line:SetHeight(2)
        else
            line:SetPoint("TOP"..edge);line:SetPoint("BOTTOM"..edge);line:SetWidth(2)
        end
    end
    ghost:Hide();markerGhosts[i]=ghost
end
local function HideMarkerGhosts()
    for _,ghost in ipairs(markerGhosts) do ghost:Hide() end
end
local function MoveTurnMarker(x,y,w,h)
    local goal={x=x-2,y=y+2,w=w+4,h=h+4}
    local old=turnMarker.goal
    if old and old.x==goal.x and old.y==goal.y and old.w==goal.w and old.h==goal.h and turnMarker:IsShown() then return end
    turnMarker.goal=goal
    local start=turnMarker.position or goal
    HideMarkerGhosts()
    local distance=math.abs(goal.x-start.x)
    local strength=math.min(1,distance/48)
    local function Draw(t)
        local eased=t*t*(3-2*t)
        local pulse=math.sin(math.pi*t)*strength
        local stretch=math.min(16,distance*.12)*pulse
        local p={}
        for key,value in pairs(goal) do p[key]=start[key]+(value-start[key])*eased end
        p.x=p.x-stretch/2;p.w=p.w+stretch
        p.y=p.y-1.5*pulse;p.h=p.h-3*pulse
        turnMarker.position=p
        turnMarker:ClearAllPoints();turnMarker:SetPoint("TOPLEFT",banner,"TOPLEFT",p.x,p.y)
        turnMarker:SetSize(p.w,p.h)
        for i,ghost in ipairs(markerGhosts) do
            local lag=math.max(0,t-i*.09)
            local progress=lag*lag*(3-2*lag)
            ghost:ClearAllPoints()
            ghost:SetPoint("TOPLEFT",banner,"TOPLEFT",start.x+(goal.x-start.x)*progress-stretch/2,start.y+(goal.y-start.y)*progress)
            ghost:SetSize(start.w+(goal.w-start.w)*progress+stretch,start.h+(goal.h-start.h)*progress)
            ghost:SetAlpha(pulse*(.76-i*.13))
            ghost:SetShown(pulse>.001)
        end
    end
    Draw(0);turnMarker:Show()
    local elapsed=0
    turnMarker:SetScript("OnUpdate",function(self,dt)
        elapsed=elapsed+dt
        local t=math.min(1,elapsed/.28)
        Draw(t)
        if t>=1 then HideMarkerGhosts();self:SetScript("OnUpdate",nil) end
    end)
end
banner:HookScript("OnHide",function()
    HideMarkerGhosts()
    turnMarker:SetScript("OnUpdate",nil);turnMarker:Hide();turnMarker.position=nil;turnMarker.goal=nil
end)

local function Rebuild()
    local st = C.initiative
    local participants = st.participants or {}
    local current = participants[st.currentIndex]


    roundBox:Refresh()
    local phase=C.initiative.phase
    startResolution:Refresh()

    for _, card in ipairs(cards) do card:Hide() end
    for _, ec in ipairs(eventCards) do ec:Hide() end

    -- À 0 HP, le participant disparaît de la bannière (mais reste dans
    -- C.initiative.participants — l'ordre du tour n'est pas affecté) ; il
    -- réapparaît dès que ses HP repassent au-dessus de 0. L'index de carte
    -- (cardIndex) est donc distinct de l'index dans la liste complète : la
    -- surbrillance "tour en cours" compare directement les participants
    -- (référence de table), pas leur position, pour rester correcte même
    -- quand des cartes sont sautées.
    local x = INPUT_W + 24
    local activeX
    local cardIndex = 0
    for _, p in ipairs(participants) do
        if IsAlive(p) then
            cardIndex = cardIndex + 1
            local card = GetCard(cardIndex)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", header, "BOTTOMLEFT", x, -5)
            card:Refresh(p, p == current and (not phase or phase == "play"))
            card:Show()
            if p==current then activeX=x end
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

    local width=math.max(200,x+6)
    banner:SetWidth(width)
    if phase=="resolve_start" or phase=="resolution_end" then
        MoveTurnMarker(width+6,0,44,BANNER_H)
    elseif phase=="counter_focus" or phase=="round_end" or phase=="transition" or phase=="round_start" then
        MoveTurnMarker(width+56,0,ROUND_BOX_W,BANNER_H)
    elseif activeX then
        MoveTurnMarker(activeX,-HEADER_H-5,CARD_W,CARD_H)
    else
        turnMarker:Hide();turnMarker:SetScript("OnUpdate",nil);turnMarker.position=nil
    end
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

-- Local presentation of synchronized phases: no chat messages or extra network traffic.
local phaseNotice=CreateFrame("Frame",nil,UIParent)
phaseNotice:SetSize(440,76)
phaseNotice:SetPoint("CENTER",UIParent,"CENTER",0,90)
phaseNotice:SetFrameStrata("DIALOG")
phaseNotice:EnableMouse(false)
-- Le cadre arrondi porte son propre fond : pas de fond carré dessous.
UI.ApplyBorder(phaseNotice)
local noticeTitle=phaseNotice:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
noticeTitle:SetPoint("TOPLEFT",12,-14);noticeTitle:SetPoint("TOPRIGHT",-12,-14)
noticeTitle:SetJustifyH("CENTER");UI.ApplyTitle(noticeTitle)
local noticeDetail=phaseNotice:CreateFontString(nil,"OVERLAY","GameFontNormal")
noticeDetail:SetPoint("TOPLEFT",12,-43);noticeDetail:SetPoint("TOPRIGHT",-12,-43)
noticeDetail:SetJustifyH("CENTER");UI.ApplyBodyText(noticeDetail)
phaseNotice:Hide()
-- Affichage commun (phases du combat, états du personnage…) : fondu
-- d'entrée, 4 s, fondu de sortie. Un message "persistant" (états : danger,
-- K.O., faible) reste jusqu'à ce que le joueur le ferme. Les messages de
-- C:ShowNotice attendent leur tour ; une phase de combat passe devant, et
-- un état interrompu revient ensuite.
local noticeQueue={}
local PlayNotice,NextNotice
local noticeClose=UI.CreateCloseButton(phaseNotice,function() NextNotice() end)
if noticeClose.SetFrameLevel then noticeClose:SetFrameLevel(phaseNotice:GetFrameLevel()+5) end
noticeClose:Hide()
function NextNotice()
    local message=table.remove(noticeQueue,1)
    if message then PlayNotice(message[1],message[2],false,message[3])
    else
        phaseNotice.fromPhase,phaseNotice.current=nil,nil
        phaseNotice:Hide();phaseNotice:SetScript("OnUpdate",nil)
    end
end
function PlayNotice(title,detail,fromPhase,sticky,duration)
    duration=duration or 4
    local current=phaseNotice.current
    if fromPhase and current and current[3] and phaseNotice:IsShown() then table.insert(noticeQueue,1,current) end
    phaseNotice.fromPhase=fromPhase
    phaseNotice.current={title,detail,sticky}
    phaseNotice:EnableMouse(sticky and true or false)
    noticeClose:SetShown(sticky and true or false)
    noticeTitle:ClearAllPoints()
    if detail and detail ~= "" then
        noticeTitle:SetPoint("TOPLEFT",12,-14)
        noticeTitle:SetPoint("TOPRIGHT",-12,-14)
        noticeDetail:Show()
    else
        noticeTitle:SetPoint("LEFT",phaseNotice,"LEFT",12,0)
        noticeTitle:SetPoint("RIGHT",phaseNotice,"RIGHT",-12,0)
        noticeDetail:Hide()
    end
    -- États (persistants) : sous-texte en italique (Noto Sans, la police
    -- du jeu n'ayant pas d'italique) ; annonces de combat : police normale.
    if sticky then
        noticeDetail:SetFont("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\Fonts\\NotoSans-Italic.ttf",13,"")
    else
        noticeDetail:SetFontObject("GameFontNormal")
    end
    UI.ApplyBodyText(noticeDetail)
    noticeTitle:SetText(title);noticeDetail:SetText(detail or "")
    phaseNotice:SetAlpha(0);phaseNotice:Show()
    local elapsed=0
    phaseNotice:SetScript("OnUpdate",function(self,dt)
        elapsed=elapsed+dt
        if sticky then
            self:SetAlpha(math.min(1,elapsed/.2))
            if elapsed>=.2 then self:SetScript("OnUpdate",nil) end
            return
        end
        self:SetAlpha(math.max(0,math.min(1,elapsed/.2,(duration-elapsed)/.5)))
        if elapsed>=duration then NextNotice() end
    end)
end
-- sticky : reste affiché jusqu'à la croix (états du personnage).
function C:ShowNotice(title,detail,sticky)
    noticeQueue[#noticeQueue+1]={title,detail,sticky}
    if not phaseNotice:IsShown() then NextNotice() end
end
local lastNoticeKey
local function RefreshPhaseNotice()
    local st=C.initiative
    if not st.active then
        lastNoticeKey=nil
        if phaseNotice.fromPhase then NextNotice() end
        return
    end
    local phase=st.phase or "play"
    local key=tostring(st.round)..":"..phase
    if key==lastNoticeKey then return end
    local first=lastNoticeKey==nil
    lastNoticeKey=key
    local title,detail
    if phase=="resolution_end" then
        title="Fin de résolution d’état";detail=""
    elseif phase=="round_end" then
        title="Fin du tour "..st.round;detail=""
    elseif phase=="resolve_start" then
        title="Phase de résolution d'état";detail=""
    elseif phase=="round_start" then
        title="Début du tour "..st.round;detail=""
    elseif first then
        title="Début du tour "..st.round;detail="Le combat commence"
    else
        -- Plus d'annonce de phase : on l'écourte, sans couper un message en file.
        if phaseNotice.fromPhase then NextNotice() end
        return
    end
    local duration=phase=="round_start" and 1 or phase=="round_end" and 1.5 or phase=="resolution_end" and 1.2 or nil
    PlayNotice(title,detail,true,nil,duration)
end

local function Refresh()
    RefreshPhaseNotice()
    if C.initiative.active then
        if not banner:IsShown() then roundBox:ResetTracking() end
        Rebuild()
        banner:Show()
        -- Reflète en direct un retrait/décompte pendant que le popup est
        -- ouvert (ex. l'hôte le retire pendant qu'un joueur le regardait) ;
        -- ne fait rien si le popup n'est pas affiché.
        RefreshStatusManagePopup()
    else
        -- Sinon un popup laissé ouvert en fin de combat resurgirait tel
        -- quel (visible, ciblant un participant qui n'existe plus) au
        -- prochain combat démarré.
        CloseEventPopup()
        CloseStatusPopup()
        statusManagePopup:Hide()
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
