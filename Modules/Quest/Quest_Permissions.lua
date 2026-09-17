local J = Quest

-- Un nom sans royaume désigne exclusivement le royaume local.
function J:Name(name)
    if type(name) ~= "string" then return nil end
    name = name:match("^%s*(.-)%s*$")
    if name == "" or #name > 100 or name:gsub("-", ""):find("[%s%p%d%c]") then return nil end
    if name:match("^%-") or name:match("%-$") or select(2, name:gsub("-", "")) > 1 then return nil end
    if not name:find("-", 1, true) then
        name = name .. "-" .. (GetNormalizedRealmName() or GetRealmName():gsub("%s", ""))
    end
    return name
end

function J:Key(name)
    local full = self:Name(name)
    return full and string.lower(full)
end

function J:UnitName(unit)
    local name, realm = UnitFullName(unit)
    if not name then return nil end
    return self:Name(name .. ((realm and realm ~= "") and ("-" .. realm) or ""))
end

function J:Me() return self:UnitName("player") end
function J:IsAdmin(name) return self:Key(name or self:Me()) == self:Key("Nytherah") end

function J:IsMJ(name)
    name = name or self:Me()
    if self:IsAdmin(name) then return true end
    local key = self:Key(name)
    for _, mj in ipairs(self.mjDB.permissions.mj) do
        if self:Key(mj) == key then return true end
    end
    return false
end

function J:RequireMJ()
    if not self.enabled or not self:IsMJ() then
        return false, "Ce panneau est réservé aux MJ autorisés."
    end
    return true
end

function J:SetMJ(name, grant)
    if not self.enabled or not self:IsAdmin() then return false, "Seule Nytherah gère les accès." end
    name = self:Name(name)
    if not name then return false, "Nom de personnage invalide." end
    if self:IsAdmin(name) then return false, "Nytherah reste toujours administratrice." end
    local p = self.mjDB.permissions
    for i = #p.mj, 1, -1 do
        if self:Key(p.mj[i]) == self:Key(name) then table.remove(p.mj, i) end
    end
    if grant and #p.mj >= 100 then return false, "La liste est limitée à 100 MJ." end
    if grant then p.mj[#p.mj + 1] = name end
    p.revision = p.revision + 1
    self.mjDB.contacts[name] = true
    self:BroadcastPermissions()
    return true
end

function J:AcceptPermissions(data, sender)
    if not self:IsAdmin(sender) or type(data) ~= "table" then return false end
    if not self:IsInteger(data.revision, 0, 1000000000) or type(data.mj) ~= "table" or #data.mj > 100 then return false end
    if data.revision < self.mjDB.permissions.revision then return false end
    local names, seen = {}, {}
    for key, value in pairs(data.mj) do
        if not self:IsInteger(key, 1, #data.mj) then return false end
        local name = self:Name(value)
        if not name or seen[self:Key(name)] then return false end
        seen[self:Key(name)] = true
        names[#names + 1] = name
    end
    if #names ~= #data.mj then return false end
    self.mjDB.permissions = { admin_defaut = "Nytherah", mj = names, revision = data.revision }
    if self.panel and not self:IsMJ() then self.panel:Hide() end
    if self.panel and self.panel:IsShown() and self.RefreshAccess then self:RefreshAccess() end
    if self.RefreshBook then self:RefreshBook() end
    return true
end
