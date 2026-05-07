-- OmegaSurvive 2.0 — SystemSchema
-- Builder indépendant pour l'onglet Système de la base de données.
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

-- ── Helper : petite scroll-list avec [−] et [Éditer] ──────────────────
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

        -- [Éditer]
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

        -- [−]
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

-- ── Panel principal de création/édition d'un système ──────────────────
local systemPanel = nil

local function GetOrCreateSystemPanel()
    if systemPanel then return systemPanel end

    local UI     = OS2.UI or {}
    local TOT_W  = 490
    local LEFT_W = 210
    local RIGHT_W= 240
    local LEFT_X = 14
    local RIGHT_X= LEFT_X + LEFT_W + 12
    local TOT_H  = 420
    local HDR_H  = 36
    local SEC_H  = math.floor((TOT_H - HDR_H - 14) / 2)  -- hauteur d'une section gauche
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

    do  -- séparateur titre
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -HDR_H); sep:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -HDR_H)
    end

    UI.CreateCloseButton(p, function() p:Hide() end)

    do  -- drag
        local drag = CreateFrame("Frame", nil, p)
        drag:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0); drag:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
        drag:SetHeight(HDR_H); OS2.MakeDraggable(p, drag)
    end

    -- ── Séparateur vertical ────────────────────────────────────────────
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

    -- ── Bouton Édition (bas gauche) ────────────────────────────────────
    local editMode = false
    local allEditBtns = {}  -- tous les boutons à afficher en mode édition

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

    -- ── COLONNE DROITE : Nom + Description ────────────────────────────
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

    -- descBox bottom = SEC_TOP_Y - 66 - 80 = SEC_TOP_Y - 146
    do
        local sep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT",  p, "TOPLEFT", RIGHT_X,            SEC_TOP_Y - 156)
        sep:SetPoint("TOPRIGHT", p, "TOPLEFT", RIGHT_X + RIGHT_W,  SEC_TOP_Y - 156)
    end

    local lblFonct = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblFonct:SetPoint("TOPLEFT", p, "TOPLEFT", RIGHT_X, SEC_TOP_Y - 168)
    lblFonct:SetText("Fonctionnement"); UI.ApplyStrongLabel(lblFonct)

    -- Valider
    local validBtn = UI.CreatePanelButton(p, RIGHT_W, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", RIGHT_X, 14)

    -- ── State & callbacks ─────────────────────────────────────────────
    local _cb         = nil
    local _gourdes    = nil
    local _sources    = nil

    local function RebuildAll()
        wipe(allEditBtns)
        if _gourdes then
            BuildSubList(gourdesSF, gourdesSB, LIST_H_SUB, _gourdes,
                function(i) OpenSubPanel("Modifier la gourde", _gourdes[i], function(pl) _gourdes[i].label = pl.label; _gourdes[i].desc = pl.desc; RebuildAll() end) end,
                function(i) table.remove(_gourdes, i); RebuildAll() end,
                allEditBtns, editMode)
        end
        if _sources then
            BuildSubList(sourcesSF, sourcesSB, LIST_H_SUB, _sources,
                function(i) OpenSubPanel("Modifier le type d'eau", _sources[i], function(pl) _sources[i].label = pl.label; _sources[i].desc = pl.desc; RebuildAll() end) end,
                function(i) table.remove(_sources, i); RebuildAll() end,
                allEditBtns, editMode)
        end
    end

    addGourdeBtn:SetScript("OnClick", function()
        OpenSubPanel("Nouvelle Gourde", nil, function(pl)
            _gourdes[#_gourdes + 1] = { key = GenerateKey("GOUR", _gourdes), label = pl.label, desc = pl.desc }
            RebuildAll()
        end)
    end)

    addSourceBtn:SetScript("OnClick", function()
        OpenSubPanel("Nouveau Type d'eau", nil, function(pl)
            _sources[#_sources + 1] = { key = GenerateKey("SRCE", _sources), label = pl.label, desc = pl.desc }
            RebuildAll()
        end)
    end)

    validBtn:SetScript("OnClick", function()
        local nom  = (nomEB:GetText()  or ""):match("^%s*(.-)%s*$")
        local desc = (descEB:GetText() or ""):match("^%s*(.-)%s*$")
        if nom == "" then return end
        if _cb then _cb({ label = nom, desc = desc, gourdes = _gourdes, sources = _sources }) end
        p:Hide()
    end)

    p.titleStr = titleStr
    p.nomEB    = nomEB
    p.descEB   = descEB

    p._open = function(mode, typeKey, item, cb)
        local sysType = nil
        for _, t in ipairs(OS2.SystemTypes or {}) do
            if t.key == typeKey then sysType = t; break end
        end

        _cb      = cb
        _gourdes = (item and item.gourdes) and { unpack(item.gourdes) } or {}
        _sources = (item and item.sources) and { unpack(item.sources) } or {}

        if mode == "create" then
            titleStr:SetText("Nouveau Système : " .. (sysType and sysType.label or typeKey))
            nomEB:SetText(""); descEB:SetText("")
        else
            titleStr:SetText("Modifier : " .. (item and item.label or ""))
            nomEB:SetText(item and item.label or "")
            descEB:SetText(item and item.desc  or "")
        end

        RebuildAll()
        p:Show(); nomEB:SetFocus()
    end

    systemPanel = p
    return p
end

-- ── Panel alimentation : Nom + Description uniquement ────────────────
local alimentationPanel = nil

local function GetOrCreateAlimentationPanel()
    if alimentationPanel then return alimentationPanel end

    local UI   = OS2.UI or {}
    local PA_W = 320
    local PA_H = 200

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(PA_W, PA_H)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(100)
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

    local lblNom = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -46)
    lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)

    local nomEB = UI.CreateStyledEditBox(p, PA_W - 28, 22)
    nomEB:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -62)

    local lblDesc = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", p, "TOPLEFT", 14, -96)
    lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)

    local descBox = CreateFrame("Frame", nil, p)
    descBox:SetSize(PA_W - 28, 48)
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
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(512)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local validBtn = UI.CreatePanelButton(p, PA_W - 28, 22, "Valider")
    validBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 14, 14)

    local _cb = nil
    validBtn:SetScript("OnClick", function()
        local nom  = (nomEB:GetText()  or ""):match("^%s*(.-)%s*$")
        local desc = (descEB:GetText() or ""):match("^%s*(.-)%s*$")
        if nom == "" then return end
        if _cb then _cb({ label = nom, desc = desc }) end
        p:Hide()
    end)

    p._open = function(mode, typeKey, item, cb)
        local sysType = nil
        for _, t in ipairs(OS2.SystemTypes or {}) do
            if t.key == typeKey then sysType = t; break end
        end
        _cb = cb
        if mode == "create" then
            titleStr:SetText("Nouveau Système : " .. (sysType and sysType.label or typeKey))
            nomEB:SetText(""); descEB:SetText("")
        else
            titleStr:SetText("Modifier : " .. (item and item.label or ""))
            nomEB:SetText(item and item.label or "")
            descEB:SetText(item and item.desc  or "")
        end
        p:Show(); nomEB:SetFocus()
    end

    alimentationPanel = p
    return p
