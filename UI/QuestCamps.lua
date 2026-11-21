local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local CreateFrame, Minimap = CreateFrame, Minimap

-- Camps des objectifs de quête sur la carte du monde (calque « Quêtes » de UI/MapPins.lua) : zone colorée en
-- pointillés par camp d'un objectif pas fini (accent : monstre ou objet au sol, orange : objet à ramasser),
-- étiquette avec l'avancée, point « ? » doré où rendre une quête prête. Quête suivie seulement, ou toutes
-- celles du journal (QuestTrack:Config().map). Petit volet « Quêtes » en haut à gauche de la carte : clic sur
-- une quête = la suivre, « Toutes » / « Suivie » = ce que la carte dessine.
local function Q() return WK.modules.QuestTrack end
local camps, labels, turns, nums, lines = {}, {}, {}, {}, {}

local function mapPos(p, mapID)
    if p.map == mapID then return p.x, p.y, true end
    -- autre carte (continent…) : passage par la position dans le monde
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local cont, wx, wy = WK.modules.Guide.ToWorld(p.map, p.x, p.y)
    if not cont then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, cont, CreateVector2D(wx, wy), mapID)
    if not ok or not pos then return nil end
    local x, y = pos.x, pos.y
    if pos.GetXY then x, y = pos:GetXY() end
    if not x or x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y, false
end

-- Contour fin en pointillés : segments de ligne (1,5 px) autour du cercle, quelle que soit sa taille (la
-- texture d'anneau grossissait avec le cercle et donnait un bord épais)
local SEGS = 40
local function thinRing(f, size, r, g, b, a)
    if not f.CreateLine then return end
    f.segs = f.segs or {}
    local rad = size / 2
    local n = SEGS
    if rad < 14 then n = 20 end
    for k = 1, SEGS do
        local l = f.segs[k]
        if k <= n and k % 2 == 1 then
            if not l then l = f:CreateLine(nil, "OVERLAY"); f.segs[k] = l end
            local a1, a2 = (k - 1) / n * 2 * math.pi, k / n * 2 * math.pi
            l:SetStartPoint("CENTER", f, math.cos(a1) * rad, math.sin(a1) * rad)
            l:SetEndPoint("CENTER", f, math.cos(a2) * rad, math.sin(a2) * rad)
            l:SetThickness(1.5)
            l:SetColorTexture(r, g, b, a)
            l:Show()
        elseif l then
            l:Hide()
        end
    end
end
local function campFrame(i, cv)
    local f = camps[i]
    if not f then
        f = CreateFrame("Frame", nil, cv)
        f.wk = true
        -- halo doux autour de la zone (plus large que le camp), remplissage, contour sombre puis anneau en pointillés
        f.glow = f:CreateTexture(nil, "BACKGROUND"); f.glow:SetPoint("TOPLEFT", -6, 6); f.glow:SetPoint("BOTTOMRIGHT", 6, -6)
        f.glow:SetTexture(UI.MEDIA .. "fxhalo"); f.glow:SetBlendMode("ADD")
        f.fill = f:CreateTexture(nil, "ARTWORK"); f.fill:SetAllPoints(); f.fill:SetTexture(UI.MEDIA .. "circle")
        f.edge = f:CreateTexture(nil, "OVERLAY", nil, 0); f.edge:SetPoint("TOPLEFT", -1, 1); f.edge:SetPoint("BOTTOMRIGHT", 1, -1)
        f.edge:SetTexture(UI.MEDIA .. "ring"); f.edge:SetVertexColor(0, 0, 0, 0.55)
        f.ring = f:CreateTexture(nil, "OVERLAY", nil, 1); f.ring:SetAllPoints(); f.ring:SetTexture(UI.MEDIA .. "ring_dash")
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(s)
            if not s.info then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.info.title, 1, 1, 1)
            GameTooltip:AddLine(s.info.text, C.text[1], C.text[2], C.text[3], true)
            GameTooltip:AddLine(T("Clic : guider jusqu'à cette zone de quête"), C.muted[1], C.muted[2], C.muted[3])
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
        f:SetScript("OnMouseUp", function(s)
            local c = s.info and s.info.camp
            if not c then return end
            local G = WK.modules.Guide
            local t = { map = c.map, x = c.x, y = c.y, e = { c.x * 100, c.y * 100, 0, nil, nil, s.info.text, s.info.text, s.info.title } }
            t.cont, t.wx, t.wy = G.ToWorld(c.map, c.x, c.y)
            G:Start(t, "Quête suivie", "qtrack")
        end)
        camps[i] = f
    end
    if f:GetParent() ~= cv then f:SetParent(cv) end
    return f
