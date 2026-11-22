local _, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page Inventaire > Monnaies (maquette A) : tableau monnaies x persos (Modules/Currency.lua), total du compte,
-- filtres par catégorie ; clic sur une ligne : le détail à droite (répartition, sacs / banque, où s'en servir).
local DETAIL_W, NAME_W, TOTAL_W, ROW_H = 280, 210, 70, 30
local MAX_COLS = 8

function UI.BuildMoneyPane(_, parent)
    local Cur = WK.modules.Currency
    local cfg = WK.DB.global.settings.ui
    local pane = UI:Scroll(parent)
    local card = UI:Card(pane.child, T("Monnaies"), " ")
    card:SetPoint("TOPLEFT")
    local opts = { { "all", "Tout" } }
    for _, c in ipairs(Cur.CATS) do opts[#opts + 1] = { c[1], c[2] } end
    local seg = UI:Segmented(card, opts, function(k) cfg.moneyCat = k; pane:Refresh() end, 26)
    seg:SetPoint("TOPRIGHT", -14, -10)
    local heads = {}
    local function head(i)
        if heads[i] then return heads[i] end
        local h = UI:Text(card, 10, C.dim)
        h:SetWordWrap(false)
        heads[i] = h
        return h
    end
    local rows = {}
    local function row(i)
        if rows[i] then return rows[i] end
        local r = _G.CreateFrame("Button", nil, card)
        r:SetHeight(ROW_H)
        r.hl = UI:Rounded(r, 6, 0, "BACKGROUND", 1)
        r.line = r:CreateTexture(nil, "BACKGROUND"); r.line:SetHeight(1)
        r.line:SetPoint("TOPLEFT", 0, 0); r.line:SetPoint("TOPRIGHT", 0, 0)
        r.icon = UI:RoundIcon(r, 20); r.icon:SetPoint("TOPLEFT", 6, -5)
        r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 34, -8); r.name:SetWidth(NAME_W - 40)
        r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
        r.cells = {}
        for k = 1, MAX_COLS + 1 do
            local t = UI:Text(r, 12); t:SetJustifyH("RIGHT"); t:SetWordWrap(false)
            r.cells[k] = t
        end
        r:SetScript("OnEnter", function(s) s.hover = true; pane:PaintRow(s) end)
        r:SetScript("OnLeave", function(s) s.hover = false; pane:PaintRow(s) end)
        r:SetScript("OnClick", function(s) cfg.moneySel = s.key; pane:Refresh() end)
        rows[i] = r
        return r
    end
    local empty = UI:Text(card, 12, C.muted); empty:SetJustifyH("LEFT")
    empty:SetText(T("Aucune monnaie relevée pour l'instant : elles apparaissent quand un perso en a dans ses sacs,"
        .. " sa banque ou l'onglet Monnaies du jeu."))
    if empty.SetWordWrap then empty:SetWordWrap(true) end
    local note = UI:Text(card, 10, C.muted); note:SetJustifyH("LEFT")
    note:SetText(T("Relevé dans les sacs, la banque et le courrier de chaque perso"
        .. " · clic sur une ligne : le détail à droite"))

    -- détail de la monnaie choisie
    local det = UI:Card(pane.child, T("Détail"), " ")
    det:SetWidth(DETAIL_W)
    det.icon = UI:RoundIcon(det, 34); det.icon:SetPoint("TOPLEFT", 14, -44)
    det.name = UI:Text(det, 13); det.name:SetPoint("TOPLEFT", 56, -46); det.name:SetWidth(DETAIL_W - 70)
    det.name:SetJustifyH("LEFT")
    det.sub = UI:Text(det, 11, C.muted); det.sub:SetPoint("TOPLEFT", 56, -64); det.sub:SetWidth(DETAIL_W - 70)
    det.sub:SetJustifyH("LEFT")
    det.h1 = UI:Text(det, 10, C.dim); det.h1:SetPoint("TOPLEFT", 14, -94); det.h1:SetText(UI:Upper(T("Répartition")))
    det.lines = {}
    det.h2 = UI:Text(det, 10, C.dim); det.h2:SetText(UI:Upper(T("Où s'en servir")))
    det.where = UI:Text(det, 11); det.where:SetWidth(DETAIL_W - 28); det.where:SetJustifyH("LEFT")
    if det.where.SetWordWrap then det.where:SetWordWrap(true) end
    local function detLine(i)
        if det.lines[i] then return det.lines[i] end
        local l = { n = UI:Text(det, 11), v = UI:Text(det, 11), s = UI:Text(det, 10, C.muted) }
        l.v:SetJustifyH("RIGHT"); l.s:SetJustifyH("LEFT")
        det.lines[i] = l
        return l
    end

    pane.PaintRow = function(_, r)
        local r1, g1, b1 = UI:Accent()
        if r.key == cfg.moneySel then r.hl:SetColor(r1, g1, b1, 0.12)
        else r.hl:SetColor(unpack(C.hover)) end
        r.hl:SetShown(r.hover or r.key == cfg.moneySel)
        r.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 0.6)
    end

    pane.Refresh = function()
        local W = math.max(640, (pane:GetWidth() or 900) - 14)
        pane.child:SetWidth(W)
        local cardW = W - DETAIL_W - 12
        card:SetWidth(cardW)
        det:ClearAllPoints(); det:SetPoint("TOPLEFT", cardW + 12, 0)
        local cat = cfg.moneyCat or "all"
        seg:Select(cat)
        local list = Cur:List(cat ~= "all" and cat or nil)
        -- colonnes : les persos qui ont au moins une monnaie de la liste, les plus riches d'abord
        local chars = WK.DB.global.characters
        local sum = {}
        for _, e in ipairs(list) do for k, n in pairs(e.per) do sum[k] = (sum[k] or 0) + n end end
        local cols = {}
        for _, e in ipairs(UI:SortedCharacters()) do if sum[e.key] then cols[#cols + 1] = e end end
        local more = #cols > MAX_COLS
        while #cols > MAX_COLS do table.remove(cols) end
        card.subtitle:SetText(string.format(T("%d monnaie(s) · %d perso(s)"), #list, #cols))
        local x0, x1 = NAME_W, cardW - 16 - TOTAL_W
        local colW = #cols > 0 and math.floor((x1 - x0) / #cols) or 0
        local hy = -50
        local h = head(1); h:ClearAllPoints(); h:SetPoint("TOPLEFT", 16, hy)
        h:SetText(UI:Upper(T("Monnaie"))); h:Show()
        for i, e in ipairs(cols) do
            h = head(i + 1); h:ClearAllPoints()
            h:SetPoint("TOPLEFT", 16 + x0 + (i - 1) * colW, hy); h:SetWidth(colW - 4); h:SetJustifyH("RIGHT")
            h:SetText(WK:CharName(e.c, e.key)); h:SetTextColor(UI:ClassColor(e.c.class)); h:Show()
        end
        h = head(#cols + 2); h:ClearAllPoints()
        h:SetPoint("TOPLEFT", 16 + x1, hy); h:SetWidth(TOTAL_W); h:SetJustifyH("RIGHT")
        h:SetText(UI:Upper(T("Compte")) .. (more and " *" or "")); h:SetTextColor(unpack(C.dim)); h:Show()
        for i = #cols + 3, #heads do heads[i]:Hide() end
        -- sélection : gardée si elle est encore là, sinon la première ligne
        local sel
        for _, e in ipairs(list) do if e.key == cfg.moneySel then sel = e end end
        if not sel and list[1] then sel = list[1]; cfg.moneySel = sel.key end
        local y = 70
        for i, e in ipairs(list) do
            local r = row(i)
            r.key = e.key
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, -y); r:SetWidth(cardW - 20)
            r.icon:SetTexture(e.icon or (UI.MEDIA .. "coin"))
            r.name:SetText(e.name)
            for k, ce in ipairs(cols) do
                local t = r.cells[k]
                local n = e.per[ce.key]
                t:ClearAllPoints(); t:SetPoint("TOPLEFT", 6 + x0 + (k - 1) * colW, -8); t:SetWidth(colW - 4)
                t:SetText(n and tostring(n) or "-")
                t:SetTextColor(unpack(n and C.text or C.dim))
                t:Show()
            end
            local tt = r.cells[#cols + 1]
            tt:ClearAllPoints(); tt:SetPoint("TOPLEFT", 6 + x1, -8); tt:SetWidth(TOTAL_W)
            tt:SetText(tostring(e.total)); tt:SetTextColor(unpack(C.gold)); tt:Show()
            for k = #cols + 2, #r.cells do r.cells[k]:Hide() end
            pane:PaintRow(r)
            r:Show()
            y = y + ROW_H
        end
        for i = #list + 1, #rows do rows[i]:Hide() end
        empty:SetShown(#list == 0)
        if #list == 0 then
            empty:ClearAllPoints(); empty:SetPoint("TOPLEFT", 16, -y); empty:SetWidth(cardW - 32)
            y = y + 40
        end
        note:ClearAllPoints(); note:SetPoint("TOPLEFT", 16, -(y + 10)); note:SetWidth(cardW - 32)
        card:SetHeight(y + 36)
        -- détail
        det:SetShown(sel ~= nil)
        local dh = 120
        if sel then
            det.icon:SetTexture(sel.icon or (UI.MEDIA .. "coin"))
            det.name:SetText(sel.name)
            local best, bestN = nil, 0
            for k, n in pairs(sel.per) do if n > bestN then best, bestN = k, n end end
            local bc = best and chars[best]
            det.sub:SetText(string.format(T("%d sur le compte"), sel.total)
                .. (bc and ("  ·  " .. string.format(T("%d sur %s"), bestN, WK:CharName(bc, best))) or ""))
            local parts = {}
            for k, n in pairs(sel.per) do parts[#parts + 1] = { k = k, n = n } end
            table.sort(parts, function(a, b) return a.n > b.n end)
            local ly = 112
            for i, pp in ipairs(parts) do
                local l = detLine(i)
                local c = chars[pp.k] or {}
                l.n:ClearAllPoints(); l.n:SetPoint("TOPLEFT", 14, -ly)
                l.n:SetText(WK:CharName(c, pp.k)); l.n:SetTextColor(UI:ClassColor(c.class))
                l.v:ClearAllPoints(); l.v:SetPoint("TOPRIGHT", -14, -ly); l.v:SetText(tostring(pp.n))
                local tot, b, k, m = Cur:Split(pp.k, sel.item)
                local bits = {}
                if tot then
                    if b > 0 then bits[#bits + 1] = string.format(T("%d sacs"), b) end
                    if k > 0 then bits[#bits + 1] = string.format(T("%d banque"), k) end
                    if m > 0 then bits[#bits + 1] = string.format(T("%d courrier"), m) end
                end
                l.s:ClearAllPoints(); l.s:SetPoint("TOPLEFT", 14, -(ly + 15))
                l.s:SetText(table.concat(bits, "  ·  "))
                l.n:Show(); l.v:Show(); l.s:SetShown(#bits > 0)
                ly = ly + (#bits > 0 and 34 or 20)
            end
            for i = #parts + 1, #det.lines do local l = det.lines[i]; l.n:Hide(); l.v:Hide(); l.s:Hide() end
            det.h2:ClearAllPoints(); det.h2:SetPoint("TOPLEFT", 14, -(ly + 10))
            det.where:ClearAllPoints(); det.where:SetPoint("TOPLEFT", 14, -(ly + 28))
            det.where:SetText(T(Cur.WHERE[sel.cat] or ""))
            dh = ly + 28 + math.ceil(det.where:GetStringHeight() or 14) + 16
        end
        det:SetHeight(dh)
        pane:SetContentHeight(math.max(y + 36, dh) + 10)
    end
    UI:OnResize(pane, function() if pane:IsShown() then pane:Refresh() end end)
    return pane
end
