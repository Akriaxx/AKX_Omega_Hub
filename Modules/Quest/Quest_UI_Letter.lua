-- Feuille de lecture : le fond ne contient aucun texte gravé dans l'image.
local J=Quest
local S=J.Style
local INK={.27,.18,.09,1}
local function Text(parent,size,x,y,width)
    local t=S:Text(parent,"",size,x,y,width); t:SetTextColor(unpack(INK)); return t
end

function J:CreateLetterSheet()
    if self.sheet then return end
    local f=CreateFrame("Frame","OmegaJournalLetterSheet",UIParent)
    self.sheet=f; f:SetSize(560,660); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(240)
    f:SetScale(math.min(1,(UIParent:GetHeight()-40)/660,(UIParent:GetWidth()-40)/560))
    f:EnableMouse(true); f:Hide()
    -- Combler la transparence entre les deux moitiés sans recouvrir le pli.
    local foldBacking=f:CreateTexture(nil,"BACKGROUND",nil,-1)
    foldBacking:SetPoint("TOPLEFT",f,"TOPLEFT",6,-326)
    foldBacking:SetSize(550,12);foldBacking:SetColorTexture(.85,.74,.53,1)
    local bg=f:CreateTexture(nil,"BACKGROUND",nil,0); bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Envelope\\paper.blp")
    f.title=Text(f,24,48,-40,464); f.title:SetHeight(62)
    f.sender=Text(f,13,48,-110,464); f.sender:SetHeight(38)
    f.subject=Text(f,14,48,-153,464); f.subject:SetHeight(44)
    f.scroll,f.content=S:Scroll(f,452,344,48,-210)
    f.body=Text(f.content,16,0,0,444); f.body:SetSpacing(5)
    f.accept=S:Button(f,"Accepter",180,310,-595,function() self:FinishLetter(true) end)
    f.refuse=S:Button(f,"Refuser",180,70,-595,function() self:FinishLetter(false) end)
end

function J:RefreshLetter()
    local f=self.sheet
    if not f or not f:IsShown() or f.demo then return end
    if not self.playerDB.pending[f.questID] then
        f:Hide(); self:NextLetter(f.questID); return
    end
    self:FillLetter(self.playerDB.pending[f.questID])
end

