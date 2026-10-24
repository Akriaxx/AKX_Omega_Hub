// Load the real Core and editor, then exercise countries, regions, places and passages.
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
function GetTime() return 0 end
function GetCursorPosition() return 0,0 end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
OmegaHub={Print=function() end}
dofile('Modules/ZoneGate/Core.lua')
local ZG=ZoneGate
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
gate.regionReady=true
local pose=ZG.GetPlayerPose
ZG.GetPlayerPose=function() return 400,-300,0,1 end
local guide=ZG.CreatePassageGuide(UIParent,function() return gate end)
guide:Refresh();assert(guide.readout.distance>0)
assert(guide.playerMarker.point[4]==138 and guide.playerMarker.point[5]==-98,'player remains at canvas centre')
ZG.GetPlayerPose=function() return 410,-290,.25,1 end
guide:Refresh()
assert(guide.playerMarker.point[4]==138 and guide.playerMarker.point[5]==-98,'moving only translates the contour')
assert(guide.playerMarker.rotation==0,'player always faces up')
for _,angle in ipairs({0,math.pi/2,math.pi,3*math.pi/2}) do
 local right,forward=ZG:PlacementOffset(math.sin(angle)*10,math.cos(angle)*10,angle)
 assert(math.abs(right)<.0001 and math.abs(forward-10)<.0001,'ahead stays above player in every direction')
end
ZG.GetPlayerPose=pose

dofile('Modules/ZoneGate/UI_Panel.lua')
local panel=ZoneGatePanel
local function button(label,parent)
 for _,o in ipairs(objects) do if o.kind=='Button' and o.text==label and (not parent or o.parent==parent) then return o end end
 error('Missing button: '..label)
end
local function click(label,parent) local b=button(label,parent);assert(b.scripts.OnClick,label);b.scripts.OnClick(b);return b end
-- Every creation goes through the named prompt.
local prompt=panel.createPrompt
local function create(label,name)
 click(label);assert(prompt:IsShown(),'creation asks first: '..label)
 local box;for _,o in ipairs(objects) do if o.kind=='EditBox' and o.parent==prompt then box=o end end
 box:SetText(name);click('Créer',prompt);assert(not prompt:IsShown())
end
local function treeHas(text)
 for _,o in ipairs(objects) do if o.kind=='FontString' and o.parent and o.parent.kind=='Button' and o.parent.w==264 and o.parent.shown and o.text==text then return true end end
 return false
