-- ============================================================
--  Character - Bouton Action
--  Fenêtre indépendante et déplaçable, affichée/masquée par
--  Shift+Clic gauche sur le portrait (voir UI_HUD.lua) ; cet état
--  est retenu par personnage d'un /reload à l'autre. Apparaît au centre
--  de l'écran la première fois, puis garde sa position glissée
--  (par personnage, comme le portrait/ressources).
--  Clic : ouvre un triangle de 4 catégories (Offensive en haut,
--  Défensive en bas à droite, Distance en bas à gauche, Actions
--  de base au centre). Clic sur une catégorie : le triangle se
--  referme, le bouton pressé se pose à gauche, et une ligne
--  d'icônes s'ouvre à sa droite avec chaque compétence de la
--  base de données (voir UI_Skills.lua).
--  Clic droit sur le bouton replié : panneau rapide pour choisir
--  les compétences affichées et leur ordre (bas du fichier).
--  Maintenir un bouton (repos ou catégorie) déplace la fenêtre.
-- ============================================================
local C = Character
local UI = C.RPGUI or OS2.UI
local hud = CharacterResourceHUD
if not hud or not C.SKILL_CATEGORIES then return end

local BTN = 36
local ICON = 29
local GAP = 4

-- Icônes fixes des 4 catégories (pas éditables, contrairement aux
-- compétences elles-mêmes) + tooltip qui affiche le libellé complet.
local CATEGORY_ICON = {
    offensive = "Interface\\Icons\\Ability_Warrior_Savageblow",
    defensive = "Interface\\Icons\\Ability_Defend",
    ranged    = "Interface\\Icons\\Ability_Marksmanship",
    base      = "Interface\\Icons\\INV_Misc_Gear_01",
}
-- Logo d'Eindhill (Media/EindhillLogo.blp, généré par Tests/logo-blp.py).
local IDLE_ICON = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\EindhillLogo"

-- Décalages (centre-à-centre) des 4 boutons du triangle, relatifs au coin
-- TOPLEFT de `root`. "base" partage la position de repos (0,0) : c'est
-- elle qui occupe le centre du triangle ET la position repliée où
-- atterrissent les 3 autres catégories une fois sélectionnées.
local RESET_X, RESET_Y = BTN / 2, -BTN / 2
local OFFSETS = {
    offensive = { 0, 70 },
    ranged    = { -61, -35 },
    defensive = { 61, -35 },
    base      = { 0, 0 },
}

-- Fenêtre indépendante (pas un enfant positionné sous le cadre) : elle
-- garde son propre emplacement à l'écran, glissé par le joueur, tant que
-- Character reste actif (parentée à hud pour se masquer avec lui).
local root = CreateFrame("Frame", "CharacterActionMenu", hud)
root:SetSize(BTN, BTN)
root:SetMovable(true)
root:SetClampedToScreen(true)
root:Hide()

local function PositionKey()
    return (UnitName("player") or "player") .. "-" .. (GetRealmName() or "")
end
-- Position enregistrée dans l'échelle de UIParent (space = "ui"), pas
-- dans celle de root : changer la taille du bouton ou du cadre principal
-- ne le déplace plus à l'écran. Les anciennes positions (sans space)
-- restent lues telles quelles.
local function SaveActionPosition()
    CharacterDB.actionButtonPositions = CharacterDB.actionButtonPositions or {}
    local x, y = root:GetCenter()
    if not x then return end
    local ratio = root:GetEffectiveScale() / UIParent:GetEffectiveScale()
    CharacterDB.actionButtonPositions[PositionKey()] = {
        point = "CENTER", relative = "BOTTOMLEFT", x = x * ratio, y = y * ratio, space = "ui",
    }
end
local function ApplyActionPosition()
    root:ClearAllPoints()
    local saved = CharacterDB.actionButtonPositions and CharacterDB.actionButtonPositions[PositionKey()]
    if saved and saved.space == "ui" then
        local ratio = UIParent:GetEffectiveScale() / root:GetEffectiveScale()
        root:SetPoint(saved.point, UIParent, saved.relative, saved.x * ratio, saved.y * ratio)
    elseif saved then
        root:SetPoint(saved.point, UIParent, saved.relative, saved.x, saved.y)
    else
        -- Première apparition, ou jamais déplacé : centre de l'écran.
        root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Taille propre au bouton Action (Paramètres -> Taille — Bouton Action).
