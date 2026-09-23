-- Persistent RP resources. Uses Character's existing setters and broadcasts.
local C, UI = Character, OS2.UI
local MEDIA="Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\"
local hud=CreateFrame("Frame","CharacterResourceHUD",UIParent)
hud:SetSize(366,114);hud:SetFrameStrata("MEDIUM")
hud:SetMovable(true);hud:SetClampedToScreen(true);hud:EnableMouse(true)
hud:RegisterForDrag("LeftButton");hud:Hide()
local active=false
local rows={}
local bonusColors={hp={.64,1,.48},mana={.35,.92,1},endurance={1,.48,.66}}
local function Settings() return C:GetSettings() end
local function PositionKey() return (UnitName("player") or "player").."-"..(GetRealmName() or "") end
local function SavePosition()
    CharacterDB.resourceHUDPositions=CharacterDB.resourceHUDPositions or {}
    local point,_,relative,x,y=hud:GetPoint()
    CharacterDB.resourceHUDPositions[PositionKey()]={point=point,relative=relative,x=x,y=y}
end
local function StopDrag()
    if hud.dragging then hud:StopMovingOrSizing();hud.dragging=false;SavePosition() end
end
hud:SetScript("OnDragStart",function() hud.dragging=true;hud:StartMoving() end)
hud:SetScript("OnDragStop",StopDrag)
-- Clic droit sur le cadre (nom compris : une FontString ne capte pas la
-- souris) : menu natif du joueur, comme sur le PlayerFrame masqué
-- (Convertir en raid, difficulté, butin, TRP3...). Client 9.2.7 : menu de
-- PlayerFrameDropDown ; client récent : UnitPopup.
local function OpenPlayerMenu()
    if PlayerFrameDropDown and ToggleDropDownMenu then
        ToggleDropDownMenu(1,nil,PlayerFrameDropDown,"cursor",0,0)
    elseif UnitPopup_OpenMenu then
        UnitPopup_OpenMenu("SELF",{unit="player"})
    end
end
C.OpenPlayerMenu=OpenPlayerMenu
hud:SetScript("OnMouseUp",function(_,button)
    if button=="RightButton" and not hud.dragging then OpenPlayerMenu() end
end)

local background=hud:CreateTexture(nil,"BACKGROUND")
background:SetPoint("TOPLEFT",hud,"TOPLEFT",42,-8)
background:SetPoint("BOTTOMRIGHT",hud,"BOTTOMRIGHT",24,8)
background:SetTexture(MEDIA.."ResourcePanelRounded.tga")

local portrait=CreateFrame("Button",nil,hud)
portrait:SetSize(80,80);portrait:SetPoint("LEFT",hud,"LEFT",0,0)
portrait:RegisterForClicks("LeftButtonUp","RightButtonUp","MiddleButtonUp");portrait:RegisterForDrag("LeftButton")
-- Keep suppression until the next press: OnClick and OnDragStop may arrive
-- in either order on release, and neither should turn a drag into a click.
local suppressPortraitClick=false
portrait:SetScript("OnMouseDown",function() suppressPortraitClick=false end)
portrait:SetScript("OnDragStart",function()
    suppressPortraitClick=true;hud.dragging=true;hud:StartMoving()
end)
portrait:SetScript("OnDragStop",StopDrag)
local mask=portrait:CreateMaskTexture()
mask:SetAllPoints();mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
local rim=portrait:CreateTexture(nil,"BACKGROUND")
rim:SetAllPoints();rim:SetColorTexture(0,0,0,1);rim:AddMaskTexture(mask)
local icon=portrait:CreateTexture(nil,"ARTWORK")
icon:SetPoint("TOPLEFT",3,-3);icon:SetPoint("BOTTOMRIGHT",-3,3)
local innerMask=portrait:CreateMaskTexture()
innerMask:SetAllPoints(icon);innerMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
icon:AddMaskTexture(innerMask)
local model=CreateFrame("PlayerModel",nil,portrait)
model:SetSize(64,64);model:SetPoint("CENTER");model:EnableMouse(false)
local ornament=CreateFrame("Frame",nil,model)
ornament:SetAllPoints(portrait);ornament:EnableMouse(false)
local medallion=ornament:CreateTexture(nil,"OVERLAY")
medallion:SetPoint("TOPLEFT",portrait,"TOPLEFT",-10,10)
medallion:SetPoint("BOTTOMRIGHT",portrait,"BOTTOMRIGHT",10,-10)
medallion:SetTexture(MEDIA.."PortraitRing.tga")
local function FramePortrait()
    model:SetPortraitZoom(1)
    if model.SetRotation then model:SetRotation(0) end
end
model:SetScript("OnModelLoaded",FramePortrait)
local function RefreshPortrait()
    if UnitExists("player") and model.SetUnit then
        model:Show();model:SetUnit("player");FramePortrait();icon:Hide()
    else model:Hide();icon:Show();icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
