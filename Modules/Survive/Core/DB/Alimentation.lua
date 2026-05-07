-- OmegaSurvive 2.0 — Builder Alimentation
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

-- ── Panel Alimentation : Nom + Description ────────────────────────────
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

    p._open = function(mode, item, cb)
        _cb = cb
        if mode == "create" then
            titleStr:SetText("Nouveau Système : Alimentation")
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

local function OpenAlimentationPanel(mode, item, cb)
    GetOrCreateAlimentationPanel()._open(mode, item, cb)
end

-- ── Section Alimentation dans l'onglet Survie ─────────────────────────
function OS2.DB.BuildAlimentationSection(ctx, offsetY, SEC_LIST_H)
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
    local typeKey   = "alimentation"

    local hdr = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hdr:SetPoint("TOPLEFT", tab, "TOPLEFT", PAD, -(offsetY + 8))
    hdr:SetText("Alimentation"); UI.ApplyStrongLabel(hdr)

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
                OpenAlimentationPanel("edit", item, function(pl)
                    item.label = pl.label; item.desc = pl.desc
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
        OpenAlimentationPanel("create", nil, function(pl)
            local list = GetSystemList(typeKey)
            list[#list + 1] = {
                key   = GenerateKey(pl.label, list),
                label = pl.label,
                desc  = pl.desc or "",
            }
            RebuildList()
        end)
    end)

    ctx.genericCatInfos[#ctx.genericCatInfos + 1] = {
        key = typeKey, editBtns = editBtns, modBtns = modBtns, linkBtns = linkBtns, rebuildFn = RebuildList,
    }

    RebuildList()
end
