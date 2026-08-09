-- ============================================================
--  Tech — Core
--  Tablette RP tactile façon appareil futuriste : écran d'accueil
--  avec grille d'applications (Notes, Inventaire, Store, Comm,
--  Réglages), verrouillage, dock, etc.
-- ============================================================

Tech = Tech or {}
local T = Tech
_G.Tech = T

T.name = "Tech"

T.colors = {
    bg        = { 0.02, 0.05, 0.05, 0.95 },
    border    = { 0.10, 0.55, 0.55, 1.00 },
    accent    = { 0.20, 0.90, 0.75, 1.00 },
    accentDim = { 0.15, 0.55, 0.50, 1.00 },
    active    = { 0.85, 0.35, 0.90, 1.00 },
    title     = { 0.55, 0.98, 0.85, 1.00 },
    text      = { 0.72, 0.92, 0.90, 1.00 },
    textMuted = { 0.45, 0.65, 0.65, 1.00 },
    logInfo   = { 0.30, 0.90, 0.40, 1.00 },
    logComm   = { 0.35, 0.65, 0.95, 1.00 },
    logAlert  = { 0.95, 0.65, 0.20, 1.00 },
    bezel     = { 0.045, 0.05, 0.055, 1.00 },
}

-- ── DB ───────────────────────────────────────────────────────────────────────

local function EnsureDB()
    TechDB = TechDB or {}
    TechDB.log = TechDB.log or {}
    TechDB.inventory = TechDB.inventory or {}
    TechDB.inventory.heirlooms = TechDB.inventory.heirlooms or {}
    TechDB.inventory.artifacts = TechDB.inventory.artifacts or {}
    TechDB.inventory.tomes     = TechDB.inventory.tomes     or {}
    TechDB.store = TechDB.store or {}
    TechDB.store.installed = TechDB.store.installed or {}
    TechDB.comm = TechDB.comm or {}
    TechDB.settings = TechDB.settings or {}
    if TechDB.settings.brightness == nil then TechDB.settings.brightness = 1.0 end
    return TechDB
end

function T:GetDB() return EnsureDB() end

function T:Timestamp()
    return date("%H:%M")
end

-- ── Widgets partagés ───────────────────────────────────────────────────────

-- ScrollFrame minimal (molette uniquement) — le contenu épouse la largeur
-- du cadre visible dès que ses ancres horizontales sont posées par l'appelant.
function T.CreateScrollList(parent, height)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetHeight(height)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetHeight(height)
    scroll:SetScrollChild(content)

    scroll:SetScript("OnSizeChanged", function(self, w)
        if w and w > 0 then content:SetWidth(w) end
    end)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = self:GetVerticalScrollRange()
        local cur = self:GetVerticalScroll()
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 28)))
    end)

    return scroll, content
end

function T.CreateDeleteButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(16, 16)

    local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetAllPoints()
    lbl:SetText("×")
    lbl:SetTextColor(0.85, 0.35, 0.35, 1)
    btn.label = lbl

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(0.85, 0.20, 0.20, 0.30)

    return btn
end

-- Icône carrée façon "app" (fond coloré + icône + surbrillance), utilisée par
-- la grille d'accueil, le dock et l'app Inventaire.
function T.CreateIconButton(parent, size, iconTexture, color)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(color or T.colors.accentDim))
    btn.bg = bg

    local shade = btn:CreateTexture(nil, "BORDER")
    shade:SetPoint("BOTTOMLEFT")
    shade:SetPoint("BOTTOMRIGHT")
    shade:SetHeight(size * 0.5)
    shade:SetColorTexture(0, 0, 0, 0.18)

    local inset = size * 0.18
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", -inset, inset)
    icon:SetTexture(iconTexture)
    btn.icon = icon

    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.18)

    return btn
end

-- ── Luminosité de l'écran ──────────────────────────────────────────────────

function T:SetBrightness(value)
    value = math.max(0.4, math.min(1.0, tonumber(value) or 1.0))
    T:GetDB().settings.brightness = value
    if T.dimOverlay then
        T.dimOverlay:SetAlpha((1 - value) * 0.85)
    end
    return value
end

-- ── Réinitialisation des données ───────────────────────────────────────────

