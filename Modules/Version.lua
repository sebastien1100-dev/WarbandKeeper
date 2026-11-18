local ADDON_NAME, WK = ...
local M = WK:NewModule("Version")
local T = function(s) return WK.T(s) end

-- Mise à jour disponible : la plus récente des deux sources
--   « client » : Core/Latest.lua, écrit par le client PC (dernière version publiée sur GitHub) ;
--   « guilde » / « groupe » : version annoncée par un autre joueur qui a l'addon (messages d'addon,
--   préfixe WKver, à la connexion et à l'entrée dans un groupe ; jamais en instance).
-- Retenue dans WK.DB.global.latestSeen = { version, source, at } (effacée quand on est à jour).
local PREFIX = "WKver"

local function parts(v)
    local t = {}
    for n in tostring(v or ""):gmatch("%d+") do t[#t + 1] = tonumber(n) end
    return t
end
-- a plus récente que b ?
function M.Newer(a, b)
    local x, y = parts(a), parts(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

-- Version plus récente que celle chargée, et d'où on la tient ; nil si à jour
function M:Available()
    local best, src, at
    local L = WK.Latest
    if type(L) == "table" and type(L.version) == "string" and M.Newer(L.version, WK.version) then
        best, src, at = L.version, "client", L.checked
    end
    local g = WK.DB and WK.DB.global
    local s = g and g.latestSeen
    if s then
        if not M.Newer(s.version, WK.version) then
            g.latestSeen = nil
        elseif not best or M.Newer(s.version, best) then
            best, src, at = s.version, s.source, s.at
        end
    end
    return best, src, at
end

-- Valeur lisible, ou nil si le jeu la masque (jamais la valeur masquée elle-même)
local function readable(v)
    if issecretvalue and issecretvalue(v) then return nil end
    local Q = WK.modules.QoL
    if Q and Q.Readable then return Q.Readable(v) end
    return v
end

local function send(channel)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    if IsInInstance and select(1, IsInInstance()) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    pcall(C_ChatInfo.SendAddonMessage, PREFIX, "V:" .. tostring(WK.version), channel)
end

local lastGroup = 0
local function announceGroup()
    if not (IsInGroup and IsInGroup()) then return end
    if GetTime() - lastGroup < 60 then return end
    lastGroup = GetTime()
    send((IsInRaid and IsInRaid()) and "RAID" or "PARTY")
end

WK:On("PLAYER_LOGIN", function()
    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX) end
    C_Timer.After(15, function()
        if IsInGuild and IsInGuild() then send("GUILD") end
        announceGroup()
    end)
end)
WK:On("GROUP_ROSTER_UPDATE", function() C_Timer.After(3, announceGroup) end)

WK:On("CHAT_MSG_ADDON", function(prefix, msg, channel, sender)
    prefix, msg, channel = readable(prefix), readable(msg), readable(channel)
    if prefix == nil or msg == nil or prefix ~= PREFIX or type(msg) ~= "string" then return end
    local v = msg:match("^V:([%d%.]+)$")
    if not v or not M.Newer(v, WK.version) then return end
    local g = WK.DB.global
    local s = g.latestSeen
    if s and not M.Newer(v, s.version) then return end
    g.latestSeen = { version = v, source = channel == "GUILD" and "guild" or "group", at = time() }
    WK:Print(string.format(T("Une version plus récente de Warband Keeper existe : %s (tu as la %s)."), v, WK.version))
    if WK.UI and WK.UI.RefreshUpdate then WK.UI:RefreshUpdate() end
end)
