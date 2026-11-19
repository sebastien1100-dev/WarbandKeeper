local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Statistiques du compte pendant un vol : à la place de la carte du monde (touche M) tant que le perso est
-- en vol, ou d'office au décollage (réglage). À gauche le vol (trajet dessiné, arrivée, chiffres des vols),
-- à droite « Le savais-tu ? » : des chiffres du compte en cartes qui défilent toutes les 8 s.
-- Réglages QoL:Config().flight : stats (à la place de la carte), statsAuto (au décollage).
local F = function() return WK.modules.Flight end
local W, H, LEFT_W = 920, 540, 320
local ROTATE = 8
local view

local function onTaxi() return UnitOnTaxi and UnitOnTaxi("player") end
local function cfg() return F():Config() end
local function gold(c) return UI:ShortGold(c or 0) end
local function num(n)
    n = math.floor(n or 0)
    return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end
-- « Hurlevent, Forêt d'Elwynn » » « Hurlevent »
local function short(n) return (tostring(n or "?"):gsub(",.*$", "")) end
local function mmss(sec)
    sec = math.max(0, math.floor(sec or 0))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

---------------------------------------------------------------------------
-- Les chiffres : { cat, big, text, color?, bars? (valeurs, la dernière mise en avant) }
---------------------------------------------------------------------------
local DAY, WEEK = 86400, 7 * 86400
local function stories()
    local g = WK.DB.global
    local out = {}
    local function add(fn) local ok, e = pcall(fn); if ok and e then table.insert(out, e) end end
    local now = time()
    -- ventes HV par semaine
    add(function()
        local weeks = {}
        for i = 1, 8 do weeks[i] = 0 end
        for _, e in ipairs(g.auction and g.auction.log or {}) do
            if e.kind == "sale" and e.t then
                local w = math.floor((now - e.t) / WEEK)
                if w < 8 then weeks[8 - w] = weeks[8 - w] + (e.net or 0) end
            end
        end
        local cur = weeks[8]
        if cur <= 0 then return nil end
        local best = 0
        for i = 1, 7 do if weeks[i] >= cur then best = i end end
        local txt = best == 0 and T("vendus à l'HV ces 7 derniers jours : ta meilleure semaine depuis 2 mois.")
            or T("vendus à l'HV ces 7 derniers jours.")
        return { cat = T("ARGENT"), big = "+" .. gold(cur), color = C.gold, text = txt, bars = weeks, sub = T("8 dernières semaines") }
    end)
    -- or du compte sur 30 jours
    add(function()
        local S = WK.modules.Statistics
        local a, b = S:AccountGoldAt(now), S:AccountGoldAt(now - 30 * DAY)
        if a <= 0 then return nil end
        local bars = {}
        for i = 7, 0, -1 do table.insert(bars, S:AccountGoldAt(now - i * WEEK)) end
        local d = a - b
        return { cat = T("OR DU COMPTE"), big = (d >= 0 and "+" or "-") .. gold(math.abs(d)), color = d >= 0 and C.gold or C.negative,
            text = string.format(T("en 30 jours ; le compte a %s aujourd'hui."), gold(a)), bars = bars, sub = T("8 dernières semaines") }
    end)
    -- temps de jeu
    add(function()
        local total, top, topKey = 0, 0, nil
        local n = 0
        for key, c in pairs(g.characters) do
            n = n + 1
            total = total + (c.played or 0)
            if (c.played or 0) > top then top, topKey = c.played, key end
        end
        if total < 3600 then return nil end
        local c = g.characters[topKey]
        return { cat = T("PERSOS"), big = string.format(T("%d h"), math.floor(total / 3600)),
            text = string.format(T("de jeu sur %d persos, dont %d %% sur %s."), n, math.floor(top / total * 100 + 0.5), WK:CharName(c, topKey)) }
    end)
    -- meilleur record de donjon et nombre de passages
    add(function()
        local D = WK.modules.Dungeons
        local best, bestKey, bestAt, runs, full = nil, nil, nil, 0, 0
        for key, list in pairs(g.dungeons and g.dungeons.history or {}) do
            for _, e in ipairs(list) do
                runs = runs + 1
                if e.dur then
                    full = full + 1
                    if not best or e.dur < best then best, bestKey, bestAt = e.dur, key, e.at end
                end
            end
        end
        if not best then return nil end
        local d = D:Get(bestKey)
        return { cat = T("DONJONS"), big = D.Clock(best),
            text = string.format(T("ton record à %s (le %s) ; %d passages notés, %d complets."), d and D:Name(d) or "?", date("%d/%m", bestAt or now), runs, full) }
    end)
    -- pêche
    add(function()
        local d = g.fishLog
        if not (d and (d.total or 0) > 0) then return nil end
        local rare, rn
        for id, it in pairs(d.items or {}) do
            if not rn or (it.n or 0) < rn then rare, rn = id, it.n or 0 end
        end
        local name = rare and WK.GetItemInfo(rare)
        return { cat = T("PÊCHE"), big = num(d.total),
            text = name and string.format(T("prises ; la plus rare : %s (%d)."), name, rn) or T("prises au total.") }
    end)
    -- quêtes faites (tout le compte)
    add(function()
        local n = 0
        for _, c in pairs(g.characters) do for _ in pairs(c.quests and c.quests.done or {}) do n = n + 1 end end
        if n == 0 then return nil end
        return { cat = T("QUÊTES"), big = num(n), text = T("quêtes faites sur le compte.") }
    end)
    -- rares tués
    add(function()
        local n = 0
        for _ in pairs(g.rares and g.rares.kills or {}) do n = n + 1 end
        if n == 0 then return nil end
        return { cat = T("RARES"), big = num(n), text = T("monstres rares différents tués par tes persos.") }
    end)
    -- plus belle vente
    add(function()
        local best
        for _, e in ipairs(g.auction and g.auction.log or {}) do
            if e.kind == "sale" and (e.net or 0) > ((best and best.net) or 0) then best = e end
        end
        if not best then return nil end
        local name = best.item and WK.GetItemInfo(best.item) or "?"
        return { cat = T("HÔTEL DES VENTES"), big = gold(best.net), color = C.gold,
            text = string.format(T("ta plus belle vente : %s x%d (le %s)."), name, best.count or 1, date("%d/%m", best.t or now)) }
    end)
    -- vols
    add(function()
        local log = g.flights and g.flights.log or {}
        if #log < 2 then return nil end
        local secs = 0
        for _, e in ipairs(log) do secs = secs + (e.dur or 0) end
        return { cat = T("VOLS"), big = num(#log), text = string.format(T("vols notés, %d h %02d en l'air."), math.floor(secs / 3600), math.floor(secs % 3600 / 60)) }
    end)
    -- persos au niveau max
    add(function()
        local n, max = 0, 0
        local X = WK.modules.XP
        local cap = X and X.MaxLevel and X:MaxLevel() or 60
        for _, c in pairs(g.characters) do n = n + 1; if (c.level or 0) >= cap then max = max + 1 end end
        if n < 2 then return nil end
        return { cat = T("COMPTE"), big = tostring(n), text = string.format(T("persos, dont %d au niveau maximum."), max) }
    end)
    -- récolte
    add(function()
        local n = 0
        for _, list in pairs(g.gatherSpots or {}) do
            if type(list) == "table" then for _ in pairs(list) do n = n + 1 end end
        end
        if n == 0 then return nil end
        return { cat = T("RÉCOLTE"), big = num(n), text = T("récoltes notées sur la carte (filons et plantes).") }
    end)
    return out
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function card(parent, big)
    local c = CreateFrame("Frame", nil, parent)
    UI:Panel(c, 10, C.surface, C.border)
    c.cat = UI:Text(c, 10, C.muted); c.cat:SetPoint("TOPLEFT", 14, -12)
    c.big = UI:Text(c, big and 28 or 20, C.text); c.big:SetPoint("TOPLEFT", c.cat, "BOTTOMLEFT", 0, -4)
    c.text = UI:Text(c, big and 13 or 11, C.text); c.text:SetPoint("TOPLEFT", c.big, "BOTTOMLEFT", 0, -4)
    c.text:SetPoint("RIGHT", -14, 0); c.text:SetJustifyH("LEFT")
    if c.text.SetWordWrap then c.text:SetWordWrap(true) end
    if big then
        c.bars = {}
        for i = 1, 8 do
            local b = c:CreateTexture(nil, "ARTWORK")
            c.bars[i] = b
        end
        c.sub = UI:Text(c, 10, C.dim); c.sub:SetPoint("BOTTOMLEFT", 14, 8)
    end
    function c:Set(e)
        self:SetShown(e ~= nil)
        if not e then return end
        self.cat:SetText(e.cat)
        self.big:SetText(e.big)
        self.big:SetTextColor(unpack(e.color or C.text))
        self.text:SetText(e.text)
        if not self.bars then return end
        local vals = e.bars
        local w = (self:GetWidth() or 500) - 28
        local bw = math.floor((w - 7 * 6) / 8)
        local mx = 0
        for _, v in ipairs(vals or {}) do mx = math.max(mx, v) end
        local r1, g1, b1 = UI:Accent()
        for i, b in ipairs(self.bars) do
            local v = vals and vals[i]
            if v and mx > 0 then
                local h = math.max(3, 56 * v / mx)
                b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", 14 + (i - 1) * (bw + 6), 24); b:SetSize(bw, h)
                local last = i == #vals
                local col = last and C.gold or { r1, g1, b1 }
                b:SetColorTexture(col[1], col[2], col[3], last and 1 or 0.7)
                b:Show()
            else b:Hide() end
        end
        self.sub:SetText(vals and e.sub or "")
    end
    return c
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperFlightStats", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER", 0, 20)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 14, { C.bg[1], C.bg[2], C.bg[3], 0.97 }, C.border)
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperFlightStats") end
    f:Hide()

    -- gauche : le vol
    local left = CreateFrame("Frame", nil, f)
    left:SetPoint("TOPLEFT"); left:SetPoint("BOTTOMLEFT"); left:SetWidth(LEFT_W)
    left.line = left:CreateTexture(nil, "ARTWORK"); left.line:SetWidth(1)
    left.line:SetPoint("TOPRIGHT"); left.line:SetPoint("BOTTOMRIGHT"); left.line:SetColorTexture(unpack(C.border))
    f.kicker = UI:Text(left, 10, C.muted); f.kicker:SetPoint("TOPLEFT", 18, -18); f.kicker:SetText(T("EN VOL"))
    f.route = UI:Text(left, 16, C.text); f.route:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -4)
    f.route:SetWidth(LEFT_W - 36); f.route:SetJustifyH("LEFT")
    if f.route.SetWordWrap then f.route:SetWordWrap(true) end
    f.eta = UI:Text(left, 11, C.muted); f.eta:SetPoint("TOPLEFT", f.route, "BOTTOMLEFT", 0, -4)
    f.map = CreateFrame("Frame", nil, left)
    f.map:SetSize(LEFT_W - 36, 220); f.map:SetPoint("TOPLEFT", 18, -96)
    UI:Panel(f.map, 10, { 0, 0, 0, 0.35 }, C.border)
    f.lines = UI:LinePool(4)
    f.dots = {}
    for i = 1, 3 do
        local d = f.map:CreateTexture(nil, "OVERLAY", nil, 7)
        d:SetTexture(UI.MEDIA .. "circle")
        f.dots[i] = d
    end
    f.fromT = UI:Text(f.map, 10, C.muted); f.toT = UI:Text(f.map, 10, C.text)
    f.mapEmpty = UI:Text(f.map, 11, C.dim); f.mapEmpty:SetPoint("CENTER"); f.mapEmpty:SetText(T("trajet pas encore connu"))
    f.stat = {}
    for i = 1, 3 do
        local r = CreateFrame("Frame", nil, left)
        r:SetHeight(22)
        r:SetPoint("TOPLEFT", 18, -330 - (i - 1) * 24); r:SetPoint("TOPRIGHT", -18, -330 - (i - 1) * 24)
        r.a = UI:Text(r, 11, C.text); r.a:SetPoint("LEFT")
        r.b = UI:Text(r, 11, C.text); r.b:SetPoint("RIGHT"); r.b:SetJustifyH("RIGHT")
        r.l = r:CreateTexture(nil, "ARTWORK"); r.l:SetHeight(1); r.l:SetPoint("BOTTOMLEFT"); r.l:SetPoint("BOTTOMRIGHT")
        r.l:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
        f.stat[i] = r
    end

    -- droite : Le savais-tu ?
    local right = CreateFrame("Frame", nil, f)
    right:SetPoint("TOPLEFT", LEFT_W, 0); right:SetPoint("BOTTOMRIGHT")
    f.head = UI:Text(right, 14, C.text); f.head:SetPoint("TOPLEFT", 16, -18); f.head:SetText(T("Le savais-tu ?"))
    f.pos = UI:Text(right, 11, C.muted); f.pos:SetPoint("LEFT", f.head, "RIGHT", 10, 0)
    f.close = UI:IconButton(right, "close", 24, "Fermer (Échap)")
    f.close:SetPoint("TOPRIGHT", -12, -12)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.mapBtn = UI:Button(right, "Carte", 70, 24, "secondary")
    f.mapBtn:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.mapBtn.tooltip = "Ouvrir la carte du monde du jeu."
    f.mapBtn:SetScript("OnClick", function()
        f.allowMap = true
        f:Hide()
        if ToggleWorldMap then ToggleWorldMap() elseif WorldMapFrame then WorldMapFrame:Show() end
    end)
    f.next = UI:Button(right, "›", 28, 24, "secondary")
    f.next:SetPoint("RIGHT", f.mapBtn, "LEFT", -8, 0)
    f.next:SetScript("OnClick", function() f:Step(1) end)
    f.prev = UI:Button(right, "‹", 28, 24, "secondary")
    f.prev:SetPoint("RIGHT", f.next, "LEFT", -4, 0)
    f.prev:SetScript("OnClick", function() f:Step(-1) end)
    f.hero = card(right, true)
    f.hero:SetPoint("TOPLEFT", 16, -52); f.hero:SetPoint("TOPRIGHT", -16, -52); f.hero:SetHeight(210)
    f.small = {}
    for i = 1, 4 do
        local c = card(right, false)
        c:SetHeight(122)
        f.small[i] = c
    end
    local function place()
        local w = ((right:GetWidth() or (W - LEFT_W)) - 32 - 10) / 2
        for i, c in ipairs(f.small) do
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 16 + col * (w + 10), -272 - row * 132)
            c:SetWidth(w)
        end
    end
    place()
    -- molette : histoire suivante / précédente
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, d) f:Step(d < 0 and 1 or -1) end)

    function f:Step(d)
        local n = #(self.list or {})
        if n == 0 then return end
        self.i = ((self.i or 1) - 1 + d) % n + 1
        self.acc = 0
        self:PaintStories()
    end
    function f:PaintStories()
        local list, n = self.list or {}, #(self.list or {})
        self.pos:SetText(n > 0 and string.format("%d / %d", self.i or 1, n) or "")
        self.hero:Set(list[self.i or 1])
        for k, c in ipairs(self.small) do
            c:Set(n > k and list[((self.i or 1) - 1 + k) % n + 1] or nil)
        end
    end

    -- vol : trajet, position, temps
    function f:PaintFlight()
        local fl = F():Current()
        local r1, g1, b1 = UI:Accent()
        if not fl then
            self.kicker:SetText(T("AU SOL"))
            self.route:SetText(T("Statistiques du compte"))
            self.eta:SetText("")
        else
            self.kicker:SetText(T("EN VOL"))
            self.route:SetText(short(fl.from) .. " » " .. short(fl.to))
            local el = GetTime() - (fl.start or GetTime())
            local remain = fl.est and math.max(0, fl.est - el)
            self.eta:SetText(remain and string.format(T("arrivée dans %s · trajet %s"), mmss(remain), mmss(fl.est)) or string.format(T("en l'air depuis %s"), mmss(el)))
        end
        self.lines:Reset()
        for _, d in ipairs(self.dots) do d:Hide() end
        self.fromT:SetText(""); self.toT:SetText("")
        local cont, pts
        if fl then cont, pts = F():Path(fl.from, fl.to) end
        self.mapEmpty:SetShown(fl ~= nil and not (pts and #pts >= 4))
        if not (pts and #pts >= 4) then return end
        local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
        for i = 1, #pts, 2 do
            minx, maxx = math.min(minx, pts[i]), math.max(maxx, pts[i])
            miny, maxy = math.min(miny, pts[i + 1]), math.max(maxy, pts[i + 1])
        end
        local mw, mh = self.map:GetWidth() - 40, self.map:GetHeight() - 40
        local k = math.min(mw / math.max(maxy - miny, 1), mh / math.max(maxx - minx, 1))
        -- monde : x vers le nord, y vers l'ouest ; écran : droite = est, haut = nord
        local function at(x, y)
            local sx = 20 + (mw - (maxy - miny) * k) / 2 + (maxy - y) * k
            local sy = 20 + (mh - (maxx - minx) * k) / 2 + (maxx - x) * k
            return sx, sy
        end
        local px, py
        for i = 1, #pts - 2, 2 do
            local x1, y1 = at(pts[i], pts[i + 1])
            local x2, y2 = at(pts[i + 2], pts[i + 3])
            self.lines:Add(self.map, x1, y1, x2, y2, 2.5, r1, g1, b1, 0.9)
            if i == 1 then px, py = x1, y1 end
        end
        local ex, ey = at(pts[#pts - 1], pts[#pts])
        local function dot(i, x, y, size, col)
            local d = self.dots[i]
            d:SetSize(size, size); d:ClearAllPoints(); d:SetPoint("CENTER", self.map, "TOPLEFT", x, -y)
            d:SetVertexColor(col[1], col[2], col[3], 1); d:Show()
        end
        dot(1, px, py, 10, C.muted)
        dot(2, ex, ey, 12, { r1, g1, b1 })
        self.fromT:ClearAllPoints(); self.fromT:SetPoint("TOP", self.map, "TOPLEFT", px, -py - 8); self.fromT:SetText(short(fl.from))
        self.toT:ClearAllPoints(); self.toT:SetPoint("BOTTOM", self.map, "TOPLEFT", ex, -ey + 8); self.toT:SetText(short(fl.to))
        local p = WK.modules.Guide:PlayerPos()
        if p and p.cont == cont then
            local x, y = at(p.wx, p.wy)
            if x > 0 and y > 0 and x < self.map:GetWidth() and y < self.map:GetHeight() then dot(3, x, y, 14, C.text) end
        end
    end
    function f:PaintLog()
        local log = WK.DB.global.flights and WK.DB.global.flights.log or {}
        local month, secs, by = 0, 0, {}
        local since = time() - 30 * 86400
        for _, e in ipairs(log) do
            if (e.t or 0) >= since then month = month + 1; secs = secs + (e.dur or 0) end
            local k = short(e.from) .. " » " .. short(e.to)
            by[k] = (by[k] or 0) + 1
        end
        local best, bn = nil, 0
        for k, n in pairs(by) do if n > bn then best, bn = k, n end end
        local rows = { { T("Vols ces 30 jours"), tostring(month) },
            { T("Temps en l'air (30 j)"), string.format("%d h %02d", math.floor(secs / 3600), math.floor(secs % 3600 / 60)) },
            { T("Trajet le plus pris"), best or "-" } }
        for i, r in ipairs(self.stat) do
            r.a:SetText(rows[i][1]); r.b:SetText(rows[i][2])
            r.b:SetWidth(LEFT_W - 36 - (r.a:GetStringWidth() or 80) - 8)
            if r.b.SetWordWrap then r.b:SetWordWrap(false) end
        end
    end
    f:SetScript("OnShow", function(s)
        s.list = stories()
        s.i = 1
        s.acc = 0
        s:PaintStories(); s:PaintFlight(); s:PaintLog()
    end)
    f:SetScript("OnUpdate", function(s, el)
        s.tick = (s.tick or 0) + el
        if s.tick >= 1 then s.tick = 0; s:PaintFlight() end
        if s:IsMouseOver() then return end
        s.acc = (s.acc or 0) + el
        if s.acc >= ROTATE then s:Step(1) end
    end)
    return f
end

function UI:ShowFlightStats()
    if InCombatLockdown and InCombatLockdown() then return end
    view = view or build()
    view:Show()
end
function UI:FlightStats() return view end

---------------------------------------------------------------------------
-- À la place de la carte en vol, au décollage (réglage), fermée à l'atterrissage
---------------------------------------------------------------------------
local hooked = false
local function hookMap()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", function()
        if not (cfg().stats and onTaxi()) or (view and view.allowMap) then return end
        C_Timer.After(0, function()
            if InCombatLockdown and InCombatLockdown() then return end
            if WorldMapFrame:IsShown() and HideUIPanel then HideUIPanel(WorldMapFrame) end
            UI:ShowFlightStats()
        end)
    end)
    WorldMapFrame:HookScript("OnHide", function() if view then view.allowMap = nil end end)
end
WK:On("PLAYER_LOGIN", hookMap)
WK:On("ADDON_LOADED", function() hookMap() end)

local Fl = F()
local prevStart, prevFinish = Fl.OnStart, Fl.OnFinish
Fl.OnStart = function(...)
    if prevStart then prevStart(...) end
    if cfg().statsAuto and cfg().stats ~= false then C_Timer.After(1, function() if onTaxi() then UI:ShowFlightStats() end end) end
end
Fl.OnFinish = function(...)
    if prevFinish then prevFinish(...) end
    if view then view:Hide(); view.allowMap = nil end
end
