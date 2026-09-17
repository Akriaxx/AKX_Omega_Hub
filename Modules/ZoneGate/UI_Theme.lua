-- ============================================================
--  Zone Gate — Éditeur de thèmes de bannière
--  Fenêtre à part (ouverte depuis le panneau principal, bouton
--  "Thèmes...") : un thème est autonome et réutilisable sur
--  plusieurs Zones/Sous-zones — voir ZG:ResolveTheme dans
--  Core.lua pour la règle d'héritage Zone → Sous-zone.
--  Colonne gauche : liste de mes thèmes. Colonne droite : formulaire.
-- ============================================================

local ZG = ZoneGate
local UI = OS2.UI

local function MyName() return UnitName("player") or "" end

local PANEL_W = 640
local PANEL_H = 700   -- assez haut pour le chemin de police perso + séparateur titre/sous-titre + cadre en plus
local PAD     = 12
local HEADER_H = 40
local LIST_W  = 160
local ROW_H   = 42

local panel = CreateFrame("Frame", "ZoneGateThemePanel", UIParent, "BackdropTemplate")
panel:SetSize(PANEL_W, PANEL_H)
panel:SetPoint("CENTER", 40, 0)
panel:SetFrameStrata("HIGH")
panel:SetFrameLevel(50)   -- au-dessus du panneau principal s'ils se chevauchent
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop",  panel.StopMovingOrSizing)
panel:Hide()

local panelBg = panel:CreateTexture(nil, "BACKGROUND")
panelBg:SetAllPoints()
UI.ApplyWindowBackground(panelBg, 0.97)

panel:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
panel:SetBackdropBorderColor(unpack(UI.colors.separator))

local header = CreateFrame("Frame", nil, panel)
header:SetPoint("TOPLEFT",  4, -4)
header:SetPoint("TOPRIGHT", -4, -4)
header:SetHeight(HEADER_H - 4)

local headerBg = header:CreateTexture(nil, "BACKGROUND")
headerBg:SetAllPoints()
UI.ApplyWindowBackground(headerBg, 0.70)

local headerAccent = header:CreateTexture(nil, "ARTWORK")
headerAccent:SetWidth(3)
headerAccent:SetPoint("TOPLEFT")
headerAccent:SetPoint("BOTTOMLEFT")
headerAccent:SetColorTexture(unpack(UI.colors.tabLine))

local titleText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("LEFT", header, "LEFT", PAD, 0)
titleText:SetText("Thèmes de bannière")
UI.ApplyTitle(titleText)

UI.CreateCloseButton(panel, function() panel:Hide() end)

local sep1 = panel:CreateTexture(nil, "ARTWORK")
sep1:SetPoint("TOPLEFT",  4, -(HEADER_H - 2))
sep1:SetPoint("TOPRIGHT", -4, -(HEADER_H - 2))
sep1:SetHeight(1)
UI.ApplySeparator(sep1)

function panel:Toggle()
    if self:IsShown() then
        self:Hide()
    else
        panel:RefreshAll()
        self:Show()
    end
end

-- Rouvre la fenêtre sur un thème précis — utilisé par le sélecteur de
-- thème du panneau principal ("Modifier ce thème").
function panel:EditTheme(id)
    panel.selectedId = id
    panel:RefreshAll()
    panel:Show()
end

-- ── Colonne gauche : liste de mes thèmes ───────────────────────────────────

panel.selectedId = nil

local listHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
listHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 8))
listHeader:SetText("Mes thèmes")
UI.ApplyLabel(listHeader)

local addBtn = UI.CreateAddButton(panel, function()
    local theme = ZG:CreateTheme("Nouveau thème")
    if theme then
        panel.selectedId = theme.id
        panel:RefreshAll()
    end
end)
addBtn:SetPoint("LEFT", listHeader, "RIGHT", 6, 0)

local listScroll = CreateFrame("ScrollFrame", nil, panel)
listScroll:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD, -(HEADER_H + 28))
listScroll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD, PAD)
listScroll:SetWidth(LIST_W)
listScroll:EnableMouseWheel(true)

local listContent = CreateFrame("Frame", nil, listScroll)
listContent:SetWidth(LIST_W)
listContent:SetHeight(1)
listScroll:SetScrollChild(listContent)

