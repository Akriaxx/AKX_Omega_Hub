const fs=require('fs'),cp=require('child_process');
const s=fs.readFileSync('Modules/Character/Core.lua','utf8');
const fn=s.slice(s.indexOf('function C:UpdateNPC('),s.indexOf('-- ── Lien PNJ'));
const lua=`
local p={id='n',kind='npc',hp={cur=7,max=10,temp=2},mana={cur=3,max=5},endurance={cur=9,max=10}}
local C={initiative={active=true,isHost=true,currentIndex=1,participants={p}}}
local function FindNPC(id) if id==p.id then return p end end
local function SortParticipants() end
local sent=0
local function BroadcastInitiative() sent=sent+1 end
`+fn+`
assert(C:UpdateNPC('n','Edited',9,20,2,10,'icon'))
assert(p.id=='n' and p.name=='Edited' and p.hp.cur==7 and p.hp.max==20 and p.hp.temp==2 and p.mana.cur==2 and sent==1)
C.initiative.isHost=false
assert(not C:UpdateNPC('n','Bad',9,1,1,1))
assert(p.name=='Edited')
C.initiative.isHost=true
assert(not C:UpdateNPC('missing','Bad',9,1,1,1))
assert(not C:UpdateNPC('n','Bad',9,-1,1,1))
assert(p.name=='Edited' and sent==1)
print('OK: NPC edit preserves identity, current resources, bonuses and permissions')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:lua,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
