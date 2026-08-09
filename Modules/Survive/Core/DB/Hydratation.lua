-- OmegaSurvive 2.0 — Builder Hydratation
OS2    = OS2    or {}
OS2.DB = OS2.DB or {}

-- ── Stockage ───────────────────────────────────────────────────────────
local function GetSystemList(typeKey)
    OS2DB = OS2DB or {}
    OS2DB.systems = OS2DB.systems or {}
    OS2.Core = OS2.Core or {}
    OS2.Core.Systems = OS2DB.systems
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

-- ── EditBox numérique (SetNumeric() natif bloque le signe "-") ─────────
-- allowDecimal accepte aussi bien "." que "," (convention FR) comme séparateur.
local function SetupNumericEditBox(eb, allowNegative, allowDecimal)
    eb:SetNumeric(false)
    local sign = allowNegative and "%-?" or ""
    local pattern = allowDecimal and ("^" .. sign .. "%d*[.,]?%d*$") or ("^" .. sign .. "%d*$")
    eb._lastValidText = eb:GetText() or ""
    eb:SetScript("OnTextChanged", function(self, isUserInput)
        if not isUserInput then return end
        local text = self:GetText()
        if text:match(pattern) then
            self._lastValidText = text
        else
            self:SetText(self._lastValidText or "")
        end
    end)
end

-- ── Parse un nombre saisi avec "," ou "." comme séparateur décimal ─────
local function ParseDecimal(text)
    return tonumber(((text or ""):gsub(",", ".")))
end

-- ── Opérande : valeur flexible (Brut / Clé / Expression) ───────────────
-- { type = "fixed", value = number, unit = "brut"|"pourcent" }
-- { type = "cle",   cleKey = string }
-- { type = "expr",  op = "addition"|"soustraction"|"multiplication"|"division", left = Opérande, right = Opérande }
local OPERATION_SYMBOLS = {
    addition       = "+",
    soustraction   = "−",
    multiplication = "×",
    division       = "÷",
}

local OPERATION_LABELS = {
    addition       = "Addition",
    soustraction   = "Soustraction",
    multiplication = "Multiplication",
    division       = "Division",
    si             = "Si",
}

local COMPARATEUR_LABELS = {
    [">"]  = ">",
    [">="] = "≥",
    ["<"]  = "<",
    ["<="] = "≤",
    ["="]  = "=",
    ["~="] = "≠",
}

local function CleLabelByKey(cles, cleKey)
    for _, c in ipairs(cles or {}) do
        if c.key == cleKey then return c.label end
    end
    return "?"
end

local function DescribeOperand(op, cles)
    if not op then return "0" end
    if op.type == "cle" then
        return CleLabelByKey(cles, op.cleKey)
    elseif op.type == "expr" then
        return string.format("(%s %s %s)",
            DescribeOperand(op.left, cles),
            OPERATION_SYMBOLS[op.op] or "?",
            DescribeOperand(op.right, cles))
    else
        local v = tostring(op.value or 0)
        return (op.unit == "pourcent") and (v .. "%") or v
    end
end

local function EvaluateOperand(op, ctx)
    if not op then return 0 end
    if op.type == "cle" then
        local def = 0
        for _, c in ipairs(ctx.cles or {}) do
            if c.key == op.cleKey then def = c.valeurDefaut or 0; break end
        end
        if OS2.DB.GetHydrationLiveValue then
            return OS2.DB.GetHydrationLiveValue(ctx.systemKey, op.cleKey, def) or 0
        end
        return def
    elseif op.type == "expr" then
        local l = EvaluateOperand(op.left,  ctx)
        local r = EvaluateOperand(op.right, ctx)
        if     op.op == "addition"       then return l + r
        elseif op.op == "soustraction"   then return l - r
        elseif op.op == "multiplication" then return l * r
        elseif op.op == "division"       then return (r ~= 0) and (l / r) or 0
        end
        return 0
    else
        local v = op.value or 0
        if op.unit == "pourcent" then
            return (v / 100) * (ctx.capaciteTotale or 0)
        end
        return v
    end
end

-- ── Condition : Base [Opération] Valeur, ou Si (branches Alors/Sinon) ──
-- { key, label, base = Opérande, operation = "addition".."division"|"si",
--   valeur = Opérande,                                  -- opérations arithmétiques
--   comparateur = ">" etc., valeurSi = Opérande,         -- si
--   alors = { actions = { Action, ... } }, sinon = { actions = { Action, ... } } }
--
-- Action :
-- { type = "formule", formule = Condition }             -- imbriqué, récursif
-- { type = "aura",    spellId = number, mode = "apply"|"remove" }
-- { type = "message", text = string }
local EvaluateCondition, ExecuteConditionActions, DescribeCondition, DescribeAction

function ExecuteConditionActions(actions, ctx)
    local total = 0
    for _, action in ipairs(actions or {}) do
        if action.type == "formule" then
            total = total + (EvaluateCondition(action.formule, ctx) or 0)
        elseif action.type == "aura" then
            if action.spellId and OS2.ModuleRules and OS2.ModuleRules.ExecuteServerCommand then
                local mode = (action.mode == "remove") and "remove" or "apply"
                OS2.ModuleRules.ExecuteServerCommand(tostring(action.spellId), mode)
            end
        elseif action.type == "message" then
            if UIErrorsFrame and action.text and action.text ~= "" then
                UIErrorsFrame:AddMessage(action.text, 1.0, 0.82, 0.0)
            end
        end
    end
    return total
end

function EvaluateCondition(cond, ctx)
    if not cond then return 0 end
    local baseVal = EvaluateOperand(cond.base, ctx)
    if cond.operation == "si" then
        local seuil = EvaluateOperand(cond.valeurSi, ctx)
        local cmp = cond.comparateur or ">"
        local ok
        if     cmp == ">"  then ok = baseVal >  seuil
        elseif cmp == ">=" then ok = baseVal >= seuil
        elseif cmp == "<"  then ok = baseVal <  seuil
        elseif cmp == "<=" then ok = baseVal <= seuil
        elseif cmp == "="  then ok = baseVal == seuil
        elseif cmp == "~=" then ok = baseVal ~= seuil
        else ok = false end
        local branch = ok and cond.alors or cond.sinon
        return ExecuteConditionActions(branch and branch.actions, ctx)
    else
        local valeur = EvaluateOperand(cond.valeur, ctx)
        if     cond.operation == "addition"       then return baseVal + valeur
        elseif cond.operation == "soustraction"    then return baseVal - valeur
        elseif cond.operation == "multiplication"  then return baseVal * valeur
        elseif cond.operation == "division"        then return (valeur ~= 0) and (baseVal / valeur) or 0
        end
        return baseVal
    end
end

function DescribeAction(action, cles)
    if not action then return "?" end
    if action.type == "formule" then
        return "Formule : " .. DescribeCondition(action.formule, cles)
    elseif action.type == "aura" then
        local verbe = (action.mode == "remove") and "Retirer" or "Appliquer"
        return string.format("Aura : %s %s", verbe, tostring(action.spellId or "?"))
    elseif action.type == "message" then
        return "Message : \"" .. (action.text or "") .. "\""
    end
    return "?"
end

function DescribeCondition(cond, cles)
    if not cond then return "?" end
    if cond.operation == "si" then
        return string.format("Si %s %s %s",
            DescribeOperand(cond.base, cles),
            COMPARATEUR_LABELS[cond.comparateur] or "?",
            DescribeOperand(cond.valeurSi, cles))
    end
    return string.format("%s %s %s",
        DescribeOperand(cond.base, cles),
        OPERATION_SYMBOLS[cond.operation] or "?",
        DescribeOperand(cond.valeur, cles))
end

-- ══════════════════════════════════════════════════════════════════════
-- Widgets partagés
-- ══════════════════════════════════════════════════════════════════════