-- root est l'enfant du cadre principal pour se masquer avec lui : on
-- compense donc l'échelle de ce dernier au lieu d'en hériter.
local function ApplyActionScale()
    local wanted = C:GetSettings().actionScale or 1
    local hudScale = hud:GetScale()
    if not hudScale or hudScale <= 0 then hudScale = 1 end
    root:SetScale(wanted / hudScale)
    if root:IsShown() and not root.dragging then ApplyActionPosition() end
end
hooksecurefunc(hud, "SetScale", ApplyActionScale)
function C:SetActionScale(value)
    local steps = math.floor((math.max(.6, math.min(1.6, tonumber(value) or 1)) - .6) / .05 + .5)
    C:GetSettings().actionScale = .6 + steps * .05
    ApplyActionScale()
end

local function NewSquareButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local bg=b:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints();bg:SetColorTexture(.018,.026,.039,1)
    local mask=b:CreateMaskTexture()
    mask:SetAllPoints();mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    bg:AddMaskTexture(mask)
    local tex=b:CreateTexture(nil,"ARTWORK")
    tex:SetPoint("TOPLEFT",2,-2);tex:SetPoint("BOTTOMRIGHT",-2,2)
    tex:SetTexCoord(.08,.92,.08,.92);tex:AddMaskTexture(mask)
    local ring=b:CreateTexture(nil,"OVERLAY")
    ring:SetAllPoints();ring:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\InitiativeRing.tga")
    local hl=b:CreateTexture(nil,"HIGHLIGHT")
    hl:SetAllPoints();hl:SetColorTexture(.85,.7,.42,.25);hl:AddMaskTexture(mask)
    local back=b:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    back:SetPoint("CENTER",0,1);back:SetText("‹");UI.ApplyTitle(back);back:Hide();b.back=back
    b.tex, b.bg, b.ring, b.mask = tex, bg, ring, mask
    b.hoverVeil=hl
    return b
end

-- ── Bouton de repos : "Action" ──────────────────────────────────────────────
-- Sert aussi de poignée pour déplacer toute la fenêtre (comme le portrait
-- déplace le cadre principal) : maintenir et glisser, au lieu de cliquer,
-- ne doit pas ouvrir le triangle.
local idleBtn = NewSquareButton(root, BTN)
idleBtn:SetPoint("CENTER", root, "TOPLEFT", RESET_X, RESET_Y)
idleBtn.tex:SetTexture(IDLE_ICON)
idleBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
-- Suivi manuel du curseur plutôt que StartMoving : root a une échelle
-- propre qui compense celle de son parent, et StartMoving décalait alors
-- le bouton de plus en plus loin du curseur. Tout est converti dans
-- l'échelle effective de root, celle de ses propres SetPoint.
local function CursorInRoot()
    local x, y = GetCursorPosition()
    local scale = root:GetEffectiveScale()
    return x / scale, y / scale
end
local dragHandle
local function StopActionDrag()
    if dragHandle then dragHandle:SetScript("OnUpdate", nil) end
    dragHandle = nil
    root.dragging = false
end
-- Maintenir et glisser un bouton (repos, catégories) déplace toute la
-- fenêtre, même ouverte ; le clic qui suit un glisser est ignoré
-- (btn.suppressClick). L'écart curseur/bouton se mesure à l'appui, pas à
-- OnDragStart : ce dernier ne part qu'une fois la souris déjà en
-- mouvement, parfois loin du point saisi si le geste est rapide.
local function MakeDragHandle(btn)
    btn:RegisterForDrag("LeftButton")
    local grabX, grabY
    btn:SetScript("OnMouseDown", function()
        btn.suppressClick = false
        local cx, cy = CursorInRoot()
        local rx, ry = root:GetCenter()
        if rx then grabX, grabY = rx - cx, ry - cy end
    end)
    btn:SetScript("OnDragStart", function()
        btn.suppressClick = true
        root.dragging = true
        dragHandle = btn
        local dx, dy = grabX, grabY
        if not dx then
            local cx, cy = CursorInRoot()
            local rx, ry = root:GetCenter()
            dx, dy = rx - cx, ry - cy
        end
        local function Follow()
            local x, y = CursorInRoot()
            root:ClearAllPoints()
            root:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x + dx, y + dy)
        end
        btn:SetScript("OnUpdate", Follow)
        Follow()
    end)
    btn:SetScript("OnDragStop", function()
        if not root.dragging then return end
        StopActionDrag()
        SaveActionPosition()
    end)
