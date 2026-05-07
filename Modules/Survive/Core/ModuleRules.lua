OS2 = OS2 or {}

local Rules = {}
OS2.ModuleRules = Rules

local CONTROL_CHANNEL_EVENTS = {
    RAID_WARNING = {
        CHAT_MSG_RAID_WARNING = true,
    },
    RAID = {
        CHAT_MSG_RAID = true,
        CHAT_MSG_RAID_LEADER = true,
    },
    GROUP = {
        CHAT_MSG_PARTY = true,
        CHAT_MSG_PARTY_LEADER = true,
        CHAT_MSG_INSTANCE_CHAT = true,
        CHAT_MSG_INSTANCE_CHAT_LEADER = true,
    },
}

local ACCENT_STRIP_PATTERNS = {
    { pattern = "[àáâãäåāăąÀÁÂÃÄÅĀĂĄ]", replace = "a" },
    { pattern = "[çćĉċčÇĆĈĊČ]", replace = "c" },
    { pattern = "[ďđĎĐ]", replace = "d" },
    { pattern = "[èéêëēĕėęěÈÉÊËĒĔĖĘĚ]", replace = "e" },
    { pattern = "[ĝğġģĜĞĠĢ]", replace = "g" },
    { pattern = "[ĥħĤĦ]", replace = "h" },
    { pattern = "[ìíîïĩīĭįıÌÍÎÏĨĪĬĮ]", replace = "i" },
    { pattern = "[ĵĴ]", replace = "j" },
    { pattern = "[ķĶ]", replace = "k" },
    { pattern = "[ĺļľłĹĻĽŁ]", replace = "l" },
    { pattern = "[ñńņňŋÑŃŅŇŊ]", replace = "n" },
    { pattern = "[òóôõöøōŏőÒÓÔÕÖØŌŎŐ]", replace = "o" },
    { pattern = "[ŕŗřŔŖŘ]", replace = "r" },
    { pattern = "[śŝşšŚŜŞŠ]", replace = "s" },
    { pattern = "[ţťŧŢŤŦ]", replace = "t" },
    { pattern = "[ùúûüũūŭůűųÙÚÛÜŨŪŬŮŰŲ]", replace = "u" },
    { pattern = "[ŵŴ]", replace = "w" },
    { pattern = "[ýÿŷÝŸŶ]", replace = "y" },
    { pattern = "[źżžŹŻŽ]", replace = "z" },
    { pattern = "[æÆ]", replace = "ae" },
    { pattern = "[œŒ]", replace = "oe" },
    { pattern = "[ßẞ]", replace = "ss" },
}

local function Trim(text)
    return (text or ""):match("^%s*(.-)%s*$") or ""
end

function Rules.GetInventoryCount(itemId)
    if not itemId then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        local ok, value = pcall(C_Item.GetItemCount, itemId, true, false, true)
        if ok and type(value) == "number" then
            return value
        end
    end

    if GetItemCount then
        local ok, value = pcall(GetItemCount, itemId)
        if ok and type(value) == "number" then
            return value
        end

        ok, value = pcall(GetItemCount, itemId, true)
        if ok and type(value) == "number" then
            return value
        end
    end

    return 0
end

function Rules.HasRequiredInventoryItem(item, contextLabel)
    if not item or not item.inventoryCheck then
        return true
    end

    local itemId = tonumber(item.inventoryItemId or item.itemId or 0)
    if itemId <= 0 then
        OS2.Notify((contextLabel or "Cet objet") .. " demande une vérification d'inventaire, mais aucun ID d'item valide n'est configuré.", 1, 0.2, 0.2)
        return false
    end

    local itemCount = nil
    if GetItemCount then
        local ok, value = pcall(GetItemCount, itemId, false, false)
        if ok and type(value) == "number" then
            itemCount = value
        end
    end

    if (itemCount or Rules.GetInventoryCount(itemId)) <= 0 then
        OS2.Notify((contextLabel or "Cet objet") .. " ne peut pas fonctionner sans l'item requis dans l'inventaire.", 1, 0.2, 0.2)
        return false
    end

    return true
end

function Rules.ValidateRechargeInventoryItem(item, resourceLabel)
    local label = resourceLabel or "objet"
    if not item or not item.inventoryCheck then
        return true, false
    end

    local itemId = tonumber(item.inventoryItemId or item.itemId or 0)
    if itemId <= 0 then
        OS2.Notify("Ce " .. label .. " demande une vérification d'inventaire, mais aucun ID d'item valide n'est configuré.", 1, 0.2, 0.2)
        return false, false
    end

    if Rules.GetInventoryCount(itemId) <= 0 then
        OS2.Notify("L'item requis pour recharger ce " .. label .. " est introuvable dans l'inventaire.", 1, 0.2, 0.2)
        return false, false
    end

    if not item.consumable then
        return true, false
    end

    return true, true, itemId
