local OmegaDice = _G.OmegaDice

function OmegaDice.RegisterCommands()
    SLASH_DICEROLLER1 = "/rd"
    SlashCmdList.DICEROLLER = function(message)
        local command = OmegaDice.Trim(message)
        if command:match("%d+d%d+") then
            OmegaDice.RollDice(command)
            return
        end
        OmegaDice.PrintError("Commande invalide. Utilisez : /rd <NdM[+|-X...]> [Texte optionnel]")
    end

    SLASH_RANDOMNUMBER1 = "/rnd"
    SlashCmdList.RANDOMNUMBER = function(message)
        local command = OmegaDice.Trim(message)
        if command:match("^%d+%-%d+") then
            OmegaDice.RandomNumber(command)
        elseif command:match("^[%+%-]%d") then
            OmegaDice.RandomNumber("0-15 " .. command)
        else
            OmegaDice.RandomNumber("0-15")
        end
    end
end

function OmegaDice.UnregisterCommands()
    SLASH_DICEROLLER1 = nil
    SlashCmdList.DICEROLLER = nil
    SLASH_RANDOMNUMBER1 = nil
    SlashCmdList.RANDOMNUMBER = nil
end
