local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bandeau des bateaux et zeppelins, sans aucun horaire : où va le navire. En haut (graphite) « Bateau pour »
-- et la destination, le navire et « Ce ponton · vers … » ; en bas une bande de mer animée (ciel pour les
-- zeppelins) avec la frise des escales, ton ponton à gauche en bleu, la prochaine escale en vert.
--   * au quai (60 m pour apparaître : sur le ponton ; 85 m pour disparaître, puis encore 5 s) : le navire de ton ponton
--     tangue au départ de la frise ; les pontons voisins entre les deux ;
--   * à bord (Nav.IsRiding) : le navire avance sur la frise selon BoatLines:RideProgress (ligne reconnue par
--     BoatLines:RideFit, sinon celle du ponton quitté, navire au départ) ;
--   * dans le tram des profondeurs : ses deux stations.
-- Lignes du jeu : Modules/BoatLines.lua ; bateaux appris en jeu : Nav:Boats(). Réglage Guide:Config().dockBanner.
local RANGE_IN, RANGE_OUT, LINGER, W = 60, 85, 5, 400 -- sur le ponton (le point d'arrêt du navire est au bout)
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

local SAMPLE = {
    { game = { vessel = "Le Bravoure", kind = "boat", stops = { { name = "Port de Menethil" }, { name = "Austrivage" }, { name = "Auberdine" } } }, s = 1, kind = "boat" },
    { game = { vessel = "La Dame Mehley", kind = "boat", stops = { { name = "Port de Menethil" }, { name = "Theramore" } } }, s = 1, kind = "boat" },
}

local MAXN = 4 -- escales dessinées au plus
local TOP_H, SEA_H, COLW = 54, 70, 3 -- haut graphite, bande de mer, largeur d'une colonne de vague
local LINE_Y = 42                    -- frise : distance depuis le haut de la bande de mer

-- teintes de la bande, tirées du bleu du thème : mer (bateau), ciel (zeppelin), rail (tram, graphite)
local function bandColors(kind)
    local i = C.info
    if kind == "tram" then return C.surface2, C.border, 0 end
    local foam = { i[1] + (1 - i[1]) * 0.45, i[2] + (1 - i[2]) * 0.45, i[3] + (1 - i[3]) * 0.45 }
    if kind == "zeppelin" then return { i[1] * 0.55, i[2] * 0.70, i[3] * 0.75 }, foam, 1.2 end
    return { i[1] * 0.40, i[2] * 0.55, i[3] * 0.50 }, foam, 3
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDockBanner", UIParent)
    f:SetSize(W, TOP_H + SEA_H)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    -- haut graphite : « Bateau pour » et la destination à gauche, le navire et le ponton à droite
    f.kicker = UI:Text(f, 11, C.muted); f.kicker:SetPoint("TOPLEFT", 16, -11)
    f.title = UI:Text(f, 16); f.title:SetPoint("TOPLEFT", 16, -27); f.title:SetPoint("RIGHT", f, "CENTER", 40, 0)
    f.title:SetJustifyH("LEFT")
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.vessel = UI:Text(f, 10, C.muted); f.vessel:SetPoint("TOPRIGHT", -16, -12); f.vessel:SetJustifyH("RIGHT")
    f.sub = UI:Text(f, 11); f.sub:SetPoint("TOPRIGHT", -16, -30); f.sub:SetJustifyH("RIGHT")
    f.sub:SetPoint("LEFT", f, "CENTER", 40, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.sep = f:CreateTexture(nil, "BORDER"); f.sep:SetHeight(1)
    f.rows = {}
    for i = 1, 3 do
        local r = {}
        r.n = UI:Text(f, 11); r.v = UI:Text(f, 10, C.muted); r.v:SetJustifyH("RIGHT")
        f.rows[i] = r
    end

    -- bande de mer en bas : fond arrondi, crête en colonnes qui ondulent, frise et bateau par-dessus
    local sea = CreateFrame("Frame", nil, f)
    sea:SetPoint("BOTTOMLEFT", 0, 0); sea:SetPoint("BOTTOMRIGHT", 0, 0); sea:SetHeight(SEA_H)
    f.sea = sea
    local bodyF = CreateFrame("Frame", nil, sea)
    bodyF:SetPoint("BOTTOMLEFT", 0, 0); bodyF:SetPoint("BOTTOMRIGHT", 0, 0); bodyF:SetHeight(SEA_H - 10)
    f.body = UI:Rounded(bodyF, 11, 1, "BACKGROUND", 2)
    -- calques au-dessus du fond : vagues, puis frise et navire
    local waveF = CreateFrame("Frame", nil, sea); waveF:SetAllPoints(sea); waveF:SetFrameLevel(bodyF:GetFrameLevel() + 1)
    local fg = CreateFrame("Frame", nil, sea); fg:SetAllPoints(sea); fg:SetFrameLevel(bodyF:GetFrameLevel() + 2)
    f.cols, f.foam = {}, {}
    local ncol = math.floor((W - 2) / COLW)
    for k = 1, ncol do
        local c = waveF:CreateTexture(nil, "BACKGROUND", nil, 3)
        c:SetWidth(k == ncol and (W - 2 - (ncol - 1) * COLW) or COLW)
        c:SetPoint("BOTTOMLEFT", sea, "BOTTOMLEFT", 1 + (k - 1) * COLW, SEA_H - 10 - 12)
        local fm = waveF:CreateTexture(nil, "BACKGROUND", nil, 4)
        fm:SetHeight(2); fm:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, -2); fm:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", 0, -2)
        -- pas d'arrondi au pixel : la crête monte et descend en douceur
        for _, t in ipairs({ c, fm }) do
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
            if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
        end
        f.cols[k], f.foam[k] = c, fm
    end
    -- vaguelettes fixes dans la mer
    f.ripples = {}
    for k = 1, 9 do
        local t = waveF:CreateTexture(nil, "BACKGROUND", nil, 4)
        t:SetSize(16, 1)
        t:SetPoint("TOPLEFT", sea, "TOPLEFT", 14 + (k - 1) * 44 + (k % 2) * 12, -(26 + (k % 3) * 12))
        f.ripples[k] = t
    end
    -- frise : pointillés, trait parcouru, points des escales et noms
    f.dashes = {}
    for k = 1, math.floor((W - 72) / 9) do
        local t = fg:CreateTexture(nil, "ARTWORK", nil, 1); t:SetSize(4, 2)
        f.dashes[k] = t
    end
    f.done = fg:CreateTexture(nil, "ARTWORK", nil, 2); f.done:SetHeight(2)
    f.dots, f.names = {}, {}
    for i = 1, MAXN do
        f.dots[i] = UI:Icon(fg, "circle", 10, nil, "OVERLAY")
        f.names[i] = UI:Text(fg, 10); f.names[i]:SetWidth(120)
    end
    f.wake = fg:CreateTexture(nil, "ARTWORK", nil, 3); f.wake:SetSize(14, 1)
    f.ship = UI:Icon(fg, "boat", 22, nil, "OVERLAY")

    local function X(i, n) return 36 + (i - 1) * ((W - 72) / math.max(1, n - 1)) end

    -- frise : noms des escales (ton quai à gauche en bleu, prochaine escale en vert), bateau à la part p du
    -- trajet entre les deux premières escales (nil : au ponton)
    function f:Route(kind, names, p)
        local body, foam, amp = bandColors(kind)
        self.amp = amp
        self.body:SetColor(body[1], body[2], body[3], 1)
        for k, c in ipairs(self.cols) do
            c:SetColorTexture(body[1], body[2], body[3], 1)
            self.foam[k]:SetColorTexture(foam[1], foam[2], foam[3], amp > 0 and 0.55 or 0)
        end
        for _, t in ipairs(self.ripples) do t:SetColorTexture(foam[1], foam[2], foam[3], kind == "tram" and 0 or 0.14) end
        local n = math.min(#names, MAXN)
        local x0, x1 = X(1, n), X(n, n)
        for k, t in ipairs(self.dashes) do
            local x = x0 + 8 + (k - 1) * 9
            t:ClearAllPoints(); t:SetPoint("LEFT", self.sea, "TOPLEFT", x, -LINE_Y)
            t:SetColorTexture(foam[1], foam[2], foam[3], 0.4)
            t:SetShown(x < x1 - 8)
        end
        for i = 1, MAXN do
            local shown = i <= n
            local dot, nm = self.dots[i], self.names[i]
            dot:SetShown(shown); nm:SetShown(shown)
            if shown then
                local x = X(i, n)
                dot:ClearAllPoints(); dot:SetPoint("CENTER", self.sea, "TOPLEFT", x, -LINE_Y)
                nm:ClearAllPoints()
                if i == 1 then nm:SetPoint("TOPLEFT", self.sea, "TOPLEFT", x - 8, -(LINE_Y + 9)); nm:SetJustifyH("LEFT")
                elseif i == n then nm:SetPoint("TOPRIGHT", self.sea, "TOPLEFT", x + 8, -(LINE_Y + 9)); nm:SetJustifyH("RIGHT")
                else nm:SetPoint("TOP", self.sea, "TOPLEFT", x, -(LINE_Y + 9)); nm:SetJustifyH("CENTER") end
                nm:SetText(names[i])
                local col = (i == 1 and kind ~= "tram") and foam or (i == 2 and kind ~= "tram") and C.positive or foam
                dot:SetVertexColor(col[1], col[2], col[3], 1)
                nm:SetTextColor(col[1], col[2], col[3], (i <= 2 or kind == "tram") and 1 or 0.65)
            end
        end
        -- bateau (ou zeppelin) : au ponton, ou là où il en est de la traversée ; pas de navire pour le tram
        local seg = n > 1 and (X(2, n) - x0) or 0
        local sx = p and (x0 + seg * p) or (x0 + 16)
        self.shipX = sx
        self.ship:SetShown(kind ~= "tram")
        self.ship:SetTexture(UI.MEDIA .. (kind == "zeppelin" and "zeppelin" or "boat"))
        self.ship:SetVertexColor(C.text[1], C.text[2], C.text[3], 1)
        self.wake:SetShown(kind == "boat" and p ~= nil)
        self.wake:ClearAllPoints(); self.wake:SetPoint("RIGHT", self.sea, "TOPLEFT", sx - 12, -(LINE_Y - 4))
        self.wake:SetColorTexture(foam[1], foam[2], foam[3], 0.5)
        self.done:SetShown(p ~= nil and sx > x0 + 2)
        self.done:ClearAllPoints()
        self.done:SetPoint("LEFT", self.sea, "TOPLEFT", x0, -LINE_Y); self.done:SetWidth(math.max(1, sx - x0))
        self.done:SetColorTexture(foam[1], foam[2], foam[3], 0.95)
        self:Animate(0)
    end
    -- houle : la crête ondule, le navire tangue (à chaque image tant que le bandeau est visible)
    function f:Animate(t)
        local amp = self.amp or 0
        for k, c in ipairs(self.cols) do
            c:SetHeight(12 + 4 + amp * math.sin(k * 0.25 - t * 1.3) + amp * 0.4 * math.sin(k * 0.10 + t * 0.7))
        end
        if self.ship:IsShown() then
            local bob = amp > 0 and math.sin(t * 2.2) * 1.5 or 0
            self.ship:ClearAllPoints(); self.ship:SetPoint("BOTTOM", self.sea, "TOPLEFT", (self.shipX or 36), -(LINE_Y - 4) + bob)
            if self.ship.SetSnapToPixelGrid then self.ship:SetSnapToPixelGrid(false); self.ship:SetTexelSnappingBias(0) end
            if self.ship.SetRotation then self.ship:SetRotation(amp > 0 and math.sin(t * 1.7) * 0.08 or 0) end
        end
    end
    function f:Rows(rows)
        local y = TOP_H
        self.sep:SetShown(#rows > 0)
        if #rows > 0 then
            self.sep:ClearAllPoints(); self.sep:SetPoint("TOPLEFT", 16, -(y - 2)); self.sep:SetPoint("TOPRIGHT", -16, -(y - 2))
            self.sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            y = y + 6
        end
        for i, r in ipairs(self.rows) do
            local row = rows[i]
            r.n:SetShown(row ~= nil); r.v:SetShown(row ~= nil)
            if row then
                r.n:ClearAllPoints(); r.n:SetPoint("TOPLEFT", 16, -y); r.n:SetText(row[1])
                r.v:ClearAllPoints(); r.v:SetPoint("TOPRIGHT", -16, -y); r.v:SetText(row[2] or "")
                y = y + 16
            end
        end
        if #rows > 0 then y = y + 6 end
        self:SetHeight(y + SEA_H)
    end
    function f:Head(kicker, title, vessel, sub)
        self.kicker:SetText(kicker or "")
        self.title:SetText(title or "")
        self.vessel:SetText(vessel or "")
        self.sub:SetText(sub or "")
    end

    -- au quai : « Bateau pour » la prochaine escale, la frise depuis ton ponton, les autres pontons au milieu
    function f:Paint(list)
        local first = list[1]
        local names = routeOf(first)
        local to = names[2] or "?"
        local zep = first.kind == "zeppelin"
        self:Head(zep and T("Zeppelin pour") or T("Bateau pour"), to,
            first.game and first.game.vessel and T(first.game.vessel) or (zep and T("Zeppelin") or T("Bateau")),
            string.format(zep and T("Cette tour · vers %s") or T("Ce ponton · vers %s"), to))
        local rows, seen = {}, { [first.game or first.pair or 0] = true }
        for i = 2, #list do
            local o = list[i]
            local key = o.game or o.pair
            if #rows < 3 and not seen[key] then
                seen[key] = true
                local on, _, onx = routeOf(o)
                local dest = on[onx] or "?"
                if o.game and #o.game.stops > 2 then dest = table.concat(BL() and BL():Destinations(o.game, o.s or 1) or { dest }, " » ") end
                table.insert(rows, { dest, (o.kind == "zeppelin" and T("autre tour") or T("ponton voisin")) .. (o.game and o.game.vessel and (" · " .. T(o.game.vessel)) or "") })
            end
        end
        self:Rows(rows)
        self:Route(first.kind or "boat", names, nil)
    end
    -- à bord : « en route vers » l'escale suivante, le navire là où il en est de la traversée
    function f:PaintRide(e, p)
        local names = routeOf(e)
        local zep = e.kind == "zeppelin"
        self:Head(T("À bord · en route vers"), names[2] or "?",
            e.game and e.game.vessel and T(e.game.vessel) or (zep and T("Zeppelin") or T("Bateau")),
            p and string.format(T("traversée %d %%"), math.floor(p * 100 + 0.5)) or (zep and T("Dans les airs") or T("En mer")))
        self:Rows({})
        self:Route(e.kind or "boat", names, p)
    end
    -- tram des profondeurs : ses deux stations, sans horaire
    function f:PaintTram()
        self:Head(T("Tram des profondeurs"), T("Entre Hurlevent et Forgefer"), "", "")
        self:Rows({})
        self:Route("tram", { T("Hurlevent"), T("Forgefer") }, nil)
    end

    f:SetScript("OnUpdate", function(s, el)
        s.clock = (s.clock or 0) + el
        s.anim = (s.anim or 0) + el
        -- houle à chaque image (au plus 60 par seconde) pour une eau fluide
        if s.anim >= 0.016 then s.anim = 0; s:Animate(s.clock) end
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
                local c, x, y
                if Nv.RideStart then c, x, y = Nv.RideStart() end
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
        banner:PaintRide(banner.ride, fit and BL():RideProgress() or nil)
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
