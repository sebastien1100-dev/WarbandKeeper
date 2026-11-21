local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

---------------------------------------------------------------------------
-- Quêtes du donjon : fenêtre volante discrète (HUD « dungeonQuests »), groupée par état :
--   DANS TON JOURNAL (objectifs, prête à rendre), À PRENDRE (zone et distance du donneur),
--   APRÈS PRÉREQUIS (le prérequis à faire d'abord), FAITES · n (repliées, clic pour déplier).
-- Niveau de chaque quête à la couleur du jeu (gris, vert, jaune, orange, rouge). Clic sur une quête à
-- prendre : guidage vers son donneur ; « Prendre (n) » = Dungeons:PickQuests.
-- Donjon montré : celui où l'on est, sinon celui dont l'entrée est à moins de 400 m (affichage
-- « Près du donjon ») ; « Toujours » garde le dernier donjon vu ou choisi (page Donjons, LFG).
-- Réglages : Dungeons:Config() questWin (auto / always / off), questWinAlpha, questWinObjs,
-- questWinDone, questWinCombat, questWinAuto (cachée quand il ne reste rien) ; roue de la page Donjons.
---------------------------------------------------------------------------
local W = 280
local NEAR = 400
local win
local closedFor -- donjon fermé par la croix (jusqu'au donjon suivant)
local doneOpen = false

local function D() return WK.modules.Dungeons end
-- pastille « NOUVELLE / APPRISE / CORRIGÉE » (Modules/DataLog.lua)
local function badge(id) local DL = WK.modules.DataLog; return DL and DL:Badge(id) or "" end
local function Q() return WK.modules.Quests end

-- couleur du niveau d'une quête pour le perso (comme le jeu)
local function levelColor(lvl)
    lvl = lvl or 0
    if GetQuestDifficultyColor then
        local ok, c = pcall(GetQuestDifficultyColor, lvl)
        if ok and type(c) == "table" and c.r then return { c.r, c.g, c.b } end
    end
    local me = UnitLevel and UnitLevel("player") or 1
    local d = lvl - me
    if d >= 5 then return { 1, 0.13, 0.13 } elseif d >= 3 then return { 1, 0.5, 0.25 }
    elseif d >= -2 then return { 1, 0.82, 0 } elseif d >= -7 then return { 0.25, 0.75, 0.25 } end
    return { 0.62, 0.62, 0.62 }
end

local function distOf(q)
    local G = WK.modules.Guide
    local map = q.smap or q.map
    local p = G and G:PlayerPos()
    if not (q.x and map and p) then return nil end
    local t = { map = map, x = q.x / 100, y = q.y / 100 }
    t.cont, t.wx, t.wy = G.ToWorld(map, t.x, t.y)
    local ok, d = pcall(G.Vector, G, p, t)
    return ok and d or nil
end
local function distText(d)
    if not d then return nil end
    if d >= 1000 then return (string.format("%.1f km", d / 1000):gsub("%.", ",")) end
    return string.format(T("%d m"), math.floor(d + 0.5))
end

-- donjon dont l'entrée est la plus proche (à moins de NEAR m)
local function nearDungeon()
    local G = WK.modules.Guide
    local p = G and G:PlayerPos()
    if not p then return nil end
    local best, bd
    for _, d in ipairs(WK.DungeonsDB or {}) do
        if d.entry and not d.raid then
            local t = { map = d.entry[1], x = d.entry[2] / 100, y = d.entry[3] / 100 }
            t.cont, t.wx, t.wy = G.ToWorld(t.map, t.x, t.y)
            local ok, dd = pcall(G.Vector, G, p, t)
            if ok and dd and dd < NEAR and (not bd or dd < bd) then best, bd = d, dd end
        end
    end
    return best
end

-- donjon à montrer selon le réglage
local function target(cfg)
    local Dg = D()
    if not Dg then return nil end
    local d = Dg:Current() or nearDungeon()
    if d then Dg.questWinLast = d.key end
    if not d and cfg.questWin == "always" and Dg.questWinLast then d = Dg:Get(Dg.questWinLast) end
    return d
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDungeonQuests", UIParent)
    f:SetSize(W, 120)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 10, { C.bg[1], C.bg[2], C.bg[3], 0.86 }, C.border)
    f.head = UI:Text(f, 10, C.muted); f.head:SetPoint("TOPLEFT", 11, -10); f.head:SetPoint("RIGHT", -96, 0)
    f.headR = UI:Text(f, 10, C.muted); f.headR:SetPoint("TOPRIGHT", -28, -10); f.headR:SetJustifyH("RIGHT")
    f.close = UI:IconButton(f, "close", 16, "Cacher jusqu'au prochain donjon")
    f.close:SetPoint("TOPRIGHT", -6, -6)
    f.close:SetScript("OnClick", function() closedFor = f.key; f:Hide() end)
    f.secs, f.rows = {}, {}
    local function sec(i)
        local s = f.secs[i]
        if not s then
            s = CreateFrame("Button", nil, f); s:SetHeight(18)
            s.l = UI:Text(s, 9, C.dim); s.l:SetPoint("LEFT", 11, 0)
            s.r = UI:Text(s, 9, C.dim); s.r:SetPoint("RIGHT", -11, 0)
            f.secs[i] = s
        end
        return s
    end
    local function row(i)
        local r = f.rows[i]
        if not r then
            r = CreateFrame("Button", nil, f)
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints()
            r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("TOPLEFT", 0, -4); r.bar:SetPoint("BOTTOMLEFT", 0, 4); r.bar:SetWidth(3)
            r.dot = UI:Icon(r, "circle", 16, nil, "ARTWORK"); r.dot:SetPoint("TOPLEFT", 10, -5)
            r.glyph = UI:Icon(r, "bang", 10, nil, "OVERLAY"); r.glyph:SetPoint("CENTER", r.dot, "CENTER")
            r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 32, -5); r.name:SetPoint("RIGHT", -34, 0)
            r.lvl = UI:Text(r, 11); r.lvl:SetPoint("TOPRIGHT", -11, -6); r.lvl:SetJustifyH("RIGHT")
            r.sub = UI:Text(r, 10, C.muted); r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3); r.sub:SetPoint("RIGHT", -11, 0)
            if r.sub.SetWordWrap then r.sub:SetWordWrap(true) end
            r:SetScript("OnClick", function(s) if s.onClick then s.onClick() end end)
            r:SetScript("OnEnter", function(s)
                if not s.tip then return end
                UI:TooltipOwner(s, "ANCHOR_LEFT")
                GameTooltip:SetText(s.tip[1], 1, 1, 1)
                for k = 2, #s.tip do GameTooltip:AddLine(s.tip[k], 0.8, 0.8, 0.8, true) end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.rows[i] = r
        end
        return r
    end
    f.foot = CreateFrame("Frame", nil, f); f.foot:SetHeight(34)
    f.footLine = f.foot:CreateTexture(nil, "ARTWORK"); f.footLine:SetPoint("TOPLEFT", 1, 0); f.footLine:SetPoint("TOPRIGHT", -1, 0); f.footLine:SetHeight(1)
    f.footLine:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
    f.pick = UI:Button(f.foot, T("Prendre"), 100, 22, "secondary")
    f.pick:SetPoint("LEFT", 10, -1)
    f.pick:SetScript("OnClick", function() if f.dungeon then D():PickQuests(f.dungeon); UI:RefreshDungeonQuests() end end)
    f.footTxt = UI:Text(f.foot, 10, C.muted); f.footTxt:SetPoint("LEFT", f.pick, "RIGHT", 8, 0); f.footTxt:SetPoint("RIGHT", -10, 0)

    -- remplit la fenêtre ; data = { name, xp, log = {…}, avail = {…}, waiting = {…}, done = n, doneList, pick, preN }
    function f:Paint(data, cfg)
        local ar, ag, ab = UI:Accent()
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], (cfg.questWinAlpha or 86) / 100)
        self.border:SetColor(C.border[1], C.border[2], C.border[3], math.min(1, (cfg.questWinAlpha or 86) / 100 + 0.1))
        self.head:SetText(UI:Upper(T("Quêtes")) .. " · " .. UI:Hex(C.text) .. UI:Upper(data.name or "") .. "|r")
        self.headR:SetText((data.xp or 0) > 0 and string.format(T("env. %d XP"), data.xp) or "")
        local y, ns, nr = 28, 0, 0
        local function section(label, n, onClick)
            ns = ns + 1
            local s = sec(ns)
            s:ClearAllPoints(); s:SetPoint("TOPLEFT", 0, -y); s:SetPoint("TOPRIGHT", 0, -y)
            s.l:SetText(UI:Upper(T(label))); s.r:SetText(n and tostring(n) or "")
            s:SetScript("OnClick", onClick)
            s:Show()
            y = y + 18
        end
        local function line(e)
            nr = nr + 1
            local r = row(nr)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            r.name:SetText(e.name or "?")
            r.name:SetTextColor(unpack(e.dim and C.muted or C.text))
            r.lvl:SetText(e.lvl and tostring(e.lvl) or "")
            local lc = levelColor(e.lvl); r.lvl:SetTextColor(lc[1], lc[2], lc[3])
            local col = e.color
            r.dot:SetVertexColor(col[1], col[2], col[3], e.solid and 1 or 0.22)
            r.glyph:SetTexture(UI.MEDIA .. (e.glyph or "bang"))
            if e.solid then r.glyph:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1) else r.glyph:SetVertexColor(col[1], col[2], col[3], 1) end
            r.sub:SetText(e.sub or ""); r.sub:SetShown(e.sub ~= nil and e.sub ~= "")
            if e.subColor then r.sub:SetTextColor(unpack(e.subColor)) else r.sub:SetTextColor(unpack(C.muted)) end
            local cur = e.current
            r.bar:SetColorTexture(ar, ag, ab, 1); r.bar:SetShown(cur and true or false)
            r.hl:SetColorTexture(ar, ag, ab, cur and 0.10 or 0)
            r.onClick, r.tip = e.onClick, e.tip
            local h = 26 + ((e.sub and e.sub ~= "") and math.max(13, (r.sub:GetStringHeight() or 12)) + 3 or 0)
            r:SetHeight(h)
            r:Show()
            y = y + h
        end
        if #data.log > 0 then section("Dans ton journal", #data.log); for _, e in ipairs(data.log) do line(e) end end
        if #data.avail > 0 then section("À prendre", #data.avail); for _, e in ipairs(data.avail) do line(e) end end
        if #data.waiting > 0 then section("Après prérequis", #data.waiting); for _, e in ipairs(data.waiting) do line(e) end end
        if cfg.questWinDone ~= false and (data.done or 0) > 0 then
            section(string.format(T("Faites · %d  %s"), data.done, doneOpen and "-" or "+"), nil, function() doneOpen = not doneOpen; UI:RefreshDungeonQuests() end)
            if doneOpen then for _, e in ipairs(data.doneList or {}) do line(e) end end
        end
        if #data.log + #data.avail + #data.waiting == 0 and (data.done or 0) == 0 then
            section("Aucune quête connue pour ce donjon.")
        end
        for i = ns + 1, #self.secs do self.secs[i]:Hide() end
        for i = nr + 1, #self.rows do self.rows[i]:Hide() end
        y = y + 4
        if (data.pick or 0) > 0 then
            self.foot:ClearAllPoints(); self.foot:SetPoint("TOPLEFT", 0, -y); self.foot:SetPoint("TOPRIGHT", 0, -y)
            self.pick:SetLabel(string.format(T("Prendre (%d)"), data.pick))
            self.footTxt:SetText((data.preN or 0) > 0 and string.format(T("dont %d prérequis"), data.preN) or T("flèche vers le donneur le plus proche"))
            self.foot:Show()
            y = y + 34
        else
            self.foot:Hide()
        end
        self:SetHeight(y + 2)
    end
    f:Hide()
    -- distance et entrée surveillées toutes les 2 s (rien à faire tant que la fenêtre est coupée)
    local acc = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 2 then return end
        acc = 0
        if not f.sample then UI:RefreshDungeonQuests() end
    end)
    UI:RegisterHUD("dungeonQuests", f, {
        label = T("Quêtes du donjon"), default = { -330, 120 },
        enabled = function() local Dg = D(); return Dg and Dg:Config().questWin ~= "off" and WK:FeatureOn("dungeons") end,
        sample = function(on)
            f.sample = on or nil
            if on then
                local A, G, P, Ok = UI:AccentTable(), C.gold, C.warning, C.positive
                f:Paint({ name = T("Les Mortemines"), xp = 2600,
                    log = { { name = T("Les rouges de la Confrérie"), lvl = 20, color = A, solid = true, current = true, sub = T("Tueur défias 6/10 · Bandeau rouge 3/7") },
                            { name = T("La fin de Van Cleef"), lvl = 22, color = Ok, solid = true, glyph = "star", sub = T("prête à rendre"), subColor = Ok } },
                    avail = { { name = T("Le collier d'Old Murk"), lvl = 18, color = G, sub = T("Marche de l'Ouest · 1,2 km") } },
                    waiting = { { name = T("Le dernier Défias"), lvl = 22, color = P, glyph = "lock", sub = T("après : La Confrérie défias"), subColor = P } },
                    done = 3, pick = 2, preN = 1 }, D():Config())
                f:Show()
            else UI:RefreshDungeonQuests() end
        end,
    })
    return f
