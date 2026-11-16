local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Panneau collé à la fenêtre du marchand : pour chaque métier du perso qui a un guide de montée,
-- les composants qui manquent jusqu'au palier choisi (75, 150, 225, 300 ou Max, le même que dans
-- Métiers > guide : settings.ui.guideTarget[métier]), d'après Recipes:GuidePlan.
-- Ce que ce marchand vend vient en premier, avec « Acheter » (la quantité qui manque) et
-- « Tout acheter » ; le reste est compté en bas (HV, récolte, autre marchand).
-- Réglage : settings.ui.merchantPanel (QoL > Général > Marchand).
local panel
local W, ROW_H = 300, 34
local R = function() return WK.modules.Recipes end

local function on()
    return WK.DB.global.settings.ui.merchantPanel ~= false and WK:FeatureOn("professions")
end
local function targets()
    local ui = WK.DB.global.settings.ui
    ui.guideTarget = ui.guideTarget or {}
    return ui.guideTarget
end
local function targetOf(prof)
    local t = targets()[prof]
    if t == "max" or not t then return nil end
    return t
end

-- Ce que vend le marchand ouvert : { [itemID] = { index, price, batch, available } }
local function merchantStock()
    local out = {}
    if not GetMerchantNumItems then return out end
    for i = 1, GetMerchantNumItems() do
        local id = GetMerchantItemID and GetMerchantItemID(i)
        if not id and GetMerchantItemLink then id = WK:ParseItemID(GetMerchantItemLink(i)) end
        if id then
            local _, _, price, batch, available = GetMerchantItemInfo(i)
            out[id] = { index = i, price = price or 0, batch = math.max(1, batch or 1), available = available }
        end
    end
    return out
end

-- Achète `need` unités (par lots si le marchand vend par paquets). Renvoie la quantité achetée.
local function buy(s, need)
    if (s.available or -1) == 0 then return 0 end
    local bought = 0
    if s.batch > 1 then
        for _ = 1, math.min(math.ceil(need / s.batch), 40) do
            if s.price > GetMoney() then break end
            BuyMerchantItem(s.index)
            bought = bought + s.batch
        end
    else
        local maxStack = GetMerchantItemMaxStack and GetMerchantItemMaxStack(s.index) or 20
        local left = need
        while left > 0 do
            local n = math.min(left, maxStack)
            if s.price * n > GetMoney() then break end
            BuyMerchantItem(s.index, n)
            bought, left = bought + n, left - n
        end
    end
    return bought
end

