local OmegaDice = _G.OmegaDice

-- Flat animation (used when no 3D geometry exists for the die type)
local ANIMATION_DURATION   = 1.35
local RESULT_HOLD_DURATION = 2.75
local ROLL_TICK  = 0.055
local MIN_SCALE  = 0.92
local MAX_SCALE  = 1.16
local MAX_DICE   = 6

local FRAME_W  = { 200, 270, 330, 380, 420, 460 }
local DIE_FONT = { 64,  52,  44,  36,  30,  26  }
local FRAME_H  = 170

local SEQ_SHOW_MOD = 0.7
local SEQ_FADE_DUR = 0.28
local SEQ_HOLD_MOD = 0.9

-- ─── Flat-specific slots (added lazily to the shared frame) ───────────────────
local function EnsureFlatSlots(frame)
    if frame.dieValues then return end

    frame.detail = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.detail:SetTextColor(0.9, 0.9, 0.9)
    frame.detail:SetText("")

    frame.dieValues = {}
    for i = 1, MAX_DICE do
        local fs = frame:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT, 64, "OUTLINE")
        fs:SetTextColor(1, 0.88, 0.35)
        fs:Hide()
        frame.dieValues[i] = fs
    end
end

local function GetFlatFrame()
    local f = OmegaDice.GetDiceFrame()
    EnsureFlatSlots(f)
    return f
end

-- ─── Modifier sequence for single flat die ────────────────────────────────────
local function PlayFlatSingleSequence(frame, dv, xOff, rv, total, modifier, fontSize, animId, onDone)
    local modFS = frame.modDisplay
    local modSz = math.floor(fontSize * 0.62)
    dv:ClearAllPoints(); dv:SetPoint("CENTER", frame, "CENTER", xOff, 10)
    dv:SetAlpha(1)
    modFS:Hide()
    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.animId ~= animId then return end
        local shift = modSz * 1.1
        dv:ClearAllPoints(); dv:SetPoint("CENTER", frame, "CENTER", xOff-shift, 10)
        local sign = modifier > 0 and "+" or ""
        modFS:SetFont(STANDARD_TEXT_FONT, modSz, "OUTLINE")
        modFS:SetText(sign..tostring(modifier))
        modFS:ClearAllPoints(); modFS:SetPoint("LEFT", dv, "RIGHT", 6, 0)
        modFS:SetAlpha(0); modFS:Show()
        OmegaDice.FadeAlpha(modFS, 0, 1, SEQ_FADE_DUR)
        C_Timer.After(SEQ_HOLD_MOD, function()
            if OmegaDice.animId ~= animId then return end
            OmegaDice.FadeAlpha(dv, 1, 0, SEQ_FADE_DUR)
            OmegaDice.FadeAlpha(modFS, 1, 0, SEQ_FADE_DUR, function()
                if OmegaDice.animId ~= animId then return end
                modFS:Hide()
                dv:ClearAllPoints(); dv:SetPoint("CENTER", frame, "CENTER", xOff, 10)
                dv:SetText(tostring(total))
                OmegaDice.FadeAlpha(dv, 0, 1, SEQ_FADE_DUR, onDone)
            end)
        end)
    end)
end

-- ─── Modifier sequence for multi flat dice ────────────────────────────────────
local function PlayFlatMultiSequence(frame, dvs, xOffsets, n, rollSum, total, modifier, fontSize, animId, onDone)
    local sumFS = frame.sumDisplay
    local modFS = frame.modDisplay
    local sumSz = math.min(fontSize + 16, 58)

    C_Timer.After(SEQ_SHOW_MOD, function()
        if OmegaDice.animId ~= animId then return end

        local t0 = GetTime()
        local ticker = CreateFrame("Frame")
        ticker:SetScript("OnUpdate", function(self)
            if OmegaDice.animId ~= animId then self:SetScript("OnUpdate", nil); return end
            local p  = math.min((GetTime()-t0)/0.45, 1)
            local ep = p * p
            for i = 1, n do
                local curX = xOffsets[i] * (1-ep)
                dvs[i]:ClearAllPoints()
                dvs[i]:SetPoint("CENTER", frame, "CENTER", curX, 10)
                dvs[i]:SetAlpha(1-ep)
            end
            if p >= 1 then
                self:SetScript("OnUpdate", nil)
                for i = 1, n do dvs[i]:SetAlpha(1); dvs[i]:Hide() end

                sumFS:SetFont(STANDARD_TEXT_FONT, sumSz, "OUTLINE")
                sumFS:SetTextColor(1, 0.88, 0.35)
                sumFS:SetText(tostring(rollSum))
                sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", 0, 10)
                sumFS:SetAlpha(0); sumFS:Show()
                OmegaDice.FadeAlpha(sumFS, 0, 1, SEQ_FADE_DUR, function()
                    if OmegaDice.animId ~= animId then return end
                    if modifier ~= 0 then
                        local modSz = math.max(math.floor(sumSz*0.68), 22)
                        C_Timer.After(SEQ_HOLD_MOD, function()
                            if OmegaDice.animId ~= animId then return end
                            local shift = modSz * 1.15
                            sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", -shift, 10)
                            local sign = modifier > 0 and "+" or ""
                            modFS:SetFont(STANDARD_TEXT_FONT, modSz, "OUTLINE")
                            modFS:SetText(sign..tostring(modifier))
                            modFS:ClearAllPoints(); modFS:SetPoint("LEFT", sumFS, "RIGHT", 6, 0)
                            modFS:SetAlpha(0); modFS:Show()
                            OmegaDice.FadeAlpha(modFS, 0, 1, SEQ_FADE_DUR)
                            C_Timer.After(SEQ_HOLD_MOD, function()
                                if OmegaDice.animId ~= animId then return end
                                OmegaDice.FadeAlpha(sumFS, 1, 0, SEQ_FADE_DUR)
                                OmegaDice.FadeAlpha(modFS, 1, 0, SEQ_FADE_DUR, function()
                                    if OmegaDice.animId ~= animId then return end
                                    modFS:Hide()
                                    sumFS:ClearAllPoints(); sumFS:SetPoint("CENTER", frame, "CENTER", 0, 10)
                                    sumFS:SetText(tostring(total))
                                    OmegaDice.FadeAlpha(sumFS, 0, 1, SEQ_FADE_DUR, onDone)
                                end)
                            end)
                        end)
                    else
                        if onDone then onDone() end
                    end
                end)
            end
        end)
    end)
