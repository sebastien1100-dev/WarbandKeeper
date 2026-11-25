local ADDON_NAME, WK = ...
local L = WK.L

-- Dans le chat, « |r » (et « |c », « |n »…) sont des codes du jeu : « boite|reparer » perdait son « |r ».
-- On double chaque barre pour qu'elle s'affiche telle quelle.
local function plainBars(s) return (s:gsub("|", "||")) end

local function help()
    WK:Print(L.HELP_TITLE)
    for _, k in ipairs({ "HELP_OPEN", "HELP_NOTES", "HELP_FARM", "HELP_TAKE", "HELP_GOLD", "HELP_CHARS", "HELP_FIND", "HELP_PROF", "HELP_STATS",
                         "HELP_MAIL_ADD", "HELP_MAIL_DEL", "HELP_MAIL_LIST", "HELP_MAIL_TOG", "HELP_NAME", "HELP_LINK", "HELP_GUIDE", "HELP_EDIT", "HELP_HALO", "HELP_MICRO", "HELP_HERITAGE", "HELP_AMMO", "HELP_BAGS", "HELP_NAV", "HELP_FISH", "HELP_HV", "HELP_ALERT", "HELP_HUD", "HELP_DUNGEON", "HELP_FP", "HELP_BOAT", "HELP_PERF", "HELP_BUFF", "HELP_RELOAD" }) do
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
    elseif cmd == "statsjeu" or cmd == "gamestats" then
        WK.modules.Statistics.GameStatsDiag()
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
    elseif cmd == "banque" or cmd == "bank" then
        WK:Print(WK.T("Banque : diagnostic (à lancer banque ouverte)"))
        for _, l in ipairs(WK.modules.Inventory:BankDiag()) do WK:Print("  " .. l) end
    elseif cmd == "cartedonjon" or cmd == "dmap" then
        -- le jeu a-t-il une carte de ce donjon, et y donne-t-il la position du perso ? (carte des boss)
        WK:Print(WK.T("Carte du donjon : diagnostic (à lancer dans le donjon)"))
        for _, l in ipairs(WK.modules.Dungeons:MapDiag()) do WK:Print("  " .. l) end
    elseif cmd == "sacs" or cmd == "bags" then
        WK:Print(WK.T("Sacs : diagnostic"))
        for _, l in ipairs(WK.UI.BagDiag and WK.UI:BagDiag() or {}) do WK:Print("  " .. l) end
        -- sacs d'un autre addon (EllesmereUI…) reconnus pour la fenêtre de désenchantement
        if WK.UI.OtherBagsDiag then WK.UI.OtherBagsDiag() end
    elseif cmd == "plan" and (rest or ""):lower():find("diag") then
        WK:Print(WK.T("Plan de montée : diagnostic"))
        for _, l in ipairs(WK.UI.TalentPlanDiag and WK.UI:TalentPlanDiag() or {}) do WK:Print("  " .. l) end
    elseif cmd == "plan" then
        if WK.UI.ToggleTalentPlan then WK.UI:ToggleTalentPlan() end
    elseif cmd == "talents" then
        WK.modules.Gear:Scan({ talents = true })
        WK:Print(WK.T("Talents : diagnostic"))
        for _, l in ipairs(WK.modules.Gear:TalentDiag()) do WK:Print("  " .. l) end
    elseif cmd == "pistage" or cmd == "tracking" then
        for _, l in ipairs(WK.modules.SelfBuffs.TrackDiag()) do WK:Print(l) end
    elseif cmd == "camp" or cmd == "feu" then
        -- effets du joueur et feu de camp reconnu ou non (Modules/Camp.lua)
        WK.modules.Camp:Diag()
    elseif cmd == "armes" or cmd == "weapons" then
        -- compétences d'armes lues en jeu (Modules/WeaponSkills.lua)
        WK.modules.WeaponSkills:Diag()
    elseif cmd == "chaines" or cmd == "chains" then
        -- chaînes de quêtes apprises en jeu (Modules/Quests.lua)
        local Q = WK.modules.Quests
        local list = Q:ChainList()
        WK:Print(string.format(WK.T("Chaînes de quêtes apprises : %d"), #list))
        for _, c in ipairs(list) do
            local q, p = Q:Get(c.id), Q:Get(c.pre)
            WK:Print(string.format("  %d <- %d · %s <- %s (x%d)", c.id, c.pre,
                q and Q:Name(q) or "?", p and Q:Name(p) or "?", c.n))
        end
    elseif cmd == "carte" or cmd == "map" then
        -- diagnostic de la carte du monde : rares de la carte affichée, erreurs des calques
        local wm = WorldMapFrame
        local mapID = wm and wm.GetMapID and wm:GetMapID()
        local R = WK.modules.Rares
        WK:Print(WK.T("Carte du monde : diagnostic"))
        WK:Print("  " .. WK.T("carte") .. " : " .. tostring(mapID) .. " · " .. WK.T("module Rares") .. " : " .. tostring(WK:FeatureOn("rares"))
            .. " · " .. WK.T("médaillons") .. " : " .. tostring(R:Config().map) .. " · " .. WK.T("rares sur cette carte") .. " : " .. (mapID and #R:OnMap(mapID) or 0))
        local st = WK.UI.mapStats
        if st then
            WK:Print("  " .. string.format("dessin : carte %s · toile %dx%d · %s/%s (calques du jeu jusqu'à %s, nos pastilles à partir de %s) · module Carte : %s · lieux : %s",
                tostring(st.map), st.w or 0, st.h or 0, tostring(st.strata), tostring(st.level), tostring(st.gameTop), tostring(WK.UI.mapBase), tostring(WK:FeatureOn("maplayers")), tostring(st.places)))
            local parts = {}
            for _, k in ipairs({ "Lieux", "Filons et plantes", "Rares", "Bateaux", "Trajet", "Notes", "Repère" }) do
                table.insert(parts, k .. " " .. tostring(st[k]))
            end
            WK:Print("  " .. table.concat(parts, " · "))
        end
        -- trajet du guidage : points du chemin, combien sont placés sur cette carte, quais de la traversée
        local ns = WK.UI.navStats
        if ns then
            WK:Print("  " .. string.format("trajet : guidage vers %s · %s (%d étapes, option tracé : %s) · %d points, %d placés · carte du monde : %s · continent : %s · traversée : %s",
                tostring(ns.guide), tostring(ns.state), ns.legs or 0, tostring(ns.option), ns.pts or 0, ns.placed or 0, tostring(ns.world), tostring(ns.cont), tostring(ns.docks)))
        end
        if WK.UI.MapLayersProbe then
            local ok, txt = pcall(WK.UI.MapLayersProbe, WK.UI)
            WK:Print("  " .. tostring(ok and txt or ("sonde : " .. tostring(txt))))
        end
        for _, line in ipairs(WK.UI.mapLog or {}) do WK:Print("  · " .. line) end
        local any = false
        for name, err in pairs(WK.UI.mapErrors or {}) do any = true; WK:Print("  " .. name .. " : " .. plainBars(err)) end
        if not any then WK:Print("  " .. WK.T("aucune erreur de calque")) end
    elseif cmd == "bateaux" or cmd == "boats" then
        WK.UI:ToggleBoatBoard(nil, "boat")
    elseif cmd == "vols" or cmd == "flights" then
        WK.UI:ToggleBoatBoard(nil, "flight")
    elseif cmd == "de" or cmd == "desenchanter" or cmd == "disenchant" then
        WK.UI:ToggleDEPanel()
    elseif cmd == "bateau" or cmd == "boat" then
        WK:Print(WK.T("Bateaux : diagnostic"))
        for _, l in ipairs(WK.modules.Nav:BoatDiag()) do WK:Print("  " .. l) end
    elseif (cmd == "vol" or cmd == "fp") and (rest or ""):lower():find("diag") then
        WK:Print(WK.T("Vols : diagnostic"))
        for _, l in ipairs(WK.modules.Flight:TaxiDiag()) do WK:Print("  " .. l) end
    elseif cmd == "vol" or cmd == "fp" then
        WK.modules.Flight:GuideToFlightPoint()
    elseif cmd == "donjon" or cmd == "dungeon" then
        WK.UI:ToggleDungeonPanel()
    elseif cmd == "hud" then
        WK.UI:ToggleGatherHUD()
    elseif cmd == "nav" then
        WK.modules.Guide:NavReport()
    elseif cmd == "micro" then
        WK.UI:ClockReport()
    elseif cmd == "heritage" or cmd == "heirloom" then
        WK.UI:HeirloomReport()
    elseif cmd == "munitions" or cmd == "ammo" then
        WK.UI:AmmoReport()
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
    elseif cmd == "rechargement" or cmd == "reloaddiag" then
        WK:Print(WK.T("Boutons de rechargement :"))
        for _, l in ipairs(WK.UI.ReloadDiag and WK.UI:ReloadDiag() or {}) do WK:Print("  " .. l) end
    elseif cmd == "buff" then
        WK:Print(WK.T("Bouton « Buffer le suivant » : diagnostic"))
        for _, l in ipairs(WK.UI.BuffDiag and WK.UI:BuffDiag() or {}) do WK:Print("  " .. l) end
    elseif cmd == "perf" then
        WK.modules.Maintenance:PerfStart(rest)
    elseif cmd == "options" then
        WK.UI:ToggleWindow("options")
    else
        help()
    end
end