-- ── Bouton à cycle : clic = valeur suivante ────────────────────────────
local function CreateCycleToggle(parent, w, h, options, labelFn, onChange)
    local tidx = 1
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, h)
    local tBg = btn:CreateTexture(nil, "BACKGROUND"); tBg:SetAllPoints(); tBg:SetColorTexture(0.12, 0.10, 0.05, 1)
    local tBd = btn:CreateTexture(nil, "ARTWORK"); tBd:SetHeight(1)
    tBd:SetPoint("BOTTOMLEFT",  btn, "BOTTOMLEFT",  2, 1)
    tBd:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 1)
    tBd:SetColorTexture(0.70, 0.60, 0.25, 0.80)
    local tHl = btn:CreateTexture(nil, "HIGHLIGHT"); tHl:SetAllPoints(); tHl:SetColorTexture(0.8, 0.7, 0.3, 0.12)
    local tLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); tLbl:SetAllPoints()
    tLbl:SetTextColor(0.92, 0.84, 0.50, 1)
    local function Refresh()
        tLbl:SetText((labelFn and labelFn(options[tidx])) or tostring(options[tidx]))
    end
    btn:SetScript("OnClick", function()
        tidx = (tidx < #options) and (tidx + 1) or 1
        Refresh()
        if onChange then onChange(options[tidx]) end
    end)
    Refresh()
    return {
        button = btn,
        GetValue = function() return options[tidx] end,
        SetValue = function(v)
            for i, o in ipairs(options) do if o == v then tidx = i; break end end
            Refresh()
        end,
    }
end

-- ── Accordéon générique : liste dont chaque ligne s'étend en place ─────
local function NewAccordion(parent)
    local SB_W = 8
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:EnableMouseWheel(true)

    local sb = CreateFrame("Slider", nil, parent)
    sb:SetWidth(SB_W); sb:SetOrientation("VERTICAL"); sb:SetMinMaxValues(0, 0); sb:SetValue(0)
    local sbt = sb:CreateTexture(nil, "THUMB"); sbt:SetSize(SB_W - 2, 24); sbt:SetColorTexture(0.5, 0.42, 0.22, 0.85); sb:SetThumbTexture(sbt)
    sf:SetScript("OnMouseWheel", function(_, d)
        sb:SetValue(math.max(0, math.min(select(2, sb:GetMinMaxValues()), sb:GetValue() - d * 40)))
    end)
    sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)

    local acc = { sf = sf, sb = sb, expanded = nil }

    function acc.Render(items, opts)
        local listH = sf:GetHeight()
        if sf._content then sf._content:Hide() end
        local cW = math.max(1, math.floor(sf:GetWidth()))
        local c = CreateFrame("Frame", nil, sf)
        c:SetSize(cW, 1); sf:SetScrollChild(c); sf:SetVerticalScroll(0); sf._content = c

        local ROW_H = 26
        local y = 0
        for i, item in ipairs(items) do
            local isOpen = (acc.expanded == i)
            local extraH = isOpen and (opts.formHeight and opts.formHeight(item) or 0) or 0
            local rowH = ROW_H + extraH

            local row = CreateFrame("Frame", nil, c)
            row:SetSize(cW, rowH)
            row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)

            local rowBg = row:CreateTexture(nil, "BACKGROUND"); rowBg:SetAllPoints()
            if isOpen then
                rowBg:SetColorTexture(0.13, 0.11, 0.06, 1)
            else
                local even = (i % 2 == 0)
                local shade = even and 0.09 or 0.06
                rowBg:SetColorTexture(shade, shade, shade, 1)
            end

            local hdrBtn = CreateFrame("Button", nil, row)
            hdrBtn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            hdrBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -26, 0)
            hdrBtn:SetHeight(ROW_H)
            local hl = hdrBtn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(0.85, 0.75, 0.40, 0.08)

            local arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            arrow:SetPoint("LEFT", row, "TOPLEFT", 6, -(ROW_H / 2))
            arrow:SetText(isOpen and "▾" or "▸"); arrow:SetTextColor(0.80, 0.70, 0.40, 1)

            local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", arrow, "RIGHT", 6, 0)
            lbl:SetPoint("RIGHT", hdrBtn, "RIGHT", -4, 0)
            lbl:SetJustifyH("LEFT"); lbl:SetText(opts.summary(item)); lbl:SetTextColor(0.85, 0.80, 0.65, 1)

            local delBtn = CreateFrame("Button", nil, row); delBtn:SetSize(16, 16)
            delBtn:SetPoint("RIGHT", row, "TOPRIGHT", -6, -(ROW_H / 2))
            local dBg = delBtn:CreateTexture(nil, "BACKGROUND"); dBg:SetAllPoints(); dBg:SetColorTexture(0.20, 0.07, 0.07, 1)
            local dLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); dLbl:SetAllPoints()
            dLbl:SetText("−"); dLbl:SetTextColor(0.80, 0.30, 0.30, 1)
            local dHl = delBtn:CreateTexture(nil, "HIGHLIGHT"); dHl:SetAllPoints(); dHl:SetColorTexture(0.75, 0.2, 0.2, 0.4)
            local di = i
            delBtn:SetScript("OnClick", function()
                if opts.onDelete then opts.onDelete(di) end
            end)

            local ci = i
            hdrBtn:SetScript("OnClick", function()
                if isOpen then
                    acc.expanded = nil
                else
                    acc.expanded = ci
                end
                acc.Render(items, opts)
            end)

            if isOpen then
                local formFrame = CreateFrame("Frame", nil, row)
                formFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -ROW_H)
                formFrame:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -ROW_H)
                formFrame:SetHeight(math.max(1, extraH))
                if opts.buildForm then
                    opts.buildForm(formFrame, item, i, function() acc.Render(items, opts) end)
                end
            end

            y = y + rowH
        end
        c:SetHeight(math.max(1, y))
        local maxS = math.max(0, y - listH)
        sb:SetMinMaxValues(0, maxS); sb:SetAlpha(maxS > 0 and 1 or 0.2)
    end

    return acc
end

-- ── Liste plate avec Éditer/Supprimer toujours visibles ────────────────
local function BuildFlatList(sf, sb, listH, list, onEdit, onDelete)
    if sf._content then sf._content:Hide() end
    local cW = math.max(1, math.floor(sf:GetWidth()))
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(cW, 1); sf:SetScrollChild(c); sf:SetVerticalScroll(0); sf._content = c

    local ROW_H = 24
    local DEL_SZ = 16
    local LINK_W = 44
    local y = 0
    for i, entry in ipairs(list) do
        local even = (i % 2 == 0)
        local shade = even and 0.09 or 0.06
        local rowBg = c:CreateTexture(nil, "BACKGROUND"); rowBg:SetHeight(ROW_H)
        rowBg:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); rowBg:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        rowBg:SetColorTexture(shade, shade, shade, 1)

        local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT",  c, "TOPLEFT",  6, -(y + 5))
        lbl:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(4 + DEL_SZ + 4 + LINK_W + 4), -(y + 5))
        lbl:SetJustifyH("LEFT"); lbl:SetText(entry.label); lbl:SetTextColor(0.85, 0.80, 0.65, 1)

        local btnY = y + math.floor((ROW_H - DEL_SZ) / 2)

        local editBtn = CreateFrame("Button", nil, c); editBtn:SetSize(LINK_W, DEL_SZ)
        editBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -(4 + DEL_SZ + 4), -btnY)
        local eBg = editBtn:CreateTexture(nil, "BACKGROUND"); eBg:SetAllPoints(); eBg:SetColorTexture(0.18, 0.14, 0.04, 1)
        local eLbl = editBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); eLbl:SetAllPoints()
        eLbl:SetText("Éditer"); eLbl:SetTextColor(0.95, 0.80, 0.20, 1)
        local eHl = editBtn:CreateTexture(nil, "HIGHLIGHT"); eHl:SetAllPoints(); eHl:SetColorTexture(1, 0.85, 0.2, 0.2)
        local ei = i; editBtn:SetScript("OnClick", function() onEdit(ei) end)

        local delBtn = CreateFrame("Button", nil, c); delBtn:SetSize(DEL_SZ, DEL_SZ)
        delBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -btnY)
        local dBg = delBtn:CreateTexture(nil, "BACKGROUND"); dBg:SetAllPoints(); dBg:SetColorTexture(0.20, 0.07, 0.07, 1)
        local dLbl = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal"); dLbl:SetAllPoints()
        dLbl:SetText("−"); dLbl:SetTextColor(0.80, 0.30, 0.30, 1)
        local dHl = delBtn:CreateTexture(nil, "HIGHLIGHT"); dHl:SetAllPoints(); dHl:SetColorTexture(0.75, 0.2, 0.2, 0.4)
        local di = i; delBtn:SetScript("OnClick", function() onDelete(di) end)

        y = y + ROW_H
    end
    c:SetHeight(math.max(1, y))
    local maxS = math.max(0, y - listH)
    sb:SetMinMaxValues(0, maxS); sb:SetAlpha(maxS > 0 and 1 or 0.2)
end

local function CreateFlatScrollList(parent)
    local SB_W = 8
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:EnableMouseWheel(true)
    local sb = CreateFrame("Slider", nil, parent)
    sb:SetWidth(SB_W); sb:SetOrientation("VERTICAL"); sb:SetMinMaxValues(0, 0); sb:SetValue(0)
    local sbt = sb:CreateTexture(nil, "THUMB"); sbt:SetSize(SB_W - 2, 24); sbt:SetColorTexture(0.5, 0.42, 0.22, 0.85); sb:SetThumbTexture(sbt)
    sf:SetScript("OnMouseWheel", function(_, d)
        sb:SetValue(math.max(0, math.min(select(2, sb:GetMinMaxValues()), sb:GetValue() - d * 44)))
    end)
    sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
    return sf, sb
end

-- ══════════════════════════════════════════════════════════════════════
-- Sections
-- ══════════════════════════════════════════════════════════════════════

-- ── Général ─────────────────────────────────────────────────────────────
local function RenderGeneralSection(container, data)
    local UI = OS2.UI or {}
    local W = container:GetWidth()

    local lblNom = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    lblNom:SetText("Nom du système"); UI.ApplyLabel(lblNom)
    local nomEB = UI.CreateStyledEditBox(container, W, 24)
    nomEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -18)
    nomEB:SetText(data.label or "")
    nomEB:SetScript("OnTextChanged", function(self) data.label = self:GetText() end)

    local lblDesc = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -56)
    lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)

    local descBox = CreateFrame("Frame", nil, container)
    descBox:SetSize(W, 130)
    descBox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -72)
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
    descEB:SetText(data.desc or "")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    descEB:SetScript("OnTextChanged", function(self) data.desc = self:GetText() end)

    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -216)
    hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -216)
    hint:SetJustifyH("LEFT"); hint:SetWordWrap(true); UI.ApplySoftText(hint)
    hint:SetText("Utilise la barre de gauche pour configurer les Clés, États, Filtres, Sources, Gourdes, Conditions et le Fonctionnement de ce système.")
end