end

-- ─── Main entry point ─────────────────────────────────────────────────────────
function OmegaDice.PlayD20Animation(rolls, total, modifier, description, minPerDie, maxPerDie, diceLabel, onComplete)
    -- ── Flat animation (always — routing to wireframe is done by RollDice.lua) ──
    local n        = math.min(#rolls, MAX_DICE)
    local isSingle = (n == 1)
    local trimDesc = OmegaDice.Trim(description)
    local frameW   = FRAME_W[n] or FRAME_W[MAX_DICE]
    local fontSize = DIE_FONT[n] or DIE_FONT[MAX_DICE]

    -- Cancel any running animation and wipe all stale visuals from the shared frame
    OmegaDice.animId = (OmegaDice.animId or 0) + 1
    local animId = OmegaDice.animId
    OmegaDice.ResetDiceFrame()

    local frame = GetFlatFrame()
    frame:SetSize(frameW, FRAME_H)
    frame:SetScale(1)
    frame.elapsed     = 0
    frame.tickElapsed = 0

    local xOffsets = {}
    for i = 1, MAX_DICE do
        local dv = frame.dieValues[i]
        dv:ClearAllPoints()
        if i <= n then
            local xOff = frameW * (2*i - 1 - n) / (2*n)
            xOffsets[i] = xOff
            local yOff = isSingle and 4 or 10
            dv:SetPoint("CENTER", frame, "CENTER", xOff, yOff)
            dv:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
            dv:SetTextColor(1, 0.88, 0.35)
            dv:SetText(tostring(math.random(minPerDie, maxPerDie)))
            dv:SetAlpha(1)
            dv:Show()
        end
        -- dv:Hide() already done by ResetDiceFrame for i > n
    end

    frame.detail:ClearAllPoints()
    frame.detail:SetPoint("TOP", frame.dieValues[1], "BOTTOM", 0, -2)
    frame.detail:SetText("")
    frame.topLabel:SetText(diceLabel)
    frame.footer:SetText("Lancement...")
    frame:Show()

    frame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed     = self.elapsed + elapsed
        self.tickElapsed = self.tickElapsed + elapsed

        if self.tickElapsed >= ROLL_TICK then
            self.tickElapsed = 0
            for i = 1, n do
                self.dieValues[i]:SetText(tostring(math.random(minPerDie, maxPerDie)))
            end
            local progress = math.min(self.elapsed / ANIMATION_DURATION, 1)
            self:SetScale(MIN_SCALE + (MAX_SCALE-MIN_SCALE)*(1-progress))
        end

        if self.elapsed >= ANIMATION_DURATION then
            self:SetScript("OnUpdate", nil)
            self:SetScale(1)

            local rollSum = 0
            local allMax, allMin = true, true
            for i = 1, n do
                local rv = rolls[i]
                rollSum = rollSum + rv
                if rv ~= maxPerDie then allMax = false end
                if rv ~= minPerDie then allMin = false end
                local dv = self.dieValues[i]
                dv:SetText(tostring(rv))
                local r, g, b = OmegaDice.RollColor(rv, minPerDie, maxPerDie)
                dv:SetTextColor(r, g, b)
            end

            -- Top label : same style as wireframe
            if modifier ~= 0 then
                self.topLabel:SetText("Jet : "..tostring(rollSum).."  |  Mod. : "..tostring(modifier))
            else
                self.topLabel:SetText("Jet : "..tostring(rollSum))
            end

            if allMax then self.footer:SetText("Critique !")
            elseif allMin then self.footer:SetText("Echec critique")
            else self.footer:SetText(trimDesc ~= "" and trimDesc or "Resultat") end

            self.detail:SetText("")

            if onComplete then onComplete() end

            local function startHold()
                C_Timer.After(RESULT_HOLD_DURATION, function()
                    if OmegaDice.animId ~= animId then return end
                    frame:Hide()
                end)
            end

            if isSingle and modifier ~= 0 then
                local dv = self.dieValues[1]
                PlayFlatSingleSequence(self, dv, xOffsets[1], rolls[1], total, modifier, fontSize, animId, startHold)
            elseif not isSingle then
                PlayFlatMultiSequence(self, self.dieValues, xOffsets, n, rollSum, total, modifier, fontSize, animId, startHold)
            else
                self.dieValues[1]:SetText(tostring(total))
                startHold()
            end
        end
    end)
end