end
MakeDragHandle(idleBtn)
idleBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Action", unpack(UI.colors.title))
    GameTooltip:AddLine("Compétences par catégorie", unpack(UI.colors.textMuted))
    GameTooltip:AddLine("Clic droit : choisir et ordonner les compétences", unpack(UI.colors.textMuted))
    GameTooltip:AddLine("Maintenez pour déplacer", unpack(UI.colors.textMuted))
    GameTooltip:Show()
end)
idleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ── Les 4 boutons de catégorie (positions du triangle OU repliées) ─────────
local catButtons = {}
for _, cat in ipairs(C.SKILL_CATEGORIES) do
  if not cat.hidden then -- l'Index n'a pas de place dans le triangle
    local b = NewSquareButton(root, BTN)
    b:Hide()
    b.cat = cat
    b.tex:SetTexture(CATEGORY_ICON[cat.key])
    MakeDragHandle(b)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local isBack = self.back:IsShown()
        GameTooltip:AddLine(isBack and "Retour aux catégories" or cat.label, unpack(UI.colors.title))
        GameTooltip:AddLine(isBack and "Clic pour revenir au menu" or "Clic droit pour fermer", unpack(UI.colors.textMuted))
        GameTooltip:AddLine("Maintenez pour déplacer", unpack(UI.colors.textMuted))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    catButtons[cat.key] = b
  end
end

-- An actual triangle plate, kept behind the four category buttons.
local plate=root:CreateTexture(nil,"BACKGROUND")
plate:SetSize(172,152);plate:SetPoint("CENTER",root,"TOPLEFT",RESET_X,RESET_Y+12)
plate:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\ActionTriangle.tga")
plate:Hide()
for key,b in pairs(catButtons) do
    local label=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    label:SetPoint("TOP",b,"BOTTOM",0,-4)
    label:SetText(({offensive="Offensive",defensive="Défensive",ranged="Distance",base="Actions"})[key])
    UI.ApplyTitle(label);b.label=label;label:Hide()
    -- Lisibilité sur la plaque et sur les icônes : ombre portée noire.
    label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1.5,-1.5)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
end
local strip=CreateFrame("Frame",nil,root)
strip:SetPoint("LEFT",root,"RIGHT",6,0);strip:SetSize(72,56);strip:Hide()
strip:SetClipsChildren(true)
local stripBg=strip:CreateTexture(nil,"BACKGROUND");stripBg:SetAllPoints()
stripBg:SetColorTexture(0,0,0,0)
local viewport=CreateFrame("ScrollFrame",nil,strip)
-- Plus haut que les icônes : place pour leur vaguelette (UI_ActionFX.lua).
viewport:SetPoint("TOPLEFT",16,-8);viewport:SetSize(32,ICON+8)
viewport:EnableMouseWheel(true)
local skillRow=CreateFrame("Frame",nil,viewport);skillRow:SetSize(1,ICON+8)
local ROW_Y=-4
viewport:SetScrollChild(skillRow)
local pageIndex,pageCount,targetWidth=0,1,72
local RefreshSkillRow
local pinnedSkill
local selectedKey,state=nil,"idle"
local pageMotion
local function ResetPageMotion()
    pageMotion=nil;skillRow:SetScript("OnUpdate",nil);skillRow:SetAlpha(1)
    viewport:ClearAllPoints();viewport:SetPoint("TOPLEFT",16,-8)
    for _,b in ipairs(C.ActionFrames and C.ActionFrames.skillButtons or {}) do b:EnableMouse(true) end
