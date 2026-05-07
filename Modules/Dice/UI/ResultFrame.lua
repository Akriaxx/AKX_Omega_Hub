local OmegaDice = _G.OmegaDice

local GLOW_ALPHA = 0.65

-- ─── Utilities ────────────────────────────────────────────────────────────────
function OmegaDice.FadeAlpha(obj, from, to, duration, onDone)
    obj:SetAlpha(from)
    local t0 = GetTime()
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        local p = math.min((GetTime()-t0)/duration, 1)
        obj:SetAlpha(from + (to-from)*p)
        if p >= 1 then self:SetScript("OnUpdate", nil); if onDone then onDone() end end
    end)
end

function OmegaDice.RollColor(rv, minVal, maxVal)
    if rv == maxVal then return 0.3, 1, 0.45
    elseif rv == minVal then return 1, 0.25, 0.25
    else return 1, 0.88, 0.35 end
end

-- ─── Glow helpers ─────────────────────────────────────────────────────────────
function OmegaDice.CreateGlow(parent)
    local g = {}
    for i = 1, 4 do
        g[i] = parent:CreateTexture(nil, "ARTWORK")
        g[i]:SetBlendMode("ADD")
        g[i]:Hide()
    end
    return g
end

function OmegaDice.GlowAttach(g, fs, gw, gh)
    local hw, hh = gw/2, gh/2
    g[1]:ClearAllPoints(); g[1]:SetPoint("TOPRIGHT",    fs, "CENTER", 0,  hh); g[1]:SetSize(hw, gh)
    g[2]:ClearAllPoints(); g[2]:SetPoint("TOPLEFT",     fs, "CENTER", 0,  hh); g[2]:SetSize(hw, gh)
    g[3]:ClearAllPoints(); g[3]:SetPoint("TOPRIGHT",    fs, "CENTER", hw, 0);  g[3]:SetSize(gw, hh)
    g[4]:ClearAllPoints(); g[4]:SetPoint("BOTTOMRIGHT", fs, "CENTER", hw, 0);  g[4]:SetSize(gw, hh)
end

function OmegaDice.GlowColor(g, r, gv, b)
    local a = GLOW_ALPHA
    g[1]:SetGradientAlpha("HORIZONTAL", 0,0,0,0, r,gv,b,a)
    g[2]:SetGradientAlpha("HORIZONTAL", r,gv,b,a, 0,0,0,0)
    g[3]:SetGradientAlpha("VERTICAL",   0,0,0,0, r,gv,b,a*0.65)
    g[4]:SetGradientAlpha("VERTICAL",   r,gv,b,a*0.65, 0,0,0,0)
end

function OmegaDice.GlowShow(g)        for _,t in ipairs(g) do t:Show()      end end
function OmegaDice.GlowHide(g)        for _,t in ipairs(g) do t:Hide()      end end
function OmegaDice.GlowSetAlpha(g, a) for _,t in ipairs(g) do t:SetAlpha(a) end end

function OmegaDice.FadeGlow(g, from, to, duration, onDone)
    OmegaDice.GlowSetAlpha(g, from)
    local t0 = GetTime()
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self)
        local p = math.min((GetTime()-t0)/duration, 1)
        OmegaDice.GlowSetAlpha(g, from + (to-from)*p)
        if p >= 1 then self:SetScript("OnUpdate", nil); if onDone then onDone() end end
    end)
end

-- ─── Shared backdrop frame ────────────────────────────────────────────────────
local sharedFrame = nil

local function CreateSharedFrame()
    local bdTpl = BackdropTemplateMixin and "BackdropTemplate" or nil
    local f = CreateFrame("Frame", "OmegaDiceFrame", UIParent, bdTpl)
    f:SetFrameStrata("DIALOG")
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile=true, tileSize=16, edgeSize=14,
            insets={left=4,right=4,top=4,bottom=4},
        })
        f:SetBackdropColor(0, 0, 0, 0.95)
        f:SetBackdropBorderColor(0.8, 0.68, 0.35, 1)
    end
    f:Hide()

    f.topLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.topLabel:SetPoint("TOP", f, "TOP", 0, -14)

    f.footer = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.footer:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    f.footer:SetText("")

    f.sumDisplay = f:CreateFontString(nil, "OVERLAY")
    f.sumDisplay:SetFont(STANDARD_TEXT_FONT, 58, "OUTLINE")
    f.sumDisplay:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.sumDisplay:Hide()
    f.sumGlow = OmegaDice.CreateGlow(f)

    f.modDisplay = f:CreateFontString(nil, "OVERLAY")
    f.modDisplay:SetFont(STANDARD_TEXT_FONT, 38, "OUTLINE")
    f.modDisplay:SetTextColor(0.65, 0.75, 1, 1)
    f.modDisplay:Hide()

    return f
end

function OmegaDice.GetDiceFrame()
    if not sharedFrame then sharedFrame = CreateSharedFrame() end
    return sharedFrame
end
