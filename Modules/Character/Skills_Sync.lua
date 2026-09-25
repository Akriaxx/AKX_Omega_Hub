-- Creator-scoped libraries, sent only through addon whispers to current raid peers.
-- Un créateur peut donner des droits d'édition : la liste des éditeurs part
-- avec sa bibliothèque, et un éditeur peut la renvoyer au raid sous le nom
-- du créateur. Un destinataire n'accepte ce renvoi que si le créateur
-- LUI-MÊME lui a déjà transmis cet éditeur ; le créateur accepte la version
-- d'un éditeur qu'il a nommé et remplace alors sa propre bibliothèque.
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
-- editors (facultatif) : { ["Nom-Royaume"]=true }, ajoutés à la fin ; sans
-- éditeurs, le format reste celui des versions précédentes.
local function Encode(db,editors)
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
    local names={};for name in pairs(editors or {}) do names[#names+1]=name end;table.sort(names)
    local usable={}
    for _,category in ipairs(categories) do
        for name,skill in pairs(db[category] or {}) do
            if skill.usable==true then usable[#usable+1]={category,name} end
        end
    end
    if #names>0 or #usable>0 then
        payload=payload..Field(#names)
        for _,name in ipairs(names) do payload=payload..Field(name) end
    end
    if #usable>0 then
        payload=payload..Field("U1")..Field(#usable)
        for _,entry in ipairs(usable) do payload=payload..Field(entry[1])..Field(entry[2]) end
    end
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
    local editors={}
    if pos<=#payload then
        local rawEditors=Read(3);local total=rawEditors and tonumber(rawEditors)
        if not total or total<0 or total>64 then return end
        for i=1,total do
            local name=Read(64)
            if not name or not name:match("^[^%-]+%-%S+$") then return end
            editors[name]=true
        end
    end
    if pos<=#payload then
        if Read(2)~="U1" then return end
        local raw=Read(3);local total=raw and tonumber(raw)
        if not total or total%1~=0 or total<0 or total>MAX_SKILLS then return end
        for i=1,total do
            local category,name=Read(16),Read(128)
            local skill=category and name and db[category] and db[category][name]
            if not skill or skill.usable then return end
            skill.usable=true
        end
    end
    if pos~=#payload+1 then return end
    return db,editors
end
-- Envoie la bibliothèque affichée : la vôtre (avec vos éditeurs), ou celle
-- d'un créateur dont vous êtes éditeur (sous son nom, révision suivante).
function C:SendSkillLibrary()
    local owner=self:GetSkillLibraryOwner()
    if owner==self.COMMON_SKILL_LIBRARY then return false,"La bibliothèque commune ne s'envoie pas" end
    if self:IsSkillLibraryReadOnly() then return false,"Seul le créateur ou un éditeur peut envoyer cette bibliothèque" end
    if not self.enabled or not IsInRaid() then return false,"Rejoignez un raid pour envoyer" end
    if next(offered) or #queue>0 then return false,"Un envoi est déjà en cours" end
    local payload,err,revision,suffix
    if owner then
        local library=CharacterDB.skillLibraries[owner]
        payload,err=Encode(library.categories)
        if not payload then return false,err end
        library.revision=(library.revision or 0)+1
        revision,suffix=library.revision,"|"..owner
    else
        payload,err=Encode(self:GetOwnedSkillLibrary(),self:GetSkillEditors())
        if not payload then return false,err end
        CharacterDB.skillRevision=(CharacterDB.skillRevision or 0)+1
        revision,suffix=CharacterDB.skillRevision,""
    end
    local id=tostring(revision).."-"..math.floor(GetTime()*1000)
    local offer={payload=payload,revision=revision,targets={},expires=GetTime()+3600}
    local count=0
    for i=1,GetNumGroupMembers() do
        local unit="raid"..i;local target=Identity(unit)
        if target and target~=Identity("player") and UnitIsConnected(unit) then
            offer.targets[target]=true;count=count+1
            Send("H|"..id.."|"..revision.."|"..math.ceil(#payload/200)..suffix,target)
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
    -- En-tête : H|id|révision|fragments (le créateur est l'expéditeur), ou
    -- H|id|révision|fragments|Créateur-Royaume (renvoi par un éditeur).
    local id,rev,total,owner=message:match("^H|([%d%-]+)|(%d+)|(%d+)|([^|]+)$")
    if not id then
        id,rev,total=message:match("^H|([%d%-]+)|(%d+)|(%d+)$")
        owner=""
    end
    if id then
        rev,total=tonumber(rev),tonumber(total)
        if #id>40 or rev>9007199254740991 or total<1 or total>MAX_CHUNKS or #owner>64 then return end
        CharacterDB.skillLibraries=CharacterDB.skillLibraries or {}
        owner=(owner~="" and owner) or sender
        local me=Identity("player")
        local authorized,oldRevision
        if owner==me then
            -- Votre bibliothèque, renvoyée par un éditeur que vous avez nommé.
            authorized=C:GetSkillEditors()[sender]
            oldRevision=CharacterDB.skillRevision or 0
        elseif owner==sender then
            authorized=true
            local old=CharacterDB.skillLibraries[sender]
            oldRevision=old and old.revision or -1
        else
            -- Renvoi par un éditeur : seulement si le créateur l'a lui-même nommé.
            local stored=CharacterDB.skillLibraries[owner]
            authorized=stored and stored.editors and stored.editors[sender]
            oldRevision=stored and stored.revision or -1
        end
        if not authorized or rev<=oldRevision then return end
        local current=incoming[sender]
        if current and current.expires>GetTime() then return end
        incoming[sender]={id=id,revision=rev,total=total,owner=owner,chunks={},count=0,bytes=0,expires=GetTime()+3600}
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
            local db,editors=Decode(table.concat(buffer.chunks));incoming[sender]=nil
            if not db then return end
            -- Le créateur vient de l'en-tête vérifié à l'arrivée (expéditeur réel,
            -- ou créateur ayant nommé cet éditeur), jamais du contenu seul.
            local owner=buffer.owner
            local status
            if owner==Identity("player") then
                C:ReplaceOwnedSkillLibrary(db)
                CharacterDB.skillRevision=buffer.revision
                status="Votre bibliothèque, modifiée par "..sender
            elseif owner==sender then
                -- Seul le créateur fixe la liste de ses éditeurs.
                CharacterDB.skillLibraries[sender]={revision=buffer.revision,categories=db,editors=editors}
                status="Bibliothèque reçue : "..sender
            else
                local stored=CharacterDB.skillLibraries[owner]
                if not stored then return end
                stored.categories,stored.revision=db,buffer.revision
                status="Bibliothèque de "..owner.." reçue (modifiée par "..sender..")"
            end
            if C.OnSkillsChanged then C.OnSkillsChanged() end
            Send("A|"..id,sender)
            if C.OnSkillTransferStatus then C.OnSkillTransferStatus(status) end
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
