local J = Quest
J.PREFIX = "OMEGAHUB_QUEST"

-- Sérialisation typée à longueurs explicites. Aucune exécution de Lua reçu.
function J:Serialize(value)
    local nodes = 0
    local function encode(v, depth)
        nodes = nodes + 1
        assert(depth <= 8 and nodes <= 2000, "Message trop complexe")
        if type(v) == "string" then
            assert(#v <= 50000 and not v:find("%z"), "Chaîne invalide")
            return "s" .. #v .. ":" .. v
        elseif type(v) == "number" then
            assert(v == math.floor(v) and math.abs(v) <= 100000000000, "Nombre invalide")
            return "n" .. string.format("%.0f", v) .. ":"
        elseif type(v) == "boolean" then return v and "b1" or "b0"
        elseif type(v) == "table" then
            local result, count = {}, 0
            for k, item in pairs(v) do
                assert(type(k) == "string" or type(k) == "number", "Clé invalide")
                count = count + 1
                result[#result + 1] = encode(k, depth + 1) .. encode(item, depth + 1)
            end
            return "t" .. count .. ":" .. table.concat(result)
        end
        error("Type non sérialisable")
    end
    local result = encode(value, 0)
    assert(#result <= 60000, "Message trop long")
    return result
end

function J:Deserialize(message)
    if type(message) ~= "string" or #message > 60000 then return nil end
    local pos, nodes = 1, 0
    local function numberToken()
        local finish = message:find(":", pos, true)
        assert(finish and finish - pos <= 12, "Longueur invalide")
        local token = message:sub(pos, finish - 1)
        assert(token:match("^%-?%d+$"), "Nombre invalide")
        pos = finish + 1
        return tonumber(token)
    end
    local function decode(depth)
        nodes = nodes + 1
        assert(depth <= 8 and nodes <= 2000, "Structure trop complexe")
        local tag = message:sub(pos, pos)
        pos = pos + 1
        if tag == "s" then
            local count = numberToken()
            assert(count >= 0 and count <= 50000 and pos + count - 1 <= #message, "Chaîne tronquée")
            local value = message:sub(pos, pos + count - 1)
            assert(not value:find("%z"), "Caractère nul")
            pos = pos + count
            return value
        elseif tag == "n" then
            local value = numberToken()
            assert(math.abs(value) <= 100000000000, "Nombre hors limites")
            return value
        elseif tag == "b" then
            local value = message:sub(pos, pos)
            assert(value == "0" or value == "1", "Booléen invalide")
            pos = pos + 1
            return value == "1"
        elseif tag == "t" then
            local count, result = numberToken(), {}
            assert(count >= 0 and count <= 1000, "Table trop grande")
            for _ = 1, count do
                local key = decode(depth + 1)
                assert(type(key) == "string" or type(key) == "number", "Clé invalide")
                assert(result[key] == nil, "Clé dupliquée")
                result[key] = decode(depth + 1)
            end
            return result
        end
        error("Type inconnu")
    end
    local ok, result = pcall(decode, 0)
    if ok and pos == #message + 1 then return result end
end

-- Barrière finale : reconstruire aussi l'enveloppe par liste blanche.
-- Un champ de travail ajouté par erreur ne doit jamais atteindre le réseau.
function J:PublicEnvelope(source)
    if type(source) ~= "table" then return nil end
    local kind = source.kind
    if kind == "quest" then
        if not self:IsMJ() or not self:ValidateProjection(source.quest) or self:Key(source.quest.auteur) ~= self:Key(self:Me()) then return nil end
        local mode = source.mode == "letter" and "letter" or source.mode == "unlock" and "unlock" or "update"
        return { kind = kind, quest = self:Copy(source.quest), mode = mode }
    elseif kind == "delete" or kind == "ack" then
        if not self:ValidText(source.id, 160, true) or not self:IsInteger(source.revision, 1, 1000000000) then return nil end
        local result = { kind = kind, id = source.id, revision = source.revision }
        if kind == "delete" then
            if not self:IsMJ() or self:Key(source.auteur) ~= self:Key(self:Me()) then return nil end
            result.auteur = self:Me()
        end
        return result
    elseif kind == "hello" then return { kind = kind }
    elseif kind == "permissions" and self:IsAdmin() then
        -- Toujours relire la liste officielle locale, jamais une table arbitraire.
        return { kind = kind, revision = self.mjDB.permissions.revision, mj = self:Copy(self.mjDB.permissions.mj) }
    end
end

-- Toutes les distributions, y compris groupe et raid, sont des whispers addon.
function J:SendWire(target, envelope, deliveryKey)
    target = self:Name(target)
    if not target or not self.enabled then return false end
    envelope = self:PublicEnvelope(envelope)
    if not envelope then return false end
    local ok, payload = pcall(self.Serialize, self, envelope)
    if not ok then return false end
    self.wireSequence = (self.wireSequence or 0) + 1
    local transfer = self.session .. "." .. self.wireSequence
    local total = math.ceil(#payload / 180)
    local packets = {}
    for part = 1, total do
        packets[part] = "J1:" .. transfer .. ":" .. part .. ":" .. total .. ":" .. payload:sub((part - 1) * 180 + 1, part * 180)
    end
    if #self.wireQueue >= 200 then return false end
    local tx = { target = target, packets = packets, part = 1, key = deliveryKey }
    if not deliveryKey then
        -- Les contrôles passent avant les longues remises, sans interrompre
        -- une transmission déjà commencée ni affamer les autres contrôles.
        local index = 1
        while self.wireQueue[index] and (not self.wireQueue[index].key or self.wireQueue[index].part > 1) do index = index + 1 end
        table.insert(self.wireQueue, index, tx)
    else self.wireQueue[#self.wireQueue + 1] = tx end
    return true
end

function J:QueueDelivery(target, envelope)
    target = self:Name(target)
    if not target or not self.enabled then return false end
    envelope = self:PublicEnvelope(envelope)
    if not envelope or (envelope.kind ~= "quest" and envelope.kind ~= "delete") then return false end
    local id = envelope.kind == "quest" and envelope.quest.id or envelope.id
    local key = self:Key(target) .. "/" .. id
    -- Coalescer : une remise en attente contient toujours le dernier état public.
    local old = self.mjDB.outbox[key]
    if old and old.message.kind == "quest" and envelope.kind == "quest" and envelope.mode == "update" then
        envelope.mode = old.message.mode
    end
    self.mjDB.outbox[key] = { target = target, auteur = self:Me(), message = self:Copy(envelope) }
    self.deliveryState[key] = nil
    for i = #self.wireQueue, 1, -1 do if self.wireQueue[i].key == key then table.remove(self.wireQueue, i) end end
    return true
end

function J:QueueQuest(q, target, mode)
    return self:QueueDelivery(target, { kind = "quest", quest = self:Project(q,target), mode = mode })
end

function J:SendPermissions(target)
    if not self:IsAdmin() then return end
    self:SendWire(target, { kind = "permissions", revision = self.mjDB.permissions.revision, mj = self:Copy(self.mjDB.permissions.mj) })
end

function J:BroadcastPermissions()
    if not self:IsAdmin() then return end
    local targets = self:Copy(self.mjDB.contacts)
    for _, name in ipairs(self.mjDB.permissions.mj) do targets[name] = true end
    for _, name in ipairs(self:GroupTargets()) do targets[name] = true end
    for name in pairs(targets) do self:SendPermissions(name) end
end

function J:RequestPermissions()
    if self:IsAdmin() then return end
    if self.lastPermissionRequest and GetTime() - self.lastPermissionRequest < 10 then return end
    self.lastPermissionRequest = GetTime()
    self:SendWire("Nytherah", { kind = "hello" })
end

function J:HandleMessage(data, sender)
    if type(data) ~= "table" or type(data.kind) ~= "string" then return end
    if data.kind == "hello" then
        local key = self:Key(sender)
        if self.helloTimes[key] and GetTime() - self.helloTimes[key] < 10 then return end
        self.helloTimes[key] = GetTime()
        if self:IsAdmin() then
            self.mjDB.contacts[sender] = true
            self:SendPermissions(sender)
        end
        for id, pending in pairs(self.mjDB.outbox) do
            if self:Key(pending.target) == key and not (self.deliveryState[id] and self.deliveryState[id].queued) then
                self.deliveryState[id] = nil
            end
        end
    elseif data.kind == "permissions" then
        if self:AcceptPermissions(data, sender) then
            local waiting = self.waitingTrust
            self.waitingTrust = {}
            for _, entry in ipairs(waiting) do
                if self:IsMJ(entry.sender) then self:HandleMessage(entry.data, entry.sender) end
            end
        end
    elseif data.kind == "ack" then
        if not self:ValidText(data.id, 160, true) or not self:IsInteger(data.revision, 1, 1000000000) then return end
        local key = self:Key(sender) .. "/" .. data.id
        local pending = self.mjDB.outbox[key]
        if pending then
            local revision = pending.message.kind == "quest" and pending.message.quest.revision or pending.message.revision
            if revision == data.revision then
                self.mjDB.outbox[key], self.deliveryState[key] = nil, nil
                if self.RefreshDeliveryStatus then self:RefreshDeliveryStatus() end
            end
        end
    elseif data.kind == "quest" or data.kind == "delete" then
        if not self:IsMJ(sender) then
            -- Attente courte, bornée, jusqu'à une réponse directe de Nytherah.
            if #self.waitingTrust < 8 then
                self.waitingTrust[#self.waitingTrust + 1] = { data = data, sender = sender, at = GetTime() }
            end
            self:RequestPermissions()
            return
        end
        local accepted = data.kind == "quest" and self:AcceptQuest(data.quest, sender, data.mode)
        if data.kind == "delete" then accepted = self:AcceptDelete(data, sender) end
        if accepted then
            local q = data.kind == "quest" and data.quest or data
            self:SendWire(sender, { kind = "ack", id = q.id, revision = q.revision })
        end
    end
end

function J:Receive(prefix, text, channel, sender)
    if not self.enabled or prefix ~= self.PREFIX or channel ~= "WHISPER" then return end
    sender = self:Name(sender)
    if not sender or type(text) ~= "string" or #text > 255 then return end
    local transfer, part, total, body = text:match("^J1:([%w%.]+):(%d+):(%d+):(.*)$")
    part, total = tonumber(part), tonumber(total)
    if not transfer or #transfer > 40 or not self:IsInteger(total, 1, 334) or not self:IsInteger(part, 1, total) or #body > 180 then return end
    local key = self:Key(sender) .. "/" .. transfer
    local entry = self.incoming[key]
    if not entry then
        local count, perSender = 0, 0
        for _, value in pairs(self.incoming) do
            count = count + 1
            if value.sender == sender then perSender = perSender + 1 end
        end
        if count >= 64 or perSender >= 4 then return end
        entry = { sender = sender, total = total, parts = {}, count = 0, at = GetTime(), bytes = 0 }
        self.incoming[key] = entry
    end
    if entry.total ~= total then self.incoming[key] = nil; return end
    if not entry.parts[part] then
        entry.parts[part], entry.count = body, entry.count + 1
        entry.bytes = entry.bytes + #body
    elseif entry.parts[part] ~= body then self.incoming[key] = nil; return end
    if entry.bytes > 60000 then self.incoming[key] = nil; return end
    if entry.count == total then
        self.incoming[key] = nil
        local data = self:Deserialize(table.concat(entry.parts))
        if data then self:HandleMessage(data, sender) end
    end
end

function J:Pump()
    local now = GetTime()
    for key, entry in pairs(self.incoming) do if now - entry.at > 600 then self.incoming[key] = nil end end
    for i = #self.waitingTrust, 1, -1 do if now - self.waitingTrust[i].at > 90 then table.remove(self.waitingTrust, i) end end
    if self:IsMJ() then
        for key, pending in pairs(self.mjDB.outbox) do
            local state = self.deliveryState[key]
            if self:Key(pending.auteur) == self:Key(self:Me()) and (not state or (not state.queued and now >= state.nextTry)) then
                state = state or { tries = 0 }
                if self:SendWire(pending.target, pending.message, key) then
                    state.tries, state.queued = state.tries + 1, true
                    self.deliveryState[key] = state
                end
            end
        end
    end
    local tx = self.wireQueue[1]
    if not tx then return end
    -- Une révocation annule aussi les fragments qui attendaient déjà leur tour.
    if tx.key and not self:IsMJ() then table.remove(self.wireQueue, 1); self.deliveryState[tx.key] = nil; return end
    local result = select(-1, C_ChatInfo.SendAddonMessage(self.PREFIX, tx.packets[tx.part], "WHISPER", tx.target))
    local success = result == true or result == 0
    if Enum and Enum.SendAddonMessageResult then success = success or result == Enum.SendAddonMessageResult.Success end
    if success then
        tx.part = tx.part + 1
        if tx.part <= #tx.packets then return end
    else
        tx.failures = (tx.failures or 0) + 1
        if tx.failures < 3 then return end
    end
    table.remove(self.wireQueue, 1)
    if tx.key and self.deliveryState[tx.key] then
        local state = self.deliveryState[tx.key]
        state.queued = false
        state.nextTry = now + math.min(300, 30 * state.tries)
    end
end

function J:StartComm()
    self.wireQueue, self.incoming, self.deliveryState, self.waitingTrust, self.helloTimes = {}, {}, {}, {}, {}
    self.session = tostring(time()) .. "." .. tostring(math.random(100000, 999999))
    C_ChatInfo.RegisterAddonMessagePrefix(self.PREFIX)
    self.commFrame = self.commFrame or CreateFrame("Frame")
    self.commFrame:RegisterEvent("CHAT_MSG_ADDON")
    self.commFrame:SetScript("OnEvent", function(_, _, ...) self:Receive(...) end)
    local elapsed = 0
    self.commFrame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1.05 then elapsed = 0; self:Pump() end
    end)
    self.lastPermissionRequest = nil
    self:RequestPermissions()
    local owners = {}
    for _, q in pairs(self.playerDB.quetes) do owners[q.auteur] = true end
    for _, q in pairs(self.playerDB.tombstones) do owners[q.auteur] = true end
    for name in pairs(owners) do self:SendWire(name, { kind = "hello" }) end
    if self:IsAdmin() then self:BroadcastPermissions() end
end

function J:StopComm()
    if self.commFrame then
        self.commFrame:UnregisterAllEvents()
        self.commFrame:SetScript("OnUpdate", nil)
    end
    self.wireQueue, self.incoming, self.waitingTrust = {}, {}, {}
end
