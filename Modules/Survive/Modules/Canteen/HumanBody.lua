-- OmegaSurvive 2.0 — Corps Humain v2
OS2    = OS2    or {}
OS2.UI = OS2.UI or {}

local bodyPanel = nil

-- ── Palette ───────────────────────────────────────────────────────────────
local MASK    = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local F       = { 0.46, 0.53, 0.68, 1.00 }   -- fill principal
local O       = { 0.07, 0.09, 0.15, 1.00 }   -- outline sombre
local H       = { 0.64, 0.70, 0.82, 0.45 }   -- highlight (top des membres)
local OT      = 2                              -- outline thickness

-- ── Helpers ───────────────────────────────────────────────────────────────
-- Toutes les fonctions capturent `canvas` et les couleurs via upvalue.
-- Appelées dans GetOrCreateBodyPanel pour éviter les globals.

local function GetOrCreateBodyPanel()
    if bodyPanel then return bodyPanel end
    local UI = OS2.UI

    -- Panel
    local PW, PH = 260, 430
    local p = CreateFrame("Frame", nil, UIParent)
    p:SetSize(PW, PH)
    p:SetFrameStrata("TOOLTIP"); p:SetFrameLevel(100)
    p:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    p:Hide()

    local bg = p:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.98); OS2.RegisterWindowFrame(p, bg)

    local titleStr = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    titleStr:SetPoint("TOP", p, "TOP", 0, -13)
    titleStr:SetText("Corps Humain"); UI.ApplyTitle(titleStr)

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

    -- Canvas (160×300), centré dans le panel
    local CW, CH = 160, 300
    local canvas = CreateFrame("Frame", nil, p)
    canvas:SetSize(CW, CH)
    canvas:SetPoint("TOP", p, "TOP", 0, -50)

    -- CX = 80 (centre horizontal du canvas)

    -- ── Primitives ────────────────────────────────────────────────────────

    -- Crée un rectangle avec contour
    local function Rect(x, y, w, h, col)
        col = col or F
        -- Contour (BACKGROUND, dessiné en premier)
        local ol = canvas:CreateTexture(nil, "BACKGROUND")
        ol:SetSize(w + OT*2, h + OT*2)
        ol:SetPoint("TOPLEFT", canvas, "TOPLEFT", x - OT, -(y - OT))
        ol:SetColorTexture(O[1], O[2], O[3], O[4])
        -- Remplissage (ARTWORK)
        local fi = canvas:CreateTexture(nil, "ARTWORK")
        fi:SetSize(w, h)
        fi:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
        fi:SetColorTexture(col[1], col[2], col[3], col[4])
        return fi
    end

    -- Crée un cercle avec contour (via masque)
    -- layer : "BACKGROUND"|"ARTWORK"|"OVERLAY" pour le fill
    local function Circ(x, y, d, col, fillLayer)
        col = col or F
        fillLayer = fillLayer or "ARTWORK"
        -- Contour circulaire
        local co = canvas:CreateTexture(nil, "BACKGROUND")
        co:SetSize(d + OT*2, d + OT*2)
        co:SetPoint("TOPLEFT", canvas, "TOPLEFT", x - OT, -(y - OT))
        co:SetColorTexture(O[1], O[2], O[3], O[4])
        local cm = canvas:CreateMaskTexture(); cm:SetAllPoints(co)
        cm:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        co:AddMaskTexture(cm)
        -- Fill circulaire
        local fi = canvas:CreateTexture(nil, fillLayer)
        fi:SetSize(d, d)
        fi:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
        fi:SetColorTexture(col[1], col[2], col[3], col[4])
        local fm = canvas:CreateMaskTexture(); fm:SetAllPoints(fi)
        fm:SetTexture(MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        fi:AddMaskTexture(fm)
        return fi
    end

    -- Cercle d'articulation dessiné APRES les segments (OVERLAY)
    -- pour lisser les jonctions entre membres
    local function Joint(cx, cy, d)
        -- Le contour de l'articulation est masqué par celui du segment adjacent,
        -- donc on ne dessine que le fill en OVERLAY (par-dessus tout)
        local r = math.floor(d / 2)
        Circ(cx - r, cy - r, d, F, "OVERLAY")
    end

    -- Highlight fin en haut d'un segment (simule la lumière venant du haut)
    local function Hilite(x, y, w, h)
        local hi = canvas:CreateTexture(nil, "OVERLAY")
        hi:SetSize(w, h)
        hi:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
        hi:SetColorTexture(H[1], H[2], H[3], H[4])
    end

    -- ══════════════════════════════════════════════════════════════════════
    --  CORPS — centre X = 80
    --
    --  Proportions : 7.5 têtes de haut (~38px/tête pour 280px de corps)
    --
    --  TÊTE    d=38   cx=80  y=0
    --  COU     w=14   cx=80  y=37
    --  TORSE (trapèze simulé en 3 bandes)
    --    Poitrine  w=104  cx=80  y=50
    --    Milieu    w=90   cx=80  y=74
    --    Taille    w=78   cx=80  y=92
    --  HANCHES   w=88   cx=80  y=108
    --
    --  BRAS G (cx=15) :  hauts=20, avant=16, main=22
    --  BRAS D (cx=145):  idem, symétrique
    --  JAMBE G (cx=57):  cuisse=32, tibia=26, pied=50
    --  JAMBE D (cx=103): idem, symétrique
    -- ══════════════════════════════════════════════════════════════════════

    -- ── 1. Segments (BACKGROUND outlines + ARTWORK fills) ─────────────────

    -- Tête (cercle d=38)
    Circ(61, 0, 38)
    Hilite(63, 2, 34, 8)   -- highlight circulaire approximé

    -- Cou
    Rect(73, 37, 14, 12)

    -- Torse : 3 bandes pour simuler la forme trapézoïdale
    Rect(28, 48, 104, 26)  -- poitrine (la plus large)
    Rect(35, 72,  90, 20)  -- milieu
    Rect(41, 90,  78, 20)  -- taille

    -- Hanches
    Rect(36, 108, 88, 18)

    -- Bras gauche (cx ≈ 15)
    Rect(6,  54, 20, 40)   -- haut du bras
    Rect(8,  93, 16, 34)   -- avant-bras
    Rect(5, 126, 22, 16)   -- main

    -- Bras droit (cx ≈ 145, symétrique)
    Rect(134, 54, 20, 40)
    Rect(136, 93, 16, 34)
    Rect(133,126, 22, 16)

    -- Jambe gauche (cx ≈ 57)
    Rect(41, 124, 32, 56)  -- cuisse
    Rect(44, 179, 26, 50)  -- tibia
    Rect(30, 228, 50, 14)  -- pied

    -- Jambe droite (cx ≈ 103, symétrique)
    Rect(87, 124, 32, 56)
    Rect(90, 179, 26, 50)
    Rect(80, 228, 50, 14)

    -- ── 2. Articulations (OVERLAY — lissent les jonctions) ────────────────

    -- Épaule gauche : où le haut du bras rejoint la poitrine
    Joint(16, 62, 22)
    -- Épaule droite
    Joint(144, 62, 22)

    -- Coude gauche
    Joint(16, 94, 18)
    -- Coude droit
    Joint(144, 94, 18)

    -- Poignet gauche
    Joint(16, 127, 16)
    -- Poignet droit
    Joint(144, 127, 16)

    -- Hanche gauche
    Joint(57, 126, 26)
    -- Hanche droite
    Joint(103, 126, 26)

    -- Genou gauche
    Joint(57, 180, 22)
    -- Genou droit
    Joint(103, 180, 22)

    -- Cheville gauche
    Joint(57, 229, 18)
    -- Cheville droite
    Joint(103, 229, 18)

    -- Jonction cou/torse (smooth)
    Joint(80, 50, 16)

    -- ── 3. Highlights ─────────────────────────────────────────────────────
    Hilite(30, 50,  104, 6)   -- haut poitrine
    Hilite(42,  92,  78, 5)   -- haut taille
    Hilite(37, 110,  88, 5)   -- haut hanches
    Hilite(7,  56,   18, 6)   -- haut bras G
    Hilite(135, 56,  18, 6)   -- haut bras D
    Hilite(42, 126,  30, 6)   -- haut cuisse G
    Hilite(88, 126,  30, 6)   -- haut cuisse D
    Hilite(45, 181,  24, 5)   -- haut tibia G
    Hilite(91, 181,  24, 5)   -- haut tibia D

    bodyPanel = p
    return p
end

-- ── API publique ───────────────────────────────────────────────────────────
function OS2.ShowHumanBodyPanel()
    local p = GetOrCreateBodyPanel()
    if p:IsShown() then p:Hide() else p:Show() end
end
