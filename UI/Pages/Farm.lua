local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local GAP = 12
local TOP_H = 150

local function clock(sec)
    sec = math.floor(sec or 0)
    return string.format("%02d:%02d:%02d", math.floor(sec / 3600), math.floor(sec % 3600 / 60), sec % 60)
end

local function Farm() return WK.modules.Farm end

-- Tuile chiffre-clé.
local function Tile(parent, label)
    local t = UI:Card(parent)
    t.bg:SetColor(unpack(C.surface2))
    t.label = UI:Text(t, 11, C.muted)
    t.label:SetPoint("TOPLEFT", 12, -10)
    t.label:SetText(label)
    t.value = UI:Text(t, 15)
    t.value:SetPoint("BOTTOMLEFT", 12, 10)
    t.value:SetPoint("BOTTOMRIGHT", -8, 10)
    return t
end

UI:RegisterPage({
    key = "farm", order = 5.5, nav = "Farm",
    title = "Session de farm",
    subtitle = "Chrono, or ramassé, butin et or par heure. Les échanges, achats et le courrier ne comptent pas.",
    count = function() return Farm():Active() and "•" or "" end,

    Build = function(self, p)
        -- Carte principale ------------------------------------------------------
        local main = UI:Card(p, nil, nil, true)
        main:SetSize(UI.PAGE_W, TOP_H)
        main:SetPoint("TOPLEFT")
        self.status = UI:Badge(main, "")
        self.status:SetPoint("TOPLEFT", 18, -16)
        self.timer = UI:Text(main, 32)
        self.timer:SetPoint("TOPLEFT", 16, -40)
        self.where = UI:Text(main, 11, C.muted)
        self.where:SetPoint("TOPLEFT", self.timer, "BOTTOMLEFT", 2, -4)
        self.where:SetWidth(280)

        self.startBtn = UI:Button(main, "Démarrer", 120, 32, "primary", "play")
        self.startBtn:SetPoint("BOTTOMLEFT", 16, 14)
        self.startBtn:SetScript("OnClick", function() Farm():Start(); self.viewing = nil; self:Refresh() end)
        self.pauseBtn = UI:Button(main, "Pause", 104, 32, "secondary", "pause")
        self.pauseBtn:SetPoint("BOTTOMLEFT", 16, 14)
        self.pauseBtn:SetScript("OnClick", function() Farm():TogglePause(); self:Refresh() end)
        self.stopBtn = UI:Button(main, "Terminer", 110, 32, "danger", "stop")
        self.stopBtn:SetPoint("LEFT", self.pauseBtn, "RIGHT", 8, 0)
        self.stopBtn:SetScript("OnClick", function() Farm():Stop(); self:Refresh() end)

        local tx, tw = 330, (UI.PAGE_W - 330 - 16 - 3 * 10) / 4
        self.tiles = {}
        for i, l in ipairs({ "Or ramassé", "Or / heure", "Objets", "Valeur du butin" }) do
            local t = Tile(main, l)
            t:SetSize(tw, 58)
            t:SetPoint("TOPLEFT", tx + (i - 1) * (tw + 10), -18)
            self.tiles[i] = t
        end
        local farm = WK.DB.global.farm
        self.miniToggle = UI:Toggle(main, function() return farm.mini end, function(v)
            farm.mini = v; UI:UpdateFarmMini()
        end)
        self.miniToggle:SetPoint("BOTTOMRIGHT", -16, 18)
        local ml = UI:Text(main, 11, C.muted)
        ml:SetPoint("RIGHT", self.miniToggle, "LEFT", -10, 0)
        ml:SetText("Mini-fenêtre pendant la session")
        local vh = UI:Text(main, 10, C.dim)
        vh:SetPoint("BOTTOMLEFT", main, "BOTTOMLEFT", tx, 24)
        vh:SetWidth(UI.PAGE_W - tx - 300)
        vh:SetText("Valeur du butin : prix Auctionator, sinon prix marchand.")

        -- Butin --------------------------------------------------------------------
        local leftW = math.floor(UI.PAGE_W * 0.6)
        local loot = UI:Card(p, "Butin de la session")
        loot:SetSize(leftW, UI.PAGE_H - TOP_H - GAP)
        loot:SetPoint("TOPLEFT", 0, -TOP_H - GAP)
        self.lootCard = loot
        self.lootEmpty = UI:Text(loot, 12, C.muted)
        self.lootEmpty:SetPoint("CENTER")
        local ls = UI:Scroll(loot)
        ls:SetPoint("TOPLEFT", 10, -40)
        ls:SetPoint("BOTTOMRIGHT", -8, 10)
        self.lootScroll = ls
        self.lootRows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, ls.child)
            r:SetHeight(36)
            r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
            r.bg:SetColor(unpack(C.surface2))
            r.icon = UI:RoundIcon(r, 22)
            r.icon:SetPoint("LEFT", 8, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 38, 0)
            r.name:SetWidth(leftW - 220)
            r.count = UI:Text(r, 13)
            r.count:SetPoint("RIGHT", -90, 0)
            r.count:SetJustifyH("RIGHT")
            r.rate = UI:Text(r, 11, C.muted)
            r.rate:SetPoint("RIGHT", -12, 0)
            r.rate:SetJustifyH("RIGHT")
            return r
        end)

        -- Historique ----------------------------------------------------------------
        local hist = UI:Card(p, "Historique")
        self.histMode = "sessions"
        local modeSeg = UI:Segmented(hist, { { "sessions", "Sessions" }, { "spots", "Meilleurs spots" } },
            function(k) self.histMode = k; self.viewing = nil; self:Refresh() end, 28)
        modeSeg:SetPoint("TOPRIGHT", -10, -8)
        modeSeg:Select("sessions")
        hist:SetSize(UI.PAGE_W - leftW - GAP, UI.PAGE_H - TOP_H - GAP)
        hist:SetPoint("TOPRIGHT", 0, -TOP_H - GAP)
        self.histEmpty = UI:Text(hist, 12, C.muted)
        self.histEmpty:SetPoint("CENTER")
        self.histEmpty:SetText("Aucune session terminée.")
        local hs = UI:Scroll(hist)
        hs:SetPoint("TOPLEFT", 10, -40)
        hs:SetPoint("BOTTOMRIGHT", -8, 10)
        self.histScroll = hs
        self.histRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, hs.child)
            r:SetHeight(46)
            r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
            r.zone = UI:Text(r, 12)
            r.zone:SetPoint("TOPLEFT", 12, -8)
            r.zone:SetPoint("TOPRIGHT", -110, -8)
            r.meta = UI:Text(r, 10, C.muted)
            r.meta:SetPoint("TOPLEFT", r.zone, "BOTTOMLEFT", 0, -4)
            r.rate = UI:Text(r, 12)
            r.rate:SetPoint("RIGHT", -12, 0)
            r.rate:SetJustifyH("RIGHT")
            r:SetScript("OnClick", function(b)
                local same = self.viewing and (self.viewing == b.session
                    or (self.viewing.spot and b.session.spot and self.viewing.zone == b.session.zone))
                self.viewing = (not same) and b.session or nil
                self:Refresh()
            end)
            r:SetScript("OnEnter", function(b) b.hover = true; b:Paint() end)
            r:SetScript("OnLeave", function(b) b.hover = false; b:Paint() end)
            function r:Paint()
                self.bg:SetColor(unpack((self.selected or self.hover) and C.hover or C.surface2))
            end
            return r
        end)

        -- Chrono en direct.
        local acc = 0
        p:SetScript("OnUpdate", function(_, dt)
            acc = acc + dt
            if acc < 1 then return end
            acc = 0
            if Farm():Active() then self:RefreshTop() end
        end)
    end,

    -- Session affichée : celle sélectionnée dans l'historique, sinon la session en cours.
    Shown = function(self)
        return self.viewing or Farm():Current()
    end,

    RefreshTop = function(self)
        local F = Farm()
        local cur = F:Current()
        local s = self:Shown()
        if cur then
            self.status:Set(cur.paused and T("En pause") or T("En cours"), cur.paused and C.muted or C.positive)
        else
            self.status:Set(T("Aucune session"), C.muted)
        end
        if self.viewing then
            if self.viewing.spot then
                self.status:Set(string.format(self.viewing.sessions > 1 and T("%d sessions") or T("%d session"), self.viewing.sessions), C.muted)
            else
                self.status:Set(date("%d/%m %H:%M", self.viewing.start), C.muted)
            end
        end
        self.startBtn:SetShown(not cur)
        self.pauseBtn:SetShown(cur ~= nil)
        self.stopBtn:SetShown(cur ~= nil)
        if cur then self.pauseBtn:SetLabel(cur.paused and T("Reprendre") or T("Pause")) end
        if self.pauseBtn.icon then self.pauseBtn.icon:SetTexture(UI.MEDIA .. ((cur and cur.paused) and "play" or "pause")) end

        local dur = s and (s.duration or F:Elapsed(s)) or 0
        self.timer:SetText(clock(dur))
        if s then
            local c = WK.DB.global.characters[s.char]
            self.where:SetText((s.zone ~= "" and s.zone or "?") .. " · " .. (c and c.name or s.char))
        else
            self.where:SetText(T("Lance une session avant de partir farmer."))
        end
        local gold = s and s.gold or 0
        local items = s and s.items or {}
        local vendor = F:VendorValue(items)
        self.tiles[1].value:SetText(UI:GoldText(gold))
        self.tiles[2].value:SetText(s and UI:GoldText(F:PerHour(gold + vendor, s)) or "-")
        self.tiles[3].value:SetText(tostring(F:ItemCount(items)))
        self.tiles[4].value:SetText(UI:GoldText(vendor))
    end,

    Refresh = function(self)
        local F = Farm()
        self.miniToggle:Refresh()
        self:RefreshTop()
        local s = self:Shown()

        -- Butin
        if self.viewing and self.viewing.spot then
            self.lootCard.title:SetText(string.format(T("Butin à %s"), self.viewing.zone))
        elseif self.viewing then
            self.lootCard.title:SetText(string.format(T("Butin du %s"), date("%d/%m", self.viewing.start)))
        else
            self.lootCard.title:SetText(T("Butin de la session"))
        end
        self.lootRows:Reset()
        local list = {}
        for id, n in pairs(s and s.items or {}) do
            local name, icon, r, g, b = UI:ItemInfo(id)
            table.insert(list, { id = id, n = n, name = name, icon = icon, color = { r, g, b } })
        end
        table.sort(list, function(a, b) return a.n > b.n end)
        local y = 0
        for _, it in ipairs(list) do
            local r = self.lootRows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r.icon:SetTexture(it.icon)
            r.name:SetText(it.name)
            r.name:SetTextColor(unpack(it.color))
            r.count:SetText("x" .. it.n)
            local ph = F:PerHour(it.n, s)
            r.rate:SetText(ph > 0 and string.format(T("%d / h"), math.floor(ph + 0.5)) or "")
            y = y + 42
        end
        self.lootScroll:SetContentHeight(y)
        self.lootEmpty:SetShown(#list == 0)
        self.lootEmpty:SetText(s and T("Rien ramassé pour l'instant.") or T("Démarre une session pour suivre ton butin."))

        -- Historique : sessions, ou spots classés par or/heure
        self.histRows:Reset()
        y = 0
        local spots = self.histMode == "spots"
        local entries = spots and F:Spots() or WK.DB.global.farm.history
        for i, h in ipairs(entries) do
            local r = self.histRows:Get()
            r.session = h
            r.selected = self.viewing ~= nil and (self.viewing == h
                or (spots and self.viewing.spot and self.viewing.zone == h.zone))
            r:Paint()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local c = WK.DB.global.characters[h.char]
            if spots then
                r.zone:SetText(UI:Hex(C.dim) .. "#" .. i .. "|r  " .. h.zone)
                r.meta:SetText(string.format(T("%d session(s) · %s · meilleur : %s"), h.sessions,
                    WK:FormatTime(h.duration), c and c.name or "?"))
                r.rate:SetText(UI:GoldText(h.rate) .. T("/h"))
            else
                r.zone:SetText((h.zone ~= "" and h.zone or "?"))
                r.meta:SetText(string.format("%s · %s · %s", date("%d/%m", h.start), WK:FormatTime(h.duration), c and c.name or ""))
                r.rate:SetText(UI:GoldText(F:PerHour(h.gold + F:VendorValue(h.items), h)) .. T("/h"))
            end
            y = y + 52
        end
        self.histScroll:SetContentHeight(y)
        self.histEmpty:SetShown(#entries == 0)
    end,
})

