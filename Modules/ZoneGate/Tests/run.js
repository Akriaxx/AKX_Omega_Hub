// Run the Lua UI harness and actual network functions without copying them.
const fs=require('fs'),path=require('path'),cp=require('child_process');
const core=fs.readFileSync(path.join(__dirname,'../Core.lua'),'utf8');
const network=core.slice(core.indexOf('local function PackPoints('),core.indexOf('local function ApplyState(payload'));
const harness=fs.readFileSync(path.join(__dirname,'Studio_test.lua'),'utf8');
const music=core.slice(core.indexOf('ZG.MusicDir ='),core.indexOf('-- Thème appliqué'));
const setter=core.slice(core.indexOf('function ZG:SetThemeSound('),core.indexOf('-- Zone/Sous-zone → thème'));
const soundSetup=`function InstallSoundLibrary() local ZG=ZoneGate;local function MyName() return "Tester" end\n${music}\n${setter}\nend\n`;
const test=`
local net=assert(load([==[
local ZG=ZoneGate
local SEP=":"
local function MyName() return "Tester" end
local function EnsureDB() return ZoneGateDB end
local function Enc(s) return tostring(s or ""):gsub("[:\\n\\r]","_") end
${network}
return {pack=PackState,apply=ApplyStateLine}
]==]))()
function strsplit(sep,s)
 local t={};for value in (s..sep):gmatch("(.-)"..sep) do t[#t+1]=value end;return unpack(t)
end
ZoneGate.SepLabels={none="None",single="Single",double="Double"}
ZoneGate.FrameLabels={none="None",box="Box",ornate="Ornate"}
local own=ZoneGate:CreateStudioTheme(ZoneGate.StudioPresets[3])
ZoneGateDB={zones={},themes={[own.id]=own}}
local wire=net.pack()
ZoneGateDB={zones={},themes={}}
net.apply(wire,"Remote")
local received=ZoneGateDB.themes[own.id]
assert(received.design=="sumi" and received.motion=="split" and received.placement=="center" and received.bannerWidth==600)
local fields={strsplit(":",wire)}
local legacy={};for i=1,23 do legacy[i]=fields[i] end
net.apply(table.concat(legacy,":"),"Legacy")
assert(ZoneGateDB.themes[own.id].design=="classic" and ZoneGateDB.themes[own.id].bannerWidth==600)
assert(received.creator=="Remote")
print("OK: real network round-trip and legacy theme compatibility")
`;
const cli=process.argv[2];if(!cli)throw Error('Pass the Fengari CLI path');
const result=cp.spawnSync(process.execPath,[cli,'-'],{input:'local ok,err=pcall(function()\n'+soundSetup+harness+'\n'+test+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
