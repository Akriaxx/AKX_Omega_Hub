-- ============================================================
--  Character — Vue MJ (compacte, groupe en temps réel)
--  /ocharmj pour ouvrir · clic sur le titre pour déplacer
-- ============================================================

local C  = Character
local UI = OS2.UI

-- Couleurs de barre (partagées depuis UI.lua)
local COL_HP  = { fg = UI.colors.statHP.fg,   dim = UI.colors.statHP.bg   }
local COL_MP  = { fg = UI.colors.statMana.fg,  dim = UI.colors.statMana.bg  }
local COL_END = { fg = UI.colors.statEnd.fg,   dim = UI.colors.statEnd.bg   }

local rows = {}
local pnjRows = {}  -- défini ici (pas plus bas) : SendImpact/UpdateAllSelections y accèdent avant sa section
local selectedPlayers = {}  -- clés = nom de joueur OU id de PNJ, indifféremment
local impactState = { stat = "hp", mode = "damage" }
local impactPanel, impactValueEB, impactMultiCB, impactStatus
local ApplyImpactToPlayer, SelectPlayerForImpact, UpdateAllSelections
local UpdateScrollRange
local ShowImpactStatus
local RefreshTurnHighlights  -- défini plus bas (Vue MJ — PNJ), appelé dès que le tour change

-- ── Barre de titre draggable ──────────────────────────────────────────────────

local function MakeTitleBar(parent, text)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:SetHeight(20)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function(_, b)
        if b == "LeftButton" then parent:StartMoving() end
    end)
    bar:SetScript("OnMouseUp", function() parent:StopMovingOrSizing() end)

    local bgTex = bar:CreateTexture(nil, "BACKGROUND")
    bgTex:SetAllPoints()
    bgTex:SetColorTexture(unpack(UI.colors.panelButtonBg))

    local lbl = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyTitle(lbl)
    lbl:SetText(text)
    lbl:SetPoint("LEFT", bar, "LEFT", 8, 0)
    return bar
end

-- ── Mini-barre pour une stat (dans la liste MJ) ───────────────────────────────
-- La barre remplit tout l'espace disponible (LEFT/RIGHT dynamiques) au lieu
-- d'une largeur fixe : avant, la barre + le texte gardaient toujours la même
-- taille peu importe la largeur du panneau, laissant un grand vide à droite.

local VAL_TXT_W = 70

local function MiniStatRow(parent, col)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)

    local valTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyMutedText(valTxt)
    valTxt:SetText("—"); valTxt:SetWidth(VAL_TXT_W); valTxt:SetHeight(12)
    valTxt:SetWordWrap(false)
    valTxt:SetJustifyH("RIGHT")
    valTxt:SetPoint("RIGHT", row, "RIGHT", 0, 0)

    local barBg = row:CreateTexture(nil, "BACKGROUND")
    barBg:SetPoint("LEFT", row, "LEFT", 0, 0)
    barBg:SetPoint("RIGHT", valTxt, "LEFT", -4, 0)
    barBg:SetHeight(9)
    barBg:SetColorTexture(col.dim[1], col.dim[2], col.dim[3], 1)

    local fill = row:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", barBg)
    fill:SetHeight(9)
    fill:SetColorTexture(col.fg[1], col.fg[2], col.fg[3], 1)
    fill:SetWidth(1)

    local tempFill = row:CreateTexture(nil, "ARTWORK")
    tempFill:SetPoint("TOPLEFT", barBg)
    tempFill:SetHeight(9)
    tempFill:SetColorTexture(unpack(UI.colors.tempFill))
    tempFill:SetWidth(1)
    tempFill:Hide()

    local function Fmt(n)
        if     n >= 10000 then return string.format("%.0fk", n / 1000)
        elseif n >= 1000  then return string.format("%.1fk", n / 1000)
        else return tostring(n) end
    end

    function row:Set(cur, max, temp)
        temp = math.max(0, tonumber(temp) or 0)
        valTxt:SetText(Fmt(cur) .. "/" .. Fmt(max) .. (temp > 0 and (" (" .. Fmt(temp) .. ")") or ""))
        local barW = math.max(1, barBg:GetWidth() or 1)
        local total = math.max(1, max + temp)
        local curW = math.max(1, barW * math.max(0, math.min(1, cur / total)))
        fill:SetWidth(curW)

        if temp > 0 then
            tempFill:ClearAllPoints()
            tempFill:SetPoint("TOPLEFT", barBg, "TOPLEFT", curW, 0)
            tempFill:SetHeight(9)
            tempFill:SetWidth(math.max(1, barW * math.max(0, math.min(1, temp / total))))
            tempFill:Show()
        else
            tempFill:Hide()
        end
    end

    return row
end

-- ── Surbrillance "tour en cours" (cadre cyan, partagé joueurs/PNJ) ────────────

local function AddTurnBorder(frame)
    local function Line(p1, p1x, p1y, p2, p2x, p2y, isVert)
        local t = frame:CreateTexture(nil, "BORDER")
        t:SetColorTexture(unpack(UI.colors.turnHighlight))
        t:SetPoint(p1, frame, p1, p1x, p1y)
        t:SetPoint(p2, frame, p2, p2x, p2y)
        if isVert then t:SetWidth(2) else t:SetHeight(2) end
        t:Hide()
        return t
    end
    return {
        Line("TOPLEFT",     0,  0, "TOPRIGHT",    0,  0, false),
        Line("BOTTOMLEFT",  0,  0, "BOTTOMRIGHT", 0,  0, false),
        Line("TOPLEFT",     0,  0, "BOTTOMLEFT",  0,  0, true),
        Line("TOPRIGHT",    0,  0, "BOTTOMRIGHT", 0,  0, true),
    }
end

local function SetTurnBorderShown(lines, shown)
    for _, line in ipairs(lines) do line:SetShown(shown) end
end

-- ── Ligne de joueur ───────────────────────────────────────────────────────────

local ROW_H = 86
local PAD   = 8

local function ApplyTargetAttribute(row, playerName)
    if not row or not playerName then return end
    if InCombatLockdown and InCombatLockdown() then return end

    local token = C.GetUnitTokenForName and C:GetUnitTokenForName(playerName)
    if token and UnitExists and UnitExists(token) then
        row:SetAttribute("type1", "target")
        row:SetAttribute("unit", token)
        row:SetAttribute("*type1", "target")
        row:SetAttribute("*unit1", token)
    else
        row:SetAttribute("type1", nil)
        row:SetAttribute("unit", nil)
        row:SetAttribute("*type1", nil)
        row:SetAttribute("*unit1", nil)
    end
