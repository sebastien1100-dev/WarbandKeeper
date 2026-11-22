local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Barre de vol (Modules/Flight.lua) : un seul cadre, affiché pendant tout le vol (à la demande du joueur : plus
-- de petite pilule avec un volet au survol) : trajet complet (départ › relais › arrivée), temps restant, barre de
-- progression (un trait par relais), heures de départ et d'arrivée, « Atterrir à … » et Statistiques.
-- Placée en mode édition.
local F = WK.modules.Flight
local bar

local W, H = 420, 118

local function fmt(sec)
    sec = math.max(0, math.floor(sec + 0.5))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end
-- « Forgefer, Dun Morogh » -> « Forgefer », « Dun Morogh »
local function split(n)
    n = n or "?"
    local a, z = n:match("^(.-),%s*(.+)$")
    if a then return a, z end
    return n, nil
end

-- Barre de progression avec traits de relais
local function progress(parent, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetHeight(h)
    p.bg = UI:Rounded(p, h / 2, 0, "BACKGROUND", 1)
    p.fill = CreateFrame("Frame", nil, p)
    p.fill:SetPoint("TOPLEFT"); p.fill:SetPoint("BOTTOMLEFT")
    p.fillTex = UI:Rounded(p.fill, h / 2, 0, "ARTWORK", 1)
    p.ticks = {}
    function p:Set(frac, stops)
        local r, g, b = UI:Accent()
        self.bg:SetColor(unpack(C.border))
        self.fillTex:SetColor(r, g, b, 1)
        local w = self:GetWidth() or 0
        self.fill:SetWidth(math.max(h, w * (frac or 0)))
        self.fill:SetShown((frac or 0) > 0)
        for _, t in ipairs(self.ticks) do t:Hide() end
        for i, st in ipairs(stops or {}) do
            local t = self.ticks[i]
            if not t then
                t = self:CreateTexture(nil, "OVERLAY")
                t:SetSize(3, h + 6)
                self.ticks[i] = t
            end
            t:ClearAllPoints()
            t:SetPoint("CENTER", self, "LEFT", w * st.frac, 0)
            local passed = (frac or 0) >= st.frac
            t:SetColorTexture(passed and C.bg[1] or C.muted[1], passed and C.bg[2] or C.muted[2], passed and C.bg[3] or C.muted[3], 1)
            t:Show()
        end
    end
    return p
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperFlightBar", UIParent)
    f:SetSize(W, H)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    -- le cadre du vol (toujours affiché pendant le vol)
    local m = CreateFrame("Frame", nil, f)
    m:SetAllPoints(f)
    m:EnableMouse(true)
    m.edge = UI:Rounded(m, 14, 0, "BACKGROUND", 0)
    m.bg = UI:Rounded(m, 13, 1, "BACKGROUND", 1)
    m.kick = UI:Text(m, 10, C.dim)
    m.kick:SetPoint("TOPLEFT", 16, -12)
    m.close = UI:IconButton(m, "close", 18)
    m.close:SetPoint("TOPRIGHT", -8, -6)
    m.close:SetScript("OnClick", function() f.dismissed = true; f:Hide() end)
    -- temps restant en gros, à gauche de la croix
    m.left = UI:Text(m, 17)
    m.left:SetPoint("TOPRIGHT", -34, -9)
    m.left:SetJustifyH("RIGHT")
    m.route = UI:Text(m, 12)
    m.route:SetPoint("TOPLEFT", 16, -28)
    m.route:SetPoint("TOPRIGHT", -80, -28)
    m.route:SetJustifyH("LEFT")
    m.bar = progress(m, 4)
    m.bar:SetPoint("TOPLEFT", 16, -50)
    m.bar:SetPoint("TOPRIGHT", -16, -50)
    -- heures sur leur propre ligne (avant : sous les boutons, coupées)
    m.times = UI:Text(m, 10, C.muted)
    m.times:SetPoint("TOPLEFT", 16, -62)
    m.times:SetPoint("TOPRIGHT", -16, -62)
    m.times:SetJustifyH("LEFT")
    -- statistiques du compte en vol (UI/FlightStats.lua), même quand la carte (M) reste la carte
    m.map = UI:Button(m, "Statistiques", nil, 24, "secondary")
    m.map:SetPoint("BOTTOMRIGHT", -14, 10)
    m.map.tooltip = "Statistiques du compte pendant le vol."
    m.map:SetScript("OnClick", function()
        local v = UI.FlightStats and UI:FlightStats()
        if v and v:IsShown() then v:Hide() elseif UI.ShowFlightStats then UI:ShowFlightStats() end
    end)
    m.land = UI:Button(m, "Atterrir", nil, 24, "primary")
    m.land:SetPoint("RIGHT", m.map, "LEFT", -6, 0)
    m.land:SetScript("OnClick", function() F:LandEarly() end)
    f.more = m

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
        local accHex, mutedHex = UI:Hex({ r, g, b }), UI:Hex(C.muted)
        local elapsed = GetTime() - fl.start
        local p, left
        if fl.est and fl.est > 0 then
            left = math.max(0, fl.est - elapsed)
            p = math.max(0, math.min(1, elapsed / fl.est))
        end
        local toName = split(fl.to)
        local stops = fl.stops or {}
        local m = self.more
        m.left:SetTextColor(r, g, b)
        m.left:SetText(left and fmt(left) or ("+" .. fmt(elapsed)))
        -- fond commun des cadres à l'écran (UI:HudBackground) : graphite et liseré gris
        UI:HudRegister(m)
        UI:HudPaint(m)
        local parts, nextStop = { (split(fl.from)) }, nil
        for _, st in ipairs(stops) do
            local passed = p and p >= st.frac
            local nm = split(st.name)
            table.insert(parts, passed and (mutedHex .. nm .. "|r") or nm)
            if not nextStop and not passed then nextStop = nm end
        end
        table.insert(parts, accHex .. toName .. "|r")
        m.route:SetText(table.concat(parts, "  " .. UI:Hex(C.dim) .. ">|r  "))
        m.kick:SetText(#stops > 0 and string.format(T("VOL EN COURS  ·  %d RELAIS"), #stops) or T("VOL EN COURS  ·  DIRECT"))
        m.bar:Set(p or 0, stops)
        local dep = date("%H:%M", time() - elapsed)
        local note
        if fl.early then note = string.format(T("atterrissage à %s"), nextStop or toName)
        elseif not left then note = T("premier vol : durée apprise à l'arrivée")
        elseif not fl.learned then note = T("durée estimée") end
        m.times:SetText(string.format(T("parti à %s"), dep) .. (left and ("  ·  " .. string.format(T("arrivée %s"), date("%H:%M", time() + left))) or "")
            .. (note and ("  ·  " .. note) or ""))
        m.land.label:SetText(nextStop and string.format(T("Atterrir à %s"), nextStop) or T("Atterrir"))
        m.land:SetWidth(m.land.label:GetStringWidth() + 28)
        m.land:SetShown(F:CanLandEarly() and not fl.early)
    end

    f:Hide()
    UI:RegisterHUD("flight", f, {
        label = T("Barre de vol"),
        default = { 0, UIParent:GetHeight() / 2 - 120 },
        -- barre coupée dans ses réglages : absente du mode édition
        enabled = function() return F:Config().enabled and true or false end,
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Paint({ from = "Rut'theran, Teldrassil", to = "Astranaar, Orneval", start = GetTime() - 50, est = 182, learned = true,
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
