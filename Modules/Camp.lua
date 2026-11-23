local ADDON_NAME, WK = ...
local M = WK:NewModule("Camp")
local T = function(s) return WK.T(s) end
function M.Readable(v)
    local Q = WK.modules.QoL
    -- avant, « Q.Readable(v) or v » rendait la valeur masquée quand Readable répondait nil (comparaison
    -- qui plantait) ; nil est maintenant rendu tel quel
    if Q and Q.Readable then return Q.Readable(v) end
    return v
end

-- Feux de camp de WoW Forever, en trois temps :
--   1. près d'un camp : effet de flamme (« Flammes pourpres »… : « augmente la durée des effets de feu de camp ») ;
--   2. assis 1 min : « Feu de camp accueillant » (compte à rebours) ;
--   3. ensuite : « Avantages du camp » pendant 2 h (selon les objets posés autour : bocal à poisson…).
-- Repérés par leur nom ou leur description (plusieurs flammes possibles) ; les n° vus sont retenus
-- (WK.DB.global.camp.seen) pour connaître les variantes. Réglages : QoL:Config().camp.
-- État (M.state) : "none" (pas de camp), "sit" (assieds-toi), "sitting" (assis, compte à rebours),
-- "done" (avantages actifs), "early" (relevé trop tôt). Affichage : UI/CampCard.lua.
-- Objets de camp par métier : données du jeu (opendata de wowlayerup-forever, CC BY 4.0 : n° d'objet, compétence,
-- paliers d'effet selon le niveau de celui qui s'assoit). Trois objets par métier, à 20 / 140 / 300 ; les
-- paliers 140 et 300 remplacent le premier et gardent son effet. Les noms sont ceux du jeu dès qu'il les
-- donne (WK.GetItemInfo), sinon les nôtres. excl : buffs de classe (en minuscules, morceaux de nom) qui
-- annulent l'effet ; exclLabel : celui qu'on affiche.
M.OBJECTS = {
    { prof = "Alchimie", ids = { 279956, 279970, 279990 }, names = { "Puits de mana", "Fermenteur", "Laboratoire d'alchimie" },
      stat = "%d mana toutes les 5 s", steps = { { 1, 10 }, { 24, 15 }, { 34, 20 }, { 44, 24 }, { 54, 29 } },
      excl = { "sagesse" }, exclLabel = "Bénédiction de sagesse" },
    { prof = "Forge", ids = { 279944, 279988, 279955 }, names = { "Meule à aiguiser", "Enclume", "Forge magistrale" },
      stat = "+%d Force", steps = { { 1, 6 }, { 24, 11 }, { 38, 20 }, { 52, 34 } },
      excl = { "force de la terre" }, exclLabel = "Totem de Force de la Terre" },
    { prof = "Enchantement", ids = { 279976, 279985, 279987 }, names = { "Luth enchanté", "Récupérateur arcanique", "Forge arcanique" },
      enchant = true, excl = { "marque du fauve", "don du fauve" }, exclLabel = "Marque du fauve" },
    { prof = "Ingénierie", ids = { 279950, 279949, 279989 }, names = { "Robot de composants", "Robot réparateur", "Établi de l'anarchiste" },
      text = { "vendeur de composants", "composants et réparations", "établi de fabrication" } },
    { prof = "Herboristerie", ids = { 279962, 279964, 279947 }, names = { "Bougie d'encens", "Serre", "Hybrideur de graines" },
      stat = "+%d Intelligence", steps = { { 1, 2 }, { 14, 6 }, { 28, 12 }, { 42, 18 }, { 56, 25 } },
      excl = { "intelligence des arcanes", "illumination des arcanes" }, exclLabel = "Intelligence des arcanes" },
    { prof = "Travail du cuir", ids = { 279978, 279941, 279945 }, names = { "Tente de campement", "Chevalet de tannage", "Machine à coudre" },
      text = "repos porté à 5 % d'un niveau" },
    { prof = "Minage", ids = { 279960, 279948, 279952 }, names = { "Magnétite", "Jardin de pierres", "Fonderie en fusion" },
      stat = "+%d puissance d'attaque en mêlée", steps = { { 1, 12 }, { 12, 20 }, { 22, 32 }, { 32, 49 }, { 42, 67 }, { 52, 90 } },
      excl = { "bénédiction de puissance" }, exclLabel = "Bénédiction de puissance" },
    { prof = "Dépeçage", ids = { 279979, 279969, 279938 }, names = { "Chaise de campement", "Guide de terrain", "Établi du trappeur" },
      text = "+2 % de coups critiques", excl = { "aura de sélénien" }, exclLabel = "Aura de sélénien" },
    { prof = "Couture", ids = { 279972, 279943, 279959 }, alt = 279973, names = { "Bannière de faction", "Rouet", "Métier à tisser" },
      stat = "+%d Esprit", steps = { { 1, 14 }, { 40, 19 }, { 50, 27 }, { 60, 32 } },
      excl = { "esprit divin", "prière d'esprit" }, exclLabel = "Esprit divin" },
    { prof = "Secourisme", ids = { 279968, 279940, 279951 }, names = { "Trousse de premiers secours", "Étude des toxines", "Laboratoire du médecin de peste" },
      stat = "+%d Endurance", steps = { { 1, 3 }, { 12, 8 }, { 24, 21 }, { 36, 34 }, { 48, 45 }, { 60, 56 } },
      excl = { "robustesse" }, exclLabel = "Mot de pouvoir : Robustesse" },
    { prof = "Pêche", ids = { 279967, 279965, 279966 }, names = { "Bocal à poisson", "Râtelier de pêche", "Cabane de pêche" },
      text = "+8 % à toutes les caractéristiques", excl = { "bénédiction des rois" }, exclLabel = "Bénédiction des rois" },
    { prof = "Cuisine", ids = { false, 279957, 279982 }, names = { false, "Festin de Cookie", "Four en fer" },
      text = { false, "nourriture d'Endurance", "four des recettes avancées" } },
}
M.RANKS = { 20, 140, 300 }
-- Feux de camp (Cuisine) : { n° d'objet, nom, compétence, objets en plus }
M.FIRES = {
    { 279981, "Kit de feu de camp basique", 1, 3 },
    { 279961, "Kit de feu de camp de compagnon", 140, 5 },
    { 279974, "Kit de feu de camp d'expert", 220, 10 },
}
M.SLEEPING_BAG = 211527
M.COOLDOWN = 3600 -- recharge commune des objets de camp
-- Début de la suite de quêtes du Sac de couchage douillet (dès le niveau 14) : carte, x, y (%)
M.BAG_QUEST = { Alliance = { 1436, 37, 50, "Marche de l'Ouest, débris d'un chariot" }, Horde = { 1413, 46, 74, "Tarides, tour incendiée" } }

-- n° d'objet » { o, tier } ; feu » palier
M.byItem = {}
for _, o in ipairs(M.OBJECTS) do
    for t = 1, 3 do if o.ids[t] then M.byItem[o.ids[t]] = { o = o, tier = t } end end
    if o.alt then M.byItem[o.alt] = { o = o, tier = 1 } end
end
M.fireByItem = {}
for i, f in ipairs(M.FIRES) do M.fireByItem[f[1]] = i end

local function step(steps, level)
    local v
    for _, s in ipairs(steps) do if level >= s[1] then v = s[2] end end
    return v
end
M.Step = step
local ENCH = {
    armor = { { 1, 28 }, { 10, 71 }, { 20, 114 }, { 30, 163 }, { 40, 211 }, { 50, 260 }, { 60, 308 } },
    stats = { { 10, 2 }, { 20, 4 }, { 30, 7 }, { 40, 9 }, { 50, 12 }, { 60, 13 } },
    res = { { 30, 6 }, { 40, 12 }, { 50, 16 }, { 60, 22 } },
}
-- Effet d'un objet (palier) pour un niveau donné
function M:Effect(o, tier, level)
    tier = tier or 1
    level = level or (UnitLevel and UnitLevel("player")) or 1
    if type(o.text) == "table" then return o.text[tier] and T(o.text[tier]) or nil end
    local base
    if o.text then base = T(o.text)
    elseif o.steps then base = string.format(T(o.stat), step(o.steps, level) or 0)
    elseif o.enchant then
        local parts = { string.format(T("+%d armure"), step(ENCH.armor, level)) }
        local st, rs = step(ENCH.stats, level), step(ENCH.res, level)
        if st then table.insert(parts, string.format(T("+%d caractéristiques"), st)) end
        if rs then table.insert(parts, string.format(T("+%d résistances"), rs)) end
        base = table.concat(parts, ", ")
    end
    return base
end
-- Paliers suivants de l'effet (« +20 dès 38 · +34 dès 52 »)
function M:NextSteps(o, level)
    if not o.steps then return nil end
    local out = {}
    for _, s in ipairs(o.steps) do
        if s[1] > level then table.insert(out, string.format(T("%s dès %d"), string.format(T(o.stat), s[2]), s[1])) end
    end
    return #out > 0 and table.concat(out, " · ") or nil
end
function M:Name(o, tier)
    local id = o.ids[tier]
    if not id then return nil end
    return (WK.GetItemInfo(id)) or T(o.names[tier])
end
function M:FireName(i)
    local f = M.FIRES[i]
    return (WK.GetItemInfo(f[1])) or T(f[2])
end

-- Buff du joueur qui annule l'effet de l'objet (nom), ou nil
local function playerBuffs()
    local out = {}
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not a then break end
            local n = M.Readable(a.name)
            if type(n) == "string" then table.insert(out, n) end
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local n = UnitBuff("player", i)
            if not n then break end
            n = M.Readable(n)
            if type(n) == "string" then table.insert(out, n) end
        end
    end
    return out
end
function M:Cancelled(o)
    if not o.excl then return nil end
    for _, n in ipairs(playerBuffs()) do
        local low = n:lower()
        for _, e in ipairs(o.excl) do if low:find(e, 1, true) then return n end end
    end
    return nil
end

-- Recharge commune des objets de camp : secondes restantes (0 : prêt), début, durée
local function itemCooldown(id)
    local f = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if not f then return nil end
    local ok, start, dur = pcall(f, id)
    start, dur = M.Readable(start), M.Readable(dur)
    if not ok or type(start) ~= "number" or type(dur) ~= "number" then return nil end
    return start, dur
end
-- Recharge d'un objet précis (feu, sac de couchage…) : secondes restantes, début, durée (nil si aucune)
function M:ItemCooldown(id)
    local start, dur = itemCooldown(id)
    if start and dur and dur > 2 and start > 0 then
        local left = start + dur - GetTime()
        if left > 0 then return left, start, dur end
    end
    return nil
end
function M:Cooldown()
    for id in pairs(M.byItem) do
        if self:Count(id) > 0 then
            local start, dur = itemCooldown(id)
            if start and dur > 2 and start > 0 then return math.max(0, start + dur - GetTime()), start, dur end
            if start then return 0 end
        end
    end
    return 0
end

-- Sacs du perso connecté
local function eachBagItem(fn)
    for bag = 0, 4 do
        for slot = 1, WK.Container.NumSlots(bag) or 0 do
            local id, count = WK.Container.Info(bag, slot)
            if id and fn(id, count or 1) then return end
        end
    end
end
-- Nombre de chaque objet en sac : gardé jusqu'au prochain changement des sacs
local counts, countsDirty = {}, true
local function bagCounts()
    if not countsDirty then return counts end
    countsDirty = false
    wipe(counts)
    eachBagItem(function(id, n) counts[id] = (counts[id] or 0) + n end)
    return counts
end
function M:Count(id) return bagCounts()[id] or 0 end
WK:On("BAG_UPDATE_DELAYED", function() countsDirty = true end)
WK:On("PLAYER_ENTERING_WORLD", function() countsDirty = true end)

-- Nourriture et boisson : « Bien nourri » repéré dans l'infobulle de l'objet, boisson par le sort d'utilisation
local foodKind = {}
local function kindOf(id)
    local k = foodKind[id]
    if k ~= nil then return k end
    local _, _, _, _, minLevel, _, _, _, _, _, _, classID, subID = WK.GetItemInfo(id)
    if minLevel == nil then return nil end -- pas encore en cache
    k = false
    if classID == 0 and subID == 5 then
        local text = ""
        if C_TooltipInfo and C_TooltipInfo.GetItemByID then
            local ok, d = pcall(C_TooltipInfo.GetItemByID, id)
            if ok and d and d.lines then
                for _, l in ipairs(d.lines) do local t = M.Readable(l.leftText); if type(t) == "string" then text = text .. " " .. t:lower() end end
            end
        end
        local getSpell = (C_Item and C_Item.GetItemSpell) or GetItemSpell
        local spell = getSpell and M.Readable((getSpell(id)))
        spell = type(spell) == "string" and spell:lower() or ""
        if text:find("bien nourri", 1, true) or text:find("well fed", 1, true) then k = "fed"
        elseif spell:find("boisson", 1, true) or spell:find("drink", 1, true) or text:find("mana", 1, true) then k = "drink" end
    end
    foodKind[id] = { k, minLevel or 0 }
    return foodKind[id]
end

-- Kit de camp : ce que le perso a dans ses sacs, dans l'ordre d'affichage
-- { { id, kind = "fire"|"object"|"bag"|"fed"|"drink", count, o?, tier? } } ; la nourriture « Bien nourri » et la
-- boisson seulement avec withFood (le kit affiché n'en montre plus : feu, objets de métier, sac de couchage)
function M:Kit(withFood)
    local c = bagCounts()
    local out = {}
    local fire
    for i, f in ipairs(M.FIRES) do if (c[f[1]] or 0) > 0 then fire = i end end
    if fire then table.insert(out, { id = M.FIRES[fire][1], kind = "fire", count = c[M.FIRES[fire][1]], fire = fire }) end
    for _, o in ipairs(M.OBJECTS) do
        local best
        for t = 3, 1, -1 do
            local id = o.ids[t]
            if id and (c[id] or 0) > 0 then best = { id = id, tier = t } break end
        end
        if not best and o.alt and (c[o.alt] or 0) > 0 then best = { id = o.alt, tier = 1 } end
        if best then table.insert(out, { id = best.id, kind = "object", count = c[best.id], o = o, tier = best.tier }) end
    end
    -- sac de couchage : son n° connu, sinon un objet des sacs dont le nom le dit, sinon le jouet
    local bagId = (c[M.SLEEPING_BAG] or 0) > 0 and M.SLEEPING_BAG or nil
    if not bagId then
        for id in pairs(c) do
            local nm = WK.GetItemInfo(id)
            if type(nm) == "string" then
                local l = nm:lower()
                if l:find("sac de couchage", 1, true) or l:find("sleeping bag", 1, true) then bagId = id break end
            end
        end
    end
    if bagId then
        table.insert(out, { id = bagId, kind = "bag", count = 1 })
    elseif _G.PlayerHasToy and _G.PlayerHasToy(M.SLEEPING_BAG) then
        table.insert(out, { id = M.SLEEPING_BAG, kind = "bag", count = 1, toy = true })
    end
    if not withFood then return out end
    local level = (UnitLevel and UnitLevel("player")) or 1
    local best = {}
    for id, n in pairs(c) do
        local k = kindOf(id)
        if k and k[1] and k[2] <= level then
            local b = best[k[1]]
            if not b or k[2] > b.lvl or (k[2] == b.lvl and n > b.count) then best[k[1]] = { id = id, lvl = k[2], count = n } end
        end
    end
    for _, kind in ipairs({ "fed", "drink" }) do
        local b = best[kind]
        if b then table.insert(out, { id = b.id, kind = kind, count = b.count }) end
    end
    return out
end
function M:HasFedFood()
    for _, e in ipairs(self:Kit(true)) do if e.kind == "fed" then return e end end
end

-- Ce que chaque perso peut apporter : { { key, c, prof, rank, item, effect, tier } }
function M:Contributions()
    local out = {}
    local level = (UnitLevel and UnitLevel("player")) or 1
    for key, c in pairs(WK.DB.global.characters) do
        for _, o in ipairs(M.OBJECTS) do
            local p = c.professions and c.professions[o.prof]
            local rank = p and p.rank or 0
            local tier
            for t = 1, 3 do if o.ids[t] and rank >= M.RANKS[t] then tier = t end end
            if tier then
                table.insert(out, { key = key, c = c, prof = o.prof, rank = rank, item = self:Name(o, tier), effect = self:Effect(o, tier, level) or "", tier = tier })
            end
        end
        local cook = c.professions and c.professions["Cuisine"]
        if cook then
            local fire
            for i, f in ipairs(M.FIRES) do if (cook.rank or 0) >= f[3] then fire = i end end
            if fire then table.insert(out, { key = key, c = c, prof = "Cuisine", rank = cook.rank or 0, item = self:FireName(fire), effect = string.format(T("feu de camp, %d objets en plus"), M.FIRES[fire][4]), tier = 0 }) end
        end
    end
    table.sort(out, function(a, b)
        if a.key ~= b.key then return WK:CharName(a.c, a.key) < WK:CharName(b.c, b.key) end
        return a.prof < b.prof
    end)
    return out
end

function M:GuideToBag()
    local fac = UnitFactionGroup and UnitFactionGroup("player")
    local q = M.BAG_QUEST[fac or ""]
    if not q then return end
    local G = WK.modules.Guide
    local t = { map = q[1], x = q[2] / 100, y = q[3] / 100 }
    t.cont, t.wx, t.wy = G.ToWorld(t.map, t.x, t.y)
    local p = G:PlayerPos()
    t.distance = p and G:Vector(p, t) or nil
    t.e = { q[2], q[3], 0, nil, nil, "Cozy Sleeping Bag", T("Sac de couchage douillet"), T(q[4]) }
    G:Start(t, "Sac de couchage douillet", "camp")
end

local DEFAULTS = { enabled = false, icon = true, iconAlways = false, renewAt = 10, sound = false, doneSecs = 8,
    kit = true, kitFlameDir = "right", chips = true, kitInBar = true, alertCd = true, alertExpire = true, alertFood = true } -- minutes restantes sous lesquelles on propose de renouveler

-- flamme près d'un camp : « Feu de camp proche » (n° 1283391 sur WoW Forever), anciennement « Flammes pourpres »
local FLAME = { "flammes pourpres", "feu de camp proche", "campfire nearby", "nearby campfire" }
local FLAME_IDS = { [1283391] = true }
local SIT = { "feu de camp accueillant", "cozy campfire", "welcoming campfire" }
local PERK = { "avantages du camp", "camp benefits" }

function M:Config()
    local q = WK.modules.QoL:Config()
    q.camp = q.camp or {}
    for k, v in pairs(DEFAULTS) do if q.camp[k] == nil then q.camp[k] = v end end
    -- l'encart « Feu de camp à proximité » faisait doublon avec l'icône de flamme : coupé une fois pour tous
    -- (réactivable dans QoL > Feu de camp)
    if not q.camp.cardOff then q.camp.cardOff = true; q.camp.enabled = false end
    return q.camp
end
local function seen()
    local g = WK.DB.global
    g.camp = g.camp or {}
    g.camp.seen = g.camp.seen or {}
    return g.camp.seen
end

local function readable(v)
    local Q = WK.modules.QoL
    -- avant, « Q.Readable(v) or v » rendait la valeur masquée quand Readable répondait nil (comparaison
    -- qui plantait) ; nil est maintenant rendu tel quel
    if Q and Q.Readable then return Q.Readable(v) end
    return v
end
local function has(list, s)
    for _, n in ipairs(list) do if s:find(n, 1, true) then return true end end
    return false
end
local descCache = {}
local function desc(spellId)
    if not spellId then return "" end
    local d = descCache[spellId]
    if d == nil then
        d = ""
        if C_Spell and C_Spell.GetSpellDescription then
            local ok, v = pcall(C_Spell.GetSpellDescription, spellId)
            if ok and type(v) == "string" then d = v:lower() end
        elseif GetSpellDescription then
            local ok, v = pcall(GetSpellDescription, spellId)
            if ok and type(v) == "string" then d = v:lower() end
        end
        descCache[spellId] = d
    end
    return d
end

-- Effets du joueur liés au camp : { flame, sit, perk } = { name, icon, expires, duration, spellId, instance }
local function seenIcons()
    local g = WK.DB.global
    g.camp = g.camp or {}
    g.camp.icons = g.camp.icons or {}
    return g.camp.icons
end
local function scan(diag)
    local out = {}
    local function consider(name, icon, duration, expires, spellId, instance)
        name, spellId, icon = readable(name), readable(spellId), readable(icon)
        -- nom masqué par le jeu : effet reconnu par son n° ou son icône déjà vus (sinon rien)
        if type(name) ~= "string" then
            local kind = (type(spellId) == "number" and (FLAME_IDS[spellId] and "flame" or seen()[spellId]))
                or (icon and seenIcons()[icon])
            if diag then diag[#diag + 1] = { name = "?", id = spellId, icon = icon, kind = kind } end
            if kind and kind ~= "fed" then
                out[kind] = { name = "?", icon = icon, duration = readable(duration), expires = readable(expires),
                    spellId = spellId, instance = instance }
            end
            return
        end
        local n = name:lower()
        local d = desc(type(spellId) == "number" and spellId or nil)
        local kind
        if has(PERK, n) or d:find("avantages de camp suivants", 1, true) then kind = "perk"
        elseif has(SIT, n) or (d:find("avantages de camp", 1, true) and d:find("près du feu", 1, true)) then kind = "sit"
        elseif has(FLAME, n) or (d:find("feu de camp", 1, true) and (n:find("flamme", 1, true) or d:find("flamme", 1, true))) then kind = "flame" end
        if not kind and type(spellId) == "number" and FLAME_IDS[spellId] then kind = "flame" end
        if not kind and type(spellId) == "number" and seen()[spellId] then kind = seen()[spellId] end
        if diag then diag[#diag + 1] = { name = name, id = spellId, icon = icon, kind = kind } end
        if n:find("bien nourri", 1, true) or n:find("well fed", 1, true) then
            out.fed = { name = name, icon = readable(icon), duration = readable(duration), expires = readable(expires) }
            return
        end
        if kind then
            out[kind] = { name = name, icon = readable(icon), duration = readable(duration), expires = readable(expires), spellId = spellId, instance = instance }
            if type(spellId) == "number" then seen()[spellId] = kind end
            if icon then seenIcons()[icon] = kind end
        end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or not a then break end
            consider(a.name, a.icon, a.duration, a.expirationTime, a.spellId, a.auraInstanceID)
        end
    elseif UnitBuff then
        for i = 1, 40 do
            local name, icon, _, _, duration, expires, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end
            consider(name, icon, duration, expires, spellId)
        end
    end
    return out
end

-- /wk camp : effets du joueur, ce que l'addon en comprend, et l'état du feu de camp
function M:Diag()
    local list = {}
    local ok = pcall(scan, list)
    WK:Print(string.format(T("Feu de camp : état « %s », icône %s"), tostring(self.state),
        self:Config().icon and T("activée") or T("coupée")))
    if not ok then WK:Print(T("  lecture des effets impossible (en combat ?)")) return end
    for _, e in ipairs(list) do
        WK:Print(string.format("  %s  · n° %s · icône %s · %s", tostring(e.name), tostring(e.id), tostring(e.icon),
            e.kind and (T("reconnu : ") .. e.kind) or T("pas un effet de camp")))
    end
    if #list == 0 then WK:Print(T("  aucun effet sur le perso")) end
    -- kit trouvé dans les sacs (clic droit sur la flamme)
    local kit = {}
    for _, e in ipairs(self:Kit()) do
        kit[#kit + 1] = string.format("%s %s%s", e.kind, tostring(e.id), e.toy and " (jouet)" or "")
    end
    WK:Print(T("  Kit : ") .. (#kit > 0 and table.concat(kit, ", ") or T("rien dans tes sacs")))
    local hint = "  Près d'un feu, il faut l'effet « Feu de camp proche » (ou un effet dont la description parle du feu de camp)."
    WK:Print(T(hint))
end

-- Texte des avantages (lignes de l'infobulle de l'effet, sans la première phrase)
function M:PerkText()
    local p = self.auras and self.auras.perk
    if not (p and p.instance and C_TooltipInfo and C_TooltipInfo.GetUnitBuffByAuraInstanceID) then return nil end
    local ok, data = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", p.instance)
    if not ok or not data or not data.lines then return nil end
    local parts = {}
    for i, l in ipairs(data.lines) do
        local t = readable(l.leftText)
        if i > 1 and type(t) == "string" and t ~= "" and not t:lower():find("obtention des avantages", 1, true)
            and not t:find("restantes?$") then
            table.insert(parts, t)
        end
    end
    return #parts > 0 and table.concat(parts, "\n") or nil
end

local function remaining(a) return a and type(a.expires) == "number" and a.expires > 0 and (a.expires - GetTime()) or nil end
M.Remaining = remaining

local wasSitting = false
function M:Update()
    -- en combat, le jeu peut masquer les effets : on garde l'état d'avant (relu à la sortie du combat) ; avant,
    -- un monstre près du feu faisait disparaître l'encart, l'icône et le kit jusqu'au prochain changement d'effet
    if _G.InCombatLockdown and _G.InCombatLockdown() and self.auras then return end
    local cfg = self:Config()
    local a = scan()
    self.auras = a
    local state = "none"
    if (cfg.enabled or cfg.icon or cfg.kit) and WK:FeatureOn("campfire") then
        local perkLeft = remaining(a.perk)
        if a.sit then
            state = "sitting"
        elseif a.flame then
            if a.perk and (not perkLeft or perkLeft > (cfg.renewAt or 10) * 60) then
                state = "done"
            elseif wasSitting and not a.perk then
                state = "early"
            else
                state = "sit"
            end
        elseif a.perk and self.state == "sitting" then
            state = "done" -- vient de l'obtenir et s'éloigne : on le dit une fois
        end
    end
    if a.sit then wasSitting = true elseif a.perk or not a.flame then wasSitting = false end
    local changed = state ~= self.state
    self.state = state
    if self.OnChange then self:OnChange(changed) end
    self:CheckAlerts()
    local UI = WK.UI
    if UI and UI.RefreshCampKit then UI:RefreshCampKit() end
    if UI and UI.RefreshCampChips then UI:RefreshCampChips() end
    if changed then WK:NotifyChanged() end -- section Feu de camp de QoL (en direct)
end

---------------------------------------------------------------------------
-- Rappels (pile d'alertes) : objet de camp de nouveau prêt, avantages bientôt finis, pas de « Bien nourri »
---------------------------------------------------------------------------
local lastCd
function M:CheckAlerts()
    local UI = WK.UI
    if not (UI and UI.SetAlert) then return end
    local cfg = self:Config()
    local on = WK:FeatureOn("campfire")
    local a = self.auras or {}
    local icon = "Interface\\Icons\\Spell_Fire_Fire"
    -- recharge terminée : rappel 20 s
    local rem = on and self:Cooldown() or 0
    if lastCd and lastCd > 0 and rem == 0 and cfg.alertCd and on then
        UI:SetAlert("camp.cd", true, { text = T("Objet de camp de nouveau disponible"), color = UI.colors.positive, prio = 4, icon = icon })
        C_Timer.After(20, function() UI:SetAlert("camp.cd", false) end)
    end
    lastCd = rem
    -- avantages bientôt finis (même loin du camp ; pas assis)
    local left = remaining(a.perk)
    local soon = on and cfg.alertExpire and left and left > 0 and left < (cfg.renewAt or 10) * 60 and not a.sit
    UI:SetAlert("camp.expire", soon or false, { text = soon and string.format(T("Avantages du camp : %s restantes"), UI:AgoShort(left, true)) or "",
        color = UI.colors.warning, prio = 3, icon = icon })
    -- au camp sans « Bien nourri », alors qu'on a de quoi manger
    local food = on and cfg.alertFood and a.flame and not a.fed and self:HasFedFood()
    UI:SetAlert("camp.food", food and true or false, { text = food and string.format(T("Pas de « Bien nourri » au camp : mange %s"), (WK.GetItemInfo(food.id)) or "") or "",
        color = UI.colors.negative, prio = 2, icon = food and ((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(food.id)) or icon) or icon })
end
-- (plus de minuterie de 5 s : les rappels à l'écran sont retirés, CheckAlerts sortait aussitôt)

-- S'asseoir (hors combat)
function M:Sit()
    if InCombatLockdown and InCombatLockdown() then return end
    if DoEmote then pcall(DoEmote, "SIT") end
end

local pending = false
-- auras du joueur seulement (RegisterUnitEvent) : plus celles de tout le raid et des plaques de nom
WK:OnUnit("UNIT_AURA", "player", function(unit)
    if unit ~= "player" or pending then return end
    pending = true
    C_Timer.After(0.2, function() pending = false; M:Update() end)
end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(2, function() M:Update() end) end)
WK:On("PLAYER_REGEN_ENABLED", function() _G.C_Timer.After(0.3, function() M:Update() end) end)
