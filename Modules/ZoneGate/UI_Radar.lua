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
    else
        local angle=cp.facing or 0
        local fx,fy=math.sin(angle),math.cos(angle)
        local dx,dy=px-cp.x,py-cp.y
        signed=dx*fx+dy*fy
        lateral=math.max(0,math.abs(-dx*fy+dy*fx)-(cp.width or 6)/2)
        distance=math.sqrt(signed*signed+lateral*lateral)
        heading=math.cos((facing or angle)-angle)
    end
    local line=cp.shape~="polygon"
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
        for _,p in ipairs(cp.points or {}) do points[#points+1]={x=p.x,y=p.y,name=p.name} end
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
    return points,cx,cy,scale,reach
end
-- The real minimap is borrowed as a true-scale backdrop while the guide is visible.
-- Radii in yards per zoom level (HereBeDragons values), used to choose the zoom.
local RADIUS={outdoor={233.33,200,166.67,133.33,100,66.67},indoor={150,120,90,60,40,25}}
-- Un disque aussi large que la diagonale du cadre (276 × 196 → 339) : il
-- remplit tout le rectangle, coins compris, à n'importe quel angle, et ne
-- change pas en pivotant (un carré déborderait jusqu'à sa demi-diagonale).
-- Le jeu ne rogne pas la minimap : elle est placée tout en bas de la fenêtre
-- et des caches opaques autour du cadre recouvrent ce qui dépasse ; tout le
-- reste de l'interface s'affiche au-dessus des caches.
local MAP_SIZE=math.ceil(math.sqrt(276^2+196^2))+6
local COVER_V,COVER_H=math.ceil(MAP_SIZE/2-98)+2,math.ceil(MAP_SIZE/2-138)+2
-- Couleur des caches : celle du fond des fenêtres de l'éditeur.
ZG.RadarCoverColor={.019,.028,.041,1}
local ROUND_MASK="Interface\\Masks\\CircleMaskScalable"
local function ZoomRadius(zoom)
    return RADIUS[IsIndoors and IsIndoors() and "indoor" or "outdoor"][zoom+1]
end
local borrowed
-- Caches opaques autour du cadre, couleur du fond de fenêtre.
local function Covers(guide,canvas,root)
    if guide.covers then return guide.covers end
    local covers=CreateFrame("Frame",nil,root)
    covers:SetAllPoints(canvas)
    local top=covers:CreateTexture(nil,"BACKGROUND")
    top:SetPoint("BOTTOMLEFT",canvas,"TOPLEFT",-COVER_H,0);top:SetPoint("BOTTOMRIGHT",canvas,"TOPRIGHT",COVER_H,0)
    top:SetHeight(COVER_V);top:SetColorTexture(unpack(ZG.RadarCoverColor))
    local bottom=covers:CreateTexture(nil,"BACKGROUND")
    bottom:SetPoint("TOPLEFT",canvas,"BOTTOMLEFT",-COVER_H,0);bottom:SetPoint("TOPRIGHT",canvas,"BOTTOMRIGHT",COVER_H,0)
    bottom:SetHeight(COVER_V);bottom:SetColorTexture(unpack(ZG.RadarCoverColor))
    local left=covers:CreateTexture(nil,"BACKGROUND")
    left:SetPoint("TOPRIGHT",canvas,"TOPLEFT",0,0);left:SetPoint("BOTTOMRIGHT",canvas,"BOTTOMLEFT",0,0)
    left:SetWidth(COVER_H);left:SetColorTexture(unpack(ZG.RadarCoverColor))
    local right=covers:CreateTexture(nil,"BACKGROUND")
    right:SetPoint("TOPLEFT",canvas,"TOPRIGHT",0,0);right:SetPoint("BOTTOMLEFT",canvas,"BOTTOMRIGHT",0,0)
    right:SetWidth(COVER_H);right:SetColorTexture(unpack(ZG.RadarCoverColor))
    covers:Hide()
    guide.covers=covers
    return covers
end
-- Fenêtre de premier niveau qui contient le tracé (panneau ou fenêtre de tracé).
local function RootOf(frame)
    local root=frame
    while root:GetParent() and root:GetParent()~=UIParent do root=root:GetParent() end
    return root
end
local function BorrowMinimap(guide,canvas,layer)
    if borrowed or not Minimap then return end
    local m=Minimap
    borrowed={parent=m:GetParent(),points={},w=m:GetWidth(),h=m:GetHeight(),scale=m:GetScale(),
        strata=m:GetFrameStrata(),level=m:GetFrameLevel(),zoom=m:GetZoom(),alpha=m:GetAlpha(),
        mouse=m:IsMouseEnabled(),wheel=m:IsMouseWheelEnabled(),rotate=GetCVar("rotateMinimap"),children={},
        mask=m.GetMaskTexture and m:GetMaskTexture() or ROUND_MASK}
    for i=1,m:GetNumPoints() do borrowed.points[i]={m:GetPoint(i)} end
    -- Zoom buttons and addon icons stay hidden: only the terrain is wanted here.
    for _,child in ipairs({m:GetChildren()}) do
        if child:IsShown() then borrowed.children[#borrowed.children+1]=child;child:Hide() end
    end
    -- Rattachée à la fenêtre elle-même (pas au cadre du tracé) : un enfant est
    -- toujours dessiné au-dessus de son parent, il faut qu'elle passe dessous.
    -- Ordre : fond de fenêtre, minimap, caches, puis tout le reste.
    local root=RootOf(guide)
    local base=root:GetFrameLevel()
    m:SetParent(root);m:ClearAllPoints();m:SetPoint("CENTER",canvas,"CENTER")
    m:SetSize(MAP_SIZE,MAP_SIZE);m:SetScale(1);m:SetAlpha(1)
    m:SetFrameStrata(root:GetFrameStrata());m:SetFrameLevel(base+1)
    local covers=Covers(guide,canvas,root)
    covers:SetFrameStrata(root:GetFrameStrata());covers:SetFrameLevel(base+2);covers:Show()
    -- Les fonds du tracé cacheraient la minimap, désormais en dessous d'eux.
    for _,frame in ipairs({guide,canvas}) do if frame.surfaceBg then frame.surfaceBg:SetAlpha(0) end end
    borrowed.guide,borrowed.canvas=guide,canvas
    layer:SetFrameLevel(canvas:GetFrameLevel()+10)
    m:EnableMouse(false);m:EnableMouseWheel(false)
    if m.SetMaskTexture then m:SetMaskTexture(ROUND_MASK) end
    -- The guide is always facing up: the map turns, never the arrow.
    SetCVar("rotateMinimap","1")
end
local function ReleaseMinimap()
    if not borrowed then return end
    local m,b=Minimap,borrowed;borrowed=nil
    m:SetParent(b.parent);m:ClearAllPoints()
    for _,point in ipairs(b.points) do m:SetPoint(unpack(point)) end
    m:SetSize(b.w,b.h);m:SetScale(b.scale);m:SetAlpha(b.alpha)
    m:SetFrameStrata(b.strata);m:SetFrameLevel(b.level);m:SetZoom(b.zoom)
    m:EnableMouse(b.mouse);m:EnableMouseWheel(b.wheel)
    if m.SetMaskTexture then m:SetMaskTexture(b.mask) end
    if b.guide.covers then b.guide.covers:Hide() end
    for _,frame in ipairs({b.guide,b.canvas}) do if frame.surfaceBg then frame.surfaceBg:SetAlpha(1) end end
    SetCVar("rotateMinimap",b.rotate or "0")
    for _,child in ipairs(b.children) do child:Show() end
end
-- Never leave the minimap borrowed (or its rotation forced) across a logout.
local logout=CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent",function() ReleaseMinimap() end)
-- Pick the closest zoom that still shows the whole contour; nil when it does not fit.
-- Contour trop grand : on s'arrête au zoom le plus large, la minimap reste
-- visible et ce qui dépasse est coupé au bord du cadre.
-- Zoom automatique : un cran plus près que « tout le contour visible » ;
-- bias (molette) rapproche ou éloigne encore.
local function MinimapScale(reach,bias)
    local levels=Minimap:GetZoomLevels()
    local fit=0
    for zoom=levels-1,0,-1 do
        local radius=ZoomRadius(zoom)
        -- Le cadre montre 98 px de haut sur les MAP_SIZE/2 px de rayon de la carte.
        if radius and radius*98/(MAP_SIZE/2)>=reach*1.15 then fit=zoom;break end
    end
    local chosen=math.max(0,math.min(levels-1,fit+1+(bias or 0)))
    if Minimap:GetZoom()~=chosen then Minimap:SetZoom(chosen) end
    local view=C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius() or ZoomRadius(chosen) or 233.33
    return (MAP_SIZE/2)/view
end
-- Sans minimap, même limite : jamais plus large qu'environ 170 mètres autour du joueur.
local MIN_SCALE=.5
-- Numéros des sommets : pleinement visibles jusqu'à LABEL_NEAR pixels de la
-- flèche, effacés au-delà de LABEL_FAR.
local LABEL_NEAR,LABEL_FAR=45,95
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
    -- Ce qui sort du cadre est coupé, au lieu de déborder sur le panneau.
    if canvas.SetClipsChildren then canvas:SetClipsChildren(true) end
    -- Molette sur le cadre : rapprocher (haut) ou éloigner (bas), de -5 à +5 crans.
    canvas:EnableMouseWheel(true)
    canvas:SetScript("OnMouseWheel",function(_,delta)
        guide.zoomBias=math.max(-5,math.min(5,(guide.zoomBias or 0)+(delta>0 and 1 or -1)))
        if guide.Refresh then guide.Refresh() end
    end)
    -- Drawing layer above the borrowed minimap.
    local layer=CreateFrame("Frame",nil,canvas)
    layer:SetAllPoints();layer:SetFrameLevel(canvas:GetFrameLevel()+10)
    -- Créés à la demande : un périmètre peut compter jusqu'à 1500 sommets.
    local segments,dots,numbers={},{},{}
    local function Segment(i)
        if not segments[i] then
            local t=layer:CreateTexture(nil,"ARTWORK");t:SetHeight(2);t:SetColorTexture(.76,.65,.39,1);t:Hide();segments[i]=t
        end
        return segments[i]
    end
    local function Dot(i)
        if not dots[i] then
            local dot=layer:CreateTexture(nil,"OVERLAY");dot:SetSize(5,5);dot:SetColorTexture(.9,.76,.45,1);dot:Hide();dots[i]=dot
            local n=layer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");n:Hide();numbers[i]=n
        end
        return dots[i],numbers[i]
    end
    local player=layer:CreateTexture(nil,"OVERLAY")
    guide.playerMarker=player
    player:SetSize(40,40);player:SetDrawLayer("OVERLAY",7);player:SetTexture("Interface\\Minimap\\MinimapArrow");player:SetVertexColor(.45,.85,1,1)
    local target=layer:CreateTexture(nil,"OVERLAY")
    target:SetSize(8,8);target:SetColorTexture(1,.8,.25,1)
    guide.targetMarker=target
    -- Premier sommet d'un contour en cours : repère bleu, collé au bord s'il est hors champ.
    local start=layer:CreateTexture(nil,"OVERLAY");start:SetSize(9,9);start:SetColorTexture(.45,.80,1,1);start:Hide()
    local startText=layer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    startText:SetText("Départ");startText:SetTextColor(.45,.80,1,1);startText:Hide()
    guide.startMarker=start
    -- Crossing direction of a straight passage: green enters, red leaves.
    local sides={}
    for key,info in pairs({enter={"ENTRÉE",.40,.90,.45},leave={"SORTIE",.90,.40,.40}}) do
        local arrow=layer:CreateTexture(nil,"OVERLAY")
        arrow:SetSize(18,18);arrow:SetTexture("Interface\\Minimap\\MinimapArrow");arrow:SetVertexColor(info[2],info[3],info[4],1)
        local text=layer:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        text:SetText(info[1]);text:SetTextColor(info[2],info[3],info[4],1)
        arrow:Hide();text:Hide();sides[key]={arrow=arrow,text=text}
    end
    guide.sideMarkers=sides
    local state=label("",12,236,276);UI.ApplyTitle(state)
    local detail=label("",12,257,276);detail:SetHeight(24)
    guide.distText=detail;guide.statusText=state
    local elapsed=0
    local function Refresh()
        for _,t in ipairs(segments) do t:Hide() end
        for i,t in ipairs(dots) do t:Hide();numbers[i]:Hide() end
        player:Hide();target:Hide();start:Hide();startText:Hide()
        for _,side in pairs(sides) do side.arrow:Hide();side.text:Hide() end
        local cp=getter and getter()
        local px,py,facing,mapID=ZG:GetPlayerPose()
        local r=ZG:PlacementReadout(cp,px,py,facing,mapID);guide.readout=r
        state:SetText(r.unavailable or r.status)
        detail:SetText(r.hint or "Flèche bleue : vous. Contour bronze : checkpoint.")
        if not cp or not px or not py or cp.mapID~=mapID then return end
        local points,cx,cy,scale,reach=ZG:PlacementGeometry(cp,px,py)
        if borrowed then scale=MinimapScale(reach,guide.zoomBias)
        else scale=math.max(scale,MIN_SCALE)*2^(1+(guide.zoomBias or 0)) end
        local function map(x,y)
            local right,forward=ZG:PlacementOffset(x-cx,y-cy,facing)
            return 138+right*scale,98-forward*scale
        end
        local used=0
        local function line(x1,y1,x2,y2,ghost,color)
            local dx,dy=x2-x1,y2-y1;local length=math.sqrt(dx*dx+dy*dy)
            if length<.1 then return end
            -- Segment entièrement hors du cadre, du même côté : rien à dessiner.
            if (x1<0 and x2<0) or (x1>276 and x2>276) or (y1<0 and y2<0) or (y1>196 and y2>196) then return end
            used=used+1;local t=Segment(used)
            t:ClearAllPoints();t:SetPoint("CENTER",canvas,"TOPLEFT",(x1+x2)/2,-(y1+y2)/2)
            if color then t:SetColorTexture(color[1],color[2],color[3],1) else t:SetColorTexture(.76,.65,.39,1) end
            t:SetWidth(length);t:SetRotation(math.atan2(-dy,dx));t:SetAlpha(ghost and .45 or 1);t:Show()
        end
        -- Tronçons des frontières déclarées : dessinés en bleu clair.
        local marked={}
        for _,b in ipairs(cp.borders or {}) do
            local path=ZG.BorderPath and ZG:BorderPath(cp,b.from,b.to,b.forward)
            for k=2,#(path or {}) do marked[path[k-1].."-"..path[k]]=true;marked[path[k].."-"..path[k-1]]=true end
        end
        local BORDER={.45,.80,1}
        for i,p in ipairs(points) do
            local x,y=map(p.x,p.y)
            local inside=x>=0 and x<=276 and y>=0 and y<=196
            if cp.shape=="polygon" and inside then
                local dot,number=Dot(i)
                -- Fondu selon la distance à la flèche (au centre du cadre, en pixels) :
                -- net près de soi, estompé plus loin ; les numéros disparaissent au loin.
                local near=math.sqrt((x-138)^2+(y-98)^2)
                local fade=clamp(1-(near-LABEL_NEAR)/(LABEL_FAR-LABEL_NEAR),0,1)
                dot:ClearAllPoints();dot:SetPoint("CENTER",canvas,"TOPLEFT",x,-y)
                dot:SetAlpha(.35+.65*fade);dot:Show()
                if fade>0 then
                    number:SetText(p.name or tostring(i))
                    if p.name then number:SetTextColor(.55,.85,1) else number:SetTextColor(1,.82,0) end
                    number:ClearAllPoints();number:SetPoint("CENTER",canvas,"TOPLEFT",clamp(x+7,8,268),-clamp(y-7,8,188))
                    number:SetAlpha(fade);number:Show()
                end
            end
            if i>1 then local a,b=map(points[i-1].x,points[i-1].y);line(a,b,x,y,false,marked[(i-1).."-"..i] and BORDER or nil) end
        end
        if #points>=3 and cp.regionReady then
            local a,b=map(points[#points].x,points[#points].y);local c,d=map(points[1].x,points[1].y);line(a,b,c,d,false,marked[#points.."-1"] and BORDER or nil)
        end
        if cp.shape~="polygon" then
            -- Entering crosses towards the arrival side (see PlacementReadout).
            local a=cp.facing or 0
            local gx,gy=map(cp.x,cp.y)
            local fx,fy=map(cp.x+math.sin(a),cp.y+math.cos(a))
            local ux,uy=fx-gx,fy-gy;local len=math.sqrt(ux*ux+uy*uy)
            if len>0 then
                ux,uy=ux/len,uy/len
                for key,sign in pairs({enter=1,leave=-1}) do
                    local side=sides[key]
                    side.arrow:ClearAllPoints()
                    side.arrow:SetPoint("CENTER",canvas,"TOPLEFT",clamp(gx+ux*sign*14,10,266),-clamp(gy+uy*sign*14,10,186))
                    side.arrow:SetRotation(math.atan2(-ux*sign,-uy*sign));side.arrow:Show()
                    side.text:ClearAllPoints()
                    side.text:SetPoint("CENTER",canvas,"TOPLEFT",clamp(gx+ux*sign*34,28,248),-clamp(gy+uy*sign*34,8,188));side.text:Show()
                end
            end
        end
        local x,y=map(px,py)
        local outside=x<8 or x>268 or y<8 or y>188
        if cp.shape=="polygon" and not cp.regionReady and #points>0 then
            local a,b=map(points[#points].x,points[#points].y)
            for i=0,7 do local t=i/8;local v=t+.065;line(a+(x-a)*t,b+(y-b)*t,a+(x-a)*v,b+(y-b)*v,true) end
            -- Pointillé bleu vers le premier point : là où le contour devra se refermer.
            if #points>=2 then
                local fx,fy=map(points[1].x,points[1].y)
                local length=math.sqrt((fx-x)^2+(fy-y)^2)
                local dashes=math.min(60,math.floor(length/10))
                for i=0,dashes-1 do
                    local t,v=i/dashes,(i+.5)/dashes
                    line(x+(fx-x)*t,y+(fy-y)*t,x+(fx-x)*v,y+(fy-y)*v,false,{.45,.80,1})
                end
                local sx,sy=clamp(fx,6,270),clamp(fy,6,190)
                start:ClearAllPoints();start:SetPoint("CENTER",canvas,"TOPLEFT",sx,-sy);start:Show()
                startText:ClearAllPoints();startText:SetPoint("CENTER",canvas,"TOPLEFT",clamp(sx,26,250),-clamp(sy+12,10,186));startText:Show()
            end
        end
        player:ClearAllPoints();player:SetPoint("CENTER",canvas,"TOPLEFT",clamp(x,20,256),-clamp(y,20,176))
        -- The contour and the minimap rotate; the player marker always points up.
        player:SetRotation(0);player:Show()
        local destination=ZG:PlacementTarget(cp,px,py,facing)
        guide.destination=destination
        local tx,ty=map(destination.x,destination.y)
        -- Cible hors du cadre : elle reste au bord, dans sa direction.
        tx,ty=clamp(tx,6,270),clamp(ty,6,190)
        target:ClearAllPoints();target:SetPoint("CENTER",canvas,"TOPLEFT",tx,-ty);target:Show()
        if destination.distance>=1 then
            for i=1,6 do
                local t=i/8;local v=t+.06
                line(x+(tx-x)*t,y+(ty-y)*t,x+(tx-x)*v,y+(ty-y)*v,true)
            end
        end
        compass:SetText("Molette : zoom")
        state:SetText(string.format("%s · %.1f yd",destination.instruction,destination.distance))
        if cp.shape=="polygon" and not cp.regionReady then
            detail:SetText("Contour en cours · Points numérotés")
        else
            detail:SetText((r.status or "").." · Cible dorée : passage")
        end
    end
    guide:SetScript("OnUpdate",function(_,dt) elapsed=elapsed+dt;if elapsed>=.1 then elapsed=0;Refresh() end end)
    guide:SetScript("OnShow",function() BorrowMinimap(guide,canvas,layer);Refresh() end)
    guide:SetScript("OnHide",ReleaseMinimap)
    guide.Refresh=Refresh;Refresh()
    return guide
end
