-- Creator-scoped libraries, sent only through addon whispers to current raid peers.
local C=Character
local PREFIX="OmegaSkills2"
local MAX_BYTES,MAX_CHUNKS,MAX_SKILLS=128000,640,256
local categories={}
for _,cat in ipairs(C.SKILL_CATEGORIES) do categories[#categories+1]=cat.key end
local frame=CreateFrame("Frame")
frame:Hide()
local queue,incoming,offered={},{},{}
local clock=0
local function Identity(unit)
    local name,realm=UnitFullName(unit)
    if not name then return nil end
    realm=(realm and realm~="") and realm or GetRealmName()
    return name.."-"..realm:gsub("%s","")
end
local function RaidMember(sender)
    if not IsInRaid() then return false end
    for i=1,GetNumGroupMembers() do
        local unit="raid"..i
        if Identity(unit)==sender and UnitIsConnected(unit) then return true end
    end
    return false
end
local function Normalize(sender)
    if not sender then return "" end
    if sender:find("-",1,true) then return sender end
    return sender.."-"..GetRealmName():gsub("%s","")
end
local function Send(payload,target)
    if #queue>=26000 then return false end
    queue[#queue+1]={payload,target};frame:Show();return true
end
frame:SetScript("OnUpdate",function(_,dt)
    clock=clock+dt
    if clock<.10 then return end
    clock=0
    if not C.enabled then queue,incoming,offered={},{},{};frame:Hide();return end
    local item=table.remove(queue,1)
    if item and C.enabled and RaidMember(item[2]) then
        C_ChatInfo.SendAddonMessage(PREFIX,item[1],"WHISPER",item[2])
    end
    local now=GetTime()
    for sender,buffer in pairs(incoming) do if buffer.expires<now then incoming[sender]=nil end end
    for id,offer in pairs(offered) do
        local pending=false
        for _,state in pairs(offer.targets) do if state=="sending" then pending=true end end
        if offer.expires<now or (offer.discoveryDone and not pending) then
            offered[id]=nil
            if C.OnSkillTransferStatus then
                local done=0;for _,state in pairs(offer.targets) do if state=="done" then done=done+1 end end
                C.OnSkillTransferStatus(pending and "Envoi incomplet : renvoyez la bibliothèque" or ("Envoi terminé : "..done.." destinataire(s)"))
            end
        end
    end
    if #queue==0 and not next(incoming) and not next(offered) then frame:Hide() end
end)
function C:StopSkillTransfers() queue,incoming,offered={},{},{};frame:Hide() end
local function Field(value)
    value=tostring(value or "")
    return #value..":"..value
end
local function Encode(db)
    local parts={};local count=0
    for _,category in ipairs(categories) do
        local names={};for name in pairs(db[category] or {}) do names[#names+1]=name end;table.sort(names)
        for _,name in ipairs(names) do
            local skill=db[category][name];count=count+1
            if count>MAX_SKILLS then return nil,"Maximum : 256 compétences" end
            if #name>128 or #(skill.description or "")>8000 or #tostring(skill.icon or "")>512 then return nil,"Une compétence dépasse la taille autorisée" end
            parts[#parts+1]=Field(category)..Field(name)..Field(skill.icon)..Field(skill.description)
        end
    end
    local payload=Field(count)..table.concat(parts)
    if #payload>MAX_BYTES then return nil,"Bibliothèque trop volumineuse (128 Ko maximum)" end
    return payload
end
local function Decode(payload)
    if #payload>MAX_BYTES then return end
    local pos=1
    local function Read(limit)
        local colon=payload:find(":",pos,true)
        if not colon or colon-pos>6 then return end
        local raw=payload:sub(pos,colon-1)
        if not raw:match("^%d+$") then return end
        local size=tonumber(raw)
        if size>limit or colon+size>#payload then return end
        local value=payload:sub(colon+1,colon+size);pos=colon+size+1;return value
    end
    local raw=Read(3);local count=raw and tonumber(raw)
    if not count or count%1~=0 or count<0 or count>MAX_SKILLS then return end
    local db={};for _,category in ipairs(categories) do db[category]={} end
    for i=1,count do
        local category,name,icon,description=Read(16),Read(128),Read(512),Read(8000)
        if not category or not db[category] or not name or not name:match("%S") or not icon or not description or db[category][name] then return end
        db[category][name]={name=name,icon=icon,description=description}
    end
    if pos~=#payload+1 then return end
    return db
end
function C:SendSkillLibrary()
    if self:IsSkillLibraryReadOnly() then return false,"Seul le créateur peut envoyer cette bibliothèque" end
    if not self.enabled or not IsInRaid() then return false,"Rejoignez un raid pour envoyer" end
    if next(offered) or #queue>0 then return false,"Un envoi est déjà en cours" end
    local payload,err=Encode(self:GetOwnedSkillLibrary());if not payload then return false,err end
    CharacterDB.skillRevision=(CharacterDB.skillRevision or 0)+1
    local revision=CharacterDB.skillRevision
    local id=tostring(revision).."-"..math.floor(GetTime()*1000)
    local offer={payload=payload,revision=revision,targets={},expires=GetTime()+3600}
    local count=0
    for i=1,GetNumGroupMembers() do
        local unit="raid"..i;local target=Identity(unit)
        if target and target~=Identity("player") and UnitIsConnected(unit) then
            offer.targets[target]=true;count=count+1
            Send("H|"..id.."|"..revision.."|"..math.ceil(#payload/200),target)
        end
    end
    if count==0 then return false,"Aucun autre joueur connecté dans le raid" end
    offered[id]=offer
    -- Discovery lasts a few seconds; the snapshot stays immutable for this send.
    C_Timer.After(8,function() if offered[id]==offer then offer.discoveryDone=true end end)
    return true,"Recherche des utilisateurs dans le raid…"
end
frame:RegisterEvent("CHAT_MSG_ADDON")
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
frame:SetScript("OnEvent",function(_,_,prefix,message,channel,sender)
    if prefix~=PREFIX or channel~="WHISPER" or not C.enabled or #message>255 then return end
    sender=Normalize(sender)
    if sender==Identity("player") or not RaidMember(sender) then return end
    local id,rev,total=message:match("^H|([%d%-]+)|(%d+)|(%d+)$")
    if id then
        rev,total=tonumber(rev),tonumber(total)
        if #id>40 or rev>9007199254740991 or total<1 or total>MAX_CHUNKS then return end
        CharacterDB.skillLibraries=CharacterDB.skillLibraries or {}
        local old=CharacterDB.skillLibraries[sender]
        if old and rev<=old.revision then return end
        local current=incoming[sender]
        if current and current.expires>GetTime() then return end
        incoming[sender]={id=id,revision=rev,total=total,chunks={},count=0,bytes=0,expires=GetTime()+3600}
        Send("Y|"..id,sender);return
    end
    id=message:match("^Y|([%d%-]+)$")
    if id then
        local offer=offered[id]
        if not offer or offer.targets[sender]~=true then return end
        offer.targets[sender]="sending"
        for i=1,math.ceil(#offer.payload/200) do
            Send("D|"..id.."|"..i.."|"..offer.payload:sub((i-1)*200+1,i*200),sender)
        end
        return
    end
    local index,chunk
    id,index,chunk=message:match("^D|([%d%-]+)|(%d+)|(.*)$")
    if id then
        local buffer=incoming[sender];index=tonumber(index)
        if not buffer or buffer.id~=id or index<1 or index>buffer.total or #chunk>200 then return end
        if buffer.chunks[index] then return end
        buffer.chunks[index]=chunk;buffer.count=buffer.count+1;buffer.bytes=buffer.bytes+#chunk
        if buffer.bytes>MAX_BYTES then incoming[sender]=nil;return end
        if buffer.count==buffer.total then
            local db=Decode(table.concat(buffer.chunks));incoming[sender]=nil
            if not db then return end
            -- Ownership comes ONLY from the transport sender, never from payload data.
            CharacterDB.skillLibraries[sender]={revision=buffer.revision,categories=db}
            if C.OnSkillsChanged then C.OnSkillsChanged() end
            Send("A|"..id,sender)
            if C.OnSkillTransferStatus then C.OnSkillTransferStatus("Bibliothèque reçue : "..sender) end
        end
        return
    end
    id=message:match("^A|([%d%-]+)$")
    local offer=id and offered[id]
    if offer and offer.targets[sender]=="sending" then
        offer.targets[sender]="done"
        if C.OnSkillTransferStatus then C.OnSkillTransferStatus("Bibliothèque reçue par "..sender) end
    end
end)
-- Pure codec entry points for regression tests; never evaluates received code.
C.SkillLibraryCodec={Encode=Encode,Decode=Decode}