end

-- ── Dispatch : chaque typeKey utilise son propre panel ────────────────
local panelBuilders = {
    hydratation  = function() return GetOrCreateSystemPanel()  end,
    alimentation = function() return GetOrCreateAlimentationPanel() end,
}

local function OpenSystemPanel(mode, typeKey, item, cb)
    local builder = panelBuilders[typeKey] or function() return GetOrCreateSystemPanel() end
    builder()._open(mode, typeKey, item, cb)
end

-- ── Builder de l'onglet Survie (liste principale, multi-sections) ────────
function OS2.DB.BuildSystemDatabaseTab(ctx)
    local tabIndex = ctx.tabIndexByKey and ctx.tabIndexByKey["gourde"]
    if not tabIndex then return end
    local tab = ctx.tabCDB[tabIndex]
    if not tab then return end

    local UI      = ctx.UI
    local PAD     = ctx.PAD
    local SF_W    = ctx.CAT_SF_W or (ctx.DB_W - PAD * 2 - ctx.SB_W - ctx.SB_GAP)
    local LIST_H  = ctx.LIST_H
    local ROW_H   = ctx.ROW_H
    local SB_W    = ctx.SB_W
    local SB_GAP  = ctx.SB_GAP
    local HDR_H   = ctx.HDR_H
    local DEL_SZ  = 16
    local LINK_W  = 36
    local LABEL_RSV = 4 + DEL_SZ + 4 + LINK_W + 4

    local types = OS2.SystemTypes or {}
    local N = #types
    if N == 0 then return end

    -- Hauteur de chaque liste : on partage LIST_H en soustrayant
    -- HDR_H pour chaque section supplémentaire + 6 px de gap entre sections.
    local SEC_GAP    = 6
    local EXTRA      = (N - 1) * (HDR_H + SEC_GAP)
    local SEC_LIST_H = math.floor((LIST_H - EXTRA) / N)

    local offsetY = 0  -- décalage cumulé depuis le haut du contenu de l'onglet

    for idx, sysType in ipairs(types) do
        -- Closure : capturer les variables locales pour chaque type
        local typeKey   = sysType.key
        local typeLabel = sysType.label

        -- ── Séparateur entre sections ──────────────────────────────────
        if idx > 1 then
            local sep = tab:CreateTexture(nil, "ARTWORK")
            UI.ApplySeparator(sep); sep:SetHeight(1)
            sep:SetPoint("TOPLEFT",  tab, "TOPLEFT",  PAD,                     -(offsetY + 3))
            sep:SetPoint("TOPRIGHT", tab, "TOPLEFT",  PAD + SF_W + SB_GAP + SB_W, -(offsetY + 3))
            offsetY = offsetY + SEC_GAP
        end

        -- ── Header ────────────────────────────────────────────────────
        local hdr = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hdr:SetPoint("TOPLEFT", tab, "TOPLEFT", PAD, -(offsetY + 8))
        hdr:SetText(typeLabel); UI.ApplyStrongLabel(hdr)

        -- ── ScrollFrame + ScrollBar ───────────────────────────────────
        local listY = offsetY + HDR_H

        local sf = CreateFrame("ScrollFrame", nil, tab)
        sf:SetPoint("TOPLEFT", tab, "TOPLEFT", PAD, -listY)
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

        -- ── Pools de boutons pour ce type ─────────────────────────────
        local editBtns = {}
        local modBtns  = {}
        local linkBtns = {}

        -- ── Rebuild ───────────────────────────────────────────────────
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
                    OpenSystemPanel("edit", typeKey, item, function(pl)
                        item.label   = pl.label;  item.desc    = pl.desc
                        item.gourdes = pl.gourdes; item.sources = pl.sources
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

        -- ── Bouton [+] ────────────────────────────────────────────────
        ctx.CreateAddButton(tab, PAD + SF_W - 16, -(offsetY + 4), function()
            OpenSystemPanel("create", typeKey, nil, function(pl)
                local list = GetSystemList(typeKey)
                list[#list + 1] = {
                    key     = GenerateKey(pl.label, list),
                    label   = pl.label,
                    desc    = pl.desc or "",
                    gourdes = pl.gourdes or {},
                    sources = pl.sources or {},
                }
                RebuildList()
            end)
        end)

        ctx.genericCatInfos[#ctx.genericCatInfos + 1] = {
            key = typeKey, editBtns = editBtns, modBtns = modBtns, linkBtns = linkBtns, rebuildFn = RebuildList,
        }

        RebuildList()

        offsetY = offsetY + HDR_H + SEC_LIST_H
    end
end
