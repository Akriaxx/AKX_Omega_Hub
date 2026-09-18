const fs=require('fs'),cp=require('child_process'),path=require('path');
const root=path.join(__dirname,'..');
const core=fs.readFileSync(path.join(root,'Core.lua'),'utf8');
const stats=core.slice(core.indexOf('local function NewChar()'),core.indexOf('-- ── Serialisation'));
const hud=fs.readFileSync(path.join(root,'UI_HUD.lua'),'utf8');
const test=`
unpack=table.unpack or unpack
local all={};local M={}
local function object(kind,name,parent)
 local o=setmetatable({kind=kind,parent=parent,shown=true,scripts={},w=1,h=1}, {__index=M})
 all[#all+1]=o;if name then _G[name]=o end;return o
end
function CreateFrame(kind,name,parent) return object(kind,name,parent) end
function M:CreateLine() return object('Line',nil,self) end
function M:SetThickness(v) self.thickness=v end
function M:SetStartPoint(...) self.start={...} end
function M:SetEndPoint(...) self.finish={...} end
function M:CreateTexture() return object('Texture',nil,self) end
function M:CreateMaskTexture() return object('Mask',nil,self) end
function M:CreateFontString() return object('Text',nil,self) end
function M:SetScript(k,v) self.scripts[k]=v end
function M:GetScript(k) return self.scripts[k] end
function M:SetSize(w,h) self.w=w;self.h=h end
function M:SetWidth(w) self.w=w end
function M:GetWidth() return self.w end
function M:SetHeight(h) self.h=h end
function M:SetPoint(...) self.point={...} end
function M:GetPoint() return unpack(self.point) end
function M:SetScale(s) self.scale=s end
function M:SetUnit(unit) self.unit=unit end
function M:SetPortraitZoom(zoom) self.zoom=zoom end
function M:SetCamDistanceScale(scale) self.cameraScale=scale end
function M:SetVertexColor(...) self.color={...} end
function M:SetText(t) self.text=t end
function M:GetText() return self.text or '' end
function M:HasFocus() return self.focus end
function M:SetFontObject() end
function M:SetShadowColor() end
function M:SetShadowOffset() end
function M:SetFocus() self.focus=true;if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end end
function M:ClearFocus() if self.focus then self.focus=false;if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end end
function M:IsShown() return self.shown end
function M:Show() self.shown=true end
function M:Hide() local was=self.shown;self.shown=false;if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function M:SetShown(v) if v then self:Show() else self:Hide() end end
function M:StartMoving() self.moving=true end
function M:StopMovingOrSizing() self.moving=false end
for _,k in ipairs({'SetFrameStrata','SetMovable','SetClampedToScreen','EnableMouse','RegisterForDrag','RegisterForClicks','SetAllPoints','SetTexture','SetColorTexture','AddMaskTexture','SetJustifyH','SetWordWrap','SetTextColor','SetMaxLetters','SetAutoFocus','HighlightText','ClearAllPoints','RegisterEvent','SetOwner','AddLine'}) do M[k]=function() end end
UIParent=object('Frame');GameTooltip=object('Tooltip')
local player='Tester'
function UnitName() return player end
function GetRealmName() return 'Realm' end
function UnitExists() return true end
function SetPortraitTexture(icon,unit) icon.unit=unit end
local shift=false
function IsShiftKeyDown() return shift end
OS2={UI={}}
function OS2.UI.CreateStyledEditBox(parent) return object('EditBox',nil,parent) end
CharacterDB={settings={}}
Character={};local C=Character
function C:GetSettings() return CharacterDB.settings end
function C:GetDisplayName() return 'Test RP' end
local broadcasts,oldRefresh=0,0
function C:Broadcast() broadcasts=broadcasts+1 end
C.OnMyDataChanged=function() oldRefresh=oldRefresh+1 end
${stats}
${hud}
assert(not CharacterResourceHUD:IsShown())
C:EnableResourceHUD();assert(CharacterResourceHUD:IsShown())
local editor,health,portrait
for _,o in ipairs(all) do
 if o.kind=='EditBox' then editor=o end
 if o.kind=='Button' and o.fields and not health then health=o end
 if o.kind=='Button' and not o.fields and not portrait then portrait=o end
end
local groupClicks,mjClicks,settingsClicks=0,0,0
function C:ToggleGroupView() groupClicks=groupClicks+1 end
function C:ToggleSettings() settingsClicks=settingsClicks+1 end
CharacterMJPanel={Toggle=function() mjClicks=mjClicks+1 end}
for _,button in ipairs({'LeftButton','RightButton','MiddleButton'}) do
 portrait.scripts.OnMouseDown(portrait,button);portrait.scripts.OnClick(portrait,button)
end
assert(groupClicks==1 and mjClicks==1 and settingsClicks==1,'Portrait buttons have distinct actions')
for _,clickFirst in ipairs({true,false}) do
 portrait.scripts.OnMouseDown(portrait,'LeftButton');portrait.scripts.OnDragStart()
 if clickFirst then portrait.scripts.OnClick(portrait,'LeftButton') end
 portrait.scripts.OnDragStop()
 if not clickFirst then portrait.scripts.OnClick(portrait,'LeftButton') end
 assert(groupClicks==1,'Drag release must never open allies')
end
portrait.scripts.OnMouseDown(portrait,'LeftButton');portrait.scripts.OnClick(portrait,'LeftButton')
assert(groupClicks==2,'A fresh click after dragging works')
assert(health.fields.cur.text=='100' and health.fields.max.text=='100' and health.fields.temp.text=='0')
local function edit(mode,value,blur)
 local field=health.fields[mode];field:SetFocus();field:SetText(value)
 if blur then field:ClearFocus() else field.scripts.OnEnterPressed(field) end
end
edit('temp','+25');assert(C:GetMyChar().hp.temp==25)
assert(health.fill.w==health.w,'Temporary points must not shrink the base gauge')
assert(health.temp.edges[1]:IsShown() and not health.temp.edges[3]:IsShown(),'Partial bonus grows around perimeter')
edit('temp','-5',true);assert(C:GetMyChar().hp.temp==20)
edit('cur','-30');assert(C:GetMyChar().hp.cur==90 and C:GetMyChar().hp.temp==0,'Damage consumes bonuses exactly once')
edit('max','80',true);assert(C:GetMyChar().hp.max==80 and C:GetMyChar().hp.cur==80)
edit('temp','12');assert(health.fields.temp.text=='12')
edit('temp','0');assert(health.fields.temp.text=='0' and not health.temp:IsShown())
edit('temp','999');assert(health.temp.edges[4]:IsShown() and health.fields.temp.text=='999','Large bonuses keep exact value with capped outline')
local last=health.temp.edges[#health.temp.edges]
assert(#health.temp.edges==24 and last:IsShown(),'Full outline includes all four rounded corners')
assert(math.abs(last.finish[3]-3)<.001 and math.abs(last.finish[4]-1)<.001,'Rounded perimeter closes at its starting point')
edit('temp','0')
edit('cur','0');assert(not health.fill:IsShown())
local field=health.fields.cur
field:SetFocus();field:SetText('45');field.scripts.OnEscapePressed(field);assert(C:GetMyChar().hp.cur==0 and field.text=='0')
edit('cur','invalid',true);assert(C:GetMyChar().hp.cur==0)
field:SetFocus();field:SetText('50');C:SetCur('hp',20);assert(field.text=='50','Network refresh preserves unfinished input')
field.scripts.OnEscapePressed(field);assert(field.text=='20','Cancel restores latest remote value')
assert(oldRefresh>0 and broadcasts>0)
CharacterDB.settings.resourceHUDEnabled=false;C:ApplyResourceHUD();assert(CharacterResourceHUD:IsShown())
C:DisableResourceHUD();C:ApplyResourceHUD();assert(not CharacterResourceHUD:IsShown())
C:EnableResourceHUD();assert(CharacterResourceHUD:IsShown())
shift=true;CharacterResourceHUD.scripts.OnDragStart();assert(CharacterResourceHUD.moving)
CharacterResourceHUD:SetPoint('CENTER',UIParent,'CENTER',123,-45)
CharacterResourceHUD.scripts.OnDragStop();C:ApplyResourceHUD();assert(CharacterResourceHUD.point[4]==123)
player='Other';C:ApplyResourceHUD();assert(CharacterResourceHUD.point[4]==-240,'Position is character-specific')
C:SetResourceHUDScale(9);assert(CharacterResourceHUD.scale==.85*1.6)
C:DisableResourceHUD();assert(not CharacterResourceHUD:IsShown())
print('OK: HUD initialization, resource synchronization, editing, bonus absorption, zero HP, lifecycle, scale, character-specific position')
`;
for(const file of ['Settings.lua','UI_HUD.lua','Core.lua']){
 const syntax=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:`assert(load([====[${fs.readFileSync(path.join(root,file),'utf8')} ]====]))`,encoding:'utf8'});
 if(syntax.stderr)throw Error(syntax.stderr);
}
const result=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:'local ok,err=pcall(function()\n'+test+'\nend)\nif not ok then print(err);os.exit(1) end',encoding:'utf8'});
process.stdout.write(result.stdout||'');process.stderr.write(result.stderr||'');process.exit(result.status||0);