end

local function label(i, cv)
    local l = labels[i]
    if not l then
        l = CreateFrame("Frame", nil, cv)
        l.wk = true
        UI:Panel(l, 5, { C.bg[1], C.bg[2], C.bg[3], 0.82 }, nil)
        l.text = UI:Text(l, 10, C.text); l.text:SetPoint("CENTER")
        labels[i] = l
    end
    if l:GetParent() ~= cv then l:SetParent(cv) end
    return l
end

local function turnPin(i, cv)
    local p = turns[i]
    if not p then
        p = CreateFrame("Frame", nil, cv)
        p.wk = true
        UI:TurnInMarker(p)
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.title or "", 1, 1, 1)
            GameTooltip:AddLine(T("Prête à rendre ici"), C.positive[1], C.positive[2], C.positive[3])
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        turns[i] = p
    end
    if p:GetParent() ~= cv then p:SetParent(cv) end
    return p
end

---------------------------------------------------------------------------
-- Zones de chaleur / points exacts (QuestTrack:Points) : halos doux qui s'additionnent là où les apparitions
-- sont nombreuses, ou petits points ; une couleur par objectif de la quête suivie. Réglages QuestTrack:Config() :
-- zoneStyle (heat / points / circles), miniStyle (heat / points / off), heat (intensité %).
---------------------------------------------------------------------------
local MAX_HEAT = 1200      -- textures au plus sur la carte du monde
local PER_OBJ = 300        -- points au plus par objectif (échantillon régulier au-delà)
local heatHolder, heatTex, heatUsed = nil, {}, 0
local function objColors()
    local a = { UI:Accent() }
    return { a, C.warning, C.plan, C.info, C.mint, C.rule, C.positive }