-- Besoins par métier : { { prof, rank, target, here = { mats vendus ici }, elsewhere = n, cost } }
local function needs(stock)
    local c = WK.DB:Me()
    local out = {}
    local Rc = R()
    if not (Rc and c.professions) then return out end
    local known = Rc:KnownOutputs(c)
    for prof, p in pairs(c.professions) do
        if Rc:Guide(prof) then
            local tgt = targetOf(prof)
            if not tgt or (p.rank or 0) < tgt then
                local _, mats = Rc:GuidePlan(prof, p.rank or 0, known, tgt)
                local e = { prof = prof, rank = p.rank or 0, target = tgt, here = {}, elsewhere = 0, cost = 0 }
                for _, m in ipairs(mats or {}) do
                    if m.missing > 0 then
                        local s = stock[m.itemID]
                        if s then
                            local unit = s.price / s.batch
                            table.insert(e.here, { id = m.itemID, missing = m.missing, stock = s, cost = math.ceil(unit * m.missing), recipe = m.recipe })
                            e.cost = e.cost + math.ceil(unit * m.missing)
                        else
                            e.elsewhere = e.elsewhere + 1
                        end
                    end
                end
                if #e.here > 0 or e.elsewhere > 0 then table.insert(out, e) end
            end
        end
    end
    table.sort(out, function(a, b) return #a.here > #b.here end)
    return out
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperMerchantPanel", UIParent)
    f:SetSize(W, 200)
    f:EnableMouse(true)
    UI:Panel(f, 12, C.surface, C.border)
    f.logo = UI:Icon(f, "hammer", 16, nil, "ARTWORK")
    f.logo:SetPoint("TOPLEFT", 14, -12)
    f.title = UI:Text(f, 12)
    f.title:SetPoint("LEFT", f.logo, "RIGHT", 6, 0)
    f.title:SetText(T("Pour monter tes métiers"))
    f.close = UI:IconButton(f, "close", 16)
    f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f.closed = true; f:Hide() end)
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", 6, -36)
    f.scroll:SetPoint("BOTTOMRIGHT", -6, 52)
    f.heads = UI:Pool(function()
        local h = CreateFrame("Frame", nil, f.scroll.child)
        h:SetHeight(46)
        h.name = UI:Text(h, 12)
        h.name:SetPoint("TOPLEFT", 10, -4)
        h.seg = UI:Segmented(h, { { 75, "75" }, { 150, "150" }, { 225, "225" }, { 300, "300" }, { "max", "Max" } }, function(v)
            targets()[h.prof] = v
            f:Refresh()
        end, 20)
        h.seg:SetPoint("TOPLEFT", 8, -22)
        return h
    end)
    f.rows = UI:Pool(function()
        local r = CreateFrame("Frame", nil, f.scroll.child)
        r:SetHeight(ROW_H)
        r.icon = UI:RoundIcon(r, 22)
        r.icon:SetPoint("LEFT", 10, 0)
        r.name = UI:Text(r, 11)
        r.name:SetPoint("TOPLEFT", 38, -3)
        r.name:SetPoint("RIGHT", -74, 0)
        r.name:SetJustifyH("LEFT")
        r.sub = UI:Text(r, 10, C.muted)
        r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
        r.sub:SetPoint("RIGHT", -74, 0)
        r.sub:SetJustifyH("LEFT")
        r.buy = UI:Button(r, "Acheter", 64, 22, "secondary")
        r.buy:SetPoint("RIGHT", -6, 0)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(s)
            if not s.id then return end
            UI:TooltipOwner(s, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText((UI:ItemInfo(s.id))) end
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return r
    end)
    f.other = UI:Text(f.scroll.child, 10, C.dim)
    f.total = UI:Text(f, 11)
    f.total:SetPoint("BOTTOMLEFT", 14, 40)
    f.total:SetPoint("RIGHT", -14, 0)
    f.total:SetJustifyH("LEFT")
    f.all = UI:Button(f, "Tout acheter", W - 28, 26, "primary")
    f.all:SetPoint("BOTTOM", 0, 10)

    function f:Refresh()
        local stock = merchantStock()
        local list = needs(stock)
        self.heads:Reset(); self.rows:Reset()
        local LW = W - 22
        local y, cost, count = 0, 0, 0
        local others = 0
        local buyAll = {}
        for _, e in ipairs(list) do
            if #e.here > 0 then
                local h = self.heads:Get()
                h.prof = e.prof
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetWidth(LW)
                h.name:SetText(T(e.prof) .. "  |cff999999" .. e.rank .. "|r")
                h.seg:Select(e.target or "max")
                y = y + 48
                for _, m in ipairs(e.here) do
                    local r = self.rows:Get()
                    r.id = m.id
                    r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetWidth(LW)
                    local name, icon = UI:ItemInfo(m.id)
                    r.icon:SetTexture(icon)
                    r.name:SetText(name .. (m.recipe and ("  |cff999999" .. T("(recette)") .. "|r") or ""))
                    r.sub:SetText(string.format(T("il en manque %d"), m.missing) .. "  ·  " .. UI:ExactMoney(m.cost))
                    r.buy:SetScript("OnClick", function()
                        local n = buy(m.stock, m.missing)
                        if n > 0 then WK:Print(string.format(T("Acheté : %d %s."), n, name)) end
                    end)
                    table.insert(buyAll, m)
                    cost, count = cost + m.cost, count + 1
                    y = y + ROW_H
                end
            end
            others = others + e.elsewhere
        end
        self.other:ClearAllPoints()
        self.other:SetPoint("TOPLEFT", 12, -(y + 4))
        self.other:SetPoint("RIGHT", self.scroll.child, "RIGHT", -12, 0)
        self.other:SetJustifyH("LEFT")
        if count == 0 then
            self.other:SetText(T("Ce marchand ne vend rien de ce qui te manque.") .. (others > 0 and ("\n" .. string.format(T("%d composant(s) à trouver ailleurs (HV, récolte, autre marchand)."), others)) or ""))
        else
            self.other:SetText(others > 0 and string.format(T("+ %d composant(s) à trouver ailleurs (HV, récolte, autre marchand)."), others) or "")
        end
        y = y + 40
        self.scroll.child:SetSize(LW, y)
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end
        self.total:SetText(count > 0 and (T("Tout ce qui manque ici :") .. " |cffffd24d" .. UI:ExactMoney(cost) .. "|r") or "")
        self.all:SetShown(count > 0)
        self.all:SetScript("OnClick", function()
            local n = 0
            for _, m in ipairs(buyAll) do n = n + buy(m.stock, m.missing) end
            if n > 0 then WK:Print(string.format(T("Acheté : %d composant(s) pour tes métiers."), n)) end
        end)
        -- hauteur : le contenu, entre 160 et 460
        self:SetHeight(math.max(160, math.min(460, y + 36 + 52)))
        local r, g, b = UI:Accent()
        self.logo:SetVertexColor(r, g, b)
        return count, #list
    end
    return f
end

local function show()
    if not on() or not MerchantFrame then return end
    local stock = merchantStock()
    if not next(stock) then return end
    -- rien à monter du tout (pas de métier avec guide, ou paliers atteints) : pas de panneau
    if #needs(stock) == 0 then if panel then panel:Hide() end return end
    panel = panel or build()
    panel.closed = nil
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 6, -12)
    panel:SetFrameStrata(MerchantFrame:GetFrameStrata() or "MEDIUM")
    local count = panel:Refresh()
    -- marchand qui ne vend rien d'utile : on n'encombre pas l'écran
    if count == 0 then panel:Hide() return end
    panel:Show()
end

WK:On("MERCHANT_SHOW", function() C_Timer.After(0.2, show) end)
WK:On("MERCHANT_CLOSED", function() if panel then panel:Hide() end end)
local pending
local function later()
    if pending or not (panel and panel:IsShown()) then return end
    pending = true
    C_Timer.After(0.5, function() pending = nil; if panel and panel:IsShown() then panel:Refresh() end end)
end
WK:On("BAG_UPDATE_DELAYED", later)
WK:On("MERCHANT_UPDATE", later)
WK:On("GET_ITEM_INFO_RECEIVED", later)