listScroll:SetScript("OnMouseWheel", function(self, delta)
    local maxScroll = self:GetVerticalScrollRange()
    local cur = self:GetVerticalScroll()
    self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 24)))
end)

local listSep = panel:CreateTexture(nil, "ARTWORK")
listSep:SetPoint("TOPLEFT",    panel, "TOPLEFT",    PAD + LIST_W + 8, -(HEADER_H + 4))
listSep:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", PAD + LIST_W + 8, PAD)
listSep:SetWidth(1)
UI.ApplySeparator(listSep, true)

local rows = {}
local function GetRow(index)
    local row = rows[index]
    if row then return row end

    row = CreateFrame("Button", nil, listContent)
    row:SetSize(LIST_W, ROW_H)

    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(UI.colors.rowBg))

    local sel = row:CreateTexture(nil, "ARTWORK")
    sel:SetAllPoints()
    sel:SetColorTexture(unpack(UI.colors.rowSelection))
    sel:Hide()
    row.sel = sel

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", row, "LEFT", 6, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")
    UI.ApplyBodyText(label)
    row.label = label

    rows[index] = row
    return row
end

local function HideExtraRows(fromIndex)
    for i = fromIndex, #rows do rows[i]:Hide() end
end

function panel:RefreshList()
    local list = ZG:GetThemeList()
    local filtered={}
    for _,theme in ipairs(list) do
        if not panel.searchText or panel.searchText=="" or string.find(string.lower(theme.name or ""),panel.searchText,1,true) then
            filtered[#filtered+1]=theme
        end
    end
    list=filtered
    for i, theme in ipairs(list) do
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:Show()
        row.label:SetText(theme.name)
        row.sel:SetShown(panel.selectedId == theme.id)
        row:SetScript("OnClick", function()
            panel.selectedId = theme.id
            panel:RefreshAll()
        end)
    end
    HideExtraRows(#list + 1)
    listContent:SetHeight(math.max(1, #list * ROW_H))
end

-- ── Colonne droite : formulaire ─────────────────────────────────────────────

local form = CreateFrame("Frame", nil, panel)
form:SetPoint("TOPLEFT",     panel, "TOPLEFT",     PAD + LIST_W + 16, -(HEADER_H + 10))
form:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PAD, PAD)

local placeholder = form:CreateFontString(nil, "OVERLAY", "GameFontNormal")
placeholder:SetPoint("TOPLEFT", form, "TOPLEFT", 4, -6)
placeholder:SetText("Sélectionnez un thème à gauche, ou créez-en un\navec le \"+\".\n\nUn thème posé sur une Zone est hérité par toutes\nses Sous-zones ; en poser un directement sur une\nSous-zone l'emporte sur celui de la Zone.")
placeholder:SetJustifyH("LEFT")
UI.ApplyMutedText(placeholder)

local editForm = CreateFrame("Frame", nil, form)
editForm:SetAllPoints()

-- Nom
local nameEB = UI.CreateStyledEditBox(editForm, 260, 22, false)
nameEB:SetPoint("TOPLEFT", editForm, "TOPLEFT", 4, -4)
nameEB:SetMaxLetters(48)
nameEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedId then return end
    ZG:RenameTheme(panel.selectedId, self:GetText())
    panel:RefreshList()
end)

local deleteBtn = UI.CreatePanelButton(editForm, 90, 22, "Supprimer")
deleteBtn:SetPoint("LEFT", nameEB, "RIGHT", 8, 0)
deleteBtn:SetScript("OnClick", function()
    if panel.selectedId then
        ZG:RemoveTheme(panel.selectedId)
        panel.selectedId = nil
        panel:RefreshAll()
    end
end)

-- Police
local fontLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
fontLabel:SetPoint("TOPLEFT", nameEB, "BOTTOMLEFT", 2, -14)
fontLabel:SetText("Police")
UI.ApplyLabel(fontLabel)

local fontDropdown = CreateFrame("Frame", "ZoneGateThemeFontDropdown", editForm, "UIDropDownMenuTemplate")
fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -16, -4)
UIDropDownMenu_SetWidth(fontDropdown, 230)
UI.StyleDropdown(fontDropdown)

UIDropDownMenu_Initialize(fontDropdown, function(self, level)
    local theme = panel.selectedId and ZG:GetTheme(panel.selectedId)
    for _, key in ipairs(ZG.FontOrder) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = ZG.FontLabels[key]
        info.notCheckable = true
        info.func = function()
            if panel.selectedId then
                ZG:SetThemeFont(panel.selectedId, key)
                panel:RefreshForm()
            end
        end
        UIDropDownMenu_AddButton(info, level)
    end
end)

-- Taille du titre
local sizeLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sizeLabel:SetPoint("LEFT", fontDropdown, "RIGHT", 30, 2)
sizeLabel:SetText("Taille")
UI.ApplyLabel(sizeLabel)

local sizeEB = UI.CreateStyledEditBox(editForm, 50, 20, false)
sizeEB:SetPoint("LEFT", sizeLabel, "RIGHT", 8, 0)
sizeEB:SetMaxLetters(3)
sizeEB:SetScript("OnEnterPressed", function(self)
    if panel.selectedId then ZG:SetThemeTitleSize(panel.selectedId, tonumber(self:GetText())) end
    self:ClearFocus()
end)
sizeEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

-- Chemin de la police "Personnalisée" — visible seulement si font == "custom"
-- (voir ZG.FontPaths dans Core.lua : pointez ici vers une police fournie par
-- un autre addon si les 7 déjà proposées ne suffisent pas).
local customFontLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
customFontLabel:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 16, -10)
customFontLabel:SetText("Chemin :")
UI.ApplyMutedText(customFontLabel)

