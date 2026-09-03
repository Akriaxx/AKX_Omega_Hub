-- ============================================================
--  Zone Gate — Radar d'édition
--  Vue égocentrique (rotative) : l'avant du joueur pointe
--  toujours vers le haut, comme une minimap en mode "rotation
--  joueur" — avec un repère "N" qui tourne pour indiquer le nord
--  du monde, comme le fait la minimap Blizzard dans ce mode.
--  Zoom fixe par paliers, piloté par le zoom caméra du joueur
--  (pas d'adaptatif en continu).
-- ============================================================

local ZG = ZoneGate
local UI = OS2.UI

local SIZE      = 160
local ARROW_OFF = 12    -- décalage des flèches de sens depuis le centre de la porte (px)
local REFRESH   = 0.1   -- throttle de l'OnUpdate

-- Convention de coordonnées monde WoW (connue des addons de waypoints type
-- TomTom) : +X pointe vers le sud, +Y vers l'ouest. Le nord est donc -X.
local NORTH_WX, NORTH_WY = -1, 0

-- Paliers fixes de zoom (px/yard), pilotés par la molette (zoom caméra du
-- joueur, GetCameraZoom() — 0 = vue épaule, ~2.6 = distance max par
-- défaut). Seuils absolus (pas normalisés sur un cvar perso) : ça répond
-- directement à chaque cran de molette dans la plage de jeu habituelle,
-- sans être noyé par un cvar de distance max personnalisé très large.
-- Pas d'interpolation continue : on saute d'un palier à l'autre.
local ZOOM_TIERS = { 10, 7, 5, 3 }
local ZOOM_BREAKS = { 0.65, 1.3, 2.0 }   -- 3 seuils → 4 paliers

local function CameraZoomTier()
    local zoom = GetCameraZoom() or ZOOM_BREAKS[2]
    for i, threshold in ipairs(ZOOM_BREAKS) do
        if zoom < threshold then return ZOOM_TIERS[i] end
    end
    return ZOOM_TIERS[#ZOOM_TIERS]
end

-- Rotation pure d'un vecteur (pas de translation) : sert à la fois pour les
-- décalages et pour les directions, en mode égocentrique. Le résultat est
-- mirroré sur X (constaté en jeu : gauche/droite étaient inversés — la
-- convention de sens de GetPlayerFacing() est donc opposée à celle
-- supposée initialement). Comme absolument tout ce qui bouge sur le radar
-- passe par cette fonction, corriger ici suffit à tout remettre d'aplomb
-- (position du checkpoint, flèches de sens, repère N).
local function Rotate(dx, dy, delta)
    local c, s = math.cos(delta), math.sin(delta)
    local rx = dx * c - dy * s
    local ry = dx * s + dy * c
    return -rx, ry
end

-- Crée un radar autonome. `checkpointGetter` doit renvoyer le checkpoint
-- actuellement édité (table brute de ZoneGateDB.checkpoints), ou nil.
function ZG.CreateRadar(parent, checkpointGetter)
    local radar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    radar:SetSize(SIZE, SIZE)

    local bg = radar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    UI.ApplyWindowBackground(bg, 0.85)
    UI.ApplyBorder(radar)

    -- Réticule central, purement décoratif
    local crosshairV = radar:CreateTexture(nil, "ARTWORK")
    crosshairV:SetPoint("TOP", radar, "TOP", 0, 0)
    crosshairV:SetPoint("BOTTOM", radar, "BOTTOM", 0, 0)
    crosshairV:SetWidth(1)
    UI.ApplySeparator(crosshairV, true)

    local crosshairH = radar:CreateTexture(nil, "ARTWORK")
    crosshairH:SetPoint("LEFT", radar, "LEFT", 0, 0)
    crosshairH:SetPoint("RIGHT", radar, "RIGHT", 0, 0)
    crosshairH:SetHeight(1)
    UI.ApplySeparator(crosshairH, true)

    -- Joueur : point fixe au centre. En mode égocentrique son "avant" pointe
    -- toujours vers le haut, donc pas besoin de flèche de facing pour lui.
    local playerDot = radar:CreateTexture(nil, "OVERLAY")
    playerDot:SetSize(7, 7)
    playerDot:SetPoint("CENTER")
    playerDot:SetColorTexture(0.95, 0.90, 0.60, 1)

    local playerArrow = radar:CreateTexture(nil, "OVERLAY")
    playerArrow:SetSize(14, 14)
    playerArrow:SetPoint("CENTER", playerDot, "CENTER", 0, 10)
    playerArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    playerArrow:SetVertexColor(1, 1, 1, 0.95)

    -- Repère "N" : tourne autour du bord du radar pour indiquer le nord du
    -- monde, comme la minimap Blizzard en mode "rotation joueur".
    local northLabel = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    northLabel:SetText("N")
    northLabel:SetTextColor(0.90, 0.78, 0.30, 1)

    -- Ligne de porte (segment perpendiculaire au sens "entrée", longueur = largeur)
    local gateLine = radar:CreateTexture(nil, "ARTWORK")
    gateLine:SetHeight(3)
    gateLine:SetColorTexture(0.85, 0.75, 0.40, 0.95)
    gateLine:Hide()

    -- Checkpoint "cercle" : pas de vraie échelle possible (le rayon peut
    -- dépasser largement la fenêtre du radar) — juste un pictogramme rond au
    -- centre du checkpoint pour le différencier visuellement d'une ligne.
    local circleIcon = radar:CreateTexture(nil, "ARTWORK")
    circleIcon:SetSize(22, 22)
    circleIcon:SetColorTexture(0.85, 0.75, 0.40, 0.45)
    -- AddMaskTexture exige un vrai objet MaskTexture (CreateMaskTexture sur
    -- le FRAME, pas sur la texture) — d'où le plantage "Wrong object type".
    local circleMask = radar:CreateMaskTexture(nil, "ARTWORK")
    circleMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    circleMask:SetAllPoints(circleIcon)   -- ancrage relatif : suit circleIcon en continu
    circleIcon:AddMaskTexture(circleMask)
    circleIcon:Hide()

    -- Checkpoint "région" (polygon) : contour approximatif — un point par
    -- sommet (clampé au bord du radar comme le reste), relié par des
    -- segments. Pool fixe réutilisé d'un rafraîchissement à l'autre (pas de
    -- CreateTexture en boucle). La boucle de fermeture (dernier → premier)
    -- n'apparaît que si la région est validée (regionReady) — sinon le
    -- contour reste ouvert, pour montrer visuellement qu'elle ne l'est pas
    -- encore.
    local MAX_REGION_POINTS = 20
    local regionDots, regionSegments = {}, {}
    for i = 1, MAX_REGION_POINTS do
        local dot = radar:CreateTexture(nil, "OVERLAY")
        dot:SetSize(6, 6)
        dot:SetColorTexture(0.85, 0.75, 0.40, 0.95)
        dot:Hide()
        regionDots[i] = dot

        local seg = radar:CreateTexture(nil, "ARTWORK")
        seg:SetHeight(2)
        seg:SetColorTexture(0.85, 0.75, 0.40, 0.75)
        seg:Hide()
        regionSegments[i] = seg
    end

    local function HideRegion()
        for i = 1, MAX_REGION_POINTS do
            regionDots[i]:Hide()
            regionSegments[i]:Hide()
        end
    end

    -- Positionne un segment (texture fine) entre deux points déjà en
    -- coordonnées radar (offsets depuis le centre). Cache le segment si les
    -- deux points sont confondus (rotation indéfinie).
    local function PositionSegment(seg, x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 0.5 then seg:Hide(); return end
        seg:ClearAllPoints()
        seg:SetPoint("CENTER", radar, "CENTER", (x1 + x2) / 2, (y1 + y2) / 2)
        seg:SetWidth(len)
        seg:SetRotation(math.atan2(dy, dx))
        seg:Show()
    end

    -- Flèches + libellés de sens
    local fwdArrow = radar:CreateTexture(nil, "OVERLAY")
    fwdArrow:SetSize(12, 12)
    fwdArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    fwdArrow:SetVertexColor(0.40, 0.90, 0.45, 1)
    fwdArrow:Hide()

    local backArrow = radar:CreateTexture(nil, "OVERLAY")
    backArrow:SetSize(12, 12)
    backArrow:SetTexture("Interface\\Minimap\\MinimapArrow")
    backArrow:SetVertexColor(0.90, 0.40, 0.40, 1)
    backArrow:Hide()

    local fwdLabel = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fwdLabel:SetText("ENTRÉE")
    fwdLabel:SetTextColor(0.40, 0.90, 0.45, 1)
    fwdLabel:Hide()

    local backLabel = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    backLabel:SetText("RETOUR")
    backLabel:SetTextColor(0.90, 0.40, 0.40, 1)
    backLabel:Hide()

    -- Distance + statut ("dans la bande"), sous le radar
    local distText = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    distText:SetPoint("TOP", radar, "BOTTOM", 0, -4)
    UI.ApplyMutedText(distText)
    radar.distText = distText

    local statusText = radar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("TOP", distText, "BOTTOM", 0, -2)
    radar.statusText = statusText

    local HALF = SIZE / 2 - 8   -- marge intérieure du radar (rayon utile, en px)

    local function ClampToRadar(dx, dy)
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= HALF or dist == 0 then return dx, dy, false end
        local scale = HALF / dist
        return dx * scale, dy * scale, true
    end

    local function HideGate()
        gateLine:Hide()
        circleIcon:Hide()
        fwdArrow:Hide(); backArrow:Hide()
        fwdLabel:Hide(); backLabel:Hide()
        HideRegion()
        distText:SetText("")
        statusText:SetText("")
    end

    radar.elapsed = 0
    radar:SetScript("OnUpdate", function(self, delta)
        self.elapsed = self.elapsed + delta
        if self.elapsed < REFRESH then return end
        self.elapsed = 0

        local px, py, facing = ZG:GetPlayerPose()
        if not px then
            HideGate()
            northLabel:Hide()
            return
        end

        -- Angle qui remet "l'avant du joueur" vers le haut de l'écran.
        local ego = math.pi / 2 - facing

        local nx, ny = Rotate(NORTH_WX, NORTH_WY, ego)
        local nAngle = math.atan2(ny, nx)
        local ringR = HALF + 6
        northLabel:ClearAllPoints()
        northLabel:SetPoint("CENTER", radar, "CENTER", math.cos(nAngle) * ringR, math.sin(nAngle) * ringR)
        northLabel:Show()

        local cp = checkpointGetter and checkpointGetter() or nil
        if not cp then
            HideGate()
            return
        end

        local scale = CameraZoomTier()

        -- cp.x/cp.y = position du checkpoint (ligne/cercle) ou centroïde des
        -- points (région) — recalculé par Core.lua à chaque ajout/retrait
        -- de point, donc toujours à jour ici.
        local distYards = math.sqrt((cp.x - px) ^ 2 + (cp.y - py) ^ 2)
        local wdx, wdy = cp.x - px, cp.y - py
        local rdx, rdy = Rotate(wdx * scale, wdy * scale, ego)
        local cdx, cdy, clamped = ClampToRadar(rdx, rdy)

        local isPolygon = cp.shape == "polygon"
        local pointCount = isPolygon and cp.points and #cp.points or 0

        if cp.shape == "circle" then
            distText:SetText(string.format("%.0f yd du centre (rayon %.0f yd)%s", distYards, cp.width or 6, clamped and " (hors radar)" or ""))
        elseif isPolygon then
            distText:SetText(string.format("%.0f yd du centre (région, %d points%s)%s",
                distYards, pointCount, cp.regionReady and "" or ", non validée", clamped and " (hors radar)" or ""))
        else
            distText:SetText(string.format("%.0f yd du centre%s", distYards, clamped and " (hors radar)" or ""))
        end

        local inBand, direction = ZG:GetCheckpointStatus(cp)
        local placeWord = isPolygon and "la région" or (cp.shape == "circle" and "le cercle" or "la bande")
        if inBand == nil then
            statusText:SetText("|cff888888autre zone / instance|r")
        elseif inBand then
            if direction == "forward" then
                statusText:SetText("|cff66e673dans " .. placeWord .. " — sens ENTRÉE|r")
            else
                statusText:SetText("|cffe66666dans " .. placeWord .. " — sens RETOUR|r")
            end
        else
            statusText:SetText("|cff888888hors de " .. placeWord .. "|r")
        end

        if isPolygon then
            gateLine:Hide(); circleIcon:Hide()
            fwdArrow:Hide(); backArrow:Hide()
            fwdLabel:Hide(); backLabel:Hide()

            local points = cp.points or {}
            local n = math.min(#points, MAX_REGION_POINTS)
            local rx, ry = {}, {}   -- positions radar (clampées) de chaque sommet

            for i = 1, n do
                local p = points[i]
                local pwdx, pwdy = p.x - px, p.y - py
                local prdx, prdy = Rotate(pwdx * scale, pwdy * scale, ego)
                local pcdx, pcdy = ClampToRadar(prdx, prdy)
                rx[i], ry[i] = pcdx, pcdy

                regionDots[i]:ClearAllPoints()
                regionDots[i]:SetPoint("CENTER", radar, "CENTER", pcdx, pcdy)
                regionDots[i]:Show()
            end
            for i = n + 1, MAX_REGION_POINTS do
                regionDots[i]:Hide()
            end

            local segCount = 0
            for i = 1, n - 1 do
                segCount = segCount + 1
                PositionSegment(regionSegments[segCount], rx[i], ry[i], rx[i + 1], ry[i + 1])
            end
            -- Boucle de fermeture (dernier → premier) : seulement si la
            -- région est validée, sinon le contour reste visiblement ouvert.
            if cp.regionReady and n >= 3 then
                segCount = segCount + 1
                PositionSegment(regionSegments[segCount], rx[n], ry[n], rx[1], ry[1])
            end
            for i = segCount + 1, MAX_REGION_POINTS do
                regionSegments[i]:Hide()
            end
        elseif cp.shape == "circle" then
            -- Pas de sens unique à représenter (dedans = entrée, dehors =
            -- retour, peu importe l'angle) : juste le pictogramme rond.
            gateLine:Hide()
            fwdArrow:Hide(); backArrow:Hide()
            fwdLabel:Hide(); backLabel:Hide()
            HideRegion()

            circleIcon:ClearAllPoints()
            circleIcon:SetPoint("CENTER", radar, "CENTER", cdx, cdy)
            circleIcon:Show()
        else
            circleIcon:Hide()
            HideRegion()

            -- Direction "entrée" du checkpoint, tournée en repère égocentrique.
            local fx, fy = math.cos(cp.facing), math.sin(cp.facing)
            local rfx, rfy = Rotate(fx, fy, ego)
            local lineAngle  = math.atan2(rfy, rfx) + math.pi / 2  -- perpendiculaire au sens "entrée"
            local arrowAngle = math.atan2(rfy, rfx) - math.pi / 2  -- artwork pointe "vers le haut" par défaut

            local halfWidthPx = math.max(3, (cp.width or 6) / 2 * scale)

            -- La ligne ne doit jamais dépasser le cadre du radar, quels que
            -- soient la largeur configurée ou le palier de zoom : on la
            -- raccourcit au besoin (borne conservatrice, inégalité triangulaire).
            local centerDist = math.sqrt(cdx * cdx + cdy * cdy)
            halfWidthPx = math.min(halfWidthPx, math.max(3, HALF - centerDist))

            gateLine:ClearAllPoints()
            gateLine:SetPoint("CENTER", radar, "CENTER", cdx, cdy)
            gateLine:SetWidth(halfWidthPx * 2)
            gateLine:SetRotation(lineAngle)
            gateLine:Show()

            fwdArrow:ClearAllPoints()
            fwdArrow:SetPoint("CENTER", radar, "CENTER", cdx + rfx * ARROW_OFF, cdy + rfy * ARROW_OFF)
            fwdArrow:SetRotation(arrowAngle)
            fwdArrow:Show()

            backArrow:ClearAllPoints()
            backArrow:SetPoint("CENTER", radar, "CENTER", cdx - rfx * ARROW_OFF, cdy - rfy * ARROW_OFF)
            backArrow:SetRotation(arrowAngle + math.pi)
            backArrow:Show()

            fwdLabel:ClearAllPoints()
            fwdLabel:SetPoint("CENTER", fwdArrow, "CENTER", rfx * 16, rfy * 16)
            fwdLabel:Show()

            backLabel:ClearAllPoints()
            backLabel:SetPoint("CENTER", backArrow, "CENTER", -rfx * 16, -rfy * 16)
            backLabel:Show()
        end
    end)

    return radar
end
