local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Carte de la quête suivie (HUD « questTrack ») : titre, zone et niveau, objectifs avec coche, jauge et
-- compte, « Camp suivant » et « Rendu » ; la croix arrête le suivi. Données : Modules/QuestTrack.lua.
-- Réglage QuestTrack:Config().hud (roue de la page Quêtes).
local W, ROWS = 236, 6
local card

local function Q() return WK.modules.QuestTrack end
local function shown() return WK:FeatureOn("quests") and Q():Config().hud end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperQuestTracker", UIParent)
    f:SetSize(W, 120)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.92 }, C.border)
    f.title = UI:Text(f, 13, C.text); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetPoint("RIGHT", -34, 0)
    f.title:SetJustifyH("LEFT"); if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3); f.sub:SetPoint("RIGHT", -14, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.sub:SetJustifyH("LEFT")
    f.close = UI:IconButton(f, "close", 20, "Ne plus suivre cette quête")
    f.close:SetPoint("TOPRIGHT", -8, -8)
    f.close:SetScript("OnClick", function()
        if f.guide then WK.modules.LevelGuide:Follow(false)
        elseif f.tour then WK.modules.QuestPlan:Stop() else Q():Untrack() end
    end)
    -- tournée : jauge d'avancée sous le titre
    f.prog = UI:Progress(f, 4)
    f.prog:SetPoint("TOPLEFT", 14, -40); f.prog:SetPoint("RIGHT", -14, 0)
    f.prog:Hide()
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetHeight(18)
        r:SetPoint("TOPLEFT", 14, -44 - (i - 1) * 20); r:SetPoint("RIGHT", -14, 0)
        r.box = r:CreateTexture(nil, "ARTWORK"); r.box:SetSize(11, 11); r.box:SetPoint("LEFT", 0, 0)
        r.name = UI:Text(r, 11, C.text); r.name:SetPoint("LEFT", 18, 0); r.name:SetWidth(104); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.count = UI:Text(r, 10, C.muted); r.count:SetPoint("RIGHT", 0, 0); r.count:SetJustifyH("RIGHT")
        r.bar = UI:Progress(r, 5)
        r.bar:SetPoint("LEFT", r.name, "RIGHT", 6, 0); r.bar:SetPoint("RIGHT", r.count, "LEFT", -6, 0)
        r:Hide()
        f.rows[i] = r
    end
    f.next = UI:Button(f, T("Zone suivante"), nil, 22, "secondary")
    f.next:SetScript("OnClick", function()
        if f.guide then local LG = WK.modules.LevelGuide; local s = LG:Steps()[1]; if s then LG:Skip(s.key) end
        elseif f.tour then WK.modules.QuestPlan:Skip() else Q():NextCamp() end
    end)
    f.next.tooltip = "Vise une autre zone d'un objectif pas fini (de la plus proche à la plus lointaine)."
    f.turn = UI:Button(f, T("Rendu"), nil, 22, "secondary")
    f.turn:SetScript("OnClick", function()
        if f.guide then WK.modules.LevelGuide:Run(1)
        elseif f.tour then local P = WK.modules.QuestPlan; P:Pause(not (P:Tour() or {}).paused) else Q():GoTurnIn() end
    end)
    f.turn.tooltip = "Guide vers le personnage qui reprend la quête."
    f.goal = UI:Text(f, 10, C.muted); f.goal:SetJustifyH("LEFT")

    -- Vue « tournée » : pastille du genre d'étape, titre et lieu, boutons ronds (pause, passer, arrêter),
    -- bandeau de distance, objectifs, frise des étapes, temps restant et les 2 étapes suivantes
    local tv = CreateFrame("Frame", nil, f)
    tv:SetAllPoints()
    tv:Hide()
    f.tv = tv
    tv.badge = CreateFrame("Frame", nil, tv); tv.badge:SetSize(30, 30); tv.badge:SetPoint("TOPLEFT", 12, -12)
    tv.badge.bg = tv.badge:CreateTexture(nil, "ARTWORK"); tv.badge.bg:SetAllPoints(); tv.badge.bg:SetTexture(UI.MEDIA .. "circle")
    tv.badge.shine = tv.badge:CreateTexture(nil, "OVERLAY"); tv.badge.shine:SetTexture(UI.MEDIA .. "circle")
    tv.badge.shine:SetSize(14, 8); tv.badge.shine:SetPoint("TOP", 0, -4); tv.badge.shine:SetVertexColor(1, 1, 1, 0.3)
    tv.badge.txt = tv.badge:CreateFontString(nil, "OVERLAY")
    if not (UI.FONT and tv.badge.txt:SetFont(UI.FONT, 16, "")) then tv.badge.txt:SetFont("Fonts\\FRIZQT__.TTF", 16, "") end
    tv.badge.txt:SetPoint("CENTER", 0, 0); tv.badge.txt:SetTextColor(unpack(C.bg))
    tv.badge.icon = UI:Icon(tv.badge, "crosshair", 16, nil, "OVERLAY"); tv.badge.icon:SetPoint("CENTER")
    tv.badge.icon:SetVertexColor(unpack(C.bg))
    tv.close = UI:IconButton(tv, "close", 20, "Arrêter la tournée")
    tv.close:SetPoint("TOPRIGHT", -10, -14)
    tv.close:SetScript("OnClick", function() WK.modules.QuestPlan:Stop() end)
    tv.skip = UI:IconButton(tv, "chevron", 20, "Passer l'étape")
    if tv.skip.icon.SetRotation then tv.skip.icon:SetRotation(math.pi / 2) end -- chevron vers la droite
    tv.skip:SetPoint("RIGHT", tv.close, "LEFT", -5, 0)
    tv.skip:SetScript("OnClick", function() WK.modules.QuestPlan:Skip() end)
    tv.pp = UI:IconButton(tv, "pause", 20, "Pause")
    tv.pp:SetPoint("RIGHT", tv.skip, "LEFT", -5, 0)
    tv.pp:SetScript("OnClick", function() local P = WK.modules.QuestPlan; P:Pause(not (P:Tour() or {}).paused) end)
    tv.title = UI:Text(tv, 13, C.text); tv.title:SetPoint("TOPLEFT", tv.badge, "TOPRIGHT", 9, 0); tv.title:SetPoint("RIGHT", tv.pp, "LEFT", -6, 0)
    tv.title:SetJustifyH("LEFT"); if tv.title.SetWordWrap then tv.title:SetWordWrap(false) end
    tv.sub = UI:Text(tv, 10, C.muted); tv.sub:SetPoint("TOPLEFT", tv.title, "BOTTOMLEFT", 0, -3); tv.sub:SetPoint("RIGHT", -12, 0)
    tv.sub:SetJustifyH("LEFT"); if tv.sub.SetWordWrap then tv.sub:SetWordWrap(false) end
    -- bandeau de distance
    tv.band = CreateFrame("Frame", nil, tv); tv.band:SetHeight(26)
    tv.band.bg = UI:Rounded(tv.band, 7, 0, "BACKGROUND", 1); tv.band.bg:SetColor(unpack(C.surface2))
    tv.band.icon = UI:Icon(tv.band, "navarrow", 12, nil, "ARTWORK"); tv.band.icon:SetPoint("LEFT", 9, 0)
    tv.band.txt = UI:Text(tv.band, 12, C.text); tv.band.txt:SetPoint("LEFT", 27, 0); tv.band.txt:SetPoint("RIGHT", -9, 0)
    tv.band.txt:SetJustifyH("LEFT")
    -- frise des étapes
    tv.dots = {}
    tv.foot = UI:Text(tv, 10, C.muted); tv.foot:SetJustifyH("LEFT")
    tv.footR = UI:Text(tv, 10, C.muted); tv.footR:SetJustifyH("RIGHT")
    -- 2 étapes suivantes
    tv.nexts = {}
    for i = 1, 2 do
        local r = CreateFrame("Frame", nil, tv); r:SetHeight(18)
        r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(16, 16); r.dot:SetPoint("LEFT", 0, 0); r.dot:SetTexture(UI.MEDIA .. "circle")
        r.num = UI:Text(r, 9, C.bg); r.num:SetPoint("CENTER", r.dot, "CENTER", 0, 0)
        r.txt = UI:Text(r, 11, C.muted); r.txt:SetPoint("LEFT", 22, 0); r.txt:SetPoint("RIGHT", 0, 0); r.txt:SetJustifyH("LEFT")
        if r.txt.SetWordWrap then r.txt:SetWordWrap(false) end
        tv.nexts[i] = r
    end

    -- data = { title, sub, objs = { { name, have, need, done } }, goal } (aperçu ou quête suivie)
    local KIND = { pick = { "gold", "!" }, ["do"] = { nil, nil }, turn = { "positive", "?" } }
    local function kindColor(k)
        local e = KIND[k]
        if e and e[1] then return C[e[1]] end
        return { UI:Accent() }
    end
    local CLASSIC = { "title", "sub", "close", "prog", "next", "turn", "goal" }
    function f:PaintTour(d)
        for _, k in ipairs(CLASSIC) do self[k]:Hide() end
        local v = self.tv
        tv:Show()
        self.tour, self.guide = true, nil
        local W2 = 292
        self:SetWidth(W2)
        local col = kindColor(d.kind)
        v.badge.bg:SetVertexColor(col[1], col[2], col[3], d.paused and 0.45 or 1)
        local letter = KIND[d.kind] and KIND[d.kind][2]
        v.badge.txt:SetText(letter or ""); v.badge.txt:SetShown(letter ~= nil)
        v.badge.icon:SetShown(letter == nil)
        v.title:SetText(d.title or "")
        v.title:SetTextColor(unpack(d.paused and C.muted or C.text))
        v.sub:SetText((d.paused and (UI:Hex(C.warning) .. T("EN PAUSE") .. "|r  ") or "") .. (d.sub or ""))
        v.pp.icon:SetTexture(UI.MEDIA .. (d.paused and "play" or "pause"))
        v.pp.tooltip = d.paused and "Reprendre" or "Pause"
        local y = -52
        -- distance
        if d.dist and not d.paused then
            v.band:ClearAllPoints(); v.band:SetPoint("TOPLEFT", 12, y); v.band:SetPoint("RIGHT", -12, 0)
            local r, g, b = UI:Accent(); v.band.icon:SetVertexColor(r, g, b, 1)
            v.band.txt:SetText(string.format(T("%d m"), math.floor(d.dist + 0.5)) .. "  " .. UI:Hex(C.muted) .. "· "
                .. string.format(T("env. %d min"), math.max(1, math.floor(d.dist / 7 / 60 + 0.5))) .. "|r")
            v.band:Show()
            y = y - 32
        else
            v.band:Hide()
        end
        -- objectifs
        for i, r in ipairs(self.rows) do
            local o = d.objs[i]
            if o then
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetPoint("RIGHT", -14, 0)
                r.name:SetWidth(150)
                y = y - 20
                if o.done then
                    r.box:SetTexture(UI.MEDIA .. "circle"); r.box:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
                else
                    r.box:SetTexture(UI.MEDIA .. "ring"); r.box:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
                end
                r.name:SetText(o.name)
                r.name:SetTextColor(unpack(o.done and C.positive or C.text))
                local need = o.need or 0
                r.count:SetText(need > 0 and string.format("%d/%d", o.have or 0, need) or (o.done and T("fait") or ""))
                r.count:SetTextColor(unpack(o.done and C.positive or C.muted))
                r.bar.color = o.done and C.positive or nil
                r.bar:SetShown(need > 0 and not o.done)
                r.bar:SetValue(need > 0 and (o.have or 0) / need or 0)
                r:Show()
            else
                r:Hide()
            end
        end
        -- frise : une case par étape (faites en vert, en cours à l'accent)
        y = y - 6
        local n = d.count
        local inner = W2 - 24
        local gap = n > 16 and 2 or 4
        local dw = math.max(3, (inner - (n - 1) * gap) / n)
        for i = 1, math.max(n, #v.dots) do
            local t = v.dots[i]
            if i <= n then
                if not t then t = tv:CreateTexture(nil, "ARTWORK"); t:SetTexture("Interface\\Buttons\\WHITE8X8"); v.dots[i] = t end
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", 12 + (i - 1) * (dw + gap), y); t:SetSize(dw, 4)
                local c = (i < d.idx and C.positive) or (i == d.idx and { UI:Accent() }) or C.surface2
                t:SetVertexColor(c[1], c[2], c[3], 1)
                t:Show()
            elseif t then
                t:Hide()
            end
        end
        y = y - 10
        v.foot:ClearAllPoints(); v.foot:SetPoint("TOPLEFT", 12, y)
        v.foot:SetText(string.format(T("Étape %d / %d"), d.idx, n))
        v.footR:ClearAllPoints(); v.footR:SetPoint("TOPRIGHT", -12, y)
        v.footR:SetText(string.format(T("reste env. %d min"), d.mins))
        y = y - 18
        -- 2 étapes suivantes
        for i, r in ipairs(v.nexts) do
            local nx = d.nexts[i]
            if nx then
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 12, y); r:SetPoint("RIGHT", -12, 0)
                local c = kindColor(nx.kind)
                r.dot:SetVertexColor(c[1], c[2], c[3], 1)
                r.num:SetText(tostring(nx.n))
                r.txt:SetText(nx.title)
                r:Show()
                y = y - 20
            else
                r:Hide()
            end
        end
        self:SetHeight(-y + 10)
    end

    function f:Paint(data)
        if self.tv then
            self.tv:Hide()
            for _, k in ipairs(CLASSIC) do if k ~= "prog" then self[k]:Show() end end
            self:SetWidth(W)
            for _, r in ipairs(self.rows) do r.name:SetWidth(104); r.count:SetTextColor(unpack(C.muted)) end
        end
        self.title:SetText(data.title or "")
        self.sub:SetText(data.sub or "")
        local y = -44
        self.tour = data.tour
        self.guide = data.guide
        self.prog:SetShown(data.prog ~= nil)
        if data.prog then self.prog:SetValue(data.prog); y = -52 end
        self.next:SetLabel(data.b1 or T("Zone suivante")); self.next:SetWidth(self.next.label:GetStringWidth() + 26)
        self.turn:SetLabel(data.b2 or T("Rendu")); self.turn:SetWidth(self.turn.label:GetStringWidth() + 26)
        self.close.tooltip = (data.guide and "Ne plus suivre le guide de montée") or (data.tour and "Arrêter la tournée") or "Ne plus suivre cette quête"
        for i, r in ipairs(self.rows) do
            local o = data.objs[i]
            if o then
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, y); r:SetPoint("RIGHT", -14, 0)
                y = y - 20
                if o.done then
                    r.box:SetTexture(UI.MEDIA .. "circle"); r.box:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
                else
                    r.box:SetTexture(UI.MEDIA .. "ring"); r.box:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
                end
                r.name:SetText(o.name)
                r.name:SetTextColor(unpack(o.done and C.muted or C.text))
                local need = o.need or 0
                r.count:SetText(need > 0 and string.format("%d/%d", o.have or 0, need) or (o.done and T("fait") or ""))
                r.bar.color = o.done and C.positive or nil
                r.bar:SetShown(need > 0)
                r.bar:SetValue(need > 0 and (o.have or 0) / need or 0)
                r:Show()
            else
                r:Hide()
            end
        end
        self.goal:ClearAllPoints(); self.goal:SetPoint("TOPLEFT", 14, y - 2); self.goal:SetPoint("RIGHT", -14, 0)
        self.goal:SetText(data.goal or "")
        y = y - ((data.goal and data.goal ~= "") and ((self.goal:GetStringHeight() or 12) + 4) or 2)
        self.next:ClearAllPoints(); self.next:SetPoint("TOPLEFT", 14, y - 4)
        self.turn:ClearAllPoints(); self.turn:SetPoint("LEFT", self.next, "RIGHT", 6, 0)
        self.next:SetEnabled(data.canNext ~= false)
        self:SetHeight(-y + 4 + 22 + 12)
    end

    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 or s.sample then return end
        s.acc = 0
        UI:RefreshQuestTracker()
    end)
    f:Hide()
    UI:RegisterHUD("questTrack", f, {
        label = T("Quête suivie"), default = { 430, 120 },
        enabled = function() return shown() end,
        sample = function(on)
            f.sample = on or nil
            if on and WK.modules.QuestPlan and WK.modules.QuestPlan:Tour() then
                -- tournée en cours : aperçu de la carte de tournée
                f:PaintTour({ kind = "turn", title = T("Rendre : Le viaduc de Thandol"), sub = T("Les Paluns"), dist = 160,
                    objs = {}, idx = 4, count = 7, mins = 18,
                    nexts = { { n = 5, kind = "do", title = T("Coin du loch : 3 quêtes") }, { n = 6, kind = "pick", title = T("Prendre : Thelsamar") } } })
                f:Show()
            elseif on then
                f:Paint({ title = T("La chasse aux loups"), sub = T("Sombrivage · niveau 14"), goal = T("Zone à 140 m"),
                    objs = { { name = T("Loup de Sombrivage"), have = 6, need = 10 }, { name = T("Croc de loup"), have = 4, need = 4, done = true } } })
                f:Show()
            else
                UI:RefreshQuestTracker()
            end
        end,
    })
    return f
