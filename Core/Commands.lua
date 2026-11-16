local ADDON_NAME, WK = ...
local L = WK.L

-- Dans le chat, « |r » (et « |c », « |n »…) sont des codes du jeu : « boite|reparer » perdait son « |r ».
-- On double chaque barre pour qu'elle s'affiche telle quelle.
local function plainBars(s) return (s:gsub("|", "||")) end

local function help()
    WK:Print(L.HELP_TITLE)
    for _, k in ipairs({ "HELP_OPEN", "HELP_NOTES", "HELP_FARM", "HELP_TAKE", "HELP_GOLD", "HELP_CHARS", "HELP_FIND", "HELP_PROF", "HELP_STATS",
                         "HELP_MAIL_ADD", "HELP_MAIL_DEL", "HELP_MAIL_LIST", "HELP_MAIL_TOG", "HELP_NAME", "HELP_LINK", "HELP_GUIDE", "HELP_EDIT", "HELP_HALO", "HELP_MICRO", "HELP_NAV", "HELP_FISH", "HELP_HV", "HELP_ALERT" }) do
        if L[k] then WK:Print("  " .. plainBars(L[k])) end
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
            if not Mail:AddRule(item, to) then WK:Print("  " .. plainBars(L.HELP_MAIL_ADD)) end
        elseif sub == "retire" or sub == "del" then
            if not Mail:RemoveRule(args) then WK:Print("  " .. plainBars(L.HELP_MAIL_DEL)) end
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
        else WK:Print("  " .. plainBars(L.HELP_GUIDE)) end
    elseif cmd == "peche" or cmd == "pêche" or cmd == "fish" then
        WK.modules.Fishing:Toggle()
    elseif cmd == "nav" then
        WK.modules.Guide:NavReport()
    elseif cmd == "micro" then
        WK.UI:ClockReport()
    elseif cmd == "hv" or cmd == "ah" then
        local r = string.lower(rest or "")
        if r == "scan" then WK.modules.AHScan:Start()
        elseif r == "scan force" then WK.modules.AHScan:Start("force") elseif r == "stop" then WK.modules.AHScan:Stop()
        else WK.modules.AHScan:Report(); if WK.modules.AHSell then WK.modules.AHSell:Report() end end
    elseif cmd == "alerte" or cmd == "alert" then
        -- /wk alerte <lien ou numéro> <prix> : prix en po (« 2.5 », « 2po50pa », « 75pa », « 30pc ») ; sans prix : retire
        local A = WK.modules.AHSell
        local item, price = string.match(rest or "", "^(.-|h|r)%s*(.-)%s*$")
        if not item then item, price = string.match(rest or "", "^(%S+)%s*(.-)%s*$") end
        local id = item and WK:ParseItemID(item)
        if not id then
            local n = 0
            for _, a in ipairs(A:Alerts()) do
                n = n + 1
                WK:Print("  " .. (WK.GetItemInfo(a.id) or ("#" .. a.id)) .. " : " .. WK.UI:ExactMoney(a.max) .. (a.hit and ("  " .. WK.T("en vente à") .. " " .. WK.UI:ExactMoney(a.price)) or ""))
            end
            if n == 0 then help() end
        elseif price == nil or price == "" then
            A:RemoveAlert(id)
            WK:Print(WK.T("Alerte de prix retirée."))
        else
            local c = A.ParsePrice(price)
            if c and A:AddAlert(id, c) then
                WK:Print(string.format(WK.T("Alerte de prix : %s à %s ou moins."), WK.GetItemInfo(id) or ("#" .. id), WK.UI:ExactMoney(c)))
            else
                WK:Print(WK.T("Prix non compris : par exemple 2.5, 2po50pa ou 75pa."))
            end
        end
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
