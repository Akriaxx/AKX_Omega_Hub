// Tracé en direct : seul le terrain de la minimap passe dans le cadre ; ses
// boutons restent dans le coin de l'écran, puis tout reprend sa place.
const fs=require('fs'),cp=require('child_process'),path=require('path');
let mock=fs.readFileSync(path.join(__dirname,'Studio_test.lua'),'utf8');
mock=mock.slice(mock.indexOf('unpack='),mock.indexOf('ZoneGate={'));
const tests=`
for _,key in ipairs({"SetClipsChildren","SetRotation","SetWordWrap","EnableMouseWheel","SetMask","SetMaskTexture"}) do M[key]=function() end end
math.atan2=math.atan2 or function(y,x) return math.atan(y,x) end
function M:SetParent(p) self.parent=p end
function M:GetParent() return self.parent end
function M:SetPoint(...) self.points=self.points or {};self.points[#self.points+1]={...} end
function M:ClearAllPoints() self.points={} end
function M:GetNumPoints() return #(self.points or {}) end
function M:GetPoint(i) return unpack(self.points[i]) end
function M:GetChildren() local list={};for _,o in ipairs(objects) do if o.parent==self and o.kind~='Texture' and o.kind~='FontString' then list[#list+1]=o end end;return unpack(list) end
function M:GetAlpha() return self.alpha end
function M:GetScale() return self.scale or 1 end
function M:IsMouseEnabled() return false end
function M:IsMouseWheelEnabled() return false end
function M:GetZoom() return self.zoom or 0 end
function M:SetZoom(z) self.zoom=z end
function M:GetZoomLevels() return 6 end
local cvars={rotateMinimap='0'}
function GetCVar(k) return cvars[k] end
function SetCVar(k,v) cvars[k]=v end
function GetTime() return 0 end
OmegaHub={Print=function() end}
dofile('Modules/ZoneGate/Core.lua')
local ZG=ZoneGate
function ZG:GetPlayerPose() return 0,0,0,1 end
dofile('Modules/ZoneGate/UI_Style.lua')
local cluster=CreateFrame('Frame','MinimapCluster',UIParent)
Minimap=CreateFrame('Frame','Minimap',cluster);Minimap:SetPoint('TOPRIGHT',cluster,'TOPRIGHT',-10,-20);Minimap:SetSize(140,140)
local addonButton=CreateFrame('Button','LibDBIcon_Test',Minimap);addonButton:SetPoint('CENTER',Minimap,'CENTER',52,-52)
local zoomIn=CreateFrame('Button','MinimapZoomIn',Minimap);zoomIn:SetPoint('BOTTOMRIGHT')
dofile('Modules/ZoneGate/UI_Radar.lua')
local window=CreateFrame('Frame','TraceWindow',UIParent)
local guide=ZG.CreatePassageGuide(window,function() return nil end)
guide:Hide();guide:Show()
local standIn=ZoneGateMinimapStandIn
assert(Minimap.parent==window,'the terrain moves into the trace window')
assert(standIn and standIn:IsShown() and standIn.parent==cluster,'a stand-in keeps the minimap place')
assert(standIn.points[1][2]==cluster and standIn.w==140,'at the exact same spot and size')
assert(addonButton.parent==standIn and addonButton.points[1][2]==standIn and addonButton.points[1][4]==52,'addon buttons stay in the corner, same offset')
assert(zoomIn.parent==standIn and zoomIn:IsShown(),'zoom buttons stay usable')
assert(cvars.rotateMinimap=='1')
guide:Hide()
assert(Minimap.parent==cluster and Minimap.points[1][2]==cluster,'the minimap returns to its corner')
assert(addonButton.parent==Minimap and addonButton.points[1][2]==Minimap,'buttons return to the minimap')
assert(not standIn:IsShown() and cvars.rotateMinimap=='0','stand-in hidden, rotation restored')
print('OK: live trace: terrain borrowed, minimap frame and buttons stay in the corner, everything restored')
`;
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+mock+tests+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
