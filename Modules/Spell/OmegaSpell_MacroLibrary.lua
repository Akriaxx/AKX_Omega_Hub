-- OmegaSpell - Bibliotheque de macros Omega

OmegaSpell = OmegaSpell or {}
OmegaSpell.MacroLibrary = OmegaSpell.MacroLibrary or {}

local OS  = OmegaSpell
local Lib = OmegaSpell.MacroLibrary

local panel

local function BodyPreview(body)
    local text = tostring(body or ""):gsub("\n+$", ""):gsub("\n", " | ")
    if #text > 52 then text = text:sub(1, 49) .. "..." end
    return text
end

local function CollectOmegaMacros(filter)
    filter = tostring(filter or ""):lower()
    local records = OS.GetSortedMacroRecords and OS.GetSortedMacroRecords() or {}
    local out = {}
    for _, record in ipairs(records) do
        local spellName = record.spellName or record.name
        local rowName = spellName
        if record.macroName and record.macroName ~= "" and record.macroName ~= spellName then
            rowName = record.macroName .. "  -  " .. spellName
        end
        if filter == "" or tostring(rowName):lower():find(filter, 1, true) or tostring(record.id or ""):lower():find(filter, 1, true) then
        local spell = OS.GetSpell(spellName)
        out[#out + 1] = {
            typeText = (record.category and record.category ~= "" and record.category)
                or (spell and spell.category and spell.category ~= "" and spell.category)
                or (record.orphaned and "Macro" or "Omega"),
            typeColorR = 0.80,
            typeColorG = 0.70,
            typeColorB = 0.40,
            name = spellName,
            displayName = rowName,
            preview = record.id or "",
            body = record.id or "",
            icon = record.icon or (spell and spell.icon) or "Interface\\Icons\\INV_Misc_QuestionMark",
            raw = record,
        }
        end
    end
    return out
end

local function CollectWoWMacros(filter)
    local results = {}
    filter = tostring(filter or ""):lower()
    if type(GetNumMacros) ~= "function" or type(GetMacroInfo) ~= "function" then
        return results
    end

    local globalCount, charCount = GetNumMacros()
    local accountMax = MAX_ACCOUNT_MACROS or 120
    local function TryAdd(index, isChar)
        local name, iconTexture, body = GetMacroInfo(index)
        if not name or name == "" then return end
        if filter ~= "" and not name:lower():find(filter, 1, true) then return end
        local iconOverride = OmegaSpellDB and OmegaSpellDB.macroIconOverrides and OmegaSpellDB.macroIconOverrides[name]
        results[#results + 1] = {
            typeText = isChar and "Perso" or "Global",
            typeColorR = isChar and 0.80 or 0.55,
            typeColorG = isChar and 0.70 or 0.75,
            typeColorB = isChar and 0.40 or 1.00,
            index = index,
            name = name,
            displayName = name,
            preview = BodyPreview(body),
            icon = iconOverride or iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark",
            isIconMask = iconOverride ~= nil,
            body = body or "",
            isChar = isChar,
        }
    end

    for i = 1, globalCount do TryAdd(i, false) end
    for i = 1, charCount do TryAdd(accountMax + i, true) end
    return results
end