end

function Rules.ExecuteServerCommand(command, auraMode)
    command = Trim(command)
    if command == "" then
        return false
    end

    if auraMode and command:match("^%d+$") then
        command = (auraMode == "remove") and (".unaura " .. command) or (".aura " .. command)
    end

    if not SendChatMessage then
        return false
    end

    local channels = {}
    if IsInRaid and IsInRaid() then
        channels[#channels + 1] = "RAID"
    end
    if IsInGuild and IsInGuild() then
        channels[#channels + 1] = "GUILD"
    end
    channels[#channels + 1] = "SAY"

    for _, channel in ipairs(channels) do
        local ok = pcall(SendChatMessage, command, channel)
        if ok then
            return true
        end
    end

    return false
end

function Rules.ConsumeInventoryItemAndThen(itemId, onConsumed, options)
    options = options or {}
    if options.isPending and options.isPending() then
        OS2.Notify("Une consommation est déjà en attente.", 1, 0.8, 0.6)
        return false
    end

    local before = Rules.GetInventoryCount(itemId)
    local command = ".additem " .. itemId .. " -1"
    if not SendChatMessage or not pcall(SendChatMessage, command, options.consumeChannel or "SAY") then
        OS2.Notify("Impossible d'exécuter la commande de consommation automatique pour cet item.", 1, 0.2, 0.2)
        return false
    end

    if options.setPending then
        options.setPending(true)
    end

    local applied = false
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:SetScript("OnEvent", function()
        local after = Rules.GetInventoryCount(itemId)
        if after < before then
            applied = true
            if options.setPending then
                options.setPending(false)
            end
            frame:UnregisterAllEvents()
            if onConsumed then
                onConsumed()
            end
        end
    end)

    C_Timer.After(options.timeout or 0.6, function()
        if applied then
            return
        end
        if options.setPending then
            options.setPending(false)
        end
        frame:UnregisterAllEvents()
        OS2.Notify((options.cancelMessage or "L'item n'a pas été consommé. La recharge est annulée."), 1, 0.8, 0.3)
    end)

    return true
end

local function StripAccents(text)
    local normalized = tostring(text or "")
    for _, entry in ipairs(ACCENT_STRIP_PATTERNS) do
        normalized = normalized:gsub(entry.pattern, entry.replace)
    end
    return normalized
end

local function NormalizeControlMessage(text)
    local cleaned = StripAccents(Trim(text))
    cleaned = cleaned:lower()
    cleaned = cleaned:gsub("[%p]+", " ")
    cleaned = cleaned:gsub("%s+", " ")
    return Trim(cleaned)
end

local function NormalizePhraseList(raw)
    local phrases = {}
    if type(raw) == "table" then
        for _, entry in ipairs(raw) do
            local source = entry
            if type(entry) == "table" then
                source = entry.text or entry.phrase or entry.label or ""
            end
            local phrase = NormalizeControlMessage(source)
            if phrase ~= "" then
                phrases[#phrases + 1] = phrase
            end
        end
    else
        for entry in tostring(raw or ""):gmatch("[^\n]+") do
            local phrase = NormalizeControlMessage(entry)
            if phrase ~= "" then
                phrases[#phrases + 1] = phrase
            end
        end
    end
    return phrases
end

local function ParseControlChannels(text)
    local selected = {}
    for token in tostring(text or ""):gmatch("[^,%s]+") do
        selected[token:upper()] = true
    end
    return selected
end

local function IsEventAllowedForItem(event, item)
    local channels = ParseControlChannels(item and item.disableChannels or "")
    for channel, events in pairs(CONTROL_CHANNEL_EVENTS) do
        if channels[channel] and events[event] then
            return true
        end
    end
    return false
end

local function MessageMatchesItemPhrases(item, message, phraseListKey, phraseKey)
    local normalizedMessage = NormalizeControlMessage(message)
    if normalizedMessage == "" then
        return nil
    end

    local raw = item and (item[phraseListKey] or item[phraseKey]) or ""
    if type(raw) == "table" then
        for _, entry in ipairs(raw) do
            local source = entry
            if type(entry) == "table" then
                source = entry.text or entry.phrase or entry.label or ""
            end
            local phrase = NormalizeControlMessage(source)
            if phrase == normalizedMessage then
                if type(entry) == "table" then
                    return entry
                end
                return { text = Trim(source) }
            end
        end
        return nil
    end

    for entry in tostring(raw or ""):gmatch("[^\n]+") do
        local phrase = NormalizeControlMessage(entry)
        if phrase == normalizedMessage then
            return { text = Trim(entry) }
        end
    end

    return nil
end

local function AuraConditionNeedsPhrase(condition)
    return condition == "DISABLE_PHRASE" or condition == "ENABLE_PHRASE"
end

function Rules.ResolveAuraStateAfterRules(wasAuraActive, removed, applied)
    if applied > 0 then
        return true
    end
    if removed > 0 then
        return false
    end
    return wasAuraActive == true
end

function Rules.CreateAuraController(config)
    config = config or {}
    local auraCommandNextAt = 0
    local delay = config.commandDelay or 0.1

    local controller = {}

    local function QueueAuraServerCommand(command, auraMode)
        local function SendQueuedAuraCommand()
            if not Rules.ExecuteServerCommand(command, auraMode) and OS2.Notify then
                OS2.Notify(config.auraErrorMessage or "Impossible d'exécuter la commande d'aura configurée pour cet élément.", 1, 0.2, 0.2)
            end
        end

        if not C_Timer or not C_Timer.After or not GetTime then
            SendQueuedAuraCommand()
            return
        end

        local now = GetTime()
        auraCommandNextAt = math.max(auraCommandNextAt, now)
        local wait = auraCommandNextAt - now
        auraCommandNextAt = auraCommandNextAt + delay

        if wait <= 0 then
            SendQueuedAuraCommand()
        else
            C_Timer.After(wait, SendQueuedAuraCommand)
        end
    end

    local function GetSelectedControlItems()
        return (config.getSelectedControlItems and config.getSelectedControlItems()) or {}
    end

    local function GetSelectedAuraItems()
        return (config.getSelectedAuraItems and config.getSelectedAuraItems()) or {}
    end

    function controller.MatchesConfiguredControlMessage(event, message, phraseListKey, phraseKey)
        return controller.GetMatchedControlPhraseEntry(event, message, phraseListKey, phraseKey) ~= nil
    end

    function controller.GetMatchedControlPhraseEntry(event, message, phraseListKey, phraseKey)
        for _, item in ipairs(GetSelectedControlItems()) do
            if IsEventAllowedForItem(event, item) then
                local entry = MessageMatchesItemPhrases(item, message, phraseListKey, phraseKey)
                if entry then
                    return entry, item
                end
            end
        end
        return nil
    end

    function controller.CollectAuraRuleActions(ruleSetKey, condition, message)
        local normalizedMessage = NormalizeControlMessage(message)
        local auraMode = (ruleSetKey == "auraRemoveRules") and "remove" or "apply"
        local actions = {}

        for _, item in ipairs(GetSelectedAuraItems()) do
            for _, rule in ipairs(item[ruleSetKey] or {}) do
                if rule.condition == condition then
                    local expectedPhrase = NormalizeControlMessage(rule.phrase or "")
                    if not AuraConditionNeedsPhrase(condition) or expectedPhrase == "" or expectedPhrase == normalizedMessage then
                        local command = Trim(rule.command)
                        if command ~= "" then
                            actions[#actions + 1] = {
                                command = command,
                                auraMode = auraMode,
                            }
                        end
                    end
                end
            end
        end

        return actions
    end

    function controller.TriggerAuraRules(ruleSetKey, condition, message)
        local actions = controller.CollectAuraRuleActions(ruleSetKey, condition, message)
        for _, action in ipairs(actions) do
            QueueAuraServerCommand(action.command, action.auraMode)
        end
        return #actions
    end

    function controller.TriggerPhraseAuraRules(event, message, condition)
        local eventAllowed = false
        for _, item in ipairs(GetSelectedAuraItems()) do
            if IsEventAllowedForItem(event, item) then
                eventAllowed = true
                break
            end
        end
        if not eventAllowed then
            return 0, 0
        end

        local removedActions = controller.CollectAuraRuleActions("auraRemoveRules", condition, message)
        local appliedActions = controller.CollectAuraRuleActions("auraApplyRules", condition, message)

        for _, action in ipairs(removedActions) do
            QueueAuraServerCommand(action.command, action.auraMode)
        end
        for _, action in ipairs(appliedActions) do
            QueueAuraServerCommand(action.command, action.auraMode)
        end

        return #removedActions, #appliedActions
    end

    return controller
end
