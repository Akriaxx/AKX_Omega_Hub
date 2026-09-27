const fs=require('fs'),cp=require('child_process'),path=require('path');
const core=fs.readFileSync(path.join(__dirname,'../Core.lua'),'utf8');
const real=core.slice(core.indexOf('local function Project('),core.indexOf('-- ── Réseau : diffusion'));
const code=`
local ZG={state={}};ZoneGate=ZG
local WIDTH_MARGIN,DEFAULT_WIDTH=1,6
local sub={id='test',shape='polygon',x=0,y=0,facing=0,mapID=1,width=5,enabled=true,regionReady=true,points={{x=-5,y=-5},{x=5,y=-5},{x=5,y=5},{x=-5,y=5}},forwardEnabled=true,backwardEnabled=true,actionForwardEnabled=true,actionBackwardEnabled=true,actionMessage='Test',actionCommand='123'}
local db={zones={z={subZones={test=sub}}}}
local function EnsureDB() return db end
local px,py,map=-8,0,1
local banners,messages,actions,sounds=0,0,{},{}
OmegaHub={Print=function() messages=messages+1 end}
OS2={ModuleRules={ExecuteServerCommand=function(_,mode) actions[#actions+1]=mode end}}
function ZG:GetPlayerPose() return px,py,0,map end
function ZG:ResolveTheme() return {} end
function ZG:ResolveBannerText() return 'Region','Checkpoint' end
function ZG:ShowBanner() banners=banners+1 end
${real}
function ZG:PlayCrossingSound(_,direction) sounds[#sounds+1]=direction end
local function tick(x,y) px=x;py=y or 0;ZG:Tick() end
local function reset() ZG.state={};banners=0;messages=0;actions={};sounds={} end
for _,shape in ipairs({'polygon','circle'}) do
 sub.shape=shape;reset()
 tick(-8);tick(-5.7);tick(-5.1);tick(-4.9);tick(-5.2)
 assert(banners==0,'boundary jitter is silent')
 tick(-3.5);tick(0);assert(banners==1 and actions[1]=='apply' and sounds[1]=='forward')
 tick(4.6);tick(5.1);tick(4.9);tick(6.5)
 assert(banners==2 and messages==2 and actions[2]=='remove' and sounds[2]=='backward','slow exit runs all effects once')
 reset();tick(0);assert(banners==0,'loading inside is not a crossing')
 sub.enabled=false;tick(8);sub.enabled=true;tick(8);assert(banners==0,'disabled state is discarded')
 map=2;tick(0);map=1;tick(0);assert(banners==0,'instance switch is not a crossing')
end
sub.shape='polygon';sub.regionReady=false;reset();tick(-8);tick(0);assert(banners==0)
sub.regionReady=true;tick(0);assert(banners==0,'validating establishes the initial side')
sub.shape='line';sub.width=6;
local oldTick=tick;tick=function(x,y) oldTick(y or 0,x) end;reset();tick(-5);tick(0,20);tick(5);assert(banners==0,'going around a line does not count')
sub.actionForwardEnabled=false;sub.actionBackwardEnabled=true
reset();tick(-5);tick(5);assert(banners==1 and #actions==0,'entry action does not inherit exit toggle')
tick(-5);assert(#actions==1 and actions[1]=='remove')
print('OK: slow polygon/circle crossings run banners, sound and actions once; deadband jitter, initial state, disabled/other instance, unfinished contour, line bypass and direction toggles')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
