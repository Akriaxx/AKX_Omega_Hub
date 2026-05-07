local OmegaDice = _G.OmegaDice

-- ─── Geometry ────────────────────────────────────────────────────────────────
local PHI  = (1 + math.sqrt(5)) / 2
local NORM = math.sqrt(1 + PHI * PHI)

local VERTS = {
    {     0,  1/NORM,  PHI/NORM }, {     0, -1/NORM,  PHI/NORM },
    {     0,  1/NORM, -PHI/NORM }, {     0, -1/NORM, -PHI/NORM },
    { 1/NORM,  PHI/NORM,      0 }, {-1/NORM,  PHI/NORM,      0 },
    { 1/NORM, -PHI/NORM,      0 }, {-1/NORM, -PHI/NORM,      0 },
    { PHI/NORM,      0,  1/NORM }, {-PHI/NORM,      0,  1/NORM },
    { PHI/NORM,      0, -1/NORM }, {-PHI/NORM,      0, -1/NORM },
}

local EDGES = {
    {1,2},{1,5},{1,6},{1,9},{1,10},{2,7},{2,8},{2,9},{2,10},{3,4},
    {3,5},{3,6},{3,11},{3,12},{4,7},{4,8},{4,11},{4,12},{5,6},{5,9},
    {5,11},{6,10},{6,12},{7,8},{7,9},{7,11},{8,10},{8,12},{9,11},{10,12},
}

local FACES = {
    {1,2,9},  {1,2,10}, {1,5,6},  {1,5,9},  {1,6,10},
    {2,7,8},  {2,7,9},  {2,8,10}, {3,4,11}, {3,4,12},
    {3,5,6},  {3,5,11}, {3,6,12}, {4,7,8},  {4,7,11},
    {4,8,12}, {5,9,11}, {6,10,12},{7,9,11},  {8,10,12},
}

local FACE_NORMALS = {}
for i, face in ipairs(FACES) do
    local va, vb, vc = VERTS[face[1]], VERTS[face[2]], VERTS[face[3]]
    local nx = (vb[2]-va[2])*(vc[3]-va[3]) - (vb[3]-va[3])*(vc[2]-va[2])
    local ny = (vb[3]-va[3])*(vc[1]-va[1]) - (vb[1]-va[1])*(vc[3]-va[3])
    local nz = (vb[1]-va[1])*(vc[2]-va[2]) - (vb[2]-va[2])*(vc[1]-va[1])
    local len = math.sqrt(nx*nx + ny*ny + nz*nz)
    nx, ny, nz = nx/len, ny/len, nz/len
    local cf = {(va[1]+vb[1]+vc[1])/3, (va[2]+vb[2]+vc[2])/3, (va[3]+vb[3]+vc[3])/3}
    if nx*cf[1] + ny*cf[2] + nz*cf[3] < 0 then nx, ny, nz = -nx, -ny, -nz end
    FACE_NORMALS[i] = {nx, ny, nz}
end

-- ─── Layout ──────────────────────────────────────────────────────────────────
local MAX_ICO = 6

local DIE_CFG = {
    [1] = { die=210, scale=72, gap=0,  edge=2.1, lbl=18, res=58 },
    [2] = { die=168, scale=58, gap=12, edge=1.8, lbl=15, res=46 },
    [3] = { die=140, scale=48, gap=10, edge=1.5, lbl=13, res=38 },
    [4] = { die=116, scale=40, gap=8,  edge=1.3, lbl=11, res=32 },
    [5] = { die=100, scale=34, gap=7,  edge=1.1, lbl=10, res=27 },
    [6] = { die=88,  scale=30, gap=6,  edge=1.0, lbl=9,  res=24 },
}
local FRAME_H       = 230
local ANIM_DURATION = 2.4
local HOLD_DURATION = 3.0
local FOV           = 3.5
local LINE_EXT      = 1.1

