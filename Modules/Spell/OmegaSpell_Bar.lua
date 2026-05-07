-- OmegaSpell - Barre Omega
-- Barres d'action addon pour lancer les macros Omega sans slot macro WoW.

OmegaSpell = OmegaSpell or {}
OmegaSpell.Bar = OmegaSpell.Bar or {}

local OS  = OmegaSpell
local Bar = OmegaSpell.Bar
local HUI = OS2.UI

local MAX_SLOTS = 1000
local SLOT_SIZE = 41
local GAP = 1
local PAD = 10
local HEADER_H = 24
local MIN_COLS = 1
local MAX_COLS = 40
local MIN_ROWS = 1
local MAX_ROWS = 40
local MIN_W = PAD * 2 + SLOT_SIZE
local MIN_H = HEADER_H + PAD * 2 + SLOT_SIZE
local MAX_W = PAD * 2 + MAX_COLS * SLOT_SIZE + (MAX_COLS - 1) * GAP
local MAX_H = HEADER_H + PAD * 2 + MAX_ROWS * SLOT_SIZE + (MAX_ROWS - 1) * GAP

local frames = {}
local pickedMacro    = nil
local cursorFrame    = nil
local cancelFrame    = nil      -- frame plein-écran pour annuler le placement par clic droit
local deletionEnabled = false   -- sécurité : clic droit inoffensif par défaut
local RefreshAllBars
local arcDragFrame   = nil      -- cache du frame de drag SpellCreator (local à leur addon)
-- Cache session : spellID → { name, icon }
-- Peuplé au drag pour les sorts Epsilon dont GetCursorInfo renvoie le slot du spellbook
-- et non le spellID réel. Évite de perdre nom/icône entre le drop et l'affichage.
local spellInfoCache = {}

-- Trouve et cache le frame de drag de SpellCreator (DIALOG strata, commID + Icon child).
-- SpellCreator le crée comme variable locale, donc on le repère parmi les enfants de UIParent.
local function GetSCDragFrame()
    if arcDragFrame then return arcDragFrame end
    for i = 1, UIParent:GetNumChildren() do
        local child = select(i, UIParent:GetChildren())
        if child and child.commID ~= nil
           and child:GetFrameStrata() == "DIALOG"
           and child.Icon ~= nil then
            arcDragFrame = child
            return arcDragFrame
        end
    end
    return nil
end

-- Tente d'exécuter une macro WoW par nom ou index via RunMacro (natif).
-- Retourne true si l'appel a réussi, false si la fonction est protégée.
local function TryRunWoWMacro(nameOrIndex)
    if not RunMacro then return false end
    local ok = pcall(RunMacro, nameOrIndex)
    return ok
end

-- Exécute le texte d'une macro RP via le simulateur Omega.
-- Remplace RunMacro() qui est une fonction protégée par Blizzard.
local function RunRPMacroBody(body)
    if not body or body == "" then return end
    if OS.ExecuteMacroBody then
        local ok, err = OS.ExecuteMacroBody(body)
        if not ok then
            print("|cff66ccffOmegaSpell|r: Macro WoW non lancee. " .. tostring(err or "Contenu non simulable."))
        end
    end
end

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.max(minValue, math.min(maxValue, value))
end

local function GetVisibleSlotCount(cfg)
    return math.min(MAX_SLOTS, math.max(1, (cfg.cols or 12) * (cfg.rows or 1)))
end

local function GetRowCount(cfg)
    return math.max(1, cfg.rows or 1)
end

local function SavePosition(frame)
    local cfg = frame.cfg
    if not cfg then return end

    local point, _, relPoint, x, y = frame:GetPoint()
    cfg.point = point or "CENTER"
    cfg.relPoint = relPoint or "CENTER"
    cfg.x = x or 0
    cfg.y = y or 0
end

local function RestorePosition(frame)
    local cfg = frame.cfg
    frame:ClearAllPoints()
    if cfg and cfg.point then
        frame:SetPoint(cfg.point, UIParent, cfg.relPoint or cfg.point, cfg.x or 0, cfg.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, -220)
    end
end

local function ApplyFrameSize(frame)
    local cfg = frame.cfg
    cfg.cols = Clamp(cfg.cols or 12, MIN_COLS, MAX_COLS)
    cfg.rows = Clamp(cfg.rows or 1, MIN_ROWS, MAX_ROWS)
    local rows = GetRowCount(cfg)
    local w = cfg.w or (PAD * 2 + (cfg.cols * SLOT_SIZE) + ((cfg.cols - 1) * GAP))
    local h = cfg.h or (HEADER_H + PAD * 2 + (rows * SLOT_SIZE) + ((rows - 1) * GAP))
    frame:SetSize(w, h)
end

local function ApplyResizeLimits(frame)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
        return
    end
    if frame.SetMinResize then
        frame:SetMinResize(MIN_W, MIN_H)
    end
    if frame.SetMaxResize then
        frame:SetMaxResize(MAX_W, MAX_H)
    end
end

-- ── Helper sort WoW natif ────────────────────────────────────────────────────
-- Sur Epsilon, GetCursorInfo() renvoie le slot du spellbook (ex : 8) et non le
-- spellID réel (ex : 283362). AcceptCursorContent résout slot→spellID via
-- GetSpellBookItemInfo et stocke le vrai ID. Ce helper est ensuite appelé avec
-- le vrai spellID et retrouve nom + icône normalement via C_Spell.GetSpellInfo.
local function GetWoWSpellData(nameOrID)
    local numID = tonumber(nameOrID)
    -- 0. Cache session (peuplé par AcceptCursorContent quand le spellbook renvoie des données)
    if numID and spellInfoCache[numID] then
        local c = spellInfoCache[numID]
        return c.name, c.icon, numID
    end
    -- 1. API moderne TWW (C_Spell.GetSpellInfo)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(nameOrID)
        if info and info.name then
            return info.name, info.iconID, info.spellID
        end
    end
    -- 2. Ancienne API GetSpellInfo (clients custom / pré-11.x)
    if GetSpellInfo then
        local name, _, icon, _, _, _, spellID = GetSpellInfo(nameOrID)
        if name then return name, icon, spellID end
    end
    -- 3. Nom seul via C_Spell.GetSpellName
    local name = nil
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(nameOrID)
    end
    -- 4. Icône seule via GetSpellTexture
    local icon = nil
    if GetSpellTexture then icon = GetSpellTexture(nameOrID) end
    if not icon and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(nameOrID)
    end
    if name or icon then return name, icon, numID end
    return nil, nil, nil
end

-- ── Helpers de type de slot ───────────────────────────────────────────────────
-- Format : table { type="wow", name, index, icon, body } → macro WoW native compactée
--          "wow:NomDeLaMacro"  → ancien format
--          "omsp_xxx_xxx"      → macro OmegaSpell (existant)

