OS2 = OS2 or {}
OS2.DB = OS2.DB or {}

function OS2.DB.CreateChatShare(deps)
    deps = deps or {}

    local ItemUsesMultiplier = deps.ItemUsesMultiplier
    local ItemUsesDuration = deps.ItemUsesDuration

    local LINK_COLOR = "7ec8e3"
    local SHARE_TOKEN_PREFIX = "{OS2ITEM:"
    local SHARE_CONT_TOKEN_PREFIX = "{OS2ITEM+:"
    local SHARE_TOKEN_SUFFIX = "}"
    local LINK_TYPE = "os2db"
    local SHARE_FIELD_SEPARATOR = "~"
    local SHARE_VALUE_SEPARATOR = string.char(31)
    local SHARE_LIST_SEPARATOR = string.char(30)
    local SHARE_PART_SEPARATOR = string.char(29)
    local SHARE_VERSION = "2"
    local BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    local BASE64_LOOKUP = {}
    local BASE36_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local SHARE_CHUNK_SIZE = 96
    local CHAT_SHARE_EVENTS = {
        "CHAT_MSG_SAY",
        "CHAT_MSG_YELL",
        "CHAT_MSG_EMOTE",
        "CHAT_MSG_GUILD",
        "CHAT_MSG_OFFICER",
        "CHAT_MSG_PARTY",
        "CHAT_MSG_PARTY_LEADER",
        "CHAT_MSG_RAID",
        "CHAT_MSG_RAID_LEADER",
        "CHAT_MSG_INSTANCE_CHAT",
        "CHAT_MSG_INSTANCE_CHAT_LEADER",
        "CHAT_MSG_CHANNEL",
        "CHAT_MSG_WHISPER",
        "CHAT_MSG_WHISPER_INFORM",
    }

    for i = 1, #BASE64_ALPHABET do
        BASE64_LOOKUP[BASE64_ALPHABET:sub(i, i)] = i - 1
    end

    local fragmentedShares = {}
    local assembledShares = {}
    local shareSequence = 0

    local function Trim(text)
        return (tostring(text or ""):match("^%s*(.-)%s*$")) or ""
    end

    local function EncodeBase36(value)
        value = math.max(0, math.floor(tonumber(value) or 0))
        if value == 0 then
            return "0"
        end

        local out = {}
        while value > 0 do
            local digit = (value % 36) + 1
            out[#out + 1] = BASE36_ALPHABET:sub(digit, digit)
            value = math.floor(value / 36)
        end

        local text = table.concat(out)
        return text:reverse()
    end

    local function DecodeBase36(value)
        local text = Trim(value)
        if text == "" then
            return 0
        end
        return tonumber(text, 36) or 0
    end

    local function EncodeShareText(text)
        local source = tostring(text or "")
        local out = {}

        for i = 1, #source, 3 do
            local b1 = string.byte(source, i) or 0
            local b2 = string.byte(source, i + 1)
            local b3 = string.byte(source, i + 2)
            local n = b1 * 65536 + (b2 or 0) * 256 + (b3 or 0)

            local c1 = math.floor(n / 262144) % 64
            local c2 = math.floor(n / 4096) % 64
            local c3 = math.floor(n / 64) % 64
            local c4 = n % 64

            out[#out + 1] = BASE64_ALPHABET:sub(c1 + 1, c1 + 1)
            out[#out + 1] = BASE64_ALPHABET:sub(c2 + 1, c2 + 1)
            if b2 then
                out[#out + 1] = BASE64_ALPHABET:sub(c3 + 1, c3 + 1)
            end
            if b3 then
                out[#out + 1] = BASE64_ALPHABET:sub(c4 + 1, c4 + 1)
            end
        end

        return table.concat(out)
    end

    local function NextShareId()
        shareSequence = shareSequence + 1
        return EncodeBase36(math.floor((GetTime and GetTime() or 0) * 1000)) .. EncodeBase36(shareSequence)
    end

    local function DecodeShareText(text)
        local source = tostring(text or "")
        local out = {}

        for i = 1, #source, 4 do
            local chunk = source:sub(i, i + 3)
            local len = #chunk
            local v1 = BASE64_LOOKUP[chunk:sub(1, 1)]
            local v2 = BASE64_LOOKUP[chunk:sub(2, 2)]
            local v3 = BASE64_LOOKUP[chunk:sub(3, 3)] or 0
            local v4 = BASE64_LOOKUP[chunk:sub(4, 4)] or 0

            if not v1 or not v2 then
                return nil
            end

            local n = v1 * 262144 + v2 * 4096 + v3 * 64 + v4
            out[#out + 1] = string.char(math.floor(n / 65536) % 256)
            if len >= 3 then
                out[#out + 1] = string.char(math.floor(n / 256) % 256)
            end
            if len >= 4 then
                out[#out + 1] = string.char(n % 256)
            end
        end

        return table.concat(out)
    end

    local function DecodeLegacyShareText(text)
        return tostring(text or ""):gsub("(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
    end

    local function SplitPayload(payload, separator)
        local parts = {}
        local text = tostring(payload or "")
        local start = 1
        local sep = separator or SHARE_FIELD_SEPARATOR

        while true do
            local sepStart, sepEnd = text:find(sep, start, true)
            if not sepStart then
                parts[#parts + 1] = text:sub(start)
                break
            end
            parts[#parts + 1] = text:sub(start, sepStart - 1)
            start = sepEnd + 1
        end

        return parts
    end

    local function NormalizeDisablePhraseEffect(effect)
        if effect == "PAUSE_FORCE_OFF" then
            return "PAUSE_FORCE_OFF"
        end
        return "PAUSE"
    end

    local function NormalizePhraseList(value)
        local phrases = {}

        if type(value) == "table" then
            for _, entry in ipairs(value) do
                local phrase = Trim(entry)
                if phrase ~= "" then
                    phrases[#phrases + 1] = phrase
                end
            end
        else
            local text = tostring(value or "")
            for entry in text:gmatch("[^\n]+") do
                local phrase = Trim(entry)
                if phrase ~= "" then
                    phrases[#phrases + 1] = phrase
                end
            end
        end

        return phrases
    end

    local function NormalizeDisablePhraseEntries(value)
        local entries = {}

        if type(value) == "table" then
            for _, entry in ipairs(value) do
                local text
                local effect = "PAUSE"

                if type(entry) == "table" then
                    text = Trim(entry.text or entry.phrase or entry.label or "")
                    effect = NormalizeDisablePhraseEffect(entry.effect)
                else
                    text = Trim(entry)
                end

                if text ~= "" then
                    entries[#entries + 1] = {
                        text = text,
                        effect = effect,
                    }
                end
            end
        else
            for _, phrase in ipairs(NormalizePhraseList(value)) do
                entries[#entries + 1] = {
                    text = phrase,
                    effect = "PAUSE",
                }
            end
        end

        return entries
    end

    local function NormalizeAuraRules(value)
        local rules = {}
        if type(value) ~= "table" then
            return rules
        end

        for _, entry in ipairs(value) do
            if type(entry) == "table" then
                local condition = Trim(entry.condition or "")
                local command = Trim(entry.command or "")
                local phrase = Trim(entry.phrase or "")
                if condition ~= "" and command ~= "" then
                    rules[#rules + 1] = {
                        condition = condition,
                        command = command,
                        phrase = phrase,
                    }
                end
            end
        end

        return rules
    end

    local function ConditionNeedsPhrase(condition)
        return condition == "DISABLE_PHRASE" or condition == "ENABLE_PHRASE"
    end

    local CONDITION_TO_CODE = {
        ACTIVATE = "A",
        DEACTIVATE = "D",
        RESOURCE_EMPTY = "R",
        DISABLE_PHRASE = "X",
        ENABLE_PHRASE = "E",
    }

    local CODE_TO_CONDITION = {
        A = "ACTIVATE",
        D = "DEACTIVATE",
        R = "RESOURCE_EMPTY",
        X = "DISABLE_PHRASE",
        E = "ENABLE_PHRASE",
    }

    local function EncodeCondition(condition)
        return CONDITION_TO_CODE[condition] or "A"
    end

    local function DecodeCondition(code)
        return CODE_TO_CONDITION[code] or "ACTIVATE"
    end

    local function EncodeChannelMask(text)
        local mask = 0
        for token in tostring(text or ""):gmatch("[^,%s]+") do
            local upper = token:upper()
            if upper == "RAID" then
                mask = mask + 1
            elseif upper == "GROUP" then
                mask = mask + 2
            elseif upper == "RAID_WARNING" then
                mask = mask + 4
            end
        end
        return EncodeBase36(mask)
    end

    local function DecodeChannelMask(mask)
        local value = DecodeBase36(mask)
        local out = {}
        if value % 2 >= 1 then
            out[#out + 1] = "RAID"
        end
        if math.floor(value / 2) % 2 >= 1 then
            out[#out + 1] = "GROUP"
        end
        if math.floor(value / 4) % 2 >= 1 then
            out[#out + 1] = "RAID_WARNING"
        end
        return table.concat(out, ",")
    end

    local function BuildFlags(item)
        local flags = 0
        if item.inventoryCheck then
            flags = flags + 1
        end
        if item.consumable then
            flags = flags + 2
        end
        if item.disableEnabled then
            flags = flags + 4
        end
        if item.auraEnabled then
            flags = flags + 8
        end
        return EncodeBase36(flags)
    end

    local function DecodeFlags(value)
        local flags = DecodeBase36(value)
        return {
            inventoryCheck = (flags % 2) >= 1,
            consumable = (math.floor(flags / 2) % 2) >= 1,
            disableEnabled = (math.floor(flags / 4) % 2) >= 1,
            auraEnabled = (math.floor(flags / 8) % 2) >= 1,
        }
    end

    local function BuildPhraseIndexMap(list)
        local map = {}
        for index, phrase in ipairs(list) do
            map[phrase] = index
        end
        return map
    end

    local function EncodeAuraCommand(command)
        local text = Trim(command)
        if text:match("^%d+$") then
            return "N" .. EncodeBase36(text)
        end
        return "T" .. text
    end

    local function DecodeAuraCommand(value)
        local prefix = tostring(value or ""):sub(1, 1)
        local body = tostring(value or ""):sub(2)
        if prefix == "N" then
            return tostring(DecodeBase36(body))
        end
        if prefix == "T" then
            return body
        end
        return tostring(value or "")
    end

    local function EncodePhraseRef(phrase, disableMap, enableMap)
        local text = Trim(phrase)
        if text == "" then
            return ""
        end

        local disableIndex = disableMap[text]
        if disableIndex then
            return "D" .. EncodeBase36(disableIndex)
        end

        local enableIndex = enableMap[text]
        if enableIndex then
            return "E" .. EncodeBase36(enableIndex)
        end

        return "T" .. text
    end

    local function DecodePhraseRef(value, disableEntries, enablePhrases)
        local token = tostring(value or "")
        local prefix = token:sub(1, 1)
        local body = token:sub(2)

        if prefix == "D" then
            local index = DecodeBase36(body)
            local entry = disableEntries[index]
            return entry and entry.text or ""
        elseif prefix == "E" then
            local index = DecodeBase36(body)
            return enablePhrases[index] or ""
        elseif prefix == "T" then
            return body
        end

        return token
    end

    local function SerializePhraseList(value)
        local phrases = NormalizePhraseList(value)
        return table.concat(phrases, SHARE_LIST_SEPARATOR)
    end

    local function ParsePhraseList(value)
        local phrases = {}
        for _, entry in ipairs(SplitPayload(value or "", SHARE_LIST_SEPARATOR)) do
            local phrase = Trim(entry)
            if phrase ~= "" then
                phrases[#phrases + 1] = phrase
            end
        end
        return phrases
    end

    local function SerializeDisablePhraseEntries(value)
        local out = {}

        for _, entry in ipairs(NormalizeDisablePhraseEntries(value)) do
            out[#out + 1] = table.concat({
                entry.text or "",
                NormalizeDisablePhraseEffect(entry.effect),
            }, SHARE_PART_SEPARATOR)
        end

        return table.concat(out, SHARE_LIST_SEPARATOR)
    end

    local function ParseDisablePhraseEntries(value)
        local entries = {}

        for _, entry in ipairs(SplitPayload(value or "", SHARE_LIST_SEPARATOR)) do
            if entry ~= "" then
                local parts = SplitPayload(entry, SHARE_PART_SEPARATOR)
                local text = Trim(parts[1] or "")
                if text ~= "" then
                    entries[#entries + 1] = {
                        text = text,
                        effect = NormalizeDisablePhraseEffect(parts[2]),
                    }
                end
            end
        end

        return entries
    end

    local function SerializeCompactAuraRules(value, disableEntries, enablePhrases)
        local out = {}
        local disableMap = BuildPhraseIndexMap((function()
            local phrases = {}
            for _, entry in ipairs(disableEntries or {}) do
                phrases[#phrases + 1] = entry.text
            end
            return phrases
        end)())
        local enableMap = BuildPhraseIndexMap(enablePhrases or {})

        for _, rule in ipairs(NormalizeAuraRules(value)) do
            out[#out + 1] = table.concat({
                EncodeCondition(rule.condition),
                EncodeAuraCommand(rule.command),
                ConditionNeedsPhrase(rule.condition) and EncodePhraseRef(rule.phrase, disableMap, enableMap) or "",
            }, SHARE_PART_SEPARATOR)
        end

        return table.concat(out, SHARE_LIST_SEPARATOR)
    end

    local function ParseAuraRules(value)
        local rules = {}

        for _, entry in ipairs(SplitPayload(value or "", SHARE_LIST_SEPARATOR)) do
            if entry ~= "" then
                local parts = SplitPayload(entry, SHARE_PART_SEPARATOR)
                local condition = Trim(parts[1] or "")
                local command = Trim(parts[2] or "")
                local phrase = Trim(parts[3] or "")
                if condition ~= "" and command ~= "" then
                    rules[#rules + 1] = {
                        condition = condition,
                        command = command,
                        phrase = phrase,
                    }
                end
            end
        end

        return rules
    end

    local function ParseCompactAuraRules(value, disableEntries, enablePhrases)
        local rules = {}

        for _, entry in ipairs(SplitPayload(value or "", SHARE_LIST_SEPARATOR)) do
            if entry ~= "" then
                local parts = SplitPayload(entry, SHARE_PART_SEPARATOR)
                local condition = DecodeCondition(parts[1] or "")
                local command = Trim(DecodeAuraCommand(parts[2] or ""))
                local phrase = ""
                if ConditionNeedsPhrase(condition) then
                    phrase = Trim(DecodePhraseRef(parts[3] or "", disableEntries or {}, enablePhrases or {}))
                end
                if condition ~= "" and command ~= "" then
                    rules[#rules + 1] = {
                        condition = condition,
                        command = command,
                        phrase = phrase,
                    }
                end
            end
        end

        return rules
    end

    local function BuildSharePayload(item, itemType)
        local typeCode, numericValue
        if itemType == "lanterne" then
            typeCode, numericValue = "L", item.mult or 1
        elseif itemType == "cristal" then
            typeCode, numericValue = "C", item.time or 0
        elseif itemType == "torche" then
            typeCode, numericValue = "T", item.mult or 1
        elseif itemType == "combustible" then
            typeCode, numericValue = "B", item.time or 0
        elseif itemType == "lanternModule" then
            typeCode, numericValue = "M", 0
        else
            typeCode, numericValue = itemType, 0
        end

        local disableEntries = NormalizeDisablePhraseEntries(item.disablePhrases or item.disablePhrase or {})
        local enablePhrases = NormalizePhraseList(item.enablePhrases or item.enablePhrase or {})
        local raw = table.concat({
            SHARE_VERSION,
            item.key or "",
            item.label or "",
            EncodeBase36(numericValue),
            item.desc or "",
            BuildFlags(item),
            EncodeBase36(item.inventoryItemId or item.itemId or 0),
            EncodeChannelMask(item.disableChannels or ""),
            SerializeDisablePhraseEntries(disableEntries),
            SerializePhraseList(enablePhrases),
            SerializeCompactAuraRules(item.auraApplyRules or {}, disableEntries, enablePhrases),
            SerializeCompactAuraRules(item.auraRemoveRules or {}, disableEntries, enablePhrases),
        }, SHARE_VALUE_SEPARATOR)

        return EncodeShareText(typeCode .. SHARE_VALUE_SEPARATOR .. raw)
    end

    local function SplitIntoChunks(text, chunkSize)
        local chunks = {}
        local size = math.max(16, tonumber(chunkSize) or SHARE_CHUNK_SIZE)
        local source = tostring(text or "")

        for i = 1, #source, size do
            chunks[#chunks + 1] = source:sub(i, i + size - 1)
        end

        if #chunks == 0 then
            chunks[1] = ""
        end

        return chunks
    end

    local function RegisterShareChunk(shareId, index, total, chunk)
        shareId = Trim(shareId)
        index = math.max(1, math.floor(tonumber(index) or 1))
        total = math.max(index, math.floor(tonumber(total) or 1))
        if shareId == "" or chunk == nil then
            return nil
        end

        local state = fragmentedShares[shareId]
        if not state then
            state = { total = total, chunks = {} }
            fragmentedShares[shareId] = state
        end

        state.total = math.max(state.total or 1, total)
        state.chunks[index] = chunk

        for i = 1, state.total do
            if not state.chunks[i] then
                return nil
            end
        end

        local payload = table.concat(state.chunks, "")
        assembledShares[shareId] = payload
        fragmentedShares[shareId] = nil
        return payload
    end

    local function ParseMainFragmentToken(content)
        local shareId, totalCode, chunk = tostring(content or ""):match("^S:([^:]+):([^:]+):(.+)$")
        if not shareId then
            return nil
        end
        return shareId, 1, DecodeBase36(totalCode), chunk
    end

    local function ParseContinuationFragmentToken(content)
        local shareId, indexCode, totalCode, chunk = tostring(content or ""):match("^([^:]+):([^:]+):([^:]+):(.+)$")
        if not shareId then
            return nil
        end
        return shareId, DecodeBase36(indexCode), DecodeBase36(totalCode), chunk
    end

    local function ParseSharePayload(payload)
        local decoded = DecodeShareText(payload)
        local parts

        if decoded and decoded:find(SHARE_VALUE_SEPARATOR, 1, true) then
            parts = SplitPayload(decoded, SHARE_VALUE_SEPARATOR)
        else
            parts = SplitPayload(payload, SHARE_FIELD_SEPARATOR)
            for i = 2, #parts do
                parts[i] = DecodeLegacyShareText(parts[i] or "") or ""
            end
        end

        local itemTypeCode = parts[1]
        local itemType
        if itemTypeCode == "L" then
            itemType = "lanterne"
        elseif itemTypeCode == "C" then
            itemType = "cristal"
        elseif itemTypeCode == "T" then
            itemType = "torche"
        elseif itemTypeCode == "B" then
            itemType = "combustible"
        elseif itemTypeCode == "M" then
            itemType = "lanternModule"
        elseif itemTypeCode and itemTypeCode ~= "" then
            itemType = itemTypeCode
        end
        if not itemType then
            return nil
        end

        local item = {
            key = "",
            label = "",
            desc = "",
        }

        if parts[2] == SHARE_VERSION then
            item.key = parts[3] or ""
            item.label = parts[4] or ""
            item.desc = parts[6] or ""

            local numericValue = DecodeBase36(parts[5] or "0")
            if ItemUsesMultiplier and ItemUsesMultiplier(itemType) then
                item.mult = math.max(1, math.floor(numericValue + 0.5))
            elseif ItemUsesDuration and ItemUsesDuration(itemType) then
                item.time = math.max(1, math.floor(numericValue + 0.5))
            end

            local flags = DecodeFlags(parts[7] or "0")
            item.inventoryCheck = flags.inventoryCheck
            item.consumable = flags.consumable
            item.disableEnabled = flags.disableEnabled
            item.auraEnabled = flags.auraEnabled

            local inventoryItemId = DecodeBase36(parts[8] or "0")
            if inventoryItemId > 0 then
                item.inventoryItemId = inventoryItemId
                item.itemId = inventoryItemId
            end

            item.disableChannels = DecodeChannelMask(parts[9] or "0")
            item.disablePhrases = ParseDisablePhraseEntries(parts[10] or "")
            item.enablePhrases = ParsePhraseList(parts[11] or "")
            item.auraApplyRules = ParseCompactAuraRules(parts[12] or "", item.disablePhrases, item.enablePhrases)
            item.auraRemoveRules = ParseCompactAuraRules(parts[13] or "", item.disablePhrases, item.enablePhrases)
        else
            item.key = parts[2] or ""
            item.label = parts[3] or ""
            item.desc = parts[5] or ""

            local numericValue = tonumber(parts[4] or "") or 0
            if ItemUsesMultiplier and ItemUsesMultiplier(itemType) then
                item.mult = math.max(1, math.floor(numericValue + 0.5))
            elseif ItemUsesDuration and ItemUsesDuration(itemType) then
                item.time = math.max(1, math.floor(numericValue + 0.5))
            end

            item.inventoryCheck = (parts[6] == "1")
            local inventoryItemId = tonumber(parts[7] or "")
            if inventoryItemId and inventoryItemId > 0 then
                inventoryItemId = math.max(1, math.floor(inventoryItemId + 0.5))
                item.inventoryItemId = inventoryItemId
                item.itemId = inventoryItemId
            end
            item.consumable = (parts[8] == "1")
            item.disableEnabled = (parts[9] == "1")
            item.disableChannels = parts[10] or ""
            item.disablePhrases = ParseDisablePhraseEntries(parts[11] or "")
            item.enablePhrases = ParsePhraseList(parts[12] or "")
            item.auraEnabled = (parts[13] == "1")
            item.auraApplyRules = ParseAuraRules(parts[14] or "")
            item.auraRemoveRules = ParseAuraRules(parts[15] or "")
        end

        if item.disablePhrases[1] and item.disablePhrases[1].text then
            item.disablePhrase = item.disablePhrases[1].text
        else
            item.disablePhrase = ""
        end
        item.enablePhrase = item.enablePhrases[1] or ""

        if item.key == "" or item.label == "" then
            return nil
        end

        return itemType, item
    end

    local function BuildVisibleHyperlink(payload, labelOverride)
        local itemType, item = ParseSharePayload(payload)
        if not itemType or not item then
            return nil
        end

        return "|cff" .. LINK_COLOR .. "|H" .. LINK_TYPE .. ":" .. payload .. "|h[" .. (labelOverride or item.label) .. "]|h|r"
    end

    local function ReplaceShareTokens(message)
        local text = tostring(message or "")
        if not text:find(SHARE_TOKEN_PREFIX, 1, true) and not text:find(SHARE_CONT_TOKEN_PREFIX, 1, true) then
            return false, message, false
        end

        local didReplace = false
        local tokenPat = SHARE_TOKEN_PREFIX:gsub("(%p)", "%%%1") .. "([^}]+)" .. SHARE_TOKEN_SUFFIX:gsub("(%p)", "%%%1")
        local contPat = SHARE_CONT_TOKEN_PREFIX:gsub("(%p)", "%%%1") .. "([^}]+)" .. SHARE_TOKEN_SUFFIX:gsub("(%p)", "%%%1")
        local fullPat = "%[([^%]]*)%]" .. tokenPat
        local result = text

        result = result:gsub(fullPat, function(label, payload)
            local shareId, index, total, chunk = ParseMainFragmentToken(payload)
            if shareId then
                RegisterShareChunk(shareId, index, total, chunk)
                didReplace = true
                return "|cff" .. LINK_COLOR .. "|H" .. LINK_TYPE .. ":" .. shareId .. "|h[" .. (label or "?") .. "]|h|r"
            end

            local hyperlink = BuildVisibleHyperlink(payload, label)
            if hyperlink then
                didReplace = true
                return hyperlink
            end
            return ""
        end)

        result = result:gsub(contPat, function(payload)
            local shareId, index, total, chunk = ParseContinuationFragmentToken(payload)
            if shareId then
                RegisterShareChunk(shareId, index, total, chunk)
                didReplace = true
            end
            return ""
        end)

        result = result:gsub(tokenPat, function(payload)
            local shareId, index, total, chunk = ParseMainFragmentToken(payload)
            if shareId then
                RegisterShareChunk(shareId, index, total, chunk)
                didReplace = true
                return "|cff" .. LINK_COLOR .. "|H" .. LINK_TYPE .. ":" .. shareId .. "|h[" .. "Objet partagé" .. "]|h|r"
            end

            local hyperlink = BuildVisibleHyperlink(payload)
            if hyperlink then
                didReplace = true
                return hyperlink
            end
            return ""
        end)

        local shouldHide = didReplace and not tostring(result or ""):find("%S")
        return didReplace, result, shouldHide
    end

    local function InsertLinkToChat(item, itemType)
        local payload = BuildSharePayload(item, itemType)
        if not payload then
            return
        end

        local eb = (ChatEdit_ChooseBoxForSend and ChatEdit_ChooseBoxForSend())
            or (DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.editBox)
            or ChatFrame1EditBox
        if not eb then
            return
        end

        if not eb:IsShown() and ChatEdit_ActivateChat then
            ChatEdit_ActivateChat(eb)
        end

        local shareId = NextShareId()
        local chunks = SplitIntoChunks(payload, SHARE_CHUNK_SIZE)
        local totalCode = EncodeBase36(#chunks)
        local tokens = {
            "[" .. (item.label or "?") .. "]" .. SHARE_TOKEN_PREFIX .. "S:" .. shareId .. ":" .. totalCode .. ":" .. chunks[1] .. SHARE_TOKEN_SUFFIX
        }

        for index = 2, #chunks do
            tokens[#tokens + 1] = SHARE_CONT_TOKEN_PREFIX
                .. shareId .. ":" .. EncodeBase36(index) .. ":" .. totalCode .. ":" .. chunks[index]
                .. SHARE_TOKEN_SUFFIX
        end

        local token = table.concat(tokens)
        eb:Insert(token)
        eb:SetFocus()
    end

    local itemRefHookInstalled = false
    local chatEditHookInstalled = false

    local function InstallHooks(showItemInfo)
        local function HandleSharedItemLink(link)
            local payload = tostring(link or ""):match("^" .. LINK_TYPE .. ":(.+)$")
            if not payload then
                return false
            end

            payload = assembledShares[payload] or payload
            local itemType, item = ParseSharePayload(payload)
            if not itemType or not item then
                return false
            end

            showItemInfo(item, itemType)
            return true
        end

        local function HandleHyperlinkClick(_, link)
            if HandleSharedItemLink(link) and ItemRefTooltip and ItemRefTooltip:IsShown() then
                ItemRefTooltip:Hide()
            end
        end

        for i = 1, 10 do
            local frame = _G["ChatFrame" .. i]
            if frame then
                frame:HookScript("OnHyperlinkClick", HandleHyperlinkClick)
            end
        end

        local function InstallItemRefHook(force)
            if itemRefHookInstalled and not force then
                return
            end

            local previousSetItemRef = SetItemRef
            function SetItemRef(link, text, button, chatFrame)
                if HandleSharedItemLink(link) then
                    if ItemRefTooltip and ItemRefTooltip:IsShown() then
                        ItemRefTooltip:Hide()
                    end
                    return
                end

                return previousSetItemRef(link, text, button, chatFrame)
            end

            itemRefHookInstalled = true
        end

        local function ShareTokenFilter(_, _, message, ...)
            if OmegaHub and OmegaHub.IsModuleEnabled and not OmegaHub:IsModuleEnabled("Omega_Survive") then
                return false, message, ...
            end

            local changed, replaced, shouldHide = ReplaceShareTokens(message)
            if shouldHide then
                return true
            end
            if changed then
                return false, replaced, ...
            end

            return false, message, ...
        end

        local function SendFragmentSequence(editBox, messages)
            local chatType = (editBox.GetAttribute and editBox:GetAttribute("chatType")) or editBox.chatType
            local language = (editBox.GetAttribute and editBox:GetAttribute("languageID")) or editBox.languageID
            local target = (editBox.GetAttribute and editBox:GetAttribute("tellTarget")) or editBox.tellTarget

            if not target then
                target = (editBox.GetAttribute and editBox:GetAttribute("channelTarget")) or editBox.channelTarget
            end
            if not target then
                target = (editBox.GetAttribute and editBox:GetAttribute("channelNumber")) or editBox.channelNumber
            end

            if chatType == "CHANNEL" then
                target = tonumber(target) or target
            end

            for _, line in ipairs(messages) do
                if line and line ~= "" then
                    SendChatMessage(line, chatType, language, target)
                end
            end
        end

        local function TrySendFragmentedShare(editBox)
            local text = tostring((editBox.GetText and editBox:GetText()) or "")
            if text == "" then
                return false
            end

            local contPattern = SHARE_CONT_TOKEN_PREFIX:gsub("(%p)", "%%%1") .. "[^}]*" .. SHARE_TOKEN_SUFFIX:gsub("(%p)", "%%%1")
            if not text:find(contPattern) then
                return false
            end

            local firstMessage = text:gsub(contPattern, "")
            local messages = {}

            if firstMessage:find("%S") then
                messages[#messages + 1] = firstMessage
            end

            for token in text:gmatch(contPattern) do
                messages[#messages + 1] = token
            end

            if #messages <= 1 then
                return false
            end

            SendFragmentSequence(editBox, messages)

            if ChatEdit_AddHistory then
                ChatEdit_AddHistory(editBox)
            end
            editBox:SetText("")
            if ChatEdit_DeactivateChat then
                ChatEdit_DeactivateChat(editBox)
            elseif editBox.Hide then
                editBox:Hide()
            end

            return true
        end

        for _, eventName in ipairs(CHAT_SHARE_EVENTS) do
            ChatFrame_AddMessageEventFilter(eventName, ShareTokenFilter)
        end

        InstallItemRefHook()

        local hookFrame = CreateFrame("Frame")
        hookFrame:RegisterEvent("PLAYER_LOGIN")
        hookFrame:SetScript("OnEvent", function()
            InstallItemRefHook(true)
        end)

        if not chatEditHookInstalled then
            for i = 1, 10 do
                local editBox = _G["ChatFrame" .. i .. "EditBox"]
                if editBox and not editBox.OS2ShareHooked then
                    local previousHandler = editBox:GetScript("OnEnterPressed")
                    editBox:SetScript("OnEnterPressed", function(self, ...)
                        if TrySendFragmentedShare(self) then
                            return
                        end

                        if previousHandler then
                            return previousHandler(self, ...)
                        end
                    end)
                    editBox.OS2ShareHooked = true
                end
            end
            chatEditHookInstalled = true
        end
    end

    return {
        BuildSharePayload = BuildSharePayload,
        ParseSharePayload = ParseSharePayload,
        ReplaceShareTokens = ReplaceShareTokens,
        InsertLinkToChat = InsertLinkToChat,
        InstallHooks = InstallHooks,
    }
end
