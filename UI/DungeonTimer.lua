local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Chrono du donjon à l'écran (réglage Dungeons:Config().timer, bandeau de l'onglet Parcours), allure des clés
-- mythiques : fond sombre plein aux coins arrondis, large comme le suivi des quêtes (ou largeur fixe),
-- parties visibles au choix (préréglages Complet / Compact / Minimal), nom du donjon, gros
-- chrono et record, barre du temps face au record, boss avec une pastille (tué en vert, en cours à la couleur
-- d'accent), temps de chaque boss et écart avec le record (Modules/Dungeons.lua).
local W, ROW = 260, 18
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
    local rec = Dg:Record(d, true)
    local nextB = Dg:Next(d)
    local rows = {}
    for _, b in ipairs(Dg:Bosses(d)) do
        if not Dg:Optional(d, b) then
            local k = run.killed[b.id]
            local rs = rec and rec.splits and rec.splits[tostring(b.id)]
            table.insert(rows, { Dg:BossName(b), k and (k - run.start) or nil, k and Dg:Delta(d, b.id) or nil, rs, b == nextB })
        end
    end
    -- chrono en attente du premier combat : dit pourquoi il reste à 0
    local name = Dg:Name(d) .. (run.wait and ("  ·  " .. WK.T("au premier pack")) or "")
    return { name = name, elapsed = Dg:Elapsed(), record = rec and rec.dur or nil, rows = rows }
end

-- largeur du suivi des quêtes (le chrono se pose dessous, aussi large), sinon W
local function trackerWidth()
    for _, n in ipairs({ "ObjectiveTrackerFrame", "WatchFrame", "QuestWatchFrame" }) do
        local t = _G[n]
        local w = t and t.GetWidth and t:GetWidth()
        if w and w > 150 and w < 500 then return math.floor(w) end
    end
    return W
end

-- options d'affichage (Donjons > roue dentée > « Chrono à l'écran ») : préréglage, largeur, parties visibles
local PARTS = { "name", "cap", "rec", "left", "bar", "boss", "bt", "dl", "remain", "soft" }
local PRESETS = {
    full = { name = true, cap = true, rec = true, left = true, bar = true, boss = true, bt = true, dl = true },
    compact = { name = true, rec = true, left = true, bar = true, boss = true, bt = true, remain = true },
    minimal = { name = true, rec = true, left = true, bar = true },
}
UI.DungeonTimerParts, UI.DungeonTimerPresets = PARTS, PRESETS

function UI:DungeonTimerOpts()
    local dc = D():Config()
    if type(dc.timerShow) ~= "table" then
        dc.timerShow = {}
        for k, v in pairs(PRESETS.full) do dc.timerShow[k] = v end
    end
    dc.timerPreset = dc.timerPreset or "full"
    dc.timerWidth = dc.timerWidth or "tracker"
    dc.timerFixed = dc.timerFixed or W
    return dc
end