end
UI.QuestObjColor = function(i)
    local cols = objColors()
    return cols[((i or 1) - 1) % #cols + 1]
end
local function heatReset()
    for i = 1, heatUsed do heatTex[i]:Hide() end
    heatUsed = 0
end
local function heatGet(holder, list, used)
    local t = list[used]
    if not t then
        t = holder:CreateTexture(nil, "ARTWORK")
        list[used] = t
    end
    return t
end
-- dessine les points pts (x1, y1, …) en style heat ou points, dans holder (w, h = taille de la toile)
local function paintPoints(holder, list, used, maxUsed, pts, w, h, col, style, size, alpha)
    local n = #pts / 2
    local step = n > PER_OBJ and n / PER_OBJ or 1
    local k = 1
    while k <= n and used < maxUsed do
        local i = math.floor(k + 0.5)
        local x, y = pts[i * 2 - 1], pts[i * 2]
        if x then
            used = used + 1
            local t = heatGet(holder, list, used)
            if style == "points" then
                t:SetTexture(UI.MEDIA .. "circle"); t:SetBlendMode("BLEND")
                t:SetSize(size, size); t:SetVertexColor(col[1], col[2], col[3], math.min(1, alpha * 3))
            else
                t:SetTexture(UI.MEDIA .. "fxhalo"); t:SetBlendMode("BLEND")
                t:SetSize(size, size); t:SetVertexColor(col[1], col[2], col[3], alpha)
            end
            t:ClearAllPoints(); t:SetPoint("CENTER", holder, "TOPLEFT", x * w, -y * h)
            t:Show()
        end
        k = k + step
    end
    return used
end

local function hideAll()
    heatReset()
    for _, f in ipairs(camps) do f:Hide() end
    for _, f in ipairs(labels) do f:Hide() end
    for _, f in ipairs(turns) do f:Hide() end
    for _, f in ipairs(nums) do f:Hide() end
    for _, l in ipairs(lines) do l:Hide() end
end

-- Tournée de quêtes (Modules/QuestPlan.lua) : étapes numérotées (or : prendre, accent : faire, vert : rendre)
-- reliées par un trait, l'étape en cours plus grande
local function numPin(i, cv)
    local p = nums[i]
    if not p then
        p = CreateFrame("Frame", nil, cv)
        p.wk = true
        p.ring = p:CreateTexture(nil, "ARTWORK"); p.ring:SetAllPoints(); p.ring:SetTexture(UI.MEDIA .. "circle")
        p.dot = p:CreateTexture(nil, "ARTWORK", nil, 1); p.dot:SetPoint("TOPLEFT", 2, -2); p.dot:SetPoint("BOTTOMRIGHT", -2, 2)
        p.dot:SetTexture(UI.MEDIA .. "circle")
        p.n = UI:Text(p, 11, C.bg); p.n:SetPoint("CENTER", 0, 0)
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(s)
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(s.tip or "", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        p:SetScript("OnLeave", function() GameTooltip:Hide() end)
        nums[i] = p
    end
    if p:GetParent() ~= cv then p:SetParent(cv) end
    return p
end
local function line(i, cv)
    -- traits sur le calque des tracés (au-dessus des calques du jeu de la carte de WoW Forever)
    if UI.MapLineLayer then cv = UI.MapLineLayer(cv) end
    local l = lines[i]
    if not l then
        l = cv:CreateLine(nil, "ARTWORK")
        lines[i] = l
    end
    if l:GetParent() ~= cv then l:SetParent(cv) end
    return l
end
local function drawTour(cv, mapID, w, h, lvl)
    local P = WK.modules.QuestPlan
    local t = P and P:Tour()
    if not t then return end
    local r, g, b = UI:Accent()
    local prev, nl = nil, 0
    -- pastilles à la taille des autres repères de la carte (rares, marchands) ; deux étapes au même endroit :
    -- une seule pastille « 2·30 », plus large
    local k = UI.MapIconScale and UI.MapIconScale() or 1
    local placed = {}
    local np = 0
    for i, s in ipairs(t.steps) do
        -- étapes passées, ou dont les quêtes sont déjà rendues : retirées de la carte
        local x, y
        if i >= t.idx and not (i > t.idx and P.StepSpent and P:StepSpent(s)) then x, y = mapPos(s, mapID) end
        if x then
            local cur = i == t.idx
            local px, py = x * w, y * h
            local same
            for _, q in ipairs(placed) do
                if math.abs(q.px - px) < 9 * k and math.abs(q.py - py) < 9 * k then same = q break end
            end
            if same then
                same.nums = same.nums .. "·" .. i
                same.p.n:SetText(same.nums)
                same.p:SetWidth(math.max(same.p:GetHeight(), (same.p.n:GetStringWidth() or 10) + 8))
                same.p.tip = same.p.tip .. "|n" .. i .. ". " .. P:StepTitle(s)
                if cur then same.p:SetHeight(17 * k) end
            else
            np = np + 1
            local p = numPin(np, cv)
            local sz = (cur and 17 or 14) * k
            p:SetSize(sz, sz)
            local col = (s.kind == "pick" and C.gold) or (s.kind == "turn" and C.positive) or ((s.kind == "trainer" or s.kind == "buy") and C.info) or { r, g, b }
            p.ring:SetVertexColor(1, 1, 1, cur and 1 or 0.8)
            p.dot:SetVertexColor(col[1], col[2], col[3], 1)
            if p.n.SetFont and UI.FONT then p.n:SetFont(UI.FONT, math.max(7, math.floor((cur and 9 or 8) * k + 0.5)), "") end
            p.n:SetText(i)
            p.tip = i .. ". " .. P:StepTitle(s)
            p:SetFrameLevel(lvl + 8)
            p:ClearAllPoints(); p:SetPoint("CENTER", cv, "TOPLEFT", px, -py)
            p:Show()
            table.insert(placed, { px = px, py = py, p = p, nums = tostring(i) })
            end
            if prev then
                nl = nl + 1
                local l = line(nl, cv)
                l:SetThickness(2)
                l:SetColorTexture(r, g, b, 0.75)
                l:SetStartPoint("TOPLEFT", cv, prev[1] * w, -prev[2] * h)
                l:SetEndPoint("TOPLEFT", cv, x * w, -y * h)
                l:Show()
            end
            prev = { x, y }
        end
    end
end

function UI:DrawQuestCamps(cv, mapID, w, h)
    hideAll()
    if not WK:FeatureOn("quests") then return end
    local q = Q()
    local mode = q:Config().map
    if mode == "off" then
        drawTour(cv, mapID, w, h, (UI.mapBase or cv:GetFrameLevel() or 1) + 20)
        return
    end
    local tracked = q:Tracked()
    local list = {}
    if mode == "all" then
        for _, e in ipairs(q:LogQuests()) do table.insert(list, e.id) end
    elseif tracked then
        list[1] = tracked
    end
    local lvl = (UI.mapBase or cv:GetFrameLevel() or 1) + 20
    local nc, nl, nt = 0, 0, 0
    local cfg = q:Config()
    local style = cfg.zoneStyle or "heat"
    if not heatHolder then heatHolder = CreateFrame("Frame", nil, cv); heatHolder.wk = true end
    if heatHolder:GetParent() ~= cv then heatHolder:SetParent(cv) end
    heatHolder:ClearAllPoints(); heatHolder:SetAllPoints(cv)
    heatHolder:SetFrameLevel(lvl - 1); heatHolder:Show()
    local heatK = (cfg.heat or 100) / 100
    for _, qid in ipairs(list) do
        local title = q:Title(qid)
        local main = qid == tracked
        if q:IsComplete(qid) then
            local p = q:TurnIn(qid)
            local x, y
            if p then x, y = mapPos(p, mapID) end
            if x then
                nt = nt + 1
                local pin = turnPin(nt, cv)
                local s = main and 18 or 14
                pin:SetSize(s, s)
                pin.title = title
                pin:SetFrameLevel(lvl + 6)
                pin:ClearAllPoints(); pin:SetPoint("CENTER", cv, "TOPLEFT", x * w, -y * h)
                pin:Show()
            end
        else
            for oi, o in ipairs(q:Objectives(qid)) do
                if not o.done then
                    -- points exacts sur cette carte : chaleur ou points, les camps restent pour le clic et l'étiquette
                    local pts = style ~= "circles" and q:Points(o, mapID) or {}
                    local exact = #pts > 0
                    if exact then
                        local ocol = main and UI.QuestObjColor(oi) or { UI:Accent() }
                        local size = style == "points" and (main and 7 or 5) or math.max(22, w * 0.042)
                        local alpha = math.min(1, (main and 0.55 or 0.28) * heatK)
                        heatUsed = paintPoints(heatHolder, heatTex, heatUsed, MAX_HEAT, pts, w, h, ocol, style, size, alpha)
                    end
                    for k, c in ipairs(o.camps) do
                        local x, y, same = mapPos(c, mapID)
                        if x then
                            nc = nc + 1
                            local f = campFrame(nc, cv)
                            local size = same and math.max(22, c.r * 2 * w) or (main and 16 or 12)
                            f:SetSize(size, size)
                            local col = o.type == "item" and C.warning or { UI:Accent() }
                            -- bien visibles sur le parchemin de la carte (les repères du jeu sont masqués)
                            -- zone fine : remplissage léger, contour fin en pointillés, sans halo ni gros anneau
                            f.ring:Hide(); f.edge:Hide(); f.glow:Hide()
                            if exact and same then
                                -- points dessinés : zone invisible, gardée pour l'infobulle et le clic
                                f.fill:SetVertexColor(0, 0, 0, 0)
                                thinRing(f, size, 0, 0, 0, 0)
                            else
                                f.fill:SetVertexColor(col[1], col[2], col[3], main and 0.2 or 0.13)
                                thinRing(f, size, col[1], col[2], col[3], main and 0.95 or 0.7)
                            end
                            f.info = { title = title, text = (o.name ~= "" and o.name or o.text) .. string.format(" · %d/%d", o.have or 0, o.need or 0), camp = c }
                            f:SetFrameLevel(lvl)
                            f:ClearAllPoints(); f:SetPoint("CENTER", cv, "TOPLEFT", x * w, -y * h)
                            f:Show()
                            -- étiquette sur le plus grand camp de chaque objectif de la quête suivie
                            if main and same and k == 1 then
                                nl = nl + 1
                                local l = label(nl, cv)
                                l.text:SetText(f.info.text)
                                l:SetSize(l.text:GetStringWidth() + 12, 16)
                                l:SetFrameLevel(lvl + 4)
                                l:ClearAllPoints(); l:SetPoint("BOTTOM", f, "TOP", 0, 2)
                                l:Show()
                            end
                        end
                    end
                end
            end
        end
    end
    UI.questZoneDiag = { map = mapID, style = style, heat = heatUsed, camps = nc, quests = #list, w = w }
    drawTour(cv, mapID, w, h, lvl)
    UI:RefreshQuestMapPanel()
end

---------------------------------------------------------------------------
-- Volet « Quêtes » sur la carte
---------------------------------------------------------------------------
local panel
local ROWS = 6
local function buildPanel()
    local parent = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
    if not (parent and parent.GetFrameLevel) then return end
    panel = CreateFrame("Frame", "WarbandKeeperQuestMapPanel", parent)
    -- volet discret : petit, fond léger, une ligne d'en-tête (titre repliable + choix Toutes / Suivie)
    panel:SetWidth(204)
    panel:SetFrameLevel((parent:GetFrameLevel() or 1) + 40)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
    UI:Panel(panel, 7, { C.bg[1], C.bg[2], C.bg[3], 0.72 }, { C.border[1], C.border[2], C.border[3], 0.6 })
    panel.head = CreateFrame("Button", nil, panel)
    panel.head:SetPoint("TOPLEFT", 0, 0); panel.head:SetPoint("TOPRIGHT", -58, 0); panel.head:SetHeight(20)
    panel.chev = UI:Icon(panel.head, "chevron", 9); panel.chev:SetPoint("LEFT", 8, 0)
    panel.chev:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
    panel.title = UI:Text(panel.head, 10, C.muted); panel.title:SetPoint("LEFT", 21, 0); panel.title:SetText(T("Quêtes du journal"))
    panel.head:SetScript("OnClick", function()
        local c = Q():Config(); c.panelFold = not c.panelFold; UI:RefreshQuestMapPanel()
    end)
    panel.head:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Quêtes du journal"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic sur une quête : la suivre · clic ici : replier"), C.muted[1], C.muted[2], C.muted[3], true)
        GameTooltip:Show()
    end)
    panel.head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.mode = CreateFrame("Button", nil, panel)
    panel.mode:SetPoint("TOPRIGHT", -8, 0); panel.mode:SetSize(52, 20)
    panel.mode.text = UI:Text(panel.mode, 10); panel.mode.text:SetPoint("RIGHT", 0, 0); panel.mode.text:SetJustifyH("RIGHT")
    panel.mode:SetScript("OnClick", function()
        local c = Q():Config()
        c.map = (c.map == "all") and "tracked" or "all"
        if UI.RedrawWorldMap then UI.RedrawWorldMap("quêtes") end
    end)
    panel.mode:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(T("Zones de quête de la quête suivie seulement, ou de toutes les quêtes du journal."), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    panel.mode:SetScript("OnLeave", function() GameTooltip:Hide() end)
    panel.rows = {}
    for i = 1, ROWS do
        local b = CreateFrame("Button", nil, panel)
        b:SetHeight(14)
        b:SetPoint("TOPLEFT", 8, -20 - (i - 1) * 15); b:SetPoint("RIGHT", -8, 0)
        b.box = b:CreateTexture(nil, "ARTWORK"); b.box:SetSize(7, 7); b.box:SetPoint("LEFT", 2, 0)
        b.text = UI:Text(b, 9, C.text); b.text:SetPoint("LEFT", 14, 0); b.text:SetPoint("RIGHT", 0, 0); b.text:SetJustifyH("LEFT")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        b:SetScript("OnClick", function(s)
            if not s.qid then return end
            if Q():Tracked() == s.qid then Q():Untrack() else Q():Track(s.qid) end
            if UI.RedrawWorldMap then UI.RedrawWorldMap("quête suivie") end
        end)
        b:Hide()
        panel.rows[i] = b
    end
end

function UI:RefreshQuestMapPanel()
    if not WK:FeatureOn("quests") or Q():Config().map == "off" or Q():Config().panel == false or not (WorldMapFrame and WorldMapFrame:IsShown()) then
        if panel then panel:Hide() end
        return
    end
    if not panel then buildPanel() end
    if not panel then return end
    local list = Q():LogQuests()
    local tracked = Q():Tracked()
    local mapInfo = WorldMapFrame.GetMapID and C_Map.GetMapInfo and C_Map.GetMapInfo(WorldMapFrame:GetMapID() or 0)
    local zone = mapInfo and mapInfo.name
    -- quêtes de la zone affichée d'abord, puis la suivie
    table.sort(list, function(a, b)
        local az, bz = a.zone == zone, b.zone == zone
        if az ~= bz then return az end
        if (a.id == tracked) ~= (b.id == tracked) then return a.id == tracked end
        return (a.level or 0) < (b.level or 0)
    end)
    local fold = Q():Config().panelFold
    local n = 0
    for i, b in ipairs(panel.rows) do
        local e = not fold and list[i]
        if e then
            n = i
            b.qid = e.id
            local on = e.id == tracked
            b.box:SetTexture(UI.MEDIA .. (on and "circle" or "ring"))
            if e.complete then b.box:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
            elseif on then b.box:SetVertexColor(UI:Accent())
            else b.box:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1) end
            b.text:SetText(string.format("%s%d|r  %s%s", UI:Hex(C.dim), e.level or 0, e.title or "?",
                e.complete and ("  " .. UI:Hex(C.positive) .. T("rendre") .. "|r") or ""))
            b.text:SetTextColor(unpack(on and C.text or C.muted))
            b:Show()
        else
            b:Hide()
        end
    end
    local r, g, b = UI:Accent()
    panel.mode.text:SetText(Q():Config().map == "all" and T("Toutes") or T("Suivie"))
    panel.mode.text:SetTextColor(r, g, b, 1)
    if panel.chev.SetRotation then panel.chev:SetRotation(fold and math.pi / 2 or 0) end
    panel.title:SetText(fold and string.format(T("Quêtes du journal (%d)"), #list) or T("Quêtes du journal"))
    panel:SetHeight(n > 0 and (20 + n * 15 + 6) or 20)
    panel:Show()
end

function UI:RefreshQuestCamps()
    if WorldMapFrame and WorldMapFrame:IsShown() and UI.RedrawWorldMap then UI.RedrawWorldMap("quêtes") end
end

WK:On("PLAYER_LOGIN", function()
    if WorldMapFrame then WorldMapFrame:HookScript("OnHide", function() if panel then panel:Hide() end end) end
end)

---------------------------------------------------------------------------
-- Minicarte : zones de la quête suivie (objectifs pas finis) autour du perso, en chaleur ou en points
-- (QuestTrack:Config().miniStyle). Liste refaite toutes les 2 s, positions toutes les 0,2 s.
---------------------------------------------------------------------------
local MAX_MINI = 260
local miniHolder, miniTex, miniUsed = nil, {}, 0
local miniList, miniAt
local function miniReset()
    for i = 1, miniUsed do miniTex[i]:Hide() end
    miniUsed = 0
end
local miniCache = {}
local function miniPoints(q, qid, map)
    local now = GetTime()
    local key = qid .. ":" .. map
    local hit = miniCache[key]
    if miniList and hit and now - hit.at < 2 then return hit.list end
    local list = {}
    if not q:IsComplete(qid) then
        for oi, o in ipairs(q:Objectives(qid)) do
            if not o.done then
                local pts = q:Points(o, map)
                if #pts > 0 then table.insert(list, { pts = pts, col = UI.QuestObjColor(oi) }) end
            end
        end
    end
    if now - (miniAt or 0) > 10 then miniCache = {} end
    miniCache[key] = { at = now, list = list }
    miniList, miniAt = list, now
    return list
end
local function updateMini()
    if not miniHolder then return end
    miniReset()
    local q = Q()
    if not (q and WK:FeatureOn("quests") and Minimap and Minimap:IsVisible()) then return end
    local cfg = q:Config()
    local style = cfg.miniStyle or "heat"
    if style == "off" or cfg.map == "off" then return end
    -- tournée en cours : la quête de l'étape « faire » ; sinon la quête suivie
    local qid
    local P = WK.modules.QuestPlan
    local tour = P and P:Active() and P:Tour()
    local st = tour and tour.steps[tour.idx]
    if st and st.kind == "do" and st.qids and st.qids[1] then qid = st.qids[1] end
    qid = qid or q:Tracked()
    if not qid then return end
    local inInst = IsInInstance
    local kind = inInst and select(2, inInst())
    if kind and kind ~= "none" then return end
    local p = WK.modules.Guide:PlayerPos()
    if not (p and p.map and UI.MapSize and UI.MiniViewRadius) then return end
    -- sous-zone (village, grotte) : les points sont sur la carte de la zone parente
    local map, px, py = p.map, p.x, p.y
    local list = miniPoints(q, qid, map)
    local CM = C_Map
    if #list == 0 and CM and CM.GetMapInfo and CM.GetPlayerMapPosition then
        local info = CM.GetMapInfo(map)
        local parent = info and info.parentMapID
        if parent and parent > 0 then
            local pos = CM.GetPlayerMapPosition(parent, "player")
            local x, y
            if pos then x, y = pos.x, pos.y; if pos.GetXY then x, y = pos:GetXY() end end
            if x and (x ~= 0 or y ~= 0) then
                local l2 = miniPoints(q, qid, parent)
                if #l2 > 0 then list, map, px, py = l2, parent, x, y end
            end
        end
    end
    local size = UI.MapSize(map)
    UI.questMiniDiag = { qid = qid, map = map, objs = #list, style = style }
    if not size or #list == 0 then return end
    local radius = UI.MiniViewRadius()
    local limit = radius * 0.95
    local half = Minimap:GetWidth() / 2
    local rotate = WK.GetCVar("rotateMinimap") == "1"
    local gf = GetPlayerFacing
    local facing = rotate and gf and gf() or nil
    local cs, sn = facing and math.cos(facing) or 1, facing and math.sin(facing) or 0
    local w, h = size[1], size[2]
    -- un halo couvre env. 3 % de la carte (comme sur la carte du monde), borné à la minicarte
    local hs = math.max(14, math.min(50, (w * 0.042) / radius * half))
    local alpha = math.min(1, 0.6 * ((cfg.heat or 100) / 100))
    for _, e in ipairs(list) do
        local pts, col = e.pts, e.col
        for i = 1, #pts, 2 do
            local dx, dy = (pts[i] - px) * w, (py - pts[i + 1]) * h
            if dx < limit and dx > -limit and dy < limit and dy > -limit and dx * dx + dy * dy < limit * limit then
                if facing then dx, dy = dx * cs + dy * sn, -dx * sn + dy * cs end
                miniUsed = miniUsed + 1
                local t = miniTex[miniUsed]
                if not t then
                    t = miniHolder:CreateTexture(nil, "ARTWORK"); t:SetBlendMode("BLEND"); miniTex[miniUsed] = t
                end
                -- texture et taille posées seulement si elles changent (avant : à chaque passage, pour chaque point)
                if style == "points" then
                    if t.wkStyle ~= "points" then
                        t:SetTexture(UI.MEDIA .. "circle"); t:SetSize(6, 6); t.wkStyle, t.wkSize = "points", 6
                    end
                    t:SetVertexColor(col[1], col[2], col[3], 0.95)
                else
                    if t.wkStyle ~= "heat" then t:SetTexture(UI.MEDIA .. "fxhalo"); t.wkStyle = "heat" end
                    if t.wkSize ~= hs then t:SetSize(hs, hs); t.wkSize = hs end
                    t:SetVertexColor(col[1], col[2], col[3], alpha)
                end
                t:ClearAllPoints(); t:SetPoint("CENTER", Minimap, "CENTER", dx / radius * half, dy / radius * half)
                t:Show()
                if miniUsed >= MAX_MINI then break end
            end
        end
        if miniUsed >= MAX_MINI then break end -- plafond pour toute la minicarte, pas seulement par objectif
    end
    UI.questMiniDiag.drawn = miniUsed
end
UI.QuestMiniUpdate = updateMini
function UI.RefreshQuestMini() miniList = nil; if miniHolder then updateMini() end end
WK:On("PLAYER_LOGIN", function()
    C_Timer.After(2.5, function()
        if not Minimap or miniHolder then return end
        miniHolder = CreateFrame("Frame", "WarbandKeeperQuestMini", Minimap)
        miniHolder:SetAllPoints(Minimap)
        miniHolder:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 3)
        miniHolder.acc = 0
        miniHolder:SetScript("OnUpdate", function(s, el)
            s.acc = s.acc + el
            if s.acc < 0.2 then return end -- 5 fois par seconde suffisent (avant 10)
            s.acc = 0
            updateMini()
        end)
    end)
end)
