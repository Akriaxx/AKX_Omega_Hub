-- Player-centred crossing assistant, with the player always facing up.
local ZG=ZoneGate
local UI=ZG.EditorUI or OS2.UI
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function segment(px,py,a,b)
    local dx,dy=b.x-a.x,b.y-a.y
    local len=dx*dx+dy*dy
    local t=len>0 and clamp(((px-a.x)*dx+(py-a.y)*dy)/len,0,1) or 0
    return math.sqrt((px-a.x-t*dx)^2+(py-a.y-t*dy)^2)
end
-- Stored coordinates: x is west, y is north (GetPlayerPose swaps UnitPosition).
-- Guide towards the closest reachable point on the actual boundary.
function ZG:PlacementTarget(cp,px,py,facing)
    local tx,ty=cp.x,cp.y
    local best=math.huge
    local function edge(a,b)
        local dx,dy=b.x-a.x,b.y-a.y
        local len=dx*dx+dy*dy
        local t=len>0 and clamp(((px-a.x)*dx+(py-a.y)*dy)/len,0,1) or 0
        local x,y=a.x+t*dx,a.y+t*dy
        local d=(px-x)^2+(py-y)^2
        if d<best then best=d;tx,ty=x,y end
    end
    if cp.shape=="polygon" then
        local pts=cp.points or {}
        if #pts>0 then tx,ty=pts[1].x,pts[1].y end
        for i=2,#pts do edge(pts[i-1],pts[i]) end
        if cp.regionReady and #pts>=3 then edge(pts[#pts],pts[1]) end
    elseif cp.shape=="circle" then
        local dx,dy=px-cp.x,py-cp.y
        local d=math.sqrt(dx*dx+dy*dy)
        if d<.001 then dx,dy,d=math.sin(facing or 0),math.cos(facing or 0),1 end
        tx,ty=cp.x+dx/d*(cp.width or 6),cp.y+dy/d*(cp.width or 6)
    else
        local a,r=cp.facing or 0,(cp.width or 6)/2
        edge({x=cp.x-math.cos(a)*r,y=cp.y+math.sin(a)*r},
             {x=cp.x+math.cos(a)*r,y=cp.y-math.sin(a)*r})
    end
    local dx,dy=tx-px,ty-py
    local distance=math.sqrt(dx*dx+dy*dy)
    local angle=math.atan2(dx,dy)-(facing or 0)
    angle=(angle+math.pi)%(2*math.pi)-math.pi
    local instruction
    if distance<1 then instruction="Passage atteint"
    elseif math.abs(angle)<.22 then instruction="Tout droit"
    elseif math.abs(angle)>2.6 then instruction="Faites demi-tour"
    elseif angle>0 then instruction="Tournez à gauche"
    else instruction="Tournez à droite" end
    return {x=tx,y=ty,distance=distance,angle=angle,instruction=instruction}