-- ── Gourdes ─────────────────────────────────────────────────────────────
local function BuildGourdeForm(form, item, filtres, Refresh)
    local UI = OS2.UI or {}
    local W = form:GetWidth()
    local y = 0

    local lblNom = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)
    local nomEB = UI.CreateStyledEditBox(form, W, 22)
    nomEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
    nomEB:SetText(item.label or "")
    nomEB:SetScript("OnTextChanged", function(self) item.label = self:GetText() end)
    y = y + 44

    local lblCont = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblCont:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblCont:SetText("Contenance"); UI.ApplyLabel(lblCont)
    local contEB = UI.CreateStyledEditBox(form, W, 22)
    contEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
    contEB:SetText(item.contenance or "")
    contEB:SetScript("OnTextChanged", function(self) item.contenance = self:GetText() end)
    y = y + 44

    local lblDesc = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)
    local descBox = CreateFrame("Frame", nil, form)
    descBox:SetSize(W, 46)
    descBox:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
    local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints(); descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
    descBorder:SetPoint("BOTTOMLEFT", descBox, "BOTTOMLEFT", 2, 1); descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
    descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local descEB = CreateFrame("EditBox", nil, descBox)
    descEB:SetPoint("TOPLEFT", descBox, "TOPLEFT", 6, -4); descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6, 4)
    descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetText(item.desc or "")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    descEB:SetScript("OnTextChanged", function(self) item.desc = self:GetText() end)
    y = y + 62

    local chkRecharge, lblRecharge = UI.CreateStyledCheckbox(form, "Recharge automatique ?")
    chkRecharge:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblRecharge:SetPoint("LEFT", chkRecharge, "RIGHT", 6, 0)
    chkRecharge:SetChecked(item.rechargeAuto or false)
    chkRecharge:SetScript("OnClick", function(self) item.rechargeAuto = self:GetChecked() and true or false end)
    y = y + 26

    if item.filtreActif == nil then item.filtreActif = item.filtre or false end
    local chkFiltre, lblFiltre = UI.CreateStyledCheckbox(form, "Accepte les filtres ?")
    chkFiltre:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblFiltre:SetPoint("LEFT", chkFiltre, "RIGHT", 6, 0)
    chkFiltre:SetChecked(item.filtreActif or false)
    chkFiltre:SetScript("OnClick", function(self)
        item.filtreActif = self:GetChecked() and true or false
        Refresh()
    end)
    y = y + 26

    if item.filtreActif then
        item.filtresCompatibles = item.filtresCompatibles or {}
        local selected = {}
        for _, k in ipairs(item.filtresCompatibles) do selected[k] = true end

        local lblComp = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblComp:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblComp:SetText("Filtres compatibles"); UI.ApplyLabel(lblComp)
        y = y + 18

        if #filtres == 0 then
            local none = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            none:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); UI.ApplySoftText(none)
            none:SetText("Aucun filtre défini (section Filtres).")
            y = y + 22
        else
            for _, filtre in ipairs(filtres) do
                local chk, lbl = UI.CreateStyledCheckbox(form, filtre.label or "?")
                chk:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lbl:SetPoint("LEFT", chk, "RIGHT", 6, 0)
                chk:SetChecked(selected[filtre.key] and true or false)
                local key = filtre.key
                chk:SetScript("OnClick", function(self)
                    selected[key] = self:GetChecked() and true or nil
                    local keys = {}
                    for _, f in ipairs(filtres) do if selected[f.key] then keys[#keys + 1] = f.key end end
                    item.filtresCompatibles = keys
                    if item.filtreEquipe and not selected[item.filtreEquipe] then item.filtreEquipe = nil end
                    Refresh()
                end)
                y = y + 22
            end
        end

        local lblEq = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblEq:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblEq:SetText("Filtre équipé"); UI.ApplyLabel(lblEq)
        y = y + 16
        local dropdown = CreateFrame("Frame", nil, form, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", form, "TOPLEFT", -16, -y)
        UIDropDownMenu_SetWidth(dropdown, W - 12)
        UI.StyleDropdown(dropdown)
        local function RefreshDD()
            local lblTxt = "Aucun"
            for _, f in ipairs(filtres) do if f.key == item.filtreEquipe then lblTxt = f.label; break end end
            UIDropDownMenu_SetText(dropdown, lblTxt)
        end
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            local infoNone = UIDropDownMenu_CreateInfo()
            infoNone.text = (item.filtreEquipe == nil) and "|cffd7b35f>  Aucun|r" or "    Aucun"
            infoNone.notCheckable = true
            infoNone.func = function() item.filtreEquipe = nil; RefreshDD() end
            UIDropDownMenu_AddButton(infoNone, level)
            for _, f in ipairs(filtres) do
                local isCompatible = false
                for _, k in ipairs(item.filtresCompatibles) do if k == f.key then isCompatible = true; break end end
                if isCompatible then
                    local info = UIDropDownMenu_CreateInfo()
                    local isSel = (item.filtreEquipe == f.key)
                    info.text = isSel and ("|cffd7b35f>  " .. f.label .. "|r") or ("    " .. f.label)
                    info.notCheckable = true
                    info.func = function() item.filtreEquipe = f.key; RefreshDD() end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end)
        RefreshDD()
        y = y + 40

        local chkMod, lblMod = UI.CreateStyledCheckbox(form, "Modifiable (échangeable en jeu) ?")
        chkMod:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblMod:SetPoint("LEFT", chkMod, "RIGHT", 6, 0)
        chkMod:SetChecked(item.filtreModifiable or false)
        chkMod:SetScript("OnClick", function(self) item.filtreModifiable = self:GetChecked() and true or false end)
        y = y + 26
    end
end

local function RenderGourdesSection(container, data)
    local UI = OS2.UI or {}
    local W = container:GetWidth()

    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", -100, 0)
    hint:SetJustifyH("LEFT"); UI.ApplySoftText(hint)
    hint:SetText("Les récipients pouvant contenir de l'eau.")

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 2)

    local acc = NewAccordion(container)
    acc.sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)
    acc.sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    acc.sb:SetPoint("TOPLEFT", acc.sf, "TOPRIGHT", 2, 0)
    acc.sb:SetPoint("BOTTOMLEFT", acc.sf, "BOTTOMRIGHT", 2, 0)

    local opts = {
        summary = function(item)
            local extra = (item.contenance and item.contenance ~= "") and ("  —  " .. item.contenance) or ""
            return (item.label or "?") .. extra
        end,
        formHeight = function(item)
            local h = 202
            if item.filtreActif then
                h = h + 18 + 40 + 26 + math.max(1, #data.filtres) * 22
            end
            return h
        end,
        buildForm = function(form, item, index, Refresh) BuildGourdeForm(form, item, data.filtres, Refresh) end,
        onDelete = function(index)
            table.remove(data.gourdes, index)
            if acc.expanded == index then acc.expanded = nil end
            acc.Render(data.gourdes, opts)
        end,
    }
    addBtn:SetScript("OnClick", function()
        data.gourdes[#data.gourdes + 1] = {
            key = GenerateKey("GOUR", data.gourdes), label = "Nouvelle gourde",
            contenance = "", desc = "", rechargeAuto = false,
            filtreActif = false, filtresCompatibles = {}, filtreModifiable = false, filtreEquipe = nil,
        }
        acc.expanded = #data.gourdes
        acc.Render(data.gourdes, opts)
    end)
    acc.Render(data.gourdes, opts)
end

-- ── Effet d'un État : Aura (appliquer/retirer) ou Message ──────────────
local function RenderEtatActionView(container, action, nav)
    local UI = OS2.UI or {}
    local W = container:GetWidth()

    local typeOptions = { "aura", "message" }
    local typeLabels = { aura = "Aura", message = "Message" }

    local lblType = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblType:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); lblType:SetText("Type d'effet"); UI.ApplyLabel(lblType)
    local typeTgl = CreateCycleToggle(container, W, 22, typeOptions, function(k) return typeLabels[k] end, function(k)
        action.type = k
        nav.Refresh()
    end)
    typeTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -16)
    typeTgl.SetValue(action.type or "message")

    local y = 46

    if action.type == "aura" then
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Aura (Spell ID)"); UI.ApplyLabel(lbl)
        local spellEB = UI.CreateStyledEditBox(container, W, 22)
        spellEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        spellEB:SetText(tostring(action.spellId or ""))
        SetupNumericEditBox(spellEB, false)
        spellEB:HookScript("OnTextChanged", function(self) action.spellId = tonumber(self:GetText()) end)
        y = y + 44

        local lblM = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblM:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblM:SetText("Mode"); UI.ApplyLabel(lblM)
        local modeTgl = CreateCycleToggle(container, W, 22, { "apply", "remove" },
            function(k) return (k == "remove") and "Retirer" or "Appliquer" end,
            function(k) action.mode = k end)
        modeTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        modeTgl.SetValue(action.mode or "apply")
    else
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Message (bandeau écran)"); UI.ApplyLabel(lbl)
        local msgEB = UI.CreateStyledEditBox(container, W, 22)
        msgEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        msgEB:SetText(action.text or "")
        msgEB:SetMaxLetters(120)
        msgEB:SetScript("OnTextChanged", function(self) action.text = self:GetText() end)
    end
end