---------------------------------------------------------------------------
-- Mini-fenêtre pendant une session (déplaçable).
---------------------------------------------------------------------------
function UI:UpdateFarmMini()
    local F = WK.modules.Farm
    local farm = WK.DB.global.farm
    local show = F:Active() and farm.mini
    local m = self.farmMini
    if not show then
        if m then m:Hide() end
        return
    end
    if not m then
        m = CreateFrame("Frame", "WarbandKeeperFarmMini", UIParent)
        self.farmMini = m
        m:SetSize(236, 92)
        m:SetFrameStrata("MEDIUM")
        m:SetClampedToScreen(true)
        m:SetMovable(true)
        m:EnableMouse(true)
        m:RegisterForDrag("LeftButton")
        m:SetScript("OnDragStart", m.StartMoving)
        m:SetScript("OnDragStop", function(f)
            f:StopMovingOrSizing()
            local pnt, _, rp, x, y = f:GetPoint()
            farm.miniPoint = { pnt, rp, x, y }
        end)
        if farm.miniPoint then
            m:SetPoint(farm.miniPoint[1], UIParent, farm.miniPoint[2], farm.miniPoint[3], farm.miniPoint[4])
        else
            m:SetPoint("TOP", UIParent, "TOP", 0, -140)
        end
        UI:Rounded(m, 14, 0, "BACKGROUND", 0):SetColor(unpack(C.frame))
        UI:Rounded(m, 13, 1, "BACKGROUND", 1):SetColor(unpack(C.bg))
        UI:TopHighlight(m)

        local logo = UI:Icon(m, "logo", 16)
        logo:SetPoint("TOPLEFT", 12, -11)
        UI:OnAccent(function() logo:SetVertexColor(UI:Accent()) end)
        m.zone = UI:Text(m, 11, C.muted)
        m.zone:SetPoint("LEFT", logo, "RIGHT", 6, 0)
        m.zone:SetWidth(130)
        m.timer = UI:Text(m, 20)
        m.timer:SetPoint("TOPLEFT", 12, -32)
        m.line = UI:Text(m, 11, C.muted)
        m.line:SetPoint("BOTTOMLEFT", 12, 12)
        m.line:SetWidth(212)

        local stop = UI:IconButton(m, "stop", 24, "Terminer la session", true)
        stop:SetPoint("TOPRIGHT", -8, -6)
        stop:SetScript("OnClick", function() F:Stop(); UI:Refresh() end)
        m.pause = UI:IconButton(m, "pause", 24, "Pause / reprendre")
        m.pause:SetPoint("RIGHT", stop, "LEFT", -2, 0)
        m.pause:SetScript("OnClick", function() F:TogglePause(); UI:UpdateFarmMini(); UI:Refresh() end)
        local open = UI:IconButton(m, "chart", 24, "Ouvrir la page Farm")
        open:SetPoint("RIGHT", m.pause, "LEFT", -2, 0)
        open:SetScript("OnClick", function() UI:ToggleWindow("farm") end)

        local acc = 0
        m:SetScript("OnUpdate", function(f, dt)
            acc = acc + dt
            if acc >= 1 then acc = 0; f:Update() end
        end)
        function m:Update()
            local s = F:Current()
            if not s then return end
            F:Tick()
            local vendor = F:VendorValue(s.items)
            local lp = WK.modules.Loot and WK.DB.global.loot.enabled and WK.modules.Loot:Effective()
            self.zone:SetText((s.zone ~= "" and s.zone or "Farm") .. (lp and ("  ·  " .. lp.name) or ""))
            self.timer:SetText(clock(F:Elapsed(s)))
            self.timer:SetTextColor(unpack(s.paused and C.muted or C.text))
            self.line:SetText(string.format("%s%s  ·  %d %s", UI:GoldText(F:PerHour(s.gold + vendor, s)), T("/h"),
                F:ItemCount(s.items), T("objets")))
            self.pause.icon:SetTexture(UI.MEDIA .. (s.paused and "play" or "pause"))
        end
    end
    m:Show()
    m:Update()
end
