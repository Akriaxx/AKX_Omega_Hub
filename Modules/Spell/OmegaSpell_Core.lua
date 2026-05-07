-- OmegaSpell - Core.lua
-- /omsp [canal] [groupe]  => envoie une phrase aleatoire du groupe.
-- /omsp cast [sort]       => lance un sort RP randomise.
-- /omsp macro [sort]      => cree/met a jour une macro Omega.
-- /omsp ui                => ouvre le panel de gestion.

OmegaSpell = OmegaSpell or {}
local OS = OmegaSpell

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function Trim(s)
    if type(s) ~= "string" then return "" end
    return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function UpperFirst(s)
    if type(s) ~= "string" or s == "" then return s end
    local leading, first, rest = s:match("^(%s*)(%S)(.*)$")
    if not first then return s end
    return leading .. string.upper(first) .. rest
end

local function SplitArgs(msg)
    msg = Trim(msg or "")
    if msg == "" then return nil, nil, nil end

    -- whisper NomCible Groupe
    local a, b, c = msg:match("^(%S+)%s+(%S+)%s+(.+)$")
    if a and b and c then return a, b, Trim(c) end

    -- canal Groupe
    local x, y = msg:match("^(%S+)%s+(.+)$")
    if x and y then return x, Trim(y), nil end

    return msg, nil, nil
end

local function JoinArgs(first, rest)
    if rest and rest ~= "" then
        return Trim((first or "") .. " " .. rest)
    end
    return Trim(first or "")
end

local function MacroBody(text)
    text = tostring(text or "")
    if #text > 255 then
        text = text:sub(1, 255)
    end
    return text
end

local function MacroBodyMatches(index, macroID)
    if type(GetMacroInfo) ~= "function" then
        return true
    end

    local _, _, body = GetMacroInfo(index)
    return tostring(body or ""):find(tostring(macroID or ""), 1, true) ~= nil
end

