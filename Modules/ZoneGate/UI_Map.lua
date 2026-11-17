-- ============================================================
--  Crossings — Carte du pays et des régions (touche M)
--  La touche de la carte du jeu ouvre à la place la carte du pays
--  où l'on se trouve : toutes ses régions, une couleur chacune. Un
--  clic sur une région l'ouvre : ses lieux remplis de couleur, leurs
--  noms (« ????? » tant qu'on ne les connaît pas) et les passages
--  droits. Volontairement, rien n'indique où se trouve le joueur
--  sur la carte. Un bouton passe
--  à la carte du jeu, et un bouton sur la carte du jeu revient ici.
-- ============================================================
local ZG=ZoneGate
local UI=ZG.EditorUI or OS2.UI
local W,H,HEAD=960,660,56
local M=16
local CW,CH=W-2*M,H-HEAD-2*M-28
local MIN_SCALE,MAX_SCALE=.02,40
local function Me() return UnitName("player") or "" end

-- Couleurs des lieux : sobres, distinctes, stables pour un même lieu.
local PALETTE={
    {.45,.70,.40},{.75,.55,.30},{.40,.60,.80},{.70,.45,.65},
    {.80,.75,.40},{.40,.72,.68},{.78,.45,.40},{.55,.55,.80},
}
local function PlaceColor(id)
    local h=0
    for i=1,#(id or "") do h=(h*31+id:byte(i))%2147483647 end
    return PALETTE[h%#PALETTE+1]
end

local function PlaceKnown(place,zone) return zone.creator==Me() or ZG:KnowsPlaceName(place) end
local function ZoneKnown(zone) return zone.creator==Me() or ZG:HasLearnedZoneName(zone.id) end

-- ── Géométrie ────────────────────────────────────────────────────────────

local function Area(points)
    local a=0
    for i=1,#points do
        local p,q=points[i],points[i%#points+1]
        a=a+p.x*q.y-q.x*p.y
    end
    return a/2
end

local function InTriangle(p,a,b,c)
    local function side(u,v,w) return (v.x-u.x)*(w.y-u.y)-(v.y-u.y)*(w.x-u.x) end
    local d1,d2,d3=side(a,b,p),side(b,c,p),side(c,a,p)
    return d1>=0 and d2>=0 and d3>=0
end

-- Découpe en triangles par « oreilles » (contour simple). Gardée en cache :
-- un périmètre peut compter jusqu'à 1500 points.
local triCache=setmetatable({},{__mode="k"})
local function Triangulate(points)
    local n=#points
    local key=n..":"..(n>0 and (points[1].x..","..points[n].y) or "")
    local cached=triCache[points]
    if cached and cached.key==key then return cached.tris end
    local idx={}
    for i=1,n do idx[i]=i end
    if Area(points)<0 then
        local r={};for i=n,1,-1 do r[#r+1]=i end;idx=r
    end
    local tris={}
    local guard=0
    while #idx>3 and guard<n*n do
        guard=guard+1
        local found=false
        for i=1,#idx do
            local ia,ib,ic=idx[(i-2)%#idx+1],idx[i],idx[i%#idx+1]
            local a,b,c=points[ia],points[ib],points[ic]
            if (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x)>0 then
                local ear=true
                for _,j in ipairs(idx) do
                    if j~=ia and j~=ib and j~=ic and InTriangle(points[j],a,b,c) then ear=false;break end
                end
                if ear then tris[#tris+1]={ia,ib,ic};table.remove(idx,i);found=true;break end
            end
        end
        if not found then break end
    end
    if #idx==3 then tris[#tris+1]={idx[1],idx[2],idx[3]}
    elseif #idx>3 then
        -- Contour qui se croise : on termine en éventail plutôt que de ne rien remplir.
        for i=2,#idx-1 do tris[#tris+1]={idx[1],idx[i],idx[i+1]} end
    end
    triCache[points]={key=key,tris=tris}
    return tris
end

local function IsClosed(sub) return sub.shape=="polygon" and sub.regionReady and sub.points and #sub.points>=3 end

local function PointInPolygon(points,x,y)
    local inside,j=false,#points
    for i=1,#points do
        local a,b=points[i],points[j]
        if (a.y>y)~=(b.y>y) and x<(b.x-a.x)*(y-a.y)/(b.y-a.y)+a.x then inside=not inside end
        j=i
    end
    return inside
end

local function LineEnds(sub)
    local a=sub.facing or 0;local r=(sub.width or 6)/2
    return {x=sub.x-math.cos(a)*r,y=sub.y+math.sin(a)*r},{x=sub.x+math.cos(a)*r,y=sub.y-math.sin(a)*r}
end

-- Région où se trouve le joueur : celle du lieu où il est, sinon celle dont
-- un périmètre le contient, sinon celle du passage le plus proche (même carte).
function ZG:CurrentRegion()
    local px,py,_,map=ZG:GetPlayerPose()
    if not px then return nil end
    for _,subId in pairs(ZG.here or {}) do
        local sub,zone=ZG:FindSubZone(subId)
        if sub and zone and sub.mapID==map then return zone end
    end
    local best,bestDist
    for _,zone in ipairs(ZG:GetZoneList()) do
        for _,sub in pairs(zone.subZones or {}) do
            if sub.mapID==map then
                if IsClosed(sub) and PointInPolygon(sub.points,px,py) then return zone end
                local d=math.sqrt(((sub.x or 0)-px)^2+((sub.y or 0)-py)^2)
                if not bestDist or d<bestDist then best,bestDist=zone,d end
            end
        end
    end
    return best
end

-- ── Fenêtre ──────────────────────────────────────────────────────────────

-- Régions sans pays : regroupées sous « Sans pays ».
local NONE="__none"
local function CountryName(key)
    local c=key and key~=NONE and ZG:GetCountry(key)
    return c and c.name or "Sans pays"
end

local win
local function Build()
    win=CreateFrame("Frame","ZoneGateRegionMap",UIParent)
    win:SetSize(W,H);win:SetPoint("CENTER");win:SetFrameStrata("HIGH")
    win:EnableMouse(true);win:SetClampedToScreen(true);win:SetMovable(true)
    UI.Surface(win);win:Hide()
    if win.surfaceBg then UI.ApplyWindowBackground(win.surfaceBg,1) end

    local head=CreateFrame("Frame",nil,win)
    head:SetPoint("TOPLEFT",1,-1);head:SetPoint("TOPRIGHT",-1,-1);head:SetHeight(HEAD)
    head:EnableMouse(true);head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart",function() win:StartMoving() end)
    head:SetScript("OnDragStop",function() win:StopMovingOrSizing() end)
    local headBg=head:CreateTexture(nil,"BACKGROUND");headBg:SetAllPoints();UI.ApplyWindowBackground(headBg,.70)
    local accent=head:CreateTexture(nil,"ARTWORK");accent:SetWidth(3)
    accent:SetPoint("TOPLEFT");accent:SetPoint("BOTTOMLEFT");accent:SetColorTexture(unpack(UI.colors.tabLine))
    win.title=head:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    win.title:SetPoint("TOPLEFT",16,-9);win.title:SetWidth(W-680);win.title:SetJustifyH("LEFT");UI.ApplyTitle(win.title)
    win.subtitle=head:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    win.subtitle:SetPoint("TOPLEFT",16,-33);win.subtitle:SetWidth(W-680);win.subtitle:SetJustifyH("LEFT");UI.ApplyMutedText(win.subtitle)
    UI.CreateCloseButton(head,function() win:Hide() end)
    local gameMap=UI.CreatePanelButton(head,130,24,"Carte du jeu")
    gameMap:SetPoint("RIGHT",head,"RIGHT",-34,0)
    gameMap:SetScript("OnClick",function() ZG:ShowGameMap() end)
    local fit=UI.CreatePanelButton(head,130,24,"Vue d'ensemble")
    fit:SetPoint("RIGHT",gameMap,"LEFT",-10,0)
    fit:SetScript("OnClick",function() win:Fit();win:Draw() end)

    -- Deux niveaux : le pays (toutes ses régions) puis, d'un clic, une région
    -- (tous ses lieux). M ouvre le pays où l'on se trouve et le suit ;
    -- choisir un pays ou une région arrête de suivre le joueur.
    local picker=UI.CreateSelect(head,190,24)
    picker:SetPoint("RIGHT",fit,"LEFT",-10,0)
    win.picker=picker
    picker.items=function()
        local seen,list={},{}
        for _,zone in ipairs(ZG:GetZoneList()) do
            if next(zone.subZones or {}) then
                local key=zone.countryId or NONE
                if not seen[key] then seen[key]=true;list[#list+1]={value=key,text=CountryName(key)} end
            end
        end
        table.sort(list,function(a,b)
            if (a.value==NONE)~=(b.value==NONE) then return b.value==NONE end
            return a.text<b.text
        end)
        return list
    end
    -- Le pays où l'on se trouve reprend le suivi du joueur.
    function win:OpenCountry(key)
        local here=ZG:CurrentRegion()
        if here and (here.countryId or NONE)==key then self:ShowCurrent() else self:ShowCountry(key) end
    end
    picker.onSelect=function(key) win:OpenCountry(key) end

    -- Pays (clé du pays, ou NONE pour les régions sans pays).
    function win:ShowCountry(key,follow)
        self.level,self.country,self.zone,self.follow="country",key,nil,follow and true or false
        picker:SetText(CountryName(key))
        self:Fit();self:Draw()
    end
    function win:ShowRegion(zone)
        if not zone then return end
        self.level,self.country,self.zone,self.follow="region",zone.countryId or NONE,zone,false
        picker:SetText(CountryName(self.country))
        self:Fit();self:Draw()
    end
    function win:ShowCurrent()
        local zone=ZG:CurrentRegion()
        self.here=zone
        if zone then self:ShowCountry(zone.countryId or NONE,true)
        else self.level,self.country,self.zone,self.follow="country",nil,nil,true;picker:SetText("Aucun pays");self:Draw() end
    end

    -- Fond dessiné : sombre, légèrement chaud, avec un quadrillage discret.
    local canvas=CreateFrame("Frame",nil,win)
    canvas:SetPoint("TOPLEFT",M,-(HEAD+M));canvas:SetSize(CW,CH)
    local bg=canvas:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.055,.060,.058,1)
    if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
    local grid=CreateFrame("Frame",nil,canvas);grid:SetAllPoints()
    for i=1,math.floor(CW/60) do
        local t=grid:CreateTexture(nil,"BORDER");t:SetColorTexture(1,1,1,.025);t:SetWidth(1)
        t:SetPoint("TOPLEFT",i*60,0);t:SetPoint("BOTTOMLEFT",i*60,0)
    end
    for i=1,math.floor(CH/60) do
        local t=grid:CreateTexture(nil,"BORDER");t:SetColorTexture(1,1,1,.025);t:SetHeight(1)
        t:SetPoint("TOPLEFT",0,-i*60);t:SetPoint("TOPRIGHT",0,-i*60)
    end
    local fills=CreateFrame("Frame",nil,canvas);fills:SetAllPoints();fills:SetFrameLevel(canvas:GetFrameLevel()+2)
    local lines=CreateFrame("Frame",nil,canvas);lines:SetAllPoints();lines:SetFrameLevel(canvas:GetFrameLevel()+3)
    local labels=CreateFrame("Frame",nil,canvas);labels:SetAllPoints();labels:SetFrameLevel(canvas:GetFrameLevel()+4)
    -- Remplissage possible seulement si le jeu sait déformer une texture.
    local probe=fills:CreateTexture(nil,"ARTWORK");probe:Hide()
    local CAN_FILL=probe.SetVertexOffset~=nil
    win.canvas=canvas
    win.empty=labels:CreateFontString(nil,"OVERLAY","GameFontNormal")
    win.empty:SetPoint("CENTER");win.empty:SetWidth(CW-80);UI.ApplyMutedText(win.empty)
    local help=win:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    help:SetPoint("BOTTOMRIGHT",-M,12);help:SetJustifyH("RIGHT");UI.ApplyMutedText(help)
    win.help=help

    -- Réserves de textures et de textes, réutilisées d'un dessin à l'autre.
    local triPool,linePool,labelPool={}, {}, {}
    local usedTri,usedLine,usedLabel=0,0,0
    local function Tri(a,b,c,color)
        usedTri=usedTri+1
        local t=triPool[usedTri]
        if not t then t=fills:CreateTexture(nil,"ARTWORK");triPool[usedTri]=t end
        local minx,maxx=math.min(a[1],b[1],c[1]),math.max(a[1],b[1],c[1])
        local miny,maxy=math.min(a[2],b[2],c[2]),math.max(a[2],b[2],c[2])
        local w,h=math.max(1,maxx-minx),math.max(1,maxy-miny)
        t:ClearAllPoints();t:SetPoint("TOPLEFT",canvas,"TOPLEFT",minx,-miny);t:SetSize(w,h)
        t:SetColorTexture(color[1],color[2],color[3],.28)
        -- Coins du carré déplacés sur le triangle : haut-gauche, bas-gauche, haut-droit, bas-droit.
        t:SetVertexOffset(1,a[1]-minx,-(a[2]-miny))
        t:SetVertexOffset(2,b[1]-minx,-(b[2]-(miny+h)))
        t:SetVertexOffset(3,c[1]-(minx+w),-(c[2]-miny))
        t:SetVertexOffset(4,c[1]-(minx+w),-(c[2]-(miny+h)))
        t:Show()
    end
    local function Line(x1,y1,x2,y2,color,width,alpha)
        local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
        if length<.5 then return end
        if (x1<0 and x2<0) or (x1>CW and x2>CW) or (y1<0 and y2<0) or (y1>CH and y2>CH) then return end
        usedLine=usedLine+1
        local t=linePool[usedLine]
        if not t then t=lines:CreateTexture(nil,"ARTWORK");linePool[usedLine]=t end
        t:ClearAllPoints();t:SetPoint("CENTER",canvas,"TOPLEFT",(x1+x2)/2,-(y1+y2)/2)
        t:SetSize(length,width or 2);t:SetRotation(math.atan2(-dy,dx))
        t:SetColorTexture(color[1],color[2],color[3],alpha or .95);t:Show()
    end
    local function Text(x,y,text,color,big)
        usedLabel=usedLabel+1
        local f=labelPool[usedLabel]
        if not f then f=labels:CreateFontString(nil,"OVERLAY","GameFontNormal");f:SetShadowColor(0,0,0,1);f:SetShadowOffset(1,-1);labelPool[usedLabel]=f end
        f:SetFontObject(big and "GameFontNormalLarge" or "GameFontNormal")
        f:ClearAllPoints();f:SetPoint("CENTER",canvas,"TOPLEFT",x,-y)
        f:SetText(text);f:SetTextColor(color[1],color[2],color[3],1);f:Show()
    end

    -- Monde → cadre : nord en haut, est à droite (voir ZG:PlacementOffset).
    function win:ToScreen(x,y)
        return CW/2+(self.cx-x)*self.scale,CH/2-(y-self.cy)*self.scale
    end
    -- Régions affichées : la région ouverte, ou toutes celles du pays.
    function win:Zones()
        if self.level=="region" then return {self.zone} end
        local list={}
        if self.country==nil then return list end
        for _,zone in ipairs(ZG:GetZoneList()) do
            if (zone.countryId or NONE)==self.country then list[#list+1]=zone end
        end
        return list
    end
    -- Carte (instance) affichée : celle du joueur si ces régions y ont des
    -- passages, sinon celle où elles en ont le plus.
    function win:Map(zones)
        local _,_,_,map=ZG:GetPlayerPose()
        local counts,best={},nil
        for _,zone in ipairs(zones) do
            for _,sub in pairs(zone.subZones or {}) do
                if sub.mapID==map then return map end
                if sub.mapID then counts[sub.mapID]=(counts[sub.mapID] or 0)+1 end
            end
        end
        for id,n in pairs(counts) do if not best or n>counts[best] then best=id end end
        return best or map
    end
    -- Passages visibles, chacun avec sa région : { {sub=, zone=} }.
    function win:Subs()
        local zones=self:Zones()
        local map=self:Map(zones)
        local list={}
        for _,zone in ipairs(zones) do
            for _,sub in pairs(zone.subZones or {}) do
                if sub.mapID==map and sub.enabled~=false then list[#list+1]={sub=sub,zone=zone} end
            end
        end
        table.sort(list,function(a,b) return a.sub.id<b.sub.id end)
        return list
    end
    function win:Fit()
        local minx,maxx,miny,maxy
        local function add(p)
            minx=math.min(minx or p.x,p.x);maxx=math.max(maxx or p.x,p.x)
            miny=math.min(miny or p.y,p.y);maxy=math.max(maxy or p.y,p.y)
        end
        for _,e in ipairs(self:Subs()) do
            local sub=e.sub
            if sub.shape=="polygon" then for _,p in ipairs(sub.points or {}) do add(p) end
            else local a,b=LineEnds(sub);add(a);add(b) end
        end
        if not minx then self.cx,self.cy,self.scale=0,0,self.scale or 2;return end
        self.cx,self.cy=(minx+maxx)/2,(miny+maxy)/2
        local w,h=math.max(20,maxx-minx),math.max(20,maxy-miny)
        self.scale=math.max(MIN_SCALE,math.min(MAX_SCALE,math.min((CW-80)/w,(CH-80)/h)))
    end
    -- Polygone fermé : rempli, contour, et boîte englobante (écran) pour l'étiquette.
    local function DrawPolygon(self,sub,color,outlineAlpha,box)
        local screen={}
        for i,p in ipairs(sub.points) do
            local x,y=self:ToScreen(p.x,p.y);screen[i]={x,y}
            if box then
                box.minx=math.min(box.minx or x,x);box.maxx=math.max(box.maxx or x,x)
                box.miny=math.min(box.miny or y,y);box.maxy=math.max(box.maxy or y,y)
            end
        end
        if IsClosed(sub) and CAN_FILL then
            for _,t in ipairs(Triangulate(sub.points)) do Tri(screen[t[1]],screen[t[2]],screen[t[3]],color) end
        end
        for i=2,#screen do Line(screen[i-1][1],screen[i-1][2],screen[i][1],screen[i][2],color,2,outlineAlpha) end
        if IsClosed(sub) then Line(screen[#screen][1],screen[#screen][2],screen[1][1],screen[1][2],color,2,outlineAlpha) end
        return screen
    end
    local function Light(c) return {math.min(1,c[1]+.35),math.min(1,c[2]+.35),math.min(1,c[3]+.35)} end

    function win:Draw()
        for i=1,usedTri do triPool[i]:Hide() end
        for i=1,usedLine do linePool[i]:Hide() end
        for i=1,usedLabel do labelPool[i]:Hide() end
        usedTri,usedLine,usedLabel=0,0,0
        self.help:SetText(self.level=="region" and "Clic droit : retour au pays · Molette : zoom · Glisser : déplacer" or "Clic : ouvrir une région · Molette : zoom · Glisser : déplacer")
        local subs=self:Subs()
        if self.country==nil or #subs==0 then
            self.title:SetText(self.country and CountryName(self.country) or "Carte")
            self.subtitle:SetText("")
            self.empty:SetText(self.country and "Rien à afficher sur cette carte." or "Aucune région Crossings ici.\nChoisissez un pays dans le menu, ou « Carte du jeu » pour la carte habituelle.")
            self.empty:Show()
            return
        end
        self.empty:Hide()

        if self.level=="country" then
            self.title:SetText(CountryName(self.country))
            self.subtitle:SetText("Pays · cliquez sur une région")
            -- Une couleur par région ; les lieux n'ont qu'un contour discret.
            local boxes={}
            for _,e in ipairs(subs) do
                if IsClosed(e.sub) then
                    local box=boxes[e.zone.id] or {zone=e.zone}
                    boxes[e.zone.id]=box
                    DrawPolygon(self,e.sub,PlaceColor(e.zone.id),.45,box)
                end
            end
            for _,box in pairs(boxes) do
                local x,y=(box.minx+box.maxx)/2,(box.miny+box.maxy)/2
                if x>-60 and x<CW+60 and y>-20 and y<CH+20 then
                    Text(x,y,ZoneKnown(box.zone) and (box.zone.name or "") or ZG:MaskText(box.zone.name or ""),Light(PlaceColor(box.zone.id)),true)
                end
            end
        else
            local zone=self.zone
            self.title:SetText(ZoneKnown(zone) and (zone.name or "") or ZG:MaskText(zone.name or ""))
            self.subtitle:SetText("Région · "..CountryName(self.country))
            local placeLabel={}
            for _,e in ipairs(subs) do
                local sub=e.sub
                local place=sub.enterPlace and ZG:FindPlace(sub.enterPlace)
                local color=place and PlaceColor(place.id) or {.6,.6,.6}
                if sub.shape=="polygon" and sub.points and #sub.points>=2 then
                    local screen=DrawPolygon(self,sub,color,.95)
                    if place and IsClosed(sub) then
                        -- Le nom se place au centre du plus grand périmètre du lieu.
                        local area=math.abs(Area(sub.points))
                        if not placeLabel[place.id] or area>placeLabel[place.id].area then
                            local sx,sy=0,0
                            for _,p in ipairs(screen) do sx,sy=sx+p[1],sy+p[2] end
                            placeLabel[place.id]={x=sx/#screen,y=sy/#screen,area=area,place=place,color=color}
                        end
                    end
                elseif sub.shape~="polygon" then
                    local a,b=LineEnds(sub)
                    local x1,y1=self:ToScreen(a.x,a.y);local x2,y2=self:ToScreen(b.x,b.y)
                    Line(x1,y1,x2,y2,color,4)
                    if place and not placeLabel[place.id] then
                        placeLabel[place.id]={x=(x1+x2)/2,y=(y1+y2)/2-14,area=0,place=place,color=color}
                    end
                end
            end
            for _,l in pairs(placeLabel) do
                if l.x>-40 and l.x<CW+40 and l.y>-20 and l.y<CH+20 then
                    local name=PlaceKnown(l.place,zone) and (l.place.name or "") or ZG:MaskText(l.place.name or "")
                    Text(l.x,l.y,name,Light(l.color),l.area>0)
                end
            end
        end
    end

    -- Région sous un point de l'écran (vue du pays), ou nil.
    function win:RegionAt(ox,oy)
        local wx=self.cx-(ox-CW/2)/self.scale
        local wy=self.cy-(oy-CH/2)/self.scale
        for _,e in ipairs(self:Subs()) do
            if IsClosed(e.sub) and PointInPolygon(e.sub.points,wx,wy) then return e.zone end
        end
    end


    -- Molette : zoom autour du curseur ; glisser : déplacer la vue.
    canvas:EnableMouse(true);canvas:EnableMouseWheel(true)
    canvas:SetScript("OnMouseWheel",function(_,delta)
        local factor=delta>0 and 1.25 or 1/1.25
        local s=math.max(MIN_SCALE,math.min(MAX_SCALE,win.scale*factor))
        local mx,my=GetCursorPosition();local es=canvas:GetEffectiveScale()
        local left,top=canvas:GetLeft(),canvas:GetTop()
        if left and top then
            local ox,oy=mx/es-left,top-my/es
            -- Le point sous le curseur reste sous le curseur.
            local wx=win.cx-(ox-CW/2)/win.scale;local wy=win.cy-(oy-CH/2)/win.scale
            win.scale=s
            win.cx=wx+(ox-CW/2)/s;win.cy=wy+(oy-CH/2)/s
        else
            win.scale=s
        end
        win:Draw()
    end)
    canvas:SetScript("OnMouseDown",function(_,button)
        if button~="LeftButton" then return end
        local mx,my=GetCursorPosition()
        win.drag={mx=mx,my=my,cx=win.cx,cy=win.cy}
    end)
    -- Un clic sans glisser, dans la vue du pays, ouvre la région cliquée ;
    -- un clic droit dans une région revient à son pays.
    canvas:SetScript("OnMouseUp",function(_,button)
        if button=="RightButton" then
            if win.level=="region" then win:OpenCountry(win.country) end
            return
        end
        local drag=win.drag;win.drag=nil
        if button~="LeftButton" or not drag or win.level~="country" then return end
        local mx,my=GetCursorPosition()
        if math.abs(mx-drag.mx)+math.abs(my-drag.my)>4 then return end
        local es=canvas:GetEffectiveScale();local left,top=canvas:GetLeft(),canvas:GetTop()
        if not left or not top then return end
        local zone=win:RegionAt(mx/es-left,top-my/es)
        if zone then win:ShowRegion(zone) end
    end)

    local regionCheck=0
    win:SetScript("OnUpdate",function(self,dt)
        if self.drag then
            local mx,my=GetCursorPosition();local es=canvas:GetEffectiveScale()
            self.cx=self.drag.cx+(mx-self.drag.mx)/es/self.scale
            self.cy=self.drag.cy-(my-self.drag.my)/es/self.scale
            self:Draw();return
        end
        regionCheck=regionCheck+dt
        -- Pays où se trouve le joueur : la carte le suit quand il en change.
        if regionCheck>=1 and self.follow then
            regionCheck=0
            local zone=ZG:CurrentRegion()
            if zone~=self.here then self:ShowCurrent() end
        end
    end)
    -- M rouvre toujours le pays où l'on se trouve.
    win:SetScript("OnShow",function(self) self:ShowCurrent() end)
    UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"ZoneGateRegionMap")
end

function ZG:ShowRegionMap()
    if not win then Build() end
    if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame) end
    win:Show()
end

function ZG:ShowGameMap()
    if win then win:Hide() end
    if WorldMapFrame and WorldMapFrame:IsShown() then return end
    if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then ShowUIPanel(WorldMapFrame) end
end

-- Touche M (ou celle de la carte du jeu) : bascule la carte de région ;
-- carte du jeu ouverte, elle la ferme comme d'habitude.
function ZG:ToggleRegionMap()
    if WorldMapFrame and WorldMapFrame:IsShown() then HideUIPanel(WorldMapFrame);return end
    if win and win:IsShown() then win:Hide() else ZG:ShowRegionMap() end
end

-- ── Raccourci ───────────────────────────────────────────────────────────
-- Surcharge des touches de la carte du jeu (impossible en combat : on
-- attend la fin du combat). Les raccourcis du joueur ne sont pas modifiés.
local toggle=CreateFrame("Button","ZoneGateMapToggle",UIParent)
toggle:SetScript("OnClick",function() ZG:ToggleRegionMap() end)
local binder=CreateFrame("Frame")
local bound,applied=false,nil
-- Ne refait la surcharge que si les touches voulues ont changé : poser une
-- surcharge déclenche lui-même UPDATE_BINDINGS.
local function Bind()
    local keys=bound and table.concat({GetBindingKey("TOGGLEWORLDMAP")},",") or ""
    if keys==applied then return end
    if InCombatLockdown and InCombatLockdown() then binder:RegisterEvent("PLAYER_REGEN_ENABLED");return end
    applied=keys
    ClearOverrideBindings(binder)
    if not bound then return end
    for _,key in ipairs({GetBindingKey("TOGGLEWORLDMAP")}) do
        SetOverrideBindingClick(binder,true,key,"ZoneGateMapToggle")
    end
end
binder:SetScript("OnEvent",function(self,event)
    if event=="PLAYER_REGEN_ENABLED" then self:UnregisterEvent("PLAYER_REGEN_ENABLED") end
    Bind()
end)
binder:RegisterEvent("UPDATE_BINDINGS")

function ZG:BindMapKey() bound=true;Bind();if ZG.worldMapButton then ZG.worldMapButton:Show() end end
function ZG:UnbindMapKey()
    bound=false;Bind()
    if win then win:Hide() end
    if ZG.worldMapButton then ZG.worldMapButton:Hide() end
end

-- Bouton « Carte de région » sur la carte du jeu.
local function AttachWorldMapButton()
    if not WorldMapFrame or ZG.worldMapButton then return end
    local b=UI.CreatePanelButton(WorldMapFrame,150,24,"Carte de région")
    local anchor=WorldMapFrame.ScrollContainer or WorldMapFrame
    b:SetPoint("TOPLEFT",anchor,"TOPLEFT",10,-10)
    b:SetFrameStrata("HIGH");b:SetFrameLevel((WorldMapFrame:GetFrameLevel() or 1)+50)
    b:SetScript("OnClick",function() ZG:ShowRegionMap() end)
    b:SetShown(bound)
    WorldMapFrame:HookScript("OnShow",function() b:SetShown(bound) end)
    ZG.worldMapButton=b
end
local loader=CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent",function(_,event,name)
    if event=="PLAYER_LOGIN" or name=="Blizzard_WorldMap" then AttachWorldMapButton() end
end)
