local OmegaDice = _G.OmegaDice

-- Cache shared utilities as locals for OnUpdate performance
local FadeAlpha    = function(...) return OmegaDice.FadeAlpha(...)    end
local RollColor    = function(...) return OmegaDice.RollColor(...)    end
local CreateGlow   = function(...) return OmegaDice.CreateGlow(...)   end
local GlowAttach   = function(...) return OmegaDice.GlowAttach(...)   end
local GlowColor    = function(...) return OmegaDice.GlowColor(...)    end
local GlowShow     = function(...) return OmegaDice.GlowShow(...)     end
local GlowHide     = function(...) return OmegaDice.GlowHide(...)     end
local GlowSetAlpha = function(...) return OmegaDice.GlowSetAlpha(...) end
local FadeGlow     = function(...) return OmegaDice.FadeGlow(...)     end

-- ─── Layout indexed by die count ─────────────────────────────────────────────
local MAX_DICE  = 6
local MAX_EDGES = 30   -- enough for D20 / D12
local MAX_FACES = 20   -- enough for D20

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
local STAGGER       = 0.4

local SEQ_SHOW_MOD = 0.7
local SEQ_FADE_DUR = 0.28
local SEQ_HOLD_MOD = 0.9

-- ─── Math ─────────────────────────────────────────────────────────────────────
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
    return rx, math.atan2(n[1], -z1)
end

local function EaseOut(t) return 1 - (1-t)^3 end

-- ─── Wireframe slot pool (added lazily to shared frame) ───────────────────────
local function EnsureWireframeSlots(frame)
    if frame.dice then return end
    frame.dice = {}
    for di = 1, MAX_DICE do
        local slot = {}
        slot.lines = {}
        for i = 1, MAX_EDGES do
            local ln = frame:CreateLine(nil, "ARTWORK")
            ln:SetColorTexture(0.8, 0.68, 0.35, 1)
            slot.lines[i] = ln
        end
        slot.labels = {}
        for i = 1, MAX_FACES do
            local fs = frame:CreateFontString(nil, "OVERLAY")
            fs:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
            fs:SetTextColor(1, 0.92, 0.55, 0.9)
            fs:SetText(tostring(i))
            fs:Hide()
            slot.labels[i] = fs
        end
        slot.result = frame:CreateFontString(nil, "OVERLAY")
        slot.result:SetFont(STANDARD_TEXT_FONT, 56, "OUTLINE")
        slot.result:SetTextColor(1, 0.88, 0.35)
        slot.result:Hide()
        slot.glow = CreateGlow(frame)
        frame.dice[di] = slot
    end
end

local function GetWireframeFrame()
    local f = OmegaDice.GetDiceFrame()
    EnsureWireframeSlots(f)
    return f
end

-- ─── Full frame reset (exported so D20Animation can call it too) ──────────────
local function HideSlot(slot)
    for _, ln in ipairs(slot.lines)  do ln:Hide() end
    for _, fs in ipairs(slot.labels) do fs:Hide() end
    slot.result:Hide()
    GlowHide(slot.glow)
end

function OmegaDice.ResetDiceFrame()
    local frame = OmegaDice.GetDiceFrame()
    frame:SetScript("OnUpdate", nil)
    frame.sumDisplay:Hide()
    frame.modDisplay:Hide()
    GlowHide(frame.sumGlow)
    -- Hide wireframe slots
    if frame.dice then
        for di = 1, MAX_DICE do HideSlot(frame.dice[di]) end
    end
    -- Hide flat die value fontstrings
    if frame.dieValues then
        for _, dv in ipairs(frame.dieValues) do dv:Hide() end
    end
    if frame.detail then frame.detail:Hide() end
end

