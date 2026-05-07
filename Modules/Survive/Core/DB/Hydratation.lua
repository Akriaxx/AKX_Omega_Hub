-- OmegaSurvive 2.0 — Builder Hydratation
OS2    = OS2    or {}
OS2.DB = OS2.DB or {}

-- ── Stockage ───────────────────────────────────────────────────────────
local function GetSystemList(typeKey)
    OS2.Core         = OS2.Core         or {}
    OS2.Core.Systems = OS2.Core.Systems or {}
    OS2.Core.Systems[typeKey] = OS2.Core.Systems[typeKey] or {}
    return OS2.Core.Systems[typeKey]
end

-- ── Clé auto-générée ──────────────────────────────────────────────────
local _seq = 0
local function GenerateKey(prefix, list)
    local base = prefix:upper():gsub("[^A-Z0-9]", ""):sub(1, 4)
    if #base == 0 then base = "SYS" end
    repeat
        _seq = _seq + 1
        local key = base .. string.format("%04d", _seq % 10000)
        local exists = false
        for _, e in ipairs(list) do
            if e.key == key then exists = true; break end
        end
        if not exists then return key end
    until false
end

-- ── Panel secondaire : création d'un sous-item (Nom + Description) ────
local subPanel = nil

local function GetOrCreateSubPanel()
    if subPanel then return subPanel end
    local UI   = OS2.UI or {}
    local SP_W = 280

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(SP_W, 170)
    p:SetFrameStrata("TOOLTIP")
    p:SetFrameLevel(110)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98)
    OS2.RegisterWindowFrame(p, bg)

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13)
    UI.ApplyTitle(titleStr)

    do
        local sep = p:CreateTexture(nil, "ARTWORK")
        UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, -36)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -36)
    end

    UI.CreateCloseButton(p, function() p:Hide() end)

    do
        local drag = CreateFrame("Frame", nil, p)
        drag:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, 0)
        drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        drag:SetHeight(36)
        OS2.MakeDraggable(p, drag)
    end

    local lblNom = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)
    lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)

    local nomEB = UI.CreateStyledEditBox(p, SP_W - 28, 22)
    nomEB:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -62)

    local lblDesc = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -96)
    lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)

    local descBox = CreateFrame("Frame", nil, p)
    descBox:SetSize(SP_W - 28, 36)
    descBox:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -112)
    local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints()
    descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
    descBorder:SetPoint("BOTTOMLEFT",  descBox, "BOTTOMLEFT",  2, 1)
    descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
    descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local descEB = CreateFrame("EditBox", nil, descBox)
    descEB:SetPoint("TOPLEFT",     descBox, "TOPLEFT",      6, -4)
    descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6,  4)
    descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local validBtn = UI.CreatePanelButton(p, SP_W - 28, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 14)

    local _cb = nil
    validBtn:SetScript("OnClick", function()
        local nom  = (nomEB:GetText()  or ""):match("^%s*(.-)%s*$")
        local desc = (descEB:GetText() or ""):match("^%s*(.-)%s*$")
        if nom == "" then return end
        if _cb then _cb({ label = nom, desc = desc }) end
        p:Hide()
    end)

    p.titleStr = titleStr
    p.nomEB    = nomEB
    p.descEB   = descEB
    p._open = function(title, item, cb)
        _cb = cb
        titleStr:SetText(title)
        nomEB:SetText(item  and item.label or "")
        descEB:SetText(item and item.desc  or "")
        p:Show(); nomEB:SetFocus()
    end

    subPanel = p
    return p
end

local function OpenSubPanel(title, item, cb)
    GetOrCreateSubPanel()._open(title, item, cb)
end

-- ── Panel Gourde : Nom + Contenance + Description + options ──────────
local gourdeSubPanel = nil

local function GetOrCreateGourdeSubPanel()
    if gourdeSubPanel then return gourdeSubPanel end
    local UI = OS2.UI or {}
    local GW = 300
    local GH = 380
    local PAD = 14
    local IW  = GW - PAD * 2   -- 272 px

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(GW, GH)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(111)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98); OS2.RegisterWindowFrame(p, bg)

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13); UI.ApplyTitle(titleStr)

    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, -36)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -36)
    end

    UI.CreateCloseButton(p, function() p:Hide() end)
    do
        local drag = CreateFrame("Frame", nil, p)
        drag:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, 0)
        drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        drag:SetHeight(36); OS2.MakeDraggable(p, drag)
    end

    -- Nom
    local lblNom = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -46)
    lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)

    local nomEB = UI.CreateStyledEditBox(p, IW, 22)
    nomEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -62)

    -- Contenance  (bottom nomEB = -84)
    local lblCont = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblCont:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -94)
    lblCont:SetText("Contenance"); UI.ApplyLabel(lblCont)

    local contEB = UI.CreateStyledEditBox(p, IW, 22)
    contEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -110)

    -- Description  (bottom contEB = -132)
    local lblDesc = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -142)
    lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)

    local descBox = CreateFrame("Frame", nil, p)
    descBox:SetSize(IW, 50)
    descBox:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -158)
    local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints()
    descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
    descBorder:SetPoint("BOTTOMLEFT",  descBox, "BOTTOMLEFT",  2, 1)
    descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
    descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local descEB = CreateFrame("EditBox", nil, descBox)
    descEB:SetPoint("TOPLEFT",     descBox, "TOPLEFT",      6, -4)
    descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6,  4)
    descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Séparateur  (descBox bottom = -208)
    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -218)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -218)
    end

    -- Recharge automatique : texte d'abord, coche ensuite
    local txtRecharge = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtRecharge:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -228)
    txtRecharge:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -228)
    txtRecharge:SetText("Si la gourde est capable de se recharger toute seule dans la nature.")
    txtRecharge:SetTextColor(0.65, 0.62, 0.55, 1); txtRecharge:SetJustifyH("LEFT")

    -- checkbox à ~-262 (texte ~32 px de haut)
    local chkRecharge, lblRecharge = UI.CreateStyledCheckbox(p, "Recharge automatique ?")
    chkRecharge:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -263)
    lblRecharge:SetPoint("LEFT", chkRecharge, "RIGHT", 6, 0)

    -- Filtre : texte d'abord, coche ensuite  (coche recharge bottom ≈ -281)
    local txtFiltre = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtFiltre:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -291)
    txtFiltre:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -291)
    txtFiltre:SetText("Si la gourde est capable de filtrer des eaux non potable.")
    txtFiltre:SetTextColor(0.65, 0.62, 0.55, 1); txtFiltre:SetJustifyH("LEFT")

    -- checkbox à ~-318 (texte ~26 px de haut)
    local chkFiltre, lblFiltre = UI.CreateStyledCheckbox(p, "Filtre ?")
    chkFiltre:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -320)
    lblFiltre:SetPoint("LEFT", chkFiltre, "RIGHT", 6, 0)

    -- Valider
    local validBtn = UI.CreatePanelButton(p, IW, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 14)

    local _cb = nil
    validBtn:SetScript("OnClick", function()
        local nom  = (nomEB:GetText()  or ""):match("^%s*(.-)%s*$")
        local cont = (contEB:GetText() or ""):match("^%s*(.-)%s*$")
        local desc = (descEB:GetText() or ""):match("^%s*(.-)%s*$")
        if nom == "" then return end
        if _cb then _cb({
            label        = nom,
            contenance   = cont,
            desc         = desc,
            rechargeAuto = chkRecharge:GetChecked() and true or false,
            filtre       = chkFiltre:GetChecked()   and true or false,
        }) end
        p:Hide()
    end)

    p._open = function(title, item, cb)
        _cb = cb
        titleStr:SetText(title)
        nomEB:SetText(item and item.label       or "")
        contEB:SetText(item and item.contenance or "")
        descEB:SetText(item and item.desc       or "")
        chkRecharge:SetChecked(item and item.rechargeAuto or false)
        chkFiltre:SetChecked(item and item.filtre         or false)
        p:Show(); nomEB:SetFocus()
    end

    gourdeSubPanel = p
    return p
