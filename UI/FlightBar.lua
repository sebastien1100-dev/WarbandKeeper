local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Barre de vol « arc de vol » (Modules/Flight.lua) : le trajet dessiné en arc pointillé, comme un
-- vol vu de côté. Le griffon glisse le long de l'arc (partie parcourue en couleur d'accent), les
-- relais sont des balises plantées sur l'arc ; temps restant et heure d'arrivée dans un médaillon.
-- Boutons « Atterrir à … », Carte et fermer. Placée et dimensionnée en mode édition.
local F = WK.modules.Flight
local bar

local W, H = 470, 152          -- cadre
local ARC_X, ARC_W = 22, 300   -- zone de l'arc
local ARC_TOP, ARC_BASE = 46, 96 -- sommet et base de l'arc (depuis le haut du cadre)
local DOTS = 44

local function fmt(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

-- Point de l'arc (courbe de Bézier quadratique) pour t entre 0 et 1, en coordonnées du cadre.
local function arcPoint(t)
    local x0, y0 = ARC_X, ARC_BASE
    local x1, y1 = ARC_X + ARC_W / 2, ARC_TOP - (ARC_BASE - ARC_TOP)
    local x2, y2 = ARC_X + ARC_W, ARC_BASE
    local u = 1 - t
    return u * u * x0 + 2 * u * t * x1 + t * t * x2, u * u * y0 + 2 * u * t * y1 + t * t * y2
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperFlightBar", UIParent)
    f:SetSize(W, H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    -- Arc pointillé
    f.dots = {}
    for i = 0, DOTS do
        local d = f:CreateTexture(nil, "ARTWORK")
        d:SetTexture(UI.MEDIA .. "circle")
        local x, y = arcPoint(i / DOTS)
        d:SetPoint("CENTER", f, "TOPLEFT", x, -y)
        f.dots[i] = d
    end
    -- Départ (point plein) et arrivée (anneau)
    f.startDot = UI:Icon(f, "circle", 10, nil, "OVERLAY")
    f.startDot:SetPoint("CENTER", f, "TOPLEFT", arcPoint(0), -ARC_BASE)
    f.endRing = UI:Icon(f, "circle", 12, nil, "OVERLAY")
    f.endRing:SetPoint("CENTER", f, "TOPLEFT", ARC_X + ARC_W, -ARC_BASE)
    f.endHole = UI:Icon(f, "circle", 7, nil, "OVERLAY")
    f.endHole:SetDrawLayer("OVERLAY", 2)
    f.endHole:SetPoint("CENTER", f.endRing, "CENTER")
    f.from = UI:Text(f, 10, C.muted)
    f.from:SetPoint("TOPLEFT", ARC_X - 6, -(ARC_BASE + 8))
    f.to = UI:Text(f, 10, C.text)
    f.to:SetPoint("TOPRIGHT", f, "TOPLEFT", ARC_X + ARC_W + 6, -(ARC_BASE + 8))
    f.to:SetJustifyH("RIGHT")
    -- Balises des relais
    f.stops = UI:Pool(function()
        local st = CreateFrame("Frame", nil, f)
        st:SetSize(12, 20)
        st.pole = st:CreateTexture(nil, "ARTWORK")
        st.pole:SetPoint("BOTTOM")
        st.pole:SetSize(2, 14)
        st.flag = UI:Icon(st, "circle", 8, nil, "OVERLAY")
        st.flag:SetPoint("BOTTOM", st.pole, "TOP", 0, -3)
        st.label = UI:Text(f, 10, C.muted)
        st.label:SetJustifyH("CENTER")
        return st
    end)
    -- Griffon qui glisse sur l'arc
    f.markRing = UI:Icon(f, "circle", 30, nil, "OVERLAY")
    f.mark = UI:RoundIcon(f, 26, "Interface\\Icons\\Ability_Mount_Gryphon_01")
    f.mark:SetDrawLayer("OVERLAY", 3)
    -- Médaillon : temps restant et heure d'arrivée
    f.medal = CreateFrame("Frame", nil, f)
    f.medal:SetSize(100, 100)
    f.medal:SetPoint("TOPRIGHT", -30, -10)
    f.medalRing = UI:Icon(f.medal, "circle", 100, nil, "ARTWORK")
    f.medalRing:SetPoint("CENTER")
    f.medalIn = UI:Icon(f.medal, "circle", 95, nil, "OVERLAY")
    f.medalIn:SetPoint("CENTER")
    f.time = UI:Text(f.medal, 22)
    f.time:SetPoint("CENTER", 0, 7)
    f.time:SetJustifyH("CENTER")
    f.eta = UI:Text(f.medal, 10, C.muted)
    f.eta:SetPoint("TOP", f.time, "BOTTOM", 0, -4)
    f.eta:SetJustifyH("CENTER")
    -- Boutons
    f.close = UI:IconButton(f, "close", 20, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -4, -4)
    f.close:SetFrameLevel(f.medal:GetFrameLevel() + 3)
    f.close:SetScript("OnClick", function() f.dismissed = true; f:Hide() end)
    f.map = UI:Button(f, "Carte", nil, 24, "secondary")
    f.map:SetPoint("BOTTOMRIGHT", -14, 10)
    f.map:SetScript("OnClick", function() if ToggleWorldMap then ToggleWorldMap() end end)
    f.land = UI:Button(f, "Atterrir", nil, 24, "primary")
    f.land:SetPoint("RIGHT", f.map, "LEFT", -6, 0)
    f.land:SetScript("OnClick", function() F:LandEarly() end)
    f.note = UI:Text(f, 10, C.muted)
    f.note:SetPoint("BOTTOMLEFT", 16, 16)
    f.elapsed = 0
    f:SetScript("OnUpdate", function(s, el)
        s.elapsed = s.elapsed + el
        if s.elapsed < 0.1 then return end
        s.elapsed = 0
        if s.sample then return end
        local fl = F:Current()
        if not fl then s:Hide() return end
        s:Paint(fl)
    end)

    function f:Paint(fl)
        local r, g, b = UI:Accent()
        local elapsed = GetTime() - fl.start
        local p, left
        if fl.est and fl.est > 0 then
            left = math.max(0, fl.est - elapsed)
            p = math.max(0, math.min(1, elapsed / fl.est))
        end
        -- arc : parcouru en couleur d'accent, le reste en pointillé discret
        for i = 0, DOTS do
            local d = self.dots[i]
            local done = p and (i / DOTS) <= p
            d:SetSize(done and 4 or 3, done and 4 or 3)
            if done then d:SetVertexColor(r, g, b, 1)
            elseif i % 2 == 0 then d:SetVertexColor(C.border[1], C.border[2], C.border[3], 1)
            else d:SetVertexColor(0, 0, 0, 0) end
        end
        self.startDot:SetVertexColor(r, g, b, 1)
        self.endRing:SetVertexColor(r, g, b, 1)
        self.endHole:SetVertexColor(unpack(C.bg))
        self.from:SetText(fl.from or "?")
        self.to:SetText(fl.to or "?")
        -- griffon
        self.mark:SetShown(p ~= nil)
        self.markRing:SetShown(p ~= nil)
        if p then
            local x, y = arcPoint(p)
            self.mark:ClearAllPoints()
            self.mark:SetPoint("CENTER", self, "TOPLEFT", x, -y)
            self.markRing:ClearAllPoints()
            self.markRing:SetPoint("CENTER", self.mark, "CENTER")
            self.markRing:SetVertexColor(r, g, b, 1)
        end
        -- relais : balises sur l'arc, noms au-dessus (sans se chevaucher)
        self.stops:Reset()
        for _, st in ipairs(self.stops.items) do st.label:Hide() end
        local stops = fl.stops or {}
        local nextStop, lastX = nil, -1000
        for _, stop in ipairs(stops) do
            local st = self.stops:Get()
            local x, y = arcPoint(stop.frac)
            st:ClearAllPoints()
            st:SetPoint("BOTTOM", self, "TOPLEFT", x, -y)
            local passed = p and p >= stop.frac
            st.pole:SetColorTexture(r, g, b, passed and 0.5 or 1)
            st.flag:SetVertexColor(r, g, b, passed and 0.5 or 1)
            st.label:ClearAllPoints()
            st.label:SetPoint("BOTTOM", st, "TOP", 0, 2)
            st.label:SetText(stop.name)
            st.label:SetTextColor(unpack(passed and C.dim or C.muted))
            local lw = st.label:GetStringWidth() or 60
            st.label:SetShown(x - lw / 2 > lastX + 6)
            if st.label:IsShown() then lastX = x + lw / 2 end
            if not nextStop and (not p or p < stop.frac) then nextStop = stop.name end
        end
        -- médaillon
        self.medalRing:SetVertexColor(r, g, b, 1)
        self.medalIn:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
        self.time:SetTextColor(r, g, b)
        if left then
            self.time:SetText(fmt(left))
            self.eta:SetText(string.format(T("arrivée %s"), date("%H:%M", time() + left)))
        else
            self.time:SetText("+" .. fmt(elapsed))
            self.eta:SetText(T("1er vol"))
        end
        -- note et bouton « Atterrir à … »
        if fl.early then self.note:SetText(string.format(T("atterrissage à %s"), nextStop or fl.to or "?"))
        elseif not left then self.note:SetText(T("premier vol : durée apprise à l'arrivée"))
        elseif not fl.learned then self.note:SetText(T("durée estimée"))
        else self.note:SetText("") end
        self.land.label:SetText(nextStop and string.format(T("Atterrir à %s"), nextStop) or T("Atterrir"))
        self.land:SetWidth(self.land.label:GetStringWidth() + 28)
        self.land:SetShown(F:CanLandEarly() and not fl.early)
    end

    f:Hide()
    UI:RegisterHUD("flight", f, {
        label = T("Barre de vol"),
        default = { 0, UIParent:GetHeight() / 2 - 330 },
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Paint({ from = "Rut'theran", to = "Astranaar", start = GetTime() - 50, est = 182, learned = true,
                          stops = { { name = "Auberdine", frac = 0.55 } } })
                f:Show()
            elseif not F:Current() then
                f:Hide()
            end
        end,
    })
    return f
end

F.OnStart = function(_, fl)
    bar = bar or build()
    bar.dismissed = nil
    if not F:Config().enabled then return end
    bar:Paint(fl)
    bar:Show()
end
F.OnFinish = function() if bar and not bar.sample then bar:Hide() end end

WK:On("PLAYER_LOGIN", function() bar = bar or build() end)
