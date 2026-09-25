const fs=require('fs'),cp=require('child_process');
const source=fs.readFileSync('Modules/Character/Core.lua','utf8');
const next=source.slice(source.indexOf('function C:NextTurn()'),source.indexOf('\nend',source.indexOf('function C:NextTurn()'))+4);
const lua=`
local C={initiative={active=true,isHost=true,currentIndex=2,round=1,participants={{id='a'},{id='b'}},phase='play'}}
local queue={};C_Timer={After=function(_,fn) queue[#queue+1]=fn end};local ROUND_STEP_DELAY=1
local advances=0;local announcements={}
local function BroadcastInitiative() end
local function AnnounceToGroup(s) announcements[#announcements+1]=s end
local function IsParticipantAlive(p) return not p.dead end
local function ApplyTurnAdvance(idx,ending,round) advances=advances+1;C.initiative.currentIndex=idx end
${next}
assert(C:NextTurn());assert(C.initiative.phase=='resolve_start' and C.initiative.round==1 and advances==0 and #queue==0)
assert(C:NextTurn());assert(C.initiative.phase=='resolution_end' and C.initiative.round==1 and advances==0)
assert(not C:NextTurn());assert(#queue==1)
queue[1]();assert(C.initiative.phase=='counter_focus' and C.initiative.round==1 and advances==0)
assert(not C:NextTurn())
queue[2]();assert(C.initiative.phase=='round_end' and C.initiative.round==1 and advances==0)
assert(not C:NextTurn())
queue[3]();assert(C.initiative.phase=='transition' and C.initiative.round==2 and advances==0)
assert(not C:NextTurn())
queue[4]();assert(C.initiative.phase=='round_start' and advances==0 and C.initiative.currentIndex==2)
assert(not C:NextTurn())
queue[5]();assert(C.initiative.phase=='play' and advances==1 and C.initiative.currentIndex==1 and C.initiative.round==2)
assert(C:NextTurn());assert(advances==2 and C.initiative.currentIndex==2 and C.initiative.round==2)
C.initiative.isHost=false;assert(not C:NextTurn())
C.initiative.isHost=true;C:NextTurn();C:NextTurn();local stale=queue[6];C.initiative._pendingRound=nil;C.initiative.phase='play';stale();assert(C.initiative.phase=='play')
assert(#announcements==0,'Round phases must never send chat announcements')
print('OK: single resolution, single increment, animation lock, start resolution, normal turns, host restriction, stale timer')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:lua,encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