local function ParseSlot(value)
    if not value or value == "" then return nil, nil end
    if type(value) == "table" then
        if value.type == "wow" then
            return "wow", value.name or value.index, value
        end
        return value.type or "omega", value.id or value.macroID, value
    end
    if value:sub(1, 4) == "wow:" then
        return "wow", value:sub(5)
    end
    if value:sub(1, 6) == "spell:" then
        return "spell", value:sub(7)
    end
    if value:sub(1, 4) == "arc:" then
        return "arc", value:sub(5)
    end
    return "omega", value
end

local function CompactMacroBody(body)
    local lines = {}
    body = tostring(body or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
    for line in body:gmatch("[^\n]+") do
        line = line:match("^%s*(.-)%s*$") or ""
        if line ~= "" and line:sub(1, 1) ~= "#" then
            line = line:gsub("%s+", " ")
            lines[#lines + 1] = line
        end
    end
    return table.concat(lines, "\n")
end

-- ── Drag WoW natif ───────────────────────────────────────────────────────────
-- Accepte le contenu du curseur WoW (sort ou macro) et le pose dans slotIndex.
-- Retourne true si quelque chose a été déposé, false sinon.
local function AcceptCursorContent(frame, slotIndex)
    local cursorType, id = GetCursorInfo()
    if cursorType == "spell" then
        local rawID = tonumber(id)
        if not rawID then return false end
        -- Le vrai spellID a été résolu dans OnUpdate pendant le drag (avant GLOBAL_MOUSE_UP)
        -- pour éviter d'appeler des APIs spellbook dans un contexte protégé par Blizzard.
        local cached  = spellInfoCache[rawID]
        local spellID = (cached and cached.resolvedID) or rawID
        OS.SetBarSlot(slotIndex, "spell:" .. spellID, frame.barIndex)
        ClearCursor()
        Bar.Refresh(frame.barIndex)
        return true
    elseif cursorType == "macro" then
        local macroIndex = tonumber(id)
        if not macroIndex or macroIndex <= 0 then return false end
        if not GetMacroInfo then return false end
        local name = GetMacroInfo(macroIndex)   -- nom uniquement, pas de copie du body
        if not name or name == "" then return false end
        -- Stockage par référence : la macro reste vivante dans l'éditeur WoW.
        -- ClearCursor() vide le curseur sans toucher à la liste de macros WoW.
        OS.SetBarSlot(slotIndex, "wow:" .. name, frame.barIndex)
        ClearCursor()
        Bar.Refresh(frame.barIndex)
        return true
    end
    return false
end

-- Retourne { type, slotID, displayName, icon } ou nil si slot vide/invalide
local function GetSlotData(barIndex, slotIndex)
    local raw = OS.GetBarSlot and OS.GetBarSlot(slotIndex, barIndex)
    if not raw then return nil end

    local slotType, id, payload = ParseSlot(raw)

    if slotType == "wow" then
        local name = payload and payload.name
        local iconTexture = payload and payload.icon
        if not name and type(id) == "string" and GetMacroIndexByName and GetMacroInfo then
            local macroIndex = GetMacroIndexByName(id)
            if macroIndex and macroIndex > 0 then
                name, iconTexture = GetMacroInfo(macroIndex)
            end
        end
        if not name then return nil end   -- macro supprimée côté WoW / ancien slot invalide
        -- Icône virtuelle : override stocké dans la DB Omega (la macro WoW native n'est pas touchée)
        local overrides = OmegaSpellDB and OmegaSpellDB.macroIconOverrides
        local icon = (overrides and overrides[name]) or iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
        return { type = "wow", slotID = raw, displayName = name, icon = icon }
    end

    if slotType == "spell" then
        local numID  = tonumber(id)
        local name, icon, spellID = GetWoWSpellData(id)
        -- Fallback : sort Epsilon custom absent de la DB WoW standard
        name    = name or ("Sort " .. tostring(id))
        icon    = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
        spellID = spellID or numID
        local desc = ""
        if spellID then
            if C_Spell and C_Spell.GetSpellDescription then
                desc = C_Spell.GetSpellDescription(spellID) or ""
            elseif GetSpellDescription then
                desc = GetSpellDescription(spellID) or ""
            end
        end
        return {
            type        = "spell",
            slotID      = raw,
            displayName = name,
            icon        = icon,
            spellID     = spellID,
            description = desc,
        }
    end

    if slotType == "arc" then
        -- Sort SpellCreator (Arcanum). Exécution via ARC:CAST(commID).
        if not (ARC and ARC.XAPI and ARC.XAPI.GetArcSpell) then return nil end
        local arcSpell = ARC.XAPI:GetArcSpell(id)
        if not arcSpell then return nil end
        -- L'icône SC peut être un index custom (<10000) ou un ID WoW (>=10000) ou un chemin
        local icon = "Interface\\Icons\\INV_Misc_QuestionMark"
        if arcSpell.icon then
            local n = tonumber(arcSpell.icon)
            if n and n >= 10000 then
                icon = n        -- ID texture WoW valide
            elseif type(arcSpell.icon) == "string" and arcSpell.icon ~= "" then
                icon = arcSpell.icon
            end
        end
        return {
            type        = "arc",
            slotID      = raw,
            displayName = arcSpell.fullName or id,
            icon        = icon,
            description = arcSpell.description or "",
            commID      = id,
        }
    end

    -- omega
    local spell, realName = OS.GetSpellByMacroID(raw)
    if not spell then return nil end
    return {
        type        = "omega",
        slotID      = raw,
        displayName = (spell.macroName and spell.macroName ~= "" and spell.macroName)
            or (OS.GetSpellMacroName and OS.GetSpellMacroName(realName))
            or realName,
        icon        = spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
        spellName   = realName,
        description = spell.description or "",
    }
end

local function EnsureCursorFrame()
    if cursorFrame then return cursorFrame end

    cursorFrame = CreateFrame("Frame", nil, UIParent)
    cursorFrame:SetSize(32, 32)
    cursorFrame:SetFrameStrata("TOOLTIP")
    cursorFrame:EnableMouse(false)
    cursorFrame:Hide()

    local icon = cursorFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    cursorFrame.icon = icon

    local border = cursorFrame:CreateTexture(nil, "OVERLAY")
    border:SetPoint("TOPLEFT", cursorFrame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", cursorFrame, "BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(0.78, 0.70, 0.42, 0.25)

    cursorFrame:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x / scale) + 12, (y / scale) - 12)
    end)

    return cursorFrame
end

local ClearPickedMacro

local function EnsureCancelFrame()
    if cancelFrame then return cancelFrame end
    -- Frame plein-écran à strata BACKGROUND : capte le clic droit en dehors de tout slot
    -- Les slots sont à MEDIUM → ils restent prioritaires, ce frame ne les bloque pas
    cancelFrame = CreateFrame("Button", nil, UIParent)
    cancelFrame:SetAllPoints(UIParent)
    cancelFrame:SetFrameStrata("BACKGROUND")
    cancelFrame:EnableMouse(true)
    cancelFrame:RegisterForClicks("RightButtonUp")
    cancelFrame:Hide()
    cancelFrame:SetScript("OnClick", function(_, btn)
        if btn == "RightButton" and pickedMacro then
            ClearPickedMacro()
        end
    end)
    return cancelFrame
end

ClearPickedMacro = function()
    pickedMacro = nil
    if cursorFrame then cursorFrame:Hide() end
    if cancelFrame then cancelFrame:Hide() end
    if RefreshAllBars then RefreshAllBars() end
end

RefreshAllBars = function()
    if Bar.Refresh then Bar.Refresh() end
end

local function IsMacroLibraryShown()
    return OS.MacroLibrary
        and OS.MacroLibrary.IsShown
        and OS.MacroLibrary.IsShown()
end

local function ShouldShowEmptySlots(frame)
    return pickedMacro ~= nil
        or (frame and frame.isOmegaResizing)
        or (frame and frame.cfg and not frame.cfg.locked)
        or IsMacroLibraryShown()
        or (frame and frame.hasNativeDrag)   -- sort/macro WoW ou SC en cours de drag
end

local function SetPickedMacro(macroID, sourceBar, sourceSlot)
    local slotType, id, payload = ParseSlot(macroID)
    local iconTex = "Interface\\Icons\\INV_Misc_QuestionMark"

    if slotType == "wow" then
        local name = payload and payload.name
        local tex = payload and payload.icon
        if not name and type(id) == "string" and GetMacroIndexByName and GetMacroInfo then
            local macroIndex = GetMacroIndexByName(id)
            if macroIndex and macroIndex > 0 then
                name, tex = GetMacroInfo(macroIndex)
            end
        end
        if not name then
            ClearPickedMacro()
            return false, "Macro WoW introuvable."
        end
        iconTex = tex or iconTex
    elseif slotType == "spell" then
        local name, icon = GetWoWSpellData(id)
        -- Pas de guard strict : les sorts Epsilon custom peuvent ne pas avoir de nom
        -- dans la DB WoW standard (GetSpellInfo/C_Spell retournent nil).
        -- On autorise quand même le déplacement avec l'icône de fallback.
        iconTex = icon or iconTex
    elseif slotType == "arc" then
        -- Sort SpellCreator : récupère l'icône via l'API publique d'Arcanum.
        if ARC and ARC.XAPI and ARC.XAPI.GetArcSpell then
            local arcSpell = ARC.XAPI:GetArcSpell(id)
            if arcSpell and arcSpell.icon then
                local n = tonumber(arcSpell.icon)
                if n and n >= 10000 then
                    iconTex = n
                elseif type(arcSpell.icon) == "string" and arcSpell.icon ~= "" then
                    iconTex = arcSpell.icon
                end
            end
        end
        -- Pas de guard : si ARC est indisponible on utilise l'icône par défaut
        -- mais on laisse quand même la macro être "tenue" (commID reste valide).
    else
        local spell = OS.GetSpellByMacroID and OS.GetSpellByMacroID(macroID)
        if not spell then
            ClearPickedMacro()
            return false, "Macro Omega introuvable."
        end
        iconTex = spell.icon or iconTex
    end

    pickedMacro = { macroID = macroID, sourceBar = sourceBar, sourceSlot = sourceSlot }

    local cursor = EnsureCursorFrame()
    cursor.icon:SetTexture(iconTex)
    cursor:Show()
    EnsureCancelFrame():Show()  -- clic droit n'importe où annule le placement
    RefreshAllBars()
    return true
end

local function PlacePickedMacro(targetBar, targetSlot)
    if not pickedMacro then return false end

    local movingID = pickedMacro.macroID
    local sourceBar = pickedMacro.sourceBar
    local sourceSlot = pickedMacro.sourceSlot
    local targetID = OS.GetBarSlot and OS.GetBarSlot(targetSlot, targetBar)

    if sourceBar and sourceSlot then
        OS.SetBarSlot(sourceSlot, targetID, sourceBar)
    end
    OS.SetBarSlot(targetSlot, movingID, targetBar)

    if not sourceBar and targetID and targetID ~= "" and targetID ~= movingID then
        SetPickedMacro(targetID)
    else
        ClearPickedMacro()
    end
    RefreshAllBars()
    return true
end

local function SlotTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    if pickedMacro then
        GameTooltip:AddLine("Déposer ici", 1, 0.86, 0.45)
        GameTooltip:AddLine("Clic gauche : poser la macro tenue", 0.55, 0.55, 0.55)
        GameTooltip:Show()
        return
    end

    if btn.slotID then
        GameTooltip:AddLine(btn.displayName or btn.slotID, 1, 0.86, 0.45)
        if btn.slotType == "wow" then
            GameTooltip:AddLine("Macro WoW native", 0.60, 0.80, 1.0)
        elseif btn.slotType == "spell" then
            GameTooltip:AddLine("Sort WoW natif", 0.35, 0.85, 0.40)
        elseif btn.slotType == "arc" then
            GameTooltip:AddLine("Sort Arcanum (SpellCreator)", 0.80, 0.35, 1.0)
        else
            GameTooltip:AddLine("Macro Omega", 0.80, 0.70, 0.40)
        end
        -- Description du sort / sort natif / arcanum
        if btn.description and btn.description ~= "" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(btn.description, 1, 1, 1, true)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Clic gauche : lancer", 0.55, 0.55, 0.55)
        GameTooltip:AddLine("Shift + clic gauche : deplacer", 0.55, 0.55, 0.55)
        if deletionEnabled then
            GameTooltip:AddLine("Clic droit : vider le slot", 0.55, 0.55, 0.55)
        else
            GameTooltip:AddLine("Clic droit : suppression désactivée", 0.65, 0.30, 0.30)
        end
    else
        GameTooltip:AddLine("Slot vide", 1, 0.86, 0.45)
        GameTooltip:AddLine("Placez une macro Omega, WoW ou un sort natif.", 0.55, 0.55, 0.55)
    end
    GameTooltip:Show()
end

local function CreateSlot(frame, slotIndex)
    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(SLOT_SIZE, SLOT_SIZE)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    btn:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropBorderColor(unpack(HUI.colors.separator))

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    btn.icon = icon

    local shade = btn:CreateTexture(nil, "OVERLAY")
    shade:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT")
    shade:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    shade:SetHeight(13)
    shade:SetColorTexture(0, 0, 0, 0.75)
    btn.shade = shade


    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 2, 1)
    label:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 1)
    label:SetJustifyH("CENTER")
    label:SetWordWrap(false)
    label:SetText(tostring(slotIndex))
    HUI.ApplyBodyText(label)
    btn.label = label

    btn:SetScript("OnReceiveDrag", function(self)
        AcceptCursorContent(frame, slotIndex)
    end)


    btn:SetScript("OnClick", function(self, button)
        -- Priorité 1 : contenu WoW sur le curseur (sort ou macro glissée depuis le spellbook)
        if button == "LeftButton" and AcceptCursorContent(frame, slotIndex) then return end

        if button == "LeftButton" and pickedMacro then
            PlacePickedMacro(frame.barIndex, slotIndex)
            return
        end

        if button == "LeftButton" and IsShiftKeyDown and IsShiftKeyDown() and self.slotID then
            local ok = SetPickedMacro(self.slotID, frame.barIndex, slotIndex)
            if ok then
                if OS.ClearBarSlot then OS.ClearBarSlot(slotIndex, frame.barIndex) end
                Bar.Refresh(frame.barIndex)
            end
            return
        end

        if button == "RightButton" then
            if pickedMacro then
                ClearPickedMacro()
                return
            end
            -- Sécurité : suppression bloquée si le verrou est actif
            if self.slotID and not deletionEnabled then return end
            if OS.ClearBarSlot then OS.ClearBarSlot(slotIndex, frame.barIndex) end
            Bar.Refresh(frame.barIndex)
            return
        end

        -- Exécution selon le type
        if self.slotType == "arc" then
            local _, commID = ParseSlot(self.slotID)
            if commID and ARC and ARC.CAST then
                ARC:CAST(commID)
            else
                print("|cff66ccffOmegaSpell|r: SpellCreator indisponible ou commID invalide.")
            end
            return
        end

        if self.slotType == "spell" then
            -- Les sorts WoW natifs ne peuvent pas être lancés directement depuis la barre :
            -- le type Epsilon du sort (cast / aura / autre) est indéterminable depuis l'addon.
            -- Le slot sert à afficher et organiser — le lancer depuis le spellbook ou une barre d'action.
            print("|cff66ccffOmegaSpell|r: Sort WoW natif — lancement non supporté depuis la barre. "
                .. "Utilisez le spellbook ou une barre d'action Epsilon.")
            return
        end

        if self.slotType == "wow" then
            local _, wowName, payload = ParseSlot(self.slotID)
            local macroName = (payload and payload.name) or (type(wowName) == "string" and wowName)

            -- RunMacro est une fonction protégée par Blizzard → taint.
            -- On lit le body via GetMacroInfo (non protégé) et on l'exécute
            -- via le simulateur Omega qui ne passe pas par les APIs WoW protégées.
            local body = nil
            if macroName and GetMacroIndexByName and GetMacroInfo then
                local macroIndex = GetMacroIndexByName(macroName)
                if macroIndex and macroIndex > 0 then
                    local _, _, rawBody = GetMacroInfo(macroIndex)
                    body = CompactMacroBody(rawBody or "")
                end
            end
            if body and body ~= "" then
                RunRPMacroBody(body)
            else
                print("|cff66ccffOmegaSpell|r: Macro WoW introuvable ou vide : " .. tostring(macroName))
            end
        elseif self.slotType == "omega" and self.slotID then
            if OS.RunStoredMacroByID then
                OS.RunStoredMacroByID(self.slotID)
            elseif OS.CastSpellByMacroID then
                OS.CastSpellByMacroID(self.slotID)
            end
        end
    end)
    btn:SetScript("OnEnter", SlotTooltip)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.slots[slotIndex] = btn
    return btn
