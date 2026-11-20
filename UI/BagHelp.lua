local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Affichage des aides des sacs (Modules/BagHelp.lua) :
--   * HUD « bagSpace » : sous le seuil de cases libres, le nombre de cases et, au clic, l'objet gris le moins
--     cher jeté (jamais en combat, jamais un objet verrouillé) ;
--   * bouton « Réassort » sous la fenêtre du marchand : ce qui manque et le prix, acheté sur un clic ;
--   * HUD « wearOffer » : objet arrivé dans les sacs meilleur que celui porté, « L'équiper » / « Pas celui-là » ;
--   * fenêtre de destruction du jeu : « Encore demandé par : quête » pour un objet d'une quête du journal ;
--   * carte de réglages « Sacs, marchand et équipement » (roue de la page Inventaire).
local function BH() return WK.modules.BagHelp end
local function inCombat() return InCombatLockdown and InCombatLockdown() or false end

---------------------------------------------------------------------------
-- Place dans les sacs
---------------------------------------------------------------------------
local space
local function buildSpace()
    local b = CreateFrame("Button", "WarbandKeeperBagSpace", UIParent)
    b:SetSize(46, 46)
    b:SetFrameStrata("MEDIUM")
    b.bg = UI:Rounded(b, 11, 0, "BACKGROUND", 1)
    b.icon = UI:Icon(b, "bag", 22, nil, "ARTWORK"); b.icon:SetPoint("CENTER", 0, 4)
    b.n = UI:Text(b, 11); b.n:SetPoint("BOTTOM", 0, 4)
    function b:Paint(free)
        self.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.92)
        local col = free <= 0 and C.negative or C.warning
        self.icon:SetVertexColor(col[1], col[2], col[3], 1)
        self.n:SetText(tostring(free)); self.n:SetTextColor(col[1], col[2], col[3])
    end
    b:SetScript("OnEnter", function(s)
        local free, total = BH():FreeSlots()
        UI:TooltipOwner(s, "ANCHOR_TOP")
        GameTooltip:SetText(string.format(T("%d case(s) libre(s) sur %d"), free, total), 1, 1, 1)
        local g = BH():CheapestGrey()
        if g then
            local _, link = WK.GetItemInfo(g.id)
            GameTooltip:AddLine(string.format(T("Clic : jeter %s (%s)"), link or "?", WK:FormatMoney(g.price)), 0.85, 0.85, 0.85, true)
        else
            GameTooltip:AddLine(T("Aucun objet gris à jeter."), 0.6, 0.6, 0.6)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        if BH():DeleteCheapest() then C_Timer.After(0.3, function() UI:RefreshBagSpace(); if s:IsMouseOver() then s:GetScript("OnEnter")(s) end end) end
    end)
    b:Hide()
    UI:RegisterHUD("bagSpace", b, {
        label = T("Place dans les sacs"), default = { 300, -200 },
        enabled = function() return BH():Config().space end,
        sample = function(on) b.sample = on or nil; if on then b:Paint(2); b:Show() else UI:RefreshBagSpace() end end,
    })
    return b
end
function UI:RefreshBagSpace()
    space = space or buildSpace()
    if space.sample then return end
    local cfg = BH():Config()
    local free = BH():FreeSlots()
    if not cfg.space or free > (cfg.low or 3) or not WK:FeatureOn("inventory") then space:Hide() return end
    space:Paint(free)
    space:Show()
end

---------------------------------------------------------------------------
-- Réassort chez le marchand
---------------------------------------------------------------------------
local rsBtn
local function plan()
    local stock = UI.MerchantStock and UI.MerchantStock() or {}
    return BH():RestockPlan(stock)
