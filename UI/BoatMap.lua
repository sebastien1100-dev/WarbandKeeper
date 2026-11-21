local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Tracés des lignes de bateaux et de zeppelins sur la carte du monde (Modules/BoatLines.lua) : trait fin, plus
-- marqué pour une ligne déjà prise. Aucun horaire, aucun navire qui avance.
-- Réglage Guide:Config().shipsMap ; calque « Bateaux » de la carte (MapLayers:Config().map.transport).
local BL = function() return WK.modules.BoatLines end
local lines = UI:LinePool(3)

local function on()
    local L = WK.modules.MapLayers
    return WK:FeatureOn("maplayers") and L and L:Config().map.transport and WK.modules.Guide:Config().shipsMap ~= false
end
local function toMapRaw(c, x, y, mapID)
    -- conversion commune (UI/NavRoute.lua) : elle sait passer par le continent sur la carte d'Azeroth
    if UI.WorldToMap then return UI.WorldToMap(c, x, y, mapID) end
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, c, CreateVector2D(x, y), mapID)
    if not (ok and pos) then return nil end
    local mx, my = pos.x, pos.y
    if pos.GetXY then mx, my = pos:GetXY() end
    return mx, my
end
-- Projections gardées par carte : les tracés des navires sont fixes, seuls les reports sur la carte coûtent
-- (jusqu'à 3 appels au jeu par point) ; avant, tout était reprojeté à chaque redessin de la carte
local proj, projMaps = {}, 0
local function toMap(c, x, y, mapID)
    local pm = proj[mapID]
    if not pm then
        if projMaps >= 12 then proj, projMaps = {}, 0 end
        pm = {}
        proj[mapID] = pm
        projMaps = projMaps + 1
    end
    local key = c .. ":" .. x .. ":" .. y
    local v = pm[key]
    if v == nil then
        local mx, my = toMapRaw(c, x, y, mapID)
        v = mx and { mx, my } or false
        pm[key] = v
    end
    if v then return v[1], v[2] end
    return nil
end
local function colorOf(l)
    if l.kind == "zeppelin" then return C.warning end
    local L = WK.modules.MapLayers
    local tl = L and L.LAYER and L.LAYER.transport
    return (tl and L.FAMILY[tl.family] and L.FAMILY[tl.family].color) or C.positive
end

-- Calque « Navires » de la carte du monde (UI/MapPins.lua)
function UI:DrawShips(cv, mapID, w, h)
    lines:Reset()
    if not on() then return end
    if UI.MapLineLayer then cv = UI.MapLineLayer(cv) end -- au-dessus des calques du jeu
    local B = BL()
    local scale = (w / 1000) * UI.MapIconScale()
    local thick = math.max(1.4 * UI.MapIconScale(), 2 * scale)
    -- carte d'Azeroth : les deux continents y sont, le saut d'un continent à l'autre est tracé aussi
    local world = UI.IsWorldMap and UI.IsWorldMap(mapID)
    local drawn = {}
    for _, l in ipairs(B:All()) do
        -- toutes les lignes (avant : seulement celles déjà prises) ; une ligne pas encore prise est plus pâle
        if B:Mine(l) or not WK.modules.MapLayers:Config().myFaction then
            local col = colorOf(l)
            local rode = B:Rode(l)
            local a, tk = rode and 0.75 or 0.4, rode and thick or thick * 0.8
            for _, g in ipairs(l.legs) do
                local pts = g.pts
                local px, py, pc
                -- carte d'Azeroth, étape d'un continent à l'autre : les points du « saut » du jeu tombent
                -- n'importe où une fois reportés ; on trace un arc net d'un quai à l'autre, une fois par paire
                local crosses = false
                if world then
                    for k = 2, #pts / 3 do if pts[k * 3 - 2] ~= pts[1] then crosses = true break end end
                end
                if crosses then
                    local n3 = #pts / 3
                    local ax, ay = toMap(pts[1], pts[2], pts[3], mapID)
                    local bx, by = toMap(pts[n3 * 3 - 2], pts[n3 * 3 - 1], pts[n3 * 3], mapID)
                    local key = ax and bx and string.format("%d:%d:%d:%d", math.floor(math.min(ax, bx) * 200), math.floor(math.min(ay, by) * 200),
                        math.floor(math.max(ax, bx) * 200), math.floor(math.max(ay, by) * 200))
                    if key and not drawn[key] then
                        drawn[key] = true
                        -- arc : courbe de Bézier dont le sommet s'écarte de 12 % de la longueur
                        local dx, dy = bx - ax, by - ay
                        local cx, cy = (ax + bx) / 2 - dy * 0.12, (ay + by) / 2 + dx * 0.12
                        local qx, qy = ax, ay
                        for i = 1, 12 do
                            local t = i / 12
                            local u = 1 - t
                            local nx = u * u * ax + 2 * u * t * cx + t * t * bx
                            local ny = u * u * ay + 2 * u * t * cy + t * t * by
                            lines:Add(cv, qx * w, qy * h, nx * w, ny * h, tk, col[1], col[2], col[3], a)
                            qx, qy = nx, ny
                        end
                    end
                    pts = {} -- rien d'autre à tracer pour cette étape
                end
                -- ligne pas encore prise : un point sur trois suffit (moins de traits à poser)
                local n3 = #pts / 3
                for k = 1, n3 do
                  if rode or k % 3 == 1 or k == n3 or (k > 1 and pts[k * 3 - 2] ~= pts[k * 3 - 5]) then
                    local c, x, y = pts[k * 3 - 2], pts[k * 3 - 1], pts[k * 3]
                    local mx, my = toMap(c, x, y, mapID)
                    local inside = mx and mx > -0.05 and mx < 1.05 and my > -0.05 and my < 1.05
                    if inside and px and pc == c then
                        lines:Add(cv, px * w, py * h, mx * w, my * h, tk, col[1], col[2], col[3], a)
                    end
                    if inside then px, py, pc = mx, my, c else px, py, pc = nil, nil, nil end
                  end
                end
            end
        end
    end
end

-- carte fermée ou redessin interrompu : tracés effacés
function UI:HideShips()
    lines:Reset()
end
-- (minicarte : plus de navire affiché, les horaires sont retirés)
function UI:RefreshMiniShips() end
