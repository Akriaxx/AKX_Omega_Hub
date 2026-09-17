-- Visual workstation built around the existing theme setters and renderer.
local ZG,UI=ZoneGate,OS2.UI
local panel=ZoneGateThemePanel
local c=panel.studioControls
local W,H=1280,760
panel:SetSize(W,H);panel:SetClampedToScreen(true)
c.title:SetText("ZONE GATE  /  Atelier des entrées")
local function place(region,parent,x,y)
    region:ClearAllPoints();region:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
end
local function text(parent,label,x,y,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    place(f,parent,x,y);f:SetText(label);f:SetTextColor(.83,.79,.69)
    if size then f:SetFont("Fonts\\FRIZQT__.TTF",size,"") end
    return f
end
local function button(parent,label,x,y,width,callback)
    local b=UI.CreatePanelButton(parent,width,26,label);place(b,parent,x,y)
    b:SetScript("OnClick",callback);return b
end
local function theme() return panel.selectedId and ZG:GetTheme(panel.selectedId) end
local function duration(t) return math.max(.05,t.fadeIn or .4)+math.max(0,t.hold or 2.5)+math.max(.05,t.fadeOut or .8) end
local function fit() panel:SetScale(math.min(1,(UIParent:GetWidth()-40)/W,(UIParent:GetHeight()-40)/H)) end
panel:HookScript("OnShow",fit)
panel:RegisterEvent("DISPLAY_SIZE_CHANGED");panel:SetScript("OnEvent",fit)
fit()

-- Library and contextual settings.
place(c.listScroll,panel,12,110);c.listScroll:SetHeight(628)
place(c.listSep,panel,196,48);c.listSep:SetHeight(696)
place(c.form,panel,816,80);c.form:SetSize(448,650)
c.placeholder:SetWidth(420);c.placeholder:SetText("Créez un style depuis la galerie, ou sélectionnez un thème dans votre bibliothèque.\n\nLes thèmes restent réutilisables dans vos zones et sous-zones.")
local search=UI.CreateStyledEditBox(panel,168,24,false);place(search,panel,12,76)
search:SetScript("OnTextChanged",function(self) panel.searchText=string.lower(self:GetText() or "");panel:RefreshList() end)
text(panel,"Rechercher dans mes thèmes",12,57)
c.listHeader:SetText("")
local inspectorTitle=text(panel,"PERSONNALISER",820,55,13)
text(panel,"Enregistrement automatique",820,710)
text(panel,"Affectation du thème : panneau Zones > Thème",820,731)
local selectedTab="text"
local tabs={}
local groups={"text","decor","timing"}
local function showTab(key)
    selectedTab=key
    for _,group in ipairs(groups) do
        for _,control in ipairs(c[group]) do control:SetShown(group==key) end
        if tabs[group] then tabs[group].accent:SetShown(group==key) end
    end
    local t=theme()
    c.customFont:SetShown(key=="text" and t and t.font=="custom")
    c.customFontLabel:SetShown(key=="text" and t and t.font=="custom")
end
for i,entry in ipairs({{"text","Typographie"},{"decor","Ornements"},{"timing","Rythme & son"}}) do
    local key=entry[1]
    tabs[key]=button(c.edit,entry[2],4+(i-1)*144,36,138,function() showTab(key) end)
end
place(c.fontLabel,c.edit,6,86);place(c.colorsLabel,c.edit,6,214)
place(c.sepStyleLabel,c.edit,6,86);place(c.sepColorLbl,c.edit,6,310)
place(c.timingLabel,c.edit,6,86)
c.timingLabel:SetText("Apparition / Lecture / Disparition (secondes)")
c.preview:Hide()
-- Commit numerical fields when leaving them, not only with Enter.
for _,eb in ipairs({c.size,c.fadeIn,c.hold,c.fadeOut}) do
    eb:HookScript("OnEditFocusLost",function(self)
        if panel.suppressEvents or not panel.selectedId then return end
        if self==c.size then ZG:SetThemeTitleSize(panel.selectedId,tonumber(self:GetText()))
        else ZG:SetThemeTiming(panel.selectedId,tonumber(c.fadeIn:GetText()),tonumber(c.hold:GetText()),tonumber(c.fadeOut:GetText())) end
    end)
end

-- Dedicated preview instance: never hides a real crossing or plays audio.
text(panel,"TEXTE DE DÉMONSTRATION",220,53,12)
local zoneEB=UI.CreateStyledEditBox(panel,270,26,false);place(zoneEB,panel,220,76);zoneEB:SetMaxLetters(64)
local subEB=UI.CreateStyledEditBox(panel,286,26,false);place(subEB,panel,500,76);subEB:SetMaxLetters(72)
zoneEB:SetText("Les Portes d'Astralune");subEB:SetText("Sanctuaire des anciens")
local stage=CreateFrame("Frame",nil,panel,"BackdropTemplate");place(stage,panel,220,114);stage:SetSize(566,230)
stage:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
stage:SetBackdropColor(.025,.035,.05,1);stage:SetBackdropBorderColor(.28,.25,.20,1)
local stageCaption=text(stage,"APERÇU EN DIRECT",14,13,10);stageCaption:SetTextColor(.55,.58,.62)
local preview=ZG.CreateBannerRenderer(stage)
preview:ClearAllPoints();preview:SetPoint("CENTER",stage,"CENTER",0,0);preview:SetScale(.86)
local stageColors={{.025,.035,.05},{.12,.10,.08},{.60,.61,.59}}
for i,label in ipairs({"Nuit","Pierre","Clair"}) do
    button(stage,label,302+(i-1)*82,194,76,function() stage:SetBackdropColor(unpack(stageColors[i])) end)
end
local clock=text(panel,"",220,357)
local status=text(panel,"",220,739)
local timeline=CreateFrame("Slider",nil,panel,"OptionsSliderTemplate")
place(timeline,panel,226,385);timeline:SetSize(550,16);timeline:SetMinMaxValues(0,4);timeline:SetValueStep(.01)
local progress,playing,loop,settingSlider=0,false,false,false
local previewTheme=ZG.DefaultTheme
local function seek(value)
    progress=math.max(0,math.min(duration(previewTheme),value))
    preview:Seek(progress)
    clock:SetText(string.format("%.1f s / %.1f s   ·   Apparition  /  Lecture  /  Disparition",progress,duration(previewTheme)))
    settingSlider=true;timeline:SetValue(progress);settingSlider=false
end
timeline:SetScript("OnValueChanged",function(_,value) if not settingSlider then playing=false;seek(value) end end)
local playBtn
playBtn=button(panel,"Lire l'entrée",220,414,124,function()
    playing=not playing
    if playing and progress>=duration(previewTheme) then seek(0) end
    if playing and progress==math.max(.05,previewTheme.fadeIn or .4) then seek(0) end
    playBtn:SetText(playing and "Pause" or "Lire l'entrée")
end)
button(panel,"Rejouer",352,414,100,function() seek(0);playing=true;playBtn:SetText("Pause") end)
local loopBtn
loopBtn=button(panel,"Boucle : non",460,414,130,function() loop=not loop;loopBtn:SetText(loop and "Boucle : oui" or "Boucle : non") end)
button(panel,"Voir en jeu",598,414,188,function()
    ZG:ShowBanner(zoneEB:GetText(),subEB:GetText(),previewTheme)
end)

-- Bounded per-selection history; IDs, ownership and links never change.
local history={undo={},redo={}}
local function fingerprint(value)
    if type(value)~="table" then return tostring(value) end
    local keys={};for k in pairs(value) do keys[#keys+1]=k end;table.sort(keys)
    local out={};for _,k in ipairs(keys) do out[#out+1]=k.."="..fingerprint(value[k]) end
    return table.concat(out,"|")
end
local lastPreviewKey
local function refreshPreview()
    local t=theme() or ZG.DefaultTheme
    local stamp=fingerprint(t)
    if history.id~=panel.selectedId then
        history={id=panel.selectedId,undo={},redo={},last=ZG.CopyTheme(t),stamp=stamp}
        playing=false;progress=math.max(.05,t.fadeIn or .4)
        c.delete:SetText("Supprimer");panel.deleteArmed=nil
    elseif stamp~=history.stamp then
        if history.last then table.insert(history.undo,history.last);if #history.undo>40 then table.remove(history.undo,1) end end
        history.redo={};history.last=ZG.CopyTheme(t);history.stamp=stamp
    end
    local key=stamp..zoneEB:GetText().."/"..subEB:GetText()
    if key~=lastPreviewKey then
        previewTheme=t;preview:Configure(zoneEB:GetText()~="" and zoneEB:GetText() or "Nom du lieu",subEB:GetText(),t)
        timeline:SetMinMaxValues(0,duration(t));seek(playing and progress or math.max(.05,t.fadeIn or .4))
        lastPreviewKey=key
    end
    status:SetText(theme() and ("Thème : "..t.name.."   ·   Enregistré") or "Choisissez un style ci-dessus pour créer votre premier thème.")
    showTab(selectedTab)
end
local function restore(from,to)
    refreshPreview()
    local snapshot=table.remove(from)
    if not snapshot or not theme() then return end
    table.insert(to,ZG.CopyTheme(theme()))
    if ZG:RestoreStudioTheme(panel.selectedId,snapshot) then
        history.last=ZG.CopyTheme(snapshot);history.stamp=fingerprint(snapshot)
        panel:RefreshAll();refreshPreview()
    end
end
button(panel,"Annuler",838,12,110,function() restore(history.undo,history.redo) end)
button(panel,"Rétablir",954,12,110,function() restore(history.redo,history.undo) end)
button(panel,"Dupliquer",1070,12,138,function()
    local t=theme();if not t then return end
    local new=ZG:CreateStudioTheme(nil,t);if new then panel.selectedId=new.id;panel:RefreshAll() end
end)
-- An explicit second click prevents deleting a shared style by accident.
local deleteAction=c.delete:GetScript("OnClick")
c.delete:SetScript("OnClick",function(self)
    if panel.deleteArmed==panel.selectedId and panel.selectedId then deleteAction(self)
    else panel.deleteArmed=panel.selectedId;self:SetText("Confirmer") end
end)

text(panel,"GALERIE  /  Créer un thème à partir d'un style",220,463,13)
for i,preset in ipairs(ZG.StudioPresets) do
    local col,row=(i-1)%2,math.floor((i-1)/2)
    local tile=CreateFrame("Button",nil,panel,"BackdropTemplate")
    place(tile,panel,220+col*288,486+row*80);tile:SetSize(278,72)
    tile:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    tile:SetBackdropColor(.055,.05,.06,1);tile:SetBackdropBorderColor(.27,.24,.20,1)
    local sample=ZG.CreateBannerRenderer(tile);sample:ClearAllPoints();sample:SetPoint("TOP",tile,"TOP",0,-10);sample:SetScale(.40)
    local sampleTheme=ZG:StudioPresetTheme(preset)
    sample:Configure(preset.name,"",sampleTheme);sample:Seek(sampleTheme.fadeIn)
    text(tile,preset.caption,14,52,10)
    tile:SetScript("OnEnter",function() tile:SetBackdropBorderColor(unpack(preset.color)) end)
    tile:SetScript("OnLeave",function() tile:SetBackdropBorderColor(.27,.24,.20,1) end)
    tile:SetScript("OnClick",function()
        local new=ZG:CreateStudioTheme(preset)
        if new then search:SetText("");panel.selectedId=new.id;panel:RefreshAll();refreshPreview() end
    end)
end
local originalRefresh=panel.RefreshForm
function panel:RefreshForm() originalRefresh(self);refreshPreview() end
zoneEB:SetScript("OnTextChanged",refreshPreview);subEB:SetScript("OnTextChanged",refreshPreview)
local elapsed=0
panel:HookScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed>=.15 then elapsed=0;refreshPreview() end
    if playing then
        local nextTime=progress+dt
        if nextTime>=duration(previewTheme) then
            if loop then nextTime=nextTime%duration(previewTheme) else nextTime=duration(previewTheme);playing=false;playBtn:SetText("Lire l'entrée") end
        end
        seek(nextTime)
    end
end)
panel:HookScript("OnHide",function() playing=false;preview:HideBanner() end)
panel:HookScript("OnShow",function() lastPreviewKey=nil;panel:RefreshAll() end)
panel:RefreshAll()
