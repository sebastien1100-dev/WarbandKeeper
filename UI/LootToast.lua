local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local GetTime, C_Timer, C_Item, UIParent, wipe = _G.GetTime, _G.C_Timer, _G.C_Item, _G.UIParent, _G.wipe

-- Butin à l'écran (maquette A avec le grand encadré de C) :
--   * pile de petits encadrés (HUD « lootToast ») : un par objet ramassé, bord et liseré à la couleur de la rareté,
--     quantité, prix du lot (scan HV, sinon marchand), ligne utile (prix à l'unité, nombre en sacs, camelote) et
--     étiquettes (amélioration, BiS, envie, quête, recette) ; le plus récent en haut, DUR secondes chacun, le
--     survol les garde ; le même objet ramassé de suite se cumule ;
--   * grand encadré (HUD « lootToastBig ») pour un butin notable : rareté >= bigQuality, lot >= bigValue, BiS du
--     perso ou objet d'envie ; halo à la couleur de la rareté, son, BIG_DUR secondes.
-- Messages « Vous recevez le butin » du perso (CHAT_MSG_LOOT, formats du jeu LOOT_ITEM_SELF…).
-- Réglages WK.DB.global.lootToast (carte « Butin à l'écran » de la roue de la page Filtre de loot).
local MAXN, W, H, GAPY = 6, 300, 48, 6
local BIG_W, BIG_H = 380, 76

local DEFAULTS = { enabled = true, minQuality = 1, duration = 4, bigQuality = 3, bigValue = 0, bigDuration = 6,
    sound = true }
function UI.LootToastConfig()
    local g = WK.DB.global
    g.lootToast = g.lootToast or {}
    local c = g.lootToast
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = v end end
    return c
end
local function cfg() return UI.LootToastConfig() end
local function on() return cfg().enabled and WK:FeatureOn("loot") end

local function qcolor(q)
    local col = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q or 1]
    if col then return { col.r, col.g, col.b } end
    return { 1, 1, 1 }
end

-- Ce qu'on sait de l'objet : nom, rareté, icône, prix, ligne utile, étiquettes, notable ou non
local function describe(id, link, qty)
    local name, _, q, ilvl, _, itype, isub, _, _, icon, _, classID = WK.GetItemInfo(link or id)
    if not name then return nil end
    local V = WK.modules.Value
    local unit, src = 0, nil
    if V then unit, src = V:Price(id) end
    unit = unit or 0
    local e = { id = id, link = link, name = name, q = q or 1, icon = icon, qty = qty, unit = unit, src = src,
        value = unit * qty }
    -- ligne utile
    local bits = {}
    if (q or 1) == 0 then bits[#bits + 1] = T("camelote") end
    if classID == 2 or classID == 4 then
        if ilvl and ilvl > 1 then bits[#bits + 1] = string.format(T("niv. %d"), ilvl) end
        if isub then bits[#bits + 1] = isub end
    elseif qty > 1 and unit > 0 then
        bits[#bits + 1] = string.format(T("%s l'unité"), UI:PlainMoney(unit))
    end
    local count = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id))
        or (_G.GetItemCount and _G.GetItemCount(id))
    if count and count > qty and classID ~= 2 and classID ~= 4 then
        bits[#bits + 1] = string.format(T("%d en sacs"), count)
    end
    if #bits == 0 and itype then bits[#bits + 1] = itype end
    e.sub = table.concat(bits, "  ·  ")
    -- étiquettes
    local tags = {}
    local BH = WK.modules.BagHelp
    if BH and BH.Upgrade and link then
        local ok, slot, gain = pcall(BH.Upgrade, BH, link)
        if ok and slot and gain and gain > 0 then
            tags[#tags + 1] = UI:Hex(C.positive) .. string.format(T("Amélioration +%d"), math.floor(gain + 0.5)) .. "|r"
        end
    end
    local B = WK.modules.BiS
    local mark = B and B.Mark and B:Mark(id)
    if mark == "mine" then tags[#tags + 1] = UI:Hex(C.gold) .. T("BiS") .. "|r"; e.bis = true
    elseif mark == "other" then tags[#tags + 1] = UI:Hex(C.silver or C.muted) .. T("BiS d'un autre perso") .. "|r" end
    local D = WK.modules.Dungeons
    if D and D.IsWished and D:IsWished(id) then
        tags[#tags + 1] = UI:Hex({ UI:Accent() }) .. T("Envie") .. "|r"; e.wish = true
    end
    if classID == 12 then tags[#tags + 1] = UI:Hex(C.warning) .. T("Quête") .. "|r" end
    if classID == 9 then tags[#tags + 1] = UI:Hex(C.info) .. T("Recette") .. "|r" end
    e.tags = table.concat(tags, "  ")
    local c = cfg()
    e.big = ((c.bigQuality or 3) < 9 and (q or 1) >= (c.bigQuality or 3))
        or ((c.bigValue or 0) > 0 and e.value >= c.bigValue) or e.bis or e.wish or false
    return e
end

local function priceText(e)
    if e.value > 0 then return UI:GoldText(e.value), e.src == "ah" and T("HV") or T("marchand") end
    return UI:Hex(C.dim) .. "-|r", T("pas de prix")
end

---------------------------------------------------------------------------
-- Pile de petits encadrés
---------------------------------------------------------------------------
local stack, big
local toasts = {}

local function newToast(parent)
    local t = _G.CreateFrame("Button", nil, parent)
    t:SetSize(W, H)
    t.edge = UI:Rounded(t, 10, 0, "BACKGROUND", 1)
    t.bg = UI:Rounded(t, 9, 1, "BACKGROUND", 2)
    t.stripe = t:CreateTexture(nil, "ARTWORK")
    t.stripe:SetPoint("TOPLEFT", 1, -6); t.stripe:SetPoint("BOTTOMLEFT", 1, 6); t.stripe:SetWidth(3)
    t.iconEdge = t:CreateTexture(nil, "ARTWORK")
    t.iconEdge:SetSize(34, 34); t.iconEdge:SetPoint("LEFT", 10, 0)
    t.icon = t:CreateTexture(nil, "OVERLAY")
    t.icon:SetPoint("TOPLEFT", t.iconEdge, "TOPLEFT", 2, -2)
    t.icon:SetPoint("BOTTOMRIGHT", t.iconEdge, "BOTTOMRIGHT", -2, 2)
    t.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    t.price = UI:Text(t, 12, C.gold); t.price:SetPoint("TOPRIGHT", -10, -9); t.price:SetJustifyH("RIGHT")
    t.src = UI:Text(t, 10, C.muted); t.src:SetPoint("TOPRIGHT", t.price, "BOTTOMRIGHT", 0, -3)
    t.src:SetJustifyH("RIGHT")
    t.name = UI:Text(t, 12); t.name:SetPoint("TOPLEFT", 52, -9); t.name:SetPoint("RIGHT", t.price, "LEFT", -8, 0)
    t.sub = UI:Text(t, 10, C.muted); t.sub:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -4)
    t.sub:SetPoint("RIGHT", t.price, "LEFT", -8, 0)
    t:SetScript("OnEnter", function(s)
        s.hover = true
        if not s.e then return end
        UI:TooltipOwner(s, "ANCHOR_LEFT")
        if s.e.link then _G.GameTooltip:SetHyperlink(s.e.link)
        elseif _G.GameTooltip.SetItemByID then _G.GameTooltip:SetItemByID(s.e.id) end
        _G.GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(s) s.hover = false; _G.GameTooltip:Hide() end)
    t:SetScript("OnClick", function(s)
        if _G.IsShiftKeyDown() and s.e and s.e.link then WK.InsertChatLink(s.e.link) end
    end)
    function t:Paint(e)
        self.e = e
        local col = qcolor(e.q)
        self.edge:SetColor(col[1], col[2], col[3], 0.6)
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.94)
        self.stripe:SetColorTexture(col[1], col[2], col[3], 1)
        self.iconEdge:SetColorTexture(col[1], col[2], col[3], 1)
        self.icon:SetTexture(e.icon or 134400)
        self.name:SetText(UI:Hex(col) .. e.name .. "|r" .. (e.qty > 1 and ("  x" .. e.qty) or ""))
        local sub = e.sub or ""
        if e.tags ~= "" then sub = (sub ~= "" and (sub .. "   ") or "") .. e.tags end
        self.sub:SetText(sub)
        local p, s = priceText(e)
        self.price:SetText(p); self.src:SetText(s)
    end
    t:Hide()
    return t
end

local function layoutStack()
    local y = 0
    for _, t in ipairs(toasts) do
        t:ClearAllPoints()
        t:SetPoint("TOP", stack, "TOP", 0, -y)
        y = y + H + GAPY
    end
end

local function buildStack()
    local f = _G.CreateFrame("Frame", "WarbandKeeperLootToasts", UIParent)
    f:SetSize(W, MAXN * (H + GAPY))
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f.free = {}
    f:SetScript("OnUpdate", function()
        local now = GetTime()
        local dur = cfg().duration or 4
        local changed = false
        for i = #toasts, 1, -1 do
            local t = toasts[i]
            if t.hover or f.sample then
                t.born = now - math.min(now - t.born, dur - 1) -- au survol : il reste (au moins 1 s ensuite)
                t:SetAlpha(1)
            else
                local age = now - t.born
                if age >= dur then
                    t:Hide(); table.remove(toasts, i); table.insert(f.free, t); changed = true
                else
                    t:SetAlpha(age > dur - 0.5 and (dur - age) / 0.5 or math.min(1, age / 0.15))
                end
            end
        end
        if changed then layoutStack() end
    end)
    UI:RegisterHUD("lootToast", f, {
        label = T("Butin à l'écran"), default = { 420, 120 },
        enabled = function() return on() end,
        sample = function(onS)
            f.sample = onS or nil
            if onS then
                UI.LootToastDemo()
            else
                for _, t in ipairs(toasts) do t:Hide(); table.insert(f.free, t) end
                wipe(toasts)
            end
        end,
        test = function() UI.LootToastDemo(true) end,
    })
    return f
end

local function push(e)
    stack = stack or buildStack()
    -- même objet encore affiché : cumulé, et remonté en haut
    for i, t in ipairs(toasts) do
        if t.e and t.e.id == e.id then
            e.qty = t.e.qty + e.qty
            e.value = e.unit * e.qty
            local n = describe(e.id, e.link, e.qty)
            t:Paint(n or e)
            t.born = GetTime()
            table.remove(toasts, i); table.insert(toasts, 1, t)
            layoutStack()
            return
        end
    end
    local t = table.remove(stack.free) or newToast(stack)
    t:Paint(e)
    t.born = GetTime(); t.hover = false
    t:SetAlpha(0); t:Show()
    table.insert(toasts, 1, t)
    while #toasts > MAXN do
        local old = table.remove(toasts)
        old:Hide(); table.insert(stack.free, old)
    end
    layoutStack()
    stack:Show()
end

---------------------------------------------------------------------------
-- Grand encadré (butin notable)
---------------------------------------------------------------------------
local function buildBig()
    local f = _G.CreateFrame("Button", "WarbandKeeperLootToastBig", UIParent)
    f:SetSize(BIG_W, BIG_H)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f.halo = f:CreateTexture(nil, "BACKGROUND", nil, -2)
    f.halo:SetTexture(UI.MEDIA .. "fxhalo"); f.halo:SetBlendMode("ADD")
    f.halo:SetPoint("TOPLEFT", -40, 34); f.halo:SetPoint("BOTTOMRIGHT", 40, -34)
    f.edge = UI:Rounded(f, 12, 0, "BACKGROUND", 1)
    f.bg = UI:Rounded(f, 10, 2, "BACKGROUND", 2)
    f.iconEdge = f:CreateTexture(nil, "ARTWORK")
    f.iconEdge:SetSize(50, 50); f.iconEdge:SetPoint("LEFT", 13, 0)
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetPoint("TOPLEFT", f.iconEdge, "TOPLEFT", 2, -2)
    f.icon:SetPoint("BOTTOMRIGHT", f.iconEdge, "BOTTOMRIGHT", -2, 2)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.price = UI:Text(f, 15, C.gold); f.price:SetPoint("TOPRIGHT", -14, -18); f.price:SetJustifyH("RIGHT")
    f.src = UI:Text(f, 10, C.muted); f.src:SetPoint("TOPRIGHT", f.price, "BOTTOMRIGHT", 0, -4)
    f.src:SetJustifyH("RIGHT")
    f.head = UI:Text(f, 10, C.muted); f.head:SetPoint("TOPLEFT", 76, -10)
    f.name = UI:Text(f, 15); f.name:SetPoint("TOPLEFT", f.head, "BOTTOMLEFT", 0, -3)
    f.name:SetPoint("RIGHT", f.price, "LEFT", -10, 0)
    f.tags = UI:Text(f, 11); f.tags:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -5)
    f.tags:SetPoint("RIGHT", f.price, "LEFT", -10, 0)
    f:SetScript("OnEnter", function(s)
        s.hover = true
        if not s.e then return end
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        if s.e.link then _G.GameTooltip:SetHyperlink(s.e.link)
        elseif _G.GameTooltip.SetItemByID then _G.GameTooltip:SetItemByID(s.e.id) end
        _G.GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(s) s.hover = false; _G.GameTooltip:Hide() end)
    f:SetScript("OnClick", function(s)
        if _G.IsShiftKeyDown() and s.e and s.e.link then WK.InsertChatLink(s.e.link) end
    end)
    local HEAD = { [2] = "Butin inhabituel", [3] = "Butin rare", [4] = "Butin épique", [5] = "Butin légendaire" }
    function f:Paint(e)
        self.e = e
        local col = qcolor(e.q)
        self.col = col
        self.edge:SetColor(col[1], col[2], col[3], 1)
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.96)
        self.iconEdge:SetColorTexture(col[1], col[2], col[3], 1)
        self.icon:SetTexture(e.icon or 134400)
        self.head:SetText(UI:Upper(T(HEAD[e.q] or "Butin notable")))
        self.name:SetText(UI:Hex(col) .. e.name .. "|r" .. (e.qty > 1 and ("  x" .. e.qty) or ""))
        self.tags:SetText(e.tags ~= "" and e.tags or (UI:Hex(C.muted) .. (e.sub or "") .. "|r"))
        local p, s = priceText(e)
        self.price:SetText(p); self.src:SetText(s)
    end
    f:SetScript("OnUpdate", function(s, el)
        s.t = (s.t or 0) + el
        local col = s.col or { 1, 1, 1 }
        s.halo:SetVertexColor(col[1], col[2], col[3], 0.35 + 0.25 * math.sin(s.t * 3))
        if s.sample then s:SetAlpha(1) return end
        if s.hover then s.born = GetTime() - math.min(GetTime() - (s.born or 0), (cfg().bigDuration or 6) - 1) end
        local age = GetTime() - (s.born or 0)
        local dur = cfg().bigDuration or 6
        if age >= dur then s:Hide() return end
        s:SetAlpha(age > dur - 0.6 and (dur - age) / 0.6 or math.min(1, age / 0.2))
    end)
    f:Hide()
    UI:RegisterHUD("lootToastBig", f, {
        label = T("Butin notable"), default = { 0, 260 },
        enabled = function() return on() end,
        sample = function(onS)
            f.sample = onS or nil
            if onS then
                f:Paint({ id = 0, name = T("Bottes de l'éclaireur fantôme"), q = 4, qty = 1, value = 380000,
                    unit = 380000,
                    src = "ah", tags = UI:Hex(C.gold) .. T("BiS") .. "|r  " .. UI:Hex(C.positive)
                        .. string.format(T("Amélioration +%d"), 18) .. "|r", icon = 132542 })
                f:Show()
            else f:Hide() end
        end,
    })
    return f
end

local function showBig(e)
    big = big or buildBig()
    -- un grand encadré encore affiché passe dans la pile
    if big:IsShown() and big.e and not big.sample then push(big.e) end
    big:Paint(e)
    big.born = GetTime(); big.hover = false; big.t = 0
    big:SetAlpha(0); big:Show()
    if cfg().sound and _G.PlaySound then
        local kit = _G.SOUNDKIT
        pcall(_G.PlaySound, (kit and (kit.UI_EPICLOOT_TOAST or kit.UI_LEGENDARY_LOOT_TOAST)) or 31578, "Master")
    end
end

-- Encadrés affichés : nombre, et quantité du plus récent (tests, diagnostic)
function UI.LootToastCount() return #toasts, toasts[1] and toasts[1].e and toasts[1].e.qty or 0 end

-- Un objet ramassé par le perso : affiché (s'il passe la qualité minimale)
function UI.LootToastShow(id, link, qty, tries)
    if not on() or not id then return end
    local e = describe(id, link, qty or 1)
    if not e then
        -- objet pas encore connu du client : redemandé un peu plus tard
        if (tries or 0) < 5 then
            C_Timer.After(0.3, function() UI.LootToastShow(id, link, qty, (tries or 0) + 1) end)
        end
        return
    end
    if e.q < (cfg().minQuality or 1) and not e.big then return end
    if e.big then showBig(e) else push(e) end
end

-- Exemple (mode édition) ou essai (bouton Tester)
function UI.LootToastDemo(real)
    stack = stack or buildStack()
    local demo = {
        { id = 2589, name = T("Etoffe de lin"), q = 1, qty = 4, unit = 200, value = 800, src = "ah",
          sub = string.format(T("%s l'unité"), UI:PlainMoney(200)) .. "  ·  " .. string.format(T("%d en sacs"), 46),
          tags = "" },
        { id = 2592, name = T("Etoffe de laine"), q = 1, qty = 2, unit = 400, value = 800, src = "ah",
          sub = string.format(T("%s l'unité"), UI:PlainMoney(400)), tags = "" },
        { id = 14047, name = T("Lame de la vengeance"), q = 3, qty = 1, unit = 42000, value = 42000, src = "ah",
          sub = string.format(T("niv. %d"), 24),
          tags = UI:Hex(C.positive) .. string.format(T("Amélioration +%d"), 12) .. "|r" },
    }
    for _, e in ipairs(demo) do
        e.icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or 134400
        push(e)
    end
    if real then
        big = big or buildBig()
        showBig({ id = 0, name = T("Bottes de l'éclaireur fantôme"), q = 4, qty = 1, value = 380000, unit = 380000,
            src = "ah", tags = UI:Hex(C.gold) .. T("BiS") .. "|r", icon = 132542 })
    end
end

---------------------------------------------------------------------------
-- Messages de butin du perso
---------------------------------------------------------------------------
local function lootPattern(fmt)
    if type(fmt) ~= "string" then return nil end
    local p = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
    p = p:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
    return "^" .. p
end
local SELF = { "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF" }
local patterns, patKey
local function selfLoot(msg)
    -- formats relus s'ils changent (langue du client chargée après ce fichier)
    if not patterns or patKey ~= _G.LOOT_ITEM_SELF then
        patterns, patKey = {}, _G.LOOT_ITEM_SELF
        for _, g in ipairs(SELF) do
            local p = lootPattern(_G[g])
            if p then patterns[#patterns + 1] = p end
        end
    end
    for _, p in ipairs(patterns) do
        local link, n = msg:match(p)
        if link then return link, tonumber(n) or 1 end
    end
    return nil
end
UI.LootToastParse = selfLoot

-- achats, courrier, échange, banque : « Vous recevez l'objet » aussi, mais ce n'est pas du butin
local BUSY = { "MerchantFrame", "MailFrame", "TradeFrame", "BankFrame", "AuctionHouseFrame", "GuildBankFrame" }
local function busy()
    for _, n in ipairs(BUSY) do
        local f = _G[n]
        if f and f.IsVisible and f:IsVisible() then return true end
    end
    return false
end
WK:On("CHAT_MSG_LOOT", function(msg)
    if not on() or type(msg) ~= "string" then return end
    if _G.issecretvalue and _G.issecretvalue(msg) then return end
    if busy() then return end
    local link, n = selfLoot(msg)
    if not link then return end
    local id = WK:ParseItemID(link)
    if id then UI.LootToastShow(id, link, n) end
end)

---------------------------------------------------------------------------
-- Carte de réglages (roue de la page Filtre de loot)
---------------------------------------------------------------------------
function UI.BuildLootToastCard(_, parent)
    local c = cfg()
    local card = UI:Card(parent, "Butin à l'écran", "un encadré par objet ramassé, prix du scan HV")
    card:SetHeight(40 + 6 * 46 + 8)
    local function row(y, name, desc, ctrl, w) UI:SettingRow(card, y, name, desc, ctrl, w) end
    local function refresh()
        if stack and not c.enabled then for _, t in ipairs(toasts) do t:Hide() end end
    end
    row(-40, "Afficher le butin à l'écran", "Un petit encadré par objet ramassé (couleur de la rareté, prix du lot,"
            .. " étiquettes), qui s'efface tout seul. Se place en mode édition.",
        UI:Toggle(card, function() return c.enabled end, function(v) c.enabled = v; refresh() end), 80)
    local qs = UI:Segmented(card, { { 0, "Grise" }, { 1, "Blanche" }, { 2, "Verte" }, { 3, "Bleue" } },
        function(v) c.minQuality = v end, 24)
    row(-86, "Qualité minimale affichée", "Les objets en dessous ne sont pas montrés.", qs, 280)
    qs:Select(c.minQuality or 1)
    row(-132, "Durée d'un encadré", "Le survol le garde affiché.",
        UI:Slider(card, 220, 2, 10, 1, function() return c.duration or 4 end,
            function(v) c.duration = v end, "%d s"), 240)
    local bs = UI:Segmented(card, { { 2, "Verte" }, { 3, "Bleue" }, { 4, "Épique" }, { 9, "Jamais" } },
        function(v) c.bigQuality = v end, 24)
    row(-178, "Grand encadré à partir de", "Butin notable : grand encadré au centre, halo et son (aussi pour un objet"
            .. " BiS du perso ou une envie).", bs, 280)
    bs:Select(c.bigQuality or 3)
    row(-224, "Grand encadré au-dessus de", "Valeur du lot qui le rend notable, quelle que soit la rareté (0 : non).",
        UI:Slider(card, 220, 0, 50, 1, function() return math.floor((c.bigValue or 0) / 10000) end,
            function(v) c.bigValue = v * 10000 end, "%d po"), 240)
    row(-270, "Son du grand encadré", "Un petit son quand un butin notable apparaît.",
        UI:Toggle(card, function() return c.sound end, function(v) c.sound = v end), 80)
    return card
end