-- ─── Rendering ────────────────────────────────────────────────────────────────
local function DrawDie(frame, slot, geo, xOff, rx, ry, cfg, isFinished)
    local cx, sx = math.cos(rx), math.sin(rx)
    local cy, sy = math.cos(ry), math.sin(ry)

    -- meshFaces/meshNormals let D100 use icosahedron topology for edge visibility
    -- while its own normals table holds the 100 Fibonacci landing targets
    local visFaces   = geo.meshFaces   or geo.faces
    local visNormals = geo.meshNormals or geo.normals

    local proj = {}
    for i, v in ipairs(geo.verts) do
        local x, y, z = RotFast(v[1], v[2], v[3], cx, sx, cy, sy)
        local px, py  = Project(x, y, z, cfg.scale)
        proj[i] = { px=px+xOff, py=py, z=z }
    end

    -- Face labels (only for visible back-facing faces; geo.faces may be empty for D100)
    local numFaces = #geo.faces
    for i = 1, MAX_FACES do
        local fs = slot.labels[i]
        if i <= numFaces then
            local fn = geo.normals[i]
            local _, _, rnz = RotFast(fn[1], fn[2], fn[3], cx, sx, cy, sy)
            if not isFinished and rnz < -0.55 then
                local face = geo.faces[i]
                local px, py = 0, 0
                for _, vi in ipairs(face) do px=px+proj[vi].px; py=py+proj[vi].py end
                local nv = #face
                fs:ClearAllPoints()
                fs:SetPoint("CENTER", frame, "CENTER", px/nv, py/nv)
                fs:SetAlpha(math.min(((-rnz-0.55)/0.45)^2, 1))
                fs:Show()
            else
                fs:Hide()
            end
        else
            fs:Hide()
        end
    end

    -- Edges (visibility determined by visFaces / visNormals)
    local numEdges = #geo.edges
    for i = 1, MAX_EDGES do
        local ln = slot.lines[i]
        if i <= numEdges then
            local edge = geo.edges[i]
            local a, b = proj[edge[1]], proj[edge[2]]
            local isVis = false
            for fi, fVerts in ipairs(visFaces) do
                local fn = visNormals[fi]
                local _, _, rnz = RotFast(fn[1], fn[2], fn[3], cx, sx, cy, sy)
                if rnz < -0.05 then
                    local hasA, hasB = false, false
                    for _, vi in ipairs(fVerts) do
                        if vi == edge[1] then hasA = true end
                        if vi == edge[2] then hasB = true end
                    end
                    if hasA and hasB then isVis = true; break end
                end
            end
            if isVis then
                local dx, dy = b.px-a.px, b.py-a.py
                local len    = math.sqrt(dx*dx+dy*dy)
                if len > 0 then
                    local ux, uy = (dx/len)*LINE_EXT, (dy/len)*LINE_EXT
                    local bright = 1 - ((a.z+b.z)*0.5+1)*0.35
                    ln:SetThickness(cfg.edge)
                    ln:SetColorTexture(0.8*bright, 0.68*bright, 0.35*bright, 1)
                    ln:SetStartPoint("CENTER", frame, a.px-ux, a.py-uy)
                    ln:SetEndPoint("CENTER",   frame, b.px+ux, b.py+uy)
                    ln:Show()
                else ln:Hide() end
            else ln:Hide() end
        else
            ln:Hide()
        end
    end
end

local function ShowResult(slot, frame, xOff, text, r, g, b, fontSize)
    local res = slot.result
    res:ClearAllPoints()
    res:SetPoint("CENTER", frame, "CENTER", xOff, 0)
    res:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
    res:SetTextColor(r, g, b)
    res:SetText(text)
    res:SetAlpha(1)
    res:Show()
    GlowAttach(slot.glow, res, fontSize*3.2, fontSize*2.1)
    GlowColor(slot.glow, r, g, b)
    GlowSetAlpha(slot.glow, 1)
    GlowShow(slot.glow)
end