end

local function OpenGourdeSubPanel(title, item, cb)
    GetOrCreateGourdeSubPanel()._open(title, item, cb)
end

-- ── Conditions d'aura disponibles ────────────────────────────────────
local AURA_CONDS = {
    { key = "always",     label = "Toujours (dès que bue)"          },
    { key = "unfiltered", label = "Si non filtrée"                  },
    { key = "unpurified", label = "Si non purifiée"                 },
    { key = "parasite",   label = "Si contient des parasites"       },
    { key = "salee",      label = "Si salée"                        },
}

-- ── Panel Aura tout-en-un (condition ◄► + aura + liste) ──────────────
local auraPanel = nil

local function GetOrCreateAuraPanel()
    if auraPanel then return auraPanel end
    local UI    = OS2.UI or {}
    local GW    = 300
    local GH    = 360
    local PAD   = 14
    local IW    = GW - PAD * 2          -- 272
    local SB_W2 = 8
    local SF_W2 = IW - SB_W2 - 2
    local ROW_H2  = 24
    local DEL_SZ2 = 16
    local LIST_H2 = GH - 36 - 110 - 14 - 22 - 14   -- ≈ 164

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(GW, GH)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(120)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98); OS2.RegisterWindowFrame(p, bg)

    do local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
       sep:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -36); sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -36) end

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13); UI.ApplyTitle(titleStr)

    UI.CreateCloseButton(p, function() p:Hide() end)
    do local drag = CreateFrame("Frame", nil, p)
       drag:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
       drag:SetHeight(36); OS2.MakeDraggable(p, drag) end

    -- ── Section ajout ────────────────────────────────────────────────
    -- Sélecteur de condition avec ◄ ►
    local condIdx = 1

    local btnPrev = CreateFrame("Button", nil, p); btnPrev:SetSize(22, 22)
    btnPrev:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -46)
    local bpBg = btnPrev:CreateTexture(nil, "BACKGROUND"); bpBg:SetAllPoints(); bpBg:SetColorTexture(0.12, 0.10, 0.06, 1)
    local bpHl = btnPrev:CreateTexture(nil, "HIGHLIGHT"); bpHl:SetAllPoints(); bpHl:SetColorTexture(0.85, 0.75, 0.40, 0.15)
    local bpLbl = btnPrev:CreateFontString(nil, "OVERLAY", "GameFontNormal"); bpLbl:SetAllPoints()
    bpLbl:SetText("◄"); bpLbl:SetTextColor(0.88, 0.78, 0.40, 1)

    local btnNext = CreateFrame("Button", nil, p); btnNext:SetSize(22, 22)
    btnNext:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -46)
    local bnBg = btnNext:CreateTexture(nil, "BACKGROUND"); bnBg:SetAllPoints(); bnBg:SetColorTexture(0.12, 0.10, 0.06, 1)
    local bnHl = btnNext:CreateTexture(nil, "HIGHLIGHT"); bnHl:SetAllPoints(); bnHl:SetColorTexture(0.85, 0.75, 0.40, 0.15)
    local bnLbl = btnNext:CreateFontString(nil, "OVERLAY", "GameFontNormal"); bnLbl:SetAllPoints()
    bnLbl:SetText("►"); bnLbl:SetTextColor(0.88, 0.78, 0.40, 1)

    local condLbl = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    condLbl:SetPoint("LEFT",  btnPrev, "RIGHT",  4, 0)
    condLbl:SetPoint("RIGHT", btnNext, "LEFT",  -4, 0)
    condLbl:SetJustifyH("CENTER"); condLbl:SetTextColor(0.88, 0.82, 0.65, 1)

    local function RefreshCond()
        local c = AURA_CONDS[condIdx] or AURA_CONDS[1]
        condLbl:SetText(c.label)
    end

    btnPrev:SetScript("OnClick", function()
        condIdx = condIdx > 1 and condIdx - 1 or #AURA_CONDS; RefreshCond()
    end)
    btnNext:SetScript("OnClick", function()
        condIdx = condIdx < #AURA_CONDS and condIdx + 1 or 1; RefreshCond()
    end)

    -- Champ aura
    local lblAura = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblAura:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -76)
    lblAura:SetText("Aura à appliquer"); UI.ApplyLabel(lblAura)

    local auraEB = UI.CreateStyledEditBox(p, IW, 22)
    auraEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -92)

    -- Bouton Ajouter
    local addBtn = UI.CreatePanelButton(p, IW, 22, "+ Ajouter la règle")
    addBtn:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -122)

    -- Séparateur
    do local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
       sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -152)
       sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -152) end

    -- ── Liste des règles ─────────────────────────────────────────────
    local sf = CreateFrame("ScrollFrame", nil, p)
    sf:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -160)
    sf:SetSize(SF_W2, LIST_H2); sf:EnableMouseWheel(true)

    local sbTrack = p:CreateTexture(nil, "BACKGROUND")
    sbTrack:SetColorTexture(0.07, 0.07, 0.07, 1); sbTrack:SetWidth(SB_W2)
    sbTrack:SetPoint("TOPLEFT",    sf, "TOPRIGHT", 2, 0)
    sbTrack:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)

    local sb = CreateFrame("Slider", nil, p)
    sb:SetPoint("TOPLEFT",    sf, "TOPRIGHT", 2, 0)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)
    sb:SetWidth(SB_W2); sb:SetOrientation("VERTICAL"); sb:SetMinMaxValues(0, 0); sb:SetValue(0)
    local thumb = sb:CreateTexture(nil, "THUMB"); thumb:SetSize(SB_W2-2, 24)
    thumb:SetColorTexture(0.5, 0.42, 0.22, 0.85); sb:SetThumbTexture(thumb)
    sf:SetScript("OnMouseWheel", function(_, d)
        sb:SetValue(math.max(0, math.min(select(2, sb:GetMinMaxValues()), sb:GetValue() - d*ROW_H2*3)))
    end)
    sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)

    local fermerBtn = UI.CreatePanelButton(p, IW, 22, "Fermer")
    fermerBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 14)
    fermerBtn:SetScript("OnClick", function() p:Hide() end)

    local _rules = nil

    local function RebuildRules()
        if sf._content then sf._content:Hide() end
        local c = CreateFrame("Frame", nil, sf)
        c:SetSize(SF_W2, 1); sf:SetScrollChild(c); sf:SetVerticalScroll(0); sf._content = c

        local y = 0
        for i, rule in ipairs(_rules or {}) do
            local condLabel = rule.condition or "?"
            for _, cd in ipairs(AURA_CONDS) do
                if cd.key == rule.condition then condLabel = cd.label; break end
            end
            local even = (i % 2 == 0)
            local rowBg = c:CreateTexture(nil, "BACKGROUND"); rowBg:SetHeight(ROW_H2)
            rowBg:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); rowBg:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
            rowBg:SetColorTexture(even and 0.09 or 0.06, even and 0.09 or 0.06, even and 0.09 or 0.06, 1)

            local txt = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            txt:SetPoint("TOPLEFT",  c, "TOPLEFT",  6, -(y+5))
            txt:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(4+DEL_SZ2+4), -(y+5))
            txt:SetJustifyH("LEFT")
            txt:SetText(condLabel .. "  →  " .. (rule.aura or "?"))
            txt:SetTextColor(0.85, 0.80, 0.65, 1)

            local delBtn = CreateFrame("Button", nil, c); delBtn:SetSize(DEL_SZ2, DEL_SZ2)
            delBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -(y + math.floor((ROW_H2-DEL_SZ2)/2)))
            local dBg = delBtn:CreateTexture(nil, "BACKGROUND"); dBg:SetAllPoints(); dBg:SetColorTexture(0.20, 0.07, 0.07, 1)
            local dLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); dLbl:SetAllPoints()
            dLbl:SetText("−"); dLbl:SetTextColor(0.80, 0.30, 0.30, 1)
            local dHl = delBtn:CreateTexture(nil, "HIGHLIGHT"); dHl:SetAllPoints(); dHl:SetColorTexture(0.75, 0.2, 0.2, 0.4)
            local di = i; delBtn:SetScript("OnClick", function() table.remove(_rules, di); RebuildRules() end)

            y = y + ROW_H2
        end
        c:SetHeight(math.max(1, y))
        local maxS = math.max(0, y - LIST_H2)
        sb:SetMinMaxValues(0, maxS); sb:SetAlpha(maxS > 0 and 1 or 0.2)
    end

    addBtn:SetScript("OnClick", function()
        local aura = (auraEB:GetText() or ""):match("^%s*(.-)%s*$")
        if aura == "" then return end
        local cond = AURA_CONDS[condIdx] or AURA_CONDS[1]
        _rules[#_rules + 1] = { condition = cond.key, aura = aura }
        auraEB:SetText("")
        RebuildRules()
    end)

    p._open = function(title, rules, srcFrame)
        titleStr:SetText(title)
        _rules  = rules
        condIdx = 1; RefreshCond()
        auraEB:SetText("")
        RebuildRules()
        -- Ancrer à droite du panel source, même hauteur
        p:ClearAllPoints()
        if srcFrame and srcFrame:IsShown() then
            p:SetPoint("TOPLEFT", srcFrame, "TOPRIGHT", 8, 0)
        else
            p:SetPoint("CENTER", UIParent, "CENTER", 160, 0)
        end
        p:Show()
    end

    auraPanel = p
    return p
end

local function OpenAuraPanel(title, rules, srcFrame)
    GetOrCreateAuraPanel()._open(title, rules, srcFrame)
end

-- ── Panel Source d'eau ────────────────────────────────────────────────
local sourceSubPanel = nil

local function GetOrCreateSourceSubPanel()
    if sourceSubPanel then return sourceSubPanel end
    local UI  = OS2.UI or {}
    local GW  = 300
    local GH  = 500
    local PAD = 14
    local IW  = GW - PAD * 2   -- 272 px

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(GW, GH)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(111)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98); OS2.RegisterWindowFrame(p, bg)

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13); UI.ApplyTitle(titleStr)

    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, -36)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -36)
    end

    UI.CreateCloseButton(p, function() p:Hide() end)
    do
        local drag = CreateFrame("Frame", nil, p)
        drag:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, 0)
        drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        drag:SetHeight(36); OS2.MakeDraggable(p, drag)
    end

    -- Nom
    local lblNom = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -46)
    lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)

    local nomEB = UI.CreateStyledEditBox(p, IW, 22)
    nomEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -62)

    -- Description  (bottom nomEB = -84)
    local lblDesc = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -94)
    lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)

    local descBox = CreateFrame("Frame", nil, p)
    descBox:SetSize(IW, 40)
    descBox:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -110)
    local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints()
    descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
    descBorder:SetPoint("BOTTOMLEFT",  descBox, "BOTTOMLEFT",  2, 1)
    descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
    descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local descEB = CreateFrame("EditBox", nil, descBox)
    descEB:SetPoint("TOPLEFT",     descBox, "TOPLEFT",      6, -4)
    descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6,  4)
    descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- Propreté  (descBox bottom = -150)
    local lblProp = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblProp:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -160)
    lblProp:SetText("Propreté de l'eau  (0 – 100)"); UI.ApplyLabel(lblProp)

    local propEB = UI.CreateStyledEditBox(p, 80, 22)
    propEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -176)
    propEB:SetNumeric(true); propEB:SetMaxLetters(3)
    propEB:SetScript("OnEditFocusLost", function(self)
        local v = tonumber(self:GetText()) or 0
        self:SetText(tostring(math.max(0, math.min(100, v))))
    end)

    -- Séparateur  (bottom propEB = -198)
    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -208)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -208)
    end

    -- Parasite (texte → coche)
    local txtParasite = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtParasite:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -218)
    txtParasite:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -218)
    txtParasite:SetText("L'eau contient des parasites pouvant infecter le consommateur.")
    txtParasite:SetTextColor(0.65, 0.62, 0.55, 1); txtParasite:SetJustifyH("LEFT")

    local chkParasite, lblParasite = UI.CreateStyledCheckbox(p, "Parasite ?")
    chkParasite:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -250)
    lblParasite:SetPoint("LEFT", chkParasite, "RIGHT", 6, 0)

    -- Peut rendre malade (texte → coche)  (bottom chkParasite ≈ -268)
    local txtMalade = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txtMalade:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -276)
    txtMalade:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -276)
    txtMalade:SetText("La consommation de cette eau peut rendre malade.")
    txtMalade:SetTextColor(0.65, 0.62, 0.55, 1); txtMalade:SetJustifyH("LEFT")

    local chkMalade, lblMalade = UI.CreateStyledCheckbox(p, "Peut rendre malade ?")
    chkMalade:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -300)
    lblMalade:SetPoint("LEFT", chkMalade, "RIGHT", 6, 0)

    -- Séparateur  (bottom chkMalade ≈ -318)
    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -326)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -326)
    end

    -- Options simples (coches sans texte descriptif)
    local chkSalee, lblSalee = UI.CreateStyledCheckbox(p, "Salée ?")
    chkSalee:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -336)
    lblSalee:SetPoint("LEFT", chkSalee, "RIGHT", 6, 0)

    local chkFiltrage, lblFiltrage = UI.CreateStyledCheckbox(p, "Nécessite filtrage ?")
    chkFiltrage:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -358)
    lblFiltrage:SetPoint("LEFT", chkFiltrage, "RIGHT", 6, 0)

    -- Séparateur Aura  (chkFiltrage bottom ≈ -376)
    do local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
       sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -384)
       sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -384) end

    local chkAura, lblAura = UI.CreateStyledCheckbox(p, "Aura ?")
    chkAura:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -394)
    lblAura:SetPoint("LEFT", chkAura, "RIGHT", 6, 0)

    -- Bouton "Configurer les auras →" (visible seulement si chkAura coché)
    local cfgAuraBtn = UI.CreatePanelButton(p, IW, 22, "Configurer les auras  →")
    cfgAuraBtn:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -418)
    cfgAuraBtn:Hide()

    chkAura:SetScript("OnClick", function(self)
        cfgAuraBtn:SetShown(self:GetChecked() and true or false)
    end)

    -- Valider
    local validBtn = UI.CreatePanelButton(p, IW, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 14)

    local _cb        = nil
    local _auraRules = {}

    cfgAuraBtn:SetScript("OnClick", function()
        OpenAuraPanel("Règles d'Aura", _auraRules, p)
    end)

    validBtn:SetScript("OnClick", function()
        local nom  = (nomEB:GetText()  or ""):match("^%s*(.-)%s*$")
        if nom == "" then return end
        local prop = math.max(0, math.min(100, tonumber(propEB:GetText()) or 0))
        local desc = (descEB:GetText() or ""):match("^%s*(.-)%s*$")
        if _cb then _cb({
            label       = nom,
            desc        = desc,
            proprete    = prop,
            parasite    = chkParasite:GetChecked() and true or false,
            malade      = chkMalade:GetChecked()   and true or false,
            salee       = chkSalee:GetChecked()    and true or false,
            filtrage    = chkFiltrage:GetChecked() and true or false,
            auraEnabled = chkAura:GetChecked()     and true or false,
            auraRules   = _auraRules,
        }) end
        p:Hide()
    end)

    p._open = function(title, item, cb)
        _cb = cb
        -- Copie des règles d'aura pour ne pas modifier l'original tant que Valider n'est pas cliqué
        _auraRules = {}
        for _, r in ipairs(item and item.auraRules or {}) do
            _auraRules[#_auraRules + 1] = { condition = r.condition, aura = r.aura }
        end
        titleStr:SetText(title)
        nomEB:SetText(item and item.label or "")
        descEB:SetText(item and item.desc  or "")
        propEB:SetText(tostring(item and item.proprete or 100))
        chkParasite:SetChecked(item and item.parasite    or false)
        chkMalade:SetChecked(item   and item.malade      or false)
        chkSalee:SetChecked(item    and item.salee       or false)
        chkFiltrage:SetChecked(item and item.filtrage    or false)
        local auraOn = item and item.auraEnabled or false
        chkAura:SetChecked(auraOn)
        cfgAuraBtn:SetShown(auraOn)
        p:Show(); nomEB:SetFocus()
    end

    sourceSubPanel = p
    return p
end

local function OpenSourceSubPanel(title, item, cb)
    GetOrCreateSourceSubPanel()._open(title, item, cb)
end

-- ── Helper : scroll-list avec [Éditer] et [−] ─────────────────────────
local ROW_H_SUB = 22
local DEL_SZ    = 16
local LINK_W    = 36
local LABEL_RSV = 4 + DEL_SZ + 4 + LINK_W + 4

local function BuildSubList(sf, sb, listH, list, onEdit, onDelete, editBtnPool, showEdit)
    if sf._content then sf._content:Hide() end
    local cW = math.max(math.floor(sf:GetWidth()), 10)
    local c  = CreateFrame("Frame", nil, sf)
    c:SetSize(cW, 1); sf:SetScrollChild(c); sf:SetVerticalScroll(0); sf._content = c

    local y = 0
    for i, entry in ipairs(list) do
        local even = (math.floor(y / ROW_H_SUB) % 2 == 0)
        local rowBg = c:CreateTexture(nil, "BACKGROUND"); rowBg:SetHeight(ROW_H_SUB)
        rowBg:SetPoint("TOPLEFT",  c, "TOPLEFT",  0, -y)
        rowBg:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        rowBg:SetColorTexture(even and 0.09 or 0.06, even and 0.09 or 0.06, even and 0.09 or 0.06, 1)

        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT",  c, "TOPLEFT",  6,          -(y + 4))
        lbl:SetPoint("TOPRIGHT", c, "TOPRIGHT", -LABEL_RSV, -(y + 4))
        lbl:SetJustifyH("LEFT"); lbl:SetText(entry.label); lbl:SetTextColor(0.85, 0.80, 0.65, 1)

        local btnY = y + math.floor((ROW_H_SUB - DEL_SZ) / 2)

        local modBtn = CreateFrame("Button", nil, c)
        modBtn:SetSize(LINK_W, DEL_SZ)
        modBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(4 + DEL_SZ + 4), -btnY)
        local mBg = modBtn:CreateTexture(nil, "BACKGROUND"); mBg:SetAllPoints(); mBg:SetColorTexture(0.18, 0.14, 0.04, 1)
        local mLbl = modBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); mLbl:SetAllPoints()
        mLbl:SetText("Éditer"); mLbl:SetTextColor(0.95, 0.80, 0.20, 1)
        local mHl = modBtn:CreateTexture(nil, "HIGHLIGHT"); mHl:SetAllPoints(); mHl:SetColorTexture(1, 0.85, 0.2, 0.2)
        local ci = i; modBtn:SetScript("OnClick", function() onEdit(ci) end)
        modBtn:SetShown(showEdit and true or false)
        if editBtnPool then editBtnPool[#editBtnPool + 1] = modBtn end

        local delBtn = CreateFrame("Button", nil, c)
        delBtn:SetSize(DEL_SZ, DEL_SZ)
        delBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -btnY)
        local dBg = delBtn:CreateTexture(nil, "BACKGROUND"); dBg:SetAllPoints(); dBg:SetColorTexture(0.20, 0.07, 0.07, 1)
        local dLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); dLbl:SetAllPoints()
        dLbl:SetText("−"); dLbl:SetTextColor(0.80, 0.30, 0.30, 1)
        local dHl = delBtn:CreateTexture(nil, "HIGHLIGHT"); dHl:SetAllPoints(); dHl:SetColorTexture(0.75, 0.2, 0.2, 0.4)
        delBtn:SetShown(showEdit and true or false)
        if editBtnPool then editBtnPool[#editBtnPool + 1] = delBtn end
        local di = i; delBtn:SetScript("OnClick", function() onDelete(di) end)

        y = y + ROW_H_SUB
    end

    c:SetHeight(math.max(1, y))
    local maxS = math.max(0, y - listH)
    sb:SetMinMaxValues(0, maxS); sb:SetAlpha(maxS > 0 and 1 or 0.2)
end

-- ── Panel Fonctionnement / Règles (Hydratation) ──────────────────────
local reglesPanel = nil

local function GetOrCreateReglesPanel()
    if reglesPanel then return reglesPanel end
    local UI  = OS2.UI or {}
    local GW  = 360
    local GH  = 530
    local PAD = 14
    local IW  = GW - PAD * 2        -- 332
    local ROW = 26                   -- hauteur d'une ligne

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(GW, GH)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(115)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98); OS2.RegisterWindowFrame(p, bg)

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13); UI.ApplyTitle(titleStr)

    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, -36)
        sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -36)
    end

    UI.CreateCloseButton(p, function() p:Hide() end)
    do
        local drag = CreateFrame("Frame", nil, p)
        drag:SetPoint("TOPLEFT",  p, "TOPLEFT",  0, 0)
        drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        drag:SetHeight(36); OS2.MakeDraggable(p, drag)
    end

    -- ── Helper : bouton toggle (%/Brut, etc.) ───────────────────────────
    local function MakeToggle(x, y, w, h, options)
        local tidx = 1
        local btn  = CreateFrame("Button", nil, p)
        btn:SetSize(w, h)
        btn:SetPoint("TOPLEFT", p, "TOPLEFT", x, -y)
        local tBg = btn:CreateTexture(nil,"BACKGROUND"); tBg:SetAllPoints(); tBg:SetColorTexture(0.12,0.10,0.05,1)
        local tBd = btn:CreateTexture(nil,"ARTWORK"); tBd:SetHeight(1)
        tBd:SetPoint("BOTTOMLEFT",  btn,"BOTTOMLEFT",  2, 1)
        tBd:SetPoint("BOTTOMRIGHT", btn,"BOTTOMRIGHT", -2, 1)
        tBd:SetColorTexture(0.70,0.60,0.25,0.80)
        local tHl = btn:CreateTexture(nil,"HIGHLIGHT"); tHl:SetAllPoints(); tHl:SetColorTexture(0.8,0.7,0.3,0.12)
        local tLbl = btn:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); tLbl:SetAllPoints()
        tLbl:SetTextColor(0.92,0.84,0.50,1)
        local function Refresh() tLbl:SetText(options[tidx] or "?") end
        btn:SetScript("OnClick", function() tidx = tidx < #options and tidx+1 or 1; Refresh() end)
        Refresh()
        return {
            GetValue = function() return options[tidx] end,
            SetValue = function(v)
                for i, o in ipairs(options) do if o == v then tidx = i; break end end
                Refresh()
            end,
        }
    end

    -- ── Helper : separateur ──────────────────────────────────────────────
    local function Sep(y)
        local s = p:CreateTexture(nil,"ARTWORK"); UI.ApplySeparator(s); s:SetHeight(1)
        s:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -(y+4))
        s:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -(y+4))
    end

    -- ── Layout ───────────────────────────────────────────────────────────
    local y = 46

    -- § Déclencheurs de consommation ─────────────────────────────────────
    local lblDec = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lblDec:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblDec:SetText("Consommation : Gourde."); UI.ApplyStrongLabel(lblDec)
    y = y + 20

    -- Temps écoulé  [valeur] [% | Brut]  / toutes les [freq] min
    local TX_VAL  = 196   -- x : editbox valeur
    local TX_TGL  = 234   -- x : toggle %/Brut
    local TX_FREQ = 292   -- x : editbox fréquence
    local TX_MIN  = 330   -- x : label "min"

    local chkTemps, lblTemps = UI.CreateStyledCheckbox(p, "Temps écoulé")
    chkTemps:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblTemps:SetPoint("LEFT", chkTemps, "RIGHT", 6, 0)
    local tempsEB = UI.CreateStyledEditBox(p, 34, 18)
    tempsEB:SetPoint("TOPLEFT", p, "TOPLEFT", TX_VAL, -(y+1))
    tempsEB:SetNumeric(true); tempsEB:SetMaxLetters(4)
    local tempsTypeTgl = MakeToggle(TX_TGL, y+1, 54, 18, {"%", "Brut"})
    local tempsFreqEB  = UI.CreateStyledEditBox(p, 34, 18)
    tempsFreqEB:SetPoint("TOPLEFT", p, "TOPLEFT", TX_FREQ, -(y+1))
    tempsFreqEB:SetNumeric(true); tempsFreqEB:SetMaxLetters(3)
    local tempsMinLbl = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    tempsMinLbl:SetPoint("TOPLEFT", p, "TOPLEFT", TX_MIN, -(y-2))
    tempsMinLbl:SetText("min"); tempsMinLbl:SetTextColor(0.50,0.48,0.40,1)
    y = y + ROW

    -- Par action  [valeur] [% | Brut]
    local chkAction, lblAction = UI.CreateStyledCheckbox(p, "Par action")
    chkAction:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblAction:SetPoint("LEFT", chkAction, "RIGHT", 6, 0)
    local actionEB = UI.CreateStyledEditBox(p, 34, 18)
    actionEB:SetPoint("TOPLEFT", p, "TOPLEFT", TX_VAL, -(y+1))
    actionEB:SetNumeric(true); actionEB:SetMaxLetters(4)
    local actionTypeTgl = MakeToggle(TX_TGL, y+1, 54, 18, {"%", "Brut"})
    y = y + ROW

    -- Température (simple coche)
    local chkTmp, lblTmp = UI.CreateStyledCheckbox(p, "Température")
    chkTmp:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblTmp:SetPoint("LEFT", chkTmp, "RIGHT", 6, 0)
    y = y + ROW

    -- Statistique (simple coche)
    local chkConsti, lblConsti = UI.CreateStyledCheckbox(p, "Statistique")
    chkConsti:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblConsti:SetPoint("LEFT", chkConsti, "RIGHT", 6, 0)
    y = y + ROW

    Sep(y); y = y + 16

    -- § Capacité d'hydratation ────────────────────────────────────────────
    local lblCap = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lblCap:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblCap:SetText("Capacité d'hydratation"); UI.ApplyStrongLabel(lblCap)
    y = y + 20

    -- Valeur brute de base (activable)
    local chkCapBase, lblCapBase = UI.CreateStyledCheckbox(p, "Valeur de base")
    chkCapBase:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblCapBase:SetPoint("LEFT", chkCapBase, "RIGHT", 6, 0)

    local capEB = UI.CreateStyledEditBox(p, 60, 18)
    capEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD+104, -(y+1))
    capEB:SetNumeric(true); capEB:SetMaxLetters(6)

    local capUnit = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    capUnit:SetPoint("TOPLEFT", p, "TOPLEFT", PAD+168, -(y-2))
    capUnit:SetText("ml"); capUnit:SetTextColor(0.50,0.48,0.40,1)

    local capHint = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    capHint:SetPoint("TOPLEFT", p, "TOPLEFT", PAD+186, -(y-2))
    capHint:SetText("≈ 2,5 L / jour"); capHint:SetTextColor(0.42,0.40,0.32,1)
    y = y + 26

    -- Coche : dépend d'une statistique ?
    local chkStatDep, lblStatDep = UI.CreateStyledCheckbox(p, "Modifiée par une statistique ?")
    chkStatDep:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblStatDep:SetPoint("LEFT", chkStatDep, "RIGHT", 6, 0)
    y = y + 26

    -- Groupe formule (label + zone + hint) — affiché/masqué selon coche
    local lblFormule = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lblFormule:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblFormule:SetText("Formule de modification"); UI.ApplyLabel(lblFormule)
    y = y + 16

    local formBox = CreateFrame("Frame", nil, p)
    formBox:SetSize(IW, 46)
    formBox:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    local fmBg = formBox:CreateTexture(nil,"BACKGROUND"); fmBg:SetAllPoints()
    fmBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local fmBd = formBox:CreateTexture(nil,"ARTWORK"); fmBd:SetHeight(1)
    fmBd:SetPoint("BOTTOMLEFT",  formBox,"BOTTOMLEFT",  2, 1)
    fmBd:SetPoint("BOTTOMRIGHT", formBox,"BOTTOMRIGHT", -2, 1)
    fmBd:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local formEB = CreateFrame("EditBox", nil, formBox)
    formEB:SetPoint("TOPLEFT",     formBox,"TOPLEFT",      6, -4)
    formEB:SetPoint("BOTTOMRIGHT", formBox,"BOTTOMRIGHT", -6,  4)
    formEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(formEB)
    formEB:SetAutoFocus(false); formEB:SetMultiLine(true); formEB:SetMaxLetters(256)
    formEB:SetJustifyH("LEFT"); formEB:SetJustifyV("TOP")
    formEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    y = y + 52

    local hintLbl = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    hintLbl:SetPoint("TOPLEFT",  p, "TOPLEFT",  PAD,  -y)
    hintLbl:SetPoint("TOPRIGHT", p, "TOPRIGHT", -PAD, -y)
    hintLbl:SetText("ex. : { Force + Constitution = (VALUE × 4) }")
    hintLbl:SetTextColor(0.45, 0.43, 0.35, 1); hintLbl:SetJustifyH("LEFT")
    y = y + 18

    -- Afficher/masquer le groupe formule selon la coche
    local formulaGroup = { lblFormule, formBox, hintLbl }
    local function RefreshStatDep()
        local on = chkStatDep:GetChecked() and true or false
        for _, w in ipairs(formulaGroup) do w:SetShown(on) end
    end
    chkStatDep:SetScript("OnClick", RefreshStatDep)

    Sep(y); y = y + 16

    -- § Comportement à vide ───────────────────────────────────────────────
    local lblComp = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lblComp:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)
    lblComp:SetText("Comportement à vide"); UI.ApplyStrongLabel(lblComp)
    y = y + 20

    local lblMsg = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lblMsg:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y); lblMsg:SetText("Message"); UI.ApplyLabel(lblMsg)
    y = y + 16
    local msgEB = UI.CreateStyledEditBox(p, IW, 18)
    msgEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y); y = y + 28

    local lblDb = p:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    lblDb:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y); lblDb:SetText("Debuff (sort / ID)"); UI.ApplyLabel(lblDb)
    y = y + 16
    local debuffEB = UI.CreateStyledEditBox(p, IW, 18)
    debuffEB:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, -y)

    -- ── Valider ──────────────────────────────────────────────────────────
    local _cb = nil
    local validBtn = UI.CreatePanelButton(p, IW, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", PAD, 14)
    validBtn:SetScript("OnClick", function()
        if _cb then _cb({
            tempsEcoule  = { enabled  = chkTemps:GetChecked()  and true or false,
                             valeur   = tonumber(tempsEB:GetText())     or 1,
                             type     = tempsTypeTgl.GetValue(),
                             frequence= tonumber(tempsFreqEB:GetText()) or 30 },
            parAction    = { enabled  = chkAction:GetChecked() and true or false,
                             valeur   = tonumber(actionEB:GetText())    or 1,
                             type     = actionTypeTgl.GetValue() },
            temperature  = { enabled  = chkTmp:GetChecked()    and true or false },
            statistique  = { enabled  = chkConsti:GetChecked() and true or false },
            capacite     = { baseEnabled = chkCapBase:GetChecked() and true or false,
                             base        = tonumber(capEB:GetText()) or 2500,
                             statDep     = chkStatDep:GetChecked() and true or false,
                             formule     = (formEB:GetText() or ""):match("^%s*(.-)%s*$") },
            messageVide  = (msgEB:GetText()    or ""):match("^%s*(.-)%s*$"),
            debuffVide   = (debuffEB:GetText() or ""):match("^%s*(.-)%s*$"),
        }) end
        p:Hide()
    end)

    p._open = function(title, fonct, cb)
        _cb = cb
        titleStr:SetText(title or "Fonctionnement")
        local f  = fonct or {}
        local ft = f.tempsEcoule or {}
        local fa = f.parAction   or {}
        local ftp= f.temperature or {}
        local fco= f.statistique or {}
        local fc = f.capacite    or {}
        chkTemps:SetChecked(ft.enabled   or false)
        tempsEB:SetText(tostring(ft.valeur    or 1))
        tempsTypeTgl.SetValue(ft.type         or "%")
        tempsFreqEB:SetText(tostring(ft.frequence or 30))
        chkAction:SetChecked(fa.enabled  or false)
        actionEB:SetText(tostring(fa.valeur or 1))
        actionTypeTgl.SetValue(fa.type    or "%")
        chkTmp:SetChecked(ftp.enabled    or false)
        chkConsti:SetChecked(fco.enabled or false)
        chkCapBase:SetChecked(fc.baseEnabled or false)
        capEB:SetText(tostring(fc.base or 2500))
        chkStatDep:SetChecked(fc.statDep or false)
        formEB:SetText(fc.formule or "")
        RefreshStatDep()
        msgEB:SetText(f.messageVide  or "")
        debuffEB:SetText(f.debuffVide or "")
        p:Show()
    end

    reglesPanel = p
    return p
end

local function OpenReglesPanel(title, fonct, cb)
    GetOrCreateReglesPanel()._open(title, fonct, cb)
end

-- ── Panel principal Hydratation ───────────────────────────────────────
local hydratationPanel = nil

local function GetOrCreateHydratationPanel()
    if hydratationPanel then return hydratationPanel end

    local UI     = OS2.UI or {}
    local TOT_W  = 490
    local LEFT_W = 210
    local RIGHT_W= 240
    local LEFT_X = 14
    local RIGHT_X= LEFT_X + LEFT_W + 12
    local TOT_H  = 420
    local HDR_H  = 36
    local SEC_H  = math.floor((TOT_H - HDR_H - 14) / 2)
    local SB_W   = 8

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(TOT_W, TOT_H)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(100)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98); OS2.RegisterWindowFrame(p, bg)

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13); UI.ApplyTitle(titleStr)

    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -HDR_H); sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -HDR_H)
    end

    UI.CreateCloseButton(p, function() p:Hide() end)

    do
        local drag = CreateFrame("Frame", nil, p)
        drag:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        drag:SetHeight(HDR_H); OS2.MakeDraggable(p, drag)
    end

    local vSep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(vSep, true); vSep:SetWidth(1)
    vSep:SetPoint("TOP",    p, "TOPLEFT", LEFT_X + LEFT_W + 6, -HDR_H)
    vSep:SetPoint("BOTTOM", p, "BOTTOMLEFT", LEFT_X + LEFT_W + 6, 14)

    -- ── SECTION GAUCHE HAUTE : Gourdes ────────────────────────────────
    local SEC_TOP_Y  = -(HDR_H + 6)
    local LIST_H_SUB = SEC_H - 26

    local lblGourdes = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblGourdes:SetPoint("TOPLEFT", p, "TOPLEFT", LEFT_X, SEC_TOP_Y)
    lblGourdes:SetText("Gourdes"); UI.ApplyStrongLabel(lblGourdes)

    local addGourdeBtn = UI.CreateAddButton(p, function() end)
    addGourdeBtn:SetPoint("TOPRIGHT", p, "TOPLEFT", LEFT_X + LEFT_W, SEC_TOP_Y + 2)
    addGourdeBtn:Hide()

    local gourdesSF = CreateFrame("ScrollFrame", nil, p)
    gourdesSF:SetPoint("TOPLEFT", p, "TOPLEFT", LEFT_X, SEC_TOP_Y - 18)
    gourdesSF:SetSize(LEFT_W - SB_W - 4, LIST_H_SUB)
    gourdesSF:EnableMouseWheel(true)

    local gourdesSB = CreateFrame("Slider", nil, p)
    gourdesSB:SetPoint("TOPLEFT",    gourdesSF, "TOPRIGHT",    2, 0)
    gourdesSB:SetPoint("BOTTOMLEFT", gourdesSF, "BOTTOMRIGHT", 2, 0)
    gourdesSB:SetWidth(SB_W); gourdesSB:SetOrientation("VERTICAL")
    gourdesSB:SetMinMaxValues(0, 0); gourdesSB:SetValue(0)
    local gt = gourdesSB:CreateTexture(nil, "THUMB"); gt:SetSize(SB_W - 2, 24); gt:SetColorTexture(0.5, 0.42, 0.22, 0.85); gourdesSB:SetThumbTexture(gt)
    gourdesSF:SetScript("OnMouseWheel", function(_, d) gourdesSB:SetValue(math.max(0, math.min(select(2, gourdesSB:GetMinMaxValues()), gourdesSB:GetValue() - d * ROW_H_SUB * 2))) end)
    gourdesSB:SetScript("OnValueChanged", function(_, v) gourdesSF:SetVerticalScroll(v) end)

    -- ── Séparateur horizontal ──────────────────────────────────────────
    local hSep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(hSep, true); hSep:SetHeight(1)
    local hSepY = SEC_TOP_Y - SEC_H
    hSep:SetPoint("TOPLEFT",  p, "TOPLEFT", LEFT_X,          hSepY)
    hSep:SetPoint("TOPRIGHT", p, "TOPLEFT", LEFT_X + LEFT_W, hSepY)

    -- ── SECTION GAUCHE BASSE : Types d'eau ────────────────────────────
    local SEC_BOT_Y = hSepY - 8

    local lblSources = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblSources:SetPoint("TOPLEFT", p, "TOPLEFT", LEFT_X, SEC_BOT_Y)
    lblSources:SetText("Types d'eau"); UI.ApplyStrongLabel(lblSources)

    local addSourceBtn = UI.CreateAddButton(p, function() end)
    addSourceBtn:SetPoint("TOPRIGHT", p, "TOPLEFT", LEFT_X + LEFT_W, SEC_BOT_Y + 2)
    addSourceBtn:Hide()

    local sourcesSF = CreateFrame("ScrollFrame", nil, p)
    sourcesSF:SetPoint("TOPLEFT", p, "TOPLEFT", LEFT_X, SEC_BOT_Y - 18)
    sourcesSF:SetSize(LEFT_W - SB_W - 4, LIST_H_SUB)
    sourcesSF:EnableMouseWheel(true)

    local sourcesSB = CreateFrame("Slider", nil, p)
    sourcesSB:SetPoint("TOPLEFT",    sourcesSF, "TOPRIGHT",    2, 0)
    sourcesSB:SetPoint("BOTTOMLEFT", sourcesSF, "BOTTOMRIGHT", 2, 0)
    sourcesSB:SetWidth(SB_W); sourcesSB:SetOrientation("VERTICAL")
    sourcesSB:SetMinMaxValues(0, 0); sourcesSB:SetValue(0)
    local st = sourcesSB:CreateTexture(nil, "THUMB"); st:SetSize(SB_W - 2, 24); st:SetColorTexture(0.5, 0.42, 0.22, 0.85); sourcesSB:SetThumbTexture(st)
    sourcesSF:SetScript("OnMouseWheel", function(_, d) sourcesSB:SetValue(math.max(0, math.min(select(2, sourcesSB:GetMinMaxValues()), sourcesSB:GetValue() - d * ROW_H_SUB * 2))) end)
    sourcesSB:SetScript("OnValueChanged", function(_, v) sourcesSF:SetVerticalScroll(v) end)

    -- ── Bouton Édition ────────────────────────────────────────────────
    local editMode   = false
    local allEditBtns = {}

    local editionBtn = CreateFrame("Button", nil, p)
    editionBtn:SetSize(LEFT_W, 22)
    editionBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", LEFT_X, 14)

    local eBg = editionBtn:CreateTexture(nil, "BACKGROUND"); eBg:SetAllPoints(); eBg:SetColorTexture(0.10, 0.10, 0.10, 1)
    local eLine = editionBtn:CreateTexture(nil, "ARTWORK"); eLine:SetHeight(2)
    eLine:SetPoint("BOTTOMLEFT",  editionBtn, "BOTTOMLEFT",  2, 1)
    eLine:SetPoint("BOTTOMRIGHT", editionBtn, "BOTTOMRIGHT", -2, 1)
    eLine:SetColorTexture(0.80, 0.70, 0.40, 1); eLine:Hide()
    local eHl = editionBtn:CreateTexture(nil, "HIGHLIGHT"); eHl:SetAllPoints(); eHl:SetColorTexture(0.85, 0.75, 0.40, 0.10)
    local eLbl = editionBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    eLbl:SetAllPoints(); eLbl:SetTextColor(0.88, 0.82, 0.65, 1); eLbl:SetText("Édition")

    local function SetEditMode(active)
        editMode = active
        eLine:SetShown(active)
        eBg:SetColorTexture(active and 0.18 or 0.10, active and 0.15 or 0.10, active and 0.08 or 0.10, 1)
        addGourdeBtn:SetShown(active)
        addSourceBtn:SetShown(active)
        for _, b in ipairs(allEditBtns) do b:SetShown(active) end
    end

    editionBtn:SetScript("OnClick", function() SetEditMode(not editMode) end)
    p:HookScript("OnHide", function() SetEditMode(false) end)

    -- ── COLONNE DROITE : Nom + Description + Fonctionnement ──────────
    local lblNom = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y)
    lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)

    local nomEB = UI.CreateStyledEditBox(p, RIGHT_W, 22)
    nomEB:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y - 16)

    local lblDesc = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y - 50)
    lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)

    local descBox = CreateFrame("Frame", nil, p)
    descBox:SetSize(RIGHT_W, 80)
    descBox:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y - 66)
    local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints(); descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
    descBorder:SetPoint("BOTTOMLEFT",  descBox, "BOTTOMLEFT",  2, 1)
    descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
    descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local descEB = CreateFrame("EditBox", nil, descBox)
    descEB:SetPoint("TOPLEFT",     descBox, "TOPLEFT",      6, -4)
    descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6,  4)
    descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(512)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    -- descBox bottom = SEC_TOP_Y - 146
    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT", RIGHT_X,           SEC_TOP_Y - 156)
        sep:SetPoint("TOPRIGHT", p, "TOPLEFT", RIGHT_X + RIGHT_W, SEC_TOP_Y - 156)
    end

    local lblFonct = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblFonct:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y - 168)
    lblFonct:SetText("Fonctionnement"); UI.ApplyStrongLabel(lblFonct)

    local reglesBtn = UI.CreatePanelButton(p, RIGHT_W, 22, "Fonctionnement  →")
    reglesBtn:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y - 192)

    local validBtn = UI.CreatePanelButton(p, RIGHT_W, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", RIGHT_X, 14)

    -- ── State & callbacks ─────────────────────────────────────────────
    local _cb             = nil
    local _gourdes        = nil
    local _sources        = nil
    local _fonctionnement = {}

    local function RebuildAll()
        wipe(allEditBtns)
        if _gourdes then
            BuildSubList(gourdesSF, gourdesSB, LIST_H_SUB, _gourdes,
                function(i)
                    OpenGourdeSubPanel("Modifier la gourde", _gourdes[i], function(pl)
                        local g = _gourdes[i]
                        g.label = pl.label; g.contenance = pl.contenance
                        g.desc  = pl.desc;  g.rechargeAuto = pl.rechargeAuto; g.filtre = pl.filtre
                        RebuildAll()
                    end)
                end,
                function(i) table.remove(_gourdes, i); RebuildAll() end,
                allEditBtns, editMode)
        end
        if _sources then
            BuildSubList(sourcesSF, sourcesSB, LIST_H_SUB, _sources,
                function(i)
                    OpenSourceSubPanel("Modifier le type d'eau", _sources[i], function(pl)
                        local s = _sources[i]
                        s.label    = pl.label;    s.desc     = pl.desc
                        s.proprete = pl.proprete; s.parasite = pl.parasite
                        s.malade      = pl.malade;      s.salee       = pl.salee
                        s.filtrage    = pl.filtrage;    s.auraEnabled = pl.auraEnabled
                        s.auraRules   = pl.auraRules
                        RebuildAll()
                    end)
                end,
                function(i) table.remove(_sources, i); RebuildAll() end,
                allEditBtns, editMode)
        end
    end

    addGourdeBtn:SetScript("OnClick", function()
        OpenGourdeSubPanel("Nouvelle Gourde", nil, function(pl)
            _gourdes[#_gourdes + 1] = {
                key          = GenerateKey("GOUR", _gourdes),
                label        = pl.label,
                contenance   = pl.contenance,
                desc         = pl.desc,
                rechargeAuto = pl.rechargeAuto,
                filtre       = pl.filtre,
            }
            RebuildAll()
        end)
    end)

    addSourceBtn:SetScript("OnClick", function()
        OpenSourceSubPanel("Nouveau Type d'eau", nil, function(pl)
            _sources[#_sources + 1] = {
                key      = GenerateKey("SRCE", _sources),
                label    = pl.label,
                desc     = pl.desc,
                proprete = pl.proprete,
                parasite = pl.parasite,
                malade   = pl.malade,
                salee       = pl.salee,
                filtrage    = pl.filtrage,
                auraEnabled = pl.auraEnabled,
                auraRules   = pl.auraRules,
            }
            RebuildAll()
        end)
    end)

    reglesBtn:SetScript("OnClick", function()
        OpenReglesPanel("Fonctionnement — Hydratation", _fonctionnement, function(f)
            _fonctionnement = f
        end)
    end)

    validBtn:SetScript("OnClick", function()
        local nom  = (nomEB:GetText()  or ""):match("^%s*(.-)%s*$")
        local desc = (descEB:GetText() or ""):match("^%s*(.-)%s*$")
        if nom == "" then return end
        if _cb then _cb({
            label           = nom,
            desc            = desc,
            gourdes         = _gourdes,
            sources         = _sources,
            fonctionnement  = _fonctionnement,
        }) end
        p:Hide()
    end)

    p._open = function(mode, item, cb)
        _cb             = cb
        _gourdes        = (item and item.gourdes) and { unpack(item.gourdes) } or {}
        _sources        = (item and item.sources) and { unpack(item.sources) } or {}
        _fonctionnement = (item and item.fonctionnement) or {}
        if mode == "create" then
            titleStr:SetText("Nouveau Système : Hydratation")
            nomEB:SetText(""); descEB:SetText("")
        else
            titleStr:SetText("Modifier : " .. (item and item.label or ""))
            nomEB:SetText(item and item.label or "")
            descEB:SetText(item and item.desc  or "")
        end
        RebuildAll()
        p:Show(); nomEB:SetFocus()
    end

    hydratationPanel = p
    return p
end

local function OpenHydratationPanel(mode, item, cb)
    GetOrCreateHydratationPanel()._open(mode, item, cb)
end

-- ── Section Hydratation dans l'onglet Survie ──────────────────────────
function OS2.DB.BuildHydratationSection(ctx, offsetY, SEC_LIST_H)
    local tabIndex = ctx.tabIndexByKey and ctx.tabIndexByKey["gourde"]
    if not tabIndex then return end
    local tab = ctx.tabCDB[tabIndex]
    if not tab then return end

    local UI        = ctx.UI
    local PAD       = ctx.PAD
    local SF_W      = ctx.CAT_SF_W or (ctx.DB_W - PAD * 2 - ctx.SB_W - ctx.SB_GAP)
    local ROW_H     = ctx.ROW_H
    local SB_W      = ctx.SB_W
    local SB_GAP    = ctx.SB_GAP
    local HDR_H     = ctx.HDR_H
    local DEL_SZ    = 16
    local LINK_W    = 36
    local LABEL_RSV = 4 + DEL_SZ + 4 + LINK_W + 4
    local typeKey   = "hydratation"

    local hdr = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", tab, "TOPLEFT", PAD, -(offsetY + 8))
    hdr:SetText("Hydratation"); UI.ApplyStrongLabel(hdr)

    local sf = CreateFrame("ScrollFrame", nil, tab)
    sf:SetPoint("TOPLEFT", tab, "TOPLEFT", PAD, -(offsetY + HDR_H))
    sf:SetSize(SF_W, SEC_LIST_H); sf:EnableMouseWheel(true)

    local track = tab:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.07, 0.07, 0.07, 1); track:SetWidth(SB_W)
    track:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    SB_GAP, 0)
    track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", SB_GAP, 0)

    local sb = CreateFrame("Slider", nil, tab)
    sb:SetPoint("TOPLEFT",    sf, "TOPRIGHT",    SB_GAP, 0)
    sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", SB_GAP, 0)
    sb:SetWidth(SB_W); sb:SetOrientation("VERTICAL"); sb:SetMinMaxValues(0, 0); sb:SetValue(0)
    local thumb = sb:CreateTexture(nil, "THUMB")
    thumb:SetSize(SB_W - 2, 30); thumb:SetColorTexture(0.50, 0.42, 0.22, 0.85); sb:SetThumbTexture(thumb)
    sf:SetScript("OnMouseWheel", function(_, d)
        sb:SetValue(math.max(0, math.min(select(2, sb:GetMinMaxValues()), sb:GetValue() - d * ROW_H * 3)))
    end)
    sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)

    local editBtns = {}
    local modBtns  = {}
    local linkBtns = {}

    local function RebuildList()
        if sf._content then sf._content:Hide() end
        wipe(editBtns); wipe(modBtns); wipe(linkBtns)
        local list = GetSystemList(typeKey)
        local cW = math.max(SF_W, math.floor(sf:GetWidth()))
        local c  = CreateFrame("Frame", nil, sf)
        c:SetSize(cW, 1); sf:SetScrollChild(c); sf:SetVerticalScroll(0); sf._content = c

        local y = 0
        for i, entry in ipairs(list) do
            local even = (math.floor(y / ROW_H) % 2 == 0)
            local rowBg = c:CreateTexture(nil, "BACKGROUND"); rowBg:SetHeight(ROW_H)
            rowBg:SetPoint("TOPLEFT",  c, "TOPLEFT",  0, -y)
            rowBg:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
            rowBg:SetColorTexture(even and 0.09 or 0.06, even and 0.09 or 0.06, even and 0.09 or 0.06, 1)

            local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT",  c, "TOPLEFT",  10, -(y + 5))
            lbl:SetPoint("TOPRIGHT", c, "TOPRIGHT", -LABEL_RSV, -(y + 5))
            lbl:SetJustifyH("LEFT"); lbl:SetText(entry.label); lbl:SetTextColor(0.85, 0.80, 0.65, 1)

            local btnY = y + math.floor((ROW_H - DEL_SZ) / 2)

            local modBtn = CreateFrame("Button", nil, c); modBtn:SetSize(LINK_W, DEL_SZ)
            modBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(4 + DEL_SZ + 4), -btnY)
            local mBg = modBtn:CreateTexture(nil, "BACKGROUND"); mBg:SetAllPoints(); mBg:SetColorTexture(0.18, 0.14, 0.04, 1)
            local mLbl = modBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); mLbl:SetAllPoints()
            mLbl:SetText("Éditer"); mLbl:SetTextColor(0.95, 0.80, 0.20, 1)
            local mHl = modBtn:CreateTexture(nil, "HIGHLIGHT"); mHl:SetAllPoints(); mHl:SetColorTexture(1, 0.85, 0.2, 0.2)
            modBtn:SetShown(false); modBtns[#modBtns + 1] = modBtn
            local ci = i; modBtn:SetScript("OnClick", function()
                local item = GetSystemList(typeKey)[ci]
                OpenHydratationPanel("edit", item, function(pl)
                    item.label          = pl.label;   item.desc    = pl.desc
                    item.gourdes        = pl.gourdes;  item.sources = pl.sources
                    item.fonctionnement = pl.fonctionnement
                    RebuildList()
                end)
            end)

            local delBtn = CreateFrame("Button", nil, c); delBtn:SetSize(DEL_SZ, DEL_SZ)
            delBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -btnY)
            local dBg = delBtn:CreateTexture(nil, "BACKGROUND"); dBg:SetAllPoints(); dBg:SetColorTexture(0.20, 0.07, 0.07, 1)
            local dLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); dLbl:SetAllPoints()
            dLbl:SetText("−"); dLbl:SetTextColor(0.80, 0.30, 0.30, 1)
            local dHl = delBtn:CreateTexture(nil, "HIGHLIGHT"); dHl:SetAllPoints(); dHl:SetColorTexture(0.75, 0.2, 0.2, 0.4)
            delBtn:SetShown(false); editBtns[#editBtns + 1] = delBtn
            local di = i; delBtn:SetScript("OnClick", function()
                table.remove(GetSystemList(typeKey), di); RebuildList()
            end)

            local linkBtn = CreateFrame("Button", nil, c); linkBtn:SetSize(LINK_W, DEL_SZ)
            linkBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -btnY)
            local lkBg = linkBtn:CreateTexture(nil, "BACKGROUND"); lkBg:SetAllPoints(); lkBg:SetColorTexture(0.10, 0.14, 0.20, 1)
            local lkLbl = linkBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); lkLbl:SetAllPoints()
            lkLbl:SetText("Link"); lkLbl:SetTextColor(0.50, 0.75, 1.00, 1)
            local lkHl = linkBtn:CreateTexture(nil, "HIGHLIGHT"); lkHl:SetAllPoints(); lkHl:SetColorTexture(0.40, 0.65, 1.00, 0.20)
            linkBtn:SetShown(true); linkBtns[#linkBtns + 1] = linkBtn

            y = y + ROW_H
        end
        c:SetHeight(math.max(1, y))
        local maxS = math.max(0, y - SEC_LIST_H)
        sb:SetMinMaxValues(0, maxS); sb:SetAlpha(maxS > 0 and 1 or 0.2)
    end

    ctx.CreateAddButton(tab, PAD + SF_W - 16, -(offsetY + 4), function()
        OpenHydratationPanel("create", nil, function(pl)
            local list = GetSystemList(typeKey)
            list[#list + 1] = {
                key            = GenerateKey(pl.label, list),
                label          = pl.label,
                desc           = pl.desc or "",
                gourdes        = pl.gourdes or {},
                sources        = pl.sources or {},
                fonctionnement = pl.fonctionnement or {},
            }
            RebuildList()
        end)
    end)

    ctx.genericCatInfos[#ctx.genericCatInfos + 1] = {
        key = typeKey, editBtns = editBtns, modBtns = modBtns, linkBtns = linkBtns, rebuildFn = RebuildList,
    }

    RebuildList()
end
