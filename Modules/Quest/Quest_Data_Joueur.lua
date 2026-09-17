local J = Quest

function J:MigrateDB_Joueur()
    local root = OmegaHubDB.Quest_Joueur or {}
    if (tonumber(root.version) or 0) > self.DB_VERSION then error("Journal de quête : données joueur d'une version plus récente.") end
    -- SavedVariables est partagé par le compte : isoler chaque personnage.
    root.personnages = root.personnages or {}
    local key = self:Key(self:Me())
    root.personnages[key] = root.personnages[key] or { quetes = root.quetes or {}, tombstones = {} }
    root.quetes = nil
    root.version = self.DB_VERSION
    self.playerDB = root.personnages[key]
    self.playerDB.tombstones = self.playerDB.tombstones or {}
    self.playerDB.pending = self.playerDB.pending or {}
    self.playerDB.refused = self.playerDB.refused or {}
    OmegaHubDB.Quest_Joueur = root
end

local fields = { id = true, titre = true, donneur = true, auteur = true, nombre_etapes = true,
    etapes_revelees = true, statut = true, revision = true, date_creation = true, lettre = true, categorie = true }

function J:ValidateProjection(q)
    if type(q) ~= "table" then return false end
    if q.categorie~=nil and q.categorie~="personnel" and q.categorie~="groupe" then return false end
    for key in pairs(q) do if not fields[key] then return false end end
    if not self:ValidText(q.id, 160, true) or not self:Name(q.auteur) then return false end
    if not self:ValidText(q.titre, 180, true) or not self:ValidText(q.donneur, 300) then return false end
    if not self:IsInteger(q.nombre_etapes, 1, 50) or not self:IsInteger(q.revision, 1, 1000000000) then return false end
    if not self:IsInteger(q.date_creation, 0, 100000000000) or not self.statuses[q.statut] then return false end
    if type(q.etapes_revelees) ~= "table" then return false end
    local bytes = #q.titre + #q.donneur
    if q.lettre ~= nil then
        local l=q.lettre
        if type(l)~="table" or not self:ValidText(l.objet,300) or not self:ValidText(l.expediteur,180) or not self:ValidText(l.texte,8192) then return false end
        for key in pairs(l) do if key~="objet" and key~="expediteur" and key~="texte" then return false end end
        bytes=bytes+#l.objet+#l.expediteur+#l.texte
    end
    for i, text in pairs(q.etapes_revelees) do
        if not self:IsInteger(i, 1, q.nombre_etapes) or not self:ValidText(text, 8192) then return false end
        bytes = bytes + #text
    end
    return bytes <= 50000
end

function J:AcceptQuest(q, sender, mode)
    if not self:IsMJ(sender) or not self:ValidateProjection(q) then return false end
    if self:Key(q.auteur) ~= self:Key(sender) then return false end
    local pending=self.playerDB.pending[q.id]
    local old, deleted = self.playerDB.quetes[q.id] or pending, self.playerDB.tombstones[q.id]
    local refused=self.playerDB.refused[q.id]
    if refused then return self:Key(refused.auteur)==self:Key(sender) end
    if old and self:Key(old.auteur) ~= self:Key(sender) then return false end
    if deleted then
        if self:Key(deleted.auteur) ~= self:Key(sender) then return false end
        if q.revision <= deleted.revision then return true end
    end
    if old and q.revision <= old.revision then return true end
    local entry = self:Copy(q)
    entry.date_reception = old and old.date_reception or time()
    if pending or (not old and mode=="letter") then
        self.playerDB.pending[q.id]=entry
    else self.playerDB.quetes[q.id] = entry end
    if self.RefreshBook then self:RefreshBook() end
    if not old and self.Notify then self:Notify(q.id, mode) end
    if self.RefreshLetter then self:RefreshLetter() end
    return true
end

function J:AcceptDelete(data, sender)
    if not self:IsMJ(sender) or not self:ValidText(data.id, 160, true)
        or not self:IsInteger(data.revision, 1, 1000000000) or self:Key(data.auteur) ~= self:Key(sender) then return false end
    local old, deleted = self.playerDB.quetes[data.id] or self.playerDB.pending[data.id] or self.playerDB.refused[data.id], self.playerDB.tombstones[data.id]
    if old and self:Key(old.auteur) ~= self:Key(sender) then return false end
    if deleted and self:Key(deleted.auteur) ~= self:Key(sender) then return false end
    if old and data.revision <= old.revision then return true end
    if deleted and data.revision <= deleted.revision then return true end
    self.playerDB.quetes[data.id] = nil
    self.playerDB.pending[data.id] = nil
    self.playerDB.refused[data.id] = nil
    self.playerDB.tombstones[data.id] = { revision = data.revision, auteur = sender }
    if self.RefreshBook then self:RefreshBook() end
    if self.RefreshLetter then self:RefreshLetter() end
    return true
end

-- L'accusé réseau confirme la remise ; seul ce choix inscrit la quête.
function J:DecideLetter(id, accept)
    local q=self.playerDB.pending[id]
    if not q then return false end
    if accept then self.playerDB.quetes[id]=q
    else self.playerDB.refused[id]={auteur=q.auteur,revision=q.revision} end
    self.playerDB.pending[id]=nil
    self:RefreshBook()
    return true
end
