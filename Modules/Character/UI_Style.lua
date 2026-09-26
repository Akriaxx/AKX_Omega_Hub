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
local MEDIA="Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\"
-- Shared nine-slice frame, matching the HUD and skill cards. Corners never stretch.
function UI.ApplyBorder(frame)
    if frame.rpgBorder then return end
    frame.rpgBorder=true
    local cuts={0,24/128,104/128,1}
    local parts={};frame.rpgSkin=parts
    for row=1,3 do for col=1,3 do
        local tex=frame:CreateTexture(nil,"BACKGROUND",nil,2)
        tex:SetTexture(MEDIA.."SkillCard")
        tex:SetTexCoord(cuts[col],cuts[col+1],cuts[row],cuts[row+1])
        parts[#parts+1]=tex
    end end
    local function Layout()
        local w,h=frame:GetWidth() or 0,frame:GetHeight() or 0
        local k=math.max(1,math.min(12,w/2,h/2))
        local xs,ys={0,k,w-k,w},{0,k,h-k,h}
        for i,tex in ipairs(parts) do
            local row,col=math.floor((i-1)/3)+1,(i-1)%3+1
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT",frame,"TOPLEFT",xs[col],-ys[row])
            tex:SetPoint("BOTTOMRIGHT",frame,"TOPLEFT",xs[col+1],-ys[row+1])
        end
    end
    frame:HookScript("OnSizeChanged",Layout);Layout()
end
UI.windowSkins=setmetatable({}, {__mode="k"})
function UI.SetWindowSkinOpacity(frame,alpha)
    for _,part in ipairs(frame.rpgSkin or {}) do part:SetAlpha(alpha) end
end
function UI.RegisterWindowSkin(frame)
    UI.ApplyBorder(frame)
    UI.windowSkins[frame]=true
    local saved=CharacterDB and CharacterDB.settings and CharacterDB.settings.windowOpacity
    UI.SetWindowSkinOpacity(frame,saved or .65)
end
function UI.ApplyWindowBackground(texture,alpha)
    texture:SetColorTexture(0,0,0,0)
    local frame=texture:GetParent()
    UI.RegisterWindowSkin(frame)
    local saved=CharacterDB and CharacterDB.settings and CharacterDB.settings.windowOpacity
    UI.SetWindowSkinOpacity(frame,math.max(0,math.min(1,saved or alpha or .65)))
end
function UI.ApplyTitle(text) text:SetTextColor(.91,.80,.57,1) end
function UI.ApplySeparator(texture,soft) texture:SetColorTexture(.58,.46,.26,soft and .32 or .65) end
function UI.CreatePanelButton(parent,w,h,label)
    local button=CreateFrame("Button",nil,parent)
    button:SetSize(w,h)
    UI.ApplyBorder(button)
    local bg=button:CreateTexture(nil,"ARTWORK")
    bg:SetPoint("TOPLEFT",5,-4);bg:SetPoint("BOTTOMRIGHT",-5,4)
    bg:SetTexture(MEDIA.."Nexus\\NexusGlow");bg:SetBlendMode("ADD");bg:SetAlpha(.06)
    local text=button:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    text:SetPoint("LEFT",7,0);text:SetPoint("RIGHT",-7,0);text:SetJustifyH("CENTER")
    text:SetWordWrap(false);text:SetText(label);text:SetTextColor(.92,.84,.67,1)
    button:SetFontString(text)
    local accent=button:CreateTexture(nil,"BORDER");accent:SetPoint("BOTTOMLEFT",2,0);accent:SetPoint("BOTTOMRIGHT",-2,0);accent:SetHeight(1)
    accent:SetColorTexture(.65,.51,.29,0);button.accent=accent
    button:HookScript("OnEnter",function() bg:SetAlpha(.38) end)
    button:HookScript("OnLeave",function() bg:SetAlpha(.06) end)
    button:SetScript("OnDisable",function() text:SetAlpha(.35);bg:SetAlpha(0) end)
    button:SetScript("OnEnable",function() text:SetAlpha(1);bg:SetAlpha(.06) end)
    return button
end
function UI.CreateStyledCheckbox(parent,labelText)
    local button=CreateFrame("CheckButton",nil,parent)
    button:SetSize(18,18)
    local background=button:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints();background:SetColorTexture(0,0,0,0)
    UI.ApplyBorder(button)
    local check=button:CreateTexture(nil,"OVERLAY")
    check:SetPoint("CENTER");check:SetSize(8,8)
    check:SetTexture(MEDIA.."SkillCardGem");check:SetSize(9,14)
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
function UI.ApplyInputBorder(frame)
    if frame.rpgInputBorder then return end
    frame.rpgInputBorder=true
    local bg=frame:CreateTexture(nil,"BACKGROUND",nil,2)
    bg:SetAllPoints();bg:SetColorTexture(.012,.019,.028,.97)
    for _,edge in ipairs({"TOP","BOTTOM","LEFT","RIGHT"}) do
        local line=frame:CreateTexture(nil,"BORDER")
        line:SetColorTexture(.62,.49,.28,.9)
        if edge=="TOP" or edge=="BOTTOM" then
            line:SetPoint(edge.."LEFT");line:SetPoint(edge.."RIGHT");line:SetHeight(1)
        else
            line:SetPoint("TOP"..edge);line:SetPoint("BOTTOM"..edge);line:SetWidth(1)
        end
    end
end
function UI.CreateStyledEditBox(parent,w,h,multiLine)
    local box=CreateFrame("EditBox",nil,parent)
    box:SetSize(w,h or 22);box:SetFontObject("GameFontNormalSmall")
    box:SetTextColor(.91,.9,.84,1);box:SetAutoFocus(false);box:SetMultiLine(multiLine or false)
    box:SetMaxLetters(multiLine and 512 or 128);box:SetTextInsets(8,8,multiLine and 6 or 0,multiLine and 6 or 0)
    box:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    if not multiLine then box:SetScript("OnEnterPressed",function(self) self:ClearFocus() end) end
    UI.ApplyInputBorder(box)
    return box
end
function UI.ApplyTabState(button,active)
    if button.label then button.label:SetTextColor(active and .96 or .60,active and .82 or .66,active and .54 or .73) end
    if button.line then button.line:SetShown(active);button.line:SetColorTexture(.85,.68,.36,1) end
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

-- Bouton de fermeture rond (anneau doré, croix fine) : cartes ouvertes
-- depuis le chat et fenêtre « Utiliser ».
function UI.CreateCloseButton(parent,onClick)
    local close=CreateFrame("Button",nil,parent)
    close:SetSize(20,20)
    -- Default corner like the shared OS2.UI button; callers may re-anchor.
    close:SetPoint("TOPRIGHT",parent,"TOPRIGHT",-8,-8)
    local closeMask=close:CreateMaskTexture()
    closeMask:SetAllPoints()
    closeMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    local closeBg=close:CreateTexture(nil,"BACKGROUND")
    closeBg:SetAllPoints();closeBg:SetColorTexture(.025,.035,.055,1);closeBg:AddMaskTexture(closeMask)
    local closeRim=close:CreateTexture(nil,"ARTWORK")
    closeRim:SetAllPoints()
    closeRim:SetTexture("Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\InitiativeRing.tga")
    closeRim:SetVertexColor(.75,.64,.43,.85)
    local strokes={}
    for i=1,2 do
        local stroke=close:CreateTexture(nil,"OVERLAY")
        stroke:SetSize(9,1.4);stroke:SetPoint("CENTER")
        stroke:SetColorTexture(.88,.76,.52,1)
        stroke:SetRotation(i==1 and math.pi/4 or -math.pi/4)
        strokes[i]=stroke
    end
    close:SetScript("OnClick",onClick)
    local function CloseStyle(hover,pressed)
        closeBg:SetColorTexture(hover and .15 or .025,hover and .12 or .035,hover and .07 or .055,1)
        closeRim:SetVertexColor(hover and 1 or .75,hover and .9 or .64,hover and .65 or .43,1)
        for _,stroke in ipairs(strokes) do
            stroke:SetColorTexture(hover and 1 or .88,hover and .92 or .76,hover and .72 or .52,1)
            stroke:SetSize(pressed and 7 or 9,1.4)
        end
    end
    close:SetScript("OnEnter",function() CloseStyle(true,false) end)
    close:SetScript("OnLeave",function() CloseStyle(false,false) end)
    close:SetScript("OnMouseDown",function() CloseStyle(true,true) end)
    close:SetScript("OnMouseUp",function() CloseStyle(true,false) end)
    close:SetScript("OnHide",function() CloseStyle(false,false) end)
    return close
end


function Character:CreateRoundCloseButton(parent,onClick) return UI.CreateCloseButton(parent,onClick) end