end

local function PlayerRow(parent, playerName)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    row:SetHeight(ROW_H)
    row.playerName = playerName
    row:EnableMouse(true)
    row:RegisterForClicks("AnyUp")
    ApplyTargetAttribute(row, playerName)

    -- Fond
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

    local turnBorder = AddTurnBorder(row)
    function row:SetTurn(isCurrent) SetTurnBorderShown(turnBorder, isCurrent) end

    -- Séparateur bas
    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT")
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)

    -- Nom du joueur
    local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyBodyText(nameTxt)
    nameTxt:SetText(playerName)
    nameTxt:SetPoint("TOPLEFT", PAD, -4)

    -- Labels des stats
    local function StatLabel(txt, col, yOff)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetTextColor(col.fg[1], col.fg[2], col.fg[3], 1)
        lbl:SetText(txt); lbl:SetWidth(28); lbl:SetJustifyH("LEFT")
        lbl:SetPoint("TOPLEFT", PAD, yOff)
        return lbl
    end

    local lHP  = StatLabel("HP",   COL_HP,  -20)
    local lMP  = StatLabel("MP",   COL_MP,  -38)
    local lEN  = StatLabel("End.", COL_END, -56)

    -- Mini-barres
    local barHP  = MiniStatRow(row, COL_HP)
    local barMP  = MiniStatRow(row, COL_MP)
    local barEN  = MiniStatRow(row, COL_END)

    local function SetBarLayout(bar, lbl, yOff)
        bar:SetPoint("LEFT",   lbl, "RIGHT", 2, 0)
        bar:SetPoint("RIGHT",  row, "RIGHT", -PAD, 0)
        bar:SetPoint("TOP",    row, "TOP",    0, yOff)
    end
    SetBarLayout(barHP, lHP, -17)
    SetBarLayout(barMP, lMP, -35)
    SetBarLayout(barEN, lEN, -53)

    -- "Pas de données" placeholder
    local noData = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.ApplySoftText(noData)
    noData:SetText("En attente de données...")
    noData:SetPoint("LEFT", PAD, 0); noData:Hide()

    function row:SetSelected(selected)
        if selected then
            selectedTex:Show()
            bgTex:SetColorTexture(unpack(UI.colors.rowBgSelected))
        else
            selectedTex:Hide()
            bgTex:SetColorTexture(unpack(UI.colors.rowBg))
        end
    end

    row:SetScript("PostClick", function()
        if SelectPlayerForImpact then SelectPlayerForImpact(playerName) end
    end)

    function row:Refresh(data)
        ApplyTargetAttribute(row, playerName)
        nameTxt:SetText(C.GetDisplayName and C:GetDisplayName(playerName, data) or "Profil en attente")
        if not data then
            lHP:Hide(); lMP:Hide(); lEN:Hide()
            barHP:Hide(); barMP:Hide(); barEN:Hide()
            noData:Show()
            row:SetSelected(selectedPlayers[playerName])
            return
        end
        noData:Hide()
        lHP:Show(); lMP:Show(); lEN:Show()
        barHP:Show(); barMP:Show(); barEN:Show()

        barHP:Set(data.hp.cur,        data.hp.max,        data.hp.temp)
        barMP:Set(data.mana.cur,      data.mana.max,      data.mana.temp)
        barEN:Set(data.endurance.cur, data.endurance.max, data.endurance.temp)
        row:SetSelected(selectedPlayers[playerName])
    end

    return row
end

-- ── Panneau MJ ────────────────────────────────────────────────────────────────

local MJ_W, MJ_H = 250, 380

local mjPanel = CreateFrame("Frame", "CharacterMJPanel", UIParent)
mjPanel:SetSize(MJ_W, MJ_H)
mjPanel:SetPoint("CENTER", UIParent, "CENTER", 180, 0)
mjPanel:SetMovable(true)
mjPanel:SetClampedToScreen(true)
mjPanel:EnableMouse(true)
mjPanel:SetFrameStrata("MEDIUM")
mjPanel:Hide()

-- Fond style OS2
local bgTex = mjPanel:CreateTexture(nil, "BACKGROUND")
bgTex:SetAllPoints()
UI.ApplyWindowBackground(bgTex)
mjPanel.bg = bgTex

-- Barre de titre draggable
local titleBar = MakeTitleBar(mjPanel, "Vue MJ — Groupe")
titleBar:SetFrameLevel(mjPanel:GetFrameLevel() + 1)

-- Bouton fermer
local closeBtn = UI.CreateCloseButton(mjPanel, function() mjPanel:Hide() end)
closeBtn:ClearAllPoints()
closeBtn:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT", -3, -3)
closeBtn:SetSize(18, 16)

if closeBtn and closeBtn.SetFrameLevel then
    closeBtn:SetFrameLevel(mjPanel:GetFrameLevel() + 50)
end

-- ── Panneau d'impact MJ ──────────────────────────────────────────────────────

impactPanel = CreateFrame("Frame", "CharacterMJImpactPanel", UIParent)
impactPanel:SetSize(220, 284)
impactPanel:SetPoint("TOPRIGHT", mjPanel, "TOPLEFT", -2, 0)
impactPanel:SetFrameStrata("MEDIUM")
impactPanel:SetFrameLevel(mjPanel:GetFrameLevel() + 5)
impactPanel:SetMovable(true)
impactPanel:SetClampedToScreen(true)
impactPanel:EnableMouse(true)
impactPanel:Hide()

local impactBg = impactPanel:CreateTexture(nil, "BACKGROUND")
impactBg:SetAllPoints()
UI.ApplyWindowBackground(impactBg)
impactPanel.bg = impactBg

local impactTitleBar = MakeTitleBar(impactPanel, "Gestionnaire de ressources")
impactTitleBar:SetFrameLevel(impactPanel:GetFrameLevel() + 1)

local function ImpactLabel(text, x, y)
    local fs = impactPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", x, y)
    fs:SetText(text)
    UI.ApplyLabel(fs)
    return fs
end

local function ImpactSeparator(y)
    local sep = impactPanel:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, y)
    sep:SetPoint("TOPRIGHT", impactPanel, "TOPRIGHT", -10, y)
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)
    return sep