local customFontEB = UI.CreateStyledEditBox(editForm, 300, 20, false)
customFontEB:SetPoint("LEFT", customFontLabel, "RIGHT", 6, 0)
customFontEB:SetMaxLetters(200)
customFontEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedId then return end
    ZG:SetThemeCustomFont(panel.selectedId, self:GetText())
end)

-- Couleurs (titre / sous-titre / séparateur / fond)
local colorsLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
colorsLabel:SetPoint("TOPLEFT", customFontLabel, "BOTTOMLEFT", -16, -14)
colorsLabel:SetText("Couleurs")
UI.ApplyLabel(colorsLabel)

local function LabeledSwatch(anchorTo, labelText, hasAlpha, onChanged)
    local lbl = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -10)
    lbl:SetText(labelText)
    UI.ApplyMutedText(lbl)

    local swatch = UI.CreateColorSwatch(editForm, 18, hasAlpha)
    swatch:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    swatch.onColorChanged = function(r, g, b, a)
        if panel.selectedId then onChanged(panel.selectedId, r, g, b, a) end
    end
    return lbl, swatch
end

local titleColorLbl, titleColorSwatch = LabeledSwatch(colorsLabel, "Titre :", false,
    function(id, r, g, b) ZG:SetThemeColor(id, "title", r, g, b) end)
local subColorLbl, subColorSwatch = LabeledSwatch(titleColorLbl, "Sous-titre :", false,
    function(id, r, g, b) ZG:SetThemeColor(id, "sub", r, g, b) end)
subColorLbl:ClearAllPoints()
subColorLbl:SetPoint("LEFT", titleColorSwatch, "RIGHT", 20, 0)

local sepColorLbl, sepColorSwatch = LabeledSwatch(titleColorLbl, "Séparateur :", true,
    function(id, r, g, b, a) ZG:SetThemeColor(id, "sep", r, g, b, a) end)
sepColorLbl:ClearAllPoints()
sepColorLbl:SetPoint("LEFT", subColorSwatch, "RIGHT", 20, 0)

-- Effets de texte
local outlineCB, outlineLabel = UI.CreateStyledCheckbox(editForm, "Contour")
outlineCB:SetPoint("TOPLEFT", titleColorLbl, "BOTTOMLEFT", -2, -14)
outlineLabel:SetPoint("LEFT", outlineCB, "RIGHT", 4, 0)
outlineCB:SetScript("OnClick", function(self)
    if panel.selectedId then ZG:SetThemeOutline(panel.selectedId, self:GetChecked()) end
end)

local upperCB, upperLabel = UI.CreateStyledCheckbox(editForm, "MAJUSCULES")
upperCB:SetPoint("LEFT", outlineLabel, "RIGHT", 16, 0)
upperLabel:SetPoint("LEFT", upperCB, "RIGHT", 4, 0)
upperCB:SetScript("OnClick", function(self)
    if panel.selectedId then ZG:SetThemeUppercase(panel.selectedId, self:GetChecked()) end
end)

