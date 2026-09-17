local J = Quest
local UI = OS2.UI
-- Le nom du fichier reste compatible avec le TOC ; le thème suit le Hub.
J.Style = {
    paper = UI.colors.rowBg, ink = UI.colors.text,
    muted = UI.colors.textMuted, gold = UI.colors.labelStrong,
    leather = UI.colors.windowBg,
    texture = "Interface\\Buttons\\WHITE8X8",
    quill = "Interface\\AddOns\\Omega_Hub\\Modules\\Quest\\Media\\Quill.ogg",
}
local S = J.Style

function S:Text(parent, text, size, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, size or 14)
    label:SetTextColor(unpack(self.ink))
    label:SetJustifyH("LEFT")
    label:SetJustifyV("TOP")
    label:SetPoint("TOPLEFT", x or 0, y or 0)
    if width then label:SetWidth(width) end
    label:SetText(text or "")
    return label
end

function S:Surface(frame, paper)
    frame:SetBackdrop({ bgFile = self.texture,
        edgeFile = self.texture, tile = false, edgeSize = 1 })
    local color = paper and self.paper or self.leather
    frame:SetBackdropColor(color[1], color[2], color[3], paper and (color[4] or 1) or 1)
    frame:SetBackdropBorderColor(unpack(UI.colors.separatorSoft))
end

function S:Button(parent, text, width, x, y, action)
    local button = UI.CreatePanelButton(parent, width, 28, text)
    button:SetPoint("TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", action)
    return button
end

function S:Window(frame, strata)
    frame:SetPoint("CENTER")
    -- Séparer les fenêtres par strate : Raise() seul ne garantit pas que
    -- le fond passe devant les contrôles enfants de l'autre fenêtre.
    frame:SetFrameStrata(strata or "HIGH")
    frame:SetScale(math.min(1, (UIParent:GetWidth() - 30) / frame:GetWidth(), (UIParent:GetHeight() - 30) / frame:GetHeight()))
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    local close = UI.CreateCloseButton(frame, function() frame:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -12)
    UISpecialFrames[#UISpecialFrames + 1] = frame:GetName()
end

function S:Scroll(parent, width, height, x, y)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetSize(width, height)
    scroll:SetPoint("TOPLEFT", x, y)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(width, height)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(f, delta)
        f:SetVerticalScroll(math.max(0, math.min(f:GetVerticalScrollRange(), f:GetVerticalScroll() - delta * 36)))
    end)
    -- Barre fine : clic dans la piste ou glissement, sans habillage Blizzard.
    local bar = CreateFrame("Slider", nil, parent)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
    bar:SetSize(4, height)
    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 1); bar:SetValueStep(1)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(); track:SetColorTexture(unpack(UI.colors.separatorSoft))
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(4, 28); thumb:SetColorTexture(unpack(UI.colors.panelButtonAccent))
    bar:SetThumbTexture(thumb)
    local syncing = false
    bar:SetScript("OnValueChanged", function(_, value)
        if not syncing then scroll:SetVerticalScroll(value) end
    end)
    scroll:SetScript("OnVerticalScroll", function(_, value)
        syncing = true; bar:SetValue(value); syncing = false
    end)
    scroll:SetScript("OnScrollRangeChanged", function(_, _, range)
        bar:SetMinMaxValues(0, math.max(1, range))
        bar:SetShown(range > 0)
        scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(), math.max(0, range)))
    end)
    bar:Hide()
    return scroll, child
end

function S:Rule(parent, x, y, width)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("TOPLEFT", x, y); rule:SetSize(width, 1)
    UI.ApplySeparator(rule, true)
    return rule
end

function S:Select(button, selected)
    button.bgN:SetColorTexture(unpack(selected and UI.colors.rowBgSelected or UI.colors.panelButtonBg))
    button.accent:SetShown(selected)
    button:GetFontString():SetTextColor(unpack(selected and UI.colors.title or UI.colors.textMuted))
end

-- ── Écritoire du MJ : identité visuelle dédiée ──────────────────────────────
-- Palette et polices propres au panneau MJ, distinctes du reste du module
-- (grimoire/lettre) qui garde son propre habillage parchemin/cuir.
S.mj = {
    ground        = { 0.0706, 0.0549, 0.0353 },
    surface       = { 0.1137, 0.0863, 0.0549 },
    surfaceRaised = { 0.1451, 0.1059, 0.0627 },
    surfaceInset  = { 0.0863, 0.0627, 0.0353 },
    border        = { 0.2275, 0.1725, 0.1020, 1 },
    borderStrong  = { 0.3608, 0.2706, 0.1529, 1 },
    accent        = { 0.7843, 0.5647, 0.2471 },
    accentDim     = { 0.5608, 0.3882, 0.1608, 1 },
    accentInk     = { 0.1020, 0.0627, 0.0235 },
    ink           = { 0.9255, 0.8824, 0.7882, 1 },
    inkMuted      = { 0.6863, 0.6157, 0.4784, 1 },
    inkFaint      = { 0.4353, 0.3843, 0.2824, 1 },
    ok            = { 0.5451, 0.6392, 0.4353, 1 },
    okDim         = { 0.3020, 0.3608, 0.2392, 1 },
    danger        = { 0.7529, 0.4157, 0.3216, 1 },
    dangerDim     = { 0.3608, 0.1961, 0.1490, 1 },
    display       = "Fonts\\MORPHEUS.TTF",
}
local MJ = S.mj

