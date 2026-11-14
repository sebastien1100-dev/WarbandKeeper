local ADDON_NAME, WK = ...
local M = WK:NewModule("Mail")

local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12

-- File d'envoi : liste de { recipient, items = { {bag, slot}, ... } } (1 courrier par entrée).
local queue = {}
local sending = false
local current -- courrier en cours d'envoi (pour le créditer au destinataire)
local MAIL_DAYS = 30 -- durée de conservation d'un courrier envoyé à un joueur

local function myName() return UnitName("player") end

-- Construit la file à partir des règles et du contenu des sacs.
function M:BuildQueue()
    wipe(queue)
    local rules = WK.DB.global.mail.rules
    local byRecipient = {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, _, locked, bound = WK.Container.Info(bag, slot)
            local to = id and rules[id]
            if to and not locked and not bound and string.lower(to) ~= string.lower(myName()) then
                byRecipient[to] = byRecipient[to] or {}
                table.insert(byRecipient[to], { bag = bag, slot = slot })
            end
        end
    end
    for to, items in pairs(byRecipient) do
        for i = 1, #items, MAX_ATTACH do
            local batch = {}
            for j = i, math.min(i + MAX_ATTACH - 1, #items) do table.insert(batch, items[j]) end
            table.insert(queue, { recipient = to, items = batch })
        end
    end
end

-- Envoie le prochain courrier de la file. La suite est déclenchée par MAIL_SEND_SUCCESS.
function M:SendNext()
    local mail = table.remove(queue, 1)
    if not mail then
        if sending then WK:Print(WK.L.MAIL_DONE) end
        sending = false
        return
    end
    sending = true
    current = mail
    mail.content = {}
    ClearCursor()
    for _, it in ipairs(mail.items) do
        local id, count = WK.Container.Info(it.bag, it.slot)
        if id then mail.content[id] = (mail.content[id] or 0) + (count or 1) end
    end
    for i, it in ipairs(mail.items) do
        WK.Container.Pickup(it.bag, it.slot)
        ClickSendMailItemButton(i)
    end
    WK:Print(string.format(WK.L.MAIL_SENDING, #mail.items, mail.recipient))
    local send = SendMail or (C_Mail and C_Mail.SendMail)
    send(mail.recipient, "Warband Keeper", "")
end

function M:Run()
    if not WK.DB.global.mail.enabled or sending then return end
    self:BuildQueue()
    if #queue > 0 then self:SendNext() end
end

WK:On("MAIL_SHOW", function()
    -- Petit délai : l'interface du courrier doit être prête.
    C_Timer.After(0.5, function() M:Run() end)
end)

-- Personnage du compte correspondant à un destinataire ("Nom" ou "Nom-Royaume").
function M:FindCharacter(recipient)
    local name, realm = string.match(recipient, "^([^%-]+)%-?(.*)$")
    name = string.lower(name or recipient)
    realm = (realm and realm ~= "") and string.lower(realm):gsub("%s", "") or nil
    local myRealm = string.lower(GetRealmName()):gsub("%s", "")
    for key, c in pairs(WK.DB.global.characters) do
        local cr = string.lower(c.realm or ""):gsub("%s", "")
        if c.name and string.lower(c.name) == name and cr == (realm or myRealm) then return c, key end
    end
end

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

---------------------------------------------------------------------------
-- Lecture de la boîte aux lettres du personnage connecté.
---------------------------------------------------------------------------
local MAX_RECEIVE = ATTACHMENTS_MAX_RECEIVE or 16

function M:ScanInbox()
    if not GetInboxNumItems then return end
    local c = WK.DB:Me()
    local box = { items = {}, money = 0, count = 0, scanned = time() }
    local n = GetInboxNumItems() or 0
    for i = 1, n do
        local _, _, _, _, money, cod, daysLeft, hasItem = GetInboxHeaderInfo(i)
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
                if name or itemID then
                    if itemID then box.items[itemID] = (box.items[itemID] or 0) + (count or 1) end
                end
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

WK:On("MAIL_FAILED", function()
    if sending then
        wipe(queue); sending = false
        WK:Print(WK.L.MAIL_ERROR)
    end
end)

WK:On("MAIL_CLOSED", function() wipe(queue); sending = false end)

-- Nombre d'objets dans les sacs du perso courant qui partiraient au prochain passage.
function M:PendingCount()
    local n = 0
    local me = WK.DB:Me()
    for id, to in pairs(WK.DB.global.mail.rules) do
        if string.lower(to) ~= string.lower(myName()) then n = n + ((me.bags or {})[id] or 0) end
    end
    return n
end

-- Gestion des règles
function M:AddRule(itemArg, recipient)
    local id = WK:ParseItemID(itemArg)
    if not id or not recipient or recipient == "" then return false end
    WK.DB.global.mail.rules[id] = recipient
    WK:Print(string.format(WK.L.MAIL_RULE_ADD, WK:ItemName(id), recipient))
    WK.modules.Statistics:UpdateItems()
    WK:NotifyChanged()
    return true
end

function M:RemoveRule(itemArg)
    local id = WK:ParseItemID(itemArg)
    if not id then return false end
    WK.DB.global.mail.rules[id] = nil
    WK:Print(string.format(WK.L.MAIL_RULE_DEL, WK:ItemName(id)))
    WK:NotifyChanged()
    return true
end

function M:ListRules()
    local any = false
    for id, to in pairs(WK.DB.global.mail.rules) do
        any = true
        local note = string.lower(to) == string.lower(myName()) and (" - " .. WK.L.MAIL_SKIP_SELF) or ""
        WK:Print(string.format("  %s -> %s%s", WK:ItemName(id), to, note))
    end
    if not any then WK:Print(WK.L.MAIL_NO_RULES) end
    WK:Print(WK.DB.global.mail.enabled and WK.L.MAIL_ON or WK.L.MAIL_OFF)
end

function M:SetEnabled(on)
    WK.DB.global.mail.enabled = on
    WK:Print(on and WK.L.MAIL_ON or WK.L.MAIL_OFF)
    WK:NotifyChanged()
end
