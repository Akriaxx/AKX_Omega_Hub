const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.join(__dirname,'..');
// Reuse the existing basic WoW widget mock, then exercise real Character views.
let mock=fs.readFileSync(path.join(root,'../ZoneGate/Tests/Studio_test.lua'),'utf8');
mock=mock.slice(mock.indexOf('unpack='),mock.indexOf('ZoneGate={'));
const code=mock+`
function M:GetParent() return self.parent end
function M:SetWordWrap() end
function M:SetShadowColor() end
function M:SetShadowOffset() end
function M:SetFocus() self.focused=true end
function M:GetLeft() return self.left or 100 end
function M:GetValue() return self.value or 0 end
function M:GetTop() return self.top or 500 end
function M:SetSnapToPixelGrid() end
function M:SetTexelSnappingBias() end
function M:SetThumbTexture() end
function M:SetObeyStepOnDrag() end
function M:SetOrientation() end
function M:SetSmoothing() end
function M:SetLooping() end
function M:SetHitRectInsets() end
function M:SetResizeBounds() end
function M:SetFontString(fs) self.fontString=fs;self.text=fs.text end
function M:GetFontString() return self.fontString end
function M:GetFrameLevel() return 10 end
function M:SetRotation() end
function M:SetBlendMode() end
function M:SetEnabled() end
function M:SetAttribute(key,value) self.attributes=self.attributes or {};self.attributes[key]=value end
function M:SetHorizontalScroll() end
function M:SetNumeric() end
function M:SetAutoFocus() end
function M:SetJustifyV() end
function M:SetNormalTexture() end
function M:SetHighlightTexture() end
function M:SetPushedTexture() end
function M:RegisterForClicks() end
function M:SetScrollChild(child) self.scrollChild=child end
function M:SetVerticalScroll(v) self.scroll=v end
function M:GetVerticalScroll() return self.scroll or 0 end
function M:GetVerticalScrollRange() return math.max(0,(self.scrollChild and self.scrollChild.h or 0)-self.h) end
function M:CreateMaskTexture() return obj('Mask',nil,self) end
function M:AddMaskTexture() end
function M:SetFontObject() end
function M:SetMultiLine() end
function M:SetTextInsets() end
function M:SetMinResize() end
function M:SetResizable() end
function M:StartSizing() self.sizing=true end
function M:StopMovingOrSizing() self.sizing=false end
function M:SetClipsChildren() end
function M:GetChecked() return self.checked end
function M:SetCheckedTexture(texture) self.checkedTexture=texture end
function M:SetChecked(v) self.checked=v end
function M:UnregisterAllEvents() end
function UI.CreateStyledCheckbox(parent,label)
 local b=obj('CheckButton',nil,parent);b.label=obj('FontString',nil,parent);b.label:SetText(label);return b,b.label
end
function UI.CreatePanelButton(parent,w,h,label)
 local b=obj('Button',nil,parent);b:SetSize(w,h);b:SetText(label);b.fontString=obj('FontString',nil,b);b.accent=obj('Texture',nil,b);return b
end
function UI.ApplyBorder() end
function UI.ApplyWarningText() end
function UI.ApplySoftText() end
function UI.ApplyStrongLabel() end
function UI.ApplyTabState() end
function UI.ApplyPlaceholderText() end
function UI.CreateIconButton(parent) return obj('Button',nil,parent) end
function UI.CreateDropdown(parent,width,label,options,getter,setter)
 local b=obj('Frame',nil,parent);b:SetWidth(width);b.Refresh=function() end;return b
end
function UnitName(unit) return unit=='player' and 'Tester' or unit end
function UnitExists() return true end
function UnitIsConnected() return true end
function IsInRaid() return true end
function IsInGroup() return true end
function GetNumGroupMembers() return 12 end
function InCombatLockdown() return false end
function UIDropDownMenu_SetSelectedValue() end
function RegisterStateDriver() end
SlashCmdList={};GameTooltip=obj('Tooltip')
CharacterDB={}
Character={groupData={},initiative={active=false,isHost=false,participants={},currentIndex=1,round=1}}
local C=Character
local ch={hp={cur=75,max=100,temp=20},mana={cur=50,max=100,temp=0},endurance={cur=90,max=100,temp=0}}
function C:GetMyChar() return ch end
function C:GetDisplayName(name) return name end
function C:GetUnitTokenForName(name) return name=='Tester' and 'player' or name end
function C:GetSettings() return {groupScale=1,windowOpacity=.9,initiativeScale=1,mjScale=1} end
function C:RequestAll() end
function C:RequestStats() end
function C:GetNPCList() return {} end
function C:GetParticipants() return {} end
function C:IsMJ() return false end
function C:Delta(key,value) self.lastDelta={key,value} end
function C:AddTemp(key,value) self.lastTemp={key,value} end
for i=1,12 do C.groupData['raid'..i]=ch end
dofile('Modules/Character/UI_Style.lua')
dofile('Modules/Character/UI_Group.lua')
C:ToggleGroupView()
assert(CharacterGroupViewPanel:IsShown() and CharacterGroupViewPanel:GetWidth()==244)
local scroll
for _,o in ipairs(objects) do if o.kind=='ScrollFrame' and o.parent==CharacterGroupViewPanel then scroll=o end end
assert(scroll and scroll.scrollChild and scroll.scrollChild.h>scroll.h)
assert(CharacterGroupViewPanel.h<=320,'Compact roster must stay bounded even in a raid')
scroll.scripts.OnMouseWheel(scroll,-100);assert(scroll:GetVerticalScroll()==scroll:GetVerticalScrollRange())
scroll.scripts.OnMouseWheel(scroll,100);assert(scroll:GetVerticalScroll()==0)
local allyRows=0
for _,row in ipairs(objects) do
 if row.playerName and row.scripts.PostClick then
  allyRows=allyRows+1
  local bars=0
  for _,o in ipairs(objects) do
   if o.parent==row and o.kind=='Frame' then bars=bars+1 end
   local ancestor=o.parent
   while ancestor and ancestor~=row do ancestor=ancestor.parent end
   if ancestor==row and o.kind=='FontString' then
    assert(o.text==row.playerName,'Ally rows must display only the name, never resource values')
   end
  end
  assert(bars==1,'Only HP must be shown in ally rows')
 end
end
assert(allyRows==13)
local positions={}
for _,row in ipairs(objects) do
 if row.playerName and row.scripts.PostClick then
  local cell=tostring(row.point[4])..':'..tostring(row.point[5])
  assert(not positions[cell],'Companion cells must not overlap');positions[cell]=true
  assert(row.w==113,'Two-column cells must fit the panel width')
 end
end
for _,o in ipairs(objects) do if o.playerName=='Tester' and o.scripts.PostClick then o.scripts.PostClick(o,'LeftButton') end end
for _,o in ipairs(objects) do if o.kind=='Button' and o.text=='Appliquer' then o.scripts.OnClick(o) end end
assert(C.lastDelta and C.lastDelta[1]=='hp' and C.lastDelta[2]==8,'Group action keeps existing resource semantics')
-- Exercise the new direct resource/action choices through their real clicks.
for _,o in ipairs(objects) do if o.kind=='Button' and (o.text=='Mana' or o.text=='Bonus') then o.scripts.OnClick(o) end end
for _,o in ipairs(objects) do if o.playerName=='Tester' and o.scripts.PostClick then o.scripts.PostClick(o,'LeftButton') end end
for _,o in ipairs(objects) do if o.kind=='Button' and o.text=='Appliquer' then o.scripts.OnClick(o) end end
assert(C.lastTemp and C.lastTemp[1]=='mana' and C.lastTemp[2]==8,'Direct choices must apply the selected resource and action')
C:ToggleGroupView();assert(not CharacterGroupViewPanel:IsShown())
do local col=Character.RPGUI.colors;if not (col.statMana and col.statMana.fg) then col.statMana={fg={.2,.45,1,1},bg={.03,.07,.2,1}} end end
dofile('Modules/Character/UI_MJ.lua')
dofile('Modules/Character/UI_Initiative.lua')
-- Several effects become separate requests; invalid drafts send nothing.
C.initiative.active=true
C.initiative.participants={{id='Tester',kind='player',name='Tester'}}
local sent={}
function C:RequestAddStatus(targets,text,turns) sent[#sent+1]={targets=targets,text=text,turns=turns};return true end
assert(C:OpenStatusPopup())
local function findButton(text)
 for i=#objects,1,-1 do local o=objects[i];if o.kind=='Button' and o.text==text then return o end end
 error('Missing button '..text)
end
local choose=findButton('Choisir vos cibles...');choose.scripts.OnClick(choose)
local targetPanel
for _,o in ipairs(objects) do if o.kind=='FontString' and o.text=='Groupe de joueurs' then targetPanel=o.parent end end
for _,o in ipairs(objects) do if o.parent==targetPanel and o.participantId=='Tester' then o.scripts.OnClick(o) end end
local add=findButton('+ Ajouter une ligne');add.scripts.OnClick(add)
local editRows={}
for _,o in ipairs(objects) do if o.text and o.turns and o.label and o.kind=='Frame' and o.shown~=false then editRows[#editRows+1]=o end end
assert(#editRows==2,'two independent editor rows')
editRows[1].text:SetText('-7 Vie');editRows[1].turns:SetText('2')
local apply=findButton('Appliquer les états');apply.scripts.OnClick(apply)
assert(#sent==0,'empty second line prevents partial submission')
editRows[2].text:SetText('+8 Mana');editRows[2].turns:SetText('3')
apply.scripts.OnClick(apply)
assert(#sent==2 and sent[1].text=='-7 Vie' and sent[2].text=='+8 Mana')
assert(sent[1].turns=='2' and sent[2].turns=='3' and sent[1].targets[1]=='Tester')

C.initiative.statuses={{id='one',targetId='Tester',text='-7 Vie',turnsLeft=2,source='Tester'},
 {id='two',targetId='Tester',text='+8 Mana',turnsLeft=3,source='Tester'}}
C.initiative.isHost=true
C.OnInitiativeChanged()
local badge
for _,o in ipairs(objects) do if o.participantId=='Tester' and o.statusBadge then badge=o.statusBadge end end
assert(badge,'status badge exists')
badge.scripts.OnEnter(badge)
assert(CharacterActiveStatuses:IsShown() and CharacterActiveStatuses.preview)
badge.scripts.OnMouseUp(badge)
badge.scripts.OnLeave(badge)
assert(CharacterActiveStatuses:IsShown() and not CharacterActiveStatuses.preview,'click pins list beyond hover')
CharacterActiveStatuses:Hide()
badge.scripts.OnEnter(badge);badge.scripts.OnLeave(badge)
assert(not CharacterActiveStatuses:IsShown(),'unfixed preview closes on leave')
C.initiative.active=false;C.OnInitiativeChanged()
assert(CharacterMJPanel:GetWidth()==276)
assert(CharacterMJImpactPanel:GetHeight()==406)
-- Vue MJ : la croix du groupe ne ferme que lui ; celle des Actions ferme tout.
CharacterMJPanel:Toggle();assert(CharacterMJPanel:IsShown() and CharacterMJImpactPanel:IsShown())
CharacterMJPanel:Hide();assert(CharacterMJImpactPanel:IsShown(),'fermer le groupe garde les Actions du MJ')
local groupBtn;for _,o in ipairs(objects) do if o.kind=='Button' and o.text=='Voir le groupe' then groupBtn=o end end
assert(groupBtn,'bouton Voir le groupe');groupBtn.scripts.OnClick(groupBtn);assert(CharacterMJPanel:IsShown() and groupBtn.text=='Masquer le groupe')
CharacterMJPanel:Toggle();assert(not CharacterMJPanel:IsShown() and not CharacterMJImpactPanel:IsShown(),'fermer les Actions ferme tout')
-- User sizing persists and list refreshes do not collapse the chosen height.
local groupView=CharacterMJPanel
local handle=groupView.resizeGrip
assert(handle,'group resize handle')
handle.scripts.OnMouseDown(handle,'LeftButton')
groupView:SetSize(520,480)
groupView.scripts.OnSizeChanged(groupView,520,480)
handle.scripts.OnMouseUp(handle)
assert(CharacterDB.settings.viewSizes.mjGroup.width==520)
groupView._rebuild()
assert(groupView:GetHeight()==480 and groupView:GetWidth()==520,'refresh preserves user dimensions')
local npcView
for _,o in ipairs(objects) do if o.resizeGrip and o~=groupView then npcView=o end end
assert(npcView and npcView.resizeGrip,'NPC resize handle')
npcView.resizeGrip.scripts.OnMouseDown(npcView.resizeGrip,'LeftButton')
npcView:SetSize(600,550);npcView.scripts.OnSizeChanged(npcView,600,550)
npcView.resizeGrip.scripts.OnMouseUp(npcView.resizeGrip)
assert(CharacterDB.settings.viewSizes.mjNpc.width==600 and CharacterDB.settings.viewSizes.mjGroup.width==520,'independent saved sizes')
-- Annonce commune (Début du tour, conditions) : les messages attendent leur tour.
function M:SetFont(path,size) self.fontPath=path;self.fontSize=size;return true end
C:ShowNotice('Premier','a');C:ShowNotice('Second','b')
local notice,title;for _,o in ipairs(objects) do if o.kind=='FontString' and o.text=='Premier' then title=o;notice=o.parent end end
assert(notice and notice.shown and notice.scripts.OnUpdate,'premier affiché')
notice.scripts.OnUpdate(notice,4.1);assert(title.text=='Second' and notice.shown,'second ensuite')
notice.scripts.OnUpdate(notice,4.1);assert(not notice.shown,'file vidée')
C:ShowNotice('Etat','x',true);assert(notice.shown and title.text=='Etat')
local detail;for _,o in ipairs(objects) do if o.kind=='FontString' and o.parent==notice and o.text=='x' then detail=o end end
assert(detail and detail.fontPath and detail.fontPath:find('NotoSans%-Italic'),'sous-texte d un état en italique')
notice.scripts.OnUpdate(notice,.3);assert(notice.shown and not notice.scripts.OnUpdate,'persistant : reste affiché')
local closeBtn;for _,o in ipairs(objects) do if o.kind=='Button' and o.parent==notice and o.scripts.OnClick then closeBtn=o end end
C.initiative=C.initiative or {};C.initiative.active=false;C.OnInitiativeChanged()
assert(notice.shown and title.text=='Etat','hors combat : l état reste affiché')
assert(closeBtn and closeBtn.shown,'croix visible');closeBtn.scripts.OnClick(closeBtn);assert(not notice.shown,'fermé par le joueur')
C:ShowNotice('Auto','y');assert(not closeBtn.shown,'pas de croix sur une annonce qui se ferme seule')
notice.scripts.OnUpdate(notice,4.1);assert(not notice.shown)
print('OK: RPG views load; 13 allies, HP only without numeric values, bounded raid scrolling, MJ dimensions, notice queue')
`;
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+code+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
