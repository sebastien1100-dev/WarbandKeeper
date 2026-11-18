local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Curseur : traînée scintillante derrière la souris (section « Curseur » de QoL, module « cursor »).
-- Trois styles :
--   sparks = étincelles (étoiles à 4 branches qui scintillent et rapetissent)
--   comet  = comète (ruban de halos qui s'affine, quelques éclats blancs)
--   dust   = poussière d'étoiles (paillettes de teintes variées qui tombent en s'éteignant)
-- Une réserve fixe de textures recyclées, posées sur UIParent sans prendre la souris ; rien n'est émis
-- quand la souris ne bouge pas. Réglages dans UI.CursorConfig() (trail, trailStyle, trailColor, trailLen,
-- trailDensity, trailNoCombat).
local MAX = 120
local TEX = { spark = UI.MEDIA .. "fxspark", halo = UI.MEDIA .. "fxhalo", dot = UI.MEDIA .. "circle" }

local function cfg() return UI.CursorConfig() end
local function on() return WK:FeatureOn("cursor") end

local host, pool, live = nil, {}, 0
local lastX, lastY, testT, testing
local rng = math.random

-- couleur d'une particule (arc-en-ciel : teinte qui tourne avec le temps)
local function hsv(h)
    local i = math.floor(h * 6) % 6
    local f = h * 6 - math.floor(h * 6)
    local q, t = 1 - f, f
    if i == 0 then return 1, t, 0 elseif i == 1 then return q, 1, 0 elseif i == 2 then return 0, 1, t
    elseif i == 3 then return 0, q, 1 elseif i == 4 then return t, 0, 1 end
    return 1, 0, q
end
local function baseColor()
    local c = cfg().trailColor
    if c == "class" then
        local _, class = UnitClass("player")
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc then return cc.r, cc.g, cc.b end
    elseif c == "gold" then return C.gold[1], C.gold[2], C.gold[3]
    elseif c == "white" then return 1, 1, 1
    elseif c == "rainbow" then return hsv((GetTime() * 0.35) % 1) end
    return UI:Accent()
end

local function build()
    if host then return end
    host = CreateFrame("Frame", nil, UIParent)
    host:SetAllPoints(UIParent)
    host:SetFrameStrata("TOOLTIP")
    host:EnableMouse(false)
    host.wk = true
    for i = 1, MAX do
        local t = host:CreateTexture(nil, "OVERLAY")
        t:SetBlendMode("ADD")
        t:Hide()
        pool[i] = { tex = t, alive = false }
    end
end

local function emit(x, y, kind, size, life, r, g, b, vx, vy, twinkle)
    -- une particule libre, sinon la plus vieille
    local p, oldest
    for i = 1, MAX do
        local q = pool[i]
        if not q.alive then p = q break end
        if not oldest or q.age / q.life > oldest.age / oldest.life then oldest = q end
    end
    p = p or oldest
    if not p.alive then live = live + 1 end
    p.alive, p.x, p.y, p.size, p.life, p.age = true, x, y, size, life, 0
    p.vx, p.vy, p.twinkle, p.phase = vx or 0, vy or 0, twinkle, rng() * 6.28
    p.tex:SetTexture(TEX[kind])
    p.tex:SetVertexColor(r, g, b, 1)
    p.tex:Show()
end

