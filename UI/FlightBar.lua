local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Barre de vol (Modules/Flight.lua) : « Départ › Arrivée », temps restant en grand, piste avec un
-- repère qui avance, boutons Atterrir, Carte et fermer. Placée et dimensionnée en mode édition.
local F = WK.modules.Flight
local bar

local function fmt(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperFlightBar", UIParent)
    f:SetSize(420, 92)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.route = UI:Text(f, 13, C.text)
    f.route:SetPoint("TOPLEFT", 16, -14)
    f.route:SetPoint("RIGHT", f, "RIGHT", -90, 0)
    f.time = UI:Text(f, 20)
    f.time:SetPoint("TOPRIGHT", -16, -10)
    f.time:SetJustifyH("RIGHT")
    -- piste
    f.track = CreateFrame("Frame", nil, f)
    f.track:SetPoint("TOPLEFT", 16, -44)
    f.track:SetPoint("TOPRIGHT", -16, -44)
    f.track:SetHeight(8)
    UI:Rounded(f.track, 4, 0, "BACKGROUND", 1):SetColor(unpack(C.surface2))
    f.fillF = CreateFrame("Frame", nil, f.track)
    f.fillF:SetPoint("TOPLEFT"); f.fillF:SetPoint("BOTTOMLEFT")
    f.fill = UI:Rounded(f.fillF, 4, 0, "ARTWORK", 1)
    f.mark = UI:RoundIcon(f, 26, "Interface\\Icons\\Ability_Mount_Gryphon_01")
    f.markRing = UI:Icon(f, "circle", 30)
    f.markRing:SetDrawLayer("BORDER")
    -- boutons
    f.close = UI:IconButton(f, "close", 22, nil, "accent")
    f.close:SetPoint("BOTTOMRIGHT", -12, 10)
    f.close:SetScript("OnClick", function() f.dismissed = true; f:Hide() end)
    f.map = UI:Button(f, "Carte", nil, 24, "secondary")
    f.map:SetPoint("RIGHT", f.close, "LEFT", -6, 0)
    f.map:SetScript("OnClick", function() if ToggleWorldMap then ToggleWorldMap() end end)
    f.land = UI:Button(f, "Atterrir", nil, 24, "primary")
    f.land:SetPoint("RIGHT", f.map, "LEFT", -6, 0)
    f.land.tooltip = "Se poser au prochain relais."
    f.land:SetScript("OnClick", function() F:LandEarly() end)
    -- Étapes : un point sur la piste et le nom du relais dessous
    f.stops = UI:Pool(function()
        local st = CreateFrame("Frame", nil, f.track)
        st:SetSize(12, 12)
        st:SetFrameLevel(f.fillF:GetFrameLevel() + 2)
        st.dot = UI:Icon(st, "circle", 12, nil, "ARTWORK")
        st.dot:SetPoint("CENTER")
        st.hole = UI:Icon(st, "circle", 6, nil, "OVERLAY")
        st.hole:SetPoint("CENTER")
        st.label = UI:Text(f, 10, C.muted)
        st.label:SetJustifyH("CENTER")
        return st
    end)
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
        self.route:SetText("|cffb6a27e" .. (fl.from or "?") .. "|r  ›  " .. (fl.to or "?"))
        self.time:SetTextColor(r, g, b)
        self.fill:SetColor(r, g, b, 1)
        self.markRing:SetVertexColor(r, g, b, 1)
        local elapsed = GetTime() - fl.start
        local w = self.track:GetWidth() or 300
        local p
        if fl.est and fl.est > 0 then
            local left = fl.est - elapsed
            self.time:SetText(fmt(math.max(0, left)))
            p = math.max(0, math.min(1, elapsed / fl.est))
            self.note:SetText(fl.learned and "" or T("durée estimée"))
        else
            self.time:SetText("+" .. fmt(elapsed))
            p = nil
            self.note:SetText(T("premier vol : durée apprise à l'arrivée"))
        end
        if fl.early then self.note:SetText(T("atterrissage au prochain relais")) end
        self.fillF:SetShown(p ~= nil)
        self.mark:SetShown(p ~= nil)
        self.markRing:SetShown(p ~= nil)
        if p then
            self.fillF:SetWidth(math.max(8, w * p))
            self.mark:ClearAllPoints()
            self.mark:SetPoint("CENTER", self.track, "LEFT", w * p, 0)
            self.markRing:ClearAllPoints()
            self.markRing:SetPoint("CENTER", self.mark, "CENTER")
        end
        self.land:SetShown(F:CanLandEarly() and not fl.early)
        -- Étapes : passées en couleur d'accent, à venir creuses ; noms sans se chevaucher
        self.stops:Reset()
        for _, st in ipairs(self.stops.items) do st.label:Hide() end
        local lastX = -1000
        local stops = fl.stops or {}
        for _, stop in ipairs(stops) do
            local st = self.stops:Get()
            local x = w * stop.frac
            st:ClearAllPoints()
            st:SetPoint("CENTER", self.track, "LEFT", x, 0)
            local passed = p and p >= stop.frac
            st.dot:SetVertexColor(r, g, b, 1)
            st.hole:SetVertexColor(unpack(passed and { r, g, b, 1 } or C.bg))
            st.label:ClearAllPoints()
            st.label:SetPoint("TOP", self.track, "BOTTOMLEFT", x, -6)
            st.label:SetText(stop.name)
            st.label:SetTextColor(unpack(passed and C.dim or C.muted))
            local lw = st.label:GetStringWidth() or 60
            st.label:SetShown(x - lw / 2 > lastX + 6)
            if st.label:IsShown() then lastX = x + lw / 2 end
        end
        -- Le prochain relais (pour « Atterrir »)
        local nextStop
        for _, stop in ipairs(stops) do if not p or p < stop.frac then nextStop = stop.name break end end
        if fl.early then self.note:SetText(string.format(T("atterrissage à %s"), nextStop or fl.to)) end
        self.land.tooltip = nextStop and string.format(T("Se poser à %s."), nextStop) or T("Se poser au prochain relais.")
        -- Plus haute quand il y a des étapes (leurs noms passent sous la piste)
        self:SetHeight(#stops > 0 and 108 or 92)
    end
    f:Hide()
    UI:RegisterHUD("flight", f, {
        label = T("Barre de vol"),
        default = { 0, UIParent:GetHeight() / 2 - 330 },
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Paint({ from = "Rut'theran", to = "Astranaar", start = GetTime() - 50, est = 182, learned = true,
                          stops = { { name = "Auberdine", frac = 0.42 } } })
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