local function Build()
    if panel then return panel end

    panel = OS.MacroInterface.Create({
        frameName = "OmegaSpellMacroLibraryPanel",
        defaultMode = "omega",
        x = 80,
        y = 40,
        frameLevel = 127,
        onOpen = function()
            if OS.Bar and OS.Bar.Refresh then OS.Bar.Refresh() end
        end,
        onClose = function()
            if OS.Bar and OS.Bar.Refresh then OS.Bar.Refresh() end
        end,
        modes = {
            omega = {
                title = "Macros Omega",
                emptyText = "Aucune macro Omega créée.",
                collect = CollectOmegaMacros,
                primaryAction = {
                    label = "Modif.",
                    width = 52,
                    onClick = function(row, p)
                        local spellName = (row.raw and row.raw.spellName) or row.name
                        if row.raw and row.raw.orphaned and OS.RestoreSpellFromMacroID then
                            local ok, restoredName = OS.RestoreSpellFromMacroID(row.raw.id)
                            if not ok then return false, restoredName or "Restauration impossible." end
                            spellName = restoredName
                        end
                        if OmegaSpell.UI and OmegaSpell.UI.SelectSpell then
                            OmegaSpell.UI.SelectSpell(spellName)
                            p:Hide()
                        end
                        return true, ""
                    end,
                },
                secondaryAction = {
                    label = "> Barre",
                    width = 58,
                    onClick = function(row)
                        local macroID = row.raw and row.raw.id
                        local ok, msg = OmegaSpell.Bar and OmegaSpell.Bar.PickMacro and OmegaSpell.Bar.PickMacro(macroID)
                        return ok, ok and (msg or "Macro prise - cliquez sur un slot.") or (msg or "Impossible.")
                    end,
                },
                deleteAction = {
                    label = "Supprimer",
                    width = 76,
                    refresh = true,
                    onClick = function(row)
                        local macroID = row.raw and row.raw.id
                        if not macroID or macroID == "" then
                            return false, "Macro introuvable."
                        end
                        if not (OS.DeleteMacroByID) then
                            return false, "Suppression indisponible."
                        end
                        local ok, result = OS.DeleteMacroByID(macroID)
                        return ok, ok and ("Macro supprimée : " .. tostring(result or macroID)) or (result or "Suppression impossible.")
                    end,
                },
            },
            wow = {
                title = "Macros WoW",
                emptyText = "Aucune macro WoW créée.",
                collect = CollectWoWMacros,
                actions = {
                    {
                        label = "> Barre",
                        width = 58,
                        onClick = function(row)
                            local ok, msg = OS.Bar and OS.Bar.PickWoWMacro and OS.Bar.PickWoWMacro(row)
                            return ok, ok and (msg or "Macro WoW prise - cliquez sur un slot.") or (msg or "Impossible.")
                        end,
                    },
                    {
                        label = "Icône",
                        width = 52,
                        refresh = true,
                        onClick = function(row)
                            if IsShiftKeyDown and IsShiftKeyDown() then
                                OmegaSpellDB = OmegaSpellDB or {}
                                OmegaSpellDB.macroIconOverrides = OmegaSpellDB.macroIconOverrides or {}
                                OmegaSpellDB.macroIconOverrides[row.name] = nil
                                if OS.Bar and OS.Bar.Refresh then OS.Bar.Refresh() end
                                return true, "Icône réinitialisée : " .. row.name
                            end
                            if not (OmegaSpell.IconBrowser and OmegaSpell.IconBrowser.Open) then
                                return false, "Navigateur d'icônes indisponible."
                            end
                            OmegaSpell.IconBrowser.Open(function(iconPath)
                                if not iconPath or iconPath == "" then return end
                                OmegaSpellDB = OmegaSpellDB or {}
                                OmegaSpellDB.macroIconOverrides = OmegaSpellDB.macroIconOverrides or {}
                                OmegaSpellDB.macroIconOverrides[row.name] = iconPath
                                if panel then panel:SetStatus("Icône personnalisée : " .. row.name); panel:Refresh() end
                                if OS.Bar and OS.Bar.Refresh then OS.Bar.Refresh() end
                            end)
                            return true, "Choisissez une icône."
                        end,
                    },
                },
                deleteAction = {
                    label = "Supprimer",
                    width = 76,
                    onClick = function()
                        return false, "Les macros WoW natives ne sont pas supprimées ici."
                    end,
                },
            },
        },
    })

    return panel
end

function Lib.Open(mode)
    Build():Open(mode or "omega")
end

function Lib.IsShown()
    return panel and panel:IsShown()
end

function Lib.Refresh()
    if panel and panel:IsShown() then panel:Refresh() end
end

function Lib.Close()
    if panel then panel:Hide() end
end