local spaceCB, spaceLabel = UI.CreateStyledCheckbox(editForm, "E s p a c é")
spaceCB:SetPoint("LEFT", upperLabel, "RIGHT", 16, 0)
spaceLabel:SetPoint("LEFT", spaceCB, "RIGHT", 4, 0)
spaceCB:SetScript("OnClick", function(self)
    if panel.selectedId then ZG:SetThemeLetterSpacing(panel.selectedId, self:GetChecked()) end
end)

-- Séparateur : style
local sepStyleLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
sepStyleLabel:SetPoint("TOPLEFT", outlineCB, "BOTTOMLEFT", 2, -14)
sepStyleLabel:SetText("Style du séparateur")
UI.ApplyLabel(sepStyleLabel)

local sepSingleBtn = UI.CreatePanelButton(editForm, 60, 20, "Simple")
sepSingleBtn:SetPoint("TOPLEFT", sepStyleLabel, "BOTTOMLEFT", -2, -8)
local sepDoubleBtn = UI.CreatePanelButton(editForm, 60, 20, "Double")
sepDoubleBtn:SetPoint("LEFT", sepSingleBtn, "RIGHT", 4, 0)
local sepNoneBtn = UI.CreatePanelButton(editForm, 60, 20, "Aucun")
sepNoneBtn:SetPoint("LEFT", sepDoubleBtn, "RIGHT", 4, 0)
sepSingleBtn:SetScript("OnClick", function()
    if panel.selectedId then ZG:SetThemeSeparatorStyle(panel.selectedId, "single"); panel:RefreshForm() end
end)
sepDoubleBtn:SetScript("OnClick", function()
    if panel.selectedId then ZG:SetThemeSeparatorStyle(panel.selectedId, "double"); panel:RefreshForm() end
end)
sepNoneBtn:SetScript("OnClick", function()
    if panel.selectedId then ZG:SetThemeSeparatorStyle(panel.selectedId, "none"); panel:RefreshForm() end
end)