end

local function RefreshSlot(frame, slotIndex)
    local btn = frame.slots[slotIndex] or CreateSlot(frame, slotIndex)
    local cfg = frame.cfg
    local visibleCount = GetVisibleSlotCount(cfg)

    if slotIndex > visibleCount then
        btn:Hide()
        return
    end

    local col = (slotIndex - 1) % cfg.cols
    local row = math.floor((slotIndex - 1) / cfg.cols)
    btn:ClearAllPoints()
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (SLOT_SIZE + GAP), -(HEADER_H + PAD + row * (SLOT_SIZE + GAP)))
    btn:Show()

    local data = GetSlotData(frame.barIndex, slotIndex)
    if not data then
        btn.slotID      = nil
        btn.slotType    = nil
        btn.displayName = nil
        btn.description = nil
        btn.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        btn.icon:SetDesaturated(true)
        btn.label:SetText(tostring(slotIndex))
        btn:SetBackdropBorderColor(unpack(HUI.colors.separator))
        if ShouldShowEmptySlots(frame) then
            btn:SetAlpha(1)
            btn:EnableMouse(true)
            if btn.icon then btn.icon:Show() end
            if btn.shade then btn.shade:Show() end
            if btn.label then btn.label:Show() end
        else
            btn:SetAlpha(0)
            btn:EnableMouse(false)
        end
        return
    end

    btn:SetAlpha(1)
    btn:EnableMouse(true)
    if btn.icon then btn.icon:Show() end
    if btn.shade then btn.shade:Show() end
    if btn.label then btn.label:Show() end

    btn.slotID      = data.slotID
    btn.slotType    = data.type
    btn.displayName = data.displayName
    btn.icon:SetTexture(data.icon)
    btn.icon:SetDesaturated(false)
    btn.label:SetText(data.displayName or "")

    -- Teinte de bordure selon le type
    if data.type == "wow" then
        btn:SetBackdropBorderColor(0.40, 0.60, 1.0, 0.80)
    elseif data.type == "spell" then
        btn:SetBackdropBorderColor(0.35, 0.85, 0.40, 0.80)
    elseif data.type == "arc" then
        btn:SetBackdropBorderColor(0.80, 0.35, 1.0, 0.80)
    else
        btn:SetBackdropBorderColor(unpack(HUI.colors.separator))
    end


    btn.description = data.description or ""

