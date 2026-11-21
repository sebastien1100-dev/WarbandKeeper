local ADDON_NAME, WK = ...
local T = function(s) return WK.T(s) end

-- Quêtes automatiques : prendre et rendre les quêtes en parlant au PNJ, choisir la récompense.
-- Trois modes (réglage WK.DB.global.autoQuest.mode) :
--   « manual » : rien d'automatique ;
--   « assist » : prend les quêtes cochées (Quêtes de ma zone, tournée), rend les quêtes finies ; la
--                récompense est laissée au joueur quand il y a un choix ;
--   « auto »   : prend et rend tout (avec les exceptions), choisit la récompense (reward = me / price).
-- Détails : pickChecked (assisté : toujours), noHigh, noGroup, skipGossip, share, noGold, fallbackPrice,
-- shift (Maj enfoncée = manuel), chat, buy / buyCap (objets de quête achetés chez le marchand, UI/BagHelp.lua),
-- quests[n°] / npcs[n°] = nom (jamais d'automatique), log (5 dernières).
local M = {}
WK.modules.AutoQuest = M

function M:Config()
    local g = WK.DB.global
    g.autoQuest = g.autoQuest or {}
    local c = g.autoQuest
    if c.mode == nil then c.mode = "assist" end
    if c.reward == nil then c.reward = "me" end
    for k, v in pairs({ noHigh = true, noGroup = true, skipGossip = true, share = false, noGold = true,
        fallbackPrice = true, shift = true, chat = true, buy = false }) do
        if c[k] == nil then c[k] = v end
    end
    c.buyCap = c.buyCap or 10000 -- achat d'objets de quête sans confirmer jusqu'à 1 po
    c.quests = c.quests or {}
    c.npcs = c.npcs or {}
    c.log = c.log or {}
    return c
end
local function on() return WK:FeatureOn("quests") end

-- n° de PNJ d'un GUID « Creature-0-…-n°-… » (6e partie)
local function idOf(guid)
    if type(guid) ~= "string" then return nil end
    local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end
local function npcID() return idOf(UnitGUID and UnitGUID("npc")) end
local function suspended()
    local c = M:Config()
    if not on() or c.mode == "manual" then return true end
    if c.shift and IsShiftKeyDown and IsShiftKeyDown() then return true end
    local id = npcID()
    if id and c.npcs[id] then return true end
    return false
end

function M:Note(kind, text)
    local c = self:Config()
    table.insert(c.log, 1, { t = time(), k = kind, s = text })
    while #c.log > 5 do table.remove(c.log) end
    if c.chat then
        local col = kind == "turn" and WK.UI.colors.positive or { WK.UI:Accent() }
        WK:Print(WK.UI:Hex(col) .. (kind == "turn" and T("Rendue :") or T("Prise :")) .. "|r " .. text)
    end
    WK:NotifyChanged()
end

---------------------------------------------------------------------------
-- Prendre
---------------------------------------------------------------------------
-- quête cochée dans « Quêtes de ma zone » (ou d'office), ou dans une étape « prendre » de la tournée
local function checked(qid)
    local P = WK.modules.QuestPlan
    if not P then return false end
    local picked = P:Config().picked[WK:CharKey()] or {}
    if picked[qid] ~= nil then return picked[qid] end
    local t = P:Tour()
    for _, s in ipairs(t and t.steps or {}) do
        if s.kind == "pick" then for _, q in ipairs(s.qids) do if q == qid then return true end end end
    end
    -- pas de choix noté : cochée d'office si son niveau va (même règle que la liste)
    local q = WK.modules.Quests and WK.modules.Quests:Get(qid)
    local lvl = UnitLevel and UnitLevel("player") or 1
    return q ~= nil and (q.lvl or 0) <= lvl + (P:Config().maxAbove or 2)
end
local function tooHigh(qid, level)
    local lvl = UnitLevel and UnitLevel("player") or 1
    local q = WK.modules.Quests and WK.modules.Quests:Get(qid)
    local ql = level or (q and q.lvl)
    local P = WK.modules.QuestPlan
    return ql ~= nil and ql > lvl + ((P and P:Config().maxAbove) or 2)
end
function M:WantPick(qid, level)
    local c = self:Config()
    if suspended() or not qid or c.quests[qid] then return false end
    if c.mode == "assist" then return checked(qid) end
    if c.noHigh and tooHigh(qid, level) then return false end
    if c.noGroup and WK.QuestIsGroup(qid) then return false end
    return true
end

---------------------------------------------------------------------------
-- Rendre et récompense
---------------------------------------------------------------------------
function M:WantTurn(qid)
    local c = self:Config()
    if suspended() or (qid and c.quests[qid]) then return false end
    return true
end
-- n° de la récompense à prendre parmi n, ou nil (laissé au joueur)
function M:PickReward(n)
    local c = self:Config()
    if n <= 1 then return 1 end
    if c.mode ~= "auto" then return nil end
    local BH = WK.modules.BagHelp
    local best, bestGain, priciest, bestPrice
    for i = 1, n do
        local link = GetQuestItemLink and GetQuestItemLink("choice", i)
        if link then
            if c.reward == "me" and BH and BH.Upgrade then
                local ok, slot, gain = pcall(BH.Upgrade, BH, link)
                if ok and slot and gain and (not bestGain or gain > bestGain) then best, bestGain = i, gain end
            end
            local id = WK:ParseItemID(link)
            local price = (id and WK.modules.Value and WK.modules.Value:Price(id)) or 0
            if price <= 0 and WK.GetItemInfo then price = select(11, WK.GetItemInfo(link)) or 0 end
            if not bestPrice or price > bestPrice then priciest, bestPrice = i, price end
        end
    end
    if best then return best, "upgrade" end
    if c.reward == "price" or c.fallbackPrice then return priciest, "price" end
    return nil
end

---------------------------------------------------------------------------
-- Évènements de la fenêtre de quête et du dialogue
---------------------------------------------------------------------------
local G = C_GossipInfo
-- Marchand qui vend un objet demandé par une quête du journal (Modules/QuestTrack.lua : BuyMissing) : son
-- dialogue peut avoir plusieurs choix (quêtes, foyer, « Je voudrais acheter ») ; on ouvre sa boutique
local function sellsNeeded()
    local QT = WK.modules.QuestTrack
    local name = UnitName and UnitName("npc")
    -- données pas chargées : rien à vérifier (avant, le premier dialogue avec un banquier ou un maître de vol
    -- chargeait tout le dossier WarbandKeeper_Data pour ce test)
    if not (QT and QT.BuyMissing and name and WK.dataLoaded) then return false end
    for _, l in ipairs(QT:LogQuests()) do
        for _, it in ipairs(QT:BuyMissing(l.id)) do
            for _, v in ipairs(QT:Vendors(it.id)) do
                if v.name == name or QT:VendorName(v) == name then return true end
            end
        end
    end
    return false
end
M.SellsNeeded = sellsNeeded
-- choix « boutique » du dialogue : n° de l'option, ou nil
local function vendorOption()
    if G and G.GetOptions then
        local ok, opts = pcall(G.GetOptions)
        for i, o in ipairs(ok and opts or {}) do
            local icon = o.icon
            if o.type == "vendor" or icon == 132060 or (type(icon) == "string" and icon:lower():find("vendorgossipicon", 1, true)) then
                return o.gossipOptionID or o.orderIndex or i, o.gossipOptionID ~= nil
            end
        end
    end
    if GetGossipOptions then
        local t = { GetGossipOptions() }
        for i = 1, #t, 2 do if t[i + 1] == "vendor" then return (i + 1) / 2, false end end
    end
    return nil
end
local function openShop()
    local id, isID = vendorOption()
    if not id then return false end
    if isID and G.SelectOption then G.SelectOption(id)
    elseif G and G.SelectOptionByIndex then G.SelectOptionByIndex(id)
    elseif SelectGossipOption then SelectGossipOption(id)
    else return false end
    return true
end

WK:On("GOSSIP_SHOW", function()
    if suspended() or not G then return end
    -- « sauter le dialogue » coupé : on attend que le joueur ouvre la quête lui-même ; la boutique d'un marchand
    -- qui vend un objet de quête s'ouvre quand même (après les quêtes de ce PNJ)
    if not M:Config().skipGossip then
        if sellsNeeded() then openShop() end
        return
    end
    -- d'abord rendre une quête finie, puis prendre une quête voulue
    local okA, active = pcall(G.GetActiveQuests)
    for _, q in ipairs(okA and active or {}) do
        if q.isComplete and M:WantTurn(q.questID) then return G.SelectActiveQuest(q.questID) end
    end
    local okB, avail = pcall(G.GetAvailableQuests)
    for _, q in ipairs(okB and avail or {}) do
        if not M.IsRepeatableOffer(q.questID, q.frequency, q.repeatable) and M:WantPick(q.questID, q.questLevel) then
            return G.SelectAvailableQuest(q.questID)
        end
    end
    if sellsNeeded() then openShop() end
end)
-- Quête répétable proposée (journalière, hebdomadaire, répétable) : valeurs du jeu comparées à ses propres
-- constantes (Enum.QuestFrequency ou LE_QUEST_FREQUENCY_*, dont la valeur « normale » change selon les clients),
-- puis la liste de la base ; jamais prise en mode auto, ni au dialogue ni à l'accueil
function M.IsRepeatableOffer(qid, freq, rep)
    if rep == true then return true end
    if type(freq) == "number" then
        local E = _G.Enum and _G.Enum.QuestFrequency
        local daily = (E and E.Daily) or _G.LE_QUEST_FREQUENCY_DAILY
        local weekly = (E and E.Weekly) or _G.LE_QUEST_FREQUENCY_WEEKLY
        if (daily and freq == daily) or (weekly and freq == weekly) then return true end
    end
    local Qs = WK.modules.Quests
    return qid and Qs and Qs.IsRepeatable and Qs:IsRepeatable(qid) and true or false
end
WK:On("QUEST_GREETING", function()
    if suspended() then return end
    for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
        local _, complete = GetActiveTitle(i)
        local qid = GetActiveQuestID and GetActiveQuestID(i)
        if complete and M:WantTurn(qid) then return SelectActiveQuest(i) end
    end
    for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
        -- (trivial, fréquence, répétable, légendaire, n°) : les répétables et journalières sont laissées, comme
        -- au dialogue (GOSSIP_SHOW) ; avant, un PNJ sans dialogue en donnait une sans le vouloir
        local qid, freq, rep
        if GetAvailableQuestInfo then
            local _, f, r, _, id = GetAvailableQuestInfo(i)
            qid, freq, rep = id, f, r
        end
        if not M.IsRepeatableOffer(qid, freq, rep) and M:WantPick(qid) then return SelectAvailableQuest(i) end
    end
end)
WK:On("QUEST_DETAIL", function()
    local qid = GetQuestID and GetQuestID()
    if not M:WantPick(qid) then return end
    -- quête répétable ouverte directement en détail (PNJ à une seule quête, clic dans le dialogue) : laissée
    -- aussi (avant, seuls le dialogue et l'accueil l'écartaient)
    local daily = (_G.QuestIsDaily and _G.QuestIsDaily()) or (_G.QuestIsWeekly and _G.QuestIsWeekly())
    if daily or M.IsRepeatableOffer(qid) then return end
    local c = M:Config()
    if c.noGroup and GetSuggestedGroupNum and (GetSuggestedGroupNum() or 0) > 1 then return end
    local title = GetTitleText and GetTitleText() or ("#" .. tostring(qid))
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
    else
        AcceptQuest()
    end
    M:Note("pick", title)
    if c.share and IsInGroup and IsInGroup() and C_QuestLog and C_QuestLog.SetSelectedQuest and QuestLogPushQuest then
        C_Timer.After(0.5, function()
            pcall(C_QuestLog.SetSelectedQuest, qid)
            pcall(QuestLogPushQuest)
        end)
    end
end)
WK:On("QUEST_PROGRESS", function()
    local qid = GetQuestID and GetQuestID()
    if not M:WantTurn(qid) then return end
    if IsQuestCompletable and IsQuestCompletable() then CompleteQuest() end
end)
WK:On("QUEST_COMPLETE", function()
    local qid = GetQuestID and GetQuestID()
    if not M:WantTurn(qid) then return end
    local c = M:Config()
    if c.noGold and GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
    local n = GetNumQuestChoices and GetNumQuestChoices() or 0
    local pick, why = M:PickReward(n)
    if not pick then return end
    local title = GetTitleText and GetTitleText() or ("#" .. tostring(qid))
    local reward = n > 1 and GetQuestItemLink and GetQuestItemLink("choice", pick) or nil
    GetQuestReward(n > 0 and pick or nil)
    M:Note("turn", title .. (reward and (" · " .. reward .. (why == "upgrade" and (" (" .. T("amélioration") .. ")") or "")) or ""))
end)

-- Exceptions : la quête suivie, ou le PNJ ciblé
function M:BlockQuest(qid, v)
    if qid then self:Config().quests[qid] = v and true or nil end
    WK:NotifyChanged()
end
function M:BlockNpc(id, name, v)
    if id then self:Config().npcs[id] = v and (name or ("#" .. id)) or nil end
    WK:NotifyChanged()
end
function M:TargetNpc()
    local id = idOf(UnitGUID and UnitGUID("target"))
    if not id then return nil end
    return id, UnitName("target")
end
