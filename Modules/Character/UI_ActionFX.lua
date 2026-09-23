-- ============================================================
--  Character - Bouton Action : habillage « nexus » animé
--  Repos : logo d'Eindhill, cubes orbitaux et fragments de données
--  autour d'un cercle doré en rotation, avec un halo qui respire.
--  Ouverture : le logo devient un cube de données qui tourne, le cube
--  éclate en fragments vers le triangle, où apparaissent des cercles de
--  données (anneau segmenté qui tourne, petite icône au centre). La
--  fermeture rejoue la même séquence à l'envers.
--  Catégorie ouverte : un flux de données défile vers la droite et les
--  compétences y ondulent en vaguelette.
--  UI_Action.lua garde la logique (clics, états, positions) ; ce fichier
--  ne fait que l'habiller, via C.ActionFrames et C.ActionFX.
-- ============================================================
local C = Character
local F = C.ActionFrames
if not F then return end

local MEDIA = "Interface\\AddOns\\Omega_Hub\\Modules\\Character\\Media\\"
local NEXUS = MEDIA .. "Nexus\\"

-- Toutes les images et réglages de l'habillage. Les images de Media/Nexus/
-- sont PROVISOIRES (Tests/nexus-art.py) : les remplacer par les définitives
-- en gardant noms, tailles et découpage suffit, sans toucher au code.
local THEME = {
    logo = MEDIA .. "EindhillLogo",       -- 256², logo (marge pour le masque rond)
    pixels = NEXUS .. "NexusPixels",      -- 128², fond de pixels derrière le logo
    ring = NEXUS .. "NexusRing",          -- 256², anneau d'or ; asymétrique pour qu'on le voie tourner
    glow = NEXUS .. "NexusGlow",          -- 128², halo, affiché en mode additif
    cube = { file = NEXUS .. "DataCube", cols = 4, rows = 4, frames = 16, fps = 20 }, -- 512², planche 4x4 de 128²
    shard = NEXUS .. "DataShard",         -- 64², éclat du cube
    dataFrame = NEXUS .. "DataFrame",     -- 128², cadre fixe d'un cercle de données
    dataRing = NEXUS .. "DataRing",       -- 128², anneau segmenté qui tourne
    stream = NEXUS .. "DataStream",       -- 256x64, flux ; doit se répéter en largeur sans raccord
    -- Petites icônes des cercles de données ; nil = icône actuelle du jeu.
    categoryIcons = { base = NEXUS .. "IconActions", offensive = NEXUS .. "IconOffensive", defensive = NEXUS .. "IconDefensive", ranged = NEXUS .. "IconDistance" },
    ringPeriod = 14,                      -- secondes par tour, anneau du nexus
    dataRingPeriod = 9,                   -- secondes par tour, cercles de données
    glowPulse = 1.8,                      -- secondes par respiration du halo
    streamSpeed = .12,                    -- largeurs de texture par seconde
    wave = { amplitude = 2.5, period = 2.2, phase = .75 }, -- vaguelette : px, s, décalage par icône
}
C.ACTION_THEME = THEME

-- OPEN_TIME : durée de l'ouverture (et de la fermeture). BURST : part de
-- cette durée réservée à logo -> cube -> éclatement, avant le triangle.
local FX = { OPEN_TIME = .8, BURST = .45 }
C.ActionFX = FX

local BTN = F.BTN
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local animations = {}

