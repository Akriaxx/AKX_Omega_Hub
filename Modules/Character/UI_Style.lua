-- Character-only skin: never changes the shared UI used by other modules.
local Base=OS2.UI
local UI=setmetatable({}, {__index=Base})
Character.RPGUI=UI
UI.colors=setmetatable({
    rowBg={.028,.039,.055,.95},rowBgSelected={.075,.095,.125,.98},
    rowSelection={.72,.53,.22,.16},title={.91,.80,.57,1},
    text={.89,.88,.80,1},textMuted={.63,.66,.71,1},
    turnHighlight={.95,.76,.35,1},
    -- Vie en vert, Endurance en rouge dans tout Character (les autres
    -- modules gardent les couleurs partagées d'OS2.UI).
    statHP={fg={0.10,0.70,0.20,1},bg={0.03,0.16,0.05,1},label="HP"},
    statEnd={fg={0.85,0.15,0.15,1},bg={0.20,0.04,0.04,1},label="END"},
}, {__index=Base.colors})
function UI.ApplyBorder(frame)
    if frame.rpgBorder then return end
    frame.rpgBorder=true
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local line=frame:CreateTexture(nil,"BORDER")
        if edge=="TOP" or edge=="BOTTOM" then
            line:SetPoint(edge.."LEFT",frame,edge.."LEFT",0,0)
            line:SetPoint(edge.."RIGHT",frame,edge.."RIGHT",0,0);line:SetHeight(1)
        else
            line:SetPoint("TOP"..edge,frame,"TOP"..edge,0,0)
            line:SetPoint("BOTTOM"..edge,frame,"BOTTOM"..edge,0,0);line:SetWidth(1)
        end
        line:SetColorTexture(.52,.42,.25,.95)
    end
    local inset=frame:CreateTexture(nil,"BORDER")
    inset:SetPoint("TOPLEFT",3,-3);inset:SetPoint("TOPRIGHT",-3,-3);inset:SetHeight(1)
    inset:SetColorTexture(.85,.72,.45,.22)
end
function UI.ApplyWindowBackground(texture,alpha)
    texture:SetColorTexture(.018,.026,.039,math.max(0,math.min(1,alpha or .97)))
    local frame=texture:GetParent()
    UI.ApplyBorder(frame)
    if not frame.rpgHeading then
        frame.rpgHeading=true
        local band=frame:CreateTexture(nil,"BACKGROUND",nil,1)
        band:SetPoint("TOPLEFT",1,-1);band:SetPoint("TOPRIGHT",-1,-1);band:SetHeight(21)
        band:SetColorTexture(.045,.06,.08,.85)
        local rule=frame:CreateTexture(nil,"BORDER")
        rule:SetPoint("TOPLEFT",8,-22);rule:SetPoint("TOPRIGHT",-8,-22);rule:SetHeight(1)
        rule:SetColorTexture(.62,.48,.25,.55)
    end
end
function UI.ApplyTitle(text) text:SetTextColor(.91,.80,.57,1) end
function UI.ApplySeparator(texture,soft) texture:SetColorTexture(.58,.46,.26,soft and .32 or .65) end
function UI.CreatePanelButton(parent,w,h,label)
    local button=CreateFrame("Button",nil,parent)
    button:SetSize(w,h)
    local bg=button:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints()
    bg:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\ResourceFill.tga")
    bg:SetVertexColor(.06,.08,.11,1)
    local text=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetPoint("LEFT",4,0);text:SetPoint("RIGHT",-4,0);text:SetJustifyH("CENTER")
    text:SetWordWrap(false);text:SetText(label);text:SetTextColor(.92,.84,.67,1)
    button:SetFontString(text)
    local accent=button:CreateTexture(nil,"BORDER");accent:SetPoint("BOTTOMLEFT",2,0);accent:SetPoint("BOTTOMRIGHT",-2,0);accent:SetHeight(1)
    accent:SetColorTexture(.65,.51,.29,.7);button.accent=accent
    button:SetScript("OnEnter",function() bg:SetVertexColor(.13,.16,.20,1) end)
    button:SetScript("OnLeave",function() bg:SetVertexColor(.06,.08,.11,1) end)
    button:SetScript("OnDisable",function() text:SetAlpha(.35);bg:SetAlpha(.5) end)
    button:SetScript("OnEnable",function() text:SetAlpha(1);bg:SetAlpha(1) end)
    return button
end
function UI.CreateStyledCheckbox(parent,labelText)
    local button=CreateFrame("CheckButton",nil,parent)
    button:SetSize(18,18)
    local background=button:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints();background:SetColorTexture(.018,.026,.039,1)
    UI.ApplyBorder(button)
    local check=button:CreateTexture(nil,"OVERLAY")
    check:SetPoint("CENTER");check:SetSize(8,8)
    check:SetColorTexture(.85,.70,.42,1)
    button:SetCheckedTexture(check)
    local hover=button:CreateTexture(nil,"HIGHLIGHT")
    hover:SetAllPoints();hover:SetColorTexture(.65,.51,.29,.18)
    button:SetHighlightTexture(hover)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    label:SetText(labelText or "");label:SetTextColor(.89,.85,.74,1)
    label:SetPoint("LEFT",button,"RIGHT",5,0)
    button.label=label
    return button,label
end
function UI.CreateStyledEditBox(parent,w,h,multiLine)
    local box=Base.CreateStyledEditBox(parent,w,h,multiLine)
    local backing=box:CreateTexture(nil,"BACKGROUND")
    backing:SetAllPoints();backing:SetColorTexture(.015,.02,.023,.95)
    box:SetTextInsets(8,8,0,0)
    UI.ApplyBorder(box)
    return box
end
-- Every option remains visible; selecting one preserves the existing setters.
function UI.CreateChoiceStrip(parent,width,label,items,getValue,setValue)
    local holder=CreateFrame("Frame",nil,parent);holder:SetSize(width,label and 38 or 22)
    local title=holder:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    title:SetPoint("TOPLEFT",2,0);title:SetText(label or "");UI.ApplyTitle(title)
    local buttons={}
    local colors={hp={.43,.79,.48},mana={.30,.64,.95},endurance={.85,.28,.32}}
    function holder:Refresh()
        for i,button in ipairs(buttons) do
            local selected=getValue()==items[i].value
            button.selected:SetShown(selected)
            local col=colors[items[i].value] or {.95,.78,.45}
            button:GetFontString():SetTextColor(selected and col[1] or .65,selected and col[2] or .67,selected and col[3] or .65,1)
        end
    end
    for i,item in ipairs(items) do
        local button=UI.CreatePanelButton(holder,(width-8)/#items,22,item.label)
        button:SetPoint("TOPLEFT",(i-1)*((width-8)/#items+4),label and -16 or 0)
        local selected=button:CreateTexture(nil,"ARTWORK");selected:SetAllPoints();selected:SetColorTexture(.58,.44,.19,.25)
        button.selected=selected;buttons[i]=button
        button:SetScript("OnClick",function() setValue(item.value);holder:Refresh() end)
    end
    holder:Refresh()
    return holder
end
-- No resource labels, values or tooltips: ally health is intentionally private.
function UI.HealthMini(parent,y)
    local bar=CreateFrame("Frame",nil,parent)
    bar:SetPoint("TOPLEFT",parent,"TOPLEFT",6,y);bar:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-6,y);bar:SetHeight(10)
    local bg=bar:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(.025,.03,.03,1)
    local fill=bar:CreateTexture(nil,"ARTWORK");fill:SetPoint("TOPLEFT");fill:SetPoint("BOTTOMLEFT")
    fill:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\ResourceFill.tga");fill:SetVertexColor(.24,.65,.40,1)
    function bar:Refresh(stat)
        local width=math.max(1,self:GetWidth())
        local cur=stat and tonumber(stat.cur) or 0
        local maximum=math.max(1,stat and tonumber(stat.max) or 1)
        fill:SetWidth(math.max(.01,width*math.max(0,math.min(1,cur/maximum))));fill:SetShown(cur>0)
    end
    return bar
end