end

local function CreateImpactDropdown(parent, width, labelText, items, getValue, setValue)
    return UI.CreateDropdown(parent, width, labelText, items, getValue, setValue)
end

ImpactLabel("Valeur", 10, -34)
impactValueEB = UI.CreateStyledEditBox(impactPanel, 198, 22)
impactValueEB:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -50)
impactValueEB:SetNumeric(true)
impactValueEB:SetMaxLetters(7)
impactValueEB:SetText("1")
ImpactSeparator(-80)

local statDropdown = CreateImpactDropdown(impactPanel, 198, "Ressource", {
    { value = "hp", label = "HP" },
    { value = "mana", label = "Mana" },
    { value = "endurance", label = "Endurance" },
}, function() return impactState.stat end, function(value) impactState.stat = value end)
statDropdown:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -92)
ImpactSeparator(-138)

local actionDropdown = CreateImpactDropdown(impactPanel, 198, "Action", {
    { value = "damage", label = "Retrait" },
    { value = "heal", label = "Ajout" },
    { value = "buff", label = "Buff Temp" },
}, function() return impactState.mode end, function(value) impactState.mode = value end)
actionDropdown:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -150)
ImpactSeparator(-196)

impactMultiCB = UI.CreateStyledCheckbox(impactPanel, "Multicible")
impactMultiCB:SetPoint("TOPLEFT", impactPanel, "TOPLEFT", 10, -208)
impactMultiCB.label:SetPoint("LEFT", impactMultiCB, "RIGHT", 6, 0)
impactMultiCB:SetScript("OnClick", function(self)
    if not self:GetChecked() then
        selectedPlayers = {}
        if UpdateAllSelections then UpdateAllSelections() end
    end
end)

local applyBtn = UI.CreatePanelButton(impactPanel, 72, 20, "Appliquer")
applyBtn:SetPoint("BOTTOMLEFT", impactPanel, "BOTTOMLEFT", 10, 28)
applyBtn:SetScript("OnClick", function()
    local count = 0
    for name in pairs(selectedPlayers) do
        count = count + 1
        if ApplyImpactToPlayer then ApplyImpactToPlayer(name, true) end
    end
    selectedPlayers = {}
    if UpdateAllSelections then UpdateAllSelections() end
    if ShowImpactStatus then ShowImpactStatus(count > 0 and "Envoyé" or "Aucune cible") end
end)

impactStatus = impactPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
impactStatus:SetPoint("TOPLEFT", applyBtn, "BOTTOMLEFT", 2, -2)
impactStatus:SetPoint("RIGHT", impactPanel, "RIGHT", -10, 0)
impactStatus:SetJustifyH("LEFT")
impactStatus:SetText("")
UI.ApplyMutedText(impactStatus)

local impactStatusToken = 0
ShowImpactStatus = function(text)
    if not impactStatus then return end
    impactStatusToken = impactStatusToken + 1
    local token = impactStatusToken
    impactStatus:SetText(text or "")
    impactStatus:Show()
    if C_Timer and C_Timer.After then
        C_Timer.After(3, function()
            if token == impactStatusToken and impactStatus then
                impactStatus:SetText("")
                impactStatus:Hide()
            end
        end)
    end
end
impactStatus:Hide()

-- ── Contrôles Initiative (en dessous du Gestionnaire de ressources) ──────────
-- Bascule combat, "Joueur suivant" puis "Rajouter un NPC", dans cet ordre.
-- Enfants d'impactPanel : ils apparaissent/disparaissent avec lui automatiquement.

local combatToggleBtn = UI.CreatePanelButton(impactPanel, 198, 20, "Début de combat")
combatToggleBtn:SetPoint("TOPLEFT", impactPanel, "BOTTOMLEFT", 10, -4)
combatToggleBtn:SetFrameLevel(impactPanel:GetFrameLevel() + 2)
combatToggleBtn:SetScript("OnClick", function()
    if C.initiative.active then
        -- "Fin de combat" ne fait rien si un AUTRE client est l'hôte (combat
        -- déjà en cours, lancé par quelqu'un d'autre) : le dire clairement
        -- plutôt que de laisser croire que le clic n'a servi à rien.
        if not C:EndCombat() and ShowImpactStatus then
            ShowImpactStatus("Vous n'êtes pas l'hôte de ce combat")
        end
    else
        C:StartCombat()
    end
end)

local nextTurnBtn = UI.CreatePanelButton(impactPanel, 198, 20, "Joueur suivant")
nextTurnBtn:SetPoint("TOPLEFT", combatToggleBtn, "BOTTOMLEFT", 0, -4)
nextTurnBtn:SetFrameLevel(impactPanel:GetFrameLevel() + 2)
nextTurnBtn:SetScript("OnClick", function()
    if not C:NextTurn() and not C.initiative.isHost and ShowImpactStatus then
        ShowImpactStatus("Vous n'êtes pas l'hôte de ce combat")
    end
end)

local addNpcBtn = UI.CreatePanelButton(impactPanel, 198, 20, "Rajouter un NPC")
addNpcBtn:SetPoint("TOPLEFT", nextTurnBtn, "BOTTOMLEFT", 0, -4)
addNpcBtn:SetFrameLevel(impactPanel:GetFrameLevel() + 2)

