// Place-linked Arcanum spells: real Core.lua detection with a fake ARC API,
// then the network format and the conversion of older checkpoints.
const fs=require('fs'),cp=require('child_process'),path=require('path');
const core=fs.readFileSync(path.join(__dirname,'../Core.lua'),'utf8');
const between=(a,b)=>core.slice(core.indexOf(a),core.indexOf(b));
const real=between('local function Project(','-- ── Réseau : diffusion');
const circle=between('local CIRCLE_POINTS','local function MigrateCircles(');
const newPlace=between('local function NewPlace(','-- Renvoie place, zone');
const legacy=between('local function Filled(','local function MigratePlaces(');
const network=between('local function PackPoints(','local function ApplyState(payload');
const code=`
local ZG={state={}};ZoneGate=ZG
local WIDTH_MARGIN,DEFAULT_WIDTH=1,6
local sky={id='sky',name='Ciel',arcEnterSpell='skyOn',arcExitSpell='skyOff',arcVault='phase',arcToggle=true}
local cave={id='cave',name='Grotte'}
local places={sky=sky,cave=cave}
local sub={id='p1',passage=true,shape='polygon',x=0,y=0,facing=0,mapID=1,width=10,enabled=true,points={{x=-10,y=-10},{x=10,y=-10},{x=10,y=10},{x=-10,y=10}},regionReady=true,enterPlace='sky'}
local zone={id='z',creator='Tester',subZones={p1=sub},places=places}
local db={zones={z=zone}}
local function EnsureDB() return db end
function ZG:FindPlace(id) if id and places[id] then return places[id],zone end end
local px,py,map=-20,0,1
local casts,vault={},{skyOn={fullName='Ciel rouge'},skyOff={fullName='Ciel normal'}}
local loading=false
ARC={XAPI={},PHASE={}}
function ARC.XAPI.GetArcSpell(_,id,isPhase) if loading or not isPhase then return nil end return vault[id] end
function ARC.PHASE.CAST(_,id) casts[#casts+1]=id end
function ARC.CAST(_,id) casts[#casts+1]='personal:'..id end
function ARC.STOP(_,id) casts[#casts+1]='stop:'..id end
function ZG:GetPlayerPose() return px,py,0,map end
function GetTime() return 100 end
${real}
function ZG:TriggerCrossing() end
local function tick(x) px=x;ZG:Tick() end
local function log() return table.concat(casts,',') end
tick(-20);assert(#casts==0)
tick(0);assert(log()=='skyOn','entering casts the entry spell')
tick(9.5);tick(0);assert(#casts==1,'deadband and moving inside do not recast')
local fx=ZG:GetArcEffects()[1];assert(fx.id=='sky' and fx.name=='Ciel rouge' and fx.active and fx.canRemove)
ZG:ArcSetActive('sky',false);assert(log()=='skyOn,stop:skyOn,skyOff','player removes the effect')
tick(0);assert(#casts==3,'a removed effect stays removed inside')
ZG:ArcSetActive('sky',true);assert(casts[4]=='skyOn','player puts it back')
tick(20);assert(casts[5]=='stop:skyOn' and casts[6]=='skyOff' and next(ZG.arc)==nil,'leaving removes it')
casts={};ZG:ArcSetActive('sky',false);tick(0);ZG:ArcSetActive('sky',false);tick(20)
assert(log()=='skyOn,stop:skyOn,skyOff','leaving after a manual removal casts nothing more')
casts={};tick(0);map=2;tick(0);assert(log()=='skyOn,stop:skyOn,skyOff','changing instance leaves the place')
map=1;casts={};loading=true;tick(0);assert(#casts==0 and ZG.arc.sky,'phase vault still loading')
loading=false;tick(0);assert(log()=='skyOn','retried once the vault is ready')
sub.enabled=false;tick(0);assert(casts[3]=='skyOff','disabling the passage leaves');sub.enabled=true
casts={};ZG.arc={};ZG.here={};sky.arcExitSpell='';tick(20);tick(0);tick(20);assert(log()=='skyOn','no exit spell: nothing interrupted')
sky.arcExitSpell='skyOff'
-- A passage inside the sky leads to the cave: going through it leaves the sky.
local door={id='p2',passage=true,shape='line',x=0,y=5,facing=0,mapID=1,width=6,enabled=true,enterPlace='cave',leavePlace='sky'}
zone.subZones.p2=door;ZG.state={};ZG.here={};ZG.arc={};casts={}
px,py=0,0;ZG:Tick();assert(log()=='skyOn')
py=2;ZG:Tick();py=8;ZG:Tick();assert(ZG.arc.sky==nil and ZG.here.cave=='p2' and casts[3]=='skyOff','a passage to another place leaves the sky')
py=2;ZG:Tick();assert(casts[4]=='skyOn','coming back enters it again')
zone.subZones.p2=nil
sub.shape='line';sub.width=6;ZG.state={};ZG.here={};ZG.arc={};casts={}
local function walk(y) py=y;px=0;ZG:Tick() end
walk(-5);walk(5);assert(log()=='skyOn','line: forward crossing enters');walk(-5);assert(ZG.arc.sky==nil,'line: backward crossing leaves')
sky.arcToggle=false;walk(5);ZG:ArcSetActive('sky',false);assert(ZG.arc.sky.active,'toggle disabled by the author')

local net=assert(load([==[
local ZG=ZoneGate
local SEP=":"
local function MyName() return "Tester" end
local function EnsureDB() return ZoneGateDB end
local function Enc(s) return (tostring(s or ""):gsub("[:\\n\\r]","_")) end
local DEFAULT_WIDTH=6
${circle}
${newPlace}
${legacy}
${network}
return {pack=PackState,apply=ApplyStateLine}
]==]))()
function strsplit(sep,s) local t={};for v in (s..sep):gmatch("(.-)"..sep) do t[#t+1]=v end;return table.unpack(t) end
sky.arcVault='personal';sky.aliases={old=true};sub.leavePlace='cave'
ZoneGateDB={zones={z={id='z',name='Z',creator='Tester',countryId='c1',subZones={p1=sub},places={sky=sky}}},themes={},countries={c1={id='c1',name='Royaume',creator='Tester'}}}
local lines={};for l in net.pack():gmatch('[^\\n]+') do lines[#lines+1]=l end
ZoneGateDB={zones={},themes={},countries={}}
for _,l in ipairs(lines) do net.apply(l,'Remote') end
local z=ZoneGateDB.zones.z
assert(ZoneGateDB.countries.c1.name=='Royaume' and z.countryId=='c1','country and filing sync')
local got=z.places.sky
assert(got.arcEnterSpell=='skyOn' and got.arcExitSpell=='skyOff' and got.arcVault=='personal' and got.arcToggle==false and got.aliases.old)
local pass=z.subZones.p1
assert(pass.enterPlace=='sky' and pass.leavePlace=='cave' and pass.shape=='line' and pass.creator=='Remote')
-- Named border points travel with the perimeter.
sub.shape='polygon';sub.points={{x=1,y=2,name='Gué du Nord'},{x=3,y=4}};sub.borders={{name='Frontière Nord',from=2,to=1,forward=false}}
ZoneGateDB={zones={z={id='z',name='Z',creator='Tester',subZones={p1=sub},places={sky=sky}}},themes={},countries={}}
lines={};for l in net.pack():gmatch('[^\\n]+') do lines[#lines+1]=l end
ZoneGateDB={zones={},themes={},countries={}}
for _,l in ipairs(lines) do net.apply(l,'Remote') end
local pts=ZoneGateDB.zones.z.subZones.p1.points
assert(pts[1].name=='Gué du Nord' and pts[2].name==nil and pts[2].x==3,'border names sync')
local got=ZoneGateDB.zones.z.subZones.p1.borders[1];assert(got.name=='Frontière Nord' and got.from==2 and got.to==1 and got.forward==false,'declared borders sync')
z=ZoneGateDB.zones.z
-- An author with an older version still sends checkpoints: they become places.
local old={'SUB','old1','z','Le bois','1','1','100','50','0','12','line','1','1','0','','','Les plaines','Bonjour','123','1','0','','skyOn','skyOff','phase','1'}
net.apply(table.concat(old,':'),'Remote')
local converted=z.subZones.old1
local woods,plains=z.places.old1,z.places.old1_b
assert(converted.passage and converted.enterPlace=='old1' and converted.leavePlace=='old1_b','legacy checkpoint becomes a passage')
assert(woods.name=='Le bois' and woods.actionMessage=='Bonjour' and woods.actionEnterEnabled and woods.arcEnterSpell=='skyOn')
assert(plains.name=='Les plaines' and converted.forwardName==nil and converted.arcEnterSpell==nil)
old[2]='old2';old[17]=''
net.apply(table.concat(old,':'),'Remote')
assert(z.subZones.old2.enterPlace=='old1' and z.places.old1.aliases.old2 and z.subZones.old2.leavePlace==nil,'same village shares one place')
old[2]='old3';old[11]='circle'
net.apply(table.concat(old,':',1,22),'Remote')
got=z.subZones.old3
assert(got.shape=='polygon' and got.regionReady and #got.points==16,'old circles become closed perimeters')
assert(math.abs(got.points[1].x-112)<1e-6 and math.abs(got.points[1].y-50)<1e-6 and got.x==100 and got.y==50)
print('OK: place Arcanum spell enters, removes, reapplies, leaves, retries while loading, follows lines and linked passages; countries, places and passages sync; old checkpoints become places')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
