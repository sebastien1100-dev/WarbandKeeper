local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bandeau des bateaux et zeppelins, sans aucun horaire : où va le navire.
--   * au quai (200 m pour apparaître, 260 m pour disparaître, puis encore 5 s) : le navire de ton ponton, la
--     frise de toutes les escales de sa ligne (ton quai à la couleur de l'apparence, la prochaine escale en
--     vert) et les pontons voisins en dessous ;
--   * à bord (Nav.IsRiding) : le navire et la frise, la prochaine escale en vert (ligne reconnue par
--     BoatLines:RideFit, sinon celle du ponton quitté) ;
--   * dans le tram des profondeurs : ses deux stations.
-- Lignes du jeu : Modules/BoatLines.lua ; bateaux appris en jeu : Nav:Boats(). Réglage Guide:Config().dockBanner.
local RANGE_IN, RANGE_OUT, LINGER, W = 200, 260, 5, 360
UI.DockRange = RANGE_IN
local banner

local function BL() return WK.modules.BoatLines end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- Quais proches : { { game = ligne du jeu, s = quai, d } ou { pair = ligne apprise, side, to, kind, d } }
local function nearDock(range)
    local G, L = WK.modules.Guide, WK.modules.MapLayers
    local p = G and G:PlayerPos()
    if not (p and p.cont) then return nil end
    local out = {}
    for _, l in ipairs(BL() and BL():All() or {}) do
        if BL():Mine(l) then
            for s, st in ipairs(l.stops) do
                if st.c == p.cont then
                    local d = dist(st.x, st.y, p.wx, p.wy)
                    if d < range then table.insert(out, { game = l, s = s, kind = l.kind, d = d }) end
                end
            end
        end
    end
    -- bateaux appris en jeu (hors lignes du jeu) ; un quai appris qui double un arrêt d'une ligne du jeu
    -- (moins de 400 m) est ignoré
    local function nearGameStop(c, x, y)
        for _, gl in ipairs(BL() and BL():All() or {}) do
            for _, st in ipairs(gl.stops) do
                if st.c == c and dist(st.x, st.y, x, y) < 400 then return true end
            end
        end
        return false
    end
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    fac = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
    for _, l in ipairs(L and L:AllTransports() or {}) do
        if not l.game and not (l.side and l.side ~= fac) then
            for _, sd in ipairs({ "a", "b" }) do
                local here = l[sd]
                local c, x, y = G.ToWorld(here[1], here[2] / 100, here[3] / 100)
                if c == p.cont and x and not nearGameStop(c, x, y) then
                    local d = dist(x, y, p.wx, p.wy)
                    if d < range then
                        table.insert(out, { pair = l, side = sd, to = (sd == "a" and l.b or l.a)[4], from = here[4], kind = l.kind, d = d })
                    end
                end
            end
        end
    end
    if #out == 0 then return nil end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

-- noms des escales d'une entrée dans l'ordre du trajet, en partant du quai courant : ton quai à gauche,
-- la prochaine escale juste à droite (quai courant et prochaine escale : indices 1 et 2)
local function routeOf(e)
    if e.game then
        local l = e.game
        local n, s = #l.stops, e.s or 1
        local names = {}
        for k = 1, n do names[k] = BL():StopName(l, (s + k - 2) % n + 1) end
        return names, 1, n > 1 and 2 or nil
    end
    return { e.from or "?", e.to or "?" }, 1, 2
end
local function titleOf(e)
    if e.game and e.game.vessel then return T(e.game.vessel) end
    return string.format(e.kind == "zeppelin" and T("Zeppelin pour %s") or T("Bateau pour %s"), e.to or "?")
end

local SAMPLE = {
    { game = { vessel = "Le Bravoure", kind = "boat", stops = { { name = "Port de Menethil" }, { name = "Austrivage" }, { name = "Auberdine" } } }, s = 1, kind = "boat" },
    { game = { vessel = "La Dame Mehley", kind = "boat", stops = { { name = "Port de Menethil" }, { name = "Theramore" } } }, s = 1, kind = "boat" },
}

