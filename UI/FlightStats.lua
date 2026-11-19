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
-- Icône (Media) et couleur de chaque catégorie (couleurs du thème, lues à l'affichage)
local STYLE = {
    ["ARGENT"] = { "coin", "gold" }, ["OR DU COMPTE"] = { "coin", "gold" }, ["PERSOS"] = { "person", "accent" },
    ["DONJONS"] = { "skull", "negative" }, ["PÊCHE"] = { "fish", "info" }, ["QUÊTES"] = { "bang", "warning" },
    ["RARES"] = { "crosshair", "rare" }, ["HÔTEL DES VENTES"] = { "chart", "gold" }, ["VOLS"] = { "griffon", "info" },
    ["COMPTE"] = { "users", "mint" }, ["RÉCOLTE"] = { "collect", "positive" },
}
local function tone(key)
    if key == "accent" then local r, g, b = UI:Accent(); return { r, g, b } end
    return C[key] or C.text
end
local function stories()
    local g = WK.DB.global
    local out = {}
    local function add(fn)
        local ok, e = pcall(fn)
        if ok and e then
            for k, st in pairs(STYLE) do
                if e.cat == T(k) then e.icon = e.icon or st[1]; e.tone = e.tone or st[2] end
            end
            table.insert(out, e)
        end
    end
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
        local each = {}
        for key, c in pairs(g.characters) do
            n = n + 1
            total = total + (c.played or 0)
            if (c.played or 0) > top then top, topKey = c.played, key end
            if (c.played or 0) > 0 then table.insert(each, { key = key, c = c, secs = c.played }) end
        end
        if total < 3600 then return nil end
        local c = g.characters[topKey]
        -- barre du temps de jeu : les trois persos les plus joués, puis le reste
        table.sort(each, function(a, b) return a.secs > b.secs end)
        local split, rest = {}, 0
        local cols = { "gold", "positive", "info" }
        for i, e in ipairs(each) do
            if i <= 3 then
                table.insert(split, { name = WK:CharName(e.c, e.key), secs = e.secs, tone = cols[i] })
            else rest = rest + e.secs end
        end
        if rest > 0 then table.insert(split, { name = T("autres"), secs = rest, tone = "silver" }) end
        return { cat = T("PERSOS"), big = string.format(T("%d h"), math.floor(total / 3600)), split = split, total = total,
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
    -- teinte de la catégorie (dégradé vers la droite) et liseré à gauche
    c.tint = c:CreateTexture(nil, "BORDER")
    c.tint:SetPoint("TOPLEFT", 4, -4); c.tint:SetPoint("BOTTOMRIGHT", -4, 4)
    c.strip = c:CreateTexture(nil, "ARTWORK")
    c.strip:SetWidth(3); c.strip:SetPoint("TOPLEFT", 1, -8); c.strip:SetPoint("BOTTOMLEFT", 1, 8)
    -- pastille : icône sur un carré arrondi de la couleur
    local chip = big and 40 or 24
    c.chip = CreateFrame("Frame", nil, c)
    c.chip:SetSize(chip, chip); c.chip:SetPoint("TOPLEFT", 14, -12)
    UI:Panel(c.chip, big and 9 or 6, { 1, 1, 1, 0.15 })
    c.icon = UI:Icon(c.chip, "star", big and 22 or 14, nil, "OVERLAY")
    c.icon:SetPoint("CENTER")
    c.cat = UI:Text(c, 10, C.muted)
    if big then c.cat:SetPoint("TOPLEFT", c.chip, "TOPRIGHT", 12, -1)
    else c.cat:SetPoint("LEFT", c.chip, "RIGHT", 8, 0) end
    c.big = UI:Text(c, big and 30 or 20, C.text)
    if big then c.big:SetPoint("TOPLEFT", c.cat, "BOTTOMLEFT", 0, -2)
    else c.big:SetPoint("TOPLEFT", c.chip, "BOTTOMLEFT", 0, -6) end
    c.text = UI:Text(c, big and 13 or 11, C.text)
    if big then c.text:SetPoint("TOPLEFT", c.chip, "BOTTOMLEFT", 0, -10)
    else c.text:SetPoint("TOPLEFT", c.big, "BOTTOMLEFT", 0, -4) end
    c.text:SetPoint("RIGHT", -14, 0); c.text:SetJustifyH("LEFT")
    if c.text.SetWordWrap then c.text:SetWordWrap(true) end
    if big then
        c.bars = {}
        for i = 1, 8 do
            local b = c:CreateTexture(nil, "ARTWORK")
            c.bars[i] = b
        end
        c.sub = UI:Text(c, 10, C.dim); c.sub:SetPoint("BOTTOMLEFT", 14, 8)
        -- temps de jeu par perso : une barre en parts et la légende
        c.segs = {}
        for i = 1, 4 do c.segs[i] = c:CreateTexture(nil, "ARTWORK") end
        c.legend = UI:Text(c, 10, C.muted)
        c.legend:SetPoint("TOPLEFT", c.text, "BOTTOMLEFT", 0, -22); c.legend:SetJustifyH("LEFT")
    end
    function c:Set(e)
        self:SetShown(e ~= nil)
        if not e then return end
        local col = e.color or tone(e.tone or "text")
        self.cat:SetText(e.cat)
        self.cat:SetTextColor(col[1], col[2], col[3], 1)
        self.big:SetText(e.big)
        self.big:SetTextColor(col[1], col[2], col[3], 1)
        self.text:SetText(e.text)
        self.icon:SetTexture(UI.MEDIA .. (e.icon or "star"))
        self.icon:SetVertexColor(col[1], col[2], col[3], 1)
        self.chip.bg:SetColor(col[1], col[2], col[3], 0.18)
        self.strip:SetColorTexture(col[1], col[2], col[3], self.bars and 0 or 0.9)
        self.tint:SetColorTexture(1, 1, 1, 1)
        local okG = self.tint.SetGradient and CreateColor and pcall(self.tint.SetGradient, self.tint, "HORIZONTAL",
            CreateColor(col[1], col[2], col[3], self.bars and 0.13 or 0.07), CreateColor(col[1], col[2], col[3], 0))
        if not okG then self.tint:SetColorTexture(col[1], col[2], col[3], 0.05) end
        if not self.bars then return end
        -- parts du temps de jeu
        local split = e.split
        local full = (self:GetWidth() or 500) - 28
        local x = 14
        local leg = {}
        for i, sg in ipairs(self.segs) do
            local part = split and split[i]
            if part and (e.total or 0) > 0 then
                local sw = math.max(2, math.floor(full * part.secs / e.total))
                local pc = tone(part.tone)
                sg:ClearAllPoints(); sg:SetPoint("TOPLEFT", self.text, "BOTTOMLEFT", x - 14, -8); sg:SetSize(sw, 8)
                sg:SetColorTexture(pc[1], pc[2], pc[3], 1); sg:Show()
                x = x + sw
                table.insert(leg, UI:Hex(pc) .. "•|r " .. part.name .. " " .. string.format(T("%d h"), math.floor(part.secs / 3600)))
            else sg:Hide() end
        end
        self.legend:SetText(table.concat(leg, "    "))
        local vals = e.bars
        local w = (self:GetWidth() or 500) - 28
        local bw = math.floor((w - 7 * 6) / 8)
        local mx = 0
        for _, v in ipairs(vals or {}) do mx = math.max(mx, v) end
        for i, b in ipairs(self.bars) do
            local v = vals and vals[i]
            if v and mx > 0 then
                local h = math.max(3, 56 * v / mx)
                b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", 14 + (i - 1) * (bw + 6), 24); b:SetSize(bw, h)
                local last = i == #vals
                b:SetColorTexture(col[1], col[2], col[3], last and 1 or 0.45)
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
    -- barre de progression du vol, puis « arrivée dans » à gauche et la durée du trajet à droite
    f.barBg = left:CreateTexture(nil, "ARTWORK")
    f.barBg:SetHeight(5); f.barBg:SetPoint("TOPLEFT", f.route, "BOTTOMLEFT", 0, -9); f.barBg:SetWidth(LEFT_W - 36)
    f.barBg:SetColorTexture(1, 1, 1, 0.08)
    f.bar = left:CreateTexture(nil, "OVERLAY")
    f.bar:SetHeight(5); f.bar:SetPoint("TOPLEFT", f.barBg, "TOPLEFT")
    f.eta = UI:Text(left, 11, C.muted); f.eta:SetPoint("TOPLEFT", f.barBg, "BOTTOMLEFT", 0, -6)
    f.etaR = UI:Text(left, 11, C.muted); f.etaR:SetPoint("TOPRIGHT", f.barBg, "BOTTOMRIGHT", 0, -6)
    f.etaR:SetJustifyH("RIGHT")
    f.map = CreateFrame("Frame", nil, left)
    f.map:SetSize(LEFT_W - 36, 214); f.map:SetPoint("TOPLEFT", 18, -108)
    UI:Panel(f.map, 10, { 0, 0, 0, 0.35 }, C.border)
    -- fond : la carte du continent du jeu (tuiles), assombrie, découpée au cadre
    f.art = CreateFrame("Frame", nil, f.map)
    f.art:SetPoint("TOPLEFT", 2, -2); f.art:SetPoint("BOTTOMRIGHT", -2, 2)
    if f.art.SetClipsChildren then f.art:SetClipsChildren(true) end
    f.art.canvas = CreateFrame("Frame", nil, f.art)
    f.art.canvas:SetAllPoints(f.art)
    f.art.tiles = {}
    f.art.shade = f.art:CreateTexture(nil, "OVERLAY", nil, 1)
    f.art.shade:SetAllPoints(); f.art.shade:SetColorTexture(0, 0, 0, 0.5)
    f.lines = UI:LinePool(4)
    f.route2 = CreateFrame("Frame", nil, f.map)
    f.route2:SetAllPoints(f.map); f.route2:SetFrameLevel(f.art:GetFrameLevel() + 5)
    f.dots = {}
    for i = 1, 3 do
        local d = f.route2:CreateTexture(nil, "OVERLAY", nil, 7)
        d:SetTexture(UI.MEDIA .. "circle")
        f.dots[i] = d
    end
    -- le perso : une flèche blanche tournée dans le sens du vol, sur un halo de la couleur de l'apparence
    f.halo = f.route2:CreateTexture(nil, "OVERLAY", nil, 5)
    f.halo:SetTexture(UI.MEDIA .. "circle"); f.halo:SetSize(30, 30)
    f.halo2 = f.route2:CreateTexture(nil, "OVERLAY", nil, 6)
    f.halo2:SetTexture(UI.MEDIA .. "circle"); f.halo2:SetSize(20, 20)
    f.plane = f.route2:CreateTexture(nil, "OVERLAY", nil, 7)
    f.plane:SetTexture(UI.MEDIA .. "navarrow"); f.plane:SetSize(20, 20)
    f.fromT = UI:Text(f.route2, 10, C.muted); f.toT = UI:Text(f.route2, 10, C.text)
    f.mapEmpty = UI:Text(f.route2, 11, C.dim); f.mapEmpty:SetPoint("CENTER"); f.mapEmpty:SetText(T("trajet pas encore connu"))
    f.stat = {}
    local STAT_STYLE = { { "griffon", "info" }, { "clock", "rule" }, { "star", "gold" } }
    for i = 1, 3 do
        local r = CreateFrame("Frame", nil, left)
        r:SetHeight(28)
        r:SetPoint("TOPLEFT", 18, -334 - (i - 1) * 30); r:SetPoint("TOPRIGHT", -18, -334 - (i - 1) * 30)
        local col = C[STAT_STYLE[i][2]] or C.text
        r.chip = CreateFrame("Frame", nil, r)
        r.chip:SetSize(22, 22); r.chip:SetPoint("LEFT")
        UI:Panel(r.chip, 6, { col[1], col[2], col[3], 0.18 })
        r.icon = UI:Icon(r.chip, STAT_STYLE[i][1], 13, col, "OVERLAY"); r.icon:SetPoint("CENTER")
        r.a = UI:Text(r, 11, C.text); r.a:SetPoint("LEFT", r.chip, "RIGHT", 8, 0)
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
    -- histoire suivante / précédente : boutons ronds avec un chevron (les « ‹ › » de la police étaient minuscules)
    f.next = UI:IconButton(right, "chevron", 24, "Histoire suivante (molette)")
    f.next:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    if f.next.icon.SetRotation then f.next.icon:SetRotation(math.pi / 2) end
    f.next:SetScript("OnClick", function() f:Step(1) end)
    f.prev = UI:IconButton(right, "chevron", 24, "Histoire précédente (molette)")
    f.prev:SetPoint("RIGHT", f.next, "LEFT", -6, 0)
    if f.prev.icon.SetRotation then f.prev.icon:SetRotation(-math.pi / 2) end
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

    -- Fond du trajet : tuiles de la carte du continent (C_Map), placées par la même projection que le trajet.
    -- Refait seulement quand le trajet ou l'échelle change.
    local CONTMAP = { [0] = 1415, [1] = 1414 }
    function f:PaintArt(cont, at, key)
        local a = self.art
        if a.key == key then return end
        a.key = key
        for _, t in ipairs(a.tiles) do t:Hide() end
        local mapID = CONTMAP[cont]
        if not (mapID and C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
        local okL, layers = pcall(C_Map.GetMapArtLayers, mapID)
        local L = okL and layers and layers[1]
        local okT, files = pcall(C_Map.GetMapArtLayerTextures, mapID, 1)
        if not (L and okT and files and #files > 0) then return end
        local function corner(u, v)
            local ok, _, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(u, v))
            if not (ok and pos) then return nil end
            local x, y = pos.x, pos.y
            if pos.GetXY then x, y = pos:GetXY() end
            return x, y
        end
        local ax, ay = corner(0, 0)
        local bx, by = corner(1, 1)
        if not (ax and bx) then return end
        local tw, th = L.tileWidth or 256, L.tileHeight or 256
        local lw, lh = L.layerWidth or tw, L.layerHeight or th
        local cols = math.ceil(lw / tw)
        local aw, ah = self.art:GetWidth() or 0, self.art:GetHeight() or 0
        local n = 0
        for idx, file in ipairs(files) do
            local col, row = (idx - 1) % cols, math.floor((idx - 1) / cols)
            local u0, u1 = col * tw / lw, (col + 1) * tw / lw
            local v0, v1 = row * th / lh, (row + 1) * th / lh
            -- coin carte (u, v) » monde : x suit v (nord-sud), y suit u (est-ouest)
            local x0, y0 = at(ax + v0 * (bx - ax), ay + u0 * (by - ay))
            local x1, y1 = at(ax + v1 * (bx - ax), ay + u1 * (by - ay))
            x0, y0 = x0 - 2, y0 - 2; x1, y1 = x1 - 2, y1 - 2 -- cadre de la carte décalé de 2 px
            if x1 > 0 and y1 > 0 and x0 < aw and y0 < ah and n < 40 then
                n = n + 1
                local t = a.tiles[n]
                if not t then t = a.canvas:CreateTexture(nil, "BACKGROUND"); a.tiles[n] = t end
                t:SetTexture(file)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", a.canvas, "TOPLEFT", x0, -y0)
                t:SetSize(math.max(1, x1 - x0), math.max(1, y1 - y0))
                t:Show()
            end
        end
    end

    -- vol : trajet, position, temps
    function f:PaintFlight()
        local fl = F():Current()
        local r1, g1, b1 = UI:Accent()
        local frac
        if not fl then
            self.kicker:SetText(T("AU SOL"))
            self.route:SetText(T("Statistiques du compte"))
            self.eta:SetText(""); self.etaR:SetText("")
        else
            self.kicker:SetText(T("EN VOL"))
            self.route:SetText(short(fl.from) .. " " .. UI:Hex({ r1, g1, b1 }) .. "»|r " .. short(fl.to))
            local el = GetTime() - (fl.start or GetTime())
            local remain = fl.est and math.max(0, fl.est - el)
            if remain then
                self.eta:SetText(string.format(T("arrivée dans %s"), UI:Hex(C.text) .. mmss(remain) .. "|r"))
                self.etaR:SetText(string.format(T("%s de trajet"), mmss(fl.est)))
                frac = fl.est > 0 and math.min(1, el / fl.est) or nil
            else
                self.eta:SetText(string.format(T("en l'air depuis %s"), mmss(el))); self.etaR:SetText("")
            end
        end
        self.barBg:SetShown(frac ~= nil); self.bar:SetShown(frac ~= nil and frac > 0)
        if frac then
            self.bar:SetWidth(math.max(1, (LEFT_W - 36) * frac))
            self.bar:SetColorTexture(r1, g1, b1, 1)
        end
        self.lines:Reset()
        for _, d in ipairs(self.dots) do d:Hide() end
        self.plane:Hide(); self.halo:Hide(); self.halo2:Hide()
        self.fromT:SetText(""); self.toT:SetText("")
        local cont, pts
        if fl then cont, pts = F():Path(fl.from, fl.to) end
        self.mapEmpty:SetShown(fl ~= nil and not (pts and #pts >= 4))
        if not (pts and #pts >= 4) then
            for _, t in ipairs(self.art.tiles) do t:Hide() end
            self.art.key = nil
            return
        end
        local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
        for i = 1, #pts, 2 do
            minx, maxx = math.min(minx, pts[i]), math.max(maxx, pts[i])
            miny, maxy = math.min(miny, pts[i + 1]), math.max(maxy, pts[i + 1])
        end
        local mw, mh = self.map:GetWidth() - 40, self.map:GetHeight() - 40
        -- échelle : le trajet remplit le cadre, sans trop grossir la carte (au plus ~1 m pour 2 px)
        local k = math.min(mw / math.max(maxy - miny, 1), mh / math.max(maxx - minx, 1), 0.5)
        -- monde : x vers le nord, y vers l'ouest ; écran : droite = est, haut = nord
        local function at(x, y)
            local sx = 20 + (mw - (maxy - miny) * k) / 2 + (maxy - y) * k
            local sy = 20 + (mh - (maxx - minx) * k) / 2 + (maxx - x) * k
            return sx, sy
        end
        self:PaintArt(cont, at, table.concat({ cont, fl.from or "", fl.to or "", math.floor(mw), math.floor(mh) }, "|"))
        -- longueur du trajet, pour couper la partie faite
        local segs, total = {}, 0
        for i = 1, #pts - 2, 2 do
            local d = math.sqrt((pts[i + 2] - pts[i]) ^ 2 + (pts[i + 3] - pts[i + 1]) ^ 2)
            segs[#segs + 1] = d; total = total + d
        end
        local done = (frac or 0) * total
        local acc, px, py, hx, hy = 0, nil, nil, nil, nil
        local dirx, diry -- sens du vol à l'écran (segment en cours)
        local cv = self.route2
        for i = 1, #pts - 2, 2 do
            local x1, y1 = at(pts[i], pts[i + 1])
            local x2, y2 = at(pts[i + 2], pts[i + 3])
            if i == 1 then px, py = x1, y1; dirx, diry = x2 - x1, y2 - y1 end
            local d = segs[(i + 1) / 2]
            if acc + d <= done then
                self.lines:Add(cv, x1, y1, x2, y2, 3, r1, g1, b1, 1) -- déjà fait : trait plein
            elseif acc >= done then
                self.lines:Add(cv, x1, y1, x2, y2, 2, r1, g1, b1, 0.45) -- reste : trait pâle
            else
                local t = (done - acc) / math.max(d, 0.001)
                local mx, my = x1 + (x2 - x1) * t, y1 + (y2 - y1) * t
                self.lines:Add(cv, x1, y1, mx, my, 3, r1, g1, b1, 1)
                self.lines:Add(cv, mx, my, x2, y2, 2, r1, g1, b1, 0.45)
                hx, hy = mx, my
                dirx, diry = x2 - x1, y2 - y1
            end
            acc = acc + d
        end
        local ex, ey = at(pts[#pts - 1], pts[#pts])
        local function dot(i, x, y, size, col)
            local d = self.dots[i]
            d:SetSize(size, size); d:ClearAllPoints(); d:SetPoint("CENTER", cv, "TOPLEFT", x, -y)
            d:SetVertexColor(col[1], col[2], col[3], 1); d:Show()
        end
        dot(1, px, py, 10, C.muted)
        dot(2, ex, ey, 12, { r1, g1, b1 })
        self.fromT:ClearAllPoints(); self.fromT:SetPoint("TOP", cv, "TOPLEFT", px, -py - 8); self.fromT:SetText(short(fl.from))
        self.toT:ClearAllPoints(); self.toT:SetPoint("BOTTOM", cv, "TOPLEFT", ex, -ey + 8); self.toT:SetText(short(fl.to))
        -- le griffon : position du perso si elle est lisible, sinon l'avancée estimée sur le trajet
        local p = WK.modules.Guide:PlayerPos()
        if p and p.cont == cont then
            local x, y = at(p.wx, p.wy)
            if x > 0 and y > 0 and x < cv:GetWidth() and y < cv:GetHeight() then hx, hy = x, y end
        end
        if hx then
            -- orientation : le cap du perso (radians, sens antihoraire depuis le nord = haut de la carte),
            -- sinon la direction du segment en cours
            local rot
            local okF, facing = pcall(function() return GetPlayerFacing and GetPlayerFacing() end)
            if okF and type(facing) == "number" then rot = facing
            elseif dirx and (dirx ~= 0 or diry ~= 0) then rot = math.atan2(-dirx, -diry) end
            for _, t in ipairs({ self.halo, self.halo2, self.plane }) do
                t:ClearAllPoints(); t:SetPoint("CENTER", cv, "TOPLEFT", hx, -hy); t:Show()
            end
            self.halo:SetVertexColor(r1, g1, b1, 0.14)
            self.halo2:SetVertexColor(r1, g1, b1, 0.26)
            self.plane:SetVertexColor(1, 1, 1, 1)
            if self.plane.SetRotation then self.plane:SetRotation(rot or 0) end
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
            r.b:SetWidth(LEFT_W - 36 - 30 - (r.a:GetStringWidth() or 80) - 8)
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
    -- réglage indépendant de « à la place de la carte » : il ouvre les statistiques même si M ouvre la carte
    if cfg().statsAuto then C_Timer.After(1, function() if onTaxi() then UI:ShowFlightStats() end end) end
end
Fl.OnFinish = function(...)
    if prevFinish then prevFinish(...) end
    if view then view:Hide(); view.allowMap = nil end
end
