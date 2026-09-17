local J = Quest
local S = J.Style
J.Book = {}
local INK={.27,.19,.10,1}
local MUTED={.46,.35,.20,1}
local BOOK_MEDIA="Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Book\\"
local BOOKMARK_TEXTURES={personal="personal",group="group",archives="archives"}
J.Book.categories={
    {id="personal",label="Personnel",color={.23,.36,.29,1},matches=function(q) return q.statut=="en_cours" and q.categorie~="groupe" end},
    {id="group",label="Groupe",color={.22,.30,.43,1},matches=function(q) return q.statut=="en_cours" and q.categorie=="groupe" end},
    {id="archives",label="Archive",color={.43,.28,.20,1},matches=function(q) return q.statut~="en_cours" end},
}

-- Une catégorie ajoute son marque-page ; aucun onglet fictif n'est affiché.
function J.Book:RegisterCategory(category)
    assert(type(category)=="table" and type(category.id)=="string" and type(category.label)=="string" and type(category.matches)=="function", "Catégorie invalide")
    for i,old in ipairs(self.categories) do
        if old.id==category.id then self.categories[i]=category; if J.book then J:RefreshBookmarks() end; return end
    end
    self.categories[#self.categories+1]=category
    if J.book then J:RefreshBookmarks() end
end

function J:RefreshBookmarks()
    local book=self.book
    if not book.rail then return end
    for _,tab in ipairs(book.tabs) do tab:Hide() end
    for i,category in ipairs(self.Book.categories) do
        local tab=book.tabs[i]
        if not tab then
            tab=CreateFrame("Button",nil,book.railChild)
            tab.ribbon=tab:CreateTexture(nil,"ARTWORK")
            tab.ribbon:SetAllPoints()
            tab:SetScript("OnClick",function(button)
                local c=button.category
                self:TurnBookPage(function()
                    book.category=c.id; book.archive=c.id=="archives"; book.selected=nil; self:RefreshBook()
                end)
            end)
            tab:SetSize(48,144)
            tab:SetScript("OnEnter",function(button)
                button.ribbon:SetVertexColor(1,1,1,1)
                if GameTooltip then GameTooltip:SetOwner(button,"ANCHOR_LEFT"); GameTooltip:SetText(button.category.label);GameTooltip:Show() end
            end)
            tab:SetScript("OnLeave",function(button)
                local brightness=book.category==button.category.id and 1 or .78
                button.ribbon:SetVertexColor(brightness,brightness,brightness,1)
                if GameTooltip then GameTooltip:Hide() end
            end)
            book.tabs[i]=tab
        end
        tab.category=category
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT",book.railChild,"TOPLEFT",book.category==category.id and 0 or 4,-(i-1)*156)
        -- Libellés tournés dans les textures pour rester nets sur le client.
        tab.ribbon:SetTexture(category.bookmark or (BOOK_MEDIA.."bookmark-"..(BOOKMARK_TEXTURES[category.id] or "blank")..".blp"))
        local strength=book.category==category.id and 1 or .78
        tab.ribbon:SetVertexColor(strength,strength,strength,1)
        tab:Show()
    end
    book.railChild:SetHeight(math.max(480,#self.Book.categories*156))
end

-- Composant de sommaire réutilisable dans un livre : aucun état métier global.
function J.Book:CreateContents(parent, width, height, onSelect, parchment)
    local scroll, child = S:Scroll(parent, width, height, 20, -66)
    local component = { frame = scroll, child = child, rows = {} }
    function component:SetEntries(entries)
        for _, row in ipairs(self.rows) do row:Hide() end
        for i, entry in ipairs(entries) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Button", nil, child)
                row:SetSize(width - 6, 52)
                row.label = S:Text(row, "", 15, 5, -6, width - 20)
                row.label:SetHeight(22)
                if parchment then row.label:SetTextColor(unpack(INK)) end
                row.meta = S:Text(row, "", 11, 5, -30, width - 20)
                row.meta:SetTextColor(unpack(parchment and MUTED or S.muted))
                local highlight = row:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetAllPoints(); highlight:SetColorTexture(unpack(OS2.UI.colors.tabHighlight))
                row:SetHighlightTexture(highlight)
                row.selection = row:CreateTexture(nil, "BACKGROUND")
                row.selection:SetAllPoints(); row.selection:SetColorTexture(unpack(OS2.UI.colors.rowBgSelected))
                if parchment then row.selection:SetColorTexture(.45,.31,.13,.13) end
                row.accent = row:CreateTexture(nil, "ARTWORK")
                row.accent:SetPoint("TOPLEFT", 0, -5); row.accent:SetSize(2, 40)
                row.accent:SetColorTexture(unpack(S.gold))
                S:Rule(row, 5, -51, width - 20)
                row:SetScript("OnClick", function(button) onSelect(button.entry) end)
                self.rows[i] = row
            end
            row.entry = entry
            row:SetPoint("TOPLEFT", 0, -(i - 1) * 56)
            row.label:SetText(entry.titre)
            row.meta:SetText(entry.sous_titre or "")
            row.selection:SetShown(entry.id == self.selected)
            row.accent:SetShown(entry.id == self.selected)
            row:Show()
        end
        child:SetHeight(math.max(height, #entries * 56))
        scroll:SetVerticalScroll(0)
    end
    function component:SetSelected(id)
        self.selected = id
        for _, row in ipairs(self.rows) do
            row.selection:SetShown(row.entry.id == id)
            row.accent:SetShown(row.entry.id == id)
        end
    end
    return component
end

function J:CreateBook()
    if self.book then return end
    local book = CreateFrame("Frame", "OmegaQuestBook", UIParent, "QuestBookTemplate")
    self.book = book
    S:Window(book)
    book:SetScale(math.min(1,(UIParent:GetWidth()-250)/940,(UIParent:GetHeight()-30)/650))
    local background=book:CreateTexture(nil,"BACKGROUND");background:SetAllPoints()
    background:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Book\\BindingEdges\\grimoire.blp")
    local heading = S:Text(book, "JOURNAL DE QUÊTE", 12, 48, -35)
    heading:SetTextColor(unpack(MUTED))
    local left = CreateFrame("Frame", nil, book, "BackdropTemplate")
    left:SetPoint("TOPLEFT", 23, -65); left:SetSize(440, 525)
    local right = CreateFrame("Frame", nil, book, "BackdropTemplate")
    right:SetPoint("TOPLEFT", 477, -65); right:SetSize(440, 525)
    book.left, book.right = left, right
    book.contentsTitle = S:Text(left, "Personnel", 23, 23, -24)
    book.contents = self.Book:CreateContents(left, 382, 423, function(entry) self:OpenQuest(entry.id, true) end,true)
    book.empty = S:Text(left, "Aucune quête pour le moment.", 15, 24, -84, 355)
    book.title = S:Text(right, "Le début d'une histoire", 22, 24, -26, 380)
    book.title:SetHeight(54)
    book.meta = S:Text(right, "", 12, 24, -87, 374)
    book.meta:SetHeight(55)
    book.scroll, book.content = S:Scroll(right, 366, 320, 24, -158)
    book.text = S:Text(book.content, "", 16, 0, 0, 358)
    book.text:SetSpacing(5)
    book.content:EnableMouse(true)
    book.content:SetScript("OnMouseDown", function() self.Write:Finish(book.content) end)
    book.scroll:SetScript("OnMouseDown", function() self.Write:Finish(book.content) end)
    S:Rule(right, 24, -485, 390)
    book.hint = S:Text(right, "", 10, 24, -496, 380)
    for _,label in ipairs({book.contentsTitle,book.title,book.empty,book.text}) do label:SetTextColor(unpack(INK)) end
    for _,label in ipairs({book.meta,book.hint}) do label:SetTextColor(unpack(MUTED)) end
    book.category="personal"; book.tabs={}
    book.rail=CreateFrame("ScrollFrame",nil,book);book.rail:SetSize(54,480);book.rail:SetPoint("TOPLEFT",-19,-80)
    book.railChild=CreateFrame("Frame",nil,book.rail);book.railChild:SetSize(54,480);book.rail:SetScrollChild(book.railChild)
    book.rail:EnableMouseWheel(true)
    book.rail:SetScript("OnMouseWheel",function(f,delta) f:SetVerticalScroll(math.max(0,math.min(f:GetVerticalScrollRange(),f:GetVerticalScroll()-delta*156))) end)
    self:RefreshBookmarks()
    book.mjButton=CreateFrame("Button",nil,book)
    book.mjButton:SetSize(48,144)
    book.mjButton:SetPoint("BOTTOMRIGHT",book,"BOTTOMRIGHT",19,32)
    book.mjButton.ribbon=book.mjButton:CreateTexture(nil,"ARTWORK")
    book.mjButton.ribbon:SetAllPoints()
    book.mjButton.ribbon:SetTexture(BOOK_MEDIA.."bookmark-mj.blp")
    book.mjButton.ribbon:SetVertexColor(.85,.85,.85,1)
    book.mjButton:SetScript("OnClick",function() self:OpenMJPanel() end)
    book.mjButton:SetScript("OnEnter",function(button)
        button.ribbon:SetVertexColor(1,1,1,1)
        if GameTooltip then GameTooltip:SetOwner(button,"ANCHOR_RIGHT");GameTooltip:SetText("Écritoire du MJ");GameTooltip:Show() end
    end)
    book.mjButton:SetScript("OnLeave",function(button)
        button.ribbon:SetVertexColor(.85,.85,.85,1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    book:SetScript("OnHide", function()
        self.Write:Stop(book.content)
        if self.enabled then self:AnimateBook(false) else self:StopBookMotion() end
    end)
    book:SetScript("OnShow", function() self:RefreshBook(); self:AnimateBook(true) end)
end

function J:RefreshBook()
    local book = self.book
    if not book or not book:IsShown() then return end
    book.mjButton:SetShown(self:IsMJ())
    if book.archive then book.category="archives"
    elseif book.category=="archives" or book.category=="active" then book.category="personal" end
    self:RefreshBookmarks()
    local category=self.Book.categories[1]
    for _,c in ipairs(self.Book.categories) do if c.id==book.category then category=c;break end end
    local entries = {}
    for id, q in pairs(self.playerDB.quetes) do
        if category.matches(q) then
            entries[#entries + 1] = { id = id, titre = q.titre, sous_titre = self.statuses[q.statut] .. " · " .. q.auteur }
        end
    end
    table.sort(entries, function(a, b) if a.titre == b.titre then return a.id < b.id end; return a.titre < b.titre end)
    book.contentsTitle:SetText(category.label .. "  ·  " .. #entries)
    book.contents:SetEntries(entries)
    book.empty:SetShown(#entries == 0)
    local q = book.selected and self.playerDB.quetes[book.selected]
    if q and not category.matches(q) then book.selected = nil end
    book.contents:SetSelected(book.selected)
    self:RenderQuest()
end

function J:RenderQuest(immediate)
    local book = self.book
    self:StopBookTextFade()
    self.Write:Stop(book.content)
    local q = book.selected and self.playerDB.quetes[book.selected]
    book.scroll:SetVerticalScroll(0)
    if not q then
        book.hint:SetText("Une quête par page · Défilement à la molette")
        book.title:SetText(book.archive and "Les récits achevés" or "Le début d'une histoire")
        book.meta:SetText("")
        book.text:SetText("Choisis une quête dans le sommaire de gauche.\n\nChaque récit tient sur sa page ; fais défiler le texte pour poursuivre la lecture.")
        book.content:SetHeight(320)
        return
    end
    book.title:SetText(q.titre)
    local revealed = 0
    for _ in pairs(q.etapes_revelees) do revealed = revealed + 1 end
    book.meta:SetText(q.donneur .. "\n" .. self.statuses[q.statut] .. "  ·  " .. revealed .. "/" .. q.nombre_etapes .. " étapes révélées")
    book.hint:SetText("Cliquer sur le texte pour terminer l'écriture")
    local parts = {}
    for index = 1, q.nombre_etapes do
        parts[#parts + 1] = "|cff795629" .. string.format("%02d", index) .. "|r  " .. (q.etapes_revelees[index] or "|cff79684a?????|r") .. "|r"
    end
    local text = table.concat(parts, "\n\n")
    book.text:SetText(text)
    book.content:SetHeight(math.max(320, book.text:GetStringHeight() + 20))
    if not immediate and (not book.motion or not book.motion:IsShown()) then self.Write:Start(book.content, book.text, text) end
end

function J:OpenQuest(id, animate)
    local q = self.playerDB.quetes[id]
    if not q then return end
    if animate and self.book:IsShown() then
        self:TurnBookPage(function() self:OpenQuest(id,false) end)
        return
    end
    self.book.selected, self.book.archive = id, q.statut ~= "en_cours"
    local matches=false
    for _,c in ipairs(self.Book.categories) do if c.id==self.book.category then matches=c.matches(q);break end end
    if not matches then self.book.category=self.book.archive and "archives" or (q.categorie=="groupe" and "group" or "personal") end
    self.book:Show()
    self:RefreshBook()
end

function J:Notify(id, mode)
    if mode == "unlock" then
        self.Print("Quête débloquée : " .. self.playerDB.quetes[id].titre .. " — ouvre ton journal")
        return
    end
    self.notices = self.notices or {}
    self.notices[#self.notices + 1] = id
    if (not self.letter or not self.letter:IsShown()) and (not self.sheet or not self.sheet:IsShown()) then self:ShowEnvelope(false) end
end
