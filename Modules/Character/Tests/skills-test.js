const fs=require('fs'),cp=require('child_process');
let basic=fs.readFileSync('Modules/ZoneGate/Tests/Studio_test.lua','utf8');basic=basic.slice(basic.indexOf('unpack='),basic.indexOf('ZoneGate={'));
let views=fs.readFileSync('Modules/Character/Tests/views-test.js','utf8');let extra=views.slice(views.indexOf('const code=mock+`')+17,views.indexOf("dofile('Modules/Character/UI_Group.lua')"));
const code=basic+extra+`
function M:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
function M:GetAlpha() return self.alpha or 1 end
function M:SetToplevel() end
function M:SetMaxBytes() end
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
function GetCursorPosition() return 0,0 end
local shift=false;function IsShiftKeyDown() return shift end
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
local REGION={Texture=true,FontString=true,MaskTexture=true}
local NOT_CHILD={Animation=true,AnimationGroup=true}
function M:GetChildren() local t={};for _,o in ipairs(objects) do if o.parent==self and not REGION[o.kind] and not NOT_CHILD[o.kind] then t[#t+1]=o end end;return unpack(t) end
function M:GetRegions() local t={};for _,o in ipairs(objects) do if o.parent==self and REGION[o.kind] then t[#t+1]=o end end;return unpack(t) end
function M:SetParent(p) self.parent=p end
function M:GetTop() return nil end
function M:GetLeft() return nil end
function M:CreateLine() local l=obj('Line',nil,self);return l end
function M:SetStartPoint(...) self.startPoint={...} end
function M:SetEndPoint(...) self.endPoint={...} end
function M:SetThickness(t) self.thickness=t end
function M:IsVisible() local f=self;while f do if f.shown==false then return false end;f=f.parent end;return true end
function M:SetDegrees(d) self.degrees=d end
function M:SetLooping(l) self.looping=l end
function M:SetFromAlpha(a) self.fromAlpha=a end
function M:SetToAlpha(a) self.toAlpha=a end
function M:SetRotation(r) self.rotation=r end
function M:SetBlendMode(m) self.blend=m end
function M:SetTexture(t) self.texture=t end
function M:GetBottom() return nil end
dofile('Modules/Character/RichText.lua')
dofile('Modules/Character/UI_Skills.lua')
dofile('Modules/Character/Skills_Sync.lua')
dofile('Modules/Character/UI_Action.lua')
dofile('Modules/Character/UI_ActionFX.lua')
assert(C:GetSkill('offensive','Legacy').description=='Old text')
assert(C:SaveSkill('offensive',nil,'Slash','134400','a:b|c\\n{{rouge}}hit{{/}}'))
assert(not C:SaveSkill('offensive',nil,'Slash','','overwrite'))
local payload=C.SkillLibraryCodec.Encode(C:GetOwnedSkillLibrary())
local decoded=C.SkillLibraryCodec.Decode(payload)
assert(decoded.offensive.Slash.description=='a:b|c\\n{{rouge}}hit{{/}}')
assert(not C.SkillLibraryCodec.Decode(payload..'garbage'))
assert(not C.SkillLibraryCodec.Decode('999999:x'))
C:ToggleSkillsBuilder();assert(CharacterSkillsBuilder:IsShown())
local form=CharacterSkillsBuilder.form;assert(not form:IsShown(),'formulaire caché hors édition')
for _,o in ipairs(objects) do if o.kind=='Button' and o.text=='+ Nouvelle' then o.scripts.OnClick(o) end end
assert(form:IsShown(),'visible pour une création')
for _,o in ipairs(objects) do if o.kind=='Button' and o.cat and o.cat.key=='defensive' and not o.back then o.scripts.OnClick(o) end end
assert(not form:IsShown(),'caché au changement d onglet')
C:OpenSkillInBuilder('offensive','Slash');assert(form:IsShown(),'visible pour une modification')
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
local triangle=0;for _,o in ipairs(objects) do if o.cat and o.back then triangle=triangle+1;assert(o.cat.key~='index','pas de bouton Index dans le triangle') end end;assert(triangle==5,triangle)
typeText('');typeText('{{Action : char');desc.scripts.OnTabPressed(desc)
assert(desc.text=='{{Action : Charge}}',desc.text)
assert(C:FindSkillRef('base','charge').name=='[[#ff8800]]Charge[[/]]')
assert(C:RenderSkillText(desc.text)=='|Hcharskill:base:Charge|h|cffff8800[|r|cffff8800Charge|r|cffff8800]|r|h')
C:ShowSkillTooltip(UIParent,{name='Source',description='Voir {{Action : Charge}}'})
local card1=CharacterSkillCard1;local links1=card1.content
assert(card1:IsShown() and links1.hyperlinks and card1.strata=='TOOLTIP')
-- Ouverture du bas vers le haut : la hauteur part de 1, le contenu est à sa taille finale.
local fullH=links1.h;assert(card1.h==1 and card1.w==links1.w and fullH>1,'carte fermée au départ')
-- Cadre en 9 parts (mêmes matériaux que le cadre de ressources) + losange sous la carte.
local parts,gem={},nil;for _,o in ipairs(objects) do if o.parent==card1 and o.kind=='Texture' then local t=tostring(o.texture);if t:find('SkillCard$') then parts[#parts+1]=o elseif t:find('SkillCardGem$') then gem=o end end end
assert(#parts==9 and gem and gem.point[1]=='CENTER' and gem.point[3]=='BOTTOM','cadre 9 parts + losange')
card1.scripts.OnUpdate(card1,.12);assert(card1.h>1 and card1.h<fullH,'en cours d ouverture')
card1.scripts.OnUpdate(card1,.2);assert(card1.h==fullH and not card1.scripts.OnUpdate,'ouverte')
-- Flux de pixels : de la source vers la carte, pixels placés à l'écran pendant qu'elle est ouverte.
local flux=card1.flux;assert(flux.shown and #flux.dots>0 and flux.fade==1)
function UIParent:GetCenter() return 400,300 end;function UIParent:GetTop() return 310 end;function card1:GetBottom() return 334 end
flux.scripts.OnUpdate(flux,.1);local d=flux.dots[1].point;assert(d and d[2]==UIParent and d[5]>=310 and d[5]<=334,'pixel entre la source et la carte')
links1.scripts.OnHyperlinkEnter(links1,'charskill:base:Charge')
local card2=CharacterSkillCard2
assert(card2:IsShown() and card2.title.text=='|cffff8800Charge|r',card2.title.text)
assert(card2.level>card1.level and card2.point[2]==links1,'la référence s’ouvre à côté, au-dessus')
-- Carte liée : s'ouvre en largeur (de gauche à droite quand la place est à droite).
assert(card2.w==1 and card2.h==card2.content.h,'carte liée fermée au départ');card2.scripts.OnUpdate(card2,.3);assert(card2.w==card2.content.w)
links1.scripts.OnHyperlinkLeave(links1);for _,fn in ipairs(timers) do fn() end
assert(not card2:IsShown())
links1.scripts.OnHyperlinkEnter(links1,'charskill:base:Inconnue');assert(card2.title.text=='Inconnue')
-- OnHyperlinkLeave perdu (aperçu redessiné, builder fermé) : la carte liée se ferme quand même.
local watcher;for _,f in ipairs(objects) do if f.scripts and f.scripts.OnUpdate and f.parent==nil and f.kind=='Frame' and not f.name then watcher=f end end
card1:Hide();assert(not card2:IsShown(),'fermée avec la carte qui l a ouverte')
C:ShowSkillTooltip(UIParent,{name='Source',description='Voir {{Action : Charge}}'});links1.scripts.OnHyperlinkEnter(links1,'charskill:base:Charge')
assert(card2:IsShown());links1.shown=false;for _,f in ipairs(objects) do if f.scripts and f.scripts.OnUpdate and f.parent==nil then pcall(f.scripts.OnUpdate,f,.3) end end
assert(not card2:IsShown(),'source disparue : carte liée fermée');links1.shown=true
C:HideSkillTooltip();assert(not card1:IsShown() and not card2:IsShown())
assert(not card1.flux.shown and not card2.flux.shown,'flux fermés avec les cartes')
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
-- Crochet jamais orphelin : "[" reste avec le nom du lien et passe à la ligne avec lui.
RT.Render(box,'aaaa {{Action : Esquive}}',60,C:SkillTextOptions())
local yWord,yBracket
for i=1,box.richText.usedStrings do local fs=box.richText.strings[i];if fs.text=='aaaa' then yWord=fs.point[5] end;if tostring(fs.text):find('[',1,true) then yBracket=fs.point[5] end end
assert(yWord and yBracket and yBracket<yWord,'le crochet part à la ligne avec le lien')
C:ShowSkillName(UIParent,{name='[[#ff8800]]Charge[[/]]'});assert(CharacterSkillNameTip:IsShown());C:HideSkillName()
typeText('{{rouge}}x{{/}} {{Défensive:');desc.scripts.OnTabPressed(desc)
assert(desc.text=='{{rouge}}x{{/}} {{Défensive:','catégorie vide : rien à insérer')
C:ToggleActionButton();local root=CharacterActionMenu;assert(root:IsShown())
local idle
for _,o in ipairs(objects) do if o.parent==root and o.scripts.OnDragStart and not o.cat then idle=o end end
assert(idle);ACTION_IDLE,ACTION_ROOT=idle,root
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
-- Nexus : logo -> cube (planche) -> éclatement vers le triangle.
local morph,cube;for _,o in ipairs(objects) do if o.kind=='Texture' and o.texture and tostring(o.texture):find('DataCube') then cube=o;morph=o.parent end end
assert(cube and morph)
root.scripts.OnUpdate(root,.2);assert(morph.shown and cube.alpha>0,'cube pendant la transformation')
root.scripts.OnUpdate(root,.2);local shardShown=false
for _,o in ipairs(objects) do if o.parent==morph and o.texture and tostring(o.texture):find('DataShard') and o.shown then shardShown=true end end
assert(shardShown,'éclats vers le triangle')
root.scripts.OnUpdate(root,.5);assert(not root.scripts.OnUpdate and not morph.shown)
local category
for _,o in ipairs(objects) do if o.cat and o.cat.key=='offensive' and o.parent==root then category=o end end
category.scripts.OnClick(category,'RightButton');assert(root.scripts.OnUpdate and not idle:IsShown(),'fermeture animée')
root.scripts.OnUpdate(root,.17);assert(category:IsShown() and category.alpha>0 and category.alpha<1)
root.scripts.OnUpdate(root,.7);assert(not root.scripts.OnUpdate and idle:IsShown() and not category:IsShown())
idle.scripts.OnClick();root.scripts.OnUpdate(root,.9)
category.scripts.OnClick(category,'LeftButton');root.scripts.OnUpdate(root,.6);assert(not root.scripts.OnUpdate)
-- Flux : défile vers la droite ; les compétences ondulent autour de leur place.
local FR=C.ActionFrames;local strip=FR.strip;assert(strip.scripts.OnUpdate,'flux animé')
local shownSkill;for _,b in ipairs(FR.skillButtons) do if b.shown and b.baseX then shownSkill=b end end
assert(shownSkill,'au moins une compétence dans la bande')
strip.scripts.OnUpdate(strip,.4)
local dy=shownSkill.point[3]-shownSkill.baseY;assert(shownSkill.point[2]==shownSkill.baseX and math.abs(dy)>0 and math.abs(dy)<=C.ACTION_THEME.wave.amplitude+1e-9,'vaguelette')
-- Catégorie : maintenir pour déplacer, le clic qui suit est ignoré ; le retour ramène au menu.
root.scripts.OnUpdate=nil
category.scripts.OnMouseDown(category);category.scripts.OnDragStart(category);assert(root.dragging and category.scripts.OnUpdate)
cursor={300,300};category.scripts.OnUpdate(category);category.scripts.OnDragStop(category)
assert(not root.dragging and not category.scripts.OnUpdate)
category.scripts.OnClick(category,'LeftButton');assert(not root.scripts.OnUpdate,'clic après glisser ignoré')
category.scripts.OnMouseDown(category);category.scripts.OnClick(category,'RightButton')
for i=1,10 do if root.scripts.OnUpdate then root.scripts.OnUpdate(root,.2) end end
assert(not idle:IsShown() and category:IsShown() and not category.back.shown,'clic droit sur le retour : retour au menu, pas fermeture')
category.scripts.OnClick(category,'RightButton');for i=1,10 do if root.scripts.OnUpdate then root.scripts.OnUpdate(root,.2) end end
assert(idle:IsShown(),'clic droit sur une catégorie du menu : fermeture')
-- Panneau rapide : clic droit sur le bouton, cases à cocher, glisser-déposer.
assert(C:SaveSkill('base',nil,'Alpha','',''));assert(C:SaveSkill('base',nil,'Beta','',''));assert(C:SaveSkill('base',nil,'Gamma','',''))
idle.scripts.OnMouseDown(idle);idle.scripts.OnClick(idle,'RightButton');assert(CharacterActionLayout:IsShown(),'panneau ouvert')
local function names(list) local t={};for _,sk in ipairs(list) do t[#t+1]=C:StripSkillMarkup(sk.name) end;return table.concat(t,',') end
local before=names(C:ListActionSkills('base'))
local rows={};for _,o in ipairs(objects) do if o.parent==CharacterActionLayout.content and o.entry and o.shown then rows[o.index]=o end end
assert(#rows==#C:ListActionEntries('base') and #rows>=3)
local beta;for _,r in ipairs(rows) do if r.entry.skill.name=='Beta' then beta=r end end
beta.check.checked=false;beta.check.scripts.OnClick(beta.check)
assert(not names(C:ListActionSkills('base')):find('Beta'),'décochée : absente de la bande')
local gamma;for _,r in ipairs(rows) do if r.entry.skill.name=='Gamma' then gamma=r end end
function CharacterActionLayout.content:GetTop() return 1000 end
gamma.scripts.OnDragStart(gamma);cursor={0,1000};CharacterActionLayout.scripts.OnUpdate(CharacterActionLayout);gamma.scripts.OnDragStop(gamma)
assert(C:ListActionEntries('base')[1].skill.name=='Gamma','glissée en tête');assert(names(C:ListActionSkills('base')):match('^Gamma'),'ordre des bulles')
for _,o in ipairs(objects) do if o.parent==CharacterActionLayout.content and o.entry and o.shown and o.entry.skill.name=='Beta' then beta=o end end
beta.check.checked=true;beta.check.scripts.OnClick(beta.check);assert(names(C:ListActionSkills('base')):find('Beta'))
assert(CharacterActionLayout.point[1]=='LEFT' and CharacterActionLayout.point[2]==idle and CharacterActionLayout.point[3]=='RIGHT','à droite du bouton, centré')
local bar;for _,o in ipairs(objects) do if o.parent==CharacterActionLayout and o.scripts.OnMouseDown and o.scripts.OnMouseUp then bar=o end end
assert(bar);bar.scripts.OnMouseDown(bar,'LeftButton');bar.scripts.OnMouseUp(bar,'LeftButton')
assert(CharacterDB.actionLayoutPositions['Tester-Realm'],'détaché : position retenue')
idle.scripts.OnClick(idle,'RightButton');idle.scripts.OnClick(idle,'RightButton')
assert(CharacterActionLayout.point[2]==UIParent,'rouvert à sa position détachée')
bar.scripts.OnMouseUp(bar,'RightButton');assert(not CharacterDB.actionLayoutPositions['Tester-Realm'] and CharacterActionLayout.point[2]==idle,'raccroché au bouton')
idle.scripts.OnClick(idle,'RightButton');assert(not CharacterActionLayout:IsShown(),'second clic droit : fermé')
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
local function pickLibrary(owner)
 local btn;for _,o in ipairs(objects) do if o.kind=='Button' and o.library then btn=o end end
 assert(btn,'bouton bibliothèque');btn.scripts.OnClick(btn)
 local row;for _,o in ipairs(objects) do if o.kind=='Button' and o.shown and o.owner==owner and o.label then row=o end end
 assert(row,'ligne '..tostring(owner));assert(row.count.text~=nil);row.scripts.OnClick(row)
end
pickLibrary('raid1-Realm')
assert(C:IsSkillLibraryReadOnly())
assert(not C:SaveSkill('offensive',nil,'Bad','',''))
assert(not C:DeleteSkill('offensive','Legacy'))
assert(not C:SendSkillLibrary())
-- Sending requires addon discovery; snapshots are never sent to silent peers.
pickLibrary(false)
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
-- Consultation : bibliothèques fusionnées, créateur affiché, doublons identiques retirés.
CharacterDB.skillLibraries['zed-Realm']={revision=1,categories={base={},offensive={Frappe={name='Frappe',icon='x',description='zed'},Esquive={name='Esquive',icon='',description=''}},defensive={},ranged={},index={}}}
CharacterDB.skillLibraries['amy-Realm']={revision=1,categories={base={},offensive={Frappe={name='Frappe',icon='x',description='zed'}},defensive={},ranged={},index={}}}
assert(C:SaveSkill('offensive',nil,'Esquive','',''))
local merged=C:ListAllSkills('offensive');local frappes,esquives=0,{}
for _,sk in ipairs(merged) do if sk.name=='Frappe' then frappes=frappes+1 end;if sk.name=='Esquive' then esquives[#esquives+1]=sk end end
assert(frappes==1,'doublon identique fusionné');assert(#esquives==2 and esquives[1].owner==nil and esquives[2].owner=='zed-Realm','la vôtre d abord')
assert(C:SkillOwnerSuffix(esquives[2]):find('zed',1,true) and C:SkillOwnerSuffix(esquives[1])=='')
assert(C:FindSkillRef('offensive','Frappe').owner=='amy-Realm','référence résolue dans une bibliothèque reçue')
-- Bibliothèque commune : tout, fusionné, en lecture seule.
pickLibrary(C.COMMON_SKILL_LIBRARY);assert(C:IsSkillLibraryReadOnly())
local common=C:ListSkills('offensive');local ownEsq,zedEsq=false,false
for _,sk in ipairs(common) do if sk.name=='Esquive' and sk.owner==nil then ownEsq=true end;if sk.name=='Esquive' and sk.owner=='zed-Realm' then zedEsq=true end end
assert(ownEsq and zedEsq,'les deux Esquive dans la commune');assert(not C:SaveSkill('offensive',nil,'X','',''))
local creators={};for _,o in ipairs(objects) do if o.kind=='Button' and o.creator and o.shown and o.skill then creators[o.creator.text]=true end end
assert(creators['Créé par : Vous'] and creators['Créé par : zed'],'créateur en bas à droite')
pickLibrary(false);assert(not C:IsSkillLibraryReadOnly())
-- Ordre alphabétique sur le nom affiché : balises, majuscules et accents ignorés.
for _,n in ipairs({'[[#ff0000]]Zèbre[[/]]','Écu','[[#00ff00]]Aptitude[[/]]','Déplacement','def.Phy','Esquive'}) do assert(C:SaveSkill('ranged',nil,n,'','')) end
local order={};for _,sk in ipairs(C:ListSkills('ranged')) do order[#order+1]=C:StripSkillMarkup(sk.name) end
assert(table.concat(order,',')=='Aptitude,def.Phy,Déplacement,Écu,Esquive,Zèbre',table.concat(order,','))
-- Fiche de consultation : jamais le créateur dans le titre.
C:ShowSkillTooltip(UIParent,{name='Frappe',owner='Erzah-Apertus',description='x'});assert(CharacterSkillCard1.title.text=='Frappe',CharacterSkillCard1.title.text);C:HideSkillTooltip()
C:ShowSkillName(UIParent,{name='Frappe',owner='Erzah-Apertus'});assert(CharacterSkillNameTip.title.text=='Frappe');C:HideSkillName()
-- Droits d'édition et bibliothèques reçues supprimables.
local Codec=C.SkillLibraryCodec
local function lib(name,desc) local db={base={},offensive={},defensive={},ranged={},index={}};db.base[name]={name=name,icon='',description=desc or ''};return db end
local dbE,edE=Codec.Decode(Codec.Encode(lib('A'),{['Tester-Realm']=true,['raid4-Realm']=true}))
assert(dbE.base.A and edE['Tester-Realm'] and edE['raid4-Realm'],'éditeurs transportés')
assert(select(2,Codec.Decode(Codec.Encode(lib('A'))))~=nil,'sans éditeurs : format inchangé')
local seq=0
local function deliver(sender,owner,rev,db,editors)
 seq=seq+1;local payload=Codec.Encode(db,editors);local total=math.ceil(#payload/200);local id=tostring(seq)..'-9'
 receive('H|'..id..'|'..rev..'|'..total..(owner and ('|'..owner) or ''),sender)
 for k=1,total do receive('D|'..id..'|'..k..'|'..payload:sub((k-1)*200+1,k*200),sender) end
end
-- Le créateur raid3 nomme Tester et raid4 éditeurs.
deliver('raid3-Realm',nil,1,lib('Orig'),{['Tester-Realm']=true,['raid4-Realm']=true})
assert(CharacterDB.skillLibraries['raid3-Realm'].editors['Tester-Realm'] and C:CanEditSkillLibrary('raid3-Realm'),'nommé éditeur')
assert(not C:CanEditSkillLibrary('raid1-Realm'),'pas éditeur ailleurs')
pickLibrary('raid3-Realm');assert(not C:IsSkillLibraryReadOnly(),'bibliothèque reçue modifiable')
assert(C:SaveSkill('base',nil,'Ajout','',''),'l éditeur modifie')
C:StopSkillTransfers();sent={};assert(C:SendSkillLibrary(),'l éditeur renvoie');for k=1,12 do network.scripts.OnUpdate(network,.1) end
assert(sent[1][2]:match('|raid3%-Realm$') and CharacterDB.skillLibraries['raid3-Realm'].revision==2,'renvoi sous le nom du créateur')
C:StopSkillTransfers()
-- Renvoi par raid4 (nommé) : accepté ; par raid5 (non nommé) : refusé.
deliver('raid4-Realm','raid3-Realm',3,lib('ParRaid4'))
local stored=CharacterDB.skillLibraries['raid3-Realm'];assert(stored.categories.base.ParRaid4 and stored.revision==3 and stored.editors['raid4-Realm'],'renvoi d un éditeur accepté, éditeurs conservés')
deliver('raid5-Realm','raid3-Realm',4,lib('Pirate'))
assert(not CharacterDB.skillLibraries['raid3-Realm'].categories.base.Pirate,'non nommé par le créateur : refusé')
deliver('raid4-Realm','raid9-Realm',1,lib('Inconnu'))
assert(not CharacterDB.skillLibraries['raid9-Realm'],'créateur jamais reçu : refusé')
-- Chez le créateur : la version d'un éditeur nommé remplace la sienne.
pickLibrary(false);C:SetSkillEditor('raid6-Realm',true);CharacterDB.skillRevision=5
deliver('raid7-Realm','Tester-Realm',9,lib('Intrus'));assert(not C:GetOwnedSkillLibrary().base.Intrus,'non éditeur : refusé')
deliver('raid6-Realm','Tester-Realm',4,lib('Vieille'));assert(not C:GetOwnedSkillLibrary().base.Vieille,'révision périmée : refusée')
deliver('raid6-Realm','Tester-Realm',6,lib('Collab'));assert(C:GetOwnedSkillLibrary().base.Collab and CharacterDB.skillRevision==6,'version de l éditeur adoptée')
-- Seul le créateur change la liste d'éditeurs ; supprimer une bibliothèque reçue.
assert(C:DeleteReceivedSkillLibrary('raid3-Realm') and not CharacterDB.skillLibraries['raid3-Realm'],'bibliothèque supprimée')
assert(not C:DeleteReceivedSkillLibrary(C.COMMON_SKILL_LIBRARY),'la commune ne se supprime pas')
-- Menu : × sur une bibliothèque reçue, second clic pour confirmer.
deliver('raid8-Realm',nil,1,lib('Temp'));assert(CharacterDB.skillLibraries['raid8-Realm'])
local ob;for _,o in ipairs(objects) do if o.kind=='Button' and o.library then ob=o end end;ob.scripts.OnClick(ob)
local del;for _,o in ipairs(objects) do if o.kind=='Button' and o.del and o.owner=='raid8-Realm' and o.shown then del=o.del end end
assert(del and del.shown,'croix sur la bibliothèque reçue')
del.scripts.OnClick(del);assert(CharacterDB.skillLibraries['raid8-Realm'],'premier clic : confirmation')
del.scripts.OnClick(del);assert(not CharacterDB.skillLibraries['raid8-Realm'],'second clic : supprimée')
-- Utilisable: storage, transfer, consultation and raid message round trip.
pickLibrary(false)
assert(C:SaveSkill('base',nil,'Usable Test','134400','Description',true))
local usable=C:GetSkill('base','Usable Test');assert(usable.usable==true)
local decodedUse=Codec.Decode(Codec.Encode(C:GetOwnedSkillLibrary(),{['raid4-Realm']=true}))
assert(decodedUse.base['Usable Test'].usable==true)
assert(not decodedUse.base.Collab.usable)
local mergedUse;for _,sk in ipairs(C:ListAllSkills('base')) do if sk.name=='Usable Test' then mergedUse=sk end end
assert(mergedUse and mergedUse.usable)
C:ShowSkillTooltip(UIParent,mergedUse);assert(CharacterSkillCard1.useButton:IsShown())
C:ShowSkillTooltip(UIParent,{name='Normal',description='x'});assert(not CharacterSkillCard1.useButton:IsShown())
local filters={};function ChatFrame_AddMessageEventFilter(event,fn) filters[event]=fn end
local nativeLinks=0;function ChatFrame_OnHyperlinkShow() nativeLinks=nativeLinks+1 end
local raid=true;IsInRaid=function() return raid end
local sentUse;function SendChatMessage(message,channel) sentUse={message,channel} end
dofile('Modules/Character/UI_SkillUse.lua')
local id=C:SkillChatID(mergedUse);assert(#id==16)
local link=C:SkillChatLink(mergedUse,id)
local message=C:PrepareSkillRaidMessage('Avant '..link..' apres',mergedUse)
assert(message and not message:find('|',1,true))
assert(C:FilterSkillRaidMessage(message)=='Avant '..link..' apres')
assert(C:FindChatSkill(id).name==mergedUse.name)
assert(not C:PrepareSkillRaidMessage('sans lien',mergedUse))
local long=C:PrepareSkillRaidMessage(string.rep('x ',200)..link,mergedUse);assert(long)
local parts=C:SplitSkillRaidMessage(long);assert(#parts>1)
for _,part in ipairs(parts) do assert(#part<=255) end
assert(table.concat(parts,' '):find('[Omega:'..id..']',1,true))
raid=false;assert(not C:PrepareSkillRaidMessage(link,mergedUse));raid=true
-- Coût : ajouté en fin d'émote, ressource abrégée.
do local costly={name=mergedUse.name,icon=mergedUse.icon,description=mergedUse.description,usable=true,cost={resource='mana',amount=50}}
local costLink=C:SkillChatLink(costly,C:SkillChatID(costly))
local sent=C:PrepareSkillRaidMessage('Je lance '..costLink..' fort  ',costly)
assert(sent and sent:sub(-16)==' [Coût : 50 MP]','coût en fin d’émote : '..tostring(sent))
costly.cost={resource='endurance',amount=5};costLink=C:SkillChatLink(costly,C:SkillChatID(costly))
assert(C:PrepareSkillRaidMessage(costLink,costly):find('[Coût : 5 End.]',1,true))
assert(not message:find('Coût',1,true),'sans coût : rien ajouté') end
do local t=C:SkillCostShortfallText({resource='mana',amount=50})
assert(t:find('^Le |cff%x%x%x%x%x%xMana|r n’est pas suffisant pour lancer cette compétence%.$'),t)
assert(C:SkillCostShortfallText({resource='hp',amount=1}):find('Vie|r n’est pas suffisante',1,true))
assert(C:SkillCostShortfallText({resource='endurance',amount=1}):find('^L’|cff'))
assert(C:SkillCostShortfallText({resource='hp',amount=1}):find('|cff1ab333Vie',1,true),'Vie en vert') end
do local costly={name=mergedUse.name,icon=mergedUse.icon,description=mergedUse.description,usable=true,cost={resource='hp',amount=3}}
local costLink=C:SkillChatLink(costly,C:SkillChatID(costly))
local sent=C:PrepareSkillRaidMessage('A '..costLink..' [Coût : 3 HP] puis B',costly)
assert(sent:sub(-15)==' [Coût : 3 HP]' and select(2,sent:gsub('Coût',''))==1,'coût déplacé en dernier, une seule fois : '..sent) end
ChatFrame_OnHyperlinkShow(UIParent,'item:123');assert(nativeLinks==1)
ChatFrame_OnHyperlinkShow(UIParent,'omegaskill:'..id);assert(nativeLinks==1 and CharacterSkillCard1.useButton:IsShown())
function M:SetCursorPosition(v) self.cursor=v end
function M:HighlightText(a,b) self.highlight={a,b} end
C:OpenSkillUse(mergedUse)
local composer=CharacterSkillUsePopup;assert(composer:IsShown())
local input=composer.edit;assert(input:GetText()=='*Votre émote ici.* '..link)
do local h=input.highlight;assert(h and input:GetText():sub(h[1]+1,h[2])=='Votre émote ici.','exemple sélectionné') end
assert(input);input:SetText('Avant '..link..' apres');input.scripts.OnEnterPressed(input)
assert(sentUse and sentUse[1]==message and sentUse[2]=='RAID' and not composer:IsShown())
assert(C:SaveSkill('grimoire',nil,'Codex','134400','Page du grimoire',true))
assert(C:GetSkill('grimoire','Codex').usable)
local grimoireRoundTrip=C.SkillLibraryCodec.Decode(C.SkillLibraryCodec.Encode(C:GetOwnedSkillLibrary()))
assert(grimoireRoundTrip.grimoire.Codex.description=='Page du grimoire')
assert(C.ActionFrames.cats.grimoire and C.ActionFrames.OFFSETS.grimoire[2]==-70)
assert(C.ActionFrames.OFFSETS.ranged[2]==0 and C.ActionFrames.OFFSETS.defensive[2]==0)
-- Maj + clic gauche sur Action : bascule la bibliothèque sans ouvrir le triangle.
do local idle,root=ACTION_IDLE,ACTION_ROOT;local builderShown=CharacterSkillsBuilder:IsShown();shift=true
idle.suppressClick=nil;root.dragging=nil;root.scripts.OnUpdate=nil
idle.scripts.OnClick(idle,'LeftButton')
assert(CharacterSkillsBuilder:IsShown()~=builderShown and not root.scripts.OnUpdate,'Maj+clic ouvre la bibliothèque')
idle.scripts.OnClick(idle,'LeftButton');shift=false
assert(CharacterSkillsBuilder:IsShown()==builderShown) end
print('OK: legacy skills, collision guard, codec, builder, animation lifecycle, imports, full replacement, raid checks, stale revision, read-only ownership')
`;
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:code,encoding:'utf8'});if(r.stderr) {const m=r.stderr.match(/stdin:(\d+)/);if(m){const n=Number(m[1]);process.stdout.write(code.split('\n').slice(n-3,n+2).join('\n')+'\n');}}process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||((r.stderr||'').includes('stack traceback')?1:0));

