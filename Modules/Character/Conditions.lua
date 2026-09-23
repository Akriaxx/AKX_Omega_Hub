-- ============================================================
--  Character - Conditions liées aux ressources
--  Au passage d'un seuil (jamais au chargement) :
--    PV à 1        : « Vous êtes en danger. » (vert, couleur de la Vie)
--    PV à 0        : « Vous êtes K.O. »
--    Mana à 0      : « Vous vous sentez faible. » (bleu)
--    Endurance à 0 : « Vous vous sentez faible. » (rouge, couleur de l'Endurance)
--  PV à 1, Mana à 0 et Endurance à 0 sont trois états d'un même statut
--  « affaibli » : chacun a son aura d'animation, et tous partagent une
--  aura d'explication. Une aura est posée dès qu'un état actif en a besoin
--  et retirée quand plus aucun n'en a besoin (PV > 1, Mana/Endurance > 0).
--  Le K.O. (PV à 0) a sa propre aura, retirée dès que les PV remontent.
--  Chaque changement de ses propres ressources (boutons, saisie, MJ)
--  passe par C.OnMyDataChanged : on compare avec les valeurs d'avant.
-- ============================================================
local C = Character

-- Auras du statut affaibli (numéros de sort). nil = pas encore choisie,
-- rien n'est envoyé pour elle.
local WEAKENED_AURAS = {
    animation = { danger = 244807, mana = 282999, endurance = 250429, ko = 308480 },
    explanation = nil,  -- commune aux trois états, en cours de création
}
C.WEAKENED_AURAS = WEAKENED_AURAS
local STATES = { "danger", "mana", "endurance", "ko" }

-- Couleurs des ressources : Vie en vert, Mana en bleu, Endurance en rouge.
local RED, BLUE, GREEN = "ffff3b3b", "ff4aa8ff", "ff5ee06a"
local function Colored(hex, text) return "|c" .. hex .. text .. "|r" end

-- Même annonce que « Début du tour » (C:ShowNotice, UI_Initiative.lua),
-- en file d'attente (Mana et Endurance peuvent tomber à 0 ensemble), mais
-- persistante : c'est le joueur qui la ferme, contrairement aux phases.
local function Notice(text, sub)
    if C.ShowNotice then C:ShowNotice(text, sub, true) end
end

-- ── Statut affaibli ──────────────────────────────────────────────────────
-- Auras requises par les états actifs, dans un ordre stable.
local function RequiredAuras(states)
    local list, seen = {}, {}
    local function add(spellId)
        if spellId and not seen[spellId] then seen[spellId] = true; list[#list + 1] = spellId end
    end
    for _, key in ipairs(STATES) do
        if states[key] then add(WEAKENED_AURAS.animation[key]) end
    end
    if states.danger or states.mana or states.endurance then add(WEAKENED_AURAS.explanation) end
    return list, seen
end

-- États actifs : danger (PV ≤ 1), mana (0), endurance (0), ko (PV à 0).
local active = {}
-- silent : suivre l'état sans rien envoyer (connexion, Character désactivé).
local function SetState(key, on, silent)
    on = on and true or nil
    if active[key] == on then return end
    local before, hadBefore = RequiredAuras(active)
    active[key] = on
    local after, hasAfter = RequiredAuras(active)
    if silent then return end
    for _, spellId in ipairs(before) do
        if not hasAfter[spellId] then SendChatMessage(".unaura " .. spellId .. " self", "GUILD") end
    end
    for _, spellId in ipairs(after) do
        if not hadBefore[spellId] then SendChatMessage(".aura " .. spellId .. " self", "GUILD") end
    end
end

local last
local function Snapshot()
    local ch = C:GetMyChar()
    return { hp = ch.hp.cur, mana = ch.mana.cur, endurance = ch.endurance.cur }
end

local function Check()
    local now = Snapshot()
    local before = last
    last = now
    if not before then return end
    local silent = not C.enabled
    if now.hp == 1 and before.hp ~= 1 then
        -- Soigné de 0 à 1 : de nouveau en danger, sans rejouer le message.
        SetState("ko", false, silent)
        SetState("danger", true, silent)
        if not silent and before.hp > 1 then Notice("Vous êtes en " .. Colored(GREEN, "danger") .. ".", "Vos PV sont bas.") end
    elseif now.hp == 0 and before.hp > 0 then
        SetState("ko", true, silent)
        if not silent then Notice("Vous êtes K.O.", "Attendez qu'un allié vous porte secours.") end
    elseif now.hp > 1 then
        SetState("ko", false, silent)
        SetState("danger", false, silent)
    end
    if now.mana == 0 and before.mana > 0 then
        SetState("mana", true, silent)
        if not silent then Notice("Vous vous sentez " .. Colored(BLUE, "faible") .. ".", "Votre maîtrise vacille, la source est tarie.") end
    elseif now.mana > 0 then
        SetState("mana", false, silent)
    end
    if now.endurance == 0 and before.endurance > 0 then
        SetState("endurance", true, silent)
        if not silent then Notice("Vous vous sentez " .. Colored(RED, "faible") .. ".", "Le souffle vous manque, vos forces vous abandonnent.") end
    elseif now.endurance > 0 then
        SetState("endurance", false, silent)
    end
end
C.CheckResourceConditions = Check

local previous = C.OnMyDataChanged
C.OnMyDataChanged = function(...)
    if previous then previous(...) end
    Check()
end

-- Valeurs de départ prises à la connexion : être déjà à 0 ne déclenche rien.
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    last = Snapshot()
    -- États déjà en cours (auras probablement toujours posées côté serveur) :
    -- suivis sans rien renvoyer, pour les retirer quand on en sortira.
    SetState("danger", last.hp <= 1, true)
    SetState("ko", last.hp == 0, true)
    SetState("mana", last.mana == 0, true)
    SetState("endurance", last.endurance == 0, true)
end)
