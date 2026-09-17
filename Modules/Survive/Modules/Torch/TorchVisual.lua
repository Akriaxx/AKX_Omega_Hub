-- Presentation only: the timer and inventory remain owned by Torch.lua.
local PATH="Interface\\AddOns\\Omega_Hub\\Modules\\Survive\\Modules\\Torch\\Media\\"
function OS2.CreateTorchVisual(parent)
    local f=CreateFrame("Frame",nil,parent)
    f:SetSize(200,300);f:EnableMouse(false)
    local function image(name,layer,w,h,x,y)
        local t=f:CreateTexture(nil,layer)
        t:SetTexture(PATH..name..".tga");t:SetSize(w,h)
        t:SetPoint("BOTTOM",f,"BOTTOM",x,y)
        return t
    end
    f.glow=image("glow","BACKGROUND",140,170,0,110)
    -- Behind the wick, then glowing fibres and tongues along both sides.
    f.fire=image("fire-flow","BORDER",100,150,0,142)
    f.handle=image("torch-painted","ARTWORK",80,160,0,28)
    f.ember=image("wick-ember","OVERLAY",80,52.5,0,135.5)
    f.left=image("fire-flow","OVERLAY",37,110,-10,142)
    f.right=image("fire-flow","OVERLAY",34,100,10,145)
    f.smokePuffs={}
    for i=1,9 do
        local puff=image("smoke-puff","OVERLAY",12,16,0,182)
        puff:ClearAllPoints();puff:SetPoint("CENTER",f,"BOTTOM",0,188)
        puff:SetAlpha(0);puff:Hide();f.smokePuffs[i]=puff
    end
    f.phase=0;f.ratio=0;f.heat=0;f.active=false;f.smokeTime=0
    for _,t in ipairs({f.fire,f.left,f.right,f.ember,f.glow}) do t:SetAlpha(0) end
    local function pose(texture,index)
        index=index%64
        local x,y=index%8,math.floor(index/8)
        texture:SetTexCoord((x*128+.5)/1024,((x+1)*128-.5)/1024,
            (y*128+.5)/1024,((y+1)*128-.5)/1024)
    end
    pose(f.fire,0);pose(f.left,21);pose(f.right,43)
    function f:SetState(ratio,active)
        self.ratio=math.max(0,math.min(1,ratio or 0))
        active=active and self.ratio>0 or false
        if self.active and not active then self.smokeTime=4 end
        if active and not self.active then
            self.smokeTime=0
            for _,puff in ipairs(self.smokePuffs) do puff:Hide() end
        end
        self.active=active
    end
    f:SetScript("OnUpdate",function(self,dt)
        if not self.active and self.heat==0 and self.smokeTime==0 then return end
        if self.fire.IsObjectLoaded and not self.fire:IsObjectLoaded() then return end
        dt=math.min(dt,.1);self.phase=(self.phase+dt)%100
        local target=self.active and (.06+.94*self.ratio^.7) or 0
        self.heat=self.heat+(target-self.heat)*(1-math.exp(-dt*5))
        if not self.active and self.heat<.001 then self.heat=0 end
        local t,h=self.phase,self.heat
        local pulse=.9+.06*math.sin(t*7.1)+.04*math.sin(t*12.3)
        local opacity=math.min(1,h*5)
        self.fire:SetSize(76+24*h,42+116*h)
        self.left:SetSize(26+11*h,34+84*h)
        self.right:SetSize(24+10*h,36+74*h)
        self.fire:SetAlpha(opacity)
        self.left:SetAlpha(opacity*.78);self.right:SetAlpha(opacity*.68)
        local index=math.floor(t*32)
        pose(self.fire,index);pose(self.left,index+21);pose(self.right,index+43)
        self.ember:SetAlpha(math.min(1,h*3)*pulse*.85)
        self.glow:SetAlpha(h*pulse*.8)
        self.smokeTime=math.max(0,self.smokeTime-dt)
        for i,puff in ipairs(self.smokePuffs) do
            local age=4-self.smokeTime-(i-1)*.13
            local life=2.25+(i%3)*.18
            local visible=self.smokeTime>0 and age>0 and age<life
            puff:SetShown(visible)
            if visible then
                local u=age/life
                local spread=10+34*u
                local drift=math.sin(age*1.8+i*.7)*u*12+u*u*9
                puff:SetSize(spread,spread*(1.2+.15*math.sin(i)))
                puff:SetPoint("CENTER",self,"BOTTOM",drift,188+age*23)
                puff:SetRotation(i*.8+age*(i%2==0 and .3 or -.25))
                puff:SetAlpha(math.min(1,age/.28)*(1-u)^1.6*.65)
            end
        end
    end)
    f:SetScript("OnHide",function(self)
        self.heat=0;self.smokeTime=0
        for _,texture in ipairs({self.fire,self.left,self.right,self.ember,self.glow}) do texture:SetAlpha(0) end
        for _,puff in ipairs(self.smokePuffs) do puff:SetAlpha(0);puff:Hide() end
    end)
    return f
end
