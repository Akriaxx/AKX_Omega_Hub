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
-- ============================================================
local C = Character
local UI = C.RPGUI or OS2.UI
local hud = CharacterResourceHUD
if not hud or not C.SKILL_CATEGORIES then return end

local BTN = 36
local ICON = 32
local GAP = 4

-- Icônes fixes des 4 catégories (pas éditables, contrairement aux
-- compétences elles-mêmes) + tooltip qui affiche le libellé complet.
local CATEGORY_ICON = {
    offensive = "Interface\\Icons\\Ability_Warrior_Savageblow",
    defensive = "Interface\\Icons\\Ability_Defend",
    ranged    = "Interface\\Icons\\Ability_Marksmanship",
    base      = "Interface\\Icons\\INV_Misc_Gear_01",
}
local IDLE_ICON = "Interface\\Icons\\INV_Misc_Book_09"

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
    bg:SetAllPoints();bg:SetColorTexture(.025,.032,.035,1)
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
    b.tex = tex
    return b
end

-- ── Bouton de repos : "Action" ──────────────────────────────────────────────
-- Sert aussi de poignée pour déplacer toute la fenêtre (comme le portrait
-- déplace le cadre principal) : maintenir et glisser, au lieu de cliquer,
-- ne doit pas ouvrir le triangle.
local idleBtn = NewSquareButton(root, BTN)
idleBtn:SetPoint("CENTER", root, "TOPLEFT", RESET_X, RESET_Y)
idleBtn.tex:SetTexture(IDLE_ICON)
idleBtn:RegisterForClicks("LeftButtonUp")
idleBtn:RegisterForDrag("LeftButton")
local suppressIdleClick = false
-- Suivi manuel du curseur plutôt que StartMoving : root a une échelle
-- propre qui compense celle de son parent, et StartMoving décalait alors
-- le bouton de plus en plus loin du curseur. Tout est converti dans
-- l'échelle effective de root, celle de ses propres SetPoint.
local function CursorInRoot()
    local x, y = GetCursorPosition()
    local scale = root:GetEffectiveScale()
    return x / scale, y / scale
end
local function StopActionDrag()
    idleBtn:SetScript("OnUpdate", nil)
    root.dragging = false
end
-- L'écart curseur/bouton se mesure à l'appui, pas à OnDragStart : ce
-- dernier ne part qu'une fois la souris déjà en mouvement, parfois loin
-- du point saisi si le geste est rapide, et cet écart restait ensuite.
local grabX, grabY
idleBtn:SetScript("OnMouseDown", function()
    suppressIdleClick = false
    local cx, cy = CursorInRoot()
    local rx, ry = root:GetCenter()
    if rx then grabX, grabY = rx - cx, ry - cy end
end)
idleBtn:SetScript("OnDragStart", function()
    suppressIdleClick = true
    root.dragging = true
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
    idleBtn:SetScript("OnUpdate", Follow)
    Follow()
end)
idleBtn:SetScript("OnDragStop", function()
    if not root.dragging then return end
    StopActionDrag()
    SaveActionPosition()
end)
idleBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Action", unpack(UI.colors.title))
    GameTooltip:AddLine("Compétences par catégorie", unpack(UI.colors.textMuted))
    GameTooltip:AddLine("Maintenir et glisser : déplacer", unpack(UI.colors.textMuted))
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
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.back:IsShown() and "Retour aux catégories" or cat.label, unpack(UI.colors.title))
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
    UI.ApplyTitle(label);b.label=label
    -- Lisibilité sur la plaque et sur les icônes : ombre portée noire.
    label:SetShadowColor(0,0,0,1);label:SetShadowOffset(1.5,-1.5)
    b:RegisterForClicks("LeftButtonUp","RightButtonUp")
