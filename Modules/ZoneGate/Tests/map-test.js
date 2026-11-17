// Carte de région : choix de la région, remplissage des lieux, noms masqués,
// position du joueur, raccourci de la carte du jeu et bascule entre les cartes.
const fs=require('fs'),cp=require('child_process'),path=require('path');
let mock=fs.readFileSync(path.join(__dirname,'Studio_test.lua'),'utf8');
mock=mock.slice(mock.indexOf('unpack='),mock.indexOf('ZoneGate={'));
const tests=`
for _,key in ipairs({"SetClipsChildren","SetShadowColor","SetShadowOffset","SetFontObject","SetWordWrap","SetRotation","UnregisterEvent","HookScript_"}) do M[key]=M[key] or function() end end
math.atan2=math.atan2 or function(y,x) return math.atan(y,x) end
function M:SetVertexOffset(i,x,y) self.vertex=self.vertex or {};self.vertex[i]={x,y} end
function M:SetEnabled(v) self.enabled=v end
function M:SetParent(p) self.parent=p end
function M:GetEffectiveScale() return 1 end
function M:GetLeft() return 0 end
function M:GetTop() return 1000 end
function M:IsMouseOver() return false end
function M:HasFocus() return false end
function GetTime() return 0 end
function GetCursorPosition() return 0,0 end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
function HideUIPanel(f) f:Hide() end
function ShowUIPanel(f) f:Show() end
function InCombatLockdown() return false end
local overrides={}
function GetBindingKey(action) if action=='TOGGLEWORLDMAP' then return 'M' end end
function ClearOverrideBindings() overrides={} end
function SetOverrideBindingClick(_,_,key,button) overrides[key]=button end
OmegaHub={Print=function() end}
dofile('Modules/ZoneGate/Core.lua')
local ZG=ZoneGate
local px,py,map=0,0,1
function ZG:GetPlayerPose() return px,py,0,map end
dofile('Modules/ZoneGate/UI_Style.lua')
WorldMapFrame=CreateFrame('Frame','WorldMapFrame',UIParent);WorldMapFrame:Hide()
function ToggleWorldMap() if WorldMapFrame:IsShown() then WorldMapFrame:Hide() else WorldMapFrame:Show() end end
dofile('Modules/ZoneGate/UI_Map.lua')
local win

-- Deux régions : la mienne autour du joueur, une autre plus loin dont je ne connais rien.
local mine=ZG:CreateZone('Forêt Automnale')
local woods=ZG:CreatePlace(mine.id,'Bois des Sorcières')
local square=ZG:CreateSubZone(mine.id,'Bois',woods.id)
square.shape='polygon';square.regionReady=true;square.mapID=1
square.points={{x=-10,y=-10},{x=10,y=-10},{x=10,y=10},{x=-10,y=10}}
local other=ZG:CreateZone('Secret')
local crypt=ZG:CreatePlace(other.id,'Crypte')
local far=ZG:CreateSubZone(other.id,'Crypte',crypt.id)
other.creator='Other';far.creator='Other';far.shape='polygon';far.regionReady=true;far.mapID=1;far.enterPlace=crypt.id
-- Contour en L : six sommets, quatre triangles.
far.points={{x=500,y=500},{x=540,y=500},{x=540,y=520},{x=520,y=520},{x=520,y=540},{x=500,y=540}}

-- Un pays, mes deux régions dedans ; une région sans pays ailleurs.
local country=ZG:CreateCountry('Osolninh')
mine.countryId=country.id;other.countryId=country.id
local lone=ZG:CreateZone('Plaine');local field=ZG:CreatePlace(lone.id,'Champ')
local fs=ZG:CreateSubZone(lone.id,'Champ',field.id);fs.shape='polygon';fs.regionReady=true;fs.mapID=1
fs.points={{x=900,y=900},{x=920,y=900},{x=920,y=920}}
local function scan()
  local tris,labels=0,{}
  for _,o in ipairs(objects) do
    if o.kind=='Texture' and o.vertex and o.shown then tris=tris+1 end
    if o.kind=='FontString' and o.shown and o.parent and o.parent.parent==win.canvas then labels[#labels+1]=o.text end
  end
  return tris,labels
end
local function has(labels,t) for _,l in ipairs(labels) do if l==t then return true end end end

-- Raccourci : la touche de la carte du jeu ouvre la carte du pays.
ZG:BindMapKey()
assert(overrides.M=='ZoneGateMapToggle','M is redirected to the Crossings map')
ZG:ToggleRegionMap()
win=ZoneGateRegionMap
assert(win:IsShown() and win.level=='country' and win.country==country.id,'M opens the country around the player')
assert(win.title:GetText()=='Osolninh' and win.help:GetText():find('Clic : ouvrir',1,true))
assert(win.picker:GetText()=='Osolninh' and win.follow,'the menu shows the country where the player is, and follows him')
local tris,labels=scan()
assert(tris==6,'every region of the country is filled (2 + 4 triangles), got '..tris)
assert(has(labels,'Forêt Automnale') and has(labels,'??????') and not has(labels,'Secret'),'region names, masked when unknown')
assert(not has(labels,'Bois des Sorcières'),'the country view names regions, not places')
assert(not has(labels,'Plaine'),'a region of another country is not drawn')
assert(win.player==nil,'the exact player position is never shown')

-- Clic sur une région : ses lieux.
local sx,sy=win:ToScreen(0,0)
assert(win:RegionAt(sx,sy)==mine,'clicking inside a region finds it')
win:ShowRegion(win:RegionAt(sx,sy))
assert(win.level=='region' and win.title:GetText()=='Forêt Automnale' and win.help:GetText():find('Clic droit',1,true),'the region opens, right click goes back')
tris,labels=scan()
assert(tris==2 and has(labels,'Bois des Sorcières'),'its places are filled and named')
win:ShowRegion(other);tris,labels=scan()
assert(win.title:GetText()=='??????' and has(labels,'??????') and not has(labels,'Crypte'),'an unknown region and place stay masked')
ZG:MarkLearnedSubZoneName(crypt.id);ZG:MarkLearnedZoneName(other.id);win:Draw()
assert(win.title:GetText()=='Secret','a learned region name shows')
win.canvas.scripts.OnMouseUp(win.canvas,'RightButton')
assert(win.level=='country' and win.country==country.id and win.follow,'right click: back to the country, following again')
win.canvas.scripts.OnMouseUp(win.canvas,'RightButton');assert(win.level=='country','right click on the country view does nothing')

-- Menu : les pays, puis « Sans pays ».
local items=win.picker.items()
assert(items[1].text=='Osolninh' and items[#items].text=='Sans pays','countries listed, regions without a country last')
win.picker.onSelect(items[#items].value);tris,labels=scan()
assert(win.title:GetText()=='Sans pays' and has(labels,'Plaine') and not win.follow,'a chosen country stops following the player')
win.picker.onSelect(items[1].value);assert(win.country==country.id and win.follow,'choosing the country where one is follows again')

-- Ailleurs, sans aucune région sur cette carte.
map=2;win:ShowCurrent()
assert(win.empty:IsShown(),'no region: a message instead of a map')
map=1

-- Bascule : carte du jeu, puis retour.
ZG:ShowGameMap();assert(WorldMapFrame:IsShown() and not win:IsShown(),'switch to the game map')
ZG:ToggleRegionMap();assert(not WorldMapFrame:IsShown() and not win:IsShown(),'M closes the game map when it is open')
ZG:ShowRegionMap();assert(win:IsShown())
ZG:UnbindMapKey();assert(next(overrides)==nil and not win:IsShown(),'turning the module off gives M back')
print('OK: Crossings map: country around the player, click a region to see its places, back, country menu, no player marker, filled places, masked names, no-region message, game map switch and M key')
`;
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+mock+tests+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