-- particules pour un déplacement de (x0, y0) à (x1, y1), en coordonnées de UIParent
local function spawn(x0, y0, x1, y1)
    local c = cfg()
    local dist = math.sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
    if dist < 1 then return end
    local life = (c.trailLen or 600) / 1000
    local dens = (c.trailDensity or 60) / 100
    local r, g, b = baseColor()
    local style = c.trailStyle or "sparks"
    if style == "comet" then
        -- ruban : un halo tous les ~6 px, éclat blanc de temps en temps
        local n = math.min(10, math.max(1, math.floor(dist / 6)))
        for k = 1, n do
            local f = k / n
            emit(x0 + (x1 - x0) * f, y0 + (y1 - y0) * f, "halo", 22, life, r, g, b)
        end
        if rng() < 0.35 * dens then emit(x1 + (rng() - 0.5) * 8, y1 + (rng() - 0.5) * 8, "spark", 10 + rng() * 6, life * 0.7, 1, 1, 1, 0, 0, true) end
    elseif style == "dust" then
        local n = math.min(6, math.max(1, math.floor(dist / 9 * dens + rng())))
        for _ = 1, n do
            local f = rng()
            local pr, pg, pb = r, g, b
            local pick = rng()
            if pick < 0.25 then pr, pg, pb = C.gold[1], C.gold[2], C.gold[3] elseif pick < 0.4 then pr, pg, pb = 1, 1, 1 end
            emit(x0 + (x1 - x0) * f + (rng() - 0.5) * 10, y0 + (y1 - y0) * f + (rng() - 0.5) * 10, "dot", 3 + rng() * 4, life * (0.8 + rng() * 0.6),
                pr, pg, pb, (rng() - 0.5) * 12, -(20 + rng() * 30), true)
        end
        if rng() < 0.15 * dens then emit(x1, y1, "spark", 10 + rng() * 6, life * 0.6, 1, 1, 1, 0, -15, true) end
    else
        local n = math.min(5, math.max(1, math.floor(dist / 12 * dens + rng())))
        for _ = 1, n do
            local f = rng()
            local white = rng() < 0.25
            emit(x0 + (x1 - x0) * f + (rng() - 0.5) * 12, y0 + (y1 - y0) * f + (rng() - 0.5) * 12, "spark", 10 + rng() * 12, life * (0.7 + rng() * 0.5),
                white and 1 or r, white and 1 or g, white and 1 or b, (rng() - 0.5) * 10, (rng() - 0.5) * 10, true)
        end
    end
end

local function update(_, el)
    local c = cfg()
    local want = (testing or (c.trail and on())) and not (c.trailNoCombat and InCombatLockdown and InCombatLockdown())
    -- position : souris, ou cercle pendant le test du mode édition
    local scale = UIParent:GetEffectiveScale()
    local x, y
    if testing then
        testT = testT + el
        local w, h = UIParent:GetWidth(), UIParent:GetHeight()
        x, y = w / 2 + math.cos(testT * 3) * 140, h / 2 + math.sin(testT * 3) * 90
    else
        local cx, cy = GetCursorPosition()
        x, y = cx / scale, cy / scale
    end
    if want and lastX and not (IsMouselooking and IsMouselooking() and not testing) then spawn(lastX, lastY, x, y) end
    lastX, lastY = x, y
    if live == 0 then return end
    for i = 1, MAX do
        local p = pool[i]
        if p.alive then
            p.age = p.age + el
            local k = p.age / p.life
            if k >= 1 then
                p.alive = false; p.tex:Hide(); live = live - 1
            else
                p.x, p.y = p.x + p.vx * el, p.y + p.vy * el
                local a = 1 - k
                if p.twinkle then a = a * (0.55 + 0.45 * math.sin(p.age * 24 + p.phase)) end
                local s = p.size * (1 - k * 0.7)
                p.tex:SetSize(s, s)
                p.tex:ClearAllPoints()
                p.tex:SetPoint("CENTER", UIParent, "BOTTOMLEFT", p.x, p.y)
                p.tex:SetAlpha(a)
            end
        end
    end
end

UI.CursorTrailStep = update -- (pour les tests)
UI.CursorTrailLive = function() return live end

function UI:SyncCursorTrail()
    local c = cfg()
    if (c.trail and on()) or testing then
        build()
        host:SetScript("OnUpdate", update)
        host:Show()
    elseif host then
        host:SetScript("OnUpdate", nil)
        for i = 1, MAX do pool[i].alive = false; pool[i].tex:Hide() end
        live, lastX, lastY = 0, nil, nil
        host:Hide()
    end
end

WK:On("PLAYER_ENTERING_WORLD", function() UI:SyncCursorTrail() end)
-- bouton « Tester » du mode édition : la traînée tourne en cercle au milieu de l'écran
UI:RegisterHUDTest(function()
    testing, testT, lastX, lastY = true, 0, nil, nil
    UI:SyncCursorTrail()
end, function()
    testing = nil
    lastX, lastY = nil, nil
    UI:SyncCursorTrail()
end)
