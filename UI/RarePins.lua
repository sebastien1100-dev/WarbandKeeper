local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Rares sur la carte du monde (Modules/Rares.lua) : un médaillon par rare à sa position la plus
-- probable (contour mauve, doré pour un élite, grisé si ce perso l'a tué). Au survol : ses autres
-- points d'apparition et sa patrouille. Liste « Rares de la zone » sur le côté de la carte.
-- Et l'infobulle d'un rare : butin notable, rares tués par tes persos.
local R = WK.modules.Rares
local MAX = 60

local holder, pins, dots, hovered = nil, {}, {}, nil

local function killedText(r)
    local k = R:Killed(r.id) or {}
    local yes, no = {}, {}
    for key, c in pairs(WK.DB.global.characters) do
        if (c.level or 0) >= (r.min or 0) - 10 then
            if k[key] then table.insert(yes, WK:CharName(c, key)) else table.insert(no, WK:CharName(c, key)) end
        end
    end
    return yes, no
end

local function tooltipLines(tt, r)
    tt:AddLine(string.format(T("Niveau %s · %s"), r.min == r.max and r.min or (r.min .. "-" .. r.max), T(r.elite and "Rare élite" or "Rare")), 0.8, 0.8, 0.8)
    local m
    for _, mm in pairs(r.maps) do m = mm break end
    if m then
        local n = #m.spawns / 2
        tt:AddLine(string.format(T("%d point(s) d'apparition"), n) .. ((#m.path > 0) and (" · " .. T("patrouille")) or ""), 0.6, 0.6, 0.6)
    end
    local loot = R:Loot(r.id)
    if #loot > 0 then
        tt:AddLine(T("Butin notable"), 0.88, 0.74, 0.45)
        for i, l in ipairs(loot) do
            if i > 5 then break end
            local name = WK.GetItemInfo(l.id) or ("#" .. l.id)
            local right = l.prof and (T(l.prof) .. (#l.who > 0 and (" · " .. table.concat(l.who, ", ")) or "")) or ""
            tt:AddDoubleLine("  " .. name, right, 1, 1, 1, #l.who > 0 and 0.56 or 0.6, #l.who > 0 and 0.82 or 0.6, #l.who > 0 and 0.54 or 0.6)
        end
    end
    local yes, no = killedText(r)
    if #yes > 0 then tt:AddLine(T("Tué par") .. " " .. table.concat(yes, ", "), 0.56, 0.82, 0.54, true) end
    if #no > 0 then tt:AddLine(T("Pas encore tué") .. " : " .. table.concat(no, ", "), 0.6, 0.6, 0.6, true) end
end

---------------------------------------------------------------------------
-- Médaillons
---------------------------------------------------------------------------
local function getPin(i)
    local p = pins[i]
    if not p then
        p = CreateFrame("Button", nil, holder)
        p.bg = UI:Icon(p, "circle", 20, nil, "ARTWORK")
        p.bg:SetPoint("CENTER")
        p.ring = UI:Icon(p, "ring", 24, nil, "OVERLAY")
        p.ring:SetPoint("CENTER")
        p.star = UI:Icon(p, "star", 12, nil, "OVERLAY")
        p.star:SetDrawLayer("OVERLAY", 2)
        p.star:SetPoint("CENTER", 0, 0)
        p:SetScript("OnEnter", function(s)
            local changed = hovered ~= s.r
            hovered = s.r
            WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
            GameTooltip:SetText(R:Name(s.r), C.rare[1], C.rare[2], C.rare[3])
            tooltipLines(GameTooltip, s.r)
            GameTooltip:AddLine(T("Clic : guidage vers ce rare"), 0.5, 0.5, 0.5)
            GameTooltip:Show()
            if changed and UI.RedrawRarePins then UI:RedrawRarePins() end
        end)
        p:SetScript("OnLeave", function(s)
            if hovered ~= s.r then return end
            hovered = nil
            GameTooltip:Hide()
            if UI.RedrawRarePins then UI:RedrawRarePins() end
        end)
        p:SetScript("OnClick", function(s) R:GuideTo(s.r) end)
        pins[i] = p
    end
    return p
end
local function getDot(i)
    local d = dots[i]
    if not d then
        d = holder:CreateTexture(nil, "ARTWORK")
        d:SetTexture(UI.MEDIA .. "circle")
        dots[i] = d
    end
    d:Show()
    return d
end

function UI:HideRarePins()
    for _, p in ipairs(pins) do p:Hide() end
    for _, d in ipairs(dots) do d:Hide() end
end

local last -- dernier dessin (pour redessiner au survol)
function UI:DrawRarePins(cv, mapID, w, h)
    last = { cv, mapID, w, h }
    if not WK:FeatureOn("rares") then
        if UI.SyncRareList then UI:SyncRareList(mapID, {}) end
        return
    end
    local list = R:OnMap(mapID)
    if UI.SyncRareList then UI:SyncRareList(mapID, list) end
    if not R:Config().map then return end
    if #list == 0 then return end
    if not holder then holder = CreateFrame("Frame", nil, cv) end
    holder:SetParent(cv)
    holder:SetAllPoints(cv)
    holder:SetFrameLevel((cv:GetFrameLevel() or 1) + 25)
    local scale = w / 1000
    local me = WK:CharKey()
    local nd = 0
    local shown = 0
    for _, r in ipairs(list) do
        if shown >= MAX then break end
        if not (R:Config().hideKilled and R:Killed(r.id, me)) then
        shown = shown + 1
        local i = shown
        local m = r.maps[mapID]
        local p = getPin(i)
        p.r = r
        local size = 26 * scale * 1.2
        p:SetSize(size, size)
        p.bg:SetSize(size * 0.82, size * 0.82)
        p.ring:SetSize(size, size)
        p.star:SetSize(size * 0.5, size * 0.5)
        local col = r.elite and C.gold or C.rare
        local dead = R:Killed(r.id, me) ~= nil
        p.bg:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
        p.ring:SetVertexColor(col[1], col[2], col[3], 1)
        p.star:SetVertexColor(col[1], col[2], col[3], 1)
        p:SetAlpha(dead and 0.45 or 1)
        if p.bg.SetDesaturated then p.bg:SetDesaturated(dead); p.ring:SetDesaturated(dead); p.star:SetDesaturated(dead) end
        p:ClearAllPoints()
        p:SetPoint("CENTER", cv, "TOPLEFT", m.spawns[1] / 100 * w, -m.spawns[2] / 100 * h)
        p:Show()
        -- survolé : autres points d'apparition ; patrouille en pointillés au survol, ou toujours
        -- si « Patrouilles des rares » est activé (plus pâle pour les rares non survolés)
        local showPath = hovered == r or R:Config().paths
        if hovered == r then
            for k = 3, #m.spawns, 2 do
                nd = nd + 1
                local d = getDot(nd)
                d:SetSize(8 * scale * 1.2, 8 * scale * 1.2)
                d:SetVertexColor(col[1], col[2], col[3], 0.8)
                d:ClearAllPoints(); d:SetPoint("CENTER", cv, "TOPLEFT", m.spawns[k] / 100 * w, -m.spawns[k + 1] / 100 * h)
            end
        end
        if showPath then
            local path = m.path
            local pa = (hovered == r) and 0.9 or 0.55
            for k = 1, #path - 2, 2 do
                local x1, y1, x2, y2 = path[k] / 100 * w, path[k + 1] / 100 * h, path[k + 2] / 100 * w, path[k + 3] / 100 * h
                local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
                local n = math.max(1, math.floor(len / (12 * scale)))
                for j = 0, n - 1, 2 do
                    nd = nd + 1
                    local d = getDot(nd)
                    d:SetSize(4 * scale * 1.2, 4 * scale * 1.2)
                    d:SetVertexColor(col[1], col[2], col[3], pa)
                    local t = j / n
                    d:ClearAllPoints(); d:SetPoint("CENTER", cv, "TOPLEFT", x1 + (x2 - x1) * t, -(y1 + (y2 - y1) * t))
                end
            end
        end
        end
    end
    for k = shown + 1, #pins do pins[k]:Hide() end
    for k = nd + 1, #dots do dots[k]:Hide() end
end
-- Redessin au survol : sans tout cacher d'abord (cacher le médaillon sous la souris déclenchait son OnLeave,
-- donc un nouveau redessin, et le médaillon clignotait / disparaissait). DrawRarePins place et montre les
-- médaillons utiles et cache seulement ceux en trop.
function UI:RedrawRarePins()
    if last and WorldMapFrame and WorldMapFrame:IsShown() then
        UI:DrawRarePins(unpack(last))
    end
end
R.OnChange = function() UI:RedrawRarePins() end

---------------------------------------------------------------------------
-- Liste « Rares de la zone » sur le côté de la carte
---------------------------------------------------------------------------
-- Compacte : une ligne par rare (étoile, nom, niveau ; le butin est dans l'infobulle).
-- En-tête : clic = replier / déplier ; glisser = déplacer (position gardée par rapport au coin
-- haut droit de la carte) ; clic droit = remettre en place ; croix = ne plus l'afficher
-- (réglage « Liste des rares de la zone » dans Rares > Carte et infobulle).
local panel, rows = nil, {}
local W_LIST, ROW = 200, 20
local function place()
    local cfg = R:Config()
    local parent = panel:GetParent()
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", cfg.listX or -8, cfg.listY or -8)
end
local function buildList()
    local parent = WorldMapFrame and (WorldMapFrame.ScrollContainer or WorldMapFrame)
    if not (parent and parent.GetFrameLevel) then parent = WorldMapFrame end
    if not (parent and parent.GetFrameLevel) then return end
    panel = CreateFrame("Frame", "WarbandKeeperRareList", parent)
    panel:SetWidth(W_LIST)
    panel:SetFrameLevel((parent:GetFrameLevel() or 1) + 40)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    UI:Panel(panel, 9, { C.bg[1], C.bg[2], C.bg[3], 0.88 }, C.border)
    panel.chev = UI:Icon(panel, "chevron", 10, nil, "ARTWORK")
    panel.chev:SetPoint("TOPLEFT", 9, -9)
    panel.title = UI:Text(panel, 11)
    panel.title:SetPoint("TOPLEFT", 24, -7)
    panel.title:SetText(T("Rares"))
    panel.count = UI:Text(panel, 10, C.muted)
    panel.count:SetPoint("LEFT", panel.title, "RIGHT", 6, 0)
    panel.close = UI:IconButton(panel, "close", 14, "Ne plus afficher cette liste (réactivable dans Rares > Carte et infobulle)", "accent")
    panel.close:SetPoint("TOPRIGHT", -5, -4)
    panel.close:SetScript("OnClick", function()
        R:Config().list = false
        panel:Hide()
        WK:Print(T("Liste des rares masquée : à réactiver dans Rares > Carte et infobulle."))
    end)
    panel.toggle = CreateFrame("Button", nil, panel)
    panel.toggle:SetPoint("TOPLEFT"); panel.toggle:SetPoint("TOPRIGHT", -22, 0)
    panel.toggle:SetHeight(22)
    panel.toggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    panel.toggle:RegisterForDrag("LeftButton")
    panel.toggle:SetScript("OnClick", function(_, btn)
        local cfg = R:Config()
        if btn == "RightButton" then cfg.listX, cfg.listY = nil, nil; place() return end
        cfg.listCollapsed = not cfg.listCollapsed
        UI:RedrawRarePins()
    end)
    panel.toggle:SetScript("OnDragStart", function() panel:StartMoving() end)
    panel.toggle:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        local par = panel:GetParent()
        local cfg = R:Config()
        local s1, s2 = panel:GetEffectiveScale(), par:GetEffectiveScale()
        cfg.listX = math.floor((panel:GetRight() * s1 - par:GetRight() * s2) / s2 + 0.5)
        cfg.listY = math.floor((panel:GetTop() * s1 - par:GetTop() * s2) / s2 + 0.5)
        place()
    end)
    panel.toggle:SetScript("OnEnter", function(b)
        WK.UI:TooltipOwner(b, "ANCHOR_LEFT")
        GameTooltip:SetText(T("Rares de la zone"), 1, 1, 1)
        GameTooltip:AddLine(T("Clic : replier ou déplier · glisser : déplacer · clic droit : remettre en place"), 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    panel.toggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    place()
end
local function getRow(i)
    local r = rows[i]
    if not r then
        r = CreateFrame("Button", nil, panel)
        r:SetHeight(ROW)
        r.dot = UI:Icon(r, "star", 10, nil, "ARTWORK")
        r.dot:SetPoint("LEFT", 8, 0)
        r.lvl = UI:Text(r, 10, C.muted)
        r.lvl:SetPoint("RIGHT", -8, 0)
        r.name = UI:Text(r, 11)
        r.name:SetPoint("LEFT", 22, 0)
        r.name:SetPoint("RIGHT", r.lvl, "LEFT", -4, 0)
        r.name:SetJustifyH("LEFT")
        r.name:SetWordWrap(false)
        r.hl = UI:Rounded(r, 5, 0, "BACKGROUND", 1)
        r:SetScript("OnEnter", function(s)
            s.hl:SetColor(unpack(C.hover)); s.hl:Show()
            WK.UI:TooltipOwner(s, "ANCHOR_LEFT")
            GameTooltip:SetText(R:Name(s.r), C.rare[1], C.rare[2], C.rare[3])
            tooltipLines(GameTooltip, s.r)
            GameTooltip:AddLine(T("Clic : guidage vers ce rare"), 0.5, 0.5, 0.5)
            GameTooltip:Show()
            hovered = s.r; UI:RedrawRarePins()
        end)
        r:SetScript("OnLeave", function(s) s.hl:Hide(); GameTooltip:Hide(); hovered = nil; UI:RedrawRarePins() end)
        r:SetScript("OnClick", function(s) R:GuideTo(s.r) end)
        r.hl:Hide()
        rows[i] = r
    end
    return r
end

function UI:SyncRareList(mapID, list)
    local cfg = R:Config()
    if not cfg.list or not list or #list == 0 then
        if panel then panel:Hide() end
        return
    end
    if not panel then buildList() end
    if not panel then return end
    local me = WK:CharKey()
    local left = 0
    for _, r in ipairs(list) do if not R:Killed(r.id, me) then left = left + 1 end end
    panel.count:SetText(left .. " / " .. #list)
    panel.chev:SetRotation(cfg.listCollapsed and math.pi / 2 or 0)
    panel.chev:SetVertexColor(unpack(C.muted))
    for _, rw in ipairs(rows) do rw:Hide() end
    local y = -24
    if not cfg.listCollapsed then
        for i, r in ipairs(list) do
            if i > 12 then break end
            local rw = getRow(i)
            rw.r = r
            rw:ClearAllPoints(); rw:SetPoint("TOPLEFT", 3, y); rw:SetPoint("TOPRIGHT", -3, y)
            local col = r.elite and C.gold or C.rare
            local dead = R:Killed(r.id, me) ~= nil
            rw.dot:SetVertexColor(unpack(dead and C.dim or col))
            rw.name:SetText(R:Name(r))
            rw.name:SetTextColor(unpack(dead and C.dim or C.text))
            rw.lvl:SetText(dead and T("tué") or tostring(r.min))
            rw:Show()
            y = y - ROW
        end
        y = y - 4
    end
    panel:SetHeight(-y + 2)
    panel:Show()
end

-- Carte fermée ou autre carte sans rares : la liste se cache avec elle
if WorldMapFrame then
    WorldMapFrame:HookScript("OnHide", function() if panel then panel:Hide() end end)
end

---------------------------------------------------------------------------
-- Infobulle d'un rare (survol du monstre ou de sa plaque)
---------------------------------------------------------------------------
local function onUnitTooltip(tooltip)
    if tooltip ~= GameTooltip or not R:Config().tooltip or not WK:FeatureOn("rares") then return end
    local unit = select(2, tooltip:GetUnit())
    unit = R.Readable(unit)
    if not unit then return end
    local id = R.NpcID(unit)
    local r = id and R:Get(id)
    if not r then return end
    tooltip:AddLine(" ")
    tooltip:AddLine(WK:Tag())
    tooltipLines(tooltip, r)
    tooltip:Show()
end
if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tt) pcall(onUnitTooltip, tt) end)
elseif GameTooltip then
    GameTooltip:HookScript("OnTooltipSetUnit", function(tt) pcall(onUnitTooltip, tt) end)
end