end
portrait:SetScript("OnClick",function(_,button)
    if suppressPortraitClick or hud.dragging then return end
    if button=="MiddleButton" then C:ToggleSettings()
    elseif button=="RightButton" then if CharacterMJPanel then CharacterMJPanel:Toggle() end
    elseif button=="LeftButton" and IsShiftKeyDown() then if C.ToggleActionButton then C:ToggleActionButton() end
    elseif button=="LeftButton" and C.ToggleGroupView then C:ToggleGroupView() end
end)
portrait:SetScript("OnEnter",function(self)
    GameTooltip:SetOwner(self,"ANCHOR_TOP")
    GameTooltip:AddLine("Ressources du personnage",.9,.8,.55)
    GameTooltip:AddLine("Maintenir le clic gauche et glisser : déplacer",.8,.8,.8)
    GameTooltip:AddLine("Clic : alliés · Clic droit : vue MJ",.8,.8,.8)
    GameTooltip:AddLine("Clic molette : paramètres · Shift+Clic : bouton Action",.8,.8,.8)
    GameTooltip:Show()
end)
portrait:SetScript("OnLeave",function() GameTooltip:Hide() end)
local name=hud:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
name:SetPoint("TOPLEFT",hud,"TOPLEFT",90,-17);name:SetSize(265,20)
name:SetFontObject("GameFontNormal");name:SetJustifyH("LEFT");name:SetWordWrap(false);name:SetTextColor(.91,.83,.65)

local function InlineField(row,key,mode,x)
    local field=CreateFrame("EditBox",nil,row)
    field:SetSize(46,15);field:SetPoint("RIGHT",row,"RIGHT",x,0)
    field:SetFontObject("GameFontNormalSmall");field:SetJustifyH("CENTER")
    field:SetAutoFocus(false);field:SetMaxLetters(7)
    if mode=="temp" then field:SetTextColor(unpack(bonusColors[key])) else field:SetTextColor(.96,.96,.92) end
    field:SetShadowColor(0,0,0,1);field:SetShadowOffset(1,-1)
    local highlight=field:CreateTexture(nil,"BACKGROUND")
    highlight:SetAllPoints();highlight:SetColorTexture(1,.8,.4,.18);highlight:Hide()
    local function Current() return tostring(C:GetMyChar()[key][mode] or 0) end
    local function Commit(self)
        local value=(self:GetText() or ""):match("^%s*(.-)%s*$")
        if not self.cancel and value~=self.original and value:match("^[+-]?%d+$") then
            local relative=value:match("^[+-]")
            if mode=="temp" then
                if relative then C:AddTemp(key,tonumber(value)) else C:SetTemp(key,tonumber(value)) end
            elseif mode=="max" then C:SetMax(key,relative and (C:GetMyChar()[key].max+tonumber(value)) or tonumber(value))
            elseif relative then C:Delta(key,tonumber(value)) else C:SetCur(key,tonumber(value)) end
        end
        self.cancel=nil;self:SetText(Current());self.original=self:GetText()
    end
    field:SetScript("OnEditFocusGained",function(self) self.original=self:GetText();highlight:Show();self:HighlightText() end)
    field:SetScript("OnEditFocusLost",function(self) Commit(self);highlight:Hide() end)
    field:SetScript("OnEnterPressed",function(self) Commit(self);self:ClearFocus() end)
    field:SetScript("OnEscapePressed",function(self) self.cancel=true;self:ClearFocus() end)
    field:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:AddLine(mode=="temp" and "Points temporaires" or mode=="max" and "Maximum" or "Valeur actuelle")
        GameTooltip:AddLine("Entrée ou clic ailleurs : valider.",.8,.8,.8)
        GameTooltip:AddLine("Échap : annuler.",.8,.8,.8);GameTooltip:Show()
    end)
    field:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return field
end
local function CloseEditors()
    for _,row in pairs(rows) do
        for _,field in pairs(row.fields) do field.cancel=true;field:ClearFocus();field.cancel=nil end
    end