-- Fond plat teinté (ground / surface / surfaceRaised / surfaceInset).
function S:MJSurface(frame, shade, borderShade)
    frame:SetBackdrop({ bgFile = self.texture, edgeFile = self.texture, tile = false, edgeSize = 1 })
    frame:SetBackdropColor(unpack(MJ[shade or "surface"]))
    frame:SetBackdropBorderColor(unpack(MJ[borderShade or "border"]))
end

-- Titre "manuscrit" (police Morpheus, réservée aux grands intitulés).
function S:MJHeading(parent, text, size, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(MJ.display, size or 22)
    label:SetTextColor(unpack(MJ.ink))
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetPoint("TOPLEFT", x or 0, y or 0)
    if width then label:SetWidth(width) end
    label:SetText(text or "")
    return label
end

-- Texte d'interface courant (police standard, tailles/couleurs de l'écritoire).
function S:MJText(parent, text, size, x, y, width, shade)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT, size or 13)
    label:SetTextColor(unpack(MJ[shade or "ink"]))
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetPoint("TOPLEFT", x or 0, y or 0)
    if width then label:SetWidth(width) end
    label:SetText(text or "")
    return label
end

-- Carte : bloc de section avec étiquette flottante sur la bordure haute,
-- comme un onglet de dossier (voir la maquette de l'écritoire).
function S:MJCard(parent, x, y, width, height, tabText)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", x, y); card:SetSize(width, height)
    self:MJSurface(card, "surface", "border")
    if tabText then
        local tab = CreateFrame("Frame", nil, card, "BackdropTemplate")
        self:MJSurface(tab, "ground", "borderStrong")
        local label = self:MJText(tab, tabText, 10, 10, -4, nil, "accent")
        tab:SetSize(label:GetStringWidth() + 20, 18)
        tab:SetPoint("BOTTOMLEFT", card, "TOPLEFT", 14, -9)
        card.tab = tab
    end
    return card
end

-- Bouton de l'écritoire : "primary" (action principale), "danger"
-- (destructif), "ghost" (discret), "tiny" (compact) ou nil (secondaire).
function S:MJButton(parent, text, width, x, y, action, kind)
    local button = UI.CreatePanelButton(parent, width, kind == "tiny" and 22 or 28, text)
    button:SetPoint("TOPLEFT", x, y)
    button:GetFontString():SetFont(STANDARD_TEXT_FONT, kind == "tiny" and 11 or 13)
    button:SetText(text)
    if action then button:SetScript("OnClick", action) end
    if kind == "primary" then
        button.bgN:SetColorTexture(unpack(MJ.accent))
        button.accent:SetColorTexture(unpack(MJ.accentDim))
        button:GetFontString():SetTextColor(unpack(MJ.accentInk))
    elseif kind == "danger" then
        button.bgN:SetColorTexture(unpack(MJ.surfaceRaised))
        button.accent:SetColorTexture(unpack(MJ.dangerDim))
        button:GetFontString():SetTextColor(unpack(MJ.danger))
    elseif kind == "ghost" then
        button.bgN:SetColorTexture(0, 0, 0, 0)
        button.accent:SetColorTexture(0, 0, 0, 0)
        button:GetFontString():SetTextColor(unpack(MJ.inkMuted))
    elseif kind == "accent" then
        button.bgN:SetColorTexture(unpack(MJ.ground))
        button.accent:SetColorTexture(unpack(MJ.accentDim))
        button:GetFontString():SetTextColor(unpack(MJ.accent))
    else
        button.bgN:SetColorTexture(unpack(MJ.surfaceRaised))
        button.accent:SetColorTexture(unpack(MJ.borderStrong))
        button:GetFontString():SetTextColor(unpack(MJ.ink))
    end
    button.mjKind = kind
    return button
end

-- Bascule visuelle d'un bouton "armé" (ex. mode rattachement actif).
function S:MJArm(button, armed)
    if armed then
        button.bgN:SetColorTexture(unpack(MJ.accent))
        button:GetFontString():SetTextColor(unpack(MJ.accentInk))
    else
        button.bgN:SetColorTexture(unpack(MJ.surfaceRaised))
        button:GetFontString():SetTextColor(unpack(MJ.ink))
    end
end

-- Pastille de statut colorée (texture Blizzard générique recolorée).
function S:MJDot(parent, size)
    local dot = parent:CreateTexture(nil, "ARTWORK")
    dot:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    dot:SetSize(size or 7, size or 7)
    return dot
end

