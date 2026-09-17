local J = Quest
J.statuses = { en_cours = "En cours", terminee = "Terminée", echouee_annulee = "Échouée / annulée" }

function J:IsInteger(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end

function J:Copy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, item in pairs(value) do copy[key] = self:Copy(item) end
    return copy
end

function J:MigrateDB_MJ()
    local db = OmegaHubDB.Quest_MJ or {}
    if (tonumber(db.version) or 0) > self.DB_VERSION then error("Journal de quête : données MJ d'une version plus récente.") end
    db.permissions = db.permissions or { mj = {}, revision = 0 }
    db.permissions.admin_defaut = "Nytherah"
    db.permissions.mj = db.permissions.mj or {}
    db.permissions.revision = db.permissions.revision or 0
    if (tonumber(db.version) or 0) < 2 then
        -- Les trames deviennent des dossiers narratifs (parents de quêtes) au
        -- lieu de gabarits jetables (titre/donneur/étapes à plat, dupliqués
        -- via FromTemplate) : forme incompatible, on repart d'une bibliothèque
        -- de trames vide. Les quêtes existantes ne sont pas affectées.
        db.trames = {}
    end
    db.trames, db.quetes = db.trames or {}, db.quetes or {}
    db.contacts, db.outbox = db.contacts or {}, db.outbox or {}
    db.sequence = db.sequence or 0
    if (tonumber(db.version) or 0) < 3 then
        -- Ajout des chapitres (subdivisions optionnelles d'une trame) et de
        -- l'ordre manuel (trames / quêtes libres) qui remplace le tri
        -- alphabétique pour permettre le glisser-déposer. Reconstruction
        -- complète à partir des quêtes existantes : aucune perte, seule la
        -- bibliothèque de chapitres démarre vide.
        db.chapitres = {}
        local function sortByTitle(list)
            table.sort(list, function(a, b) if a.titre == b.titre then return a.id < b.id end; return a.titre < b.titre end)
        end
        local byTrame = {}
        for _, q in pairs(db.quetes) do
            if q.trame_id and db.trames[q.trame_id] then
                byTrame[q.trame_id] = byTrame[q.trame_id] or {}
                table.insert(byTrame[q.trame_id], q)
            end
        end
        local trameList = {}
        for tid, t in pairs(db.trames) do
            t.chapitres = {}
            local list = byTrame[tid] or {}
            sortByTitle(list)
            t.quetes = {}
            for _, q in ipairs(list) do t.quetes[#t.quetes + 1] = q.id end
            trameList[#trameList + 1] = t
        end
        sortByTitle(trameList)
        db.trameOrder = {}
        for _, t in ipairs(trameList) do db.trameOrder[#db.trameOrder + 1] = t.id end
        local orphans = {}
        for _, q in pairs(db.quetes) do
            if not (q.trame_id and db.trames[q.trame_id]) then orphans[#orphans + 1] = q end
        end
        sortByTitle(orphans)
        db.libres = {}
        for _, q in ipairs(orphans) do db.libres[#db.libres + 1] = q.id end
    end
    db.chapitres = db.chapitres or {}
    db.trameOrder = db.trameOrder or {}
    db.libres = db.libres or {}
    db.version = self.DB_VERSION
    OmegaHubDB.Quest_MJ, self.mjDB = db, db
end

function J:NewID()
    self.mjDB.sequence = self.mjDB.sequence + 1
    return (UnitGUID("player") or self:Me()) .. ":" .. time() .. ":" .. self.mjDB.sequence
end

function J:ValidText(text, limit, required)
    return type(text) == "string" and #text <= limit and not text:find("%z")
        and (not required or text:find("%S") ~= nil)
end

function J:ValidateDraft(q)
    if type(q) ~= "table" or not self:ValidText(q.titre, 180, true) then return false, "Titre obligatoire (180 octets maximum)." end
    if not self:ValidText(q.donneur, 300) then return false, "Donneur trop long (300 octets maximum)." end
    if not self.statuses[q.statut] then return false, "Statut invalide." end
    if type(q.etapes) ~= "table" or #q.etapes < 1 or #q.etapes > 50 then return false, "Prévoir entre 1 et 50 étapes." end
    local letter = q.lettre
    if letter ~= nil and (type(letter) ~= "table" or not self:ValidText(letter.objet,300)
        or not self:ValidText(letter.expediteur,180) or not self:ValidText(letter.texte,8192)) then
        return false, "Lettre invalide : objet 300, expéditeur 180, texte 8192 octets maximum."
    end
    local bytes = #q.titre + #q.donneur + (letter and (#letter.objet+#letter.expediteur+#letter.texte) or 0)
    for _, step in ipairs(q.etapes) do
        if type(step) ~= "table" or not self:ValidText(step.texte, 8192) or type(step.revelee) ~= "boolean" then
            return false, "Chaque étape accepte au maximum 8192 octets."
        end
        bytes = bytes + #step.texte
    end
    if bytes > 50000 then return false, "La quête dépasse 50 000 octets." end
    return true
end

-- Seul ce DTO peut devenir un message de quête. Aucune copie du dossier MJ.
function J:Project(q, target)
    local dto = {
        categorie = target and q.recipientCategories and q.recipientCategories[self:Key(target)] or "personnel",
        id = q.id, titre = q.titre, donneur = q.donneur, auteur = q.auteur,
        nombre_etapes = #q.etapes, etapes_revelees = {}, statut = q.statut,
        revision = q.revision, date_creation = q.date_creation,
    }
    if q.lettre then
        dto.lettre = { objet=q.lettre.objet, expediteur=q.lettre.expediteur, texte=q.lettre.texte }
    end
    for index, step in ipairs(q.etapes) do
        if step.revelee == true then dto.etapes_revelees[index] = step.texte end
    end
    return dto
end

-- Retire un identifiant d'une liste ordonnée (appartenance = présence, rang
-- = position), puis l'insère avant `beforeID` (en fin de liste sinon).
local function insertOrdered(list, id, beforeID)
    for i, existing in ipairs(list) do
        if existing == id then table.remove(list, i); break end
    end
    if beforeID then
        for i, existing in ipairs(list) do
            if existing == beforeID then table.insert(list, i, id); return end
        end
    end
    list[#list + 1] = id
end

-- Retire une quête de son conteneur ordonné actuel (trame, chapitre ou
-- quêtes libres), sans rien faire s'il a déjà disparu.
local function detachQuest(mjDB, q)
    local list
    if q.chapitre_id then
        local c = mjDB.chapitres[q.chapitre_id]
        list = c and c.quetes
    elseif q.trame_id then
        local t = mjDB.trames[q.trame_id]
        list = t and t.quetes
    else
        list = mjDB.libres
    end
    if not list then return end
    for i, id in ipairs(list) do
        if id == q.id then table.remove(list, i); break end
    end
end

-- Place une quête (déjà détachée de son ancien conteneur) dans son nouveau
-- conteneur ordonné, selon q.trame_id / q.chapitre_id à jour.
local function attachQuest(mjDB, q, beforeID)
    local list
    if q.chapitre_id then list = mjDB.chapitres[q.chapitre_id].quetes
    elseif q.trame_id then list = mjDB.trames[q.trame_id].quetes
    else list = mjDB.libres end
    insertOrdered(list, q.id, beforeID)
end

function J:SaveQuest(draft)
    local ok, err = self:RequireMJ()
    if not ok then return nil, err end
    ok, err = self:ValidateDraft(draft)
    if not ok then return nil, err end
    local old = draft.id and self.mjDB.quetes[draft.id]
    if draft.id and not old then return nil, "Cette quête n'existe plus." end
    if old and self:Key(old.auteur) ~= self:Key(self:Me()) then return nil, "Ouvre cette quête avec son personnage MJ créateur." end
    local chapitreID = draft.chapitre_id or (old and old.chapitre_id) or nil
    if chapitreID and not self.mjDB.chapitres[chapitreID] then chapitreID = nil end
    local trameID
    if chapitreID then
        trameID = nil -- le chapitre porte déjà sa trame ; pas de double rattachement.
    else
        trameID = draft.trame_id or (old and old.trame_id) or nil
        if trameID and not self.mjDB.trames[trameID] then trameID = nil end
    end
    local q = {
        id = old and old.id or self:NewID(), auteur = self:Me(),
        titre = draft.titre, donneur = draft.donneur, etapes = self:Copy(draft.etapes),
        statut = draft.statut, date_creation = old and old.date_creation or time(),
        revision = old and old.revision + 1 or 1,
        destinataires = old and self:Copy(old.destinataires) or {},
        recipientCategories = old and self:Copy(old.recipientCategories or {}) or {},
        lettre = draft.lettre and self:Copy(draft.lettre) or nil,
        trame_id = trameID, chapitre_id = chapitreID,
    }
    self.mjDB.quetes[q.id] = q
    if old then detachQuest(self.mjDB, old) end
    attachQuest(self.mjDB, q)
    for _, target in ipairs(q.destinataires) do self:QueueQuest(q, target, "update") end
    return q
end

function J:DeleteQuest(id)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local q = self.mjDB.quetes[id]
    if not q then return false, "Quête introuvable." end
    if self:Key(q.auteur) ~= self:Key(self:Me()) then return false, "Seul le personnage créateur peut supprimer cette quête." end
    for _, target in ipairs(q.destinataires) do
        self:QueueDelivery(target, { kind = "delete", id = id, auteur = q.auteur, revision = q.revision + 1 })
    end
    detachQuest(self.mjDB, q)
    self.mjDB.quetes[id] = nil
    return true
end

-- ── Trames : dossiers narratifs regroupant plusieurs quêtes (parent/enfant) ─

function J:CreateTrame(titre, description)
    local ok, err = self:RequireMJ()
    if not ok then return nil, err end
    if not self:ValidText(titre, 180, true) then return nil, "Titre de trame obligatoire (180 octets maximum)." end
    if description ~= nil and not self:ValidText(description, 2000) then return nil, "Description trop longue (2000 octets maximum)." end
    local t = {
        id = self:NewID(), auteur = self:Me(), titre = titre, description = description or "",
        date_creation = time(), revision = 1, quetes = {}, chapitres = {},
    }
    self.mjDB.trames[t.id] = t
    self.mjDB.trameOrder[#self.mjDB.trameOrder + 1] = t.id
    return t
end

function J:SaveTrame(id, titre, description)
    local ok, err = self:RequireMJ()
    if not ok then return nil, err end
    local t = self.mjDB.trames[id]
    if not t then return nil, "Trame introuvable." end
    if self:Key(t.auteur) ~= self:Key(self:Me()) then return nil, "Ouvre cette trame avec son personnage MJ créateur." end
    if not self:ValidText(titre, 180, true) then return nil, "Titre de trame obligatoire (180 octets maximum)." end
    if description ~= nil and not self:ValidText(description, 2000) then return nil, "Description trop longue (2000 octets maximum)." end
    t.titre, t.description, t.revision = titre, description or "", t.revision + 1
    return t
end

function J:DeleteTrame(id)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local t = self.mjDB.trames[id]
    if not t then return false, "Trame introuvable." end
    if self:Key(t.auteur) ~= self:Key(self:Me()) then return false, "Seul le personnage créateur peut supprimer cette trame." end
    -- Une trame est un simple classeur : la supprimer libère ses chapitres
    -- et ses quêtes (elles redeviennent des quêtes libres) sans jamais les
    -- effacer. Un chapitre ne pouvant exister sans trame, il est supprimé.
    for _, chapitreID in ipairs(t.chapitres) do
        local c = self.mjDB.chapitres[chapitreID]
        if c then
            for _, questID in ipairs(c.quetes) do
                local q = self.mjDB.quetes[questID]
                if q then
                    q.trame_id, q.chapitre_id = nil, nil
                    self.mjDB.libres[#self.mjDB.libres + 1] = q.id
                end
            end
            self.mjDB.chapitres[chapitreID] = nil
        end
    end
    for _, questID in ipairs(t.quetes) do
        local q = self.mjDB.quetes[questID]
        if q then q.trame_id = nil; self.mjDB.libres[#self.mjDB.libres + 1] = q.id end
    end
    for i, tid in ipairs(self.mjDB.trameOrder) do
        if tid == id then table.remove(self.mjDB.trameOrder, i); break end
    end
    self.mjDB.trames[id] = nil
    return true
end

-- Rattache une quête à une trame ou un chapitre, ou la détache (kind =
-- "libre"). beforeID (optionnel) : identifiant devant lequel insérer, sinon
-- ajout en fin de liste.
function J:SetQuestParent(questID, kind, parentID, beforeID)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local q = self.mjDB.quetes[questID]
    if not q then return false, "Quête introuvable." end
    if self:Key(q.auteur) ~= self:Key(self:Me()) then return false, "Ouvre cette quête avec son personnage MJ créateur." end
    local trameID, chapitreID
    if kind == "trame" then
        local t = self.mjDB.trames[parentID]
        if not t then return false, "Trame introuvable." end
        if self:Key(t.auteur) ~= self:Key(self:Me()) then return false, "Trame d'un autre personnage MJ." end
        trameID = parentID
    elseif kind == "chapitre" then
        local c = self.mjDB.chapitres[parentID]
        if not c then return false, "Chapitre introuvable." end
        if self:Key(c.auteur) ~= self:Key(self:Me()) then return false, "Chapitre d'un autre personnage MJ." end
        chapitreID = parentID
    elseif kind ~= "libre" then
        return false, "Destination invalide."
    end
    detachQuest(self.mjDB, q)
    q.trame_id, q.chapitre_id = trameID, chapitreID
    attachQuest(self.mjDB, q, beforeID)
    return true
end

-- ── Chapitres : subdivisions optionnelles d'une trame, toujours enfants
-- d'une trame (jamais orphelins, jamais enfants d'un autre chapitre) ───────

function J:CreateChapitre(trameID, titre)
    local ok, err = self:RequireMJ()
    if not ok then return nil, err end
    local t = self.mjDB.trames[trameID]
    if not t then return nil, "Trame introuvable." end
    if self:Key(t.auteur) ~= self:Key(self:Me()) then return nil, "Ouvre cette trame avec son personnage MJ créateur." end
    if not self:ValidText(titre, 180, true) then return nil, "Titre de chapitre obligatoire (180 octets maximum)." end
    local c = {
        id = self:NewID(), auteur = self:Me(), trame_id = trameID, titre = titre,
        date_creation = time(), revision = 1, quetes = {},
    }
    self.mjDB.chapitres[c.id] = c
    t.chapitres[#t.chapitres + 1] = c.id
    return c
end

function J:SaveChapitre(id, titre)
    local ok, err = self:RequireMJ()
    if not ok then return nil, err end
    local c = self.mjDB.chapitres[id]
    if not c then return nil, "Chapitre introuvable." end
    if self:Key(c.auteur) ~= self:Key(self:Me()) then return nil, "Ouvre ce chapitre avec son personnage MJ créateur." end
    if not self:ValidText(titre, 180, true) then return nil, "Titre de chapitre obligatoire (180 octets maximum)." end
    c.titre, c.revision = titre, c.revision + 1
    return c
end

function J:DeleteChapitre(id)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local c = self.mjDB.chapitres[id]
    if not c then return false, "Chapitre introuvable." end
    if self:Key(c.auteur) ~= self:Key(self:Me()) then return false, "Seul le personnage créateur peut supprimer ce chapitre." end
    for _, questID in ipairs(c.quetes) do
        local q = self.mjDB.quetes[questID]
        if q then q.trame_id, q.chapitre_id = nil, nil; self.mjDB.libres[#self.mjDB.libres + 1] = q.id end
    end
    local t = self.mjDB.trames[c.trame_id]
    if t then
        for i, cid in ipairs(t.chapitres) do
            if cid == id then table.remove(t.chapitres, i); break end
        end
    end
    self.mjDB.chapitres[id] = nil
    return true
end

-- Déplace un chapitre vers une trame (éventuellement la même), avant beforeID.
function J:SetChapitreParent(chapitreID, trameID, beforeID)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local c = self.mjDB.chapitres[chapitreID]
    if not c then return false, "Chapitre introuvable." end
    if self:Key(c.auteur) ~= self:Key(self:Me()) then return false, "Ouvre ce chapitre avec son personnage MJ créateur." end
    local t = self.mjDB.trames[trameID]
    if not t then return false, "Trame introuvable." end
    if self:Key(t.auteur) ~= self:Key(self:Me()) then return false, "Trame d'un autre personnage MJ." end
    local old = self.mjDB.trames[c.trame_id]
    if old then
        for i, cid in ipairs(old.chapitres) do
            if cid == chapitreID then table.remove(old.chapitres, i); break end
        end
    end
    c.trame_id = trameID
    insertOrdered(t.chapitres, chapitreID, beforeID)
    return true
end

-- Réordonne une trame parmi les siennes (aucune reparentification possible).
function J:SetTrameOrder(trameID, beforeID)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local t = self.mjDB.trames[trameID]
    if not t then return false, "Trame introuvable." end
    if self:Key(t.auteur) ~= self:Key(self:Me()) then return false, "Trame d'un autre personnage MJ." end
    insertOrdered(self.mjDB.trameOrder, trameID, beforeID)
    return true
end

function J:GroupTargets(raidOnly)
    local targets = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do targets[#targets + 1] = self:UnitName("raid" .. i) end
    elseif not raidOnly and IsInGroup() then
        targets[1] = self:Me()
        for i = 1, GetNumSubgroupMembers() do targets[#targets + 1] = self:UnitName("party" .. i) end
    end
    return targets
end

function J:Distribute(id, targets, mode)
    local ok, err = self:RequireMJ()
    if not ok then return false, err end
    local q = self.mjDB.quetes[id]
    if not q or self:Key(q.auteur) ~= self:Key(self:Me()) then return false, "Enregistre une quête de ce personnage MJ." end
    local unique, recipients = {}, {}
    for _, target in ipairs(targets) do
        local name = self:Name(target)
        if not name then return false, "Nom de destinataire invalide." end
        if not unique[self:Key(name)] then
            unique[self:Key(name)] = true
            recipients[#recipients + 1] = name
        end
    end
    if #recipients == 0 then return false, "Aucun destinataire : vérifie le nom ou ton groupe / raid." end
    q.recipientCategories=q.recipientCategories or {}
    -- La catégorie appartient à la remise : une même quête peut être
    -- personnelle pour un destinataire et collective pour un autre.
    local category=(mode=="group" or mode=="raid") and "groupe" or "personnel"
    local changed=false
    for _,target in ipairs(recipients) do
        local key=self:Key(target)
        if (q.recipientCategories[key] or "personnel")~=category then changed=true end
        q.recipientCategories[key]=category
    end
    if changed then q.revision=q.revision+1 end
    for _, target in ipairs(recipients) do
        local known = false
        for _, name in ipairs(q.destinataires) do if self:Key(name) == self:Key(target) then known = true end end
        if not known then q.destinataires[#q.destinataires + 1] = target end
        self.mjDB.contacts[target] = true
        if self:IsAdmin() then self:SendPermissions(target) end
        self:QueueQuest(q, target, mode == "unlock" and "unlock" or "letter")
    end
    return true, #recipients .. " remise(s) en attente de réception."
end