end
function ZG:PlacementReadout(cp,px,py,facing,mapID)
    if not cp then return {unavailable="Sélectionnez un checkpoint."} end
    if not px or not py then return {unavailable="Position indisponible."} end
    if cp.mapID~=mapID then return {unavailable="Checkpoint dans une autre instance."} end
    local signed,distance,lateral,heading
    if cp.shape=="polygon" then
        local points=cp.points or {}
        if #points<3 or not cp.regionReady then
            return {unavailable=string.format("Contour en cours : %d point(s).",#points),hint="Ajoutez au moins trois points, puis validez le périmètre."}
        end
        local inside=false;distance=math.huge
        local j=#points
        for i,p in ipairs(points) do
            local q=points[j]
            if (p.y>py)~=(q.y>py) and px<(q.x-p.x)*(py-p.y)/(q.y-p.y)+p.x then inside=not inside end
            distance=math.min(distance,segment(px,py,q,p));j=i
        end
        signed=inside and distance or -distance
    elseif cp.shape=="circle" then
        signed=(cp.width or 6)-math.sqrt((px-cp.x)^2+(py-cp.y)^2)
        distance=math.abs(signed)
    else
        local angle=cp.facing or 0
        local fx,fy=math.sin(angle),math.cos(angle)
        local dx,dy=px-cp.x,py-cp.y
        signed=dx*fx+dy*fy
        lateral=math.max(0,math.abs(-dx*fy+dy*fx)-(cp.width or 6)/2)
        distance=math.sqrt(signed*signed+lateral*lateral)
        heading=math.cos((facing or angle)-angle)
    end
    local line=cp.shape~="circle" and cp.shape~="polygon"
    local status,hint
    if line and lateral>1 then
        status="Décalé du passage"
        hint=string.format("Rejoignez le passage : %.1f yd de décalage latéral.",lateral)
    elseif math.abs(signed)<1 then
        status="Sur la limite";hint="Éloignez-vous d'un côté, puis traversez pour tester."
    elseif signed<0 then
        status=line and "Côté départ" or "À l'extérieur"
        hint=line and (heading>.25 and "Avancez à travers le passage pour entrer." or "Orientez-vous vers le passage pour entrer.") or "Franchissez le contour vers l'intérieur pour entrer."
    else
        status=line and "Côté arrivée" or "À l'intérieur"
        hint=line and (heading<-.25 and "Avancez à travers le passage pour sortir." or "Faites demi-tour et retraversez pour sortir.") or "Franchissez le contour vers l'extérieur pour sortir."
    end
    if cp.enabled==false then status="Checkpoint désactivé";hint="Activez-le pour déclencher ses effets au passage." end
    return {signed=signed,distance=distance,lateral=lateral,status=status,hint=hint,line=line}
end
-- Project world offsets onto the player's right/forward axes.
function ZG:PlacementOffset(dx,dy,facing)
    local c,s=math.cos(facing or 0),math.sin(facing or 0)
    return -dx*c+dy*s,dx*s+dy*c
end
-- Fit a circle around the player so turning never changes the zoom or clips the contour.
function ZG:PlacementGeometry(cp,px,py)
    local points={}
    if cp.shape=="polygon" then
        for _,p in ipairs(cp.points or {}) do points[#points+1]={x=p.x,y=p.y} end
    elseif cp.shape=="circle" then
        for i=0,47 do local a=i*math.pi/24;points[#points+1]={x=cp.x+math.cos(a)*(cp.width or 6),y=cp.y+math.sin(a)*(cp.width or 6)} end
    else
        local a=cp.facing or 0;local r=(cp.width or 6)/2
        points={{x=cp.x-math.cos(a)*r,y=cp.y+math.sin(a)*r},{x=cp.x+math.cos(a)*r,y=cp.y-math.sin(a)*r}}
    end
    local cx,cy=px,py
    local reach=6
    for _,p in ipairs(points) do
        reach=math.max(reach,math.sqrt((p.x-px)^2+(p.y-py)^2))
    end
    local fit=84/reach
    local scale=8
    while scale>fit do scale=scale/2 end
    return points,cx,cy,scale
end
function ZG.CreatePassageGuide(parent,getter)
    local guide=CreateFrame("Frame",nil,parent)
    guide:SetSize(300,284);UI.Surface(guide,true)
    local function label(text,x,y,w)
        local fs=guide:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        fs:SetPoint("TOPLEFT",x,-y);fs:SetWidth(w);fs:SetJustifyH("LEFT")
        fs:SetText(text);UI.ApplyMutedText(fs);return fs
    end
    label("TRACÉ EN DIRECT",12,10,150)
    local compass=label("Face en haut",180,10,108);compass:SetJustifyH("RIGHT")
    local canvas=CreateFrame("Frame",nil,guide)
    canvas:SetPoint("TOPLEFT",12,-32);canvas:SetSize(276,196)
    UI.Surface(canvas,true)
    local segments,dots,numbers={},{},{}
    for i=1,64 do
        local t=canvas:CreateTexture(nil,"ARTWORK");t:SetHeight(2);t:SetColorTexture(.76,.65,.39,1);t:Hide();segments[i]=t
    end
    for i=1,20 do
        local dot=canvas:CreateTexture(nil,"OVERLAY");dot:SetSize(5,5);dot:SetColorTexture(.9,.76,.45,1);dot:Hide();dots[i]=dot
        local n=canvas:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");n:SetText(tostring(i));n:Hide();numbers[i]=n
    end
    local player=canvas:CreateTexture(nil,"OVERLAY")
    guide.playerMarker=player
    player:SetSize(13,13);player:SetTexture("Interface\\Minimap\\MinimapArrow");player:SetVertexColor(.45,.85,1,1)
    local target=canvas:CreateTexture(nil,"OVERLAY")
    target:SetSize(8,8);target:SetColorTexture(1,.8,.25,1)
    guide.targetMarker=target
    local state=label("",12,236,276);UI.ApplyTitle(state)
    local detail=label("",12,257,276);detail:SetHeight(24)
    guide.distText=detail;guide.statusText=state
    local elapsed=0
    local function Refresh()
        for _,t in ipairs(segments) do t:Hide() end
        for i,t in ipairs(dots) do t:Hide();numbers[i]:Hide() end
        player:Hide();target:Hide()
        local cp=getter and getter()
        local px,py,facing,mapID=ZG:GetPlayerPose()
        local r=ZG:PlacementReadout(cp,px,py,facing,mapID);guide.readout=r
        state:SetText(r.unavailable or r.status)
        detail:SetText(r.hint or "Flèche bleue : vous. Contour bronze : checkpoint.")
        if not cp or not px or not py or cp.mapID~=mapID then return end
        local points,cx,cy,scale=ZG:PlacementGeometry(cp,px,py)
        local function map(x,y)
            local right,forward=ZG:PlacementOffset(x-cx,y-cy,facing)
            return 138+right*scale,98-forward*scale
        end
        local used=0
        local function line(x1,y1,x2,y2,ghost)
            local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
            if length<.1 then return end
            used=used+1;local t=segments[used];if not t then return end
            t:ClearAllPoints();t:SetPoint("CENTER",canvas,"TOPLEFT",(x1+x2)/2,-(y1+y2)/2)
            t:SetWidth(length);t:SetRotation(math.atan2(-dy,dx));t:SetAlpha(ghost and .45 or 1);t:Show()
        end
        for i,p in ipairs(points) do
            local x,y=map(p.x,p.y)
            if cp.shape=="polygon" and dots[i] then
                dots[i]:ClearAllPoints();dots[i]:SetPoint("CENTER",canvas,"TOPLEFT",x,-y);dots[i]:Show()
                numbers[i]:ClearAllPoints();numbers[i]:SetPoint("CENTER",canvas,"TOPLEFT",clamp(x+7,8,268),-clamp(y-7,8,188));numbers[i]:Show()
            end
            if i>1 then local a,b=map(points[i-1].x,points[i-1].y);line(a,b,x,y) end
        end
        if #points>=3 and (cp.shape=="circle" or cp.regionReady) then
            local a,b=map(points[#points].x,points[#points].y);local c,d=map(points[1].x,points[1].y);line(a,b,c,d)
        end
        local x,y=map(px,py)
        local outside=x<8 or x>268 or y<8 or y>188
        if cp.shape=="polygon" and not cp.regionReady and #points>0 then
            local a,b=map(points[#points].x,points[#points].y)
            for i=0,7 do local t=i/8;local v=t+.065;line(a+(x-a)*t,b+(y-b)*t,a+(x-a)*v,b+(y-b)*v,true) end
        end
        player:ClearAllPoints();player:SetPoint("CENTER",canvas,"TOPLEFT",clamp(x,8,268),-clamp(y,8,188))
        -- The contour rotates; the player marker always points up.
        player:SetRotation(0);player:Show()
        local destination=ZG:PlacementTarget(cp,px,py,facing)
        guide.destination=destination
        local tx,ty=map(destination.x,destination.y)
        target:ClearAllPoints();target:SetPoint("CENTER",canvas,"TOPLEFT",tx,-ty);target:Show()
        if destination.distance>=1 then
            for i=1,6 do
                local t=i/8;local v=t+.06
                line(x+(tx-x)*t,y+(ty-y)*t,x+(tx-x)*v,y+(ty-y)*v,true)
            end
        end
        compass:SetText("Face en haut")
        state:SetText(string.format("%s · %.1f yd",destination.instruction,destination.distance))
        if cp.shape=="polygon" and not cp.regionReady then
            detail:SetText("Contour en cours · Points numérotés")
        else
            detail:SetText((r.status or "").." · Cible dorée : passage")
        end
    end
    guide:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>=.1 then elapsed=0;Refresh() end end)
    guide:SetScript("OnShow",Refresh);guide.Refresh=Refresh;Refresh()
    return guide
end
