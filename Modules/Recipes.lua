local ADDON_NAME, WK = ...
local M = WK:NewModule("Recipes")
local T = function(s) return WK.T(s) end

-- Recettes connues de chaque personnage, lues à l'ouverture de la fenêtre de métier.
-- c.recipes[clé] = { name, icon, prof, out = itemID produit, qty = quantité produite,
--                    reagents = { { itemID, count }, ... } }
-- La clé d'une recette est son nom (identique d'un perso à l'autre).
-- diff = couleur de la recette lors de la lecture : "optimal" (orange), "medium" (jaune),
--        "easy" (vert), "trivial" (gris). c.recipeScans[métier] = { t = date, rank = niveau }.

-- Couleurs du client moderne (Enum.TradeskillRelativeDifficulty : 0 orange … 3 gris).
local MODERN_DIFF = { [0] = "optimal", [1] = "medium", [2] = "easy", [3] = "trivial" }

local function keyOf(name) return name end

-- Client moderne (C_TradeSkillUI).
local function scanModern()
    local api = C_TradeSkillUI
    if (api.IsTradeSkillLinked and api.IsTradeSkillLinked()) or (api.IsTradeSkillGuild and api.IsTradeSkillGuild()) then
        return nil
    end
    local prof
    if api.GetBaseProfessionInfo then
        local info = api.GetBaseProfessionInfo()
        prof = info and info.professionName
    end
    if not prof and api.GetTradeSkillLine then prof = select(2, api.GetTradeSkillLine()) end
    local out = {}
    for _, id in ipairs(api.GetAllRecipeIDs() or {}) do
        local r = api.GetRecipeInfo(id)
        if r and r.learned and r.name then
            local rec = { name = r.name, icon = r.icon, prof = prof, qty = 1, reagents = {},
                diff = MODERN_DIFF[r.relativeDifficulty] }
            -- Temps de recharge (transmutations, étoffe lunaire…)
            if api.GetRecipeCooldown then
                local ok, cd = pcall(api.GetRecipeCooldown, id)
                if ok and type(cd) == "number" and cd > 0 then rec.cooldown = cd end
            end
            local sch = api.GetRecipeSchematic and api.GetRecipeSchematic(id, false)
            if sch then
                rec.out = sch.outputItemID
                rec.qty = sch.quantityMin or 1
                for _, slot in ipairs(sch.reagentSlotSchematics or {}) do
                    local basic = (slot.required ~= false) and (slot.reagentType == nil or slot.reagentType == 1)
                    local first = slot.reagents and slot.reagents[1]
                    if basic and first and first.itemID then
                        table.insert(rec.reagents, { first.itemID, slot.quantityRequired or 1 })
                    end
                end
            end
            out[keyOf(r.name)] = rec
        end
    end
    return out, prof
end

-- Ancien client (GetTradeSkillInfo).
local function scanClassic()
    if not GetNumTradeSkills then return nil end
    local prof = GetTradeSkillLine and GetTradeSkillLine() or nil
    local out = {}
    for i = 1, GetNumTradeSkills() do
        local name, kind = GetTradeSkillInfo(i)
        if name and kind ~= "header" and kind ~= "subheader" then
            local link = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
            local cd = GetTradeSkillCooldown and GetTradeSkillCooldown(i)
            local rec = { name = name, icon = GetTradeSkillIcon and GetTradeSkillIcon(i), prof = prof,
                cooldown = (type(cd) == "number" and cd > 0) and cd or nil,
                out = WK:ParseItemID(link), qty = 1, reagents = {},
                diff = (kind == "optimal" or kind == "medium" or kind == "easy" or kind == "trivial") and kind or nil }
            for j = 1, (GetTradeSkillNumReagents(i) or 0) do
                local _, _, count = GetTradeSkillReagentInfo(i, j)
                local id = WK:ParseItemID(GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, j))
                if id then table.insert(rec.reagents, { id, count or 1 }) end
            end
            out[keyOf(name)] = rec
        end
    end
    return out, prof
end

