local ADDON_NAME, WK = ...
local M = WK:NewModule("LFG")
local T = function(s) return WK.T(s) end

-- Recherche de groupe (onglet LFG, UI/Pages/LFG.lua) : s'appuie sur la recherche de groupe du jeu
-- (C_LFGList). La recherche part d'un clic du joueur ; les résultats arrivent par évènement.
-- Toute valeur lue peut être masquée par le jeu (en donjon, en combat) : elle passe par readable,
-- et une valeur illisible ne cache jamais un groupe.
-- Réglages : WK.DB.global.lfg ; rôles et message par perso : WK.DB.char.lfg.

local function readable(v, fallback)
    if issecretvalue and issecretvalue(v) then return fallback end
    if v == nil then return fallback end
    return v
end
M.Readable = readable

-- Messages envoyés aux autres joueurs : en anglais (WoW Forever est un serveur européen, l'anglais y est
-- la langue commune). Les mots-clés existent en anglais et en français.
local DEFAULT_MSG = "Hi! %class% %level%, %role%, available for %dungeon%."
local OLD_DEFAULT = "Salut ! %classe% %niveau%, %role%, dispo pour %donjon%."
local CLASS_EN = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
                   SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
local ROLE_EN = { tank = "tank", heal = "healer", dps = "dps" }
function M:Config()
    local g = WK.DB.global
    g.lfg = g.lfg or {}
    local c = WK.DB.char
    c.lfg = c.lfg or {}
    if c.lfg.roles == nil then c.lfg.roles = { dps = true } end
    if c.lfg.mode == nil then c.lfg.mode = "group" end
    if c.lfg.message == nil or c.lfg.message == OLD_DEFAULT then c.lfg.message = DEFAULT_MSG end
    -- Affiner : classes et niveau des joueurs seuls, style de jeu, langues (vide : tout)
    c.lfg.filters = c.lfg.filters or {}
    local f = c.lfg.filters
    f.classes = f.classes or {}
    f.playstyles = f.playstyles or {}
    f.languages = f.languages or {}
    c.lfg.requests = c.lfg.requests or {}
    g.lfg.ratings = g.lfg.ratings or {}   -- [nom] = 1 à 3 étoiles (compte entier)
    g.lfg.recent = g.lfg.recent or {}     -- joueurs croisés en groupe : { name, class, level, t, where }
    return c.lfg, g.lfg
end
M.DEFAULT_MSG = DEFAULT_MSG

function M:Available() return C_LFGList ~= nil and C_LFGList.Search ~= nil end

---------------------------------------------------------------------------
-- Catégories et activités
---------------------------------------------------------------------------
function M:Categories()
    local out = {}
    if not self:Available() then return out end
    local ok, cats = pcall(C_LFGList.GetAvailableCategories)
    for _, id in ipairs(ok and cats or {}) do
        local info = C_LFGList.GetLfgCategoryInfo and C_LFGList.GetLfgCategoryInfo(id)
        if info then table.insert(out, { id = id, name = info.name }) end
    end
    return out
end

-- Activités d'une catégorie, triées par niveau conseillé : { id, name, min, max }
local actCache = {}
function M:Activities(categoryID)
    if actCache[categoryID] then return actCache[categoryID] end
    local out = {}
    local ok, ids = pcall(C_LFGList.GetAvailableActivities, categoryID)
    for _, id in ipairs(ok and ids or {}) do
        local a = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(id)
        if a then
            table.insert(out, { id = id, name = a.fullName or a.shortName or ("#" .. id),
                min = a.minLevelSuggestion or a.minLevel or 0, max = a.maxLevelSuggestion or a.maxLevel or 0 })
        end
    end
    table.sort(out, function(a, b) if a.min ~= b.min then return a.min < b.min end return a.name < b.name end)
    actCache[categoryID] = out
    return out
end
function M:Activity(id)
    local a = id and C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(id)
    return a and (a.fullName or a.shortName) or nil
end

-- Catégorie des donjons (la première qui a des activités), à défaut la première.
function M:DefaultCategory()
    local cats = self:Categories()
    for _, c in ipairs(cats) do
        if c.id == 2 then return c.id end
    end
    return cats[1] and cats[1].id or nil
end

---------------------------------------------------------------------------
-- Recherche
---------------------------------------------------------------------------
M.results = {}
M.searching = false
M.searchedAt = nil

