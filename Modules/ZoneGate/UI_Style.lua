-- Local editor skin: does not alter other modules or the in-world banners.
local Base=OS2.UI
local UI=setmetatable({}, {__index=Base})
ZoneGate.EditorUI=UI
UI.colors=setmetatable({
    rowBg={.025,.038,.052,.95},rowSelection={.22,.32,.39,.65},
    separator={.55,.44,.27,.9},separatorSoft={.34,.31,.24,.6},
}, {__index=Base.colors})
function UI.Surface(frame,soft)
    if frame.editorSurface then return end
    frame.editorSurface=true
    if not frame.bgN and not frame.bg then
        local bg=frame:CreateTexture(nil,"BACKGROUND")
        bg:SetAllPoints();bg:SetColorTexture(.025,.038,.052,soft and .92 or .98)
        frame.surfaceBg=bg
    end
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local t=frame:CreateTexture(nil,"BORDER")
        t:SetColorTexture(.57,.46,.28,soft and .4 or .85)
        if edge=="TOP" or edge=="BOTTOM" then
            t:SetPoint(edge.."LEFT");t:SetPoint(edge.."RIGHT");t:SetHeight(1)
        else
            t:SetPoint("TOP"..edge);t:SetPoint("BOTTOM"..edge);t:SetWidth(1)
        end
    end
end
function UI.ApplyWindowBackground(texture,alpha)
    texture:SetColorTexture(.019,.028,.041,alpha or .97)
end
function UI.CreatePanelButton(parent,w,h,label)
    local b=Base.CreatePanelButton(parent,w,h,label)
    if b.bgN then b.bgN:SetColorTexture(.035,.053,.073,.98) end
    if b.bgP then b.bgP:SetColorTexture(.12,.17,.21,1) end
    UI.Surface(b,true)
    return b
end
function UI.CreateStyledEditBox(parent,w,h,multi)
    local box=Base.CreateStyledEditBox(parent,w,h,multi)
    if box.bg then box.bg:SetColorTexture(.012,.020,.031,.98) end
    UI.Surface(box,true)
    return box
end

-- Menu déroulant maison (pas de menu Blizzard) : un champ cliquable et une
-- liste partagée au style de l'éditeur. select.items() renvoie
-- { {text=, value=, title=} } ; select.onSelect(value) reçoit le choix.
local MENU_ROW,MENU_MAX=28,10
local menu
local function Chevron(parent,right)
    local strokes={}
    for i=1,2 do
        local t=parent:CreateTexture(nil,"OVERLAY")
        t:SetSize(7,1.5);t:SetPoint("RIGHT",right-(i==1 and 5 or 0),0)
        t:SetRotation(i==1 and -math.pi/4 or math.pi/4)
        t:SetColorTexture(.91,.78,.5,1);strokes[i]=t
    end
    return strokes
