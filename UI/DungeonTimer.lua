local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Chrono du donjon à l'écran (réglage Dungeons:Config().timer, bandeau de l'onglet Parcours) :
-- temps du passage, temps de chaque boss depuis l'entrée et écart avec le record (Modules/Dungeons.lua).
local W, ROW = 230, 17
local frame

local function D() return WK.modules.Dungeons end

local SAMPLE = {
    name = "Mortemines", elapsed = 1122, record = 1265,
    rows = { { "Rhahk'Zor", 130, -15 }, { "Sneed", 408, -40 }, { "Gilnid", 605, 22 }, { "M. Smite", 931, -72 },
        { "Capitaine Vertepeau", nil, nil, 1078, true }, { "Cookie", nil, nil, 1150 }, { "Edwin VanCleef", nil, nil, 1265 } },
}

-- lignes du passage en cours : { nom, temps, écart, record, en cours }
local function liveData()
    local Dg = D()
    local run = Dg.run
    local d = run and Dg:Get(run.key)
    if not d then return nil end
    local rec = Dg:Record(d)
    local nextB = Dg:Next(d)
    local rows = {}
    for _, b in ipairs(Dg:Bosses(d)) do
        if not Dg:Optional(d, b) then
            local k = run.killed[b.id]
            local rs = rec and rec.splits and rec.splits[tostring(b.id)]
            table.insert(rows, { Dg:BossName(b), k and (k - run.start) or nil, k and Dg:Delta(d, b.id) or nil, rs, b == nextB })
        end
    end
    return { name = Dg:Name(d), elapsed = Dg:Elapsed(), record = rec and rec.dur or nil, rows = rows }
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDungeonTimer", UIParent)
    f:SetSize(W, 60)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.time = UI:Text(f, 20); f.time:SetPoint("TOPLEFT", 12, -10)
    f.name = UI:Text(f, 11, C.muted); f.name:SetPoint("LEFT", f.time, "RIGHT", 8, -1); f.name:SetPoint("RIGHT", -10, 0)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.rows = {}
    f.foot = UI:Text(f, 10, C.muted)
    function f:Paint(data)
        if not data then return end
        local r1, g1, b1 = UI:Accent()
        self.time:SetText(D().Clock(data.elapsed))
        self.name:SetText(data.name or "")
        local y = 40
        for i, rw in ipairs(data.rows) do
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Frame", nil, self); r:SetHeight(ROW)
                r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints()
                r.n = UI:Text(r, 11); r.n:SetPoint("LEFT", 6, 0); r.n:SetPoint("RIGHT", -96, 0)
                if r.n.SetWordWrap then r.n:SetWordWrap(false) end
                r.dl = UI:Text(r, 11); r.dl:SetPoint("RIGHT", -6, 0); r.dl:SetWidth(44); r.dl:SetJustifyH("RIGHT")
                r.t = UI:Text(r, 11); r.t:SetPoint("RIGHT", r.dl, "LEFT", -4, 0); r.t:SetWidth(44); r.t:SetJustifyH("RIGHT")
                self.rows[i] = r
            end
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -y); r:SetPoint("TOPRIGHT", -6, -y)
            local name, t, dl, rs, cur = rw[1], rw[2], rw[3], rw[4], rw[5]
            r.n:SetText(name)
            local done = t ~= nil
            r.n:SetTextColor(unpack(done and C.text or cur and C.text or C.dim))
            r.t:SetText(done and D().Clock(t) or (cur and "..." or "-"))
            r.t:SetTextColor(unpack(done and C.text or C.dim))
            if dl then
                r.dl:SetText(D().ClockDelta(dl)); r.dl:SetTextColor(unpack(dl <= 0 and C.positive or C.negative))
            else
                r.dl:SetText(rs and D().Clock(rs) or ""); r.dl:SetTextColor(unpack(C.dim))
            end
            r.hl:SetColorTexture(r1, g1, b1, cur and 0.14 or 0)
            r:Show()
            y = y + ROW
        end
        for i = #data.rows + 1, #self.rows do self.rows[i]:Hide() end
        self.foot:ClearAllPoints(); self.foot:SetPoint("TOPLEFT", 12, -(y + 6))
        local n = D():HourCount()
        self.foot:SetText((data.record and string.format(T("Record %s"), UI:Hex(C.gold) .. D().Clock(data.record) .. "|r") or T("Pas encore de record"))
            .. "  ·  " .. UI:Hex(n >= D().CAP - 1 and C.negative or C.muted) .. string.format(T("%d / %d cette heure"), n, D().CAP) .. "|r")
        self:SetHeight(y + 26)
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 then return end
        s.acc = 0
        if s.sample then return end
        local data = liveData()
        if data then s:Paint(data) else s:Hide() end
    end)
    f:Hide()
    UI:RegisterHUD("dungeonTimer", f, {
        label = T("Chrono de donjon"), default = { 420, 120 },
        enabled = function() return D():Config().timer and WK:FeatureOn("dungeons") end,
        sample = function(on)
            f.sample = on or nil
            if on then f:Paint(SAMPLE); f:Show() else UI:RefreshDungeonTimer() end
        end,
        -- « Tester » : le chrono défile et le boss en cours tombe au bout de 4 s
        test = function()
            f.sample = true
            local data = { name = SAMPLE.name, elapsed = SAMPLE.elapsed, record = SAMPLE.record, rows = {} }
            for i, r in ipairs(SAMPLE.rows) do data.rows[i] = { r[1], r[2], r[3], r[4], r[5] } end
            local n = 0
            f:Paint(data); f:Show()
            f.testTicker = C_Timer.NewTicker and C_Timer.NewTicker(1, function()
                n = n + 1
                data.elapsed = data.elapsed + 1
                if n == 4 then
                    local cur = data.rows[5]
                    cur[2], cur[3], cur[5] = data.elapsed, data.elapsed - cur[4], nil
                    data.rows[6][5] = true
                end
                f:Paint(data)
            end)
        end,
        testStop = function()
            if f.testTicker then f.testTicker:Cancel(); f.testTicker = nil end
            f.sample = nil
            UI:RefreshDungeonTimer()
        end,
    })
    return f
