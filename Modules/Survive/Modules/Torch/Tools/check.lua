assert(loadfile("Modules/Survive/Modules/Torch/Torch.lua"))
OS2={}
local methods={}
function methods:SetScript(k,v) self[k]=v end
function methods:CreateTexture() return setmetatable({}, {__index=methods}) end
methods.CreateFontString=methods.CreateTexture
function methods:SetText(v) self.text=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetSize(w,h) assert(w>0 and h>0);self.width=w;self.height=h end
function methods:SetTexCoord(a,b,c,d) assert(a>=0 and b<=1 and c>=0 and d<=1);self.uv={a,b,c,d} end
for _,name in ipairs({"EnableMouse","SetTexture","SetPoint","SetTextColor","ClearAllPoints","SetRotation"}) do methods[name]=function() end end
function methods:SetShown(value) self.shown=value end
function methods:Hide() self.shown=false end
function CreateFrame() return setmetatable({}, {__index=methods}) end
dofile("Modules/Survive/Modules/Torch/TorchVisual.lua")
local f=OS2.CreateTorchVisual({})
assert(not f.timer)
local function run() for i=1,180 do f:OnUpdate(1/60) end end
f:SetState(1,true,120,false);run();local full=f.fire.height
f:SetState(.1,true,12,false);run();assert(f.fire.height<full*.6)
f:SetState(.1,true);run();assert(f.heat>0)
f:SetState(0,false,0,false);f:OnUpdate(.1)
assert(f.smokePuffs[1].shown and not f.smokePuffs[9].shown)
run();run();assert(f.heat<.001 and f.smokeTime==0)
for _,puff in ipairs(f.smokePuffs) do assert(not puff.shown) end
f:SetState(1,true,120,false);run();assert(f.fire.height>full*.95)
f:OnHide();assert(f.heat==0 and f.fire.alpha==0)
assert(f.left.alpha==0 and f.right.alpha==0 and f.ember.alpha==0)
f:SetState(1,true);run();f:SetState(0,false);f:OnUpdate(.1)
f:SetState(1,true);assert(f.smokeTime==0)
for _,puff in ipairs(f.smokePuffs) do assert(not puff.shown) end
print("OK: Lua syntax, fuel decrease, pause, extinction, recharge, hidden state")

-- Two views receive one authoritative reserve; hiding one cannot drain it.
local panelView,quickView=OS2.CreateTorchVisual({}),OS2.CreateTorchVisual({})
for _,ratio in ipairs({1,.5,.1,0}) do
    panelView:SetState(ratio,ratio>0);quickView:SetState(ratio,ratio>0)
    for i=1,180 do panelView:OnUpdate(1/60);quickView:OnUpdate(1/60) end
    assert(panelView.ratio==quickView.ratio and panelView.heat==quickView.heat)
    assert(panelView.fire.height==quickView.fire.height)
end
panelView:SetState(.5,true);quickView:SetState(.5,true)
panelView:OnHide();quickView:OnUpdate(.1)
assert(panelView.ratio==.5 and quickView.ratio==.5 and quickView.active)
print("OK: shared reserve, matching views, independent visibility")
