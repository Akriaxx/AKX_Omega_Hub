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
function M:GetFrameLevel() return 1 end
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
altDown = false
function IsAltKeyDown() return altDown end
playerAuras = {}
C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return playerAuras[id] and { spellId = id } or nil end }
function hooksecurefunc(t, k, f)
    local orig = t[k]
    t[k] = function(...) local r = { orig(...) }; f(...); return unpack(r) end
end
-- EpsilonLib : état des triches, mis à jour par les réponses du serveur
cheats = { fly = false, god = true }
EpsilonLib = { Cheat = {
    GetCheatStatus = function(c) return cheats[c] end,
    SetCheatStatus = function(c, v) cheats[c] = v end,
} }

-- Hub
local loaded = {}
OmegaHub = { _startingUp = true, Print = noop,
    RegisterModule = function(self, d) self.data = d end,
    IsModuleEnabled = function() return true end,
    SetModuleLoaded = function(_, n, v) loaded[n] = v end }
SlashCmdList = {}

dofile("UI/UI.lua")
for _, file in ipairs({ "Version", "Abbrev.generated", "AuraVisuals.generated", "EmoteAnimations.generated", "Commands", "Core", "Macros", "UI_Panel", "UI_Bar", "UI_AuraBank", "UI_AuraPreview" }) do dofile("Modules/GMMaster/" .. file .. ".lua") end
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
                block = "0", optnum = "1", page = "2", angle = "90",
                level = "10", health = "2", faction = "35", mount = "1", hover = "dynamic" }
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

-- ── Macros techniques : résolution d'après la doc EpsilonLib ──────────────
local R = GM.ResolveLine
local r = R("mod speed 20")
assert(r.status == "ok" and r.full == "modify speed 20" and "." .. r.short == S("modify speed 20"), r.short)
r = R(".ph f n scale 2"); assert(r.status == "ok" and r.full == "phase forge npc scale 2")
r = R("phase forge npc gossip text add Bonjour à tous")
assert(r.status == "ok" and r.args[1] == "Bonjour" and r.short:match("Bonjour à tous$"), "les arguments ne sont jamais abrégés")
r = R("n s"); assert(r.status == "error" and r.problem:find("ambigu"), "n s est ambigu")
r = R("modify speed"); assert(r.status == "warn" and r.problem:find("argument"), "argument manquant")
r = R("ph f n g"); assert(r.status == "error" and r.problem:find("Sous%-commande"), "gossip exige un sous-mot")
r = R("zorglub 3"); assert(r.status == "warn" and r.short == "zorglub 3", "inconnue : envoyée telle quelle")
r = R("MOD SPEED 20"); assert(r.status == "ok", "insensible à la casse")
-- Feuilles documentées sans syntaxe ni description : exécutables
r = R(".wa sta"); assert(r.status == "ok" and r.full == "waypoints start", tostring(r.problem))
r = R("waypoints stop"); assert(r.status == "ok")
-- Aucun groupe « sous-commande attendue » sans sous-commande à proposer
local function NoEmptyGroup(level, path)
    for name, node in pairs(level) do
        assert(node.run or (node.sub and next(node.sub)), "groupe vide : " .. path .. name)
        if node.sub then NoEmptyGroup(node.sub, path .. name .. " ") end
    end
