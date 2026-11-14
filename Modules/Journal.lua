local ADDON_NAME, WK = ...
local M = WK:NewModule("Journal")

-- Journal d'activité : courriers envoyés, variations d'or, progrès de métier, niveaux.
-- Entrée : { t, kind = "mail"|"gold"|"skill"|"level", char = clé, ... }
local MAX_ENTRIES = 500
local MERGE_WINDOW = 3600 -- regroupe les entrées similaires sur une heure

local function journal() return WK.DB.global.journal end

local function push(entry)
    local j = journal()
    table.insert(j, 1, entry)
    while #j > MAX_ENTRIES do table.remove(j) end
    WK:NotifyChanged()
end

-- Dernière entrée fusionnable (même type, même perso, même clé) dans la fenêtre de regroupement.
local function mergeable(kind, char, match)
    local now = time()
    for _, e in ipairs(journal()) do
        if now - e.t > MERGE_WINDOW then return nil end
        if e.kind == kind and e.char == char and (not match or match(e)) then return e end
    end
end

function M:Gold(delta)
    if delta == 0 then return end
    local key = WK:CharKey()
    local e = mergeable("gold", key)
    if e then
        e.delta = e.delta + delta
        e.t = time()
        if e.delta == 0 then
            for i, x in ipairs(journal()) do if x == e then table.remove(journal(), i) break end end
        end
        WK:NotifyChanged()
    else
        push({ t = time(), kind = "gold", char = key, delta = delta })
    end
end

function M:Skill(name, from, to)
    local key = WK:CharKey()
    local e = mergeable("skill", key, function(x) return x.prof == name end)
    if e then
        e.to = to; e.t = time()
        WK:NotifyChanged()
    else
        push({ t = time(), kind = "skill", char = key, prof = name, from = from, to = to })
    end
end

function M:Level(level)
    push({ t = time(), kind = "level", char = WK:CharKey(), level = level })
end

-- Un courrier envoyé : content = { [itemID] = quantité }.
function M:MailSent(recipient, content)
    local key = WK:CharKey()
    local e = mergeable("mail", key, function(x) return x.to == recipient end)
    if not e then
        e = { t = time(), kind = "mail", char = key, to = recipient, items = {}, letters = 0 }
        push(e)
    end
    e.t = time()
    e.letters = (e.letters or 0) + 1
    for id, n in pairs(content) do e.items[id] = (e.items[id] or 0) + n end
    WK:NotifyChanged()
end

-- Dépôt en banque : items = { [itemID] = quantité }.
function M:Deposit(target, items)
    local copy = {}
    for id, n in pairs(items) do copy[id] = n end
    push({ t = time(), kind = "bank", char = WK:CharKey(), target = target, items = copy })
end

-- Fin d'une session de farm.
function M:Farm(s)
    push({ t = time(), kind = "farm", char = s.char, zone = s.zone, duration = s.duration,
        gold = s.gold, count = WK.modules.Farm:ItemCount(s.items) })
end

WK:On("PLAYER_LEVEL_UP", function(level) M:Level(level) end)

function M:Entries(filter)
    if not filter or filter == "all" then return journal() end
    local out = {}
    for _, e in ipairs(journal()) do
        if e.kind == filter or (filter == "skill" and e.kind == "level")
            or (filter == "mail" and e.kind == "bank") or (filter == "gold" and e.kind == "farm") then
            table.insert(out, e)
        end
    end
    return out
end
