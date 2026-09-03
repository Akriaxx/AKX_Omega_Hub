-- ============================================================
--  Zone Gate — Bannière de franchissement
--  Texte de zone façon Blizzard, mais maison (pas de hook sur
--  ZoneTextFrame — trop fragile d'une version à l'autre).
-- ============================================================

local ZG = ZoneGate
local UI = OS2.UI

local HOLD_DURATION = 2.5

local banner = CreateFrame("Frame", "ZoneGateBanner", UIParent)
banner:SetSize(600, 90)
banner:SetPoint("TOP", UIParent, "TOP", 0, -140)
banner:SetFrameStrata("HIGH")
banner:EnableMouse(false)
banner:SetAlpha(0)
banner:Hide()

local lineTop = banner:CreateTexture(nil, "ARTWORK")
lineTop:SetPoint("TOP", banner, "TOP", 0, -6)
lineTop:SetSize(360, 1)
UI.ApplySeparator(lineTop, true)

local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", lineTop, "BOTTOM", 0, -10)
title:SetTextColor(1.00, 0.90, 0.55, 1.00)
-- Agrandi par rapport au template de base pour un vrai effet "bannière".
do
    local fontPath, _, flags = title:GetFont()
    if fontPath then title:SetFont(fontPath, 28, flags) end
end

local sub = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
UI.ApplyMutedText(sub)

local lineBottom = banner:CreateTexture(nil, "ARTWORK")
lineBottom:SetPoint("TOP", sub, "BOTTOM", 0, -10)
lineBottom:SetSize(360, 1)
UI.ApplySeparator(lineBottom, true)

-- ── Animation : fade in → hold → fade out ─────────────────────────────────

local anim = banner:CreateAnimationGroup()

local fadeIn = anim:CreateAnimation("Alpha")
fadeIn:SetFromAlpha(0)
fadeIn:SetToAlpha(1)
fadeIn:SetDuration(0.4)
fadeIn:SetOrder(1)

local hold = anim:CreateAnimation("Alpha")
hold:SetFromAlpha(1)
hold:SetToAlpha(1)
hold:SetDuration(HOLD_DURATION)
hold:SetOrder(2)

local fadeOut = anim:CreateAnimation("Alpha")
fadeOut:SetFromAlpha(1)
fadeOut:SetToAlpha(0)
fadeOut:SetDuration(0.8)
fadeOut:SetOrder(3)

anim:SetScript("OnFinished", function()
    banner:Hide()
end)

-- ── API publique ─────────────────────────────────────────────────────────────

-- Un nouveau déclenchement pendant qu'une bannière est déjà affichée relance
-- simplement l'animation avec le nouveau texte (pas de file d'attente).
function ZG:ShowBanner(zoneName, subName)
    if not zoneName or zoneName == "" then return end

    anim:Stop()
    title:SetText(zoneName)

    if subName and subName ~= "" then
        sub:SetText(subName)
        sub:Show()
    else
        sub:SetText("")
        sub:Hide()
    end

    banner:SetAlpha(0)
    banner:Show()
    anim:Play()
end

function ZG:HideBanner()
    anim:Stop()
    banner:SetAlpha(0)
    banner:Hide()
end