-- ─── Modifier merge (shared by single and multi) ──────────────────────────────
local function PlayModifierMerge(frame, sumFS, sumGlow, modFS, modifier, total, cr, cg, cb, animId, onDone)
    local modSz = math.max(math.floor(sumFS:GetStringHeight()*0.68), 22)
    C_Timer.After(SEQ_HOLD_MOD, function()
        if OmegaDice.animId ~= animId then return end
        local shift = modSz * 1.15
        sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", -shift, 0)
        local sign = modifier > 0 and "+" or ""
        modFS:SetFont(STANDARD_TEXT_FONT, modSz, "OUTLINE")
        modFS:SetText(sign..tostring(modifier))
        modFS:ClearAllPoints(); modFS:SetPoint("LEFT", sumFS, "RIGHT", 6, 0)
        modFS:SetAlpha(0); modFS:Show()
        FadeAlpha(modFS, 0, 1, SEQ_FADE_DUR)
        C_Timer.After(SEQ_HOLD_MOD, function()
            if OmegaDice.animId ~= animId then return end
            FadeAlpha(sumFS, 1, 0, SEQ_FADE_DUR)
            FadeGlow(sumGlow, 1, 0, SEQ_FADE_DUR)
            FadeAlpha(modFS, 1, 0, SEQ_FADE_DUR, function()
                if OmegaDice.animId ~= animId then return end
                modFS:Hide()
                sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
                sumFS:SetText(tostring(total)); sumFS:SetTextColor(cr, cg, cb)
                local sz = sumFS:GetStringHeight()
                GlowAttach(sumGlow, sumFS, sz*3.2, sz*2.1)
                GlowColor(sumGlow, cr, cg, cb)
                FadeAlpha(sumFS, 0, 1, SEQ_FADE_DUR)
                FadeGlow(sumGlow, 0, 1, SEQ_FADE_DUR, onDone)
            end)
        end)
    end)
end

-- ─── Single-die modifier sequence ────────────────────────────────────────────
local function PlaySingleDieSequence(frame, slot, xOff, rv, total, modifier, cfg, animId, onDone)
    local res   = slot.result
    local modFS = frame.modDisplay
    local modSz = math.floor(cfg.res * 0.62)
    res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOff, 0)
    res:SetAlpha(1); res:Show()
    GlowSetAlpha(slot.glow, 1); GlowShow(slot.glow)
    modFS:Hide()
    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.animId ~= animId then return end
        local shift = modSz * 1.1
        res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOff-shift, 0)
        local sign = modifier > 0 and "+" or ""
        modFS:SetFont(STANDARD_TEXT_FONT, modSz, "OUTLINE")
        modFS:SetText(sign..tostring(modifier))
        modFS:ClearAllPoints(); modFS:SetPoint("LEFT", res, "RIGHT", 6, 0)
        modFS:SetAlpha(0); modFS:Show()
        FadeAlpha(modFS, 0, 1, SEQ_FADE_DUR)
        C_Timer.After(SEQ_HOLD_MOD, function()
            if OmegaDice.animId ~= animId then return end
            FadeAlpha(res, 1, 0, SEQ_FADE_DUR)
            FadeGlow(slot.glow, 1, 0, SEQ_FADE_DUR)
            FadeAlpha(modFS, 1, 0, SEQ_FADE_DUR, function()
                if OmegaDice.animId ~= animId then return end
                modFS:Hide()
                res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOff, 0)
                res:SetText(tostring(total))
                GlowAttach(slot.glow, res, cfg.res*3.2, cfg.res*2.1)
                FadeAlpha(res, 0, 1, SEQ_FADE_DUR)
                FadeGlow(slot.glow, 0, 1, SEQ_FADE_DUR, onDone)
            end)
        end)
    end)
end

