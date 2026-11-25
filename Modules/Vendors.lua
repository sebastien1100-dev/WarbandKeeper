local _, WK = ...
local M = WK:NewModule("Vendors")
local T = function(s) return WK.T(s) end

-- Où acheter un objet chez un marchand : prix vus par tes persos (WK.DB.global.vendorSeen, relevés à MERCHANT_SHOW
-- dans UI/AuctionTabs.lua), puis marchands vus dans WoW Forever par les joueurs de ForeverDB
-- (Modules/ForeverVendorsDB.lua, généré par tools/gen_foreverdb.py ; « Data from ForeverDB.net
-- (https://foreverdb.net) », mention obligatoire partout où ces données sont montrées : `M.CREDIT`).
-- WK.FVendorNpc[pnj] = { carte, x, y, camp (1 Alliance, 2 Horde, 3 les deux), nom anglais }
-- WK.FVendorSells[objet] = "pnj:prix,pnj:prix" (prix d'un objet, en cuivre)

M.CREDIT = "foreverdb.net"

local function myFaction()
    local f = _G.UnitFactionGroup and _G.UnitFactionGroup("player")
    return f == "Horde" and 2 or (f == "Alliance" and 1) or nil
end

-- un PNJ de ForeverDB (marchand, ou maître / marchand de recettes de Modules/ForeverProfDB.lua)
local function npcEntry(npc)
    return (WK.FVendorNpc and WK.FVendorNpc[npc]) or (WK.FProfNpc and WK.FProfNpc[npc])
end
M.NpcEntry = npcEntry

-- nom du PNJ : français de QuestieDB si connu, sinon celui de ForeverDB
function M.NpcName(npc)
    local v = npcEntry(npc)
    if not v then return "#" .. tostring(npc) end
    return (WK.Lang() == "frFR" and v[6]) or v[5] or ("#" .. tostring(npc))
end

local function zoneName(map)
    local CM = _G.C_Map
    local info = map and CM and CM.GetMapInfo and CM.GetMapInfo(map)
    return info and info.name or nil
end
M.ZoneName = zoneName

-- Marchands (ForeverDB) qui vendent l'objet, pour ton camp : { npc, name, map, x, y (0-1), price, zone },
-- le plus proche d'abord (même continent), sinon le moins cher. Gardé par objet le temps de la séance.
local cache = {}
function M.Sources(_, id)
    if not id then return {} end
    local raw = WK.FVendorSells and WK.FVendorSells[id]
    if not raw then return {} end
    local fac = myFaction()
    local list = cache[id]
    if not list then
        list = {}
        for npc, p in raw:gmatch("(%d+):(%d+)") do
            npc, p = tonumber(npc), tonumber(p)
            local v = WK.FVendorNpc and WK.FVendorNpc[npc]
            if v and (not fac or v[4] == 3 or v[4] == fac) then
                list[#list + 1] = { npc = npc, map = v[1], x = v[2] / 100, y = v[3] / 100, price = p }
            end
        end
        cache[id] = list
    end
    return M.ByDistance(list)
end

-- liste d'entrées { map, x, y (0-1), price? } rangée du plus proche (même continent) au plus loin, puis par prix
function M.ByDistance(list)
    local G = WK.modules.Guide
    local pos = G and G.PlayerPos and G:PlayerPos()
    for _, s in ipairs(list) do
        s.dist = nil
        if pos and G.ToWorld then
            local cont, wx, wy = G.ToWorld(s.map, s.x, s.y)
            if cont then
                s.dist = G:Vector(pos, { map = s.map, x = s.x, y = s.y, cont = cont, wx = wx, wy = wy })
            end
        end
    end
    table.sort(list, function(a, b)
        if (a.dist ~= nil) ~= (b.dist ~= nil) then return a.dist ~= nil end
        if a.dist and b.dist and a.dist ~= b.dist then return a.dist < b.dist end
        return (a.price or 0) < (b.price or 0)
    end)
    return list
end

-- Prix d'achat chez un marchand : le tien (vu par un de tes persos) d'abord, sinon le moins cher de ForeverDB.
-- Rend prix, source (« seen » / « fdb »), nom du marchand, entrée de Sources (fdb seulement).
function M:BuyPrice(id)
    local seen = WK.DB and WK.DB.global.vendorSeen and WK.DB.global.vendorSeen[id]
    if seen and seen.p and seen.p > 0 then return seen.p, "seen", seen.npc end
    local best
    for _, s in ipairs(self:Sources(id)) do
        if not best or s.price < best.price then best = s end
    end
    if best then return best.price, "fdb", M.NpcName(best.npc), best end
end

-- Texte court : « Nom (Zone) » du marchand le plus proche qui le vend (ForeverDB)
function M:Where(id)
    local s = self:Sources(id)[1]
    if not s then return nil end
    local z = zoneName(s.map)
    return M.NpcName(s.npc) .. (z and (" (" .. z .. ")") or ""), s
end

-- Guidage vers une entrée { npc, map, x, y } (marchand, maître)
function M.GuideToEntry(_, s, kind)
    local G = WK.modules.Guide
    if not (s and G and G.Start) then return false end
    local name = M.NpcName(s.npc)
    local t = { map = s.map, x = s.x, y = s.y, e = { s.x * 100, s.y * 100, 0, nil, nil, name, name, zoneName(s.map) } }
    if G.ToWorld then t.cont, t.wx, t.wy = G.ToWorld(s.map, s.x, s.y) end
    G:Start(t, name, kind or "vendor")
    return true
end

-- Guidage vers le marchand le plus proche qui vend l'objet
function M:GuideTo(id)
    return self:GuideToEntry(self:Sources(id)[1], "vendor")
end

-- Lignes d'infobulle d'un objet vendu par des marchands (réglage settings.ui.tooltipVendors)
function M:AddTooltip(tt, id)
    local st = WK.DB.global.settings.ui
    if st.tooltipVendors == false or not id then return end
    local list = self:Sources(id)
    if #list == 0 then return end
    local s = list[1]
    local z = zoneName(s.map)
    local more = #list > 1 and ("  " .. string.format(T("(+%d autres)"), #list - 1)) or ""
    tt:AddDoubleLine(T("Vendu par") .. " " .. M.NpcName(s.npc) .. (z and (" · " .. z) or "") .. more,
        WK:FormatMoney(s.price), 0.6, 0.8, 1, 1, 1, 1)
    tt:AddLine(T("Marchands vus dans WoW Forever · ") .. M.CREDIT, 0.45, 0.45, 0.45)
end

-- Recettes et maîtres de métier (Modules/ForeverProfDB.lua) :
-- WK.FRecipes[sort] = "métier|apprise à|prix du maître|prix vu|objet de recette|maîtres|pnj:prix,…"
local function entries(ids, prices)
    local fac, out = myFaction(), {}
    for _, npc in ipairs(ids) do
        local v = npcEntry(npc)
        if v and (not fac or v[4] == 3 or v[4] == fac) then
            out[#out + 1] = { npc = npc, map = v[1], x = v[2] / 100, y = v[3] / 100, price = prices and prices[npc] }
        end
    end
    return out
end

-- Comment s'apprend une recette (n° de sort) : { prof, learnAt, cost, costSeen, item, trainers, vendors }, maîtres et
-- marchands de ton camp, du plus proche au plus loin ; nil si ForeverDB ne la connaît pas.
local rcache = {}
function M.Recipe(_, spell)
    local raw = spell and WK.FRecipes and WK.FRecipes[spell]
    if not raw then return nil end
    local r = rcache[spell]
    if not r then
        local p, at, cost, seen, item, tr, vd = raw:match("^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|([^|]*)|(.*)$")
        if not p then return nil end
        local tids, vids, prices = {}, {}, {}
        for n in tr:gmatch("%d+") do tids[#tids + 1] = tonumber(n) end
        for n, pr in vd:gmatch("(%d+):(%d+)") do
            n = tonumber(n); vids[#vids + 1] = n; prices[n] = tonumber(pr)
        end
        r = { prof = WK.FProfSlugs and WK.FProfSlugs[tonumber(p)], learnAt = tonumber(at), cost = tonumber(cost),
            costSeen = seen == "1", item = tonumber(item) ~= 0 and tonumber(item) or nil,
            trainers = entries(tids), vendors = entries(vids, prices) }
        rcache[spell] = r
    end
    M.ByDistance(r.trainers)
    M.ByDistance(r.vendors)
    return r
end

-- Maître le plus proche d'un métier (slug ForeverDB) qui enseigne au moins jusqu'à `skill` (0 = inconnu, gardé
-- en dernier recours)
function M.ProfTrainer(_, slug, skill)
    local list = WK.FProfTrainers and WK.FProfTrainers[slug]
    if not list then return nil end
    local ok, any = {}, {}
    for _, t in ipairs(list) do
        any[#any + 1] = t[1]
        if t[2] == 0 or t[2] >= (skill or 0) then ok[#ok + 1] = t[1] end
    end
    return M.ByDistance(entries(#ok > 0 and ok or any))[1]
end

-- Texte « Nom (Zone) » d'une entrée
function M.EntryText(_, s)
    if not s then return nil end
    local z = zoneName(s.map)
    return M.NpcName(s.npc) .. (z and (" (" .. z .. ")") or "")
end
