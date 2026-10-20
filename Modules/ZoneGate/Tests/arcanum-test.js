// Region-linked Arcanum spells: real Core.lua detection with a fake ARC API.
const fs=require('fs'),cp=require('child_process'),path=require('path');
const core=fs.readFileSync(path.join(__dirname,'../Core.lua'),'utf8');
const real=core.slice(core.indexOf('local function Project('),core.indexOf('-- ── Réseau : diffusion'));
const circle=core.slice(core.indexOf('local CIRCLE_POINTS'),core.indexOf('local function MigrateCircles('));
const network=core.slice(core.indexOf('local function PackPoints('),core.indexOf('local function ApplyState(payload'));
const code=`
local ZG={state={}};ZoneGate=ZG
local WIDTH_MARGIN,DEFAULT_WIDTH=1,6
local sub={id='sky',shape='polygon',x=0,y=0,facing=0,mapID=1,width=10,enabled=true,points={{x=-10,y=-10},{x=10,y=-10},{x=10,y=10},{x=-10,y=10}},regionReady=true,
 arcEnterSpell='skyOn',arcExitSpell='skyOff',arcVault='phase',arcToggle=true}
local db={zones={z={id='z',creator='Tester',subZones={sky=sub}}}}
local function EnsureDB() return db end
local px,py,map=-20,0,1
local casts,vault={},{skyOn={fullName='Ciel rouge'},skyOff={fullName='Ciel normal'}}
local loading=false
ARC={XAPI={},PHASE={}}
function ARC.XAPI.GetArcSpell(_,id,isPhase) if loading or not isPhase then return nil end return vault[id] end
function ARC.PHASE.CAST(_,id) casts[#casts+1]=id end
function ARC.CAST(_,id) casts[#casts+1]='personal:'..id end
function ARC.STOP(_,id) casts[#casts+1]='stop:'..id end
function ZG:GetPlayerPose() return px,py,0,map end
${real}
function ZG:TriggerCrossing() end
local function tick(x) px=x;ZG:Tick() end
local function log() return table.concat(casts,',') end
tick(-20);assert(#casts==0)
tick(0);assert(log()=='skyOn','entering casts the entry spell')
tick(9.5);tick(0);assert(#casts==1,'deadband and moving inside do not recast')
local fx=ZG:GetArcEffects()[1];assert(fx.name=='Ciel rouge' and fx.active and fx.canRemove)
ZG:ArcSetActive('sky',false);assert(log()=='skyOn,stop:skyOn,skyOff','player removes the effect')
tick(0);assert(#casts==3,'a removed effect stays removed inside')
ZG:ArcSetActive('sky',true);assert(casts[4]=='skyOn','player puts it back')
tick(20);assert(casts[5]=='stop:skyOn' and casts[6]=='skyOff' and next(ZG.arc)==nil,'leaving removes it')
casts={};ZG:ArcSetActive('sky',false);tick(0);ZG:ArcSetActive('sky',false);tick(20)
assert(log()=='skyOn,stop:skyOn,skyOff','leaving after a manual removal casts nothing more')
casts={};tick(0);map=2;tick(0);assert(log()=='skyOn,stop:skyOn,skyOff','changing instance leaves the region')
map=1;casts={};loading=true;tick(0);assert(#casts==0 and ZG.arc.sky,'phase vault still loading')
loading=false;tick(0);assert(log()=='skyOn','retried once the vault is ready')
sub.enabled=false;tick(0);assert(casts[3]=='skyOff','disabling the checkpoint leaves');sub.enabled=true
casts={};ZG.arc={};sub.arcExitSpell='';tick(20);tick(0);tick(20);assert(log()=='skyOn','no exit spell: nothing interrupted')
sub.shape='line';sub.width=6;ZG.state={};casts={}
local function walk(y) py=y;px=0;ZG:Tick() end
walk(-5);walk(5);assert(log()=='skyOn','line: forward crossing enters');walk(-5);assert(ZG.arc.sky==nil,'line: backward crossing leaves')
sub.arcToggle=false;walk(5);ZG:ArcSetActive('sky',false);assert(ZG.arc.sky.active,'toggle disabled by the author')

local net=assert(load([==[
local ZG=ZoneGate
local SEP=":"
local function MyName() return "Tester" end
local function EnsureDB() return ZoneGateDB end
local function Enc(s) return (tostring(s or ""):gsub("[:\\n\\r]","_")) end
local DEFAULT_WIDTH=6
${circle}
${network}
return {pack=PackState,apply=ApplyStateLine}
]==]))()
function strsplit(sep,s) local t={};for v in (s..sep):gmatch("(.-)"..sep) do t[#t+1]=v end;return table.unpack(t) end
sub.arcExitSpell='skyOff';sub.arcVault='personal';sub.arcToggle=false
ZoneGateDB={zones={z={id='z',name='Z',creator='Tester',subZones={sky=sub}}},themes={}}
local lines={};for l in net.pack():gmatch('[^\\n]+') do lines[#lines+1]=l end
ZoneGateDB={zones={z={id='z',subZones={}}},themes={}}
net.apply(lines[2],'Remote')
local got=ZoneGateDB.zones.z.subZones.sky
assert(got.arcEnterSpell=='skyOn' and got.arcExitSpell=='skyOff' and got.arcVault=='personal' and got.arcToggle==false)
local legacy={strsplit(':',lines[2])};for i=23,26 do legacy[i]=nil end
net.apply(table.concat(legacy,':',1,22),'Old')
got=ZoneGateDB.zones.z.subZones.sky
assert(got.arcEnterSpell=='' and got.arcVault=='phase' and got.arcToggle==true,'older authors: no spell')
legacy[11]='circle';legacy[7],legacy[8],legacy[10]='100','50','12'
net.apply(table.concat(legacy,':',1,22),'Old')
got=ZoneGateDB.zones.z.subZones.sky
assert(got.shape=='polygon' and got.regionReady and #got.points==16,'old circles become closed perimeters')
assert(math.abs(got.points[1].x-112)<1e-6 and math.abs(got.points[1].y-50)<1e-6 and got.x==100 and got.y==50)
print('OK: Arcanum region spell enters, removes, reapplies, leaves, retries while loading, follows lines and syncs; old circles become perimeters')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
