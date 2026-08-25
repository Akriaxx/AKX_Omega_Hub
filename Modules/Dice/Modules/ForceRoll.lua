local OmegaDice = _G.OmegaDice

-- /rdfdp [joueur] <NdM>=<resultat force>[+mod] [Texte optionnel]
-- Force le resultat naturel du (des) de(s) d'un joueur cible, sans que rien
-- ne le trahisse dans le message final (visuellement identique a un vrai
-- jet). Si la cible a Omega_Dice actif, son client execute le jet et publie
-- le resultat lui-meme ; sinon rien ne se passe (on ne peut pas forcer
-- l'execution de code chez un joueur qui n'a pas l'addon).
-- Le nom du joueur est optionnel : si omis, la cible UI courante (/target
-- ou un clic sur son portrait/nom) est utilisee.
local namedPattern    = "^(%S+)%s+(%d+)d(%d+)=(%d+)([%+%-%d]*)%s*(.*)$"
local targetedPattern = "^(%d+)d(%d+)=(%d+)([%+%-%d]*)%s*(.*)$"

local function MyName() return UnitName("player") or "" end

-- Normalise la casse d'un nom de cible sur celui du groupe/raid s'il en fait
-- partie (le message d'addon WHISPER exige la casse exacte).
local function ResolveTargetName(rawName)
    for i = 1, 4 do
        local n = UnitName("party" .. i)
        if n and n:lower() == rawName:lower() then return n end
    end
    for i = 1, 40 do
        local n = UnitName("raid" .. i)
        if n and n:lower() == rawName:lower() then return n end
    end
    return rawName
end

-- Nom complet ("Nom-Royaume" si la cible est cross-royaume) de la cible UI
-- courante (/target ou clic), pour l'envoi en whisper.
local function CurrentTargetName()
    if not UnitExists("target") or not UnitIsPlayer("target") then return nil end
    local name, realm = UnitName("target")
    if not name then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

function OmegaDice.ForceRoll(command)
    command = command or ""

    local rawTarget, numRolls, dieSides, forcedValue, modifiers, description = command:match(namedPattern)

    if not rawTarget then
        -- Pas de nom fourni : on retente sans, et on utilise la cible UI.
        numRolls, dieSides, forcedValue, modifiers, description = command:match(targetedPattern)
        if numRolls then
            rawTarget = CurrentTargetName()
            if not rawTarget then
                OmegaDice.PrintError("Aucune cible valide. Ciblez un joueur (/target ou un clic) ou precisez son nom : /rdfdp [joueur] <NdM>=<resultat force>[+mod] [Texte optionnel]")
                return
            end
        end
    end

    if not rawTarget or not numRolls then
        OmegaDice.PrintError("Commande invalide. Utilisez : /rdfdp [joueur] <NdM>=<resultat force>[+mod] [Texte optionnel]")
        return
    end

    numRolls    = tonumber(numRolls)
    dieSides    = tonumber(dieSides)
    forcedValue = tonumber(forcedValue)
    description = OmegaDice.Trim(description)

    if numRolls < 1 or dieSides < 1 then
        OmegaDice.PrintError("Le nombre de des et leurs faces doivent etre superieurs a 0.")
        return
    end

    if forcedValue < 1 or forcedValue > dieSides then
        OmegaDice.PrintError(string.format("Le resultat force doit etre compris entre 1 et %d.", dieSides))
        return
    end

    local target = ResolveTargetName(rawTarget)

    if target == MyName() then
        OmegaDice.ExecuteForcedRoll(numRolls, dieSides, forcedValue, modifiers, description)
        return
    end

    local sent = OmegaDice.SendForcedRoll and OmegaDice.SendForcedRoll(target, numRolls, dieSides, forcedValue, modifiers, description)
    if sent then
        print(OmegaDice.printPrefix, string.format(
            "Jet truque envoye a %s : %dd%d=%d%s.",
            target, numRolls, dieSides, forcedValue, (modifiers ~= "" and modifiers or "")
        ))
    else
        OmegaDice.PrintError("Impossible d'envoyer le jet truque (cible hors ligne, introuvable, ou sans Omega_Dice actif).")
    end
end
