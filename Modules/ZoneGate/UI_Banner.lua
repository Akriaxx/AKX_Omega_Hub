-- ============================================================
--  Zone Gate — Bannière de franchissement
--  Texte de zone façon Blizzard, mais maison (pas de hook sur
--  ZoneTextFrame — trop fragile d'une version à l'autre).
--  Le rendu (police, couleurs, séparateur, bandeau de fond,
--  timing) vient du thème résolu par ZG:ResolveTheme (voir
--  Core.lua) — ZG.DefaultTheme reproduit l'ancien rendu codé en
--  dur quand rien n'est choisi, donc aucune régression visuelle
--  pour qui n'utilise jamais les thèmes.
-- ============================================================

local ZG = ZoneGate

local MEDIA_DIR = "Interface\\AddOns\\Omega_Hub\\Modules\\ZoneGate\\Media\\"

-- One renderer for crossings, studio and style thumbnails.
function ZG.CreateBannerRenderer(parent, name)
local banner = CreateFrame("Frame", name, parent or UIParent)
banner:SetSize(600, 90)
banner:SetPoint("TOP", UIParent, "TOP", 0, -140)
banner:SetFrameStrata("HIGH")
banner:EnableMouse(false)
banner:SetAlpha(0)
banner:Hide()

-- ── Bandeau de fond ─────────────────────────────────────────────────────────
-- Une texture "dégradé" pré-calculée (transparent→opaque→transparent,
-- Media/Gradient.tga) teintée via SetVertexColor, plutôt que
-- Texture:SetGradient — cette API s'est révélée absente sur certains
-- clients en pratique (le bandeau restait invisible, aucune erreur).
local bgBand = banner:CreateTexture(nil, "BACKGROUND")
bgBand:SetTexture(MEDIA_DIR .. "Gradient.tga")
bgBand:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, -2)
bgBand:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", 0, 2)
bgBand:Hide()

-- ── Cadre (aucun / simple / orné) ────────────────────────────────────────
-- Indépendant des séparateurs et du bandeau de fond — les trois se cumulent
-- librement. "box" : 4 traits colorés formant un rectangle (aucune image).
-- "ornate" : 4 coins en filigrane (Media/FrameCorner.tga, un seul fichier
-- réutilisé aux 4 coins via SetTexCoord — voir CornerTexCoord) reliés par
-- les mêmes traits, simplement resserrés pour laisser la place aux coins.
local FRAME_INSET  = 6
local FRAME_CORNER = 26
local FRAME_THICK  = 2

local frameTop = banner:CreateTexture(nil, "ARTWORK")
frameTop:SetHeight(FRAME_THICK)
local frameBottom = banner:CreateTexture(nil, "ARTWORK")
frameBottom:SetHeight(FRAME_THICK)
local frameLeft = banner:CreateTexture(nil, "ARTWORK")
frameLeft:SetWidth(FRAME_THICK)
local frameRight = banner:CreateTexture(nil, "ARTWORK")
frameRight:SetWidth(FRAME_THICK)
for _, tex in ipairs({ frameTop, frameBottom, frameLeft, frameRight }) do
    tex:Hide()
end

-- x0/x1 = coordonnées U (gauche/droite), y0/y1 = coordonnées V (haut/bas) —
-- inversées pour retourner l'image horizontalement/verticalement, de façon
-- à obtenir les 4 orientations à partir d'un seul fichier.
local function CornerTexCoord(flipH, flipV)
    local x0, x1 = 0, 1
    local y0, y1 = 0, 1
    if flipH then x0, x1 = 1, 0 end
    if flipV then y0, y1 = 1, 0 end
    return x0, y0, x0, y1, x1, y0, x1, y1
end

local function CreateFrameCorner(flipH, flipV)
    local tex = banner:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(MEDIA_DIR .. "FrameCorner.tga")
    tex:SetSize(FRAME_CORNER, FRAME_CORNER)
    tex:SetTexCoord(CornerTexCoord(flipH, flipV))
    tex:Hide()
    return tex
end

local frameCornerTL = CreateFrameCorner(false, false)
frameCornerTL:SetPoint("TOPLEFT", banner, "TOPLEFT", FRAME_INSET, -FRAME_INSET)
local frameCornerTR = CreateFrameCorner(true, false)
frameCornerTR:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -FRAME_INSET, -FRAME_INSET)
local frameCornerBL = CreateFrameCorner(false, true)
frameCornerBL:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", FRAME_INSET, FRAME_INSET)
local frameCornerBR = CreateFrameCorner(true, true)
frameCornerBR:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -FRAME_INSET, FRAME_INSET)

