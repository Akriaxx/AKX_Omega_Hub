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
