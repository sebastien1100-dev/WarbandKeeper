local ADDON_NAME, WK = ...
local M = WK:NewModule("Gear")

-- Fiche de personnage (UI/CharacterSheet.lua) : ce qu'on relève sur le perso connecté, pour le revoir
-- depuis n'importe quel autre perso.
--   c.gear    = { [emplacement 1-19] = lien de l'objet }
--   c.stats   = { str, agi, sta, int, spi, armor, ap, rap, crit, rcrit, hit, dodge, parry, block,
--                 spell, heal, scrit, res = { holy, fire, nature, frost, shadow, arcane } }
--   c.talents = { { name, points, list = { { nom, icône, rangée, colonne, rang, rang max } } }, ... } (arbres de talents), c.talentFree, c.talentsAt
--   c.reps    = { { name, standing (1-8), cur, max, header = true? }, ... }
--   c.sheetAt = date du relevé
-- Relevé à la connexion, puis à chaque changement d'équipement, de stats ou de réputation (regroupé).
-- Toute valeur que le jeu masque (restrictions) est ignorée : la précédente reste.
local T = function(s) return WK.T(s) end
local SLOTS = 19

local function readable(v)
    local Q = WK.modules.QoL
    if Q and Q.Readable then v = Q.Readable(v) end
    return v
end
local function num(v)
    v = readable(v)
    return type(v) == "number" and v or nil
end
local function call(f, ...)
    if not f then return end
    local r = { pcall(f, ...) }
    if not r[1] then return end
    return select(2, unpack(r))
end

local function scanGear(c)
    if not GetInventoryItemLink then return end
    local gear = {}
    for slot = 1, SLOTS do
        local link = readable(call(GetInventoryItemLink, "player", slot))
        if type(link) == "string" then gear[slot] = link end
    end
    c.gear = gear
end

local function scanStats(c)
    local s = c.stats or {}
    local keys = { "str", "agi", "sta", "int", "spi" }
    for i, k in ipairs(keys) do
        local _, eff = call(UnitStat, "player", i)
        s[k] = num(eff) or s[k]
    end
    local _, armor = call(UnitArmor, "player")
    s.armor = num(armor) or s.armor
    local base, pos, neg = call(UnitAttackPower, "player")
    if num(base) then s.ap = num(base) + (num(pos) or 0) + (num(neg) or 0) end
    base, pos, neg = call(UnitRangedAttackPower, "player")
    if num(base) then s.rap = num(base) + (num(pos) or 0) + (num(neg) or 0) end
    s.crit = num(call(GetCritChance)) or s.crit
    s.rcrit = num(call(GetRangedCritChance)) or s.rcrit
    s.hit = num(call(GetHitModifier)) or s.hit
    s.dodge = num(call(GetDodgeChance)) or s.dodge
    s.parry = num(call(GetParryChance)) or s.parry
    s.block = num(call(GetBlockChance)) or s.block
    -- sorts : meilleure école (2 = sacré … 7 = arcanes)
    local spell, scrit = nil, nil
    for school = 2, 7 do
        local d = num(call(GetSpellBonusDamage, school))
        if d and (not spell or d > spell) then spell = d end
        local cr = num(call(GetSpellCritChance, school))
        if cr and (not scrit or cr > scrit) then scrit = cr end
    end
    s.spell, s.scrit = spell or s.spell, scrit or s.scrit
    s.heal = num(call(GetSpellBonusHealing)) or s.heal
    -- résistances : 1 sacré, 2 feu, 3 nature, 4 givre, 5 ombre, 6 arcanes
    s.res = s.res or {}
    local RES = { "holy", "fire", "nature", "frost", "shadow", "arcane" }
    for i, k in ipairs(RES) do
        local _, total = call(UnitResistance, "player", i)
        s.res[k] = num(total) or s.res[k]
    end
    c.stats = s
end

-- Talents du système de traits (WoW Forever : C_ClassTalents / C_Traits) : configuration active, nœuds de l'arbre
-- regroupés par sous-arbre (ou, à défaut, en colonnes d'après leur position), rangées et colonnes déduites
-- des positions. Rend { { name, points, list = { { nom, icône, rangée, colonne, rang, max, sort } } } }
local function traitConfig()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo) then return nil end
    local id = num(call(C_ClassTalents.GetActiveConfigID))
    if not id then return nil end
    return id, call(C_Traits.GetConfigInfo, id)
end
M.TraitConfig = traitConfig
local function nodeData(cfgID, nodeID)
    local n = call(C_Traits.GetNodeInfo, cfgID, nodeID)
    if type(n) ~= "table" or n.isVisible == false then return nil end
    local entry = (n.activeEntry and n.activeEntry.entryID) or (n.entryIDs and n.entryIDs[1])
    local name, icon, spell
    if entry and C_Traits.GetEntryInfo then
        local e = call(C_Traits.GetEntryInfo, cfgID, entry)
        local def = e and e.definitionID and C_Traits.GetDefinitionInfo and call(C_Traits.GetDefinitionInfo, e.definitionID)
        if def then
            spell = num(def.spellID) or num(def.overriddenSpellID)
            name = readable(def.overrideName)
            icon = readable(def.overrideIcon)
            if spell and (not name or name == "" or not icon) then
                local sn, si = WK.SpellInfo(spell)
                if not name or name == "" then name = sn end
                icon = icon or si
            end
        end
    end
    if type(name) ~= "string" then return nil end
    return { node = nodeID, name = name, icon = icon, spell = spell, x = num(n.posX) or 0, y = num(n.posY) or 0,
        rank = num(n.currentRank) or num(n.activeRank) or 0, max = num(n.maxRanks) or 1, sub = num(n.subTreeID) }
end
-- Noms des trois arbres par classe (ordre classique de gauche à droite), quand le jeu ne les donne pas
local TREE_NAMES = {
    WARRIOR = { "Armes", "Fureur", "Protection" }, PALADIN = { "Sacré", "Protection", "Vindicte" },
    HUNTER = { "Maîtrise des bêtes", "Précision", "Survie" }, ROGUE = { "Assassinat", "Combat", "Finesse" },
    PRIEST = { "Discipline", "Sacré", "Ombre" }, SHAMAN = { "Élémentaire", "Amélioration", "Restauration" },
    MAGE = { "Arcanes", "Feu", "Givre" }, WARLOCK = { "Affliction", "Démonologie", "Destruction" },
    DRUID = { "Équilibre", "Combat farouche", "Restauration" },
}
local function scanTraits(c)
    local cfgID, cfg = traitConfig()
    if not cfgID or type(cfg) ~= "table" or not C_Traits.GetTreeNodes then return false end
    local nodes = {}
    for _, treeID in ipairs(cfg.treeIDs or {}) do
        for _, nodeID in ipairs(call(C_Traits.GetTreeNodes, treeID) or {}) do
            local d = nodeData(cfgID, nodeID)
            if d then d.tree = treeID; table.insert(nodes, d) end
        end
        if C_Traits.GetTreeCurrencyInfo then
            local cur = call(C_Traits.GetTreeCurrencyInfo, cfgID, treeID, false)
            if type(cur) == "table" and cur[1] then c.talentFree = num(cur[1].quantity) end
        end
    end
    if #nodes == 0 then return false end
    -- groupes : sous-arbres s'il y en a, sinon arbres, sinon colonnes séparées par un grand écart de position
    local key = "tree"
    local subs = {}
    for _, d in ipairs(nodes) do if d.sub then subs[d.sub] = true end end
    if next(subs) then key = "sub" end
    local groups, order = {}, {}
    local trees = {}
    for _, d in ipairs(nodes) do trees[d.tree] = true end
    local nTrees = 0
    for _ in pairs(trees) do nTrees = nTrees + 1 end
    if key == "tree" and nTrees == 1 then
        -- un seul arbre : trois arbres côte à côte (comme toutes les classes), coupés sur les grands écarts
        -- horizontaux ; un petit bloc isolé (un talent seul) rejoint le bloc le plus proche
        local xs, seen = {}, {}
        for _, d in ipairs(nodes) do if not seen[d.x] then seen[d.x] = true; xs[#xs + 1] = d.x end end
        table.sort(xs)
        local gaps = {}
        for i = 2, #xs do gaps[#gaps + 1] = { size = xs[i] - xs[i - 1], at = (xs[i] + xs[i - 1]) / 2 } end
        local sizes = {}
        for i, g in ipairs(gaps) do sizes[i] = g.size end
        table.sort(sizes)
        local typical = sizes[math.max(1, math.floor(#sizes / 2))] or 1
        -- blocs : [début, fin] en x
        local blocks, startX, lastX = {}, xs[1], xs[1]
        for i = 2, #xs do
            if xs[i] - lastX > typical * 2.5 then blocks[#blocks + 1] = { lo = startX, hi = lastX }; startX = xs[i] end
            lastX = xs[i]
        end
        if startX then blocks[#blocks + 1] = { lo = startX, hi = lastX } end
        local function count(bk) local n = 0 for _, d in ipairs(nodes) do if d.x >= bk.lo and d.x <= bk.hi then n = n + 1 end end return n end
        -- trop de blocs : le plus petit rejoint son voisin le plus proche
        while #blocks > 3 do
            local mi, mn = 1, math.huge
            for i, bk in ipairs(blocks) do local n = count(bk); if n < mn then mi, mn = i, n end end
            local bk = blocks[mi]
            local left, right = blocks[mi - 1], blocks[mi + 1]
            local into
            if left and right then into = (bk.lo - left.hi <= right.lo - bk.hi) and mi - 1 or mi + 1 else into = left and mi - 1 or mi + 1 end
            local t = blocks[into]
            t.lo, t.hi = math.min(t.lo, bk.lo), math.max(t.hi, bk.hi)
            table.remove(blocks, mi)
        end
        -- pas assez de blocs : on coupe sur les plus grands écarts
        if #blocks < 3 and #gaps >= 2 then
            table.sort(gaps, function(p, q) return p.size > q.size end)
            local cuts = { gaps[1].at, gaps[2].at }
            table.sort(cuts)
            blocks = { { lo = -math.huge, hi = cuts[1] }, { lo = cuts[1], hi = cuts[2] }, { lo = cuts[2], hi = math.huge } }
        end
        for _, d in ipairs(nodes) do
            local g = #blocks
            for i, bk in ipairs(blocks) do if d.x >= bk.lo and d.x <= bk.hi then g = i break end end
            d.group = g
        end
    else
        for _, d in ipairs(nodes) do d.group = d[key] end
    end
    for _, d in ipairs(nodes) do
        if not groups[d.group] then groups[d.group] = { list = {} }; table.insert(order, d.group) end
        table.insert(groups[d.group].list, d)
    end
    table.sort(order, function(a, b)
        local ax, bx = math.huge, math.huge
        for _, d in ipairs(groups[a].list) do ax = math.min(ax, d.x) end
        for _, d in ipairs(groups[b].list) do bx = math.min(bx, d.x) end
        return ax < bx
    end)
    local out = {}
    for i, gk in ipairs(order) do
        local g = groups[gk]
        -- rangées et colonnes : positions distinctes triées
        local xs, ys, xi, yi = {}, {}, {}, {}
        for _, d in ipairs(g.list) do
            if not xi[d.x] then xi[d.x] = true; xs[#xs + 1] = d.x end
            if not yi[d.y] then yi[d.y] = true; ys[#ys + 1] = d.y end
        end
        table.sort(xs); table.sort(ys)
        for k, v in ipairs(xs) do xi[v] = k end
        for k, v in ipairs(ys) do yi[v] = k end
        local name
        if key == "sub" and C_Traits.GetSubTreeInfo then
            local st = call(C_Traits.GetSubTreeInfo, cfgID, gk)
            name = st and readable(st.name)
        end
        if type(name) ~= "string" and #order == 3 then name = TREE_NAMES[c.class or ""] and T(TREE_NAMES[c.class][i]) end
        local tree = { name = type(name) == "string" and name or string.format(T("Arbre %d"), i), points = 0, list = {}, cols = #xs }
        for _, d in ipairs(g.list) do
            tree.points = tree.points + d.rank
            table.insert(tree.list, { d.name, d.icon, yi[d.y], xi[d.x], d.rank, d.max, d.spell, d.node })
        end
        table.insert(out, tree)
    end
    if WK.modules.TalentPlan then pcall(WK.modules.TalentPlan.Record, WK.modules.TalentPlan, c, c.talents, out) end
    c.talents = out
    c.talentsAt = time()
    if WK.modules.TalentPlan then pcall(WK.modules.TalentPlan.CheckAlert, WK.modules.TalentPlan) end
    return true
end

-- Arbres de talents : nom et points (deux formes de GetTalentTabInfo selon le client)
local function scanTalents(c)
    if not (GetNumTalentTabs and GetTalentTabInfo) then
        pcall(scanTraits, c)
        return
    end
    local n = num(call(GetNumTalentTabs)) or 0
    local out = {}
    for i = 1, n do
        local r = { pcall(GetTalentTabInfo, i) }
        if r[1] then
            local name, points
            if type(r[2]) == "number" then name, points = r[3], r[6] else name, points = r[2], r[4] end
            name, points = readable(name), readable(points)
            if type(name) == "string" then
                local tree = { name = name, points = type(points) == "number" and points or 0 }
                -- talents de l'arbre : { nom, icône, rangée, colonne, rang, rang max }
                if GetNumTalents and GetTalentInfo then
                    tree.list = {}
                    for j = 1, num(call(GetNumTalents, i)) or 0 do
                        local ok, tn, ic, tier, col, rank, maxRank = pcall(GetTalentInfo, i, j)
                        tn, ic, tier, col, rank, maxRank = readable(tn), readable(ic), num(tier), num(col), num(rank), num(maxRank)
                        if ok and type(tn) == "string" and tier and col then
                            table.insert(tree.list, { tn, ic, tier, col, rank or 0, maxRank or 1 })
                        end
                    end
                end
                table.insert(out, tree)
            end
        end
    end
    if #out > 0 then
        if WK.modules.TalentPlan then pcall(WK.modules.TalentPlan.Record, WK.modules.TalentPlan, c, c.talents, out) end
        c.talents = out
        local free = (UnitCharacterPoints and num(call(UnitCharacterPoints, "player")))
            or (GetUnspentTalentPoints and num(call(GetUnspentTalentPoints)))
        c.talentFree = free
        c.talentsAt = time()
    end
end

local function scanReps(c)
    local out = {}
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        local n = num(call(C_Reputation.GetNumFactions)) or 0
        for i = 1, n do
            local d = call(C_Reputation.GetFactionDataByIndex, i)
            if type(d) == "table" and type(readable(d.name)) == "string" then
                local mn, mx, v = num(d.currentReactionThreshold) or 0, num(d.nextReactionThreshold) or 1, num(d.currentStanding) or 0
                table.insert(out, { name = d.name, standing = num(d.reaction) or 4, cur = v - mn, max = math.max(1, mx - mn),
                    header = (d.isHeader and not d.isHeaderWithRep) or nil })
            end
        end
    elseif GetNumFactions and GetFactionInfo then
        local n = num(call(GetNumFactions)) or 0
        for i = 1, n do
            local name, _, standing, bMin, bMax, bVal, _, _, isHeader, _, hasRep = call(GetFactionInfo, i)
            name = readable(name)
            if type(name) == "string" then
                bMin, bMax, bVal = num(bMin) or 0, num(bMax) or 1, num(bVal) or 0
                table.insert(out, { name = name, standing = num(standing) or 4, cur = bVal - bMin, max = math.max(1, bMax - bMin),
                    header = (readable(isHeader) and not readable(hasRep)) or nil })
            end
        end
    end
    if #out > 0 then c.reps = out end
end

function M:Scan(what)
    local c = WK.DB:Me()
    if not c then return end
    if not what or what.gear then scanGear(c) end
    if not what or what.stats then scanStats(c) end
    if not what or what.talents then scanTalents(c) end
    if not what or what.reps then scanReps(c) end
    c.sheetAt = time()
    WK:NotifyChanged()
end

-- Regroupe les évènements rapprochés en un seul relevé
local pending
local function later(part)
    if pending then
        if part then for k in pairs(part) do pending[k] = true end else pending.all = true end
        return
    end
    pending = part and {} or { all = true }
    if part then for k in pairs(part) do pending[k] = true end end
    C_Timer.After(1, function()
        local p = pending
        pending = nil
        M:Scan(not p.all and p or nil)
    end)
end

WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(3, function() later() end) end)
WK:On("PLAYER_EQUIPMENT_CHANGED", function() later({ gear = true, stats = true }) end)
WK:On("UNIT_INVENTORY_CHANGED", function(unit) if unit == "player" then later({ gear = true }) end end)
WK:On("UNIT_STATS", function(unit) if unit == "player" then later({ stats = true }) end end)
WK:On("UNIT_RESISTANCES", function(unit) if unit == "player" then later({ stats = true }) end end)
WK:On("CHARACTER_POINTS_CHANGED", function() later({ talents = true }) end)
-- les talents ne sont pas toujours prêts à l'entrée dans le monde : relevés aussi quand le jeu les annonce
WK:On("PLAYER_TALENT_UPDATE", function() later({ talents = true }) end)
WK:On("SPELLS_CHANGED", function()
    local c = WK.DB:Me()
    if c and not (c.talents and c.talents[1] and c.talents[1].list) then later({ talents = true }) end
end)

-- Diagnostic (/wk talents) : ce que le jeu répond aux fonctions de talents
function M:TalentDiag()
    local out = {}
    local function show(v) v = readable(v); return type(v) == "string" and ('"' .. v .. '"') or tostring(v) end
    local function add(s) table.insert(out, s) end
    add("GetNumTalentTabs : " .. tostring(GetNumTalentTabs ~= nil) .. " = " .. show(call(GetNumTalentTabs)))
    if GetTalentTabInfo then
        local r = { pcall(GetTalentTabInfo, 1) }
        local parts = {}
        for i = 1, math.min(#r, 9) do parts[i] = show(r[i]) end
        add("GetTalentTabInfo(1) : " .. table.concat(parts, ", "))
    else add("GetTalentTabInfo : absent") end
    add("GetNumTalents(1) : " .. tostring(GetNumTalents ~= nil) .. " = " .. show(call(GetNumTalents, 1)))
    if GetTalentInfo then
        local r = { pcall(GetTalentInfo, 1, 1) }
        local parts = {}
        for i = 1, math.min(#r, 8) do parts[i] = show(r[i]) end
        add("GetTalentInfo(1, 1) : " .. table.concat(parts, ", "))
    else add("GetTalentInfo : absent") end
    add("UnitCharacterPoints : " .. show(call(UnitCharacterPoints, "player")) .. " · GetUnspentTalentPoints : " .. show(call(GetUnspentTalentPoints)))
    add("GetNumSpecializations : " .. show(call(GetNumSpecializations)) .. " · GetSpecialization : " .. show(call(GetSpecialization)))
    add("C_ClassTalents : " .. tostring(C_ClassTalents ~= nil) .. " · C_Traits : " .. tostring(C_Traits ~= nil) .. " · C_SpecializationInfo : " .. tostring(C_SpecializationInfo ~= nil))
    local cfgID, cfg = traitConfig()
    add("configuration active : " .. tostring(cfgID) .. " · arbres : " .. (type(cfg) == "table" and cfg.treeIDs and table.concat(cfg.treeIDs, ", ") or "?"))
    if cfgID and type(cfg) == "table" and cfg.treeIDs and cfg.treeIDs[1] and C_Traits.GetTreeNodes then
        local ids = call(C_Traits.GetTreeNodes, cfg.treeIDs[1]) or {}
        add("nœuds du 1er arbre : " .. #ids)
        local n1 = ids[1] and call(C_Traits.GetNodeInfo, cfgID, ids[1])
        if type(n1) == "table" then
            add(string.format("1er nœud : x %s, y %s, rang %s/%s, sous-arbre %s, type %s, visible %s",
                show(n1.posX), show(n1.posY), show(n1.currentRank), show(n1.maxRanks), show(n1.subTreeID), show(n1.type), show(n1.isVisible)))
        end
        local d = ids[1] and nodeData(cfgID, ids[1])
        if d then add("1er talent : " .. d.name .. " (sort " .. tostring(d.spell) .. ")") end
    end
    local fr = {}
    for _, name in ipairs({ "PlayerSpellsFrame", "ClassTalentFrame", "PlayerTalentFrame", "TalentFrame" }) do
        local f = _G[name]
        if f then
            local sub = f.TalentsFrame or f.TalentsTab or f
            table.insert(fr, name .. (sub.GetTalentButtonByNodeID and " (boutons : oui)" or " (boutons : non)"))
        end
    end
    add("fenêtre des talents du jeu : " .. (#fr > 0 and table.concat(fr, ", ") or "pas encore chargée (ouvre-la puis retape la commande)"))
    add("placer un point : " .. tostring(C_Traits and C_Traits.PurchaseRank ~= nil) .. " · valider : " .. tostring(C_Traits and C_Traits.CommitConfig ~= nil))
    local c = WK.DB:Me()
    add("relevé : " .. (c and c.talents and (#c.talents .. " arbre(s), détail : " .. tostring(c.talents[1] and c.talents[1].list and #c.talents[1].list)) or "aucun"))
    return out
end
WK:On("UPDATE_FACTION", function() later({ reps = true }) end)
WK:On("PLAYER_LEVEL_UP", function() later() end)


---------------------------------------------------------------------------
-- Builds de talents (onglet Talents de la fiche) : WK.DB.global.talentBuilds[perso] = { { name, at, level, trees } }
-- trees = copie des arbres relevés (mêmes champs que c.talents). Comparaison talent par talent (n° de nœud,
-- sinon place dans l'arbre), code de partage, application des points libres (perso connecté, hors combat).
---------------------------------------------------------------------------
local function buildStore(key)
    local g = WK.DB.global
    g.talentBuilds = g.talentBuilds or {}
    g.talentBuilds[key] = g.talentBuilds[key] or {}
    return g.talentBuilds[key]
end
local function copyTrees(trees)
    local out = {}
    for i, t in ipairs(trees or {}) do
        local nt = { name = t.name, points = t.points, cols = t.cols, list = {} }
        for j, d in ipairs(t.list or {}) do nt.list[j] = { d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8] } end
        out[i] = nt
    end
    return out
end
function M:Builds(key) return buildStore(key) end
function M:SaveBuild(key, name)
    local c = WK.DB.global.characters[key]
    if not (c and c.talents and c.talents[1] and c.talents[1].list) then return nil end
    local b = { name = name, at = time(), level = c.level, trees = copyTrees(c.talents) }
    table.insert(buildStore(key), b)
    WK:NotifyChanged()
    return b
end
function M:DeleteBuild(key, i) table.remove(buildStore(key), i); WK:NotifyChanged() end
function M:RenameBuild(key, i, name)
    local b = buildStore(key)[i]
    if b and name and name ~= "" then b.name = name; WK:NotifyChanged() end
end
function M:Split(trees)
    local out = {}
    for i, t in ipairs(trees or {}) do
        local n = 0
        for _, d in ipairs(t.list or {}) do n = n + (d[5] or 0) end
        out[i] = n
    end
    return table.concat(out, " / ")
end
-- Rang actuel du talent d'un build (même n° de nœud, sinon même place)
local function curRank(cur, ti, j, d)
    local t = cur and cur[ti]
    if not t then return 0 end
    if d[8] then
        for _, e in ipairs(t.list or {}) do if e[8] == d[8] then return e[5] or 0 end end
    end
    local e = t.list and t.list[j]
    return e and (e[5] or 0) or 0
end
M.CurRank = curRank
-- Écart entre un build et les talents actuels : points à placer, points à retirer
function M:Diff(build, cur)
    local add, rem = 0, 0
    for ti, t in ipairs(build.trees or {}) do
        for j, d in ipairs(t.list or {}) do
            local now = curRank(cur, ti, j, d)
            local want = d[5] or 0
            if want > now then add = add + want - now elseif want < now then rem = rem + now - want end
        end
    end
    return add, rem
end
-- Code de partage : WK1:CLASSE:rangs de chaque arbre (un chiffre par talent), arbres séparés par « - »
function M:ExportBuild(key, i)
    local b = buildStore(key)[i]
    local c = WK.DB.global.characters[key]
    if not b then return nil end
    local parts = {}
    for ti, t in ipairs(b.trees) do
        local r = {}
        for j, d in ipairs(t.list or {}) do r[j] = tostring(math.min(9, d[5] or 0)) end
        parts[ti] = table.concat(r)
    end
    return "WK1:" .. ((c and c.class) or "?") .. ":" .. table.concat(parts, "-")
end
-- Importe un code sur la structure des talents relevés du perso ; rend le build ou nil et la raison
function M:ImportBuild(key, code, name)
    local c = WK.DB.global.characters[key]
    if not (c and c.talents and c.talents[1] and c.talents[1].list) then return nil, T("talents de ce perso pas encore relevés") end
    local cls, body = (code or ""):match("^%s*WK1:(%u+):([%d%-]+)%s*$")
    if not cls then return nil, T("code non reconnu") end
    if cls ~= c.class then return nil, T("ce code est pour une autre classe") end
    local trees = copyTrees(c.talents)
    local ti = 0
    for part in body:gmatch("[^%-]+") do
        ti = ti + 1
        local t = trees[ti]
        if not t or #part ~= #t.list then return nil, T("le code ne correspond pas à tes arbres") end
        for j = 1, #part do t.list[j][5] = math.min(t.list[j][6] or 9, tonumber(part:sub(j, j)) or 0) end
    end
    if ti ~= #trees then return nil, T("le code ne correspond pas à tes arbres") end
    local b = { name = name or T("Build importé"), at = time(), level = c.level, trees = trees }
    table.insert(buildStore(key), b)
    WK:NotifyChanged()
    return b
end
-- Place les points libres du perso connecté vers le build (rangée par rangée). Rend placés, raison
function M:ApplyBuild(key, i)
    if key ~= WK:CharKey() then return 0, T("seulement pour le perso connecté") end
    if InCombatLockdown and InCombatLockdown() then return 0, T("pas en combat") end
    local b = buildStore(key)[i]
    if not b then return 0 end
    local c = WK.DB:Me()
    local _, rem = self:Diff(b, c.talents)
    if rem > 0 then return 0, string.format(T("%d point(s) à retirer : réinitialise tes talents chez ton maître de classe, puis recommence"), rem) end
    local cfgID = traitConfig()
    if not (cfgID and C_Traits and C_Traits.PurchaseRank) then return 0, T("le jeu ne permet pas à l'addon de placer les points : place-les dans la fenêtre des talents") end
    -- ordre : rangée puis colonne
    local todo = {}
    for ti, t in ipairs(b.trees) do
        for j, d in ipairs(t.list or {}) do
            local now = curRank(c.talents, ti, j, d)
            if d[8] and (d[5] or 0) > now then table.insert(todo, { node = d[8], n = d[5] - now, row = d[3] or 0, col = d[4] or 0, tree = ti }) end
        end
    end
    table.sort(todo, function(a, z) if a.row ~= z.row then return a.row < z.row end if a.tree ~= z.tree then return a.tree < z.tree end return a.col < z.col end)
    local placed = 0
    for _, e in ipairs(todo) do
        for _ = 1, e.n do
            local ok, res = pcall(C_Traits.PurchaseRank, cfgID, e.node)
            if ok and res ~= false then placed = placed + 1 end
        end
    end
    if placed > 0 and C_Traits.CommitConfig then pcall(C_Traits.CommitConfig, cfgID) end
    C_Timer.After(1, function() M:Scan({ talents = true }) end)
    if placed == 0 then return 0, T("aucun point placé (pas de point libre, ou talent pas encore accessible)") end
    return placed
end