-- cornerGap = FRAME_CORNER en style "ornate" (les traits s'arrêtent avant
-- les coins), 0 en style "box" (les traits vont d'un bout à l'autre).
local function LayoutFrameLines(cornerGap)
    frameTop:ClearAllPoints()
    frameTop:SetPoint("TOPLEFT", banner, "TOPLEFT", FRAME_INSET + cornerGap, -FRAME_INSET)
    frameTop:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -FRAME_INSET - cornerGap, -FRAME_INSET)

    frameBottom:ClearAllPoints()
    frameBottom:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", FRAME_INSET + cornerGap, FRAME_INSET)
    frameBottom:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -FRAME_INSET - cornerGap, FRAME_INSET)

    frameLeft:ClearAllPoints()
    frameLeft:SetPoint("TOPLEFT", banner, "TOPLEFT", FRAME_INSET, -FRAME_INSET - cornerGap)
    frameLeft:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", FRAME_INSET, FRAME_INSET + cornerGap)

    frameRight:ClearAllPoints()
    frameRight:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -FRAME_INSET, -FRAME_INSET - cornerGap)
    frameRight:SetPoint("BOTTOMRIGHT", banner, "BOTTOMRIGHT", -FRAME_INSET, FRAME_INSET + cornerGap)
end

local lineTop = banner:CreateTexture(nil, "ARTWORK")
lineTop:SetPoint("TOP", banner, "TOP", 0, -6)
lineTop:SetSize(360, 1)

local lineTop2 = banner:CreateTexture(nil, "ARTWORK")
lineTop2:SetPoint("TOP", lineTop, "BOTTOM", 0, -2)
lineTop2:SetSize(360, 1)

local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", lineTop, "BOTTOM", 0, -10)

-- Séparateur optionnel entre titre et sous-titre (theme.midSepEnabled) —
-- toujours en trait simple, même couleur que lineTop/lineBottom, un peu
-- plus étroit pour marquer la hiérarchie visuelle. Sa taille/position ne
-- change pas selon qu'il soit affiché ou non (juste :Show()/:Hide()), donc
-- l'ancrage de "sub" ci-dessous reste stable dans les deux cas.
local lineMid = banner:CreateTexture(nil, "ARTWORK")
lineMid:SetPoint("TOP", title, "BOTTOM", 0, -6)
lineMid:SetSize(240, 1)
lineMid:Hide()

local sub = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
sub:SetPoint("TOP", lineMid, "BOTTOM", 0, -6)

local lineBottom = banner:CreateTexture(nil, "ARTWORK")
lineBottom:SetPoint("TOP", sub, "BOTTOM", 0, -10)
lineBottom:SetSize(360, 1)

local lineBottom2 = banner:CreateTexture(nil, "ARTWORK")
lineBottom2:SetPoint("TOP", lineBottom, "BOTTOM", 0, -2)
lineBottom2:SetSize(360, 1)

-- Police d'origine (avant tout thème) — repli si un thème pointe vers une
-- police introuvable pour une raison ou une autre.
local DEFAULT_FONT_PATH = title:GetFont() or "Fonts\\FRIZQT__.TTF"

-- ── Animation : fade in → hold → fade out ─────────────────────────────────
-- Durées reprises depuis le thème à chaque ShowBanner (voir ApplyTheme) —
-- celles ci-dessous ne sont que les valeurs de secours au tout premier
-- chargement, avant le premier SetDuration.

local anim = banner:CreateAnimationGroup()

local fadeIn = anim:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(0.4)
fadeIn:SetOrder(1)

local hold = anim:CreateAnimation("Alpha")
hold:SetFromAlpha(1)
hold:SetToAlpha(1)
hold:SetDuration(2.5)
hold:SetOrder(2)

local fadeOut = anim:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(0.8)
fadeOut:SetOrder(3)

anim:SetScript("OnFinished", function()
    banner:Hide()
end)

-- ── Application du thème au cadre ───────────────────────────────────────────

local function ResolveFontPath(theme)
    if theme.font == "custom" and theme.customFont and theme.customFont ~= "" then
        return theme.customFont
    end
    return (theme.font and ZG.FontPaths[theme.font]) or DEFAULT_FONT_PATH
end