local SEQ_SHOW_MOD = 0.7
local SEQ_FADE_DUR = 0.28
local SEQ_HOLD_MOD = 0.9

-- ─── Math Utils ──────────────────────────────────────────────────────────────
local function RotFast(vx, vy, vz, cx, sx, cy, sy)
    local y2 = vy*cx - vz*sx
    local z2 = vy*sx + vz*cx
    return vx*cy + z2*sy, y2, -vx*sy + z2*cy
end

local function Project(x, y, z, scale)
    local w = FOV / (FOV + z)
    return x*w*scale, y*w*scale
end

local function FaceToCamera(n)
    local rx = math.atan2(n[2], n[3])
    local z1 = math.sqrt(n[2]*n[2] + n[3]*n[3])
    local ry = math.atan2(n[1], -z1)
    return rx, ry
end

local function EaseOut(t) return 1 - (1-t)^3 end

local function FadeAlpha(obj, from, to, duration, onDone)
    obj:SetAlpha(from)
    local t0 = GetTime()
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(self)
        local p = math.min((GetTime() - t0) / duration, 1)
        obj:SetAlpha(from + (to - from) * p)
        if p >= 1 then
            self:SetScript("OnUpdate", nil)
            if onDone then onDone() end
        end
    end)
end

local function RollColor(rv, minVal, maxVal)
    if rv == maxVal then return 0.3, 1, 0.45
    elseif rv == minVal then return 1, 0.25, 0.25
    else return 1, 0.88, 0.35 end
end

-- ─── Glow helpers ─────────────────────────────────────────────────────────────
-- Each glow = 4 gradient textures with ADD blend mode anchored to a FontString.
-- They follow the FontString automatically when it moves.
-- Layout: [1]=left half, [2]=right half, [3]=bottom half, [4]=top half.
local GLOW_ALPHA = 0.65  -- peak alpha of the additive glow

local function CreateGlow(parent)
    local g = {}
    for i = 1, 4 do
        g[i] = parent:CreateTexture(nil, "ARTWORK")
        g[i]:SetBlendMode("ADD")
        g[i]:Hide()
    end
    return g
end

-- Attach glow to fontstring `fs`, sized gw×gh around its center.
local function GlowAttach(g, fs, gw, gh)
    local hw, hh = gw / 2, gh / 2
    -- Left half: TOPRIGHT at fs center → extends left; gradient transparent→color
    g[1]:ClearAllPoints()
    g[1]:SetPoint("TOPRIGHT", fs, "CENTER", 0, hh)
    g[1]:SetSize(hw, gh)
    -- Right half: TOPLEFT at fs center → extends right; gradient color→transparent
    g[2]:ClearAllPoints()
    g[2]:SetPoint("TOPLEFT", fs, "CENTER", 0, hh)
    g[2]:SetSize(hw, gh)
    -- Bottom half: TOPRIGHT at fs center-right → extends down; gradient top-color→bottom-transparent
    g[3]:ClearAllPoints()
    g[3]:SetPoint("TOPRIGHT", fs, "CENTER", hw, 0)
    g[3]:SetSize(gw, hh)
    -- Top half: BOTTOMRIGHT at fs center-right → extends up; gradient bottom-color→top-transparent
    g[4]:ClearAllPoints()
    g[4]:SetPoint("BOTTOMRIGHT", fs, "CENTER", hw, 0)
    g[4]:SetSize(gw, hh)
end

local function GlowColor(g, r, gv, b)
    local a = GLOW_ALPHA
    g[1]:SetGradientAlpha("HORIZONTAL", 0, 0, 0, 0,    r, gv, b, a)
    g[2]:SetGradientAlpha("HORIZONTAL", r, gv, b, a,   0, 0, 0, 0)
    g[3]:SetGradientAlpha("VERTICAL",   0, 0, 0, 0,    r, gv, b, a * 0.65)
    g[4]:SetGradientAlpha("VERTICAL",   r, gv, b, a * 0.65, 0, 0, 0, 0)
