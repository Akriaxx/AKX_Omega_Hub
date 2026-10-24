const fs=require('fs'),cp=require('child_process'),path=require('path');
const core=fs.readFileSync(path.join(__dirname,'../Core.lua'),'utf8');
const real=core.slice(core.indexOf('local function Project('),core.indexOf('-- ── Réseau : diffusion'));
const code=`
local ZG={state={}};ZoneGate=ZG
local WIDTH_MARGIN,DEFAULT_WIDTH=1,6
local bois={id='bois',name='Bois',actionEnterEnabled=true,actionLeaveEnabled=true,actionMessage='Test',actionCommand='123'}
local plaine={id='plaine',name='Plaine'}
local places={bois=bois,plaine=plaine}
local sub={id='test',passage=true,shape='polygon',x=0,y=0,facing=0,mapID=1,width=5,enabled=true,regionReady=true,points={{x=-5,y=-5},{x=5,y=-5},{x=5,y=5},{x=-5,y=5}},enterPlace='bois'}
local zone={subZones={test=sub},places=places}
local db={zones={z=zone}}
local function EnsureDB() return db end
local px,py,map=-8,0,1
local banners,messages,actions,sounds={},0,{},{}
OmegaHub={Print=function() messages=messages+1 end}
OS2={ModuleRules={ExecuteServerCommand=function(_,mode) actions[#actions+1]=mode end}}
function ZG:GetPlayerPose() return px,py,0,map end
function GetTime() return 100 end
function ZG:FindPlace(id) if id and places[id] then return places[id],zone end end
function ZG:ResolveTheme() return {} end
function ZG:ResolveBannerText(place) return 'Region',place.name end
function ZG:ShowBanner(_,subtitle) banners[#banners+1]=subtitle end
${real}
function ZG:PlayCrossingSound(_,direction) sounds[#sounds+1]=direction end
local function tick(x,y) px=x;py=y or 0;ZG:Tick() end
local function reset() ZG.state={};ZG.here={};banners={};messages=0;actions={};sounds={} end
reset()
tick(-8);tick(-5.7);tick(-5.1);tick(-4.9);tick(-5.2)
assert(#banners==0,'boundary jitter is silent')
tick(-3.5);tick(0)
assert(#banners==1 and banners[1]=='Bois' and actions[1]=='apply' and sounds[1]=='forward','entering shows the place')
assert(ZG.here.bois=='test','player is in the place')
tick(4.6);tick(5.1);tick(4.9);tick(6.5)
assert(#banners==1 and messages==2 and actions[2]=='remove' and sounds[2]=='backward','leaving to no place: no banner, exit sound and action once')
assert(ZG.here.bois==nil)
sub.leavePlace='plaine';tick(0);tick(8)
assert(#banners==2 and banners[2]=='Bois' and ZG.here.plaine==nil and ZG.here.bois==nil,'a perimeter ignores its exit place: the neighbour decides')
sub.leavePlace=nil
reset();ZG.quietUntil=200;tick(0);assert(#banners==0 and ZG.here.bois=='test','right after loading, inside is silent but places the player')
sub.enabled=false;tick(8);assert(ZG.here.bois==nil,'a disabled passage releases its place')
sub.enabled=true;tick(8);assert(#banners==0,'disabled state is discarded')
map=2;tick(0);map=1;tick(0);assert(#banners==0,'instance switch (a loading screen) is not a crossing')
ZG.quietUntil=nil
sub.regionReady=false;reset();tick(-8);tick(0);assert(#banners==0)
sub.regionReady=true;tick(0);assert(#banners==1 and banners[1]=='Bois','validating while inside shows the banner')
sub.shape='line';sub.width=6
local oldTick=tick;tick=function(x,y) oldTick(y or 0,x) end;reset();tick(-5);tick(0,20);tick(5);assert(#banners==0,'going around a line does not count')
bois.actionEnterEnabled=false;bois.actionLeaveEnabled=true
reset();tick(-5);tick(5);assert(#banners==1 and #actions==0,'arrival action does not inherit the departure toggle')
tick(-5);assert(#actions==1 and actions[1]=='remove')
-- Two passages of one region: the second one leads from the wood to the plain.
bois.actionLeaveEnabled=false
local gate={id='gate',passage=true,shape='line',x=0,y=40,facing=0,mapID=1,width=6,enabled=true,enterPlace='plaine',leavePlace='bois'}
zone.subZones.gate=gate;reset()
tick(-5);tick(5);assert(ZG.here.bois=='test')
tick(35);tick(45);assert(ZG.here.bois==nil and ZG.here.plaine=='gate' and banners[2]=='Plaine','a linked passage moves from one place to the next')
tick(35);assert(ZG.here.bois=='gate' and banners[3]=='Bois','and back')
-- Shared border: leaving A and entering B in the same instant is one direct A -> B passage.
local left={id='a',passage=true,shape='polygon',mapID=1,enabled=true,regionReady=true,points={{x=-10,y=-5},{x=0,y=-5},{x=0,y=5},{x=-10,y=5}},enterPlace='bois'}
local right={id='b',passage=true,shape='polygon',mapID=1,enabled=true,regionReady=true,points={{x=0,y=-5},{x=10,y=-5},{x=10,y=5},{x=0,y=5}},enterPlace='plaine'}
zone.subZones={a=left,b=right};bois.actionLeaveEnabled=true;reset()
ZG.quietUntil=200;oldTick(-5);ZG.quietUntil=nil;oldTick(5)
assert(#banners==1 and banners[1]=='Plaine' and #sounds==1 and sounds[1]=='forward' and actions[1]=='remove','one banner, one sound, the departure action of A')
assert(ZG.here.plaine=='b' and ZG.here.bois==nil)
oldTick(-5);assert(#banners==2 and banners[2]=='Bois' and #sounds==2,'and back the same way')
print('OK: passages lead to places: banners, sound and actions once; exit place or none; deadband jitter, initial state, disabled/other instance, unfinished contour, line bypass, direction toggles and linked passages')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