end

local function ApplyGridFromSize(frame)
    local cfg = frame.cfg
    local width = Clamp(frame:GetWidth(), MIN_W, MAX_W)
    local height = Clamp(frame:GetHeight(), MIN_H, MAX_H)
    local oldCols = cfg.cols
    local oldRows = cfg.rows
    local oldW = cfg.w
    local oldH = cfg.h

    cfg.w = width
    cfg.h = height
    cfg.cols = Clamp(math.floor((width - PAD * 2 + GAP) / (SLOT_SIZE + GAP)), MIN_COLS, MAX_COLS)
    cfg.rows = Clamp(math.floor((height - HEADER_H - PAD * 2 + GAP) / (SLOT_SIZE + GAP)), MIN_ROWS, MAX_ROWS)

    if oldCols == cfg.cols and oldRows == cfg.rows and oldW == width and oldH == height then
        return
    end

    ApplyFrameSize(frame)
    SavePosition(frame)
    for i = 1, MAX_SLOTS do
        RefreshSlot(frame, i)
    end
end

local function CreateResizeHandle(frame)
    local handle
    if OS.SliderUI and OS.SliderUI.CreateResizeGrip then
        handle = OS.SliderUI.CreateResizeGrip(frame, 18)
    else
        handle = CreateFrame("Button", nil, frame)
        handle:SetSize(18, 18)
    end
    handle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    handle:SetFrameLevel(frame:GetFrameLevel() + 5)

    handle:SetScript("OnMouseDown", function()
        frame.isOmegaResizing = true
        for i = 1, MAX_SLOTS do RefreshSlot(frame, i) end
        frame:StartSizing("BOTTOMRIGHT")
    end)
    handle:SetScript("OnMouseUp", function()
        frame.isOmegaResizing = false
        frame:StopMovingOrSizing()
        -- Snap à la grille une fois le drag terminé
        local cfg = frame.cfg
        local w = PAD * 2 + (cfg.cols * SLOT_SIZE) + ((cfg.cols - 1) * GAP)
        local h = HEADER_H + PAD * 2 + (cfg.rows * SLOT_SIZE) + ((cfg.rows - 1) * GAP)
        cfg.w = w
        cfg.h = h
        frame:SetSize(w, h)
        SavePosition(frame)
        for i = 1, MAX_SLOTS do RefreshSlot(frame, i) end
    end)
    frame.resizeHandle = handle
