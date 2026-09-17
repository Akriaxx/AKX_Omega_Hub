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

local DIE_CFG = {
    [1] = { die=210, scale=72, gap=0,  edge=2.1, lbl=18, res=58 },
    [2] = { die=168, scale=58, gap=12, edge=1.8, lbl=15, res=46 },
    [3] = { die=140, scale=48, gap=10, edge=1.5, lbl=13, res=38 },
    [4] = { die=116, scale=40, gap=8,  edge=1.3, lbl=11, res=32 },
    [5] = { die=100, scale=34, gap=7,  edge=1.1, lbl=10, res=27 },
    [6] = { die=88,  scale=30, gap=6,  edge=1.0, lbl=9,  res=24 },
}

local FRAME_H       = 260
local ANIM_DURATION = 2.4
local HOLD_DURATION = 3.0
local STAGGER       = 0.4

local SEQ_SHOW_MOD = 0.7
local SEQ_FADE_DUR = 0.28
local SEQ_HOLD_MOD = 0.9

-- Images calculées hors jeu : aucune projection ni arête Lua par image.
local BLP_PATH="Interface\\AddOns\\Omega_Hub\\Modules\\Dice\\Media\\Flight\\Atlas\\"

local function PickRollVariant(previous, neighbour)
    local candidates={}
    for variant=1,4 do
        if variant~=previous and variant~=neighbour then candidates[#candidates+1]=variant end
    end
    return candidates[math.random(1,#candidates)]
end

function OmegaDice.WarmDiceTextures()
    if OmegaDice.textureWarmup then return end
    local f=CreateFrame("Frame",nil,UIParent)
    OmegaDice.textureWarmup=f;f:SetSize(1,1);f:SetPoint("CENTER");f:EnableMouse(false)
    f.images={};f.elapsed=0;f.frames=0
    for _,sides in ipairs({4,6,8,10,12,20,100}) do
        local image=f:CreateTexture(nil,"ARTWORK");image:SetAllPoints()
        image:SetTexture(BLP_PATH.."d"..sides.."-face-1-p1.blp")
        image:SetTexCoord(.25/2048,.75/2048,.25/2048,.75/2048)
        f.images[#f.images+1]=image
    end
    f:SetScript("OnUpdate",function(self,dt)
        self.elapsed=self.elapsed+dt
        local ready=true
        for _,image in ipairs(self.images) do
            if image.IsObjectLoaded and not image:IsObjectLoaded() then ready=false;break end
        end
        self.frames=ready and self.frames+1 or 0
        if (self.frames>=8 and self.elapsed>=.5) or self.elapsed>15 then
            self:SetScript("OnUpdate",nil);self:Hide()
        end
    end)
end

-- ─── BLP slot pool (added lazily to shared frame) ───────────────────────
local function EnsureBLPSlots(frame)
    if frame.dice then return end
    frame.dice = {}
    for di = 1, MAX_DICE do
        local slot = {}
        slot.lines = {} -- Conservées vides pour les anciennes extensions.
        slot.labels = {}
        slot.rollImage=frame:CreateTexture(nil,"ARTWORK");slot.rollImage:Hide()
        slot.landImage=frame:CreateTexture(nil,"ARTWORK");slot.landImage:Hide()
        slot.middleImage=frame:CreateTexture(nil,"ARTWORK");slot.middleImage:Hide()
        slot.pages={slot.rollImage,slot.middleImage,slot.landImage};slot.pagePaths={}
        slot.image=slot.rollImage
        slot.result = frame:CreateFontString(nil, "OVERLAY")
        slot.result:SetFont(STANDARD_TEXT_FONT, 56, "OUTLINE")
        slot.result:SetTextColor(1, 0.88, 0.35)
        slot.result:Hide()
        slot.modDisplay = frame:CreateFontString(nil, "OVERLAY")
        slot.modDisplay:SetFont(STANDARD_TEXT_FONT, 24, "OUTLINE")
        slot.modDisplay:SetTextColor(0.65, 0.75, 1, 1)
        slot.modDisplay:Hide()
        slot.glow = CreateGlow(frame)
        frame.dice[di] = slot
    end
end

local function GetBLPFrame()
    local f = OmegaDice.GetDiceFrame()
    EnsureBLPSlots(f)
    return f
end

-- ─── Full frame reset (exported so D20Animation can call it too) ──────────────
local function HideSlot(slot)
    for _,image in ipairs(slot.pages) do image:Hide() end
    for _, ln in ipairs(slot.lines)  do ln:Hide() end
    for _, fs in ipairs(slot.labels) do fs:Hide() end
    slot.result:Hide()
    slot.modDisplay:Hide()
    GlowHide(slot.glow)
end

function OmegaDice.ResetDiceFrame()
    local frame = OmegaDice.GetDiceFrame()
    frame:SetScript("OnUpdate", nil)
    frame.sumDisplay:Hide()
    frame.modDisplay:Hide()
    GlowHide(frame.sumGlow)
    -- Hide BLP slots
    if frame.dice then
        for di = 1, MAX_DICE do HideSlot(frame.dice[di]) end
    end
    -- Hide flat die value fontstrings
    if frame.dieValues then
        for _, dv in ipairs(frame.dieValues) do dv:Hide() end
    end
    if frame.modValues then
        for _, fs in ipairs(frame.modValues) do fs:Hide() end
    end
    if frame.detail then frame.detail:Hide() end
end

-- ─── Rendering ────────────────────────────────────────────────────────────────
local function DrawDie(frame,slot,xOff,cfg,t)
    -- Une seule trajectoire de 144 poses. Les trois planches ne sont que
    -- du stockage : aucun changement de mouvement à leurs frontières.
    local progress=1-(1-t)^(slot.motionPower or 1)
    local index=math.min(143,math.floor(progress*143+.5))
    local page=math.floor(index/64)+1
    local image=slot.pages[page]
    if image~=slot.image then slot.image:Hide();slot.image=image;slot.imageIndex=nil end
    if slot.imageIndex~=index then
        local cell=index%64
        local rows=page==3 and 2 or 8
        local x,y=cell%8,math.floor(cell/8)
        image:SetTexCoord(x/8,(x+1)/8,y/rows,(y+1)/rows)
        slot.imageIndex=index
    end
    image:Show()
end

local function ShowResult(slot, frame, xOff, text, r, g, b, fontSize)
    local res = slot.result
    res:ClearAllPoints()
    res:SetPoint("CENTER", frame, "CENTER", xOff, -slot.dieSize*.48)
    res:SetFont(STANDARD_TEXT_FONT, math.floor(fontSize*.55), "OUTLINE")
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
        sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", -shift, frame.resultY)
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
                sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", 0, frame.resultY)
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
    res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOff, frame.resultY)
    res:SetAlpha(1); res:Show()
    GlowSetAlpha(slot.glow, 1); GlowShow(slot.glow)
    modFS:Hide()
    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.animId ~= animId then return end
        local shift = modSz * 1.1
        res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOff-shift, frame.resultY)
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
                res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOff, frame.resultY)
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
            slots[i].result:SetPoint("CENTER", frame, "CENTER", curX, frame.resultY)
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
            sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", 0, frame.resultY)
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

-- ─── Modifier sequence for separate (independent) dice ────────────────────────
-- Same reveal as PlaySingleDieSequence, run in parallel on every die that has
-- its own non-zero modifier. Dice without one already show their final value.
local function PlaySeparateModifierSequence(frame, slots, xOffsets, n, rolls, perDieMods, cfg, animId, onDone)
    local modSz  = math.floor(cfg.res * 0.62)
    local modIdx = {}
    for i = 1, n do
        if perDieMods and perDieMods[i] and perDieMods[i] ~= 0 then
            table.insert(modIdx, i)
            slots[i].modDisplay:Hide()
        end
    end

    if #modIdx == 0 then
        if onDone then onDone() end
        return
    end

    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.animId ~= animId then return end
        local shift = modSz * 1.1
        for _, i in ipairs(modIdx) do
            local res  = slots[i].result
            local fs   = slots[i].modDisplay
            local dmod = perDieMods[i]
            res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOffsets[i]-shift, frame.resultY)
            local sign = dmod > 0 and "+" or ""
            fs:SetFont(STANDARD_TEXT_FONT, modSz, "OUTLINE")
            fs:SetText(sign..tostring(dmod))
            fs:ClearAllPoints(); fs:SetPoint("LEFT", res, "RIGHT", 6, 0)
            fs:SetAlpha(0); fs:Show()
            FadeAlpha(fs, 0, 1, SEQ_FADE_DUR)
        end
        C_Timer.After(SEQ_HOLD_MOD, function()
            if OmegaDice.animId ~= animId then return end
            for k, i in ipairs(modIdx) do
                local slot   = slots[i]
                local res    = slot.result
                local fs     = slot.modDisplay
                local dmod   = perDieMods[i]
                local isLast = (k == #modIdx)
                FadeAlpha(res, 1, 0, SEQ_FADE_DUR)
                FadeGlow(slot.glow, 1, 0, SEQ_FADE_DUR)
                FadeAlpha(fs, 1, 0, SEQ_FADE_DUR, function()
                    if OmegaDice.animId ~= animId then return end
                    fs:Hide()
                    res:ClearAllPoints(); res:SetPoint("CENTER", frame, "CENTER", xOffsets[i], frame.resultY)
                    res:SetText(tostring(rolls[i] + dmod))
                    GlowAttach(slot.glow, res, cfg.res*3.2, cfg.res*2.1)
                    FadeAlpha(res, 0, 1, SEQ_FADE_DUR)
                    FadeGlow(slot.glow, 0, 1, SEQ_FADE_DUR, isLast and onDone or nil)
                end)
            end
        end)
    end)
