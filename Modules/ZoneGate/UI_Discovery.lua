local ZG=ZoneGate
local UI=ZG.EditorUI or OS2.UI
local picker
local function short(name) return (name or ""):match("^([^%-]+)") end
local function source(scope,id)
    if scope=="zone" then local z=ZG:GetZone(id);return z,z end
    return ZG:FindSubZone(id)
end
function ZG:DiscoveryRoster()
    local members,seen={},{}
    local function add(token)
        if UnitIsConnected and not UnitIsConnected(token) then return end
        local name,realm=UnitName(token)
        if not name or name=="" or name==UnitName("player") then return end
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
function ZG:OpenDiscoveryPicker(scope,id,onSaved)
    local item,zone=source(scope,id)
    if not item or not zone or zone.creator~=UnitName("player") then return end
    if not picker then
        picker=CreateFrame("Frame","ZoneGateDiscoveryPicker",ZoneGatePanel)
        picker:SetSize(430,440);picker:SetPoint("CENTER");picker:SetFrameStrata("DIALOG")
        picker:EnableMouse(true);picker:SetClampedToScreen(true);UI.Surface(picker)
        local function label(text,x,y,w)
            local f=picker:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            f:SetPoint("TOPLEFT",x,-y);f:SetWidth(w);f:SetJustifyH("LEFT");f:SetText(text);UI.ApplyLabel(f);return f
        end
        picker.title=label("Débloquer pour…",16,16,390)
        label("Cochez pour révéler le nom. Décochez pour le retirer.\nLes changements s'appliquent uniquement après validation.",16,42,398)
        local all=UI.CreatePanelButton(picker,190,26,"Tout cocher");all:SetPoint("TOPLEFT",16,-86)
        local none=UI.CreatePanelButton(picker,200,26,"Tout décocher");none:SetPoint("TOPLEFT",214,-86)
        local scroll=CreateFrame("ScrollFrame",nil,picker)
        scroll:SetPoint("TOPLEFT",16,-122);scroll:SetSize(398,224);scroll:EnableMouseWheel(true)
        local content=CreateFrame("Frame",nil,scroll);content:SetSize(398,1);scroll:SetScrollChild(content)
        scroll:SetScript("OnMouseWheel",function(self,delta)
            self:SetVerticalScroll(math.max(0,math.min(math.max(0,content:GetHeight()-224),self:GetVerticalScroll()-delta*28)))
        end)
        picker.scroll,picker.content,picker.rows=scroll,content,{}
        picker.status=label("",16,354,398)
        local cancel=UI.CreatePanelButton(picker,190,28,"Annuler");cancel:SetPoint("TOPLEFT",16,-398)
        local save=UI.CreatePanelButton(picker,200,28,"Valider");save:SetPoint("TOPLEFT",214,-398)
        picker.saveButton=save
        local function selectAll(value)
            for _,member in ipairs(picker.members) do picker.selection[member.name]=value end
            picker:Refresh()
        end
        all:SetScript("OnClick",function() selectAll(true) end)
        none:SetScript("OnClick",function() selectAll(false) end)
        cancel:SetScript("OnClick",function() picker:Hide() end)
        UI.CreateCloseButton(picker,function() picker:Hide() end)
        function picker:Refresh()
            local current,owner=source(self.scope,self.itemId)
            if not current or not owner or owner.creator~=UnitName("player") then self:Hide();return end
            self.members=ZG:DiscoveryRoster()
            local checked=0
            for i,member in ipairs(self.members) do
                if self.selection[member.name]==nil then self.selection[member.name]=current.grantedTo and current.grantedTo[member.key] and true or false end
                local row=self.rows[i]
                if not row then
                    local cb,txt=UI.CreateStyledCheckbox(content,"")
                    cb:SetPoint("TOPLEFT",4,-(i-1)*28);txt:SetWidth(360);txt:SetJustifyH("LEFT")
                    row={box=cb,label=txt};self.rows[i]=row
                    cb:SetScript("OnClick",function(button)
                        self.selection[row.member.name]=button:GetChecked() and true or false;self:Refresh()
                    end)
                end
                row.member=member;row.label:SetText(member.name)
                row.box:SetChecked(self.selection[member.name]);row.box:Show();row.label:Show()
                if self.selection[member.name] then checked=checked+1 end
            end
            for i=#self.members+1,#self.rows do self.rows[i].box:Hide();self.rows[i].label:Hide() end
            content:SetHeight(math.max(1,#self.members*28))
            scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,content:GetHeight()-224)))
            self.status:SetText(#self.members==0 and "Aucun autre joueur connecté dans votre groupe ou raid." or string.format("%d / %d sélectionnés · Molette pour défiler\nVotre personnage connaît déjà ce nom.",checked,#self.members))
            save:SetEnabled(#self.members>0)
        end
        save:SetScript("OnClick",function()
            picker:Refresh() -- validate only members still present, and recheck ownership
            if not picker:IsShown() then return end
            local current=source(picker.scope,picker.itemId)
            local failures=0
            for _,member in ipairs(picker.members) do
                local before=current.grantedTo and current.grantedTo[member.key] and true or false
                local wanted=picker.selection[member.name]
                if before~=wanted then
                    local method=wanted and (picker.scope=="zone" and "SendZoneGrant" or "SendSubZoneGrant") or (picker.scope=="zone" and "RevokeZoneGrant" or "RevokeGrant")
                    if not ZG[method](ZG,picker.itemId,member.name) then
                        failures=failures+1
                        if before then current.grantedTo=current.grantedTo or {};current.grantedTo[member.key]=true end
                    end
                end
            end
            if picker.onSaved then picker.onSaved() end
            if failures==0 then picker:Hide()
            else picker.status:SetText(failures.." envoi(s) impossible(s). Réessayez avec Valider.") end
        end)
        picker:RegisterEvent("GROUP_ROSTER_UPDATE")
        picker:RegisterEvent("UNIT_CONNECTION")
        picker:SetScript("OnEvent",function(self) if self:IsShown() and self.itemId then self:Refresh() end end)
        picker:SetScript("OnHide",function(self) self.selection={};self.itemId=nil end)
        UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"ZoneGateDiscoveryPicker")
    end
    picker.scope,picker.itemId,picker.onSaved=scope,id,onSaved
    picker.selection={};picker.scroll:SetVerticalScroll(0)
    picker.title:SetText(scope=="zone" and "Débloquer le nom de la région pour…" or "Débloquer le nom du checkpoint pour…")
    picker:Show();picker:Refresh()
    return picker
end