end

local function CreateHeaderButton(parent, size, text)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(size, size)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    btn:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    btn:SetBackdropBorderColor(unpack(HUI.colors.separator))

    local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetAllPoints()
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetText(text)
    HUI.ApplyStrongLabel(fs)
    btn.text = fs

    return btn
end

local function CreateBarFrame(barIndex, cfg)
    local frame = CreateFrame("Frame", "OmegaSpellBarFrame" .. barIndex, UIParent, "BackdropTemplate")
    frame.barIndex = barIndex
    frame.cfg = cfg
    frame.slots = {}
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(90 + barIndex)
    frame:SetMovable(true)
    frame:SetResizable(true)
    ApplyResizeLimits(frame)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    HUI.ApplyWindowBackground(bg, 0.88)
    frame.bg = bg

    frame:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropBorderColor(unpack(HUI.colors.separator))

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -4)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -28, -4)
    title:SetHeight(18)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(cfg.name or ("Barre Omega " .. barIndex))
    HUI.ApplyStrongLabel(title)
    frame.title = title

    local closeBtn = CreateHeaderButton(frame, 18, "x")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -4)
    closeBtn:SetScript("OnClick", function() Bar.Hide(barIndex) end)
    frame.closeBtn = closeBtn

    CreateResizeHandle(frame)

    -- Cache/montre le chrome (fond, bordure, titre, close, grip)
    frame.SetChromeVisible = function(visible)
        cfg.locked = not visible
        if visible then
            frame.bg:Show()
            frame:SetBackdropBorderColor(unpack(HUI.colors.separator))
            frame.title:Show()
            frame.closeBtn:Show()
            if frame.resizeHandle then frame.resizeHandle:Show() end
        else
            frame.bg:Hide()
            frame:SetBackdropBorderColor(0, 0, 0, 0)
            frame.title:Hide()
            frame.closeBtn:Hide()
            if frame.resizeHandle then frame.resizeHandle:Hide() end
        end
        for i = 1, MAX_SLOTS do
            RefreshSlot(frame, i)
        end
    end

    -- GLOBAL_MOUSE_UP : point d'entrée unique pour tous les drags natifs.
    -- WoW et SC gardent tous deux la capture souris sur leur bouton source,
    -- donc ni OnReceiveDrag ni OnClick ne sont garantis sur nos slots.
    frame:SetScript("OnEvent", function(self, event, button)
        if event ~= "GLOBAL_MOUSE_UP" or button ~= "LeftButton" then return end
        if not self.hasNativeDrag then return end

        local visCount = GetVisibleSlotCount(self.cfg)

        -- Cas 1 : drag SpellCreator (frame custom DIALOG)
        -- IMPORTANT : SC appelle dragIcon:Hide() dans dropSpell() via OnDragStop,
        -- qui s'exécute dans le même frame AVANT GLOBAL_MOUSE_UP.
        -- Donc sc:IsShown() est déjà false ici — on utilise self.hasSCDrag
        -- (valeur stockée au frame précédent par OnUpdate, encore true pendant le drag).
        local sc = GetSCDragFrame()
        if self.hasSCDrag and sc and sc.commID and sc.commID ~= "" then
            self.hasSCDrag = false  -- consommé, évite toute double-détection
            for i = 1, visCount do
                local slotBtn = self.slots[i]
                if slotBtn and slotBtn:IsShown() and MouseIsOver(slotBtn) then
                    OS.SetBarSlot(i, "arc:" .. sc.commID, self.barIndex)
                    Bar.Refresh(self.barIndex)
                    return
                end
            end
            return
        end

        -- Cas 2 : curseur WoW natif (sort ou macro du menu ESC)
        local cursorType, id = GetCursorInfo()
        if cursorType == "spell" or cursorType == "macro" then
            for i = 1, visCount do
                local slotBtn = self.slots[i]
                if slotBtn and slotBtn:IsShown() and MouseIsOver(slotBtn) then
                    AcceptCursorContent(self, i)
                    return
                end
            end
        end
    end)

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition(self)
    end)
    frame:SetScript("OnUpdate", function(self)
        -- Détection unifiée de tous les drags natifs :
        --   · curseur WoW (sort spellbook, macro menu ESC)
        --   · drag SpellCreator (frame DIALOG custom)
        -- Dans tous les cas, le bouton source garde la capture → GLOBAL_MOUSE_UP.
        local cursorType, cursorID = GetCursorInfo()
        local hasWoWCursor = (cursorType == "spell" or cursorType == "macro")

        -- Résolution slot→spellID pour les sorts du spellbook Epsilon.
        -- Sur Epsilon, GetCursorInfo renvoie l'index du slot (ex : 8) et non le spellID
        -- réel (ex : 283362). On appelle GetSpellBookItemInfo ici, pendant le drag,
        -- dans un contexte Lua normal — et NON dans GLOBAL_MOUSE_UP qui s'exécute
        -- au moment où Blizzard finalise une action protégée (risque de taint).
        if cursorType == "spell" then
            local rawID = tonumber(cursorID)
            if rawID and not (spellInfoCache[rawID] and spellInfoCache[rawID].resolved) then
                local spellID = rawID
                local name, icon

                -- Résolution via C_SpellBook (TWW)
                if C_SpellBook then
                    if C_SpellBook.GetSpellBookItemInfo then
                        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, rawID)
                        if ok and info and info.actionID and info.actionID ~= 0 then
                            spellID = info.actionID
                        end
                    end
                    if C_SpellBook.GetSpellBookItemName then
                        local ok, n = pcall(C_SpellBook.GetSpellBookItemName, rawID)
                        if ok and n then name = n end
                    end
                    if C_SpellBook.GetSpellBookItemTexture then
                        local ok, ic = pcall(C_SpellBook.GetSpellBookItemTexture, rawID)
                        if ok and ic then icon = ic end
                    end
                end
                -- Fallback ancienne API
                if spellID == rawID and GetSpellBookItemInfo then
                    local ok, itype, sid = pcall(GetSpellBookItemInfo, rawID, "SPELL")
                    if ok and itype == "SPELL" and sid and sid ~= 0 then spellID = sid end
                end
                if not name and GetSpellBookItemName then
                    local ok, n = pcall(GetSpellBookItemName, rawID, "SPELL")
                    if ok and n then name = n end
                end
                if not icon and GetSpellBookItemTexture then
                    local ok, ic = pcall(GetSpellBookItemTexture, rawID, "SPELL")
                    if ok and ic then icon = ic end
                end

                -- Si on n'a pas encore de nom/icône, essayer directement avec spellID résolu
                if not name or not icon then
                    local n2, ic2 = GetWoWSpellData(spellID)
                    name = name or n2
                    icon = icon or ic2
                end

                spellInfoCache[rawID] = {
                    resolved   = true,
                    resolvedID = spellID,
                    name       = name,
                    icon       = icon,
                }
                -- Indexer aussi par spellID réel pour que GetWoWSpellData le trouve
                if spellID ~= rawID then
                    spellInfoCache[spellID] = spellInfoCache[spellID] or { name = name, icon = icon }
                end
            end
        end

        local sc = GetSCDragFrame()
        local hasSCDrag = sc ~= nil and sc:IsShown()
        -- hasSCDrag est stocké séparément : utilisé dans OnEvent où sc:IsShown()
        -- est déjà false (SC cache dragIcon avant GLOBAL_MOUSE_UP dans le même frame).
        self.hasSCDrag = hasSCDrag

        local hasNative = hasWoWCursor or hasSCDrag
        if hasNative ~= self.hasNativeDrag then
            self.hasNativeDrag = hasNative
            if hasNative then
                self:RegisterEvent("GLOBAL_MOUSE_UP")
            else
                self:UnregisterEvent("GLOBAL_MOUSE_UP")
            end
            for i = 1, MAX_SLOTS do RefreshSlot(self, i) end
        end

        if not self.isOmegaResizing then return end
        -- Pendant le drag : recalcule la grille sans toucher à SetSize
        local w = math.max(MIN_W, self:GetWidth())
        local h = math.max(MIN_H, self:GetHeight())
        local cfg = self.cfg
        local newCols = Clamp(math.floor((w - PAD * 2 + GAP) / (SLOT_SIZE + GAP)), MIN_COLS, MAX_COLS)
        local newRows = Clamp(math.floor((h - HEADER_H - PAD * 2 + GAP) / (SLOT_SIZE + GAP)), MIN_ROWS, MAX_ROWS)
        if newCols ~= cfg.cols or newRows ~= cfg.rows then
            cfg.cols = newCols
            cfg.rows = newRows
            for i = 1, MAX_SLOTS do RefreshSlot(self, i) end
        end
    end)

    ApplyFrameSize(frame)
    RestorePosition(frame)
    frames[barIndex] = frame
    return frame