-- ── États (bibliothèque commune, utilisée par Filtres et Sources) ──────
local function RenderEtatsSection(container, data, nav)
    local UI = OS2.UI or {}
    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", -100, 0)
    hint:SetJustifyH("LEFT"); UI.ApplySoftText(hint)
    hint:SetText("États d'une eau (ex : Parasite, Salée...). Une Source peut en avoir, un Filtre peut les neutraliser.")

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 2)

    local acc = NewAccordion(container)
    acc.sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)
    acc.sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    acc.sb:SetPoint("TOPLEFT", acc.sf, "TOPRIGHT", 2, 0)
    acc.sb:SetPoint("BOTTOMLEFT", acc.sf, "BOTTOMRIGHT", 2, 0)

    local ACTION_LIST_H = 84

    local opts = {
        summary = function(item) return string.format("%s  —  %d effet(s)", item.label or "?", #(item.actions or {})) end,
        formHeight = function() return 44 + 56 + 62 + 20 + ACTION_LIST_H + 16 end,
        buildForm = function(form, item)
            local W = form:GetWidth()
            local y = 0

            local lblNom = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblNom:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)
            local nomEB = UI.CreateStyledEditBox(form, W, 22)
            nomEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            nomEB:SetText(item.label or "")
            nomEB:SetScript("OnTextChanged", function(self) item.label = self:GetText() end)
            y = y + 44

            local lblIcon = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblIcon:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblIcon:SetText("Icône"); UI.ApplyLabel(lblIcon)
            y = y + 16

            local iconBtn = CreateFrame("Button", nil, form)
            iconBtn:SetSize(32, 32)
            iconBtn:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y)
            local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints(); iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconTex:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            local iconHl = iconBtn:CreateTexture(nil, "HIGHLIGHT"); iconHl:SetAllPoints(); iconHl:SetColorTexture(0.85, 0.75, 0.40, 0.15)

            local iconPickBtn = UI.CreatePanelButton(form, W - 32 - 8, 22, "Choisir une icône")
            iconPickBtn:SetPoint("LEFT", iconBtn, "RIGHT", 8, 0)
            iconPickBtn:SetScript("OnClick", function()
                if OmegaSpell and OmegaSpell.IconBrowser and OmegaSpell.IconBrowser.Open then
                    OmegaSpell.IconBrowser.Open(function(iconPath)
                        item.icon = iconPath
                        iconTex:SetTexture(iconPath)
                    end)
                else
                    OS2.Notify("Banque d'icônes indisponible (module Omega Spell / SpellCreator requis).", 1, 0.6, 0.2)
                end
            end)
            y = y + 40

            local lblDesc = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblDesc:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)
            local descBox = CreateFrame("Frame", nil, form)
            descBox:SetSize(W, 46)
            descBox:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints(); descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
            local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
            descBorder:SetPoint("BOTTOMLEFT", descBox, "BOTTOMLEFT", 2, 1); descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
            descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
            local descEB = CreateFrame("EditBox", nil, descBox)
            descEB:SetPoint("TOPLEFT", descBox, "TOPLEFT", 6, -4); descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6, 4)
            descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
            descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
            descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
            descEB:SetText(item.desc or "")
            descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            descEB:SetScript("OnTextChanged", function(self) item.desc = self:GetText() end)
            y = y + 62

            item.actions = item.actions or {}

            local lblFx = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblFx:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblFx:SetText("Effet (quand cet état n'est pas filtré)"); UI.ApplyStrongLabel(lblFx)
            local addFxBtn = UI.CreateAddButton(form, function() end)
            addFxBtn:SetPoint("TOPRIGHT", form, "TOPRIGHT", 0, -(y - 2))
            y = y + 20

            local sf, sb = CreateFlatScrollList(form)
            sf:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y)
            sf:SetSize(W - 12, ACTION_LIST_H)
            sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0); sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)

            local function RebuildFx()
                local rows = {}
                for i, a in ipairs(item.actions) do rows[i] = { label = DescribeAction(a, nil) } end
                BuildFlatList(sf, sb, ACTION_LIST_H, rows,
                    function(i) nav.Push(item.label or "État", function(c) RenderEtatActionView(c, item.actions[i], nav) end) end,
                    function(i) table.remove(item.actions, i); RebuildFx() end)
            end
            addFxBtn:SetScript("OnClick", function()
                item.actions[#item.actions + 1] = { type = "message", text = "" }
                RebuildFx()
                nav.Push(item.label or "État", function(c) RenderEtatActionView(c, item.actions[#item.actions], nav) end)
            end)
            RebuildFx()
        end,
        onDelete = function(index)
            table.remove(data.etats, index)
            if acc.expanded == index then acc.expanded = nil end
            acc.Render(data.etats, opts)
        end,
    }
    addBtn:SetScript("OnClick", function()
        data.etats[#data.etats + 1] = { key = GenerateKey("ETATLIB", data.etats), label = "Nouvel état", desc = "", icon = "Interface\\Icons\\INV_Misc_QuestionMark", actions = {} }
        acc.expanded = #data.etats
        acc.Render(data.etats, opts)
    end)
    acc.Render(data.etats, opts)
end

-- ── Filtres (bibliothèque, équipables sur les Gourdes) ─────────────────
local function RenderFiltresSection(container, data)
    local UI = OS2.UI or {}
    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", -100, 0)
    hint:SetJustifyH("LEFT"); UI.ApplySoftText(hint)
    hint:SetText("Filtres pouvant être équipés sur les Gourdes qui les acceptent.")

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 2)

    local acc = NewAccordion(container)
    acc.sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)
    acc.sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    acc.sb:SetPoint("TOPLEFT", acc.sf, "TOPRIGHT", 2, 0)
    acc.sb:SetPoint("BOTTOMLEFT", acc.sf, "BOTTOMRIGHT", 2, 0)

    local opts = {
        summary = function(item) return item.label or "?" end,
        formHeight = function() return 106 + 18 + math.max(1, #data.etats) * 22 end,
        buildForm = function(form, item)
            local W = form:GetWidth()
            local y = 0

            local lblNom = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblNom:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)
            local nomEB = UI.CreateStyledEditBox(form, W, 22)
            nomEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            nomEB:SetText(item.label or "")
            nomEB:SetScript("OnTextChanged", function(self) item.label = self:GetText() end)
            y = y + 44

            local lblDesc = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblDesc:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblDesc:SetText("À quoi il sert"); UI.ApplyLabel(lblDesc)
            local descBox = CreateFrame("Frame", nil, form)
            descBox:SetSize(W, 46)
            descBox:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints(); descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
            local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
            descBorder:SetPoint("BOTTOMLEFT", descBox, "BOTTOMLEFT", 2, 1); descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
            descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
            local descEB = CreateFrame("EditBox", nil, descBox)
            descEB:SetPoint("TOPLEFT", descBox, "TOPLEFT", 6, -4); descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6, 4)
            descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
            descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
            descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
            descEB:SetText(item.effet or "")
            descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            descEB:SetScript("OnTextChanged", function(self) item.effet = self:GetText() end)
            y = y + 62

            item.etatsFiltres = item.etatsFiltres or {}
            local selected = {}
            for _, k in ipairs(item.etatsFiltres) do selected[k] = true end

            local lblEtats = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblEtats:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblEtats:SetText("États neutralisés"); UI.ApplyLabel(lblEtats)
            y = y + 18

            if #data.etats == 0 then
                local none = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                none:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); UI.ApplySoftText(none)
                none:SetText("Aucun état défini (section États).")
                y = y + 22
            else
                for _, etat in ipairs(data.etats) do
                    local chk, lbl = UI.CreateStyledCheckbox(form, etat.label or "?")
                    chk:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lbl:SetPoint("LEFT", chk, "RIGHT", 6, 0)
                    chk:SetChecked(selected[etat.key] and true or false)
                    local key = etat.key
                    chk:SetScript("OnClick", function(self)
                        selected[key] = self:GetChecked() and true or nil
                        local keys = {}
                        for _, e in ipairs(data.etats) do if selected[e.key] then keys[#keys + 1] = e.key end end
                        item.etatsFiltres = keys
                    end)
                    y = y + 22
                end
            end
        end,
        onDelete = function(index)
            table.remove(data.filtres, index)
            if acc.expanded == index then acc.expanded = nil end
            acc.Render(data.filtres, opts)
        end,
    }
    addBtn:SetScript("OnClick", function()
        data.filtres[#data.filtres + 1] = { key = GenerateKey("FILT", data.filtres), label = "Nouveau filtre", effet = "", etatsFiltres = {} }
        acc.expanded = #data.filtres
        acc.Render(data.filtres, opts)
    end)
    acc.Render(data.filtres, opts)
end

-- ── Sources (Types d'eau) ───────────────────────────────────────────────
local function BuildSourceForm(form, item, Refresh, nav, etats)
    local UI = OS2.UI or {}
    local W = form:GetWidth()
    local y = 0

    local lblNom = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblNom:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)
    local nomEB = UI.CreateStyledEditBox(form, W, 22)
    nomEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
    nomEB:SetText(item.label or "")
    nomEB:SetScript("OnTextChanged", function(self) item.label = self:GetText() end)
    y = y + 44

    local lblDesc = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblDesc:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblDesc:SetText("Description"); UI.ApplyLabel(lblDesc)
    local descBox = CreateFrame("Frame", nil, form)
    descBox:SetSize(W, 40); descBox:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
    local descBg = descBox:CreateTexture(nil, "BACKGROUND"); descBg:SetAllPoints(); descBg:SetColorTexture(unpack(UI.colors.editBoxBg))
    local descBorder = descBox:CreateTexture(nil, "ARTWORK"); descBorder:SetHeight(1)
    descBorder:SetPoint("BOTTOMLEFT", descBox, "BOTTOMLEFT", 2, 1); descBorder:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -2, 1)
    descBorder:SetColorTexture(unpack(UI.colors.editBoxAccent))
    local descEB = CreateFrame("EditBox", nil, descBox)
    descEB:SetPoint("TOPLEFT", descBox, "TOPLEFT", 6, -4); descEB:SetPoint("BOTTOMRIGHT", descBox, "BOTTOMRIGHT", -6, 4)
    descEB:SetFontObject("GameFontNormalSmall"); UI.ApplyBodyText(descEB)
    descEB:SetAutoFocus(false); descEB:SetMultiLine(true); descEB:SetMaxLetters(256)
    descEB:SetJustifyH("LEFT"); descEB:SetJustifyV("TOP")
    descEB:SetText(item.desc or "")
    descEB:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    descEB:SetScript("OnTextChanged", function(self) item.desc = self:GetText() end)
    y = y + 56

    local lblProp = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblProp:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblProp:SetText("Propreté (0-100)"); UI.ApplyLabel(lblProp)
    local propEB = UI.CreateStyledEditBox(form, 80, 22)
    propEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
    propEB:SetNumeric(true); propEB:SetMaxLetters(3)
    propEB:SetText(tostring(item.proprete or 100))
    propEB:SetScript("OnTextChanged", function(self) item.proprete = tonumber(self:GetText()) or 0 end)
    propEB:SetScript("OnEditFocusLost", function(self)
        local v = math.max(0, math.min(100, tonumber(self:GetText()) or 0))
        self:SetText(tostring(v)); item.proprete = v
    end)
    y = y + 44

    item.etats = item.etats or {}
    local selected = {}
    for _, k in ipairs(item.etats) do selected[k] = true end

    local lblEtats = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblEtats:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblEtats:SetText("États de cette eau"); UI.ApplyLabel(lblEtats)
    y = y + 18

    if #etats == 0 then
        local none = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        none:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); UI.ApplySoftText(none)
        none:SetText("Aucun état défini (section États).")
        y = y + 22
    else
        for _, etat in ipairs(etats) do
            local chk, lbl = UI.CreateStyledCheckbox(form, etat.label or "?")
            chk:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lbl:SetPoint("LEFT", chk, "RIGHT", 6, 0)
            chk:SetChecked(selected[etat.key] and true or false)
            local key = etat.key
            chk:SetScript("OnClick", function(self)
                selected[key] = self:GetChecked() and true or nil
                local keys = {}
                for _, e in ipairs(etats) do if selected[e.key] then keys[#keys + 1] = e.key end end
                item.etats = keys
            end)
            y = y + 22
        end
    end

end

local function RenderSourcesSection(container, data, nav)
    local UI = OS2.UI or {}
    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", -100, 0)
    hint:SetJustifyH("LEFT"); UI.ApplySoftText(hint)
    hint:SetText("Les types d'eau que le joueur peut consommer.")

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 2)

    local acc = NewAccordion(container)
    acc.sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)
    acc.sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    acc.sb:SetPoint("TOPLEFT", acc.sf, "TOPRIGHT", 2, 0)
    acc.sb:SetPoint("BOTTOMLEFT", acc.sf, "BOTTOMRIGHT", 2, 0)

    local opts = {
        summary = function(item) return string.format("%s  —  propreté %d%%", item.label or "?", item.proprete or 0) end,
        formHeight = function(item) return 144 + 18 + math.max(1, #data.etats) * 22 end,
        buildForm = function(form, item, index, Refresh) BuildSourceForm(form, item, Refresh, nav, data.etats) end,
        onDelete = function(index)
            table.remove(data.sources, index)
            if acc.expanded == index then acc.expanded = nil end
            acc.Render(data.sources, opts)
        end,
    }
    addBtn:SetScript("OnClick", function()
        data.sources[#data.sources + 1] = {
            key = GenerateKey("SRCE", data.sources), label = "Nouveau type d'eau", desc = "",
            proprete = 100, etats = {},
        }
        acc.expanded = #data.sources
        acc.Render(data.sources, opts)
    end)
    acc.Render(data.sources, opts)
end

-- ── Clés ────────────────────────────────────────────────────────────────
local function RenderClesSection(container, data)
    local UI = OS2.UI or {}
    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", -100, 0)
    hint:SetJustifyH("LEFT"); UI.ApplySoftText(hint)
    hint:SetText("Valeurs nommées réutilisables dans les Conditions et le Fonctionnement.")

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 2)

    local acc = NewAccordion(container)
    acc.sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)
    acc.sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    acc.sb:SetPoint("TOPLEFT", acc.sf, "TOPRIGHT", 2, 0)
    acc.sb:SetPoint("BOTTOMLEFT", acc.sf, "BOTTOMRIGHT", 2, 0)

    local opts = {
        summary = function(item)
            return string.format("%s  —  %s · %s", item.label or "?", item.saisiePar or "MJ", tostring(item.valeurDefaut or 0))
        end,
        formHeight = function(item) return 132 end,
        buildForm = function(form, item, index, Refresh)
            local W = form:GetWidth()
            local y = 0

            local lblNom = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblNom:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblNom:SetText("Nom"); UI.ApplyLabel(lblNom)
            local nomEB = UI.CreateStyledEditBox(form, W, 22)
            nomEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            nomEB:SetText(item.label or "")
            nomEB:SetScript("OnTextChanged", function(self) item.label = self:GetText() end)
            y = y + 44

            local lblSaisie = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblSaisie:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblSaisie:SetText("Saisie par"); UI.ApplyLabel(lblSaisie)
            local saisieTgl = CreateCycleToggle(form, W, 22, { "MJ", "Joueur" }, nil, function(v)
                item.saisiePar = v
                Refresh()
            end)
            saisieTgl.button:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            saisieTgl.SetValue(item.saisiePar or "MJ")
            y = y + 44

            local lblVal = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lblVal:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -y); lblVal:SetText("Valeur par défaut"); UI.ApplyLabel(lblVal)
            local valEB = UI.CreateStyledEditBox(form, W, 22)
            valEB:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(y + 16))
            valEB:SetText(tostring(item.valeurDefaut or 0))
            SetupNumericEditBox(valEB, true, true)
            valEB:HookScript("OnTextChanged", function(self) item.valeurDefaut = ParseDecimal(self:GetText()) or 0 end)
            y = y + 44
        end,
        onDelete = function(index)
            table.remove(data.cles, index)
            if acc.expanded == index then acc.expanded = nil end
            acc.Render(data.cles, opts)
        end,
    }
    addBtn:SetScript("OnClick", function()
        data.cles[#data.cles + 1] = { key = GenerateKey("CLE", data.cles), label = "Nouvelle clé", saisiePar = "MJ", valeurDefaut = 0 }
        acc.expanded = #data.cles
        acc.Render(data.cles, opts)
    end)
    acc.Render(data.cles, opts)
end

-- ── Conditions : Opérande / Action / Condition (navigation en pile) ────
local RenderOperandView, RenderActionView, RenderConditionView, BuildActionBranch

RenderOperandView = function(container, op, cles, nav)
    local UI = OS2.UI or {}
    local W = container:GetWidth()

    local typeOptions = { "fixed", "cle", "expr" }
    local typeLabels  = { fixed = "Brut", cle = "Clé", expr = "Expression" }

    local lblType = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblType:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); lblType:SetText("Type"); UI.ApplyLabel(lblType)
    local typeTgl = CreateCycleToggle(container, W, 22, typeOptions, function(k) return typeLabels[k] end, function(k)
        op.type = k
        nav.Refresh()
    end)
    typeTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -16)
    typeTgl.SetValue(op.type or "fixed")

    local y = 46

    if op.type == "cle" then
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Clé"); UI.ApplyLabel(lbl)

        local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", container, "TOPLEFT", -16, -(y + 12))
        UIDropDownMenu_SetWidth(dropdown, W - 12)
        UI.StyleDropdown(dropdown)
        local function RefreshDD()
            local lblTxt = "Aucune clé"
            for _, c in ipairs(cles) do if c.key == op.cleKey then lblTxt = c.label; break end end
            UIDropDownMenu_SetText(dropdown, lblTxt)
        end
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, c in ipairs(cles) do
                local info = UIDropDownMenu_CreateInfo()
                local isSel = (op.cleKey == c.key)
                info.text = isSel and ("|cffd7b35f>  " .. c.label .. "|r") or ("    " .. c.label)
                info.value = c.key
                info.notCheckable = true
                info.func = function() op.cleKey = c.key; RefreshDD() end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        RefreshDD()
        y = y + 40

        local newCleBtn = UI.CreatePanelButton(container, W, 22, "+ Nouvelle clé")
        newCleBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
        newCleBtn:SetScript("OnClick", function()
            local newCle = { key = GenerateKey("CLE", cles), label = "Nouvelle clé", saisiePar = "MJ", valeurDefaut = 0 }
            cles[#cles + 1] = newCle
            op.cleKey = newCle.key
            nav.Refresh()
        end)

    elseif op.type == "expr" then
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Opération"); UI.ApplyLabel(lbl)
        local opTgl = CreateCycleToggle(container, W, 22,
            { "addition", "soustraction", "multiplication", "division" },
            function(k) return OPERATION_LABELS[k] .. "  (" .. OPERATION_SYMBOLS[k] .. ")" end,
            function(k) op.op = k end)
        opTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        opTgl.SetValue(op.op or "addition")
        y = y + 46

        op.left  = op.left  or { type = "fixed", value = 0, unit = "brut" }
        op.right = op.right or { type = "fixed", value = 0, unit = "brut" }

        local leftBtn = UI.CreatePanelButton(container, W, 22, "Opérande gauche")
        leftBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
        leftBtn:SetScript("OnClick", function()
            nav.Push("Opérande gauche", function(c) RenderOperandView(c, op.left, cles, nav) end)
        end)
        y = y + 26
        local leftPrev = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        leftPrev:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); UI.ApplySoftText(leftPrev)
        leftPrev:SetText(DescribeOperand(op.left, cles))
        y = y + 26

        local rightBtn = UI.CreatePanelButton(container, W, 22, "Opérande droite")
        rightBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
        rightBtn:SetScript("OnClick", function()
            nav.Push("Opérande droite", function(c) RenderOperandView(c, op.right, cles, nav) end)
        end)
        y = y + 26
        local rightPrev = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        rightPrev:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); UI.ApplySoftText(rightPrev)
        rightPrev:SetText(DescribeOperand(op.right, cles))

    else -- fixed
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Valeur"); UI.ApplyLabel(lbl)
        local valEB = UI.CreateStyledEditBox(container, W, 22)
        valEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        valEB:SetText(tostring(op.value or 0))
        SetupNumericEditBox(valEB, true, true)
        valEB:HookScript("OnTextChanged", function(self) op.value = ParseDecimal(self:GetText()) or 0 end)
        y = y + 44

        local lblU = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblU:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblU:SetText("Unité"); UI.ApplyLabel(lblU)
        local uTgl = CreateCycleToggle(container, W, 22, { "brut", "pourcent" },
            function(k) return (k == "pourcent") and "Pourcentage (% Capacité)" or "Brut" end,
            function(k) op.unit = k end)
        uTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        uTgl.SetValue(op.unit or "brut")
    end
