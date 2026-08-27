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

local cards = {}

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

    -- Badge (nombre) affiché tant que ce participant a des évènements en
    -- attente, peu importe le tour ; l'infobulle liste leur description et
    -- le nombre de tours restants.
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
                GameTooltip:AddLine(e.description .. "  (" .. e.turnsLeft .. " " .. turnWord .. ")", unpack(UI.colors.textMuted))
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

-- ── Popup "Ajouter un évènement" ─────────────────────────────────────────────
-- Ouverte via le "+" affiché sur la carte du participant dont c'est le tour :
-- décrit un évènement annoncé en /rw une fois que ce participant a effectué
-- le nombre de tours indiqué (voir C:AddEvent / TickEventsFor côté Core.lua).

local eventPopupTarget = nil  -- id du participant visé par le popup ouvert

local eventPopup = CreateFrame("Frame", nil, banner)
eventPopup:SetSize(220, 208)
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

local eventConfirmBtn = UI.CreatePanelButton(eventPopup, 200, 20, "Ajouter")
eventConfirmBtn:SetPoint("TOPLEFT", eventTurnsEB, "BOTTOMLEFT", 0, -14)

local function CloseEventPopup()
    eventPopup:Hide()
    eventDescEB:SetText("")
    eventTurnsEB:SetText("")
    eventPopupTarget = nil
end

local eventPopupCloseBtn = UI.CreateCloseButton(eventPopup, function() CloseEventPopup() end)
eventPopupCloseBtn:ClearAllPoints()
eventPopupCloseBtn:SetPoint("TOPRIGHT", eventPopup, "TOPRIGHT", -3, -3)
eventPopupCloseBtn:SetSize(18, 16)
eventPopupCloseBtn:SetFrameLevel(eventPopup:GetFrameLevel() + 50)

eventConfirmBtn:SetScript("OnClick", function()
    local desc  = eventDescEB:GetText()
    local turns = eventTurnsEB:GetText()
    if eventPopupTarget and desc and desc:match("%S") and turns and turns ~= "" then
        if C:AddEvent(eventPopupTarget, desc, turns) then
            CloseEventPopup()
        end
    end
end)

OpenEventPopup = function(participantId)
    if not C.initiative.isHost or not C.initiative.active then return end
    local p = FindParticipantById(participantId)
    if not p then return end
    eventPopupTarget = participantId
    eventForLbl:SetText("Pour : " .. ParticipantLabel(p))
    eventDescEB:SetText("")
    eventTurnsEB:SetText("")
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

    for _, card in ipairs(cards) do card:Hide() end

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
