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
local COLS, SLOT, GAP, PAD = 10, 38, 5, 14
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

---------------------------------------------------------------------------
-- Classement d'un objet
---------------------------------------------------------------------------
local CATS = {
    { key = "new", label = "Nouveaux", color = "positive" },
    { key = "equip", label = "Équipement" },
    { key = "mine", label = "Composants de tes métiers" },
    { key = "ship", label = "Pour d'autres persos", color = "accent" },
    { key = "cons", label = "Consommables" },
    { key = "quest", label = "Quête", color = "gold" },
    { key = "other", label = "Divers" },
    { key = "junk", label = "Camelote", color = "muted" },
}
local REAGENT_CLASS = { [3] = true, [5] = true, [7] = true, [9] = true }

local function instant(id)
    local f = _G.C_Item and _G.C_Item.GetItemInfoInstant or _G.GetItemInfoInstant
    if not f then return nil end
    local ok, _, _, _, _, _, classID = pcall(f, id)
    return ok and classID or nil
end
local function isNew(bag, slot)
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
    elseif q == 0 then info.cat = "junk"
    elseif ship then info.cat = "ship"
    elseif classID == 2 or classID == 4 then info.cat = "equip"
    elseif classID and REAGENT_CLASS[classID] then info.cat = "mine"
    elseif classID == 0 then info.cat = "cons"
    else info.cat = "other" end
    -- pastille (une seule, la plus utile)
    if info.cat == "new" then info.badge, info.badgeCol = T("NEUF"), C.positive end
    if info.upgrade then info.badge, info.badgeCol = "+" .. math.floor(info.upgrade + 0.5), C.positive
    elseif info.bis == "mine" then info.badge, info.badgeCol = T("BiS"), C.gold
    elseif info.de then info.badge, info.badgeCol = T("DE"), C.plan
    elseif ship then info.badge, info.badgeCol = shortName(ship.to), nil
    elseif questItem then info.badge, info.badgeCol = "Q", C.gold end
    return info
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------
local win
local holders, buttons = {}, {}   -- holders[bag] ; buttons[bag][slot]
local pending = false
local filter, query = "all", ""
local hovered
local gameOpen -- plus bas (sacs du jeu)

local function holderOf(bag)
    if holders[bag] then return holders[bag] end
    local h = _G.CreateFrame("Frame", nil, win.content)
    h:SetID(bag)
    h:SetAllPoints(win.content)
    holders[bag] = h
    return h
end
local function newButton(bag, slot)
    local h = holderOf(bag)
    local name = string.format("WarbandKeeperBagItem%d_%d", bag + 1, slot)
    local ok, b = pcall(_G.CreateFrame, "ItemButton", name, h, "ContainerFrameItemButtonTemplate")
    if not ok or not b then b = _G.CreateFrame("Button", name, h, "ContainerFrameItemButtonTemplate") end
    b:SetID(slot)
    b:SetSize(SLOT, SLOT)
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
    b:HookScript("OnEnter", function(s) if s.wkEntry then hovered = s.wkEntry; B.RefreshFiche() end end)
    buttons[bag] = buttons[bag] or {}
    buttons[bag][slot] = b
    return b
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
local function paintButton(b, e)
    local icon = region(b, "icon", "Icon", "IconTexture")
    if icon and icon.SetTexture then icon:SetTexture(e and e.icon or nil) end
    local cnt = region(b, "Count")
    if cnt and cnt.SetText then
        if e and (e.count or 1) > 1 then cnt:SetText(e.count); cnt:Show() else cnt:SetText(""); cnt:Hide() end
    end
    if _G.SetItemButtonQuality then pcall(_G.SetItemButtonQuality, b, e and e.quality, e and e.link) end
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
        tag.t:SetText(info.badge)
        tag:SetWidth(math.max(14, (tag.t:GetStringWidth() or 10) + 8))
        tag:Show()
    else tag:Hide() end
    b.wkEntry = e
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