end
local function buildRestock()
    local b = UI:Button(UIParent, T("Réassort"), nil, 26, "primary")
    b:SetFrameStrata("DIALOG")
    b:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        GameTooltip:SetText(T("Réassort"), 1, 1, 1)
        for _, p in ipairs(s.plan or {}) do
            local _, link = WK.GetItemInfo(p.id)
            GameTooltip:AddDoubleLine((link or ("#" .. p.id)) .. " x" .. p.need,
                WK:FormatMoney(math.ceil(p.stock.price / math.max(1, p.stock.batch) * p.need)), 1, 1, 1, 1, 1, 1)
        end
        GameTooltip:AddLine(T("Quantités : roue de la page Inventaire."), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(s)
        local n = 0
        for _, p in ipairs(s.plan or {}) do n = n + (UI.MerchantBuy(p.stock, p.need) or 0) end
        if n > 0 then WK:Print(string.format(T("Réassort : %d objet(s) acheté(s)."), n)) end
        C_Timer.After(1, function() UI:RefreshRestock() end)
    end)
    b:Hide()
    return b
end
function UI:RefreshRestock()
    rsBtn = rsBtn or buildRestock()
    local cfg = BH():Config()
    if not (cfg.restock and MerchantFrame and MerchantFrame:IsShown() and WK:FeatureOn("inventory")) then rsBtn:Hide() return end
    local p = plan()
    rsBtn.plan = p
    if #p == 0 then rsBtn:Hide() return end
    rsBtn:SetLabel(string.format(T("Réassort : %d objet(s), %s"), #p, UI:PlainMoney(BH():PlanCost(p))))
    rsBtn:SetWidth(rsBtn.label:GetStringWidth() + 32)
    rsBtn:ClearAllPoints()
    rsBtn:SetPoint("TOPLEFT", MerchantFrame, "BOTTOMLEFT", 4, -4)
    UI:MatchHost(rsBtn, MerchantFrame)
    rsBtn:Show()
end
WK:On("MERCHANT_SHOW", function() C_Timer.After(0.3, function() UI:RefreshRestock() end) end)
WK:On("MERCHANT_CLOSED", function() if rsBtn then rsBtn:Hide() end end)
WK:On("MERCHANT_UPDATE", function() if rsBtn and rsBtn:IsShown() then C_Timer.After(0.3, function() UI:RefreshRestock() end) end end)

---------------------------------------------------------------------------
-- Amélioration à porter
---------------------------------------------------------------------------
local wear
local function buildWear()
    local f = CreateFrame("Frame", "WarbandKeeperWearOffer", UIParent)
    f:SetSize(320, 78)
    f:SetFrameStrata("MEDIUM")
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(34, 34); f.icon:SetPoint("TOPLEFT", 12, -12)
    f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.title = UI:Text(f, 10, C.muted); f.title:SetPoint("TOPLEFT", 56, -12); f.title:SetText(UI:Upper(T("Mieux que ce que tu portes")))
    f.name = UI:Text(f, 12); f.name:SetPoint("TOPLEFT", 56, -26); f.name:SetPoint("RIGHT", -12, 0)
    if f.name.SetWordWrap then f.name:SetWordWrap(false) end
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 56, -42); f.sub:SetPoint("RIGHT", -12, 0)
    if f.sub.SetWordWrap then f.sub:SetWordWrap(false) end
    f.yes = UI:Button(f, T("L'équiper"), nil, 22, "primary")
    f.yes:SetPoint("BOTTOMRIGHT", -12, 10)
    f.no = UI:Button(f, T("Pas celui-là"), nil, 22, "ghost")
    f.no:SetPoint("RIGHT", f.yes, "LEFT", -6, 0)
    f.yes:SetScript("OnClick", function() BH():Wear(f.q); C_Timer.After(0.5, function() UI:RefreshWearOffer() end) end)
    f.no:SetScript("OnClick", function() BH():Skip(f.q); UI:RefreshWearOffer() end)
    local hover = CreateFrame("Frame", nil, f)
    hover:SetPoint("TOPLEFT", f.icon); hover:SetPoint("BOTTOMRIGHT", f.sub, "BOTTOMRIGHT")
    hover:SetScript("OnEnter", function(s)
        if not (f.q and f.q.link) then return end
        UI:TooltipOwner(s, "ANCHOR_TOP"); GameTooltip:SetHyperlink(f.q.link); GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
    function f:Paint(q)
        self.q = q
        local _, _, _, _, _, _, _, _, _, icon = WK.GetItemInfo(q.link)
        self.icon:SetTexture(icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(q.id)) or "Interface\\Icons\\INV_Misc_QuestionMark")
        self.name:SetText(q.link or "?")
        local oldName = q.old and q.old:match("%[(.-)%]")
        self.sub:SetText(string.format(T("+%d points (caractéristiques de ta classe)"), math.floor((q.gain or 0) + 0.5))
            .. "  ·  " .. (oldName and string.format(T("à la place de %s"), oldName) or T("emplacement vide")))
    end
    f:Hide()
    UI:RegisterHUD("wearOffer", f, {
        label = T("Amélioration à porter"), default = { 0, -180 },
        enabled = function() return BH():Config().wear end,
        sample = function(on)
            f.sample = on or nil
            if on then
                f:Paint({ id = 2575, link = "|cff1eff00|Hitem:2575::::::::|h[Exemple d'objet]|h|r", gain = 6, old = "[Ancien objet]" })
                f:Show()
            else UI:RefreshWearOffer() end
        end,
    })
    return f
end
function UI:RefreshWearOffer()
    wear = wear or buildWear()
    if wear.sample then return end
    local q = BH():Config().wear and WK:FeatureOn("inventory") and not inCombat() and BH():Offer()
    if not q then wear:Hide() return end
    wear:Paint(q)
    wear:Show()
end
WK:On("PLAYER_REGEN_DISABLED", function() if wear and not wear.sample then wear:Hide() end end)

---------------------------------------------------------------------------
-- Fenêtre de destruction : objet demandé par une quête du journal
---------------------------------------------------------------------------
local DELETE = { DELETE_ITEM = true, DELETE_GOOD_ITEM = true, DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }
local function onPopup(which)
    if not DELETE[which] or not GetCursorInfo then return end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    local q = WK.modules.ItemLock and WK.modules.ItemLock:QuestFor(id)
    if not q then return end
    local frame = StaticPopup_FindVisible and StaticPopup_FindVisible(which)
    local text = frame and (frame.text or frame.Text)
    if not (text and text.GetText) then return end
    local cur = text:GetText() or ""
    if cur:find(q, 1, true) then return end
    text:SetText(cur .. "\n\n" .. UI:Hex(C.warning) .. string.format(T("Encore demandé par : %s"), q) .. "|r")
    if StaticPopup_Resize then pcall(StaticPopup_Resize, frame, which) end
end
UI.QuestDeleteLine = onPopup
if hooksecurefunc and StaticPopup_Show then hooksecurefunc("StaticPopup_Show", onPopup) end

---------------------------------------------------------------------------
-- Réglages : carte de la roue de la page Inventaire
---------------------------------------------------------------------------
function UI:BuildBagHelpCard(root)
    local cfg = BH():Config()
    local rs = BH():Restock()
    local card = UI:Card(root, T("Sacs, marchand et équipement"))
    local y = -40
    local function row(label, desc, ctrl, w) UI:SettingRow(card, y, label, desc, ctrl, w); y = y - 46 end
    row("Place dans les sacs", "Sous le seuil, un bouton à l'écran montre les cases libres ; un clic jette l'objet gris le moins cher.",
        UI:Toggle(card, function() return cfg.space end, function(v) cfg.space = v; UI:RefreshBagSpace() end), 80)
    row("Seuil de cases libres", nil, UI:Slider(card, 220, 0, 12, 1, function() return cfg.low or 3 end, function(v) cfg.low = v; UI:RefreshBagSpace() end, "%d"), 240)
    row("Amélioration à porter", "Un objet qui arrive dans les sacs et vaut mieux que celui porté est proposé (jamais équipé tout seul).",
        UI:Toggle(card, function() return cfg.wear end, function(v) cfg.wear = v; UI:RefreshWearOffer() end), 80)
    row("Réassort chez le marchand", "Un bouton sous la fenêtre du marchand complète ce qui manque, sur un clic (munitions et composants de classe : QoL > Classes).",
        UI:Toggle(card, function() return cfg.restock end, function(v) cfg.restock = v; UI:RefreshRestock() end), 80)
    row("Boissons (ce perso)", "Le meilleur que vend le marchand pour ton niveau.",
        UI:Slider(card, 220, 0, 100, 5, function() return rs.drink or 0 end, function(v) rs.drink = v end, "%d"), 240)
    row("Nourriture (ce perso)", nil, UI:Slider(card, 220, 0, 100, 5, function() return rs.food or 0 end, function(v) rs.food = v end, "%d"), 240)
    -- objets choisis : glisser un objet sur la case ; quantité réglée par - / + ; croix pour retirer
    local drop = CreateFrame("Button", nil, card)
    drop:SetSize(34, 34)
    drop.bg = UI:Rounded(drop, 8, 0, "BACKGROUND", 1); drop.bg:SetColor(unpack(C.surface2))
    drop.plus = UI:Icon(drop, "plus", 14, nil, "ARTWORK"); drop.plus:SetPoint("CENTER")
    drop:SetPoint("TOPLEFT", 16, y - 4)
    local dl = UI:Text(card, 12); dl:SetPoint("LEFT", drop, "RIGHT", 10, 6); dl:SetText(T("Autres objets à garder en stock"))
    local dd = UI:Text(card, 10, C.muted); dd:SetPoint("LEFT", drop, "RIGHT", 10, -8); dd:SetText(T("Glisse un objet des sacs sur la case (composants, flacons…)."))
    y = y - 46
    local rows = {}
    local MAXR = 6
    local function refreshItems()
        local ids = {}
        for id in pairs(rs.items) do ids[#ids + 1] = id end
        table.sort(ids)
        for i = 1, MAXR do
            local r = rows[i]
            local id = ids[i]
            r:SetShown(id ~= nil)
            if id then
                r.id = id
                local name = WK.GetItemInfo(id)
                r.name:SetText(name or ("#" .. id))
                r.qty:SetText(tostring(rs.items[id]))
            end
        end
    end
    local function add()
        local kind, id
        if GetCursorInfo then kind, id = GetCursorInfo() end
        if kind ~= "item" or not id then return end
        ClearCursor()
        local n = 0
        for _ in pairs(rs.items) do n = n + 1 end
        if not rs.items[id] and n >= MAXR then return end
        rs.items[id] = rs.items[id] or (select(8, WK.GetItemInfo(id)) or 20)
        refreshItems()
    end
    drop:SetScript("OnReceiveDrag", add)
    drop:SetScript("OnClick", add)
    for i = 1, MAXR do
        local r = CreateFrame("Frame", nil, card)
        r:SetHeight(24)
        r:SetPoint("TOPLEFT", 16, y - (i - 1) * 26); r:SetPoint("RIGHT", card, "RIGHT", -16, 0)
        r.name = UI:Text(r, 11); r.name:SetPoint("LEFT", 4, 0); r.name:SetPoint("RIGHT", -150, 0)
        r.del = UI:IconButton(r, "close", 20, T("Retirer"), true); r.del:SetPoint("RIGHT", 0, 0)
        r.plus = UI:IconButton(r, "plus", 20, "+5"); r.plus:SetPoint("RIGHT", r.del, "LEFT", -12, 0)
        r.qty = UI:Text(r, 11); r.qty:SetWidth(44); r.qty:SetJustifyH("CENTER"); r.qty:SetPoint("RIGHT", r.plus, "LEFT", -4, 0)
        r.minus = UI:IconButton(r, "minus", 20, "-5"); r.minus:SetPoint("RIGHT", r.qty, "LEFT", -4, 0)
        r.plus:SetScript("OnClick", function() rs.items[r.id] = (rs.items[r.id] or 0) + 5; refreshItems() end)
        r.minus:SetScript("OnClick", function() rs.items[r.id] = math.max(1, (rs.items[r.id] or 0) - 5); refreshItems() end)
        r.del:SetScript("OnClick", function() rs.items[r.id] = nil; refreshItems() end)
        rows[i] = r
    end
    y = y - MAXR * 26
    refreshItems()
    card:SetHeight(-y + 10)
    card:HookScript("OnShow", refreshItems)
    return card
end
