local ADDON_NAME, WK = ...
local L = WK.L

local function help()
    WK:Print(L.HELP_TITLE)
    for _, k in ipairs({ "HELP_OPEN", "HELP_NOTES", "HELP_FARM", "HELP_TAKE", "HELP_GOLD", "HELP_CHARS", "HELP_FIND", "HELP_PROF", "HELP_STATS",
                         "HELP_MAIL_ADD", "HELP_MAIL_DEL", "HELP_MAIL_LIST", "HELP_MAIL_TOG" }) do
        WK:Print("  " .. L[k])
    end
end

SLASH_WARBANDKEEPER1 = "/wk"
SLASH_WARBANDKEEPER2 = "/warbandkeeper"

SlashCmdList.WARBANDKEEPER = function(msg)
    local cmd, rest = string.match(msg or "", "^%s*(%S*)%s*(.-)%s*$")
    cmd = string.lower(cmd or "")

    if cmd == "or" or cmd == "gold" then
        WK.modules.Characters:PrintGold()
    elseif cmd == "persos" or cmd == "chars" then
        WK.modules.Characters:PrintCharacters()
    elseif cmd == "cherche" or cmd == "find" then
        WK.modules.Inventory:Find(rest)
    elseif cmd == "metiers" or cmd == "prof" then
        WK.modules.Professions:Print()
    elseif cmd == "stats" then
        WK.modules.Statistics:PrintGold(rest)
    elseif cmd == "envoi" or cmd == "mail" then
        local sub, args = string.match(rest, "^(%S*)%s*(.-)$")
        sub = string.lower(sub or "")
        local Mail = WK.modules.Mail
        if sub == "ajoute" or sub == "add" then
            -- Le lien d'objet peut contenir des espaces : le destinataire est le dernier mot.
            local item, to = string.match(args, "^(.-)%s+(%S+)$")
            if not Mail:AddRule(item, to) then WK:Print("  " .. L.HELP_MAIL_ADD) end
        elseif sub == "retire" or sub == "del" then
            if not Mail:RemoveRule(args) then WK:Print("  " .. L.HELP_MAIL_DEL) end
        elseif sub == "on" then
            Mail:SetEnabled(true)
        elseif sub == "off" then
            Mail:SetEnabled(false)
        else
            Mail:ListRules()
        end
    elseif cmd == "" then
        WK.UI:ToggleWindow()
    elseif cmd == "farm" then
        WK.modules.Farm:Toggle()
    elseif cmd == "prendre" or cmd == "take" then
        WK.modules.Mail:TakeAll()
    elseif cmd == "notes" then
        WK.UI:ToggleWindow("notes")
    elseif cmd == "options" then
        WK.UI:ToggleWindow("options")
    else
        help()
    end
end