end

function UI:RefreshQuestTracker()
    if not card then
        if not shown() then return end
        card = build()
    end
    if card.sample then return end
    local q = Q()
    -- tournée de quêtes en cours (Modules/QuestPlan.lua) : la carte suit la tournée
    local P = WK.modules.QuestPlan
    local tour = shown() and P and P:Tour()
    if tour and tour.steps[tour.idx] then
        local s = tour.steps[tour.idx]
        local objs = P:StepObjectives(s)
        local mins = math.max(1, math.floor(P:Remaining() / 60 + 0.5))
        -- distance jusqu'à l'étape
        local G = WK.modules.Guide
        local me, dist = G and G:PlayerPos(), nil
        if me and s.map then
            local t = { map = s.map, x = s.x, y = s.y }
            t.cont, t.wx, t.wy = G.ToWorld(s.map, s.x, s.y)
            dist = G:Vector(me, t)
        end
        local zone = s.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(s.map)
        local sub = {}
        if zone and zone.name then table.insert(sub, zone.name) end
        if s.kind == "do" and #s.qids > 1 then table.insert(sub, string.format(T("%d quêtes ici"), #s.qids))
        elseif s.kind ~= "do" and #s.qids > 1 then table.insert(sub, string.format(T("%d quêtes"), #s.qids)) end
        local nexts = {}
        for i = 1, 2 do
            local ns = tour.steps[tour.idx + i]
            if ns then table.insert(nexts, { n = tour.idx + i, kind = ns.kind, title = P:StepTitle(ns) }) end
        end
        card:PaintTour({ kind = s.kind, title = P:StepTitle(s), sub = table.concat(sub, " · "), paused = tour.paused,
            dist = dist, objs = objs, idx = tour.idx, count = #tour.steps, mins = mins, nexts = nexts })
        card:Show()
        return
    end
    -- guide de montée suivi (Modules/LevelGuide.lua), sans tournée en cours
    local LG = WK.modules.LevelGuide
    if shown() and LG and LG:Following() then
        local steps = LG:Steps()
        local s1, s2 = steps[1], steps[2]
        local lvl = UnitLevel and UnitLevel("player") or 1
        local cur, max = (UnitXP and UnitXP("player")) or 0, (UnitXPMax and UnitXPMax("player")) or 1
        local qid0 = q:Tracked()
        local objs = {}
        if qid0 then
            for _, o in ipairs(q:Objectives(qid0)) do
                table.insert(objs, { name = o.name ~= "" and o.name or o.text, have = o.have, need = o.need, done = o.done })
            end
        end
        card:Paint({ guide = true, title = string.format(T("Montée en niveaux · niveau %d"), lvl),
            sub = s1 and s1.title or T("Rien à faire pour l'instant"),
            prog = max > 0 and cur / max or 0, objs = objs,
            goal = (s1 and s1.sub and (s1.sub .. (s2 and ("|n" .. T("Ensuite : ") .. s2.title) or ""))) or (s2 and (T("Ensuite : ") .. s2.title)) or "",
            b1 = T("Passer"), b2 = T("Lancer"), canNext = s1 ~= nil })
        card:Show()
        return
    end
    local qid = shown() and q:Tracked()
    if not qid then card:Hide() return end
    local objs = {}
    for _, o in ipairs(q:Objectives(qid)) do
        table.insert(objs, { name = o.name ~= "" and o.name or o.text, have = o.have, need = o.need, done = o.done })
    end
    local lvl = q:Level(qid)
    local goal = q:Goal(qid)
    local gtext
    local complete = q:IsComplete(qid)
    if goal then
        local me, G = WK.modules.Guide:PlayerPos(), WK.modules.Guide
        local d
        if me then
            local t = { map = goal.map, x = goal.x, y = goal.y }
            t.cont, t.wx, t.wy = G.ToWorld(goal.map, goal.x, goal.y)
            d = G:Vector(me, t)
        end
        if goal.turnIn then
            gtext = d and string.format(T("Rendu à %d m"), math.floor(d + 0.5)) or T("Rendu dans une autre zone")
        else
            gtext = d and string.format(T("%s · zone à %d m"), goal.name, math.floor(d + 0.5))
                or string.format(T("%s · zone sur une autre carte"), goal.name)
        end
    elseif not complete then
        gtext = T("Pas de zone connue pour ces objectifs.")
    end
    local zone = goal and goal.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(goal.map)
    local sub = {}
    if zone and zone.name then table.insert(sub, zone.name) end
    if lvl then table.insert(sub, string.format(T("niveau %d"), lvl)) end
    if complete then table.insert(sub, UI:Hex(C.positive) .. T("prête à rendre") .. "|r") end
    card:Paint({ title = q:Title(qid), sub = table.concat(sub, " · "), objs = objs, goal = gtext,
        canNext = goal and not goal.turnIn and (goal.count or 0) > 1 })
    card:Show()
end

WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3.5, function() UI:RefreshQuestTracker() end) end)
