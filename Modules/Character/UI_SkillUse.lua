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
    return found
end
function C:SkillChatLink(skill,id)
    local name=self:StripSkillMarkup(skill.name):gsub("[|%[%]\r\n]","")
    return "|cffdfbf79|Homegaskill:"..id.."|h["..name.."]|h|r"
end
local COST_ORDER={"hp","mana","endurance"}
local COST_SHORT={hp="HP",mana="MP",endurance="End."}
local COST_TAG_PATTERN="%[Coût : %d+ [^%]]*%]"
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
-- Retire tous les [Coût : …] du texte et remet les totaux à la fin.
function C:ApplySkillCostTags(text,totals)
    text=text:gsub(COST_TAG_PATTERN,"")
    local tags={}
    for _,resource in ipairs(COST_ORDER) do
        if totals[resource] then tags[#tags+1]=CostTag(resource,totals[resource]) end
    end
    if #tags==0 then return text end
    return text:gsub("%s+$","").." "..table.concat(tags," ")
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
function C:PrepareSkillRaidMessage(text,skill,extras)
    if not self.enabled then return nil,"Character est désactivé." end
    if not skill or skill.usable~=true then return nil,"Cette entrée n’est pas utilisable." end
    if not IsInRaid() then return nil,"Rejoignez un raid pour envoyer cette émote." end
    local hyperlink=self:SkillChatLink(skill,self:SkillChatID(skill))
    if not text:find(hyperlink,1,true) then return nil,"Conservez le lien de la fiche dans votre émote." end
    local used=self:SkillsInEmote(text,skill,extras)
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
    if text:find("[|]") then return nil,"Utilisez du texte simple autour du lien." end
    -- Le coût termine toujours l'émote, même déplacé ou effacé à la saisie.
    return self:ApplySkillCostTags(text,self:SkillCostTotals(used)),nil,used
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
    local text=edit:GetText()
    local pos=math.max(0,math.min(#text,edit:GetCursorPosition() or #text))
    local before,after=text:sub(1,pos),text:sub(pos+1)
    local insert=table.concat(links," ")
    if before~="" and not before:find("%s$") then insert=" "..insert end
    if after~="" and not after:find("^%s") then insert=insert.." " end
    text=before..insert..after
    local used=C:SkillsInEmote(text,popup.skill,popup.extras)
    edit:SetText(C:ApplySkillCostTags(text,C:SkillCostTotals(used)))
    edit:SetCursorPosition(math.min(#edit:GetText(),#before+#insert))
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
    search:SetScript("OnTextChanged",function() picker:Refresh() end)
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
        hint:SetText("Écrivez avant ou après le lien · N'oubliez pas vos astérisques · Entrée : envoyer · Échap : annuler")
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
    errorText:SetText("");local tag=self:SkillCostTag(skill)
    local placeholder="Votre émote ici."
    edit:SetText("*"..placeholder.."* "..link..(tag and (" "..tag) or ""));viewport:SetVerticalScroll(0)
    -- Texte d'exemple déjà sélectionné entre les astérisques : il suffit
    -- d'écrire (positions en octets, comme l'EditBox de WoW).
    popup:Show();self:SetSkillCostReservation(self:SkillCostTotals({skill}));edit:SetFocus()
    edit:SetCursorPosition(1+#placeholder);edit:HighlightText(1,1+#placeholder)
end

function C:FilterSkillRaidMessage(message)
    return (message:gsub("%[Omega:([0-9a-f]+)%]",function(id)
        local skill=self:FindChatSkill(id)
        if skill then return self:SkillChatLink(skill,id) end
        if #id==16 then return "|cffdfbf79|Homegaskill:"..id.."|h[Fiche Omega indisponible]|h|r" end
    end))
end
if ChatFrame_AddMessageEventFilter then
    for _,event in ipairs({"CHAT_MSG_RAID","CHAT_MSG_RAID_LEADER"}) do
        ChatFrame_AddMessageEventFilter(event,function(_,_,message,...)
            if not C.enabled then return end
            return false,C:FilterSkillRaidMessage(message),...
        end)
    end
end
-- Intercept only our links; all native links retain their original handler.
local chatAnchor
if ChatFrame_OnHyperlinkShow then
    local original=ChatFrame_OnHyperlinkShow
    ChatFrame_OnHyperlinkShow=function(frame,hyperlink,...)
        local id=hyperlink and hyperlink:match("^omegaskill:([0-9a-f]+)$")
        if not id then return original(frame,hyperlink,...) end
        if not C.enabled then return end
        local skill=C:FindChatSkill(id)
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
