local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Notre inventaire (maquette A + fiche de B) : remplace les sacs du jeu (et ceux d'un autre addon de sacs, à
-- couper chez lui) par une fenêtre rangée en catégories qui suivent nos modules : nouveaux, équipement
-- (amélioration, BiS, à désenchanter), composants de tes métiers, composants qui partent à un autre perso
-- (Rangement), consommables, quête, camelote, le reste. Fiche de l'objet survolé à droite (prix, qui en a besoin,
-- actions). Réglage WK.DB.global.bags.enabled (Inventaire > roue) ; changement pris en compte au /reload.
--
-- Fonctionnement des sacs du jeu : leurs cadres (ContainerFrameCombinedBags, ContainerFrameN) sont posés dans un
-- cadre caché ; le jeu continue de les ouvrir et de les fermer (touche B, marchand, banque, Échap) et notre
-- fenêtre suit leur état (OnShow / OnHide). Rien n'est remplacé dans le code du jeu.
--
-- Cases : boutons du jeu ContainerFrameItemButtonTemplate (clic droit = utiliser / vendre, glisser = déplacer,
-- infobulle du jeu), chacun dans un cadre porteur dont l'ID est le n° du sac ; seuls SetID et la position sont
-- posés par l'addon (aucun champ lu par le code du jeu). Jamais créés ni déplacés en combat : la disposition
-- attend la fin du combat (pending), seuls les icônes et les nombres sont repeints.

local B = {}
UI.Bags = B
local COLS, SLOT, GAP, PAD = 10, 38, 4, 14
local SIZES = { s = 30, m = 38, l = 46 } -- taille des cases au choix (Petit, Moyen, Grand)
local MIN_COLS, MAX_COLS = 5, 24
local FICHE_W = 260
local inCombat = function() return _G.InCombatLockdown and _G.InCombatLockdown() end

function B.Config()
    local g = WK.DB.global
    g.bags = g.bags or {}
    local c = g.bags
    if c.enabled == nil then c.enabled = true end
    if c.fiche == nil then c.fiche = true end
    c.seen = c.seen or {} -- objets déjà vus dans les sacs de ce perso (repère « nouveau » de secours)
    return c
end
local function enabled() return B.Config().enabled and WK:FeatureOn("inventory") end
-- infobulle des cases allégée : les infos de l'addon sont dans la fiche (si elle est affichée)
function B.LightTip()
    local c = B.Config()
    return c.lightTip ~= false and c.fiche and enabled()
end

