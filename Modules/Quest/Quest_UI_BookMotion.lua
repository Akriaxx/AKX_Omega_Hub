-- Lecteur d'atlas uniquement : chaque image contient tout le grimoire animé.
-- Les déformations et occultations sont précalculées dans book_animation.py.
local J=Quest
local PATH="Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Book\\BindingEdges\\"

-- Dessiner chaque ressource entière à très petite taille, une à la fois.
-- Un texel transparent / une région masquée ne prouve pas sa préparation GPU.
function J:WarmAnimationTextures()
    local warm=self.animationWarmup
    if warm and (warm.ready or (warm:IsShown() and warm:GetScript("OnUpdate"))) then return end
    if not warm then
        warm=CreateFrame("Frame",nil,UIParent);self.animationWarmup=warm
        warm:SetSize(2,2);warm:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",0,0)
        warm:SetFrameStrata("TOOLTIP");warm:EnableMouse(false)
        warm.images={};warm.resources={};warm.groups={opening={},turning={},envelope={},book={}}
        local paths={}
        local function add(group,path)
            local resource=paths[path]
            if not resource then
                local image=warm:CreateTexture(nil,"ARTWORK")
                image:SetAllPoints();image:SetTexCoord(0,1,0,1);image:SetAlpha(.02);image:Hide()
                resource={image=image,path=path,frames=0};paths[path]=resource
                warm.images[#warm.images+1]=image;warm.resources[#warm.resources+1]=resource
            end
            warm.groups[group][#warm.groups[group]+1]=resource
        end
        for i=1,6 do add("opening",PATH.."opening-"..i..".blp") end
        for i=1,4 do add("turning",PATH.."turning-"..i..".blp") end
        local envelope="Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Envelope\\"
        for i=1,4 do add("envelope",envelope.."atlas-"..i..".blp") end
        add("envelope",envelope.."paper.blp");add("book",PATH.."grimoire.blp")
        local book="Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Book\\"
        for _,name in ipairs({"personal","group","archives","mj","blank"}) do add("book",book.."bookmark-"..name..".blp") end
    end
    warm.elapsed=0;warm.failed=false;warm:Show()
    local function pending(group)
        for _,resource in ipairs(group or {}) do if not resource.ready then return resource end end
    end
    warm:SetScript("OnUpdate",function(f,dt)
        -- Ne pas charger d'autres ressources pendant une animation déjà partie.
        local motion=self.book and self.book.motion
        if (motion and motion:IsShown() and not motion.waitingForTextures)
            or (self.letter and self.letter.playing and not self.letter.waitingForTextures) then return end
        f.elapsed=f.elapsed+dt
        if f.current then
            local resource=f.current;local image=resource.image
            if not image.IsObjectLoaded or image:IsObjectLoaded() then
                resource.frames=resource.frames+1
                if resource.frames>=3 then resource.ready=true;image:Hide();f.current=nil end
            else resource.frames=0 end
        end
        if not f.current then
            local resource=pending(f.groups[f.priority])
            if not resource and (f.priority=="opening" or f.priority=="turning") then resource=pending(f.groups.book) end
            resource=resource or pending(f.resources)
            if not resource then f.ready=true;f:SetScript("OnUpdate",nil);f:Hide();return end
            f.current=resource;resource.frames=0
            if not resource.assigned then resource.image:SetTexture(resource.path);resource.assigned=true end
            resource.image:Show()
        end
        if f.elapsed>=15 then
            f.failed=true;f.current.image:Hide();f.current=nil
            f:SetScript("OnUpdate",nil);f:Hide()
        end
    end)
end

function J:AnimationTexturesReady(group)
    if not self.animationWarmup then self:WarmAnimationTextures() end
    local warm=self.animationWarmup
    local function ready(resources)
        for _,resource in ipairs(resources) do if not resource.ready then return false end end
        return true
    end
    if ready(warm.groups[group]) and ((group~="opening" and group~="turning") or ready(warm.groups.book)) then return true end
    if warm.failed then return false,true end
    warm.priority=group
    if not warm:IsShown() then self:WarmAnimationTextures() end
    return false,false
end

-- Une région persistante par planche : SetTexture n'est jamais rappelé
-- pendant la lecture. La création masquée lance le chargement en avance.
function J:PrepareBookMotion()
    local book=self.book
    if book.motion then return end
    local m=CreateFrame("Frame",nil,UIParent)
    book.motion=m
    m:Hide()
    m:SetFrameStrata("HIGH");m:SetFrameLevel(book:GetFrameLevel()+30)
    m:SetAllPoints(book);m:EnableMouse(true)
    m.images={opening={},turning={}}
    for sequence,count in pairs({opening=6,turning=4}) do
        for i=1,count do
            local texture=m:CreateTexture(nil,"ARTWORK")
            texture:SetAllPoints();texture:SetTexture(PATH..sequence.."-"..i..".blp")
            texture:Hide();m.images[sequence][i]=texture
        end
    end
end

function J:StopBookTextFade()
    local book=self.book
    if not book then return end
    if book.textFade then book.textFade:SetScript("OnUpdate",nil);book.textFade:Hide() end
    if book.left then book.left:SetAlpha(1);book.right:SetAlpha(1) end
    book.textAlpha=1
end

function J:FadeBookText(outgoing,onComplete)
    local book=self.book
    local initial=outgoing and (book.textAlpha or 1) or 0
    self:StopBookTextFade()
    if not book.textFade then book.textFade=CreateFrame("Frame",nil,book) end
    local fade=book.textFade
    fade.elapsed=0
    book.textAlpha=initial
    book.left:SetAlpha(initial);book.right:SetAlpha(initial)
    fade:Show()
    fade:SetScript("OnUpdate",function(_,dt)
        fade.elapsed=fade.elapsed+dt
        local progress=math.min(1,fade.elapsed/.3)
        local alpha=outgoing and initial*(1-progress) or progress
        book.textAlpha=alpha
        book.left:SetAlpha(alpha);book.right:SetAlpha(alpha)
        if progress==1 then
            self:StopBookTextFade()
            if onComplete then onComplete() end
        end
    end)
end

function J:StopBookMotion()
    local book=self.book
    if not book then return end
    self:StopBookTextFade()
    if book.motion then
        book.motion:SetScript("OnUpdate",nil)
        book.motion:Hide()
    end
    book:SetAlpha(1)
    for _,tab in ipairs({book.rail,book.mjButton}) do
        tab:SetIgnoreParentAlpha(false)
        tab:SetFrameLevel(book:GetFrameLevel()+1)
    end
end

function J:PlayBookSequence(mode)
    local book=self.book
    self:StopBookTextFade()
    self:PrepareBookMotion()
    local m=book.motion
    for _,tab in ipairs({book.rail,book.mjButton}) do
        tab:SetIgnoreParentAlpha(mode=="page")
        tab:SetFrameStrata("HIGH")
        tab:SetFrameLevel(m:GetFrameLevel()+1)
    end
    local sequence=mode=="page" and "turning" or "opening"
    local count=mode=="page" and 16 or 24
    local first=mode=="close" and count-1 or 0
    local last=mode=="close" and 0 or count-1
    -- Une inversion rapide repart de l'image déjà affichée, sans saut.
    if sequence=="opening" and m:IsShown() and m.sequence==sequence then first=m.index or first end
    m:SetScript("OnUpdate",nil)
    m.sequence=sequence;m.mode=mode;m.elapsed=0;m.atlas=nil;m.waitingForTextures=true
    m.duration=math.max(.03,(mode=="page" and .45 or .70)*math.abs(last-first)/(count-1))
    self.Write:Stop(book.content)
    book:SetAlpha(0)
    m:SetScale(book:GetScale())
    local function draw(index)
        local atlas=math.floor(index/4)+1
        local image=m.images[sequence][atlas]
        if image.IsObjectLoaded and not image:IsObjectLoaded() then return false end
        m.index=index
        if atlas~=m.atlas then
            if m.image then m.image:Hide() end
            m.image=m.images[sequence][atlas]
            m.image:Show()
            m.atlas=atlas
        end
        local tile=index%4;local x,y=tile%2,math.floor(tile/2)
        m.image:SetTexCoord(x/2,(x+1)/2,y/2,(y+1)/2)
        return true
    end
    local started=draw(first);m:Show()
    self:AnimationTexturesReady(sequence)
    m:SetScript("OnUpdate",function(_,dt)
        local ready,failed=self:AnimationTexturesReady(sequence)
        if failed then
            self:StopBookMotion()
            if book:IsShown() and self.enabled then self:RenderQuest(mode=="page") end
            return
        end
        if not ready then return end
        -- Si le client charge encore une planche, conserver la dernière
        -- image et suspendre le temps plutôt que montrer une texture vide.
        for _,image in ipairs(m.images[sequence]) do
            if image.IsObjectLoaded and not image:IsObjectLoaded() then return end
        end
        if not started then started=draw(first);return end
        if m.waitingForTextures then m.waitingForTextures=false;return end
        -- Une pause du client ne doit pas avaler plusieurs poses d'un coup.
        m.elapsed=m.elapsed+math.min(dt,m.duration/math.max(1,math.abs(last-first)))
        local t=math.min(1,m.elapsed/m.duration)
        local index=math.floor(first+(last-first)*t+.5)
        if index~=m.index then draw(index) end
        if t==1 then
            self:StopBookMotion()
            if book:IsShown() and self.enabled then
                self:RenderQuest(mode=="page")
                if mode=="page" then self:FadeBookText() end
            end
        end
    end)
end

function J:AnimateBook(opening)
    self:PlayBookSequence(opening and "open" or "close")
end

function J:TurnBookPage(onTurn)
    -- Une ouverture en cours a priorité sur la sélection initiale d'une quête.
    local book=self.book
    if book.motion and book.motion:IsShown() then
        if onTurn then onTurn() end
        if book.motion.mode~="open" then self:PlayBookSequence("page") end
        return
    end
    self.Write:Finish(book.content)
    self:FadeBookText(true,function()
        if not book:IsShown() or not self.enabled then return end
        if onTurn then onTurn() end
        self:PlayBookSequence("page")
    end)
end
