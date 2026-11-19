local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Tableau des bateaux et zeppelins, sans horaires : chaque ligne du jeu (Modules/BoatLines.lua) avec son
-- navire, ses escales et le quai le plus proche de toi. Clic : guidage vers ce quai.
-- Ouvert par le raccourci « Bateaux » du micro menu et /wk bateaux.
local W, ROW, HEAD = 520, 36, 64
local board

local function BL() return WK.modules.BoatLines end
local function dist(ax, ay, bx, by) local dx, dy = ax - bx, ay - by; return math.sqrt(dx * dx + dy * dy) end

-- quai de la ligne le plus proche du perso (même continent) et sa distance, sinon le premier
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
    return best, bd
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperBoatBoard", UIParent)
    f:SetSize(W, 200)
    f:SetPoint("CENTER", 0, 80)
    -- au-dessus de la fenêtre de l'addon (strate HIGH, qui se remet devant à chaque clic)
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
    local cols = { { T("LIGNE"), 40 }, { T("QUAI LE PLUS PROCHE"), 330 } }
    for _, cdef in ipairs(cols) do
        local h = UI:Text(f, 9, C.dim); h:SetPoint("TOPLEFT", cdef[2], -52); h:SetText(cdef[1])
    end
    f.rows = {}
    local function row(i)
        local r = f.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, f)
        r:SetHeight(ROW)
        r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 2)
        r.ring = UI:Icon(r, "circle", 20, nil, "ARTWORK"); r.ring:SetPoint("LEFT", 12, 0)
        r.icon = UI:Icon(r, "boat", 12, nil, "OVERLAY"); r.icon:SetPoint("CENTER", r.ring, "CENTER")
        r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 40, -4); r.name:SetWidth(280); r.name:SetJustifyH("LEFT")
        if r.name.SetWordWrap then r.name:SetWordWrap(false) end
        r.vessel = UI:Text(r, 10, C.muted); r.vessel:SetPoint("TOPLEFT", 40, -19); r.vessel:SetWidth(280); r.vessel:SetJustifyH("LEFT")
        r.near = UI:Text(r, 11); r.near:SetPoint("TOPLEFT", 330, -4); r.near:SetPoint("RIGHT", -12, 0); r.near:SetJustifyH("LEFT")
        if r.near.SetWordWrap then r.near:SetWordWrap(false) end
        r.dist = UI:Text(r, 9, C.muted); r.dist:SetPoint("TOPLEFT", 330, -19); r.dist:SetPoint("RIGHT", -12, 0); r.dist:SetJustifyH("LEFT")
        r:SetScript("OnEnter", function(s)
            s.bg:SetColor(unpack(C.hover)); s.bg:Show()
            if not s.line then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            local l = s.line
            GameTooltip:SetText(T(l.vessel or "?"), 1, 1, 1)
            GameTooltip:AddLine(BL():LineName(l), 0.85, 0.85, 0.85, true)
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
        local list, near = {}, {}
        for _, l in ipairs(B:All()) do
            if self.showAll or B:Mine(l) then
                table.insert(list, l)
                local s, d = nearestStop(l)
                near[l] = { s = s, d = d }
            end
        end
        -- la ligne dont un quai est le plus proche de toi en premier
        table.sort(list, function(a, b)
            local da, db = near[a].d, near[b].d
            if (da ~= nil) ~= (db ~= nil) then return da ~= nil end
            if da and db then return da < db end
            return B:LineName(a) < B:LineName(b)
        end)
        self.all:SetLabel(self.showAll and T("Ma faction") or T("Toutes les lignes"))
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
            local nr = near[l]
            r.near:SetText(B:StopName(l, nr.s))
            r.dist:SetText(nr.d and string.format(T("à %d m · vers %s"), math.floor(nr.d + 0.5), table.concat(B:Destinations(l, nr.s), " » "))
                or string.format(T("vers %s"), table.concat(B:Destinations(l, nr.s), " » ")))
            r:Show()
        end
        for i = #list + 1, #self.rows do self.rows[i]:Hide() end
        self.sub:SetText(string.format(T("%d lignes · trajets et quais tirés des fichiers du jeu"), #list))
        self:SetHeight(HEAD + #list * ROW + 14)
    end
    f:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "WarbandKeeperBoatBoard") end
    return f
end

function UI:ToggleBoatBoard(show)
    if not board then board = build() end
    if show == true or not board:IsShown() then board:Refresh(); board:Show(); board:Raise() else board:Hide() end
end