function M:Scan()
    local recipes, prof
    if C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs then
        recipes, prof = scanModern()
    else
        recipes, prof = scanClassic()
    end
    -- Lien de la fenêtre du métier (cliquable par les autres joueurs), gardé pour le coller plus tard.
    if prof then M:CaptureLink(prof) end
    if not recipes or not next(recipes) then return end
    local c = WK.DB:Me()
    c.recipes = c.recipes or {}
    -- On remplace les recettes de ce métier seulement.
    for k, r in pairs(c.recipes) do
        if prof and r.prof == prof then c.recipes[k] = nil end
    end
    -- Temps de recharge : on retient l'heure où la recette sera prête (gardée tant qu'on ne la refait pas).
    c.cooldowns = c.cooldowns or {}
    for k, r in pairs(recipes) do
        if r.cooldown then
            c.cooldowns[k] = { prof = r.prof or prof, readyAt = time() + r.cooldown, out = r.out }
        end
        r.cooldown = nil
        c.recipes[k] = r
    end
    if prof then
        c.recipeScans = c.recipeScans or {}
        local p = c.professions and c.professions[prof]
        c.recipeScans[prof] = { t = time(), rank = p and p.rank }
    end
    WK:NotifyChanged()
end

local pending = false
local function schedule()
    if pending then return end
    pending = true
    C_Timer.After(1, function() pending = false; M:Scan() end)
end
WK:On("TRADE_SKILL_SHOW", schedule)
WK:On("TRADE_SKILL_LIST_UPDATE", schedule)
WK:On("TRADE_SKILL_DATA_SOURCE_CHANGED", schedule)

---------------------------------------------------------------------------
-- Index du compte : qui sait fabriquer quoi.
---------------------------------------------------------------------------
-- Recettes en recharge ou prêtes d'un perso : { key, prof, readyAt, ready }.
function M:Cooldowns(c)
    local out, now = {}, time()
    for k, cd in pairs(c and c.cooldowns or {}) do
        table.insert(out, { key = k, prof = cd.prof, readyAt = cd.readyAt, out = cd.out, ready = cd.readyAt <= now })
    end
    table.sort(out, function(a, b) return a.readyAt < b.readyAt end)
    return out
end

-- Recettes d'un perso pour un métier, triées : orange, jaune, vert, gris, puis par nom.
local DIFF_ORDER = { optimal = 1, medium = 2, easy = 3, trivial = 4 }
function M:ForProfession(c, prof)
    local list = {}
    for k, r in pairs(c and c.recipes or {}) do
        if r.prof == prof then
            table.insert(list, { key = k, name = r.name, icon = r.icon, prof = r.prof, out = r.out,
                qty = r.qty or 1, reagents = r.reagents, diff = r.diff })
        end
    end
    table.sort(list, function(a, b)
        local da, db = DIFF_ORDER[a.diff] or 5, DIFF_ORDER[b.diff] or 5
        if da ~= db then return da < db end
        return a.name < b.name
    end)
    return list
end

function M:All()
    local index = {}
    for key, c in pairs(WK.DB.global.characters) do
        for k, r in pairs(c.recipes or {}) do
            local e = index[k]
            if not e then
                e = { key = k, name = r.name, icon = r.icon, prof = r.prof, out = r.out, qty = r.qty or 1,
                    reagents = r.reagents, crafters = {} }
                index[k] = e
            end
            table.insert(e.crafters, key)
        end
    end
    local list = {}
    for _, e in pairs(index) do table.insert(list, e) end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list, index
end

-- Nombre de fabrications possibles avec le stock de tout le compte.
function M:Craftable(rec)
    if not rec.reagents or #rec.reagents == 0 then return nil end
    local n = math.huge
    for _, rg in ipairs(rec.reagents) do
        local have = WK.modules.Inventory:AccountCount(rg[1])
        n = math.min(n, math.floor(have / math.max(1, rg[2])))
    end
    return n
end

-- Rentabilité d'une recette au prix actuel (Auctionator, sinon marchand) :
-- cost = prix des composants, sale = prix de l'objet fabriqué x quantité produite,
-- profit = sale - cost (nil si l'objet fabriqué n'a pas de prix connu).
function M:Economics(rec)
    local V = WK.modules.Value
    local cost = 0
    for _, rg in ipairs(rec.reagents or {}) do cost = cost + V:Price(rg[1]) * rg[2] end
    local sale
    if rec.out then
        local p = V:Price(rec.out)
        if p and p > 0 then sale = p * (rec.qty or 1) end
    end
    return cost, sale, sale and (sale - cost) or nil