end
NoEmptyGroup(GM.CommandTree, "")
-- Plusieurs lignes, commentaires, variables
local lines = GM.MacroLines("# vitesse\nmod speed 2\n\n  mod scale 1  ")
assert(#lines == 2 and lines[2] == "mod scale 1")
target = nil
before = #sent
local okm, errm = GM:RunMacro("appear {cible}"); assert(not okm and errm:find("cible") and #sent == before)
target = "Ami"
assert(GM:RunMacro("appear {cible}")); assert(last() == S("appear") .. " Ami", last())
target = nil
before = #sent
assert(GM:RunMacro("mod speed 2\nmod scale 1.5")); assert(#sent == before + 2 and last() == S("modify scale 1.5"))
before = #sent
assert(not GM:RunMacro("mod speed 2\nn s 3") and #sent == before, "une ligne en erreur bloque toute la macro")

-- Chaque recette (et chaque option) produit des commandes conformes à la doc
local recipeChecks = 0
for _, recipe in ipairs(GM.SlotRecipes) do
    assert(#recipe.fields <= 1, "une saisie au plus par recette : " .. recipe.key)
    if not recipe.free then
        local field = recipe.fields[1]
        local samples = { {} }
        if field and field.kind == "pick" then
            assert(#field.options <= 12, "12 choix au plus : " .. recipe.key)
            samples = {}
            for _, o in ipairs(field.options) do samples[#samples + 1] = { [field.key] = o.value } end
        elseif field then
            samples = { { [field.key] = field.kind == "text" and "Hurlevent" or "301895" } }
        end
        for _, values in ipairs(samples) do
            local built, err = GM.BuildRecipe(recipe, values)
            assert(built, recipe.key .. " : " .. tostring(err))
            assert(#built.label <= 24 and built.label ~= "", recipe.key)
            local parts = { built.cmds }
            if built.second then parts[2] = built.second end
            if built.mode == "toggle" and not built.second then parts[2] = GM.ApplySwitchToken(built.cmds, false) end
            assert(built.mode ~= "alt" or built.second, recipe.key .. " : Alt sans commande")
            for _, text in ipairs(parts) do
                local report, worst = GM.CheckMacro(text)
                assert(worst == "ok", recipe.key .. " : " .. text .. " -> " .. tostring(report[1] and report[1].problem))
                recipeChecks = recipeChecks + 1
            end
        end
        -- Saisie manquante ou invalide : message clair, rien de construit
        if field and field.kind ~= "pick" and not field.default then
            local built, err = GM.BuildRecipe(recipe, {})
            assert(not built and err:find(field.label, 1, true), recipe.key)
        end
    end
end
assert(recipeChecks > 30)
-- Aura de PNJ : exactement la macro voulue (.n se aur / .n se una…)
local npcBuilt = GM.BuildRecipe(GM.RecipeByKey.npcaura, { id = "301895" })
assert(npcBuilt.mode == "alt" and npcBuilt.cmds == "npc set aura 301895" and npcBuilt.second == "npc set unaura 301895")
assert(R(npcBuilt.cmds).short == "n se aur 301895", R(npcBuilt.cmds).short)
assert(not GM.BuildRecipe(GM.RecipeByKey.npcaura, { id = "12a" }))

-- Chaque bouton du catalogue : commande ET nombre d'arguments conformes à la doc
-- (exception : la doc annonce #guid obligatoire pour .gobject delete, mais la
-- commande vise aussi l'objet sélectionné, comme le dit sa description).
local docExceptions = { ["gobject.delete"] = true }
local badArgs = {}
for _, domain in ipairs(GM.Domains) do
    local v = { id = "1", scale = "1", speed = "1", hp = "1", stand = "1", emote = "1", range = "5",
                text = "Bonjour", name = "Lieu", player = "Ami", who = "self",
                subname = "Garde", display = "1", aura = "1", option = "clickable", item = "1", slot = "0",
                race = "1", gender = "male", part = "hair", value = "2",
                block = "0", optnum = "1", page = "2", angle = "90",
                level = "10", health = "2", faction = "35", mount = "1", hover = "dynamic" }
    for _, action in ipairs(domain.actions) do
        for _, t in ipairs(type(action.cmd) == "table" and action.cmd or { action.cmd }) do
            local c = GM.Build(domain, t, v)
            local res = R(c)
            if res.status ~= "ok" and not docExceptions[domain.key .. "." .. action.key] then
                badArgs[#badArgs + 1] = domain.key .. "." .. action.key .. " (" .. t .. ") : " .. tostring(res.problem)
            end
        end
    end
end
assert(#badArgs == 0, "non conformes à la doc :  " .. table.concat(badArgs, "  |  "))
assert(D.cast.actionByKey.back.cmd == "cast back {id}", ".cast back : la cible lance sur vous")

-- ── Barre MJ ─────────────────────────────────────────────────────────────
local cfg = GM.EnsureBar()
assert(cfg.cols == 6 and cfg.rows == 2 and cfg.slots[2].cmds == "mod speed 20", "barre par défaut")
assert(GMMasterBar:IsShown(), "la barre s'affiche à l'activation")
local function Visible()
    local n = 0
    for _, b in ipairs(GM.barButtons) do if b:IsShown() then n = n + 1 end end
    return n
end
assert(Visible() == 12, "6 × 2 cases : " .. Visible())
-- Clic : exécute
GM.barButtons[3]:Click(); assert(last() == S("modify speed 50"), last())
assert(GM:RunSlot(1)); assert(last() == S("modify speed 1"))
-- Taille de la grille : bornée, cases masquées conservées
GM:SetBarOption("cols", 2); GM:SetBarOption("rows", 1)
assert(Visible() == 2 and cfg.slots[6], "réduction : 2 cases visibles, la 6e est gardée")
GM:SetBarOption("cols", 99); assert(GM.EnsureBar().cols == 24)
GM:SetBarOption("size", 2); assert(GM.EnsureBar().size == 24)
GM:SetBarOption("cols", 6); GM:SetBarOption("rows", 2); GM:SetBarOption("size", 40)
assert(Visible() == 12)
-- Échange de cases
GM:SwapSlots(1, 2); assert(cfg.slots[1].cmds == "mod speed 20" and cfg.slots[2].cmds == "mod speed 1"); GM:SwapSlots(1, 2)
-- Éditeur : une case vide s'ouvre sur une recette ; on ne tape que l'ID
local free = GM:FirstFreeSlot(); assert(free == 7, tostring(free))
GM.barButtons[free]:Click()
local ed = GM.macroEditor
assert(ed:IsShown() and ed.index == free and ed.recipe.key == "npcaura", "recette par défaut : Aura de PNJ")
assert(ed.fieldBox:IsShown() and ed.worst == "error", "ID à saisir")
ed.fieldBox:Type("1234")
assert(ed.worst == "ok" and ed.labelBox.text == "Flamme" and ed.iconBox.text == "1", "libellé et icône repris du sort")
assert(ed.report.text:find("Alt %+ clic") and ed.report.text:find(".n se aur 1234", 1, true), ed.report.text)
ed.saveBtn:Click()
local s7 = cfg.slots[free]
assert(not ed:IsShown() and s7.recipe == "npcaura" and s7.params.id == "1234" and s7.cmdsAlt == "npc set unaura 1234")
GM.barButtons[free]:Click(); assert(last() == S("npc set aura 1234"), last())
altDown = true; GM.barButtons[free]:Click(); altDown = false
assert(last() == S("npc set unaura 1234"), last())
-- Rouvrir : même recette, ID déjà rempli ; changer l'ID suffit
GM.barButtons[free]:Click("RightButton")
assert(ed.recipe.key == "npcaura" and ed.fieldBox.text == "1234")
ed.fieldBox:Type("301895"); assert(ed.labelBox.text == "Sort 301895", "libellé automatique suivi")
ed.labelBox:Type("Mon aura"); ed.fieldBox:Type("301896"); assert(ed.labelBox.text == "Mon aura", "libellé choisi conservé")
ed.saveBtn:Click(); assert(cfg.slots[free].label == "Mon aura" and cfg.slots[free].cmds == "npc set aura 301896")
-- Enregistrer + case suivante : même recette, seul l'ID à retaper
local nextFree = GM:FirstFreeSlot()
GM.barButtons[free]:Click("RightButton")
ed.saveNextBtn:Click()
assert(ed:IsShown() and ed.index == nextFree and ed.recipe.key == "npcaura" and ed.fieldBox.text == "")
ed.fieldBox:Type("555"); ed.saveBtn:Click()
assert(cfg.slots[nextFree].cmds == "npc set aura 555")
GM:SetSlot(nextFree, "", "", "")
-- Recette à choix : un clic, rien à taper
GM.barButtons[free]:Click("RightButton")
ed.navButtons.cheat:Click(); assert(ed.recipe.key == "cheat" and not ed.fieldBox:IsShown())
ed.pickButtons[1]:Click(); assert(ed.worst == "ok" and ed.labelBox.text == "Vol")
ed.saveBtn:Click(); assert(GM.SlotMode(cfg.slots[free]) == "toggle" and cfg.slots[free].cmds == "cheat fly [on/off]")
-- Une nouvelle case reprend la dernière recette utilisée
GM.barButtons[GM:FirstFreeSlot()]:Click(); assert(ed.recipe.key == "cheat"); ed:Hide()
-- Commande libre : vérification en direct
GM.barButtons[free]:Click("RightButton")
ed.navButtons.free:Click(); assert(ed.recipe.free)
ed.cmdBox:Type("n s 2"); assert(ed.worst == "error" and ed.report.text:find("ambigu"))
ed.cmdBox:Type(".ph f n scale 3"); assert(ed.worst == "ok" and ed.report.text:find("phase forge npc scale"), ed.report.text)
ed.labelBox:Type("Forgé x3")
ed.saveBtn:Click(); assert(not ed:IsShown() and cfg.slots[free].label == "Forgé x3" and not cfg.slots[free].recipe)
GM.barButtons[free]:Click(); assert(last() == S("phase forge npc scale 3"), last())
GM.barButtons[free]:Click("RightButton"); assert(ed.recipe.free and ed.cmdBox.text == ".ph f n scale 3")
-- Une case en erreur n'est pas enregistrée
ed.cmdBox:Type("n s 2"); ed.saveBtn:Click(); assert(ed:IsShown() and cfg.slots[free].cmds == ".ph f n scale 3")
ed.clearBtn:Click(); assert(cfg.slots[free] == nil)
-- Tester n'enregistre pas
GM.barButtons[free]:Click(); ed.navButtons.speed:Click(); ed.fieldBox:Type("7"); ed.testBtn:Click()
assert(last() == S("modify speed 7") and cfg.slots[free] == nil); ed:Hide()
-- Clic droit sur une action de la fenêtre : figée dans la barre
GM.SelectDomain("modify")
GM:GetValues(D.modify).speed = "12"
GM.pages.modify.actionButtons.speed:Click("RightButton")
assert(cfg.slots[free] and cfg.slots[free].cmds == S("modify speed 12"):sub(2), tostring(cfg.slots[free] and cfg.slots[free].cmds))
assert(cfg.slots[free].label == "Appliquer la vitesse 12", tostring(cfg.slots[free].label))
assert(GM.lastNotice and GM.lastNotice:find("case " .. free))
-- Barre pleine : une ligne de plus
for i = 1, 12 do if not cfg.slots[i] then GM:SetSlot(i, "x", "gps") end end
assert(GM:AddToBar("y", "gps") == 13 and cfg.rows == 3)
-- Raccourcis et commande /gmm
assert(BINDING_NAME_OMEGA_GMMASTER_SLOT12)
SlashCmdList.OMEGAGMMASTER("barre"); assert(not GMMasterBar:IsShown() and not cfg.shown)
SlashCmdList.OMEGAGMMASTER("barre"); assert(GMMasterBar:IsShown() and cfg.shown)
SlashCmdList.OMEGAGMMASTER("case 2"); assert(last() == S("modify speed 20"))
SlashCmdList.OMEGAGMMASTER("réglages"); assert(GMMasterBarSettings:IsShown())
-- ── Interrupteurs ────────────────────────────────────────────────────────
-- État serveur : la case « Vol » (cheat fly [on/off]) suit EpsilonLib.
local volIndex
for i, slot in pairs(cfg.slots) do if slot.cmds == "cheat fly [on/off]" then volIndex = i end end
assert(volIndex and GM.IsSwitch(cfg.slots[volIndex]), "Vol est un interrupteur par défaut")
cheats.fly = false
GM.barButtons[volIndex]:Click(); assert(last() == S("cheat fly on"), last())
EpsilonLib.Cheat.SetCheatStatus("fly", true)   -- réponse du serveur
assert(GM.barButtons[volIndex].badge.text:find("ON"), "badge ON après la réponse du serveur")
local on, source = GM:SwitchState(cfg.slots[volIndex]); assert(on and source == "server")
GM.barButtons[volIndex]:Click(); assert(last() == S("cheat fly off"), last())
EpsilonLib.Cheat.SetCheatStatus("fly", false)
assert(GM.barButtons[volIndex].badge.text:find("OFF"))
-- Déjà activé ailleurs (ex. .cheat fly on tapé à la main) : le clic désactive
cheats.fly = true
GM.barButtons[volIndex]:Click(); assert(last() == S("cheat fly off"))
cheats.fly = false
-- Mémoire : deux commandes distinctes, état retenu par personnage
local dm = GM:AddToBar("Mode MJ", "phase dm on", nil, { mode = "toggle", cmdsOff = "phase dm off" })
assert(GM.SlotMode(cfg.slots[dm]) == "toggle" and cfg.slots[dm].id)
GM:RunSlot(dm); assert(last() == S("phase dm on"))
GM:RunSlot(dm); assert(last() == S("phase dm off"))
GM:RunSlot(dm); assert(last() == S("phase dm on") and GMMasterCharDB.switches[cfg.slots[dm].id] == true)
-- Aura sur soi : état lu sur les auras du joueur
local sa = GM:AddToBar("Bouclier", "aura 1234 self", nil, { mode = "toggle", cmdsOff = "unaura 1234 self" })
playerAuras[1234] = nil
GM:RunSlot(sa); assert(last() == S("aura 1234 self"))
playerAuras[1234] = true
assert(select(2, GM:SwitchState(cfg.slots[sa])) == "aura")
GM:RunSlot(sa); assert(last() == S("unaura 1234 self"))
playerAuras[1234] = nil

-- ── Clic / Alt + clic (macro /run SendChatMessage(IsAltKeyDown() and ...)) ─
assert(R("n se aur 301895").status == "ok" and R("n se una 301895").status == "ok")
local ax = GM:AddToBar("Aura PNJ", "n se aur 301895", nil, { mode = "alt", cmdsAlt = "n se una 301895" })
assert(GM.SlotMode(cfg.slots[ax]) == "alt")
GM.barButtons[ax]:Click(); assert(last() == S("npc set aura 301895"), last())
altDown = true
GM.barButtons[ax]:Click(); assert(last() == S("npc set unaura 301895"), last())
altDown = false

-- ── Éditeur : type de case ───────────────────────────────────────────────
local fe = GM:FirstFreeSlot() or (function() GM:SetBarOption("rows", cfg.rows + 1); return GM:FirstFreeSlot() end)()
GM.barButtons[fe]:Click()
ed.navButtons.free:Click(); ed.cmdBox:Type(""); ed.mode = "simple"; ed.navButtons.free:Click()
assert(ed.mode == "simple" and not ed.secondArea:IsShown())
ed.modeBtn:Click(); assert(ed.mode == "toggle" and ed.secondArea:IsShown())
ed.cmdBox:Type("phase dm on"); assert(ed.worst == "error" and ed.report.text:find("Interrupteur"), "toggle sans désactivation")
ed.secondBox:Type("phase dm off"); assert(ed.worst == "ok", ed.report.text)
ed.modeBtn:Click(); assert(ed.mode == "alt")
ed.cmdBox:Type("cheat god [on/off]"); assert(ed.mode == "toggle", "[on/off] bascule en interrupteur")
ed.modeBtn:Click(); assert(ed.mode == "alt")
ed.cmdBox:Type("aura 99"); ed.secondBox:Type("unaura 99"); ed.labelBox:Type("A99")
ed.saveBtn:Click(); assert(cfg.slots[fe].cmdsAlt == "unaura 99" and not cfg.slots[fe].toggle)
GM.barButtons[fe]:Click("RightButton"); assert(ed.mode == "alt" and ed.secondBox.text == "unaura 99"); ed:Hide()

-- ── Banque d'auras ───────────────────────────────────────────────────────
assert(not GM:AddAura("abc") and not GM:AddAura("0"))
assert(GM:AddAura("301895", "npc"))
assert(not GM:AddAura("301895", "self"), "pas de doublon")
assert(GM:AddAura("1234", "self", "Flammes de test"))
local bankList = GM.EnsureAuraBank()
assert(bankList[1].id == 1234 and bankList[1].note == "Flammes de test" and bankList[2].who == "npc")
-- Commandes conformes à la doc pour les trois cibles
for _, who in ipairs({ "self", "target", "npc" }) do
    local onc, offc = GM.AuraCommands({ id = 5, who = who })
    assert(R(onc).status == "ok" and R(offc).status == "ok", who)
end
GM:ApplyAura(bankList[2], false); assert(last() == S("npc set aura 301895"))
GM:ApplyAura(bankList[2], true);  assert(last() == S("npc set unaura 301895"))
-- Vers la barre : PNJ = clic / Alt ; moi = interrupteur
local pi = GM:AuraToBar(bankList[2]); assert(cfg.slots[pi].cmdsAlt == "npc set unaura 301895" and cfg.slots[pi].cmds == "npc set aura 301895")
local si = GM:AuraToBar(bankList[1]); assert(GM.SlotMode(cfg.slots[si]) == "toggle" and cfg.slots[si].label == "Flammes de test" and cfg.slots[si].icon == "1")
-- Fenêtre
SlashCmdList.OMEGAGMMASTER("auras"); assert(GMMasterAuraBank:IsShown())
local bankUI = GMMasterAuraBank
assert(bankUI.rows[1]:IsShown() and bankUI.rows[1].entry.id == 1234 and not bankUI.rows[3]:IsShown())
bankUI.rows[2].apply:Click(); assert(last() == S("npc set aura 301895"))
bankUI.rows[2].who:Click(); assert(bankList[2].who == "self")
bankUI.idBox:Type("555"); bankUI.whoBtn:Click(); bankUI.addBtn:Click()
assert(bankList[1].id == 555 and bankList[1].who == "target" and bankUI.rows[1].entry.id == 555)
bankUI.rows[1].delete:Click(); assert(#bankList == 3, "premier clic : confirmation")
bankUI.rows[1].delete:Click(); assert(#bankList == 2 and bankList[1].id == 1234)
assert(GM.Utf8Cut("Vitesse éclair", 9) == "Vitesse ", "coupure UTF-8 sûre")

-- Banque MJ : recherche, essai immédiat, favoris et barre pour les autres actions.
assert(not GM:AddNpcAction("cast", "abc") and not GM:AddNpcAction("cast", "0"))
bankUI.tabs.cast:Click(); assert(bankUI.kind == "cast" and bankUI.previewColumn:IsShown())
bankUI.castListBtn:Click(); assert(last() == S("npc cast list"))
bankUI.idBox:Type("1234"); bankUI.testBtn:Click(); assert(last() == S("npc cast 1234"))
bankUI.noteBox:SetText("Flamme"); bankUI.lookupBtn:Click(); assert(last() == S("lookup spell Flamme"))
bankUI.addBtn:Click(); assert(GM.EnsureNpcActionBank("cast")[1].id == 1234)
bankUI.rows[1].remove:Click(); assert(last() == S("npc cast area 1234"))
local ci = GM:NpcActionToBar("cast", GM.EnsureNpcActionBank("cast")[1])
assert(cfg.slots[ci].cmds == "npc cast 1234" and cfg.slots[ci].cmdsAlt == "npc cast area 1234")
bankUI.tabs.emote:Click(); bankUI.idBox:Type("10"); bankUI.addBtn:Click()
bankUI.rows[1].apply:Click(); assert(last() == S("npc emote 10"))
bankUI.rows[1].remove:Click(); assert(last() == S("npc emote 10 repeat"))
bankUI.tabs.anim:Click(); bankUI.idBox:Type("145"); bankUI.testBtn:Click()
assert(last() == S("modify anim 145"))
bankUI.tabs.aura:Click(); assert(bankUI.previewColumn:IsShown() and #bankList == 2)
SlashCmdList.OMEGAGMMASTER("emotes"); assert(bankUI.kind == "emote")
SlashCmdList.OMEGAGMMASTER("auras"); assert(bankUI.kind == "aura" and bankUI:IsShown())

-- Onglets : jamais plus de 5 sections par domaine
for _, group in ipairs(GM.Groups) do assert(#group.sections <= 5, group.key) end

-- ── Aperçu des auras ─────────────────────────────────────────────────────
-- Données : sort → kits (Mot de pouvoir : Bouclier, sans visuel d'aura, dernière ligne, inconnu)
local pws = GM.AuraVisualKits(17)
assert(pws and pws.loop[1] == 43564 and #pws.once == 0 and #pws.impact == 2 and not pws.transform, "17")
assert(#GM.AuraVisualKits(7).loop == 0 and GM.AuraVisualKits(7).impact[1] == 142191, "7 : impact seul")
assert(GM.AuraVisualKits(392862) and GM.AuraVisualKits(118).transform, "dernière ligne, transformation")
assert(GM.AuraVisualKits(99999999) == nil and GM.AuraVisualKits("abc") == nil and GM.AuraVisualKits(1.5) == nil)
assert(GM.AuraVisualKits(17) == pws, "cache")
-- Fenêtre : le modèle reçoit les kits
local pv = bankUI.auraPreview
local applied, races, undressed = {}, {}, 0
pv.model.ApplySpellVisualKit = function(_, kit, once) applied[#applied + 1] = kit .. (once and "!" or "") end
pv.model.SetCustomRace = function(_, r, s) races[#races + 1] = r .. ":" .. s end
pv.model.Undress = function() undressed = undressed + 1 end
assert(GMMasterDB.auraPreview.race == 0, "mon personnage par défaut")
bankUI.idBox:Type("17"); assert(GM.PreviewedAura() == 17 and applied[#applied] == "43564", "saisie = aperçu")
assert(#races == 0, "mon personnage : pas de changement de race")
assert(pv.status.text:find("43564") and pv.status.text:find("En boucle"))
-- Race et sexe : rechargent le modèle et rejouent l'aura, réglages mémorisés
local n = #applied
pv.raceButtons[2]:Click(); assert(races[#races]:match("^1:") and #applied == n + 1 and undressed > 0, "Humain")
pv.femaleBtn:Click(); assert(races[#races] == "1:1" and GMMasterDB.auraPreview.sex == 1)
pv.dressBtn:Click(); local u = undressed; pv.replayBtn:Click(); assert(undressed == u, "habillé : pas de Undress")
pv.dressBtn:Click(); assert(not GMMasterDB.auraPreview.dressed)
for _, b in ipairs(pv.raceButtons) do assert(GM.PREVIEW_RACES[_].name and b.raceID ~= nil) end
assert(#GM.PREVIEW_RACES == 24, "23 races jouables + mon personnage")
-- Sans visuel d'aura : incantation / impact en ponctuel, avec une remarque
bankUI.idBox:Type("7"); assert(applied[#applied] == "142191!" and pv.status.text:find("Pas de visuel d'aura"))
GM:PreviewAura(118); assert(pv.status.text:find("transformation"))
n = #applied
GM:PreviewAura(99999999); assert(#applied == n and pv.status.text:find("Aucun visuel"))
-- Clic sur une ligne de la banque : aperçu + ligne surlignée
bankUI.rows[1].hover.scripts.OnMouseUp(bankUI.rows[1].hover, "LeftButton")
assert(GM.PreviewedAura() == 1234 and applied[#applied] == "17224")
-- Une saisie rapide ne joue que la dernière valeur
local timers = {}
C_Timer = { After = function(_, f) timers[#timers + 1] = f end }
bankUI.idBox:Type("6"); bankUI.idBox:Type("642")
for _, f in ipairs(timers) do f() end
assert(GM.PreviewedAura() == 642, "anti-rebond")
C_Timer = nil
-- Chargement du modèle après le filet de sécurité : rejoue une fois, pas plus
n = #applied
pv.model.scripts.OnModelLoaded(pv.model); pv.model.scripts.OnModelLoaded(pv.model)
assert(#applied == n + 1 and applied[#applied] == "23547", "chargement tardif")
-- Animation des kits, jouée à part : portage de caisse (AnimKit), remplacement de pose (aura 312)
local carry = GM.AuraVisualKits(178683)
assert(carry.animKit == 7832 and carry.animLoop and not carry.stand, "178683")
local newAnim = GM.AuraVisualKits(244874)
assert(newAnim.animKit == 13291 and newAnim.stand == 1208, "244874")
assert(not GM.AuraVisualKits(17).animKit and not GM.AuraVisualKits(17).stand, "17 : pas d'animation")
local anims = {}
pv.model.PlayAnimKit = function(_, kit, loop) anims[#anims + 1] = "kit" .. kit .. (loop and "" or "!") end
pv.model.SetAnimation = function(_, a) anims[#anims + 1] = "anim" .. a end
local sentBeforePreview = #sent
bankUI.tabs.emote:Click(); bankUI.idBox:Type("1")
assert(GM.EmoteAnimations[1] == 60 and anims[#anims] == "anim60" and pv.status.text:find("Émote 1"), "aperçu d'émote automatique")
local animCount = #anims
pv.model.scripts.OnAnimFinished(pv.model)
pv.model.scripts.OnAnimFinished(pv.model)
assert(#anims == animCount + 2 and anims[#anims] == "anim60", "l'émote se répète après chaque fin")
animCount = #anims
bankUI.idBox:Type("99999999")
assert(#anims == animCount and pv.status.text:find("Aucune animation"), "émote inconnue sans animation parasite")
bankUI.tabs.anim:Click(); bankUI.idBox:Type("145")
assert(anims[#anims] == "anim145" and pv.status.text:find("Animation 145"), "aperçu d'animation automatique")
animCount = #anims; pv.model.scripts.OnAnimFinished(pv.model)
assert(#anims == animCount, "la boucle d'émote cesse dans un autre onglet")
bankUI.tabs.cast:Click(); bankUI.idBox:Type("7")
assert(applied[#applied] == "142191!" and pv.status.text:find("incantation"), "aperçu de cast automatique")
assert(#sent == sentBeforePreview, "l'aperçu ne doit rien envoyer au serveur")
bankUI.tabs.aura:Click()
GM:PreviewAura(178683); assert(anims[#anims] == "kit7832" and applied[#applied] == "53659", "caisse : objet + bras")
GM:PreviewAura(244874); assert(anims[#anims - 1] == "anim1208" and anims[#anims] == "kit13291")
assert(pv.status.text:find("AnimKit 13291") and pv.status.text:find("pose 1208"))
n = #anims; GM:PreviewAura(17); assert(#anims == n, "aucune animation forcée")
-- Souris : clic droit = tourner, clic gauche = déplacer, Face = tout remettre
local cx, cy, facing, pos = 100, 100, nil, nil
GetCursorPosition = function() return cx, cy end
pv.model.SetFacing = function(_, f) facing = f end
pv.model.SetPosition = function(_, x, y, z) pos = { x, y, z } end
pv.model.GetEffectiveScale = function() return 1 end
local ms = pv.model.scripts
ms.OnMouseDown(pv.model, "RightButton"); cx = 180; ms.OnUpdate(pv.model)
assert(facing == 1 and (not pos or (pos[2] == 0 and pos[3] == 0)), "rotation seule")
ms.OnMouseUp(pv.model, "RightButton"); ms.OnUpdate(pv.model)
ms.OnMouseDown(pv.model, "LeftButton"); cx, cy = 280, 150; ms.OnUpdate(pv.model)
assert(facing == 1 and pos[2] > 0 and pos[3] > 0, "déplacement seul")
ms.OnMouseUp(pv.model, "LeftButton")
local moved = pos[2]; GM:PreviewAura(17); assert(pos[2] == moved, "position gardée au rechargement")
pv.resetBtn:Click(); assert(facing == 0 and pos[2] == 0 and pos[3] == 0, "Face")
GetCursorPosition = nil
-- Retour à mon personnage
pv.raceButtons[1]:Click(); n = #races; pv.replayBtn:Click(); assert(#races == n)

-- Désactivation
GM:Disable(); assert(not GMMasterAuraBank:IsShown())
assert(not GMMasterPanel:IsShown() and not GMMasterBar:IsShown() and SlashCmdList.OMEGAGMMASTER == nil)
print("OK: GM Master — " .. #sent .. " commandes envoyées, " .. #GM.Groups .. " domaines, " .. #GM.Domains .. " sections")
`;
const result = cp.spawnSync(process.execPath, [cli, '-'], { input: 'local ok,err=pcall(function()\n' + lua + '\nend)\nif not ok then print(err);os.exit(1) end', encoding: 'utf8' });
process.stdout.write(result.stdout || ''); process.stderr.write(result.stderr || ''); process.exit(result.status || 0);