-- Langues : celles que le jeu propose. Les langues imposées par le jeu sont toujours cherchées.
function M:Languages()
    local out = {}
    local ok, list = pcall(C_LFGList.GetAvailableLanguageSearchFilter)
    local okD, def = pcall(C_LFGList.GetDefaultLanguageSearchFilter)
    def = okD and type(def) == "table" and def or {}
    for _, code in ipairs(ok and type(list) == "table" and list or {}) do
        if type(code) == "string" then table.insert(out, { code = code, locked = def[code] == true }) end
    end
    return out
end
function M:LanguageFilter()
    local chosen = self:Config().filters.languages
    local filter, extra = {}, false
    for _, l in ipairs(self:Languages()) do
        if l.locked then filter[l.code] = true
        elseif chosen[l.code] then filter[l.code] = true; extra = true end
    end
    if not extra then
        local ok, def = pcall(C_LFGList.GetDefaultLanguageSearchFilter)
        return ok and def or nil
    end
    return filter
end

-- Styles de jeu des annonces (valeurs du jeu)
local PS = Enum and Enum.LFGEntryGeneralPlaystyle or {}
M.PLAYSTYLES = {
    { key = "learning", value = PS.Learning or 1, label = "Apprentissage" },
    { key = "relaxed", value = PS.FunRelaxed or 2, label = "Décontracté" },
    { key = "serious", value = PS.FunSerious or 3, label = "Compétitif" },
    { key = "expert", value = PS.Expert or 4, label = "Carry" },
}
function M:PlaystyleLabel(v)
    for _, p in ipairs(M.PLAYSTYLES) do if p.value == v then return p.label end end
end

-- L'annonce passe-t-elle les filtres « Affiner » ? Une valeur illisible ne cache rien.
function M:PassFilters(r)
    local f = self:Config().filters
    local anyPS = false
    for _ in pairs(f.playstyles) do anyPS = true break end
    if anyPS and r.playstyle and r.playstyle ~= 0 then
        local ok = false
        for _, p in ipairs(M.PLAYSTYLES) do if p.value == r.playstyle and f.playstyles[p.key] then ok = true end end
        if not ok then return false end
    end
    if r.solo then
        local anyCl = false
        for _ in pairs(f.classes) do anyCl = true break end
        if anyCl and r.class and not f.classes[r.class] then return false end
        if r.level and f.minLevel and r.level < f.minLevel then return false end
        if r.level and f.maxLevel and r.level > f.maxLevel then return false end
    end
    return true
end
function M:FiltersActive()
    local f = self:Config().filters
    for _, t in ipairs({ f.classes, f.playstyles, f.languages }) do for _ in pairs(t) do return true end end
    return f.minLevel ~= nil or f.maxLevel ~= nil
end

function M:Search(categoryID, activityIDs)
    if not self:Available() or self.searching or not categoryID then return false end
    if not activityIDs or #activityIDs == 0 then
        activityIDs = {}
        for _, a in ipairs(self:Activities(categoryID)) do table.insert(activityIDs, a.id) end
    end
    local filter = self:LanguageFilter()
    local ok = pcall(C_LFGList.Search, categoryID, 0, 0, filter, false, nil, activityIDs)
    self.failed = not ok or nil
    if not ok then WK:NotifyChanged(); return false end
    self.searching = true
    -- autre catégorie : les groupes de l'ancienne ne sont plus montrés
    if self.category ~= categoryID then self.results = {} end
    self.category = categoryID
    C_Timer.After(10, function() if M.searching then M.searching = false; WK:NotifyChanged() end end)
    WK:NotifyChanged()
    return true
end

-- Vide les résultats (changement de catégorie dans la page).
function M:ClearResults()
    self.results = {}
    self.failed = nil
end

-- Lecture d'un résultat : ce dont la page a besoin.
local function counts(resultID)
    local c = C_LFGList.GetSearchResultMemberCounts and readable(C_LFGList.GetSearchResultMemberCounts(resultID), nil)
    if type(c) ~= "table" then return nil end
    return { tank = readable(c.TANK, 0), heal = readable(c.HEALER, 0), dps = readable(c.DAMAGER, 0) }
end