function J:FillLetter(q)
    local f=self.sheet; local l=q.lettre
    f.title:SetText(q.titre)
    f.sender:SetText("Expéditeur : "..(l and l.expediteur~="" and l.expediteur or (q.donneur~="" and q.donneur or q.auteur)))
    f.subject:SetText("Objet : "..(l and l.objet~="" and l.objet or q.titre))
    local body=l and l.texte
    if not body then
        local parts={}
        for i=1,q.nombre_etapes do if q.etapes_revelees[i] then parts[#parts+1]=q.etapes_revelees[i] end end
        body=table.concat(parts,"\n\n")
    end
    f.body:SetText(body)
    f.content:SetHeight(math.max(344,f.body:GetStringHeight()+16)); f.scroll:SetVerticalScroll(0)
end

function J:ShowLetterSheet(id,demo)
    self:CreateLetterSheet()
    local q=demo and {titre="Une lettre à votre attention",donneur="",auteur="Nytherah",lettre={
        objet="Rendez-vous aux anciennes archives",expediteur="Nytherah, gardienne des archives",
        texte="À vous qui recevez cette lettre,\n\nUn ancien registre a été retrouvé parmi les vestiges de la tour. Ses pages portent un sceau que nous pensions disparu.\n\nJe vous demande de me rejoindre aux archives à la tombée du jour. Venez avec discrétion : nous aurons besoin de votre regard et de votre jugement.\n\nQue cette lettre vous parvienne en de bonnes mains.\n\nNytherah"}}
        or self.playerDB.pending[id]
    if not q then self:NextLetter(id); return end
    self.sheet.questID=id; self.sheet.demo=demo
    self:FillLetter(q); self.sheet:Show()
end

function J:NextLetter(id)
    self.notices=self.notices or {}
    for i=#self.notices,1,-1 do
        if self.notices[i]==id or not self.playerDB.pending[self.notices[i]] then table.remove(self.notices,i) end
    end
    if #self.notices>0 and self.enabled then self:ShowEnvelope(false) end
end

function J:FinishLetter(accept)
    local f=self.sheet
    if not f or not f:IsShown() then return end
    local id,demo=f.questID,f.demo
    if not demo then self:DecideLetter(id,accept) end
    f:Hide()
    if not demo and accept and self.playerDB.quetes[id] then self:OpenQuest(id,true) end
    self:NextLetter(id)
end

function J:RestoreLetters()
    self.notices={}
    for id in pairs(self.playerDB.pending) do self.notices[#self.notices+1]=id end
    table.sort(self.notices)
    if #self.notices>0 then self:ShowEnvelope(false) end
end

-- Rédaction de la lettre publique, indépendante des étapes secrètes.
function J:OpenLetterEditor()
    if not self:RequireMJ() then return end
    if not self.letterEditor then
        local f=CreateFrame("Frame","OmegaJournalLetterEditor",UIParent,"BackdropTemplate")
        self.letterEditor=f; f:SetSize(620,570); S:Surface(f,false); S:Window(f,"DIALOG"); f:SetFrameLevel(260)
        S:Text(f,"Lettre au destinataire",22,24,-24,540)
        S:Text(f,"Expéditeur",13,24,-68,540)
        f.sender=OS2.UI.CreateStyledEditBox(f,560,28); f.sender:SetPoint("TOPLEFT",24,-88); f.sender:SetMaxLetters(180)
        S:Text(f,"Objet",13,24,-130,540)
        f.subject=OS2.UI.CreateStyledEditBox(f,560,28); f.subject:SetPoint("TOPLEFT",24,-150); f.subject:SetMaxLetters(300)
        S:Text(f,"Texte de la lettre — visible avant acceptation",13,24,-194,560)
        f.scroll=S:Scroll(f,548,262,24,-220)
        f.body=CreateFrame("EditBox",nil,f.scroll); f.body:SetWidth(540); f.body:SetHeight(262)
        f.body:SetMultiLine(true); f.body:SetAutoFocus(false); f.body:SetFontObject(ChatFontNormal)
        f.body:SetMaxLetters(8192); f.body:SetTextColor(unpack(S.ink))
        f.body:SetScript("OnEscapePressed",f.body.ClearFocus)
        f.body:SetScript("OnTextChanged",function(edit)
            -- La hauteur est mesurée sur une copie pour conserver tout le texte.
            f.measure:SetText(edit:GetText()); edit:SetHeight(math.max(262,f.measure:GetStringHeight()+28))
        end)
        f.body:SetScript("OnCursorChanged",function(_,_,y,_,height)
            local offset=f.scroll:GetVerticalScroll(); local top=-y
            if top<offset then f.scroll:SetVerticalScroll(top)
            elseif top+height>offset+262 then f.scroll:SetVerticalScroll(top+height-262) end
        end)
        f.measure=S:Text(f,"",14,0,0,540); f.measure:SetFontObject(ChatFontNormal); f.measure:Hide()
        f.scroll:SetScrollChild(f.body)
        S:Button(f,"Appliquer au brouillon",220,24,-510,function()
            if not self:RequireMJ() then return end
            self.panel.draft.lettre={objet=f.subject:GetText(),expediteur=f.sender:GetText(),texte=f.body:GetText()}
            f:Hide()
            self.Print("Lettre appliquée au brouillon. Enregistre la quête pour actualiser les destinataires.")
        end)
        S:Button(f,"Annuler",140,444,-510,function() f:Hide() end)
    end
    local q=self:ReadDraft(); local l=q.lettre or {objet=q.titre,expediteur=q.donneur,texte=""}
    local f=self.letterEditor; f.sender:SetText(l.expediteur); f.subject:SetText(l.objet); f.body:SetText(l.texte)
    f.scroll:SetVerticalScroll(0); f:Show()
end
