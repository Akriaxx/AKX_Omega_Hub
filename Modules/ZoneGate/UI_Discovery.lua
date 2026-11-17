-- ============================================================
--  Crossings — Connaissances
--  Apprendre des noms par lots : on coche des joueurs à gauche,
--  des régions et des lieux à droite (toutes vos régions), puis
--  « Apprendre » ou « Faire oublier ». Exemple : trois joueurs
--  parlent à un PNJ, on leur apprend d'un coup ce qu'il révèle.
--  Les joueurs viennent de ceux qui connaissent déjà un nom, du
--  groupe ou du raid, et de ceux ajoutés à la main par leur nom.
-- ============================================================
local ZG=ZoneGate
local UI=ZG.EditorUI or OS2.UI
local W,H,HEAD=900,620,56
local M=16
local LEFT_W=270
local RX=M+LEFT_W+16
local RIGHT_W=W-RX-M
local LIST_Y=HEAD+92
local ROW=26
local win
local function short(name) return (name or ""):match("^([^%-]+)") end
local function Trim(s) return (tostring(s or ""):match("^%s*(.-)%s*$")) or "" end
local function Me() return UnitName("player") or "" end

-- Membres connectés du groupe ou du raid (sans soi-même), nom court en clé.
function ZG:DiscoveryRoster()
    local members,seen={},{}
    local function add(token)
        if UnitIsConnected and not UnitIsConnected(token) then return end
        local name,realm=UnitName(token)
        if not name or name=="" or name==Me() then return end
        local full=realm and realm~="" and name.."-"..realm or name
        if not seen[full] then seen[full]=true;members[#members+1]={name=full,key=short(name)} end
    end
    if IsInRaid and IsInRaid() then
        for i=1,GetNumGroupMembers() do add("raid"..i) end
    elseif IsInGroup and IsInGroup() then
        for i=1,4 do add("party"..i) end
    end
    table.sort(members,function(a,b) return a.name<b.name end)
    return members
end

-- Nombre de joueurs qui connaissent un nom (région ou lieu), pour les fiches.
function ZG:DiscoveryCount(item)
    local n=0
    for _ in pairs(item and item.grantedTo or {}) do n=n+1 end
    return n
end

local function label(parent,text,x,y,w,muted)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    f:SetPoint("TOPLEFT",x,-y);f:SetWidth(w);f:SetJustifyH("LEFT");f:SetText(text)
    if muted then UI.ApplyMutedText(f) else UI.ApplyLabel(f) end
    return f
end

-- Liste à rangées recyclées : seules les rangées visibles existent, la
-- molette fait défiler. Tient des milliers de lieux sans ralentir.
local function VList(parent,x,y,w,h,build)
    local list=CreateFrame("Frame",nil,parent)
    list:SetPoint("TOPLEFT",x,-y);list:SetSize(w,h);list:EnableMouseWheel(true)
    list.rows,list.items,list.offset={},{},0
    list.size=math.floor(h/ROW)
    for i=1,list.size do
        local row=build(list)
        row:SetPoint("TOPLEFT",list,"TOPLEFT",0,-(i-1)*ROW);row:SetSize(w,ROW)
        list.rows[i]=row
    end
    list.more=label(parent,"",x,y+h+4,w,true)
    function list:Update(items,fill)
        self.items,self.fill=items or self.items,fill or self.fill
        self.offset=math.max(0,math.min(self.offset,#self.items-self.size))
        for i,row in ipairs(self.rows) do
            local item=self.items[self.offset+i]
            if item then self.fill(row,item,self.offset+i);row:Show() else row:Hide() end
        end
        self.more:SetText(#self.items>self.size and string.format("%d–%d sur %d · molette pour défiler",self.offset+1,math.min(#self.items,self.offset+self.size),#self.items) or "")
    end
    list:SetScript("OnMouseWheel",function(self,delta) self.offset=self.offset-delta*3;self:Update() end)
    return list
end

local function RowBase(list)
    local row=CreateFrame("Button",nil,list)
    row.bg=row:CreateTexture(nil,"BACKGROUND");row.bg:SetAllPoints()
    local hl=row:CreateTexture(nil,"HIGHLIGHT");hl:SetAllPoints();hl:SetColorTexture(1,1,1,.05)
    row.box=UI.CreateStyledCheckbox(row,"")
    row.text=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.text:SetJustifyH("LEFT");row.text:SetWordWrap(false);UI.ApplyBodyText(row.text)
    row.info=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    row.info:SetPoint("RIGHT",-8,0);row.info:SetJustifyH("RIGHT");UI.ApplyMutedText(row.info)
    return row
end

local function Build()
    win=CreateFrame("Frame","ZoneGateKnowledge",UIParent)
    win:SetSize(W,H);win:SetPoint("CENTER");win:SetFrameStrata("DIALOG")
    win:EnableMouse(true);win:SetClampedToScreen(true);win:SetMovable(true)
    UI.Surface(win);win:Hide()
    if win.surfaceBg then UI.ApplyWindowBackground(win.surfaceBg,1) end

    -- En-tête : on déplace la fenêtre en le saisissant.
    local head=CreateFrame("Frame",nil,win)
    head:SetPoint("TOPLEFT",1,-1);head:SetPoint("TOPRIGHT",-1,-1);head:SetHeight(HEAD)
    head:EnableMouse(true);head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart",function() win:StartMoving() end)
    head:SetScript("OnDragStop",function() win:StopMovingOrSizing() end)
    local headBg=head:CreateTexture(nil,"BACKGROUND");headBg:SetAllPoints();UI.ApplyWindowBackground(headBg,.70)
    local accent=head:CreateTexture(nil,"ARTWORK");accent:SetWidth(3)
    accent:SetPoint("TOPLEFT");accent:SetPoint("BOTTOMLEFT");accent:SetColorTexture(unpack(UI.colors.tabLine))
    local title=head:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",16,-9);title:SetText("Connaissances");UI.ApplyTitle(title)
    label(head,"Apprenez des noms de régions et de lieux à plusieurs joueurs à la fois.",16,33,W-80,true)
    local sep=win:CreateTexture(nil,"ARTWORK")
    sep:SetPoint("TOPLEFT",1,-(HEAD+1));sep:SetPoint("TOPRIGHT",-1,-(HEAD+1));sep:SetHeight(1);UI.ApplySeparator(sep)
    UI.CreateCloseButton(head,function() win:Hide() end)

    -- ── Colonne gauche : joueurs ──
    label(win,"1. Joueurs",M,HEAD+14,LEFT_W)
    local groupBtn=UI.CreatePanelButton(win,(LEFT_W-8)/2,24,"Tout le groupe");groupBtn:SetPoint("TOPLEFT",M,-(HEAD+36))
    local noneBtn=UI.CreatePanelButton(win,(LEFT_W-8)/2,24,"Aucun");noneBtn:SetPoint("TOPLEFT",M+(LEFT_W+8)/2,-(HEAD+36))
    local playersH=H-LIST_Y-176
    win.playerList=VList(win,M,LIST_Y-24,LEFT_W,playersH+24,function(list)
        local row=RowBase(list)
        row.box:SetPoint("LEFT",4,0);row.text:SetPoint("LEFT",28,0);row.text:SetPoint("RIGHT",-60,0)
        local function toggle() win.players[row.name]=not win.players[row.name] or nil;win:Refresh() end
        row:SetScript("OnClick",toggle);row.box:SetScript("OnClick",toggle)
        return row
    end)
    local addY=H-150
    label(win,"Ajouter un joueur par son nom",M,addY,LEFT_W)
    win.nameBox=UI.CreateStyledEditBox(win,LEFT_W-90,28,false)
    win.nameBox:SetPoint("TOPLEFT",M,-(addY+18));win.nameBox:SetMaxLetters(48)
    local add=UI.CreatePanelButton(win,82,28,"Ajouter");add:SetPoint("TOPLEFT",M+LEFT_W-82,-(addY+18))
    local function AddName()
        local name=short(Trim(win.nameBox:GetText()))
        if name and name~="" and name~=Me() then
            name=name:sub(1,1):upper()..name:sub(2)
            win.extra[name]=true;win.players[name]=true
        end
        win.nameBox:SetText("");win.nameBox:ClearFocus();win:Refresh()
    end
    add:SetScript("OnClick",AddName)
    win.nameBox:SetScript("OnEnterPressed",AddName)
    win.nameBox:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)

    -- ── Colonne droite : régions et lieux ──
    label(win,"2. Régions et lieux à apprendre",RX,HEAD+14,RIGHT_W)
    win.search=UI.CreateStyledEditBox(win,RIGHT_W-208,24,false)
    win.search:SetPoint("TOPLEFT",RX,-(HEAD+36));win.search:SetMaxLetters(40)
    win.search:SetScript("OnTextChanged",function() win.itemList.offset=0;win:Refresh() end)
    win.search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    win.search:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    win.search:SetScript("OnEditFocusGained",function() win.searchHint:Hide() end)
    win.search:SetScript("OnEditFocusLost",function() win.searchHint:SetShown(Trim(win.search:GetText())=="") end)
    local searchHint=label(win,"Rechercher…",RX+8,HEAD+42,200,true)
    win.searchHint=searchHint
    local clearItems=UI.CreatePanelButton(win,200,24,"Tout désélectionner");clearItems:SetPoint("TOPLEFT",RX+RIGHT_W-200,-(HEAD+36))
    clearItems:SetScript("OnClick",function() win.items={};win:Refresh() end)
    win.itemList=VList(win,RX,LIST_Y-24,RIGHT_W,playersH+24,function(list)
        local row=RowBase(list)
        -- Région : bouton pour cocher d'un coup tous ses lieux.
        row.all=UI.CreatePanelButton(row,96,20,"+ ses lieux")
        row.all:SetPoint("RIGHT",-110,0)
        row.all:SetScript("OnClick",function()
            local zone=ZG:GetZone(row.entry.id)
            local select=not win:AllPlacesSelected(zone)
            win.items["Z:"..zone.id]=select or nil
            for _,place in ipairs(ZG:GetPlaceList(zone.id)) do win.items["P:"..place.id]=select or nil end
            if select then win.open[zone.id]=true end
            win:Refresh()
        end)
        -- Accordéon : le +/− (ou un clic sur la rangée) déplie la région.
        -- Dessiné comme les cases à cocher : cadre doré, fond sombre, trait doré.
        row.fold=CreateFrame("Button",nil,row);row.fold:SetSize(16,16);row.fold:SetPoint("LEFT",6,0)
        local foldBorder=row.fold:CreateTexture(nil,"BORDER");foldBorder:SetAllPoints()
        foldBorder:SetColorTexture(.57,.46,.28,.85)
        local foldBox=row.fold:CreateTexture(nil,"ARTWORK")
        foldBox:SetPoint("TOPLEFT",1,-1);foldBox:SetPoint("BOTTOMRIGHT",-1,1);foldBox:SetColorTexture(.012,.020,.031,.98)
        local across=row.fold:CreateTexture(nil,"OVERLAY");across:SetSize(8,2);across:SetPoint("CENTER")
        across:SetColorTexture(1,.82,.36,1)
        row.fold.down=row.fold:CreateTexture(nil,"OVERLAY");row.fold.down:SetSize(2,8);row.fold.down:SetPoint("CENTER")
        row.fold.down:SetColorTexture(1,.82,.36,1)
        local foldHl=row.fold:CreateTexture(nil,"HIGHLIGHT")
        foldHl:SetPoint("TOPLEFT",1,-1);foldHl:SetPoint("BOTTOMRIGHT",-1,1);foldHl:SetColorTexture(1,.82,.36,.15)
        local function fold() local id=row.entry.id;win.open[id]=not win.open[id] or nil;win:Refresh() end
        row.fold:SetScript("OnClick",fold)
        local function toggle() win.items[row.entry.key]=not win.items[row.entry.key] or nil;win:Refresh() end
        row:SetScript("OnClick",function() if row.entry.region then fold() else toggle() end end)
        row.box:SetScript("OnClick",toggle)
        return row
    end)

    -- ── Bas : résumé et actions ──
    win.summary=label(win,"",RX,H-104,RIGHT_W)
    win.status=label(win,"",RX,H-84,RIGHT_W,true);win.status:SetHeight(28)
    local forget=UI.CreatePanelButton(win,200,30,"Faire oublier")
    forget:SetPoint("BOTTOMRIGHT",win,"BOTTOMRIGHT",-M-216,14)
    if forget.bgN then forget.bgN:SetColorTexture(.30,.05,.05,.95) end
    if forget.accent then forget.accent:SetColorTexture(.90,.30,.30,1) end
    local learnBtn=UI.CreatePanelButton(win,200,30,"Apprendre")
    learnBtn:SetPoint("BOTTOMRIGHT",win,"BOTTOMRIGHT",-M,14)
    win.learnBtn,win.forgetBtn=learnBtn,forget

    -- Joueurs connus : ceux qui savent déjà un nom dans mes régions, le groupe, les ajouts.
    function win:PlayerEntries()
        local seen,list={},{}
        local function add(name,group)
            if not name or name=="" or name==Me() then return end
            if seen[name] then seen[name].group=seen[name].group or group;return end
            seen[name]={name=name,group=group};list[#list+1]=seen[name]
        end
        for _,zone in ipairs(ZG:GetZoneList()) do
            if zone.creator==Me() then
                for name in pairs(zone.grantedTo or {}) do add(name) end
                for _,place in ipairs(ZG:GetPlaceList(zone.id)) do for name in pairs(place.grantedTo or {}) do add(name) end end
            end
        end
        for _,member in ipairs(ZG:DiscoveryRoster()) do add(member.key,true) end
        for name in pairs(self.extra) do add(name) end
        table.sort(list,function(a,b) return a.name<b.name end)
        return list
    end
    function win:SelectedPlayers()
        local list={}
        for name in pairs(self.players) do list[#list+1]=name end
        table.sort(list)
        return list
    end
    -- Vos régions (rangées par pays puis par nom) et leurs lieux, filtrés par la recherche.
    -- Les lieux n'apparaissent que sous une région dépliée, ou pendant une recherche.
    function win:ItemEntries()
        local query=Trim(self.search:GetText()):lower()
        local zones={}
        for _,zone in ipairs(ZG:GetZoneList()) do if zone.creator==Me() then zones[#zones+1]=zone end end
        local function countryName(zone) local c=ZG:GetCountry(zone.countryId);return c and c.name or "~" end
        table.sort(zones,function(a,b)
            local ca,cb=countryName(a),countryName(b)
            if ca~=cb then return ca<cb end
            return (a.name or "")<(b.name or "")
        end)
        local list={}
        local function match(text) return query=="" or (text or ""):lower():find(query,1,true)~=nil end
        for _,zone in ipairs(zones) do
            local places={}
            for _,place in ipairs(ZG:GetPlaceList(zone.id)) do
                if match(place.name) or match(zone.name) then places[#places+1]=place end
            end
            if match(zone.name) or #places>0 then
                local c=ZG:GetCountry(zone.countryId)
                local open=query~="" or self.open[zone.id]
                list[#list+1]={key="Z:"..zone.id,id=zone.id,item=zone,region=true,name=zone.name or "",country=c and c.name,places=#places,open=open}
                if open then
                    for _,place in ipairs(places) do list[#list+1]={key="P:"..place.id,id=place.id,item=place,name=place.name or "",zoneId=zone.id} end
                end
            end
        end
        return list
    end
    function win:AllPlacesSelected(zone)
        if not self.items["Z:"..zone.id] then return false end
        for _,place in ipairs(ZG:GetPlaceList(zone.id)) do if not self.items["P:"..place.id] then return false end end
        return true
    end
    -- Combien des joueurs cochés connaissent ce nom (ou combien de joueurs au total).
    function win:KnownText(item,selected)
        local known=item.grantedTo or {}
        if #selected==0 then
            local n=ZG:DiscoveryCount(item)
            return n>0 and string.format("connu de %d",n) or "inconnu de tous"
        end
        local n=0
        for _,name in ipairs(selected) do if known[name] then n=n+1 end end
        local color=(n==#selected and "66e673") or (n>0 and "e6c94d") or "888888"
        return string.format("|cff%sconnu %d/%d|r",color,n,#selected)
    end

    function win:Refresh()
        self.searchHint:SetShown(Trim(self.search:GetText())=="" and not self.search:HasFocus())
        local players=self:PlayerEntries()
        local selected=self:SelectedPlayers()
        -- Combien de noms chaque joueur connaît dans mes régions.
        local counts={}
        for _,zone in ipairs(ZG:GetZoneList()) do
            if zone.creator==Me() then
                for name in pairs(zone.grantedTo or {}) do counts[name]=(counts[name] or 0)+1 end
                for _,place in ipairs(ZG:GetPlaceList(zone.id)) do
                    for name in pairs(place.grantedTo or {}) do counts[name]=(counts[name] or 0)+1 end
                end
            end
        end
        self.playerList:Update(players,function(row,p,i)
            row.name=p.name
            row.bg:SetColorTexture(1,1,1,i%2==0 and .03 or 0)
            row.box:SetChecked(self.players[p.name] and true or false)
            row.text:SetText(p.name..(p.group and "  |cff888888groupe|r" or ""))
            row.info:SetText(counts[p.name] and (counts[p.name].." nom(s)") or "")
        end)
        self.playerList.more:SetText(#players==0 and "Personne : ajoutez un joueur par son nom ou formez un groupe." or self.playerList.more:GetText())

        local items=self:ItemEntries()
        self.itemList:Update(items,function(row,e,i)
            row.entry=e
            row.bg:SetColorTexture(1,1,1,e.region and .05 or (i%2==0 and .02 or 0))
            row.box:ClearAllPoints();row.text:ClearAllPoints()
            local indent=e.region and 28 or 52
            row.box:SetPoint("LEFT",indent,0);row.text:SetPoint("LEFT",indent+24,0)
            row.text:SetPoint("RIGHT",e.region and -214 or -110,0)
            row.box:SetChecked(self.items[e.key] and true or false)
            row.fold:SetShown(e.region and e.places>0)
            if e.region then
                row.fold.down:SetShown(not e.open)
                local count=e.places>0 and string.format("  |cff888888(%d lieu%s)|r",e.places,e.places>1 and "x" or "") or ""
                row.text:SetText("|cffe6c94d"..e.name.."|r"..(e.country and ("  |cff888888"..e.country.."|r") or "")..count)
                local zone=e.item
                row.all:SetText(self:AllPlacesSelected(zone) and "− ses lieux" or "+ ses lieux");row.all:Show()
            else
                row.text:SetText(e.name);row.all:Hide()
            end
            row.info:SetText(self:KnownText(e.item,selected))
        end)
        if #items==0 then
            self.itemList.more:SetText(Trim(self.search:GetText())~="" and "Aucun nom ne correspond." or "Vous n'avez encore créé aucune région.")
        end

        local n=0
        for _ in pairs(self.items) do n=n+1 end
        self.summary:SetText(string.format("Sélection : %d joueur(s) · %d nom(s)",#selected,n))
        local ready=#selected>0 and n>0
        learnBtn:SetEnabled(ready);forget:SetEnabled(ready)
    end

    -- Envoie à chaque joueur coché chaque nom coché ; ce qui est déjà
    -- dans l'état voulu n'est pas renvoyé.
    local function Apply(learn)
        local selected=win:SelectedPlayers()
        local sent,failures=0,0
        for key in pairs(win.items) do
            local scope,id=key:match("^(%a):(.+)$")
            local item=scope=="Z" and ZG:GetZone(id) or ZG:FindPlace(id)
            if item then
                for _,name in ipairs(selected) do
                    local knows=item.grantedTo and item.grantedTo[name] and true or false
                    if knows~=learn then
                        local method=learn and (scope=="Z" and "SendZoneGrant" or "SendPlaceGrant") or (scope=="Z" and "RevokeZoneGrant" or "RevokePlaceGrant")
                        if ZG[method](ZG,id,name) then sent=sent+1 else failures=failures+1 end
                    end
                end
            else
                win.items[key]=nil
            end
        end
        win:Refresh()
        if failures>0 then
            win.status:SetText(string.format("|cffe6c94d%d envoi(s) impossible(s). Les joueurs sont-ils connectés ?|r",failures))
        elseif sent==0 then
            win.status:SetText(learn and "Ces joueurs connaissaient déjà tous ces noms." or "Ces joueurs ne connaissaient aucun de ces noms.")
        else
            win.status:SetText(string.format(learn and "|cff66e673%d nom(s) appris.|r" or "|cff66e673%d nom(s) oublié(s).|r",sent))
        end
        if win.onChanged then win.onChanged() end
    end
    learnBtn:SetScript("OnClick",function() Apply(true) end)
    forget:SetScript("OnClick",function() Apply(false) end)
    groupBtn:SetScript("OnClick",function()
        for _,member in ipairs(ZG:DiscoveryRoster()) do win.players[member.key]=true end
        win:Refresh()
    end)
    noneBtn:SetScript("OnClick",function() win.players={};win:Refresh() end)

    win:RegisterEvent("GROUP_ROSTER_UPDATE")
    win:RegisterEvent("UNIT_CONNECTION")
    win:SetScript("OnEvent",function(self) if self:IsShown() then self:Refresh() end end)
    win:SetScript("OnHide",function(self) self.status:SetText("") end)
    UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"ZoneGateKnowledge")
    win.players,win.items,win.extra,win.open={},{},{},{}
end

-- Ouvre le panneau ; preset (facultatif) coche d'office une région
-- ({zone=id}) ou un lieu ({place=id}) et le fait apparaître dans la liste.
function ZG:OpenKnowledge(preset,onChanged)
    if not win then Build() end
    win.onChanged=onChanged
    win.status:SetText("")
    if preset then
        win.items={}
        local name
        if preset.zone then
            local zone=ZG:GetZone(preset.zone)
            if zone then win.items["Z:"..zone.id]=true;name=zone.name end
        elseif preset.place then
            local place=ZG:FindPlace(preset.place)
            if place then win.items["P:"..place.id]=true;name=place.name end
        end
        win.search:SetText(name or "")
    end
    win:Show();win:Refresh()
    return win
end

function ZG:ToggleKnowledge()
    if win and win:IsShown() then win:Hide() else ZG:OpenKnowledge() end
end
