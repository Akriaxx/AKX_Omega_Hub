// Charge les vrais fichiers du module dans un faux client WoW et vérifie
// la construction des commandes, l'envoi, la bascule appliquer/retirer,
// l'historique, les favoris et la fenêtre.
// Usage (depuis la racine de l'addon) : node Modules/GMMaster/Tests/gmmaster-test.js <chemin de lua-cli.js de fengari-node-cli>
const cp = require('child_process');
const cli = process.argv[2]; if (!cli) throw Error('Pass the Fengari CLI path');

const lua = String.raw`
unpack = table.unpack or unpack
local noop = function() end
local M = setmetatable({}, { __index = function(_, k) if k:match("^%u") then return noop end end })
local frames = {}
local function obj(kind, name, parent)
    local f = setmetatable({ kind = kind, parent = parent, scripts = {}, shown = true, text = "", events = {} }, { __index = M })
    if name then _G[name] = f end
    frames[#frames + 1] = f
    return f
end
function CreateFrame(kind, name, parent) return obj(kind, name, parent) end
function M:CreateTexture() return obj("Texture", nil, self) end
function M:CreateFontString() return obj("FontString", nil, self) end
function M:SetScript(k, v) self.scripts[k] = v end
function M:GetScript(k) return self.scripts[k] end
function M:HookScript(k, v) local old = self.scripts[k]; self.scripts[k] = function(...) if old then old(...) end; v(...) end end
function M:Show() local was = self.shown; self.shown = true; if not was and self.scripts.OnShow then self.scripts.OnShow(self) end end
function M:Hide() local was = self.shown; self.shown = false; if was and self.scripts.OnHide then self.scripts.OnHide(self) end end
function M:SetShown(v) if v then self:Show() else self:Hide() end end
function M:IsShown() return self.shown end
function M:SetText(t) self.text = t or "" end
function M:GetText() return self.text end
function M:SetFontString(fs) self.fs = fs end
function M:GetFontString() return self.fs end
function M:SetChecked(v) self.checked = v end
function M:GetChecked() return self.checked end
function M:HasFocus() return false end
function M:RegisterEvent(e) self.events[e] = true end
function M:Click(button) self.scripts.OnClick(self, button or "LeftButton") end
function M:Type(text) self:SetText(text); self.scripts.OnTextChanged(self, true) end
function M:Enter() self.scripts.OnEnterPressed(self) end
UIParent = obj("Frame")
UISpecialFrames = {}
tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end end
GameTooltip = obj("GameTooltip")

-- Client
local sent, opened = {}, 0
SendChatMessage = function(text, channel) sent[#sent + 1] = text; assert(channel == "GUILD") end
C_ChatInfo = { SendChatMessage = function() error("doit passer par SendChatMessage (crochet EpsilonLib)") end }
ChatFrame_OpenChat = function() opened = opened + 1 end
ChatFrameUtil = { OpenChat = ChatFrame_OpenChat }
local target
function UnitExists(u) return u == "target" and target ~= nil end
function UnitIsUnit(a, b) return false end
function UnitName(u) return u == "target" and target or "Moi" end
function UnitIsPlayer() return true end
function GetUnitName(u) return UnitName(u) end
local shift = false
function IsShiftKeyDown() return shift end
local clock = 0
function GetTime() return clock end
C_Spell = { GetSpellInfo = function(id) if id == 1234 then return { name = "Flamme", iconID = 1 } end end }

-- Hub
local loaded = {}
OmegaHub = { _startingUp = true, Print = noop,
    RegisterModule = function(self, d) self.data = d end,
    IsModuleEnabled = function() return true end,
    SetModuleLoaded = function(_, n, v) loaded[n] = v end }
SlashCmdList = {}

dofile("UI/UI.lua")
for _, file in ipairs({ "Version", "Abbrev.generated", "Commands", "Core", "UI_Panel" }) do dofile("Modules/GMMaster/" .. file .. ".lua") end
for _, f in ipairs(frames) do
    if f.events.PLAYER_LOGIN then f.scripts.OnEvent(f, "PLAYER_LOGIN") end
end
local GM = GMMaster
assert(loaded.GMMaster and OmegaHub.data.version == GMMASTER_VERSION, "enregistrement")
local function last() return sent[#sent] end
-- Forme abrégée attendue d'une commande écrite en toutes lettres.
local function S(full)
    local words = {}
    for w in full:gmatch("%S+") do words[#words + 1] = { text = w, cmd = not w:match("^%d") } end
    GM.Shorten(words)
    local out = {}
    for i, w in ipairs(words) do out[i] = w.text end
    return "." .. table.concat(out, " ")
end
local D = GM.DomainByKey

-- Construction
assert("." .. GM.Build(D.npc, "npc spawn {id}", { id = " 123 " }) == S("npc spawn 123"))
local cmd, err = GM.Build(D.npc, "npc spawn {id}", { id = "" }); assert(not cmd and err == "Renseigner : ID créature", err)
cmd, err = GM.Build(D.npc, "npc spawn {id}", { id = "12a" }); assert(not cmd and err:find("entier"))
cmd, err = GM.Build(D.modify, "modify scale {scale}", { scale = "abc" }); assert(not cmd and err:find("nombre attendu"))
-- Abréviations sans ambiguïté (exemples validés en jeu)
assert(S("npc say") == ".n sa" and S("npc scale") == ".n sc" and S("npc set") == ".n se" and S("npc spawn") == ".n sp")
assert(S("phase forge npc gossip") == ".ph f n g")
-- Les valeurs saisies ne sont jamais abrégées, même si elles ressemblent à une sous-commande
assert(GM.Build(D.tele, "tele {name}", { name = "add" }):match(" add$"))
assert("." .. GM.Build(D.aura, "aura {id} {who}", { id = "5", who = "" }) == S("aura 5"))
assert("." .. GM.Build(D.aura, "aura {id} {who}", { id = "5", who = "self" }) == S("aura 5 self"))

-- Chaque modèle du catalogue se construit avec des valeurs plausibles
-- et correspond à une commande de la liste du serveur (EpsilonLib).
local unknown = {}
for _, domain in ipairs(GM.Domains) do
    local v = { id = "1", scale = "1", speed = "1", hp = "1", stand = "1", emote = "1", range = "5",
                text = "Bonjour", name = "Lieu", player = "Ami", who = "self",
                subname = "Garde", display = "1", aura = "1", option = "clickable", item = "1", slot = "0",
                race = "1", gender = "male", part = "hair", value = "2",
                block = "0", optnum = "1", page = "2", angle = "90" }
    for _, action in ipairs(domain.actions) do
        for _, t in ipairs(type(action.cmd) == "table" and action.cmd or { action.cmd }) do
            local c, e, known = GM.Build(domain, t, v); assert(c and not c:find("[{}]"), domain.key .. "." .. action.key .. " " .. tostring(e))
            if not known then unknown[#unknown + 1] = domain.key .. "." .. action.key .. " : " .. t end
        end
    end
end

assert(#unknown == 0, "commandes inconnues du serveur :  " .. table.concat(unknown, "  |  "))

-- Auras : appliquer, basculer, retirer, sans retaper l'ID
local values = GM:GetValues(D.aura)
assert(values.who == "", "choix par défaut")
values.id, values.who = "1234", "self"
assert(GM:RunAction(D.aura, D.aura.actionByKey.apply))
assert(last() == S("aura 1234 self") and #GM:GetTracked(D.aura) == 1)
assert(GM:RunAction(D.aura, D.aura.actionByKey.apply)); assert(#GM:GetTracked(D.aura) == 1, "pas de doublon")
assert(GM:RunAction(D.aura, D.aura.actionByKey.toggle)); assert(last() == S("unaura 1234 self") and #GM:GetTracked(D.aura) == 0)
assert(GM:RunAction(D.aura, D.aura.actionByKey.toggle)); assert(last() == S("aura 1234 self") and #GM:GetTracked(D.aura) == 1)
-- Sur une cible : suivie séparément, retirée depuis la liste
target = "Garde"; values.who = ""
assert(GM:RunAction(D.aura, D.aura.actionByKey.apply)); assert(last() == S("aura 1234") and #GM:GetTracked(D.aura) == 2)
local entry = GM:GetTracked(D.aura)[1]
assert(entry.values.target == "Garde")
assert(GM:TrackedLabel(D.aura, entry):find("Flamme") and GM:TrackedLabel(D.aura, entry):find("Garde"))
assert(GM:UntrackEntry(D.aura, 1)); assert(last() == S("unaura 1234") and #GM:GetTracked(D.aura) == 1)
-- Tout retirer sans cible oublie les auras posées sur soi
target = nil
assert(GM:RunAction(D.aura, D.aura.actionByKey.all)); assert(last() == S("unaura all") and #GM:GetTracked(D.aura) == 0)
-- Erreur : rien n'est envoyé
local before = #sent; values.id = ""
local ok, msg = GM:RunAction(D.aura, D.aura.actionByKey.apply)
assert(not ok and #sent == before and GM.lastError == msg)

-- Auras de PNJ : liées au PNJ ciblé
local nv = GM:GetValues(D.npcaura); nv.id = "77"; target = "Ours"
assert(GM:RunAction(D.npcaura, D.npcaura.actionByKey.toggle)); assert(last() == S("npc set aura 77"))
target = "Loup"
assert(GM:RunAction(D.npcaura, D.npcaura.actionByKey.toggle)); assert(last() == S("npc set aura 77") and #GM:GetTracked(D.npcaura) == 2)
target = "Ours"
assert(GM:RunAction(D.npcaura, D.npcaura.actionByKey.toggle)); assert(last() == S("npc set unaura 77") and #GM:GetTracked(D.npcaura) == 1)

-- Historique et favoris
local idField = D.npc.fieldByKey.id
local pv = GM:GetValues(D.npc)
for _, id in ipairs({ "10", "20", "10", "30" }) do pv.id = id; GM:RunAction(D.npc, D.npc.actionByKey.spawn) end
local h = GM:GetHistory(D.npc, idField); assert(h[1] == "30" and h[2] == "10" and h[3] == "20" and #h == 3)
GM:ToggleFavorite(D.npc, idField, "20")
local chips = GM:GetChips(D.npc, idField); assert(chips[1].value == "20" and chips[1].favorite and #chips == 3)
for i = 1, 20 do GM:PushHistory(D.npc, idField, tostring(100 + i)) end
assert(#GM:GetHistory(D.npc, idField) == 12)

-- Plusieurs commandes
before = #sent
assert(GM:RunAction(D.modify, D.modify.actionByKey.reset)); assert(#sent == before + 2 and sent[#sent - 1] == S("modify scale 1"))

-- Fenêtre
SlashCmdList.OMEGAGMMASTER("")
assert(GMMasterPanel:IsShown())
for _, domain in ipairs(GM.Domains) do GM.SelectDomain(domain.key); assert(GM.pages[domain.key]:IsShown()) end
-- Domaines : chaque section appartient à un seul domaine, un onglet par section
local seen = {}
for _, group in ipairs(GM.Groups) do
    GM.SelectGroup(group.key)
    local shown = 0
    for i, tab in ipairs(GM.tabs) do
        if tab:IsShown() then shown = shown + 1; assert(tab.sectionKey == group.sections[i]) end
    end
    assert(shown == #group.sections, group.key)
    for _, key in ipairs(group.sections) do assert(not seen[key], key); seen[key] = true end
end
for _, domain in ipairs(GM.Domains) do assert(seen[domain.key], "section sans domaine : " .. domain.key) end
GM.SelectGroup("npc"); GM.tabs[2]:Click()
assert(GM.pages.npcaura:IsShown() and not GM.pages.npc:IsShown())
assert(GM.tabs[1].text == "Créature" and GM.tabs[2].text == "Auras")
GM.SelectGroup("spell"); assert(GM.tabs[1].sectionKey == "aura" and GM.tabs[2].sectionKey == "cast")
GM.SelectGroup("npc"); assert(GM.pages.npcaura:IsShown(), "le domaine rouvre la dernière section")
GM.SelectDomain("npc")
local page = GM.pages.npc
page.editors.id:Type("777"); page.editors.id:Enter()
assert(last() == S("npc spawn 777"), last())
assert(GM:GetHistory(D.npc, idField)[1] == "777")
page.actionButtons.delete:Click(); assert(last() == S("npc delete"))
-- La pastille reprend la valeur ; double-clic l'exécute
local chip = page.chipRows.id[2]; local chipValue = chip.value
chip:Click(); assert(GM:GetValues(D.npc).id == chipValue and page.editors.id:GetText() == chipValue)
clock = 0.1; chip:Click(); assert(last() == S("npc spawn " .. chipValue))
-- Clic droit oublie
clock = 5; chip:Click("RightButton")
for _, v in ipairs(GM:GetHistory(D.npc, idField)) do assert(v ~= chipValue) end
-- Pas à pas sur un nombre
GM.SelectDomain("modify")
local mp = GM.pages.modify
local plus
for _, f in ipairs(frames) do if f.parent == mp and f.text == "+" then plus = f; break end end
plus:Click(); assert(GM:GetValues(D.modify).scale == "1.05", GM:GetValues(D.modify).scale)
-- Choix « Sur » qui défile
GM.SelectDomain("aura")
local ap = GM.pages.aura
ap.editors.who:Click(); assert(GM:GetValues(D.aura).who == "self")
ap.editors.who:Click(); assert(GM:GetValues(D.aura).who == "")
-- Toujours envoyée, même avec Maj enfoncée ou un ancien réglage « préparer »
GMMasterDB.prepare = true; shift = true
GM.SelectDomain("npc"); before = #sent
page.actionButtons.near:Click(); assert(#sent == before + 1 and last() == S("npc near"))
page.editors.id:Type("55"); page.editors.id:Enter(); assert(last() == S("npc spawn 55"))
shift = false
assert(opened == 0, "rien ne doit être placé dans la saisie du chat")
-- .gm n'existe pas sur Epsilon
for _, domain in ipairs(GM.Domains) do
    for _, action in ipairs(domain.actions) do
        for _, t in ipairs(type(action.cmd) == "table" and action.cmd or { action.cmd }) do assert(not t:match("^gm "), t) end
    end
end

-- Désactivation
GM:Disable(); assert(not GMMasterPanel:IsShown() and SlashCmdList.OMEGAGMMASTER == nil)
print("OK: GM Master — " .. #sent .. " commandes envoyées, " .. #GM.Groups .. " domaines, " .. #GM.Domains .. " sections")
`;
const result = cp.spawnSync(process.execPath, [cli, '-'], { input: 'local ok,err=pcall(function()\n' + lua + '\nend)\nif not ok then print(err);os.exit(1) end', encoding: 'utf8' });
process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || ''); process.exit(result.status || 0);
