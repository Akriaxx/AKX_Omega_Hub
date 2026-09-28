-- Raid messages carry a compact plain-text reference; Omega renders it as
-- a hyperlink locally. No unsupported custom hyperlink is sent to the server.
local C=Character
local UI=C.RPGUI or OS2.UI
local popup,edit,errorText,viewport

local function Signature(skill)
    return tostring(skill.name).."\0"..tostring(skill.icon).."\0"..tostring(skill.description).."\0"..tostring(skill.usable==true)..C:SkillCostKey(skill)
end
function C:SkillChatID(skill)
    local a,b=5381.0,7919.0
    local s=Signature(skill)
    for i=1,#s do a=(a*33+s:byte(i))%2147483647;b=(b*131+s:byte(i))%2147483629 end
    return string.format("%08x%08x",a,b)
end
function C:FindChatSkill(id)
    if not id or #id~=16 or id:find("[^0-9a-f]") then return end
    local found,signature
    local libraries={self:GetOwnedSkillLibrary()}
    for _,library in pairs(CharacterDB.skillLibraries or {}) do libraries[#libraries+1]=library.categories end
    for _,library in ipairs(libraries) do
    for _,cat in ipairs(self.SKILL_CATEGORIES) do
        for _,skill in pairs(library[cat.key] or {}) do
            if self:SkillChatID(skill)==id then
                local current=Signature(skill)
                if signature and signature~=current then return end
                found,signature=skill,current
            end
        end
    end
    end
    -- Fiche non partagée, déjà demandée à son auteur (voir plus bas).
    return found or (CharacterDB and CharacterDB.remoteSkills and CharacterDB.remoteSkills[id])
end
function C:SkillChatLink(skill,id)
    local name=self:StripSkillMarkup(skill.name):gsub("[|%[%]\r\n]","")
    return "|cffdfbf79|Homegaskill:"..id.."|h["..name.."]|h|r"
end
local COST_ORDER={"hp","mana","endurance"}
local COST_SHORT={hp="HP",mana="MP",endurance="End."}
local COST_TAG_PATTERN="%[Coût : %d[^%]]*%]"
-- Coût en abrégé, écrit en dernier dans l'émote : [Coût : 50 MP].
local function CostTag(resource,amount)
    return "[Coût : "..amount.." "..(COST_SHORT[resource] or "").."]"
end
function C:SkillCostTag(skill)
    local cost=skill and skill.cost
    if not cost then return end
    return CostTag(cost.resource,cost.amount)
end
-- Total par ressource des fiches utilisables d'une émote : { mana = 12, ... }.
function C:SkillCostTotals(skills)
    local totals={}
    for _,skill in ipairs(skills or {}) do
        local cost=skill.usable==true and skill.cost
        if cost and self:ValidateSkillCost(cost) then totals[cost.resource]=(totals[cost.resource] or 0)+cost.amount end
    end
    return totals
end
-- Retire tous les [Coût : …] du texte et remet le total à la fin, en une
-- seule étiquette : [Coût : 4 MP · 5 End.] (pas de « | » : réservé aux
-- codes de couleur/lien, un message de chat ne peut pas en contenir).
function C:ApplySkillCostTags(text,totals)
    text=text:gsub(COST_TAG_PATTERN,"")
    local parts={}
    for _,resource in ipairs(COST_ORDER) do
        if totals[resource] then parts[#parts+1]=totals[resource].." "..(COST_SHORT[resource] or "") end
    end
    if #parts==0 then return text end
    return text:gsub("%s+$","").." [Coût : "..table.concat(parts," · ").."]"
end
-- Fiche principale + fiches ajoutées (« Ajouter une action ») dont le lien est
-- encore dans le texte : une fiche ajoutée puis effacée n'est ni envoyée ni payée.
function C:SkillsInEmote(text,skill,extras)
    local used={skill}
    for _,extra in ipairs(extras or {}) do
        if text:find(self:SkillChatLink(extra,self:SkillChatID(extra)),1,true) then used[#used+1]=extra end
    end
    return used
end
local function RemovePlain(text,needle)
    local start,finish=text:find(needle,1,true)
    while start do
        text=text:sub(1,start-1)..text:sub(finish+1)
        start,finish=text:find(needle,start,true)
    end
    return text
end
-- Mise en forme finale : texte libre, puis toutes les fiches groupées entre
-- parenthèses (principale d'abord, puis les ajouts dans l'ordre), puis le
-- coût en conclusion : *Texte* ([Coup de Poing][Assaut]) [Coût : 4 MP].
-- Les liens déplacés ou collés au milieu du texte reviennent dans le groupe.
function C:ComposeSkillEmote(text,skill,extras)
    local used=self:SkillsInEmote(text,skill,extras)
    local links={}
    for i,entry in ipairs(used) do
        links[i]=self:SkillChatLink(entry,self:SkillChatID(entry))
        text=RemovePlain(text,links[i])
    end
    text=text:gsub(COST_TAG_PATTERN,""):gsub("%(%s*%)","")
    text=text:gsub("[ \t][ \t]+"," "):gsub("%s+$","")
    text=text..(text~="" and " " or "").."("..table.concat(links,"")..")"
    return self:ApplySkillCostTags(text,self:SkillCostTotals(used)),used
end
function C:PrepareSkillRaidMessage(text,skill,extras)
    if not self.enabled then return nil,"Character est désactivé." end
    if not skill or skill.usable~=true then return nil,"Cette entrée n’est pas utilisable." end
    if not IsInRaid() then return nil,"Rejoignez un raid pour envoyer cette émote." end
    local hyperlink=self:SkillChatLink(skill,self:SkillChatID(skill))
    if not text:find(hyperlink,1,true) then return nil,"Conservez le lien de la fiche dans votre émote." end
    local used
    text,used=self:ComposeSkillEmote(text,skill,extras)
    for _,entry in ipairs(used) do
        local id=self:SkillChatID(entry)
        local link,marker=self:SkillChatLink(entry,id),"[Omega:"..id.."]"
        local start,finish=text:find(link,1,true)
        while start do
            text=text:sub(1,start-1)..marker..text:sub(finish+1)
            start,finish=text:find(link,start+#marker,true)
        end
    end
    text=text:gsub("[\r\n]+"," ")
    if text:find("[|]") then return nil,"Retirez le caractère « | » de votre texte." end
    -- Le coût termine toujours l'émote, même déplacé ou effacé à la saisie
    -- (déjà remis en place par ComposeSkillEmote).
    return text,nil,used
end
-- Split on words where possible, never inside UTF-8 or an Omega reference.
function C:SplitSkillRaidMessage(text)
    local chunks={}
    while #text>255 do
        local cut=255
        local start,finish=text:find("%[Omega:[0-9a-f]+%]")
        if start and start<=cut and finish>cut then cut=start-1 end
        while cut>0 and text:byte(cut+1)>=128 and text:byte(cut+1)<192 do cut=cut-1 end
        local space=text:sub(1,cut):match(".*()%s")
        if space and space>cut/2 then cut=space end
        chunks[#chunks+1]=text:sub(1,cut)
        text=text:sub(cut+1)
    end
    if #text>0 then chunks[#chunks+1]=text end
    return chunks
end
local outgoing,busy={},false
local function SendNext()
    if not C.enabled or not IsInRaid() then outgoing={};busy=false;return end
    local message=table.remove(outgoing,1)
    if not message then busy=false;return end
    SendChatMessage(message,"RAID")
    C_Timer.After(.8,SendNext)
end
function C:SendSkillRaidMessage(message)
    for _,chunk in ipairs(self:SplitSkillRaidMessage(message)) do outgoing[#outgoing+1]=chunk end
    if not busy then busy=true;SendNext() end
end
-- Réservation affichée sur le HUD : { mana = 7, endurance = 3 } (un coût
-- seul {resource, amount} est aussi accepté).
function C:SetSkillCostReservation(costs)
    if costs and costs.resource then costs={[costs.resource]=costs.amount} end
    self.skillCostReservation=costs and next(costs) and costs or nil
    if CharacterResourceHUD and CharacterResourceHUD.Refresh then CharacterResourceHUD:Refresh() end
end
function C:CanPaySkillCost(cost)
    if not cost then return true end
    if not self:ValidateSkillCost(cost) then return false end
    local stat=self:GetMyChar()[cost.resource]
    return stat and (stat.cur or 0)+(stat.temp or 0)>=cost.amount
end
-- « L’Endurance n’est pas suffisante… » : la ressource dans sa couleur de jauge.
local SHORTFALL={
    hp={"La ","Vie","statHP","e"},mana={"Le ","Mana","statMana",""},endurance={"L’","Endurance","statEnd","e"},
}
function C:SkillCostShortfallText(cost)
    local entry=SHORTFALL[cost and cost.resource] or SHORTFALL.mana
    local color=(UI.colors[entry[3]] or {}).fg or {1,1,1}
    local hex=string.format("%02x%02x%02x",math.floor(color[1]*255+.5),math.floor(color[2]*255+.5),math.floor(color[3]*255+.5))
    return entry[1].."|cff"..hex..entry[2].."|r n’est pas suffisant"..entry[4].." pour utiliser ceci."
end
-- Raison du grisage (survol), ou nil si la compétence est payable.
function C:SkillCostBlockedText(skill)
    local cost=skill and skill.cost
    if skill and skill.usable==true and cost and not self:CanPaySkillCost(cost) then
        return self:SkillCostShortfallText(cost)
    end
end
-- ── « Ajouter une action » ────────────────────────────────────────────────
-- Choix multiple parmi les actions visibles du bouton Action (celles que le
-- joueur a gardées), l'Index et les États ; chaque fiche choisie est insérée
-- comme lien au curseur. Une fiche utilisable ajoutée est aussi payée.
local picker
local PICK_W,PICK_H,PICK_ROW=300,360,22

local function PickerEntries(query)
    local list={}
    query=(query or ""):lower()
    local mainID=popup.skill and C:SkillChatID(popup.skill)
    for _,cat in ipairs(C.SKILL_CATEGORIES) do
        local skills=cat.hidden and C:ListAllSkills(cat.key) or C:ListActionSkills(cat.key)
        local rows={}
        for _,skill in ipairs(skills) do
            local plain=C:StripSkillMarkup(skill.name)
            local id=C:SkillChatID(skill)
            if id~=mainID and (query=="" or plain:lower():find(query,1,true)) then
                rows[#rows+1]={skill=skill,id=id}
            end
        end
        if #rows>0 then
            list[#list+1]={header=cat.label}
            for _,row in ipairs(rows) do list[#list+1]=row end
        end
    end
    return list
end

local function RefreshReservation()
    if not popup or not popup.skill then return end
    C:SetSkillCostReservation(C:SkillCostTotals(C:SkillsInEmote(edit:GetText(),popup.skill,popup.extras)))
end

local function InsertSkills(skills)
    local links={}
    for _,skill in ipairs(skills) do
        local id=C:SkillChatID(skill)
        local known=false
        for _,extra in ipairs(popup.extras) do if C:SkillChatID(extra)==id then known=true end end
        if not known then popup.extras[#popup.extras+1]=skill end
        links[#links+1]=C:SkillChatLink(skill,id)
    end
    if #links==0 then return end
    -- Toujours à la fin du groupe ( … ), avant le coût : voir ComposeSkillEmote.
    local text=edit:GetText()
    local pos=edit:GetCursorPosition() or #text
    edit:SetText((C:ComposeSkillEmote(text.." "..table.concat(links," "),popup.skill,popup.extras)))
    local free=edit:GetText():find(" %(|c") or #edit:GetText()
    edit:SetCursorPosition(math.max(0,math.min(pos,free-1)))
    RefreshReservation()
end

local function BuildPicker()
    picker=CreateFrame("Frame","CharacterSkillUsePicker",popup)
    picker:SetSize(PICK_W,PICK_H);picker:SetPoint("TOPLEFT",popup,"TOPRIGHT",8,0)
    picker:SetFrameStrata("DIALOG");picker:SetFrameLevel(popup:GetFrameLevel()+10)
    picker:SetClampedToScreen(true);picker:EnableMouse(true);picker:Hide()
    local bg=picker:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();UI.ApplyWindowBackground(bg)
    if UI.ApplyBorder then UI.ApplyBorder(picker) end
    local title=picker:CreateFontString(nil,"OVERLAY","GameFontNormal")
    title:SetPoint("TOPLEFT",12,-8);title:SetText("Ajouter une action");UI.ApplyTitle(title)
    local close=C:CreateRoundCloseButton(picker,function() picker:Hide() end)
    close:ClearAllPoints();close:SetPoint("TOPRIGHT",-6,-5)
    local search=UI.CreateStyledEditBox(picker,PICK_W-24,22)
    search:SetPoint("TOPLEFT",12,-32);search:SetAutoFocus(false)
    picker.search=search
    local scroll=CreateFrame("ScrollFrame",nil,picker)
    scroll:SetPoint("TOPLEFT",12,-60);scroll:SetPoint("BOTTOMRIGHT",-12,40)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(PICK_W-24,1);scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(self,d)
        local range=math.max(0,content:GetHeight()-self:GetHeight())
        self:SetVerticalScroll(math.max(0,math.min(range,self:GetVerticalScroll()-d*PICK_ROW*2)))
    end)
    picker.scroll,picker.content,picker.rows=scroll,content,{}
    picker.selected,picker.order={},{}
    local add=UI.CreatePanelButton(picker,PICK_W-24,22,"Ajouter")
    add:SetPoint("BOTTOMLEFT",12,10)
    picker.add=add
    add:SetScript("OnClick",function()
        local skills={}
        for _,id in ipairs(picker.order) do if picker.selected[id] then skills[#skills+1]=picker.selected[id] end end
        picker.selected,picker.order={},{}
        picker:Hide()
        edit:SetFocus()
        InsertSkills(skills)
    end)
    -- Nouvelle recherche : retour en haut, sinon les résultats (moins
    -- nombreux) restaient sous la zone visible si la liste était défilée.
    search:SetScript("OnTextChanged",function() scroll:SetVerticalScroll(0);picker:Refresh() end)
    search:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)

    local function Row(i)
        local row=picker.rows[i]
        if row then return row end
        row=CreateFrame("Button",nil,content)
        row:SetHeight(PICK_ROW)
        row:SetPoint("TOPLEFT",0,-(i-1)*PICK_ROW);row:SetPoint("TOPRIGHT",0,-(i-1)*PICK_ROW)
        row.bg=row:CreateTexture(nil,"BACKGROUND");row.bg:SetPoint("TOPLEFT",0,-1);row.bg:SetPoint("BOTTOMRIGHT",0,1)
        row.check=row:CreateTexture(nil,"ARTWORK");row.check:SetSize(14,14);row.check:SetPoint("LEFT",4,0)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.icon=row:CreateTexture(nil,"ARTWORK");row.icon:SetSize(16,16);row.icon:SetPoint("LEFT",22,0)
        row.icon:SetTexCoord(.08,.92,.08,.92)
        row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        row.text:SetPoint("LEFT",42,0);row.text:SetPoint("RIGHT",-4,0);row.text:SetJustifyH("LEFT");row.text:SetWordWrap(false)
        row:SetScript("OnClick",function(self)
            local entry=self.entry
            if not entry or entry.header then return end
            if picker.selected[entry.id] then
                picker.selected[entry.id]=nil
            else
                picker.selected[entry.id]=entry.skill
                picker.order[#picker.order+1]=entry.id
            end
            picker:Refresh()
        end)
        picker.rows[i]=row
        return row
    end

    function picker:Refresh()
        local entries=PickerEntries(search:GetText())
        for i,entry in ipairs(entries) do
            local row=Row(i)
            row.entry=entry
            if entry.header then
                row.bg:SetColorTexture(0,0,0,0);row.check:Hide();row.icon:Hide()
                row.text:SetPoint("LEFT",4,0);row.text:SetText(entry.header);UI.ApplyTitle(row.text)
            else
                local on=self.selected[entry.id]~=nil
                row.bg:SetColorTexture(unpack(on and UI.colors.rowBgSelected or UI.colors.rowBg))
                row.check:SetShown(on);row.icon:Show();row.icon:SetTexture(C:ResolveIconValue(entry.skill.icon))
                row.text:SetPoint("LEFT",42,0);row.text:SetText(C:RenderSkillName(entry.skill.name));row.text:SetTextColor(1,1,1)
            end
            row:Show()
        end
        for i=#entries+1,#self.rows do self.rows[i]:Hide();self.rows[i].entry=nil end
        content:SetHeight(math.max(1,#entries*PICK_ROW))
        local range=math.max(0,#entries*PICK_ROW-(scroll:GetHeight() or 0))
        if scroll:GetVerticalScroll()>range then scroll:SetVerticalScroll(range) end
        local count=0
        for _ in pairs(self.selected) do count=count+1 end
        self.add:SetText(count>0 and ("Ajouter ("..count..")") or "Ajouter")
        self.add:SetEnabled(count>0)
    end
end

function C:OpenSkillUsePicker()
    if not popup or not popup:IsShown() then return end
    if not picker then BuildPicker() end
    if picker:IsShown() then picker:Hide();return end
    picker.selected,picker.order={},{}
    picker.search:SetText("")
    picker.scroll:SetVerticalScroll(0)
    picker:Refresh()
    picker:Show()
end

function C:OpenSkillUse(skill)
    if not self.enabled or not skill or skill.usable~=true then return end
    if self:SkillCostBlockedText(skill) then return end
    self:HideSkillTooltip()
    if popup then popup:Hide() end
    if not popup then
        popup=CreateFrame("Frame","CharacterSkillUsePopup",UIParent)
        popup:SetSize(540,302);popup:SetPoint("CENTER");popup:SetFrameStrata("DIALOG")
        popup:SetClampedToScreen(true);popup:EnableMouse(true)
        if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]="CharacterSkillUsePopup" end
        local bg=popup:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();UI.ApplyWindowBackground(bg)
        local title=popup:CreateFontString(nil,"OVERLAY","GameFontNormal")
        title:SetPoint("TOPLEFT",12,-8);title:SetText("Utiliser — émote en raid");UI.ApplyTitle(title)
        -- Barre de titre : glisser pour déplacer la fenêtre (la croix reste cliquable).
        popup:SetMovable(true)
        local header=CreateFrame("Frame",nil,popup)
        header:SetPoint("TOPLEFT",0,0);header:SetPoint("TOPRIGHT",-32,0);header:SetHeight(30)
        header:EnableMouse(true);header:RegisterForDrag("LeftButton")
        header:SetScript("OnDragStart",function() popup:StartMoving() end)
        header:SetScript("OnDragStop",function() popup:StopMovingOrSizing() end)
        popup.header=header
        local close=C:CreateRoundCloseButton(popup,function() popup:Hide() end)
        close:SetPoint("TOPRIGHT",-6,-5)
        viewport=CreateFrame("ScrollFrame",nil,popup)
        viewport:SetPoint("TOPLEFT",12,-36);viewport:SetSize(516,198)
        local field=viewport:CreateTexture(nil,"BACKGROUND")
        field:SetAllPoints();field:SetColorTexture(.012,.019,.028,1);UI.ApplyInputBorder(viewport)
        edit=CreateFrame("EditBox",nil,viewport)
        edit:SetSize(516,198);edit:SetMultiLine(true);edit:SetAutoFocus(false)
        edit:SetFontObject("GameFontHighlight");edit:SetTextInsets(10,10,8,8)
        edit:SetMaxLetters(0);edit:SetMaxBytes(0)
        viewport:SetScrollChild(edit);viewport:EnableMouseWheel(true);viewport:EnableMouse(true)
        viewport:SetScript("OnMouseDown",function() edit:SetFocus() end)
        viewport:SetScript("OnMouseWheel",function(self,d)
            self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-d*30)))
        end)
        edit:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local top=math.abs(y);local scroll=viewport:GetVerticalScroll()
            if top<scroll then viewport:SetVerticalScroll(top)
            elseif top+height>scroll+198 then viewport:SetVerticalScroll(math.max(0,top+height-198)) end
        end)
        popup.edit=edit
        local hint=popup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        hint:SetPoint("TOPLEFT",12,-242);hint:SetWidth(516);hint:SetJustifyH("LEFT")
        hint:SetText("Les fiches et le coût se placent à la fin · N'oubliez pas vos astérisques · Entrée : envoyer · Échap : annuler")
        UI.ApplyMutedText(hint)
        errorText=popup:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        errorText:SetPoint("TOPLEFT",12,-270);errorText:SetWidth(340);errorText:SetJustifyH("LEFT")
        local addAction=UI.CreatePanelButton(popup,160,22,"Ajouter une action")
        addAction:SetPoint("BOTTOMRIGHT",-12,10)
        addAction:SetScript("OnClick",function() C:OpenSkillUsePicker() end)
        popup.addAction=addAction
        errorText:SetTextColor(1,.4,.3)
        edit:SetScript("OnEscapePressed",function() popup:Hide() end)
        edit:SetScript("OnEnterPressed",function()
            local message,err,used=C:PrepareSkillRaidMessage(edit:GetText(),popup.skill,popup.extras)
            if not message then errorText:SetText(err);return end
            -- Garde-fou : la ressource a pu baisser pendant la saisie (total
            -- de la fiche et des actions ajoutées, ressource par ressource).
            local totals=C:SkillCostTotals(used)
            for _,resource in ipairs(COST_ORDER) do
                local cost=totals[resource] and {resource=resource,amount=totals[resource]}
                if cost and not C:CanPaySkillCost(cost) then errorText:SetText(C:SkillCostShortfallText(cost));return end
            end
            -- Commit once, only after message validation; cancel never edits stats.
            C:SetSkillCostReservation(nil)
            for _,resource in ipairs(COST_ORDER) do
                if totals[resource] then C:Delta(resource,-totals[resource],true) end
            end
            C:SendSkillRaidMessage(message)
            popup:Hide()
        end)
        edit:SetScript("OnTextChanged",function(_,user) if user then RefreshReservation() end end)
        popup:SetScript("OnHide",function()
            edit:ClearFocus();popup.skill=nil;popup.extras=nil;C:SetSkillCostReservation(nil)
            if picker then picker:Hide() end
        end)
    end
    popup.skill=skill
    popup.extras={}
    local link=self:SkillChatLink(skill,self:SkillChatID(skill))
    errorText:SetText("")
    local placeholder="Votre émote ici."
    edit:SetText((self:ComposeSkillEmote("*"..placeholder.."* "..link,skill,{})));viewport:SetVerticalScroll(0)
    -- Texte d'exemple déjà sélectionné entre les astérisques : il suffit
    -- d'écrire (positions en octets, comme l'EditBox de WoW).
    popup:Show();self:SetSkillCostReservation(self:SkillCostTotals({skill}));edit:SetFocus()
    edit:SetCursorPosition(1+#placeholder);edit:HighlightText(1,1+#placeholder)
end

-- author : expéditeur de l'émote. Une fiche qu'on ne possède pas (entrée
-- non partagée) garde son nom dans le lien, pour la lui demander au clic.
function C:FilterSkillRaidMessage(message,author)
    return (message:gsub("%[Omega:([0-9a-f]+)%]",function(id)
        local skill=self:FindChatSkill(id)
        if skill then return self:SkillChatLink(skill,id) end
        if #id==16 then
            local from=author and author:gsub("[|:]","") or ""
            return "|cffdfbf79|Homegaskill:"..id..(from~="" and (":"..from) or "").."|h["..(from~="" and "Fiche Omega" or "Fiche Omega indisponible").."]|h|r"
        end
    end))
end
if ChatFrame_AddMessageEventFilter then
    for _,event in ipairs({"CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER"}) do
        ChatFrame_AddMessageEventFilter(event,function(_,_,message,author,...)
            if not C.enabled then return end
            return false,C:FilterSkillRaidMessage(message,author),author,...
        end)
    end
end

-- ── Fiches non partagées : demandées à l'auteur ─────────────────────────────
-- Une émote ne transporte que l'identifiant d'une fiche. Si on ne l'a pas
-- (l'auteur ne l'a pas partagée), un clic la demande à l'auteur en message
-- d'addon privé ; elle est gardée en cache (l'identifiant dépend du contenu,
-- une fiche modifiée a un autre identifiant). Ses références {{Tag : Nom}}
-- se demandent de la même façon, et l'auteur ne répond qu'aux références
-- présentes dans une fiche qu'il a déjà envoyée à ce joueur.
local FETCH_PREFIX,FETCH_CHUNK,FETCH_TIMEOUT,CACHE_MAX="OmegaFiche",200,8,300
local fetchFrame=CreateFrame("Frame")
fetchFrame:Hide()
local fetchQueue,pending,allowedRefs,refCache,refPending={}, {}, {}, {}, {}
local fetchClock,reqSeq=0,0

local function FullName(name)
    if not name or name=="" then return "" end
    if name:find("-",1,true) then return name end
    return name.."-"..(GetRealmName() or ""):gsub("%s","")
end
local function InGroup(sender)
    local short=Ambiguate and Ambiguate(sender,"none") or sender
    return (UnitInRaid and UnitInRaid(short)) or (UnitInParty and UnitInParty(short))
end
local function RefKey(catKey,name)
    return catKey..":"..C:StripSkillMarkup(name or ""):lower():match("^%s*(.-)%s*$")
end
local function Field(value)
    value=tostring(value or "")
    return #value..":"..value
end
local function ReadFields(text)
    local out,pos={},1
    while pos<=#text do
        local len,start=text:match("^(%d+):()",pos)
        if not len then return nil end
        len=tonumber(len)
        out[#out+1]=text:sub(start,start+len-1)
        pos=start+len
    end
    return out
end
local function EncodeRemote(skill)
    local cost=skill.cost
    return Field(skill.name)..Field(skill.icon)..Field(skill.description)..Field(cost and cost.resource)..Field(cost and cost.amount)
end
local function DecodeRemote(payload,author)
    local f=ReadFields(payload)
    if not f or #f<5 or f[1]=="" or #f[1]>128 or #f[3]>8000 then return nil end
    local skill={name=f[1],icon=f[2]~="" and f[2] or nil,description=f[3],usable=false,author=author,remote=true}
    local amount=tonumber(f[5])
    if f[4]~="" and amount then skill.cost={resource=f[4],amount=amount} end
    return skill
end

local function Queue(message,target)
    if #fetchQueue>2000 then return end
    fetchQueue[#fetchQueue+1]={message,target}
    fetchFrame:Show()
end
fetchFrame:SetScript("OnUpdate",function(self,dt)
    fetchClock=fetchClock+dt
    if fetchClock<.1 then return end
    fetchClock=0
    local item=table.remove(fetchQueue,1)
    if item and C.enabled then C_ChatInfo.SendAddonMessage(FETCH_PREFIX,item[1],"WHISPER",item[2]) end
    local now=GetTime()
    for req,p in pairs(pending) do
        if p.expires<now then pending[req]=nil;p.done(nil) end
    end
    if #fetchQueue==0 and not next(pending) then self:Hide() end
end)

local function Request(author,query,done)
    reqSeq=reqSeq+1
    local req=tostring(reqSeq)
    pending[req]={author=FullName(author),chunks={},count=0,done=done,expires=GetTime()+FETCH_TIMEOUT}
    Queue("Q|"..req.."|"..query,author)
end

-- Côté auteur : les références d'une fiche envoyée deviennent demandables.
local function AllowRefs(sender,skill)
    local allowed=allowedRefs[sender] or {}
    allowedRefs[sender]=allowed
    for tag,name in tostring(skill.description or ""):gmatch("{{%s*([^:{}]-)%s*:%s*([^{}]-)%s*}}") do
        local cat=C:ResolveCategoryByTag(tag)
        if cat then allowed[RefKey(cat.key,name)]=true end
    end
end
local function Reply(sender,req,skill)
    if not skill then Queue("N|"..req,sender);return end
    AllowRefs(sender,skill)
    local payload=EncodeRemote(skill)
    local total=math.max(1,math.ceil(#payload/FETCH_CHUNK))
    for i=1,total do
        Queue("A|"..req.."|"..i.."|"..total.."|"..payload:sub((i-1)*FETCH_CHUNK+1,i*FETCH_CHUNK),sender)
    end
end

fetchFrame:RegisterEvent("CHAT_MSG_ADDON")
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(FETCH_PREFIX) end
fetchFrame:SetScript("OnEvent",function(_,_,prefix,message,channel,sender)
    if prefix~=FETCH_PREFIX or channel~="WHISPER" or not C.enabled or #message>255 then return end
    sender=FullName(sender)
    local req,kind,a,b=message:match("^Q|(%d+)|(%a)|([^|]*)|?(.*)$")
    if req then
        if not InGroup(sender) then return end
        if kind=="I" then
            Reply(sender,req,a:match("^[0-9a-f]+$") and C:FindChatSkill(a) or nil)
        elseif kind=="R" then
            local allowed=allowedRefs[sender]
            local skill=allowed and allowed[RefKey(a,b)] and C:ResolveNumberedSkillRef(a,b) or nil
            Reply(sender,req,skill)
        end
        return
    end
    local nreq=message:match("^N|(%d+)$")
    if nreq then
        local p=pending[nreq]
        if p and p.author==sender then pending[nreq]=nil;p.done(nil) end
        return
    end
    local areq,index,total,chunk=message:match("^A|(%d+)|(%d+)|(%d+)|(.*)$")
    local p=areq and pending[areq]
    if not p or p.author~=sender then return end
    index,total=tonumber(index),tonumber(total)
    if total<1 or total>60 or index<1 or index>total then return end
    if not p.chunks[index] then p.chunks[index]=chunk;p.count=p.count+1 end
    if p.count>=total then
        pending[areq]=nil
        p.done(DecodeRemote(table.concat(p.chunks,"",1,total),sender))
    end
end)

local UNAVAILABLE="L’auteur n’a pas pu l’envoyer (hors ligne, hors du groupe ou fiche supprimée)."

-- Fiche d'une émote, par identifiant : cache, sinon demande à l'auteur.
function C:FetchChatSkill(id,author,done)
    CharacterDB.remoteSkills=CharacterDB.remoteSkills or {}
    local cache=CharacterDB.remoteSkills
    Request(author,"I|"..id,function(skill)
        if skill then
            local n=0;for _ in pairs(cache) do n=n+1 end
            if n>=CACHE_MAX then cache[next(cache)]=nil end
            cache[id]=skill
        end
        done(skill)
    end)
end

-- Référence {{Tag : Nom}} dans une fiche reçue : renvoie la fiche en cache,
-- sinon une carte « Chargement… » rafraîchie à l'arrivée (RefreshSkillCardsFor).
function C:RemoteSkillRef(author,catKey,name)
    local key=author.."\0"..RefKey(catKey,name)
    local cached=refCache[key]
    if cached then return cached end
    if cached==false then return {name=name,missing=true,missingText=UNAVAILABLE} end
    local loadKey="ref:"..key
    if not refPending[key] then
        refPending[key]=true
        Request(author,"R|"..catKey.."|"..name,function(skill)
            refPending[key]=nil
            refCache[key]=skill or false
            self:RefreshSkillCardsFor(loadKey,skill or {name=name,missing=true,missingText=UNAVAILABLE})
        end)
    end
    return {name=name,loading=true,loadKey=loadKey}
end
-- Intercept only our links; all native links retain their original handler.
local chatAnchor
if ChatFrame_OnHyperlinkShow then
    local original=ChatFrame_OnHyperlinkShow
    ChatFrame_OnHyperlinkShow=function(frame,hyperlink,...)
        local id,author=hyperlink and hyperlink:match("^omegaskill:([0-9a-f]+):?(.*)$")
        if not id then return original(frame,hyperlink,...) end
        if not C.enabled then return end
        local skill=C:FindChatSkill(id)
        if not skill and author~="" then
            local loadKey="id:"..id
            skill={name="Fiche Omega",loading=true,loadKey=loadKey}
            C:FetchChatSkill(id,author,function(found)
                C:RefreshSkillCardsFor(loadKey,found or {name="Fiche indisponible",missing=true,missingText=UNAVAILABLE})
            end)
        end
        -- Capture the click position, not the top of the entire chat window.
        -- The anchor stays still so the mouse can enter the card and its links.
        if not chatAnchor then
            chatAnchor=CreateFrame("Frame",nil,UIParent)
            chatAnchor.isSkillChatAnchor=true
            chatAnchor:SetSize(1,1);chatAnchor:EnableMouse(false)
        end
        local x,y=GetCursorPosition()
        local scale=UIParent:GetEffectiveScale()
        chatAnchor:ClearAllPoints()
        chatAnchor:SetPoint("CENTER",UIParent,"BOTTOMLEFT",x/scale,y/scale+8)
        chatAnchor:Show()
        C:HideSkillTooltip()
        C:ShowSkillTooltip(chatAnchor,skill or {name="Fiche indisponible",missing=true})
    end
end