end
local function itemTexts(dd) local t={};for _,item in ipairs(dd.items()) do t[#t+1]=item.text end;return table.concat(t,'|') end

-- Region, then its places (the region's database).
click('+ Région');assert(prompt:IsShown() and #ZG:GetZoneList()==0,'nothing is created before confirming')
click('Annuler',prompt);assert(not prompt:IsShown() and #ZG:GetZoneList()==0,'cancel creates nothing')
click('+ Région');click('Créer',prompt);assert(prompt:IsShown() and #ZG:GetZoneList()==0,'a name is required');click('Annuler',prompt)
create('+ Région','Nouvelle région');local z=ZG:GetZone(panel.zoneId);assert(z and panel.mode=='zone' and panel.zoneTab=='places')
assert(z.countryId==nil and treeHas('Nouvelle région'),'without a country the region is top-level')
create('+ Nouveau lieu','Lieu 1');local woods=ZG:FindPlace(panel.placeId);assert(woods and panel.mode=='place')
ZG:RenamePlace(woods.id,'Le bois des Anciens')
local plains=ZG:CreatePlace(z.id,'Les Plaines')
assert(panel.placePages.banner:IsShown() and not panel.placePages.effects:IsShown())
click('Effets');assert(panel.placePages.effects:IsShown())
click('Sort Arcanum');assert(panel.placePages.arcanum:IsShown())
click('Découverte');assert(panel.placePages.discovery:IsShown())

-- Passages: geometry first, then where each side leads.
panel.mode='zone';panel.zoneTab='passages';panel:RefreshAll()
assert(panel.zonePages.passages:IsShown())
create('+ Passage ici','Porte');local s=ZG:FindSubZone(panel.passageId)
assert(s and s.enterPlace==woods.id and s.leavePlace==nil,'a new passage enters the first place and leaves to nothing')
local south=ZG:CreateZone('Plaines du Sud');local ford=ZG:CreatePlace(south.id,'Le Gué')
local items=itemTexts(panel.pickers.leave)
assert(items:find('(Aucun',1,true) and items:find('Les Plaines',1,true) and items:find('Plaines du Sud > Le Gué',1,true),'exit can lead to any of my places')
panel.pickers.leave.onSelect(ford.id);assert(s.leavePlace==ford.id,'cross-region exit')
panel.pickers.leave.onSelect('');assert(s.leavePlace==nil,'exit back to nothing')
panel.pickers.leave.onSelect(plains.id);assert(s.leavePlace==plains.id)
assert(#ZG:GetPlacePassages(plains.id)==1 and ZG:GetPlacePassages(plains.id)[1].which=='leave')
-- Our own dropdown: the list opens under the field, a row picks, then it closes.
local enter=panel.pickers.enter
enter.scripts.OnClick(enter);local list=ZoneGateSelectMenu
assert(list:IsShown() and list.owner==enter and list.rows[3].text.text=='Les Plaines')
list.rows[3].scripts.OnClick(list.rows[3])
assert(not list:IsShown() and s.enterPlace==plains.id and enter:GetText()=='Les Plaines','a row picks the place')
enter.onSelect(woods.id)
click('Périmètre libre');assert(s.shape=='polygon')
assert(panel.traceWindow:IsShown() and panel.tracingId==s.id,'drawing a perimeter shows only the trace window')
local before=#s.points;click('+ Point ici',panel.traceWindow.content);assert(#s.points==before+1)
click('Valider le périmètre',panel.traceWindow.content);assert(panel.traceWindow:IsShown(),'not enough points: stays in trace')
click('Panneau complet',panel.traceWindow.content);assert(not panel.traceWindow:IsShown() and panel:IsShown() and panel.zoneTab=='passages')
click('Passage droit');assert(s.shape=='line')

-- Countries file regions.
create('+ Pays','Nouveau pays');local c=ZG:GetCountry(panel.countryId);assert(c and panel.mode=='country')
create('+ Nouvelle région dans ce pays','Nouvelle région');local inCountry=ZG:GetZone(panel.zoneId)
assert(inCountry.countryId==c.id and treeHas('NOUVEAU PAYS') and treeHas('SANS PAYS'),'country groups its regions, the rest is unfiled')
-- Drag a region onto a country; fold and unfold the accordion.
function M:IsMouseOver() return self.mouseOver end
local function rowWith(text)
 for _,o in ipairs(objects) do if o.kind=='FontString' and o.parent and o.parent.kind=='Button' and o.parent.w==264 and o.parent.shown and o.text==text then return o.parent end end
end
ZG:RenameZone(z.id,'Forêt Automnale');panel:RefreshTree()
local dragged=rowWith('Forêt Automnale');assert(dragged and dragged.dragZone==z.id)
dragged.scripts.OnDragStart(dragged);assert(panel.dragZoneId==z.id and treeHas('SANS PAYS'))
local target=rowWith('NOUVEAU PAYS');target.mouseOver=true
dragged.scripts.OnDragStop(dragged);target.mouseOver=false
assert(z.countryId==c.id and panel.dragZoneId==nil,'dropping on a country files the region')
assert(treeHas('Forêt Automnale'))
-- Creator rows: not a region, not counted, they create in place.
local creator=rowWith('+  Nouvelle région');assert(creator and creator.count.text=='','a creator row is not counted')
assert(rowWith('NOUVEAU PAYS').count.text=='2 régions')
creator.scripts.OnClick(creator);assert(prompt:IsShown())
local box;for _,o in ipairs(objects) do if o.kind=='EditBox' and o.parent==prompt then box=o end end
box:SetText('Plaine');click('Créer',prompt);local made=ZG:GetZone(panel.zoneId);assert(made.countryId==c.id,'creator row files the new region')
ZG:RemoveZone(made.id);panel:RefreshAll()
local countryRow=rowWith('NOUVEAU PAYS');countryRow.toggle.scripts.OnClick(countryRow.toggle)
assert(not treeHas('Forêt Automnale'),'a folded country hides its regions')
countryRow=rowWith('NOUVEAU PAYS');countryRow.toggle.scripts.OnClick(countryRow.toggle)
assert(treeHas('Forêt Automnale'),'and shows them again')
local regionRow=rowWith('Forêt Automnale');assert(treeHas('Le bois des Anciens'))
regionRow.toggle.scripts.OnClick(regionRow.toggle);assert(not treeHas('Le bois des Anciens'),'a folded region hides its places')
panel.searchBox:SetText('bois');assert(treeHas('Le bois des Anciens'),'search unfolds everything')
panel.searchBox:SetText('')
ZG:RemoveCountry(c.id);assert(z.countryId==nil and ZG:GetZone(z.id),'removing a country keeps its regions')

-- Discovery of a place.
local roster={'Tester','Alice','Bob'}
function IsInRaid() return true end
function GetNumGroupMembers() return #roster end
function UnitName(token) if token=='player' then return 'Tester' end;return roster[tonumber((token or ''):match('raid(%d+)'))] end
function UnitIsConnected() return true end
local sent=0
function ZG:SendZoneGrant(id,name) sent=sent+1;local item=self:GetZone(id);item.grantedTo=item.grantedTo or {};item.grantedTo[name]=true;return true end
function ZG:RevokeZoneGrant(id,name) sent=sent+1;self:GetZone(id).grantedTo[name]=nil;return true end
function ZG:SendPlaceGrant(id,name) sent=sent+1;local item=self:FindPlace(id);item.grantedTo[name]=true;return true end
function ZG:RevokePlaceGrant(id,name) sent=sent+1;self:FindPlace(id).grantedTo[name]=nil;return true end
z.grantedTo={Alice=true,Absent=true}
local picker=ZG:OpenDiscoveryPicker('zone',z.id)
assert(picker.selection.Alice and not picker.selection.Bob and #picker.members==2)
click('Tout décocher',picker);click('Annuler',picker);assert(sent==0 and z.grantedTo.Alice)
picker=ZG:OpenDiscoveryPicker('place',woods.id)
click('Tout cocher',picker)
roster={'Tester','Alice'};picker.scripts.OnEvent(picker,'GROUP_ROSTER_UPDATE')
click('Valider',picker);assert(woods.grantedTo.Alice and not woods.grantedTo.Bob,'departed member is not modified')
picker:Hide()

-- A hidden remote name must not become searchable, nor editable.
local remote=ZG:CreateZone('Secret Sanctuary');ZG:CreatePlace(remote.id,'Crypte');remote.creator='Other'
panel:RefreshTree()
local unknownShown=false
for _,o in ipairs(objects) do if o.kind=='FontString' and o.parent and o.parent.w==264 and o.parent.shown and (o.text or ''):find('^Région inconnue') then unknownShown=true end end
assert(unknownShown,'an unknown region still shows without search')
panel.searchBox:SetText('Secret');assert(not treeHas('Secret Sanctuary') and not treeHas('Région inconnue'),'search leaked an unknown name')
panel.searchBox:SetText('Crypte');assert(not treeHas('Crypte'))
panel.searchBox:SetText('')
panel.mode='zone';panel.zoneId=remote.id;panel.zoneTab='places';panel:RefreshAll()
assert(not button('+ Nouveau lieu').shown,'cannot create in another author region')

-- Deleting a place unlinks its passages; deleting a region asks first.
panel.mode='place';panel.placeId=plains.id;panel.placeTab='banner';panel:RefreshAll()
click('Supprimer le lieu');assert(ZG:FindPlace(plains.id),'must await confirmation')
click('Confirmer la suppression');assert(not ZG:FindPlace(plains.id) and s.leavePlace==nil)
panel.mode='zone';panel.zoneId=z.id;panel.zoneTab='settings';panel:RefreshAll()
-- A region with places: a table to reassign each place, applied only on "Exécuter".
local reassign=panel.reassign
click('Supprimer la région');assert(reassign:IsShown() and ZG:GetZone(z.id),'must await the table')
click('Annuler',reassign);assert(ZG:GetZone(z.id) and ZG:FindPlace(woods.id))
click('Supprimer la région')
local rows={};for _,o in ipairs(objects) do if o.parent==reassign and o.items and o.onSelect then rows[#rows+1]=o end end
local all=rows[1];local texts={};for _,item in ipairs(all.items()) do texts[#texts+1]=item.text end
assert(texts[1]=='Ne pas garder' and table.concat(texts,'|'):find('Plaines du Sud',1,true),'targets: none or my other regions')
all.onSelect(south.id)
local woodsPassage=ZG:FindSubZone(s.id)
click('Exécuter',reassign)
local moved,home=ZG:FindPlace(woods.id)
assert(not ZG:GetZone(z.id) and panel.mode==nil and moved and home.id==south.id and moved.zoneId==south.id,'the place moves, the region goes')
assert(woodsPassage and not ZG:FindSubZone(s.id),'its passages go with the region')
-- Without places, a simple confirmation is enough.
local empty=ZG:CreateZone('Vide');panel:DeleteRegion(empty.id)
assert(not reassign:IsShown() and ZG:GetZone(empty.id));click('Confirmer la suppression');assert(not ZG:GetZone(empty.id))
-- Right click opens the context menu.
local region=rowWith('Plaines du Sud');region.scripts.OnClick(region,'RightButton')
assert(ZoneGateSelectMenu:IsShown() and ZoneGateSelectMenu.rows[4].text.text=='Supprimer la région…');ZoneGateSelectMenu:Hide()
-- Border: a neighbouring perimeter, two points, and the path along its contour (both ways, through the closure too).
local borders=ZG:CreateZone('Frontières')
local pa=ZG:CreateSubZone(borders.id,'A');ZG:SetSubZoneShape(pa.id,'polygon')
pa.points={{x=0,y=0},{x=10,y=0},{x=20,y=0},{x=20,y=10},{x=10,y=10},{x=0,y=10}};pa.mapID=1
ZG:SetRegionPointName(pa.id,2,'Gué du Nord');assert(pa.points[2].name=='Gué du Nord')
local pb=ZG:CreateSubZone(borders.id,'B');ZG:SetSubZoneShape(pb.id,'polygon');ZG:ClearRegionPoints(pb.id)
panel.mode='zone';panel.zoneId=borders.id;panel.zoneTab='passages';panel.passageId=pb.id;panel:RefreshAll()
local pick=panel.borderPick
local function selects() local t={};for _,o in ipairs(objects) do if o.parent==pick and o.items and o.onSelect then t[#t+1]=o end end;return t end
local function texts(dd) local t={};for _,item in ipairs(dd.items()) do t[#t+1]=item.text end;return table.concat(t,'|') end
pa.regionReady=false
click('Reprendre une frontière…');assert(pick:IsShown() and pick.source==pa,'the only neighbour is preselected')
local source,from,to,path=unpack(selects())
assert(texts(from):find('2 · Gué du Nord',1,true),'named points show their name')
from.onSelect(5);to.onSelect(2)
assert(#path.items()==2 and path.items()[2].text:find('5 > 4 > 3 > 2',1,true),'a contour still being drawn already offers both ways')
pa.regionReady=true
local options=path.items();assert(#options==2,'a closed contour has two paths')
assert(options[1].text:find('5 > 6 > 1 > 2',1,true) and options[1].text:find('(4 points)',1,true),'through the closure')
path.onSelect(true);click('Ajouter 4 points',pick)
assert(not pick:IsShown() and #pb.points==4,'the whole stretch is copied')
assert(pb.points[1].x==10 and pb.points[1].y==10 and pb.points[3].x==0 and pb.points[3].y==0 and pb.points[4].name=='Gué du Nord','exact coordinates, order and names')
-- Declaring a border on one's own contour, before any neighbour exists, then reusing it.
assert(ZG:DeclareBorder(pa.id,'Frontière Nord',5,2,true) and pa.borders[1].name=='Frontière Nord')
assert(not ZG:DeclareBorder(pa.id,'',5,2,true),'a name is required')
panel.mode='zone';panel.zoneId=borders.id;panel.zoneTab='passages';panel.passageId=pa.id;panel:RefreshAll()
local panelDeclare;for _,o in ipairs(objects) do if o.kind=='Button' and o.text=='Gérer les frontières…' and o.parent~=panel.traceWindow.content then panelDeclare=o end end
assert(pa.regionReady and panelDeclare.shown,'declaring is offered on a closed perimeter, without reopening it')
panelDeclare.scripts.OnClick(panelDeclare);assert(panel.borderDeclare:IsShown() and pa.regionReady)
-- Editing an existing border: pick it, change it, save; then delete a second one.
local dlg=panel.borderDeclare;local dsel={};for _,o in ipairs(objects) do if o.parent==dlg and o.items and o.onSelect then dsel[#dsel+1]=o end end
dsel[1].onSelect(1);assert(dlg.editing==1 and dlg.from==5 and button('Enregistrer',dlg))
dsel[3].onSelect(3);dsel[4].onSelect(false);click('Enregistrer',dlg)
assert(pa.borders[1].to==3 and pa.borders[1].forward==false and pa.borders[1].name=='Frontière Nord','an existing border can be modified')
ZG:DeclareBorder(pa.id,'Temporaire',1,2,true);panelDeclare.scripts.OnClick(panelDeclare);dsel[1].onSelect(2);click('Supprimer',dlg)
assert(#pa.borders==1 and dlg:IsShown(),'and deleted');ZG:UpdateBorder(pa.id,1,'Frontière Nord',5,2,true);dlg:Hide()
local pc=ZG:CreateSubZone(borders.id,'C');ZG:SetSubZoneShape(pc.id,'polygon');ZG:ClearRegionPoints(pc.id)
panel.passageId=pc.id;panel:RefreshAll()
click('Reprendre une frontière…')
local src=selects()[1];local declared
for _,item in ipairs(src.items()) do if not item.title and item.value.border then declared=item end end
assert(declared and declared.text:find('Frontière Nord',1,true),'declared borders are offered first')
src.onSelect(declared.value);assert(pick.from==5 and pick.to==2 and pick.forward==true,'the declared stretch is prefilled')
click('Ajouter 4 points',pick);assert(#pc.points==4 and pc.points[4].name=='Gué du Nord')
ZG:RemoveLastRegionPoint(pa.id);assert(#pa.borders==1,'border still valid while its points exist')
-- Starting a new perimeter from a declared border: empty contour, dialog opened, either end, renumbered from 1.
ZG:FinishRegion(pa.id)
local pd=ZG:CreateSubZone(borders.id,'D');ZG:SetSubZoneShape(pd.id,'polygon');assert(#pd.points==0,'a new perimeter starts empty')
panel:EnterTrace(pd.id);assert(pick:IsShown() and pick.title.text=="Partir d'une frontière",'starting from a border is offered')
local first;for _,item in ipairs(selects()[1].items()) do if not item.title and item.value.border then first=item end end
selects()[1].onSelect(first.value);click('Inverser',pick);assert(pick.from==2 and pick.to==5 and pick.forward==false)
click('Ajouter 3 points',pick)
assert(#pd.points==3 and pd.points[1].name=='Gué du Nord' and pd.points[3].x==pa.points[5].x,'the border opens the new contour, renumbered from 1')
panel:ExitTrace()
print('OK: Crossings editor: countries, regions, places, passages with entry and exit places, cross-region links, discovery, hidden-name search, ownership and deletion confirmation')
`;
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+mock+tests+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