end

RenderActionView = function(container, action, cles, nav)
    local UI = OS2.UI or {}
    local W = container:GetWidth()

    local typeOptions = { "formule", "aura", "message" }
    local typeLabels = { formule = "Formule", aura = "Aura", message = "Message" }

    local lblType = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblType:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); lblType:SetText("Type d'action"); UI.ApplyLabel(lblType)
    local typeTgl = CreateCycleToggle(container, W, 22, typeOptions, function(k) return typeLabels[k] end, function(k)
        action.type = k
        nav.Refresh()
    end)
    typeTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -16)
    typeTgl.SetValue(action.type or "message")

    local y = 46

    if action.type == "formule" then
        action.formule = action.formule or { operation = "addition" }
        local cfgBtn = UI.CreatePanelButton(container, W, 22, "Configurer la formule")
        cfgBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
        cfgBtn:SetScript("OnClick", function()
            nav.Push("Formule", function(c) RenderConditionView(c, action.formule, cles, nav, false) end)
        end)
        y = y + 26
        local prev = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        prev:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
        prev:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -y)
        prev:SetWordWrap(true); prev:SetJustifyH("LEFT"); UI.ApplySoftText(prev)
        prev:SetText(DescribeCondition(action.formule, cles))

    elseif action.type == "aura" then
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Aura (Spell ID)"); UI.ApplyLabel(lbl)
        local spellEB = UI.CreateStyledEditBox(container, W, 22)
        spellEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        spellEB:SetText(tostring(action.spellId or ""))
        SetupNumericEditBox(spellEB, false)
        spellEB:HookScript("OnTextChanged", function(self) action.spellId = tonumber(self:GetText()) end)
        y = y + 44

        local lblM = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblM:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblM:SetText("Mode"); UI.ApplyLabel(lblM)
        local modeTgl = CreateCycleToggle(container, W, 22, { "apply", "remove" },
            function(k) return (k == "remove") and "Retirer" or "Appliquer" end,
            function(k) action.mode = k end)
        modeTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        modeTgl.SetValue(action.mode or "apply")

    else -- message
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Message (bandeau écran)"); UI.ApplyLabel(lbl)
        local msgEB = UI.CreateStyledEditBox(container, W, 22)
        msgEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        msgEB:SetText(action.text or "")
        msgEB:SetMaxLetters(120)
        msgEB:SetScript("OnTextChanged", function(self) action.text = self:GetText() end)
    end
end

