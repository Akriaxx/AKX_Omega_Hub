-- Raid messages carry a compact plain-text reference; Omega renders it as
-- a hyperlink locally. No unsupported custom hyperlink is sent to the server.
local C=Character
local UI=C.RPGUI or OS2.UI
local popup,edit,errorText,viewport

local function Signature(skill)
    return tostring(skill.name).."\0"..tostring(skill.icon).."\0"..tostring(skill.description).."\0"..tostring(skill.usable==true)
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
    return text
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
function C:OpenSkillUse(skill)
    if not self.enabled or not skill or skill.usable~=true then return end
    self:HideSkillTooltip()
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
        field:SetAllPoints();field:SetColorTexture(.012,.019,.028,1);UI.ApplyBorder(viewport)
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
            C:SendSkillRaidMessage(message)
            popup:Hide()
        end)
        popup:SetScript("OnHide",function() edit:ClearFocus();popup.skill=nil end)
    end
    popup.skill=skill
    local link=self:SkillChatLink(skill,self:SkillChatID(skill))
    errorText:SetText("");edit:SetText("*Votre émote ici.* "..link);viewport:SetVerticalScroll(0)
    popup:Show();edit:SetFocus();edit:HighlightText(0,0);edit:SetCursorPosition(0)
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