local function readBags()
    local list, free, total = {}, 0, 0
    local ctx = context()
    for _, bag in ipairs(WK.modules.Inventory:BagList()) do
        local n = WK.Container.NumSlots(bag) or 0
        total = total + n
        for slot = 1, n do
            local id, count, locked = WK.Container.Info(bag, slot)
            if id then
                local name, link, quality, _, _, _, _, _, _, icon = WK.GetItemInfo(id)
                local cl = _G.C_Container and _G.C_Container.GetContainerItemLink
                local slink = cl and cl(bag, slot) or link
                local e = { bag = bag, slot = slot, id = id, count = count, locked = locked, name = name,
                    link = slink, quality = quality, icon = icon or (_G.C_Item and _G.C_Item.GetItemIconByID and
                    _G.C_Item.GetItemIconByID(id)) }
                e.new = isNew(bag, slot)
                e.info = classify(e, ctx)
                list[#list + 1] = e
            else
                free = free + 1
                list[#list + 1] = { bag = bag, slot = slot, empty = true }
            end
        end
    end
    return list, free, total
end

local function chip(parent, key, label)
    local b = UI:Button(parent, label, nil, 22, "ghost")
    b.key = key
    b:SetScript("OnClick", function() filter = (filter == key and key ~= "all") and "all" or key; B.Refresh() end)
    return b
end

local function build()
    local f = _G.CreateFrame("Frame", "WarbandKeeperBags", _G.UIParent)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local p, _, rp, x, y = s:GetPoint()
        B.Config().pos = { p, rp, x, y }
    end)
    UI:HudBackground(f, "window", 12)
    local pos = B.Config().pos
    if pos then f:SetPoint(pos[1], _G.UIParent, pos[2], pos[3], pos[4]) else f:SetPoint("BOTTOMRIGHT", -80, 120) end
    -- en-tête
    f.title = UI:Text(f, 14); f.title:SetPoint("TOPLEFT", PAD, -12); f.title:SetText(T("Sacs"))
    f.sub = UI:Text(f, 11, C.muted); f.sub:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
    f.close = UI:IconButton(f, "close", 18); f.close:SetPoint("TOPRIGHT", -10, -10)
    -- fermer = fermer les sacs du jeu (notre fenêtre suit) ; Échap passe aussi par eux
    f.close:SetScript("OnClick", function()
        if _G.CloseAllBags then _G.CloseAllBags() end
        _G.C_Timer.After(0.05, function() if f:IsShown() and not gameOpen() then f:Hide() end end)
    end)
    f.search = UI:Input(f, 170, 24, "Rechercher...", "search")
    f.search:SetPoint("RIGHT", f.close, "LEFT", -8, 0)
    f.search.onChange = function(t) query = (t or ""):lower(); B.Refresh(true) end
    -- filtres
    f.chips = {}
    local prev
    for _, c in ipairs({ { "all", "Tout" }, { "new", "Nouveaux" }, { "ship", "À ranger" }, { "sell", "À vendre" },
        { "de", "Désenchanter" }, { "up", "Améliorations" } }) do
        local b = chip(f, c[1], c[2])
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", PAD - 4, -38) end
        f.chips[#f.chips + 1] = b
        prev = b
    end
    -- contenu (défilant si les sacs sont grands)
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", PAD, -70)
    f.content = f.scroll.child
    f.heads = {}
    -- pied
    f.foot = UI:Text(f, 11, C.muted); f.foot:SetPoint("BOTTOMLEFT", PAD, 12)
    f.sell = UI:Button(f, "Vendre la camelote", nil, 22, "secondary")
    f.sell:SetPoint("BOTTOMRIGHT", -(PAD + (B.Config().fiche and FICHE_W + 10 or 0)), 9)
    f.sell:SetScript("OnClick", function() B.SellJunk() end)
    -- fiche de l'objet survolé (maquette B)
    local fi = _G.CreateFrame("Frame", nil, f)
    fi:SetPoint("TOPRIGHT", -PAD, -70); fi:SetPoint("BOTTOMRIGHT", -PAD, 40); fi:SetWidth(FICHE_W)
    UI:Panel(fi, 10, C.surface, C.border)
    fi.icon = fi:CreateTexture(nil, "ARTWORK"); fi.icon:SetSize(36, 36); fi.icon:SetPoint("TOPLEFT", 12, -12)
    fi.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    fi.name = UI:Text(fi, 13); fi.name:SetPoint("TOPLEFT", 56, -12); fi.name:SetPoint("TOPRIGHT", -10, -12)
    fi.name:SetJustifyH("LEFT")
    fi.sub = UI:Text(fi, 10, C.muted); fi.sub:SetPoint("TOPLEFT", 56, -32); fi.sub:SetPoint("TOPRIGHT", -10, -32)
    fi.sub:SetJustifyH("LEFT")
    fi.body = UI:Text(fi, 11); fi.body:SetPoint("TOPLEFT", 12, -60); fi.body:SetPoint("TOPRIGHT", -12, -60)
    fi.body:SetJustifyH("LEFT"); fi.body:SetJustifyV("TOP")
    if fi.body.SetWordWrap then fi.body:SetWordWrap(true) end
    if fi.body.SetSpacing then fi.body:SetSpacing(4) end
    fi.lock = UI:Button(fi, "Verrouiller", nil, 24, "secondary")
    fi.lock:SetPoint("BOTTOMLEFT", 10, 10)
    fi.lock:SetScript("OnClick", function()
        if hovered and hovered.id then WK.modules.ItemLock:Toggle(hovered.id); B.Refresh() end
    end)
    fi.de = UI:Button(fi, "Toujours désenchanter", nil, 24, "secondary")
    fi.de:SetPoint("BOTTOMLEFT", fi.lock, "TOPLEFT", 0, 6)
    fi.de:SetScript("OnClick", function()
        if hovered and hovered.id then WK.modules.ProfHelp:ToggleDEMark(hovered.id); B.Refresh() end
    end)
    fi.ah = UI:Button(fi, "Chercher à l'HV", nil, 24, "secondary")
    fi.ah:SetPoint("LEFT", fi.lock, "RIGHT", 6, 0)
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
function B.Refresh(light)
    if not win or not win:IsShown() then return end
    local list, free, total = readBags()
    win.list = list
    win.sub:SetText(string.format(T("%d / %d places"), total - free, total))
    for _, b in ipairs(win.chips) do b:SetStyle(b.key == filter and "primary" or "ghost") end
    -- money / pied
    local money = _G.GetMoney and _G.GetMoney() or 0
    win.foot:SetText(string.format(T("%d places libres  ·  %s"), free, WK:FormatMoney(money)))
    local junk = 0
    for _, e in ipairs(list) do if not e.empty and e.info.cat == "junk" then junk = junk + 1 end end
    local merchant = _G.MerchantFrame and _G.MerchantFrame:IsShown()
    win.sell:SetShown(merchant and junk > 0)
    -- disposition : par catégorie, cases vides à la fin
    if inCombat() then
        pending = true
        for _, e in ipairs(list) do
            local b = buttons[e.bag] and buttons[e.bag][e.slot]
            if b then paintButton(b, not e.empty and e or nil); b:SetAlpha((e.empty or matches(e)) and 1 or 0.25) end
        end
        return
    end
    pending = false
    local groups = {}
    for _, c in ipairs(CATS) do groups[c.key] = {} end
    local empties = {}
    for _, e in ipairs(list) do
        if e.empty then empties[#empties + 1] = e else table.insert(groups[e.info.cat], e) end
    end
    for _, g in pairs(groups) do
        table.sort(g, function(a, b)
            if (a.quality or 0) ~= (b.quality or 0) then return (a.quality or 0) > (b.quality or 0) end
            if (a.name or "") ~= (b.name or "") then return (a.name or "") < (b.name or "") end
            return (a.count or 0) > (b.count or 0)
        end)
    end
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
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetWidth(COLS * (SLOT + GAP) - GAP)
        h.t:SetText(UI:Upper(T(label)))
        local cc = col == "accent" and { UI:Accent() } or C[col or "muted"] or C.muted
        h.t:SetTextColor(cc[1], cc[2], cc[3])
        h.m:SetText(meta or "")
        h.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        h:Show()
        y = y + 22
    end
    local function place(items)
        for i, e in ipairs(items) do
            local b = (buttons[e.bag] and buttons[e.bag][e.slot]) or newButton(e.bag, e.slot)
            local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", win.content, "TOPLEFT", col * (SLOT + GAP), -(y + row * (SLOT + GAP)))
            paintButton(b, not e.empty and e or nil)
            b:SetAlpha((e.empty or matches(e)) and 1 or 0.25)
            b:Show()
            used[b] = true
        end
        if #items > 0 then y = y + math.ceil(#items / COLS) * (SLOT + GAP) + 8 end
    end
    for _, c in ipairs(CATS) do
        local g = groups[c.key]
        if #g > 0 then
            local meta = tostring(#g)
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
    for i = hi + 1, #win.heads do win.heads[i]:Hide() end
    -- cases d'un sac retiré : cachées
    for _, byBag in pairs(buttons) do for _, b in pairs(byBag) do if not used[b] then b:Hide() end end end
    -- tailles : la grille fixe la largeur ; la hauteur suit, bornée à 75 % de l'écran (puis défilement)
    local gridW = COLS * (SLOT + GAP) - GAP
    win.content:SetWidth(gridW)
    win.scroll:SetContentHeight(y)
    local ficheW = B.Config().fiche and (FICHE_W + 10) or 0
    local maxH = math.floor((_G.UIParent:GetHeight() or 900) * 0.75)
    local h = math.min(maxH, y + 70 + 40)
    win:SetSize(PAD * 2 + gridW + 14 + ficheW, math.max(320, h))
    win.scroll:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -(PAD + ficheW), 40)
    if not light then B.RefreshFiche() end
end

function B.RefreshFiche()
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
    for _, w in ipairs({ fi.icon, fi.name, fi.sub, fi.body, fi.lock, fi.ah }) do w:SetShown(has) end
    fi.empty:SetShown(not has)
    local PH = WK.modules.ProfHelp
    fi.de:SetShown(has and PH and PH:EnchantRank() ~= nil and e.info and (e.info.de or e.quality and e.quality >= 2)
        and (instant(e.id) == 2 or instant(e.id) == 4) or false)
    if not has then return end
    local name, _, quality, _, _, _, _, _, _, icon, vendor = WK.GetItemInfo(e.id)
    fi.icon:SetTexture(icon or e.icon)
    fi.name:SetText(name or e.name or ("#" .. e.id))
    if quality and _G.GetItemQualityColor then fi.name:SetTextColor(_G.GetItemQualityColor(quality)) end
    local inBags = 0
    for _, x in ipairs(win.list or {}) do if not x.empty and x.id == e.id then inBags = inBags + (x.count or 1) end end
    local acc = WK.modules.Inventory:AccountCount(e.id) or inBags
    fi.sub:SetText(string.format(T("%d dans tes sacs  ·  %d sur le compte"), inBags, acc))
    local lines = {}
    local V = WK.modules.Value
    local ah = V and V.Prices and select(1, V:Prices(e.id))
    table.insert(lines, UI:Hex(C.muted) .. T("Prix HV") .. "|r  " .. (ah and WK:FormatMoney(ah) or "-"))
    table.insert(lines, UI:Hex(C.muted) .. T("Marchand") .. "|r  " .. WK:FormatMoney(vendor or 0))
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
end

-- Vendre la camelote (marchand ouvert) : objets gris non verrouillés, revérifiés juste avant chaque vente
function B.SellJunk()
    local Q = WK.modules.QoL
    if not (Q and _G.MerchantFrame and _G.MerchantFrame:IsShown()) or inCombat() then return end
    local list = Q:GreyItems()
    local i = 0
    local function step()
        for _ = 1, 8 do
            i = i + 1
            local it = list[i]
            if not it then B.Refresh() return end
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

---------------------------------------------------------------------------
-- Sacs du jeu : posés dans un cadre caché, notre fenêtre suit leur état
---------------------------------------------------------------------------
local hider
local GAME_BAGS = { "ContainerFrameCombinedBags" }
for i = 1, 13 do GAME_BAGS[#GAME_BAGS + 1] = "ContainerFrame" .. i end
-- sac du joueur (sac à dos et sacs 1 à 4, ou la vue combinée) ; les cadres des sacs de banque ont un autre ID
local function isPlayerBag(fr, n)
    if n == "ContainerFrameCombinedBags" then return true end
    local id = fr.GetID and fr:GetID() or 0
    return id >= 0 and id <= 4
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
    if not win then return end
    if gameOpen() then
        if not win:IsShown() then win:Show(); B.Refresh() end
    elseif win:IsShown() then
        win:Hide()
    end
end
local function soonSync()
    if syncQueued then return end
    syncQueued = true
    _G.C_Timer.After(0, sync)
end
-- un cadre posé dans le cadre caché ne déclenche plus OnShow : on suit ses Show / Hide directement
local function watch(fr, n)
    local function placed()
        -- sacs de banque (même cadres réutilisés) : rendus au jeu pour qu'ils restent visibles
        local want = isPlayerBag(fr, n) and hider or _G.UIParent
        if fr:GetParent() ~= want then fr:SetParent(want) end
    end
    _G.hooksecurefunc(fr, "Show", function() placed(); soonSync() end)
    _G.hooksecurefunc(fr, "Hide", function() soonSync() end)
    if fr.SetShown then _G.hooksecurefunc(fr, "SetShown", function() placed(); soonSync() end) end
end
local function takeOver()
    if not enabled() or hider then return end
    hider = _G.CreateFrame("Frame", nil, _G.UIParent)
    hider:Hide()
    win = win or build()
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
    win = win or build()
    win:Show()
    B.Refresh()
    return win
end

WK:On("PLAYER_LOGIN", function() if not inCombat() then takeOver() end end)
WK:On("PLAYER_REGEN_ENABLED", function()
    if not hider then takeOver() end
    if pending then B.Refresh() end
end)
-- contenu changé : un seul rafraîchissement regroupé
local queued = false
local function soon()
    if queued or not (win and win:IsShown()) then return end
    queued = true
    _G.C_Timer.After(0.15, function() queued = false; B.Refresh() end)
end
for _, ev in ipairs({ "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "PLAYER_MONEY", "BAG_NEW_ITEMS_UPDATED", "AUCTION_HOUSE_SHOW",
    "AUCTION_HOUSE_CLOSED" }) do
    WK:On(ev, soon)
end