BuildActionBranch = function(container, y, W, title, actions, cles, nav)
    local UI = OS2.UI or {}
    local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText(title); UI.ApplyStrongLabel(lbl)

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -(y - 2))
    y = y + 20

    local LIST_H = 84
    local sf, sb = CreateFlatScrollList(container)
    sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y)
    sf:SetSize(W - 12, LIST_H)
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0); sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)

    local function Rebuild()
        local rows = {}
        for i, a in ipairs(actions) do rows[i] = { label = DescribeAction(a, cles) } end
        BuildFlatList(sf, sb, LIST_H, rows,
            function(i) nav.Push(title, function(c) RenderActionView(c, actions[i], cles, nav) end) end,
            function(i) table.remove(actions, i); Rebuild() end)
    end
    addBtn:SetScript("OnClick", function()
        actions[#actions + 1] = { type = "message", text = "" }
        Rebuild()
        nav.Push(title, function(c) RenderActionView(c, actions[#actions], cles, nav) end)
    end)
    Rebuild()

    y = y + LIST_H + 16
    return y
end

RenderConditionView = function(container, cond, cles, nav, showLabel)
    local UI = OS2.UI or {}
    local W = container:GetWidth()
    local y = 0

    if showLabel then
        local lbl = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lbl:SetText("Nom"); UI.ApplyLabel(lbl)
        local nomEB = UI.CreateStyledEditBox(container, W, 22)
        nomEB:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        nomEB:SetText(cond.label or "")
        nomEB:SetScript("OnTextChanged", function(self) cond.label = self:GetText() end)
        y = y + 44
    end

    local lblBase = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblBase:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblBase:SetText("Base"); UI.ApplyLabel(lblBase)
    local baseBtn = UI.CreatePanelButton(container, W, 22, "Définir la Base")
    baseBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
    baseBtn:SetScript("OnClick", function()
        cond.base = cond.base or { type = "fixed", value = 0, unit = "brut" }
        nav.Push("Base", function(c) RenderOperandView(c, cond.base, cles, nav) end)
    end)
    y = y + 42
    local basePrev = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    basePrev:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); UI.ApplySoftText(basePrev)
    basePrev:SetText(DescribeOperand(cond.base, cles))
    y = y + 30

    local lblOp = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblOp:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblOp:SetText("Opération"); UI.ApplyLabel(lblOp)
    local opTgl = CreateCycleToggle(container, W, 22,
        { "addition", "soustraction", "multiplication", "division", "si" },
        function(k) return OPERATION_LABELS[k] end,
        function(k) cond.operation = k; nav.Refresh() end)
    opTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
    opTgl.SetValue(cond.operation or "addition")
    y = y + 46

    if cond.operation == "si" then
        local lblCmp = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblCmp:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblCmp:SetText("Comparateur"); UI.ApplyLabel(lblCmp)
        local cmpTgl = CreateCycleToggle(container, W, 22, { ">", ">=", "<", "<=", "=", "~=" },
            function(k) return COMPARATEUR_LABELS[k] end,
            function(k) cond.comparateur = k end)
        cmpTgl.button:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        cmpTgl.SetValue(cond.comparateur or ">")
        y = y + 46

        local lblVSi = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblVSi:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblVSi:SetText("Valeur seuil"); UI.ApplyLabel(lblVSi)
        local vSiBtn = UI.CreatePanelButton(container, W, 22, "Définir le seuil")
        vSiBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        vSiBtn:SetScript("OnClick", function()
            cond.valeurSi = cond.valeurSi or { type = "fixed", value = 0, unit = "brut" }
            nav.Push("Valeur seuil", function(c) RenderOperandView(c, cond.valeurSi, cles, nav) end)
        end)
        y = y + 42
        local vSiPrev = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        vSiPrev:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); UI.ApplySoftText(vSiPrev)
        vSiPrev:SetText(DescribeOperand(cond.valeurSi, cles))
        y = y + 30

        cond.alors = cond.alors or { actions = {} }
        cond.sinon = cond.sinon or { actions = {} }
        cond.alors.actions = cond.alors.actions or {}
        cond.sinon.actions = cond.sinon.actions or {}

        y = BuildActionBranch(container, y, W, "Alors", cond.alors.actions, cles, nav)
        y = BuildActionBranch(container, y, W, "Sinon", cond.sinon.actions, cles, nav)
    else
        local lblV = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblV:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); lblV:SetText("Valeur"); UI.ApplyLabel(lblV)
        local vBtn = UI.CreatePanelButton(container, W, 22, "Définir la Valeur")
        vBtn:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(y + 16))
        vBtn:SetScript("OnClick", function()
            cond.valeur = cond.valeur or { type = "fixed", value = 0, unit = "brut" }
            nav.Push("Valeur", function(c) RenderOperandView(c, cond.valeur, cles, nav) end)
        end)
        y = y + 42
        local vPrev = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        vPrev:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -y); UI.ApplySoftText(vPrev)
        vPrev:SetText(DescribeOperand(cond.valeur, cles))
    end
end

