-- ============================================================
--  Character - Bouton Action
--  Fenêtre indépendante et déplaçable, invoquée par Shift+Clic
--  gauche sur le portrait (voir UI_HUD.lua). Apparaît au centre
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

local BTN = 32
local ICON = 28
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
    offensive = { 0, 36 },
    ranged    = { -34, -20 },
    defensive = { 34, -20 },
    base      = { 0, 0 },
}

-- Fenêtre indépendante (pas un enfant positionné sous le cadre) : elle
-- garde son propre emplacement à l'écran, glissé par le joueur, tant que
-- Character reste actif (parentée à hud pour se masquer avec lui).
local root = CreateFrame("Frame", nil, hud)
root:SetSize(1, 1)
root:SetMovable(true)
root:SetClampedToScreen(true)
root:Hide()

local function PositionKey()
    return (UnitName("player") or "player") .. "-" .. (GetRealmName() or "")
end
local function SaveActionPosition()
    CharacterDB.actionButtonPositions = CharacterDB.actionButtonPositions or {}
    local point, _, relative, x, y = root:GetPoint()
    CharacterDB.actionButtonPositions[PositionKey()] = { point = point, relative = relative, x = x, y = y }
end
local function ApplyActionPosition()
    root:ClearAllPoints()
    local saved = CharacterDB.actionButtonPositions and CharacterDB.actionButtonPositions[PositionKey()]
    if saved then
        root:SetPoint(saved.point, UIParent, saved.relative, saved.x, saved.y)
    else
        -- Première apparition, ou jamais déplacé : centre de l'écran.
        root:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function NewSquareButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local border = b:CreateTexture(nil, "BACKGROUND")
    border:SetAllPoints()
    border:SetColorTexture(.58, .46, .26, .9)
    local bg = b:CreateTexture(nil, "BORDER")
    bg:SetPoint("TOPLEFT", 2, -2); bg:SetPoint("BOTTOMRIGHT", -2, 2)
    bg:SetColorTexture(.09, .08, .06, .97)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 3, -3); tex:SetPoint("BOTTOMRIGHT", -3, 3)
    tex:SetTexCoord(.08, .92, .08, .92)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(.85, .7, .42, .25)
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
idleBtn:SetScript("OnMouseDown", function() suppressIdleClick = false end)
idleBtn:SetScript("OnDragStart", function()
    suppressIdleClick = true
    root.dragging = true
    root:StartMoving()
end)
idleBtn:SetScript("OnDragStop", function()
    root:StopMovingOrSizing()
    root.dragging = false
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
    local b = NewSquareButton(root, BTN)
    b:Hide()
    b.cat = cat
    b.tex:SetTexture(CATEGORY_ICON[cat.key])
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(cat.label, unpack(UI.colors.title))
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    catButtons[cat.key] = b
end

-- ── Ligne d'icônes de compétences, à droite du bouton replié ────────────────
local skillRow = CreateFrame("Frame", nil, root)
skillRow:Hide()
local skillButtons = {}

local function RefreshSkillRow(catKey)
    local skills = C:ListSkills(catKey)
    for i, skill in ipairs(skills) do
        local b = skillButtons[i]
        if not b then
            b = NewSquareButton(skillRow, ICON)
            skillButtons[i] = b
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.skill.name, 1, .82, 0)
                if self.skill.description and self.skill.description ~= "" then
                    GameTooltip:AddLine(C:RenderSkillText(self.skill.description), .9, .9, .9, true)
                end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        b.skill = skill
        b.tex:SetTexture(C:ResolveIconValue(skill.icon))
        b:ClearAllPoints()
        b:SetPoint("LEFT", skillRow, "LEFT", (i - 1) * (ICON + GAP), 0)
        b:Show()
    end
    for i = #skills + 1, #skillButtons do skillButtons[i]:Hide() end
    skillRow:SetSize(math.max(1, #skills * (ICON + GAP) - GAP), ICON)
    return #skills
end

-- ── États ────────────────────────────────────────────────────────────────────
local STATE_IDLE, STATE_TRIANGLE, STATE_EXPANDED = "idle", "triangle", "expanded"
local state, selectedKey = STATE_IDLE, nil

local function HideSkillRow()
    skillRow:Hide()
    for _, b in ipairs(skillButtons) do b:Hide() end
end

local function ShowIdle()
    state, selectedKey = STATE_IDLE, nil
    for _, b in pairs(catButtons) do b:Hide() end
    HideSkillRow()
    idleBtn:Show()
end

local function ShowTriangle()
    state, selectedKey = STATE_TRIANGLE, nil
    idleBtn:Hide()
    HideSkillRow()
    for key, b in pairs(catButtons) do
        local dx, dy = unpack(OFFSETS[key])
        b:ClearAllPoints()
        b:SetPoint("CENTER", root, "TOPLEFT", RESET_X + dx, RESET_Y + dy)
        b:Show()
    end
end

local function ShowExpanded(cat)
    state, selectedKey = STATE_EXPANDED, cat.key
    idleBtn:Hide()
    local activeBtn
    for key, b in pairs(catButtons) do
        if key == cat.key then
            b:ClearAllPoints()
            b:SetPoint("CENTER", root, "TOPLEFT", RESET_X, RESET_Y)
            b:Show()
            activeBtn = b
        else
            b:Hide()
        end
    end
    local count = RefreshSkillRow(cat.key)
    skillRow:ClearAllPoints()
    skillRow:SetPoint("LEFT", activeBtn, "RIGHT", 8, 0)
    skillRow:SetShown(count > 0)
end

idleBtn:SetScript("OnClick", function()
    if suppressIdleClick or root.dragging then return end
    ShowTriangle()
end)
for key, b in pairs(catButtons) do
    b:SetScript("OnClick", function()
        if state == STATE_EXPANDED and selectedKey == key then
            ShowIdle()
        else
            ShowExpanded(b.cat)
        end
    end)
end

-- Shift+Clic gauche sur le portrait (voir UI_HUD.lua) : apparaît au centre
-- la première fois, garde ensuite la position glissée.
function C:ToggleActionButton()
    if root:IsShown() then
        root:Hide()
    else
        ApplyActionPosition()
        ShowIdle()
        root:Show()
    end
end

-- Repliée ET masquée avec le cadre principal : pas de fenêtre Action qui
-- traîne à l'écran une fois Character désactivé, ni d'état incohérent qui
-- réapparaît au prochain /reload ou à la prochaine réactivation.
hud:HookScript("OnHide", function()
    ShowIdle()
    root:Hide()
end)