end

local function GlowShow(g)          for _, t in ipairs(g) do t:Show()        end end
local function GlowHide(g)          for _, t in ipairs(g) do t:Hide()        end end
local function GlowSetAlpha(g, a)   for _, t in ipairs(g) do t:SetAlpha(a)   end end

local function FadeGlow(g, from, to, duration, onDone)
    GlowSetAlpha(g, from)
    local t0 = GetTime()
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(self)
        local p = math.min((GetTime() - t0) / duration, 1)
        GlowSetAlpha(g, from + (to - from) * p)
        if p >= 1 then
            self:SetScript("OnUpdate", nil)
            if onDone then onDone() end
        end
    end)
end

-- ─── Single shared frame ──────────────────────────────────────────────────────
local icoFrame = nil

local function CreateIcoFrame()
    local bdTpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "OmegaDiceIcoFrame", UIParent, bdTpl)
    f:SetFrameStrata("DIALOG")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 110)

    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left=4, right=4, top=4, bottom=4 },
        })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(0.8, 0.68, 0.35, 1)
    end
    f:Hide()

    f.topLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.topLabel:SetPoint("TOP", f, "TOP", 0, -14)

    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)

    f.sumDisplay = f:CreateFontString(nil, "OVERLAY")
    f.sumDisplay:SetFont(STANDARD_TEXT_FONT, 58, "OUTLINE")
    f.sumDisplay:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.sumDisplay:Hide()
    f.sumGlow = CreateGlow(f)

    f.modDisplay = f:CreateFontString(nil, "OVERLAY")
    f.modDisplay:SetFont(STANDARD_TEXT_FONT, 38, "OUTLINE")
    f.modDisplay:SetTextColor(0.65, 0.75, 1, 1)
    f.modDisplay:Hide()

    f.dice = {}
    for di = 1, MAX_ICO do
        local slot = {}

        slot.lines = {}
        for i = 1, #EDGES do
            local ln = f:CreateLine(nil, "ARTWORK")
            ln:SetColorTexture(0.8, 0.68, 0.35, 1)
            slot.lines[i] = ln
        end

        slot.labels = {}
        for i = 1, #FACES do
            local fs = f:CreateFontString(nil, "OVERLAY")
            fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
            fs:SetTextColor(1, 0.92, 0.55, 0.9)
            fs:SetText(tostring(i))
            fs:Hide()
            slot.labels[i] = fs
        end

        slot.result = f:CreateFontString(nil, "OVERLAY")
        slot.result:SetFont(STANDARD_TEXT_FONT, 56, "OUTLINE")
        slot.result:SetTextColor(1, 0.88, 0.35)
        slot.result:Hide()

        slot.glow = CreateGlow(f)

        f.dice[di] = slot
    end

    return f
end

local function GetIcoFrame()
    if not icoFrame then icoFrame = CreateIcoFrame() end
    return icoFrame
end

