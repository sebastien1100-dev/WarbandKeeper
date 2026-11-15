local ADDON_NAME, WK = ...
local L = WK.L

local function help()
    WK:Print(L.HELP_TITLE)
    for _, k in ipairs({ "HELP_OPEN", "HELP_NOTES", "HELP_FARM", "HELP_TAKE", "HELP_GOLD", "HELP_CHARS", "HELP_FIND", "HELP_PROF", "HELP_STATS",
                         "HELP_MAIL_ADD", "HELP_MAIL_DEL", "HELP_MAIL_LIST", "HELP_MAIL_TOG", "HELP_NAME", "HELP_LINK", "HELP_GUIDE", "HELP_EDIT", "HELP_HALO" }) do
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
            -- Le destinataire peut avoir plusieurs mots (« Prénom Nom ») : il suit le lien ou l'ID.
            local item, to = string.match(args, "^(.-|h|r)%s*(.-)%s*$")
            if not item then item, to = string.match(args, "^(%S+)%s+(.-)%s*$") end
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
    elseif cmd == "nom" or cmd == "name" then
        WK.modules.Mail:PrintNames()
    elseif cmd == "edit" or cmd == "disposition" then
        WK.UI:EnterEditMode()
    elseif cmd == "guide" then
        local map = { boite = "mail", mail = "mail", banque = "bank", bank = "bank", reparer = "repair", repair = "repair",
                      marchand = "vendor", vendor = "vendor", maitre = "trainer", trainer = "trainer", munitions = "ammo", ammo = "ammo", ecurie = "stable", stable = "stable" }
        local what = map[string.lower(rest or "")]
        if what then WK.modules.Guide:GoTo(what) elseif string.lower(rest or "") == "stop" then WK.modules.Guide:Stop()
        else WK:Print("  " .. L.HELP_GUIDE) end
    elseif cmd == "halo" then
        WK.modules.Glow:Report()
    elseif cmd == "lien" or cmd == "link" then
        WK.modules.Recipes:LinkReport()
    elseif cmd == "notes" then
        WK.UI:ToggleWindow("notes")
    elseif cmd == "options" then
        WK.UI:ToggleWindow("options")
    else
        help()
    end
end