local function Spin(texture, period, clockwise)
    local group = texture:CreateAnimationGroup()
    local rotation = group:CreateAnimation("Rotation")
    rotation:SetDegrees(clockwise and -360 or 360)
    rotation:SetDuration(period)
    group:SetLooping("REPEAT")
    group:Play()
    animations[#animations + 1] = group
end

local function Pulse(texture, from, to, period)
    local group = texture:CreateAnimationGroup()
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(from)
    alpha:SetToAlpha(to)
    alpha:SetDuration(period / 2)
    group:SetLooping("BOUNCE")
    group:Play()
    animations[#animations + 1] = group
end

local function Centered(texture, anchor, size)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER", anchor, "CENTER", 0, 0)
end

-- Cœur du nexus : disque sombre, pixels, logo et anneau d'or. Construit sur
-- le bouton de repos, puis recopié dans le calque d'ouverture pour que la
-- transformation parte exactement de la même image.
local function BuildCore(parent, mask)
    local pixels = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
    pixels:SetAllPoints(); pixels:SetTexture(THEME.pixels); pixels:AddMaskTexture(mask)
    local ring = parent:CreateTexture(nil, "OVERLAY", nil, 2)
    Centered(ring, parent, BTN * 1.35); ring:SetTexture(THEME.ring)
    -- Le cercle accompagne le flux, sans entraîner le logo central.
    ring:SetAlpha(.9)
    local orbit=CreateFrame("Frame",nil,parent)
    orbit:SetAllPoints();orbit:EnableMouse(false)
    local fragments={}
    for i=1,24 do
        local fragment=orbit:CreateTexture(nil,"ARTWORK")
        fragment:SetColorTexture(.92,.74,.39,1)
        fragment:SetBlendMode("ADD")
        fragments[i]=fragment
    end
    local cubes={}
    for i=1,7 do
        local cube=orbit:CreateTexture(nil,"OVERLAY")
        cube:SetTexture(THEME.cube.file)
        local size=7+(i*7%9)
        cube:SetSize(size,size)
        cubes[i]={texture=cube,size=size,phase=i*2.39996,
            speed=(.36+(i*13%19)/32)*(i%2==0 and -1 or 1),
            radius=BTN*(.70+(i*3%7)*.018),spin=7+i*1.37}
    end
    local time,accumulator=0,0
    orbit:SetScript("OnUpdate",function(_,dt)
        time=time+dt;accumulator=accumulator+dt
        if accumulator<1/30 then return end
        accumulator=0
        ring:SetRotation(-time*2*math.pi/THEME.ringPeriod)
        ring:SetAlpha(.82+.12*math.sin(time*2*math.pi/3.6))
        for i,fragment in ipairs(fragments) do
            local lane=i%3
            local angle=i*2.39996+time*(.72+lane*.22)
            local pulse=(1+math.sin(time*2.3-i*.8))/2
            local radius=BTN*(.65+lane*.025)+.8*math.sin(time*1.4+i)
            fragment:ClearAllPoints()
            fragment:SetPoint("CENTER",parent,"CENTER",math.cos(angle)*radius,math.sin(angle)*radius)
            fragment:SetSize(1.2+pulse*2.5,1+lane*.35)
            fragment:SetRotation(angle+math.pi/2)
            fragment:SetAlpha(.12+pulse*.78)
        end
        for i,entry in ipairs(cubes) do
            local angle=entry.phase+time*entry.speed+.19*math.sin(time*.67+i)
            local radius=entry.radius+BTN*.035*math.sin(time*.83+i*1.7)
            local x=math.cos(angle)*radius
            local y=math.sin(angle)*radius*(.80+.08*math.sin(i))
            local depth=(math.sin(angle)+1)/2
            local size=entry.size*(.8+.2*depth)
            entry.texture:SetSize(size,size)
            entry.texture:ClearAllPoints()
            entry.texture:SetPoint("CENTER",parent,"CENTER",x,y)
            entry.texture:SetAlpha(.50+.45*depth)
            local frame=math.floor(time*entry.spin+i*3)%THEME.cube.frames
            local col,row=frame%THEME.cube.cols,math.floor(frame/THEME.cube.cols)
            entry.texture:SetTexCoord(col/THEME.cube.cols,(col+1)/THEME.cube.cols,row/THEME.cube.rows,(row+1)/THEME.cube.rows)
        end
    end)
    return pixels, ring
end

-- ── Repos : le nexus ───────────────────────────────────────────────────────
local idle = F.idle
idle.ring:Hide()
idle.tex:SetTexture(THEME.logo)
BuildCore(idle, idle.mask)
local idleGlow = idle:CreateTexture(nil, "BACKGROUND", nil, -8)
Centered(idleGlow, idle, BTN * 1.9); idleGlow:SetTexture(THEME.glow); idleGlow:SetBlendMode("ADD")
Pulse(idleGlow, .25, .7, THEME.glowPulse)

-- ── Ouverture : logo -> cube de données -> éclatement ──────────────────────
local morph = CreateFrame("Frame", nil, F.root)
morph:SetSize(BTN * 3, BTN * 3)
morph:SetPoint("CENTER", F.root, "TOPLEFT", F.RESET_X, F.RESET_Y)
morph:SetFrameLevel(F.root:GetFrameLevel() + 30)
morph:EnableMouse(false)
morph:Hide()

local core = CreateFrame("Frame", nil, morph)
core:SetSize(BTN, BTN); core:SetPoint("CENTER")
local coreMask = core:CreateMaskTexture()
coreMask:SetAllPoints(); coreMask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
local coreDisc = core:CreateTexture(nil, "BACKGROUND")
coreDisc:SetAllPoints(); coreDisc:SetColorTexture(.018, .026, .039, 1); coreDisc:AddMaskTexture(coreMask)
local coreLogo = core:CreateTexture(nil, "ARTWORK")
coreLogo:SetPoint("TOPLEFT", 2, -2); coreLogo:SetPoint("BOTTOMRIGHT", -2, 2)
coreLogo:SetTexture(THEME.logo); coreLogo:SetTexCoord(.08, .92, .08, .92); coreLogo:AddMaskTexture(coreMask)
BuildCore(core, coreMask)

local cube = morph:CreateTexture(nil, "ARTWORK")
cube:SetPoint("CENTER"); cube:SetTexture(THEME.cube.file)
local flash = morph:CreateTexture(nil, "OVERLAY")
Centered(flash, morph, BTN * 2.6); flash:SetTexture(THEME.glow); flash:SetBlendMode("ADD")

local shards = {}
local spinOffset = 0
for key in pairs(F.cats) do
    local shard = morph:CreateTexture(nil, "OVERLAY", nil, 1)
    shard:SetSize(16, 16); shard:SetTexture(THEME.shard)
    shard.spin = spinOffset; spinOffset = spinOffset + 1.7
    shard:Hide()
    shards[key] = shard
end

local function CubeFrame(t)
    local sheet = THEME.cube
    local index = math.floor(t * FX.OPEN_TIME * sheet.fps) % sheet.frames
    local col, row = index % sheet.cols, math.floor(index / sheet.cols)
    cube:SetTexCoord(col / sheet.cols, (col + 1) / sheet.cols, row / sheet.rows, (row + 1) / sheet.rows)
end

-- t : 0 -> 1 sur toute l'ouverture (1 -> 0 à la fermeture).
function FX.DrawOpen(t)
    if t <= 0 or t >= 1 then morph:Hide(); return end
    morph:Show()
    local burst = FX.BURST
    local m = math.min(1, t / burst)                          -- logo -> cube
    local k = t > burst and (t - burst) / (1 - burst) or 0     -- éclatement
    core:SetAlpha(1 - m)
    core:SetScale(math.max(.05, 1 - .5 * m))
    local size = BTN * (.7 + .6 * m + .5 * k)
    cube:SetSize(size, size)
    cube:SetAlpha(math.min(1, m * 2) * (1 - math.min(1, k * 4)))
    CubeFrame(t)
    flash:SetAlpha(math.max(0, 1 - math.abs(t - burst) / .1) * .9)
    for key, shard in pairs(shards) do
        local offset = F.OFFSETS[key]
        if k > 0 and k < 1 then
            local ease = 1 - (1 - k) ^ 2
            shard:ClearAllPoints()
            shard:SetPoint("CENTER", morph, "CENTER", offset[1] * ease, offset[2] * ease)
            shard:SetAlpha(1 - k)
            shard:SetRotation(k * math.pi * 3 + shard.spin)
            shard:Show()
        else
            shard:Hide()
        end
    end
end

function FX.Reset()
    morph:Hide()
end

-- ── Cercles de données : les quatre catégories ─────────────────────────────
local clockwise = true
for key, b in pairs(F.cats) do
    b.ring:Hide()
    b.bg:SetColorTexture(.028, .039, .055, 1) -- fond bleu-gris sombre
    local dataRing = b:CreateTexture(nil, "ARTWORK", nil, 6)
    Centered(dataRing, b, BTN * 1.3); dataRing:SetTexture(THEME.dataRing)
    Spin(dataRing, THEME.dataRingPeriod, clockwise)
    clockwise = not clockwise
    local frame = b:CreateTexture(nil, "ARTWORK", nil, 7)
    Centered(frame, b, BTN * 1.3); frame:SetTexture(THEME.dataFrame)
    -- Petite icône au centre du cercle.
    b.tex:ClearAllPoints()
    b.tex:SetPoint("TOPLEFT", 8, -8); b.tex:SetPoint("BOTTOMRIGHT", -8, 8)
    if THEME.categoryIcons[key] then b.tex:SetTexture(THEME.categoryIcons[key]) end
    if b.label then
        b.label:ClearAllPoints()
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -8)
    end
end

-- ── Flux de données et vaguelettes ─────────────────────────────────────────
local strip = F.strip
local stream = strip:CreateTexture(nil, "BACKGROUND", nil, 2)
stream:SetAllPoints()
stream:SetTexture(THEME.stream, "REPEAT", "CLAMP")
local flowMask=strip:CreateMaskTexture()
flowMask:SetAllPoints()
flowMask:SetTexture(NEXUS.."StreamMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
stream:AddMaskTexture(flowMask)
stream:SetBlendMode("ADD")
local wake=strip:CreateTexture(nil,"BACKGROUND",nil,1)
wake:SetAllPoints();wake:SetTexture(NEXUS.."StreamWake")
wake:SetBlendMode("ADD")
-- Dense packets follow a broad current which narrows toward its tip.
-- They remain behind the skill buttons, leaving the icon faces unobscured.
local packets={}
for i=1,64 do
    local packet=strip:CreateTexture(nil,"BACKGROUND",nil,3)
    packet:SetColorTexture(.94,.76,.42,1)
    packet:SetBlendMode("ADD")
    packets[i]=packet
end
-- Upward data sparks sit behind the icons, outside the clipped strip.
local risers={}
for i=1,18 do
    local spark=F.root:CreateTexture(nil,"ARTWORK")
    spark:SetColorTexture(.85,.72,.45,1);spark:SetBlendMode("ADD");spark:Hide()
    risers[i]=spark
end
strip:HookScript("OnHide",function() for _,spark in ipairs(risers) do spark:Hide() end end)
local streamOffset, clock = 0, 0
strip:SetScript("OnUpdate", function(self, elapsed)
    clock = clock + elapsed
    -- Le motif avance vers la droite : on recule dans la texture.
    streamOffset = (streamOffset - elapsed * THEME.streamSpeed) % 1
    stream:SetTexCoord(streamOffset, streamOffset + (self:GetWidth() or 0) / 256, 0, 1)
    local width=self:GetWidth() or 0
    local count=math.min(64,math.max(18,math.floor(width/4)))
    for i,packet in ipairs(packets) do
        if i<=count then
            local phase=(clock*(.19+(i%5)*.027)+i*.618034)%1
            local lane=math.sin(i*12.9898)
            local spread=23*(1-phase)^.65
            local y=lane*spread+math.sin(clock*2+i+phase*7)*2*(1-phase)
            packet:ClearAllPoints()
            packet:SetPoint("CENTER",strip,"TOPLEFT",phase*math.max(0,width-3),-28+y)
            packet:SetSize((i%4==0 and 7 or 2)+(1-phase)*2,1+(i%3)*.5)
            packet:SetAlpha(math.min(1,phase*12,(1-phase)*7)*(.55+(i%4)*.14))
            packet:Show()
        else packet:Hide() end
    end
    for i,spark in ipairs(risers) do
        local slot=math.floor((i-1)/3)+1
        local b=F.skillButtons[slot]
        if b and b:IsShown() and b.baseX then
            local phase=(clock*.62+(i%3)*.33+slot*.17)%1
            local drift=math.sin(phase*4+slot)*3
            spark:SetSize(1+(1-phase)*.4,1.5+(1-phase)*1.5)
            spark:ClearAllPoints()
            spark:SetPoint("CENTER",strip,"TOPLEFT",16+b.baseX+F.ICON/2+(i%3-1)*8+drift,-12+phase*34)
            spark:SetAlpha(math.sin(phase*math.pi)*.72*strip:GetAlpha())
            spark:Show()
        else spark:Hide() end
    end
    local wave = THEME.wave
    for i, b in ipairs(F.skillButtons) do
        if b.baseX and b:IsShown() then
            -- Ouverte : la vague s'amortit et l'icône se fige au centre du flux ;
            -- refermée, elle reprend doucement.
            local target = F.IsPinned and F.IsPinned(b) and 0 or 1
            local weight = b.waveWeight or 1
            local step = elapsed * 5
            weight = weight < target and math.min(target, weight + step) or math.max(target, weight - step)
            b.waveWeight = weight
            local y = math.sin(clock * 2 * math.pi / wave.period + i * wave.phase) * wave.amplitude * weight
            b:SetPoint("TOPLEFT", b.baseX, b.baseY + y)
        end
    end
end)

-- Les animations en boucle reprennent quand la fenêtre réapparaît.
F.root:HookScript("OnShow", function()
    for _, group in ipairs(animations) do group:Play() end
end)