end

local function GetFrame(barIndex)
    local cfg = OS.GetBar and OS.GetBar(barIndex)
    if not cfg then return nil end
    return frames[barIndex] or CreateBarFrame(barIndex, cfg)
end

function Bar.Refresh(barIndex)
    if barIndex then
        local frame = GetFrame(barIndex)
        if not frame then return end
        frame.cfg = OS.GetBar(barIndex)
        if frame.title then
            frame.title:SetText(frame.cfg.name or ("Barre Omega " .. barIndex))
        end
        ApplyFrameSize(frame)
        if frame.SetChromeVisible then
            frame.SetChromeVisible(not frame.cfg.locked)
        end
        for i = 1, MAX_SLOTS do
            RefreshSlot(frame, i)
        end
        return
    end

    local bars = OS.GetBars and OS.GetBars() or {}
    for i = 1, #bars do
        Bar.Refresh(i)
    end
end

function Bar.Open(barIndex)
    barIndex = barIndex or 1
    local frame = GetFrame(barIndex)
    if not frame then return end
    frame.cfg.shown = true
    RestorePosition(frame)
    Bar.Refresh(barIndex)
    frame:Show()
end

function Bar.Hide(barIndex)
    barIndex = barIndex or 1
    local frame = GetFrame(barIndex)
    if not frame then return end
    frame.cfg.shown = false
    frame:Hide()
    Bar.RefreshManager()
end

function Bar.Toggle(barIndex)
    -- Si un index précis est donné, toggle cette barre uniquement
    if barIndex then
        local frame = GetFrame(barIndex)
        if frame and frame:IsShown() then
            Bar.Hide(barIndex)
        else
            Bar.Open(barIndex)
        end
        return
    end

    -- Sans argument : toggle toutes les barres existantes
    local bars = OS.GetBars and OS.GetBars() or {}
    local anyShown = false
    for i = 1, #bars do
        local frame = frames[i]
        if frame and frame:IsShown() then
            anyShown = true
            break
        end
    end

    if anyShown then
        -- Toutes visibles → cacher toutes
        for i = 1, #bars do
            Bar.Hide(i)
        end
    else
        -- Aucune visible → ouvrir toutes (ou créer la première si aucune)
        if #bars == 0 then
            local ok, idx = OS.CreateBar and OS.CreateBar()
            if ok then Bar.Open(idx) end
        else
            for i = 1, #bars do
                Bar.Open(i)
            end
        end
    end
end

function Bar.AssignMacro(macroID, barIndex)
    barIndex = barIndex or 1
    if not OS.AssignMacroToBar then return false, "Barre Omega indisponible." end
    local ok, slotOrMsg, usedBar = OS.AssignMacroToBar(macroID, barIndex)
    if ok then
        Bar.Open(usedBar or barIndex)
        Bar.Refresh(usedBar or barIndex)
        return true, "Assigne a la barre " .. tostring(usedBar or barIndex) .. ", slot " .. tostring(slotOrMsg)
    end
    return false, slotOrMsg
end

function Bar.PickMacro(macroID)
    local ok, msg = SetPickedMacro(macroID)
    if ok then
        Bar.Open(1)
        return true, "Macro prise : cliquez sur un slot de barre."
    end
    return false, msg
end

-- Place un sort WoW natif sur le curseur pour dépôt sur une barre.
-- nameOrID : nom du sort (string) ou spellID (number).
function Bar.PickSpell(nameOrID)
    if not nameOrID or nameOrID == "" then
        return false, "Nom ou ID de sort requis."
    end
    local name, icon = GetWoWSpellData(nameOrID)
    if not name then
        return false, "Sort introuvable : " .. tostring(nameOrID)
    end
    local slotID = "spell:" .. tostring(nameOrID)
    local ok, msg = SetPickedMacro(slotID)
    if ok then
        Bar.Open(1)
        return true, "Sort [" .. name .. "] pris - cliquez sur un slot de barre."
    end
    return false, msg
end

