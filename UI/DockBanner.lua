local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bandeau au quai : près d'un quai de bateau ou de zeppelin (150 m pour apparaître, 300 m pour
-- disparaître, puis encore 8 s : il reste affiché tant qu'on attend sur le ponton ; le point d'arrêt du
-- navire est souvent au bout du ponton, voire dans l'eau), le prochain départ avec une barre qui se
-- vide, « exact » ou « estimé », les 3 prochains départs (heure d'arrivée de l'autre côté), et des alertes :
-- le bateau arrive au quai dans 30 s, il part dans 15 s (son en option). Lignes du jeu : Modules/BoatLines.lua ;
-- bateaux appris en jeu : Modules/BoatTimes.lua. À bord, il reste affiché pendant la traversée (PaintRide : destination, temps restant, barre).
-- Réglages Guide:Config() : dockBanner, dockAlerts, dockSound (QoL > Carte, Navigation).
local RANGE_IN, RANGE_OUT, LINGER, W = 150, 300, 8, 360
local banner
local alerted = {}

local function BT() return WK.modules.BoatTimes end
local function BL() return WK.modules.BoatLines end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- Destinations du quai proche : { { to, kind, st, game = ligne du jeu, s = quai } ou { …, pair, side } }
local function nearDock(range)
    local G, L = WK.modules.Guide, WK.modules.MapLayers
    local p = G and G:PlayerPos()
    if not (p and p.cont) then return nil end
    local out = {}
    -- lignes du jeu : position monde des quais
    for _, l in ipairs(BL() and BL():All() or {}) do
        if BL():Mine(l) then
            for s, st in ipairs(l.stops) do
                if st.c == p.cont then
                    local d = dist(st.x, st.y, p.wx, p.wy)
                    if d < range then
                        local state = BL():State(l, s)
                        table.insert(out, { to = BL():StopName(l, s % #l.stops + 1), kind = l.kind, st = state, game = l, s = s, d = d })
                    end
                end
            end
        end
    end
    -- bateaux appris en jeu (hors lignes du jeu)
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    fac = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
    for _, l in ipairs(L and L:AllTransports() or {}) do
        if not l.game and not (l.side and l.side ~= fac) then
            for _, sd in ipairs({ "a", "b" }) do
                local here = l[sd]
                local c, x, y = G.ToWorld(here[1], here[2] / 100, here[3] / 100)
                if c == p.cont and x then
                    local d = dist(x, y, p.wx, p.wy)
                    if d < range then
                        table.insert(out, { to = (sd == "a" and l.b or l.a)[4], kind = l.kind, pair = l, side = sd, st = BT():State(l, sd), d = d })
                    end
                end
            end
        end
    end
    if #out == 0 then return nil end
    return out
end

local SAMPLE = {
    { to = "Auberdine", kind = "boat", st = { inn = 42, following = 289, atDock = true, w = 60, P = 247, travel = 64, est = false } },
    { to = "Theramore", kind = "boat", st = { inn = 185, following = 514, atDock = false, w = 60, P = 329, travel = 105, est = true } },
}

local function known(x) return x.st ~= nil and not x.st.guess end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDockBanner", UIParent)
    f:SetSize(W, 60)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.icon = UI:Icon(f, "boat", 22, nil, "ARTWORK"); f.icon:SetPoint("TOPLEFT", 14, -14)
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 46, -12); f.title:SetPoint("RIGHT", -80, 0)
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.time = UI:Text(f, 18); f.time:SetPoint("TOPRIGHT", -14, -10); f.time:SetJustifyH("RIGHT")
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("TOPLEFT", 46, -30); f.sub:SetPoint("RIGHT", -14, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.pill = CreateFrame("Frame", nil, f); f.pill:SetSize(46, 15)
    f.pill.bg = UI:Rounded(f.pill, 6, 0, "BACKGROUND", 1)
    f.pill.t = UI:Text(f.pill, 10); f.pill.t:SetPoint("CENTER")
    f.track = f:CreateTexture(nil, "ARTWORK"); f.track:SetHeight(4)
    f.fill = f:CreateTexture(nil, "ARTWORK", nil, 2); f.fill:SetHeight(4); f.fill:SetPoint("LEFT", f.track, "LEFT")
    f.head = UI:Text(f, 9, C.dim)
    f.headD = UI:Text(f, 9, C.dim); f.headD:SetJustifyH("RIGHT")
    f.headA = UI:Text(f, 9, C.dim); f.headA:SetJustifyH("RIGHT")
    f.rows = {}
    for i = 1, 4 do
        local r = {}
        r.n = UI:Text(f, 11); r.d = UI:Text(f, 11); r.a = UI:Text(f, 11, C.muted)
        r.d:SetJustifyH("RIGHT"); r.a:SetJustifyH("RIGHT")
        f.rows[i] = r
    end

    function f:Paint(list)
        local first = list[1]
        self.first = first
        local st = first.st
        local zep = first.kind == "zeppelin"
        local Clock = BT().Clock
        self.icon:SetTexture(UI.MEDIA .. (zep and "zeppelin" or "boat"))
        local ic = zep and C.warning or C.positive
        self.icon:SetVertexColor(ic[1], ic[2], ic[3], 1)
        self.title:SetText(string.format(zep and T("Zeppelin pour %s") or T("Bateau pour %s"), first.to or "?"))
        local y = 48
        self.pill:Hide()
        self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", 46, -12); self.title:SetPoint("RIGHT", -80, 0)
        if known(first) then
            local pre = st.est and T("env. ") or ""
            -- grand temps sans « env. » : la pastille « estimé » le dit déjà
            self.time:SetText(Clock(st.inn))
            local col = st.atDock and C.positive or (st.inn < 60 and C.gold or C.text)
            self.time:SetTextColor(col[1], col[2], col[3])
            self.sub:SetText(st.atDock and string.format(T("À quai : monte, il part dans %s"), pre .. Clock(st.inn))
                or string.format(T("Arrive au quai dans %s"), pre .. Clock(math.max(0, st.inn - st.w))))
            -- exact / estimé
            local pc = st.est and C.gold or C.positive
            self.pill.t:SetText(st.est and T("estimé") or T("exact"))
            self.pill.t:SetTextColor(pc[1], pc[2], pc[3])
            self.pill.bg:SetColor(pc[1], pc[2], pc[3], 0.18)
            self.pill:SetWidth((self.pill.t:GetStringWidth() or 30) + 12)
            -- pastille juste à gauche du temps ; le titre s'arrête avant elle (coupé s'il est trop long)
            self.pill:ClearAllPoints(); self.pill:SetPoint("RIGHT", self.time, "LEFT", -8, 0)
            self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", 46, -12); self.title:SetPoint("RIGHT", self.pill, "LEFT", -6, 0)
            self.pill:Show()
            local tw = W - 28
            local frac = 1 - math.max(0, math.min(1, st.inn / math.max(1, st.P)))
            self.track:ClearAllPoints(); self.track:SetPoint("TOPLEFT", 14, -y); self.track:SetPoint("TOPRIGHT", -14, -y)
            self.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            self.fill:SetColorTexture(col[1], col[2], col[3], 1)
            self.fill:SetWidth(math.max(0.01, tw * frac))
            self.track:Show(); self.fill:Show()
            y = y + 12
        else
            self.time:SetText("")
            self.sub:SetText(T("Heure pas encore connue : elle se cale toute seule à l'annonce du maître de quai, quand tu le prends, ou par le partage."))
            self.track:Hide(); self.fill:Hide()
        end
        -- prochains départs : les 3 de la première destination, puis le prochain des autres
        local rows = {}
        if known(first) then
            if first.game then
                for _, d in ipairs(BL():Departures(first.game, first.s, 3)) do table.insert(rows, { d.to, d.inn, d.arrive, d.est }) end
            else
                table.insert(rows, { first.to, st.inn, st.inn + (st.travel or 0), st.est })
                table.insert(rows, { first.to, st.following, st.following + (st.travel or 0), st.est })
            end
        end
        for i = 2, #list do
            local o = list[i]
            if known(o) and #rows < 4 then table.insert(rows, { o.to, o.st.inn, o.st.inn + (o.st.travel or 0), o.st.est }) end
        end
        self.head:SetShown(#rows > 0); self.headD:SetShown(#rows > 0); self.headA:SetShown(#rows > 0)
        if #rows > 0 then
            self.head:ClearAllPoints(); self.head:SetPoint("TOPLEFT", 14, -y)
            self.head:SetText(UI:Upper(T("Prochains départs")))
            self.headD:ClearAllPoints(); self.headD:SetPoint("TOPRIGHT", -94, -y); self.headD:SetWidth(80)
            self.headD:SetText(UI:Upper(T("part")))
            self.headA:ClearAllPoints(); self.headA:SetPoint("TOPRIGHT", -14, -y); self.headA:SetWidth(70)
            self.headA:SetText(UI:Upper(T("arrive")))
            y = y + 14
        end
        for i, r in ipairs(self.rows) do
            local row = rows[i]
            local shown = row ~= nil
            r.n:SetShown(shown); r.d:SetShown(shown); r.a:SetShown(shown)
            if shown then
                local pre = row[4] and T("env. ") or ""
                r.n:ClearAllPoints(); r.n:SetPoint("TOPLEFT", 14, -y)
                r.a:ClearAllPoints(); r.a:SetPoint("TOPRIGHT", -14, -y); r.a:SetWidth(70)
                r.d:ClearAllPoints(); r.d:SetPoint("TOPRIGHT", -94, -y); r.d:SetWidth(80)
                r.n:SetText(row[1])
                r.d:SetText(pre .. Clock(row[2])); r.a:SetText(Clock(row[3]))
                local dc = (i == 1 and st and st.atDock) and C.positive or C.text
                r.d:SetTextColor(dc[1], dc[2], dc[3])
                y = y + 15
            end
        end
        self:SetHeight(y + 10)
    end
    -- à bord : la traversée en cours (destination, temps restant estimé, barre d'avancement)
    function f:PaintRide(r)
        local zep = r.kind == "zeppelin"
        local Clock = BT().Clock
        self.icon:SetTexture(UI.MEDIA .. (zep and "zeppelin" or "boat"))
        local ic = zep and C.warning or C.positive
        self.icon:SetVertexColor(ic[1], ic[2], ic[3], 1)
        self.pill:Hide()
        self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", 46, -12); self.title:SetPoint("RIGHT", -80, 0)
        self.title:SetText(string.format(zep and T("Zeppelin pour %s") or T("Bateau pour %s"), r.to or "?"))
        local y = 48
        if r.travel and r.travel > 0 then
            local el = GetTime() - r.start
            local left = math.max(0, r.travel - el)
            self.time:SetText(Clock(left)); self.time:SetTextColor(C.text[1], C.text[2], C.text[3])
            self.sub:SetText(string.format(T("À bord : arrivée vers %s"), date("%H:%M", time() + left)))
            self.track:ClearAllPoints(); self.track:SetPoint("TOPLEFT", 14, -y); self.track:SetPoint("TOPRIGHT", -14, -y)
            self.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            self.fill:SetColorTexture(ic[1], ic[2], ic[3], 1)
            self.fill:SetWidth(math.max(0.01, (W - 28) * math.min(1, el / r.travel)))
            self.track:Show(); self.fill:Show()
            y = y + 12
        else
            self.time:SetText("")
            self.sub:SetText(T("À bord : durée de la traversée pas encore connue."))
            self.track:Hide(); self.fill:Hide()
        end
        self.head:Hide(); self.headD:Hide(); self.headA:Hide()
        for _, row in ipairs(self.rows) do row.n:Hide(); row.d:Hide(); row.a:Hide() end
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
        label = T("Horaires au quai"), default = { 0, 220 },
        enabled = function() return WK.modules.Guide:Config().dockBanner end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint(SAMPLE); f:Show() else UI:RefreshDockBanner() end
        end,
        -- « Tester » : les départs approchent seconde après seconde
        test = function()
            f.sample = true
            local data = {}
            for i, e in ipairs(SAMPLE) do
                local st = {}
                for k, v in pairs(e.st) do st[k] = v end
                data[i] = { to = e.to, kind = e.kind, st = st }
            end
            f:Paint(data); f:Show()
            f.testTicker = C_Timer.NewTicker and C_Timer.NewTicker(1, function()
                for _, e in ipairs(data) do
                    e.st.inn = math.max(0, e.st.inn - 1)
                    e.st.following = math.max(0, e.st.following - 1)
                end
                f:Paint(data)
            end)
        end,
        testStop = function()
            if f.testTicker then f.testTicker:Cancel(); f.testTicker = nil end
            f.sample = nil
            UI:RefreshDockBanner()
        end,
    })
    return f
end

-- Alertes : le bateau arrive au quai dans 30 s, puis il part dans 15 s (une fois par départ)
local function alerts(list)
    local cfg = WK.modules.Guide:Config()
    if cfg.dockAlerts == false then return end
    for _, e in ipairs(list) do
        local st = e.st
        if known(e) then
            local depAt = math.floor((WK.modules.BoatLines.Now() + st.inn) / 5)
            local key = (e.to or "?") .. ":" .. depAt
            local msg
            local arriveIn = st.inn - st.w
            if not st.atDock and arriveIn <= 30 and arriveIn > 25 and not alerted[key .. "a"] then
                alerted[key .. "a"] = true
                msg = string.format(T("%s pour %s : il arrive au quai dans 30 s"), e.kind == "zeppelin" and T("Zeppelin") or T("Bateau"), e.to or "?")
            elseif st.atDock and st.inn <= 15 and st.inn > 10 and not alerted[key .. "d"] then
                alerted[key .. "d"] = true
                msg = string.format(T("%s pour %s : il part dans 15 s"), e.kind == "zeppelin" and T("Zeppelin") or T("Bateau"), e.to or "?")
            end
            if msg then
                WK.modules.QoL:Remind("dock", msg, C.gold[1], C.gold[2], C.gold[3])
                if cfg.dockSound ~= false and PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.RAID_WARNING or 8959) end
            end
        end
    end
end

function UI:RefreshDockBanner()
    if not banner then banner = build() end
    if banner.sample then return end
    local Nv = WK.modules.Nav
    if not WK.modules.Guide:Config().dockBanner or (UnitOnTaxi and UnitOnTaxi("player")) or (IsInInstance and IsInInstance()) then
        banner.ride = nil; banner:Hide() return
    end
    -- à bord : on garde le bandeau pendant la traversée (le navire qu'on attendait au quai)
    if Nv and Nv.IsRiding and Nv.IsRiding() then
        if not banner.ride then
            local lf = banner.lastFirst
            if not (lf and banner.lastSeen and GetTime() - banner.lastSeen < 90) then banner:Hide() return end
            banner.ride = { to = lf.to, kind = lf.kind, start = GetTime(), travel = lf.st and lf.st.travel }
        end
        banner:PaintRide(banner.ride)
        banner:Show()
        return
    end
    banner.ride = nil
    local list = nearDock(banner:IsShown() and RANGE_OUT or RANGE_IN)
    if not list then
        -- position illisible un instant (chargement, carte) : on garde le bandeau quelques secondes
        -- position illisible un instant, ou on vient de s'éloigner un peu : on garde le bandeau quelques secondes
        if banner:IsShown() and banner.lastSeen and GetTime() - banner.lastSeen < LINGER then return end
        banner:Hide() return
    end
    banner.lastSeen = GetTime()
    -- le départ le plus proche en tête, puis le quai le plus proche
    table.sort(list, function(a, b)
        if known(a) ~= known(b) then return known(a) end
        if known(a) and known(b) then return a.st.inn < b.st.inn end
        return (a.d or 0) < (b.d or 0)
    end)
    banner:Paint(list)
    banner.lastFirst = list[1]
    banner:Show()
    alerts(list)
end

-- vérifié toutes les 2 s (le bandeau, une fois visible, se met à jour chaque seconde)
WK:On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(2, function() if not (banner and banner:IsShown()) then pcall(UI.RefreshDockBanner, UI) end end)
    end
end)
