local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

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

local function hideAll()
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
    local l = lines[i]
    if not l then
        l = cv:CreateLine(nil, "ARTWORK")
        lines[i] = l
    end
    return l
end
local function drawTour(cv, mapID, w, h, lvl)
    local P = WK.modules.QuestPlan
    local t = P and P:Tour()
    if not t then return end
    local r, g, b = UI:Accent()
    local prev, nl = nil, 0
    for i, s in ipairs(t.steps) do
        local x, y = mapPos(s, mapID)
        if x then
            local p = numPin(i, cv)
            local cur = i == t.idx
            local sz = cur and 26 or 20
            p:SetSize(sz, sz)
            local col = (s.kind == "pick" and C.gold) or (s.kind == "turn" and C.positive) or { r, g, b }
            p.ring:SetVertexColor(1, 1, 1, cur and 1 or 0.8)
            p.dot:SetVertexColor(col[1], col[2], col[3], i < t.idx and 0.4 or 1)
            p.n:SetText(i)
            p.tip = P:StepTitle(s)
            p:SetFrameLevel(lvl + 8)
            p:ClearAllPoints(); p:SetPoint("CENTER", cv, "TOPLEFT", x * w, -y * h)
            p:Show()
            if prev and i > t.idx - 1 then
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
            for _, o in ipairs(q:Objectives(qid)) do
                if not o.done then
                    for k, c in ipairs(o.camps) do
                        local x, y, same = mapPos(c, mapID)
                        if x then
                            nc = nc + 1
                            local f = campFrame(nc, cv)
                            local size = same and math.max(22, c.r * 2 * w) or (main and 16 or 12)
                            f:SetSize(size, size)
                            local col = o.type == "item" and C.warning or { UI:Accent() }
                            -- bien visibles sur le parchemin de la carte (les repères du jeu sont masqués)
                            f.fill:SetVertexColor(col[1], col[2], col[3], main and 0.38 or 0.28)
                            f.ring:SetVertexColor(col[1], col[2], col[3], 1)
                            f.glow:SetVertexColor(col[1], col[2], col[3], main and 0.45 or 0.3)
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
    drawTour(cv, mapID, w, h, lvl)
    UI:RefreshQuestMapPanel()
end

---------------------------------------------------------------------------
-- Volet « Quêtes » sur la carte
---------------------------------------------------------------------------
local panel
local ROWS = 8
local function buildPanel()
    local parent = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
    if not (parent and parent.GetFrameLevel) then return end
    panel = CreateFrame("Frame", "WarbandKeeperQuestMapPanel", parent)
    panel:SetWidth(220)
    panel:SetFrameLevel((parent:GetFrameLevel() or 1) + 40)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 8, 8)
    UI:Panel(panel, 9, { C.bg[1], C.bg[2], C.bg[3], 0.9 }, C.border)
    panel.title = UI:Text(panel, 11); panel.title:SetPoint("TOPLEFT", 10, -8); panel.title:SetText(T("Quêtes du journal"))
    panel.hint = UI:Text(panel, 9, C.muted); panel.hint:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -2)
    panel.hint:SetText(T("Clic : suivre la quête"))
    panel.rows = {}
    for i = 1, ROWS do
        local b = CreateFrame("Button", nil, panel)
        b:SetHeight(17)
        b:SetPoint("TOPLEFT", 8, -36 - (i - 1) * 18); b:SetPoint("RIGHT", -8, 0)
        b.box = b:CreateTexture(nil, "ARTWORK"); b.box:SetSize(10, 10); b.box:SetPoint("LEFT", 2, 0)
        b.text = UI:Text(b, 10, C.text); b.text:SetPoint("LEFT", 18, 0); b.text:SetPoint("RIGHT", 0, 0); b.text:SetJustifyH("LEFT")
        if b.text.SetWordWrap then b.text:SetWordWrap(false) end
        b:SetScript("OnClick", function(s)
            if not s.qid then return end
            if Q():Tracked() == s.qid then Q():Untrack() else Q():Track(s.qid) end
            if UI.RedrawWorldMap then UI.RedrawWorldMap("quête suivie") end
        end)
        b:Hide()
        panel.rows[i] = b
    end
    panel.mode = UI:Button(panel, "", nil, 20, "secondary")
    panel.mode:SetScript("OnClick", function()
        local c = Q():Config()
        c.map = (c.map == "all") and "tracked" or "all"
        if UI.RedrawWorldMap then UI.RedrawWorldMap("quêtes") end
    end)
    panel.mode.tooltip = "Zones de quête de la quête suivie seulement, ou de toutes les quêtes du journal."
end

function UI:RefreshQuestMapPanel()
    if not WK:FeatureOn("quests") or Q():Config().map == "off" or not (WorldMapFrame and WorldMapFrame:IsShown()) then
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
    local n = 0
    for i, b in ipairs(panel.rows) do
        local e = list[i]
        if e then
            n = i
            b.qid = e.id
            local on = e.id == tracked
            b.box:SetTexture(UI.MEDIA .. (on and "circle" or "ring"))
            if e.complete then b.box:SetVertexColor(C.positive[1], C.positive[2], C.positive[3], 1)
            elseif on then b.box:SetVertexColor(UI:Accent())
            else b.box:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1) end
            b.text:SetText(string.format("[%d] %s%s", e.level or 0, e.title or "?", e.complete and (" · " .. T("à rendre")) or ""))
            b.text:SetTextColor(unpack(on and C.text or C.muted))
            b:Show()
        else
            b:Hide()
        end
    end
    panel.mode:SetLabel(Q():Config().map == "all" and T("Zones : toutes") or T("Zones : la suivie"))
    panel.mode:SetWidth(panel.mode.label:GetStringWidth() + 24)
    panel.mode:ClearAllPoints(); panel.mode:SetPoint("TOPLEFT", 8, -36 - n * 18 - 6)
    panel:SetHeight(36 + n * 18 + 6 + 20 + 10)
    if n == 0 then panel.hint:SetText(T("Journal vide")) else panel.hint:SetText(T("Clic : suivre la quête")) end
    panel:Show()
end

function UI:RefreshQuestCamps()
    if WorldMapFrame and WorldMapFrame:IsShown() and UI.RedrawWorldMap then UI.RedrawWorldMap("quêtes") end
end

WK:On("PLAYER_LOGIN", function()
    if WorldMapFrame then WorldMapFrame:HookScript("OnHide", function() if panel then panel:Hide() end end) end
end)
