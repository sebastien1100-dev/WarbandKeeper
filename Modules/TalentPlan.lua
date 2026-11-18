local ADDON_NAME, WK = ...
local M = WK:NewModule("TalentPlan")
local T = function(s) return WK.T(s) end

-- Plans de montée de niveau : l'ordre des points de talent, un point par niveau à partir du 10.
--   WK.DB.global.talentPlans[perso] = { list = { { name, steps = { { arbre, n° dans l'arbre, n° de nœud, nom } } } }, active = n° }
-- Le plan « Montée enregistrée » se remplit tout seul quand le perso connecté prend un talent.
-- Affichage : onglet Talents de la fiche (cartes, mode plan) et panneau collé à la fenêtre des talents (UI/TalentPlan.lua).
local FIRST_LEVEL = 10
M.FIRST_LEVEL = FIRST_LEVEL
local RECORDED = "Montée enregistrée"

local function store(key)
    local g = WK.DB.global
    g.talentPlans = g.talentPlans or {}
    g.talentPlans[key] = g.talentPlans[key] or { list = {} }
    return g.talentPlans[key]
end
function M:Plans(key) return store(key).list end
function M:Active(key)
    local s = store(key)
    local p = s.active and s.list[s.active]
    return p, s.active
end
function M:SetActive(key, i) store(key).active = i; WK:NotifyChanged() end
function M:New(key, name)
    local s = store(key)
    table.insert(s.list, { name = name, steps = {} })
    if not s.active then s.active = #s.list end
    WK:NotifyChanged()
    return #s.list
end
function M:Delete(key, i)
    local s = store(key)
    table.remove(s.list, i)
    if s.active == i then s.active = nil elseif s.active and s.active > i then s.active = s.active - 1 end
    WK:NotifyChanged()
end
function M:Rename(key, i, name)
    local p = store(key).list[i]
    if p and name and name ~= "" then p.name = name; WK:NotifyChanged() end
end

-- Talent d'une étape dans les arbres relevés du perso (même nœud, sinon même place)
function M:Talent(c, st)
    local t = c and c.talents and c.talents[st[1]]
    if not t or not t.list then return nil end
    if st[3] then for _, d in ipairs(t.list) do if d[8] == st[3] then return d end end end
    return t.list[st[2]]
end
-- Rangs du plan jusqu'à l'étape n (toutes si nil) : clé « arbre:n° » » rang
function M:Ranks(plan, n)
    local out = {}
    for i, st in ipairs(plan.steps) do
        if n and i > n then break end
        local k = st[1] .. ":" .. st[2]
        out[k] = (out[k] or 0) + 1
    end
    return out
end
-- Ajoute un point au plan (refusé si le talent est déjà au maximum)
function M:AddStep(key, i, ti, j)
    local p = store(key).list[i]
    local c = WK.DB.global.characters[key]
    local d = c and c.talents and c.talents[ti] and c.talents[ti].list and c.talents[ti].list[j]
    if not (p and d) then return false end
    local r = self:Ranks(p)[ti .. ":" .. j] or 0
    if r >= (d[6] or 1) then return false end
    table.insert(p.steps, { ti, j, d[8], d[1] })
    WK:NotifyChanged()
    return true
end
function M:RemoveLast(key, i)
    local p = store(key).list[i]
    if p and #p.steps > 0 then table.remove(p.steps); WK:NotifyChanged() end
end
-- Niveaux où chaque talent est pris dans le plan : clé » texte (« 10-14 », « 26 »)
function M:LevelLabels(plan)
    local first, last = {}, {}
    for i, st in ipairs(plan.steps) do
        local k = st[1] .. ":" .. st[2]
        local lv = FIRST_LEVEL + i - 1
        first[k] = first[k] or lv
        last[k] = lv
    end
    local out = {}
    for k, f in pairs(first) do out[k] = (f == last[k]) and tostring(f) or (f .. "-" .. last[k]) end
    return out
end
-- Plan proposé à partir d'un build enregistré : rangée par rangée, arbre par arbre
function M:FromBuild(key, b)
    local i = self:New(key, b.name)
    local p = store(key).list[i]
    local todo = {}
    for ti, t in ipairs(b.trees or {}) do
        for j, d in ipairs(t.list or {}) do
            if (d[5] or 0) > 0 then table.insert(todo, { ti = ti, j = j, d = d }) end
        end
    end
    table.sort(todo, function(a, z)
        if a.d[3] ~= z.d[3] then return a.d[3] < z.d[3] end
        if a.ti ~= z.ti then return a.ti < z.ti end
        return a.d[4] < z.d[4]
    end)
    for _, e in ipairs(todo) do
        for _ = 1, e.d[5] do table.insert(p.steps, { e.ti, e.j, e.d[8], e.d[1] }) end
    end
    WK:NotifyChanged()
    return i
end

-- Code de partage : WKP1:CLASSE:arbre.n°,arbre.n°,…
function M:Export(key, i)
    local p = store(key).list[i]
    local c = WK.DB.global.characters[key]
    if not p then return nil end
    local parts = {}
    for k, st in ipairs(p.steps) do parts[k] = st[1] .. "." .. st[2] end
    return "WKP1:" .. ((c and c.class) or "?") .. ":" .. table.concat(parts, ",")
end
function M:Import(key, code, name)
    local c = WK.DB.global.characters[key]
    if not (c and c.talents and c.talents[1] and c.talents[1].list) then return nil, T("talents de ce perso pas encore relevés") end
    local cls, body = (code or ""):match("^%s*WKP1:(%u+):([%d%.,]*)%s*$")
    if not cls then return nil, T("code non reconnu") end
    if cls ~= c.class then return nil, T("ce code est pour une autre classe") end
    local i = self:New(key, name or T("Plan importé"))
    for ti, j in body:gmatch("(%d+)%.(%d+)") do
        if not self:AddStep(key, i, tonumber(ti), tonumber(j)) then
            self:Delete(key, i)
            return nil, T("le code ne correspond pas à tes arbres")
        end
    end
    return i
end

-- Où en est le perso : points dépensés, étape suivante (n°, étape, talent), points libres
function M:Progress(key)
    local c = WK.DB.global.characters[key]
    local p = self:Active(key)
    if not (c and p) then return nil end
    local spent = 0
    for _, t in ipairs(c.talents or {}) do for _, d in ipairs(t.list or {}) do spent = spent + (d[5] or 0) end end
    local n = spent + 1
    local st = p.steps[n]
    return { plan = p, spent = spent, next = n, step = st, talent = st and self:Talent(c, st), free = c.talentFree or 0 }
end
-- Rang que le talent de l'étape n aura une fois l'étape faite
function M:StepRank(plan, n)
    local st = plan.steps[n]
    if not st then return 0 end
    return self:Ranks(plan, n)[st[1] .. ":" .. st[2]] or 0
end

-- Place le point de l'étape suivante (perso connecté, hors combat)
function M:PlaceNext()
    local key = WK:CharKey()
    local pr = self:Progress(key)
    if not (pr and pr.step) then return false, T("plan terminé ou pas de plan actif") end
    if pr.free <= 0 then return false, T("pas de point libre") end
    if InCombatLockdown and InCombatLockdown() then return false, T("pas en combat") end
    local cfgID = WK.modules.Gear.TraitConfig and WK.modules.Gear.TraitConfig()
    local node = pr.step[3] or (pr.talent and pr.talent[8])
    if not (cfgID and node and C_Traits and C_Traits.PurchaseRank) then
        return false, T("le jeu ne permet pas à l'addon de placer le point : prends-le dans la fenêtre des talents")
    end
    local ok, res = pcall(C_Traits.PurchaseRank, cfgID, node)
    if not ok or res == false then return false, T("le jeu a refusé ce point (talent pas encore accessible ?)") end
    if C_Traits.CommitConfig then pcall(C_Traits.CommitConfig, cfgID) end
    C_Timer.After(1, function() WK.modules.Gear:Scan({ talents = true }) end)
    return true
end

-- Enregistrement automatique : appelé par Modules/Gear.lua avec les arbres d'avant et d'après
function M:Record(c, old, new)
    if not (old and new and old[1] and old[1].list and new[1] and new[1].list) then return end
    -- même structure d'arbres seulement (sinon : autre version des données, rien à enregistrer)
    if #old ~= #new then return end
    for ti, t in ipairs(new) do
        local ot = old[ti]
        if not (ot.list and #ot.list == #t.list and (ot.list[1] and ot.list[1][1]) == (t.list[1] and t.list[1][1])) then return end
    end
    local key = WK:CharKey()
    local function total(trees) local n = 0 for _, t in ipairs(trees) do for _, d in ipairs(t.list or {}) do n = n + (d[5] or 0) end end return n end
    local s = store(key)
    local rec
    for i, p in ipairs(s.list) do if p.auto then rec = i end end
    -- talents réinitialisés : on repart de zéro
    if total(new) == 0 and rec then s.list[rec].steps = {} return end
    for ti, t in ipairs(new) do
        local ot = old[ti]
        for j, d in ipairs(t.list or {}) do
            local before = ot and ot.list and ot.list[j] and ot.list[j][5] or 0
            local now = d[5] or 0
            if now > before then
                if not rec then
                    rec = self:New(key, T(RECORDED))
                    s.list[rec].auto = true
                end
                for _ = 1, now - before do table.insert(s.list[rec].steps, { ti, j, d[8], d[1] }) end
            end
        end
    end
end

-- Alerte à chaque niveau : prochain talent du plan tant qu'il reste un point libre
function M:CheckAlert()
    local UI = WK.UI
    if UI and UI.RefreshTalentPlan then UI:RefreshTalentPlan() end
    if not (UI and UI.SetAlert) then return end
    local pr = self:Progress(WK:CharKey())
    local on = pr and pr.step and pr.talent and pr.free > 0
    UI:SetAlert("talent.plan", on and true or false, {
        text = on and string.format(T("Prochain talent : %s (%d/%d)"), pr.talent[1], self:StepRank(pr.plan, pr.next), pr.talent[6] or 1) or "",
        prio = 3, icon = on and pr.talent[2] or nil })
end
WK:On("PLAYER_LEVEL_UP", function() C_Timer.After(3, function() M:CheckAlert() end) end)
WK:On("PLAYER_ENTERING_WORLD", function() C_Timer.After(6, function() M:CheckAlert() end) end)
