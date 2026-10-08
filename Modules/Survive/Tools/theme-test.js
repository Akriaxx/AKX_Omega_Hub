
const fs=require('fs'),cp=require('child_process'),path=require('path');
let mock=fs.readFileSync('Modules/ZoneGate/Tests/Studio_test.lua','utf8');
mock=mock.slice(mock.indexOf('unpack='),mock.indexOf('ZoneGate={'));
let views=fs.readFileSync('Modules/Character/Tests/views-test.js','utf8');
let extra=views.slice(views.indexOf('function M:GetParent()'),views.indexOf("dofile('Modules/Character/UI_Style.lua')"));
const files=[];function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,e.name);if(e.isDirectory())walk(f);else if(f.endsWith('.lua'))files.push(f.replaceAll('\\','/'));}}walk('Modules/Survive');
const lua=mock+extra+`
dofile('Modules/Survive/Core/UI.lua')
local original=OS2.UI
local originalButton=original.CreatePanelButton
dofile('Modules/Survive/Core/Theme.lua')
local theme=OS2.SurviveUI
assert(theme~=original and original.CreatePanelButton==originalButton,'other modules keep their shared widgets')
local window=CreateFrame('Frame',nil,UIParent);window:SetSize(300,220)
local bg=window:CreateTexture(nil,'BACKGROUND')
theme.ApplyWindowBackground(bg,.8)
assert(window.rpgSkin and #window.rpgSkin==9)
local button=theme.CreatePanelButton(window,120,24,'Test')
assert(button.bgN,'settings can tint action buttons')
theme.CreateStyledEditBox(window,160,24)
local cb,label=theme.CreateStyledCheckbox(window,'Test')
assert(cb and label)
theme.CreateCloseButton(window,function() end)
theme.ApplyWindowBackground(bg,.3)
assert(window.rpgSkin[1].alpha==.3,'opacity updates skin')
assert(theme.colors.warning[1]>.8,'fallback palette stays accessible')
print('OK: isolated Survive theme, windows, inputs, checkbox, buttons, close controls and opacity')
`+files.map(f=>'assert(loadfile('+JSON.stringify(f)+'))').join('\n');
const r=cp.spawnSync(process.execPath,[process.argv[2],'-'],{input:lua,encoding:'utf8'});process.stdout.write(r.stdout||'');process.stderr.write(r.stderr||'');process.exit(r.status||0);