end

-- couleur d'accent en table (pour les pastilles)
function UI:AccentTable() local r, g, b = UI:Accent(); return { r, g, b } end

---------------------------------------------------------------------------
-- Données de la fenêtre
---------------------------------------------------------------------------
local function objectivesText(qid)
    local QT = WK.modules.QuestTrack
    local parts = {}
    for _, o in ipairs(QT and QT:Objectives(qid) or {}) do
        local need = o.need or 0
        local name = tostring(o.name or o.text or ""):gsub("%s*:%s*%d+%s*/%s*%d+.*$", "")
        if need > 0 then
            local cnt = string.format("%d/%d", math.min(o.have or 0, need), need)
            table.insert(parts, name .. " " .. (o.done and (UI:Hex(C.positive) .. cnt .. "|r") or (UI:Hex(C.text) .. cnt .. "|r")))
        elseif name ~= "" then
            table.insert(parts, o.done and (UI:Hex(C.positive) .. name .. "|r") or name)
        end
    end
    return table.concat(parts, " · ")
end

function UI:DungeonQuestsData(d, cfg)
    local Dg, Qm = D(), Q()
    local QT = WK.modules.QuestTrack
    local s = Dg:QuestSummary(d)
    local R = WK.modules.Rares
    local A = UI:AccentTable()
    local out = { name = Dg:Name(d), log = {}, avail = {}, waiting = {}, done = s.done, doneList = {}, pick = Dg:PickCount(s), preN = #s.pre, xp = 0 }
    for _, q in ipairs(s.logList or {}) do
        local ready = QT and QT:IsComplete(q.id)
        local e = { name = Qm:Name(q) .. badge(q.id), lvl = q.lvl, solid = true }
        if ready then
            e.color, e.glyph, e.sub, e.subColor = C.positive, "star", T("prête à rendre"), C.positive
        else
            e.color, e.current = A, true
            e.sub = cfg.questWinObjs ~= false and objectivesText(q.id) or nil
        end
        e.onClick = function() if QT and QT.Track then QT:Track(q.id) end end
        table.insert(out.log, e)
        out.xp = out.xp + (q.xp or 0)
    end
    for _, q in ipairs(s.avail) do
        local zone = R and R.ZoneName and R:ZoneName(q.smap or q.map) or ""
        local dt = distText(distOf(q))
        table.insert(out.avail, { name = Qm:Name(q) .. badge(q.id), lvl = q.lvl, color = C.gold,
            sub = zone .. (dt and (" · " .. dt) or ""),
            tip = { Qm:Name(q), T("Clic : guider vers le donneur") },
            onClick = function() Qm:GuideTo(q) end })
        out.xp = out.xp + (q.xp or 0)
    end
    for _, q in ipairs(s.waiting) do
        local pre
        for _, e in ipairs(s.pre) do if e.unlock == q then pre = e.q break end end
        local sub = pre and string.format(T("après : %s"), Qm:Name(pre)) or T("après une autre quête (en cours)")
        table.insert(out.waiting, { name = Qm:Name(q) .. badge(q.id), lvl = q.lvl, color = C.warning, glyph = "lock", sub = sub, subColor = C.warning,
            tip = pre and { Qm:Name(pre), T("Prérequis de :") .. " " .. Qm:Name(q), T("Clic : guider vers son donneur") } or nil,
            onClick = pre and function() Qm:GuideTo(pre) end or nil })
        out.xp = out.xp + (q.xp or 0)
    end
    for _, q in ipairs(s.doneList or {}) do
        table.insert(out.doneList, { name = Qm:Name(q), lvl = q.lvl, color = C.positive, glyph = "star", dim = true })
    end
    return out
end

function UI:RefreshDungeonQuests()
    local Dg = D()
    if not Dg then return end
    win = win or build()
    if win.sample then return end
    local cfg = Dg:Config()
    if cfg.questWin == "off" or not WK:FeatureOn("dungeons") then win:Hide() return end
    if cfg.questWinCombat and InCombatLockdown and InCombatLockdown() then win:Hide() return end
    local d = target(cfg)
    if not d then win:Hide() return end
    if closedFor and closedFor ~= d.key then closedFor = nil end
    if closedFor == d.key then win:Hide() return end
    local data = UI:DungeonQuestsData(d, cfg)
    -- rien à faire ni à prendre : cachée si demandé
    if cfg.questWinAuto and #data.log + #data.avail + #data.waiting == 0 then win:Hide() return end
    win.key, win.dungeon = d.key, d
    win:Paint(data, cfg)
    win:Show()
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(3, function() UI:RefreshDungeonQuests() end) end)
for _, ev in ipairs({ "QUEST_LOG_UPDATE", "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    WK:On(ev, function() if win and not win.sample then C_Timer.After(0.3, function() UI:RefreshDungeonQuests() end) end end)
end