end
local function ChangePage(delta)
    if state~="expanded" or pageMotion then return end
    pinnedSkill=nil;C:HideSkillTooltip();C:HideSkillName()
    local nextPage=math.max(0,math.min(pageCount-1,pageIndex+(delta<0 and 1 or -1)))
    if nextPage==pageIndex then return end
    local direction=nextPage>pageIndex and 1 or -1
    local elapsed,swapped=0,false
    pageMotion=true
    for _,b in ipairs(C.ActionFrames.skillButtons) do b:EnableMouse(false) end
    skillRow:SetScript("OnUpdate",function(_,dt)
        elapsed=elapsed+dt
        local t=math.min(1,elapsed/.32)
        local offset,alpha
        if t<.45 then
            local u=t/.45;offset=-direction*14*u*u;alpha=1-u
        else
            if not swapped then pageIndex=nextPage;RefreshSkillRow();swapped=true end
            local u=(t-.45)/.55
            offset=direction*14*(1-u)^3;alpha=1-(1-u)^2
        end
        viewport:ClearAllPoints();viewport:SetPoint("TOPLEFT",16+offset,-8)
        skillRow:SetAlpha(alpha)
        if t>=1 then ResetPageMotion() end
    end)
end
viewport:SetScript("OnMouseWheel",function(_,delta) ChangePage(delta) end)
strip:EnableMouseWheel(true)
strip:SetScript("OnMouseWheel",function(_,delta) ChangePage(delta) end)
strip:HookScript("OnHide",ResetPageMotion)
local function PageArrow(text,side,delta)
    local b=CreateFrame("Button",nil,strip)
    b:SetSize(20,36);b:SetPoint(side,strip,side,side=="LEFT" and 1 or -2,0)
    local label=b:CreateFontString(nil,"OVERLAY","GameFontNormal")
    -- Flèche nettement plus grande que la police standard (+13 px).
    local font,size,flags=label:GetFont()
    if font and size then label:SetFont(font,size+13,flags) end
    label:SetAllPoints();label:SetText(text);label:SetTextColor(.92,.76,.43)
    b:SetScript("OnClick",function() ChangePage(delta) end)
    b:EnableMouseWheel(true);b:SetScript("OnMouseWheel",function(_,d) ChangePage(d) end)
    b:Hide();return b
