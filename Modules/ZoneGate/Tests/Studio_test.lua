local root="Modules/ZoneGate/"
for _,file in ipairs({"Core.lua","UI_Banner.lua","UI_Theme.lua","Studio.lua","UI_Studio.lua"}) do assert(loadfile(root..file)) end
unpack=table.unpack or unpack
local objects={}
local M={}
local function obj(kind,name,parent)
    local f=setmetatable({kind=kind,name=name,parent=parent,scripts={},shown=true,alpha=1,text="",w=100,h=24}, {__index=M})
    objects[#objects+1]=f;if name then _G[name]=f end;return f
end
function CreateFrame(kind,name,parent) return obj(kind,name,parent) end
function M:CreateTexture() return obj("Texture",nil,self) end
function M:CreateFontString() return obj("FontString",nil,self) end
function M:CreateAnimationGroup() return obj("AnimationGroup",nil,self) end
function M:CreateAnimation() return obj("Animation",nil,self) end
function M:SetScript(k,v) self.scripts[k]=v end
function M:GetScript(k) return self.scripts[k] end
function M:HookScript(k,v) local old=self.scripts[k];self.scripts[k]=function(...) if old then old(...) end;v(...) end end
function M:Show() local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function M:Hide() local old=self.shown;self.shown=false;if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function M:SetShown(v) if v then self:Show() else self:Hide() end end
function M:IsShown() return self.shown end
function M:SetAlpha(v) assert(v>=0 and v<=1);self.alpha=v end
function M:SetSize(w,h) self.w=w;self.h=h end
function M:SetWidth(w) self.w=w end
function M:SetHeight(h) self.h=h end
function M:GetWidth() return self.w end
function M:GetHeight() return self.h end
function M:SetText(t) self.text=t or "";if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self) end end
function M:GetText() return self.text end
function M:SetFont(path,size) self.fontSize=size;return true end
function M:GetStringWidth() return #self.text*(self.fontSize or 12)*.5 end
function M:GetStringHeight() return self.text~="" and (self.fontSize or 12) or 0 end
function M:GetFont() return "Fonts\\FRIZQT__.TTF" end
function M:SetPoint(...) self.point={...} end
function M:SetValue(v) self.value=v;if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,v) end end
function M:GetVerticalScrollRange() return 0 end
function M:GetVerticalScroll() return 0 end
function M:HasFocus() return false end
for _,key in ipairs({"SetFrameStrata","SetFrameLevel","EnableMouse","SetTexture","SetColorTexture","SetVertexColor","SetTextColor","SetTexCoord","SetAllPoints","ClearAllPoints","SetDuration","SetOrder","SetFromAlpha","SetToAlpha","Stop","Play","SetMovable","RegisterForDrag","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetClampedToScreen","RegisterEvent","SetScale","SetJustifyH","SetMaxLetters","SetScrollChild","EnableMouseWheel","SetMinMaxValues","SetValueStep","SetColor","SetChecked","ClearFocus","SetVerticalScroll"}) do M[key]=function() end end
UIParent=obj("Frame");UIParent:SetSize(1920,1080)
OS2={UI={colors=setmetatable({}, {__index=function() return {1,1,1,1} end})}}
local UI=OS2.UI
for _,key in ipairs({"ApplyWindowBackground","ApplyTitle","ApplyLabel","ApplySeparator","ApplyBodyText","ApplyMutedText","StyleDropdown"}) do UI[key]=function() end end
function UI.CreatePanelButton(parent,w,h,label) local b=obj("Button",nil,parent);b:SetSize(w,h);b:SetText(label);b.accent=obj("Texture",nil,b);return b end
function UI.CreateStyledEditBox(parent,w,h) local b=obj("EditBox",nil,parent);b:SetSize(w,h);return b end
function UI.CreateAddButton(parent,fn) local b=obj("Button",nil,parent);b:SetScript("OnClick",fn);return b end
function UI.CreateCloseButton(parent,fn) return UI.CreateAddButton(parent,fn) end
function UI.CreateColorSwatch(parent) return obj("Button",nil,parent) end
function UI.CreateStyledCheckbox(parent,label) return obj("CheckButton",nil,parent),obj("FontString",nil,parent) end
function UIDropDownMenu_Initialize(frame,fn) frame.initialize=fn end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText(frame,t) frame.text=t end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton() end
function UnitName() return "Tester" end
function time() return 10 end
local broadcasts=0
ZoneGate={DefaultTheme={name="Défaut",font="cinzel",customFont="",titleSize=28,titleColor={1,1,1},subColor={1,1,1},sepColor={1,1,1,1},bgColor={0,0,0,.5},frameColor={1,1,1,1},frameStyle="none",sepStyle="none",fadeIn=.4,hold=2.5,fadeOut=.8,bgEnabled=false,outline=false,uppercase=false,letterSpacing=false,midSepEnabled=false,soundEnter="",soundExit="",design="classic",motion="fade",placement="top",bannerWidth=600},FontPaths={cinzel="test.ttf"},FontLabels={cinzel="Cinzel",frizqt="Friz"},FontOrder={"cinzel"}}
local ZG=ZoneGate;local themes={};local count=0
function ZG:CreateTheme(name) count=count+1;local t=self.CopyTheme(self.DefaultTheme);t.id=tostring(count);t.creator="Tester";t.name=name;themes[t.id]=t;return t end
function ZG:GetTheme(id) return themes[id] end
function ZG:GetThemeList() local t={};for _,v in pairs(themes) do t[#t+1]=v end;return t end
function ZG:ScheduleBroadcast() broadcasts=broadcasts+1 end
function ZG:StyleThemeText(s) return s end
function ZG:RemoveTheme(id) themes[id]=nil end
function ZG:RenameTheme(id,name) self:GetTheme(id).name=name end
if InstallThemeSetters then InstallThemeSetters() end
dofile(root.."Studio.lua")
local a=ZG:CreateStudioTheme(ZG.StudioPresets[2]);assert(a.design=="western")
local b=ZG:CreateStudioTheme(nil,a);assert(b.id~=a.id and b.titleColor~=a.titleColor)
assert(ZG:SetStudioOption(a.id,"bannerWidth",2000));assert(a.bannerWidth==900)
assert(not ZG:SetStudioOption(a.id,"design","../../oops"))
b.creator="Other";assert(not ZG:RestoreStudioTheme(b.id,a))
themes[b.id]=nil
dofile(root.."UI_Banner.lua")
local renderer=ZG.CreateBannerRenderer(UIParent)
renderer:Configure("Lieu","Sous-zone",a)
assert(renderer:Seek(0)==5 and renderer.alpha==0)
renderer:Seek(a.fadeIn);assert(renderer.alpha==1)
renderer:Seek(100);assert(renderer.alpha==0)
ZG:ShowBanner("Lieu","",a);assert(ZoneGateBanner:IsShown())
renderer:HideBanner();assert(ZoneGateBanner:IsShown())
for _,p in ipairs(ZG.StudioPresets) do
    renderer:Configure(p.name,"",ZG:StudioPresetTheme(p));renderer:Seek(.3)
    assert(renderer.material and renderer.baseWidth>=600)
end
dofile(root.."UI_Style.lua")
dofile(root.."UI_Theme.lua")
local sizing=ZG:StudioPresetTheme(ZG.StudioPresets[2])
for _,preset in ipairs(ZG.StudioPresets) do
    local t=ZG:StudioPresetTheme(preset)
    t.titleSize=48
    renderer:Configure("Les Portes d'Astralune","Sanctuaire des anciens",t)
    local fullHeight=renderer.baseHeight
    assert(fullHeight>150,"Large two-line text needs vertical room")
    assert(renderer.textTop==(48+12+38)/2,"Text block must be vertically centered")
    renderer:Seek(t.fadeIn)
    assert(renderer.material.h==fullHeight,"Animation must preserve measured height")
    renderer:Configure("Lieu","",t)
    assert(renderer.textTop==24 and renderer.baseHeight<fullHeight,"No subtitle must leave no phantom gap")
end
renderer:Configure("Lieu","",sizing)
local shortWidth=renderer.baseWidth
renderer:Configure(string.rep("W",80),"",sizing)
assert(renderer.baseWidth>shortWidth,"Long title must expand the decoration")
renderer:Configure("Lieu",string.rep("W",120),sizing)
assert(renderer.baseWidth>shortWidth,"Long subtitle must expand the decoration")
renderer:Configure("Lieu","",sizing)
assert(renderer.baseWidth==shortWidth,"A later short title must restore the minimum width")
dofile(root.."UI_Studio.lua")
function M:SetFrameStrata(v) self.strata=v end
function M:SetFrameLevel(v) self.frameLevel=v end
function M:SetScale(v) self.scale=v end
ZoneGateThemePanel:EditTheme(a.id)
ZoneGateThemePanel.scripts.OnUpdate(ZoneGateThemePanel,.2)
assert(ZoneGateThemePanel.w==1280)
local function click(label)
 for _,o in ipairs(objects) do if o.kind=="Button" and o.text==label and o.scripts.OnClick then o.scripts.OnClick(o);return end end
 error("Missing button "..label)
end
ZG:SetStudioOption(a.id,"bannerWidth",500)
ZoneGateThemePanel.scripts.OnUpdate(ZoneGateThemePanel,.2)
click("Annuler");assert(a.bannerWidth==900)
click("Rétablir");assert(a.bannerWidth==500)
local liveWasShown=ZoneGateBanner:IsShown()
click("Voir en jeu")
local example=ZoneGateBannerExample
assert(example and example.strata=='TOOLTIP' and example.frameLevel==10000 and example.scale>1,'large preview above editor')
example.scripts.OnUpdate(example,1)
assert(example.alpha>0 and example:IsShown() and ZoneGateBanner:IsShown()==liveWasShown,'visible and isolated from live crossings')
example.scripts.OnUpdate(example,100);assert(not example:IsShown(),'example ends cleanly')
local beforeCount=#ZG:GetThemeList()
local beforeBroadcast=broadcasts
click("Dupliquer");assert(ZoneGateThemePanel.selectedId~=a.id)
local editor=ZG.ThemeEditor
local draft=editor.draft
assert(draft and not ZG:GetTheme(draft.id),'draft is outside the saved library')
assert(#ZG:GetThemeList()==beforeCount and broadcasts==beforeBroadcast,'duplicate starts only a draft')
editor:SetStudioOption(draft.id,'bannerWidth',650)
editor:RenameTheme(draft.id,'Mon brouillon')
if InstallThemeSetters then
 editor:SetThemeTitleSize(draft.id,38)
 editor:SetThemeColor(draft.id,'title',.2,.4,.6,1)
 editor:SetThemeOutline(draft.id,true)
 editor:SetThemeTiming(draft.id,.5,3,1)
 assert(draft.titleSize==38 and draft.titleColor[1]==.2 and draft.outline)
end
assert(a.bannerWidth==500 and broadcasts==beforeBroadcast,'draft edits cannot mutate or broadcast the source')
click('Créer le thème')
assert(not editor.draft and #ZG:GetThemeList()==beforeCount+1)
assert(ZG:GetTheme(ZoneGateThemePanel.selectedId).name=='Mon brouillon')
click('Créer le thème');assert(#ZG:GetThemeList()==beforeCount+1,'double validation does not duplicate')
-- Browsing multiple gallery templates and changing preview controls stays ephemeral.
local tile;for _,o in ipairs(objects) do if o.kind=='Button' and o.w==278 and o.h==72 then tile=o;break end end
beforeCount=#ZG:GetThemeList();beforeBroadcast=broadcasts
tile.scripts.OnClick(tile);local first=editor.draft.id
tile.scripts.OnClick(tile);assert(editor.draft.id~=first)
click('Pierre');click('Rejouer')
assert(#ZG:GetThemeList()==beforeCount and broadcasts==beforeBroadcast)
click('Abandonner le brouillon');assert(not editor.draft and #ZG:GetThemeList()==beforeCount)
ZoneGateThemePanel:BeginDraft()
editor:RenameTheme(editor.draft.id,'   ')
click('Créer le thème');assert(editor.draft and #ZG:GetThemeList()==beforeCount,'empty draft name is rejected')
ZoneGateThemePanel:Hide();assert(not editor.draft and #ZG:GetThemeList()==beforeCount,'closing discards the draft')
ZoneGateThemePanel:EditTheme(a.id)
assert( #ZG.StudioPresets==42,"All 42 presets must be available")
for i=1,7 do click(">") end
click("<")
if InstallSoundLibrary then
    InstallSoundLibrary()
    dofile(root.."Music/Manifest.lua")
    local choices
    function EasyMenu(menu) choices=menu end
    click("Sons")
    assert(#choices==13,"Sound menu must have 12 families and None")
    local total=0
    for i=2,#choices do
        assert(choices[i].hasArrow and #choices[i].menuList==6)
        for _,item in ipairs(choices[i].menuList) do
            item.func()
            assert(ZG:GetTheme(ZoneGateThemePanel.selectedId).soundEnter:match('omega_.*%.ogg$'))
            total=total+1
        end
    end
    assert(total==72)
    choices[1].func();assert(ZG:GetTheme(ZoneGateThemePanel.selectedId).soundEnter=="")
    table.insert(ZoneGateMusicManifest,"personal.ogg")
    click("Sons");assert(choices[#choices].text=="personal.ogg","Keep personal audio accessible")
    table.remove(ZoneGateMusicManifest)
    print("OK: 72 sound choices, 12 families, selection, clearing, personal audio")
end
ZoneGateThemePanel:Hide()
print("OK: syntax, 42 designs, adaptive height, gallery pagination, ownership, clone isolation, bounded settings, renderer timeline, isolated preview, editor startup, undo/redo, duplication")
