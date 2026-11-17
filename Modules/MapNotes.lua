local ADDON_NAME, WK = ...
local M = WK:NewModule("MapNotes")
local T = function(s) return WK.T(s) end

-- Notes de carte perso : posées sur la carte du monde (UI/MapNotes.lua), vues par tous les persos du
-- compte, jamais envoyées. Hors profils (ce sont des données, pas des réglages).
--   WK.DB.global.mapNotes = { list = { note }, cfg = { place, size, labels } }
--   note = { id, map, x, y (0-1 sur la carte), cont, wx, wy (monde, pour la minicarte), icon, color,
--            title, text, mini (aussi sur la minicarte), label (nom toujours affiché), at }
M.ICONS = { "star", "fish", "logo", "bang", "home", "mail", "hammer", "skull", "notes" }
-- couleurs proposées (données de la note, pas du thème) ; "accent" suit l'apparence
M.COLORS = {
    { key = "blue", rgb = { 0.36, 0.78, 1 } }, { key = "accent" }, { key = "yellow", rgb = { 0.96, 0.77, 0.26 } },
    { key = "green", rgb = { 0.49, 0.85, 0.34 } }, { key = "red", rgb = { 0.89, 0.38, 0.38 } },
    { key = "purple", rgb = { 0.71, 0.55, 1 } }, { key = "white", rgb = { 0.87, 0.87, 0.87 } },
}
local DEFAULTS = { place = "alt", size = 18, labels = false }

local function db()
    local g = WK.DB.global
    g.mapNotes = g.mapNotes or {}
    local d = g.mapNotes
    d.list = d.list or {}
    d.cfg = d.cfg or {}
    for k, v in pairs(DEFAULTS) do if d.cfg[k] == nil then d.cfg[k] = v end end
    return d
end
function M:Config() return db().cfg end
function M:List() return db().list end

function M:Color(key)
    for _, c in ipairs(M.COLORS) do
        if c.key == key then
            if c.rgb then return c.rgb end
            local r, g, b = WK.UI:Accent()
            return { r, g, b }
        end
    end
    return M.COLORS[1].rgb
end

function M:ForMap(mapID)
    local out = {}
    for _, n in ipairs(db().list) do if n.map == mapID then table.insert(out, n) end end
    return out
end
function M:Get(id)
    for _, n in ipairs(db().list) do if n.id == id then return n end end
end

function M:ZoneName(mapID)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    return info and info.name or ("#" .. tostring(mapID))
end
function M:Coords(n) return (string.format("%.1f / %.1f", n.x * 100, n.y * 100):gsub("%.", ",")) end

local function changed()
    if WK.UI and WK.UI.RefreshMapNotes then WK.UI:RefreshMapNotes() end
    WK:NotifyChanged()
end

-- Nouvelle note (ou mise à jour si fields.id existe)
function M:Save(fields)
    local d = db()
    local n = fields.id and self:Get(fields.id)
    if not n then
        d.nextId = (d.nextId or 0) + 1
        n = { id = d.nextId, at = time() }
        table.insert(d.list, n)
    end
    for k, v in pairs(fields) do n[k] = v end
    if n.map and n.x and (not n.cont or fields.x) then
        n.cont, n.wx, n.wy = WK.modules.Guide.ToWorld(n.map, n.x, n.y)
    end
    n.title = (n.title and n.title ~= "") and n.title or T("Note")
    changed()
    return n
end

function M:Delete(id)
    local list = db().list
    for i = #list, 1, -1 do if list[i].id == id then table.remove(list, i) end end
    changed()
end

-- Guider jusqu'à la note (flèche et trajet de Modules/Guide.lua)
function M:GuideTo(n)
    local G = WK.modules.Guide
    local t = { map = n.map, x = n.x, y = n.y, cont = n.cont, wx = n.wx, wy = n.wy,
                e = { n.x * 100, n.y * 100, 0, nil, nil, n.title, n.title, T("Note de carte") } }
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    G:Start(t, "Note de carte", "note")
end

-- Liste rangée par zone, filtrée par un texte (titre, note, zone)
function M:Grouped(filter)
    filter = filter and filter:lower() or ""
    local zones, order = {}, {}
    for _, n in ipairs(db().list) do
        local zone = self:ZoneName(n.map)
        local hay = ((n.title or "") .. " " .. (n.text or "") .. " " .. zone):lower()
        if filter == "" or hay:find(filter, 1, true) then
            if not zones[zone] then zones[zone] = {}; table.insert(order, zone) end
            table.insert(zones[zone], n)
        end
    end
    table.sort(order)
    local out = {}
    for _, z in ipairs(order) do
        table.sort(zones[z], function(a, b) return (a.title or "") < (b.title or "") end)
        table.insert(out, { zone = z, notes = zones[z] })
    end
    return out
end