-- Qui pilote le combat : sans ça, un non-hôte qui clique Fin de combat /
-- Joueur suivant / Rajouter un NPC pendant qu'un combat est en cours ne
-- comprend pas pourquoi rien ne se passe (ces actions n'ont d'effet que
-- pour l'hôte, celui qui a cliqué Début de combat).
local hostStatus = impactPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hostStatus:SetPoint("TOPLEFT", addNpcBtn, "BOTTOMLEFT", 2, -3)
hostStatus:SetPoint("RIGHT", impactPanel, "RIGHT", -10, 0)
hostStatus:SetJustifyH("LEFT")
UI.ApplyMutedText(hostStatus)

-- Popup d'ajout de PNJ (nom, initiative, HP/MP/End.), affichée au centre de
-- l'écran : ancrée près du bouton elle recouvrait le reste du panneau MJ.
-- Une fois validée, le PNJ apparaît dans la Vue MJ — PNJ.
local npcPopup = CreateFrame("Frame", nil, impactPanel)
npcPopup:SetSize(220, 172)
npcPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
npcPopup:SetFrameStrata("DIALOG")
npcPopup:SetMovable(true)
npcPopup:SetClampedToScreen(true)
npcPopup:EnableMouse(true)
npcPopup:Hide()

local npcPopupBg = npcPopup:CreateTexture(nil, "BACKGROUND")
npcPopupBg:SetAllPoints()
UI.ApplyWindowBackground(npcPopupBg, 0.95)
UI.ApplyBorder(npcPopup)

local npcPopupTitleBar = MakeTitleBar(npcPopup, "Rajouter un NPC")
npcPopupTitleBar:SetFrameLevel(npcPopup:GetFrameLevel() + 1)

-- Icone du PNJ (à gauche du nom) : ouvre le navigateur d'icones déjà utilisé
-- par le module Spell, pour distinguer les PNJ entre eux dans la bannière.
local selectedNpcIcon = nil

local npcIconBtn = CreateFrame("Button", nil, npcPopup)
npcIconBtn:SetSize(28, 28)
npcIconBtn:SetPoint("TOPLEFT", npcPopup, "TOPLEFT", 10, -30)

local npcIconTex = npcIconBtn:CreateTexture(nil, "ARTWORK")
npcIconTex:SetAllPoints()
npcIconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
npcIconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

local npcIconBorder = npcIconBtn:CreateTexture(nil, "BORDER")
npcIconBorder:SetPoint("TOPLEFT", npcIconBtn, "TOPLEFT", -1, 1)
npcIconBorder:SetPoint("BOTTOMRIGHT", npcIconBtn, "BOTTOMRIGHT", 1, -1)
npcIconBorder:SetColorTexture(unpack(UI.colors.panelButtonAccent))

local npcIconHL = npcIconBtn:CreateTexture(nil, "HIGHLIGHT")
npcIconHL:SetAllPoints()
npcIconHL:SetColorTexture(1, 1, 1, 0.20)

npcIconBtn:SetScript("OnClick", function()
    if OmegaSpell and OmegaSpell.IconBrowser and OmegaSpell.IconBrowser.Open then
        OmegaSpell.IconBrowser.Open(function(iconPath)
            selectedNpcIcon = iconPath
            npcIconTex:SetTexture(iconPath)
        end)
    end
end)
npcIconBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Icone du PNJ", unpack(UI.colors.title))
    GameTooltip:AddLine("Clic pour en choisir une autre.", unpack(UI.colors.textMuted))
    GameTooltip:Show()
end)
npcIconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local npcNameLbl = npcPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
npcNameLbl:SetPoint("TOPLEFT", npcIconBtn, "TOPRIGHT", 8, 0)
npcNameLbl:SetText("Nom")
UI.ApplyLabel(npcNameLbl)

local npcNameEB = UI.CreateStyledEditBox(npcPopup, 164, 22)
npcNameEB:SetPoint("TOPLEFT", npcIconBtn, "TOPRIGHT", 8, -14)
npcNameEB:SetMaxLetters(32)

-- Rangée compacte : Initiative / HP / MP / End., 4 petits champs numériques.
local NPC_FIELD_W, NPC_FIELD_GAP = 44, 6
local npcStatFields = {}

local npcFieldsLbl = npcPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
npcFieldsLbl:SetPoint("TOPLEFT", npcPopup, "TOPLEFT", 10, -76)
npcFieldsLbl:SetText("Init.")
UI.ApplyLabel(npcFieldsLbl)

local function NpcFieldLabel(text, x)
    local lbl = npcPopup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", npcFieldsLbl, "TOPLEFT", x, 0)
    lbl:SetWidth(NPC_FIELD_W)
    lbl:SetJustifyH("LEFT")
    lbl:SetText(text)
    UI.ApplyLabel(lbl)
    return lbl
end
NpcFieldLabel("HP",   NPC_FIELD_W + NPC_FIELD_GAP)
NpcFieldLabel("MP",   (NPC_FIELD_W + NPC_FIELD_GAP) * 2)
NpcFieldLabel("End.", (NPC_FIELD_W + NPC_FIELD_GAP) * 3)

for i = 1, 4 do
    local eb = UI.CreateStyledEditBox(npcPopup, NPC_FIELD_W, 22)
    eb:SetNumeric(true)
    eb:SetMaxLetters(4)
    eb:SetPoint("TOPLEFT", npcFieldsLbl, "BOTTOMLEFT", (i - 1) * (NPC_FIELD_W + NPC_FIELD_GAP), -4)
    npcStatFields[i] = eb
end
local npcInitEB, npcHpEB, npcMpEB, npcEndEB = npcStatFields[1], npcStatFields[2], npcStatFields[3], npcStatFields[4]

local npcAddConfirmBtn = UI.CreatePanelButton(npcPopup, 200, 20, "Ajouter")
npcAddConfirmBtn:SetPoint("TOPLEFT", npcFieldsLbl, "BOTTOMLEFT", 0, -40)

local function CloseNpcPopup()
    npcPopup:Hide()
    for _, eb in ipairs(npcStatFields) do eb:SetText("") end
    npcNameEB:SetText("")
    selectedNpcIcon = nil
    npcIconTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

local npcPopupCloseBtn = UI.CreateCloseButton(npcPopup, function() CloseNpcPopup() end)
npcPopupCloseBtn:ClearAllPoints()
npcPopupCloseBtn:SetPoint("TOPRIGHT", npcPopup, "TOPRIGHT", -3, -3)
npcPopupCloseBtn:SetSize(18, 16)
npcPopupCloseBtn:SetFrameLevel(npcPopup:GetFrameLevel() + 50)

npcAddConfirmBtn:SetScript("OnClick", function()
    local name = npcNameEB:GetText()
    local init = npcInitEB:GetText()
    if name and name:match("%S") and init and init ~= "" then
        local added = C:AddNPC(name, init, npcHpEB:GetText(), npcMpEB:GetText(), npcEndEB:GetText(), selectedNpcIcon)
        if added then
            CloseNpcPopup()
            if ShowImpactStatus then ShowImpactStatus("PNJ ajouté") end
        elseif ShowImpactStatus then
            -- N'arrive que si un AUTRE client est l'hôte du combat en cours :
            -- seul l'hôte peut faire apparaître le PNJ dans la Vue MJ — PNJ
            -- de tout le monde. On le dit plutôt que de fermer en silence.
            ShowImpactStatus("Vous n'êtes pas l'hôte de ce combat")
        end
    end
end)