end

-- ─── Entry point ──────────────────────────────────────────────────────────────
function OmegaDice.PlayBLPAnimation(geo, rolls, total, modifier, separate, perDieMods, description, minVal, maxVal, onComplete)
    local n        = math.min(#rolls, MAX_DICE)
    local isSingle = (n == 1)
    local trimDesc = OmegaDice.Trim(description)
    local cfg      = DIE_CFG[n]
    local totalW   = n * cfg.die + (n-1) * cfg.gap

    -- Cancel any running animation and wipe all stale visuals from the shared frame
    OmegaDice.animId = (OmegaDice.animId or 0) + 1
    local animId = OmegaDice.animId
    OmegaDice.ResetDiceFrame()

    local frame = GetBLPFrame()
    frame:SetSize(totalW + 20, math.max(FRAME_H, cfg.die + 90))
    frame.resultY = -cfg.die * .48
    frame:SetScale(1)
    frame.topLabel:SetText(n..(separate and "x" or "").."D"..geo.sides)
    frame.footer:SetText("Lancement...")

    -- Font pass for active slots (slots are already fully hidden by ResetDiceFrame)
    local xOffsets = {}
    for i = 1, n do
        xOffsets[i] = -(totalW/2) + cfg.die/2 + (i-1)*(cfg.die+cfg.gap)
        for _, fs in ipairs(frame.dice[i].labels) do fs:SetFont(STANDARD_TEXT_FONT, cfg.lbl, "OUTLINE") end
    end
    frame:Show()

    OmegaDice.WarmDiceTextures()
    for i=1,n do
        local slot=frame.dice[i]
        slot.rollVariant=PickRollVariant(slot.rollVariant,i>1 and frame.dice[i-1].rollVariant or nil)
        slot.motionPower=({.94,.98,1.02,1.06})[slot.rollVariant]
        local base=BLP_PATH.."d"..geo.sides.."-face-"..rolls[i].."-p"
        slot.rawResult=rolls[i];slot.dieSize=cfg.die;slot.imageIndex=nil;slot.image=slot.rollImage
        for page,image in ipairs(slot.pages) do
            local path=base..page..".blp"
            if slot.pagePaths[page]~=path then image:SetTexture(path);slot.pagePaths[page]=path end
            image:SetSize(1,1);image:ClearAllPoints()
            image:SetPoint("CENTER",frame,"CENTER",xOffsets[i],0)
            image:SetTexCoord(.25/2048,.75/2048,.25/2048,.75/2048);image:Show()
        end
        slot.rollPath=slot.pagePaths[1];slot.landPath=slot.pagePaths[3]
    end

    local warmFrames=0
    local texturesReady=false
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
        if not texturesReady then
            for i=1,n do
                local slot=self.dice[i]
                for _,image in ipairs(slot.pages) do
                    if image.IsObjectLoaded and not image:IsObjectLoaded() then
                        startTime=GetTime();return
                    end
                end
            end
            texturesReady=true
        end
        if warmFrames<8 then
            warmFrames=warmFrames+1;startTime=GetTime()
            if warmFrames<8 then return end
            for i=1,n do
                for _,image in ipairs(self.dice[i].pages) do
                    image:Hide();image:SetSize(cfg.die,cfg.die)
                end
            end
        end
        local elapsed = GetTime() - startTime
        local allDone = true

        for i = 1, n do
            local ti = math.min(math.max(elapsed-(i-1)*STAGGER,0) / ANIM_DURATION, 1)
            if ti < 1 then
                DrawDie(self,self.dice[i],xOffsets[i],cfg,ti)
                allDone = false
            else
                DrawDie(self,self.dice[i],xOffsets[i],cfg,1)
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

            if separate then
                local parts = {}
                for i = 1, n do parts[i] = tostring(rolls[i]) end
                self.topLabel:SetText("Jets : "..table.concat(parts, " | "))
            elseif modifier ~= 0 then
                self.topLabel:SetText("Jet : "..tostring(rollSum).."  |  Mod. : "..tostring(modifier))
            else
                self.topLabel:SetText("Jet : "..tostring(rollSum))
            end

            if allMax then self.footer:SetText("Critique !")
            elseif allMin then self.footer:SetText("Echec critique")
            else self.footer:SetText(trimDesc ~= "" and trimDesc or "Resultat") end

            if onComplete then onComplete() end

            if separate then
                PlaySeparateModifierSequence(self, self.dice, xOffsets, n, rolls, perDieMods, cfg, animId, startHold)
            elseif isSingle then
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

OmegaDice.PlayWireframeAnimation=OmegaDice.PlayBLPAnimation -- Compatibilité réseau/extensions

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
    OmegaDice.PlayWireframeAnimation(OmegaDice.D20Geometry, rolls, total, modifier, false, nil, description, minVal, maxVal, onComplete)
end