end
local previousPage=PageArrow("‹","LEFT",1)
local followingPage=PageArrow("›","RIGHT",-1)
local empty=NewSquareButton(skillRow,ICON)
empty:SetPoint("TOPLEFT",0,ROW_Y);empty.tex:Hide();empty.back:SetText("—");empty.back:Show()
empty:SetScript("OnClick",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Aucune action dans cette catégorie");GameTooltip:Show()
end)
empty:SetScript("OnLeave",function() GameTooltip:Hide() end)
local skillButtons={}
RefreshSkillRow=function()
    -- Consultation : toutes les bibliothèques fusionnées, dans l'ordre et
    -- le choix du panneau rapide (clic droit sur le bouton, ListActionSkills).
    local skills=C:ListActionSkills(selectedKey)
    pageCount=math.max(1,math.ceil(#skills/6));pageIndex=math.min(pageIndex,pageCount-1)
    previousPage:SetShown(pageIndex>0)
    followingPage:SetShown(pageIndex<pageCount-1)
    local visible=math.min(6,math.max(0,#skills-pageIndex*6))
    for i=1,visible do
        local skill=skills[pageIndex*6+i]
        local b=skillButtons[i]
        if not b then
            b=NewSquareButton(skillRow,ICON);skillButtons[i]=b
            b.hoverVeil:SetAlpha(0)
            b:SetScript("OnClick",function(self)
                C:HideSkillName()
                if pinnedSkill==self then pinnedSkill=nil;C:HideSkillTooltip();return end
                pinnedSkill=self
                C:ShowSkillTooltip(self,self.skill)
            end)
            -- Survol : le nom seul ; le clic ouvre la carte avec la description.
            b:SetScript("OnEnter",function(self) if pinnedSkill~=self then C:ShowSkillName(self,self.skill) end end)
            b:SetScript("OnLeave",function() C:HideSkillName() end)
        end
        b.skill=skill;b.tex:SetTexture(C:ResolveIconValue(skill.icon))
        b.baseX,b.baseY=(i-1)*(ICON+GAP),ROW_Y
        b:ClearAllPoints();b:SetPoint("TOPLEFT",b.baseX,b.baseY);b:Show()
    end
    for i=visible+1,#skillButtons do skillButtons[i]:Hide() end
    local width=math.max(1,visible*(ICON+GAP)-GAP)
    empty:SetShown(#skills==0)
    width=math.max(ICON,width)
    targetWidth=width+40
    skillRow:SetWidth(width);viewport:SetHorizontalScroll(0)
    if state=="expanded" then strip:SetWidth(targetWidth);viewport:SetWidth(targetWidth-32) end
    pinnedSkill=nil;C:HideSkillTooltip();C:HideSkillName()
end
-- Éléments exposés à l'habillage animé (UI_ActionFX.lua, chargé après).
C.ActionFrames={
    root=root,idle=idleBtn,cats=catButtons,plate=plate,strip=strip,stripBg=stripBg,
    viewport=viewport,skillButtons=skillButtons,empty=empty,
    BTN=BTN,ICON=ICON,RESET_X=RESET_X,RESET_Y=RESET_Y,OFFSETS=OFFSETS,
    -- Compétence ouverte (carte affichée) : l'habillage la fige au centre du flux.
    IsPinned=function(b) return pinnedSkill==b end,
}
local function Place(b,x,y)
    b:ClearAllPoints();b:SetPoint("CENTER",root,"TOPLEFT",RESET_X+x,RESET_Y+y)
end
local function CancelMotion()
    ResetPageMotion()
    root:SetScript("OnUpdate",nil)
    pinnedSkill=nil;C:HideSkillTooltip();C:HideSkillName()
end
local function Animate(duration,draw,done)
    CancelMotion();state="animating"
    local elapsed=0
    draw(0)
    root:SetScript("OnUpdate",function(_,dt)
        elapsed=math.min(duration,elapsed+dt)
        local t=elapsed/duration
        draw(t)
        if t>=1 then root:SetScript("OnUpdate",nil);done() end
    end)
end
local function ShowIdle()
    CancelMotion();state="idle";selectedKey=nil
    plate:Hide();strip:Hide();strip:SetAlpha(1)
    for _,b in pairs(catButtons) do b:Hide();b:SetAlpha(1);b:SetScale(1) end
    idleBtn:SetAlpha(1);idleBtn:Show()
    if C.ActionFX then C.ActionFX.Reset() end
end
-- Habillage (UI_ActionFX.lua) : il peut réserver le début de l'ouverture
-- (logo -> cube -> éclatement) ; les catégories partent ensuite du centre.
local function OpenTime() return C.ActionFX and C.ActionFX.OPEN_TIME or .34 end
local function DrawTriangle(t)
    local fx=C.ActionFX
    local burst=fx and fx.BURST or 0
    if fx then fx.DrawOpen(t) end
    t=burst>0 and math.max(0,(t-burst)/(1-burst)) or t
    local u=1-(1-t)^3
    plate:SetAlpha(u);plate:SetScale(.72+.28*u)
    for key,b in pairs(catButtons) do
        local o=OFFSETS[key];Place(b,o[1]*u,o[2]*u)
        b:SetAlpha(u);b:SetScale(.8+.2*u)
    end
end
local function ShowTriangle()
    strip:Hide();idleBtn:Hide();plate:Show();selectedKey=nil
    for _,b in pairs(catButtons) do b:Show();b.label:Hide();b.back:Hide();b.tex:Show() end
    Animate(OpenTime(),DrawTriangle,function() state="triangle" end)
end
-- Fermeture : la même animation que l'ouverture, jouée à l'envers.
local function CloseTriangle()
    Animate(OpenTime(),function(t) DrawTriangle(1-t) end,ShowIdle)
end
-- The same timeline is sampled backwards on return, including the collapse.
local function DrawExpansion(t)
    local active=catButtons[selectedKey]
    if t<.42 then
        strip:Hide();plate:Show();plate:SetScale(1)
        local u=t/.42;plate:SetAlpha(1-u)
        for key,b in pairs(catButtons) do
            local o=OFFSETS[key];Place(b,o[1]*(1-u),o[2]*(1-u))
            b:Show();b.tex:Show();b.back:Hide();b.label:Hide()
            b:SetAlpha(1-u);b:SetScale(1)
        end
    else
        plate:Hide()
        for _,b in pairs(catButtons) do b:Hide() end
        local u=math.max(0,math.min(1,(t-.42)/.58));local ease=1-(1-u)^3
        active:Show();active.tex:Hide();active.back:Show();active.label:Hide()
        Place(active,0,0);active:SetAlpha(ease)
        strip:Show();strip:SetAlpha(ease);strip:SetWidth(16+(targetWidth-16)*ease)
        viewport:SetWidth(math.max(1,strip:GetWidth()-32));viewport:SetAlpha(u)
    end
end
local function ShowExpanded(cat)
    selectedKey=cat.key;pageIndex=0;RefreshSkillRow()
    Animate(.58,DrawExpansion,function() state="expanded" end)
end
local function ReturnToTriangle()
    Animate(.58,function(t) DrawExpansion(1-t) end,function()
        DrawExpansion(0);state="triangle";selectedKey=nil
    end)
end
idleBtn:SetScript("OnClick",function(_,mouse)
    if idleBtn.suppressClick or root.dragging or state=="animating" then return end
    if mouse=="RightButton" then C:ToggleActionLayout(idleBtn);return end
    ShowTriangle()
end)
for key,b in pairs(catButtons) do
    b:SetScript("OnClick",function(_,mouse)
        if b.suppressClick or root.dragging or state=="animating" then return end
        -- Bouton retour : tout clic (gauche ou droit) revient aux catégories.
        if state=="expanded" then ReturnToTriangle()
        elseif mouse=="RightButton" then CloseTriangle()
        else ShowExpanded(b.cat) end
    end)
end
-- Affiché/masqué retenu par personnage : il revient tel quel après un
-- /reload ou une reconnexion, au lieu de disparaître à chaque fois.
local function SaveActionShown(shown)
    CharacterDB.actionButtonShown = CharacterDB.actionButtonShown or {}
    CharacterDB.actionButtonShown[PositionKey()] = shown or nil
end
local function ShowActionMenu() ApplyActionScale();ApplyActionPosition();ShowIdle();root:Show() end
function C:ToggleActionButton()
    if root:IsShown() then ShowIdle();root:Hide();SaveActionShown(false)
    else ShowActionMenu();SaveActionShown(true) end
end
local previousSkillsChanged=C.OnSkillsChanged
C.OnSkillsChanged=function(...)
    if previousSkillsChanged then previousSkillsChanged(...) end
    if selectedKey then RefreshSkillRow() end
end
root:SetScript("OnHide",function()
    if root.dragging then StopActionDrag() end
    pinnedSkill=nil;C:HideSkillTooltip();C:HideSkillName()
    ShowIdle()
end)
hud:HookScript("OnHide",function() root:Hide() end)
hud:HookScript("OnShow",function()
    local saved=CharacterDB and CharacterDB.actionButtonShown
    if saved and saved[PositionKey()] and not root:IsShown() then ShowActionMenu() end
end)

-- ── Panneau rapide (clic droit sur le bouton) ───────────────────────────────
-- Par catégorie, toutes les compétences de la bibliothèque commune : la
-- case à cocher décide si elle apparaît dans la bande, l'ordre de la liste
-- (glisser-déposer) est l'ordre des bulles, de gauche à droite.
local LAYOUT_W, LAYOUT_H, ROW_H = 270, 360, 26
local layoutCats = {}
for _, cat in ipairs(C.SKILL_CATEGORIES) do
    if not cat.hidden then layoutCats[#layoutCats + 1] = cat end
end
local layout, layoutCat, RefreshLayout

local function BuildLayout()
    local p = CreateFrame("Frame", "CharacterActionLayout", UIParent)
    p:SetSize(LAYOUT_W, LAYOUT_H)
    p:SetFrameStrata("DIALOG"); p:SetClampedToScreen(true); p:EnableMouse(true)
    p:Hide()
    p:SetScript("OnHide", function(self) if self.moving then self:StopMovingOrSizing(); self.moving = false end end)
    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); UI.ApplyWindowBackground(bg, .97); UI.ApplyBorder(p)
    local title = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 10, -9); title:SetText("Compétences du bouton Action"); UI.ApplyTitle(title)
    local close = UI.CreateCloseButton(p, function() p:Hide() end)
    if close.SetFrameLevel then close:SetFrameLevel(p:GetFrameLevel() + 20) end

    -- Barre de titre : glisser détache le panneau du bouton (position
    -- retenue par personnage) ; clic droit le raccroche au bouton.
    p:SetMovable(true)
    local bar = CreateFrame("Frame", nil, p)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT", -26, 0); bar:SetHeight(28)
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then p:StartMoving(); p.moving = true end
    end)
    bar:SetScript("OnMouseUp", function(_, button)
        if p.moving then
            p:StopMovingOrSizing(); p.moving = false
            local point, _, relative, x, y = p:GetPoint()
            CharacterDB.actionLayoutPositions = CharacterDB.actionLayoutPositions or {}
            CharacterDB.actionLayoutPositions[PositionKey()] = { point = point, relative = relative, x = x, y = y }
        elseif button == "RightButton" then
            if CharacterDB.actionLayoutPositions then CharacterDB.actionLayoutPositions[PositionKey()] = nil end
            p.PlaceLayout()
        end
    end)
    bar:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Maintenez pour déplacer", unpack(UI.colors.textMuted))
        GameTooltip:AddLine("Clic droit : raccrocher au bouton", unpack(UI.colors.textMuted))
        GameTooltip:Show()
    end)
    bar:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Position d'origine : à droite du bouton, centré sur lui.
    function p.PlaceLayout()
        p:ClearAllPoints()
        local saved = CharacterDB.actionLayoutPositions and CharacterDB.actionLayoutPositions[PositionKey()]
        if saved then
            p:SetPoint(saved.point, UIParent, saved.relative, saved.x, saved.y)
        else
            p:SetPoint("LEFT", idleBtn, "RIGHT", 12, 0)
        end
    end

    p.tabs = {}
    local tabW = (LAYOUT_W - 16) / #layoutCats
    for i, cat in ipairs(layoutCats) do
        local tab = CreateFrame("Button", nil, p)
        tab:SetSize(tabW - 2, 22)
        tab:SetPoint("TOPLEFT", 8 + (i - 1) * tabW, -30)
        tab.cat = cat
        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetAllPoints(); label:SetJustifyH("CENTER")
        label:SetText(({ base = "Actions", offensive = "Offensive", defensive = "Défensive", ranged = "Distance" })[cat.key] or cat.tag)
        local line = tab:CreateTexture(nil, "ARTWORK")
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(2)
        tab.label, tab.line = label, line
        tab:SetScript("OnClick", function() layoutCat = cat; p.viewport:SetVerticalScroll(0); RefreshLayout() end)
        p.tabs[i] = tab
    end

    local viewport = CreateFrame("ScrollFrame", nil, p)
    viewport:SetPoint("TOPLEFT", 8, -58); viewport:SetPoint("BOTTOMRIGHT", -8, 30)
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * ROW_H)))
    end)
    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(LAYOUT_W - 16, 1)
    viewport:SetScrollChild(content)
    p.viewport, p.content = viewport, content

    local hint = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOMLEFT", 10, 10); hint:SetPoint("RIGHT", -10, 0); hint:SetJustifyH("LEFT")
    hint:SetText("Cochez pour afficher · glissez pour ordonner")
    UI.ApplyMutedText(hint)
    p.empty = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    p.empty:SetPoint("TOP", 0, -12); p.empty:SetText("Aucune compétence dans cette catégorie")
    UI.ApplyMutedText(p.empty)

    -- Trait d'insertion pendant un glisser-déposer.
    p.insert = content:CreateTexture(nil, "OVERLAY")
    p.insert:SetHeight(2); p.insert:SetColorTexture(.85, .70, .42, 1); p.insert:Hide()

    p.rows = {}
    return p
