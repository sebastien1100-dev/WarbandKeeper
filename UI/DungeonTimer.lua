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
        self.foot:SetText(data.record and string.format(T("Record %s"), UI:Hex(C.gold) .. D().Clock(data.record) .. "|r") or T("Pas encore de record"))
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
