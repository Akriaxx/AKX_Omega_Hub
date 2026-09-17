-- Deux rendus du même mouvement : atlas BLP et primitives natives du client.
local J = Quest
local PATH = "Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Envelope\\atlas-"
local function Ease(t) t = math.max(0, math.min(1, t)); return t*t*(3-2*t) end
local function Color(hex)
    return { tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255, 1 }
end
local paper, edge, ink = Color("d9bc87"), Color("95703e"), Color("725635")

-- Les bandes de remplissage sont réutilisées ; aucune allocation par image
-- après la première ouverture. Chaque pièce possède sa propre profondeur.
local function Polygon(group, points, color)
    local low, high = 512, 0
    for _, p in ipairs(points) do low=math.min(low,p[2]); high=math.max(high,p[2]) end
    local used = 0
    for y=low,high-1,2 do
        local xs={}
        for i,a in ipairs(points) do
            local b=points[i % #points+1]
            if (a[2]<=y and b[2]>y) or (b[2]<=y and a[2]>y) then
                xs[#xs+1]=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
            end
        end
        table.sort(xs)
        if #xs>=2 and xs[#xs]>xs[1] then
            used=used+1
            local strip=group.strips[used]
            if not strip then strip=group:CreateTexture(nil,"ARTWORK"); group.strips[used]=strip end
            strip:SetPoint("TOPLEFT",xs[1]*.625,-y*.625)
            strip:SetSize((xs[#xs]-xs[1])*.625,math.min(2,high-y)*.625)
            strip:SetColorTexture(unpack(color)); strip:Show()
        end
    end
    for i=used+1,#group.strips do group.strips[i]:Hide() end
end
local function Line(group,index,x1,y1,x2,y2,color)
    local line=group.lines[index]
    if not line then line=group:CreateLine(nil,"OVERLAY"); group.lines[index]=line end
    line:SetThickness(1); line:SetColorTexture(unpack(color or edge))
    line:SetStartPoint("TOPLEFT",group,x1*.625,-y1*.625)
    line:SetEndPoint("TOPLEFT",group,x2*.625,-y2*.625)
    line:Show()
end
local function Outline(group,points)
    for i,a in ipairs(points) do local b=points[i % #points+1]; Line(group,i,a[1],a[2],b[1],b[2]) end
end
local function Shape(group,points,color) Polygon(group,points,color); Outline(group,points) end

function J:DrawEnvelope(t)
    local frame=self.letter
    if frame.backend=="blp" then
        local index=math.min(63,math.floor(t*63+.5))
        if frame.imageIndex~=index then
            local image=frame.images[math.floor(index/16)+1]
            if image.IsObjectLoaded and not image:IsObjectLoaded() then return false end
            frame.imageIndex=index
            if image~=frame.image then frame.image:Hide();frame.image=image end
            frame.image:Show()
            local tile=index%16; local x,y=tile%4,math.floor(tile/4)
            frame.image:SetTexCoord(x/4,(x+1)/4,y/4,(y+1)/4)
        end
        return
    end
    local g=frame.groups
    local flap=Ease((t-.04)/.30); local top=282-222*Ease((t-.30)/.30)
    local unfold=Ease((t-.63)/.37)
    local scale=-math.cos(unfold*math.pi)
    local envelope=1-Ease((t-.60)/.25)
    for _,i in ipairs({1,2,4,5,6,7}) do g[i]:SetAlpha(envelope) end
    local tip=270+116*math.cos(flap*math.pi)
    Shape(g[1],{{88,270},{424,270},{424,450},{88,450}},Color("73634b"))
    g[2]:SetShown(flap>.5); g[7]:SetShown(flap<=.5)
    Shape(flap>.5 and g[2] or g[7],{{88,270},{424,270},{256,tip}},Color("cbb080"))
    Shape(g[3],{{118,top},{394,top},{394,top+162},{118,top+162}},paper)
    for i=1,5 do Line(g[3],4+i,155,top+58+i*12,i==5 and 310 or 357,top+58+i*12,ink) end
    -- Oméga tracé, sans dépendre d'une police ou d'un caractère de remplacement.
    for i=1,24 do
        local a=(40+(i-1)*280/24)*math.pi/180; local b=(40+i*280/24)*math.pi/180
        Line(g[3],9+i,256+18*math.sin(a),top+25+18*math.cos(a),256+18*math.sin(b),top+25+18*math.cos(b),ink)
    end
    -- Deuxième moitié : rotation autour du pli central, verso puis recto.
    local hinge=top+162
    local bottom=hinge+162*scale
    Shape(g[9],{{118,hinge},{394,hinge},{394,bottom},{118,bottom}},Color("ceb07a"))
    for i=1,8 do
        if unfold>.5 then
            Line(g[9],4+i,149,hinge+(9+i*14)*scale,i==8 and 306 or 357,hinge+(9+i*14)*scale,ink)
        elseif g[9].lines[4+i] then g[9].lines[4+i]:Hide() end
    end
    -- Marques d'usure fixes et pli souligné, liés à la feuille.
    Line(g[3],34,120,top+162,392,top+162,edge)
    Line(g[3],35,122,top+6,122,top+153,edge)
    Line(g[9],13,389,hinge+8*scale,389,hinge+155*scale,edge)
    Shape(g[4],{{88,270},{273,373},{88,448}},Color("c6ab7a"))
    Shape(g[5],{{424,270},{239,373},{424,448}},Color("bba070"))
    Shape(g[6],{{88,448},{256,337},{424,448}},Color("b89b69"))
    g[8]:SetAlpha(1-Ease(t/.14))
    local circle={}
    for i=1,48 do local a=i*math.pi/24; circle[i]={256+28*math.cos(a),371+28*math.sin(a)} end
    Shape(g[8],circle,Color("25302b"))
    for i=1,24 do
        local a=(40+(i-1)*280/24)*math.pi/180; local b=(40+i*280/24)*math.pi/180
        Line(g[8],48+i,256+15*math.sin(a),369+15*math.cos(a),256+15*math.sin(b),369+15*math.cos(b),edge)
    end
end

function J:CreateEnvelope()
    if self.letter then return end
    local f=CreateFrame("Button","OmegaJournalEnvelope",UIParent,"BackdropTemplate")
    self.letter=f
    f:SetSize(360,380); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200); f:Hide()
    J.Style:Surface(f,false)
    local canvas=CreateFrame("Frame",nil,f); canvas:SetSize(320,320); canvas:SetPoint("TOPLEFT",20,12)
    f.images={}
    for i=1,4 do
        local image=canvas:CreateTexture(nil,"ARTWORK");image:SetAllPoints()
        image:SetTexture(PATH..i..".blp");image:Hide();f.images[i]=image
    end
    f.image=f.images[1]
    f.groups={}
    for i=1,9 do
        local g=CreateFrame("Frame",nil,canvas); g:SetAllPoints()
        g:SetFrameLevel(canvas:GetFrameLevel()+(i==9 and 4 or (i>=4 and i+1 or i))); g.strips={}; g.lines={}; f.groups[i]=g
    end
    f.heading=J.Style:Text(f,"Une lettre pour vous",17,24,-300,312)
    f.hint=J.Style:Text(f,"Cliquer pour briser le sceau",12,24,-332,312)
    local close=OS2.UI.CreateCloseButton(f,function() f:Hide() end)
    close:SetFrameLevel(canvas:GetFrameLevel()+12)
    f:SetScript("OnHide",function() f:SetScript("OnUpdate",nil); f.playing=false end)
    f:SetScript("OnClick",function()
        if f.playing then return end
        if not f.ready then self:AnimateEnvelope(); return end
    end)
end

function J:AnimateEnvelope()
    local f=self.letter
    f.elapsed=0; f.playing=true; f.ready=false;f.waitingForTextures=f.backend=="blp"
    if f.waitingForTextures then self:AnimationTexturesReady("envelope") end
    f.hint:SetText("Ouverture de la lettre…")
    f:SetScript("OnUpdate",function(_,dt)
        if f.backend=="blp" then
            local ready,failed=self:AnimationTexturesReady("envelope")
            if failed then
                f:SetScript("OnUpdate",nil);f.playing=false;f.ready=true;f:Hide()
                self:ShowLetterSheet(not f.demo and self.notices and self.notices[1] or nil,f.demo)
                return
            end
            if not ready then return end
            for _,image in ipairs(f.images) do
                if image.IsObjectLoaded and not image:IsObjectLoaded() then return end
            end
            if f.waitingForTextures then f.waitingForTextures=false;return end
        end
        f.elapsed=f.elapsed+math.min(dt,3.2/63)
        local t=math.min(1,f.elapsed/3.2)
        self:DrawEnvelope(t)
        if t==1 then
            f:SetScript("OnUpdate",nil); f.playing=false; f.ready=true
            f:Hide()
            self:ShowLetterSheet(not f.demo and self.notices and self.notices[1] or nil,f.demo)
        end
    end)
end

function J:ShowEnvelope(demo,backend)
    self:CreateEnvelope()
    if self.sheet then self.sheet:Hide() end
    local f=self.letter
    f:SetScript("OnUpdate",nil)
    f.demo=demo; f.backend=backend or OmegaHubDB.Quest_EnvelopeMode or "blp"
    f.ready=false; f.playing=false; f.imageIndex=nil
    for _,image in ipairs(f.images) do image:Hide() end
    for _,g in ipairs(f.groups) do g:SetShown(f.backend=="dessin") end
    f.heading:SetText(demo and ("Aperçu · "..(f.backend=="blp" and "BLP" or "Dessin Lua")) or "Une lettre pour vous")
    f.hint:SetText("Cliquer pour briser le sceau")
    self:DrawEnvelope(0); f:Show()
    if demo then self:AnimateEnvelope() end
end

function J:PreviewEnvelope(backend)
    if backend~="blp" and backend~="dessin" then return end
    OmegaHubDB.Quest_EnvelopeMode=backend
    self:ShowEnvelope(true,backend)
end