end

---------------------------------------------------------------------------
-- Liste de courses : WK.DB.global.shopping[clé de recette] = nombre de fabrications.
---------------------------------------------------------------------------
function M:AddToList(key, n)
    local list = WK.DB.global.shopping
    list[key] = math.max(0, (list[key] or 0) + (n or 1))
    if list[key] == 0 then list[key] = nil end
    WK:NotifyChanged()
end

function M:ClearList()
    wipe(WK.DB.global.shopping)
    WK:NotifyChanged()
end

-- Composants nécessaires : { { itemID, need, have, missing, cost }, ... } et coût total manquant.
function M:Needs()
    local _, index = self:All()
    local need = {}
    for key, crafts in pairs(WK.DB.global.shopping) do
        local rec = index[key]
        if rec then
            for _, rg in ipairs(rec.reagents or {}) do
                need[rg[1]] = (need[rg[1]] or 0) + rg[2] * crafts
            end
        end
    end
    local out, total = {}, 0
    for id, n in pairs(need) do
        local have = WK.modules.Inventory:AccountCount(id)
        local missing = math.max(0, n - have)
        local cost = missing * WK.modules.Value:Price(id)
        total = total + cost
        table.insert(out, { itemID = id, need = n, have = have, missing = missing, cost = cost })
    end
    table.sort(out, function(a, b)
        if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
        return a.cost > b.cost
    end)
    return out, total
end