local function ApplyTheme(theme)
    theme = theme or ZG.DefaultTheme

    local fontPath = ResolveFontPath(theme)
    local flags = theme.outline and "OUTLINE" or ""
    local titleSize = theme.titleSize or 28
    title:SetFont(fontPath, titleSize, flags)
    sub:SetFont(fontPath, math.max(12, titleSize - 10), flags)

    local tc = theme.titleColor or ZG.DefaultTheme.titleColor
    title:SetTextColor(tc[1], tc[2], tc[3], 1)
    local sc = theme.subColor or ZG.DefaultTheme.subColor
    sub:SetTextColor(sc[1], sc[2], sc[3], 1)

    local sep = theme.sepColor or ZG.DefaultTheme.sepColor
    for _, tex in ipairs({ lineTop, lineBottom }) do
        tex:SetColorTexture(sep[1], sep[2], sep[3], sep[4] or 1)
    end
    local showSep = theme.sepStyle ~= "none"
    local showDouble = theme.sepStyle == "double"
    lineTop:SetShown(showSep)
    lineBottom:SetShown(showSep)
    lineTop2:SetShown(showSep and showDouble)
    lineBottom2:SetShown(showSep and showDouble)
    if showDouble then
        lineTop2:SetColorTexture(sep[1], sep[2], sep[3], (sep[4] or 1) * 0.6)
        lineBottom2:SetColorTexture(sep[1], sep[2], sep[3], (sep[4] or 1) * 0.6)
    end

    lineMid:SetColorTexture(sep[1], sep[2], sep[3], sep[4] or 1)
    lineMid:SetShown(theme.midSepEnabled)

    -- Bandeau de fond (voir bgBand plus haut).
    bgBand:SetShown(theme.bgEnabled)
    if theme.bgEnabled then
        local bg = theme.bgColor or ZG.DefaultTheme.bgColor
        bgBand:SetVertexColor(bg[1], bg[2], bg[3], bg[4] or 0.55)
    end

    -- Cadre (voir frameTop/.../frameCornerBR plus haut).
    local frameStyle = theme.frameStyle or "none"
    local showBox = frameStyle == "box"
    local showOrnate = frameStyle == "ornate"
    LayoutFrameLines(showOrnate and FRAME_CORNER or 0)

    local fc = theme.frameColor or ZG.DefaultTheme.frameColor
    for _, tex in ipairs({ frameTop, frameBottom, frameLeft, frameRight }) do
        tex:SetColorTexture(fc[1], fc[2], fc[3], fc[4] or 1)
        tex:SetShown(showBox or showOrnate)
    end
    for _, tex in ipairs({ frameCornerTL, frameCornerTR, frameCornerBL, frameCornerBR }) do
        tex:SetVertexColor(fc[1], fc[2], fc[3], fc[4] or 1)
        tex:SetShown(showOrnate)
    end

    fadeIn:SetDuration(math.max(0.05, theme.fadeIn or 0.4))
    hold:SetDuration(math.max(0, theme.hold or 2.5))
    fadeOut:SetDuration(math.max(0.05, theme.fadeOut or 0.8))
end

-- ── API publique ─────────────────────────────────────────────────────────────

-- Un nouveau déclenchement pendant qu'une bannière est déjà affichée relance
-- simplement l'animation avec le nouveau texte (pas de file d'attente).
-- theme (optionnel) : voir ZG:ResolveTheme — nil = ZG.DefaultTheme (rendu
-- historique, avant l'existence des thèmes).
function banner:Configure(zoneName, subName, theme)
    if not zoneName or zoneName == "" then return end
    theme = theme or ZG.DefaultTheme

    anim:Stop()
    ApplyTheme(theme)

    title:SetText(ZG:StyleThemeText(zoneName, theme))

    if subName and subName ~= "" then
        sub:SetText(ZG:StyleThemeText(subName, theme))
        sub:Show()
    else
        sub:SetText("")
        sub:Hide()
    end

    banner.theme=theme
end

function banner:ShowBanner(zoneName, subName, theme)
    if not zoneName or zoneName=="" then return end
    self:Configure(zoneName,subName,theme)
    banner:SetAlpha(0)
    banner:Show()
    anim:Play()
end

function banner:HideBanner()
    anim:Stop()
    banner:SetAlpha(0)
    banner:Hide()
end

function banner:Seek(seconds)
    anim:Stop()
    local theme=self.theme or ZG.DefaultTheme
    local enter=math.max(.05,theme.fadeIn or .4)
    local stay=math.max(0,theme.hold or 2.5)
    local leave=math.max(.05,theme.fadeOut or .8)
    local t=math.max(0,seconds or enter)
    local alpha=t<enter and t/enter or (t<enter+stay and 1 or math.max(0,1-(t-enter-stay)/leave))
    self:SetAlpha(alpha);self:Show()
    return enter+stay+leave
end
return banner
end

local liveBanner=ZG.CreateBannerRenderer(UIParent,"ZoneGateBanner")
function ZG:ShowBanner(zoneName,subName,theme) liveBanner:ShowBanner(zoneName,subName,theme) end
function ZG:HideBanner() liveBanner:HideBanner() end