local function readResult(id)
    local info = C_LFGList.GetSearchResultInfo(id)
    if not info then return nil end
    local r = {
        id = id,
        leader = readable(info.leaderName, nil),
        comment = readable(info.comment, ""),
        members = readable(info.numMembers, nil),
        delisted = readable(info.isDelisted, false) == true,
        self = readable(info.hasSelf, false) == true,
        age = readable(info.age, nil),
        playstyle = readable(info.generalPlaystyle, nil),
    }
    local acts = readable(info.activityIDs, nil) or {}
    r.activity = acts[1]
    r.activityCount = #acts
    r.counts = counts(id)
    r.solo = r.members ~= nil and r.members <= 1
    if r.solo and C_LFGList.GetSearchResultPlayerInfo then
        local p = C_LFGList.GetSearchResultPlayerInfo(id, 1)
        if p then
            r.class = readable(p.classFilename, nil)
            r.level = readable(p.level, nil)
            local roles = readable(p.lfgRoles, nil)
            if type(roles) == "table" then
                r.roles = { tank = readable(roles.tank, false), heal = readable(roles.healer, false), dps = readable(roles.dps, false) }
            end
        end
    elseif C_LFGList.GetSearchResultLeaderInfo then
        local li = C_LFGList.GetSearchResultLeaderInfo(id)
        if li then r.class = readable(li.classFilename, nil); r.level = readable(li.level, nil) end
    end
    -- membres du groupe : classe, niveau, rôle (souvent masqué en donjon), chef
    r.list = {}
    local ROLE = { TANK = "tank", HEALER = "heal", DAMAGER = "dps" }
    if not r.solo and r.members and C_LFGList.GetSearchResultPlayerInfo then
        for i = 1, math.min(r.members, 40) do
            local p = C_LFGList.GetSearchResultPlayerInfo(id, i)
            if p then
                local name = readable(p.name, nil)
                local role = readable(p.assignedRole, nil)
                table.insert(r.list, {
                    name = name, class = readable(p.classFilename, nil), level = readable(p.level, nil),
                    role = type(role) == "string" and ROLE[role] or nil,
                    leader = readable(p.isLeader, nil) == true or (name ~= nil and r.leader ~= nil and name == r.leader),
                })
            end
        end
    end
    -- ami ou guilde : le jeu le donne dans les listes de l'annonce
    r.friend = (readable(info.numBNetFriends, 0) or 0) + (readable(info.numCharFriends, 0) or 0) > 0
    r.guild = (readable(info.numGuildMates, 0) or 0) > 0
    return r
end