end
-- Vie en vert, Endurance en rouge (choix du serveur, dans tout Character).
local definitions={{"hp","Vie",.24,.65,.40},{"mana","Mana",.16,.43,.79},{"endurance","Endurance",.74,.15,.17}}
for i,def in ipairs(definitions) do
    local key,label,r,g,b=unpack(def)
    local row=CreateFrame("Button",nil,hud)
    row:RegisterForClicks("LeftButtonUp","RightButtonUp")
    row:SetSize(266,15);row:SetPoint("TOPLEFT",hud,"TOPLEFT",96,-39-(i-1)*18)
    local bg=row:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(r*.18,g*.18,b*.18,1)
    local fill=row:CreateTexture(nil,"ARTWORK");fill:SetPoint("TOPLEFT");fill:SetPoint("BOTTOMLEFT");fill:SetWidth(1);fill:SetTexture(MEDIA.."ResourceFill.tga");fill:SetVertexColor(r,g,b,1)
    local temp=CreateFrame("Frame",nil,row);temp:SetAllPoints();temp:Hide()
    temp.edges={};temp.perimeter=0
    -- Inset onto the metallic border; five chords per quarter-circle.
    local points={{3,1},{263,1}}
    local function Arc(cx,cy,start)
        for step=1,5 do
            local angle=math.rad(start-step*18)
            points[#points+1]={cx+4*math.cos(angle),cy+4*math.sin(angle)}
        end
    end
    Arc(263,-3,90)
    points[#points+1]={267,-12};Arc(263,-12,0)
    points[#points+1]={3,-16};Arc(3,-12,-90)
    points[#points+1]={-1,-3};Arc(3,-3,-180)
    for i=1,#points-1 do
        local a,b=points[i],points[i+1]
        local segment=temp:CreateLine(nil,"OVERLAY")
        segment:SetColorTexture(unpack(bonusColors[key]));segment:SetThickness(1.5)
        segment.startX=a[1];segment.startY=a[2];segment.dx=b[1]-a[1];segment.dy=b[2]-a[2]
        segment.length=math.sqrt(segment.dx^2+segment.dy^2)
        segment:SetStartPoint("TOPLEFT",row,a[1],a[2])
        temp.perimeter=temp.perimeter+segment.length;temp.edges[#temp.edges+1]=segment
    end
    local shine=row:CreateTexture(nil,"OVERLAY");shine:SetPoint("TOPLEFT");shine:SetPoint("TOPRIGHT");shine:SetHeight(1);shine:SetColorTexture(1,1,1,.14)
    local border=row:CreateTexture(nil,"OVERLAY")
    border:SetPoint("TOPLEFT",row,"TOPLEFT",-2,2);border:SetPoint("BOTTOMRIGHT",row,"BOTTOMRIGHT",2,-2)
    border:SetTexture(MEDIA.."ResourceBorder.tga")
    local text=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");text:SetPoint("LEFT",5,0);text:SetText(label);text:SetTextColor(1,1,1)
    row.fill=fill;row.temp=temp;rows[key]=row
    row.fields={cur=InlineField(row,key,"cur",-121),max=InlineField(row,key,"max",-66),temp=InlineField(row,key,"temp",-10)}
    for _,mark in ipairs({{"/",-113},{"(",-61},{")",-3}}) do
        local punctuation=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        punctuation:SetPoint("RIGHT",row,"RIGHT",mark[2],0);punctuation:SetText(mark[1])
        punctuation:SetTextColor(.88,.79,.59)
    end
end
function hud:Refresh()
    if not CharacterDB then return end
    local ch=C:GetMyChar()
    local display=C:GetDisplayName(UnitName("player"),ch)
    name:SetText(display~="Profil en attente" and display or UnitName("player"))
    for key,row in pairs(rows) do
        local stat=ch[key]
        local maximum=math.max(1,stat.max);local bonus=math.max(0,stat.temp or 0)
        local width=row:GetWidth()
        local filled=width*math.min(1,stat.cur/maximum)
        row.fill:SetWidth(math.max(.01,filled));row.fill:SetShown(stat.cur>0)
        -- Clockwise perimeter; a bonus equal to the maximum fills the outline.
        -- Bonuses never reduce the main gauge's fill or cover the values.
        local remaining=row.temp.perimeter*math.min(1,bonus/maximum)
        for _,segment in ipairs(row.temp.edges) do
            local length=math.min(remaining,segment.length)
            if length>0 then
                local portion=length/segment.length
                segment:SetEndPoint("TOPLEFT",row,segment.startX+segment.dx*portion,segment.startY+segment.dy*portion)
            end
            segment:SetShown(length>0);remaining=math.max(0,remaining-length)
        end
        row.temp:SetShown(bonus>0)
        for mode,field in pairs(row.fields) do if not field:HasFocus() then field:SetText(tostring(stat[mode] or 0)) end end
    end
end
function C:ApplyResourceHUD()
    local s=Settings()
    hud:SetScale(.85*math.max(.6,math.min(1.6,tonumber(s.resourceHUDScale) or 1)))
    hud:ClearAllPoints()
    local position=CharacterDB.resourceHUDPositions and CharacterDB.resourceHUDPositions[PositionKey()]
    if position then hud:SetPoint(position.point,UIParent,position.relative,position.x,position.y)
    else hud:SetPoint("CENTER",UIParent,"CENTER",-240,-220) end
    hud:SetShown(active)
    if hud:IsShown() then RefreshPortrait();hud:Refresh() end
end
function C:SetResourceHUDScale(value) Settings().resourceHUDScale=math.max(.6,math.min(1.6,tonumber(value) or 1));C:ApplyResourceHUD() end
function C:EnableResourceHUD() active=true;C:ApplyResourceHUD() end
function C:DisableResourceHUD() active=false;hud:Hide() end
local previous=C.OnMyDataChanged
C.OnMyDataChanged=function(...) if previous then previous(...) end;if hud:IsShown() then hud:Refresh() end end
hud:SetScript("OnHide",function() StopDrag();CloseEditors();GameTooltip:Hide() end)
hud:RegisterEvent("UNIT_PORTRAIT_UPDATE");hud:RegisterEvent("PLAYER_ENTERING_WORLD");hud:RegisterEvent("UNIT_NAME_UPDATE")
hud:RegisterEvent("UNIT_MODEL_CHANGED")
hud:SetScript("OnEvent",function(_,event,unit)
    if hud:IsShown() and (not unit or unit=="player") then RefreshPortrait();hud:Refresh() end
end)
