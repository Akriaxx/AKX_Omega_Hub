-- Tests hors jeu : fengari Modules/Quest/Tests/Quest_test.lua
local base = "Modules/Quest/"
local passed = 0
local function test(name, run)
    local ok, err = pcall(run)
    if not ok then error("ECHEC " .. name .. ": " .. tostring(err)) end
    passed = passed + 1
    print("OK " .. name)
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local now, character = 0, "Nytherah"
local players = { player = "Nytherah", target = "Lecteur", party1 = "Lecteur", party2 = "Autre", raid1 = "Nytherah", raid2 = "Lecteur", raid3 = "Autre" }
local raid, grouped, sounds, sent, sendResult = false, false, {}, {}, true
function GetTime() return now end
local bindings, combat, savedBindings = {}, false, 0
function InCombatLockdown() return combat end
function GetCurrentBindingSet() return 1 end
function GetBindingKey(action)
    for key, value in pairs(bindings) do if value == action then return key end end
end
function SetBinding(key, action) bindings[key] = action; return true end
function SaveBindings() savedBindings = savedBindings + 1 end
function time() return 1800000000 end
function GetNormalizedRealmName() return "Epsilon" end
function GetRealmName() return "Epsilon" end
function UnitGUID() return "Player-1-ABC" end
function UnitFullName(unit) return unit == "player" and character or players[unit], "Epsilon" end
function UnitIsPlayer(unit) return players[unit] ~= nil end
function IsInRaid() return raid end
function IsInGroup() return grouped or raid end
function GetNumGroupMembers() return 3 end
function GetNumSubgroupMembers() return 2 end
function PlaySoundFile() local id = #sounds + 1; sounds[id] = true; return true, id end
function StopSound(id) sounds[id] = false end
unpack = table.unpack or unpack
STANDARD_TEXT_FONT, ChatFontNormal = "font.ttf", "ChatFontNormal"
SlashCmdList, UISpecialFrames, StaticPopupDialogs = {}, {}, {}
function StaticPopup_Show(_, _, _, data) _G.popupData = data end
local frames = {}
local Frame = {}
Frame.__index = Frame
function Frame:SetScript(event, fn) self.scripts[event] = fn end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:RegisterEvent(event) self.events[event] = true end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:SetSize(w, h) self.w, self.h = w, h end
function Frame:SetWidth(w) self.w = w end
function Frame:SetHeight(h) self.h = h end
function Frame:GetWidth() return self.w or 100 end
function Frame:GetHeight() return self.h or 100 end
function Frame:SetText(text) self.text = text; if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end end
function Frame:GetText() return self.text or "" end
function Frame:SetFontString(label) self.fontString = label end
function Frame:GetFontString() return self.fontString end
function Frame:GetNumLetters() return #self:GetText() end
function Frame:GetStringHeight() return math.max(20, math.ceil(#self:GetText() / ((self.w or 400) / 8)) * 20) end
function Frame:GetStringWidth() return math.min(self.w or 400, #self:GetText() * 7) end
function Frame:GetName() return self.name end
function Frame:SetChecked(value) self.checked = value end
function Frame:GetChecked() return self.checked or false end
function Frame:SetEnabled(value) self.enabled = value end
function Frame:SetPoint(...) self.point = {...} end
function Frame:SetScrollChild(child) self.child = child end
function Frame:SetVerticalScroll(value) self.offset = value end
function Frame:GetVerticalScroll() return self.offset or 0 end
function Frame:GetVerticalScrollRange() return math.max(0, (self.child and self.child:GetHeight() or 0) - self:GetHeight()) end
function Frame:Show() local old = self.shown; self.shown = true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() local old = self.shown; self.shown = false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown ~= false end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:Play() self.playing = true end
function Frame:Stop() self.playing = false end
function Frame:IsPlaying() return self.playing end
local noop = { "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "SetFont", "SetFontObject", "SetTextColor", "SetJustifyH", "SetJustifyV", "SetSpacing", "SetFrameStrata", "SetScale", "RegisterForDrag", "StartMoving", "StopMovingOrSizing", "SetHighlightTexture", "SetTexture", "SetVertexColor", "SetColorTexture", "SetAllPoints", "SetDegrees", "SetOrigin", "SetDuration", "SetOrder", "SetFromAlpha", "SetToAlpha", "SetAutoFocus", "SetMaxLetters", "ClearFocus", "SetFocus", "SetMultiLine", "UpdateScrollChildRect", "Raise", "EnableMouse", "EnableMouseWheel" }
for _, method in ipairs(noop) do Frame[method] = function() end end
for _, method in ipairs({ "SetOrientation", "SetMinMaxValues", "SetValueStep", "SetValue", "SetThumbTexture", "SetTextInsets", "SetCheckedTexture", "SetNormalTexture", "SetAlpha", "SetTexCoord", "SetThickness", "SetStartPoint", "SetEndPoint" }) do
    Frame[method] = function() end
end
function CreateFrame(kind, name, parent, template)
    local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, scripts = {}, events = {}, shown = not (template and template:match("^Quest")) }, Frame)
    if template == "QuestBookTemplate" then f:SetSize(940, 650) end
    if template == "QuestMJTemplate" then f:SetSize(1080, 780) end
    frames[#frames + 1] = f
    return f
end
function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:CreateLine() return CreateFrame("Line", nil, self) end
function Frame:SetDesaturated(value) self.desaturated=value end
function Frame:GetScale() return 1 end
function Frame:SetTexture(value) self.texture=value; self.textureLoads=(self.textureLoads or 0)+1; return true end
function Frame:IsObjectLoaded() return self.loaded~=false end
function Frame:SetTexCoord(...) self.texCoord={...} end
function Frame:SetAlpha(value) self.alpha=value end
function Frame:SetIgnoreParentAlpha(value) self.ignoreParentAlpha=value end
function Frame:ClearAllPoints() self.point=nil end
function Frame:SetFrameLevel(value) self.level=value end
function Frame:GetFrameLevel() return self.level or (self.parent and self.parent:GetFrameLevel()+1) or 0 end
function Frame:CreateAnimationGroup() return CreateFrame("AnimationGroup", nil, self) end
function Frame:CreateAnimation() return CreateFrame("Animation", nil, self) end
UIParent = CreateFrame("Frame"); UIParent:SetSize(1920, 1080)
OmegaHub = { modules = {}, Print = function() end, _startingUp = true }
function OmegaHub:RegisterModule(data) self.modules[data.name] = data end
function OmegaHub:IsModuleEnabled(name) return OmegaHubDB.modules[name] and OmegaHubDB.modules[name].enabled end
function OmegaHub:SetModuleLoaded(name, value) self.loaded = value end
C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end,
    SendAddonMessage = function(prefix, text, channel, target)
        sent[#sent + 1] = { prefix = prefix, text = text, channel = channel, target = target }
        return sendResult
    end }
-- Charger les vrais composants du Hub utilisés par le thème du module.
dofile("UI/UI.lua")
local files = { "Version.lua", "Quest_Permissions.lua", "Quest_Data_MJ.lua", "Quest_Data_Joueur.lua", "Styles/parchemin.lua", "Quest_UI_Write.lua", "Quest_UI_Envelope.lua", "Quest_UI_Letter.lua", "Quest_UI_Book.lua", "Quest_UI_BookMotion.lua", "Quest_Panel_MJ.lua", "Quest_Comm.lua", "Quest.lua" }
for _, file in ipairs(files) do dofile(base .. file) end
local J = Quest
local function pumpWarm()
    local warm=J.animationWarmup
    for _=1,300 do
        if not warm or not warm.scripts.OnUpdate then return end
        warm.scripts.OnUpdate(warm,1/60)
    end
end
local function advanceFrame(frame,seconds)
    for _=1,math.ceil(seconds*60) do
        local warm=J.animationWarmup
        if warm and warm.scripts.OnUpdate then warm.scripts.OnUpdate(warm,1/60) end
        if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame,1/60) end
    end
end
local function reset(name)
    if J.letter then J.letter:Hide() end
    if J.sheet then J.sheet:Hide() end
    J.notices={}
    character, now, sent, sounds, raid, grouped, sendResult = name or "Nytherah", 0, {}, {}, false, false, true
    OmegaHubDB = { modules = {} }
    J.enabled = true
    J:MigrateDB(); J:StartComm()
    J.wireQueue = {}; J.lastPermissionRequest = nil
    J:WarmAnimationTextures();pumpWarm()
end
local function draft()
    return { titre = "Le serment", donneur = "|cffccaa66Gardien|r |TInterface\\Icons\\INV_Misc_Book_09:16|t",
        statut = "en_cours", etapes = { { texte = "SECRET_ALPHA", revelee = false }, { texte = "Étape révélée : cœur et mémoire", revelee = true }, { texte = "SECRET_OMEGA", revelee = false } } }
end
local function tick(n) for _ = 1, n do now = now + 1.1; J:Pump() end end

test("Migrations idempotentes et journal isolé par personnage", function()
    reset()
    J.playerDB.quetes.test = { id = "test" }
    J:MigrateDB(); assert(J.playerDB.quetes.test)
    character = "Lecteur"; J:MigrateDB_Joueur(); assert(not J.playerDB.quetes.test)
    character = "Nytherah"; J:MigrateDB_Joueur(); assert(J.playerDB.quetes.test)
    OmegaHubDB.Quest_MJ.version = J.DB_VERSION + 1
    assert(not pcall(J.MigrateDB_MJ, J))
end)

test("Nytherah permanente, contrôle local et royaume explicite", function()
    reset()
    assert(J:IsAdmin()); assert(not J:IsAdmin("Nytherah-AutreRoyaume"))
    assert(not J:SetMJ("Nytherah", false))
    assert(J:SetMJ("Akriax", true)); assert(J:IsMJ("Akriax-Epsilon"))
    character = "Lecteur"
    assert(not J:SetMJ("Intrus", true)); assert(not J:SaveQuest(draft())); assert(not J:CreateTrame("Test", ""))
    J:OpenMJPanel(); assert(not J.panel or not J.panel:IsShown())
    assert(not J:Name("Nom/Intrus")); assert(not J:Name("Nom--Royaume"))
end)

test("Autorisations acceptées uniquement directement de Nytherah", function()
    reset("Lecteur")
    assert(not J:AcceptPermissions({ revision = 1, mj = {"Intrus"} }, "Intrus"))
    assert(J:AcceptPermissions({ revision = 2, mj = {"Akriax"} }, "Nytherah"))
    assert(J:IsMJ("Akriax"))
    assert(not J:AcceptPermissions({ revision = 1, mj = {} }, "Nytherah"))
    assert(not J:AcceptPermissions({ revision = 3, mj = { [2] = "Akriax" } }, "Nytherah"))
    assert(J:AcceptPermissions({ revision = 3, mj = {} }, "Nytherah")); assert(not J:IsMJ("Akriax"))
end)

test("Projection et sérialisation sans aucun texte masqué", function()
    reset()
    local q = assert(J:SaveQuest(draft()))
    local public = J:Project(q)
    assert(public.nombre_etapes == 3 and public.etapes_revelees[2] and not public.etapes_revelees[1])
    local wire = J:Serialize({kind = "quest", quest = public})
    assert(not wire:find("SECRET", 1, true)); assert(not wire:find("destinataires", 1, true))
    local decoded = J:Deserialize(wire)
    assert(decoded.quest.etapes_revelees[2] == q.etapes[2].texte)
    assert(not J:SendWire("Lecteur", {kind = "quest", quest = q}))
    local clean = J:PublicEnvelope({kind = "quest", quest = public, dossier_mj = q, mode = "letter"})
    assert(not J:Serialize(clean):find("SECRET", 1, true))
    assert(not J:PublicEnvelope({kind = "inconnu", dossier_mj = q}))
end)

test("Sérialiseur rejette code, doublons, longueurs et structures malformées", function()
    reset()
    for _, payload in ipairs({ "return os.execute('oops')", "s900:abc", "t1:s1:xt0:", "t2:s1:xn1:s1:xn2:", "nNaN:", "t-1:", "s-1:", "b3", "t99999999:", "t0:garbage" }) do
        if payload ~= "t1:s1:xt0:" then assert(J:Deserialize(payload) == nil, payload) end
    end
    local data = { a = "a:b|cffffaa00é|r\n\"", [2] = false, b = {} }
    local copy = J:Deserialize(J:Serialize(data)); assert(copy.a == data.a and copy[2] == false)
end)

test("Validation réseau, usurpation et mises à jour sans doublon", function()
    reset()
    local q = assert(J:SaveQuest(draft())); local public = J:Project(q)
    assert(not J:AcceptQuest(public, "Intrus"))
    assert(J:AcceptQuest(public, "Nytherah"))
    assert(J:AcceptQuest(public, "Nytherah")); assert(count(J.playerDB.quetes) == 1)
    public.etapes = q.etapes; assert(not J:AcceptQuest(public, "Nytherah")); public.etapes = nil
    public.etapes_revelees[4] = "invalide"; assert(not J:ValidateProjection(public)); public.etapes_revelees[4] = nil
    local changed = J:Copy(q); changed.etapes[1].revelee = true; changed.statut = "terminee"
    local nextQ = assert(J:SaveQuest(changed)); assert(nextQ.id == q.id and nextQ.revision == 2)
    assert(J:AcceptQuest(J:Project(nextQ), "Nytherah"))
    assert(J.playerDB.quetes[q.id].statut == "terminee")
    assert(J:AcceptQuest(J:Project(q), "Nytherah")); assert(J.playerDB.quetes[q.id].revision == 2)
    nextQ.etapes[1].revelee = false; nextQ.revision = 3
    assert(J:AcceptQuest(J:Project(nextQ), "Nytherah")); assert(not J.playerDB.quetes[q.id].etapes_revelees[1])
end)

test("Suppression versionnée résistante aux anciens messages", function()
    reset()
    local q = assert(J:SaveQuest(draft())); assert(J:AcceptQuest(J:Project(q), "Nytherah"))
    assert(J:Distribute(q.id, {"Lecteur"}, "letter")); assert(J:DeleteQuest(q.id))
    local deletion = J.mjDB.outbox[J:Key("Lecteur") .. "/" .. q.id].message
    assert(deletion.kind == "delete" and not deletion.quest)
    assert(J:AcceptDelete(deletion, "Nytherah")); assert(not J.playerDB.quetes[q.id])
    assert(J:AcceptQuest(J:Project(q), "Nytherah")); assert(not J.playerDB.quetes[q.id])
    assert(not J:AcceptDelete(deletion, "Intrus"))
end)

test("Distribution groupe, raid, trames et actualisation automatique", function()
    reset()
    local q = assert(J:SaveQuest(draft()))
    assert(#J:GroupTargets() == 0)
    grouped = true; assert(#J:GroupTargets() == 3); assert(#J:GroupTargets(true) == 0)
    raid = true; local targets = J:GroupTargets(true); assert(#targets == 3)
    assert(J:Distribute(q.id, targets, "letter")); assert(#q.destinataires == 3)
    assert(J:Distribute(q.id, {"Lecteur", "Lecteur-Epsilon"}, "unlock")); assert(#q.destinataires == 3)
    q.etapes[3].revelee = true
    local update = assert(J:SaveQuest(q)); assert(count(J.mjDB.outbox) == 3)
    for _, pending in pairs(J.mjDB.outbox) do
        assert(pending.message.quest.revision == update.revision)
        assert(pending.message.quest.etapes_revelees[3] == "SECRET_OMEGA")
        assert(not pending.message.quest.etapes_revelees[1])
    end
    local trame = assert(J:CreateTrame("Saga du Nord", "Une trame de test"))
    assert(J:SetQuestParent(update.id, "trame", trame.id))
    assert(J.mjDB.quetes[update.id].trame_id == trame.id)
    assert(#J.mjDB.trames[trame.id].quetes == 1 and J.mjDB.trames[trame.id].quetes[1] == update.id)
    assert(J:SetQuestParent(update.id, "libre"))
    assert(J.mjDB.quetes[update.id].trame_id == nil and #J.mjDB.trames[trame.id].quetes == 0)
    assert(J:SetQuestParent(update.id, "trame", trame.id))
    assert(J:DeleteTrame(trame.id))
    assert(J.mjDB.quetes[update.id].trame_id == nil and J.mjDB.trames[trame.id] == nil)
end)

test("Découpage, ordre inversé, accusé ciblé et absence de messages publics", function()
    reset()
    local q = assert(J:SaveQuest(draft()))
    q.etapes[2].texte = string.rep("révélé;\n", 120)
    J:QueueQuest(q, "Lecteur", "letter"); tick(15)
    local wire = table.concat((function() local r = {}; for _, p in ipairs(sent) do r[#r + 1] = p.text end; return r end)())
    assert(not wire:find("SECRET", 1, true))
    assert(#sent > 2)
    local packets = sent; sent = {}
    for i = #packets, 1, -1 do
        local p = packets[i]
        assert(#p.text <= 255 and p.channel == "WHISPER" and p.target == "Lecteur-Epsilon")
        J:Receive(p.prefix, p.text, "RAID", "Nytherah"); assert(not J.playerDB.quetes[q.id])
    end
    for i = #packets, 1, -1 do local p = packets[i]; J:Receive(p.prefix, p.text, "WHISPER", "Nytherah") end
    assert(J.playerDB.pending[q.id] and count(J.playerDB.quetes) == 0)
    J:HandleMessage({kind = "ack", id = q.id, revision = q.revision}, "Intrus"); assert(count(J.mjDB.outbox) == 1)
    J:HandleMessage({kind = "ack", id = q.id, revision = q.revision}, "Lecteur"); assert(count(J.mjDB.outbox) == 0)
end)

test("Messages incomplets bornés, expiration et accusé ancien ignoré", function()
    reset()
    J:Receive(J.PREFIX, "J1:one:0:2:abc", "WHISPER", "Nytherah"); assert(count(J.incoming) == 0)
    J:Receive(J.PREFIX, "J1:one:1:2:abc", "WHISPER", "Nytherah"); assert(count(J.incoming) == 1)
    J:Receive(J.PREFIX, "J1:one:1:2:def", "WHISPER", "Nytherah"); assert(count(J.incoming) == 0)
    J:Receive(J.PREFIX, "J1:two:1:2:abc", "WHISPER", "Nytherah"); now = 601; J:Pump(); assert(count(J.incoming) == 0)
    local q = assert(J:SaveQuest(draft())); J:Distribute(q.id, {"Lecteur"}, "letter")
    q = assert(J:SaveQuest(q))
    J:HandleMessage({kind = "ack", id = q.id, revision = 1}, "Lecteur"); assert(count(J.mjDB.outbox) == 1)
    sendResult = false; tick(12); assert(count(J.mjDB.outbox) == 1)
    J:StopComm(); J:StartComm(); assert(count(J.mjDB.outbox) == 1)
end)

test("MJ inconnu attend les accès de Nytherah, révocation coupe les envois", function()
    reset("Akriax")
    J:AcceptPermissions({revision = 1, mj = {"Akriax"}}, "Nytherah")
    local q = assert(J:SaveQuest(draft())); local data = {kind = "quest", quest = J:Project(q)}
    J.mjDB.permissions.mj = {}
    J:HandleMessage(data, "Akriax"); assert(not J.playerDB.quetes[q.id]); assert(#J.waitingTrust == 1)
    J:HandleMessage({kind = "permissions", revision = 2, mj = {"Akriax"}}, "Nytherah")
    assert(J.playerDB.quetes[q.id]); assert(#J.waitingTrust == 0)
    J:QueueQuest(q, "Lecteur", "letter"); J.wireQueue = {}; tick(1)
    J:AcceptPermissions({revision = 3, mj = {}}, "Nytherah")
    local before = #sent; tick(3); assert(#sent == before)
end)

test("Écriture UTF-8 et markup indivisible, clic et fermeture arrêtent le son", function()
    reset()
    local tokens = J.Write:Tokens("é|cff00ff00à|r|TInterface\\Icons\\INV_Misc_Book_09:16|t")
    assert(#tokens == 5 and tokens[1] == "é" and tokens[3] == "à")
    local f, label = CreateFrame("Frame"), CreateFrame("FontString")
    local text = string.rep("écriture |cff00ff00verte|r ", 20)
    J.Write:Start(f, label, text); f.scripts.OnUpdate(f, .1); assert(f.quillHandle)
    J.Write:Finish(f); assert(label:GetText() == text and not f.quillHandle and not f.scripts.OnUpdate)
end)

test("Livre unique, archives, panneau MJ, confirmation et cycle Enable/Disable", function()
    reset()
    J:CreateBook(); local book = J.book
    local q = assert(J:SaveQuest(draft())); J:AcceptQuest(J:Project(q), "Nytherah", "unlock")
    J:OpenQuest(q.id, true); assert(book.selected == q.id and book.motion:IsShown())
    advanceFrame(book.motion,1); book.content.scripts.OnUpdate(book.content, .1)
    assert(book.text:GetText():find("1", 1, true))
    J.Write:Finish(book.content); assert(book.text:GetText():find("?????", 1, true))
    assert(not book.text:GetText():find("SECRET", 1, true))
    J:OpenMJPanel(); assert(J.panel:IsShown()); J:SetDraft(q)
    assert(J:ReadDraft().id == q.id)
    J.panel.stepEdit:SetText("modification"); J:ReadDraft(); J:LoadStep(2)
    assert(J.panel.draft.etapes[1].texte == "modification")
    J.panel.draft.statut = "terminee"; local saved = J:SavePanelQuest(); assert(saved.statut == "terminee")
    J:AcceptQuest(J:Project(saved), "Nytherah"); assert(book.selected == nil)
    book.archive = true; J:RefreshBook(); assert(book.contents.rows[1].entry.id == q.id)
    StaticPopupDialogs.OMEGA_JOURNAL_DELETE.OnAccept(nil, q.id); assert(not J.mjDB.quetes[q.id])
    J:Disable(); assert(not book:IsShown() and not J.panel:IsShown() and not J.commFrame.scripts.OnUpdate)
    J:Enable(); assert(J.book == book and SlashCmdList.QUEST)
    character = "Lecteur"; J:OpenMJPanel(); assert(not J.panel:IsShown())
end)

test("Écritoire : sommaire trames/chapitres/quêtes, glisser-déposer, renommage et suppression", function()
    reset()
    J:OpenMJPanel()
    local panel = J.panel
    panel.titleEdit:SetText("Une quête"); panel.giverEdit:SetText("Un donneur")
    local q = assert(J:SavePanelQuest())
    local trame = assert(J:CreateTrame("Saga de test", ""))
    panel.selected, panel.expanded[trame.id] = { kind = "trame", id = trame.id }, true
    J:RefreshLibrary()
    local function findNode(kind, id)
        for _, row in ipairs(panel.rows) do
            if row:IsShown() and row.node.kind == kind and row.node.id == id then return row end
        end
    end
    -- Pas d'en-tête « Quêtes libres » : la quête orpheline apparaît directement.
    assert(findNode("trame", trame.id)); assert(findNode("quest", q.id))

    -- Un chapitre est toujours l'enfant d'une trame.
    local chapitre = assert(J:CreateChapitre(trame.id, "Chapitre I"))
    panel.expanded[chapitre.id] = true
    J:RefreshLibrary()
    assert(findNode("chapitre", chapitre.id))

    -- Glisser la quête libre sur la trame : rattachement direct (sans chapitre).
    J:ApplyDrag({ kind = "quest", id = q.id }, { kind = "trame", id = trame.id })
    assert(J.mjDB.quetes[q.id].trame_id == trame.id and J.mjDB.quetes[q.id].chapitre_id == nil)

    -- Glisser la même quête sur le chapitre : elle en devient l'enfant, plus
    -- de rattachement direct à la trame.
    J:ApplyDrag({ kind = "quest", id = q.id }, { kind = "chapitre", id = chapitre.id })
    assert(J.mjDB.quetes[q.id].chapitre_id == chapitre.id and J.mjDB.quetes[q.id].trame_id == nil)
    assert(#chapitre.quetes == 1 and chapitre.quetes[1] == q.id)

    -- Un chapitre ne peut jamais devenir orphelin (dépose ignorée).
    J:ApplyDrag({ kind = "chapitre", id = chapitre.id }, { kind = "libre", id = "__libre__" })
    assert(J.mjDB.chapitres[chapitre.id].trame_id == trame.id)

    -- Une seconde trame : réordonnancement des trames et changement de trame
    -- d'un chapitre, tous deux par glisser-déposer.
    local autre = assert(J:CreateTrame("Autre saga", ""))
    assert(J.mjDB.trameOrder[1] == trame.id and J.mjDB.trameOrder[2] == autre.id)
    J:ApplyDrag({ kind = "trame", id = autre.id }, { kind = "trame", id = trame.id })
    assert(J.mjDB.trameOrder[1] == autre.id and J.mjDB.trameOrder[2] == trame.id)
    J:ApplyDrag({ kind = "chapitre", id = chapitre.id }, { kind = "trame", id = autre.id })
    assert(J.mjDB.chapitres[chapitre.id].trame_id == autre.id)
    assert(#trame.chapitres == 0 and #autre.chapitres == 1 and autre.chapitres[1] == chapitre.id)

    -- Une trame ne se réordonne qu'entre trames : ignorée sur toute autre cible.
    J:ApplyDrag({ kind = "trame", id = trame.id }, { kind = "chapitre", id = chapitre.id })
    assert(J.mjDB.trameOrder[1] == autre.id and J.mjDB.trameOrder[2] == trame.id)

    -- Repli / dépli de la trame.
    panel.expanded[autre.id] = true; J:RefreshLibrary()
    J:OnLibraryRowClick({ kind = "trame", id = autre.id })
    assert(panel.expanded[autre.id] == false); assert(not findNode("chapitre", chapitre.id))
    J:OnLibraryRowClick({ kind = "trame", id = autre.id })
    assert(panel.expanded[autre.id] ~= false)

    -- Consulter une trame puis un chapitre remplit le côté droit (Détails) ;
    -- « Enregistrer » y renomme l'élément consulté.
    J:OnLibraryRowClick({ kind = "trame", id = trame.id })
    assert(panel.details:IsShown()); assert(panel.detailsHeading:GetText() == "Trame")
    assert(not panel.identity:IsShown())
    panel.detailsNameEdit:SetText("Saga renommée"); J:SaveDetails()
    assert(J.mjDB.trames[trame.id].titre == "Saga renommée")
    J:OnLibraryRowClick({ kind = "chapitre", id = chapitre.id })
    assert(panel.detailsHeading:GetText() == "Chapitre")
    -- Le chapitre a été déplacé dans la seconde trame plus haut.
    assert(panel.detailsParent:GetText():find("Autre saga", 1, true))
    panel.detailsNameEdit:SetText("Chapitre renommé"); J:SaveDetails()
    assert(J.mjDB.chapitres[chapitre.id].titre == "Chapitre renommé")

    -- Sélectionner de nouveau une quête reprend les cartes de quête.
    J:OnLibraryRowClick({ kind = "quest", id = q.id })
    assert(panel.identity:IsShown()); assert(not panel.details:IsShown())

    -- Détachement par glisser-déposer vers l'état libre (plus de groupe dédié).
    J:ApplyDrag({ kind = "quest", id = q.id }, { kind = "libre", id = "__libre__" })
    assert(J.mjDB.quetes[q.id].trame_id == nil and J.mjDB.quetes[q.id].chapitre_id == nil)

    -- Suppression en cascade : la trame emporte son chapitre avec elle.
    StaticPopupDialogs.OMEGA_QUEST_DELETE_TRAME.OnAccept(nil, autre.id)
    assert(not J.mjDB.trames[autre.id]); assert(not J.mjDB.chapitres[chapitre.id])
end)

test("Builders trame/chapitre : fenêtre au thème de l'écritoire, un nom suffit", function()
    reset()
    J:OpenMJPanel()
    local panel = J.panel

    -- « Nouvelle trame » ouvre le builder (même identité visuelle que le
    -- reste de l'écritoire) : un seul champ, le nom.
    panel.newTrameButton.scripts.OnClick()
    assert(J.namePrompt:IsShown()); assert(J.namePrompt.heading:GetText() == "Nom de la trame")
    J.namePrompt.nameEdit:SetText("Saga du builder")
    J:CommitNamePrompt()
    assert(not J.namePrompt:IsShown())
    local trameID
    for id, t in pairs(J.mjDB.trames) do if t.titre == "Saga du builder" then trameID = id end end
    assert(trameID); assert(panel.selected.kind == "trame" and panel.selected.id == trameID)
    assert(panel.details:IsShown()); assert(panel.detailsNameEdit:GetText() == "Saga du builder")

    -- « Nouveau chapitre » réutilise la même fenêtre, ciblée sur la trame active.
    panel.newChapitreButton.scripts.OnClick()
    assert(J.namePrompt:IsShown()); assert(J.namePrompt.heading:GetText() == "Nom du chapitre")
    J.namePrompt.nameEdit:SetText("Chapitre du builder")
    J:CommitNamePrompt()
    local chapitreID
    for id, c in pairs(J.mjDB.chapitres) do if c.titre == "Chapitre du builder" then chapitreID = id end end
    assert(chapitreID); assert(J.mjDB.chapitres[chapitreID].trame_id == trameID)
    assert(panel.selected.kind == "chapitre" and panel.selected.id == chapitreID)
    assert(panel.detailsParent:GetText():find("Saga du builder", 1, true))
end)

test("Raccourci journal : installation différée et personnalisation conservée", function()
    reset()
    bindings, savedBindings = {}, 0
    OmegaHubDB.Quest_Bindings = nil
    combat = true
    J:InstallBinding(); assert(not bindings["SHIFT-I"])
    combat = false
    for _, frame in ipairs(frames) do
        if frame.events.PLAYER_REGEN_ENABLED then frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED") end
    end
    assert(bindings["SHIFT-I"] == "OMEGA_JOURNAL_TOGGLE" and savedBindings == 1)
    J.book:Hide(); J:ToggleJournal(); assert(J.book:IsShown())
    J:ToggleJournal(); assert(not J.book:IsShown())
    bindings["SHIFT-I"] = "OTHER_ACTION"
    J:InstallBinding(); assert(bindings["SHIFT-I"] == "OTHER_ACTION" and savedBindings == 1)
    J:Disable(); J:ToggleJournal(); assert(not J.book:IsShown())
end)

test("Enveloppes BLP et dessin : aperçus locaux, file et arrêt des animations", function()
    reset(); J.notices={}
    local before=count(J.playerDB.quetes)
    for _,backend in ipairs({"blp","dessin"}) do
        J:PreviewEnvelope(backend)
        assert(J.letter.playing and J.letter:IsShown())
        for _=1,70 do if J.letter.scripts.OnUpdate then J.letter.scripts.OnUpdate(J.letter,.05) end end
        assert(J.letter.ready and not J.letter.scripts.OnUpdate)
        assert(J.sheet:IsShown() and J.sheet.demo)
        J:FinishLetter(true)
        assert(not J.letter:IsShown() and count(J.playerDB.quetes)==before and #sent==0)
    end
    local first=assert(J:SaveQuest(draft())); local second=assert(J:SaveQuest(draft()))
    J:AcceptQuest(J:Project(first),"Nytherah","letter"); J:AcceptQuest(J:Project(second),"Nytherah","letter")
    assert(#J.notices==2 and not J.letter.demo)
    local original=J.OpenQuest; local opened
    J.OpenQuest=function(_,id) opened=id end
    J.letter.scripts.OnClick(); advanceFrame(J.letter,4)
    assert(J.sheet:IsShown() and not J.playerDB.quetes[first.id])
    J:FinishLetter(true)
    assert(opened==first.id and #J.notices==1 and J.letter:IsShown())
    J.OpenQuest=original
    J:AnimateEnvelope(); J:Disable()
    assert(not J.letter.scripts.OnUpdate and not J.letter:IsShown())
end)

test("Lettre publique, refus persistant et suppression des remises en attente", function()
    reset()
    local d=draft()
    d.lettre={objet="Le registre",expediteur="Le gardien",texte="Retrouvez-moi aux archives.",secret="NE_PAS_TRANSMETTRE"}
    local q=assert(J:SaveQuest(d)); local projected=J:Project(q)
    assert(projected.lettre.texte==d.lettre.texte and not projected.lettre.secret)
    assert(not J:Serialize(projected):find("NE_PAS_TRANSMETTRE",1,true))
    assert(J:AcceptQuest(projected,"Nytherah","letter"))
    assert(J.playerDB.pending[q.id] and not J.playerDB.quetes[q.id])
    J:MigrateDB_Joueur(); assert(J.playerDB.pending[q.id])
    J:ShowLetterSheet(q.id,false)
    assert(J.sheet.subject:GetText():find("Le registre",1,true))
    assert(J.sheet.body:GetText()==d.lettre.texte)
    J:FinishLetter(false)
    assert(J.playerDB.refused[q.id] and not J.playerDB.quetes[q.id] and not J.playerDB.pending[q.id])
    q=assert(J:SaveQuest(q))
    assert(J:AcceptQuest(J:Project(q),"Nytherah","update"))
    assert(not J.playerDB.quetes[q.id] and not J.playerDB.pending[q.id])
    local other=assert(J:SaveQuest(draft()))
    J:AcceptQuest(J:Project(other),"Nytherah","letter"); J:ShowLetterSheet(other.id,false)
    assert(J:AcceptDelete({id=other.id,auteur="Nytherah",revision=other.revision+1},"Nytherah"))
    assert(not J.sheet:IsShown() and not J.playerDB.pending[other.id])
end)

test("Grimoire : marque-pages extensibles, ouverture, fermeture et interruption", function()
    reset();J:CreateBook()
    local b=J.book
    b:Hide();b:Show();assert(b.motion:IsShown() and b.motion.scripts.OnUpdate)
    assert(b.alpha==0 and b.motion.sequence=="opening" and b.motion.index>=0)
    advanceFrame(b.motion,.15);assert(b.alpha==0 and b.motion.index<24)
    advanceFrame(b.motion,1);assert(not b.motion:IsShown())
    b:Hide();assert(b.motion:IsShown())
    b:Show();advanceFrame(b.motion,1);assert(b:IsShown() and not b.motion:IsShown())
    local size=#J.Book.categories
    J.Book:RegisterCategory({id="test",label="Test",matches=function() return true end})
    assert(#b.tabs==size+1)
    b.tabs[size+1].scripts.OnClick(b.tabs[size+1]);b.textFade.scripts.OnUpdate(b.textFade,.3);assert(b.category=="test" and b.motion.mode=="page")
    advanceFrame(b.motion,.22);advanceFrame(b.motion,1)
    table.remove(J.Book.categories);b.category="active";J:RefreshBookmarks()
    J:Disable();assert(not b.motion:IsShown() and not b.motion.scripts.OnUpdate)
end)

test("Personnel, Groupe et Archive : classement par destinataire conservé", function()
    reset()
    local q=assert(J:SaveQuest(draft()))
    assert(J:Distribute(q.id,{"Lecteur"},"letter"))
    assert(J:Distribute(q.id,{"Autre"},"group"))
    assert(J:Project(q,"Lecteur").categorie=="personnel")
    assert(J:Project(q,"Autre").categorie=="groupe")
    q=assert(J:SaveQuest(q));assert(J:Project(q,"Autre").categorie=="groupe")
    local personal,group,archive=J.Book.categories[1],J.Book.categories[2],J.Book.categories[3]
    assert(personal.matches(J:Project(q,"Lecteur")) and not group.matches(J:Project(q,"Lecteur")))
    assert(group.matches(J:Project(q,"Autre")) and not personal.matches(J:Project(q,"Autre")))
    q.statut="terminee";assert(archive.matches(J:Project(q,"Autre")) and not group.matches(J:Project(q,"Autre")))
end)

test("Atlas du grimoire : indices, inversion rapide et texte masqué", function()
    reset();J:CreateBook();local b=J.book
    b:Hide();J:StopBookMotion();b:Show()
    local m=b.motion
    assert(m.index==0 and b.alpha==0 and m.image.texture:find("opening-1.blp",1,true))
    advanceFrame(m,.25);local index=m.index
    assert(index>0 and index<23 and b.alpha==0)
    b:Hide();assert(m.index==index and m.mode=="close")
    advanceFrame(m,.10);assert(m.index<index)
    index=m.index;b:Show();assert(m.index==index and m.mode=="open")
    advanceFrame(m,1);assert(m.index==23 and b.alpha==1 and not m:IsShown())
    J:TurnBookPage();b.textFade.scripts.OnUpdate(b.textFade,.3);assert(m.index==0 and b.alpha==0)
    assert(b.rail.ignoreParentAlpha and b.mjButton.ignoreParentAlpha)
    assert(b.rail:GetFrameLevel()>m:GetFrameLevel() and b.mjButton:GetFrameLevel()>m:GetFrameLevel())
    assert(b.mjButton.ribbon.texture:find("bookmark-mj.blp",1,true))
    assert(m.image.texture:find("turning-1.blp",1,true))
    advanceFrame(m,1);assert(m.index==15 and b.alpha==1)
    assert(not b.rail.ignoreParentAlpha and not b.mjButton.ignoreParentAlpha)
    assert(m.image.texture:find("turning-4.blp",1,true))
    assert(m.image.texCoord[1]==.5 and m.image.texCoord[4]==1)
    b:Hide();advanceFrame(m,1)
    assert(m.index==0 and not m:IsShown() and not b:IsShown())
end)

test("Page tournée : fondu du texte sur 0,3 seconde et interruption", function()
    reset();J:CreateBook();local b=J.book
    b:Show();advanceFrame(b.motion,1)
    local changed=false
    J:TurnBookPage(function() changed=true end)
    assert(not changed and b.left.alpha==1 and not b.motion:IsShown())
    b.textFade.scripts.OnUpdate(b.textFade,.15)
    assert(not changed and b.left.alpha==.5 and b.rail:IsShown())
    b.textFade.scripts.OnUpdate(b.textFade,.15)
    assert(changed and b.motion:IsShown() and b.alpha==0)
    advanceFrame(b.motion,1)
    local fade=b.textFade
    assert(b.alpha==1 and b.left.alpha==0 and b.right.alpha==0)
    assert(b.rail:IsShown() and not b.content.writing)
    fade.scripts.OnUpdate(fade,.15)
    assert(b.left.alpha==.5 and b.right.alpha==.5)
    fade.scripts.OnUpdate(fade,.15)
    assert(b.left.alpha==1 and b.right.alpha==1 and not fade.scripts.OnUpdate)
    J:TurnBookPage();b.textFade.scripts.OnUpdate(b.textFade,.3);advanceFrame(b.motion,1)
    fade.scripts.OnUpdate(fade,.06);J:TurnBookPage()
    assert(fade.scripts.OnUpdate and b.left.alpha==.2)
    fade.scripts.OnUpdate(fade,.3);advanceFrame(b.motion,1);b:Hide()
    assert(not fade.scripts.OnUpdate and b.right.alpha==1)
    J:StopBookMotion()
end)

test("Textures préchargées : aucune réaffectation et attente sans image vide", function()
    reset();J:OnLoad()
    local b=J.book;local m=b.motion
    assert(not m:IsShown() and not J.letter:IsShown())
    local pending=m.images.opening[2];pending.loaded=false
    b:Show();local previous=m.image;local index=m.index
    advanceFrame(m,.2)
    assert(m.image==previous and m.index==index and m.elapsed==0)
    pending.loaded=true;advanceFrame(m,.3)
    assert(m.index>index)
    advanceFrame(m,1);J:TurnBookPage();b.textFade.scripts.OnUpdate(b.textFade,.3);advanceFrame(m,1)
    for _,images in pairs(m.images) do
        for _,image in ipairs(images) do assert(image.textureLoads==1) end
    end
    J:ShowEnvelope(true,"blp");local f=J.letter
    f.images[2].loaded=false;local first=f.image
    f.scripts.OnUpdate(f,.5);assert(f.elapsed==0 and f.image==first)
    f.images[2].loaded=true
    for i=0,63 do J:DrawEnvelope(i/63) end
    for _,image in ipairs(f.images) do assert(image.textureLoads==1) end
    f:Hide();J:ShowEnvelope(true,"dessin")
    for _,image in ipairs(f.images) do assert(not image:IsShown()) end
    f:Hide()
end)

test("Première lecture : images entières, attente, priorité et annulation", function()
    reset();J.animationWarmup=nil;J:WarmAnimationTextures()
    local warm=J.animationWarmup
    assert(warm:IsShown() and warm.parent==UIParent and #warm.images==21)
    for _,texture in ipairs(warm.images) do
        assert(not texture:IsShown() and texture.alpha>0)
        assert(texture.texCoord[1]==0 and texture.texCoord[2]==1 and texture.texCoord[4]==1)
    end
    J:WarmAnimationTextures();assert(warm.elapsed==0)
    J:AnimationTexturesReady("envelope")
    warm.scripts.OnUpdate(warm,.016)
    assert(warm.current.path:find("Envelope",1,true))
    local image=warm.current.image;image.loaded=false
    for _=1,10 do warm.scripts.OnUpdate(warm,.1) end
    assert(not warm.ready and not J:AnimationTexturesReady("envelope"))
    image.loaded=true
    warm.scripts.OnUpdate(warm,.016);warm.scripts.OnUpdate(warm,.016)
    assert(not warm.current.ready)
    pumpWarm()
    assert(warm.ready and not warm:IsShown() and not warm.scripts.OnUpdate)
    for _,texture in ipairs(warm.images) do assert(texture.textureLoads==1) end
    assert(J:AnimationTexturesReady("opening") and J:AnimationTexturesReady("turning") and J:AnimationTexturesReady("envelope"))
    J:WarmAnimationTextures();assert(not warm:IsShown())
    warm.ready=false;J:WarmAnimationTextures();J:Disable()
    assert(not warm:IsShown() and not warm.scripts.OnUpdate)
end)

test("Première animation : attendre le dessin préalable et ne pas sauter les poses",function()
    reset();J:OnLoad();J.animationWarmup=nil;J:WarmAnimationTextures()
    local warm=J.animationWarmup
    J.book:Show();local m=J.book.motion
    m.scripts.OnUpdate(m,.5);assert(m.elapsed==0 and m.waitingForTextures)
    -- Le préchargement doit continuer tant que l'animation attend.
    for _=1,100 do if warm.scripts.OnUpdate then warm.scripts.OnUpdate(warm,.016) end end
    m.scripts.OnUpdate(m,.5);assert(m.elapsed==0 and not m.waitingForTextures)
    local index=m.index
    m.scripts.OnUpdate(m,.8);assert(m.index==index+1)
    advanceFrame(m,1)
    J:TurnBookPage();J.book.textFade.scripts.OnUpdate(J.book.textFade,.3)
    m.scripts.OnUpdate(m,.5);index=m.index
    m.scripts.OnUpdate(m,.8);assert(m.index==index+1)
    advanceFrame(m,1)
    J:ShowEnvelope(true,"blp");local f=J.letter
    f.scripts.OnUpdate(f,.5);assert(f.elapsed==0)
    f.scripts.OnUpdate(f,.8);assert(f.imageIndex<=1)
    advanceFrame(f,4);assert(J.sheet:IsShown())
end)

test("Préchargement défaillant : pas de faux succès ni animation bloquée",function()
    reset();J:OnLoad();J.animationWarmup=nil;J:WarmAnimationTextures()
    local warm=J.animationWarmup
    warm.scripts.OnUpdate(warm,.016);warm.current.image.loaded=false
    warm.scripts.OnUpdate(warm,16)
    assert(warm.failed and not warm.ready and not warm:IsShown())
    J.book:Show();J:PlayBookSequence("open")
    local m=J.book.motion;m.scripts.OnUpdate(m,.1)
    assert(not m:IsShown() and J.book.alpha==1)
    J:ShowEnvelope(true,"blp");J.letter.scripts.OnUpdate(J.letter,.1)
    assert(J.sheet:IsShown() and not J.letter:IsShown())
    J:Disable()
end)

test("Trois clients séparés : accès, lettre, mise à jour, reconnexion et suppression", function()
    local clients, bus = {}, {}
    local originalSend = C_ChatInfo.SendAddonMessage
    local active
    local function selectClient(client)
        active, character, OmegaHubDB = client, client.name, client.db
    end
    local function client(name, saved)
        character, OmegaHubDB = name, saved or { modules = {} }
        for _, file in ipairs(files) do dofile(base .. file) end
        local module = Quest
        module.enabled = true
        module:MigrateDB()
        local instance = { name = name, db = OmegaHubDB, module = module, notices = {} }
        module.Notify = function(_, id, mode) instance.notices[#instance.notices + 1] = {id = id, mode = mode} end
        module.RefreshBook = function() end
        clients[name:lower() .. "-epsilon"] = instance
        selectClient(instance); module:StartComm()
        return instance
    end
    C_ChatInfo.SendAddonMessage = function(prefix, text, channel, target)
        assert(channel == "WHISPER" and #text <= 255)
        bus[#bus + 1] = {prefix = prefix, text = text, sender = active.name .. "-Epsilon", target = target:lower()}
        return true
    end
    local admin = client("Nytherah")
    local mj = client("Akriax")
    local reader = client("Lecteur")
    local function network(ticks)
        for _ = 1, ticks do
            now = now + 1.1
            for _, c in pairs(clients) do selectClient(c); c.module:Pump() end
            local messages = bus; bus = {}
            for _, packet in ipairs(messages) do
                local receiver = clients[packet.target]
                if receiver then selectClient(receiver); receiver.module:Receive(packet.prefix, packet.text, "WHISPER", packet.sender) end
            end
        end
    end
    selectClient(admin); assert(admin.module:SetMJ("Akriax", true))
    network(20)
    selectClient(mj); assert(mj.module:IsMJ())
    local q = assert(mj.module:SaveQuest(draft()))
    assert(mj.module:Distribute(q.id, {"Lecteur"}, "letter"))
    network(30)
    assert(reader.module.playerDB.pending[q.id] and not reader.module.playerDB.quetes[q.id])
    assert(reader.module:DecideLetter(q.id,true))
    assert(reader.notices[1].mode == "letter" and #reader.notices == 1)
    assert(not reader.module.playerDB.quetes[q.id].etapes_revelees[1])
    assert(count(mj.module.mjDB.outbox) == 0)
    -- Hors ligne : la remise reste persistée chez le MJ.
    clients["lecteur-epsilon"] = nil
    selectClient(mj)
    q.etapes[1].revelee = true; q.statut = "terminee"
    q = assert(mj.module:SaveQuest(q)); network(20)
    assert(count(mj.module.mjDB.outbox) == 1)
    reader = client("Lecteur", reader.db); network(35)
    assert(reader.module.playerDB.quetes[q.id].statut == "terminee")
    assert(reader.module.playerDB.quetes[q.id].etapes_revelees[1] == "SECRET_ALPHA")
    assert(count(reader.module.playerDB.quetes) == 1 and #reader.notices == 0)
    assert(count(mj.module.mjDB.outbox) == 0)
    selectClient(mj); assert(mj.module:DeleteQuest(q.id)); network(20)
    assert(not reader.module.playerDB.quetes[q.id] and reader.module.playerDB.tombstones[q.id])
    assert(count(mj.module.mjDB.outbox) == 0)
    C_ChatInfo.SendAddonMessage = originalSend
end)

print("SUCCES : " .. passed .. " scénarios")