---------------------------------------------------------------------------
-- Buffs d'un groupe : d'après les classes et niveaux des membres (le jeu ne dit rien des talents)
--   { nom, niveau où le sort s'apprend, talent? } par classe ; missing = libellé court d'une classe absente
---------------------------------------------------------------------------
M.BUFFS = {
    WARRIOR = { { "Cri de guerre", 1 } },
    PRIEST  = { { "Mot de pouvoir : Robustesse", 1 }, { "Protection contre l'Ombre", 30 }, { "Esprit divin", 30, true } },
    MAGE    = { { "Intelligence des arcanes", 1 } },
    DRUID   = { { "Marque du fauve", 1 }, { "Aura de sélénien", 40, true } },
    PALADIN = { { "Aura de dévotion", 1 }, { "Bénédiction de puissance", 4 }, { "Bénédiction de sagesse", 14 },
                { "Bénédiction des rois", 20, true }, { "Bénédiction de salut", 26 } },
    SHAMAN  = { { "Totem de peau de pierre", 4 }, { "Totem de Force de la Terre", 10 }, { "Totem Fontaine de mana", 26 },
                { "Totem Furie-des-vents", 32 }, { "Totem de grâce aérienne", 42 } },
    HUNTER  = { { "Aspect de la meute", 30 }, { "Aura de précision", 40, true } },
    WARLOCK = { { "Lien de sang (diablotin)", 4 }, { "Pierre de soins", 10 }, { "Pierre d'âme", 18 } },
    ROGUE   = {},
}
M.BUFF_SHORT = { WARRIOR = "Cri de guerre", PRIEST = "Robustesse", MAGE = "Intelligence des arcanes", DRUID = "Marque du fauve",
    PALADIN = "Bénédictions et auras", SHAMAN = "Totems", HUNTER = "Aspect de la meute", WARLOCK = "Pierres de soins et d'âme" }
local BUFF_ORDER = { "WARRIOR", "PRIEST", "MAGE", "DRUID", "PALADIN", "SHAMAN", "HUNTER", "WARLOCK" }

-- r : résultat lu (r.list = membres). Renvoie { have = { { name, class, talent } }, mine = {…}, missing = { { label, class } },
-- camp = { « nom du buff » = métier dont l'objet de camp est annulé } }
function M:GroupBuffs(r)
    local inGroup, best = {}, {}
    for _, m in ipairs(r and r.list or {}) do
        if m.class then
            inGroup[m.class] = true
            best[m.class] = math.max(best[m.class] or 0, m.level or 60)
        end
    end
    local out = { have = {}, mine = {}, missing = {}, camp = {} }
    local function add(list, class, lvl)
        for _, b in ipairs(M.BUFFS[class] or {}) do
            if (lvl or 60) >= b[2] then table.insert(list, { name = b[1], class = class, talent = b[3] }) end
        end
    end
    for _, cl in ipairs(BUFF_ORDER) do if inGroup[cl] then add(out.have, cl, best[cl]) end end
    local me = WK.DB:Me()
    local myClass = me and me.class
    if myClass and not inGroup[myClass] then add(out.mine, myClass, (UnitLevel and UnitLevel("player")) or me.level) end
    for _, cl in ipairs(BUFF_ORDER) do
        if not inGroup[cl] and cl ~= myClass and M.BUFF_SHORT[cl] then table.insert(out.missing, { label = M.BUFF_SHORT[cl], class = cl }) end
    end
    -- objets de camp annulés par un buff du groupe ou par les tiens (WoW Forever)
    local Cp = WK.modules.Camp
    for _, list in ipairs({ out.have, out.mine }) do
        for _, b in ipairs(list) do
            local low = b.name:lower()
            for _, o in ipairs(Cp and Cp.OBJECTS or {}) do
                for _, pat in ipairs(o.excl or {}) do
                    if low:find(pat, 1, true) then out.camp[b.name] = o.prof end
                end
            end
        end
    end
    return out
end

function M:ReadResults()
    local list = {}
    if C_LFGList.GetFilteredSearchResults then
        local _, ids = C_LFGList.GetFilteredSearchResults()
        for _, id in ipairs(ids or {}) do
            local r = readResult(id)
            if r then table.insert(list, r) end
        end
    end
    self.results = list
    return list
end

---------------------------------------------------------------------------
-- Place pour moi
---------------------------------------------------------------------------
local NEED = { tank = 1, heal = 1, dps = 3 }
M.NEED = NEED

-- Rôle que je prendrais dans ce groupe (nil : pas de place pour mes rôles). Comptes illisibles : place supposée.
function M:FitRole(r, roles)
    if r.solo or r.delisted or r.self then return nil end
    roles = roles or self:Config().roles
    local c = r.counts
    for _, role in ipairs({ "tank", "heal", "dps" }) do
        if roles[role] and (not c or (c[role] or 0) < NEED[role]) then return role end
    end
    return nil
end
function M:Full(r)
    local c = r.counts
    return c and (c.tank or 0) + (c.heal or 0) + (c.dps or 0) >= 5 or false
end

-- Nombre de groupes par activité (pour l'échelle des donjons)
function M:ActivityCounts()
    local n = {}
    for _, r in ipairs(self.results) do
        if r.activity and not r.solo and not r.delisted then n[r.activity] = (n[r.activity] or 0) + 1 end
    end
    return n
end

---------------------------------------------------------------------------
-- Demander / inviter
---------------------------------------------------------------------------
local ROLE_WORD = { tank = "tank", heal = "soin", dps = "dégâts" }
M.ROLE_WORD = ROLE_WORD

-- Nom anglais d'un donjon ou d'un raid, pour les messages. Le jeu ne donne que le nom traduit, et
-- WoW Forever mélange parfois les deux (« Prison de Stormwind ») : reconnaissance par mots-clés,
-- dans l'ordre (le premier trouvé l'emporte). Un nom inconnu (ou déjà anglais) reste tel quel.
local DUNGEON_EN = {
    { "ragefeu", "Ragefire Chasm" }, { "ragefire", "Ragefire Chasm" },
    { "lamentations", "Wailing Caverns" },
    { "mortemines", "The Deadmines" },
    { "ombrecroc", "Shadowfang Keep" },
    { "brassenoire", "Blackfathom Deeps" },
    { "prison", "The Stockade" },
    { "gnomeregan", "Gnomeregan" },
    { "kraal", "Razorfen Kraul" },
    { "souilles", "Razorfen Downs" },
    { "cimetiere", "Scarlet Monastery Graveyard" }, { "bibliotheque", "Scarlet Monastery Library" },
    { "armurerie", "Scarlet Monastery Armory" }, { "cathedrale", "Scarlet Monastery Cathedral" },
    { "monastere", "Scarlet Monastery" },
    { "uldaman", "Uldaman" },
    { "zul'farrak", "Zul'Farrak" }, { "zulfarrak", "Zul'Farrak" },
    { "maraudon", "Maraudon" },
    { "atal", "Sunken Temple" }, { "englouti", "Sunken Temple" },
    { "profondeurs de rochenoire", "Blackrock Depths" }, { "profondeurs de blackrock", "Blackrock Depths" },
    { "inferieur", "Lower Blackrock Spire" }, { "bas du pic", "Lower Blackrock Spire" },
    { "superieur", "Upper Blackrock Spire" }, { "haut du pic", "Upper Blackrock Spire" },
    { "pic de rochenoire", "Blackrock Spire" }, { "pic blackrock", "Blackrock Spire" },
    { "hache-tripes", "Dire Maul", wing = true }, { "dire maul", "Dire Maul", wing = true },
    { "stratholme", "Stratholme" },
    { "scholomance", "Scholomance" },
    { "coeur du magma", "Molten Core" },
    { "onyxia", "Onyxia's Lair" },
    { "aile noire", "Blackwing Lair" },
    { "zul'gurub", "Zul'Gurub" }, { "zulgurub", "Zul'Gurub" },
    { "ruines d'ahn", "Ruins of Ahn'Qiraj" }, { "temple d'ahn", "Temple of Ahn'Qiraj" },
    { "naxxramas", "Naxxramas" },
}
local ACCENTS = { ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["à"] = "a", ["â"] = "a", ["î"] = "i", ["ï"] = "i",
                  ["ô"] = "o", ["û"] = "u", ["ù"] = "u", ["ç"] = "c", ["œ"] = "oe", ["É"] = "e", ["Œ"] = "oe" }
function M.EnglishName(name)
    if not name or name == "" then return name end
    local low = string.lower(name)
    for k, v in pairs(ACCENTS) do low = low:gsub(k, v) end
    for _, e in ipairs(DUNGEON_EN) do
        if string.find(low, e[1], 1, true) then
            if e.wing then -- Hache-tripes : l'aile, quel que soit le séparateur
                local rest = " " .. low:gsub("[^%a]", " ") .. " "
                if rest:find(" ouest ") or rest:find(" west ") then return e[2] .. " West" end
                if rest:find(" est ") or rest:find(" east ") then return e[2] .. " East" end
                if rest:find(" nord ") or rest:find(" north ") then return e[2] .. " North" end
            end
            return e[2]
        end
    end
    return name
end

function M:Message(activityName, role)
    local cfg = self:Config()
    local me = WK.DB:Me()
    local class = CLASS_EN[me.class or ""] or ""
    local roles = {}
    if role then roles = { ROLE_EN[role] }
    else for _, k in ipairs({ "tank", "heal", "dps" }) do if cfg.roles[k] then table.insert(roles, ROLE_EN[k]) end end end
    local level = tostring(UnitLevel("player") or "")
    activityName = M.EnglishName(activityName)
    local msg = cfg.message or DEFAULT_MSG
    msg = msg:gsub("%%class%%", class):gsub("%%classe%%", class)
    msg = msg:gsub("%%level%%", level):gsub("%%niveau%%", level)
    msg = msg:gsub("%%role%%", table.concat(roles, " / "))
    msg = msg:gsub("%%dungeon%%", activityName or "your group"):gsub("%%donjon%%", activityName or "your group")
    return msg
end

-- Demandes : sauvegardées par perso (WK.DB.char.lfg.requests), gardées 3 heures
M.requests = {} -- [nom] = { t, activity, state = "sent"|"answer"|"closed"|"invited", reply }
function M:OnLogin()
    local cfg = self:Config()
    local now = time()
    for name, q in pairs(cfg.requests) do if now - (q.t or 0) > 3 * 3600 then cfg.requests[name] = nil end end
    for name, q in pairs(M.requests) do cfg.requests[name] = q end
    M.requests = cfg.requests
end

---------------------------------------------------------------------------
-- Notes des joueurs (1 à 3 étoiles) et joueurs croisés en groupe
---------------------------------------------------------------------------
local function bare(name)
    name = readable(name, nil)
    if type(name) ~= "string" then return nil end
    return (name:gsub("%-.*$", ""))
end
M.Bare = bare
function M:Rating(name)
    name = bare(name)
    if not name then return nil end
    local _, g = self:Config()
    return g.ratings[name]
end
function M:SetRating(name, stars)
    name = bare(name)
    if not name then return end
    local _, g = self:Config()
    g.ratings[name] = (stars and stars > 0) and stars or nil
    WK:NotifyChanged()
end
-- Note la plus basse d'une annonce (chef seulement : les membres ne sont pas tous lisibles)
function M:ListingRating(r) return self:Rating(r.leader) end

local inGroup = {}
local rosterSeeded = false -- après un /reload, le groupe déjà là n'est pas « nouveau »
local function rosterUnits()
    local units = {}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do table.insert(units, "raid" .. i) end
    else
        for i = 1, 4 do table.insert(units, "party" .. i) end
    end
    return units
end
-- Relève le groupe ; record = false : mémorise seulement qui est là (rien n'est noté).
local function scanRoster(record)
    local g = record and select(2, M:Config())
    local now, seen = time(), {}
    local me = bare(UnitName("player"))
    local where = GetZoneText and readable(GetZoneText(), nil)
    for _, u in ipairs(rosterUnits()) do
        if UnitExists and UnitExists(u) then
            local name = bare(GetUnitName and GetUnitName(u, false) or UnitName(u))
            if name and name ~= me then
                seen[name] = true
                if record and not inGroup[name] then
                    -- nouveau venu : on le note dans les récents, et on prévient si tu l'as noté 1 étoile
                    if g.ratings[name] == 1 then
                        WK:Print(string.format(T("%s vient de rejoindre ton groupe : tu l'avais noté 1 étoile."), name))
                    end
                    for i = #g.recent, 1, -1 do if g.recent[i].name == name then table.remove(g.recent, i) end end
                    local _, class = UnitClass(u)
                    table.insert(g.recent, 1, { name = name, class = readable(class, nil), level = readable(UnitLevel(u), nil), t = now, where = where })
                    while #g.recent > 40 do table.remove(g.recent) end
                end
            end
        end
    end
    inGroup = seen
    rosterSeeded = true
end
WK:On("PLAYER_ENTERING_WORLD", function()
    if not rosterSeeded then scanRoster(false) end
end)
WK:On("GROUP_ROSTER_UPDATE", function()
    scanRoster(rosterSeeded)
    WK:NotifyChanged()
end)

local function whisper(name, msg)
    if C_ChatInfo and C_ChatInfo.SendChatMessage then pcall(C_ChatInfo.SendChatMessage, msg, "WHISPER", nil, name)
    elseif SendChatMessage then pcall(SendChatMessage, msg, "WHISPER", nil, name) end
end

function M:Ask(r)
    if not r.leader then return end
    local act = self:Activity(r.activity)
    whisper(r.leader, self:Message(act, self:FitRole(r)))
    self.requests[r.leader] = { t = time(), activity = act, state = "sent", id = r.id }
    WK:NotifyChanged()
end

function M:Invite(r)
    if not r.leader then return end
    local f = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
    if f then pcall(f, r.leader) end
    whisper(r.leader, string.format("Hi! Want to join us for %s?", M.EnglishName(self:Activity(r.activity)) or "a group"))
    self.requests[r.leader] = { t = time(), activity = self:Activity(r.activity), state = "invited" }
    WK:NotifyChanged()
end

-- Réponses : un chuchotement d'un chef à qui on a demandé
local function sameName(a, b)
    if not a or not b then return false end
    a, b = a:gsub("%-.*$", ""), b:gsub("%-.*$", "")
    return a:lower() == b:lower()
end
WK:On("CHAT_MSG_WHISPER", function(text, sender)
    for name, q in pairs(M.requests) do
        if sameName(name, readable(sender, nil)) then
            q.state, q.reply, q.replyAt = "answer", readable(text, ""), time()
            WK:NotifyChanged()
        end
    end
end)

---------------------------------------------------------------------------
-- Évènements de la recherche
---------------------------------------------------------------------------
WK:On("LFG_LIST_SEARCH_RESULTS_RECEIVED", function()
    M.searching = false
    M.failed = nil
    M.searchedAt = time()
    M:ReadResults()
    WK:NotifyChanged()
end)
WK:On("LFG_LIST_SEARCH_FAILED", function()
    M.searching = false
    M.failed = true
    WK:NotifyChanged()
end)
WK:On("LFG_LIST_SEARCH_RESULT_UPDATED", function(id)
    for i, r in ipairs(M.results) do
        if r.id == id then
            local n = readResult(id)
            if n then M.results[i] = n end
            -- annonce retirée : les demandes en attente vers ce groupe sont closes
            if n and n.delisted and n.leader and M.requests[n.leader] and M.requests[n.leader].state == "sent" then
                M.requests[n.leader].state = "closed"
            end
            break
        end
    end
    WK:NotifyChanged()
end)