-- Pré-remplit les champs du popup depuis `prefill` (nom/hp/mana/endurance/
-- initiative/icone), ou les vide si prefill est nil. Utilisé par le bouton
-- "Rajouter un NPC" (vide), /chnpcadd et "Dupliquer" sur un PNJ existant
-- (pré-rempli).
local function FillNpcPopup(prefill)
    prefill = prefill or {}
    npcNameEB:SetText(prefill.name and tostring(prefill.name) or "")
    npcInitEB:SetText(prefill.initiative ~= nil and tostring(prefill.initiative) or "")
    npcHpEB:SetText(prefill.hp ~= nil and tostring(prefill.hp) or "")
    npcMpEB:SetText(prefill.mana ~= nil and tostring(prefill.mana) or "")
    npcEndEB:SetText(prefill.endurance ~= nil and tostring(prefill.endurance) or "")
    selectedNpcIcon = prefill.icon
    npcIconTex:SetTexture(prefill.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
end

local function OpenNpcPopup(prefill)
    if not C.initiative.active then
        if ShowImpactStatus then ShowImpactStatus("Combat non démarré") end
        return
    end
    FillNpcPopup(prefill)
    npcPopup:Show()
end

addNpcBtn:SetScript("OnClick", function()
    if not C.initiative.active then
        if ShowImpactStatus then ShowImpactStatus("Combat non démarré") end
        return
    end
    if npcPopup:IsShown() then CloseNpcPopup() else OpenNpcPopup() end
end)

-- Point d'entrée pour /chnpcadd (Core.lua) : ouvre la Vue MJ si besoin, puis
-- le popup d'ajout de PNJ déjà rempli.
function C:ShowNpcAddPopup(prefill)
    if CharacterMJPanel and not CharacterMJPanel:IsShown() then
        CharacterMJPanel:Show()
    end
    OpenNpcPopup(prefill)
end

local function RefreshCombatControls()
    local active = C.initiative.active
    local hasParticipants = #C.initiative.participants > 0

    combatToggleBtn:SetText(active and "Fin de combat" or "Début de combat")
    nextTurnBtn:SetEnabled(active and hasParticipants)
    nextTurnBtn:SetAlpha((active and hasParticipants) and 1 or 0.45)
    addNpcBtn:SetAlpha(active and 1 or 0.45)
    if not active then npcPopup:Hide() end

    if active then
        hostStatus:SetText(C.initiative.isHost and "Hôte : vous" or "Hôte : un autre MJ")
    else
        hostStatus:SetText("")
    end
end

local prevInitMJ = C.OnInitiativeChanged
C.OnInitiativeChanged = function()
    if prevInitMJ then prevInitMJ() end
    RefreshCombatControls()
end

RefreshCombatControls()

-- Bouton Actualiser (à gauche du bouton fermer)
local refreshBtn = UI.CreatePanelButton(mjPanel, 64, 16, "Actualiser")
refreshBtn:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT", -26, -3)
refreshBtn:SetFrameLevel(mjPanel:GetFrameLevel() + 40)
refreshBtn:SetScript("OnClick", function()
    C:RequestAll()
    local myName = UnitName("player")
    if myName then C.groupData[myName] = C:GetMyChar() end
    if CharacterMJPanel._rebuild then CharacterMJPanel._rebuild() end
end)

-- Séparateur sous le titre
local titleSep = mjPanel:CreateTexture(nil, "ARTWORK")
titleSep:SetPoint("TOPLEFT",  mjPanel, "TOPLEFT",   8, -21)
titleSep:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT",  -8, -21)
titleSep:SetHeight(1)
UI.ApplySeparator(titleSep, true)

-- ── ScrollFrame ───────────────────────────────────────────────────────────────

local scrollFrame = CreateFrame("ScrollFrame", nil, mjPanel)
scrollFrame:SetPoint("TOPLEFT",     mjPanel, "TOPLEFT",     2,  -24)
scrollFrame:SetPoint("BOTTOMRIGHT", mjPanel, "BOTTOMRIGHT", -18,  4)
scrollFrame:EnableMouseWheel(true)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetWidth(scrollFrame:GetWidth())
content:SetHeight(1)
scrollFrame:SetScrollChild(content)

local scrollSlider = CreateFrame("Slider", nil, mjPanel)
scrollSlider:SetOrientation("VERTICAL")
scrollSlider:SetPoint("TOPRIGHT", mjPanel, "TOPRIGHT", -7, -30)
scrollSlider:SetPoint("BOTTOMRIGHT", mjPanel, "BOTTOMRIGHT", -7, 10)
scrollSlider:SetWidth(8)
scrollSlider:SetMinMaxValues(0, 0)
scrollSlider:SetValueStep(1)
scrollSlider:SetValue(0)

local track = scrollSlider:CreateTexture(nil, "BACKGROUND")
track:SetPoint("TOP", scrollSlider, "TOP", 0, 0)
track:SetPoint("BOTTOM", scrollSlider, "BOTTOM", 0, 0)
track:SetWidth(4)
track:SetColorTexture(0.10, 0.10, 0.10, 0.82)

local thumb = scrollSlider:CreateTexture(nil, "ARTWORK")
thumb:SetSize(10, 28)
thumb:SetColorTexture(0.46, 0.42, 0.32, 0.95)
scrollSlider:SetThumbTexture(thumb)
scrollSlider:Hide()

UpdateScrollRange = function()
    local viewportH = math.max(1, scrollFrame:GetHeight())
    local contentH = math.max(1, content:GetHeight())
    local maxScroll = math.max(0, contentH - viewportH)
    scrollSlider:SetMinMaxValues(0, maxScroll)
    scrollSlider:SetValueStep(20)

    if maxScroll <= 0 then
        scrollFrame:SetVerticalScroll(0)
        scrollSlider:SetValue(0)
        scrollSlider:Hide()
    else
        scrollSlider:Show()
        if scrollSlider:GetValue() > maxScroll then scrollSlider:SetValue(maxScroll) end
    end
end

scrollSlider:SetScript("OnValueChanged", function(_, value)
    scrollFrame:SetVerticalScroll(value or 0)
end)

scrollFrame:SetScript("OnMouseWheel", function(_, delta)
    local _, maxScroll = scrollSlider:GetMinMaxValues()
    if maxScroll <= 0 then return end
    local nextValue = scrollSlider:GetValue() - (delta * 34)
    scrollSlider:SetValue(math.max(0, math.min(maxScroll, nextValue)))
end)

-- ── Gestion des lignes ────────────────────────────────────────────────────────

local function GetImpactAmount()
    local amount = math.floor(tonumber(impactValueEB and impactValueEB:GetText() or "") or 0)
    if amount < 0 then amount = math.abs(amount) end
    return amount
end

local function FindNpcParticipant(id)
    for _, p in ipairs(C.initiative.participants) do
        if p.kind == "npc" and p.id == id then return p end
    end
end

-- targetId est soit un nom de joueur, soit un id de PNJ ("npc1", ...) —
-- même Valeur/Ressource/Action/Multicible/Appliquer pour les deux.
local function SendImpact(targetId)
    local amount = GetImpactAmount()
    if amount <= 0 then
        if ShowImpactStatus then ShowImpactStatus("Valeur ?") end
        return false
    end

    if FindNpcParticipant(targetId) then
        if not C.initiative.isHost then
            if ShowImpactStatus then ShowImpactStatus("Vous n'êtes pas l'hôte du combat") end
            return false
        end
        if impactState.mode == "buff" then
            C:ApplyNPCTemp(targetId, impactState.stat, amount)
        else
            local delta = (impactState.mode == "damage") and -amount or amount
            C:ApplyNPCDelta(targetId, impactState.stat, delta)
        end
        return true
    end

    if impactState.mode == "buff" then
        if targetId == UnitName("player") then
            C:AddTemp(impactState.stat, amount, true)
        elseif C.SendTempCmd then
            C:SendTempCmd(targetId, impactState.stat, amount)
        end
        return true
    end

    local delta = (impactState.mode == "damage") and -amount or amount
    if targetId == UnitName("player") then
        C:Delta(impactState.stat, delta, true)
    else
        C:SendModCmd(targetId, impactState.stat, delta)
    end
    return true
end

-- Lu par la bannière d'initiative (UI_Initiative.lua) pour savoir quel
-- participant surligner légèrement quand on clique sa ligne ici.
function C:IsImpactSelected(id)
    return selectedPlayers[id] == true
end

UpdateAllSelections = function()
    for name, row in pairs(rows) do
        if row.SetSelected then row:SetSelected(selectedPlayers[name]) end
    end
    for npcId, row in pairs(pnjRows) do
        if row.SetSelected then row:SetSelected(selectedPlayers[npcId]) end
    end
    if C.RefreshBannerSelection then C:RefreshBannerSelection() end
end

ApplyImpactToPlayer = function(playerName, forceApply)
    if not playerName or playerName == "" then return end

    if impactMultiCB and impactMultiCB:GetChecked() and not forceApply then
        selectedPlayers[playerName] = not selectedPlayers[playerName] or nil
        UpdateAllSelections()
        if ShowImpactStatus then
            local count = 0
            for _ in pairs(selectedPlayers) do count = count + 1 end
            ShowImpactStatus(tostring(count) .. " cible(s)")
        end
        return
    end

    if SendImpact(playerName) and ShowImpactStatus then
        ShowImpactStatus("Envoyé")
    end
end

SelectPlayerForImpact = function(playerName)
    if not playerName or playerName == "" then return end

    if impactMultiCB and impactMultiCB:GetChecked() then
        selectedPlayers[playerName] = not selectedPlayers[playerName] or nil
    else
        selectedPlayers = {}
        selectedPlayers[playerName] = true
    end

    UpdateAllSelections()

    if ShowImpactStatus then
        local count = 0
        for _ in pairs(selectedPlayers) do count = count + 1 end
        ShowImpactStatus(count > 0 and (tostring(count) .. " cible(s)") or "Aucune cible")
    end
end

-- Ne liste que les membres présents : un membre du groupe déconnecté n'a
-- aucune chance d'envoyer ses données, sa ligne resterait bloquée sur
-- "Profil en attente" indéfiniment et prendrait de la place pour rien.
local function GetVisibleMembers()
    local members, seen = {}, {}
    local myName = UnitName("player")

    local function Add(n)
        if n and n ~= "" and not seen[n] then seen[n] = true; table.insert(members, n) end
    end

    Add(myName)

    if IsInRaid and IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local token = "raid" .. i
            if UnitIsConnected(token) then Add(UnitName(token)) end
        end
    elseif IsInGroup and IsInGroup() then
        for i = 1, 4 do
            local token = "party" .. i
            if UnitIsConnected(token) then Add(UnitName(token)) end
        end
    end

    table.sort(members)
    return members
end

local function Rebuild()
    local members = GetVisibleMembers()
    local myName  = UnitName("player")

    content:SetWidth(math.max(1, scrollFrame:GetWidth()))
    for _, row in pairs(rows) do row:Hide() end

    local totalH = 0
    for _, name in ipairs(members) do
        if not rows[name] then
            rows[name] = PlayerRow(content, name)
        end
        local row = rows[name]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -totalH)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -totalH)
        row:Show()

        local data = (name == myName) and C:GetMyChar() or C.groupData[name]
        row:Refresh(data)
        totalH = totalH + ROW_H + 2
    end

    content:SetHeight(math.max(1, totalH))
    UpdateScrollRange()
    if RefreshTurnHighlights then RefreshTurnHighlights() end
