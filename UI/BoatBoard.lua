local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Tableau des bateaux et zeppelins : chaque ligne du jeu (Modules/BoatLines.lua) avec son navire, son tour,
-- où il en est (barre), et le prochain départ du quai le plus proche de toi. Clic : guidage vers ce quai ;
-- bouton « partager » : le prochain départ écrit dans la ligne de chat (tu choisis le canal).
-- Ouvert par le raccourci « Bateaux » du micro menu, /wk bateaux, le clic sur un navire de la carte.
local W, ROW, HEAD = 560, 36, 64
local board

local function BL() return WK.modules.BoatLines end
local function Clock(s) return WK.modules.BoatTimes.Clock(s) end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- quai de la ligne le plus proche du perso (même continent), sinon le premier
local function nearestStop(l)
    local p = WK.modules.Guide:PlayerPos()
    local best, bd = 1, nil
    if p and p.cont then
        for s, st in ipairs(l.stops) do
            if st.c == p.cont then
                local d = dist(st.x, st.y, p.wx, p.wy)
                if not bd or d < bd then best, bd = s, d end
            end
        end
    end
    return best
end

-- texte dans la ligne de chat (ouverte sur le canal en cours) : le joueur choisit où l'envoyer
local function toChat(text)
    local eb = ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()
    if eb then eb:Insert(text)
    elseif ChatFrame_OpenChat then ChatFrame_OpenChat(text)
    else WK:Print(text) end
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperBoatBoard", UIParent)
    f:SetSize(W, 200)
    f:SetPoint("CENTER", 0, 80)
    -- au-dessus de la fenêtre de l'addon (strate HIGH, qui se remet devant à chaque clic) : le bouton
    -- « Ouvrir le tableau des bateaux » de QoL l'ouvrait derrière elle
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, "boat", 18, nil, "ARTWORK"); f.logo:SetPoint("TOPLEFT", 14, -13)
    f.logo:SetVertexColor(UI:Accent())
    f.title = UI:Text(f, 14); f.title:SetPoint("LEFT", f.logo, "RIGHT", 8, 0)
    f.title:SetText(T("Bateaux et zeppelins"))
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 16, -36)
    f.close = UI:IconButton(f, "close", 18); f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.all = UI:Button(f, "Toutes les lignes", nil, 22, "ghost")
    f.all:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.all:SetScript("OnClick", function() f.showAll = not f.showAll; f:Refresh() end)
    -- en-têtes de colonnes
    local cols = { { T("LIGNE"), 40 }, { T("TOUR"), 300 }, { T("OÙ IL EST"), 350 }, { T("DÉPART"), 446 } }
    for _, cdef in ipairs(cols) do
        local h = UI:Text(f, 9, C.dim); h:SetPoint("TOPLEFT", cdef[2], -52); h:SetText(cdef[1])
    end
    f.help = UI:Text(f, 10, C.muted)
    f.help:SetJustifyH("LEFT")
    if f.help.SetWordWrap then f.help:SetWordWrap(true) end
    f.help:SetText(T("L'heure de chaque navire se cale toute seule : quand tu le prends, quand le maître de quai annonce son arrivée près de toi, ou quand un membre de ta guilde ou de ton groupe qui a Warband Keeper en voit un."))
    f.rows = {}
    local function row(i)
        local r = f.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, f)
        r:SetHeight(ROW)
        r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 2)
        r.ring = UI:Icon(r, "circle", 20, nil, "ARTWORK"); r.ring:SetPoint("LEFT", 12, 0)
        r.icon = UI:Icon(r, "boat", 12, nil, "OVERLAY"); r.icon:SetPoint("CENTER", r.ring, "CENTER")
        r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 40, -4); r.name:SetWidth(250); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.vessel = UI:Text(r, 10, C.muted); r.vessel:SetPoint("TOPLEFT", 40, -19); r.vessel:SetWidth(250); r.vessel:SetJustifyH("LEFT")
        r.tour = UI:Text(r, 11); r.tour:SetPoint("LEFT", 300, 0)
        r.track = r:CreateTexture(nil, "ARTWORK"); r.track:SetSize(80, 5); r.track:SetPoint("LEFT", 350, 0)
        r.fill = r:CreateTexture(nil, "ARTWORK", nil, 2); r.fill:SetHeight(5); r.fill:SetPoint("LEFT", r.track, "LEFT")
        r.dep = UI:Text(r, 11); r.dep:SetPoint("TOPLEFT", 446, -4); r.dep:SetPoint("RIGHT", -34, 0); r.dep:SetJustifyH("LEFT")
        r.from = UI:Text(r, 9, C.muted); r.from:SetPoint("TOPLEFT", 446, -19); r.from:SetPoint("RIGHT", -34, 0); r.from:SetJustifyH("LEFT")
        if r.from.SetWordWrap then r.from:SetWordWrap(false) end
        r.share = UI:IconButton(r, "send", 22, T("Partager dans le chat"))
        r.share:SetPoint("RIGHT", -8, 0)
        r.share:SetScript("OnClick", function() if r.line then toChat(BL():ChatText(r.line, nearestStop(r.line))) end end)
        r:SetScript("OnEnter", function(s)
            s.bg:SetColor(unpack(C.hover)); s.bg:Show()
            if not s.line then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            local l = s.line
            GameTooltip:SetText(T(l.vessel or "?"), 1, 1, 1)
            for st = 1, #l.stops do
                local state = BL():State(l, st)
                local txt = state and (state.atDock and string.format(T("à quai, départ dans %s"), Clock(state.inn)) or string.format(T("départ dans %s"), Clock(state.inn))) or T("heure pas encore calée")
                GameTooltip:AddDoubleLine(BL():StopName(l, st) .. " » " .. BL():StopName(l, st % #l.stops + 1), txt, 0.85, 0.85, 0.85, 1, 1, 1)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("Clic : guidage vers le quai le plus proche"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function(s) s.bg:Hide(); GameTooltip:Hide() end)
        r:SetScript("OnClick", function(s)
            local l = s.line
            if not l then return end
            local sidx = nearestStop(l)
            local st = l.stops[sidx]
            local mapID, x, y = BL():ToMap(st.c, st.x, st.y)
            if mapID then
                local name = BL():StopName(l, sidx)
                WK.modules.MapLayers:GuideTo(mapID, { x, y, 0, nil, nil, name, name, T(l.vessel or "") }, "Quai")
            end
        end)
        r.bg:Hide()
        f.rows[i] = r
        return r
    end

    function f:Refresh()
        local B = BL()
        local list = {}
        for _, l in ipairs(B:All()) do if self.showAll or B:Mine(l) then table.insert(list, l) end end
        -- la ligne la plus proche de son départ en premier
        local states = {}
        for _, l in ipairs(list) do states[l] = B:State(l, nearestStop(l)) end
        table.sort(list, function(a, b)
            local sa, sb = states[a], states[b]
            if (sa ~= nil) ~= (sb ~= nil) then return sa ~= nil end
            if sa and sb then return sa.inn < sb.inn end
            return B:LineName(a) < B:LineName(b)
        end)
        self.all:SetLabel(self.showAll and T("Ma faction") or T("Toutes les lignes"))
        local known = 0
        for i, l in ipairs(list) do
            local r = row(i)
            r.line = l
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -(HEAD + (i - 1) * ROW)); r:SetPoint("TOPRIGHT", -6, -(HEAD + (i - 1) * ROW))
            local col = l.kind == "zeppelin" and C.warning or C.positive
            r.ring:SetVertexColor(col[1], col[2], col[3], 1)
            r.icon:SetTexture(UI.MEDIA .. (l.kind == "zeppelin" and "zeppelin" or "boat"))
            r.icon:SetVertexColor(0.06, 0.06, 0.07, 1)
            r.name:SetText(B:LineName(l))
            r.vessel:SetText(T(l.vessel or ""))
            local st = states[l]
            r.tour:SetText((st and st.P or l.period) and Clock(st and st.P or l.period) or "?")
            r.track:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
            local _, _, _, at, leg, frac = B:ShipPos(l)
            local prog
            if leg then prog = ((leg - 1) + (frac or 0)) / #l.stops elseif at then prog = (at - 1) / #l.stops end
            r.fill:SetShown(prog ~= nil)
            if prog then r.fill:SetWidth(math.max(1, 80 * prog)); r.fill:SetColorTexture(col[1], col[2], col[3], 0.9) end
            if st then
                known = known + 1
                local pre = st.est and T("env. ") or ""
                r.dep:SetText(st.atDock and (UI:Hex(C.positive) .. T("à quai") .. " " .. Clock(st.inn) .. "|r") or (pre .. Clock(st.inn)))
                r.from:SetText(string.format(T("de %s"), B:StopName(l, nearestStop(l))))
            else
                r.dep:SetText(UI:Hex(C.dim) .. T("heure inconnue") .. "|r")
                r.from:SetText("")
            end
            r:Show()
        end
        for i = #list + 1, #self.rows do self.rows[i]:Hide() end
        self.sub:SetText(string.format(T("%d lignes · heure calée pour %d · trajets et tours tirés des fichiers du jeu et de Nauticus"), #list, known))
        -- aucune heure calée : expliquer comment faire (une seule fois suffit par ligne)
        self.help:SetShown(known < #list)
        self.help:ClearAllPoints(); self.help:SetPoint("TOPLEFT", 16, -(HEAD + #list * ROW + 8)); self.help:SetPoint("RIGHT", -16, 0)
        self:SetHeight(HEAD + #list * ROW + 14 + (known < #list and 46 or 0))
    end
    f:SetScript("OnUpdate", function(s, el)
        s.acc = (s.acc or 0) + el
        if s.acc < 1 then return end
        s.acc = 0
        s:Refresh()
    end)
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperBoatBoard") end
    return f
end

function UI:ToggleBoatBoard(show)
    if not board then board = build() end
    if show == true or not board:IsShown() then board:Refresh(); board:Show(); board:Raise() else board:Hide() end
end