local function RenderConditionsSection(container, data, nav)
    local UI = OS2.UI or {}
    local hint = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0); hint:SetPoint("TOPRIGHT", container, "TOPRIGHT", -100, 0)
    hint:SetJustifyH("LEFT"); UI.ApplySoftText(hint)
    hint:SetText("Formules réutilisables dans le Fonctionnement (Capacité / Vitesse).")

    local addBtn = UI.CreateAddButton(container, function() end)
    addBtn:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, 2)

    local W = container:GetWidth()
    local sf, sb = CreateFlatScrollList(container)
    sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -28)
    sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -12, 0)
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0); sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)

    local function Rebuild()
        local rows = {}
        for i, cond in ipairs(data.conditions) do
            rows[i] = { label = string.format("%s  —  %s", cond.label or "?", DescribeCondition(cond, data.cles)) }
        end
        BuildFlatList(sf, sb, sf:GetHeight(), rows,
            function(i)
                nav.Push(data.conditions[i].label or "Condition", function(c) RenderConditionView(c, data.conditions[i], data.cles, nav, true) end)
            end,
            function(i) table.remove(data.conditions, i); Rebuild() end)
    end
    addBtn:SetScript("OnClick", function()
        local newCond = { key = GenerateKey("COND", data.conditions), label = "Nouvelle condition", operation = "addition" }
        data.conditions[#data.conditions + 1] = newCond
        Rebuild()
        nav.Push(newCond.label, function(c) RenderConditionView(c, newCond, data.cles, nav, true) end)
    end)
    Rebuild()
end

-- ── Fonctionnement : Base + Conditions (Capacité / Vitesse) + Paliers ──
local function RenderFonctionnementSection(container, data)
    local UI = OS2.UI or {}
    data.fonctionnement = data.fonctionnement or {}
    local fonct = data.fonctionnement
    fonct.capacite = fonct.capacite or {}
    fonct.vitesse  = fonct.vitesse  or {}
    fonct.paliers  = fonct.paliers  or {}

    local SB_W = 8
    local sf = CreateFrame("ScrollFrame", nil, container)
    sf:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    sf:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -SB_W - 6, 0)
    sf:EnableMouseWheel(true)
    local sb = CreateFrame("Slider", nil, container)
    sb:SetPoint("TOPLEFT", sf, "TOPRIGHT", 2, 0); sb:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 2, 0)
    sb:SetWidth(SB_W); sb:SetOrientation("VERTICAL"); sb:SetMinMaxValues(0, 0); sb:SetValue(0)
    local sbt = sb:CreateTexture(nil, "THUMB"); sbt:SetSize(SB_W - 2, 24); sbt:SetColorTexture(0.5, 0.42, 0.22, 0.85); sb:SetThumbTexture(sbt)
    sf:SetScript("OnMouseWheel", function(_, d) sb:SetValue(math.max(0, math.min(select(2, sb:GetMinMaxValues()), sb:GetValue() - d * 44))) end)
    sb:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)

    local cW = math.max(1, math.floor(sf:GetWidth()))
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(cW, 1); sf:SetScrollChild(c)

    local y = 0

    local function BuildBaseBlock(title, section)
        section.base = section.base or {}
        section.conditionKeys = section.conditionKeys or {}
        local base = section.base

        local lblTitle = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblTitle:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblTitle:SetText(title); UI.ApplyStrongLabel(lblTitle)
        y = y + 22

        local lblCle = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblCle:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblCle:SetText("Base : Clé  ×  Coefficient"); UI.ApplyLabel(lblCle)
        y = y + 16

        local dropdown = CreateFrame("Frame", nil, c, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", c, "TOPLEFT", -16, -y)
        UIDropDownMenu_SetWidth(dropdown, cW - 130)
        UI.StyleDropdown(dropdown)
        local function RefreshDD()
            local lblTxt = "Aucune clé"
            for _, cl in ipairs(data.cles) do if cl.key == base.cleKey then lblTxt = cl.label; break end end
            UIDropDownMenu_SetText(dropdown, lblTxt)
        end
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            for _, cl in ipairs(data.cles) do
                local info = UIDropDownMenu_CreateInfo()
                local isSel = (base.cleKey == cl.key)
                info.text = isSel and ("|cffd7b35f>  " .. cl.label .. "|r") or ("    " .. cl.label)
                info.value = cl.key
                info.notCheckable = true
                info.func = function() base.cleKey = cl.key; RefreshDD() end
                UIDropDownMenu_AddButton(info, level)
            end
        end)
        RefreshDD()

        local coefEB = UI.CreateStyledEditBox(c, 90, 22)
        coefEB:SetPoint("TOPLEFT", c, "TOPLEFT", cW - 90, -y)
        SetupNumericEditBox(coefEB, true, true)
        coefEB:SetText(tostring(base.coef or 1))
        coefEB:HookScript("OnTextChanged", function(self) base.coef = ParseDecimal(self:GetText()) or 1 end)
        y = y + 30

        local lblConds = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblConds:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblConds:SetText("Conditions supplémentaires"); UI.ApplyLabel(lblConds)
        y = y + 18

        local selected = {}
        for _, k in ipairs(section.conditionKeys) do selected[k] = true end

        if #data.conditions == 0 then
            local none = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            none:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); UI.ApplySoftText(none)
            none:SetText("Aucune Condition définie.")
            y = y + 22
        else
            for _, cond in ipairs(data.conditions) do
                local chk, lbl = UI.CreateStyledCheckbox(c, string.format("%s  (%s)", cond.label or "?", DescribeCondition(cond, data.cles)))
                chk:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lbl:SetPoint("LEFT", chk, "RIGHT", 6, 0)
                chk:SetChecked(selected[cond.key] and true or false)
                local key = cond.key
                chk:SetScript("OnClick", function(self)
                    selected[key] = self:GetChecked() and true or nil
                    local keys = {}
                    for _, cc in ipairs(data.conditions) do
                        if selected[cc.key] then keys[#keys + 1] = cc.key end
                    end
                    section.conditionKeys = keys
                end)
                y = y + 22
            end
        end
        y = y + 14
    end

    BuildBaseBlock("Capacité (unités totales)", fonct.capacite)
    do
        local sep = c:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        y = y + 14
    end
    BuildBaseBlock("Vitesse de descente", fonct.vitesse)
    do
        local sep = c:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        y = y + 14
    end

    -- Gorgée : règle globale de consommation (le litrage reste défini par Gourde)
    do
        fonct.gorgee = fonct.gorgee or {}
        local gorgee = fonct.gorgee

        local lblTitle = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblTitle:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblTitle:SetText("Gorgée"); UI.ApplyStrongLabel(lblTitle)
        y = y + 22

        local lblMl = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblMl:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblMl:SetText("Volume par gorgée (mL)"); UI.ApplyLabel(lblMl)
        y = y + 16
        local mlEB = UI.CreateStyledEditBox(c, cW, 22)
        mlEB:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
        SetupNumericEditBox(mlEB, false)
        mlEB:SetText(tostring(gorgee.ml or 0))
        mlEB:HookScript("OnTextChanged", function(self) gorgee.ml = tonumber(self:GetText()) or 0 end)
        y = y + 30

        local lblPts = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lblPts:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblPts:SetText("Points d'hydratation rendus par gorgée"); UI.ApplyLabel(lblPts)
        y = y + 16
        local ptsEB = UI.CreateStyledEditBox(c, cW, 22)
        ptsEB:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
        SetupNumericEditBox(ptsEB, false)
        ptsEB:SetText(tostring(gorgee.points or 0))
        ptsEB:HookScript("OnTextChanged", function(self) gorgee.points = tonumber(self:GetText()) or 0 end)
        y = y + 30

        local hint = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); hint:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        hint:SetJustifyH("LEFT"); hint:SetWordWrap(true); UI.ApplySoftText(hint)
        hint:SetText("Le litrage total (contenance) se définit par Gourde ; cette règle est commune à toutes les gourdes du système.")
        y = y + 34
    end
    do
        local sep = c:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); sep:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        y = y + 14
    end

    local lblPal = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPal:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y); lblPal:SetText("Paliers d'état"); UI.ApplyStrongLabel(lblPal)
    local addPalBtn = UI.CreateAddButton(c, function() end)
    addPalBtn:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -(y - 2))
    y = y + 24

    local PAL_LIST_H = 200
    local palAcc = NewAccordion(c)
    palAcc.sf:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
    palAcc.sf:SetSize(cW - SB_W - 4, PAL_LIST_H)
    palAcc.sb:SetPoint("TOPLEFT", palAcc.sf, "TOPRIGHT", 2, 0)
    palAcc.sb:SetPoint("BOTTOMLEFT", palAcc.sf, "BOTTOMRIGHT", 2, 0)

    local palOpts = {
        summary = function(pal) return string.format("%d%%  —  %s", pal.seuil or 0, pal.label or "") end,
        formHeight = function() return 176 end,
        buildForm = function(form, item)
            local W2 = form:GetWidth()
            local yy = 0
            local function Field(labelText, initial, onChange, numeric)
                local l = form:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                l:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -yy); l:SetText(labelText); UI.ApplyLabel(l)
                local eb = UI.CreateStyledEditBox(form, W2, 22)
                eb:SetPoint("TOPLEFT", form, "TOPLEFT", 0, -(yy + 16))
                eb:SetText(initial or "")
                if numeric then
                    SetupNumericEditBox(eb, false)
                    eb:HookScript("OnTextChanged", function(self) onChange(tonumber(self:GetText()) or 0) end)
                else
                    eb:SetScript("OnTextChanged", function(self) onChange(self:GetText()) end)
                end
                yy = yy + 44
            end
            Field("Seuil (%)", tostring(item.seuil or 50), function(v) item.seuil = v end, true)
            Field("État", item.label or "", function(v) item.label = v end)
            Field("Message", item.message or "", function(v) item.message = v end)
            Field("Debuff (sort / ID)", item.debuff or "", function(v) item.debuff = v end)
        end,
        onDelete = function(index)
            table.remove(fonct.paliers, index)
            if palAcc.expanded == index then palAcc.expanded = nil end
            palAcc.Render(fonct.paliers, palOpts)
        end,
    }
    addPalBtn:SetScript("OnClick", function()
        fonct.paliers[#fonct.paliers + 1] = { key = GenerateKey("ETAT", fonct.paliers), seuil = 50, label = "", message = "", debuff = "" }
        palAcc.expanded = #fonct.paliers
        palAcc.Render(fonct.paliers, palOpts)
    end)
    palAcc.Render(fonct.paliers, palOpts)

    y = y + PAL_LIST_H + 20
    c:SetHeight(math.max(1, y))
    local maxS = math.max(0, y - sf:GetHeight())
    sb:SetMinMaxValues(0, maxS); sb:SetAlpha(maxS > 0 and 1 or 0.2)
end

-- ══════════════════════════════════════════════════════════════════════
-- Fenêtre unique : sidebar + fil d'Ariane + zone de contenu
-- ══════════════════════════════════════════════════════════════════════
local SECTION_ORDER = {
    { key = "general",        label = "Général",        render = RenderGeneralSection },
    { key = "cles",           label = "Clés",           render = RenderClesSection },
    { key = "etats",          label = "États",          render = RenderEtatsSection },
    { key = "filtres",        label = "Filtres",        render = RenderFiltresSection },
    { key = "sources",        label = "Sources",        render = RenderSourcesSection },
    { key = "gourdes",        label = "Gourdes",        render = RenderGourdesSection },
    { key = "conditions",     label = "Conditions",     render = RenderConditionsSection },
    { key = "fonctionnement", label = "Fonctionnement", render = RenderFonctionnementSection },
}

local builderWindow = nil

local function GetOrCreateHydratationBuilder()
    if builderWindow then return builderWindow end
    local UI       = OS2.UI or {}
    local WW, WH   = 700, 580
    local PAD      = 14
    local HDR_H    = 36
    local SIDE_W   = 130
    local FOOTER_H = 46
    local CRUMB_H  = 26

    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(WW, WH)
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

    -- Barre latérale
    local sideButtons = {}
    local sy = -(HDR_H + 10)
    for _, sec in ipairs(SECTION_ORDER) do
        local btn = CreateFrame("Button", nil, p)
        btn:SetSize(SIDE_W, 26)
        btn:SetPoint("TOPLEFT", p, "TOPLEFT", PAD, sy)
        local sBg = btn:CreateTexture(nil, "BACKGROUND"); sBg:SetAllPoints(); sBg:SetColorTexture(0.10, 0.10, 0.10, 1)
        local sLine = btn:CreateTexture(nil, "ARTWORK"); sLine:SetWidth(2)
        sLine:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0); sLine:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        sLine:SetColorTexture(0.80, 0.70, 0.40, 1); sLine:Hide()
        local sHl = btn:CreateTexture(nil, "HIGHLIGHT"); sHl:SetAllPoints(); sHl:SetColorTexture(0.85, 0.75, 0.40, 0.10)
        local sLbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sLbl:SetPoint("LEFT", btn, "LEFT", 10, 0); sLbl:SetText(sec.label)
        sLbl:SetTextColor(0.80, 0.76, 0.65, 1)
        sideButtons[sec.key] = { btn = btn, bg = sBg, line = sLine, lbl = sLbl }
        sy = sy - 30
    end

    local vSep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(vSep, true); vSep:SetWidth(1)
    vSep:SetPoint("TOP",    p, "TOPLEFT",    PAD + SIDE_W + 10, -HDR_H)
    vSep:SetPoint("BOTTOM", p, "BOTTOMLEFT", PAD + SIDE_W + 10, FOOTER_H)

    local CONTENT_X = PAD + SIDE_W + 24
    local CONTENT_R = -PAD

    -- Fil d'Ariane
    local crumbBar = CreateFrame("Frame", nil, p)
    crumbBar:SetPoint("TOPLEFT",  p, "TOPLEFT",  CONTENT_X, -(HDR_H + 8))
    crumbBar:SetPoint("TOPRIGHT", p, "TOPRIGHT", CONTENT_R, -(HDR_H + 8))
    crumbBar:SetHeight(CRUMB_H)
    crumbBar:Hide()

    local backBtn = CreateFrame("Button", nil, crumbBar); backBtn:SetSize(76, 20)
    backBtn:SetPoint("LEFT", crumbBar, "LEFT", 0, 0)
    local bBg = backBtn:CreateTexture(nil, "BACKGROUND"); bBg:SetAllPoints(); bBg:SetColorTexture(0.14, 0.12, 0.06, 1)
    local bHl = backBtn:CreateTexture(nil, "HIGHLIGHT"); bHl:SetAllPoints(); bHl:SetColorTexture(0.85, 0.75, 0.40, 0.15)
    local bLbl = backBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); bLbl:SetAllPoints()
    bLbl:SetText("← Retour"); bLbl:SetTextColor(0.88, 0.78, 0.40, 1)

    local crumbTxt = crumbBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    crumbTxt:SetPoint("LEFT", backBtn, "RIGHT", 10, 0)
    crumbTxt:SetPoint("RIGHT", crumbBar, "RIGHT", 0, 0)
    crumbTxt:SetJustifyH("LEFT"); crumbTxt:SetTextColor(0.65, 0.62, 0.55, 1)

    do
        local sep = crumbBar:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(sep); sep:SetHeight(1)
        sep:SetPoint("BOTTOMLEFT",  crumbBar, "BOTTOMLEFT",  0, -6)
        sep:SetPoint("BOTTOMRIGHT", crumbBar, "BOTTOMRIGHT", 0, -6)
    end

    local contentTop = CreateFrame("Frame", nil, p)

    local footerSep = p:CreateTexture(nil, "ARTWORK"); UI.ApplySeparator(footerSep); footerSep:SetHeight(1)
    footerSep:SetPoint("BOTTOMLEFT",  p, "BOTTOMLEFT",  0, FOOTER_H)
    footerSep:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, FOOTER_H)

    local validBtn = UI.CreatePanelButton(p, 150, 24, "Valider")
    validBtn:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -PAD, 12)

    -- ── State ────────────────────────────────────────────────────────
    local _cb, _data = nil, nil
    local navStack = {}

    local function NewContentChild()
        if contentTop._child then contentTop._child:Hide() end
        local child = CreateFrame("Frame", nil, contentTop)
        child:SetAllPoints(contentTop)
        contentTop._child = child
        return child
    end

    local RenderCurrentView
    local function PushView(label, renderFn)
        navStack[#navStack + 1] = { label = label, render = renderFn }
        RenderCurrentView()
    end
    local function PopView()
        if #navStack > 1 then table.remove(navStack) end
        RenderCurrentView()
    end
    local function ResetNav(label, renderFn)
        navStack = { { label = label, render = renderFn } }
        RenderCurrentView()
    end

    RenderCurrentView = function()
        contentTop:ClearAllPoints()
        if #navStack > 1 then
            crumbBar:Show()
            contentTop:SetPoint("TOPLEFT", p, "TOPLEFT", CONTENT_X, -(HDR_H + 8 + CRUMB_H + 8))
        else
            crumbBar:Hide()
            contentTop:SetPoint("TOPLEFT", p, "TOPLEFT", CONTENT_X, -(HDR_H + 8))
        end
        contentTop:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", CONTENT_R, FOOTER_H + 10)

        local path = {}
        for _, v in ipairs(navStack) do path[#path + 1] = v.label end
        crumbTxt:SetText(table.concat(path, "   ›   "))

        local top = navStack[#navStack]
        local child = NewContentChild()
        if top then top.render(child) end
    end
    backBtn:SetScript("OnClick", PopView)

    local nav = { Push = PushView, Pop = PopView, Refresh = function() RenderCurrentView() end }

    local function SelectSection(key)
        for k, sb2 in pairs(sideButtons) do
            local active = (k == key)
            sb2.line:SetShown(active)
            sb2.bg:SetColorTexture(active and 0.16 or 0.10, active and 0.13 or 0.10, active and 0.06 or 0.10, 1)
            local c1 = active and 0.95 or 0.80
            local c2 = active and 0.85 or 0.76
            local c3 = active and 0.55 or 0.65
            sb2.lbl:SetTextColor(c1, c2, c3, 1)
        end
        for _, sec in ipairs(SECTION_ORDER) do
            if sec.key == key then
                ResetNav(sec.label, function(c) sec.render(c, _data, nav) end)
                break
            end
        end
    end

    for _, sec in ipairs(SECTION_ORDER) do
        sideButtons[sec.key].btn:SetScript("OnClick", function() SelectSection(sec.key) end)
    end

    validBtn:SetScript("OnClick", function()
        local nom = (_data.label or ""):match("^%s*(.-)%s*$")
        if nom == "" then SelectSection("general"); return end
        if _cb then _cb(_data) end
        p:Hide()
    end)

    p._open = function(mode, item, cb)
        _cb = cb
        _data = {
            key            = item and item.key or nil,
            label          = item and item.label or "",
            desc           = item and item.desc or "",
            gourdes        = (item and item.gourdes) and { unpack(item.gourdes) } or {},
            etats          = (item and item.etats) and { unpack(item.etats) } or {},
            filtres        = (item and item.filtres) and { unpack(item.filtres) } or {},
            sources        = (item and item.sources) and { unpack(item.sources) } or {},
            cles           = (item and item.cles) and { unpack(item.cles) } or {},
            conditions     = (item and item.conditions) and { unpack(item.conditions) } or {},
            fonctionnement = (item and item.fonctionnement) or {},
        }
        titleStr:SetText(mode == "create" and "Nouveau Système : Hydratation" or ("Modifier — " .. ((item and item.label ~= "" and item.label) or "Hydratation")))
        SelectSection("general")
        p:Show()
    end

    builderWindow = p
    return p
end

local function OpenHydratationPanel(mode, item, cb)
    GetOrCreateHydratationBuilder()._open(mode, item, cb)
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
                    item.cles           = pl.cles
                    item.conditions     = pl.conditions
                    item.filtres        = pl.filtres
                    item.etats          = pl.etats
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
                filtres        = pl.filtres or {},
                etats          = pl.etats or {},
                sources        = pl.sources or {},
                fonctionnement = pl.fonctionnement or {},
                cles           = pl.cles or {},
                conditions     = pl.conditions or {},
            }
            RebuildList()
        end)
    end)

    ctx.genericCatInfos[#ctx.genericCatInfos + 1] = {
        key = typeKey, editBtns = editBtns, modBtns = modBtns, linkBtns = linkBtns, rebuildFn = RebuildList,
    }

    RebuildList()