end

mjPanel._rebuild = Rebuild

-- ── Callbacks Core ────────────────────────────────────────────────────────────

local prevGroup = C.OnGroupDataChanged
C.OnGroupDataChanged = function(name)
    if prevGroup then prevGroup(name) end
    if not mjPanel:IsShown() then return end
    if rows[name] then
        rows[name]:Refresh(C.groupData[name])
    else
        Rebuild()
    end
end

local prevMine = C.OnMyDataChanged
C.OnMyDataChanged = function()
    if prevMine then prevMine() end
    if not mjPanel:IsShown() then return end
    local myName = UnitName("player")
    if rows[myName] then
        rows[myName]:Refresh(C:GetMyChar())
    else
        Rebuild()
    end
end

-- ── Toggle ────────────────────────────────────────────────────────────────────

mjPanel:SetScript("OnShow", function()
    local myName = UnitName("player")
    if myName then C.groupData[myName] = C:GetMyChar() end
    if impactPanel then
        impactPanel:ClearAllPoints()
        impactPanel:SetPoint("TOPRIGHT", mjPanel, "TOPLEFT", -2, 0)
        impactPanel:Show()
    end
    Rebuild()
end)

mjPanel:SetScript("OnHide", function()
    if impactPanel then impactPanel:Hide() end
end)

