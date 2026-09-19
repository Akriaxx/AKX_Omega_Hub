local J = Quest
BINDING_HEADER_OMEGA_HUB = "Omega Hub"
BINDING_NAME_OMEGA_JOURNAL_TOGGLE = "Ouvrir / fermer le journal de quête"

function J:ToggleJournal()
    if not self.enabled or not self.book then return end
    self.book:SetShown(not self.book:IsShown())
end

-- Installer le raccourci une seule fois par profil, puis respecter les
-- changements effectués par le joueur dans les raccourcis du jeu.
local bindingEvents = CreateFrame("Frame")
function J:InstallBinding()
    if not self.enabled then return end
    if InCombatLockdown() then
        bindingEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local set = GetCurrentBindingSet()
    -- Login may expose 0 before the account/character bindings are loaded.
    -- Wait for a valid profile rather than writing into the wrong one.
    if set ~= 1 and set ~= 2 then
        bindingEvents:RegisterEvent("UPDATE_BINDINGS")
        bindingEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
        return
    end
    bindingEvents:UnregisterAllEvents()
    OmegaHubDB.Quest_Bindings = OmegaHubDB.Quest_Bindings or {}
    local installed = OmegaHubDB.Quest_Bindings
    local profile = set == 1 and "account" or self:Me()
    if installed[profile] then return end
    if GetBindingKey("OMEGA_JOURNAL_TOGGLE") then
        installed[profile] = true
    elseif SetBinding("SHIFT-I", "OMEGA_JOURNAL_TOGGLE") then
        SaveBindings(set)
        installed[profile] = true
    end
end
bindingEvents:SetScript("OnEvent", function() J:InstallBinding() end)

function J.Print(message) OmegaHub.Print("Journal de quête : " .. (message or "")) end

function J:MigrateDB()
    self:MigrateDB_MJ()
    self:MigrateDB_Joueur()
end

function J:OnLoad()
    self:MigrateDB()
    self:CreateBook()
    self:PrepareBookMotion()
    self:CreateEnvelope()
    self:CreateLetterSheet()
end

function J:OnEnable() self:WarmAnimationTextures(); self:StartComm(); self:RestoreLetters() end

function J:Enable()
    if self.enabled then return end
    local ok, err = pcall(self.OnLoad, self)
    if not ok then self.Print(err); return end
    self.enabled = true
    self:OnEnable()
    self:InstallBinding()
    SLASH_QUEST1, SLASH_QUEST2 = "/jq", "/quest"
    SlashCmdList.QUEST = function(message)
        local backend = message:lower():match("^%s*lettre%s+(%a+)%s*$")
        if backend=="blp" then
            self.Print("La commande /jq lettre blp a été retirée.")
            return
        elseif backend then self:PreviewEnvelope(backend)
        elseif message:lower():match("^%s*mj%s*$") then self:OpenMJPanel()
        else self:ToggleJournal() end
    end
    OmegaHub:SetModuleLoaded(self.name, true)
    if not OmegaHub._startingUp then self.Print("Activé — Maj + I pour le journal, /jq mj pour l'écritoire.") end
end

function J:Disable()
    self.enabled = false
    bindingEvents:UnregisterAllEvents()
    self:StopComm()
    if self.book then self.book:Hide() end
    self:StopBookMotion()
    if self.animationWarmup then self.animationWarmup:SetScript("OnUpdate",nil);self.animationWarmup:Hide() end
    if self.panel then self.panel:Hide() end
    if self.letter then self.letter:Hide() end
    if self.sheet then self.sheet:Hide() end
    if self.letterEditor then self.letterEditor:Hide() end
    self.notices = {}
    SLASH_QUEST1, SLASH_QUEST2, SlashCmdList.QUEST = nil, nil, nil
    OmegaHub:SetModuleLoaded(self.name, false)
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", function()
    -- Le registre réel reçoit une table et appelle Enable/Disable via le panneau.
    OmegaHub:RegisterModule({ name = J.name, title = "Journal de quête", module = J, version = QUEST_VERSION })
    OmegaHubDB.modules = OmegaHubDB.modules or {}
    if not OmegaHubDB.modules[J.name] and OmegaHubDB.modules.QuestGenerator then
        OmegaHubDB.modules[J.name] = OmegaHubDB.modules.QuestGenerator
    end
    OmegaHubDB.modules.QuestGenerator = nil
    if OmegaHub:IsModuleEnabled(J.name) then J:Enable() end
    init:UnregisterAllEvents()
end)