end

local dragFrom, dropSlot
local function SlotUnderCursor()
    local content = layout.content
    local _, cy = GetCursorPosition()
    cy = cy / content:GetEffectiveScale()
    local top = content:GetTop() or cy
    local count = #layout.entries
    return math.max(1, math.min(count + 1, math.floor((top - cy) / ROW_H + .5) + 1))
end
local function DragUpdate()
    local viewport = layout.viewport
    local _, cy = GetCursorPosition()
    cy = cy / viewport:GetEffectiveScale()
    -- Défilement automatique près des bords.
    if viewport:GetTop() and cy > viewport:GetTop() - 12 then
        viewport:SetVerticalScroll(math.max(0, viewport:GetVerticalScroll() - 4))
    elseif viewport:GetBottom() and cy < viewport:GetBottom() + 12 then
        viewport:SetVerticalScroll(math.min(viewport:GetVerticalScrollRange(), viewport:GetVerticalScroll() + 4))
    end
    dropSlot = SlotUnderCursor()
    layout.insert:ClearAllPoints()
    layout.insert:SetPoint("TOPLEFT", layout.content, "TOPLEFT", 0, -(dropSlot - 1) * ROW_H)
    layout.insert:SetPoint("RIGHT", layout.content, "RIGHT", 0, 0)
    layout.insert:Show()