function T:ResetData()
    wipe(TechDB.log)
    wipe(TechDB.inventory.heirlooms)
    wipe(TechDB.inventory.artifacts)
    wipe(TechDB.inventory.tomes)
    wipe(TechDB.comm)
    wipe(TechDB.store.installed)

    if T.RefreshNotes then T:RefreshNotes() end
    if T.RefreshInventoryList then T:RefreshInventoryList() end
    if T.RefreshStore then T:RefreshStore() end
    if T.RefreshComm then T:RefreshComm() end
    OmegaHub.Print("Tech : données réinitialisées.")
end

-- ── Log (Notes) ──────────────────────────────────────────────────────────────

function T:AddLogEntry(kind, text)
    text = (text or ""):match("^%s*(.-)%s*$") or ""
    if text == "" then return false end
    kind = (kind == "comm" or kind == "alert") and kind or "log"

    table.insert(TechDB.log, 1, { time = T:Timestamp(), kind = kind, text = text })
    if T.RefreshNotes then T:RefreshNotes() end
    return true
end

function T:RemoveLogEntry(index)
    table.remove(TechDB.log, index)
    if T.RefreshNotes then T:RefreshNotes() end
end

-- ── Inventaire ───────────────────────────────────────────────────────────────

T.InventoryCategories = { "heirlooms", "artifacts", "tomes" }

function T:AddInventoryItem(category, name)
    name = (name or ""):match("^%s*(.-)%s*$") or ""
    if name == "" then return false end
    local list = TechDB.inventory[category]
    if not list then return false end
    table.insert(list, { name = name })
    if T.RefreshInventoryList then T:RefreshInventoryList(category) end
    return true
end

function T:RemoveInventoryItem(category, index)
    local list = TechDB.inventory[category]
    if not list then return end
    table.remove(list, index)
    if T.RefreshInventoryList then T:RefreshInventoryList(category) end
end

-- ── Store ────────────────────────────────────────────────────────────────────

function T:IsAppInstalled(appId)
    return TechDB.store.installed[appId] == true
end

function T:SetAppInstalled(appId, installed)
    TechDB.store.installed[appId] = installed and true or nil
    if T.RefreshStore then T:RefreshStore() end
end

-- ── Comm ─────────────────────────────────────────────────────────────────────

function T:AddCommEntry(sender, text)
    sender = (sender or ""):match("^%s*(.-)%s*$") or ""
    text   = (text or ""):match("^%s*(.-)%s*$") or ""
    if text == "" then return false end
    if sender == "" then sender = "INCONNU" end

    table.insert(TechDB.comm, 1, { time = T:Timestamp(), sender = sender, text = text })
    if T.RefreshComm then T:RefreshComm() end
    return true
end

function T:RemoveCommEntry(index)
    table.remove(TechDB.comm, index)
    if T.RefreshComm then T:RefreshComm() end
end

-- ── Enable / Disable ──────────────────────────────────────────────────────────

function T:Enable()
    if T._resetLauncherOnNextEnable and T.ResetLauncherPosition then
        T:ResetLauncherPosition(true)
    elseif TechLauncherBtn then
        TechLauncherBtn:Show()
    end
    T._resetLauncherOnNextEnable = nil
    OmegaHub:SetModuleLoaded("Tech", true)
    if not OmegaHub._startingUp then
        OmegaHub.Print("Tech activé.  |cffAAAAAA/otech|r")
    end
end

function T:Disable()
    T._resetLauncherOnNextEnable = true
    if TechMainPanel then TechMainPanel:Hide() end
    if TechLauncherBtn then TechLauncherBtn:Hide() end
    if T.LockScreen then T.LockScreen:Hide() end
    if T.GoHome then T:GoHome() end
    OmegaHub:SetModuleLoaded("Tech", false)
    OmegaHub.Print("Tech désactivé.")
end

-- ── Slash ─────────────────────────────────────────────────────────────────────

SLASH_OTECH1 = "/otech"
SlashCmdList["OTECH"] = function()
    if TechMainPanel then TechMainPanel:Toggle() end
end

-- ── Init ─────────────────────────────────────────────────────────────────────

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    OmegaHub:RegisterModule({
        name    = "Tech",
        title   = "Omega Tech",
        desc    = "Tablette RP : notes, inventaire, store et communications",
        version = "1.0.0",
        module  = T,
    })
    EnsureDB()
    if OmegaHub:IsModuleEnabled("Tech") then T:Enable() end
    f:UnregisterAllEvents()
end)
