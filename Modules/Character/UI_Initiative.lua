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

    function card:Refresh(p, isCurrent)
        card.participantId = p.id
        initFS:SetText(tostring(p.initiative or 0))
        for _, line in ipairs(glow) do line:SetShown(isCurrent) end

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
