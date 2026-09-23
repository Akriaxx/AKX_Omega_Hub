const fs=require('fs'),cp=require('child_process');
let basic=fs.readFileSync('Modules/ZoneGate/Tests/Studio_test.lua','utf8');basic=basic.slice(basic.indexOf('unpack='),basic.indexOf('ZoneGate={'));
let views=fs.readFileSync('Modules/Character/Tests/views-test.js','utf8');let extra=views.slice(views.indexOf('const code=mock+`')+17,views.indexOf("dofile('Modules/Character/UI_Group.lua')"));
const code=basic+extra+`
function M:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
function M:SetToplevel() end
function M:SetShadowColor() end
function M:SetShadowOffset() end
function M:SetScale(v) self.scale=v end
function M:GetScale() return self.scale or 1 end
function M:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent.GetEffectiveScale and self.parent:GetEffectiveScale() or 1) end
function M:GetCenter() return 100,100 end
function hooksecurefunc(t,k,f) local old=t[k];t[k]=function(...) local r=old(...);f(...);return r end end
function M:SetHyperlinksEnabled(v) self.hyperlinks=v end
function M:SetFrameStrata(v) self.strata=v end
function M:SetFrameLevel(v) self.level=v end
function M:GetFrameLevel() return self.level or 1 end
function M:IsMouseOver() return false end
function M:GetRight() return 100 end
function M:SetSpacing() end
function M:SetWordWrap() end
function M:AddLine(t) self.lines=self.lines or {};self.lines[#self.lines+1]=t end
function M:SetOwner() self.lines={} end
function M:SetFocus() end
function M:SetFontString(fs) self.fontString=fs;self.text=fs.text end
function M:GetPoint() return 'CENTER',UIParent,'CENTER',0,0 end
function M:StartMoving() end
function M:StopMovingOrSizing() end
function GetRealmName() return 'Realm' end
function UnitFullName(unit) return unit=='player' and 'Tester' or unit,'Realm' end
local now=0;function GetTime() return now end
local timers={};C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
local sent={};C_ChatInfo={RegisterAddonMessagePrefix=function() end,SendAddonMessage=function(...) sent[#sent+1]={...} end}
function GetMacroIcons() return 'IconA',134400 end
CharacterResourceHUD=obj('Frame')
local settings={groupScale=1,windowOpacity=.9,initiativeScale=1,mjScale=1};function C:GetSettings() return settings end
C.enabled=true
CharacterDB.skills={['Tester-Realm']={offensive={Legacy={name='Legacy',icon='134400',description='Old text'}},defensive={},ranged={},base={}}}
-- Police factice : 6 px par caractère × taille/12, pour tester la mise en page.
function M:SetFont(path,size) self.fontPath=path;self.fontSize=size;return true end
function M:GetStringWidth() local t=tostring(self.text or ''):gsub('|H.-|h',''):gsub('|h','');return #t*6*((self.fontSize or 12)/12) end
M.GetUnboundedStringWidth=M.GetStringWidth
function M:SetDrawLayer(l) self.layer=l end
dofile('Modules/Character/RichText.lua')
dofile('Modules/Character/UI_Skills.lua')
dofile('Modules/Character/Skills_Sync.lua')
dofile('Modules/Character/UI_Action.lua')
assert(C:GetSkill('offensive','Legacy').description=='Old text')
assert(C:SaveSkill('offensive',nil,'Slash','134400','a:b|c\\n{{rouge}}hit{{/}}'))
assert(not C:SaveSkill('offensive',nil,'Slash','','overwrite'))
local payload=C.SkillLibraryCodec.Encode(C:GetOwnedSkillLibrary())
local decoded=C.SkillLibraryCodec.Decode(payload)
assert(decoded.offensive.Slash.description=='a:b|c\\n{{rouge}}hit{{/}}')
assert(not C.SkillLibraryCodec.Decode(payload..'garbage'))
assert(not C.SkillLibraryCodec.Decode('999999:x'))
C:ToggleSkillsBuilder();assert(CharacterSkillsBuilder:IsShown())
C:OpenSkillInBuilder('offensive','Slash')
assert(C:SaveSkill('base',nil,'Action de Déplacement','',''));assert(C:SaveSkill('base',nil,'Esquive','',''))
local desc
for _,o in ipairs(objects) do if o.kind=='EditBox' and o.scripts.OnTabPressed then desc=o end end
assert(desc);desc.cursor=0
function desc:HasFocus() return true end
function desc:GetCursorPosition() return self.cursor end
function desc:SetCursorPosition(n) self.cursor=n;self.scripts.OnCursorChanged(self,0,-self.cursor,0,14) end
function desc:IsMouseOver() return false end
local function typeText(t) desc.text=t;desc.cursor=#t;desc.scripts.OnTextChanged(desc) end
typeText('Voir {{Act');desc.scripts.OnTabPressed(desc)
assert(desc.text=='Voir {{Action : ',desc.text)
typeText('Voir {{action:dépl');desc.scripts.OnTabPressed(desc)
assert(desc.text=='Voir {{Action : Action de Déplacement}}',desc.text)
assert(desc.cursor==#desc.text)
typeText('{{Action : ');desc.scripts.OnEscapePressed(desc);typeText('{{Action : E');desc.scripts.OnTabPressed(desc)
assert(desc.text=='{{Action : E','Echap garde la liste fermée pour cette référence')
assert(C:SaveSkill('base',nil,'[[#ff8800]]Charge[[/]]','',''))
assert(C:RenderSkillName('[[#ff8800]]Charge[[/]] !')=='|cffff8800Charge|r !')
assert(C:RenderSkillText('[[#00FF00]]ok[[/]] {{vert}}v{{/}}')=='|cff00FF00ok|r |cff3ce26bv|r')
assert(C:RenderSkillText('[[#zz]]x[[/]]')=='[[#zz]]x[[/]]')
-- Index : consultable par référence, synchronisé, mais absent du triangle.
assert(C:SaveSkill('index',nil,'Garde','','Posture'))
assert(C:RenderSkillText('{{Index : Garde}}')=='|Hcharskill:index:Garde|h|cff8fd6ff[Garde]|r|h')
assert(C:SaveSkill('index',nil,'[[#ac8b74]]Arme à distance[[/]]','',''))
assert(C:RenderSkillText('{{Index : Arme à distance}}')=='|Hcharskill:index:Arme à distance|h|cffac8b74[|r|cffac8b74Arme à distance|r|cffac8b74]|r|h','lien à la couleur du nom')
do local out=C:RenderSkillText('{{Index : Arme à distance}} suite');local _,opens=out:gsub('|c','');local _,closes=out:gsub('|r','');assert(opens==closes,'couleurs équilibrées') end
assert(C.SkillLibraryCodec.Decode(C.SkillLibraryCodec.Encode(C:GetOwnedSkillLibrary())).index.Garde.description=='Posture')
local triangle=0;for _,o in ipairs(objects) do if o.cat and o.back then triangle=triangle+1;assert(o.cat.key~='index','pas de bouton Index dans le triangle') end end;assert(triangle==4,triangle)
typeText('');typeText('{{Action : char');desc.scripts.OnTabPressed(desc)
assert(desc.text=='{{Action : Charge}}',desc.text)
assert(C:FindSkillRef('base','charge').name=='[[#ff8800]]Charge[[/]]')
assert(C:RenderSkillText(desc.text)=='|Hcharskill:base:Charge|h|cffff8800[|r|cffff8800Charge|r|cffff8800]|r|h')
C:ShowSkillTooltip(UIParent,{name='Source',description='Voir {{Action : Charge}}'})
local card1=CharacterSkillCard1
assert(card1:IsShown() and card1.hyperlinks and card1.strata=='TOOLTIP')
card1.scripts.OnHyperlinkEnter(card1,'charskill:base:Charge')
local card2=CharacterSkillCard2
assert(card2:IsShown() and card2.title.text=='|cffff8800Charge|r',card2.title.text)
assert(card2.level>card1.level and card2.point[2]==card1,'la référence s’ouvre à côté, au-dessus')
card1.scripts.OnHyperlinkLeave(card1);for _,fn in ipairs(timers) do fn() end
assert(not card2:IsShown())
card1.scripts.OnHyperlinkEnter(card1,'charskill:base:Inconnue');assert(card2.title.text=='Inconnue')
C:HideSkillTooltip();assert(not card1:IsShown() and not card2:IsShown())
ColorPickerFrame=obj('Frame');ColorPickerFrame:Hide();ColorPickerFrame.strata='DIALOG'
function ColorPickerFrame:GetFrameStrata() return self.strata end
function ColorPickerFrame:Raise() end
function ColorPickerFrame:SetupColorPickerAndShow(info) self.info=info;self:Show() end
function ColorPickerFrame:GetColorRGB() return 1,.5,0 end
function desc:HighlightText(a,b) self.highlight={a,b} end
local function typeUser(t) desc.text=t;desc.cursor=#t;desc.scripts.OnTextChanged(desc,true) end
function desc:Insert(v) local a,b=self.sel and self.sel[1] or self.cursor,self.sel and self.sel[2] or self.cursor;self.text=self.text:sub(1,a)..v..self.text:sub(b+1);self.cursor=a+#v;self.sel=nil end
local function tool(key) for _,o in ipairs(objects) do if o.kind=='Button' and o.toolKey==key then return o end end end
local function click(key) local b=tool(key);assert(b,key);b.scripts.OnClick(b) end
typeUser('Un coup [[');assert(not ColorPickerFrame:IsShown(),'taper [[ n ouvre plus le sélecteur')
typeText('Un coup');desc.cursor=7;click('couleur');assert(ColorPickerFrame:IsShown() and ColorPickerFrame.strata=='FULLSCREEN_DIALOG')
ColorPickerFrame:Hide()
assert(desc.text=='Un coup[[#ff8000]]TEXTE[[/]]',desc.text)
assert(desc.highlight[1]==#'Un coup[[#ff8000]]' and desc.highlight[2]==#'Un coup[[#ff8000]]TEXTE')
assert(ColorPickerFrame.strata=='DIALOG','strate du sélecteur restaurée')
typeText('x');desc.cursor=1;click('couleur');ColorPickerFrame.info.cancelFunc();ColorPickerFrame:Hide()
assert(desc.text=='x','annuler garde le texte')
ColorPickerFrame.SetupColorPickerAndShow=nil
function ColorPickerFrame:SetColorRGB(r,g,b) self.rgb={r,g,b} end
function ShowUIPanel(f) f:Show() end
typeText('9.2.7');desc.sel={0,5};click('couleur');assert(ColorPickerFrame:IsShown() and ColorPickerFrame.rgb[1]==1)
ColorPickerFrame:Hide();assert(desc.text=='[[#ff8000]]9.2.7[[/]]',desc.text)
typeText('y');desc.cursor=1;click('couleur');ColorPickerFrame.cancelFunc(ColorPickerFrame.previousValues);ColorPickerFrame:Hide()
assert(desc.text=='y')
-- Barre d'outils : la sélection se lit via Insert("") comme dans le jeu.
local function pick() ColorPickerFrame:Hide() end
typeText('les [ DM ] infligés');desc.sel={4,10}
click('couleur');assert(ColorPickerFrame:IsShown() and desc.text=='les [ DM ] infligés','texte restauré avant la couleur')
pick();assert(desc.text=='les [[#ff8000]][ DM ][[/]] infligés',desc.text)
assert(desc.highlight[1]==15 and desc.highlight[2]==21,'sélection conservée')
desc.sel={15,21};click('couleur');pick();assert(desc.text=='les [[#ff8000]][ DM ][[/]] infligés','recolorer remplace la balise')
desc.sel={15,21};click('effacer');assert(desc.text=='les [ DM ] infligés',desc.text)
typeText('a [[#112233]]b[[/]] c');desc.sel={0,#desc.text}
click('couleur');pick();assert(desc.text=='[[#ff8000]]a b c[[/]]','couleurs internes remplacées')
typeText('ab');desc.cursor=1;click('couleur');pick();assert(desc.text=='a[[#ff8000]]TEXTE[[/]]b',desc.text)
typeText('xy');desc.sel={0,1};click('couleur');typeText('changé');pick();assert(desc.text=='changé','texte modifié entre-temps : rien')
-- Gras / italique / souligné / barré : bascule.
typeText('un mot ici');desc.sel={3,6};click('b');assert(desc.text=='un [[b]]mot[[/b]] ici',desc.text)
desc.sel={8,11};click('b');assert(desc.text=='un mot ici','gras retiré')
desc.sel={3,6};click('i');desc.sel={3,17};click('i');assert(desc.text=='un mot ici','balises sélectionnées retirées')
desc.sel={3,6};click('u');desc.sel={8,11};click('s');assert(desc.text=='un [[u]][[s]]mot[[/s]][[/u]] ici',desc.text)
-- Taille, surlignage, police.
typeText('grand');desc.sel={0,5};click('taillePlus');desc.sel={13,18};click('taillePlus')
assert(desc.text=='[[taille 14]]grand[[/taille]]',desc.text)
desc.sel={13,18};click('tailleMoins');desc.sel={13,18};click('tailleMoins');assert(desc.text=='grand','taille par défaut : plus de balise')
desc.sel={0,5};click('fond');pick();assert(desc.text:match('^%[%[fond #ff8000%]%]grand%[%[/fond%]%]$'),desc.text)
typeText('titre');desc.sel={0,5};click('police')
local cinzel;for _,o in ipairs(objects) do if o.kind=='FontString' and o.text=='Cinzel' and o.parent and o.parent.kind=='Button' and not o.parent.toolKey then cinzel=o.parent end end
assert(cinzel);cinzel.scripts.OnClick(cinzel);assert(desc.text=='[[police cinzel]]titre[[/police]]',desc.text)
-- Alignement par ligne.
typeText('a\\nb\\nc');desc.sel={2,3};click('centre');assert(desc.text=='a\\n[[centre]]b\\nc',desc.text)
desc.sel={0,#desc.text};click('droite');assert(desc.text=='[[droite]]a\\n[[droite]]b\\n[[droite]]c',desc.text)
desc.sel={0,#desc.text};click('gauche');assert(desc.text=='a\\nb\\nc',desc.text)
-- Référence : insère {{ et ouvre la liste.
typeText('voir ');desc.cursor=5;click('lien');assert(desc.text=='voir {{',desc.text)
-- Moteur de texte enrichi.
local RT=C.RichText
local paras=RT.Parse('a [[b]]gras[[/b]] [[i]][[u]]x[[/u]][[/i]]\\n[[centre]][[taille 20]]T[[/taille]]',C:SkillTextOptions())
assert(#paras==2 and paras[2].align=='CENTER' and paras[2].runs[1].style.size==20)
assert(paras[1].runs[2].text=='gras' and paras[1].runs[2].style.bold and not paras[1].runs[1].style.bold)
assert(paras[1].runs[4].style.italic and paras[1].runs[4].style.underline)
assert(RT.Strip('[[b]]x[[/b]] [[#ff0000]]y[[/]] [[inconnu]]')=='x y [[inconnu]]')
local refRuns=RT.Parse('{{Index : Arme à distance}}',C:SkillTextOptions())[1].runs
assert(refRuns[1].text=='[' and math.abs(refRuns[1].style.color[1]-0xac/255)<1e-6 and refRuns[3].text==']' and refRuns[3].style.color==refRuns[1].style.color,'crochets à la couleur du nom')
assert(refRuns[2].text=='Arme à distance' and math.abs(refRuns[2].style.color[1]-0xac/255)<1e-6 and refRuns[2].style.link.catKey=='index')
local plainRef=RT.Parse('{{Action : Esquive}}',C:SkillTextOptions())[1].runs
assert(plainRef[1].style.color==RT.LINK_COLOR and plainRef[2].style.color==RT.LINK_COLOR,'lien sans couleur : bleu')
local box=CreateFrame('Frame');local w,h=RT.Render(box,'un deux trois quatre',60,{})
assert(w<=60 and h>=3*17,'retour à la ligne');assert(box.richText.usedStrings==3,box.richText.usedStrings)
RT.Render(box,'[[b]][[police friz]]gras[[/police]][[/b]] [[u]]sous[[/u]] [[fond #000000]]f[[/fond]]',300,{})
assert(box.richText.usedStrings==4,'faux gras doublé');assert(box.richText.usedTextures==2)
RT.Render(box,'{{Action : Esquive}}',300,C:SkillTextOptions());assert(box.richText.strings[1].text:find('^|Hcharskill:base:Esquive|h'),box.richText.strings[1].text)
RT.Render(box,'motextremementlongsansespace',40,{});assert(box.richText.usedStrings>=2,'mot trop long découpé')
C:ShowSkillName(UIParent,{name='[[#ff8800]]Charge[[/]]'});assert(CharacterSkillNameTip:IsShown());C:HideSkillName()
typeText('{{rouge}}x{{/}} {{Défensive:');desc.scripts.OnTabPressed(desc)
assert(desc.text=='{{rouge}}x{{/}} {{Défensive:','catégorie vide : rien à insérer')
C:ToggleActionButton();local root=CharacterActionMenu;assert(root:IsShown())
local idle
for _,o in ipairs(objects) do if o.parent==root and o.scripts.OnDragStart then idle=o end end
assert(idle)
CharacterResourceHUD:SetScale(.85)
assert(math.abs(root:GetEffectiveScale()-1)<1e-9,'le bouton Action ignore l’échelle du portrait')
C:SetActionScale(1.3);assert(math.abs(root:GetEffectiveScale()-1.3)<1e-9)
C:SetActionScale(1)
local cursor={500,400};function GetCursorPosition() return cursor[1],cursor[2] end
function root:GetEffectiveScale() return .85 end
function root:GetCenter() return 600/.85,400/.85 end
idle.scripts.OnMouseDown(idle)
cursor={560,340};idle.scripts.OnDragStart(idle)
assert(math.abs(root.point[4]-(660/.85))<1e-6,'geste rapide : pas de décalage au départ')
cursor={585,315};idle.scripts.OnUpdate(idle)
assert(root.point[1]=='CENTER' and root.point[3]=='BOTTOMLEFT')
assert(math.abs(root.point[4]-(685/.85))<1e-6 and math.abs(root.point[5]-(315/.85))<1e-6,'le bouton suit le curseur à l’échelle')
idle.scripts.OnDragStop(idle);assert(not idle.scripts.OnUpdate and not root.dragging)
idle.scripts.OnMouseDown(idle)
idle.scripts.OnClick();assert(root.scripts.OnUpdate)
root.scripts.OnUpdate(root,.4);assert(not root.scripts.OnUpdate)
local category
for _,o in ipairs(objects) do if o.cat and o.cat.key=='offensive' and o.parent==root then category=o end end
category.scripts.OnClick(category,'RightButton');assert(root.scripts.OnUpdate and not idle:IsShown(),'fermeture animée')
root.scripts.OnUpdate(root,.17);assert(category:IsShown() and category.alpha>0 and category.alpha<1)
root.scripts.OnUpdate(root,.2);assert(not root.scripts.OnUpdate and idle:IsShown() and not category:IsShown())
idle.scripts.OnClick();root.scripts.OnUpdate(root,.4)
category.scripts.OnClick(category,'LeftButton');root.scripts.OnUpdate(root,.6);assert(not root.scripts.OnUpdate)
C:ToggleActionButton();assert(not root:IsShown() and not root.scripts.OnUpdate)
assert(not CharacterDB.actionButtonShown['Tester-Realm'])
C:ToggleActionButton();assert(CharacterDB.actionButtonShown['Tester-Realm'])
CharacterResourceHUD.scripts.OnHide(CharacterResourceHUD);assert(not root:IsShown())
CharacterResourceHUD.scripts.OnShow(CharacterResourceHUD);assert(root:IsShown(),'revient après /reload')
C:ToggleActionButton();assert(not root:IsShown())
local network
for _,o in ipairs(objects) do if o.events and o.events.CHAT_MSG_ADDON and o.scripts.OnUpdate then network=o end end
assert(network)
local function receive(msg,sender,channel) network.scripts.OnEvent(network,'CHAT_MSG_ADDON','OmegaSkills2',msg,channel or 'WHISPER',sender or 'raid1-Realm') end
local n=math.ceil(#payload/200)
receive('H|1-1|1|'..n)
for i=n,1,-1 do receive('D|1-1|'..i..'|'..payload:sub((i-1)*200+1,i*200)) end
assert(CharacterDB.skillLibraries['raid1-Realm'].categories.offensive.Slash)
local empty=C.SkillLibraryCodec.Encode({})
receive('H|2-1|2|1','outsider-Realm');receive('D|2-1|1|'..empty,'outsider-Realm')
assert(not CharacterDB.skillLibraries['outsider-Realm'])
receive('H|2-1|2|1');receive('D|2-1|1|'..empty)
assert(not next(CharacterDB.skillLibraries['raid1-Realm'].categories.offensive))
receive('H|1-1|1|'..n)
for i=1,n do receive('D|1-1|'..i..'|'..payload:sub((i-1)*200+1,i*200)) end
assert(CharacterDB.skillLibraries['raid1-Realm'].revision==2)
for _,o in ipairs(objects) do if o.kind=='Button' and type(o.text)=='string' and o.text:find('la mienne',1,true) then o.scripts.OnClick() end end
assert(C:IsSkillLibraryReadOnly())
assert(not C:SaveSkill('offensive',nil,'Bad','',''))
assert(not C:DeleteSkill('offensive','Legacy'))
assert(not C:SendSkillLibrary())
-- Sending requires addon discovery; snapshots are never sent to silent peers.
for _,o in ipairs(objects) do if o.kind=='Button' and type(o.text)=='string' and o.text:find('(lecture seule)',1,true) then o.scripts.OnClick() end end
assert(not C:IsSkillLibraryReadOnly())
C:StopSkillTransfers();sent={}
local ok=C:SendSkillLibrary();assert(ok)
for i=1,12 do network.scripts.OnUpdate(network,.1) end
assert(#sent==12 and sent[1][2]:sub(1,2)=='H|' and sent[1][3]=='WHISPER')
local id=sent[1][2]:match('^H|([^|]+)')
receive('Y|'..id)
local before=#sent
for i=1,math.ceil(#C.SkillLibraryCodec.Encode(C:GetOwnedSkillLibrary())/200) do network.scripts.OnUpdate(network,.1) end
assert(#sent>before)
for i=before+1,#sent do assert(sent[i][4]=='raid1-Realm' and #sent[i][2]<=255) end
receive('A|'..id)
for _,fn in ipairs(timers) do fn() end
network.scripts.OnUpdate(network,.1)
assert(C:SendSkillLibrary())
C:StopSkillTransfers()
print('OK: legacy skills, collision guard, codec, builder, animation lifecycle, imports, full replacement, raid checks, stale revision, read-only ownership')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});if(r.stderr) {const m=r.stderr.match(/stdin:(\d+)/);if(m){const n=Number(m[1]);process.stdout.write(code.split('\n').slice(n-3,n+2).join('\n')+'\n');}}process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||((r.stderr||'').includes('stack traceback')?1:0));