---------------------------------------------------------------------------
-- Guides de montée (Modules/Guides.lua, d'après les guides WoW Forever).
---------------------------------------------------------------------------
function M:Guide(prof) return WK.Guides and WK.Guides[prof] end

-- Prix d'un composant : source de prix choisie, sinon prix noté dans le guide.
function M:GuidePrice(id)
    local p = WK.modules.Value:Price(id)
    if (not p or p == 0) and WK.GuidePrices then p = WK.GuidePrices[id] or 0 end
    return p or 0
end

-- Objets que ce perso sait déjà fabriquer (pour ne pas compter les recettes déjà apprises).
function M:KnownOutputs(c)
    local known = { names = {} }
    for k, r in pairs(c and c.recipes or {}) do
        if r.out then known[r.out] = true end
        known.names[r.name or k] = true -- enchantements : pas d'objet fabriqué, on compare le nom
    end
    return known
end

-- La recette de cette étape est-elle déjà connue ?
function M:StepKnown(st, known)
    if not known then return false end
    if st.out and known[st.out] then return true end
    local name = st.spell and WK.SpellInfo(st.spell)
    return name ~= nil and known.names ~= nil and known.names[name] == true
end

-- Plan pour un niveau : étapes (status "done" / "current" / "todo", left = fabrications restantes)
-- et matériaux jusqu'au maximum { itemID, need, have, missing, unit, cost, recipe? }, recettes à
-- acheter comprises (sauf celles déjà connues : known = { [objet fabriqué] = true }).
function M:GuidePlan(prof, rank, known)
    local g = self:Guide(prof)
    if not g then return nil end
    rank = rank or 0
    -- Objets fabriqués par le guide lui-même (peaux traitées, bandages…) : on ne les achète pas,
    -- leurs composants sont déjà comptés dans l'étape qui les fabrique. Exception : les objets
    -- « skillOnly » (cuirs…) qu'on fabrique juste pour monter : il faut s'en procurer le reste.
    local skillOnly = g.skillOnly or {}
    local made, produced = {}, {}
    for _, st in ipairs(g.steps) do
        if st.out then made[st.out] = true end
        for _, f in ipairs(st.first or {}) do if f.out then made[f.out] = true end end
    end
    local steps, need = {}, {}
    local learns
    for _, st in ipairs(g.steps) do
        local status, ratio
        if rank >= st.to then status, ratio = "done", 0
        elseif rank >= st.from then status, ratio = "current", (st.to - rank) / math.max(1, st.to - st.from)
        else status, ratio = "todo", 1 end
        local left = math.ceil(st.crafts * ratio)
        table.insert(steps, { step = st, status = status, left = left })
        -- Recette à acheter (une seule fois, même si plusieurs étapes l'utilisent)
        if status ~= "done" and st.learn and not self:StepKnown(st, known) then
            need[st.learn] = 1
            learns = learns or {}
            learns[st.learn] = learns[st.learn] or { vendors = st.vendors, from = st.from, to = st.to }
        end
        local function add(s, n)
            for _, rg in ipairs(s.reagents or {}) do need[rg[1]] = (need[rg[1]] or 0) + rg[2] * n end
        end
        -- Outils achetés (marteau de forgeron…) : un seul exemplaire suffit
        if status ~= "done" then
            for _, tool in ipairs(st.tools or {}) do
                if not made[tool] then need[tool] = math.max(need[tool] or 0, 1) end
            end
        end
        if left > 0 then
            add(st, left)
            if st.out then produced[st.out] = (produced[st.out] or 0) + left * (st.qty or 1) end
            for _, f in ipairs(st.first or {}) do
                local n = math.ceil(f.crafts * ratio)
                add(f, n)
                if f.out then produced[f.out] = (produced[f.out] or 0) + n * (f.qty or 1) end
            end
        end
    end
    local mats, total = {}, 0
    for id, n in pairs(need) do
        if skillOnly[id] then n = math.max(0, n - (produced[id] or 0)) end
        if n > 0 and (not made[id] or skillOnly[id]) then
            local have = WK.modules.Inventory:AccountCount(id)
            local missing = math.max(0, n - have)
            local unit = self:GuidePrice(id)
            local cost = missing * unit
            total = total + cost
            table.insert(mats, { itemID = id, need = n, have = have, missing = missing, unit = unit, cost = cost,
                recipe = learns and learns[id] or nil })
        end
    end
    table.sort(mats, function(a, b)
        if (a.missing > 0) ~= (b.missing > 0) then return a.missing > 0 end
        if a.cost ~= b.cost then return a.cost > b.cost end
        return a.itemID < b.itemID
    end)
    return steps, mats, total, g
end

---------------------------------------------------------------------------
-- Lien du métier dans le chat : lien de la fenêtre (enregistré à la dernière ouverture)
-- + texte personnalisé du métier s'il est activé. Sans lien, un résumé en texte.
---------------------------------------------------------------------------
-- Lien du métier ouvert : on essaie toutes les fonctions du jeu qui peuvent le donner
-- (la version moderne peut exister et ne rien renvoyer sur ce client).
M.linkDiag = {}
function M:CaptureLink(prof)
    local tries = {
        { "C_TradeSkillUI.GetTradeSkillListLink", C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillListLink },
        { "GetTradeSkillListLink", GetTradeSkillListLink },
        { "GetCraftListLink", GetCraftListLink },
    }
    local diag = { prof = prof, t = time(), results = {} }
    for _, tr in ipairs(tries) do
        local name, fn = tr[1], tr[2]
        if not fn then
            table.insert(diag.results, name .. " : absente")
        else
            local ok, link = pcall(fn)
            table.insert(diag.results, name .. " : " .. (ok and (type(link) == "string" and link ~= "" and "lien reçu" or "rien") or "erreur"))
            if ok and type(link) == "string" and link ~= "" then
                self:SaveLink(prof, link)
                diag.saved = true
                break
            end
        end
    end
    self.linkDiag = diag
end

function M:SaveLink(prof, link)
    local me = WK.DB:Me()
    me.profLinks = me.profLinks or {}
    me.profLinks[prof] = { link = link, t = time() }
    WK:NotifyChanged()
    M:FinishPendingLink(prof)
end

-- Un lien de métier mis dans le chat depuis la fenêtre du jeu (bouton de lien, Maj + clic) est
-- aussi retenu : « [Couture] » est rattaché au métier du perso qui porte ce nom.
local function captureFromChat(text)
    if type(text) ~= "string" or not string.find(text, "|Htrade:", 1, true) then return end
    local link = string.match(text, "(|c%x+|Htrade:.-|h.-|h|r)") or string.match(text, "(|Htrade:.-|h.-|h)")
    if not link then return end
    local label = string.match(link, "|h%[?(.-)%]?|h") or ""
    for prof in pairs(WK.DB:Me().professions or {}) do
        if string.find(string.lower(label), string.lower(prof), 1, true) then
            M:SaveLink(prof, link)
            return
        end
    end
end
if hooksecurefunc then
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", captureFromChat) end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", captureFromChat) end
    if SendChatMessage then hooksecurefunc("SendChatMessage", captureFromChat) end
end
WK:On("CRAFT_SHOW", function() C_Timer.After(0.5, function()
    local name = GetCraftDisplaySkillLine and GetCraftDisplaySkillLine() or (GetCraftName and GetCraftName())
    if name then M:CaptureLink(name) end
end) end)

-- /wk lien : ce que le jeu a répondu à la dernière ouverture d'un métier, et les liens gardés.
function M:LinkReport()
    local d = self.linkDiag
    if not d or not d.prof then
        WK:Print(T("Aucun métier ouvert depuis la connexion : ouvre la fenêtre d'un métier puis refais /wk lien."))
    else
        WK:Print(string.format(T("Dernier métier ouvert : %s"), d.prof))
        for _, r in ipairs(d.results) do WK:Print("  " .. r) end
    end
    local me = WK.DB:Me()
    local n = 0
    for prof, l in pairs(me.profLinks or {}) do
        n = n + 1
        WK:Print("  " .. prof .. " : " .. (l.link or "?"))
    end
    if n == 0 then WK:Print(T("Aucun lien de métier gardé pour ce perso.")) end
end

function M:LinkSettings(prof)
    local all = WK.DB.global.settings.profLink
    all[prof] = all[prof] or { text = "", on = false }
    return all[prof]
end

function M:LinkText(c, key, prof)
    local pr = c and c.professions and c.professions[prof] or {}
    local saved = c and c.profLinks and c.profLinks[prof]
    local text
    if saved and saved.link then
        text = saved.link
    else
        text = string.format("%s %d/%d", prof, pr.rank or 0, pr.max or 0)
    end
    local cfg = self:LinkSettings(prof)
    if cfg.on and cfg.text and cfg.text ~= "" then text = text .. " " .. cfg.text end
    return text, saved ~= nil
end

function M:LinkToChat(c, key, prof)
    local text, real = self:LinkText(c, key, prof)
    if real then WK.ChatInsert(text) return end
    -- Herboristerie, Dépeçage, Pêche : pas de fenêtre de métier, donc pas de lien. Nom et niveau.
    local kind = WK.modules.Gathering:Kind(prof)
    if kind == "herb" or kind == "skin" or prof == "Pêche" or prof == "Fishing" then
        WK.ChatInsert(text)
        return
    end
    -- Pas encore de lien : pour le perso connecté, on ouvre le métier une fois (le lien est lu à
    -- l'ouverture), on le referme et on colle le lien. Sinon, on explique quoi faire.
    if key == select(2, WK.DB:Me()) and WK.modules.Professions:OpenDirect(prof) then
        local token = {}
        self.pendingLink = { prof = prof, key = key, c = c, token = token }
        C_Timer.After(3, function()
            local p = M.pendingLink
            if p and p.token == token then
                M.pendingLink = nil
                WK.ChatInsert((M:LinkText(c, key, prof)))
                WK:Print(string.format(T("Le jeu n'a pas donné le lien de %s : seul le nom et le niveau sont envoyés."), prof))
            end
        end)
        return
    end
    WK.ChatInsert(text)
    if key == select(2, WK.DB:Me()) then
        WK:Print(string.format(T("Lien de %s pas encore enregistré : ouvre une fois la fenêtre du métier (bouton « Ouvrir le métier »), puis réessaie."), prof))
    else
        WK:Print(string.format(T("Lien de %s pas encore enregistré pour %s : connecte ce perso et ouvre une fois la fenêtre du métier."), prof, WK:CharName(c, key)))
    end
end

-- Le lien demandé par « Lier dans le chat » vient d'arriver : on referme la fenêtre ouverte pour lui.
function M:FinishPendingLink(prof)
    local p = self.pendingLink
    if not p or p.prof ~= prof then return end
    self.pendingLink = nil
    if C_TradeSkillUI and C_TradeSkillUI.CloseTradeSkill then pcall(C_TradeSkillUI.CloseTradeSkill)
    elseif CloseTradeSkill then pcall(CloseTradeSkill) end
    C_Timer.After(0.1, function() WK.ChatInsert((M:LinkText(p.c, p.key, prof))) end)
end

---------------------------------------------------------------------------
-- Recettes manquantes (Modules/RecipeDB.lua : toutes les recettes de chaque métier).
---------------------------------------------------------------------------
-- Recettes que ce perso ne connaît pas, triées par niveau requis.
-- Renvoie la liste et le nombre de recettes du métier dans la base.
function M:Missing(c, prof)
    local db = WK.RecipeDB and WK.RecipeDB[prof]
    if not db then return nil end
    local known = self:KnownOutputs(c)
    local list = {}
    for _, r in ipairs(db) do
        local isKnown = (r.o and known[r.o]) or false
        if not isKnown then
            local name = WK.SpellInfo(r.s)
            isKnown = name ~= nil and known.names[name] == true
        end
        if not isKnown then table.insert(list, r) end
    end
    return list, #db
end

-- Composants manquants du guide vers une liste de courses Auctionator.
function M:GuideToAuctionator(prof, rank, known)
    local _, mats = self:GuidePlan(prof, rank, known)
    local list = {}
    for _, m in ipairs(mats or {}) do if m.missing > 0 then table.insert(list, m) end end
    return self:ExportToAuctionator(list, "Warband Keeper - " .. prof)
end

-- Règles d'envoi pour que les composants du guide arrivent à ce perso (sans toucher aux
-- règles existantes). Renvoie le nombre de règles ajoutées et ignorées.
function M:GuideMailRules(prof, key)
    local c = WK.DB.global.characters[key]
    local _, mats = self:GuidePlan(prof, c and c.professions and c.professions[prof] and c.professions[prof].rank or 0,
        self:KnownOutputs(c))
    if not c or not mats then return 0, 0 end
    local to = WK.modules.Mail:MailName(c)
    local rules = WK.DB.global.mail.rules
    local added, skipped = 0, 0
    for _, m in ipairs(mats) do
        if m.recipe then -- les recettes s'achètent chez un vendeur : pas de règle d'envoi
        elseif rules[m.itemID] then skipped = skipped + 1
        else rules[m.itemID] = { to = to, keep = 0 }; added = added + 1 end
    end
    WK.modules.Statistics:UpdateItems()
    WK:NotifyChanged()
    return added, skipped
end

-- Crée une liste de courses Auctionator avec les composants manquants
-- (ceux de la liste de courses, ou la liste { itemID, missing } donnée).
function M:ExportToAuctionator(entries, listName)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.CreateShoppingList then
        WK:Print(T("Auctionator n'est pas disponible."))
        return false
    end
    local terms, unknown = {}, 0
    for _, e in ipairs(entries or (self:Needs())) do
        if e.missing > 0 then
            local name = WK.GetItemInfo(e.itemID)
            if not name then
                unknown = unknown + 1
                if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(e.itemID) end
            else
                local term = name
                if api.ConvertToSearchString then
                    local ok, s = pcall(api.ConvertToSearchString, ADDON_NAME,
                        { searchString = name, isExact = true, quantity = e.missing })
                    if ok and s then term = s end
                end
                table.insert(terms, term)
            end
        end
    end
    if unknown > 0 then
        WK:Print(string.format(T("%d objet(s) pas encore chargés par le jeu : réessaie dans un instant."), unknown))
        if #terms == 0 then return false end
    end
    if #terms == 0 then
        WK:Print(T("Rien à acheter : tu as déjà tous les composants."))
        return false
    end
    listName = listName or "Warband Keeper"
    local ok, err = pcall(api.CreateShoppingList, ADDON_NAME, listName, terms)
    if ok then
        WK:Print(string.format(T("Liste « %s » créée dans Auctionator (%d objet(s))."), listName, #terms))
    else
        WK:Print(T("Auctionator a refusé la liste : ") .. tostring(err))
    end
    return ok
end
