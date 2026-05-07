local OmegaDice = _G.OmegaDice

local DEFAULT_MIN = 0
local DEFAULT_MAX = 15

function OmegaDice.RandomNumber(command)
    local rangePattern = "(%d+)%-(%d+)%s*([%+%-%d%s]*)%s*(.*)"
    local minVal, maxVal, modifiers, description = string.match(command or "", rangePattern)

    if not minVal or not maxVal then
        minVal = DEFAULT_MIN
        maxVal = DEFAULT_MAX
    else
        minVal = tonumber(minVal) or DEFAULT_MIN
        maxVal = tonumber(maxVal) or DEFAULT_MAX
    end

    if minVal > maxVal then
        minVal, maxVal = maxVal, minVal
    end

    description = OmegaDice.Trim(description)

    local modifier, modifierText = OmegaDice.SumModifiers(modifiers)
    local roll = math.random(minVal, maxVal)
    local total = roll + modifier
    local resultMessage

    if modifier ~= 0 then
        resultMessage = string.format(
            "[ Jet : %d-%d = %d | Mod. : %+d ] ( Total : %d )",
            minVal,
            maxVal,
            roll,
            modifier,
            total
        )
    else
        resultMessage = string.format("[ Jet : %d-%d = %d ] ( Total : %d )", minVal, maxVal, roll, total)
    end

    if description ~= "" then
        resultMessage = resultMessage .. " [ " .. description .. " ]"
    end

    if OmegaDice.PlayD20Animation then
        local diceLabel = minVal .. "-" .. maxVal
        OmegaDice.PlayD20Animation({ roll }, total, modifier, description, minVal, maxVal, diceLabel, function()
            OmegaDice.SendResult(resultMessage)
        end)
        return
    end

    OmegaDice.SendResult(resultMessage)
end