-- Ligne indépendante entre le titre et le sous-titre (toujours simple, même
-- couleur que le style ci-dessus — n'affecte pas les lignes haut/bas).
local midSepCB, midSepLabel = UI.CreateStyledCheckbox(editForm, "Séparateur titre / sous-titre")
midSepCB:SetPoint("TOPLEFT", sepSingleBtn, "BOTTOMLEFT", 0, -14)
midSepLabel:SetPoint("LEFT", midSepCB, "RIGHT", 4, 0)
midSepCB:SetScript("OnClick", function(self)
    if panel.selectedId then ZG:SetThemeMidSeparator(panel.selectedId, self:GetChecked()) end
end)

-- Bandeau de fond
local bgCB, bgLabel = UI.CreateStyledCheckbox(editForm, "Bandeau de fond")
bgCB:SetPoint("TOPLEFT", midSepCB, "BOTTOMLEFT", 0, -14)
bgLabel:SetPoint("LEFT", bgCB, "RIGHT", 4, 0)
bgCB:SetScript("OnClick", function(self)
    if panel.selectedId then ZG:SetThemeBackgroundEnabled(panel.selectedId, self:GetChecked()) end
end)

local bgColorSwatch = UI.CreateColorSwatch(editForm, 18, true)
bgColorSwatch:SetPoint("LEFT", bgLabel, "RIGHT", 10, 0)
bgColorSwatch.onColorChanged = function(r, g, b, a)
    if panel.selectedId then ZG:SetThemeColor(panel.selectedId, "bg", r, g, b, a) end
end

-- Cadre autour de la bannière — indépendant du bandeau de fond ci-dessus et
-- des séparateurs plus haut, se cumule librement avec les deux.
local frameStyleLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
frameStyleLabel:SetPoint("TOPLEFT", bgCB, "BOTTOMLEFT", 2, -14)
frameStyleLabel:SetText("Cadre")
UI.ApplyLabel(frameStyleLabel)

local frameNoneBtn = UI.CreatePanelButton(editForm, 60, 20, "Aucun")
frameNoneBtn:SetPoint("TOPLEFT", frameStyleLabel, "BOTTOMLEFT", -2, -8)
local frameBoxBtn = UI.CreatePanelButton(editForm, 60, 20, "Simple")
frameBoxBtn:SetPoint("LEFT", frameNoneBtn, "RIGHT", 4, 0)
local frameOrnateBtn = UI.CreatePanelButton(editForm, 60, 20, "Orné")
frameOrnateBtn:SetPoint("LEFT", frameBoxBtn, "RIGHT", 4, 0)
frameNoneBtn:SetScript("OnClick", function()
    if panel.selectedId then ZG:SetThemeFrameStyle(panel.selectedId, "none"); panel:RefreshForm() end
end)
frameBoxBtn:SetScript("OnClick", function()
    if panel.selectedId then ZG:SetThemeFrameStyle(panel.selectedId, "box"); panel:RefreshForm() end
end)
frameOrnateBtn:SetScript("OnClick", function()
    if panel.selectedId then ZG:SetThemeFrameStyle(panel.selectedId, "ornate"); panel:RefreshForm() end
end)

local frameColorSwatch = UI.CreateColorSwatch(editForm, 18, true)
frameColorSwatch:SetPoint("LEFT", frameOrnateBtn, "RIGHT", 12, 0)
frameColorSwatch.onColorChanged = function(r, g, b, a)
    if panel.selectedId then ZG:SetThemeColor(panel.selectedId, "frame", r, g, b, a) end
end

-- Timing (secondes)
local timingLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
timingLabel:SetPoint("TOPLEFT", frameNoneBtn, "BOTTOMLEFT", 2, -16)
timingLabel:SetText("Animation (secondes) : apparition / maintien / disparition")
UI.ApplyLabel(timingLabel)

local fadeInEB = UI.CreateStyledEditBox(editForm, 44, 20, false)
fadeInEB:SetPoint("TOPLEFT", timingLabel, "BOTTOMLEFT", -2, -8)
fadeInEB:SetMaxLetters(4)
local holdEB = UI.CreateStyledEditBox(editForm, 44, 20, false)
holdEB:SetPoint("LEFT", fadeInEB, "RIGHT", 6, 0)
holdEB:SetMaxLetters(4)
local fadeOutEB = UI.CreateStyledEditBox(editForm, 44, 20, false)
fadeOutEB:SetPoint("LEFT", holdEB, "RIGHT", 6, 0)
fadeOutEB:SetMaxLetters(4)

local function CommitTiming()
    if not panel.selectedId then return end
    ZG:SetThemeTiming(panel.selectedId, tonumber(fadeInEB:GetText()), tonumber(holdEB:GetText()), tonumber(fadeOutEB:GetText()))
end
for _, eb in ipairs({ fadeInEB, holdEB, fadeOutEB }) do
    eb:SetScript("OnEnterPressed", function(self) CommitTiming(); self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
end

-- Son (entrée / retour) — un ID SoundKit Blizzard (nombre) ou un chemin de
-- fichier ("Sound\..." natif ou un .ogg/.mp3 déposé par vous dans le
-- dossier de l'addon), voir ResolveSoundValue dans Core.lua.
local soundLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
soundLabel:SetPoint("TOPLEFT", fadeInEB, "BOTTOMLEFT", 2, -16)
soundLabel:SetText("Son (dossier Music, ou ID SoundKit Blizzard / chemin manuel)")
UI.ApplyLabel(soundLabel)

-- Menu "dossier Music" partagé par les deux boutons 🎵 (entrée/retour) —
-- reconstruit à chaque ouverture à partir de ZG:GetMusicList() (voir
-- Core.lua : liste générée à l'avance dans Music/Manifest.lua, WoW ne
-- pouvant pas lire un dossier lui-même). Choisir une entrée remplit le
-- champ correspondant (déclenche son OnTextChanged normalement).
local musicMenuFrame = CreateFrame("Frame", "ZoneGateMusicMenuFrame", editForm, "UIDropDownMenuTemplate")
musicMenuFrame:Hide()

local function ShowMusicMenu(anchorBtn, targetEB)
    local menu = {
        { text = "(Aucun)", notCheckable = true, func = function() targetEB:SetText("") end },
    }
    local files = ZG:GetMusicList()
    if #files == 0 then
        table.insert(menu, { text = "(dossier Music vide — voir Music/README.txt)", notCheckable = true, isTitle = true })
    else
        for _, entry in ipairs(files) do
            table.insert(menu, {
                text = entry.name, notCheckable = true,
                func = function() targetEB:SetText(entry.path) end,
            })
        end
    end
    EasyMenu(menu, musicMenuFrame, anchorBtn, 0, 0, "MENU")
end

local soundEnterLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
soundEnterLabel:SetPoint("TOPLEFT", soundLabel, "BOTTOMLEFT", 0, -8)
soundEnterLabel:SetText("Entrée :")
UI.ApplyMutedText(soundEnterLabel)

local soundEnterEB = UI.CreateStyledEditBox(editForm, 150, 20, false)
soundEnterEB:SetPoint("LEFT", soundEnterLabel, "RIGHT", 6, 0)
soundEnterEB:SetMaxLetters(200)
soundEnterEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedId then return end
    ZG:SetThemeSound(panel.selectedId, "enter", self:GetText())
end)

local musicEnterBtn = UI.CreatePanelButton(editForm, 40, 20, "Mus.")
musicEnterBtn:SetPoint("LEFT", soundEnterEB, "RIGHT", 4, 0)
musicEnterBtn:SetScript("OnClick", function() ShowMusicMenu(musicEnterBtn, soundEnterEB) end)

local testEnterBtn = UI.CreatePanelButton(editForm, 52, 20, "Tester")
testEnterBtn:SetPoint("LEFT", musicEnterBtn, "RIGHT", 4, 0)
testEnterBtn:SetScript("OnClick", function()
    local theme = panel.selectedId and ZG:GetTheme(panel.selectedId)
    if theme then ZG:PlayCrossingSound(theme, "forward") end
end)

local soundExitLabel = editForm:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
soundExitLabel:SetPoint("TOPLEFT", soundEnterLabel, "BOTTOMLEFT", 0, -8)
soundExitLabel:SetText("Retour :")
UI.ApplyMutedText(soundExitLabel)

local soundExitEB = UI.CreateStyledEditBox(editForm, 150, 20, false)
soundExitEB:SetPoint("LEFT", soundExitLabel, "RIGHT", 6, 0)
soundExitEB:SetMaxLetters(200)
soundExitEB:SetScript("OnTextChanged", function(self)
    if panel.suppressEvents or not panel.selectedId then return end
    ZG:SetThemeSound(panel.selectedId, "exit", self:GetText())
end)

local musicExitBtn = UI.CreatePanelButton(editForm, 40, 20, "Mus.")
musicExitBtn:SetPoint("LEFT", soundExitEB, "RIGHT", 4, 0)
musicExitBtn:SetScript("OnClick", function() ShowMusicMenu(musicExitBtn, soundExitEB) end)

local testExitBtn = UI.CreatePanelButton(editForm, 52, 20, "Tester")
testExitBtn:SetPoint("LEFT", musicExitBtn, "RIGHT", 4, 0)
testExitBtn:SetScript("OnClick", function()
    local theme = panel.selectedId and ZG:GetTheme(panel.selectedId)
    if theme then ZG:PlayCrossingSound(theme, "backward") end
end)

-- Aperçu — rejoue la bannière avec ce thème et un texte d'exemple, sans
-- passer par un vrai franchissement.
local previewBtn = UI.CreatePanelButton(editForm, 160, 24, "Aperçu de la bannière")
previewBtn:SetPoint("TOPLEFT", soundExitLabel, "BOTTOMLEFT", -2, -18)
previewBtn:SetScript("OnClick", function()
    local theme = panel.selectedId and ZG:GetTheme(panel.selectedId)
    if theme and ZG.ShowBanner then
        ZG:ShowBanner("Nom de la Zone", "Nom de la Sous-zone", theme)
    end
end)

function panel:RefreshForm()
    local theme = panel.selectedId and ZG:GetTheme(panel.selectedId)
    if not theme or theme.creator ~= MyName() then
        editForm:Hide()
        placeholder:Show()
        return
    end
    placeholder:Hide()
    editForm:Show()

    panel.suppressEvents = true
    nameEB:SetText(theme.name or "")
    sizeEB:SetText(tostring(theme.titleSize or 28))
    customFontEB:SetText(theme.customFont or "")
    soundEnterEB:SetText(theme.soundEnter or "")
    soundExitEB:SetText(theme.soundExit or "")
    panel.suppressEvents = false

    UIDropDownMenu_SetText(fontDropdown, ZG.FontLabels[theme.font] or ZG.FontLabels.frizqt)
    customFontLabel:SetShown(theme.font == "custom")
    customFontEB:SetShown(theme.font == "custom")

    local tc = theme.titleColor or ZG.DefaultTheme.titleColor
    titleColorSwatch:SetColor(tc[1], tc[2], tc[3], 1)
    local sc = theme.subColor or ZG.DefaultTheme.subColor
    subColorSwatch:SetColor(sc[1], sc[2], sc[3], 1)
    local sep = theme.sepColor or ZG.DefaultTheme.sepColor
    sepColorSwatch:SetColor(sep[1], sep[2], sep[3], sep[4] or 1)
    local bg = theme.bgColor or ZG.DefaultTheme.bgColor
    bgColorSwatch:SetColor(bg[1], bg[2], bg[3], bg[4] or 1)
    local frameCol = theme.frameColor or ZG.DefaultTheme.frameColor
    frameColorSwatch:SetColor(frameCol[1], frameCol[2], frameCol[3], frameCol[4] or 1)

    outlineCB:SetChecked(theme.outline)
    upperCB:SetChecked(theme.uppercase)
    spaceCB:SetChecked(theme.letterSpacing)

    sepSingleBtn.accent:SetShown(theme.sepStyle == "single")
    sepDoubleBtn.accent:SetShown(theme.sepStyle == "double")
    sepNoneBtn.accent:SetShown(theme.sepStyle == "none")
    midSepCB:SetChecked(theme.midSepEnabled)

    bgCB:SetChecked(theme.bgEnabled)
    bgColorSwatch:SetShown(true)

    frameNoneBtn.accent:SetShown(theme.frameStyle == "none")
    frameBoxBtn.accent:SetShown(theme.frameStyle == "box")
    frameOrnateBtn.accent:SetShown(theme.frameStyle == "ornate")

    fadeInEB:SetText(string.format("%.1f", theme.fadeIn or 0.4))
    holdEB:SetText(string.format("%.1f", theme.hold or 2.5))
    fadeOutEB:SetText(string.format("%.1f", theme.fadeOut or 0.8))
end

function panel:RefreshAll()
    if panel.selectedId and not ZG:GetTheme(panel.selectedId) then panel.selectedId = nil end
    panel:RefreshList()
    panel:RefreshForm()
end

-- Public handles used by the studio layout; the original setters remain
-- the only route for individual setting changes.
panel.studioControls={
    title=titleText,form=form,edit=editForm,placeholder=placeholder,
    listScroll=listScroll,listContent=listContent,listSep=listSep,listHeader=listHeader,
    name=nameEB,delete=deleteBtn,preview=previewBtn,
    fontLabel=fontLabel,colorsLabel=colorsLabel,sepStyleLabel=sepStyleLabel,
    sepColorLbl=sepColorLbl,sepColorSwatch=sepColorSwatch,timingLabel=timingLabel,
    customFontLabel=customFontLabel,customFont=customFontEB,
    size=sizeEB,fadeIn=fadeInEB,hold=holdEB,fadeOut=fadeOutEB,
    text={fontLabel,fontDropdown,sizeLabel,sizeEB,customFontLabel,customFontEB,colorsLabel,
        titleColorLbl,titleColorSwatch,subColorLbl,subColorSwatch,outlineCB,outlineLabel,upperCB,upperLabel,spaceCB,spaceLabel},
    decor={sepStyleLabel,sepSingleBtn,sepDoubleBtn,sepNoneBtn,sepColorLbl,sepColorSwatch,
        midSepCB,midSepLabel,bgCB,bgLabel,bgColorSwatch,frameStyleLabel,frameNoneBtn,frameBoxBtn,frameOrnateBtn,frameColorSwatch},
    timing={timingLabel,fadeInEB,holdEB,fadeOutEB,soundLabel,soundEnterLabel,soundEnterEB,
        musicEnterBtn,testEnterBtn,soundExitLabel,soundExitEB,musicExitBtn,testExitBtn},
    swatches={titleColorSwatch,subColorSwatch,sepColorSwatch,bgColorSwatch,frameColorSwatch},
}
panel:RefreshForm()
