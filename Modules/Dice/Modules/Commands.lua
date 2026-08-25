local OmegaDice = _G.OmegaDice

function OmegaDice.RegisterCommands()
    SLASH_DICEROLLER1 = "/rd"
    SlashCmdList.DICEROLLER = function(message)
        local command = OmegaDice.Trim(message)
        if command:match("%d+x?d%d+") then
            OmegaDice.RollDice(command)
            return
        end
        OmegaDice.PrintError("Commande invalide. Utilisez : /rd <NdM[+|-X...]> ou /rd <NxdM[+X][!+X ou !D+X...]> (jets separes, !D cible le de D) [Texte optionnel]")
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

    SLASH_DICEROLLERFORCE1 = "/rdfdp"
    SlashCmdList.DICEROLLERFORCE = function(message)
        local command = OmegaDice.Trim(message)
        OmegaDice.ForceRoll(command)
    end
end

function OmegaDice.UnregisterCommands()
    SLASH_DICEROLLER1 = nil
    SlashCmdList.DICEROLLER = nil
    SLASH_RANDOMNUMBER1 = nil
    SlashCmdList.RANDOMNUMBER = nil
    SLASH_DICEROLLERFORCE1 = nil
    SlashCmdList.DICEROLLERFORCE = nil
end