end
local strip=CreateFrame("Frame",nil,root)
strip:SetPoint("LEFT",root,"RIGHT",6,0);strip:SetSize(48,44);strip:Hide()
strip:SetClipsChildren(true)
local stripBg=strip:CreateTexture(nil,"BACKGROUND");stripBg:SetAllPoints()
stripBg:SetColorTexture(.025,.032,.035,.72)
local viewport=CreateFrame("ScrollFrame",nil,strip)
viewport:SetPoint("TOPLEFT",8,-6);viewport:SetSize(32,ICON)
viewport:EnableMouseWheel(true)
local skillRow=CreateFrame("Frame",nil,viewport);skillRow:SetSize(1,ICON)
viewport:SetScrollChild(skillRow)
local rowScroll,rowRange,targetWidth=0,0,48
local pinnedSkill
viewport:SetScript("OnMouseWheel",function(_,delta)
    pinnedSkill=nil;C:HideSkillTooltip();C:HideSkillName()
    rowScroll=math.max(0,math.min(rowRange,rowScroll-delta*(ICON+GAP)))
    viewport:SetHorizontalScroll(rowScroll)
end)
local empty=NewSquareButton(skillRow,ICON)
empty:SetPoint("TOPLEFT",0,0);empty.tex:Hide();empty.back:SetText("—");empty.back:Show()
empty:SetScript("OnClick",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:SetText("Aucune action dans cette catégorie");GameTooltip:Show()
end)
empty:SetScript("OnLeave",function() GameTooltip:Hide() end)
local skillButtons={}
local selectedKey,state=nil,"idle"
local function RefreshSkillRow()
    local skills=C:ListSkills(selectedKey)
    for i,skill in ipairs(skills) do
        local b=skillButtons[i]
        if not b then
            b=NewSquareButton(skillRow,ICON);skillButtons[i]=b
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
        b:ClearAllPoints();b:SetPoint("TOPLEFT",(i-1)*(ICON+GAP),0);b:Show()
    end
    for i=#skills+1,#skillButtons do skillButtons[i]:Hide() end
    local width=math.max(1,#skills*(ICON+GAP)-GAP)
    empty:SetShown(#skills==0)
    width=math.max(ICON,width)
    targetWidth=math.min(320,width+16)
    skillRow:SetWidth(width);rowRange=math.max(0,width-(targetWidth-16))
    rowScroll=math.min(rowScroll,rowRange);viewport:SetHorizontalScroll(rowScroll)
    if state=="expanded" then strip:SetWidth(targetWidth);viewport:SetWidth(targetWidth-16) end
    pinnedSkill=nil;C:HideSkillTooltip();C:HideSkillName()
end
local function Place(b,x,y)
    b:ClearAllPoints();b:SetPoint("CENTER",root,"TOPLEFT",RESET_X+x,RESET_Y+y)
end
local function CancelMotion()
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
end
local function DrawTriangle(t)
    local u=1-(1-t)^3
    plate:SetAlpha(u);plate:SetScale(.72+.28*u)
    for key,b in pairs(catButtons) do
        local o=OFFSETS[key];Place(b,o[1]*u,o[2]*u)
        b:SetAlpha(u);b:SetScale(.8+.2*u)
    end
end
local function ShowTriangle()
    strip:Hide();idleBtn:Hide();plate:Show();selectedKey=nil
    for _,b in pairs(catButtons) do b:Show();b.label:Show();b.back:Hide();b.tex:Show() end
    Animate(.34,DrawTriangle,function() state="triangle" end)
end
-- Fermeture : la même animation que l'ouverture, jouée à l'envers.
local function CloseTriangle()
    Animate(.34,function(t) DrawTriangle(1-t) end,ShowIdle)
end
-- The same timeline is sampled backwards on return, including the collapse.
local function DrawExpansion(t)
    local active=catButtons[selectedKey]
    if t<.42 then
        strip:Hide();plate:Show();plate:SetScale(1)
        local u=t/.42;plate:SetAlpha(1-u)
        for key,b in pairs(catButtons) do
            local o=OFFSETS[key];Place(b,o[1]*(1-u),o[2]*(1-u))
            b:Show();b.tex:Show();b.back:Hide();b.label:SetShown(t==0)
            b:SetAlpha(1-u);b:SetScale(1)
        end
    else
        plate:Hide()
        for _,b in pairs(catButtons) do b:Hide() end
        local u=math.max(0,math.min(1,(t-.42)/.58));local ease=1-(1-u)^3
        active:Show();active.tex:Hide();active.back:Show();active.label:Hide()
        Place(active,0,0);active:SetAlpha(ease)
        strip:Show();strip:SetAlpha(ease);strip:SetWidth(16+(targetWidth-16)*ease)
        viewport:SetWidth(math.max(1,strip:GetWidth()-16));viewport:SetAlpha(u)
    end
end
local function ShowExpanded(cat)
    selectedKey=cat.key;RefreshSkillRow()
    Animate(.58,DrawExpansion,function() state="expanded" end)
end
local function ReturnToTriangle()
    Animate(.58,function(t) DrawExpansion(1-t) end,function()
        DrawExpansion(0);state="triangle";selectedKey=nil
    end)
end
idleBtn:SetScript("OnClick",function()
    if suppressIdleClick or root.dragging or state=="animating" then return end
    ShowTriangle()
end)
for key,b in pairs(catButtons) do
    b:SetScript("OnClick",function(_,mouse)
        if state=="animating" then return end
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