-- ─── Per-die render ───────────────────────────────────────────────────────────
local function DrawDie(frame, slot, xOff, rx, ry, cfg, isFinished)
    local cx, sx = math.cos(rx), math.sin(rx)
    local cy, sy = math.cos(ry), math.sin(ry)
    local scale  = cfg.scale

    local proj = {}
    for i, v in ipairs(VERTS) do
        local x, y, z = RotFast(v[1], v[2], v[3], cx, sx, cy, sy)
        local px, py  = Project(x, y, z, scale)
        proj[i] = { px = px + xOff, py = py, z = z }
    end

    for i, face in ipairs(FACES) do
        local fn = FACE_NORMALS[i]
        local _, _, rnz = RotFast(fn[1], fn[2], fn[3], cx, sx, cy, sy)
        local fs = slot.labels[i]

        if not isFinished and rnz < -0.55 then
            local a, b, c = proj[face[1]], proj[face[2]], proj[face[3]]
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", frame, "CENTER",
                (a.px + b.px + c.px) / 3,
                (a.py + b.py + c.py) / 3)
            local alpha = ((-rnz - 0.55) / 0.45)^2
            fs:SetAlpha(math.min(alpha, 1))
            fs:Show()
        else
            fs:Hide()
        end
    end

    for i, edge in ipairs(EDGES) do
        local a, b  = proj[edge[1]], proj[edge[2]]
        local ln    = slot.lines[i]
        local isVis = false

        for fIdx, fVerts in ipairs(FACES) do
            local fn = FACE_NORMALS[fIdx]
            local _, _, rnz = RotFast(fn[1], fn[2], fn[3], cx, sx, cy, sy)
            if rnz < -0.05 then
                local hasA, hasB = false, false
                for _, vIdx in ipairs(fVerts) do
                    if vIdx == edge[1] then hasA = true end
                    if vIdx == edge[2] then hasB = true end
                end
                if hasA and hasB then isVis = true; break end
            end
        end

        if isVis then
            local dx, dy = b.px - a.px, b.py - a.py
            local len    = math.sqrt(dx*dx + dy*dy)
            if len > 0 then
                local ux, uy = (dx/len)*LINE_EXT, (dy/len)*LINE_EXT
                local bright = 1 - ((a.z+b.z)*0.5 + 1) * 0.35
                ln:SetThickness(cfg.edge)
                ln:SetColorTexture(0.8*bright, 0.68*bright, 0.35*bright, 1)
                ln:SetStartPoint("CENTER", frame, a.px - ux, a.py - uy)
                ln:SetEndPoint("CENTER", frame, b.px + ux, b.py + uy)
                ln:Show()
            else
                ln:Hide()
            end
        else
            ln:Hide()
        end
    end
end

local function HideSlot(slot)
    for _, ln in ipairs(slot.lines)  do ln:Hide() end
    for _, fs in ipairs(slot.labels) do fs:Hide() end
    slot.result:Hide()
    GlowHide(slot.glow)
end

-- ─── Show a result fontstring with its glow ───────────────────────────────────
local function ShowResult(slot, frame, xOff, text, r, g, b, resFontSize)
    local res = slot.result
    res:ClearAllPoints()
    res:SetPoint("CENTER", frame, "CENTER", xOff, 0)
    res:SetFont(STANDARD_TEXT_FONT, resFontSize, "OUTLINE")
    res:SetTextColor(r, g, b)
    res:SetText(text)
    res:SetAlpha(1)
    res:Show()

    local gw = resFontSize * 3.2
    local gh = resFontSize * 2.1
    GlowAttach(slot.glow, res, gw, gh)
    GlowColor(slot.glow, r, g, b)
    GlowSetAlpha(slot.glow, 1)
    GlowShow(slot.glow)
end

-- ─── Modifier merge: sumFS shifts left, modifier fades in, both merge to total ─
local function PlayModifierMerge(frame, sumFS, sumGlow, modFS, modifier, total, cr, cg, cb, animId, onDone)
    local modFontSize = math.max(math.floor(sumFS:GetStringHeight() * 0.68), 22)

    C_Timer.After(SEQ_HOLD_MOD, function()
        if OmegaDice.icoAnimId ~= animId then return end

        local shift = modFontSize * 1.15
        sumFS:ClearAllPoints()
        sumFS:SetPoint("CENTER", frame, "CENTER", -shift, 0)

        local sign = modifier > 0 and "+" or ""
        modFS:SetFont(STANDARD_TEXT_FONT, modFontSize, "OUTLINE")
        modFS:SetText(sign .. tostring(modifier))
        modFS:ClearAllPoints()
        modFS:SetPoint("LEFT", sumFS, "RIGHT", 6, 0)
        modFS:SetAlpha(0)
        modFS:Show()
        FadeAlpha(modFS, 0, 1, SEQ_FADE_DUR)

        C_Timer.After(SEQ_HOLD_MOD, function()
            if OmegaDice.icoAnimId ~= animId then return end
            FadeAlpha(sumFS, 1, 0, SEQ_FADE_DUR)
            FadeGlow(sumGlow, 1, 0, SEQ_FADE_DUR)
            FadeAlpha(modFS, 1, 0, SEQ_FADE_DUR, function()
                if OmegaDice.icoAnimId ~= animId then return end
                modFS:Hide()

                sumFS:ClearAllPoints()
                sumFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
                sumFS:SetText(tostring(total))
                sumFS:SetTextColor(cr, cg, cb)

                -- Re-attach glow to the now-repositioned sumFS
                local sz = sumFS:GetStringHeight()
                GlowAttach(sumGlow, sumFS, sz * 2.6, sz * 1.7)
                GlowColor(sumGlow, cr, cg, cb)

                FadeAlpha(sumFS, 0, 1, SEQ_FADE_DUR)
                FadeGlow(sumGlow, 0, 1, SEQ_FADE_DUR, onDone)
            end)
        end)
    end)