function mjPanel:Toggle()
    if self:IsShown() then self:Hide() else self:Show() end
end

-- ── Panneau MJ — PNJ (à droite de la Vue MJ — Groupe) ────────────────────────
-- N'apparaît que s'il y a au moins un PNJ dans le tableau d'initiative :
-- pas la peine d'occuper l'écran avant qu'un PNJ soit créé.

local function NpcRow(parent, npcId)
    -- Button (pas juste Frame) : sélectionnable pour le Gestionnaire de
    -- ressources, comme une ligne de joueur. Pas de SecureActionButtonTemplate
    -- ici — un PNJ n'est pas une unité réelle, pas de ciblage à sécuriser.
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row.npcId = npcId
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

    local sep = row:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("BOTTOMLEFT"); sep:SetPoint("BOTTOMRIGHT")
    sep:SetHeight(1)
    UI.ApplySeparator(sep, true)

    local turnBorder = AddTurnBorder(row)
    function row:SetTurn(isCurrent) SetTurnBorderShown(turnBorder, isCurrent) end

    function row:SetSelected(selected)
        if selected then
            selectedTex:Show()
            bgTex:SetColorTexture(unpack(UI.colors.rowBgSelected))
        else
            selectedTex:Hide()
            bgTex:SetColorTexture(unpack(UI.colors.rowBg))
        end
    end

    row:SetScript("PostClick", function()
        if SelectPlayerForImpact then SelectPlayerForImpact(row.npcId) end
    end)

    local iconTex = row:CreateTexture(nil, "ARTWORK")
    iconTex:SetSize(16, 16)
    iconTex:SetPoint("TOPLEFT", row, "TOPLEFT", PAD, -4)
    iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconTex = iconTex

    local nameTxt = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    UI.ApplyBodyText(nameTxt)
    nameTxt:SetPoint("TOPLEFT", iconTex, "TOPRIGHT", 4, 2)
    nameTxt:SetPoint("RIGHT", row, "RIGHT", -20, 0)
    nameTxt:SetWordWrap(false)

    local function StatLabel(txt, col, yOff)
        local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetTextColor(col.fg[1], col.fg[2], col.fg[3], 1)
        lbl:SetText(txt); lbl:SetWidth(28); lbl:SetJustifyH("LEFT")
        lbl:SetPoint("TOPLEFT", PAD, yOff)
        return lbl
    end
    local lHP = StatLabel("HP",   COL_HP,  -20)
    local lMP = StatLabel("MP",   COL_MP,  -38)
    local lEN = StatLabel("End.", COL_END, -56)

    local barHP = MiniStatRow(row, COL_HP)
    local barMP = MiniStatRow(row, COL_MP)
    local barEN = MiniStatRow(row, COL_END)
    local function SetBarLayout(bar, lbl, yOff)
        bar:SetPoint("LEFT",  lbl, "RIGHT", 2, 0)
        bar:SetPoint("RIGHT", row, "RIGHT", -PAD, 0)
        bar:SetPoint("TOP",   row, "TOP",    0, yOff)
    end
    SetBarLayout(barHP, lHP, -17)
    SetBarLayout(barMP, lMP, -35)
    SetBarLayout(barEN, lEN, -53)

    -- Suppression à la volée (ex : le PNJ meurt) — seul l'hôte du combat
    -- peut effectivement retirer un PNJ (C:RemoveNPC est gardé côté Core).
    local deleteBtn = UI.CreateCloseButton(row, nil)
    deleteBtn:ClearAllPoints()
    deleteBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -2, -2)
    deleteBtn:SetSize(14, 14)
    deleteBtn:SetScript("OnClick", function()
        if row.npcId then C:RemoveNPC(row.npcId) end
    end)

    -- Rouvre le popup d'ajout de PNJ pré-rempli avec les stats max de ce
    -- PNJ (pas ses HP/Mana/Endu actuels — un clone part au complet) : il ne
    -- reste plus qu'à changer le nom et valider.
    local duplicateBtn = UI.CreatePanelButton(row, 62, 14, "Dupliquer")
    duplicateBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
    duplicateBtn:SetScript("OnClick", function()
        local p = row.npcId and FindNpcParticipant(row.npcId)
        if not p then return end
        OpenNpcPopup({
            name       = p.name,
            initiative = p.initiative,
            hp         = p.hp and p.hp.max,
            mana       = p.mana and p.mana.max,
            endurance  = p.endurance and p.endurance.max,
            icon       = p.icon,
        })
    end)

    function row:Refresh(p)
        row.npcId = p.id
        nameTxt:SetText(p.name or "?")
        iconTex:SetTexture(p.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        local hp = p.hp or {}
        local mp = p.mana or {}
        local en = p.endurance or {}
        barHP:Set(hp.cur or 0, hp.max or 0, hp.temp or 0)
        barMP:Set(mp.cur or 0, mp.max or 0, mp.temp or 0)
        barEN:Set(en.cur or 0, en.max or 0, en.temp or 0)
        deleteBtn:SetShown(C.initiative.isHost)
        duplicateBtn:SetShown(C.initiative.isHost)
        row:SetSelected(selectedPlayers[p.id])
    end

    return row
end

local pnjPanel = CreateFrame("Frame", "CharacterMJPnjPanel", UIParent)
pnjPanel:SetSize(MJ_W, MJ_H)
pnjPanel:SetPoint("TOPLEFT", mjPanel, "TOPRIGHT", 2, 0)
pnjPanel:SetMovable(true)
pnjPanel:SetClampedToScreen(true)
pnjPanel:EnableMouse(true)
pnjPanel:SetFrameStrata("MEDIUM")
pnjPanel:Hide()

local pnjBg = pnjPanel:CreateTexture(nil, "BACKGROUND")
pnjBg:SetAllPoints()
UI.ApplyWindowBackground(pnjBg)
pnjPanel.bg = pnjBg

local pnjTitleBar = MakeTitleBar(pnjPanel, "Vue MJ — PNJ")
pnjTitleBar:SetFrameLevel(pnjPanel:GetFrameLevel() + 1)

local pnjManuallyClosed = false
local pnjCloseBtn = UI.CreateCloseButton(pnjPanel, function()
    pnjManuallyClosed = true
    pnjPanel:Hide()
end)
pnjCloseBtn:ClearAllPoints()
pnjCloseBtn:SetPoint("TOPRIGHT", pnjPanel, "TOPRIGHT", -3, -3)
pnjCloseBtn:SetSize(18, 16)
pnjCloseBtn:SetFrameLevel(pnjPanel:GetFrameLevel() + 50)

local pnjTitleSep = pnjPanel:CreateTexture(nil, "ARTWORK")
pnjTitleSep:SetPoint("TOPLEFT",  pnjPanel, "TOPLEFT",   8, -21)
pnjTitleSep:SetPoint("TOPRIGHT", pnjPanel, "TOPRIGHT",  -8, -21)
pnjTitleSep:SetHeight(1)
UI.ApplySeparator(pnjTitleSep, true)

local pnjScrollFrame = CreateFrame("ScrollFrame", nil, pnjPanel)
pnjScrollFrame:SetPoint("TOPLEFT",     pnjPanel, "TOPLEFT",     2,  -24)
pnjScrollFrame:SetPoint("BOTTOMRIGHT", pnjPanel, "BOTTOMRIGHT", -18,  4)
pnjScrollFrame:EnableMouseWheel(true)

local pnjContent = CreateFrame("Frame", nil, pnjScrollFrame)
pnjContent:SetWidth(pnjScrollFrame:GetWidth())
pnjContent:SetHeight(1)
pnjScrollFrame:SetScrollChild(pnjContent)

local pnjScrollSlider = CreateFrame("Slider", nil, pnjPanel)
pnjScrollSlider:SetOrientation("VERTICAL")
pnjScrollSlider:SetPoint("TOPRIGHT", pnjPanel, "TOPRIGHT", -7, -30)
pnjScrollSlider:SetPoint("BOTTOMRIGHT", pnjPanel, "BOTTOMRIGHT", -7, 10)
pnjScrollSlider:SetWidth(8)
pnjScrollSlider:SetMinMaxValues(0, 0)
pnjScrollSlider:SetValueStep(1)
pnjScrollSlider:SetValue(0)

local pnjTrack = pnjScrollSlider:CreateTexture(nil, "BACKGROUND")
pnjTrack:SetPoint("TOP", pnjScrollSlider, "TOP", 0, 0)
pnjTrack:SetPoint("BOTTOM", pnjScrollSlider, "BOTTOM", 0, 0)
pnjTrack:SetWidth(4)
pnjTrack:SetColorTexture(0.10, 0.10, 0.10, 0.82)

local pnjThumb = pnjScrollSlider:CreateTexture(nil, "ARTWORK")
pnjThumb:SetSize(10, 28)
pnjThumb:SetColorTexture(0.46, 0.42, 0.32, 0.95)
pnjScrollSlider:SetThumbTexture(pnjThumb)
pnjScrollSlider:Hide()

local function UpdatePnjScrollRange()
    local viewportH = math.max(1, pnjScrollFrame:GetHeight())
    local contentH = math.max(1, pnjContent:GetHeight())
    local maxScroll = math.max(0, contentH - viewportH)
    pnjScrollSlider:SetMinMaxValues(0, maxScroll)
    pnjScrollSlider:SetValueStep(20)

    if maxScroll <= 0 then
        pnjScrollFrame:SetVerticalScroll(0)
        pnjScrollSlider:SetValue(0)
        pnjScrollSlider:Hide()
    else
        pnjScrollSlider:Show()
        if pnjScrollSlider:GetValue() > maxScroll then pnjScrollSlider:SetValue(maxScroll) end
    end
end

pnjScrollSlider:SetScript("OnValueChanged", function(_, value)
    pnjScrollFrame:SetVerticalScroll(value or 0)
end)

pnjScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    local _, maxScroll = pnjScrollSlider:GetMinMaxValues()
    if maxScroll <= 0 then return end
    local nextValue = pnjScrollSlider:GetValue() - (delta * 34)
    pnjScrollSlider:SetValue(math.max(0, math.min(maxScroll, nextValue)))
end)