end
local function FinishDrag()
    layout:SetScript("OnUpdate", nil)
    layout.insert:Hide()
    local from, slot = dragFrom, dropSlot
    dragFrom, dropSlot = nil, nil
    if from and slot then
        local to = slot > from and slot - 1 or slot
        if to ~= from then C:MoveActionEntry(layoutCat.key, from, to) end
    end
    RefreshLayout()
end

local function LayoutRow(index)
    local row = layout.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, layout.content)
    row:SetSize(LAYOUT_W - 16, ROW_H - 2)
    row:RegisterForDrag("LeftButton")
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(); row.bg:SetColorTexture(unpack(UI.colors.rowBg))
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, .06)
    row.check = UI.CreateStyledCheckbox(row)
    row.check:SetPoint("LEFT", 4, 0)
    row.check:SetScript("OnClick", function(self)
        C:SetActionEntryShown(layoutCat.key, row.entry.key, self:GetChecked() and true or false)
        RefreshLayout()
    end)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20); row.icon:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
    row.icon:SetTexCoord(.08, .92, .08, .92)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0); row.text:SetPoint("RIGHT", -22, 0)
    row.text:SetJustifyH("LEFT"); row.text:SetWordWrap(false)
    -- Poignée : trois traits à droite.
    for i = 0, 2 do
        local grip = row:CreateTexture(nil, "OVERLAY")
        grip:SetSize(10, 1); grip:SetPoint("RIGHT", -6, 3 - i * 3)
        grip:SetColorTexture(.65, .60, .50, .8)
    end
    row:SetScript("OnDragStart", function(self)
        dragFrom = self.index
        self:SetAlpha(.45)
        layout:SetScript("OnUpdate", DragUpdate)
    end)
    row:SetScript("OnDragStop", FinishDrag)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(C:RenderSkillName(self.entry.skill.name) .. C:SkillOwnerSuffix(self.entry.skill), 1, 1, 1)
        GameTooltip:AddLine("Maintenez pour déplacer dans la liste", unpack(UI.colors.textMuted))
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    layout.rows[index] = row
    return row
