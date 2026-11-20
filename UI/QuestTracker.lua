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

    -- Vue « tournée » : liste fine au texte ombré dans un cadre léger (fond transparent, sans bordure) ;
    -- en-tête (zone, avancée, temps, XP) et barre fine, étape en cours (genre, titre, niveau, PNJ, distance et
    -- direction, XP), objectifs, 2 étapes suivantes avec leur distance ; boutons visibles seulement au survol
    local tv = CreateFrame("Frame", nil, f)
    tv:SetAllPoints()
    tv:Hide()
    f.tv = tv
    local function shade(fs) if fs.SetShadowOffset then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1) end return fs end
    tv.head = shade(UI:Text(tv, 9, C.muted)); tv.head:SetPoint("TOPLEFT", 12, -9)
    tv.headR = shade(UI:Text(tv, 9, C.muted)); tv.headR:SetPoint("TOPRIGHT", -12, -9); tv.headR:SetJustifyH("RIGHT")
    tv.barBg = tv:CreateTexture(nil, "ARTWORK"); tv.barBg:SetHeight(3)
    tv.barBg:SetPoint("TOPLEFT", 12, -24); tv.barBg:SetPoint("TOPRIGHT", -12, -24)
    tv.barBg:SetColorTexture(1, 1, 1, 0.12)
    tv.bar = tv:CreateTexture(nil, "OVERLAY"); tv.bar:SetHeight(3); tv.bar:SetPoint("TOPLEFT", tv.barBg, "TOPLEFT")
    tv.dot = tv:CreateTexture(nil, "ARTWORK"); tv.dot:SetSize(16, 16); tv.dot:SetTexture(UI.MEDIA .. "circle")
    tv.dot:SetPoint("TOPLEFT", 12, -34)
    tv.mark = tv:CreateFontString(nil, "OVERLAY")
    if not (UI.FONT and tv.mark:SetFont(UI.FONT, 11, "")) then tv.mark:SetFont("Fonts\\FRIZQT__.TTF", 11, "") end
    tv.mark:SetPoint("CENTER", tv.dot, "CENTER", 0, 0); tv.mark:SetTextColor(unpack(C.bg))
    tv.markIcon = UI:Icon(tv, "crosshair", 10, nil, "OVERLAY"); tv.markIcon:SetPoint("CENTER", tv.dot, "CENTER")
    tv.markIcon:SetVertexColor(unpack(C.bg))
    tv.title = shade(UI:Text(tv, 13, C.text)); tv.title:SetPoint("TOPLEFT", 34, -34); tv.title:SetPoint("RIGHT", -10, 0)
    tv.title:SetJustifyH("LEFT"); if tv.title.SetWordWrap then tv.title:SetWordWrap(false) end
    tv.sub = shade(UI:Text(tv, 11, C.muted)); tv.sub:SetPoint("TOPLEFT", 34, -52); tv.sub:SetPoint("RIGHT", -10, 0)
    tv.sub:SetJustifyH("LEFT"); if tv.sub.SetWordWrap then tv.sub:SetWordWrap(false) end
    tv.objs = {}
    for i = 1, ROWS do
        local r = shade(UI:Text(tv, 11, C.text)); r:SetJustifyH("LEFT"); if r.SetWordWrap then r:SetWordWrap(false) end
        tv.objs[i] = r
    end
    tv.nexts = {}
    for i = 1, 2 do
        local r = CreateFrame("Frame", nil, tv); r:SetHeight(16)
        r.dot = r:CreateTexture(nil, "ARTWORK"); r.dot:SetSize(14, 14); r.dot:SetPoint("LEFT", 0, 0); r.dot:SetTexture(UI.MEDIA .. "circle")
        r.num = UI:Text(r, 8, C.bg); r.num:SetPoint("CENTER", r.dot, "CENTER", 0, 0)
        r.txt = shade(UI:Text(r, 11, C.muted)); r.txt:SetPoint("LEFT", 22, 0); r.txt:SetPoint("RIGHT", 0, 0); r.txt:SetJustifyH("LEFT")
        if r.txt.SetWordWrap then r.txt:SetWordWrap(false) end
        tv.nexts[i] = r
    end
    -- boutons (pause / reprendre, passer, arrêter) : petits, à la place des chiffres de l'en-tête au survol
    tv.close = UI:IconButton(tv, "close", 16, "Arrêter la tournée")
    tv.close:SetPoint("TOPRIGHT", -8, -4)
    tv.close:SetScript("OnClick", function() WK.modules.QuestPlan:Stop() end)
    tv.skip = UI:IconButton(tv, "chevron", 16, "Passer l'étape")
    if tv.skip.icon.SetRotation then tv.skip.icon:SetRotation(math.pi / 2) end -- chevron vers la droite
    tv.skip:SetPoint("RIGHT", tv.close, "LEFT", -4, 0)
    tv.skip:SetScript("OnClick", function() WK.modules.QuestPlan:Skip() end)
    tv.pp = UI:IconButton(tv, "pause", 16, "Pause")
    tv.pp:SetPoint("RIGHT", tv.skip, "LEFT", -4, 0)
    -- roue : réglages de la carte (opacité du fond…) dans la roue de la page Quêtes
    tv.gear = UI:IconButton(tv, "gear", 16, "Réglages de la carte (opacité du fond…)")
    tv.gear:SetPoint("RIGHT", tv.pp, "LEFT", -4, 0)
    tv.gear:SetScript("OnClick", function()
        if UI.ToggleWindow and not (UI.frame and UI.frame:IsShown()) then UI:ToggleWindow() end
        UI:ShowPage("quests")
        local def = UI.pages and UI.pages.quests
        if def and def.side then def.settingsOpen = true; def:Layout(); def:Refresh() end
    end)
    tv.pp:SetScript("OnClick", function() local P = WK.modules.QuestPlan; P:Pause(not (P:Tour() or {}).paused) end)
    local function hoverButtons(on)
        for _, b in ipairs({ tv.close, tv.skip, tv.pp, tv.gear }) do b:SetShown(on) end
        tv.headR:SetShown(not on)
    end
    hoverButtons(false)
    tv:SetScript("OnUpdate", function(v, el)
        v.h = (v.h or 0) + el
        if v.h < 0.1 then return end
        v.h = 0
        local over = f:IsMouseOver() and true or false
        if over ~= v.over then v.over = over; hoverButtons(over) end
    end)

    local KIND = { pick = { "gold", "!" }, ["do"] = { nil, nil }, turn = { "positive", "?" }, trainer = { "info", nil } }
    local function kindColor(k)
        local e = KIND[k]
        if e and e[1] then return C[e[1]] end
        return { UI:Accent() }
    end
    local CLASSIC = { "title", "sub", "close", "prog", "next", "turn", "goal" }
    local function bgAlpha(a, border)
        if f.bg then f.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], a) end
        if f.border then f.border:SetShown(border) end
    end
    -- d = { kind, title, lvl, sub, paused, objs, idx, count, mins, xp, zone, nexts = { { n, kind, title, dist } } }
    function f:PaintTour(d)
        for _, k in ipairs(CLASSIC) do self[k]:Hide() end
        for _, r in ipairs(self.rows) do r:Hide() end
        local v = self.tv
        v:Show()
        self.tour, self.guide = true, nil
        local W2 = 300
        self:SetWidth(W2)
        bgAlpha((Q():Config().tourBg or 50) / 100, false)
        v.head:SetText(UI:Upper(T("Tournée")) .. (d.zone and (" · " .. UI:Upper(d.zone)) or "")
            .. (d.paused and ("  " .. UI:Hex(C.warning) .. T("EN PAUSE") .. "|r") or ""))
        v.headR:SetText(string.format("%d/%d · %s", d.idx, d.count, string.format(T("env. %d min"), d.mins))
            .. ((d.xp or 0) > 0 and (" · " .. UI:Hex(C.gold) .. "+" .. d.xp .. " XP|r") or ""))
        local r, g, b = UI:Accent()
        v.bar:SetColorTexture(r, g, b, 1)
        v.bar:SetWidth(math.max(1, (W2 - 24) * math.max(0, d.idx - 1) / math.max(1, d.count)))
        local col = kindColor(d.kind)
        v.dot:SetVertexColor(col[1], col[2], col[3], d.paused and 0.45 or 1)
        local letter = KIND[d.kind] and KIND[d.kind][2]
        v.mark:SetText(letter or ""); v.mark:SetShown(letter ~= nil)
        v.markIcon:SetShown(letter == nil)
        v.title:SetText((d.title or "") .. (d.lvl and ("  " .. UI:Hex(C.dim) .. "[" .. d.lvl .. "]|r") or ""))
        v.title:SetTextColor(unpack(d.paused and C.muted or C.text))
        -- titre sur deux lignes au besoin (il était coupé), puis la ligne d'infos dessous
        if v.title.SetWordWrap then v.title:SetWordWrap(true) end
        if v.title.SetMaxLines then v.title:SetMaxLines(2) end
        v.title:SetWidth(W2 - 34 - 10)
        local th = math.max(16, math.min(34, v.title:GetStringHeight() or 16))
        v.sub:ClearAllPoints(); v.sub:SetPoint("TOPLEFT", 34, -34 - th - 2); v.sub:SetPoint("RIGHT", -10, 0)
        v.sub:SetText(d.sub or "")
        v.pp.icon:SetTexture(UI.MEDIA .. (d.paused and "play" or "pause"))
        v.pp.tooltip = d.paused and "Reprendre" or "Pause"
        local y = -34 - th - 2 - ((d.sub and d.sub ~= "") and 18 or 0)
        -- objectifs
        for i, fs in ipairs(v.objs) do
            local o = d.objs[i]
            if o then
                fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", 34, y); fs:SetPoint("RIGHT", -10, 0)
                if fs.SetWordWrap then fs:SetWordWrap(true) end
                local need = o.need or 0
                local cnt = need > 0 and string.format("  %d/%d", o.have or 0, need) or ""
                -- texte du jeu « Murloc : 0/12 personnages tués » : le nom seul, le compte à part
                local name = tostring(o.name or ""):gsub("%s*:%s*%d+%s*/%s*%d+.*$", "")
                if o.done then fs:SetText(UI:Hex(C.positive) .. name .. cnt .. "|r")
                else fs:SetText(name .. UI:Hex(C.muted) .. cnt .. "|r") end
                fs:Show()
                y = y - math.max(15, (fs:GetStringHeight() or 13) + 2)
            else
                fs:Hide()
            end
        end
        if #d.objs > 0 then y = y - 4 end
        -- 2 étapes suivantes
        for i, row in ipairs(v.nexts) do
            local nx = d.nexts[i]
            if nx then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 12, y - 2); row:SetPoint("RIGHT", -10, 0)
                local c = kindColor(nx.kind)
                row.dot:SetVertexColor(c[1], c[2], c[3], 1)
                row.num:SetText(tostring(nx.n))
                row.txt:SetText(nx.title .. (nx.dist and ("  " .. UI:Hex(C.dim) .. "· " .. string.format(T("%d m"), math.floor(nx.dist + 0.5)) .. "|r") or ""))
                row:Show()
                y = y - 18
            else
                row:Hide()
            end
        end
        self:SetHeight(-y + 8)
    end

    function f:Paint(data)
        if self.tv then
            self.tv:Hide()
            bgAlpha(0.92, true)
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
                f:PaintTour({ kind = "turn", title = T("Rendre : Le viaduc de Thandol"), lvl = 31, sub = "160 m nord-est · +2500 XP",
                    objs = {}, idx = 4, count = 7, mins = 18, xp = 7400, zone = T("Les Paluns"),
                    nexts = { { n = 5, kind = "do", title = T("Coin du loch : 3 quêtes"), dist = 420 }, { n = 6, kind = "pick", title = T("Prendre : Thelsamar"), dist = 900 } } })
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
        local Qs = WK.modules.Quests
        -- niveau, XP et PNJ de l'étape (première quête ; XP de toutes)
        local lvl, xp, npc
        for i, qid in ipairs(s.qids or {}) do
            local qq = Qs and Qs:Get(qid)
            if qq then
                xp = (xp or 0) + (qq.xp or 0)
                if i == 1 then
                    lvl = qq.lvl
                    local n = s.kind == "pick" and qq.sid and WK.EverNpcs and WK.EverNpcs[qq.sid]
                    if n then npc = (WK.Lang and WK.Lang() == "frFR" and n[2]) or n[1] end
                end
            end
        end
        local sub = {}
        if npc then table.insert(sub, npc) end
        if #(s.qids or {}) > 1 then table.insert(sub, string.format(T("%d quêtes"), #s.qids)) end
        if dist and not tour.paused then
            local dir = P.Direction and me and me.map == s.map and P:Direction(me, { map = s.map, x = s.x, y = s.y })
            table.insert(sub, UI:Hex({ UI:Accent() }) .. string.format(T("%d m"), math.floor(dist + 0.5))
                .. ((dir and dir ~= "") and (" " .. dir) or "") .. "|r")
        end
        if (xp or 0) > 0 and s.kind ~= "pick" then table.insert(sub, UI:Hex(C.gold) .. "+" .. xp .. " XP|r") end
        -- XP qui reste à gagner dans la tournée (rendus à venir)
        local left = 0
        for i = tour.idx, #tour.steps do
            local st = tour.steps[i]
            if st.kind == "turn" then
                for _, qid in ipairs(st.qids or {}) do local qq = Qs and Qs:Get(qid); left = left + (qq and qq.xp or 0) end
            end
        end
        local nexts = {}
        for i = 1, 2 do
            local ns = tour.steps[tour.idx + i]
            if ns then
                local nd
                if me and ns.map then
                    local t = { map = ns.map, x = ns.x, y = ns.y }
                    t.cont, t.wx, t.wy = G.ToWorld(ns.map, ns.x, ns.y)
                    nd = G:Vector(me, t)
                end
                table.insert(nexts, { n = tour.idx + i, kind = ns.kind, title = P:StepTitle(ns), dist = nd })
            end
        end
        card:PaintTour({ kind = s.kind, title = P:StepTitle(s), lvl = lvl, sub = table.concat(sub, " · "), paused = tour.paused,
            objs = objs, idx = tour.idx, count = #tour.steps, mins = mins, xp = left, zone = zone and zone.name, nexts = nexts })
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
