// Auras imposées par un passage : posées dedans (même juste après une connexion),
// reposées si elles disparaissent, retirées en sortant ; partagées par le réseau.
const fs=require('fs'),cp=require('child_process'),path=require('path');
const core=fs.readFileSync(path.join(__dirname,'../Core.lua'),'utf8');
const real=core.slice(core.indexOf('local function Project('),core.indexOf('-- ── Réseau : diffusion'));
const network=core.slice(core.indexOf('local function PackPoints('),core.indexOf('local function ApplyState(payload'));
const code=`
local ZG={state={}};ZoneGate=ZG
local WIDTH_MARGIN,DEFAULT_WIDTH,SEP=1,6,":"
local sub={id='test',passage=true,shape='polygon',x=0,y=0,facing=0,mapID=1,enabled=true,regionReady=true,
  points={{x=-5,y=-5},{x=5,y=-5},{x=5,y=5},{x=-5,y=5}},auras={{id=111,source='phase'},{id=222,source='personal'}}}
local zone={id='z',name='Z',creator='Tester',subZones={test=sub},places={}}
local db={zones={z=zone},themes={},countries={}}
ZoneGateDB=db
local function EnsureDB() return db end
local function MyName() return 'Tester' end
local function Enc(s) return (tostring(s or ''):gsub('[:\\n\\r]','_')) end
local px,py,now=0,0,100
local commands,has={},{}
OS2={ModuleRules={ExecuteServerCommand=function(c) commands[#commands+1]=c
  local verb,id=c:match('^%.(%a+) (%d+) self$');id=tonumber(id)
  if verb=='aura' then has[id]=true elseif verb=='unaura' then has[id]=nil end end}}
C_UnitAuras={GetPlayerAuraBySpellID=function(id) return has[id] and {} or nil end}
function ZG:GetPlayerPose() return px,py,0,1 end
function GetTime() return now end
function wipe(t) for k in pairs(t) do t[k]=nil end return t end
function ZG:FindPlace() end
function ZG:FindSubZone(id) for _,z in pairs(db.zones) do if z.subZones[id] then return z.subZones[id],z end end end
${real}
local function count(verb,id) local n=0;for _,c in ipairs(commands) do if c=='.'..verb..' '..id..' self' then n=n+1 end end;return n end
-- Connexion dans le périmètre : rien pendant le délai de chargement, puis les deux auras.
ZG:HoldAuras();ZG:Tick();assert(#commands==0,'nothing during the loading delay')
now=104;ZG:Tick();assert(count('aura',111)==1 and count('aura',222)==1,'logging in inside applies the auras')
assert(ZoneGateCharDB.forcedAuras[111] and ZoneGateCharDB.forcedAuras[222])
ZG:Tick();assert(#commands==2,'present auras are not resent')
-- Retirée à la main : reposée, mais pas plus d'une fois par intervalle.
has[111]=nil;now=105;ZG:Tick();assert(count('aura',111)==1,'retry waits for the interval')
now=108;ZG:Tick();assert(count('aura',111)==2,'a removed aura is applied again')
-- Sortie : retirées.
px=20;now=110;ZG:Tick();assert(count('unaura',111)==1 and count('unaura',222)==1,'leaving removes the auras')
assert(next(ZoneGateCharDB.forcedAuras)==nil)
-- Reconnexion ailleurs avec une aura restée posée : retirée.
ZoneGateCharDB.forcedAuras[222]=true;has[222]=true;ZG:HoldAuras();now=114;ZG:Tick()
assert(count('unaura',222)==2,'a leftover aura is removed after logging in outside')
-- Passage désactivé : plus rien d'imposé.
px=0;now=120;ZG:Tick();assert(has[111] and has[222])
sub.enabled=false;now=125;ZG:Tick();assert(not has[111] and not has[222],'a disabled passage releases its auras')
sub.enabled=true;now=130;ZG:Tick();ZG:ReleaseAuras();assert(not has[111] and not has[222],'turning the module off releases them')
-- Interrupteur général : coupé, tout est retiré et rien n'est reposé ; rallumé, tout revient.
OmegaHub={Print=function() end}
now=140;ZG:Tick();assert(has[111] and has[222])
ZG:SetAurasEnabled(false);now=141;ZG:Tick();assert(not has[111] and not has[222],'switching off removes the auras')
now=150;ZG:Tick();assert(not has[111],'switched off: nothing is applied inside')
ZG:SetAurasEnabled(true);now=151;ZG:Tick();assert(has[111] and has[222],'switching on applies them again at once')
ZG:ReleaseAuras()
-- Réseau : la liste voyage avec le passage.
local net=assert(load([==[
local ZG=ZoneGate
local SEP=":"
local DEFAULT_WIDTH=6
local function MyName() return "Tester" end
local function EnsureDB() return ZoneGateDB end
local function Enc(s) return (tostring(s or ""):gsub("[:\\n\\r]","_")) end
local function NewPlace(id,zoneId,name) return {id=id,zoneId=zoneId,name=name,aliases={}} end
local function CircleToPerimeter() end
local function ConvertLegacySub() end
${network}
return {pack=PackState,apply=ApplyStateLine}
]==]))()
function strsplit(sep,s) local t={};for v in (s..sep):gmatch("(.-)"..sep) do t[#t+1]=v end;return (unpack or table.unpack)(t) end
local wire=net.pack()
ZoneGateDB={zones={},themes={},countries={}}
for line in wire:gmatch("[^\\n]+") do net.apply(line,"Remote") end
local got=ZoneGateDB.zones.z.subZones.test.auras
assert(#got==2 and got[1].id==111 and got[1].source=='phase' and got[2].id==222 and got[2].source=='personal','auras travel with the passage')
print('OK: passage auras: applied inside even right after logging in, reapplied when removed, removed when leaving or disabled, leftovers cleared, global switch, synced')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
