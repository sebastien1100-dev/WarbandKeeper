local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local CreateFrame, GameTooltip, GetCursorPosition = CreateFrame, GameTooltip, GetCursorPosition

---------------------------------------------------------------------------
-- Quêtes du donjon : fenêtre volante discrète (HUD « dungeonQuests »), groupée par état :
--   DANS TON JOURNAL (objectifs, prête à rendre), À PRENDRE (zone et distance du donneur),
--   APRÈS PRÉREQUIS (le prérequis à faire d'abord), FAITES · n (repliées, clic pour déplier).
-- Niveau de chaque quête à la couleur du jeu (gris, vert, jaune, orange, rouge). Clic sur une quête à
-- la fenêtre (gauche ou droit) : son lien dans le chat ; « Prendre (n) » = Dungeons:PickQuests.
-- Donjon montré : celui où l'on est, sinon celui dont l'entrée est à moins de 400 m (affichage
-- « Près du donjon ») ; « Toujours » garde le dernier donjon vu ou choisi (page Donjons, LFG).
-- Réglages : Dungeons:Config() questWin (auto / always / off), questWinObjs (opacité : UI:HudAlpha, commune),
-- questWinDone, questWinCombat, questWinAuto (cachée quand il ne reste rien) ; roue de la page Donjons.
---------------------------------------------------------------------------
local W = 280
local MAX_H = 440 -- hauteur maximale de la fenêtre (au-delà : molette)
local win
local closedFor -- donjon fermé par la croix (jusqu'au donjon suivant)
local doneOpen = false

local function D() return WK.modules.Dungeons end
-- pastille « NOUVELLE / APPRISE / CORRIGÉE » (Modules/DataLog.lua)
local function badge(id) local DL = WK.modules.DataLog; return DL and DL:Badge(id, true) or "" end
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

-- donjon à montrer : seulement celui où l'on est (avant aussi près de l'entrée, en « Toujours » ou choisi depuis
-- la page Donjons : la fenêtre restait à l'écran dehors, avec les quêtes d'une autre zone)
local function target()
    local Dg = D()
    return Dg and Dg:Current() or nil
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDungeonQuests", UIParent)
    f:SetSize(W, 120)
    f:SetFrameStrata("MEDIUM")
    UI:HudBackground(f, "hud")
    -- en-tête : nom du donjon en entier (deux lignes au besoin), puis « QUÊTES · env. N XP » ; glisser le titre
    -- déplace la fenêtre (sans passer par le mode édition)
    f.title = UI:Text(f, 12, C.text); f.title:SetPoint("TOPLEFT", 11, -9); f.title:SetPoint("TOPRIGHT", -28, -9)
    f.title:SetJustifyH("LEFT")
    if f.title.SetWordWrap then f.title:SetWordWrap(true) end
    if f.title.SetMaxLines then f.title:SetMaxLines(2) end
    f.head = UI:Text(f, 10, C.muted)
    f.head:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2); f.head:SetPoint("TOPRIGHT", f.title, "BOTTOMRIGHT", 0, -2)
    f.head:SetJustifyH("LEFT"); f.head:Hide()
    -- pastilles de compte de l'en-tête (maquette B) : « N en cours », « N à prendre »
    f.pills = {}
    for i = 1, 2 do
        local p = CreateFrame("Frame", nil, f); p:SetHeight(15)
        p.bg = UI:Rounded(p, 7, 0, "BACKGROUND", 1)
        p.t = UI:Text(p, 9); p.t:SetPoint("CENTER", 0, 0)
        f.pills[i] = p
    end
    f:SetMovable(true); f:SetClampedToScreen(true)
    f.drag = CreateFrame("Button", nil, f)
    f.drag:SetPoint("TOPLEFT", 0, 0); f.drag:SetPoint("TOPRIGHT", -26, 0); f.drag:SetHeight(30)
    f.drag:RegisterForDrag("LeftButton")
    f.drag:SetScript("OnDragStart", function() f:StartMoving() end)
    f.drag:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        if UI.HUDCapture then UI:HUDCapture("dungeonQuests") end
    end)
    f.drag:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Glisser pour déplacer"), 1, 1, 1)
        if f.xpText then GameTooltip:AddLine(f.xpText, 0.8, 0.8, 0.8, true) end
        GameTooltip:AddLine(T("Molette : faire défiler"), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    f.drag:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- molette : défiler quand tout ne tient pas
    f.off = 0
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(s, delta)
        if not s.lastData then return end
        local n = s.items or 0
        -- vers le bas seulement s'il reste des lignes cachées : la dernière quête reste en bas de la fenêtre
        if delta < 0 and (s.hidden or 0) == 0 then return end
        s.off = math.max(0, math.min(math.max(0, n - 1), (s.off or 0) - delta))
        s:Paint(s.lastData, s.lastCfg)
    end)
    f.close = UI:IconButton(f, "close", 16, "Cacher jusqu'au prochain donjon")
    f.close:SetPoint("TOPRIGHT", -6, -6)
    f.close:SetScript("OnClick", function()
        closedFor = f.key
        f:Hide()
        UI:RefreshDungeonQuests()
    end)
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
            -- maquette B : niveau (couleur de difficulté) · nom · avancée à droite, fine barre dessous
            r.hl = r:CreateTexture(nil, "BACKGROUND"); r.hl:SetAllPoints()
            r.lvl = UI:Text(r, 10); r.lvl:SetPoint("TOPLEFT", 8, -5); r.lvl:SetWidth(18); r.lvl:SetJustifyH("RIGHT")
            r.right = UI:Text(r, 10, C.muted); r.right:SetPoint("TOPRIGHT", -11, -5); r.right:SetJustifyH("RIGHT")
            r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 31, -4); r.name:SetPoint("RIGHT", r.right, "LEFT", -6, 0)
            r.name:SetJustifyH("LEFT")
            r.track = r:CreateTexture(nil, "ARTWORK"); r.track:SetHeight(3)
            r.track:SetPoint("TOPLEFT", 31, -20); r.track:SetPoint("TOPRIGHT", -11, -20)
            r.fill = r:CreateTexture(nil, "OVERLAY"); r.fill:SetHeight(3)
            r.fill:SetPoint("TOPLEFT", r.track, "TOPLEFT", 0, 0)
            r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            -- clic (gauche ou droit) : lien de la quête dans le chat (à la demande du joueur : plus de guidage
            -- ni de menu ici)
            r:SetScript("OnClick", function(s)
                if s.qid then WK.ChatInsert((UI:QuestLink(s.qid))) elseif s.onClick then s.onClick() end
            end)
            r:SetScript("OnEnter", function(s)
                if not s.tip then return end
                UI:TooltipOwner(s, "ANCHOR_LEFT")
                GameTooltip:SetText(s.tip[1], 1, 1, 1)
                for k = 2, 6 do if s.tip[k] then GameTooltip:AddLine(s.tip[k], 0.8, 0.8, 0.8, true) end end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            f.rows[i] = r
        end
        return r
    end
    -- remplit la fenêtre ; data = { name, xp, log = {…}, avail = {…}, waiting = {…}, done = n, doneList, pick, preN }
    function f:Paint(data, cfg)
        local ar, ag, ab = UI:Accent()
        UI:HudPaint(self)
        self.lastData, self.lastCfg = data, cfg
        if self.dungeonKey ~= data.name then self.dungeonKey = data.name; self.off = 0 end
        self.title:SetText(data.name or "")
        self.xpText = (data.xp or 0) > 0 and string.format(T("env. %d XP"), data.xp) or nil
        -- pastilles : quêtes du journal, quêtes à prendre (cachées à zéro), alignées à droite du titre
        local pdef = { { #data.log, T("%d en cours"), { ar, ag, ab } }, { #data.avail, T("%d à prendre"), C.gold } }
        -- à droite du titre s'il tient sur une ligne à côté, sinon sur une ligne sous le titre (avant : le titre
        -- gardait deux ancres à droite et passait sous les pastilles)
        local widths, pillsW = {}, 0
        for i = 1, 2 do
            local p, d = self.pills[i], pdef[i]
            if d[1] > 0 then
                p.t:SetText(string.format(d[2], d[1])); p.t:SetTextColor(d[3][1], d[3][2], d[3][3])
                p.bg:SetColor(d[3][1], d[3][2], d[3][3], 0.18)
                widths[i] = math.floor((p.t:GetStringWidth() or 40) + 12)
                p:SetWidth(widths[i])
                pillsW = pillsW + widths[i] + 4
                p:Show()
            else
                p:Hide()
            end
        end
        self.title:ClearAllPoints(); self.title:SetPoint("TOPLEFT", 11, -9); self.title:SetPoint("TOPRIGHT", -28, -9)
        local avail = (self:GetWidth() or W) - 11 - 28
        local below = pillsW > 0 and (self.title:GetStringWidth() or 0) + pillsW + 6 > avail
        if pillsW > 0 and not below then self.title:SetPoint("TOPRIGHT", -28 - pillsW - 2, -9) end
        local th = math.max(14, math.min(30, self.title:GetStringHeight() or 14))
        local px, py = -28, -8
        if below then px, py = 11, -(9 + th + 4) end
        for i = 2, 1, -1 do
            local p = self.pills[below and (3 - i) or i]
            local w = widths[below and (3 - i) or i]
            if w then
                p:ClearAllPoints()
                if below then p:SetPoint("TOPLEFT", px, py); px = px + w + 4
                else p:SetPoint("TOPRIGHT", px, py); px = px - w - 4 end
            end
        end
        local top = 9 + th + 8
        if below then top = top + 15 + 4 end
        self.drag:SetHeight(top)
        local compact = cfg.questWinCompact
        -- hauteur bornée (plus de poignée) : au-delà, la molette fait défiler
        local maxH = MAX_H
        local footH = 0
        -- éléments (titres de section et lignes) ; défilement : les « off » premiers sont sautés
        local items = {}
        local function section(label, n, onClick)
            items[#items + 1] = { sec = true, label = label, n = n, onClick = onClick }
        end
        local function line(e) items[#items + 1] = { e = e } end
        -- journal sans titre de section (les pastilles comptent), puis les quêtes à prendre derrière un trait
        for _, e in ipairs(data.log) do line(e) end
        if #data.avail > 0 then
            if #data.log > 0 then items[#items + 1] = { sep = true } end
            for _, e in ipairs(data.avail) do line(e) end
        end
        if #data.waiting > 0 then
            section("Après prérequis", #data.waiting)
            for _, e in ipairs(data.waiting) do line(e) end
        end
        if cfg.questWinDone ~= false and (data.done or 0) > 0 then
            section(string.format(T("Faites · %d  %s"), data.done, doneOpen and "-" or "+"), nil,
                function() doneOpen = not doneOpen; UI:RefreshDungeonQuests() end)
            if doneOpen then for _, e in ipairs(data.doneList or {}) do line(e) end end
        end
        if #data.log + #data.avail + #data.waiting == 0 and (data.done or 0) == 0 then
            section("Aucune quête connue pour ce donjon.")
        end
        self.items = #items
        self.off = math.max(0, math.min(self.off or 0, math.max(0, #items - 1)))
        local y, ns, nr = top, 0, 0
        local function drawSection(label, n, onClick)
            ns = ns + 1
            local s = sec(ns)
            s:ClearAllPoints(); s:SetPoint("TOPLEFT", 0, -y); s:SetPoint("TOPRIGHT", 0, -y)
            s.l:SetText(UI:Upper(T(label))); s.r:SetText(n and tostring(n) or "")
            s:SetScript("OnClick", onClick)
            s:Show()
            y = y + 18
        end
        local function drawLine(e)
            nr = nr + 1
            local r = row(nr)
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            r.name:SetText(e.name or "?")
            local nc = e.nameColor or (e.dim and C.muted) or C.text
            r.name:SetTextColor(nc[1], nc[2], nc[3])
            r.lvl:SetText(e.lvl and e.lvl > 0 and tostring(e.lvl) or "")
            local lc = e.dim and C.dim or levelColor(e.lvl); r.lvl:SetTextColor(lc[1], lc[2], lc[3])
            r.right:SetText(e.right or "")
            local rc = e.rightColor or C.muted; r.right:SetTextColor(rc[1], rc[2], rc[3])
            -- barre d'avancée : quêtes du journal (sauf en mode compact)
            local bar = e.frac ~= nil and not compact
            r.track:SetShown(bar); r.fill:SetShown(bar and e.frac > 0)
            if bar then
                local bc = e.barColor or { ar, ag, ab }
                r.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.9)
                r.fill:SetColorTexture(bc[1], bc[2], bc[3], 1)
                r.fill:SetWidth(math.max(1, math.floor((W - 42) * math.min(1, e.frac))))
            end
            r.hl:SetColorTexture(ar, ag, ab, 0)
            r.onClick, r.qid = e.onClick, e.qid
            r.tip = e.tip
            local h = bar and 27 or 21
            r:SetHeight(h)
            r:Show()
            y = y + h
        end
        local seps = self.seps or {}
        self.seps = seps
        local nsep = 0
        local function drawSep()
            nsep = nsep + 1
            local t = seps[nsep]
            if not t then t = self:CreateTexture(nil, "ARTWORK"); t:SetHeight(1); seps[nsep] = t end
            t:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.9)
            t:ClearAllPoints(); t:SetPoint("TOPLEFT", 11, -(y + 3)); t:SetPoint("TOPRIGHT", -11, -(y + 3))
            t:Show()
            y = y + 7
        end
        -- rendu jusqu'à la hauteur maximale (poignée), le reste au-delà via la molette
        local limit = maxH - footH - 22
        local hidden = 0
        for i = self.off + 1, #items do
            local it = items[i]
            local y0 = y
            if it.sep then drawSep() elseif it.sec then drawSection(it.label, it.n, it.onClick) else drawLine(it.e) end
            if y > limit then
                -- ne tient plus : retiré, la suite passe à la molette
                if it.sep then seps[nsep]:Hide(); nsep = nsep - 1
                elseif it.sec then self.secs[ns]:Hide(); ns = ns - 1 else self.rows[nr]:Hide(); nr = nr - 1 end
                y = y0
                hidden = #items - i + 1
                break
            end
        end
        self.hidden = hidden
        local scrolling = self.off > 0 or hidden > 0
        if scrolling then
            -- hauteur fixe pendant le défilement : la ligne « plus haut / plus bas » toujours tout en bas
            y = maxH - 4 - 2 - 18
            drawSection("", nil, nil)
            self.secs[ns].l:SetText((self.off > 0 and string.format(T("%d plus haut"), self.off) or "")
                .. ((self.off > 0 and hidden > 0) and "  ·  " or "") .. (hidden > 0 and string.format(T("%d plus bas"), hidden) or ""))
            self.secs[ns].r:SetText(T("molette"))
        end
        for i = ns + 1, #self.secs do self.secs[i]:Hide() end
        for i = nr + 1, #self.rows do self.rows[i]:Hide() end
        for i = nsep + 1, #seps do seps[i]:Hide() end
        y = y + 4
        self:SetHeight(scrolling and maxH or math.min(maxH, y + 2))
    end
    f:Hide()
    -- distance et entrée surveillées toutes les 2 s (rien à faire tant que la fenêtre est coupée)
    local acc = 0
    local ticker = CreateFrame("Frame")
    ticker:SetScript("OnUpdate", function(_, el)
        acc = acc + el
        if acc < 2 then return end
        acc = 0
        if not f.sample then UI:RefreshDungeonQuests(true) end
    end)
    UI:RegisterHUD("dungeonQuests", f, {
        label = T("Quêtes du donjon"), default = { -330, 120 },
        enabled = function() local Dg = D(); return Dg and Dg:Config().questWin ~= "off" and WK:FeatureOn("dungeons") end,
        sample = function(on)
            f.sample = on or nil
            if on then
                local G, P, Ok = C.gold, C.warning, C.positive
                f:Paint({ name = T("Les Mortemines"), xp = 2600,
                    log = { { name = T("Les rouges de la Confrérie"), lvl = 20, right = "7/10", frac = 0.7 },
                            { name = T("La fin de Van Cleef"), lvl = 22, right = T("prête à rendre"), rightColor = Ok, frac = 1, barColor = Ok } },
                    avail = { { name = T("Le collier d'Old Murk"), lvl = 18, nameColor = G, right = "1,2 km" } },
                    waiting = { { name = T("Le dernier Défias"), lvl = 22, nameColor = P, right = T("prérequis"), rightColor = P } },
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
-- avancée d'une quête du journal : part faite (0-1) et texte court (« 7/10 », « 2/3 objectifs »), nil sans chiffres
local function progressOf(qid)
    local QT = WK.modules.QuestTrack
    local objs = QT and QT:Objectives(qid, true) or {}
    local have, need, done = 0, 0, 0
    for _, o in ipairs(objs) do
        local n = o.need or 0
        if n > 0 then have = have + math.min(o.have or 0, n); need = need + n end
        if o.done then done = done + 1 end
    end
    if need > 0 then
        if #objs == 1 then return have / need, string.format("%d/%d", have, need) end
        return have / need, string.format("%d/%d", have, need)
    end
    if #objs > 0 then return done / #objs, string.format("%d/%d", done, #objs) end
    return nil
end

local function objectivesText(qid)
    local QT = WK.modules.QuestTrack
    local parts = {}
    for _, o in ipairs(QT and QT:Objectives(qid, true) or {}) do -- texte seul : ne charge pas la base des camps
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
    local out = { name = Dg:Name(d), log = {}, avail = {}, waiting = {}, done = s.done, doneList = {}, pick = Dg:PickCount(s), preN = #s.pre, xp = 0 }
    for _, q in ipairs(s.logList or {}) do
        local ready = QT and QT:IsComplete(q.id)
        local e = { name = UI.GroupTag(q.id) .. Qm:Name(q) .. badge(q.id), lvl = q.lvl, qid = q.id }
        if ready then
            e.right, e.rightColor, e.frac, e.barColor = T("prête à rendre"), C.positive, 1, C.positive
            e.tip = { Qm:Name(q), T("Prête à rendre"), T("Clic : lier dans le chat") }
        else
            local frac, txt = progressOf(q.id)
            e.right = txt or T("en cours")
            e.frac = cfg.questWinObjs ~= false and (frac or 0) or nil
            local obj = objectivesText(q.id)
            e.tip = { Qm:Name(q), obj ~= "" and obj or nil, T("Clic : lier dans le chat") }
        end
        table.insert(out.log, e)
        out.xp = out.xp + (q.xp or 0)
    end
    for _, q in ipairs(s.avail) do
        local zone = R and R.ZoneName and R:ZoneName(q.smap or q.map) or ""
        local dt = distText(distOf(q))
        table.insert(out.avail, { qid = q.id, name = UI.GroupTag(q.id) .. Qm:Name(q) .. badge(q.id),
            lvl = q.lvl, nameColor = C.gold, q = q, zone = zone, -- q et zone : distance refaite seule (lightDistances)
            right = dt or T("à prendre"), sub = zone .. (dt and (" · " .. dt) or ""),
            tip = { Qm:Name(q), zone ~= "" and zone or nil, T("À prendre"), T("Clic : lier dans le chat") } })
        out.xp = out.xp + (q.xp or 0)
    end
    for _, q in ipairs(s.waiting) do
        local pre
        for _, e in ipairs(s.pre) do if e.unlock == q then pre = e.q break end end
        local sub = pre and string.format(T("après : %s"), Qm:Name(pre)) or T("après une autre quête (en cours)")
        table.insert(out.waiting, { qid = q.id, name = UI.GroupTag(q.id) .. Qm:Name(q) .. badge(q.id),
            lvl = q.lvl, nameColor = C.warning, right = T("prérequis"), rightColor = C.warning, sub = sub,
            tip = { Qm:Name(q), sub, T("Clic : lier dans le chat") } })
        out.xp = out.xp + (q.xp or 0)
    end
    for _, q in ipairs(s.doneList or {}) do
        table.insert(out.doneList, { qid = q.id, name = Qm:Name(q), lvl = q.lvl, dim = true, right = T("faite"), rightColor = C.dim })
    end
    return out
end

-- Distances seules, sur les données déjà faites : vrai si un texte a changé
local function lightDistances(data)
    local changed = false
    for _, e in ipairs(data.avail or {}) do
        if e.q then
            local dt = distText(distOf(e.q))
            local sub = (e.zone or "") .. (dt and (" · " .. dt) or "")
            if sub ~= e.sub then e.sub = sub; e.right = dt or T("à prendre"); changed = true end
        end
    end
    return changed
end

-- light (minuterie des 2 s) : les données ne sont refaites qu'après un évènement (refreshSoon, autres appels)
-- ou toutes les 30 s hors combat ; sinon seules les distances. Avant, tout (journal, résumé des quêtes du
-- donjon) était refait toutes les 2 s, même en combat.
function UI:RefreshDungeonQuests(light)
    local Dg = D()
    if not Dg then return end
    win = win or build()
    if win.sample then return end
    local cfg = Dg:Config()
    if cfg.questWin == "off" or not WK:FeatureOn("dungeons") then win:Hide() return end
    if cfg.questWinCombat and InCombatLockdown and InCombatLockdown() then win:Hide() return end
    local d = target()
    if not d then closedFor = nil; win:Hide() return end
    if closedFor and closedFor ~= d.key then closedFor = nil end
    if closedFor == d.key then win:Hide() return end
    local lock, clock = _G.InCombatLockdown, _G.GetTime
    local fight = lock and lock()
    if light and win.dataKey == d.key and win.dataFor and (fight or clock() - (win.dataAt or 0) < 30) then
        if win.autoHidden then return end
        local changed = lightDistances(win.dataFor)
        if changed or not win:IsShown() then win:Paint(win.dataFor, cfg) end
        win:Show()
        return
    end
    local data = UI:DungeonQuestsData(d, cfg)
    win.dataKey, win.dataAt, win.dataFor = d.key, clock(), data
    -- rien à faire ni à prendre : cachée si demandé
    win.autoHidden = nil
    if cfg.questWinAuto and #data.log + #data.avail + #data.waiting == 0 then
        win.autoHidden = true; win:Hide() return
    end
    win.key, win.dungeon = d.key, d
    win:Paint(data, cfg)
    win:Show()
end

WK:On("PLAYER_LOGIN", function() C_Timer.After(3, function() UI:RefreshDungeonQuests() end) end)
-- une seule relecture pour une rafale : après un rendu, QUEST_TURNED_IN puis plusieurs QUEST_LOG_UPDATE arrivent sur
-- environ une seconde ; chaque évènement repousse la relecture de 0,5 s (avant : une relecture à 0,3 s puis une autre
-- pour les évènements suivants, d'où une petite saccade). QUEST_LOG_UPDATE sans changement du journal (même
-- empreinte de QuestTrack.LogSignature) est ignoré.
local due, lastSig
local debounce = CreateFrame("Frame")
debounce:Hide()
debounce:SetScript("OnUpdate", function(s)
    if _G.GetTime() < due then return end
    s:Hide()
    UI:RefreshDungeonQuests()
end)
local function refreshSoon()
    if not win or win.sample or not win:IsShown() and not D():Current() then return end
    due = _G.GetTime() + 0.5
    debounce:Show()
end
WK:On("QUEST_LOG_UPDATE", function()
    -- hors donjon et fenêtre jamais construite : rien à relire (évènement très fréquent en monde ouvert)
    if not win and not (_G.IsInInstance and _G.IsInInstance()) then return end
    local QT = WK.modules.QuestTrack
    local sig = QT and QT.LogSignature and QT.LogSignature()
    if sig and sig == lastSig then return end
    lastSig = sig
    refreshSoon()
end)
for _, ev in ipairs({ "QUEST_TURNED_IN", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED", "PLAYER_LEVEL_UP" }) do
    WK:On(ev, refreshSoon)
end