local function FindOmegaMacroIndex(spell, macroID, macroName)
    if type(GetMacroIndexByName) ~= "function" then
        return 0
    end

    local candidates = {}
    candidates[#candidates + 1] = spell and spell.macroCreatedName or ""
    candidates[#candidates + 1] = macroID
    candidates[#candidates + 1] = macroName

    local seen = {}
    for _, name in ipairs(candidates) do
        name = Trim(name or "")
        if name ~= "" and not seen[name] then
            seen[name] = true
            local index = GetMacroIndexByName(name) or 0
            if index > 0 and (name ~= macroName or MacroBodyMatches(index, macroID)) then
                return index
            end
        end
    end

    return 0
end

local function SaveAddonMacroFallback(spellName, reason)
    if OS.SaveAddonMacro then
        local ok, macroID = OS.SaveAddonMacro(spellName)
        if ok then
            local msg = "Macro stockée dans Omega"
            if reason and reason ~= "" then
                msg = msg .. " (" .. reason .. ")"
            end
            msg = msg .. " : " .. tostring(macroID)
            print("|cff66ccffOmegaSpell|r: " .. msg)
            return true, msg
        end
    end

    local msg = reason or "Création de macro impossible."
    print("|cff66ccffOmegaSpell|r: " .. msg)
    return false, msg
end

local function FriendlyMacroError(err)
    err = tostring(err or "")
    if err:find("already have", 1, true) or err:find("120 macros", 1, true) then
        return "limite des macros WoW atteinte"
    end
    if err == "" then
        return "création WoW refusée"
    end
    return err
end

local function CanonChannel(ch)
    ch = (ch or ""):lower()
    local map = {
        ["say"]      = "SAY",      ["s"] = "SAY",
        ["yell"]     = "YELL",     ["y"] = "YELL",
        ["emote"]    = "EMOTE",    ["e"] = "EMOTE",
        ["party"]    = "PARTY",    ["p"] = "PARTY",
        ["raid"]     = "RAID",     ["r"] = "RAID",
        ["guild"]    = "GUILD",    ["g"] = "GUILD",
        ["officer"]  = "OFFICER",  ["o"] = "OFFICER",
        ["instance"] = "INSTANCE_CHAT", ["i"] = "INSTANCE_CHAT",
        ["whisper"]  = "WHISPER",  ["w"] = "WHISPER",
    }
    return map[ch]
end

local function PickRandom(tbl)
    if type(tbl) ~= "table" or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

local function PrintHelp()
    local c  = "|cff66ccff"
    local m  = "|cffAAAAAA"
    local g  = "|cff88cc44"
    local r  = "|r"

    print(c .. "OmegaSpell" .. r .. "  -  createur de sorts RP et macros")
    print(m .. "  /omsp " .. r .. "[canal] [groupe]")
    print(m .. "  /omsp " .. r .. "cast [sort]")
    print(m .. "  /omsp " .. r .. "macro [sort]")
    print(m .. "  /omsp " .. r .. "bar")
    print(m .. "  /omsp " .. r .. "whisper [cible] [groupe]")
    print(m .. "  /omsp " .. r .. "ui")
    print(m .. "  Canaux : " .. r .. "say  yell  emote  party  raid  guild  officer  instance  whisper")

    local names = OS.GetSortedGroupNames()
    if #names > 0 then
        print(m .. "  Groupes d'emotes : " .. r .. g .. table.concat(names, r .. "  " .. g))
    end
end

local function Send(text, channel, target)
    if type(SendChatMessage) ~= "function" then return end
    if not text or text == "" then return end

    if channel ~= "EMOTE" then
        text = "*" .. UpperFirst(text) .. "*"
    end

    if channel == "WHISPER" then
        if not target or target == "" then
            print("|cff66ccffOmegaSpell|r: Whisper demande une cible.")
            return
        end
        SendChatMessage(text, "WHISPER", nil, target)
        return
    end

    SendChatMessage(text, channel)
end

local function GetSpellText(spell)
    local variant = OS.GetRandomVariant(spell)
    if not variant then return nil end

    if type(variant) == "string" then
        return variant, spell.channel or "EMOTE"
    end

    if type(variant) == "table" and variant.type == "emoteGroup" then
        local group = OS.GetEmoteGroup(variant.group)
        local text = PickRandom(group)
        return text, spell.channel or "EMOTE"
    end

    return variant.text, spell.channel or variant.channel or "EMOTE"
end

local function GetArcaneumLink(spell)
    if type(spell) ~= "table" then return nil end

    if type(spell.arcaneum) == "table" and Trim(spell.arcaneum.commID) ~= "" then
        return Trim(spell.arcaneum.commID), spell.arcaneum.vault or "personal"
    end

    for _, line in ipairs(spell.macroLines or {}) do
        local macroLine = tostring(line or "")
        local commID = macroLine:match("ARC%.PHASE:CAST%(%s*['\"]([^'\"]+)['\"]%s*%)")
            or macroLine:match("ARC:CASTP%(%s*['\"]([^'\"]+)['\"]%s*%)")
        if commID and commID ~= "" then
            return commID, "phase"
        end

        commID = macroLine:match("ARC:CAST%(%s*['\"]([^'\"]+)['\"]%s*%)")
        if commID and commID ~= "" then
            return commID, "personal"
        end
    end

    return nil
end

local function CastLinkedArcaneum(spell)
    local commID, vault = GetArcaneumLink(spell)
    if not commID then return false end

    if OS.Arcaneum and OS.Arcaneum.Cast then
        local ok, err = OS.Arcaneum.Cast(commID, vault)
        if not ok then
            print("|cff66ccffOmegaSpell|r: " .. (err or "Sort Arcaneum impossible."))
        end
        return ok
    end

    if vault == "phase" and type(ARC) == "table" and type(ARC.PHASE) == "table" and type(ARC.PHASE.CAST) == "function" then
        ARC.PHASE:CAST(commID, true)
        return true
    end

    if type(ARC) == "table" and type(ARC.CAST) == "function" then
        ARC:CAST(commID)
        return true
    end

    print("|cff66ccffOmegaSpell|r: Arcaneum n'est pas charge.")
    return false
end

function OS.CastSpell(spellName, overrideChannel, target)
    local spell, realName = OS.GetSpell(spellName)
    if not spell then
        print("|cff66ccffOmegaSpell|r: Sort inconnu: " .. tostring(spellName))
        return
    end

    local arcaneumCasted = CastLinkedArcaneum(spell)
    local text, channel = GetSpellText(spell)
    if not text then
        if not arcaneumCasted then
            print("|cff66ccffOmegaSpell|r: Sort vide: " .. tostring(realName))
        end
        return
    end

    Send(text, overrideChannel or channel, target)
end

function OS.CastSpellByMacroID(macroID)
    local spell, realName = OS.GetSpellByMacroID(macroID)
    if not spell then
        print("|cff66ccffOmegaSpell|r: Macro inconnue: " .. tostring(macroID))
        return
    end

    OS.CastSpell(realName)
end

local function ExecuteArcaneumMacroLine(code)
    code = Trim(code or "")
    local commID = code:match("ARC%.PHASE:CAST%(%s*['\"]([^'\"]+)['\"]")
        or code:match("ARC:CASTP%(%s*['\"]([^'\"]+)['\"]")
    if commID and commID ~= "" then
        if OS.Arcaneum and OS.Arcaneum.Cast then
            local ok, err = OS.Arcaneum.Cast(commID, "phase")
            if ok == false then return false, err end
            return true
        end
        if type(ARC) == "table" and ARC.PHASE and type(ARC.PHASE.CAST) == "function" then
            ARC.PHASE:CAST(commID, true)
            return true
        end
    end

    commID = code:match("ARC:CAST%(%s*['\"]([^'\"]+)['\"]")
    if commID and commID ~= "" then
        if OS.Arcaneum and OS.Arcaneum.Cast then
            local ok, err = OS.Arcaneum.Cast(commID, "personal")
            if ok == false then return false, err end
            return true
        end
        if type(ARC) == "table" and type(ARC.CAST) == "function" then
            ARC:CAST(commID)
            return true
        end
    end

    return false
end

local function CompactNativeMacroArgs(args)
    args = Trim(args or "")
    if args == "" then return "" end

    if type(SecureCmdOptionParse) == "function" then
        local parsed = SecureCmdOptionParse(args)
        if parsed and parsed ~= "" then
            return Trim(parsed)
        end
    end

    args = args:gsub("^%s*%b[]%s*", "")
    return Trim(args:match("^[^;]+") or args)
end

local function ResolveNativeSlashCommand(cmd)
    if not cmd or cmd == "" or type(_G) ~= "table" or type(SlashCmdList) ~= "table" then return nil end
    local wanted = "/" .. cmd:lower()

    for key, value in pairs(_G) do
        if type(key) == "string" and type(value) == "string" and value:lower() == wanted then
            local name = key:match("^SLASH_(.-)%d+$")
            local handler = name and SlashCmdList[name]
            if type(handler) == "function" then
                return handler
            end
        end
    end

    return nil
end

local function EvalRunStringExpression(expr)
    expr = Trim(expr or "")
    local plain = expr:match("^['\"]([^'\"]*)['\"]$")
    if plain then return plain end

    local checkName, trueText, falseText = expr:match("^(Is%a+KeyDown%(%))%s*and%s*['\"]([^'\"]*)['\"]%s*or%s*['\"]([^'\"]*)['\"]$")
    if checkName then
        local fnName = checkName:match("^(Is%a+KeyDown)")
        local fn = fnName and _G and _G[fnName]
        if type(fn) == "function" and fn() then return trueText end
        return falseText
    end

    return nil
end

local function ExecuteSafeRunLine(code)
    local ok, err = ExecuteArcaneumMacroLine(code)
    if ok then return true end

    local textExpr, channel, language, target = code:match("^SendChatMessage%(%s*(.-)%s*,%s*['\"]([^'\"]+)['\"]%s*,?%s*([^,]*)%s*,?%s*([^)]*)%)$")
    if textExpr and type(SendChatMessage) == "function" then
        local text = EvalRunStringExpression(textExpr)
        if not text or text == "" then
            return false, "SendChatMessage non simulable: " .. tostring(textExpr)
        end
        language = Trim(language or "")
        target = Trim(target or "")
        if language == "" or language == "nil" then language = nil end
        if target == "" or target == "nil" then target = nil end
        SendChatMessage(text, channel, language, target)
        return true
    end

    return false, err
end

function OS.ExecuteMacroLine(line, context)
    line = Trim(line or "")
    if line == "" or line:sub(1, 1) == "#" then return true end
    if line:match("^ARC[%.:]") then
        return ExecuteArcaneumMacroLine(line)
    end
    if line:sub(1, 1) == "." then
        SendChatMessage(line, "SAY")
        return true
    end
    if line:sub(1, 1) ~= "/" then return false, "Ligne non reconnue: " .. line end

    local cmd, args = line:match("^/(%S+)%s*(.*)$")
    if not cmd then return false end

    local lower = cmd:lower()
    args = Trim(args or "")

    if lower == "omsp" then
        local subCmd, rest = args:match("^(%S+)%s*(.*)$")
        subCmd = (subCmd or ""):lower()
        rest = Trim(rest or "")
        if subCmd == "id" and context and Trim(rest) == Trim(context.macroID) then
            OS.CastSpell(context.spellName)
            return true
        end
        OS.Run(args)
        return true
    end

    local channel = CanonChannel(lower)
    if channel then
        if channel == "WHISPER" then
            local target, msg = args:match("^(%S+)%s+(.+)$")
            if target and msg then SendChatMessage(msg, "WHISPER", nil, target) end
        else
            SendChatMessage(args, channel)
        end
        return true
    end

    if lower == "run" or lower == "script" then
        local ok, err = ExecuteSafeRunLine(args)
        if not ok then return false, err or ("Script non simulable: " .. args) end
        return true
    end

    if lower == "cast" or lower == "lancer" then
        local spellName = CompactNativeMacroArgs(args)
        if spellName ~= "" and type(CastSpellByName) == "function" then
            CastSpellByName(spellName)
            return true
        end
        return false, "Sort introuvable dans la macro: " .. args
    end

    if lower == "castsequence" then
        local spellName = CompactNativeMacroArgs(args)
        spellName = spellName:gsub("^reset=[^%s]+%s*", "")
        spellName = Trim(spellName:match("([^,]+)") or spellName)
        if spellName ~= "" and type(CastSpellByName) == "function" then
            CastSpellByName(spellName)
            return true
        end
        return false, "Castsequence non simulable: " .. args
    end

    if lower == "use" or lower == "utiliser" then
        local itemName = CompactNativeMacroArgs(args)
        local itemSlot = tonumber(itemName)
        if itemSlot and type(UseInventoryItem) == "function" then
            UseInventoryItem(itemSlot)
            return true
        end
        if itemName ~= "" and type(UseItemByName) == "function" then
            UseItemByName(itemName)
            return true
        end
        if itemName ~= "" and C_Item and type(C_Item.UseItemByName) == "function" then
            C_Item.UseItemByName(itemName)
            return true
        end
        return false, "Objet introuvable dans la macro: " .. args
    end

    if lower == "stopcasting" and type(SpellStopCasting) == "function" then
        SpellStopCasting()
        return true
    end

    if lower == "target" or lower == "tar" then
        local unit = CompactNativeMacroArgs(args)
        if unit ~= "" and type(TargetUnit) == "function" then
            TargetUnit(unit)
            return true
        end
        return false, "Cible introuvable dans la macro: " .. args
    end

    local slashHandler = ResolveNativeSlashCommand(lower)
    if slashHandler then
        local ok, err = pcall(slashHandler, args, nil)
        if ok then return true end
        return false, "Commande slash en erreur: /" .. tostring(cmd) .. " (" .. tostring(err) .. ")"
    end

    return false, "Commande non simulable: /" .. tostring(cmd)
end

function OS.ExecuteMacroBody(body, context)
    body = tostring(body or "")
    if body == "" then return false, "Macro vide." end

    local didRun = false
    local firstError
    for line in body:gmatch("[^\n]+") do
        local ok, err = OS.ExecuteMacroLine(line, context)
        if ok then
            didRun = true
        elseif err and not firstError then
            firstError = err
        end
    end
    return didRun, firstError
end

function OS.RunStoredMacroByID(macroID)
    local spell, realName = OS.GetSpellByMacroID(macroID)
    if not spell then
        print("|cff66ccffOmegaSpell|r: Macro inconnue: " .. tostring(macroID))
        return false, "Macro Omega inconnue."
    end

    local body = spell.macroStored
    if not body or body == "" then
        body = OS.BuildMacroText and OS.BuildMacroText(spell) or ""
    end

    if Trim(body) == "/omsp id " .. tostring(macroID) then
        if OS.GetSpell(realName) then
            OS.CastSpell(realName)
        else
            print("|cff66ccffOmegaSpell|r: Macro Omega orpheline sans contenu exécutable: " .. tostring(macroID))
            return false, "Macro Omega orpheline."
        end
        return true
    end

    local ok = OS.ExecuteMacroBody(body, { macroID = macroID, spellName = realName })
    if not ok then
        OS.CastSpell(realName)
    end
    return true
end

function OS.CreateOrUpdateMacro(spellName)
    local spell, realName = OS.GetSpell(spellName)
    if not spell then
        print("|cff66ccffOmegaSpell|r: Sort inconnu: " .. tostring(spellName))
        return false, "Sort inconnu."
    end

    if not OS.SaveAddonMacro then
        print("|cff66ccffOmegaSpell|r: Stockage Omega indisponible.")
        return false, "Stockage Omega indisponible."
    end

    local ok, macroID = OS.SaveAddonMacro(realName)
    if not ok then
        local msg = macroID or "Impossible de créer la macro Omega."
        print("|cff66ccffOmegaSpell|r: " .. msg)
        return false, msg
    end

    spell.macroCreatedName = nil
    local msg = "Macro Omega créée : " .. tostring(macroID)
    print("|cff66ccffOmegaSpell|r: " .. msg)
    return true, msg
end

function OS.PickupMacroByID(macroID)
    if not OS.GetSpellByMacroID(macroID) then return false, "Macro Omega introuvable." end
    if OS.Bar and OS.Bar.PickMacro then
        return OS.Bar.PickMacro(macroID)
    end
    return false, "Barre Omega indisponible."
end

function OS.DeleteMacroByID(macroID)
    local spell, realName = OS.GetSpellByMacroID(macroID)
    if not spell then return false, "Macro Omega introuvable." end

    if OmegaSpellDB and OmegaSpellDB.macroIDs then
        OmegaSpellDB.macroIDs[macroID] = nil
    end
    if OmegaSpellDB and OmegaSpellDB.macros then
        OmegaSpellDB.macros[macroID] = nil
    end
    if OmegaSpellDB and OmegaSpellDB.bars then
        for _, cfg in pairs(OmegaSpellDB.bars) do
            for i, slotID in pairs(cfg.slots or {}) do
                if slotID == macroID then
                    cfg.slots[i] = nil
                end
            end
        end
    end
    local liveSpell = OS.GetSpell(realName)
    if liveSpell then
        liveSpell.macroID = nil
        liveSpell.macroCreatedName = nil
        liveSpell.macroStored = nil
    end
    if OS.Bar and OS.Bar.Refresh then OS.Bar.Refresh() end
    return true, realName
end

-- ── Main ──────────────────────────────────────────────────────────────────────

function OS.Run(msg)
    local a, b, c = SplitArgs(msg)

    if not a or a == "" then
        PrintHelp()
        return
    end

    -- Commande UI
    if a:lower() == "ui" then
        if OmegaSpell.UI and OmegaSpell.UI.Open then
            OmegaSpell.UI.Open()
        end
        return
    end

    if a:lower() == "cast" then
        local spellName = JoinArgs(b, c)
        if spellName == "" then PrintHelp() return end
        OS.CastSpell(spellName)
        return
    end

    if a:lower() == "macro" then
        local spellName = JoinArgs(b, c)
        if spellName == "" then PrintHelp() return end
        OS.CreateOrUpdateMacro(spellName)
        return
    end

    if a:lower() == "bar" or a:lower() == "barre" then
        if OS.Bar and OS.Bar.Toggle then
            OS.Bar.Toggle()
        end
        return
    end

    if a:lower() == "id" then
        local macroID = JoinArgs(b, c)
        if macroID == "" then PrintHelp() return end
        if OS.RunStoredMacroByID then
            OS.RunStoredMacroByID(macroID)
        else
            OS.CastSpellByMacroID(macroID)
        end
        return
    end

    local channel = CanonChannel(a)
    if not channel then
        print("|cff66ccffOmegaSpell|r: Canal inconnu: " .. tostring(a))
        PrintHelp()
        return
    end

    local groupName, whisperTarget
    if channel == "WHISPER" then
        whisperTarget = b
        groupName     = c
    else
        groupName = JoinArgs(b, c)
    end

    if not groupName or groupName == "" then
        PrintHelp()
        return
    end

    local groupTbl = OS.GetGroup(groupName)
    if not groupTbl then
        print("|cff66ccffOmegaSpell|r: Groupe inconnu: " .. tostring(groupName))
        return
    end

    local text = PickRandom(groupTbl)
    if not text then
        print("|cff66ccffOmegaSpell|r: Groupe vide.")
        return
    end

    Send(text, channel, whisperTarget)
end

-- ── Enable / Disable ─────────────────────────────────────────────────────────

function OS:Enable()
    OS.DB_Init()
    SLASH_OMEGASPELL1 = "/omsp"
    SlashCmdList["OMEGASPELL"] = function(msg) OS.Run(msg) end
    OmegaHub:SetModuleLoaded("Omega_Spell", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Omega Spell active.  |cffAAAAAA/omsp cast [sort]  -  /omsp macro [sort]  -  /omsp ui|r")
    end
end

function OS:Disable()
    SLASH_OMEGASPELL1 = nil
    SlashCmdList["OMEGASPELL"] = nil
    if OmegaSpell.UI then OmegaSpell.UI.Close() end
    OmegaHub:SetModuleLoaded("Omega_Spell", false)
    OmegaHub.Print("Omega Spell désactivé.")
end

-- ── Init ──────────────────────────────────────────────────────────────────────

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({
        name    = "Omega_Spell",
        title   = "Omega Spell",
        desc    = "Créateur de sorts RP, macros et groupes d'emotes randomisés.",
        version = "2.0",
        module  = OS,
    })
    if OmegaHub:IsModuleEnabled("Omega_Spell") then
        OS:Enable()
    end
    initFrame:UnregisterAllEvents()
end)