end

-- ─── Single-die modifier sequence ────────────────────────────────────────────
local function PlaySingleDieSequence(frame, slot, xOff, rv, total, modifier, cfg, animId, onHoldStart)
    local res      = slot.result
    local modFS    = frame.modDisplay
    local modFontSize = math.floor(cfg.res * 0.62)
    local r, g, b  = res:GetTextColor()  -- already set by caller

    -- Phase 1: raw roll at center
    res:ClearAllPoints()
    res:SetPoint("CENTER", frame, "CENTER", xOff, 0)
    res:SetAlpha(1)
    res:Show()
    GlowSetAlpha(slot.glow, 1)
    GlowShow(slot.glow)
    modFS:Hide()

    -- Phase 2: shift left, modifier fades in right
    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.icoAnimId ~= animId then return end

        local shift = modFontSize * 1.1
        res:ClearAllPoints()
        res:SetPoint("CENTER", frame, "CENTER", xOff - shift, 0)

        local sign = modifier > 0 and "+" or ""
        modFS:SetFont(STANDARD_TEXT_FONT, modFontSize, "OUTLINE")
        modFS:SetText(sign .. tostring(modifier))
        modFS:ClearAllPoints()
        modFS:SetPoint("LEFT", res, "RIGHT", 6, 0)
        modFS:SetAlpha(0)
        modFS:Show()
        FadeAlpha(modFS, 0, 1, SEQ_FADE_DUR)

        -- Phase 3: fade out both, show total
        C_Timer.After(SEQ_HOLD_MOD, function()
            if OmegaDice.icoAnimId ~= animId then return end
            FadeAlpha(res,   1, 0, SEQ_FADE_DUR)
            FadeGlow(slot.glow, 1, 0, SEQ_FADE_DUR)
            FadeAlpha(modFS, 1, 0, SEQ_FADE_DUR, function()
                if OmegaDice.icoAnimId ~= animId then return end
                modFS:Hide()

                res:ClearAllPoints()
                res:SetPoint("CENTER", frame, "CENTER", xOff, 0)
                res:SetText(tostring(total))

                -- Reattach glow after reposition
                local gw = cfg.res * 2.6
                local gh = cfg.res * 1.7
                GlowAttach(slot.glow, res, gw, gh)

                FadeAlpha(res, 0, 1, SEQ_FADE_DUR)
                FadeGlow(slot.glow, 0, 1, SEQ_FADE_DUR, onHoldStart)
            end)
        end)
    end)
end

