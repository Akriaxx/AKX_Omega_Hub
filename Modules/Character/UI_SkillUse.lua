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
function C:PrepareSkillRaidMessage(text,skill)
    if not self.enabled then return nil,"Character est désactivé." end
    if not skill or skill.usable~=true then return nil,"Cette entrée n’est pas utilisable." end
    if not IsInRaid() then return nil,"Rejoignez un raid pour envoyer cette émote." end
    local id=self:SkillChatID(skill)
    local hyperlink=self:SkillChatLink(skill,id)
    local marker="[Omega:"..id.."]"
    local start,finish=text:find(hyperlink,1,true)
    if not start then return nil,"Conservez le lien de la fiche dans votre émote." end
    text=text:sub(1,start-1)..marker..text:sub(finish+1)
    text=text:gsub("[\r\n]+"," ")
    if text:find("[|]") then return nil,"Utilisez du texte simple autour du lien." end
    -- Le coût termine toujours l'émote, même déplacé ou effacé à la saisie.
    local tag=self:SkillCostTag(skill)
    if tag then
        local start,finish=text:find(tag,1,true)
        while start do
            text=text:sub(1,start-1)..text:sub(finish+1)
            start,finish=text:find(tag,1,true)
        end
        text=text:gsub("%s+$","").." "..tag
    end
    return text
end
-- Coût en abrégé, écrit en dernier dans l'émote : [Coût : 50 MP].
function C:SkillCostTag(skill)
    local cost=skill and skill.cost
    if not cost then return end
    return "[Coût : "..cost.amount.." "..(({hp="HP",mana="MP",endurance="End."})[cost.resource] or "").."]"
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
function C:SetSkillCostReservation(cost)
    self.skillCostReservation=cost and {resource=cost.resource,amount=cost.amount} or nil
    if CharacterResourceHUD and CharacterResourceHUD.Refresh then CharacterResourceHUD:Refresh() end
end
function C:CanPaySkillCost(cost)
    if not cost then return true end
    if not self:ValidateSkillCost(cost) then return false end
    local stat=self:GetMyChar()[cost.resource]
    return stat and (stat.cur or 0)+(stat.temp or 0)>=cost.amount
end
-- « La Vie n'est pas suffisante… » : la ressource dans sa couleur de jauge.
local SHORTFALL={
    hp={"La ","Vie","statHP","e"},mana={"Le ","Mana","statMana",""},endurance={"L’","Endurance","statEnd","e"},
}
function C:SkillCostShortfallText(cost)
    local entry=SHORTFALL[cost and cost.resource] or SHORTFALL.mana
    local color=(UI.colors[entry[3]] or {}).fg or {1,1,1}
    local hex=string.format("%02x%02x%02x",math.floor(color[1]*255+.5),math.floor(color[2]*255+.5),math.floor(color[3]*255+.5))
    return entry[1].."|cff"..hex..entry[2].."|r n’est pas suffisant"..entry[4].." pour lancer cette compétence."
end
function C:OpenSkillUse(skill)
    if not self.enabled or not skill or skill.usable~=true then return end
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
        errorText:SetPoint("TOPLEFT",12,-270);errorText:SetWidth(516)
        errorText:SetTextColor(1,.4,.3)
        edit:SetScript("OnEscapePressed",function() popup:Hide() end)
        edit:SetScript("OnEnterPressed",function()
            local message,err=C:PrepareSkillRaidMessage(edit:GetText(),popup.skill)
            if not message then errorText:SetText(err);return end
            local cost=popup.skill.cost
            if not C:CanPaySkillCost(cost) then errorText:SetText(C:SkillCostShortfallText(cost));return end
            -- Commit once, only after message validation; cancel never edits stats.
            C:SetSkillCostReservation(nil)
            if cost then C:Delta(cost.resource,-cost.amount,true) end
            C:SendSkillRaidMessage(message)
            popup:Hide()
        end)
        popup:SetScript("OnHide",function() edit:ClearFocus();popup.skill=nil;C:SetSkillCostReservation(nil) end)
    end
    popup.skill=skill
    local link=self:SkillChatLink(skill,self:SkillChatID(skill))
    errorText:SetText("");local tag=self:SkillCostTag(skill)
    local placeholder="Votre émote ici."
    edit:SetText("*"..placeholder.."* "..link..(tag and (" "..tag) or ""));viewport:SetVerticalScroll(0)
    -- Texte d'exemple déjà sélectionné entre les astérisques : il suffit
    -- d'écrire (positions en octets, comme l'EditBox de WoW).
    popup:Show();self:SetSkillCostReservation(skill.cost);edit:SetFocus()
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