end

function UI:RefreshDungeonTimer()
    if not frame then frame = build() end
    if frame.sample then return end
    local data = D():Config().timer and WK:FeatureOn("dungeons") and liveData()
    if not data then frame:Hide() return end
    frame:Paint(data)
    frame:Show()
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(2, function() UI:RefreshDungeonTimer() end) end)
local prev = D().OnChange
D().OnChange = function(...)
    if prev then prev(...) end
    UI:RefreshDungeonTimer()
end


---------------------------------------------------------------------------
-- Rappel « Réal de Terremine terni » (Modules/Dungeons.lua : RealBoss) : icône qui clignote après la
-- 1re victoire du jour sur un boss qui en donne un, jusqu'au butin de son corps (clic : la cacher).
---------------------------------------------------------------------------
local real
local function buildReal()
    -- bandeau compact (même style que la pile « Rappels ») : fond sombre, liseré d'accent qui respire,
    -- icône carrée de l'objet, « Ramasse le loot » et l'objet · le boss dessous, croix pour le cacher
    local f = CreateFrame("Button", "WarbandKeeperRealReminder", UIParent)
    f:SetSize(250, 48)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.edge = CreateFrame("Frame", nil, f)
    f.edge:SetPoint("TOPLEFT", 8, -8); f.edge:SetSize(32, 32)
    f.edge.bg = UI:Rounded(f.edge, 6, 0, "BACKGROUND", 1)
    f.edge.bg:SetColor(C.gold[1], C.gold[2], C.gold[3], 0.9)
    f.icon = f.edge:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", 1, -1); f.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.text = UI:Text(f, 12, C.text); f.text:SetPoint("TOPLEFT", f.edge, "TOPRIGHT", 10, -1)
    f.text:SetText(T("Ramasse le loot"))
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", f.text, "BOTTOMLEFT", 0, -4)
    f.sub:SetPoint("RIGHT", -30, 0); f.sub:SetJustifyH("LEFT"); f.sub:SetWordWrap(false)
    f.close = UI:IconButton(f, "close", 18, "Cacher")
    f.close:SetPoint("RIGHT", -8, 0)
    f.close:SetScript("OnClick", function() D():OnRealClear() end)
    f:SetScript("OnClick", function() D():OnRealClear() end)
    f:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        local name = WK.GetItemInfo(D().REAL_ITEM)
        GameTooltip:SetText(name or T("Réal de Terremine terni"), 1, 0.82, 0)
        if s.boss then GameTooltip:AddLine(string.format(T("Sur le corps de %s (un par boss et par jour)."), s.boss), 0.85, 0.85, 0.85, true) end
        GameTooltip:AddLine(T("Clic : cacher"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- le liseré prend la couleur d'accent et respire doucement
    f:SetScript("OnUpdate", function(s)
        local a = 0.5 + 0.5 * math.abs(math.sin(GetTime() * 2))
        local r, g, b = UI:Accent()
        s.border:SetColor(r * a + C.border[1] * (1 - a), g * a + C.border[2] * (1 - a), b * a + C.border[3] * (1 - a), 1)
    end)
    local function setIcon()
        local tex = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(D().REAL_ITEM)) or (GetItemIcon and GetItemIcon(D().REAL_ITEM))
        f.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_Coin_02")
        local name = WK.GetItemInfo(D().REAL_ITEM) or T("Réal de Terremine terni")
        f.sub:SetText(f.boss and (name .. " · " .. f.boss) or name)
    end
    f.setIcon = setIcon
    setIcon()
    UI:RegisterHUD("realReminder", f, { label = T("Rappel du Réal"), default = { 0, 160 },
        enabled = function() return D():Config().real and WK:FeatureOn("dungeons") end,
        sample = function(on) f.sample = on; if on then setIcon(); f:Show() else UI:RefreshRealReminder() end end,
        -- « Tester » : comme après la victoire sur un boss
        test = function() f.sample = true; f.boss = "Gorrak"; setIcon(); f:Show() end,
        testStop = function() f.sample = nil; f.boss = nil; UI:RefreshRealReminder() end })
    f:Hide()
    return f
end
function UI:RefreshRealReminder()
    if not real then real = buildReal() end
    if real.sample then return end
    local p = D().realPending
    real.boss = p and p.name
    real.setIcon()
    real:SetShown(p ~= nil and D():Config().real and WK:FeatureOn("dungeons"))
end
D().OnReal = function() UI:RefreshRealReminder() end
WK:On("PLAYER_LOGIN", function() C_Timer.After(2, function() UI:RefreshRealReminder() end) end)