local MAXN = 4 -- escales dessinées au plus
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDockBanner", UIParent)
    f:SetSize(W, 60)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.icon = UI:Icon(f, "boat", 22, nil, "ARTWORK"); f.icon:SetPoint("TOPLEFT", 14, -14)
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 46, -12); f.title:SetPoint("RIGHT", -14, 0)
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("TOPLEFT", 46, -30); f.sub:SetPoint("RIGHT", -14, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    -- frise des escales : points, traits et noms
    f.dots, f.names, f.segs = {}, {}, {}
    for i = 1, MAXN do
        f.dots[i] = UI:Icon(f, "circle", 12, nil, "ARTWORK")
        f.names[i] = UI:Text(f, 10, C.muted); f.names[i]:SetJustifyH("CENTER"); f.names[i]:SetWidth(90)
        if i < MAXN then f.segs[i] = f:CreateTexture(nil, "BORDER"); f.segs[i]:SetHeight(2) end
    end
    f.sep = f:CreateTexture(nil, "BORDER"); f.sep:SetHeight(1)
    f.rows = {}
    for i = 1, 3 do
        local r = {}
        r.n = UI:Text(f, 11); r.v = UI:Text(f, 10, C.muted); r.v:SetJustifyH("RIGHT")
        f.rows[i] = r
    end

    -- frise : noms des escales, quai courant (bleu) et prochaine escale (vert) ; renvoie le bas de la frise
    function f:Route(names, cur, nx, y)
        local n = math.min(#names, MAXN)
        local x0, x1 = 30, W - 30
        local step = n > 1 and (x1 - x0) / (n - 1) or 0
        for i = 1, MAXN do
            local shown = i <= n
            self.dots[i]:SetShown(shown); self.names[i]:SetShown(shown)
            if self.segs[i] then self.segs[i]:SetShown(i < n) end
            if shown then
                local x = x0 + (i - 1) * step
                local dot = self.dots[i]
                dot:ClearAllPoints(); dot:SetPoint("CENTER", self, "TOPLEFT", x, -(y + 6))
                local nm = self.names[i]
                nm:ClearAllPoints(); nm:SetPoint("TOP", self, "TOPLEFT", x, -(y + 16))
                nm:SetText(names[i])
                if i == cur then
                    dot:SetVertexColor(C.info[1], C.info[2], C.info[3], 1); nm:SetTextColor(C.info[1], C.info[2], C.info[3])
                elseif i == nx then
                    dot:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1); nm:SetTextColor(C.positive[1], C.positive[2], C.positive[3])
                else
                    dot:SetVertexColor(C.border[1], C.border[2], C.border[3], 1); nm:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                end
                local sg = self.segs[i]
                if sg and i < n then
                    sg:ClearAllPoints()
                    sg:SetPoint("LEFT", self, "TOPLEFT", x + 8, -(y + 6)); sg:SetWidth(math.max(1, step - 16))
                    -- trait qui mène à la prochaine escale : vert ; les autres discrets
                    if i + 1 == nx then sg:SetColorTexture(C.positive[1], C.positive[2], C.positive[3], 0.8)
                    else sg:SetColorTexture(C.border[1], C.border[2], C.border[3], 1) end
                end
            end
        end
        return y + 32
    end
    function f:Rows(rows, y)
        self.sep:SetShown(#rows > 0)
        if #rows > 0 then
            self.sep:ClearAllPoints(); self.sep:SetPoint("TOPLEFT", 14, -(y + 4)); self.sep:SetPoint("TOPRIGHT", -14, -(y + 4))
            self.sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            y = y + 10
        end
        for i, r in ipairs(self.rows) do
            local row = rows[i]
            r.n:SetShown(row ~= nil); r.v:SetShown(row ~= nil)
            if row then
                r.n:ClearAllPoints(); r.n:SetPoint("TOPLEFT", 14, -y); r.n:SetText(row[1])
                r.v:ClearAllPoints(); r.v:SetPoint("TOPRIGHT", -14, -y); r.v:SetText(row[2] or "")
                y = y + 16
            end
        end
        return y
    end
    function f:Head(kind, title, sub)
        local zep = kind == "zeppelin"
        self.icon:SetTexture(UI.MEDIA .. (kind == "tram" and "clock" or (zep and "zeppelin" or "boat")))
        local ic = kind == "tram" and C.info or (zep and C.warning or C.positive)
        self.icon:SetVertexColor(ic[1], ic[2], ic[3], 1)
        self.title:SetText(title)
        self.sub:SetText(sub or "")
    end

    -- au quai : le navire du ponton le plus proche, sa frise, les autres pontons en dessous
    function f:Paint(list)
        local first = list[1]
        local names, cur, nx = routeOf(first)
        self:Head(first.kind, titleOf(first), string.format(first.kind == "zeppelin" and T("Cette tour · vers %s") or T("Ce ponton · vers %s"), names[nx] or "?"))
        local y = self:Route(names, cur, nx, 48)
        local rows, seen = {}, { [first.game or first.pair or 0] = true }
        for i = 2, #list do
            local o = list[i]
            local key = o.game or o.pair
            if #rows < 3 and not seen[key] then
                seen[key] = true
                local on, _, onx = routeOf(o)
                local to = on[onx] or "?"
                if o.game and #o.game.stops > 2 then to = table.concat(BL() and BL():Destinations(o.game, o.s or 1) or { to }, " » ") end
                table.insert(rows, { to, (o.kind == "zeppelin" and T("autre tour") or T("ponton voisin")) .. (o.game and o.game.vessel and (" · " .. T(o.game.vessel)) or "") })
            end
        end
        y = self:Rows(rows, y)
        self:SetHeight(y + 10)
    end
    -- à bord : le navire, la frise, la prochaine escale en vert
    function f:PaintRide(e)
        local names, _, nx = routeOf(e)
        local vessel = e.game and e.game.vessel and T(e.game.vessel)
        self:Head(e.kind, vessel and string.format(T("À bord : %s"), vessel) or (e.kind == "zeppelin" and T("À bord du zeppelin") or T("À bord du bateau")),
            string.format(T("En route vers %s"), names[nx] or "?"))
        local y = self:Route(names, nil, nx, 48)
        y = self:Rows({}, y)
        self:SetHeight(y + 10)
    end
    -- tram des profondeurs : ses deux stations, sans horaire
    function f:PaintTram()
        self:Head("tram", T("Tram des profondeurs"), T("Entre Hurlevent et Forgefer"))
        local y = self:Route({ T("Hurlevent"), T("Forgefer") }, nil, nil, 48)
        y = self:Rows({}, y)
        self:SetHeight(y + 10)
    end

    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 then return end
        s.acc = 0
        if s.sample then return end
        UI:RefreshDockBanner()
    end)
    f:Hide()
    UI:RegisterHUD("dockBanner", f, {
        label = T("Bateaux au quai"), default = { 0, 220 },
        enabled = function() return WK.modules.Guide:Config().dockBanner end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint(SAMPLE); f:Show() else UI:RefreshDockBanner() end
        end,
    })
    return f
end

function UI:RefreshDockBanner()
    if not banner then banner = build() end
    if banner.sample then return end
    local Nv = WK.modules.Nav
    -- tram des profondeurs : son propre bandeau dans l'instance du tram
    if WK.modules.Guide:Config().dockBanner and BL() and BL():InTram() then
        banner.ride = nil
        banner:PaintTram()
        banner:Show()
        return
    end
    if not WK.modules.Guide:Config().dockBanner or (UnitOnTaxi and UnitOnTaxi("player")) or (IsInInstance and IsInInstance()) then
        banner.ride = nil; banner:Hide() return
    end
    -- à bord : la ligne reconnue par les positions, sinon celle du ponton quitté
    if Nv and Nv.IsRiding and Nv.IsRiding() then
        local fit = BL() and BL():RideFit()
        if fit then
            banner.ride = { game = fit.l, s = fit.i, kind = fit.l.kind }
        elseif not banner.ride then
            local lf = banner.lastFirst
            if not (lf and banner.lastSeen and GetTime() - banner.lastSeen < 90) then
                -- bandeau pas vu au quai : la ligne du quai le plus proche du point de départ de la traversée
                lf = nil
                local c, x, y = Nv.RideStart and Nv.RideStart()
                local best
                for _, l in ipairs(c and BL() and BL():All() or {}) do
                    if BL():Mine(l) then
                        for si, st in ipairs(l.stops) do
                            if st.c == c then
                                local d = dist(st.x, st.y, x, y)
                                if d < 600 and (not best or d < best) then best, lf = d, { game = l, s = si, kind = l.kind } end
                            end
                        end
                    end
                end
            end
            banner.ride = lf
        end
        if not banner.ride then banner:Hide() return end
        banner:PaintRide(banner.ride)
        banner:Show()
        return
    end
    banner.ride = nil
    local list = nearDock(banner:IsShown() and RANGE_OUT or RANGE_IN)
    if not list then
        -- position illisible un instant, ou on vient de s'éloigner un peu : on garde le bandeau quelques secondes
        if banner:IsShown() and banner.lastSeen and GetTime() - banner.lastSeen < LINGER then return end
        banner:Hide() return
    end
    banner.lastSeen = GetTime()
    banner:Paint(list)
    banner.lastFirst = list[1]
    banner:Show()
end

-- vérifié toutes les 2 s (le bandeau, une fois visible, se met à jour chaque seconde)
WK:On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(2, function() if not (banner and banner:IsShown()) then pcall(UI.RefreshDockBanner, UI) end end)
    end
end)
