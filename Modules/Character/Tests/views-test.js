const fs=require('fs'),path=require('path'),cp=require('child_process');
const root=path.join(__dirname,'..');
// Reuse the existing basic WoW widget mock, then exercise real Character views.
let mock=fs.readFileSync(path.join(root,'../ZoneGate/Tests/Studio_test.lua'),'utf8');
mock=mock.slice(mock.indexOf('unpack='),mock.indexOf('ZoneGate={'));
const code=mock+`
function M:GetParent() return self.parent end
function M:SetWordWrap() end
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
dofile('Modules/Character/UI_MJ.lua')
dofile('Modules/Character/UI_Initiative.lua')
assert(CharacterMJPanel:GetWidth()==276)
assert(CharacterMJImpactPanel:GetHeight()==346)
print('OK: RPG views load; 13 allies, HP only without numeric values, bounded raid scrolling, MJ dimensions')
`;
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+code+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