end

function RefreshLayout()
    if not layout or not layout:IsShown() or dragFrom then return end
    for _, tab in ipairs(layout.tabs) do UI.ApplyTabState(tab, tab.cat == layoutCat) end
    local entries = C:ListActionEntries(layoutCat.key)
    layout.entries = entries
    for i, entry in ipairs(entries) do
        local row = LayoutRow(i)
        row.index, row.entry = i, entry
        row:ClearAllPoints(); row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        row.check:SetChecked(entry.shown)
        row.icon:SetTexture(C:ResolveIconValue(entry.skill.icon))
        row.text:SetText(C:RenderSkillName(entry.skill.name) .. C:SkillOwnerSuffix(entry.skill))
        row:SetAlpha(entry.shown and 1 or .5)
        row:Show()
    end
    for i = #entries + 1, #layout.rows do layout.rows[i]:Hide() end
    layout.empty:SetShown(#entries == 0)
    layout.content:SetHeight(math.max(1, #entries * ROW_H))
end

function C:ToggleActionLayout(anchor)
    layout = layout or BuildLayout()
    if layout:IsShown() then layout:Hide(); return end
    layoutCat = layoutCat or layoutCats[1]
    layout.PlaceLayout()
    layout:Show()
    RefreshLayout()
end

local previousLayoutRefresh = C.OnSkillsChanged
C.OnSkillsChanged = function(...)
    if previousLayoutRefresh then previousLayoutRefresh(...) end
    RefreshLayout()
end
root:HookScript("OnHide", function() if layout then layout:Hide() end end)