-- ─── Multi-die convergence ────────────────────────────────────────────────────
local function PlayMergeToCenter(frame, slots, xOffsets, n, duration, animId, onDone)
    local t0 = GetTime()
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(self)
        if OmegaDice.icoAnimId ~= animId then self:SetScript("OnUpdate", nil); return end
        local p  = math.min((GetTime() - t0) / duration, 1)
        local ep = p * p

        for i = 1, n do
            local curX = xOffsets[i] * (1 - ep)
            slots[i].result:ClearAllPoints()
            slots[i].result:SetPoint("CENTER", frame, "CENTER", curX, 0)
            slots[i].result:SetAlpha(1 - ep)
            GlowSetAlpha(slots[i].glow, 1 - ep)
        end

        if p >= 1 then
            self:SetScript("OnUpdate", nil)
            for i = 1, n do
                slots[i].result:SetAlpha(1)
                slots[i].result:Hide()
                GlowHide(slots[i].glow)
            end
            if onDone then onDone() end
        end
    end)
end

-- ─── Multi-die sequence ───────────────────────────────────────────────────────
local function PlayMultiDieSequence(frame, slots, xOffsets, n, rolls, rollSum, total, modifier, allMax, allMin, minVal, maxVal, cfg, animId, onHoldStart)
    local sumFS  = frame.sumDisplay
    local sumGlow = frame.sumGlow
    local modFS  = frame.modDisplay
    local sumFontSize = math.min(cfg.res + 16, 58)

    local sr, sg, sb
    if allMax then sr, sg, sb = 0.3, 1, 0.45
    elseif allMin then sr, sg, sb = 1, 0.25, 0.25
    else sr, sg, sb = 1, 0.88, 0.35 end

    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.icoAnimId ~= animId then return end

        PlayMergeToCenter(frame, slots, xOffsets, n, 0.45, animId, function()
            if OmegaDice.icoAnimId ~= animId then return end

            sumFS:SetFont(STANDARD_TEXT_FONT, sumFontSize, "OUTLINE")
            sumFS:SetTextColor(sr, sg, sb)
            sumFS:SetText(tostring(rollSum))
            sumFS:ClearAllPoints()
            sumFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
            sumFS:SetAlpha(0)
            sumFS:Show()

            local gw = sumFontSize * 3.2
            local gh = sumFontSize * 2.1
            GlowAttach(sumGlow, sumFS, gw, gh)
            GlowColor(sumGlow, sr, sg, sb)
            GlowSetAlpha(sumGlow, 0)
            GlowShow(sumGlow)

            FadeAlpha(sumFS, 0, 1, SEQ_FADE_DUR)
            FadeGlow(sumGlow, 0, 1, SEQ_FADE_DUR, function()
                if OmegaDice.icoAnimId ~= animId then return end

                if modifier ~= 0 then
                    PlayModifierMerge(frame, sumFS, sumGlow, modFS,
                        modifier, total, sr, sg, sb, animId, onHoldStart)
                else
                    if onHoldStart then onHoldStart() end
                end
            end)
        end)
    end)
end

