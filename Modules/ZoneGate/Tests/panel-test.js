// Load the real editor and exercise navigation, filtering and bounded forms.
const fs=require('fs'),cp=require('child_process'),path=require('path');
let mock=fs.readFileSync(path.join(__dirname,'Studio_test.lua'),'utf8');
mock=mock.slice(mock.indexOf('unpack='),mock.indexOf('ZoneGate={'));
const tests=`
function M:SetParent(p) self.parent=p end
function M:SetEnabled(v) self.enabled=v end
function M:SetWordWrap() end
function M:Enable() self.enabled=true end
function M:Disable() self.enabled=false end
function M:GetEffectiveScale() return 1 end
function M:SetChecked(v) self.checked=v end
function M:GetChecked() return self.checked end
function M:SetVerticalScroll(v) self.scroll=v end
function M:GetVerticalScroll() return self.scroll or 0 end
function UI.ApplyStrongLabel() end
function UI.ApplySoftText() end
OmegaHub={Print=function() end}
ZoneGate={};local ZG=ZoneGate
local zones={};local counter=0
function ZG:CreateZone(name) counter=counter+1;local z={id='z'..counter,name=name,creator='Tester',subZones={}};zones[z.id]=z;return z end
function ZG:GetZone(id) return zones[id] end
function ZG:GetZoneList() local list={};for _,z in pairs(zones) do list[#list+1]=z end;table.sort(list,function(a,b)return a.id<b.id end);return list end
function ZG:FindSubZone(id) for _,z in pairs(zones) do if z.subZones[id] then return z.subZones[id],z end end end
function ZG:CreateSubZone(id) local z=zones[id];if not z or z.creator~='Tester' then return end;counter=counter+1;local s={id='s'..counter,name='Checkpoint',shape='line',width=6,enabled=true,forwardEnabled=true,backwardEnabled=true};z.subZones[s.id]=s;return s end
function ZG:RemoveZone(id) zones[id]=nil end
function ZG:RemoveSubZone(id) local s,z=self:FindSubZone(id);if z then z.subZones[id]=nil end end
function ZG:HasLearnedZoneName() return false end
function ZG:HasLearnedSubZoneName() return false end
function ZG:MaskText() return '????' end
function ZG:GetThemeList() return {} end
function ZG:GetTheme() end
function ZG:GetGrantedList() return {} end
function ZG:GetZoneGrantedList() return {} end
function ZG:MaybeRequestSync() end
function ZG:ScheduleBroadcast() end
function ZG:ResolveBannerText() return 'Région inconnue','????' end
function ZG:SetSubZoneShape(id,shape) self:FindSubZone(id).shape=shape end
function ZG:GetPlayerPose() return 0,0,0,1 end
function M:SetRotation(value) self.rotation=value end
math.atan2=math.atan2 or function(y,x) return math.atan(y,x) end
dofile('Modules/ZoneGate/UI_Style.lua')
dofile('Modules/ZoneGate/UI_Radar.lua')
dofile('Modules/ZoneGate/UI_Discovery.lua')
local gate={shape='line',x=0,y=0,facing=0,width=6,mapID=1,enabled=true}
local r=ZG:PlacementReadout(gate,0,-5,0,1)
assert(r.signed==-5 and r.distance==5 and r.status=='Côté départ')
r=ZG:PlacementReadout(gate,0,5,math.pi,1);assert(r.signed==5 and r.status=='Côté arrivée')
r=ZG:PlacementReadout(gate,9,0,0,1);assert(r.lateral==6 and r.status=='Décalé du passage')
assert(ZG:PlacementReadout(gate,0,0,0,2).unavailable)
local nav=ZG:PlacementTarget(gate,0,-10,0)
assert(nav.instruction=='Tout droit' and nav.distance==10 and nav.x==0 and nav.y==0)
assert(ZG:PlacementTarget(gate,10,0,0).instruction=='Tournez à droite')
assert(ZG:PlacementTarget(gate,-10,0,0).instruction=='Tournez à gauche')
assert(ZG:PlacementTarget(gate,0,10,0).instruction=='Faites demi-tour')
assert(ZG:PlacementTarget(gate,0,0,0).instruction=='Passage atteint')
gate.shape='circle';gate.width=10
r=ZG:PlacementReadout(gate,0,0,0,1);assert(r.signed==10 and r.distance==10)
r=ZG:PlacementReadout(gate,15,0,0,1);assert(r.signed==-5 and r.distance==5)
gate.shape='polygon';gate.regionReady=true
gate.points={{x=-5,y=-5},{x=5,y=-5},{x=5,y=5},{x=-5,y=5}}
r=ZG:PlacementReadout(gate,0,0,0,1);assert(r.signed==5 and r.distance==5)
r=ZG:PlacementReadout(gate,8,0,0,1);assert(r.signed==-3 and r.distance==3)
gate.regionReady=false;assert(ZG:PlacementReadout(gate,0,0,0,1).unavailable)
local points,cx,cy,scale=ZG:PlacementGeometry(gate,400,-300)
assert(cx==400 and cy==-300,'view stays centred on player')
for _,p in ipairs(points) do
 assert(math.abs((p.x-cx)*scale)<=122.001 and math.abs((p.y-cy)*scale)<=84.001,'complete contour stays visible')
end
assert(math.abs((400-cx)*scale)<=84.001 and math.abs((-300-cy)*scale)<=122.001,'distant player stays visible too')
gate.regionReady=true
ZG.GetPlayerPose=function() return 400,-300,0,1 end
local guide=ZG.CreatePassageGuide(UIParent,function() return gate end)
guide:Refresh();assert(guide.readout.distance>0)
assert(guide.playerMarker.point[4]==138 and guide.playerMarker.point[5]==-98,'player remains at canvas centre')
local baseRotation=guide.playerMarker.rotation
ZG.GetPlayerPose=function() return 410,-290,.25,1 end
guide:Refresh()
assert(guide.playerMarker.point[4]==138 and guide.playerMarker.point[5]==-98,'moving only translates the contour')
assert(guide.playerMarker.rotation==0 and baseRotation==0,'player always faces up')
for _,angle in ipairs({0,math.pi/2,math.pi,3*math.pi/2}) do
 local right,forward=ZG:PlacementOffset(math.sin(angle)*10,math.cos(angle)*10,angle)
 assert(math.abs(right)<.0001 and math.abs(forward-10)<.0001,'ahead stays above player in every direction')
 right,forward=ZG:PlacementOffset(-math.cos(angle)*10,math.sin(angle)*10,angle)
 assert(math.abs(right-10)<.0001 and math.abs(forward)<.0001,'right remains on screen right')
 for _,p in ipairs(points) do
  right,forward=ZG:PlacementOffset(p.x-cx,p.y-cy,angle)
  assert(math.abs(right*scale)<=122.001 and math.abs(forward*scale)<=84.001,'rotated contour stays in bounds')
 end
end
local right=ZG:PlacementOffset(0,10,math.pi/2)
assert(right>0,'turning left moves a northern landmark to the right')
ZG.GetPlayerPose=function() return 0,0,0,1 end
dofile('Modules/ZoneGate/UI_Panel.lua')
local panel=ZoneGatePanel
local function button(label,parent)
 for _,o in ipairs(objects) do if o.kind=='Button' and o.text==label and (not parent or o.parent==parent) then return o end end
 error('Missing button: '..label)
end
local function click(label,parent) local b=button(label,parent);assert(b.scripts.OnClick);b.scripts.OnClick(b);return b end
click('+ Créer une région');local z=ZG:GetZone(panel.selectedZoneId);assert(z and panel.formMode=='zone')
click('+ Placer un checkpoint ici');local s=ZG:FindSubZone(panel.selectedSubZoneId);assert(s and panel.formMode=='subzone')
assert(panel.checkpointPages.placement:IsShown() and not panel.checkpointPages.effects:IsShown())
local roster={'Tester','Alice','Bob'}
function IsInRaid() return true end
function GetNumGroupMembers() return #roster end
function UnitName(token) if token=='player' then return 'Tester' end;return roster[tonumber((token or ''):match('raid(%d+)'))] end
function UnitIsConnected() return true end
local sent=0
function ZG:SendZoneGrant(id,name) sent=sent+1;local item=self:GetZone(id);item.grantedTo=item.grantedTo or {};item.grantedTo[name]=true;return true end
function ZG:RevokeZoneGrant(id,name) sent=sent+1;self:GetZone(id).grantedTo[name]=nil;return true end
function ZG:SendSubZoneGrant(id,name) sent=sent+1;local item=self:FindSubZone(id);item.grantedTo=item.grantedTo or {};item.grantedTo[name]=true;return true end
function ZG:RevokeGrant(id,name) sent=sent+1;self:FindSubZone(id).grantedTo[name]=nil;return true end
z.grantedTo={Alice=true,Absent=true}
local picker=ZG:OpenDiscoveryPicker('zone',z.id)
assert(picker.selection.Alice and not picker.selection.Bob and #picker.members==2)
click('Tout décocher',picker);assert(sent==0 and z.grantedTo.Alice)
click('Annuler',picker);assert(sent==0 and z.grantedTo.Alice)
picker=ZG:OpenDiscoveryPicker('zone',z.id)
click('Tout cocher',picker);click('Valider',picker)
assert(sent==1 and z.grantedTo.Alice and z.grantedTo.Bob and z.grantedTo.Absent)
picker=ZG:OpenDiscoveryPicker('zone',z.id)
click('Tout décocher',picker);click('Valider',picker)
assert(not z.grantedTo.Alice and not z.grantedTo.Bob and z.grantedTo.Absent)
picker=ZG:OpenDiscoveryPicker('subzone',s.id)
click('Tout cocher',picker)
roster={'Tester','Alice'};picker.scripts.OnEvent(picker,'GROUP_ROSTER_UPDATE')
click('Valider',picker);assert(s.grantedTo.Alice and not s.grantedTo.Bob,'departed member is not modified')
roster={'Tester'};picker=ZG:OpenDiscoveryPicker('zone',z.id)
assert(not picker.saveButton.enabled and #picker.members==0);picker:Hide()
click('Déclenchement');assert(panel.checkpointPages.effects:IsShown() and not panel.checkpointPages.placement:IsShown())
click('Découverte');assert(panel.checkpointPages.discovery:IsShown() and not panel.checkpointPages.effects:IsShown())
click('Placement');click('Périmètre libre');assert(s.shape=='polygon')
-- A hidden remote name must not become searchable.
local remote=ZG:CreateZone('Secret Sanctuary');remote.creator='Other'
panel.searchBox:SetText('Secret Sanctuary')
for _,o in ipairs(objects) do if o.kind=='Button' and o.w==248 and o.h==32 then assert(not o.shown,'search leaked an unknown name') end end
panel.searchBox:SetText('')
panel.selectedZoneId=remote.id;panel.formMode='zone';panel:RefreshAll()
assert(not button('+ Placer un checkpoint ici').shown,'cannot create in another author region')
panel.selectedZoneId=z.id;panel.formMode='zone';panel:RefreshAll()
click('Supprimer la région');assert(ZG:GetZone(z.id),'must await confirmation')
click('Annuler');assert(ZG:GetZone(z.id))
click('Supprimer la région');click('Confirmer la suppression');assert(not ZG:GetZone(z.id))
print('OK: Crossings editor, create/checkpoint flow, tabs, shapes, hidden-name search, ownership and deletion confirmation')
`;
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+mock+tests+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