-- recueille les lignes qu'un module ajoute à une infobulle, en texte coloré pour la fiche
local function collector()
    local out = {}
    local function hex(r, g, b)
        return string.format("|cff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
    end
    local t = { Show = function() end }
    function t.AddLine(_, txt, r, g, b)
        if txt and txt ~= " " then out[#out + 1] = hex(r or 0.85, g or 0.85, b or 0.85) .. txt .. "|r" end
    end
    function t.AddDoubleLine(_, a, b2, r, g, bb, r2, g2, b3)
        out[#out + 1] = hex(r or 0.65, g or 0.65, bb or 0.65) .. (a or "") .. "|r  "
            .. hex(r2 or 1, g2 or 1, b3 or 1) .. (b2 or "") .. "|r"
    end
    return t, out
end

---------------------------------------------------------------------------
-- Classement d'un objet
---------------------------------------------------------------------------
local CATS = {
    { key = "new", label = "Nouveaux", color = "positive" },
    { key = "equip", label = "Équipement" },
    { key = "mine", label = "Composants de tes métiers" },
    { key = "rbag", label = "Sac de composants", color = "rule" },
    { key = "abag", label = "Sac à munitions", color = "gold" },
    { key = "ship", label = "Pour d'autres persos", color = "accent" },
    { key = "cons", label = "Consommables" },
    { key = "quest", label = "Quête", color = "gold" },
    { key = "other", label = "Divers" },
    { key = "junk", label = "Camelote", color = "muted" },
}
local REAGENT_CLASS = { [3] = true, [5] = true, [7] = true, [9] = true }
-- sac de composants du perso (seuls les composants d'artisanat y vont) : sa propre catégorie et ses places libres
local function reagentBag()
    local BI = _G.Enum and _G.Enum.BagIndex
    if BI and BI.ReagentBag then return BI.ReagentBag end
    local total, nb = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS, _G.NUM_BAG_SLOTS or 4
    return (total and total > nb) and total or nil
end

-- carquois et gibernes du perso (genre de sac « flèches » 1 ou « balles » 2) : seules des munitions y vont,
-- leur contenu et leurs places libres ont leur propre section, comme le sac de composants
local function ammoBags()
    local out = {}
    local CC = _G.C_Container
    local nf = (CC and CC.GetContainerNumFreeSlots) or _G.GetContainerNumFreeSlots
    if not nf then return out end
    for bag = 1, (_G.NUM_BAG_SLOTS or 4) do
        local ok, _, family = pcall(nf, bag)
        if ok and type(family) == "number" and family > 0 and (family % 4) > 0 and family < 4 then out[bag] = true end
    end
    return out
end

local function instant(id)
    local f = _G.C_Item and _G.C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    if not f then return nil end
    local ok, _, _, _, _, _, classID = pcall(f, id)
    return ok and classID or nil
end
-- objets neufs déjà vus (survolés, ou sacs refermés) : plus jamais « nouveaux » pendant la séance, même si le jeu
-- garde son repère (il ne l'efface qu'à la fermeture de ses propres sacs, que les nôtres remplacent)
local seenNew = {}
local function newKey(bag, slot, id) return bag .. ":" .. slot .. ":" .. tostring(id) end
local function isNew(bag, slot, id)
    if id and seenNew[newKey(bag, slot, id)] then return false end
    local NI = _G.C_NewItems
    if NI and NI.IsNewItem then
        local ok, v = pcall(NI.IsNewItem, bag, slot)
        if ok then return v and true or false end
    end
    return false
end
local function shortName(key)
    local c = WK.DB.global.characters[key]
    local n = c and WK:CharName(c, key) or key or "?"
    return (n:match("^(%S+)")) or n
end

-- Contexte calculé une fois par rafraîchissement (envois, désenchantement)
local function context()
    local ctx = { ship = {}, enchanter = false }
    local St = WK.modules.Stash
    if St and St.MyShipments then
        local ok, list = pcall(St.MyShipments, St)
        if ok then for _, e in ipairs(list or {}) do ctx.ship[e.id] = e end end
    end
    local PH = WK.modules.ProfHelp
    ctx.enchanter = PH and PH.EnchantRank and PH:EnchantRank() ~= nil
    return ctx
end

-- { cat, badge = texte, badgeCol, upgrade, de, bis, ship }
local function classify(e, ctx)
    local id, q = e.id, e.quality
    local classID = instant(id)
    local info = {}
    local IL = WK.modules.ItemLock
    local questItem = classID == 12 or (IL and IL.QuestFor and IL:QuestFor(id))
    local ship = ctx.ship[id]
    if ship then info.ship = ship end
    if classID == 2 or classID == 4 then
        local BH = WK.modules.BagHelp
        if BH and BH.Upgrade and e.link then
            local ok, slotName, gain = pcall(BH.Upgrade, BH, e.link)
            if ok and slotName and gain and gain > 0 then info.upgrade = gain end
        end
        local Bi = WK.modules.BiS
        if Bi and Bi.Mark then info.bis = Bi:Mark(id) end
    end
    if ctx.enchanter and (classID == 2 or classID == 4) and q and q >= 2 then
        local PH = WK.modules.ProfHelp
        local ok, a = pcall(PH.DEAdvice, PH, id)
        if ok and a and a.advice == "de" then info.de = true end
    end
    -- catégorie
    if e.new then info.cat = "new"
    elseif questItem then info.cat = "quest"
    elseif q == 0 or (WK.modules.QoL and WK.modules.QoL:IsJunk(id)) then info.cat = "junk"
    elseif ship then info.cat = "ship"
    elseif classID == 2 or classID == 4 then info.cat = "equip"
    elseif classID and REAGENT_CLASS[classID] then info.cat = "mine"
    elseif classID == 0 then info.cat = "cons"
    else info.cat = "other" end
    -- pastille (une seule, la plus utile)
    -- nouvel objet : une simple pastille verte (pas de texte) ; les autres pastilles passent devant
    if info.cat == "new" then info.badge, info.badgeCol, info.dot = "", C.positive, true end
    if info.upgrade or info.bis == "mine" or info.de or ship or questItem then info.dot = nil end
    if info.upgrade then info.badge, info.badgeCol = "+" .. math.floor(info.upgrade + 0.5), C.positive
    elseif info.bis == "mine" then info.badge, info.badgeCol = T("BiS"), C.gold
    elseif info.de then info.badge, info.badgeCol = T("DE"), C.plan
    elseif ship then
        -- pastille du destinataire à la couleur de sa classe
        local dc = WK.DB.global.characters[ship.to]
        local col
        if dc and dc.class then
            local r, g, b = UI:ClassColor(dc.class)
            col = { r, g, b }
        end
        info.badge, info.badgeCol = shortName(ship.to), col
    elseif questItem then info.badge, info.badgeCol = "Q", C.gold end
    return info
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
-- Une fenêtre (sacs du perso ou banque) : même structure, même design ; makeView("bags") / makeView("bank")
local gameOpen -- plus bas (sacs du jeu)
-- couleur d'une qualité d'objet (fonctions du jeu, sinon table du jeu, sinon couleurs habituelles)
local QCOL = { [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
    [6] = { 0.9, 0.8, 0.5 }, [7] = { 0, 0.8, 1 } }
function B.QualityColor(q)
    if not q then return nil end
    local CI = _G.C_Item
    if CI and CI.GetItemQualityColor then
        local ok, r, g, b = pcall(CI.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    if _G.GetItemQualityColor then
        local ok, r, g, b = pcall(_G.GetItemQualityColor, q)
        if ok and type(r) == "number" then return r, g, b end
    end
    local t = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
    if t and t.r then return t.r, t.g, t.b end
    local c = QCOL[q]
    if c then return c[1], c[2], c[3] end
end
-- région du bouton du jeu (le nom du champ change selon les versions du client)
local function region(b, ...)
    for _, k in ipairs({ ... }) do
        local r = b[k]
        if type(r) == "table" and r.SetTexture or type(r) == "table" and r.SetText then return r end
        local n = b.GetName and b:GetName()
        r = n and _G[n .. k]
        if type(r) == "table" then return r end
    end
end
-- case carrée : bord de 2 px (couleur de la qualité) et fond plein, à la manière des barres d'action
local Sq = {}
Sq.__index = Sq
function Sq:SetColor(r, g, b, a) self.t:SetColorTexture(r, g, b, a or 1) end
local function square(b, inset, sub)
    local t = b:CreateTexture(nil, "BACKGROUND", nil, sub)
    t:SetPoint("TOPLEFT", inset, -inset); t:SetPoint("BOTTOMRIGHT", -inset, inset)
    return setmetatable({ t = t }, Sq)
end
local EDGE = 2
local function edgeColor(e)
    if e and (e.quality or 1) >= 2 then
        local r, g, b = B.QualityColor(e.quality)
        if r then return r, g, b, 1 end
    end
    return C.border[1], C.border[2], C.border[3], e and 1 or 0.6
end
local function makeView(kind)
local V = {}
local isBank = kind == "bank"
local cols, slotSize = COLS, SLOT -- disposition en cours (colonnes : vcfg().cols, taille : vcfg().size)
local hiBag -- sac survolé dans la barre des sacs : ses objets ressortent
local SLOTS_H = 44 -- hauteur de la barre des sacs quand elle est ouverte
-- position et colonnes propres à chaque fenêtre (la banque dans WK.DB.global.bags.bank)
local function vcfg()
    local c = B.Config()
    if not isBank then return c end
    c.bank = c.bank or {}
    return c.bank
end
local function SZ() return SIZES[vcfg().size or "m"] or SLOT end
local win
local holders, buttons = {}, {}   -- holders[bag] ; buttons[bag][slot]
local pending = false
local filter, query = "all", ""
local hovered

-- décalage vertical du contenu quand la barre des sacs est ouverte
local function topOff() return (win and win.slotBar and win.slotBar:IsShown()) and SLOTS_H or 0 end

-- métier qui se sert d'un composant (recettes connues de tes persos, Modules/Recipes.lua)
local function profOf(id)
    local R = WK.modules.Recipes
    local idx = R and R.CraftIndex and R.CraftIndex()
    local list = idx and idx.byReagent[id]
    return list and list[1] and list[1].prof or nil
end

local function holderOf(bag)
    if holders[bag] then return holders[bag] end
    local h = _G.CreateFrame("Frame", nil, win.content)
    h:SetID(bag)
    h:SetAllPoints(win.content)
    holders[bag] = h
    return h
end
-- objet qu'on ouvre d'un clic droit (paquet, coffre) : son n°, sinon nil
local function lootable(bag, slot)
    local CC = _G.C_Container
    if CC and CC.GetContainerItemInfo then
        local ok, info = pcall(CC.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" and info.hasLoot then return info.itemID end
        return nil
    end
    if _G.GetContainerItemInfo then
        local ok, _, _, _, _, _, canLoot, _, _, _, itemID = pcall(_G.GetContainerItemInfo, bag, slot)
        if ok and canLoot then return itemID end
    end
end
-- fenêtre du jeu ouverte où le clic droit fait autre chose (vendre, déposer, poster, échanger)
local BUSY = { "MerchantFrame", "MailFrame", "TradeFrame", "AuctionHouseFrame", "GuildBankFrame" }
local function busyWindow()
    for _, n in ipairs(BUSY) do
        local f = _G[n]
        if f and f.IsShown and f:IsShown() then return true end
    end
    local bf = _G.BankFrame -- gardé ouvert mais invisible par notre banque : visible seulement à la banque
    return bf and bf.IsVisible and bf:IsVisible() and true or false
end
local function openLater(bag, slot, id)
    if _G.InCombatLockdown and _G.InCombatLockdown() then return end
    if _G.LootFrame and _G.LootFrame:IsShown() then return end -- déjà ouvert
    if busyWindow() then return end
    local cur, _, locked = WK.Container.Info(bag, slot)
    if cur ~= id or locked then return end -- déjà ouvert, ou le jeu est en train de le faire
    local CC = _G.C_Container
    if CC and CC.UseContainerItem then pcall(CC.UseContainerItem, bag, slot)
    elseif _G.UseContainerItem then pcall(_G.UseContainerItem, bag, slot) end
end

local function newButton(bag, slot)
    local h = holderOf(bag)
    local name = string.format("WarbandKeeper%sItem%d_%d", isBank and "Bank" or "Bag", bag + 2, slot)
    local ok, b = pcall(_G.CreateFrame, "ItemButton", name, h, "ContainerFrameItemButtonTemplate")
    if not ok or not b then b = _G.CreateFrame("Button", name, h, "ContainerFrameItemButtonTemplate") end
    b:SetID(slot)
    b:SetSize(SZ(), SZ())
    b.wkOurs = true
    -- Objet à ouvrir (paquet, coffre à butin) : le jeu refuse de l'ouvrir depuis le clic d'une case créée par un
    -- addon (ADDON_ACTION_FORBIDDEN « UNKNOWN() » dans UseContainerItem). Une couche invisible, posée seulement sur
    -- ces objets, prend le clic droit (l'addon l'ouvre à l'image suivante) et laisse passer le clic gauche vers la
    -- case. Le clic du jeu n'est jamais remplacé : le remplacer rendait tous les clics « non sûrs »
    -- (potions comprises).
    local op = _G.CreateFrame("Button", nil, b)
    op:SetAllPoints()
    op:SetFrameLevel(b:GetFrameLevel() + 5)
    op:RegisterForClicks("RightButtonUp")
    if op.SetPassThroughButtons then pcall(op.SetPassThroughButtons, op, "LeftButton") end
    op:SetScript("OnClick", function(_, button)
        if button ~= "RightButton" or busyWindow() then return end
        local id = lootable(bag, slot)
        if id then _G.C_Timer.After(0, function() openLater(bag, slot, id) end) end
    end)
    op:SetScript("OnEnter", function() local fn = b:GetScript("OnEnter"); if fn then fn(b) end end)
    op:SetScript("OnLeave", function() local fn = b:GetScript("OnLeave"); if fn then fn(b) end end)
    op:Hide()
    b.wkOpen = op -- infobulle allégée (Modules/Inventory.lua)
    -- case à notre style : carré, bord de 2 px à la couleur de la qualité (le cadre brillant du jeu est masqué)
    b.wkEdge = square(b, 0, -8)
    b.wkFill = square(b, EDGE, -7)
    local ic = region(b, "icon", "Icon", "IconTexture")
    if ic and ic.SetPoint then
        ic:ClearAllPoints(); ic:SetPoint("TOPLEFT", EDGE, -EDGE); ic:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
        if ic.SetTexCoord then ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    end
    -- pastille de l'addon (en haut à gauche : le cadenas est en haut à droite, l'étoile BiS en bas à gauche)
    b.wkTag = _G.CreateFrame("Frame", nil, b)
    b.wkTag:SetFrameLevel(b:GetFrameLevel() + 6)
    b.wkTag:SetPoint("TOPLEFT", -3, 4)
    b.wkTag:SetSize(20, 13)
    b.wkTag.bg = UI:Rounded(b.wkTag, 6, 0, "ARTWORK", 1)
    b.wkTag.t = UI:Text(b.wkTag, 10, C.onAccent or C.bg)
    b.wkTag.t:SetPoint("CENTER", 0, 0)
    b.wkTag:Hide()
    -- survol : la fiche suit l'objet
    b:HookScript("OnEnter", function(s)
        -- cases de la banque principale : infobulle par l'emplacement d'inventaire (le jeu ne la trouve pas par le sac)
        local bc = WK.modules.Inventory:BankMain()
        if bag == bc and _G.BankButtonIDToInvSlotID then
            local okI, inv = pcall(_G.BankButtonIDToInvSlotID, slot)
            if okI and inv then
                _G.GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
                _G.GameTooltip:SetInventoryItem("player", inv)
                _G.GameTooltip:Show()
            end
        end
        if s.wkEntry then hovered = s.wkEntry; V.RefreshFiche() end
        -- objet neuf survolé : la pastille verte part pour de bon
        local e = s.wkEntry
        if e and e.new and not e.offline then
            e.new = false
            seenNew[newKey(e.bag, e.slot, e.id)] = true
            local NI = _G.C_NewItems
            if NI and NI.RemoveNewItem then pcall(NI.RemoveNewItem, e.bag, e.slot) end
            if e.info and e.info.dot then e.info.dot, e.info.badge = nil, nil; s.wkTag:Hide() end
            -- plus compté dans « Nouveaux » : rangé dans sa vraie catégorie au prochain rafraîchissement
            if e.info and e.info.cat == "new" then e.info.cat = "other"; V.newDirty = true end
        end
        V.PlaceTip(s)
    end)
    -- objet neuf vu : rangé dans sa vraie catégorie une fois la souris partie (rien ne bouge sous le curseur)
    b:HookScript("OnLeave", function()
        if V.newDirty then V.newDirty = nil; _G.C_Timer.After(0.2, function() V.Refresh() end) end
    end)
    -- le jeu replace l'infobulle à chaque mise à jour : on la remet hors de la fiche
    if type(b.UpdateTooltip) == "function" then _G.hooksecurefunc(b, "UpdateTooltip", function(s) V.PlaceTip(s) end) end
    buttons[bag] = buttons[bag] or {}
    buttons[bag][slot] = b
    return b
end

-- case d'affichage (autre perso / tout le compte) : icône, nombre, liseré de qualité, infobulle et fiche
local offButtons = {}
local function offButton(i)
    if offButtons[i] then return offButtons[i] end
    local b = _G.CreateFrame("Button", nil, win.content)
    b:SetSize(SZ(), SZ())
    b.wkEdge = square(b, 0, -8)
    b.wkFill = square(b, EDGE, -7)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", EDGE, -EDGE); b.icon:SetPoint("BOTTOMRIGHT", -EDGE, EDGE)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = UI:Text(b, 12); b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    b:SetScript("OnEnter", function(s)
        if not s.e then return end
        UI:TooltipOwner(s, "ANCHOR_LEFT")
        if _G.GameTooltip.SetItemByID then _G.GameTooltip:SetItemByID(s.e.id) end
        _G.GameTooltip:Show()
        hovered = s.e; V.RefreshFiche()
    end)
    b:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        if s.e and _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") and s.e.link and _G.ChatEdit_InsertLink then
            _G.ChatEdit_InsertLink(s.e.link)
        end
    end)
    offButtons[i] = b
    return b
end
local function paintOff(b, e)
    b.e = e
    b.icon:SetTexture(e.icon)
    b.count:SetText((e.count or 1) > 1 and tostring(e.count) or "")
    b.wkEdge:SetColor(edgeColor(e))
    b.wkFill:SetColor(C.surface[1], C.surface[2], C.surface[3], 1)
end

local function paintButton(b, e)
    local icon = region(b, "icon", "Icon", "IconTexture")
    if icon and icon.SetTexture then icon:SetTexture(e and e.icon or nil) end
    local cnt = region(b, "Count")
    if cnt and cnt.SetText then
        if e and (e.count or 1) > 1 then cnt:SetText(e.count); cnt:Show() else cnt:SetText(""); cnt:Hide() end
    end
    if _G.SetItemButtonQuality then pcall(_G.SetItemButtonQuality, b, e and e.quality, e and e.link) end
    local ib = region(b, "IconBorder")
    if ib and ib.Hide then ib:Hide() end -- la qualité est sur notre bord
    if _G.SetItemButtonDesaturated then pcall(_G.SetItemButtonDesaturated, b, e and e.locked or false) end
    local cd = region(b, "Cooldown")
    if cd and e and _G.C_Container and _G.C_Container.GetContainerItemCooldown and _G.CooldownFrame_Set then
        local ok, s, d, en = pcall(_G.C_Container.GetContainerItemCooldown, e.bag, e.slot)
        if ok then pcall(_G.CooldownFrame_Set, cd, s, d, en) end
    end
    local tag = b.wkTag
    local info = e and e.info
    if info and info.badge then
        local col = info.badgeCol or { UI:Accent() }
        tag.bg:SetColor(col[1], col[2], col[3], 1)
        -- texte sombre sur un fond clair (couleurs de classe), comme sur l'accent
        local tc = C.onAccent or C.bg
        tag.t:SetTextColor(tc[1], tc[2], tc[3])
        tag.t:SetText(info.badge)
        if info.dot then tag:SetSize(10, 10)
        else tag:SetSize(math.max(14, (tag.t:GetStringWidth() or 10) + 8), 13) end
        tag:Show()
    else tag:Hide() end
    -- fond de case : le nôtre (cadre brillant du jeu masqué, repeint ici car le jeu peut le remettre)
    local nt = b.GetNormalTexture and b:GetNormalTexture()
    if nt then nt:SetAlpha(0) end
    local sb = region(b, "SlotBackground", "ItemSlotBackground")
    if sb and sb.SetAlpha then sb:SetAlpha(0) end
    if b.wkEdge then
        b.wkEdge:SetColor(edgeColor(e))
        local fc = e and C.surface or C.bg -- case vide : fond creusé
        b.wkFill:SetColor(fc[1], fc[2], fc[3], 1)
    end
    -- reflets du jeu (objet neuf, boutique, emplacement étendu) : notre pastille NEUF les remplace
    for _, k in ipairs({ "NewItemTexture", "BattlepayItemTexture", "ExtendedSlot", "ItemContextOverlay" }) do
        local r = region(b, k)
        if r and r.Hide then r:Hide() end
    end
    for _, k in ipairs({ "newitemglowAnim", "flashAnim" }) do
        local a = b[k]
        if type(a) == "table" and a.Stop then pcall(a.Stop, a) end
    end
    b.wkEntry = e
    -- couche du clic droit : seulement sur un objet à ouvrir, hors marchand, banque, courrier, échange, HV
    if b.wkOpen then
        b.wkOpen:SetShown(e ~= nil and e.bag ~= nil and not busyWindow() and lootable(e.bag, e.slot) ~= nil)
    end
    if UI.ItemLockPaint then pcall(UI.ItemLockPaint, b) end
end

-- l'objet passe-t-il le filtre et la recherche ?
local function matches(e)
    if not e then return false end
    if query ~= "" then
        local n = (e.name or ""):lower()
        if not n:find(query, 1, true) then return false end
    end
    if filter == "new" then return e.info.cat == "new"
    elseif filter == "ship" then return e.info.ship ~= nil
    elseif filter == "sell" then return e.info.cat == "junk"
    elseif filter == "de" then return e.info.de == true
    elseif filter == "up" then return e.info.upgrade ~= nil end
    return true
end

local function dimmed(e)
    if hiBag ~= nil then return e.bag ~= hiBag end
    return not (e.empty or matches(e))
end

local function readBags()
    local list, free, total = {}, 0, 0
    local ctx = context()
    local rb = not isBank and reagentBag() or nil
    local ab = not isBank and ammoBags() or {}
    local rfree, afree = 0, 0
    for _, bag in ipairs((isBank and WK.modules.Inventory:BankList() or WK.modules.Inventory:BagList())) do
        local n = WK.Container.NumSlots(bag) or 0
        total = total + n
        for slot = 1, n do
            local id, count, locked, _, cq = WK.Container.Info(bag, slot)
            if id then
                local name, link, quality, _, _, _, _, _, _, icon = WK.GetItemInfo(id)
                -- qualité lue sur la case (l'objet n'est pas toujours en cache au premier passage)
                if type(cq) == "number" and cq >= 0 then quality = cq end
                if not quality and _G.C_Item and _G.C_Item.GetItemQualityByID then
                    local okq, q2 = pcall(_G.C_Item.GetItemQualityByID, id)
                    if okq then quality = q2 end
                end
                local cl = _G.C_Container and _G.C_Container.GetContainerItemLink
                local slink = cl and cl(bag, slot) or link
                local e = { bag = bag, slot = slot, id = id, count = count, locked = locked, name = name,
                    link = slink, quality = quality, icon = icon or (_G.C_Item and _G.C_Item.GetItemIconByID and
                    _G.C_Item.GetItemIconByID(id)) }
                e.new = isNew(bag, slot, id)
                e.info = classify(e, ctx)
                if rb and bag == rb then e.info.cat = "rbag" elseif ab[bag] then e.info.cat = "abag" end
                list[#list + 1] = e
            else
                if rb and bag == rb then rfree = rfree + 1
                elseif ab[bag] then afree = afree + 1
                else free = free + 1 end
                list[#list + 1] = { bag = bag, slot = slot, empty = true }
            end
        end
    end
    return list, free + rfree + afree, total, rfree + afree, afree
end

-- Sacs et banque d'un autre perso (ou de tout le compte), d'après les derniers relevés (quantités par objet) :
-- cases d'affichage seulement, sans place dans un sac
local function readOffline(key)
    local chars = WK.DB.global.characters
    local ctx = { ship = {}, enchanter = false }
    local list = {}
    local function add(id, n, where, who)
        local name, link, quality, _, _, _, _, _, _, icon = WK.GetItemInfo(id)
        if not quality and _G.C_Item and _G.C_Item.GetItemQualityByID then
            local okq, q2 = pcall(_G.C_Item.GetItemQualityByID, id)
            if okq then quality = q2 end
        end
        local e = { id = id, count = n, name = name, link = link, quality = quality, offline = true,
            where = where, who = who,
            icon = icon or (_G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(id)) }
        e.info = classify(e, ctx)
        list[#list + 1] = e
    end
    if key == "all" then
        local tot = {}
        for _, c in pairs(chars) do
            for _, src in ipairs({ c.bags or {}, c.bank or {} }) do
                for id, n in pairs(src) do tot[id] = (tot[id] or 0) + n end
            end
        end
        local wb = WK.DB.global.warbank
        for id, n in pairs(wb and wb.items or {}) do tot[id] = (tot[id] or 0) + n end
        for id, n in pairs(tot) do add(id, n, "all") end
    else
        local c = chars[key] or {}
        for id, n in pairs(c.bags or {}) do add(id, n, "bags", key) end
        for id, n in pairs(c.bank or {}) do add(id, n, "bank", key) end
    end
    return list
end

-- filtre (maquette B) : icône + nombre d'objets concernés ; le filtre choisi montre aussi son nom
local function chip(parent, key, label, icon)
    local b = UI:Button(parent, "", nil, 26, "ghost", icon)
    b.key, b.name = key, label
    -- pastille de la maquette : fond teinté de l'apparence + liseré ; pleine si choisie, grise si vide
    b.edge = UI:Rounded(b, 13, 0, "BACKGROUND", 2)
    b.fill = UI:Rounded(b, 12, 1, "BACKGROUND", 3)
    local refresh = b.Refresh
    b.Refresh = function(s)
        refresh(s)
        local r, g, bl = UI:Accent()
        local on, empty = s.style == "primary", (s.count or 0) == 0 and s.style ~= "primary"
        local bg = C.bg
        local k = s.hover and 0.26 or 0.16
        if on then
            s.edge:SetColor(r, g, bl, 1); s.fill:SetColor(r, g, bl, 1)
        elseif empty then
            s.edge:SetColor(C.border[1], C.border[2], C.border[3], 1); s.fill:SetColor(bg[1], bg[2], bg[3], 1)
        else
            s.edge:SetColor(r, g, bl, 0.45)
            s.fill:SetColor(r * k + bg[1] * (1 - k), g * k + bg[2] * (1 - k), bl * k + bg[3] * (1 - k), 1)
        end
        local fg = on and C.onAccent or empty and C.dim or { r, g, bl, 1 }
        s.label:SetTextColor(fg[1], fg[2], fg[3], 1)
        if s.icon then s.icon:SetVertexColor(fg[1], fg[2], fg[3], 1) end
    end
    if key == "up" and b.icon then b.icon:SetRotation(math.pi / 2) end
    b:SetScript("OnClick", function() filter = (filter == key and key ~= "all") and "all" or key; V.Refresh(true) end)
    b:HookScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T(s.name), 1, 1, 1)
        _G.GameTooltip:AddLine(string.format(T("%d objet(s)"), s.count or 0), 0.8, 0.8, 0.8)
        _G.GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() _G.GameTooltip:Hide() end)
    return b
end

local function build()
    local f = _G.CreateFrame("Frame", isBank and "WarbandKeeperBank" or "WarbandKeeperBags", _G.UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        vcfg().pos = { p, rp, x, y }
    end)
    UI:HudBackground(f, "window", 12)
    if not isBank then
        -- tout le compte : choix du perso dont on regarde les sacs et la banque (derniers relevés)
        f.who = UI:Dropdown(f, FICHE_W, 26, {}, function(v)
            V.viewKey = (v ~= "me") and v or nil
            hovered = nil
            V.Refresh()
        end)
        f:HookScript("OnHide", function() V.viewKey = nil end)
        -- sacs refermés : les objets neufs ne le sont plus (comme les sacs du jeu)
        f:HookScript("OnHide", function()
            local lr = win and win.lastRead
            for _, e in ipairs(lr and lr.list or {}) do
                if e.new and e.bag and e.slot then seenNew[newKey(e.bag, e.slot, e.id)] = true end
            end
            local NI = _G.C_NewItems
            if NI and NI.ClearAll then pcall(NI.ClearAll) end
        end)
        -- fenêtre de désenchantement des enchanteurs collée à nos sacs (UI/ProfPanels.lua)
        f:HookScript("OnShow", function() if UI.OurBagsShown then UI.OurBagsShown(true) end end)
        f:HookScript("OnHide", function() if UI.OurBagsShown then UI.OurBagsShown(false) end end)
    end
    local pos = vcfg().pos
    if pos then f:SetPoint(pos[1], _G.UIParent, pos[2], pos[3], pos[4])
    elseif isBank then f:SetPoint("TOPLEFT", 60, -120)
    else f:SetPoint("BOTTOMRIGHT", -80, 120) end
    -- en-tête
    f.title = UI:Text(f, 14); f.title:SetPoint("TOPLEFT", PAD, -12); f.title:SetText(T(isBank and "Banque" or "Sacs"))
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
    f.close = UI:IconButton(f, "close", 18); f.close:SetPoint("TOPRIGHT", -10, -10)
    -- fermer = fermer les sacs du jeu (notre fenêtre suit) ; Échap passe aussi par eux
    f.close:SetScript("OnClick", function()
        if isBank then
            if _G.CloseBankFrame then _G.CloseBankFrame() end
            f:Hide()
            return
        end
        if _G.CloseAllBags then _G.CloseAllBags() end
        _G.C_Timer.After(0.05, function() if f:IsShown() and not gameOpen() then f:Hide() end end)
    end)
    f.search = UI:Input(f, 170, 24, "Rechercher...", "search")
    f.search:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    -- barre des sacs équipés (changer de sac, acheter un emplacement de banque)
    f.bagsBtn = UI:IconButton(f, "bag", 22, isBank and "Sacs de banque" or "Sacs équipés")
    f.bagsBtn:SetPoint("RIGHT", f.search, "LEFT", -8, 0)
    -- passer à la fenêtre du jeu (un bouton « Warband Keeper » sur celle-ci ramène la nôtre)
    f.gameBtn = UI:IconButton(f, "refresh", 22, isBank and "Banque du jeu" or "Sacs du jeu")
    f.gameBtn:SetPoint("RIGHT", f.bagsBtn, "LEFT", -6, 0)
    f.gameBtn:SetScript("OnClick", function() if B.UseGame then B.UseGame(kind, true) end end)
    -- tri du jeu (range les objets dans les vrais sacs / la banque)
    f.sortBtn = UI:IconButton(f, "filter", 22,
        isBank and "Trier la banque (tri du jeu)" or "Trier les sacs (tri du jeu)")
    f.sortBtn:SetPoint("RIGHT", f.gameBtn, "LEFT", -6, 0)
    f.sortBtn:SetScript("OnClick", function() V.Sort() end)
    -- avec ou sans catégories
    -- affichage : avec ou sans catégories, taille des cases
    f.flatBtn = UI:IconButton(f, "menu", 22, "Affichage : catégories et taille des objets")
    f.flatBtn:SetPoint("RIGHT", f.sortBtn, "LEFT", -6, 0)
    local lm = _G.CreateFrame("Frame", nil, f)
    lm:SetFrameLevel(f:GetFrameLevel() + 30)
    lm:EnableMouse(true)
    UI:HudBackground(lm, "hud", 8)
    lm:SetPoint("TOPRIGHT", f.flatBtn, "BOTTOMRIGHT", 0, -6)
    lm:Hide()
    local l1 = UI:Text(lm, 11, C.muted); l1:SetPoint("TOPLEFT", 12, -12); l1:SetText(T("Catégories"))
    lm.flat = UI:Segmented(lm, { { "cats", T("Avec") }, { "flat", T("Sans") } }, function(k)
        vcfg().flat = k == "flat" or nil
        V.Refresh()
    end, 26)
    lm.flat:SetPoint("TOPLEFT", 12, -30)
    local l2 = UI:Text(lm, 11, C.muted); l2:SetPoint("TOPLEFT", 12, -66); l2:SetText(T("Taille des objets"))
    lm.size = UI:Segmented(lm, { { "s", T("Petit") }, { "m", T("Moyen") }, { "l", T("Grand") } }, function(k)
        if inCombat() then lm.size:Select(vcfg().size or "m"); return end
        vcfg().size = k ~= "m" and k or nil
        f.applyBounds()
        V.Refresh()
    end, 26)
    lm.size:SetPoint("TOPLEFT", 12, -84)
    lm:SetSize(math.max(lm.flat:GetWidth(), lm.size:GetWidth(), 150) + 24, 122)
    lm:SetScript("OnShow", function()
        lm.flat:Select(vcfg().flat and "flat" or "cats")
        lm.size:Select(vcfg().size or "m")
        f.flatBtn:SetActive(true)
    end)
    lm:SetScript("OnHide", function() f.flatBtn:SetActive(false) end)
    f.layMenu = lm
    f.flatBtn:SetScript("OnClick", function() lm:SetShown(not lm:IsShown()) end)
    f:HookScript("OnHide", function() lm:Hide() end)
    f.slotBar = _G.CreateFrame("Frame", nil, f)
    f.slotBar:SetPoint("TOPLEFT", PAD, -38); f.slotBar:SetPoint("TOPRIGHT", -PAD, -38); f.slotBar:SetHeight(SLOTS_H - 6)
    f.slotBar:SetShown(vcfg().slots and true or false)
    f.bagsBtn:SetActive(f.slotBar:IsShown())
    f.bagsBtn:SetScript("OnClick", function()
        if inCombat() then return end
        f.slotBar:SetShown(not f.slotBar:IsShown())
        vcfg().slots = f.slotBar:IsShown()
        f.bagsBtn:SetActive(f.slotBar:IsShown())
        V.ApplyTop(); V.Refresh()
    end)
    f.bagSlots = {}
    f.search.onChange = function(t) query = (t or ""):lower(); V.Refresh(true) end
    -- filtres
    f.chips = {}
    local prev
    for _, c in ipairs({ { "all", "Tout", "bag" }, { "new", "Nouveaux", "star" }, { "ship", "À ranger", "send" },
        { "sell", "À vendre", "coin" }, { "de", "Désenchanter", "spark" }, { "up", "Améliorations", "arrow" } }) do
        local b = chip(f, c[1], c[2], c[3])
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", PAD - 4, -38); f.chip1 = b end
        f.chips[#f.chips + 1] = b
        prev = b
    end
    -- contenu : toutes les cases visibles, sans défilement
    f.content = _G.CreateFrame("Frame", nil, f)
    f.content:SetPoint("TOPLEFT", PAD, -70)
    f.content:SetSize(1, 1)
    -- coin de redimensionnement : la largeur fixe le nombre de colonnes, la hauteur suit (tout reste visible)
    f:SetResizable(true)
    function f.applyBounds()
        local minW = PAD * 2 + MIN_COLS * (SZ() + GAP) + 14 + (B.Config().fiche and (FICHE_W + 10) or 0)
        if f.SetResizeBounds then f:SetResizeBounds(minW, 320)
        elseif f.SetMinResize then f:SetMinResize(minW, 320) end
    end
    f.applyBounds()
    local grip = _G.CreateFrame("Button", nil, f)
    grip:SetSize(18, 18)
    grip:SetPoint("BOTTOMRIGHT", -4, 4)
    grip:SetFrameLevel(f:GetFrameLevel() + 20)
    local gt = UI:Icon(grip, "grip", 14, C.dim)
    gt:SetPoint("CENTER")
    grip:SetScript("OnEnter", function()
        gt:SetVertexColor(UI:Accent())
        UI:TooltipOwner(grip, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T("Redimensionner : plus ou moins de colonnes, toutes les cases restent visibles"),
            1, 1, 1, 1, true)
        _G.GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() gt:SetVertexColor(unpack(C.dim)); _G.GameTooltip:Hide() end)
    grip:SetScript("OnMouseDown", function()
        if inCombat() then return end
        f.sizing = true
        f:StartSizing("BOTTOMRIGHT")
    end)
    grip:SetScript("OnMouseUp", function()
        if not f.sizing then return end
        f:StopMovingOrSizing()
        f.sizing = nil
        local ficheW = B.Config().fiche and (FICHE_W + 10) or 0
        local n = math.floor((f:GetWidth() - PAD * 2 - 14 - ficheW + GAP) / (SZ() + GAP))
        vcfg().cols = math.max(MIN_COLS, math.min(MAX_COLS, n))
        -- la position reste celle du coin haut gauche
        local l, t = f:GetLeft(), f:GetTop()
        if l and t then
            f:ClearAllPoints(); f:SetPoint("TOPLEFT", _G.UIParent, "BOTTOMLEFT", l, t)
            vcfg().pos = { "TOPLEFT", "BOTTOMLEFT", l, t }
        end
        V.Refresh()
    end)
    f:SetScript("OnSizeChanged", function(s)
        if s.sizing and not s.reflow then
            s.reflow = true
            _G.C_Timer.After(0.05, function() s.reflow = nil; if s.sizing then V.Refresh(true, true) end end)
        end
    end)
    f.grip = grip
    f.heads = {}
    -- pied
    -- places libres (nombre à la couleur de l'apparence) et or du perso, bien lisibles
    f.foot = UI:Text(f, 14, C.muted); f.foot:SetPoint("BOTTOMLEFT", PAD, 12)
    f.coin = UI:Icon(f, "coin", 16, C.gold)
    f.coin:SetPoint("LEFT", f.foot, "RIGHT", 18, 0)
    f.money = UI:Text(f, 15); f.money:SetPoint("LEFT", f.coin, "RIGHT", 6, 0)
    -- clic sur l'or : Inventaire > Monnaies
    f.moneyBtn = _G.CreateFrame("Button", nil, f)
    f.moneyBtn:SetPoint("TOPLEFT", f.coin, "TOPLEFT", -4, 6)
    f.moneyBtn:SetPoint("BOTTOMRIGHT", f.money, "BOTTOMRIGHT", 4, -6)
    f.moneyBtn:SetScript("OnClick", function() B.OpenMoney() end)
    f.moneyBtn:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T("Voir les monnaies du compte"), 1, 1, 1)
        _G.GameTooltip:Show()
    end)
    f.moneyBtn:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
    f.sell = UI:Button(f, "Vendre la camelote", nil, 22, "secondary")
    f.sell:SetPoint("BOTTOMRIGHT", -(PAD + (B.Config().fiche and FICHE_W + 10 or 0)), 9)
    f.sell:SetScript("OnClick", function() V.SellJunk() end)
    -- marchand : objets dont personne n'a besoin (Rangement, « au marchand »)
    f.sellMore = UI:Button(f, "Vendre les inutiles", nil, 22, "secondary")
    f.sellMore:SetScript("OnClick", function() V.SellUnneeded() end)
    f.sellMore:HookScript("OnEnter", function(s)
        local St = WK.modules.Stash
        local ok, list = pcall(St.MyVendorItems, St)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        local tip = _G.GameTooltip
        tip:SetText(T("Vendre les inutiles"), 1, 1, 1)
        tip:AddLine(T("Objets dont aucun de tes persos n'a besoin (Inventaire > Rangement, colonne « Au marchand »). "
            .. "Jamais un objet verrouillé."),
            0.85, 0.85, 0.85, true)
        local total = 0
        for i, e in ipairs(ok and list or {}) do
            if i <= 12 then
                local name, _, r, g, b = UI:ItemInfo(e.id)
                tip:AddDoubleLine(name .. " x" .. e.count, WK:FormatMoney((e.unit or 0) * e.count), r, g, b, 1, 1, 1)
            end
            total = total + (e.unit or 0) * e.count
        end
        tip:AddDoubleLine(T("Total"), WK:FormatMoney(total), 0.6, 0.6, 0.6, 1, 1, 1)
        tip:Show()
    end)
    f.sellMore:HookScript("OnLeave", function() _G.GameTooltip:Hide() end)
    -- piles incomplètes d'un même objet : réunies (place gagnée)
    f.merge = UI:Button(f, "Réunir les piles", nil, 22, "secondary")
    f.merge:SetScript("OnClick", function()
        local St = WK.modules.Stash
        if St and St:MergeStacks(isBank and { "bank" } or { "bags" }, function() V.Refresh() end) then
            f.merge:Hide()
        end
    end)
    f.merge:HookScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        _G.GameTooltip:SetText(T("Réunir les piles"), 1, 1, 1)
        local txt = T("Regroupe les piles incomplètes d'un même objet : %d case(s) libérée(s).")
        _G.GameTooltip:AddLine(string.format(txt, s.freed or 0), 0.85, 0.85, 0.85, true)
        _G.GameTooltip:Show()
    end)
    f.merge:HookScript("OnLeave", function() _G.GameTooltip:Hide() end)
    -- banque : « Ranger » = dépôt d'après les règles de banque, puis sortie de ce dont le perso a besoin
    if isBank then
        f.tidy = UI:Button(f, "Ranger", nil, 24, "primary", "bag")
        f.tidy:SetPoint("BOTTOMRIGHT", -(PAD + (B.Config().fiche and FICHE_W + 10 or 0)), 8)
        f.tidy:SetScript("OnClick", function()
            if WK.modules.BankDeposit then WK.modules.BankDeposit:Tidy() end
        end)
        f.tidy:HookScript("OnEnter", function(s)
            local BD = WK.modules.BankDeposit
            if not BD then return end
            local okD, dep = pcall(BD.PendingCount, BD)
            local okW, out = pcall(BD.WithdrawCount, BD)
            UI:TooltipOwner(s, "ANCHOR_TOP")
            local tip = _G.GameTooltip
            tip:SetText(T("Ranger"), 1, 1, 1)
            tip:AddLine(string.format(T("Déposer : %d objet(s) d'après tes règles de banque"), okD and dep or 0),
                0.85, 0.85, 0.85)
            tip:AddLine(string.format(T("Sortir : %d objet(s) pour tes métiers et Avant de partir"), okW and out or 0),
                0.85, 0.85, 0.85)
            local St = WK.modules.Stash
            if St and St.MergePlan then
                local Inv = WK.modules.Inventory
                local _, fb = St:MergePlan(Inv:BankList())
                local _, fs = St:MergePlan(Inv:BagList())
                local fmt = T("Réunir les piles : %d case(s) libérée(s) dans la banque, %d dans les sacs")
                tip:AddLine(string.format(fmt, fb, fs), 0.85, 0.85, 0.85)
            end
            tip:Show()
        end)
        f.tidy:HookScript("OnLeave", function() _G.GameTooltip:Hide() end)
    end
    -- fiche de l'objet survolé (maquette B)
    local fi = _G.CreateFrame("Frame", nil, f)
    fi:SetPoint("TOPRIGHT", -PAD, -70); fi:SetWidth(FICHE_W); fi:SetHeight(60) -- hauteur : suit le contenu
    UI:Panel(fi, 10, C.surface, C.border)
    fi.icon = fi:CreateTexture(nil, "ARTWORK"); fi.icon:SetSize(36, 36); fi.icon:SetPoint("TOPLEFT", 12, -12)
    fi.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fi.name = UI:Text(fi, 13); fi.name:SetPoint("TOPLEFT", 56, -12); fi.name:SetPoint("TOPRIGHT", -10, -12)
    fi.name:SetJustifyH("LEFT")
    fi.sub = UI:Text(fi, 10, C.muted); fi.sub:SetPoint("TOPLEFT", 56, -32); fi.sub:SetPoint("TOPRIGHT", -10, -32)
    fi.sub:SetJustifyH("LEFT")
    if fi.sub.SetWordWrap then fi.sub:SetWordWrap(true) end -- « 121 dans ta banque · 121 sur le compte » sur 2 lignes
    fi.body = UI:Text(fi, 11); fi.body:SetPoint("TOPLEFT", 12, -60); fi.body:SetPoint("TOPRIGHT", -12, -60)
    fi.body:SetJustifyH("LEFT"); fi.body:SetJustifyV("TOP")
    if fi.body.SetWordWrap then fi.body:SetWordWrap(true) end
    if fi.body.SetSpacing then fi.body:SetSpacing(4) end
    fi.lock = UI:Button(fi, "Verrouiller", nil, 24, "secondary")
    fi.lock:SetPoint("TOPLEFT", 10, -60)
    fi.lock:SetScript("OnClick", function()
        if hovered and hovered.id then WK.modules.ItemLock:Toggle(hovered.id); V.Refresh() end
    end)
    fi.de = UI:Button(fi, "Toujours désenchanter", nil, 24, "secondary")
    fi.de:SetPoint("TOPLEFT", fi.lock, "BOTTOMLEFT", 0, -6)
    fi.de:SetScript("OnClick", function()
        if hovered and hovered.id then WK.modules.ProfHelp:ToggleDEMark(hovered.id); V.Refresh() end
    end)
    -- camelote à la main : part avec « Vendre la camelote » (et la vente automatique des gris)
    fi.junk = UI:Button(fi, "Camelote", nil, 24, "secondary")
    fi.junk:SetPoint("TOPLEFT", fi.de, "BOTTOMLEFT", 0, -6)
    fi.junk:SetScript("OnClick", function()
        if hovered and hovered.id and WK.modules.QoL then WK.modules.QoL:ToggleJunk(hovered.id); V.Refresh() end
    end)
    -- exception de répartition (Rangement) : automatique, toujours à un perso, jamais, toujours à l'HV
    fi.dest = UI:Button(fi, "Destination", nil, 24, "secondary")
    fi.dest:SetScript("OnClick", function(b)
        if hovered and hovered.id and UI.StashItemMenu then UI:StashItemMenu(hovered.id, b) end
    end)
    fi.ah = UI:Button(fi, "Chercher à l'HV", nil, 24, "secondary")
    fi.ah:SetPoint("TOPLEFT", fi.lock, "TOPRIGHT", 6, 0)
    fi.ah:SetScript("OnClick", function()
        if hovered and hovered.id and WK.modules.AHScan then WK.modules.AHScan:SearchItem(hovered.id) end
    end)
    fi.empty = UI:Text(fi, 11, C.muted); fi.empty:SetPoint("TOPLEFT", 12, -14); fi.empty:SetPoint("TOPRIGHT", -12, -14)
    fi.empty:SetJustifyH("LEFT"); if fi.empty.SetWordWrap then fi.empty:SetWordWrap(true) end
    fi.empty:SetText(T("Survole un objet : son prix, qui en a besoin sur le compte et ce que tu peux en faire."))
    f.fiche = fi
    fi:SetShown(B.Config().fiche)
    f:Hide()
    -- au-dessus des fenêtres du jeu ouvertes avec les sacs (marchand, courrier) : la nôtre se met devant au clic
    return f
end

-- Repeint (et place les cases hors combat). light = seulement filtres / recherche
function V.Refresh(light, live)
    if not win or not win:IsShown() then return end
    V.ApplyTop()
    V.RefreshSlots()
    local offKey = not isBank and V.viewKey or nil
    local list, free, total, rfree, afree
    local chars = WK.DB.global.characters
    -- rafraîchissement léger (filtre, recherche, survol d'un sac) : la dernière lecture est reprise telle quelle
    -- (avant : sacs relus et chaque objet reclassé à chaque frappe dans la recherche)
    local lr = win.lastRead
    if light and lr and lr.key == (offKey or "me") then
        list, free, total, rfree, afree = lr.list, lr.free, lr.total, lr.rfree, lr.afree
    elseif offKey then
        list = readOffline(offKey)
        local c = offKey ~= "all" and chars[offKey] or nil
        free, total, rfree = c and (c.freeSlots or 0) or 0, c and (c.totalSlots or 0) or 0, 0
    else
        list, free, total, rfree, afree = readBags()
    end
    win.lastRead = { key = offKey or "me", list = list, free = free, total = total, rfree = rfree, afree = afree }
    win.list = list
    if win.who then V.RefreshWho() end
    if offKey == "all" then
        win.sub:SetText(T("tout le compte (derniers relevés)"))
    elseif offKey then
        local c = chars[offKey] or {}
        local bank = c.bankSlots
            and string.format(T("banque %d / %d"), (c.bankSlots or 0) - (c.bankFree or 0), c.bankSlots)
            or T("banque pas encore vue")
        win.sub:SetText(string.format(T("%d / %d places"), total - free, total) .. "  ·  " .. bank)
    else
        win.sub:SetText(string.format(T("%d / %d places"), total - free, total))
    end
    local counts = { all = 0, new = 0, ship = 0, sell = 0, de = 0, up = 0 }
    for _, e in ipairs(list) do
        if not e.empty then
            local i = e.info
            counts.all = counts.all + 1
            if i.cat == "new" then counts.new = counts.new + 1 end
            if i.ship then counts.ship = counts.ship + 1 end
            if i.cat == "junk" then counts.sell = counts.sell + 1 end
            if i.de then counts.de = counts.de + 1 end
            if i.upgrade then counts.up = counts.up + 1 end
        end
    end
    for _, b in ipairs(win.chips) do
        local on, n = b.key == filter, counts[b.key] or 0
        b.count = n
        b:SetLabel(on and (T(b.name) .. "  ·  " .. n) or tostring(n))
        b:SetStyle(on and "primary" or "ghost")
    end
    -- money / pied
    local money = _G.GetMoney and _G.GetMoney() or 0
    local ac = { UI:Accent() }
    local normal = free - (rfree or 0)
    win.foot:SetText(string.format(T("%s places libres"), UI:Hex(normal == 0 and C.negative or ac) .. normal .. "|r")
        .. (((rfree or 0) - (afree or 0)) > 0 and ("  " .. UI:Hex(C.muted) .. "+ "
            .. string.format(T("%d pour les composants"), rfree - (afree or 0)) .. "|r") or "")
        .. ((afree or 0) > 0 and ("  " .. UI:Hex(C.muted) .. "+ " .. string.format(T("%d pour les munitions"), afree)
            .. "|r") or ""))
    if offKey then
        money = 0
        for k, c in pairs(chars) do if offKey == "all" or k == offKey then money = money + (c.money or 0) end end
    end
    win.money:SetText(WK:FormatMoney(money))
    local junk = 0
    for _, e in ipairs(list) do if not e.empty and e.info.cat == "junk" then junk = junk + 1 end end
    local merchant = _G.MerchantFrame and _G.MerchantFrame:IsShown()
    win.sell:SetShown(not isBank and not offKey and merchant and junk > 0)
    -- boutons du pied, de droite à gauche : Ranger (banque) / Vendre la camelote, Vendre les inutiles, Réunir les piles
    local St = WK.modules.Stash
    local unneeded = 0
    if not isBank and not offKey and merchant and St then
        local okV, vl = pcall(St.MyVendorItems, St)
        unneeded = okV and #vl or 0
    end
    win.sellMore:SetShown(unneeded > 0)
    if unneeded > 0 then win.sellMore:SetLabel(string.format(T("Vendre les inutiles (%d)"), unneeded)) end
    if not offKey and St and not light and not (St.Merging and St:Merging()) then
        local Inv = WK.modules.Inventory
        local okM, _, fr = pcall(St.MergePlan, St, isBank and Inv:BankList() or Inv:BagList())
        local mFreed = okM and fr or 0
        win.merge.freed = mFreed
        win.merge:SetShown(mFreed > 0)
    elseif offKey then
        win.merge:Hide()
    end
    local anchor = isBank and win.tidy or (win.sell:IsShown() and win.sell) or nil
    for _, b in ipairs({ win.sellMore, win.merge }) do
        if b:IsShown() then
            b:ClearAllPoints()
            if anchor then b:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
            else b:SetPoint("BOTTOMRIGHT", -(PAD + (B.Config().fiche and FICHE_W + 10 or 0)), 9) end
            anchor = b
        end
    end
    -- disposition : par catégorie, cases vides à la fin
    if inCombat() and not offKey then
        pending = true
        for _, e in ipairs(list) do
            local b = buttons[e.bag] and buttons[e.bag][e.slot]
            if b then paintButton(b, not e.empty and e or nil); b:SetAlpha(dimmed(e) and 0.25 or 1) end
        end
        return
    end
    pending = false
    -- catégories : celles des sacs ; la banque range ses composants par métier ; option « sans catégories »
    local flat = vcfg().flat
    -- tri du jeu utile seulement sans catégories (avec, l'ordre affiché ne dépend pas de la place dans les sacs)
    win.sortBtn.wkOff = not flat
    win.sortBtn:SetEnabled(flat and true or false)
    win.sortBtn:SetAlpha(flat and 1 or 0.35)
    local groups, cats = {}, {}
    if offKey and offKey ~= "all" then
        cats = { { key = "o:bags", label = "Dans les sacs" }, { key = "o:bank", label = "En banque" } }
    elseif flat then
        -- sans catégories : une seule grille, mais le sac de composants garde la sienne (seuls des composants y vont)
        cats = { { key = "all", label = "Objets" } }
        if not isBank then
            for _, c in ipairs(CATS) do if c.key == "rbag" or c.key == "abag" then cats[#cats + 1] = c end end
        end
    else
        for _, c in ipairs(CATS) do
            if isBank and c.key == "mine" then cats[#cats + 1] = { key = "__prof" }
            elseif not (isBank and (c.key == "rbag" or c.key == "abag")) then cats[#cats + 1] = c end
        end
    end
    for _, c in ipairs(cats) do groups[c.key] = {} end
    local profKeys = {}
    local function keyOf(e)
        if e.offline and e.where ~= "all" then return "o:" .. e.where end
        if flat then
            if not isBank and (e.info.cat == "rbag" or e.info.cat == "abag") then return e.info.cat end
            return "all"
        end
        local k = e.info.cat
        if isBank and (k == "mine" or (k == "other" and REAGENT_CLASS[instant(e.id) or -1])) then
            local p = profOf(e.id)
            k = p and ("p:" .. p) or "reag"
            if not groups[k] then
                groups[k] = {}
                profKeys[#profKeys + 1] = { key = k, label = p or "Autres composants", prof = p }
            end
        end
        return k
    end
    local empties, rEmpties, aEmpties = {}, {}, {}
    local abags = not isBank and ammoBags() or {}
    for _, e in ipairs(list) do
        if e.empty then
            if not isBank and e.bag == reagentBag() then rEmpties[#rEmpties + 1] = e
            elseif abags[e.bag] then aEmpties[#aEmpties + 1] = e
            else empties[#empties + 1] = e end
        else table.insert(groups[keyOf(e)], e) end
    end
    if isBank and not flat then
        -- composants par métier (ordre alphabétique), « Autres composants » à la fin, à la place de « Composants »
        table.sort(profKeys, function(a, b)
            if (a.prof == nil) ~= (b.prof == nil) then return a.prof ~= nil end
            return T(a.label) < T(b.label)
        end)
        local out = {}
        for _, c in ipairs(cats) do
            if c.key == "__prof" then for _, pk in ipairs(profKeys) do out[#out + 1] = pk end
            else out[#out + 1] = c end
        end
        cats = out
    end
    -- sans catégories : l'ordre réel des sacs (le tri du jeu se voit) ; avec : qualité, nom, quantité
    local catIdx = {}
    for i, c in ipairs(CATS) do catIdx[c.key] = i end
    for _, g in pairs(flat and not offKey and {} or groups) do
        table.sort(g, function(a, b)
            if a.offline and (catIdx[a.info.cat] or 0) ~= (catIdx[b.info.cat] or 0) then
                return (catIdx[a.info.cat] or 0) < (catIdx[b.info.cat] or 0)
            end
            if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
            if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
            return (a.count or 0) > (b.count or 0)
        end)
    end
    -- colonnes : suivent la largeur de la fenêtre (cases de taille fixe) ; la hauteur montre toutes les cases
    local ficheW = B.Config().fiche and (FICHE_W + 10) or 0
    if live then
        cols = math.floor((win:GetWidth() - PAD * 2 - 14 - ficheW + GAP) / (SZ() + GAP))
    else
        cols = vcfg().cols or COLS
    end
    cols = math.max(MIN_COLS, math.min(MAX_COLS, cols))
    slotSize = SZ()
    local used = {}
    local y, hi = 0, 0
    local function head(label, meta, col)
        hi = hi + 1
        local h = win.heads[hi]
        if not h then
            h = _G.CreateFrame("Frame", nil, win.content)
            h:SetHeight(18)
            h.t = UI:Text(h, 10, C.muted); h.t:SetPoint("LEFT", 0, 0)
            h.m = UI:Text(h, 10, C.dim); h.m:SetPoint("LEFT", h.t, "RIGHT", 8, 0)
            h.line = h:CreateTexture(nil, "ARTWORK"); h.line:SetHeight(1)
            h.line:SetPoint("LEFT", h.m, "RIGHT", 8, 0); h.line:SetPoint("RIGHT", 0, 0)
            win.heads[hi] = h
        end
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetWidth(cols * (slotSize + GAP) - GAP)
        h.t:SetText(UI:Upper(T(label)))
        local cc = col == "accent" and { UI:Accent() } or C[col or "muted"] or C.muted
        h.t:SetTextColor(cc[1], cc[2], cc[3])
        h.m:SetText(meta or "")
        h.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        h:Show()
        y = y + 22
    end
    local offN = 0
    local function place(items)
        for i, e in ipairs(items) do
            local b
            if e.offline then
                offN = offN + 1
                b = offButton(offN)
                paintOff(b, e)
            else
                b = (buttons[e.bag] and buttons[e.bag][e.slot]) or newButton(e.bag, e.slot)
            end
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            b:ClearAllPoints()
            b:SetSize(slotSize, slotSize)
            b:SetPoint("TOPLEFT", win.content, "TOPLEFT", col * (slotSize + GAP), -(y + row * (slotSize + GAP)))
            if not e.offline then paintButton(b, not e.empty and e or nil) end
            b:SetAlpha(dimmed(e) and 0.25 or 1)
            b:Show()
            used[b] = true
        end
        if #items > 0 then y = y + math.ceil(#items / cols) * (slotSize + GAP) + 8 end
    end
    -- sacs spéciaux (composants, munitions) : places vides à la suite des objets, sur les mêmes lignes ;
    -- en-tête « occupées / total »
    local special = {}
    if groups.rbag then special.rbag = rEmpties; rEmpties = {} end
    if groups.abag then special.abag = aEmpties; aEmpties = {} end
    for _, c in ipairs(cats) do
        local g = groups[c.key] or {}
        local sp = special[c.key]
        local usedN = #g
        if sp then for _, e in ipairs(sp) do g[#g + 1] = e end end
        if #g > 0 then
            local meta = sp and (usedN .. " / " .. #g) or tostring(#g)
            if c.key == "junk" then
                local v = 0
                for _, e in ipairs(g) do v = v + (select(11, WK.GetItemInfo(e.id)) or 0) * (e.count or 1) end
                meta = WK:FormatMoney(v)
            end
            head(c.label, meta, c.color)
            place(g)
        end
    end
    if #empties > 0 then head("Places libres", tostring(#empties)); place(empties) end
    if #rEmpties > 0 then head("Places libres du sac de composants", tostring(#rEmpties), "rule"); place(rEmpties) end
    if #aEmpties > 0 then head("Places libres du sac à munitions", tostring(#aEmpties), "gold"); place(aEmpties) end
    for i = hi + 1, #win.heads do win.heads[i]:Hide() end
    -- cases d'un sac retiré : cachées
    for _, byBag in pairs(buttons) do for _, b in pairs(byBag) do if not used[b] then b:Hide() end end end
    for i = offN + 1, #offButtons do offButtons[i]:Hide() end
    -- tailles : pendant le redimensionnement, la fenêtre suit la souris ; sinon elle prend la place choisie
    -- (ou juste ce qu'il faut sans réglage), jamais moins que les cases
    win.content:SetSize(math.max(1, cols * (slotSize + GAP) - GAP), math.max(1, y))
    if not live then
        win:SetSize(PAD * 2 + cols * (slotSize + GAP) - GAP + 14 + ficheW, math.max(320, y + 110 + topOff()))
    end
    if not light then V.RefreshFiche() end
end

function V.Layout() return cols, slotSize end -- pour les tests

-- Objet pris en main ou recharge d'un objet : seules les cases sont repeintes (cadenas du jeu, nombre, recharge),
-- sans relire ni reclasser tous les sacs (avant : tout était refait à chaque clic et à chaque recharge en combat).
-- Rend faux si une case a changé d'objet : il faut alors tout refaire.
function V.Repaint()
    if not (win and win:IsShown() and win.list) or V.viewKey then return true end
    for _, e in ipairs(win.list) do
        if not e.empty and e.bag then
            local b = buttons[e.bag] and buttons[e.bag][e.slot]
            local id, count, locked = WK.Container.Info(e.bag, e.slot)
            if id ~= e.id then return false end
            e.count, e.locked = count, locked
            if b then paintButton(b, e) end
        end
    end
    return true
end

-- Tri du jeu : sacs (C_Container.SortBags) ou banque (SortBankBags) ; jamais en combat
function V.Sort()
    if inCombat() then return end
    local CC = _G.C_Container
    if isBank then
        local f = (CC and CC.SortBankBags) or _G.SortBankBags
        if f then pcall(f) else WK:Print(T("Le tri de la banque n'existe pas sur ce client.")) end
    else
        WK.modules.Inventory:SortBags()
    end
end

-- infobulle d'une case : à gauche de l'objet (au-dessus s'il n'y a pas la place), jamais sur la fiche de droite
function V.PlaceTip(btn)
    local tip = _G.GameTooltip
    if not (win and tip and tip:IsShown() and tip:GetOwner() == btn) then return end
    tip:ClearAllPoints()
    local left = btn:GetLeft() or 0
    if left * (btn:GetEffectiveScale() / (tip:GetEffectiveScale() or 1)) > (tip:GetWidth() or 280) + 8 then
        tip:SetPoint("TOPRIGHT", btn, "TOPLEFT", -4, 0)
    else
        tip:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 4)
    end
end

-- menu du perso regardé : moi, les autres persos (places libres), tout le compte
function V.RefreshWho()
    if not win or not win.who then return end
    local me = WK:CharKey()
    local opts = { { "me", T("Mes sacs") } }
    for _, e in ipairs(UI:SortedCharacters()) do
        if e.key ~= me then
            local c = e.c
            local lbl = WK:CharName(c, e.key)
            if c.totalSlots then lbl = lbl .. "  ·  " .. string.format(T("%d libres"), c.freeSlots or 0) end
            opts[#opts + 1] = { e.key, lbl }
        end
    end
    opts[#opts + 1] = { "all", T("Tout le compte") }
    win.who:SetOptions(opts)
    win.who:Select(V.viewKey or "me")
end

-- place les filtres, les cases et la fiche sous la barre des sacs (ouverte ou non)
function V.ApplyTop()
    if not win or inCombat() then return end
    local off = topOff()
    if win.chip1 then win.chip1:ClearAllPoints(); win.chip1:SetPoint("TOPLEFT", PAD - 4, -38 - off) end
    win.content:ClearAllPoints(); win.content:SetPoint("TOPLEFT", PAD, -70 - off)
    win.fiche:ClearAllPoints()
    if win.who then
        -- choix du perso au-dessus de la fiche (ou sur la ligne des filtres sans fiche)
        win.who:ClearAllPoints()
        if win.fiche:IsShown() then
            win.who:SetPoint("TOPRIGHT", -PAD, -70 - off)
            win.fiche:SetPoint("TOPRIGHT", -PAD, -104 - off)
        else
            win.who:SetPoint("TOPRIGHT", -PAD, -38 - off)
            win.fiche:SetPoint("TOPRIGHT", -PAD, -70 - off)
        end
    else
        win.fiche:SetPoint("TOPRIGHT", -PAD, -70 - off)
    end
end

-- Barre des sacs : sacs 1 à 4 (sacs) ou sacs de banque ; glisser un sac pour le mettre ou le changer,
-- clic pour le prendre ; emplacement de banque pas encore acheté : deux clics pour l'acheter
local function bagSlotList()
    -- sacs du perso : 1 à 4, plus le sac de composants quand le client en a un
    local t, nb = {}, _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4
    if isBank then
        for _, b in ipairs(WK.modules.Inventory:BankBagIDs()) do t[#t + 1] = b end
    else
        for i = 1, nb do t[#t + 1] = i end
    end
    return t
end
local function invOf(bag)
    local CC = _G.C_Container
    local f = (CC and CC.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
    if not f then return nil end
    local ok, v = pcall(f, bag)
    return ok and v or nil
end
local function slotButton(i)
    local b = _G.CreateFrame("Button", nil, win.slotBar)
    b:SetSize(34, 34)
    b:SetPoint("TOPLEFT", (i - 1) * 40, 0)
    b.edge = UI:Rounded(b, 6, 0, "BACKGROUND", 1)
    b.fill = UI:Rounded(b, 5, 1, "BACKGROUND", 2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 3, -3); b.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.n = UI:Text(b, 10); b.n:SetPoint("BOTTOMRIGHT", -2, 2)
    b.lock = UI:Icon(b, "lock", 14, C.muted); b.lock:SetPoint("CENTER")
    b:RegisterForDrag("LeftButton")
    local function pick()
        if b.locked or not b.inv or inCombat() or not _G.PickupInventoryItem then return end
        _G.PickupInventoryItem(b.inv)
    end
    b:SetScript("OnClick", function()
        if not b.locked then return pick() end
        if b.armed and _G.PurchaseSlot then
            b.armed = nil
            _G.PurchaseSlot()
            return
        end
        b.armed = true
        _G.C_Timer.After(3, function() b.armed = nil end)
        b:GetScript("OnEnter")(b)
    end)
    b:SetScript("OnDragStart", pick)
    b:SetScript("OnReceiveDrag", pick)
    b:SetScript("OnEnter", function(s)
        hiBag = s.bag
        V.Refresh(true)
        UI:TooltipOwner(s, "ANCHOR_TOP")
        local tip = _G.GameTooltip
        if s.locked then
            local cost = _G.GetBankSlotCost and _G.GetBankSlotCost(s.owned or 0)
            tip:SetText(T("Emplacement de sac de banque"), 1, 1, 1)
            if cost then tip:AddLine(T("Prix") .. " : " .. WK:FormatMoney(cost), 1, 1, 1) end
            tip:AddLine(s.armed and T("Clique encore pour l'acheter") or T("Deux clics pour l'acheter"), 0.8, 0.8, 0.8)
        elseif s.inv and _G.GetInventoryItemTexture("player", s.inv) then
            tip:SetInventoryItem("player", s.inv)
        else
            tip:SetText(T("Emplacement de sac vide"), 1, 1, 1)
            tip:AddLine(T("Glisse un sac ici"), 0.8, 0.8, 0.8)
        end
        tip:Show()
    end)
    b:SetScript("OnLeave", function()
        hiBag = nil
        V.Refresh(true)
        _G.GameTooltip:Hide()
    end)
    return b
end
function V.RefreshSlots()
    if not (win and win.slotBar and win.slotBar:IsShown()) then return end
    local CC = _G.C_Container
    local list = bagSlotList()
    -- emplacements de banque achetés : d'après le jeu, et au moins jusqu'au dernier qui contient déjà un sac
    -- (sur ce client, le nombre rendu par le jeu peut manquer ou être faux)
    local owned = 99
    if isBank then
        owned = 0
        local okN, n = pcall(function() return _G.GetNumBankSlots and _G.GetNumBankSlots() end)
        if okN and type(n) == "number" then owned = n end
        for i, bag in ipairs(list) do
            local inv = invOf(bag)
            local has = inv and _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", inv)
            if has then owned = math.max(owned, i) end
        end
    end
    for i, bag in ipairs(list) do
        local b = win.bagSlots[i] or slotButton(i)
        win.bagSlots[i] = b
        local tex0 = invOf(bag)
        tex0 = tex0 and _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", tex0)
        b.bag, b.inv, b.locked, b.owned = bag, invOf(bag), i > owned and not tex0, owned
        local tex = b.inv and _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", b.inv)
        b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        b.icon:SetDesaturated(b.locked)
        b.icon:SetAlpha(b.locked and 0.35 or 1)
        local n = tex and CC and CC.GetContainerNumSlots and CC.GetContainerNumSlots(bag) or 0
        b.n:SetText(n > 0 and tostring(n) or "")
        b.lock:SetShown(b.locked)
        local r, g, bl = UI:Accent()
        if hiBag == bag then b.edge:SetColor(r, g, bl, 1)
        else b.edge:SetColor(C.border[1], C.border[2], C.border[3], 1) end
        b.fill:SetColor(C.surface[1], C.surface[2], C.surface[3], 1)
        b:Show()
    end
end

function V.RefreshFiche()
    local fi = win and win.fiche
    if not (fi and fi:IsShown()) then return end
    local e = hovered
    -- l'objet survolé a pu changer de place ou partir : relu dans la liste
    if e and win.list then
        local still
        for _, x in ipairs(win.list) do if not x.empty and x.id == e.id then still = x break end end
        e = still
    end
    local has = e ~= nil
    for _, w in ipairs({ fi.icon, fi.name, fi.sub, fi.body, fi.lock, fi.ah, fi.junk }) do w:SetShown(has) end
    fi.empty:SetShown(not has)
    local PH = WK.modules.ProfHelp
    fi.de:SetShown(has and PH and PH:EnchantRank() ~= nil and e.info and (e.info.de or e.quality and e.quality >= 2)
        and (instant(e.id) == 2 or instant(e.id) == 4) or false)
    if not has then fi:SetHeight(math.ceil(fi.empty:GetStringHeight() or 30) + 28) return end
    local name, _, quality, _, _, _, _, _, _, icon, vendor = WK.GetItemInfo(e.id)
    fi.icon:SetTexture(icon or e.icon)
    fi.name:SetText(name or e.name or ("#" .. e.id))
    if quality and B.QualityColor(quality) then fi.name:SetTextColor(B.QualityColor(quality)) end
    local inBags = 0
    for _, x in ipairs(win.list or {}) do if not x.empty and x.id == e.id then inBags = inBags + (x.count or 1) end end
    local acc = WK.modules.Inventory:AccountCount(e.id) or inBags
    if e.offline then
        -- autre perso / tout le compte : où il est et combien sur le compte
        local where = e.where == "bank" and T("en banque") or e.where == "bags" and T("dans ses sacs")
            or T("sur le compte")
        fi.sub:SetText(string.format("%d %s", e.count or 1, where) .. "  ·  "
            .. string.format(T("%d sur le compte"), acc))
    else
        fi.sub:SetText(string.format(T(isBank and "%d dans ta banque  ·  %d sur le compte"
            or "%d dans tes sacs  ·  %d sur le compte"), inBags, acc))
    end
    local lines = {}
    local Val = WK.modules.Value
    local ah = Val and Val.Prices and select(1, Val:Prices(e.id))
    table.insert(lines, UI:Hex(C.muted) .. T("Prix HV") .. "|r  " .. (ah and WK:FormatMoney(ah) or "-"))
    table.insert(lines, UI:Hex(C.muted) .. T("Marchand") .. "|r  " .. WK:FormatMoney(vendor or 0))
    local Au = WK.modules.Auction
    local sold = Au and Au.SoldInfo and Au:SoldInfo(e.id)
    if sold and sold.avg then
        table.insert(lines, UI:Hex(C.muted) .. T("Tu le vends") .. "|r  " .. WK:FormatMoney(sold.avg) .. "  "
            .. UI:Hex(C.muted) .. "(" .. string.format(T("%d vendu(s)"), sold.sold)
            .. (sold.rate and (", " .. math.floor(sold.rate * 100 + 0.5) .. " %") or "") .. ")|r")
    end
    if ah and inBags > 1 then
        table.insert(lines, UI:Hex(C.muted) .. T("Valeur du lot") .. "|r  " .. WK:FormatMoney(ah * inBags))
    end
    local info = e.info or {}
    local need = {}
    if info.ship then
        table.insert(need, string.format(T("%s : %d à lui envoyer"), WK:CharName(WK.DB.global.characters[info.ship.to]
            or {}, info.ship.to), info.ship.count or 0))
    end
    local Bi = WK.modules.BiS
    if Bi and Bi.Holders then for _, h in ipairs(Bi:Holders(e.id)) do table.insert(need, T("Liste BiS : ") .. h) end end
    if info.upgrade then
        table.insert(need, string.format(T("Amélioration à porter (+%d)"), math.floor(info.upgrade + 0.5)))
    end
    if info.de then table.insert(need, T("Conseillé au désenchantement")) end
    -- ce que l'infobulle de l'addon montrait : persos, en vente, métiers, fabrication, désenchantement
    local S = WK.modules.AHScan
    local se = S and S:Entry(e.id)
    if se and se.q then
        local age = S:Age(e.id) or 0
        table.insert(lines, UI:Hex(C.muted) .. T("En vente") .. "|r  " .. se.q .. "  " .. UI:Hex(C.muted) .. "· "
            .. (age == 0 and T("aujourd'hui") or string.format(T("il y a %d j"), age)) .. "|r")
    end
    local per = {}
    for key, c in pairs(WK.DB.global.characters) do
        local n = WK.modules.Inventory:CharCount(c, e.id)
        if n > 0 then per[#per + 1] = { key = key, c = c, n = n } end
    end
    table.sort(per, function(a, b) return a.n > b.n end)
    if #per > 0 then
        local parts = {}
        for i, pp in ipairs(per) do
            if i > 4 then parts[#parts + 1] = "…" break end
            parts[#parts + 1] = UI:Hex({ UI:ClassColor(pp.c.class) }) .. WK:CharName(pp.c, pp.key) .. "|r " .. pp.n
        end
        table.insert(lines, " ")
        table.insert(lines, table.concat(parts, "  ·  "))
    end
    local col, got = collector()
    local nop = function() end
    local R, PHm = WK.modules.Recipes, WK.modules.ProfHelp
    if R and R.AddTooltip then pcall(R.AddTooltip, R, col, e.id, nop, true) end
    if R and R.AddCraftTooltip then pcall(R.AddCraftTooltip, R, col, e.id, nop) end
    if PHm and PHm.AddTooltip then pcall(PHm.AddTooltip, PHm, col, e.id, nop) end
    if #got > 0 then
        table.insert(lines, " ")
        for _, l in ipairs(got) do table.insert(lines, l) end
    end
    if #need > 0 then
        table.insert(lines, " ")
        table.insert(lines, UI:Hex(C.muted) .. UI:Upper(T("Qui en a besoin")) .. "|r")
        for _, n in ipairs(need) do table.insert(lines, n) end
    end
    fi.body:SetText(table.concat(lines, "\n"))
    local IL = WK.modules.ItemLock
    local why = IL and IL:Reason(e.id)
    fi.lock:SetLabel(why == "manual" and T("Déverrouiller") or T("Verrouiller"))
    fi.lock:SetEnabled(why == nil or why == "manual")
    local marked = PH and PH:Config().deMark[e.id]
    fi.de:SetLabel(marked and T("Ne plus forcer le DE") or T("Toujours désenchanter"))
    local ahOpen = (_G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown())
        or (_G.AuctionFrame and _G.AuctionFrame:IsShown())
    fi.ah:SetShown(ahOpen and true or false)
    -- boutons juste sous le texte ; la fiche s'arrête là (pas de grand vide jusqu'en bas)
    local bodyH = math.ceil(fi.body:GetStringHeight() or 40)
    -- camelote à la main (pas pour un gris, qui l'est toujours, ni pour un objet verrouillé)
    local Q = WK.modules.QoL
    local jm = Q and Q.JunkMarks()[e.id]
    fi.junk:SetShown(Q ~= nil and (e.quality or 0) > 0 and (why == nil or jm) and true or false)
    fi.junk:SetLabel(jm and T("Plus de la camelote") or T("Camelote"))
    -- boutons alignés : une colonne, tous de la largeur de la fiche
    local y = 60 + bodyH + 14
    local bw = FICHE_W - 20
    local St = WK.modules.Stash
    local rule = St and St.ItemRule and St:ItemRule(e.id)
    local chars = WK.DB.global.characters
    local dl = T("Destination : automatique")
    if rule and rule.never then dl = T("Destination : ne bouge jamais")
    elseif rule and rule.ah then dl = T("Destination : toujours à l'HV")
    elseif rule and rule.to then
        local c = chars[rule.to]
        dl = string.format(T("Destination : toujours » %s"), c and WK:CharName(c, rule.to) or rule.to)
    end
    fi.dest:SetLabel(dl)
    fi.dest:SetShown(St ~= nil and why ~= "manual")
    for _, b in ipairs({ fi.lock, fi.de, fi.junk, fi.dest, fi.ah }) do
        if b:IsShown() then
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 10, -y); b:SetWidth(bw)
            y = y + 30
        end
    end
    local h = y - 6 + 12
    -- fiche plus haute que la fenêtre : la fenêtre s'allonge (elle reprend sa taille au rafraîchissement)
    local th = 110 + topOff() + ((win.who and fi:IsShown()) and 34 or 0)
    if h > win:GetHeight() - th and not inCombat() then win:SetHeight(h + th) end
    fi:SetHeight(h)
end

-- Vendre la camelote (marchand ouvert) : objets gris non verrouillés, revérifiés juste avant chaque vente
function V.SellJunk()
    local Q = WK.modules.QoL
    if not (Q and _G.MerchantFrame and _G.MerchantFrame:IsShown()) or inCombat() then return end
    local list = Q:GreyItems()
    local i = 0
    local function step()
        for _ = 1, 8 do
            i = i + 1
            local it = list[i]
            if not it then V.Refresh() return end
            if Q.StillGrey(it) then
                local CC = _G.C_Container
                if CC and CC.UseContainerItem then CC.UseContainerItem(it.bag, it.slot)
                elseif _G.UseContainerItem then _G.UseContainerItem(it.bag, it.slot) end
            end
        end
        _G.C_Timer.After(0.25, step)
    end
    step()
end

-- Vendre les inutiles (marchand ouvert) : objets « au marchand » du Rangement, jamais un verrouillé ni plus que prévu
function V.SellUnneeded()
    local St, IL = WK.modules.Stash, WK.modules.ItemLock
    if not (St and _G.MerchantFrame and _G.MerchantFrame:IsShown()) or inCombat() then return end
    local want = {}
    for _, e in ipairs(St:MyVendorItems()) do
        if not (IL and IL.Reason and IL:Reason(e.id)) then want[e.id] = e.count end
    end
    local jobs = {}
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        for slot = 1, (WK.Container.NumSlots(bag) or 0) do
            local id, n, locked = WK.Container.Info(bag, slot)
            if id and not locked and want[id] and want[id] >= (n or 1) then
                want[id] = want[id] - (n or 1)
                jobs[#jobs + 1] = { bag = bag, slot = slot, id = id }
            end
        end
    end
    local i = 0
    local function step()
        if not (_G.MerchantFrame and _G.MerchantFrame:IsShown()) or inCombat() then return end
        for _ = 1, 6 do
            i = i + 1
            local j = jobs[i]
            if not j then St:Invalidate(); V.Refresh() return end
            if WK.Container.Info(j.bag, j.slot) == j.id then
                local CC = _G.C_Container
                if CC and CC.UseContainerItem then CC.UseContainerItem(j.bag, j.slot)
                elseif _G.UseContainerItem then _G.UseContainerItem(j.bag, j.slot) end
            end
        end
        _G.C_Timer.After(0.25, step)
    end
    step()
end

function V.Win() return win end
function V.Pending() return pending end
function V.Ensure() win = win or build(); return win end
return V
end

-- Monnaies : tableau en bas de la page Persos, dans la fenêtre principale
function B.OpenMoney()
    if not WK:PageOn("characters") then return end
    UI:Create():Show()
    UI:ShowPage("characters")
    local cp = UI.pages.characters
    if cp and cp.ScrollToMoney then cp:ScrollToMoney() end
end

---------------------------------------------------------------------------
-- Les deux fenêtres : sacs du perso (Bags) et banque (UI.Bank)
---------------------------------------------------------------------------
local BV = makeView("bags")
local KV = makeView("bank")
B.Refresh, B.RefreshFiche, B.SellJunk, B.Layout = BV.Refresh, BV.RefreshFiche, BV.SellJunk, BV.Layout
-- perso regardé dans nos sacs (nil = moi, clé d'un perso, « all » = tout le compte) ; pour les tests et les liens
function B.SetView(key) BV.viewKey = key; BV.Refresh() end
UI.Bank = KV
local function bankOn() return enabled() and B.Config().bankWin ~= false end
B.BankOn = bankOn

---------------------------------------------------------------------------
-- Sacs du jeu : posés dans un cadre caché, notre fenêtre suit leur état
---------------------------------------------------------------------------
local hider
-- fenêtre du jeu choisie à la place de la nôtre (jusqu'au retour par le bouton « Warband Keeper » ou au /reload)
local gameMode = { bags = false, bank = false }
local GAME_BAGS = { "ContainerFrameCombinedBags" }
for i = 1, 13 do GAME_BAGS[#GAME_BAGS + 1] = "ContainerFrame" .. i end
-- sac du joueur (sac à dos et sacs 1 à 4, ou la vue combinée) ; les cadres des sacs de banque ont un autre ID
local function isPlayerBag(fr, n)
    if n == "ContainerFrameCombinedBags" then return true end
    local id = fr.GetID and fr:GetID() or 0
    return id >= 0 and id <= (_G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4)
end
gameOpen = function()
    for _, n in ipairs(GAME_BAGS) do
        local fr = _G[n]
        if fr and fr:IsShown() and isPlayerBag(fr, n) then return true end
    end
    return false
end
local syncQueued = false
local function sync()
    syncQueued = false
    local w = BV.Win()
    if not w then return end
    if gameOpen() and not gameMode.bags then
        if not w:IsShown() then w:Show(); BV.Refresh() end
    elseif w:IsShown() then
        w:Hide()
    end
    if B.PlaceBack then B.PlaceBack() end
end
local function soonSync()
    if syncQueued then return end
    syncQueued = true
    _G.C_Timer.After(0, sync)
end
-- un cadre posé dans le cadre caché ne déclenche plus OnShow : on suit ses Show / Hide directement
local function watch(fr, n)
    local function placed()
        -- sacs de banque (mêmes cadres réutilisés) : cachés aussi quand notre banque les montre, sinon rendus au jeu
        local ours
        if isPlayerBag(fr, n) then ours = not gameMode.bags else ours = bankOn() and not gameMode.bank end
        local want = ours and hider or _G.UIParent
        if fr:GetParent() ~= want then fr:SetParent(want) end
    end
    _G.hooksecurefunc(fr, "Show", function() placed(); soonSync() end)
    _G.hooksecurefunc(fr, "Hide", function() soonSync() end)
    if fr.SetShown then _G.hooksecurefunc(fr, "SetShown", function() placed(); soonSync() end) end
end

-- Banque du jeu : sa fenêtre doit rester ouverte (la fermer ferme la banque) ; rendue invisible et minuscule
-- tant que la nôtre est là, rétablie si notre banque est coupée
local function hideGameBank(on)
    local bf = _G.BankFrame
    if not bf then return end
    if on then
        bf.wkScale = bf.wkScale or bf:GetScale()
        bf:SetAlpha(0); bf:SetScale(0.001)
    elseif bf.wkScale then
        bf:SetAlpha(1); bf:SetScale(bf.wkScale); bf.wkScale = nil
    end
end

local function takeOver()
    if not enabled() or hider then return end
    hider = _G.CreateFrame("Frame", nil, _G.UIParent)
    hider:Hide()
    BV.Ensure()
    for _, n in ipairs(GAME_BAGS) do
        local fr = _G[n]
        if fr then
            if isPlayerBag(fr, n) then fr:SetParent(hider) end
            watch(fr, n)
        end
    end
    soonSync()
end
B.TakeOver = takeOver
-- ouverture directe (tests, /wk sacs)
function B.Open()
    local w = BV.Ensure()
    w:Show()
    BV.Refresh()
    return w
end
-- notre banque (tests ; sinon ouverte avec la banque du jeu)
function B.OpenBank()
    local w = KV.Ensure()
    w:Show()
    KV.Refresh()
    return w
end

-- Bouton « Warband Keeper » posé au-dessus de la fenêtre du jeu (sacs ou banque) pour revenir à la nôtre
local backBtns = {}
local function backBtn(which)
    if backBtns[which] then return backBtns[which] end
    local b = UI:Button(_G.UIParent, "Warband Keeper", nil, 24, "primary", which == "bank" and "safe" or "bag")
    b:SetFrameStrata("HIGH")
    b:SetScript("OnClick", function() B.UseGame(which, false) end)
    b:Hide()
    backBtns[which] = b
    return b
end
function B.PlaceBack()
    local b = backBtns.bags
    if gameMode.bags then
        b = backBtn("bags")
        local host
        for _, n in ipairs(GAME_BAGS) do
            local fr = _G[n]
            if fr and fr:IsVisible() and isPlayerBag(fr, n) then host = fr break end
        end
        b:ClearAllPoints()
        if host then b:SetPoint("BOTTOMRIGHT", host, "TOPRIGHT", 0, 4) end
        b:SetShown(host ~= nil)
    elseif b then b:Hide() end
    local k = backBtns.bank
    local bf = _G.BankFrame
    if gameMode.bank and bf and bf:IsShown() then
        k = backBtn("bank")
        k:ClearAllPoints(); k:SetPoint("BOTTOMRIGHT", bf, "TOPRIGHT", 0, 4)
        k:Show()
    elseif k then k:Hide() end
end
-- which = "bags" ou "bank" ; on = true : fenêtre du jeu, false : la nôtre
function B.UseGame(which, on)
    if inCombat() then return end
    gameMode[which] = on and true or false
    if which == "bags" then
        for _, n in ipairs(GAME_BAGS) do
            local fr = _G[n]
            if fr and isPlayerBag(fr, n) and hider then fr:SetParent(on and _G.UIParent or hider) end
        end
        soonSync()
    else
        for _, n in ipairs(GAME_BAGS) do
            local fr = _G[n]
            if fr and not isPlayerBag(fr, n) and fr:IsShown() then
                fr:SetParent(on and _G.UIParent or hider or _G.UIParent)
            end
        end
        local bankOpen = _G.BankFrame and _G.BankFrame:IsShown()
        if on then
            hideGameBank(false)
            local w = KV.Win()
            if w then w:Hide() end
        elseif bankOpen then
            hideGameBank(true)
            B.OpenBank()
        end
    end
    B.PlaceBack()
end
WK:On("BANKFRAME_CLOSED", function() if B.PlaceBack then B.PlaceBack() end end)

WK:On("PLAYER_LOGIN", function() if not inCombat() then takeOver() end end)
WK:On("PLAYER_REGEN_ENABLED", function()
    if not hider then takeOver() end
    if BV.Pending() then BV.Refresh() end
    if KV.Pending() then KV.Refresh() end
end)
WK:On("BANKFRAME_OPENED", function()
    if gameMode.bank then _G.C_Timer.After(0, B.PlaceBack) return end
    if not bankOn() or inCombat() then return end
    hideGameBank(true)
    B.OpenBank()
end)
WK:On("BANKFRAME_CLOSED", function()
    local w = KV.Win()
    if w and w:IsShown() then w:Hide() end
end)
-- contenu changé : un seul rafraîchissement regroupé par fenêtre ouverte
local queued = false
local function soon()
    if queued then return end
    local bw, kw = BV.Win(), KV.Win()
    if not ((bw and bw:IsShown()) or (kw and kw:IsShown())) then return end
    queued = true
    _G.C_Timer.After(0.15, function()
        queued = false
        local b2, k2 = BV.Win(), KV.Win()
        if b2 and b2:IsShown() then BV.Refresh() end
        if k2 and k2:IsShown() then KV.Refresh() end
    end)
end
-- prise en main et recharges : repeindre les cases seulement (tout refaire seulement si un objet a bougé)
local repaintQueued = false
local function repaintSoon()
    if repaintQueued then return end
    repaintQueued = true
    _G.C_Timer.After(0.05, function()
        repaintQueued = false
        for _, v in ipairs({ BV, KV }) do
            local w = v.Win()
            if w and w:IsShown() and not v.Repaint() then soon() end
        end
    end)
end
WK:On("ITEM_LOCK_CHANGED", repaintSoon)
WK:On("BAG_UPDATE_COOLDOWN", repaintSoon)
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_MONEY", "BAG_NEW_ITEMS_UPDATED", "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED", "PLAYERBANKSLOTS_CHANGED", "PLAYERBANKBAGSLOTS_CHANGED", "BAG_CONTAINER_UPDATE",
    -- fenêtres où le clic droit fait autre chose : la couche « ouvrir le paquet » se retire ou revient
    "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "BANKFRAME_OPENED", "BANKFRAME_CLOSED" }) do
    WK:On(ev, soon)
end
