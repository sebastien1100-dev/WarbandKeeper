local _, WK = ...

-- Buffs à ne pas oublier (maquette B) : buffs de classe, de race et pistages de métier que le perso connecté
-- devrait avoir selon le lieu (monde ouvert, donjon, raid). Liste toute prête par classe (`LIST`), cases par lieu
-- modifiables (réglages `QoL:Config().general.selfBuffs` = { bar, rules = { ["CLASSE:clé"] = "wdr" } }).
-- Seulement les sorts connus du perso. Affichage : case « buffs » de la barre « Sacs, marchand et maître »
-- (UI/BagHelp.lua) et liste déroulée de UI/SelfBuffs.lua (boutons protégés, hors combat).
-- Entrée : { key, label, ids (le 1er connu est lancé, n'importe lequel compte), def = lieux par défaut,
--   track = pistage de la minicarte, mine = seulement le tien (aura de paladin), stance = forme du jeu }
local M = {}
WK.modules.SelfBuffs = M

local AURAS = { 465, 7294, 19746, 19876, 19888, 19891, 20218, 32223 }
local LIST = {
    PALADIN = {
        { key = "aura", label = "Une aura (au choix)", ids = AURAS, def = "wdr", stance = true },
        { key = "undead", label = "Détection des morts-vivants", ids = { 5502 }, def = "dr", track = true },
        { key = "fury", label = "Fureur vertueuse (tank)", ids = { 25780 }, def = "" },
    },
    PRIEST = {
        { key = "fort", label = "Robustesse", ids = { 1243, 21562 }, def = "wdr" },
        { key = "fire", label = "Feu intérieur", ids = { 588 }, def = "wdr" },
        { key = "shadow", label = "Forme d'ombre", ids = { 15473 }, def = "" },
    },
    MAGE = {
        { key = "armor", label = "Une armure (au choix)", ids = { 7302, 168, 6117, 30482 }, def = "wdr" },
        { key = "int", label = "Intelligence des arcanes", ids = { 1459, 23028 }, def = "wdr" },
    },
    DRUID = {
        { key = "motw", label = "Marque du fauve", ids = { 1126, 21849 }, def = "wdr" },
        { key = "thorns", label = "Épines", ids = { 467 }, def = "" },
        { key = "humanoid", label = "Pistage des humanoïdes", ids = { 5225 }, def = "", track = true },
    },
    WARLOCK = {
        { key = "armor", label = "Peau ou armure de démon", ids = { 706, 687, 28176 }, def = "wdr" },
    },
    SHAMAN = {
        { key = "shield", label = "Bouclier de foudre ou d'eau", ids = { 324, 24398 }, def = "wdr" },
    },
    HUNTER = {
        { key = "aspect", label = "Un aspect (au choix)", ids = { 13165, 13163, 13161, 13159, 20043, 5118, 34074 },
            def = "wdr" },
        { key = "beasts", label = "Pistage des bêtes", ids = { 1494 }, def = "", track = true },
    },
    WARRIOR = {
        { key = "shout", label = "Cri de guerre", ids = { 6673 }, def = "" },
    },
    ROGUE = {},
}
local RACE = {
    Dwarf = { { key = "treasure", label = "Découverte de trésors (nain)", ids = { 2481 }, def = "", track = true } },
}
local PROF = {
    { key = "ore", label = "Découverte de gisements", ids = { 2580 }, def = "w", track = true },
    { key = "herb", label = "Découverte d'herbes", ids = { 2383 }, def = "w", track = true },
}
M.LIST, M.RACE, M.PROF = LIST, RACE, PROF
M.SOON = 180 -- secondes : « bientôt fini » (doré)

function M.Config()
    local g = WK.modules.QoL:Config().general
    local c = g.selfBuffs
    if type(c) ~= "table" then c = {}; g.selfBuffs = c end
    if c.bar == nil then c.bar = true end
    if type(c.rules) ~= "table" then c.rules = {} end
    return c
end

-- Noms des sorts du grimoire (le jeu ne dit plus « connu » pour un rang remplacé par un rang plus haut :
-- Dévotion rang 1 n'est plus « connue » au rang 4) ; relus à SPELLS_CHANGED
local book
local function bookNames()
    if book then return book end
    book = {}
    local SB = _G.C_SpellBook
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemName then
        local bank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player or 0
        for i = 1, SB.GetNumSpellBookSkillLines() or 0 do
            local info = SB.GetSpellBookSkillLineInfo(i)
            local off, num = info and info.itemIndexOffset or 0, info and info.numSpellBookItems or 0
            for j = off + 1, off + num do
                local ok, n = pcall(SB.GetSpellBookItemName, j, bank)
                if ok and n then book[n] = true end
            end
        end
    elseif _G.GetNumSpellTabs and _G.GetSpellTabInfo and _G.GetSpellBookItemName then
        for t = 1, _G.GetNumSpellTabs() or 0 do
            local _, _, off, num = _G.GetSpellTabInfo(t)
            for j = (off or 0) + 1, (off or 0) + (num or 0) do
                local ok, n = pcall(_G.GetSpellBookItemName, j, "spell")
                if ok and n then book[n] = true end
            end
        end
    end
    return book
end
WK:On("SPELLS_CHANGED", function() book = nil end)
local function known(id)
    local name = WK.SpellInfo(id)
    if not name then return false end
    local k = (_G.IsPlayerSpell and _G.IsPlayerSpell(id)) or (_G.IsSpellKnown and _G.IsSpellKnown(id))
    return k and true or bookNames()[name] or false
end
local function firstKnown(e)
    for _, id in ipairs(e.ids) do if known(id) then return id end end
end

-- Entrées du perso connecté : classe, race, puis pistages de métier ; chaque entrée garde sa clé de réglage
function M.Entries()
    local _, class = _G.UnitClass("player")
    local _, race = _G.UnitRace("player")
    local out = {}
    for _, e in ipairs(LIST[class or ""] or {}) do out[#out + 1] = { e = e, rk = (class or "?") .. ":" .. e.key } end
    for _, e in ipairs(RACE[race or ""] or {}) do out[#out + 1] = { e = e, rk = "race:" .. e.key } end
    for _, e in ipairs(PROF) do out[#out + 1] = { e = e, rk = "prof:" .. e.key } end
    return out
end
function M:Places(rk, e)
    local v = self.Config().rules[rk]
    if type(v) ~= "string" then v = e.def or "" end
    return v
end
function M:SetPlace(rk, e, place, on)
    local v = self:Places(rk, e)
    v = v:gsub(place, "")
    if on then v = v .. place end
    M.Config().rules[rk] = v
end

-- Lieu actuel : « w » monde ouvert, « d » donjon, « r » raid ; nil en champ de bataille ou en arène
function M.Context()
    local inside, kind
    if _G.IsInInstance then inside, kind = _G.IsInInstance() end
    if not inside or kind == "none" or kind == nil then return "w" end
    if kind == "party" or kind == "scenario" then return "d" end
    if kind == "raid" then return "r" end
    return nil
end

-- Effet sur toi : temps restant (0 = sans fin) ou nil ; mine = seulement les tiens
local function auraLeft(e)
    local names = {}
    for _, id in ipairs(e.ids) do local n = WK.SpellInfo(id); if n then names[n] = true end end
    for i = 1, 40 do
        local name, exp, src
        if _G.C_UnitAuras and _G.C_UnitAuras.GetAuraDataByIndex then
            local d = _G.C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not d then break end
            name, exp, src = d.name, d.expirationTime, d.sourceUnit
        elseif _G.UnitBuff then
            local n, _, _, _, _, x, s = _G.UnitBuff("player", i)
            if not n then break end
            name, exp, src = n, x, s
        else break end
        if name and names[name] and (not e.mine or (src and _G.UnitIsUnit and _G.UnitIsUnit(src, "player"))) then
            if not exp or exp == 0 then return 0 end
            return math.max(0, exp - _G.GetTime())
        end
    end
    return nil
end
-- Pistage actif : n° du sort, false si aucun, nil si le jeu ne le dit pas (alors pas de rappel)
local function activeTracking()
    if not (_G.C_Minimap and _G.C_Minimap.GetNumTrackingTypes and _G.C_Minimap.GetTrackingInfo) then return nil end
    local okn, n = pcall(_G.C_Minimap.GetNumTrackingTypes)
    if not okn or not n then return nil end
    for i = 1, n do
        local ok, info = pcall(_G.C_Minimap.GetTrackingInfo, i)
        if ok and type(info) == "table" and info.active and info.spellID then return info.spellID end
    end
    return false
end
-- Forme du jeu (aura de paladin) : vrai si une est active, nil si le jeu n'en a pas
local function stanceOn()
    if not (_G.GetNumShapeshiftForms and _G.GetShapeshiftForm) then return nil end
    if (_G.GetNumShapeshiftForms() or 0) == 0 then return nil end
    return _G.GetShapeshiftForm() ~= 0
end
-- Sort de la forme active (aura de paladin en cours) parmi ceux de l'entrée : n°, sinon nil
local function activeStance(e)
    local i = _G.GetShapeshiftForm and _G.GetShapeshiftForm() or 0
    if i == 0 or not _G.GetShapeshiftFormInfo then return nil end
    local a, b, c, d = _G.GetShapeshiftFormInfo(i)
    -- client moderne : icône, actif, lançable, n° du sort ; ancien : icône, nom, actif, lançable
    local sid = type(d) == "number" and d or nil
    local sname = type(b) == "string" and b or (sid and WK.SpellInfo(sid))
    for _, id in ipairs(e.ids) do
        if id == sid or (sname and WK.SpellInfo(id) == sname) then return id end
    end
    return nil, a, c
end

-- Lignes à montrer ici : { e, rk, id, name, icon, state = "missing" | "soon" | "ok", left }
-- (seulement les entrées cochées pour ce lieu et connues du perso) ; plusieurs pistages demandés : un seul
-- peut être actif, n'importe lequel de la liste compte
function M:Status()
    local out = {}
    local ctx = M.Context()
    if not ctx then return out, ctx end
    if _G.UnitIsDeadOrGhost and _G.UnitIsDeadOrGhost("player") then return out, ctx end
    local tracks, trackOk, active
    for _, it in ipairs(M.Entries()) do
        local e = it.e
        if self:Places(it.rk, e):find(ctx, 1, true) then
            local id = firstKnown(e)
            if id then
                local name, icon = WK.SpellInfo(id)
                local row = { e = e, rk = it.rk, id = id, name = name, icon = icon }
                if e.track then
                    if active == nil then active = activeTracking() end
                    if active ~= nil then
                        tracks = tracks or {}
                        tracks[#tracks + 1] = row
                        for _, x in ipairs(e.ids) do if x == active then trackOk = row end end
                    end
                else
                    local left
                    local st = e.stance and stanceOn()
                    if st ~= nil then
                        left = st and 0 or nil
                        -- aura en cours : la sienne s'affiche (Vindicte, pas la 1re connue)
                        local act = st and activeStance(e)
                        if act then
                            row.id = act
                            row.name, row.icon = WK.SpellInfo(act)
                        end
                    else left = auraLeft(e) end
                    row.left = left
                    row.state = not left and "missing" or ((left > 0 and left < M.SOON) and "soon" or "ok")
                    out[#out + 1] = row
                end
            end
        end
    end
    if tracks then
        for _, row in ipairs(tracks) do
            if trackOk then
                if row == trackOk then row.state, row.left = "ok", 0; out[#out + 1] = row end
            else
                row.state = "missing"; out[#out + 1] = row
            end
        end
    end
    -- manquants d'abord, puis bientôt finis, puis le reste
    local rank = { missing = 1, soon = 2, ok = 3 }
    for i, r in ipairs(out) do r.i = i end
    table.sort(out, function(a, b)
        if rank[a.state] ~= rank[b.state] then return rank[a.state] < rank[b.state] end
        return a.i < b.i
    end)
    return out, ctx
end
function M:Counts()
    local miss, soon, total = 0, 0, 0
    for _, r in ipairs((self:Status())) do
        total = total + 1
        if r.state == "missing" then miss = miss + 1 elseif r.state == "soon" then soon = soon + 1 end
    end
    return miss, soon, total
end