local lastNpcCount = 0

local function RebuildPnj()
    local npcs = {}
    for _, p in ipairs(C.initiative.participants) do
        if p.kind == "npc" then table.insert(npcs, p) end
    end

    -- Réapparaît automatiquement dès qu'un nouveau lot de PNJ démarre
    -- (0 → au moins 1), même si le MJ avait fermé le panneau juste avant.
    if lastNpcCount == 0 and #npcs > 0 then
        pnjManuallyClosed = false
    end
    lastNpcCount = #npcs

    pnjContent:SetWidth(math.max(1, pnjScrollFrame:GetWidth()))
    for _, row in pairs(pnjRows) do row:Hide() end

    local totalH = 0
    for _, p in ipairs(npcs) do
        if not pnjRows[p.id] then
            pnjRows[p.id] = NpcRow(pnjContent, p.id)
        end
        local row = pnjRows[p.id]
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  pnjContent, "TOPLEFT",  0, -totalH)
        row:SetPoint("TOPRIGHT", pnjContent, "TOPRIGHT", 0, -totalH)
        row:Show()
        row:Refresh(p)
        totalH = totalH + ROW_H + 2
    end

    pnjContent:SetHeight(math.max(1, totalH))
    UpdatePnjScrollRange()

    if #npcs > 0 and mjPanel:IsShown() and not pnjManuallyClosed then
        pnjPanel:Show()
    else
        pnjPanel:Hide()
    end
end

RefreshTurnHighlights = function()
    local cur = C.initiative.active and C.initiative.participants[C.initiative.currentIndex]
    for name, row in pairs(rows) do
        if row.SetTurn then row:SetTurn(cur and cur.kind == "player" and cur.id == name) end
    end
    for npcId, row in pairs(pnjRows) do
        if row.SetTurn then row:SetTurn(cur and cur.kind == "npc" and cur.id == npcId) end
    end
end

local prevInitPnj = C.OnInitiativeChanged
C.OnInitiativeChanged = function()
    if prevInitPnj then prevInitPnj() end
    RebuildPnj()
    RefreshTurnHighlights()
end

-- Ajoutés en plus des OnShow/OnHide déjà posés sur mjPanel plus haut.
mjPanel:HookScript("OnShow", function() RebuildPnj() end)
mjPanel:HookScript("OnHide", function() pnjPanel:Hide() end)
