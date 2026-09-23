// Seuils de ressources : node Modules/Character/Tests/conditions-test.js <lanceur Lua>
const cp=require('child_process');
const code=String.raw`
local M={};M.__index=M
local frames={}
function CreateFrame(kind,name) local f=setmetatable({scripts={},shown=true,alpha=1},M);frames[#frames+1]=f;if name then _G[name]=f end;return f end
function M:SetScript(k,v) self.scripts[k]=v end
function M:CreateFontString() return setmetatable({scripts={}},M) end
function M:SetText(t) self.text=t end
function M:Show() self.shown=true end
function M:Hide() self.shown=false end
function M:IsShown() return self.shown end
function M:SetAlpha(a) self.alpha=a end
function M:RegisterEvent(e) self.event=e end
function M:UnregisterAllEvents() end
setmetatable(M,{__index=function() return function() end end})
UIParent=CreateFrame('Frame')
local sent={}
function SendChatMessage(msg,channel) sent[#sent+1]=msg end
local ch={hp={cur=10,max=10},mana={cur=5,max=5},endurance={cur=5,max=5}}
Character={enabled=true}
local C=Character
function C:GetMyChar() return ch end
dofile('Modules/Character/Conditions.lua')
local notices={}
function C:ShowNotice(t,d,sticky) assert(sticky==true,'état : message persistant');notices[#notices+1]={t,d} end
local login;for _,f in ipairs(frames) do if f.event=='PLAYER_LOGIN' then login=f end end
local function set(stat,v) ch[stat].cur=v;C.OnMyDataChanged() end
local function last() return sent[#sent] end
-- Déjà à 0 Mana à la connexion : état suivi, rien d'envoyé ni d'affiché.
ch.mana.cur=0;login.scripts.OnEvent(login);set('hp',10);assert(#notices==0 and #sent==0,'rien au chargement')
set('mana',3);assert(last()=='.unaura 282999 self','sortie de l état suivi depuis la connexion')
sent={}
-- PV à 1 : danger + animation 244807.
set('hp',1);assert(#notices==1 and notices[1][1]:find('|cff5ee06adanger',1,true) and notices[1][2]=='Vos PV sont bas.')
assert(#sent==1 and last()=='.aura 244807 self','animation posée (explication pas encore définie)')
-- PV à 0 : K.O., auras inchangées ; remonter au-dessus de 1 retire tout.
local n=#notices;set('hp',0);assert(#sent==2 and last()=='.aura 308480 self' and notices[#notices][1]=='Vous êtes K.O.' and notices[#notices][2]=="Attendez qu'un allié vous porte secours.")
-- Soigné de 0 à 1 : K.O. retiré, danger gardé, pas de nouveau message.
n=#notices;set('hp',1);assert(#sent==3 and last()=='.unaura 308480 self' and #notices==n)
set('hp',0);set('hp',4);assert(#sent==6 and sent[5]=='.unaura 308480 self' and sent[6]=='.unaura 244807 self',table.concat(sent,' / '))
set('hp',6);assert(#sent==6,'déjà sorti : rien')
sent={}
-- L'explication, une fois définie, est commune aux trois états.
C.WEAKENED_AURAS.explanation=999
-- Mana et Endurance à 0 : deux annonces ; 282999 (mana), 244807 (endurance), 999 une seule fois.
n=#notices;ch.mana.cur=0;ch.endurance.cur=0;C.OnMyDataChanged()
assert(#notices==n+2 and notices[n+1][1]:find('|cff4aa8fffaible',1,true) and notices[n+2][1]:find('|cffff3b3bfaible',1,true))
assert(notices[n+1][2]=='Votre maîtrise vacille, la source est tarie.' and notices[n+2][2]=='Le souffle vous manque, vos forces vous abandonnent.')
assert(#sent==3 and sent[1]=='.aura 282999 self' and sent[2]=='.aura 999 self' and sent[3]=='.aura 250429 self',table.concat(sent,' / '))
-- Sortir du mana : seule son aura part ; l'explication reste (endurance).
set('mana',2);assert(#sent==4 and last()=='.unaura 282999 self')
-- PV à 1 pendant l'endurance à 0 : chacun son aura.
set('hp',1);assert(#sent==5 and last()=='.aura 244807 self')
set('endurance',1);assert(#sent==6 and last()=='.unaura 250429 self','l explication reste pour PV à 1')
set('hp',3);assert(#sent==8 and sent[7]=='.unaura 244807 self' and sent[8]=='.unaura 999 self',table.concat(sent,' / '))
-- Character désactivé : rien.
C.enabled=false;local count,nn=#sent,#notices;set('mana',0);set('mana',5);assert(#sent==count and #notices==nn)
print('OK: seuils PV/Mana/Endurance, textes, statut affaibli (animation par état, explication commune, posées/retirées au besoin), K.O. 308480, connexion, désactivation')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});
process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status);
