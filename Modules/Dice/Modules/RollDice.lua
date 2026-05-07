local OmegaDice = _G.OmegaDice

local DEFAULT_ROLLS = 1
local DEFAULT_SIDES = 20

function OmegaDice.RollDice(command)
    local dicePattern = "(%d+)d(%d+)([%+%-%d%s]*)%s*(.*)"
    local numRolls, dieSides, modifiers, description = string.match(command or "", dicePattern)

    numRolls = tonumber(numRolls) or DEFAULT_ROLLS
    dieSides = tonumber(dieSides) or DEFAULT_SIDES
    description = OmegaDice.Trim(description)

    if numRolls < 1 or dieSides < 1 then
        OmegaDice.PrintError("Commande invalide. Le nombre de des et leurs faces doivent etre superieurs a 0.")
        return
    end

    local modifier, modifierText = OmegaDice.SumModifiers(modifiers)
    local rolls   = {}
    local rollSum = 0

    for i = 1, numRolls do
        rolls[i] = math.random(1, dieSides)
        rollSum  = rollSum + rolls[i]
    end

    local total = rollSum + modifier
    local resultMessage

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

    if description ~= "" then
        resultMessage = resultMessage .. " [ " .. description .. " ]"
    end

    local geo = OmegaDice.GeoForSides and OmegaDice.GeoForSides(dieSides)
    if geo and OmegaDice.PlayWireframeAnimation then
        OmegaDice.PlayWireframeAnimation(geo, rolls, total, modifier, description, 1, dieSides, function()
            OmegaDice.SendResult(resultMessage)
        end)
        return
    end

    if OmegaDice.PlayD20Animation then
        local diceLabel = numRolls .. "D" .. dieSides
        OmegaDice.PlayD20Animation(rolls, total, modifier, description, 1, dieSides, diceLabel, function()
            OmegaDice.SendResult(resultMessage)
        end)
        return
    end

    OmegaDice.SendResult(resultMessage)
end
