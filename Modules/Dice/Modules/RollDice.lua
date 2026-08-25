local OmegaDice = _G.OmegaDice

local DEFAULT_ROLLS = 1
local DEFAULT_SIDES = 20

-- Splits a modifiers string like "+2!+4" or "+2!3+4" into modifiers applied
-- to specific dice. Each segment after a "!" may start with a die number
-- (1-based) immediately followed by a signed modifier to target that die
-- explicitly, e.g. "!3+4" -> die 3 gets +4, regardless of where it appears
-- in the string. A segment without a leading "number+sign" applies
-- positionally, in declaration order, to the next die that hasn't already
-- received a modifier (explicit segments are resolved first, so they always
-- win their die regardless of order). Returns nil + an error message on an
-- out-of-range die, a die targeted twice, or too many positional segments.
local function ParsePerDieModifiers(modifiersText, numRolls)
    local segments = {}
    for segment in (modifiersText .. "!"):gmatch("(.-)!") do
        table.insert(segments, segment)
    end

    local parsed = {}
    for _, segment in ipairs(segments) do
        local indexText, rest = segment:match("^(%d+)([%+%-].*)$")
        table.insert(parsed, { index = indexText and tonumber(indexText) or nil, text = indexText and rest or segment })
    end

    local perDie = {}

    -- 1st pass: explicit die targets ("!2+4") reserve their die first, no
    -- matter where they show up in the string.
    for _, seg in ipairs(parsed) do
        if seg.index then
            if seg.index < 1 or seg.index > numRolls then
                return nil, string.format("De %d invalide (jet de %d de(s)).", seg.index, numRolls)
            end
            if perDie[seg.index] ~= nil then
                return nil, string.format("Modificateur deja defini pour le de %d.", seg.index)
            end
            perDie[seg.index] = OmegaDice.SumModifiers(seg.text)
        end
    end

    -- 2nd pass: untargeted, non-empty segments fill in, in order, whichever
    -- dice are still free. An empty segment (e.g. the always-present gap
    -- before a leading "!", as in "!2+4") carries no modifier and consumes
    -- no die — otherwise a fully-explicit string like "!1+2!2+4!3-1" would
    -- wrongly fail once that phantom empty segment ran out of free dice.
    local nextFree = 1
    for _, seg in ipairs(parsed) do
        if not seg.index and seg.text ~= "" then
            while perDie[nextFree] ~= nil do
                nextFree = nextFree + 1
            end
            if nextFree > numRolls then
                return nil, string.format("Trop de modificateurs pour %d de(s).", numRolls)
            end
            perDie[nextFree] = OmegaDice.SumModifiers(seg.text)
            nextFree = nextFree + 1
        end
    end

    for i = 1, numRolls do
        perDie[i] = perDie[i] or 0
    end
    return perDie
end

function OmegaDice.RollDice(command)
    local dicePattern = "(%d+)(x?)d(%d+)([%+%-%d%s!]*)%s*(.*)"
    local numRolls, separateFlag, dieSides, modifiers, description = string.match(command or "", dicePattern)

    local separate = (separateFlag == "x")

    numRolls = tonumber(numRolls) or DEFAULT_ROLLS
    dieSides = tonumber(dieSides) or DEFAULT_SIDES
    description = OmegaDice.Trim(description)

    if numRolls < 1 or dieSides < 1 then
        OmegaDice.PrintError("Commande invalide. Le nombre de des et leurs faces doivent etre superieurs a 0.")
        return
    end

    if not separate and modifiers:find("!", 1, true) then
        OmegaDice.PrintError("Le caractere '!' n'est utilisable qu'avec le mode separe : /rd NxdM[+X][!+X...]")
        return
    end

    local perDieMods
    if separate then
        local perDie, err = ParsePerDieModifiers(modifiers, numRolls)
        if not perDie then
            OmegaDice.PrintError(err)
            return
        end
        perDieMods = perDie
    end

    local rolls   = {}
    local rollSum = 0
    for i = 1, numRolls do
        rolls[i] = math.random(1, dieSides)
        rollSum  = rollSum + rolls[i]
    end

    local diceLabel = numRolls .. (separate and "x" or "") .. "D" .. dieSides
    local modifier  = 0
    local resultMessage

    if separate then
        local valueParts = {}
        for i = 1, numRolls do
            local raw = rolls[i]
            local mod = perDieMods[i]
            if mod ~= 0 then
                valueParts[i] = string.format("%d%+d=%d", raw, mod, raw + mod)
            else
                valueParts[i] = tostring(raw)
            end
        end
        resultMessage = string.format("[ Jets separes : %s -> %s ]", diceLabel, table.concat(valueParts, " | "))
    else
        modifier = OmegaDice.SumModifiers(modifiers)
        local total = rollSum + modifier
        if modifier ~= 0 then
            resultMessage = string.format(
                "[ Jet : %dd%d = %d | Mod. : %+d ] ( Total : %d )",
                numRolls,
                dieSides,
                rollSum,
                modifier,
                total
            )
        else
            resultMessage = string.format("[ Jet : %dd%d = %d ] ( Total : %d )", numRolls, dieSides, rollSum, total)
        end
    end

    if description ~= "" then
        resultMessage = resultMessage .. " [ " .. description .. " ]"
    end

    local total = rollSum + modifier

    local geo = OmegaDice.GeoForSides and OmegaDice.GeoForSides(dieSides)
    if geo and OmegaDice.PlayWireframeAnimation then
        OmegaDice.PlayWireframeAnimation(geo, rolls, total, modifier, separate, perDieMods, description, 1, dieSides, function()
            OmegaDice.SendResult(resultMessage)
        end)
        return
    end

    if OmegaDice.PlayD20Animation then
        OmegaDice.PlayD20Animation(rolls, total, modifier, separate, perDieMods, description, 1, dieSides, diceLabel, function()
            OmegaDice.SendResult(resultMessage)
        end)
        return
    end

    OmegaDice.SendResult(resultMessage)
end
