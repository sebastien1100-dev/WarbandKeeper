local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Tracé du trajet de navigation (Modules/Nav.lua) : pointillés de la couleur d'accent, de toi
-- jusqu'au lieu guidé, sur la carte du monde (appelé par UI/MapPins.lua) et sur la minicarte.
-- Les étapes de vol sont en tirets plus espacés et plus pâles.
local N = WK.modules.Nav
local MAX_MAP, MAX_MINI = 1200, 160

local function gcfg() return WK.modules.Guide:Config() end

-- Points restants du trajet (monde), depuis la position du perso : { { x, y, fly } }
local function remaining()
    local r = N.route
    if not r then return nil end
    local G = WK.modules.Guide
    local p = G:PlayerPos()
    local out = {}
    if p and p.cont == r.cont then out[1] = { p.wx, p.wy } end
    for li = r.leg or 1, #r.legs do
        local l = r.legs[li]
        if l.kind == "walk" then
            local start = (li == r.leg) and (r.idx or 1) or 1
            for k = start, #l.pts / 2 do out[#out + 1] = { l.pts[k * 2 - 1], l.pts[k * 2] } end
        elseif l.kind == "fly" then
            out[#out + 1] = { l.ax, l.ay }
            out[#out + 1] = { l.bx, l.by, true } -- le segment qui arrive ici est un vol
        end
    end
    return out, r.cont
end

---------------------------------------------------------------------------
-- Carte du monde
---------------------------------------------------------------------------
local mapDots = {}
local function mapDot(i, cv)
    local d = mapDots[i]
    if not d then
        d = cv:CreateTexture(nil, "OVERLAY", nil, 6)
        d:SetTexture(UI.MEDIA .. "circle")
        mapDots[i] = d
    end
    if d:GetParent() ~= cv then d:SetParent(cv) end
    return d
end
function UI:HideNavRoute()
    for _, d in ipairs(mapDots) do d:Hide() end
end
local function toMap(cont, x, y, mapID)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(x, y), mapID)
    if not ok or not pos then return nil end
    local mx, my = pos.x, pos.y
    if pos.GetXY then mx, my = pos:GetXY() end
    return mx, my
end
function UI:DrawNavRoute(cv, mapID, w, h)
    UI:HideNavRoute()
    if not gcfg().route then return end
    local pts, cont = remaining()
    if not pts or #pts < 2 then return end
    local r, g, b = UI:Accent()
    local scale = w / 1000
    local size = math.max(3, 5 * scale)
    local gap = math.max(6, 11 * scale)
    local n = 0
    local px, py
    for i, pt in ipairs(pts) do
        local mx, my = toMap(cont, pt[1], pt[2], mapID)
        if mx then
            local x, y = mx * w, my * h
            if px then
                local fly = pt[3]
                local dx, dy = x - px, y - py
                local len = math.sqrt(dx * dx + dy * dy)
                local step = fly and gap * 2.2 or gap
                local inside = (mx > -0.05 and mx < 1.05 and my > -0.05 and my < 1.05) or (px > -0.05 * w and px < 1.05 * w and py > -0.05 * h and py < 1.05 * h)
                if len > 0 and inside then
                    local k = 0
                    while k < len and n < MAX_MAP do
                        n = n + 1
                        local d = mapDot(n, cv)
                        local s = fly and size * 0.8 or size
                        d:SetSize(s, s)
                        d:SetVertexColor(r, g, b, fly and 0.55 or 0.95)
                        d:ClearAllPoints()
                        d:SetPoint("CENTER", cv, "TOPLEFT", px + dx * k / len, -(py + dy * k / len))
                        d:Show()
                        k = k + step
                    end
                end
            end
            px, py = x, y
        else
            px, py = nil, nil
        end
        if n >= MAX_MAP then break end
    end
end

---------------------------------------------------------------------------
-- Minicarte
---------------------------------------------------------------------------
local holder, miniDots = nil, {}
local RADIUS_OUT = { [0] = 233.3, 200, 166.7, 133.3, 100, 66.7 }
local RADIUS_IN = { [0] = 150, 120, 90, 60, 40, 25 }
local function viewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, rr = pcall(C_Minimap.GetViewRadius)
        if ok and type(rr) == "number" and rr > 0 then return rr end
    end
    local zoom = Minimap.GetZoom and Minimap:GetZoom() or 0
    return ((IsIndoors and IsIndoors()) and RADIUS_IN or RADIUS_OUT)[zoom] or 233.3
end
local function miniDot(i)
    local d = miniDots[i]
    if not d then
        d = holder:CreateTexture(nil, "OVERLAY")
        d:SetTexture(UI.MEDIA .. "circle")
        miniDots[i] = d
    end
    return d
end
local function updateMini()
    for _, d in ipairs(miniDots) do d:Hide() end
    if not gcfg().routeMini or not Minimap:IsVisible() then return end
    local pts, cont = remaining()
    if not pts or #pts < 2 then return end
    local G = WK.modules.Guide
    local p = G:PlayerPos()
    if not (p and p.cont == cont) then return end
    local radius = viewRadius()
    local limit = radius * 0.94
    local half = Minimap:GetWidth() / 2
    local rotate = GetCVar and GetCVar("rotateMinimap") == "1"
    local facing = rotate and GetPlayerFacing and GetPlayerFacing() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local r, g, b = UI:Accent()
    local spacing = radius / 14
    local n = 0
    for i = 2, #pts do
        local a, c = pts[i - 1], pts[i]
        local fly = c[3]
        local len = N.Dist(a[1], a[2], c[1], c[2])
        local k = 0
        while k < len and n < MAX_MINI do
            local x = a[1] + (c[1] - a[1]) * k / len
            local y = a[2] + (c[2] - a[2]) * k / len
            -- monde : x vers le nord, y vers l'ouest ; écran : dx vers l'est, dy vers le nord
            local dx, dy = -(y - p.wy), x - p.wx
            if dx * dx + dy * dy < limit * limit then
                if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
                n = n + 1
                local d = miniDot(n)
                local s = fly and 3 or 4
                d:SetSize(s, s)
                d:SetVertexColor(r, g, b, fly and 0.5 or 0.95)
                d:ClearAllPoints()
                d:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
                d:Show()
            end
            k = k + (fly and spacing * 2 or spacing)
        end
        if n >= MAX_MINI then break end
    end
end

function UI:RefreshNavRoute()
    if WK.modules.Guide.Redraw then WK.modules.Guide:Redraw() end
    if holder then updateMini() end
end

WK:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function()
        if Minimap and not holder then
            holder = CreateFrame("Frame", "WarbandKeeperNavRoute", Minimap)
            holder:SetAllPoints(Minimap)
            holder:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3)
            holder.acc, holder.mapAcc = 0, 0
            holder:SetScript("OnUpdate", function(s, el)
                s.acc, s.mapAcc = s.acc + el, s.mapAcc + el
                -- carte du monde ouverte : le tracé suit le perso (une fois par seconde)
                if s.mapAcc > 1 and WorldMapFrame and WorldMapFrame:IsShown() and UI.RefreshGuidePinLabel then
                    UI:RefreshGuidePinLabel()
                end
                if s.mapAcc > 1 and N.route and WorldMapFrame and WorldMapFrame:IsShown() then
                    s.mapAcc = 0
                    local cv = WorldMapFrame.ScrollContainer and WorldMapFrame.ScrollContainer.Child
                    local mapID = WorldMapFrame.GetMapID and WorldMapFrame:GetMapID()
                    if cv and mapID and (cv:GetWidth() or 0) > 0 then UI:DrawNavRoute(cv, mapID, cv:GetWidth(), cv:GetHeight()) end
                end
                if s.mapAcc > 1 then s.mapAcc = 0 end
                if s.acc < 0.15 then return end
                s.acc = 0
                updateMini()
            end)
        end
    end)
end)