end
local function Menu()
    if menu then return menu end
    menu=CreateFrame("Frame","ZoneGateSelectMenu",UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG");menu:SetClampedToScreen(true)
    menu:EnableMouse(true);menu:EnableMouseWheel(true);UI.Surface(menu);menu:Hide()
    -- Un clic n'importe où ailleurs referme la liste.
    local catcher=CreateFrame("Button",nil,UIParent)
    catcher:SetAllPoints(UIParent);catcher:SetFrameStrata("FULLSCREEN");catcher:Hide()
    catcher:SetScript("OnClick",function() menu:Hide() end)
    menu.catcher,menu.rows,menu.list,menu.offset=catcher,{},{},0
    menu.more=menu:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    menu.more:SetPoint("BOTTOMRIGHT",-10,6);UI.ApplyMutedText(menu.more)
    menu:SetScript("OnHide",function(self) catcher:Hide();self.owner,self.pick,self.current,self.width=nil,nil,nil,nil end)
    menu:SetScript("OnMouseWheel",function(self,delta)
        self.offset=math.max(0,math.min(math.max(0,#self.list-MENU_MAX),self.offset-delta))
        self:Render()
    end)
    function menu:Render()
        local owner=self.owner
        if not owner then return end
        local width=self.width or owner:GetWidth()
        for i=1,MENU_MAX do
            local row=self.rows[i]
            if not row then
                row=CreateFrame("Button",nil,self)
                row:SetHeight(MENU_ROW);row:SetPoint("TOPLEFT",4,-4-(i-1)*MENU_ROW)
                local hl=row:CreateTexture(nil,"HIGHLIGHT");hl:SetAllPoints();hl:SetColorTexture(.90,.78,.30,.14)
                row.mark=row:CreateTexture(nil,"ARTWORK");row.mark:SetSize(3,16);row.mark:SetPoint("LEFT",2,0)
                row.mark:SetColorTexture(.91,.78,.5,1)
                row.text=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
                row.text:SetPoint("LEFT",12,0);row.text:SetPoint("RIGHT",-8,0)
                row.text:SetJustifyH("LEFT");row.text:SetWordWrap(false)
                self.rows[i]=row
            end
            row:SetWidth(width-8)
            local item=self.list[i+self.offset]
            if item then
                row.text:SetText(item.text or "")
                local current=not item.title and self.current~=nil and item.text==self.current
                row.mark:SetShown(current)
                if item.title then UI.ApplyLabel(row.text) elseif current then UI.ApplyStrongLabel(row.text) else UI.ApplyBodyText(row.text) end
                row:EnableMouse(not item.title)
                row:SetScript("OnClick",function()
                    local pick=self.pick
                    self:Hide()
                    if pick then pick(item) end
                end)
                row:Show()
            else
                row:Hide()
            end
        end
        local shown=math.min(#self.list,MENU_MAX)
        self.more:SetText(#self.list>MENU_MAX and string.format("Molette · %d-%d sur %d",self.offset+1,self.offset+shown,#self.list) or "")
        self:SetSize(width,math.max(1,shown)*MENU_ROW+8+(#self.list>MENU_MAX and 18 or 0))
    end
    UISpecialFrames=UISpecialFrames or {};table.insert(UISpecialFrames,"ZoneGateSelectMenu")
    return menu
end
function UI.CreateSelect(parent,w,h)
    local s=CreateFrame("Button",nil,parent)
    s:SetSize(w,h or 30);UI.Surface(s,true)
    local hl=s:CreateTexture(nil,"HIGHLIGHT");hl:SetAllPoints();hl:SetColorTexture(.90,.78,.30,.08)
    s.label=s:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    s.label:SetPoint("LEFT",10,0);s.label:SetPoint("RIGHT",-34,0)
    s.label:SetJustifyH("LEFT");s.label:SetWordWrap(false);UI.ApplyBodyText(s.label)
    local divider=s:CreateTexture(nil,"ARTWORK")
    divider:SetSize(1,14);divider:SetPoint("RIGHT",-26,0);divider:SetColorTexture(.65,.51,.29,.4)
    local strokes=Chevron(s,-10)
    s.enabled=true
    function s:SetText(text) self.label:SetText(text or "") end
    function s:GetText() return self.label:GetText() end
    function s:SetEnabled(on)
        self.enabled=on and true or false
        self:EnableMouse(self.enabled)
        self.label:SetAlpha(self.enabled and 1 or .45)
        for _,t in ipairs(strokes) do t:SetAlpha(self.enabled and 1 or .3) end
    end
    s:SetScript("OnClick",function(self)
        local m=Menu()
        if m:IsShown() and m.owner==self then m:Hide();return end
        m.owner,m.list,m.offset=self,self.items and self.items() or {},0
        m.current=self.label:GetText()
        m.pick=function(item)
            self:SetText(item.text)
            if self.onSelect then self.onSelect(item.value) end
        end
        -- La liste vit sur UIParent : on reprend l'échelle du champ (fenêtre réduite).
        m:SetScale(self:GetEffectiveScale()/UIParent:GetEffectiveScale())
        m:ClearAllPoints();m:SetPoint("TOPLEFT",self,"BOTTOMLEFT",0,-2)
        m.catcher:Show();m:Show();m:Render()
    end)
    s:SetScript("OnHide",function(self) if menu and menu.owner==self then menu:Hide() end end)
    return s
end

-- Menu contextuel (clic droit) à la position du curseur, même liste que les
-- menus déroulants. items : { {text=, func=, title=} }.
function UI.OpenContextMenu(owner,items,width)
    local m=Menu()
    m:Hide()
    m.owner,m.list,m.offset,m.width=owner,items,0,width or 200
    m.pick=function(item) if item.func then item.func() end end
    m:SetScale(1)
    local x,y=GetCursorPosition()
    local scale=UIParent:GetEffectiveScale()
    m:ClearAllPoints();m:SetPoint("TOPLEFT",UIParent,"BOTTOMLEFT",x/scale,y/scale)
    m.catcher:Show();m:Show();m:Render()
    return m
end