function UI:ApplyDungeonTimerPreset(key)
    local dc = UI:DungeonTimerOpts()
    local p = PRESETS[key]
    dc.timerPreset = key
    if p then
        local soft = dc.timerShow.soft
        dc.timerShow = {}
        for k, v in pairs(p) do dc.timerShow[k] = v end
        dc.timerShow.soft = soft
    end
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDungeonTimer", UIParent)
    f:SetSize(W, 60)
    f:SetFrameStrata("MEDIUM")
    -- fond graphite et liseré fin, comme la fenêtre des quêtes du donjon et les autres fenêtres à l'écran
    f.edge = UI:Rounded(f, 10, 0, "BACKGROUND", 0)
    f.bg = UI:Rounded(f, 9, 1, "BACKGROUND", 1)
    -- 1re ligne : nom du donjon à gauche, gros chrono à droite
    f.name = UI:Text(f, 13, C.gold)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.name:SetJustifyH("LEFT")
    f.time = UI:Text(f, 24); f.time:SetJustifyH("RIGHT")
    -- 2e ligne : record · compteur de l'heure, et à droite le temps restant (ou le dépassement)
    f.rec = UI:Text(f, 11, C.muted); f.rec:SetJustifyH("LEFT")
    if f.rec.SetWordWrap then f.rec:SetWordWrap(false) end
    f.left = UI:Text(f, 12); f.left:SetJustifyH("RIGHT")
    f.cap = f.rec -- compteur dans la même ligne que le record
    -- frise des boss (maquette A) : une pastille par boss compté, grise et pleine = tué, cerclée d'accent =
    -- prochain, cerclée sombre = à venir ; « 2 / 3 boss » à la suite. Plus petites quand il y a beaucoup de boss
    f.bar = CreateFrame("Frame", nil, f)
    f.bar:SetHeight(14)
    f.segs = {}
    f.count = UI:Text(f.bar, 11, C.muted); f.count:SetJustifyH("LEFT")
    -- en-têtes des colonnes
    f.hdr = CreateFrame("Frame", nil, f); f.hdr:SetHeight(14)
    f.hdr.n = UI:Text(f.hdr, 9, C.dim); f.hdr.n:SetPoint("LEFT", 18, 0); f.hdr.n:SetText(T("BOSS"))
    f.hdr.dl = UI:Text(f.hdr, 9, C.dim); f.hdr.dl:SetPoint("RIGHT", -2, 0); f.hdr.dl:SetWidth(46); f.hdr.dl:SetJustifyH("RIGHT"); f.hdr.dl:SetText(T("ÉCART"))
    f.hdr.t = UI:Text(f.hdr, 9, C.dim); f.hdr.t:SetWidth(46); f.hdr.t:SetJustifyH("RIGHT"); f.hdr.t:SetText(T("TEMPS"))
    -- boss tués plus tôt, repliés
    f.more = UI:Text(f, 11, C.muted); f.more:SetJustifyH("LEFT")
    f.rows = {}
    function f:Paint(data)
        if not data then return end
        local r1, g1, b1 = UI:Accent()
        local o = UI:DungeonTimerOpts()
        local sh = o.timerShow
        local W2 = o.timerWidth == "fixed" and o.timerFixed or trackerWidth()
        self:SetWidth(W2)
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], sh.soft and 0.6 or 0.92)
        self.edge:SetColor(C.border[1], C.border[2], C.border[3], sh.soft and 0.5 or 1)
        local over = data.record and data.elapsed > data.record
        local y = 8
        -- nom et chrono
        self.time:ClearAllPoints(); self.time:SetPoint("TOPRIGHT", -10, -y)
        self.time:SetText(D().Clock(data.elapsed))
        self.time:SetTextColor(unpack(over and C.negative or C.text))
        self.name:SetShown(sh.name)
        -- largeur plutôt qu'un 2e ancrage centré (TOPLEFT + RIGHT écrasait la hauteur du texte)
        self.name:ClearAllPoints(); self.name:SetPoint("TOPLEFT", 10, -(y + 8))
        self.name:SetWidth(math.max(40, W2 - 28 - (self.time:GetStringWidth() or 60)))
        self.name:SetText(data.name or "")
        y = y + 28
        -- record · compteur, temps restant
        local parts = {}
        if sh.rec then parts[#parts + 1] = data.record and string.format(T("record %s"), D().Clock(data.record)) or T("pas de record") end
        if sh.cap then
            local n = D():HourCount()
            parts[#parts + 1] = UI:Hex(n >= D().CAP - 1 and C.negative or C.muted) .. string.format(T("%d / %d cette heure"), n, D().CAP) .. "|r"
        end
        self.rec:SetShown(#parts > 0)
        self.rec:SetText(table.concat(parts, " · "))
        if sh.left and data.record then
            local d = data.record - data.elapsed
            self.left:SetText(d >= 0 and (UI:Hex(C.positive) .. "-" .. D().Clock(d) .. "|r") or (UI:Hex(C.negative) .. "+" .. D().Clock(-d) .. "|r"))
        else self.left:SetText("") end
        self.left:SetShown(sh.left)
        if #parts > 0 or (sh.left and data.record) then
            self.rec:ClearAllPoints(); self.rec:SetPoint("TOPLEFT", 10, -y)
            self.rec:SetWidth(math.max(40, W2 - 26 - (sh.left and (self.left:GetStringWidth() or 40) or 0)))
            self.left:ClearAllPoints(); self.left:SetPoint("TOPRIGHT", -10, -(y - 1))
            y = y + 16
        end
        -- frise des boss : pastilles
        local nb = #data.rows
        self.bar:SetShown(sh.bar and nb > 0)
        if sh.bar and nb > 0 then
            y = y + 2
            self.bar:ClearAllPoints(); self.bar:SetPoint("TOPLEFT", 10, -y); self.bar:SetPoint("TOPRIGHT", -10, -y)
            local killed = 0
            for _, rw in ipairs(data.rows) do if rw[2] ~= nil then killed = killed + 1 end end
            self.count:SetText(string.format(T("%d / %d boss"), killed, nb))
            local room = (W2 - 20) - (self.count:GetStringWidth() or 60) - 8
            local DOT, GAPD = 14, 6
            if nb * (DOT + GAPD) > room then DOT, GAPD = 10, 4 end
            if nb * (DOT + GAPD) > room then DOT, GAPD = 8, 3 end
            self.bar:SetHeight(DOT)
            for i, rw in ipairs(data.rows) do
                local sg = self.segs[i]
                if not sg then
                    sg = CreateFrame("Frame", nil, self.bar)
                    sg.fill = sg:CreateTexture(nil, "ARTWORK")
                    sg.fill:SetTexture(UI.MEDIA .. "circle"); sg.fill:SetAllPoints()
                    sg.ring = sg:CreateTexture(nil, "ARTWORK", nil, 1)
                    sg.ring:SetTexture(UI.MEDIA .. "ring"); sg.ring:SetAllPoints()
                    self.segs[i] = sg
                end
                local isDone, cur = rw[2] ~= nil, rw[5]
                sg:SetSize(DOT, DOT)
                sg:ClearAllPoints(); sg:SetPoint("LEFT", self.bar, "LEFT", (i - 1) * (DOT + GAPD), 0)
                if isDone then
                    sg.fill:Show(); sg.fill:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1); sg.ring:Hide()
                else
                    sg.fill:Hide(); sg.ring:Show()
                    if cur then
                        local cc = over and C.negative or { r1, g1, b1 }
                        sg.ring:SetVertexColor(cc[1], cc[2], cc[3], 1)
                    else sg.ring:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 0.8) end
                end
                sg:Show()
            end
            for i = nb + 1, #self.segs do self.segs[i]:Hide() end
            self.count:ClearAllPoints(); self.count:SetPoint("LEFT", self.bar, "LEFT", nb * (DOT + GAPD) + 4, 0)
            y = y + DOT + 8
        else
            for _, sg in ipairs(self.segs) do sg:Hide() end
        end
        -- boss : les tués plus tôt se replient (les 2 derniers restent), « Masquer les boss tués » les cache tous
        local list, done = {}, {}
        if sh.boss then
            for i, rw in ipairs(data.rows) do if rw[2] ~= nil then done[#done + 1] = i end end
        end
        local keep = sh.remain and 0 or 2
        local hiddenN = math.max(0, #done - keep)
        local skip = {}
        for k = 1, hiddenN do skip[done[k]] = true end
        if sh.boss then
            for i, rw in ipairs(data.rows) do if not skip[i] then list[#list + 1] = rw end end
        end
        local cols = sh.bt or sh.dl
        self.hdr:SetShown(#list > 0 and cols)
        if #list > 0 and cols then
            self.hdr:ClearAllPoints(); self.hdr:SetPoint("TOPLEFT", 6, -y); self.hdr:SetPoint("TOPRIGHT", -6, -y)
            self.hdr.t:ClearAllPoints(); self.hdr.t:SetPoint("RIGHT", sh.dl and -52 or -2, 0)
            self.hdr.t:SetShown(sh.bt); self.hdr.dl:SetShown(sh.dl)
            y = y + 16
        end
        local shown = 0
        for _, rw in ipairs(list) do
            shown = shown + 1
            local i = shown
            local r = self.rows[i]
            if not r then
                r = CreateFrame("Frame", nil, self); r:SetHeight(ROW)
                r.hl = r:CreateTexture(nil, "BACKGROUND", nil, 3); r.hl:SetAllPoints()
                r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetTexture(UI.MEDIA .. "circle"); r.dot:SetSize(8, 8); r.dot:SetPoint("LEFT", 4, 0)
                r.n = UI:Text(r, 12); r.n:SetPoint("LEFT", 18, 0); r.n:SetPoint("RIGHT", -100, 0)
                if r.n.SetWordWrap then r.n:SetWordWrap(false) end
                r.dl = UI:Text(r, 12); r.dl:SetPoint("RIGHT", -2, 0); r.dl:SetWidth(46); r.dl:SetJustifyH("RIGHT")
                r.t = UI:Text(r, 12); r.t:SetPoint("RIGHT", -52, 0); r.t:SetWidth(46); r.t:SetJustifyH("RIGHT")
                self.rows[i] = r
            end
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -y); r:SetPoint("TOPRIGHT", -6, -y)
            local name, t, dl, rs, cur = rw[1], rw[2], rw[3], rw[4], rw[5]
            local isDone = t ~= nil
            r.n:SetText(name)
            r.n:SetTextColor(unpack(isDone and C.muted or cur and C.text or C.dim))
            if isDone then r.dot:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
            elseif cur then r.dot:SetVertexColor(r1, g1, b1, 1)
            else r.dot:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 0.8) end
            r.t:SetShown(sh.bt); r.dl:SetShown(sh.dl)
            r.t:ClearAllPoints(); r.t:SetPoint("RIGHT", sh.dl and -52 or -2, 0)
            r.n:SetPoint("RIGHT", -(sh.bt and 50 or 0) - (sh.dl and 50 or 0) - 2, 0)
            r.t:SetText(isDone and D().Clock(t) or (cur and "..." or ""))
            r.t:SetTextColor(unpack(isDone and C.positive or C.text))
            if dl then
                r.dl:SetText(D().ClockDelta(dl)); r.dl:SetTextColor(unpack(dl <= 0 and C.positive or C.negative))
            else
                r.dl:SetText(rs and D().Clock(rs) or ""); r.dl:SetTextColor(unpack(C.muted))
            end
            r.hl:SetColorTexture(r1, g1, b1, cur and 0.15 or 0)
            r:Show()
            y = y + ROW
        end
        for i = shown + 1, #self.rows do self.rows[i]:Hide() end
        self.more:SetShown(sh.boss and hiddenN > 0 and not sh.remain)
        if self.more:IsShown() then
            self.more:ClearAllPoints(); self.more:SetPoint("TOPLEFT", 24, -(y + 2))
            self.more:SetText(hiddenN == 1 and T("+ 1 boss tué plus tôt") or string.format(T("+ %d boss tués plus tôt"), hiddenN))
            y = y + 18
        end
        self:SetHeight(y + 6)
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 then return end
        s.acc = 0
        if s.sample then return end
        local data = D():Config().timer and WK:FeatureOn("dungeons") and liveData()
        if data then s:Paint(data) else s:Hide() end
    end)
    f:Hide()
    UI:RegisterHUD("dungeonTimer", f, {
        label = T("Chrono de donjon"), default = { 420, 120 },
        enabled = function() return D():Config().timer and WK:FeatureOn("dungeons") end,
        sample = function(on)
            f.sample, f.preview = on or nil, nil
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

-- aperçu de quelques secondes après un changement d'option (hors passage en cours)
local timerPreviewN = 0
function UI:PreviewDungeonTimer()
    if not frame then frame = build() end
    if frame.sample and not frame.preview then return end -- mode édition
    if liveData() and D():Config().timer then frame.sample, frame.preview = nil, nil; UI:RefreshDungeonTimer() return end
    timerPreviewN = timerPreviewN + 1
    local mine = timerPreviewN
    frame.sample, frame.preview = true, mine
    frame:Paint(SAMPLE); frame:Show()
    C_Timer.After(6, function()
        if frame.preview == mine then frame.sample, frame.preview = nil, nil; UI:RefreshDungeonTimer() end
    end)
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
    -- icône : notre sac dans un rond teinté à la couleur d'accent (comme nos boutons en icône)
    f.edge = CreateFrame("Frame", nil, f)
    f.edge:SetPoint("TOPLEFT", 8, -8); f.edge:SetSize(32, 32)
    f.edge.ring = UI:Rounded(f.edge, 16, 0, "BACKGROUND", 1)
    f.edge.bg = UI:Rounded(f.edge, 15, 1, "BACKGROUND", 2)
    f.icon = UI:Icon(f.edge, "bag", 16, nil, "ARTWORK")
    f.icon:SetPoint("CENTER")
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
        local r, g, b = UI:Accent()
        f.edge.ring:SetColor(r, g, b, 1)
        f.edge.bg:SetColor(C.bg[1] * 0.84 + r * 0.16, C.bg[2] * 0.84 + g * 0.16, C.bg[3] * 0.84 + b * 0.16, 1)
        f.icon:SetVertexColor(r, g, b, 1)
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

---------------------------------------------------------------------------
-- Bandeau de bilan (maquette B) : en sortant du donjon, une ligne en haut de l'écran pendant 5 s : nom, boss et
-- morts, temps et écart au record, XP, or. Clic = fermer. HUD « dungeonSummary », réglage summaryBanner.
---------------------------------------------------------------------------
local banner
local SHOW_SECS = 5
local function bannerCol(parent, big, bigCol, small)
    local c = _G.CreateFrame("Frame", nil, parent)
    c.big = UI:Text(c, big, bigCol); c.big:SetPoint("TOPRIGHT", 0, 0); c.big:SetJustifyH("RIGHT")
    c.small = UI:Text(c, 9, small or C.muted); c.small:SetPoint("TOPRIGHT", c.big, "BOTTOMRIGHT", 0, -1)
    c.small:SetJustifyH("RIGHT")
    function c:Set(a, b, colB)
        self.big:SetText(a or ""); self.small:SetText(b or "")
        if colB then self.small:SetTextColor(colB[1], colB[2], colB[3]) end
        self:SetSize(math.max(self.big:GetStringWidth() or 0, self.small:GetStringWidth() or 0), 30)
    end
    return c
end
local function buildBanner()
    local f = _G.CreateFrame("Button", "WarbandKeeperDungeonSummary", _G.UIParent)
    f:SetSize(420, 46)
    f:SetFrameStrata("HIGH")
    f.edge = UI:Rounded(f, 10, 0, "BACKGROUND", 0)
    f.bg = UI:Rounded(f, 9, 1, "BACKGROUND", 1)
    f.name = UI:Text(f, 13, C.gold); f.name:SetPoint("TOPLEFT", 12, -8); f.name:SetJustifyH("LEFT")
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -2); f.sub:SetJustifyH("LEFT")
    f.sep = f:CreateTexture(nil, "ARTWORK"); f.sep:SetWidth(1); f.sep:SetColorTexture(1, 1, 1, 0.1)
    f.gold = bannerCol(f, 14, C.gold)
    f.xp = bannerCol(f, 14, C.plan or C.info)
    f.time = bannerCol(f, 16, C.text)
    f:SetScript("OnClick", function(s) s.left = 0 end)
    f:SetScript("OnUpdate", function(s, el)
        if s.sample then s:SetAlpha(1) return end
        s.left = (s.left or 0) - el
        local a = math.min(1, (SHOW_SECS - s.left) / 0.25, s.left / 0.4)
        if s.left <= 0 then s:Hide() return end
        s:SetAlpha(math.max(0, a))
    end)
    function f:Fill(data)
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.94)
        self.edge:SetColor(C.border[1], C.border[2], C.border[3], 1)
        self.name:SetText(data.name or "")
        local sub = { T("bilan") }
        if (data.total or 0) > 0 then sub[#sub + 1] = string.format(T("%d / %d boss"), data.killed or 0, data.total) end
        sub[#sub + 1] = (data.deaths or 0) == 1 and T("1 mort") or string.format(T("%d morts"), data.deaths or 0)
        if data.rep then sub[#sub + 1] = string.format("+%d %s", data.rep[2], data.rep[1]) end
        self.sub:SetText(table.concat(sub, " · "))
        -- temps et écart au record (complet seulement : un passage inachevé ne se compare pas)
        local recTxt, recCol
        if data.complete and data.record then
            local dlt = data.dur - data.record
            recTxt = dlt <= 0 and string.format(T("record -%s"), D().Clock(-dlt))
                or string.format(T("record +%s"), D().Clock(dlt))
            recCol = dlt <= 0 and C.positive or C.negative
        elseif data.complete then recTxt, recCol = T("1er temps"), C.muted
        else recTxt, recCol = T("inachevé"), C.muted end
        self.time:Set(D().Clock(data.dur or 0), recTxt, recCol)
        self.xp:SetShown((data.xp or 0) > 0)
        if (data.xp or 0) > 0 then
            self.xp:Set("+" .. (UI.FormatXP and UI.FormatXP(data.xp) or tostring(data.xp)), T("XP"))
        end
        local m = data.money or 0
        self.gold:SetShown(m ~= 0)
        if m ~= 0 then self.gold:Set(UI:PlainMoney(math.abs(m)), m < 0 and T("dépensés") or T("or")) end
        -- de droite à gauche : or, XP, temps, trait, nom
        local x = -12
        for _, c in ipairs({ self.gold, self.xp, self.time }) do
            if c:IsShown() then
                c:ClearAllPoints(); c:SetPoint("TOPRIGHT", x, -8)
                x = x - c:GetWidth() - 14
            end
        end
        self.sep:ClearAllPoints(); self.sep:SetPoint("TOPRIGHT", x + 6, -8); self.sep:SetPoint("BOTTOMRIGHT", x + 6, 8)
        local textW = math.max(self.name:GetStringWidth() or 0, self.sub:GetStringWidth() or 0)
        local nameW = math.max(140, math.min(240, textW))
        self.name:SetWidth(nameW); self.sub:SetWidth(nameW)
        self:SetWidth(12 + nameW + 14 - x)
    end
    UI:RegisterHUD("dungeonSummary", f, {
        label = T("Bilan du donjon"), default = { 0, 300 },
        enabled = function() return D():Config().summaryBanner ~= false and WK:FeatureOn("dungeons") end,
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Fill({ name = "Excavations : les Paluns", dur = 2528, record = 2600, complete = true, xp = 16934,
                    money = 297, deaths = 0, killed = 3, total = 3 })
                f:SetAlpha(1); f:Show()
            else f:Hide() end
        end,
        test = function()
            f.sample = nil
            f:Fill({ name = "Excavations : les Paluns", dur = 2528, record = 2600, complete = true, xp = 16934,
                money = 297, deaths = 0, killed = 3, total = 3 })
            f.left = SHOW_SECS; f:SetAlpha(0); f:Show()
        end,
        testStop = function() f:Hide() end })
    f:Hide()
    return f
end
function UI.ShowDungeonSummary(_, data)
    if not data then return end
    if not banner then banner = buildBanner() end
    if banner.sample then return end
    banner:Fill(data)
    if UI.HUDApply then pcall(UI.HUDApply, UI, "dungeonSummary") end
    banner.left = SHOW_SECS; banner:SetAlpha(0); banner:Show()
end
D().OnSummary = function(data) UI:ShowDungeonSummary(data) end
WK:On("PLAYER_LOGIN", function() if not banner then banner = buildBanner() end end)
