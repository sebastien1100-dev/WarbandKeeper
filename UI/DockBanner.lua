local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Bandeau au quai : à moins de 120 m d'un quai (gardé jusqu'à 200 m) de bateau ou de zeppelin, le prochain départ appris
-- (Modules/BoatTimes.lua) pour chaque destination ; barre qui se vide jusqu'au départ, verte quand le
-- bateau est à quai. Caché une fois à bord. Réglage Guide:Config().dockBanner (QoL > Carte, Navigation).
-- 120 m pour apparaître (le ponton peut être long), 200 m pour disparaître : il reste affiché tant qu'on attend sur le ponton
local RANGE_IN, RANGE_OUT, W = 120, 200, 340
local banner

local function BT() return WK.modules.BoatTimes end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- destinations du quai le plus proche (moins de range m) : { { line, side, to, kind } }
local function nearDock(range)
    local G, L = WK.modules.Guide, WK.modules.MapLayers
    local p = G and G:PlayerPos()
    if not (p and p.cont and L) then return nil end
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    fac = fac == "Alliance" and "A" or fac == "Horde" and "H" or nil
    local out, bestD = {}, nil
    for _, l in ipairs(L:AllTransports()) do
        if not (l.side and l.side ~= fac) then
            for _, sd in ipairs({ "a", "b" }) do
                local here = l[sd]
                local c, x, y = G.ToWorld(here[1], here[2] / 100, here[3] / 100)
                if c == p.cont and x then
                    local d = dist(x, y, p.wx, p.wy)
                    if d < range then
                        table.insert(out, { line = l, side = sd, to = (sd == "a" and l.b or l.a)[4], kind = l.kind, d = d })
                        bestD = math.min(bestD or d, d)
                    end
                end
            end
        end
    end
    if #out == 0 then return nil end
    table.sort(out, function(a, b) return a.d < b.d end)
    return out
end

local SAMPLE = { { to = "Auberdine", kind = "boat", st = { inn = 42, following = 362, atDock = true, w = 45, P = 320 } },
    { to = "Theramore", kind = "boat", st = { inn = 190, following = 510, atDock = false, w = 45, P = 320 } } }

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDockBanner", UIParent)
    f:SetSize(W, 60)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.icon = UI:Icon(f, "boat", 22, nil, "ARTWORK"); f.icon:SetPoint("TOPLEFT", 14, -14)
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 46, -12); f.title:SetPoint("RIGHT", -60, 0)
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.time = UI:Text(f, 18); f.time:SetPoint("TOPRIGHT", -14, -10); f.time:SetJustifyH("RIGHT")
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("TOPLEFT", 46, -30); f.sub:SetPoint("RIGHT", -14, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.track = f:CreateTexture(nil, "ARTWORK"); f.track:SetHeight(4)
    f.track:SetPoint("BOTTOMLEFT", 14, 10); f.track:SetPoint("BOTTOMRIGHT", -14, 10)
    f.fill = f:CreateTexture(nil, "ARTWORK", nil, 2); f.fill:SetHeight(4); f.fill:SetPoint("LEFT", f.track, "LEFT")
    f.more = UI:Text(f, 10, C.dim); f.more:SetPoint("BOTTOMLEFT", 14, 18); f.more:SetPoint("RIGHT", -14, 0)
    if f.more.SetWordWrap then f.more:SetWordWrap(false) end
    -- list = { { to, kind, st (BoatTimes:State) ou nil } }
    function f:Paint(list)
        local first = list[1]
        local st = first.st
        local zep = first.kind == "zeppelin"
        self.icon:SetTexture(UI.MEDIA .. (zep and "zeppelin" or "boat"))
        local ic = zep and C.warning or C.positive
        self.icon:SetVertexColor(ic[1], ic[2], ic[3], 1)
        self.title:SetText(string.format(zep and T("Zeppelin pour %s") or T("Bateau pour %s"), first.to or "?"))
        local Clock = BT().Clock
        local h = 60
        if st then
            local pre = st.est and "~" or ""
            self.time:SetText(pre .. Clock(st.inn))
            local col = st.atDock and C.positive or (st.inn < 60 and C.gold or C.text)
            self.time:SetTextColor(col[1], col[2], col[3])
            self.sub:SetText(st.atDock and string.format(T("À quai : monte, il part dans %s"), pre .. Clock(st.inn))
                or string.format(T("Arrive au quai dans %s · suivant dans %s"), pre .. Clock(math.max(0, st.inn - st.w)), pre .. Clock(st.following)))
            self.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            local tw = W - 28
            local frac = 1 - math.max(0, math.min(1, st.inn / math.max(1, st.P)))
            self.fill:SetColorTexture(col[1], col[2], col[3], 1)
            self.fill:SetWidth(math.max(0.01, tw * frac))
            self.track:Show(); self.fill:Show()
        else
            self.time:SetText("")
            self.sub:SetText(T("Horaires pas encore connus : prends-le une fois pour les apprendre."))
            self.track:Hide(); self.fill:Hide()
        end
        -- autres destinations du même quai
        local others = {}
        for i = 2, #list do
            local o = list[i]
            local txt = o.to or "?"
            if o.st then txt = txt .. " " .. (o.st.est and "~" or "") .. Clock(o.st.inn) end
            table.insert(others, txt)
        end
        self.more:SetShown(#others > 0)
        if #others > 0 then
            self.more:SetText(T("Ici aussi : ") .. table.concat(others, "  ·  "))
            self.track:ClearAllPoints(); self.track:SetPoint("BOTTOMLEFT", 14, 10); self.track:SetPoint("BOTTOMRIGHT", -14, 10)
            h = 74
            self.more:ClearAllPoints(); self.more:SetPoint("TOPLEFT", 46, -48); self.more:SetPoint("RIGHT", -14, 0)
        end
        self:SetHeight(h)
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
    })
    return f
end

function UI:RefreshDockBanner()
    if not banner then banner = build() end
    if banner.sample then return end
    local Nv = WK.modules.Nav
    if not WK.modules.Guide:Config().dockBanner or (Nv and Nv.IsRiding and Nv.IsRiding()) or (UnitOnTaxi and UnitOnTaxi("player"))
        or (IsInInstance and IsInInstance()) then
        banner:Hide() return
    end
    local docks = nearDock(banner:IsShown() and RANGE_OUT or RANGE_IN)
    if not docks then
        -- position illisible un instant (chargement, carte) : on garde le bandeau quelques secondes
        if banner:IsShown() and banner.lastSeen and GetTime() - banner.lastSeen < 5 and not (WK.modules.Guide:PlayerPos() or {}).cont then return end
        banner:Hide() return
    end
    banner.lastSeen = GetTime()
    local list = {}
    for _, d in ipairs(docks) do table.insert(list, { to = d.to, kind = d.kind, st = BT():State(d.line, d.side) }) end
    -- le départ le plus proche en tête
    table.sort(list, function(a, b)
        if (a.st ~= nil) ~= (b.st ~= nil) then return a.st ~= nil end
        return a.st and b.st and a.st.inn < b.st.inn or false
    end)
    banner:Paint(list)
    banner:Show()
end

-- vérifié toutes les 2 s (le bandeau, une fois visible, se met à jour chaque seconde)
WK:On("PLAYER_LOGIN", function()
    if C_Timer and C_Timer.NewTicker then
        C_Timer.NewTicker(2, function() if not (banner and banner:IsShown()) then pcall(UI.RefreshDockBanner, UI) end end)
    end
end)
