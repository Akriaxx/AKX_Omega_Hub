-- Lanceur autonome : fengari Modules/Dice/Tests/BLP_test.lua
local now,frames,timers=0,{},{}
local methods={}
local noop=function() end
for _,k in ipairs({'SetSize','SetPoint','ClearAllPoints','SetFont','SetTextColor','SetScale','EnableMouse','SetAllPoints'}) do methods[k]=noop end
function methods:SetPoint(...) self.point={...} end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:SetScript(k,v) self[k]=v end
function methods:SetAlpha(v) self.alpha=v end
function methods:SetText(v) self.text=v end
function methods:GetStringHeight() return 30 end
function methods:SetTexture(v) self.path=v;self.loads=(self.loads or 0)+1 end
function methods:SetTexCoord(...)
    self.uv={...}
    if self.record then self.record[#self.record+1]=self.uv end
end
function methods:IsObjectLoaded() self.readyChecks=(self.readyChecks or 0)+1;return self.loaded~=false end
function CreateFrame()
    local f=setmetatable({shown=true},{__index=methods});frames[#frames+1]=f;return f
end
function methods:CreateTexture() return CreateFrame() end
function methods:CreateFontString() return CreateFrame() end
function methods:CreateLine() error('Le lecteur BLP ne doit pas créer de lignes') end
UIParent=CreateFrame();STANDARD_TEXT_FONT='font';GetTime=function() return now end
C_Timer={After=function(delay,fn) timers[#timers+1]={time=now+delay,fn=fn} end}
OmegaDice={Trim=function(s)return s or ''end,RollColor=function()return 1,1,1 end}
for _,k in ipairs({'GlowAttach','GlowColor','GlowShow','GlowHide','GlowSetAlpha'}) do OmegaDice[k]=noop end
OmegaDice.CreateGlow=function()return {}end
OmegaDice.FadeAlpha=function(obj,a,b,d,fn)obj:SetAlpha(b);if fn then fn() end end
OmegaDice.FadeGlow=function(obj,a,b,d,fn)if fn then fn() end end
local frame=CreateFrame()
for _,k in ipairs({'sumDisplay','modDisplay','topLabel','footer'}) do frame[k]=CreateFrame() end
frame.sumGlow={};OmegaDice.GetDiceFrame=function()return frame end
dofile(DICE_ANIMATION_TEST_PATH or 'Modules/Dice/UI/DiceAnimation.lua')
local function advance(seconds,step)
    step=step or .05
    for tick=1,math.floor(seconds/step+.5) do
        now=now+step
        for _,f in ipairs(frames) do if f.shown and f.OnUpdate then f.OnUpdate(f,step) end end
        local ready={}
        for i=#timers,1,-1 do if timers[i].time<=now then ready[#ready+1]=table.remove(timers,i).fn end end
        for _,fn in ipairs(ready) do fn() end
    end
end
for _,sides in ipairs({4,6,8,10,12,20,100}) do
    local calls=0
    OmegaDice.PlayBLPAnimation({sides=sides},{sides},sides,0,false,nil,'test',1,sides,function()calls=calls+1 end)
    advance(3)
    assert(calls==1 and frame.dice[1].result.text==tostring(sides))
    assert(frame.dice[1].image.path:find('d'..sides..'-face-'..sides..'-p3.blp',1,true))
    assert(frame.dice[1].image.uv[1]==7/8 and frame.dice[1].image.uv[3]==1/2 and frame.dice[1].image.uv[4]==1)
end
OmegaDice.PlayBLPAnimation({sides=6},{6},9,3,false,nil,'',1,6)
advance(6);assert(frame.dice[1].result.text=='9')
assert(frame.dice[1].result.point[5]==frame.resultY and frame.resultY<0)
OmegaDice.PlayBLPAnimation({sides=20},{2,5},7,0,true,{1,-2},'',1,20)
advance(6);assert(frame.dice[1].result.text=='3' and frame.dice[2].result.text=='3')
assert(frame.dice[1].result.point[5]==frame.resultY and frame.dice[2].result.point[5]==frame.resultY)
OmegaDice.PlayBLPAnimation({sides=8},{2,5},11,4,false,nil,'',1,8)
advance(9);assert(frame.sumDisplay.text=='11')
local stale=0
OmegaDice.PlayBLPAnimation({sides=4},{1},1,0,false,nil,'',1,4,function()stale=stale+1 end)
advance(.2)
OmegaDice.PlayWireframeAnimation({sides=6},{4},4,0,false,nil,'',1,6)
advance(3);assert(stale==0 and frame.dice[1].result.text=='4')
OmegaDice.ResetDiceFrame();assert(not frame.dice[1].image.shown)
for value=1,20 do
    OmegaDice.PlayBLPAnimation({sides=20},{value},value+3,3,false,nil,'',1,20)
    advance(3)
    assert(frame.dice[1].image==frame.dice[1].landImage)
    assert(frame.dice[1].image.path:find('d20-face-'..value..'-p3.blp',1,true))
    assert(frame.dice[1].rawResult==value)
end
OmegaDice.PlayBLPAnimation({sides=20},{12,3,19},34,0,true,{0,0,0},'',1,20)
advance(4)
for i,value in ipairs({12,3,19}) do assert(frame.dice[i].landPath:find('d20-face-'..value..'-p3.blp',1,true)) end
OmegaDice.ResetDiceFrame()
assert(not frame.dice[1].rollImage.shown and not frame.dice[1].middleImage.shown and not frame.dice[1].landImage.shown)
-- À 120 Hz, toutes les poses sont parcourues et aucune texture n'est rechargée.
OmegaDice.PlayBLPAnimation({sides=20},{12},12,0,false,nil,'',1,20)
local slot=frame.dice[1]
slot.rollImage.record={};slot.middleImage.record={};slot.landImage.record={}
local rollLoads,landLoads=slot.rollImage.loads,slot.landImage.loads
local middleLoads=slot.middleImage.loads
local readyChecks=(slot.rollImage.readyChecks or 0)+(slot.landImage.readyChecks or 0)+(slot.middleImage.readyChecks or 0)
advance(2.6,1/120)
assert(#slot.rollImage.record==64 and #slot.middleImage.record==64 and #slot.landImage.record==16)
assert(slot.rollImage.loads==rollLoads and slot.landImage.loads==landLoads and slot.middleImage.loads==middleLoads)
assert(slot.rollImage.readyChecks+slot.middleImage.readyChecks+slot.landImage.readyChecks==readyChecks+3)
assert(slot.imageIndex==143 and slot.image==slot.landImage)
slot.rollImage.record=nil;slot.middleImage.record=nil;slot.landImage.record=nil
-- Le deuxième dé suit la même cadence avec 0,4 s de retard, sans étirer ses poses.
OmegaDice.PlayBLPAnimation({sides=6},{2,4},6,0,true,{0,0},'',1,6)
frame.dice[1].motionPower=1;frame.dice[2].motionPower=1
advance(.4,1/120)
local firstIndex=frame.dice[1].imageIndex
assert(frame.dice[2].imageIndex==0)
advance(.4,1/120)
assert(math.abs(frame.dice[2].imageIndex-firstIndex)<=1)
OmegaDice.ResetDiceFrame()
-- Une texture lente à charger ne doit pas faire sauter le début de l'animation.
OmegaDice.PlayBLPAnimation({sides=20},{7},7,0,false,nil,'',1,20)
slot.middleImage.loaded=false
advance(.5,1/60)
assert(not slot.result.shown and slot.imageIndex==nil)
slot.middleImage.loaded=true
advance(.2,1/60)
assert(slot.image==slot.rollImage and slot.imageIndex<10)
advance(2.5,1/60)
assert(slot.imageIndex==143 and slot.result.text=='7')
OmegaDice.ResetDiceFrame()
-- Des variations de cadence indépendantes du résultat, sans répétition consécutive.
local previous={}
for attempt=1,12 do
    OmegaDice.PlayBLPAnimation({sides=20},{12,12,12},36,0,true,{0,0,0},'',1,20)
    for i=1,3 do
        local die=frame.dice[i]
        assert(die.rollVariant>=1 and die.rollVariant<=4)
        assert(die.rollVariant~=previous[i])
        if i>1 then assert(die.rollVariant~=frame.dice[i-1].rollVariant) end
        assert(die.rollPath:find('d20-face-12-p1.blp',1,true))
        assert(die.motionPower==({.94,.98,1.02,1.06})[die.rollVariant])
        assert(die.landPath:find('d20-face-12-p3.blp',1,true))
        previous[i]=die.rollVariant
    end
    OmegaDice.ResetDiceFrame()
end
print('OK : 7 modèles BLP, résultats, modificateurs, jets multiples, interruption, zéro ligne Lua')
