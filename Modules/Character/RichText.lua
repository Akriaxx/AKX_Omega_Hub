-- ============================================================
--  Character - Texte enrichi des compétences
--  Une FontString WoW n'a qu'une police et qu'un style : pas de gras,
--  d'italique ni de souligné en ligne. Ce module découpe le texte en
--  morceaux de même style, fait lui-même le retour à la ligne, et pose
--  une FontString par morceau (+ textures pour souligné, barré, surligné).
--
--  Balises (saisies par la barre d'outils du builder) :
--    [[#rrggbb]]…[[/]]          couleur
--    [[b]]…[[/b]]  [[i]]…[[/i]]  [[u]]…[[/u]]  [[s]]…[[/s]]
--    [[fond #rrggbb]]…[[/fond]] surlignage
--    [[taille 14]]…[[/taille]]  taille (8 à 32)
--    [[police cinzel]]…[[/police]]
--    [[centre]] / [[droite]] / [[gauche]] : alignement du paragraphe
--    {{Catégorie : Nom}}        référence survolable
--    {{rouge}}…{{/}}            ancienne couleur nommée
-- ============================================================
local C = Character
local RT = {}
C.RichText = RT

local NOTO = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\Fonts\\NotoSans-"
local ZG = "Interface\\AddOns\\Omega_Hub\\Modules\\ZoneGate\\Fonts\\"
-- Seule Noto Sans a de vraies variantes : ailleurs, le gras est simulé
-- (texte doublé décalé d'un pixel) et l'italique n'existe pas.
RT.FONTS = {
    { key = "noto", label = "Noto Sans", regular = NOTO .. "Regular.ttf", bold = NOTO .. "Bold.ttf",
      italic = NOTO .. "Italic.ttf", boldItalic = NOTO .. "BoldItalic.ttf" },
    { key = "friz", label = "Friz Quadrata", regular = "Fonts\\FRIZQT__.TTF" },
    { key = "arial", label = "Arial Narrow", regular = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", label = "Morpheus", regular = "Fonts\\MORPHEUS.TTF" },
    { key = "skurri", label = "Skurri", regular = "Fonts\\SKURRI.TTF" },
    { key = "cinzel", label = "Cinzel", regular = ZG .. "Cinzel-Regular.ttf" },
    { key = "almendra", label = "Almendra", regular = ZG .. "Almendra-Regular.ttf" },
    { key = "medievalsharp", label = "MedievalSharp", regular = ZG .. "MedievalSharp-Regular.ttf" },
    { key = "philosopher", label = "Philosopher", regular = ZG .. "Philosopher-Regular.ttf" },
    { key = "marcellus", label = "Marcellus", regular = ZG .. "Marcellus-Regular.ttf" },
    { key = "caudex", label = "Caudex", regular = ZG .. "Caudex-Regular.ttf" },
    { key = "pirataone", label = "Pirata One", regular = ZG .. "PirataOne-Regular.ttf" },
}
local FONT_BY_KEY = {}
for _, font in ipairs(RT.FONTS) do FONT_BY_KEY[font.key] = font end
RT.DEFAULT_FONT, RT.DEFAULT_SIZE, RT.MIN_SIZE, RT.MAX_SIZE = "noto", 12, 8, 32
RT.LINK_COLOR = { .56, .84, 1 }
local WHITE = { 1, 1, 1 }

function RT.GetFont(key) return FONT_BY_KEY[key] end

local function HexColor(hex)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255 }
end

-- ── Analyse ────────────────────────────────────────────────────────────────
-- opts.resolveRef(tag, name) -> catKey, skill ; opts.namedColors = {rouge="ffe23c3c"}
-- Résultat : { { align = "LEFT", runs = { { text, style }, … } }, … }
local function NewState()
    return { color = {}, bg = {}, size = {}, font = {}, b = 0, i = 0, u = 0, s = 0 }
end

local function Snapshot(state, link, linkColor)
    local top = function(stack) return stack[#stack] end
    return {
        color = top(state.color) or linkColor, bg = top(state.bg),
        size = top(state.size), font = top(state.font),
        bold = state.b > 0, italic = state.i > 0, underline = state.u > 0, strike = state.s > 0,
        link = link,
    }
end

local TOGGLES = { b = "b", i = "i", u = "u", s = "s" }

-- Applique une balise [[…]] ; renvoie false si elle n'est pas reconnue.
local function ApplyTag(state, tag, paragraph)
    local lower = tag:lower():match("^%s*(.-)%s*$")
    local hex = lower:match("^#(%x%x%x%x%x%x)$")
    if hex then state.color[#state.color + 1] = HexColor(hex); return true end
    if lower == "/" then table.remove(state.color); return true end
    if TOGGLES[lower] then state[lower] = state[lower] + 1; return true end
    local closing = lower:match("^/(%a)$")
    if closing and TOGGLES[closing] then state[closing] = math.max(0, state[closing] - 1); return true end
    hex = lower:match("^fond%s*#(%x%x%x%x%x%x)$")
    if hex then state.bg[#state.bg + 1] = HexColor(hex); return true end
    if lower == "/fond" then table.remove(state.bg); return true end
    local size = tonumber(lower:match("^taille%s+(%d+)$") or "")
    if size then
        state.size[#state.size + 1] = math.max(RT.MIN_SIZE, math.min(RT.MAX_SIZE, size)); return true
    end
    if lower == "/taille" then table.remove(state.size); return true end
    local fontKey = lower:match("^police%s+(%w+)$")
    if fontKey and FONT_BY_KEY[fontKey] then state.font[#state.font + 1] = fontKey; return true end
    if lower == "/police" then table.remove(state.font); return true end
    if lower == "centre" or lower == "droite" or lower == "gauche" then
        if paragraph then paragraph.align = ({ centre = "CENTER", droite = "RIGHT", gauche = "LEFT" })[lower] end
        return true
    end
    return false
end

local ParseInto

-- Le nom d'une référence garde ses propres balises : seules les parties
-- entre balises de couleur sont colorées. Les crochets prennent la couleur
-- du nom (sa première) ; sans couleur du tout, tout le lien est bleu.
local function EmitReference(state, paragraph, emit, catKey, displayName, skill, opts)
    local link = { catKey = catKey, name = displayName }
    local source = skill and skill.name or displayName
    local firstHex = source:match("%[%[%s*#(%x%x%x%x%x%x)%s*%]%]")
    local linkColor = not firstHex and RT.LINK_COLOR or nil
    local bracketColor = firstHex and HexColor(firstHex) or RT.LINK_COLOR
    local bracket = Snapshot(state, link)
    bracket.color = bracketColor
    emit(paragraph, "[", bracket)
    local inner = NewState()
    for key, value in pairs(state) do
        if type(value) == "table" then
            inner[key] = {}
            for i, v in ipairs(value) do inner[key][i] = v end
        else
            inner[key] = value
        end
    end
    ParseInto(source:gsub("\n", " "), inner, paragraph, emit, opts, link, linkColor)
    emit(paragraph, "]", bracket)
end

function ParseInto(text, state, paragraph, emit, opts, link, linkColor)
    local pos, len = 1, #text
    local buffer = {}
    local function flush()
        if #buffer > 0 then
            emit(paragraph, table.concat(buffer), Snapshot(state, link, linkColor))
            buffer = {}
        end
    end
    while pos <= len do
        local nextPos = text:find("[%[{\n]", pos)
        if not nextPos then buffer[#buffer + 1] = text:sub(pos); break end
        if nextPos > pos then buffer[#buffer + 1] = text:sub(pos, nextPos - 1) end
        pos = nextPos
        local ch = text:sub(pos, pos)
        local handled = false
        if ch == "\n" then
            flush()
            paragraph = opts.newParagraph()
            pos = pos + 1
            handled = true
        elseif text:sub(pos, pos + 1) == "[[" then
            local tag, stop = text:match("^%[%[([^%[%]\n]-)%]%]()", pos)
            if tag then
                flush()
                if ApplyTag(state, tag, not link and paragraph or nil) then
                    pos = stop
                    handled = true
                end
            end
        elseif text:sub(pos, pos + 1) == "{{" then
            local tag, name, stop = text:match("^{{%s*([^:{}\n]-)%s*:%s*([^{}\n]-)%s*}}()", pos)
            if tag and not link and opts.resolveRef then
                local catKey, skill = opts.resolveRef(tag, name)
                if catKey then
                    flush()
                    EmitReference(state, paragraph, emit, catKey, name, skill, opts)
                    pos = stop
                    handled = true
                end
            end
            if not handled then
                local colorName, stop2 = text:match("^{{%s*(%a+)%s*}}()", pos)
                local named = colorName and opts.namedColors and opts.namedColors[colorName:lower()]
                if named then
                    flush()
                    state.color[#state.color + 1] = HexColor(named:sub(3))
                    pos = stop2
                    handled = true
                elseif text:sub(pos, pos + 4) == "{{/}}" then
                    flush()
                    table.remove(state.color)
                    pos = pos + 5
                    handled = true
                end
            end
        end
        if not handled then
            buffer[#buffer + 1] = ch
            pos = pos + 1
        end
    end
    flush()
    return paragraph
end

function RT.Parse(text, opts)
    opts = opts or {}
    local paragraphs = {}
    local parseOpts = setmetatable({}, { __index = opts })
    function parseOpts.newParagraph()
        local paragraph = { align = "LEFT", runs = {} }
        paragraphs[#paragraphs + 1] = paragraph
        return paragraph
    end
    local function emit(paragraph, chunk, style)
        if chunk ~= "" then paragraph.runs[#paragraph.runs + 1] = { text = chunk, style = style } end
    end
    ParseInto(tostring(text or ""), NewState(), parseOpts.newParagraph(), emit, parseOpts)
    return paragraphs
end

-- Texte sans aucune balise de mise en forme (références laissées telles quelles).
function RT.Strip(text)
    text = tostring(text or "")
    return (text:gsub("%[%[([^%[%]\n]-)%]%]", function(tag)
        if ApplyTag(NewState(), tag, nil) then return "" end
    end))
end

-- ── Mise en page ───────────────────────────────────────────────────────────
local function FontFor(style)
    local font = FONT_BY_KEY[style.font or RT.DEFAULT_FONT] or FONT_BY_KEY[RT.DEFAULT_FONT]
    local path = font.regular
    if style.bold and style.italic and font.boldItalic then path = font.boldItalic
    elseif style.italic and font.italic then path = font.italic
    elseif style.bold and font.bold then path = font.bold end
    local fakeBold = style.bold and not font.bold
    return path, style.size or RT.DEFAULT_SIZE, fakeBold
end

local function SameStyle(a, b)
    return a.color == b.color and a.bg == b.bg and a.size == b.size and a.font == b.font
        and a.bold == b.bold and a.italic == b.italic and a.underline == b.underline
        and a.strike == b.strike and a.link == b.link
end

local function Pool(frame)
    local pool = frame.richText
    if not pool then
        pool = { strings = {}, textures = {}, usedStrings = 0, usedTextures = 0 }
        pool.measure = frame:CreateFontString(nil, "OVERLAY")
        pool.measure:Hide()
        pool.measure:SetWordWrap(false)
        frame.richText = pool
    end
    return pool
end

local function Measure(pool, text, style)
    local path, size, fakeBold = FontFor(style)
    local fs = pool.measure
    fs:SetFont(path, size, "")
    fs:SetText(text)
    local width = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
    return width + (fakeBold and 1 or 0)
end

local function SpaceWidth(pool, style)
    return Measure(pool, "a a", style) - Measure(pool, "aa", style)
end

-- Découpe un mot trop long pour la largeur (caractères UTF-8 entiers).
local function SplitLongWord(pool, word, style, width)
    local pieces, current = {}, ""
    for char in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if current ~= "" and Measure(pool, current .. char, style) > width then
            pieces[#pieces + 1] = current
            current = char
        else
            current = current .. char
        end
    end
    if current ~= "" then pieces[#pieces + 1] = current end
    return pieces
end

local function LineHeight(size) return math.floor(size * 1.4 + .5) end

-- Mots et espaces → lignes de morceaux { text, style, x, width }.
local function LayoutParagraph(pool, paragraph, width)
    local lines = {}
    local line
    local function newLine()
        line = { pieces = {}, width = 0, height = LineHeight(RT.DEFAULT_SIZE), align = paragraph.align }
        lines[#lines + 1] = line
    end
    newLine()
    local function place(word, style, spaced)
        local last = line.pieces[#line.pieces]
        local size = style.size or RT.DEFAULT_SIZE
        local sep = (spaced and #line.pieces > 0) and " " or ""
        local candidateWidth
        if last and SameStyle(last.style, style) then
            candidateWidth = last.x + Measure(pool, last.text .. sep .. word, style)
        else
            local gap = sep ~= "" and SpaceWidth(pool, style) or 0
            candidateWidth = line.width + gap + Measure(pool, word, style)
        end
        if candidateWidth > width and #line.pieces > 0 then
            newLine()
            return false
        end
        if last and SameStyle(last.style, style) then
            last.text = last.text .. sep .. word
            last.width = candidateWidth - last.x
        else
            local gap = sep ~= "" and SpaceWidth(pool, style) or 0
            local piece = { text = word, style = style, x = line.width + gap }
            piece.width = candidateWidth - piece.x
            line.pieces[#line.pieces + 1] = piece
        end
        line.width = candidateWidth
        line.height = math.max(line.height, LineHeight(size))
        return true
    end
    local pendingSpace = false
    for _, run in ipairs(paragraph.runs) do
        local pos, text = 1, run.text
        while pos <= #text do
            local spaceStart, spaceEnd = text:find("^%s+", pos)
            if spaceStart then
                pendingSpace = true
                pos = spaceEnd + 1
            else
                local word = text:match("^%S+", pos)
                pos = pos + #word
                if Measure(pool, word, run.style) > width then
                    for index, part in ipairs(SplitLongWord(pool, word, run.style, width)) do
                        local spaced = index == 1 and pendingSpace
                        if not place(part, run.style, spaced) then place(part, run.style, false) end
                    end
                elseif not place(word, run.style, pendingSpace) then
                    -- Nouvelle ligne : l'espace de coupure disparaît.
                    place(word, run.style, false)
                end
                pendingSpace = false
            end
        end
    end
    return lines
end

local function NextString(pool, frame)
    pool.usedStrings = pool.usedStrings + 1
    local fs = pool.strings[pool.usedStrings]
    if not fs then
        fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetWordWrap(false)
        fs:SetJustifyH("LEFT")
        pool.strings[pool.usedStrings] = fs
    end
    fs:ClearAllPoints()
    fs:Show()
    return fs
end

local function NextTexture(pool, frame, layer)
    pool.usedTextures = pool.usedTextures + 1
    local tex = pool.textures[pool.usedTextures]
    if not tex then
        tex = frame:CreateTexture(nil, "ARTWORK")
        pool.textures[pool.usedTextures] = tex
    end
    tex:SetDrawLayer(layer)
    tex:ClearAllPoints()
    tex:Show()
    return tex
end

function RT.Clear(frame)
    local pool = frame.richText
    if not pool then return end
    for i = 1, #pool.strings do pool.strings[i]:Hide() end
    for i = 1, #pool.textures do pool.textures[i]:Hide() end
    pool.usedStrings, pool.usedTextures = 0, 0
end

-- Mesure sans rien afficher : largeur de la plus longue ligne, hauteur.
function RT.Measure(frame, text, width, opts)
    local pool = Pool(frame)
    local maxWidth, height = 0, 0
    for _, paragraph in ipairs(RT.Parse(text, opts)) do
        for _, line in ipairs(LayoutParagraph(pool, paragraph, width)) do
            maxWidth = math.max(maxWidth, line.width)
            height = height + line.height
        end
    end
    return maxWidth, height
end

-- Pose le texte dans frame à partir de (x, y) sous son coin haut gauche.
-- Renvoie la largeur de la plus longue ligne et la hauteur totale.
function RT.Render(frame, text, width, opts, x, y)
    opts = opts or {}
    x, y = x or 0, y or 0
    RT.Clear(frame)
    local pool = Pool(frame)
    local defaultColor = opts.color or WHITE
    local maxWidth, top = 0, 0
    for _, paragraph in ipairs(RT.Parse(text, opts)) do
        for _, line in ipairs(LayoutParagraph(pool, paragraph, width)) do
            local offset = 0
            if line.align == "CENTER" then offset = math.floor((width - line.width) / 2)
            elseif line.align == "RIGHT" then offset = math.floor(width - line.width) end
            local baseline = top + line.height
            for _, piece in ipairs(line.pieces) do
                local style = piece.style
                local path, size, fakeBold = FontFor(style)
                local color = style.color or defaultColor
                -- py = bas de la FontString ; sa ligne de base est ~0,25 × taille
                -- plus haut, alignée sur le bas de la ligne pour toutes les tailles.
                local px, py = x + offset + piece.x, -(y + baseline - math.floor(size * .25))
                local function draw(dx)
                    local fs = NextString(pool, frame)
                    fs:SetFont(path, size, "")
                    fs:SetText(style.link and ("|Hcharskill:" .. style.link.catKey .. ":" .. style.link.name .. "|h" .. piece.text .. "|h") or piece.text)
                    fs:SetTextColor(color[1], color[2], color[3], 1)
                    fs:SetShadowColor(0, 0, 0, .8)
                    fs:SetShadowOffset(1, -1)
                    fs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", px + dx, py)
                    return fs
                end
                local fs = draw(0)
                if fakeBold then draw(1) end
                if style.bg then
                    local bg = NextTexture(pool, frame, "BACKGROUND")
                    bg:SetColorTexture(style.bg[1], style.bg[2], style.bg[3], .55)
                    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", px - 1, -(y + top + 1))
                    bg:SetSize(piece.width + 2, line.height)
                end
                local thickness = math.max(1, math.floor(size / 12 + .5))
                if style.underline then
                    local rule = NextTexture(pool, frame, "OVERLAY")
                    rule:SetColorTexture(color[1], color[2], color[3], 1)
                    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", px, py + math.floor(size * .14 + .5))
                    rule:SetSize(piece.width, thickness)
                end
                if style.strike then
                    local rule = NextTexture(pool, frame, "OVERLAY")
                    rule:SetColorTexture(color[1], color[2], color[3], 1)
                    rule:SetPoint("TOPLEFT", frame, "TOPLEFT", px, py + math.floor(size * .58 + .5))
                    rule:SetSize(piece.width, thickness)
                end
                piece.fontString = fs
            end
            maxWidth = math.max(maxWidth, line.width)
            top = baseline
        end
    end
    return maxWidth, top
end