-- ─── Multi-die convergence ────────────────────────────────────────────────────
local function PlayMergeToCenter(frame, slots, xOffsets, n, duration, animId, onDone)
    local t0 = GetTime()
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        if OmegaDice.animId ~= animId then self:SetScript("OnUpdate", nil); return end
        local p  = math.min((GetTime()-t0)/duration, 1)
        local ep = p * p
        for i = 1, n do
            local curX = xOffsets[i] * (1-ep)
            slots[i].result:ClearAllPoints()
            slots[i].result:SetPoint("CENTER", frame, "CENTER", curX, 0)
            slots[i].result:SetAlpha(1-ep)
            GlowSetAlpha(slots[i].glow, 1-ep)
        end
        if p >= 1 then
            self:SetScript("OnUpdate", nil)
            for i = 1, n do slots[i].result:SetAlpha(1); slots[i].result:Hide(); GlowHide(slots[i].glow) end
            if onDone then onDone() end
        end
    end)
end

local function PlayMultiDieSequence(frame, slots, xOffsets, n, rollSum, total, modifier, sr, sg, sb, cfg, animId, onDone)
    local sumFS   = frame.sumDisplay
    local sumGlow = frame.sumGlow
    local modFS   = frame.modDisplay
    local sumSz   = math.min(cfg.res + 16, 58)
    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.animId ~= animId then return end
        PlayMergeToCenter(frame, slots, xOffsets, n, 0.45, animId, function()
            if OmegaDice.animId ~= animId then return end
            sumFS:SetFont(STANDARD_TEXT_FONT, sumSz, "OUTLINE")
            sumFS:SetTextColor(sr, sg, sb)
            sumFS:SetText(tostring(rollSum))
            sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", 0, 0)
            sumFS:SetAlpha(0); sumFS:Show()
            GlowAttach(sumGlow, sumFS, sumSz*3.2, sumSz*2.1)
            GlowColor(sumGlow, sr, sg, sb)
            GlowSetAlpha(sumGlow, 0); GlowShow(sumGlow)
            FadeAlpha(sumFS, 0, 1, SEQ_FADE_DUR)
            FadeGlow(sumGlow, 0, 1, SEQ_FADE_DUR, function()
                if OmegaDice.animId ~= animId then return end
                if modifier ~= 0 then
                    PlayModifierMerge(frame, sumFS, sumGlow, modFS, modifier, total, sr, sg, sb, animId, onDone)
                else
                    if onDone then onDone() end
                end
            end)
        end)
    end)
end