-- ─── Animation entry point ────────────────────────────────────────────────────
function OmegaDice.PlayIcoAnimation(rolls, total, modifier, description, minVal, maxVal, onComplete)
    local n        = math.min(#rolls, MAX_ICO)
    local isSingle = (n == 1)
    local trimDesc = OmegaDice.Trim(description)
    local cfg      = DIE_CFG[n]

    local totalW = n * cfg.die + (n - 1) * cfg.gap

    local frame = GetIcoFrame()
    frame:SetScript("OnUpdate", nil)
    frame:SetSize(totalW + 20, FRAME_H)
    frame:SetScale(1)
    frame.topLabel:SetText(n .. "D20")
    frame.footer:SetText("Lancement...")
    frame.sumDisplay:Hide()
    frame.modDisplay:Hide()
    GlowHide(frame.sumGlow)

    local xOffsets = {}
    for i = 1, n do
        xOffsets[i] = -(totalW/2) + cfg.die/2 + (i-1)*(cfg.die + cfg.gap)
    end

    for di = 1, MAX_ICO do
        local slot = frame.dice[di]
        if di <= n then
            for _, fs in ipairs(slot.labels) do
                fs:SetFont(STANDARD_TEXT_FONT, cfg.lbl, "OUTLINE")
            end
            slot.result:Hide()
            GlowHide(slot.glow)
        else
            HideSlot(slot)
        end
    end

    frame:Show()

    local startRx, startRy = {}, {}
    for i = 1, n do
        startRx[i] = (math.random() + 1) * 18
        startRy[i] = (math.random() + 1) * 18
    end

    local targetRx, targetRy = {}, {}
    for i = 1, n do
        targetRx[i], targetRy[i] = FaceToCamera(FACE_NORMALS[rolls[i]])
    end

    OmegaDice.icoAnimId = (OmegaDice.icoAnimId or 0) + 1
    local animId    = OmegaDice.icoAnimId
    local startTime = GetTime()

    local STAGGER       = 0.4  -- extra seconds added per successive die
    local totalDuration = ANIM_DURATION + (n - 1) * STAGGER
    local dieFinished   = {}   -- tracks which dice have already shown their result

    local rollSum = 0
    local allMax, allMin = true, true
    for i = 1, n do
        rollSum = rollSum + rolls[i]
        if rolls[i] ~= maxVal then allMax = false end
        if rolls[i] ~= minVal then allMin = false end
    end

    local function startHold()
        C_Timer.After(HOLD_DURATION, function()
            if OmegaDice.icoAnimId == animId then
                frame:Hide()
                GlowHide(frame.sumGlow)
                for i = 1, n do GlowHide(frame.dice[i].glow) end
            end
        end)
    end

    frame:SetScript("OnUpdate", function(self)
        local elapsed = GetTime() - startTime
        local allDone = true

        for i = 1, n do
            local dieDuration = ANIM_DURATION + (i - 1) * STAGGER
            local ti  = math.min(elapsed / dieDuration, 1)

            if ti < 1 then
                local tei = EaseOut(ti)
                local rx  = (1 - tei) * startRx[i] + tei * targetRx[i]
                local ry  = (1 - tei) * startRy[i] + tei * targetRy[i]
                DrawDie(self, self.dice[i], xOffsets[i], rx, ry, cfg, false)
                allDone = false
            else
                -- Die i just finished or was already done
                DrawDie(self, self.dice[i], xOffsets[i], targetRx[i], targetRy[i], cfg, true)
                if not dieFinished[i] then
                    dieFinished[i] = true
                    local rv      = rolls[i]
                    local r, g, b = RollColor(rv, minVal, maxVal)
                    local displayText = isSingle and tostring(rv) or tostring(rv)
                    ShowResult(self.dice[i], self, xOffsets[i], displayText, r, g, b, cfg.res)
                end
            end
        end

        local tOverall = math.min(elapsed / totalDuration, 1)
        self:SetScale(1 + math.sin(tOverall * math.pi) * 0.025 * (1 - tOverall))

        if allDone then
            self:SetScript("OnUpdate", nil)
            self:SetScale(1)

            if modifier ~= 0 then
                self.topLabel:SetText("Jet : "..tostring(rollSum).."  |  Mod. : "..tostring(modifier))
            else
                self.topLabel:SetText("Jet : "..tostring(rollSum))
            end

            if allMax then
                self.footer:SetText("Critique !")
            elseif allMin then
                self.footer:SetText("Echec critique")
            else
                self.footer:SetText(trimDesc ~= "" and trimDesc or "Resultat")
            end

            if onComplete then onComplete() end

            if isSingle then
                local rv    = rolls[1]
                local slot  = self.dice[1]

                if modifier ~= 0 then
                    PlaySingleDieSequence(self, slot, xOffsets[1],
                        rv, total, modifier, cfg, animId, startHold)
                else
                    slot.result:SetText(tostring(total))
                    startHold()
                end
            else
                -- Results already shown per-die in OnUpdate; just trigger the merge
                PlayMultiDieSequence(self, self.dice, xOffsets, n, rolls,
                    rollSum, total, modifier, allMax, allMin,
                    minVal, maxVal, cfg, animId, startHold)
            end
        end
    end)
end
