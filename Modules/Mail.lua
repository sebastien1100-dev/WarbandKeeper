local ADDON_NAME, WK = ...
local M = WK:NewModule("Mail")

local MAX_ATTACH = ATTACHMENTS_MAX_SEND or 12

-- File d'envoi : liste de { recipient, items = { {bag, slot}, ... } } (1 courrier par entrée).
local queue = {}
local sending = false

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
    ClearCursor()
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

WK:On("MAIL_SEND_SUCCESS", function()
    if sending then C_Timer.After(0.5, function() M:SendNext() end) end
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
