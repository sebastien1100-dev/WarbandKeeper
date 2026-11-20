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
    f.next = UI:Button(f, T("Camp suivant"), nil, 22, "secondary")
    f.next:SetScript("OnClick", function()
        if f.guide then local LG = WK.modules.LevelGuide; local s = LG:Steps()[1]; if s then LG:Skip(s.key) end
        elseif f.tour then WK.modules.QuestPlan:Skip() else Q():NextCamp() end
    end)
    f.next.tooltip = "Vise un autre camp d'un objectif pas fini (du plus proche au plus loin)."
    f.turn = UI:Button(f, T("Rendu"), nil, 22, "secondary")
    f.turn:SetScript("OnClick", function()
        if f.guide then WK.modules.LevelGuide:Run(1)
        elseif f.tour then local P = WK.modules.QuestPlan; P:Pause(not (P:Tour() or {}).paused) else Q():GoTurnIn() end
    end)
    f.turn.tooltip = "Guide vers le personnage qui reprend la quête."
    f.goal = UI:Text(f, 10, C.muted); f.goal:SetJustifyH("LEFT")

    -- data = { title, sub, objs = { { name, have, need, done } }, goal } (aperçu ou quête suivie)
    function f:Paint(data)
        self.title:SetText(data.title or "")
        self.sub:SetText(data.sub or "")
        local y = -44
        self.tour = data.tour
        self.guide = data.guide
        self.prog:SetShown(data.prog ~= nil)
        if data.prog then self.prog:SetValue(data.prog); y = -52 end
        self.next:SetLabel(data.b1 or T("Camp suivant")); self.next:SetWidth(self.next.label:GetStringWidth() + 26)
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
            if on then
                f:Paint({ title = T("La chasse aux loups"), sub = T("Sombrivage · niveau 14"), goal = T("Camp à 140 m"),
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
        local nxt = tour.steps[tour.idx + 1]
        local objs = P:StepObjectives(s)
        local mins = math.max(1, math.floor(P:Remaining() / 60 + 0.5))
        card:Paint({ tour = true, title = string.format(T("Étape %d / %d"), tour.idx, #tour.steps),
            sub = P:StepTitle(s) .. " · " .. string.format(T("env. %d min restantes"), mins),
            prog = (tour.idx - 1) / #tour.steps, objs = objs,
            goal = (tour.paused and T("En pause")) or (nxt and (T("Ensuite : ") .. P:StepTitle(nxt))) or T("Dernière étape"),
            b1 = T("Passer l'étape"), b2 = tour.paused and T("Reprendre") or T("Pause"), canNext = true })
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
        card:Paint({ guide = true, title = string.format(T("Montée · niveau %d"), lvl),
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
            gtext = d and string.format(T("%s · camp à %d m"), goal.name, math.floor(d + 0.5))
                or string.format(T("%s · camp dans une autre zone"), goal.name)
        end
    elseif not complete then
        gtext = T("Pas de camp connu pour ces objectifs.")
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
