local ADDON_NAME, WK = ...
local M = WK:NewModule("Mail")
local T = function(s) return WK.T(s) end

local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12
local MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16
local MAIL_DAYS = 30 -- durée de conservation d'un courrier envoyé à un joueur

-- File d'envoi : liste de { recipient, items = { {bag, slot, count, split}, ... } } (1 courrier par entrée).
local queue = {}
local sending = false
local sentSummary = {} -- [destinataire] = objets envoyés pendant cette ouverture de la boîte
local lastError        -- dernier message d'erreur du jeu pendant un envoi (diagnostic)
local current -- courrier en cours d'envoi (pour le créditer au destinataire)

---------------------------------------------------------------------------
-- Noms des personnages. Sur WoW Forever un nom est en deux parties (« Prénom Nom »)
-- et le courrier demande le nom complet. Chaque perso garde :
--   name     : ce que renvoie UnitName ;
--   fullName : le nom complet détecté à la connexion (s'il contient un espace) ;
--   mailName : le nom saisi à la main pour le courrier (prioritaire).
---------------------------------------------------------------------------
local function norm(s)
    s = string.lower(s or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    return s
end
local function words(s)
    local t = {}
    for w in string.gmatch(norm(s), "[^ ]+") do table.insert(t, w) end
    return t
end

-- Nom à mettre dans le champ « À : » pour ce personnage.
function M:MailName(c)
    if not c then return end
    return WK:CharName(c)
end

-- Personnage du compte désigné par un destinataire (« Prénom Nom », « Prénom »,
-- « Nom-Royaume »…). Nom exact d'abord ; sinon un seul mot du nom, s'il ne
-- correspond qu'à un seul perso du royaume. Renvoie c, key.
function M:Resolve(recipient)
    if not recipient or recipient == "" then return end
    local name, realm = string.match(recipient, "^([^%-]+)%-?(.*)$")
    name = norm(name or recipient)
    realm = (realm and realm ~= "") and string.lower(realm):gsub("%s", "") or nil
    local myRealm = string.lower(GetRealmName() or ""):gsub("%s", "")
    local partial, partialKey, partialCount = nil, nil, 0
    for key, c in pairs(WK.DB.global.characters) do
        local cr = string.lower(c.realm or ""):gsub("%s", "")
        if c.name and cr == (realm or myRealm) then
            -- (pas d'ipairs : mailName ou fullName peuvent être nil)
            if norm(c.mailName) == name or norm(c.fullName) == name or norm(c.name) == name then return c, key end
            if not string.find(name, " ", 1, true) then
                local full = words(M:MailName(c))
                if #full > 1 and (full[1] == name or full[#full] == name) then
                    partial, partialKey, partialCount = c, key, partialCount + 1
                end
            end
        end
    end
    if partialCount == 1 then return partial, partialKey end
end

-- Le destinataire est-il le personnage connecté ?
function M:IsMe(recipient)
    local _, key = self:Resolve(recipient)
    if key then return key == select(2, WK.DB:Me()) end
    return norm(recipient):match("^[^%-]+") == norm(UnitName("player"))
end
local function isMe(name) return M:IsMe(name) end

-- Nom réellement envoyé : le nom complet d'un perso du compte, sinon le texte saisi.
function M:Recipient(to)
    local c = self:Resolve(to)
    return c and self:MailName(c) or to
end

-- Corrige à la main le nom de courrier d'un perso (vide = détection automatique).
function M:SetMailName(key, name)
    local c = WK.DB.global.characters[key]
    if not c then return end
    name = (name or ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")
    c.mailName = name ~= "" and name or nil
    WK:Print(string.format(T("Nom complet de %s : %s"), c.name or key, M:MailName(c)))
    WK:NotifyChanged()
end

-- /wk nom : ce que le jeu renvoie pour le perso connecté (pour régler un souci de courrier).
function M:PrintNames()
    local c = WK.DB:Me()
    local function show(label, ...)
        local parts = {}
        for i = 1, select("#", ...) do table.insert(parts, "« " .. tostring((select(i, ...))) .. " »") end
        WK:Print(string.format("  %s : %s", label, table.concat(parts, ", ")))
    end
    WK:Print(T("Noms du personnage connecté :"))
    show("UnitName", UnitName("player"))
    if GetUnitName then show("GetUnitName", GetUnitName("player", true)) end
    if UnitFullName then show("UnitFullName", UnitFullName("player")) end
    show(T("Nom pour le courrier"), M:MailName(c))
end

-- Règles d'envoi : objets précis + catégories. Chaque règle : { to = "Nom", keep = n }.
function M:Store()
    local mail = WK.DB.global.mail
    return { items = mail.rules, cats = mail.cats }
end

---------------------------------------------------------------------------
-- Envoi automatique
---------------------------------------------------------------------------
-- Une fois l'envoi (et la prise automatique) terminés : tri des sacs puis fermeture
-- de la boîte aux lettres, chacun selon son option.
local afterTake -- fonction à lancer quand la prise automatique a fini
local function closeMailbox()
    if CloseMail then CloseMail() elseif MailFrame and HideUIPanel then HideUIPanel(MailFrame) end
end
local function afterSend()
    local mail = WK.DB.global.mail
    if mail.sortAfter ~= false then WK.modules.Inventory:SortBags() end
    if mail.closeAfter ~= false then C_Timer.After(0.3, closeMailbox) end
end

local function plan()
    return WK.modules.Rules:Plan(M:Store(), function(rule, _, bound)
        return rule.to and rule.to ~= "" and not bound and not isMe(rule.to)
    end)
end

-- Construit la file à partir des règles et du contenu des sacs.
function M:BuildQueue()
    wipe(queue)
    local byRecipient = {}
    for _, e in ipairs(plan()) do
        local to = M:Recipient(e.rule.to)
        local list = byRecipient[to]
        if not list then list = {}; byRecipient[to] = list end
        for _, op in ipairs(e.ops) do table.insert(list, op) end
    end
    for to, ops in pairs(byRecipient) do
        for i = 1, #ops, MAX_ATTACH do
            local batch = {}
            for j = i, math.min(i + MAX_ATTACH - 1, #ops) do table.insert(batch, ops[j]) end
            table.insert(queue, { recipient = to, items = batch })
        end
    end
end

-- Nombre d'objets des sacs qui partiraient au prochain passage à la boîte aux lettres.
function M:PendingCount()
    local n = 0
    for _, e in ipairs(plan()) do
        for _, op in ipairs(e.ops) do n = n + op.count end
    end
    return n
end

-- Envoie le prochain courrier de la file. La suite est déclenchée par MAIL_SEND_SUCCESS.
function M:SendNext()
    local mail = table.remove(queue, 1)
    if not mail then
        if sending then
            local parts = {}
            for who, n in pairs(sentSummary) do table.insert(parts, n .. " " .. T("à") .. " " .. who) end
            table.sort(parts)
            if #parts > 0 then WK:Print(T("Courrier envoyé : ") .. table.concat(parts, ", ")) end
            wipe(sentSummary)
            sending = false
            if WK.DB.global.mail.autoTake then
                afterTake = afterSend
                C_Timer.After(0.5, function() M:TakeAll() end)
            else
                C_Timer.After(0.5, afterSend)
            end
        end
        return
    end
    sending = true
    lastError = nil
    current = mail
    mail.content = {}
    for _, op in ipairs(mail.items) do
        local id = WK.Container.Info(op.bag, op.slot)
        if id then mail.content[id] = (mail.content[id] or 0) + op.count end
    end
    for i, op in ipairs(mail.items) do
        WK.modules.Rules:PickUp(op)
        ClickSendMailItemButton(i)
    end
    ClearCursor()
    local n = 0
    for _, op in ipairs(mail.items) do n = n + (op.count or 1) end
    sentSummary[mail.recipient] = (sentSummary[mail.recipient] or 0) + n
    local send = SendMail or (C_Mail and C_Mail.SendMail)
    send(mail.recipient, "Warband Keeper", "")
end

function M:Run()
    if sending then return end
    if WK.DB.global.mail.enabled then
        self:BuildQueue()
        if #queue > 0 then self:SendNext() return end
    end
    if WK.DB.global.mail.autoTake then self:TakeAll() end
end

WK:On("MAIL_SHOW", function()
    -- Petit délai : l'interface du courrier doit être prête.
    M:EnsureTakeButton()
    C_Timer.After(0.5, function() M:Run() end)
end)

-- Personnage du compte correspondant à un destinataire.
function M:FindCharacter(recipient) return self:Resolve(recipient) end

-- Ajoute le contenu d'un courrier envoyé à la boîte aux lettres du destinataire (si c'est un perso du compte).
function M:Credit(recipient, content)
    local c = self:FindCharacter(recipient)
    if not c then return end
    c.mailbox = c.mailbox or { items = {}, money = 0, count = 0 }
    for id, n in pairs(content) do c.mailbox.items[id] = (c.mailbox.items[id] or 0) + n end
    c.mailbox.count = (c.mailbox.count or 0) + 1
    local exp = time() + MAIL_DAYS * 86400
    if not c.mailbox.expiresAt or exp < c.mailbox.expiresAt then c.mailbox.expiresAt = exp end
end

WK:On("MAIL_SEND_SUCCESS", function()
    if sending then
        if current then
            M:Credit(current.recipient, current.content or {})
            if WK.modules.Journal then WK.modules.Journal:MailSent(current.recipient, current.content or {}) end
            current = nil
        end
        C_Timer.After(0.5, function() M:SendNext() end)
    end
end)

-- Message d'erreur du jeu pendant un envoi (destinataire inconnu…), repris dans le chat.
WK:On("UI_ERROR_MESSAGE", function(_, msg) if sending then lastError = msg end end)

WK:On("MAIL_FAILED", function()
    if sending then
        wipe(queue); sending = false
        WK:Print(WK.L.MAIL_ERROR)
        if current then
            WK:Print(string.format(T("Destinataire utilisé : « %s »%s"), current.recipient,
                lastError and (" (" .. tostring(lastError) .. ")") or ""))
            WK:Print(T("Si le nom est incomplet : clic droit sur le perso dans Courrier > Nouvelle règle, ou /wk nom."))
        end
        current, lastError = nil, nil
    end
end)

---------------------------------------------------------------------------
-- Lecture de la boîte aux lettres du personnage connecté.
---------------------------------------------------------------------------
function M:ScanInbox()
    if not GetInboxNumItems then return end
    local c = WK.DB:Me()
    local box = { items = {}, money = 0, count = 0, scanned = time() }
    local n = GetInboxNumItems() or 0
    for i = 1, n do
        local _, _, _, _, money, _, daysLeft, hasItem = GetInboxHeaderInfo(i)
        box.count = box.count + 1
        box.money = box.money + (money or 0)
        if daysLeft then
            local exp = time() + daysLeft * 86400
            if not box.expiresAt or exp < box.expiresAt then box.expiresAt = exp end
        end
        if hasItem then
            for a = 1, MAX_RECEIVE do
                local name, itemID, _, count = GetInboxItem(i, a)
                if not itemID and GetInboxItemLink then itemID = WK:ParseItemID(GetInboxItemLink(i, a)) end
                if (name or itemID) and itemID then box.items[itemID] = (box.items[itemID] or 0) + (count or 1) end
            end
        end
    end
    c.mailbox = box
    WK.modules.Statistics:UpdateItems()
    WK:NotifyChanged()
end

local inboxPending = false
WK:On("MAIL_INBOX_UPDATE", function()
    if inboxPending then return end
    inboxPending = true
    C_Timer.After(0.3, function() inboxPending = false; M:ScanInbox() end)
end)

---------------------------------------------------------------------------
-- « Tout prendre » : or et objets de chaque lettre, une opération à la fois.
-- Ignore les contre-remboursements et s'arrête quand les sacs sont pleins.
---------------------------------------------------------------------------
local taking = false
local takeStats, lastKey, sameCount, skip

local function freeSlots()
    local n = 0
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do n = n + (WK.Container.NumFree(bag) or 0) end
    return n
end

local function finishTake(reason)
    taking = false
    if M.takeButton then M.takeButton:SetLabel(T("Tout prendre")) end
    local parts = {}
    if takeStats.money > 0 then table.insert(parts, WK:FormatMoney(takeStats.money)) end
    if takeStats.items > 0 then table.insert(parts, string.format(T("%d objet(s)"), takeStats.items)) end
    if #parts > 0 then WK:Print(T("Récupéré : ") .. table.concat(parts, ", ")) end
    if reason then WK:Print(reason) end
    if afterTake then
        local f = afterTake
        afterTake = nil
        C_Timer.After(0.3, f)
    end
end

local function takeStep()
    if not taking then return end
    local n = GetInboxNumItems() or 0
    for i = n, 1, -1 do
        if not skip[i] then
            local _, _, _, _, money, cod, _, hasItem = GetInboxHeaderInfo(i)
            if (cod or 0) == 0 and ((money or 0) > 0 or hasItem) then
                local key
                -- (les stats ne comptent qu'une fois une opération répétée en attendant la mise à jour)
                if (money or 0) > 0 then
                    key = i .. ":m"
                    if key ~= lastKey then takeStats.money = takeStats.money + money end
                    TakeInboxMoney(i)
                else
                    for a = 1, MAX_RECEIVE do
                        local name, itemID, _, count = GetInboxItem(i, a)
                        if name or itemID then
                            if freeSlots() == 0 then return finishTake(T("Sacs pleins : récupération arrêtée.")) end
                            key = i .. ":" .. a .. ":" .. tostring(itemID)
                            if key ~= lastKey then takeStats.items = takeStats.items + (count or 1) end
                            TakeInboxItem(i, a)
                            break
                        end
                    end
                end
                -- Sécurité : la même opération répétée sans effet (objet unique déjà possédé…) -> on passe la lettre.
                if key == lastKey then
                    sameCount = sameCount + 1
                    if sameCount >= 4 then skip[i] = true end
                else
                    lastKey, sameCount = key, 0
                end
                if key then
                    C_Timer.After(0.35, takeStep)
                    return
                end
            end
        end
    end
    finishTake()
end

function M:TakeAll()
    if taking or sending or not GetInboxNumItems then return end
    taking = true
    takeStats = { money = 0, items = 0 }
    lastKey, sameCount, skip = nil, 0, {}
    if self.takeButton then self.takeButton:SetLabel(T("Récupération...")) end
    takeStep()
end

-- Bouton ajouté à la boîte de réception du jeu.
function M:EnsureTakeButton()
    if self.takeButton or not InboxFrame then return end
    local b = WK.UI:Button(InboxFrame, T("Tout prendre"), 110, 24, "primary")
    b:SetPoint("TOPRIGHT", InboxFrame, "TOPRIGHT", -60, -32)
    b:SetFrameLevel((InboxFrame:GetFrameLevel() or 1) + 10)
    b.tooltip = "Récupère l'or et les objets de toutes les lettres (sauf contre-remboursement)."
    b:SetScript("OnClick", function() M:TakeAll() end)
    self.takeButton = b
end

WK:On("MAIL_CLOSED", function()
    wipe(queue); sending = false; afterTake = nil
    if taking then taking = false; if M.takeButton then M.takeButton:SetLabel(T("Tout prendre")) end end
end)

---------------------------------------------------------------------------
-- Gestion des règles
---------------------------------------------------------------------------
-- from : clé du perso qui envoie (nil = tous les persos).
function M:AddRule(itemArg, recipient, keep, from)
    local id = WK:ParseItemID(itemArg)
    if not id or not recipient or recipient == "" then return false end
    WK.DB.global.mail.rules[WK.modules.Rules:MakeKey(id, from)] = { to = recipient, keep = keep or 0 }
    WK:Print(string.format(WK.L.MAIL_RULE_ADD, WK:ItemName(id), recipient))
    WK.modules.Statistics:UpdateItems()
    WK:NotifyChanged()
    return true
end

function M:AddCategoryRule(key, recipient, keep, from)
    if not WK.modules.Rules.byKey[key] or not recipient or recipient == "" then return false end
    WK.DB.global.mail.cats[WK.modules.Rules:MakeKey(key, from)] = { to = recipient, keep = keep or 0 }
    WK:Print(string.format(WK.L.MAIL_RULE_ADD, WK.modules.Rules:CategoryLabel(key), recipient))
    WK:NotifyChanged()
    return true
end

-- itemArg : lien, itemID, ou clé de règle complète (« id@Perso »).
function M:RemoveRule(itemArg)
    local key = itemArg
    if not WK.DB.global.mail.rules[key] then key = WK:ParseItemID(itemArg) end
    if not key then return false end
    local id = WK.modules.Rules:SplitKey(key)
    WK.DB.global.mail.rules[key] = nil
    WK:Print(string.format(WK.L.MAIL_RULE_DEL, WK:ItemName(id)))
    WK:NotifyChanged()
    return true
end

function M:RemoveCategoryRule(key)
    WK.DB.global.mail.cats[key] = nil
    WK:Print(string.format(WK.L.MAIL_RULE_DEL, WK.modules.Rules:CategoryLabel(key)))
    WK:NotifyChanged()
end

function M:ListRules()
    local any = false
    for key, r in pairs(WK.DB.global.mail.rules) do
        local id = WK.modules.Rules:SplitKey(key)
        any = true
        local note = isMe(r.to) and (" - " .. WK.L.MAIL_SKIP_SELF) or ""
        local keep = (r.keep or 0) > 0 and string.format(" (%s %d)", T("garder"), r.keep) or ""
        WK:Print(string.format("  %s -> %s%s%s", WK:ItemName(id), r.to, keep, note))
    end
    for key, r in pairs(WK.DB.global.mail.cats) do
        any = true
        WK:Print(string.format("  [%s] -> %s", WK.modules.Rules:CategoryLabel(key), r.to))
    end
    if not any then WK:Print(WK.L.MAIL_NO_RULES) end
    WK:Print(WK.DB.global.mail.enabled and WK.L.MAIL_ON or WK.L.MAIL_OFF)
end

function M:SetEnabled(on)
    WK.DB.global.mail.enabled = on
    WK:Print(on and WK.L.MAIL_ON or WK.L.MAIL_OFF)
    WK:NotifyChanged()
end