end

-- ── Diffusion réseau : valeurs des Clés "Saisie par MJ" ────────────────
-- Communication discrète via message d'addon, sur le même principe que
-- Character/Core.lua (SendAddonMessage, invisible dans le chat).
local COMM_PREFIX        = "OS2Hydra"
local commRegistered     = false
local liveValues         = {} -- [systemKey.."/"..cleKey] = valeur courante
local liveValueListeners = {}

local function LiveKey(systemKey, cleKey)
    return tostring(systemKey) .. "/" .. tostring(cleKey)
end

function OS2.DB.GetHydrationLiveValue(systemKey, cleKey, fallback)
    local v = liveValues[LiveKey(systemKey, cleKey)]
    if v == nil then return fallback end
    return v
end

function OS2.DB.OnHydrationLiveValueChanged(fn)
    liveValueListeners[#liveValueListeners + 1] = fn
end

local function NotifyLiveValueChanged(systemKey, cleKey, value)
    for _, fn in ipairs(liveValueListeners) do
        pcall(fn, systemKey, cleKey, value)
    end
end

local function ApplyIncomingLiveValue(systemKey, cleKey, value)
    liveValues[LiveKey(systemKey, cleKey)] = value
    NotifyLiveValueChanged(systemKey, cleKey, value)
end

function OS2.DB.BroadcastHydrationLiveValue(systemKey, cleKey, value)
    if not systemKey or not cleKey or value == nil then return end
    ApplyIncomingLiveValue(systemKey, cleKey, value)

    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    local payload = table.concat({ "V", systemKey, cleKey, tostring(value) }, ":")

    local channels = {}
    if IsInRaid and IsInRaid() then
        channels[#channels + 1] = "RAID"
    elseif IsInGroup and IsInGroup() then
        channels[#channels + 1] = "PARTY"
    end
    channels[#channels + 1] = "GUILD"

    for _, channel in ipairs(channels) do
        pcall(C_ChatInfo.SendAddonMessage, COMM_PREFIX, payload, channel)
    end
end

local function HandleCommMessage(payload)
    local kind, systemKey, cleKey, valueStr = strsplit(":", payload or "")
    if kind ~= "V" or not systemKey or systemKey == "" or not cleKey or cleKey == "" then return end
    local value = tonumber(valueStr)
    if value == nil then return end
    ApplyIncomingLiveValue(systemKey, cleKey, value)
end

local function EnsureCommRegistered()
    if commRegistered then return end
    commRegistered = true

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("CHAT_MSG_ADDON")
    frame:SetScript("OnEvent", function(_, _, prefix, message, _, sender)
        if prefix ~= COMM_PREFIX then return end
        HandleCommMessage(message)
    end)
end

-- ── Évaluation runtime : Capacité / Vitesse + déclenchement des Actions ─
local function FindConditionByKey(conditions, key)
    for _, c in ipairs(conditions or {}) do
        if c.key == key then return c end
    end
    return nil
end

local function EvaluateBaseOperand(base, ctx)
    if not base or not base.cleKey then return 0 end
    local def = 0
    for _, c in ipairs(ctx.cles or {}) do
        if c.key == base.cleKey then def = c.valeurDefaut or 0; break end
    end
    local v = OS2.DB.GetHydrationLiveValue(ctx.systemKey, base.cleKey, def) or def
    return v * (base.coef or 1)
end

-- Recalcule Capacité/Vitesse et déclenche au passage les Actions (aura/message)
-- des Conditions "Si" référencées par ce système.
function OS2.DB.EvaluateHydrationSystem(systemKey)
    local item = nil
    for _, it in ipairs(GetSystemList("hydratation")) do
        if it.key == systemKey then item = it; break end
    end
    if not item then return nil end

    local fonct      = item.fonctionnement or {}
    local cles       = item.cles or {}
    local conditions = item.conditions or {}
    local ctx = { systemKey = systemKey, cles = cles, capaciteTotale = 0 }

    local capacite = EvaluateBaseOperand(fonct.capacite and fonct.capacite.base, ctx)
    ctx.capaciteTotale = capacite
    for _, key in ipairs((fonct.capacite and fonct.capacite.conditionKeys) or {}) do
        local cond = FindConditionByKey(conditions, key)
        if cond then capacite = capacite + (EvaluateCondition(cond, ctx) or 0) end
    end

    ctx.capaciteTotale = capacite
    local vitesse = EvaluateBaseOperand(fonct.vitesse and fonct.vitesse.base, ctx)
    for _, key in ipairs((fonct.vitesse and fonct.vitesse.conditionKeys) or {}) do
        local cond = FindConditionByKey(conditions, key)
        if cond then vitesse = vitesse + (EvaluateCondition(cond, ctx) or 0) end
    end

    return { capacite = capacite, vitesse = vitesse }
end

-- ── Suivi visuel des États actifs : icône près de la minimap ───────────
local function FindEtatDef(systemKey, etatKey)
    for _, it in ipairs(GetSystemList("hydratation")) do
        if it.key == systemKey then
            for _, e in ipairs(it.etats or {}) do
                if e.key == etatKey then return e end
            end
            return nil
        end
    end
    return nil
end

local activeEtatsList  = {}
local activeEtatsIndex = {}
local etatIconFrames   = {}
local etatTrackerBar   = nil

local function RebuildActiveEtatsIndex()
    activeEtatsIndex = {}
    for i, e in ipairs(activeEtatsList) do activeEtatsIndex[e.key] = i end
end

local function GetOrCreateEtatTrackerBar()
    if etatTrackerBar then return etatTrackerBar end
    local bar = CreateFrame("Frame", "OS2_EtatTrackerBar", UIParent)
    bar:SetFrameStrata("HIGH")
    bar:SetSize(1, 26)
    bar:SetPoint("TOP", UIParent, "TOP", 0, -40)
    etatTrackerBar = bar
    return bar
end

local function RefreshEtatTrackerBar()
    local bar = GetOrCreateEtatTrackerBar()
    for _, f in ipairs(etatIconFrames) do f:Hide() end

    local totalW = 0
    for i, info in ipairs(activeEtatsList) do
        local f = etatIconFrames[i]
        if not f then
            f = CreateFrame("Button", nil, bar)
            f:SetSize(24, 24)
            local tex = f:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints(); tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            f.tex = tex
            local border = f:CreateTexture(nil, "BACKGROUND")
            border:SetPoint("TOPLEFT", f, "TOPLEFT", -1, 1); border:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 1, -1)
            border:SetColorTexture(0.05, 0.05, 0.05, 1)
            f:SetFrameLevel(bar:GetFrameLevel() + 1)
            f:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetText(self._label or "État", 1, 1, 1)
                if self._desc and self._desc ~= "" then
                    GameTooltip:AddLine(self._desc, 0.9, 0.9, 0.9, true)
                end
                GameTooltip:Show()
            end)
            f:SetScript("OnLeave", function() GameTooltip:Hide() end)
            etatIconFrames[i] = f
        end
        f.tex:SetTexture(info.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        f._label = info.label
        f._desc  = info.desc
        f:ClearAllPoints()
        f:SetPoint("RIGHT", bar, "RIGHT", -totalW, 0)
        f:Show()
        totalW = totalW + 28
    end
    bar:SetWidth(math.max(1, totalW))
end

-- Appelable par un futur mécanisme « boire » : applique/retire visuellement
-- et fonctionnellement un État sur le joueur (icône minimap + message
-- + Actions configurées sur cet État — aura/message).
function OS2.DB.ApplyEtatToPlayer(systemKey, etatKey)
    local etat = FindEtatDef(systemKey, etatKey)
    if not etat then return end
    local key = LiveKey(systemKey, etatKey)
    if activeEtatsIndex[key] then return end

    activeEtatsList[#activeEtatsList + 1] = { key = key, icon = etat.icon, label = etat.label, desc = etat.desc }
    RebuildActiveEtatsIndex()
    RefreshEtatTrackerBar()

    OS2.Notify("Vous ressentez : " .. (etat.label or "un état inconnu"), 1, 0.7, 0.3)
    ExecuteConditionActions(etat.actions, {})
end

function OS2.DB.RemoveEtatFromPlayer(systemKey, etatKey)
    local key = LiveKey(systemKey, etatKey)
    local idx = activeEtatsIndex[key]
    if not idx then return end
    local etat = activeEtatsList[idx]
    table.remove(activeEtatsList, idx)
    RebuildActiveEtatsIndex()
    RefreshEtatTrackerBar()

    OS2.Notify("Vous n'avez plus : " .. (etat and etat.label or "cet état"), 0.6, 0.9, 0.5)
end

function OS2.DB.IsEtatActiveOnPlayer(systemKey, etatKey)
    return activeEtatsIndex[LiveKey(systemKey, etatKey)] ~= nil
end

OS2.DB.OnHydrationLiveValueChanged(function(systemKey)
    OS2.DB.EvaluateHydrationSystem(systemKey)
end)

EnsureCommRegistered()