-- ─── Entry point ──────────────────────────────────────────────────────────────
function OmegaDice.PlayWireframeAnimation(geo, rolls, total, modifier, description, minVal, maxVal, onComplete)
    local n        = math.min(#rolls, MAX_DICE)
    local isSingle = (n == 1)
    local trimDesc = OmegaDice.Trim(description)
    local cfg      = DIE_CFG[n]
    local totalW   = n * cfg.die + (n-1) * cfg.gap

    -- Cancel any running animation and wipe all stale visuals from the shared frame
    OmegaDice.animId = (OmegaDice.animId or 0) + 1
    local animId = OmegaDice.animId
    OmegaDice.ResetDiceFrame()

    local frame = GetWireframeFrame()
    frame:SetSize(totalW + 20, FRAME_H)
    frame:SetScale(1)
    frame.topLabel:SetText(n.."D"..geo.sides)
    frame.footer:SetText("Lancement...")

    -- Font pass for active slots (slots are already fully hidden by ResetDiceFrame)
    local xOffsets = {}
    for i = 1, n do
        xOffsets[i] = -(totalW/2) + cfg.die/2 + (i-1)*(cfg.die+cfg.gap)
        for _, fs in ipairs(frame.dice[i].labels) do fs:SetFont(STANDARD_TEXT_FONT, cfg.lbl, "OUTLINE") end
    end
    frame:Show()

    local startRx, startRy, targetRx, targetRy = {}, {}, {}, {}
    for i = 1, n do
        startRx[i]  = (math.random()+1) * 18
        startRy[i]  = (math.random()+1) * 18
        local fi    = rolls[i]
        targetRx[i], targetRy[i] = FaceToCamera(geo.normals[fi])
    end

    local startTime   = GetTime()
    local totalDur    = ANIM_DURATION + (n-1) * STAGGER
    local dieFinished = {}

    local rollSum = 0
    local allMax, allMin = true, true
    for i = 1, n do
        rollSum = rollSum + rolls[i]
        if rolls[i] ~= maxVal then allMax = false end
        if rolls[i] ~= minVal then allMin = false end
    end

    local sr, sg, sb
    if allMax then sr,sg,sb = 0.3,1,0.45 elseif allMin then sr,sg,sb = 1,0.25,0.25 else sr,sg,sb = 1,0.88,0.35 end

    local function startHold()
        C_Timer.After(HOLD_DURATION, function()
            if OmegaDice.animId ~= animId then return end
            frame:Hide()
            GlowHide(frame.sumGlow)
            for i = 1, n do GlowHide(frame.dice[i].glow) end
        end)
    end

    frame:SetScript("OnUpdate", function(self)
        local elapsed = GetTime() - startTime
        local allDone = true

        for i = 1, n do
            local dieDur = ANIM_DURATION + (i-1) * STAGGER
            local ti     = math.min(elapsed / dieDur, 1)
            if ti < 1 then
                local tei = EaseOut(ti)
                DrawDie(self, self.dice[i], geo, xOffsets[i],
                    (1-tei)*startRx[i]+tei*targetRx[i],
                    (1-tei)*startRy[i]+tei*targetRy[i], cfg, false)
                allDone = false
            else
                DrawDie(self, self.dice[i], geo, xOffsets[i], targetRx[i], targetRy[i], cfg, true)
                if not dieFinished[i] then
                    dieFinished[i] = true
                    local rv = rolls[i]
                    local r, g, b = RollColor(rv, minVal, maxVal)
                    ShowResult(self.dice[i], self, xOffsets[i], tostring(rv), r, g, b, cfg.res)
                end
            end
        end

        local tOv = math.min(elapsed/totalDur, 1)
        self:SetScale(1 + math.sin(tOv*math.pi)*0.025*(1-tOv))

        if allDone then
            self:SetScript("OnUpdate", nil)
            self:SetScale(1)

            if modifier ~= 0 then
                self.topLabel:SetText("Jet : "..tostring(rollSum).."  |  Mod. : "..tostring(modifier))
            else
                self.topLabel:SetText("Jet : "..tostring(rollSum))
            end

            if allMax then self.footer:SetText("Critique !")
            elseif allMin then self.footer:SetText("Echec critique")
            else self.footer:SetText(trimDesc ~= "" and trimDesc or "Resultat") end

            if onComplete then onComplete() end

            if isSingle then
                local rv      = rolls[1]
                local r, g, b = RollColor(rv, minVal, maxVal)
                self.dice[1].result:SetTextColor(r, g, b)
                if modifier ~= 0 then
                    PlaySingleDieSequence(self, self.dice[1], xOffsets[1], rv, total, modifier, cfg, animId, startHold)
                else
                    self.dice[1].result:SetText(tostring(total))
                    startHold()
                end
            else
                PlayMultiDieSequence(self, self.dice, xOffsets, n, rollSum, total, modifier, sr, sg, sb, cfg, animId, startHold)
            end
        end
    end)
end

-- ─── Geometry router ──────────────────────────────────────────────────────────
function OmegaDice.GeoForSides(sides)
    if     sides == 100 then return OmegaDice.D100Geometry
    elseif sides ==  20 then return OmegaDice.D20Geometry
    elseif sides ==  12 then return OmegaDice.D12Geometry
    elseif sides ==  10 then return OmegaDice.D10Geometry
    elseif sides ==   8 then return OmegaDice.D8Geometry
    elseif sides ==   6 then return OmegaDice.D6Geometry
    elseif sides ==   4 then return OmegaDice.D4Geometry
    end
    return nil
end

-- Compat shim
function OmegaDice.PlayIcoAnimation(rolls, total, modifier, description, minVal, maxVal, onComplete)
    OmegaDice.PlayWireframeAnimation(OmegaDice.D20Geometry, rolls, total, modifier, description, minVal, maxVal, onComplete)
end