-- Place une macro WoW native sur le curseur pour dépôt sur une barre.
-- On ne copie pas le body : on stocke uniquement le nom (référence vivante).
function Bar.PickWoWMacro(macro)
    local macroIndex = nil
    local name

    if type(macro) == "table" then
        macroIndex = tonumber(macro.index)
        name = macro.name
    elseif type(macro) == "number" then
        macroIndex = macro
    elseif GetMacroIndexByName then
        macroIndex = GetMacroIndexByName(tostring(macro or ""))
    end

    if macroIndex and macroIndex > 0 and GetMacroInfo then
        local infoName = GetMacroInfo(macroIndex)
        name = name or infoName
    end

    if not name or name == "" then
        return false, "Macro WoW introuvable."
    end

    -- Stockage par référence : "wow:NomDeLaMacro"
    local slotID = "wow:" .. name

    local ok, msg = SetPickedMacro(slotID)
    if ok then
        Bar.Open(1)
        return true, "Macro WoW [" .. name .. "] prise : cliquez sur un slot de barre."
    end
    return false, msg
end

function Bar.ClearPickedMacro()
    ClearPickedMacro()
end

-- ── Gestionnaire de barres ────────────────────────────────────────────────────

local manager = CreateFrame("Frame", "OmegaSpellBarManager", UIParent, "BackdropTemplate")
manager:SetWidth(260)
manager:SetFrameStrata("HIGH")
manager:SetFrameLevel(140)
manager:SetMovable(true)
manager:EnableMouse(true)
manager:RegisterForDrag("LeftButton")
manager:SetScript("OnDragStart", manager.StartMoving)
manager:SetScript("OnDragStop",  manager.StopMovingOrSizing)
manager:Hide()

local mgrBg = manager:CreateTexture(nil, "BACKGROUND")
mgrBg:SetAllPoints()
HUI.ApplyWindowBackground(mgrBg, 0.97)
manager:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets   = { left = 4, right = 4, top = 4, bottom = 4 },
})
manager:SetBackdropBorderColor(unpack(HUI.colors.separator))

-- Header
local mgrHeader = CreateFrame("Frame", nil, manager)
mgrHeader:SetPoint("TOPLEFT",  4, -4)
mgrHeader:SetPoint("TOPRIGHT", -4, -4)
mgrHeader:SetHeight(36)

local mgrHBg = mgrHeader:CreateTexture(nil, "BACKGROUND")
mgrHBg:SetAllPoints()
HUI.ApplyWindowBackground(mgrHBg, 0.70)

local mgrAccent = mgrHeader:CreateTexture(nil, "ARTWORK")
mgrAccent:SetWidth(3)
mgrAccent:SetPoint("TOPLEFT")
mgrAccent:SetPoint("BOTTOMLEFT")
mgrAccent:SetColorTexture(unpack(HUI.colors.tabLine))

local mgrTitle = mgrHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
mgrTitle:SetPoint("LEFT", mgrHeader, "LEFT", 12, 0)
mgrTitle:SetText("Barres Omega")
HUI.ApplyTitle(mgrTitle)

local macroLibraryBtn = HUI.CreatePanelButton(mgrHeader, 100, 22, "Bibliothèque")
macroLibraryBtn:SetPoint("RIGHT", mgrHeader, "RIGHT", -32, 0)
macroLibraryBtn:SetScript("OnClick", function()
    if OmegaSpell.MacroLibrary and OmegaSpell.MacroLibrary.Open then
        OmegaSpell.MacroLibrary.Open()
    end
end)

HUI.CreateCloseButton(manager, function() manager:Hide() end)

-- Séparateur
local mgrSep = manager:CreateTexture(nil, "ARTWORK")
mgrSep:SetHeight(1)
mgrSep:SetPoint("TOPLEFT",  manager, "TOPLEFT",  4, -42)
mgrSep:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -4, -42)
HUI.ApplySeparator(mgrSep, true)

-- ── Bouton de sécurité — unique pour toutes les barres ───────────────────────

local mgrControls = CreateFrame("Frame", nil, manager)
mgrControls:SetPoint("TOPLEFT",  manager, "TOPLEFT",  8, -48)
mgrControls:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -8, -48)
mgrControls:SetHeight(22)

local delToggleBtn = CreateFrame("Button", nil, mgrControls, "BackdropTemplate")
delToggleBtn:SetPoint("TOPLEFT",     mgrControls, "TOPLEFT",  0, 0)
delToggleBtn:SetPoint("BOTTOMRIGHT", mgrControls, "BOTTOMRIGHT", 0, 0)
delToggleBtn:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 8,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 },
})
delToggleBtn:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
delToggleBtn:SetBackdropBorderColor(unpack(HUI.colors.separator))

local delToggleText = delToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
delToggleText:SetAllPoints()
delToggleText:SetJustifyH("CENTER")
delToggleText:SetJustifyV("MIDDLE")
HUI.ApplyStrongLabel(delToggleText)

local function UpdateDelToggle()
    if deletionEnabled then
        delToggleText:SetText("Suppression clic droit : ACTIVÉE")
        delToggleText:SetTextColor(1.0, 0.35, 0.35, 1)
        delToggleBtn:SetBackdropBorderColor(0.75, 0.20, 0.20, 0.90)
    else
        delToggleText:SetText("Suppression clic droit : désactivée")
        HUI.ApplyStrongLabel(delToggleText)
        delToggleBtn:SetBackdropBorderColor(unpack(HUI.colors.separator))
    end
end
UpdateDelToggle()

delToggleBtn:SetScript("OnClick", function()
    deletionEnabled = not deletionEnabled
    UpdateDelToggle()
end)
delToggleBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Sécurité de suppression", 1, 0.86, 0.45)
    GameTooltip:AddLine("Désactivée : le clic droit ne vide aucun slot.", 0.55, 0.55, 0.55)
    GameTooltip:AddLine("Activée : le clic droit vide le slot ciblé.", 0.55, 0.55, 0.55)
    GameTooltip:AddLine("Ce réglage s'applique à toutes les barres.", 0.45, 0.45, 0.45)
    GameTooltip:Show()
end)
delToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local mgrCtrlSep = manager:CreateTexture(nil, "ARTWORK")
mgrCtrlSep:SetHeight(1)
mgrCtrlSep:SetPoint("TOPLEFT",  manager, "TOPLEFT",  4, -72)
mgrCtrlSep:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -4, -72)
HUI.ApplySeparator(mgrCtrlSep, true)

-- Zone de liste
local mgrList = CreateFrame("Frame", nil, manager)
mgrList:SetPoint("TOPLEFT",  manager, "TOPLEFT",  8, -78)
mgrList:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -8, -78)
manager.list = mgrList

local ROW_H_MGR   = 28
local mgrRows     = {}   -- frames de lignes trackées
local mgrFootSep  = nil  -- séparateur footer (frame)
local mgrAddBtn   = nil  -- bouton "+" (frame)

local function DeleteBar(index)
    -- 1. Détruire TOUS les frames existants (les closures internes ont barIndex figé)
    for j = 1, #(OS.GetBars and OS.GetBars() or {}) do
        if frames[j] then
            frames[j]:Hide()
            frames[j] = nil
        end
    end
    -- 2. Supprimer de la DB (décale les indices)
    table.remove(OmegaSpellDB.bars, index)
    -- 3. Réouvrir les barres encore marquées "shown" avec leurs nouveaux indices corrects
    local bars = OS.GetBars and OS.GetBars() or {}
    for j, cfg in ipairs(bars) do
        if cfg.shown then
            Bar.Open(j)
        end
    end
end

local function RefreshManager()
    -- Masquer les lignes précédentes (frames trackées)
    for _, row in ipairs(mgrRows) do row:Hide() end
    wipe(mgrRows)
    -- Masquer le séparateur et le bouton "+" précédents
    if mgrFootSep then mgrFootSep:Hide() end
    if mgrAddBtn  then mgrAddBtn:Hide()  end

    local bars  = OS.GetBars and OS.GetBars() or {}
    local count = #bars

    for i = 1, count do
        local cfg = bars[i]
        local row = CreateFrame("Frame", nil, mgrList)
        row:SetPoint("TOPLEFT",  mgrList, "TOPLEFT",  0, -(i - 1) * ROW_H_MGR)
        row:SetPoint("TOPRIGHT", mgrList, "TOPRIGHT", 0, -(i - 1) * ROW_H_MGR)
        row:SetHeight(ROW_H_MGR)

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        local shade = i % 2 == 0 and 0.12 or 0.08
        rowBg:SetColorTexture(shade, shade, shade, 1)

        -- Checkbox visibilité
        local shown = frames[i] and frames[i]:IsShown()
        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(20, 20)
        check:SetPoint("LEFT", row, "LEFT", 4, 0)
        check:SetChecked(shown)
        local ci = i
        check:SetScript("OnClick", function(self)
            if self:GetChecked() then Bar.Open(ci) else Bar.Hide(ci) end
        end)
        check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Afficher / Masquer la barre", 1, 0.86, 0.45)
            GameTooltip:Show()
        end)
        check:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Checkbox cadre (chrome)
        local chromeCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        chromeCheck:SetSize(20, 20)
        chromeCheck:SetPoint("LEFT", check, "RIGHT", 2, 0)
        chromeCheck:SetChecked(not cfg.locked)
        chromeCheck:SetScript("OnClick", function(self)
            local f = frames[ci]
            if f and f.SetChromeVisible then
                f.SetChromeVisible(self:GetChecked())
            else
                cfg.locked = not self:GetChecked()
            end
        end)
        chromeCheck:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine("Afficher / Masquer le cadre", 1, 0.86, 0.45)
            GameTooltip:AddLine("Cache le fond, le titre, les boutons et les slots vides.", 0.55, 0.55, 0.55)
            GameTooltip:Show()
        end)
        chromeCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Nom (EditBox inline pour renommer directement)
        local nameEdit = CreateFrame("EditBox", nil, row, "BackdropTemplate")
        nameEdit:SetPoint("LEFT",  chromeCheck, "RIGHT", 4, 0)
        nameEdit:SetPoint("RIGHT", row,   "RIGHT", -54, 0)
        nameEdit:SetHeight(20)
        nameEdit:SetAutoFocus(false)
        nameEdit:SetMaxLetters(32)
        nameEdit:SetFontObject(GameFontNormalSmall)
        nameEdit:SetTextColor(0.85, 0.82, 0.72, 1)
        nameEdit:SetText(cfg.name or ("Barre Omega " .. i))
        nameEdit:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 6,
            insets   = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        nameEdit:SetBackdropColor(0.04, 0.04, 0.04, 0)
        nameEdit:SetBackdropBorderColor(0, 0, 0, 0)
        nameEdit:SetScript("OnEditFocusGained", function(self)
            self:SetBackdropColor(0.04, 0.04, 0.04, 0.95)
            self:SetBackdropBorderColor(unpack(HUI.colors.separator))
            self:HighlightText()
        end)
        local function CommitRename(self)
            self:SetBackdropColor(0.04, 0.04, 0.04, 0)
            self:SetBackdropBorderColor(0, 0, 0, 0)
            local text = self:GetText()
            if OS.SetBarName then
                local ok, newName = OS.SetBarName(ci, text)
                if ok and newName then
                    cfg.name = newName
                    self:SetText(newName)
                    Bar.Refresh(ci)
                else
                    self:SetText(cfg.name or ("Barre Omega " .. ci))
                end
            end
        end
        nameEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        nameEdit:SetScript("OnEscapePressed", function(self)
            self:SetText(cfg.name or ("Barre Omega " .. ci))
            self:ClearFocus()
        end)
        nameEdit:SetScript("OnEditFocusLost", CommitRename)

        -- Bouton Supprimer
        local delBtn = HUI.CreatePanelButton(row, 46, 20, "Suppr.")
        delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        delBtn:SetScript("OnClick", function()
            DeleteBar(ci)
            RefreshManager()
        end)

        mgrRows[i] = row
    end

    -- Séparateur footer (frame, pas texture → masquable proprement)
    local sep = CreateFrame("Frame", nil, mgrList)
    sep:SetPoint("TOPLEFT",  mgrList, "TOPLEFT",  0, -(count * ROW_H_MGR) - 4)
    sep:SetPoint("TOPRIGHT", mgrList, "TOPRIGHT", 0, -(count * ROW_H_MGR) - 4)
    sep:SetHeight(1)
    local sepTex = sep:CreateTexture(nil, "ARTWORK")
    sepTex:SetAllPoints()
    HUI.ApplySeparator(sepTex, true)
    mgrFootSep = sep

    -- Bouton "+"
    local addBtn = HUI.CreatePanelButton(mgrList, 240, 24, "+ Nouvelle barre")
    addBtn:SetPoint("TOPLEFT", mgrList, "TOPLEFT", 0, -(count * ROW_H_MGR) - 12)
    addBtn:SetScript("OnClick", function()
        if OS.CreateBar then
            local ok, idx = OS.CreateBar()
            if ok then
                Bar.Open(idx)
                RefreshManager()
            end
        end
    end)
    mgrAddBtn = addBtn

    -- Hauteur dynamique
    manager:SetHeight(78 + count * ROW_H_MGR + 44)
    mgrList:SetHeight(count * ROW_H_MGR + 40)
end

function Bar.OpenManager()
    if manager:IsShown() then
        manager:Hide()
        return
    end
    manager:ClearAllPoints()
    manager:SetPoint("CENTER")
    RefreshManager()
    manager:Show()
end

function Bar.RefreshManager()
    if manager:IsShown() then
        RefreshManager()
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if OmegaHub and OmegaHub.IsModuleEnabled and OmegaHub:IsModuleEnabled("Omega_Spell") then
        local bars = OS.GetBars and OS.GetBars() or {}
        for i, cfg in ipairs(bars) do
            if cfg.shown then
                Bar.Open(i)
            end
        end
    end
    initFrame:UnregisterAllEvents()
end)
