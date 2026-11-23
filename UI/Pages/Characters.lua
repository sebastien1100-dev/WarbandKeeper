local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Colonnes : { libellé, x, alignement }
-- Positions prévues pour 924 px de large, mises à l'échelle à la construction.
local BASE_COLS = {
    { "Personnage", 52, "LEFT" },
    { "Niveau", 262, "LEFT" },
    { "Or", 430, "RIGHT" },
    { "Temps de jeu", 462, "LEFT" },
    { "Banque", 582, "LEFT" },
    { "Courrier", 700, "LEFT" },
    { "Vu", 802, "LEFT" },
}
local COLS = {}

UI:RegisterPage({
    key = "characters", order = 2, nav = "Persos",
    title = "Personnages",
    subtitle = "Tous tes personnages enregistrés. Clic sur un perso : sa fiche. Maj + clic sur la corbeille pour en oublier un.",
    count = function()
        local n = 0
        for _ in pairs(WK.DB.global.characters) do n = n + 1 end
        return tostring(n)
    end,

    Build = function(self, p)
        local k = UI.PAGE_W / 924
        for i, c in ipairs(BASE_COLS) do COLS[i] = { c[1], math.floor(c[2] * k), c[3] } end
        self.page = p
        self.colHeaders = {}
        for i, col in ipairs(BASE_COLS) do
            local t = UI:Text(p, 10, C.dim)
            if col[3] == "RIGHT" then t:SetJustifyH("RIGHT") end
            t:SetText(UI:Upper(T(col[1])))
            self.colHeaders[i] = t
        end

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", 0, -24)
        scroll:SetPoint("BOTTOMRIGHT")
        -- Bouton « Expérience » (en haut à droite) : rythme de la session et repos de tous tes persos
        -- (cartes reprises de QoL > Expérience, qui ne garde que les réglages de la barre)
        self.xp = UI:PageGear(p, { title = "Expérience : rythme et repos de tes persos", icon = "chart", size = 26, top = 24, columns = 1,
            cards = function()
                local out = {}
                for _, c in ipairs(UI:SectionCards("qol", "xp")) do if c.xpData then table.insert(out, c) end end
                return out
            end,
            onToggle = function(open)
                for _, h in ipairs(self.colHeaders or {}) do h:SetShown(not open) end
                self.xpTitle:SetShown(open)
                if self.share then self.share:SetShown(not open) end
            end }, self)
        self.xp.gear:SetPoint("TOPRIGHT", 0, 2)
        -- au-dessus du volet (qui commence juste sous la ligne des titres de colonnes)
        self.xp.gear:SetFrameLevel(self.xp.overlay:GetFrameLevel() + 5)
        -- Carte de la Warband (maquette A) : résumé de tes persos à copier pour Discord ou la guilde
        self.share = UI:IconButton(p, "send", 26, T("Carte de la Warband : partager tes persos"))
        self.share:SetPoint("RIGHT", self.xp.gear, "LEFT", -6, 0)
        self.share:SetFrameLevel(self.xp.overlay:GetFrameLevel() + 5)
        self.share:SetScript("OnClick", function() UI:ShowWarbandCard() end)
        self.xpTitle = UI:Text(p, 12)
        self.xpTitle:SetPoint("TOPLEFT", 4, -4)
        self.xpTitle:SetText(T("Expérience de tes persos"))
        self.xpTitle:Hide()
        self.scroll = scroll
        local child = scroll.child

        local function cell(r, color)
            return UI:Text(r, 12, color)
        end

        self.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, child)
            r:SetHeight(50)
            UI:Panel(r, 12, C.surface, C.border)
            r.icon = UI:RoundIcon(r, 28)
            r.icon:SetPoint("LEFT", 12, 0)
            r.name = UI:Text(r, 13)
            r.name:SetPoint("TOPLEFT", 52, -10)
            r.realm = UI:Text(r, 10, C.muted)
            r.realm:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.badge = UI:Badge(r, "connecté")
            r.badge:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
            -- alertes du perso (sacs, banque, réparation…) en petites icônes
            r.alerts = UI:CharAlertIcons(r)
            r.level = cell(r)
            r.gold = UI:Text(r, 12)
            r.gold:SetJustifyH("RIGHT")
            r.played = cell(r, C.muted)
            r.bank = cell(r, C.muted)
            r.mail = cell(r, C.muted)
            r.seen = cell(r, C.muted)
            -- Clic droit : corriger le nom complet (« Prénom Nom »).
            UI:HoverRow(r, r.border, r.bg, nil, function(s, button)
                if button == "RightButton" and s.key then UI:EditCharName(s.key)
                elseif button == "LeftButton" and s.key then UI:ShowCharSheet(s.key) end
            end)
            r:HookScript("OnEnter", function(s)
                WK.UI:TooltipOwner(s, "ANCHOR_CURSOR")
                GameTooltip:SetText(WK.T("Clic : fiche du personnage"), 1, 1, 1)
                GameTooltip:AddLine(WK.T("Clic droit : corriger le nom complet"), 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end)
            r:HookScript("OnLeave", function() GameTooltip:Hide() end)
            r.del = UI:IconButton(r, "trash", 26, "Maj + clic : oublier ce personnage", true)
            r:HoverChild(r.del)
            r.del:SetPoint("RIGHT", -10, 0)
            r.del:SetScript("OnClick", function(btn)
                if IsShiftKeyDown() and btn.key then WK.modules.Characters:Delete(btn.key) end
            end)
            self:PlaceRow(r)
            return r
        end)
        UI:OnResize(p, function(w) self:PlaceColumns(w) end)
        self:BuildGoals(child)
        self:BuildMoney(child)
    end,

    -- Monnaies du compte (maquette A) : tableau monnaies × persos sous les Objectifs, mêmes catégories que
    -- Inventaire > Monnaies (Modules/Currency.lua) ; filtre retenu dans settings.ui.persoMoneyCat
    BuildMoney = function(self, child)
        local Cur = WK.modules.Currency
        local head = _G.CreateFrame("Frame", nil, child)
        head:SetHeight(30)
        head.t = UI:Text(head, 14); head.t:SetPoint("LEFT", 4, 0); head.t:SetText(T("Monnaies"))
        head.n = UI:Text(head, 11, C.muted); head.n:SetPoint("LEFT", head.t, "RIGHT", 10, 0)
        local opts = { { "all", T("Tout") } }
        for _, c in ipairs(Cur and Cur.CATS or {}) do opts[#opts + 1] = { c[1], T(c[2]) } end
        head.seg = UI:Segmented(head, opts, function(k)
            WK.DB.global.settings.ui.persoMoneyCat = k; UI:Refresh()
        end, 26)
        head.seg:SetPoint("RIGHT", 0, 0)
        head.seg:Select(WK.DB.global.settings.ui.persoMoneyCat or "all")
        self.moneyHead = head
        local card = UI:Card(child)
        self.moneyCard = card
        card.heads = UI:Pool(function()
            local t = UI:Text(card, 10, C.dim); t:SetJustifyH("RIGHT")
            return t
        end)
        self.moneyRows = UI:Pool(function()
            local r = _G.CreateFrame("Button", nil, card)
            r:SetHeight(36)
            r.line = r:CreateTexture(nil, "ARTWORK"); r.line:SetTexture("Interface\\Buttons\\WHITE8X8")
            r.line:SetVertexColor(C.border[1], C.border[2], C.border[3], 1); r.line:SetHeight(1)
            r.line:SetPoint("TOPLEFT"); r.line:SetPoint("TOPRIGHT")
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 12, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 42, -5)
            r.cat = UI:Text(r, 10, C.dim); r.cat:SetPoint("TOPLEFT", 42, -20)
            r.cells = {}
            r.total = UI:Text(r, 12, C.gold); r.total:SetJustifyH("RIGHT")
            r:SetScript("OnEnter", function(b)
                local e = b.e
                if not e then return end
                UI:TooltipOwner(b, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(e.name or "?", 1, 1, 1)
                local chars = WK.DB.global.characters
                for _, ce in ipairs(UI:SortedCharacters()) do
                    local n = e.per[ce.key]
                    if n and n > 0 then
                        local cr, cg, cb = UI:ClassColor(ce.c.class)
                        local detail = tostring(n)
                        if e.item and Cur then
                            local _, bg, bk, ml = Cur:Split(ce.key, e.item)
                            local parts = {}
                            if (bg or 0) > 0 then parts[#parts + 1] = string.format(T("sacs %d"), bg) end
                            if (bk or 0) > 0 then parts[#parts + 1] = string.format(T("banque %d"), bk) end
                            if (ml or 0) > 0 then parts[#parts + 1] = string.format(T("courrier %d"), ml) end
                            if #parts > 0 then detail = detail .. "  (" .. table.concat(parts, ", ") .. ")" end
                        end
                        _G.GameTooltip:AddDoubleLine(WK:CharName(chars[ce.key], ce.key), detail, cr, cg, cb, 1, 1, 1)
                    end
                end
                local where = Cur and Cur.WHERE and Cur.WHERE[e.cat]
                if where then
                    _G.GameTooltip:AddLine(" ")
                    _G.GameTooltip:AddLine(T(where), 0.7, 0.7, 0.7, true)
                end
                _G.GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
            return r
        end)
    end,

    RefreshMoney = function(self, y)
        local Cur = WK.modules.Currency
        local head, card = self.moneyHead, self.moneyCard
        if not (Cur and head) then return y end
        local cat = WK.DB.global.settings.ui.persoMoneyCat or "all"
        local okL, list = pcall(Cur.List, Cur, cat ~= "all" and cat or nil)
        list = okL and list or {}
        local okA, everything = pcall(Cur.List, Cur, nil)
        local any = okA and everything and #everything > 0
        head:SetShown(any); card:SetShown(any)
        self.moneyRows:Reset(); card.heads:Reset()
        if not any then return y end
        y = y + 14
        head:ClearAllPoints(); head:SetPoint("TOPLEFT", 0, -y); head:SetPoint("TOPRIGHT", 0, -y)
        head.seg:Select(cat)
        local chars = UI:SortedCharacters()
        head.n:SetText(string.format(T("%d monnaie(s) · %d perso(s)"), #list, #chars))
        y = y + 38
        local W = card:GetWidth() > 0 and card:GetWidth() or (self.scroll:GetWidth() - 14)
        local NAMEW, TOTW = math.max(220, W * 0.3), 90
        local cw = math.max(70, (W - NAMEW - TOTW - 24) / math.max(1, #chars))
        -- en-tête des colonnes : un perso par colonne (couleur de classe), puis le total
        local hy = 10
        for i, ce in ipairs(chars) do
            local t = card.heads:Get()
            t:ClearAllPoints(); t:SetPoint("TOPRIGHT", card, "TOPLEFT", NAMEW + i * cw, -hy); t:SetWidth(cw - 8)
            t:SetText(WK:CharName(ce.c, ce.key)); t:SetTextColor(UI:ClassColor(ce.c.class))
            if t.SetWordWrap then t:SetWordWrap(false) end
            t:Show()
        end
        local tt = card.heads:Get()
        tt:ClearAllPoints(); tt:SetPoint("TOPRIGHT", card, "TOPRIGHT", -12, -hy); tt:SetWidth(TOTW)
        tt:SetText(UI:Upper(T("Total"))); tt:SetTextColor(C.dim[1], C.dim[2], C.dim[3]); tt:Show()
        local ry = 30
        local catName = {}
        for _, c in ipairs(Cur.CATS or {}) do catName[c[1]] = T(c[2]) end
        for _, e in ipairs(list) do
            local r = self.moneyRows:Get()
            r.e = e
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -ry)
            r:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -ry)
            r.icon:SetTexture(e.icon or 134400)
            r.name:SetText(e.name or "?"); r.cat:SetText(catName[e.cat] or "")
            for i, ce in ipairs(chars) do
                local cell = r.cells[i]
                if not cell then
                    cell = UI:Text(r, 12); cell:SetJustifyH("RIGHT"); r.cells[i] = cell
                end
                cell:ClearAllPoints(); cell:SetPoint("RIGHT", r, "LEFT", NAMEW + i * cw, 0); cell:SetWidth(cw - 8)
                local n = e.per[ce.key] or 0
                cell:SetText(n > 0 and tostring(n) or "-")
                local col = n > 0 and C.text or C.dim
                cell:SetTextColor(col[1], col[2], col[3]); cell:Show()
            end
            for i = #chars + 1, #r.cells do r.cells[i]:Hide() end
            r.total:ClearAllPoints(); r.total:SetPoint("RIGHT", -12, 0); r.total:SetWidth(TOTW)
            r.total:SetText(tostring(e.total or 0))
            r:Show()
            ry = ry + 36
        end
        if #list == 0 then ry = ry + 30 end
        card:ClearAllPoints(); card:SetPoint("TOPLEFT", 0, -y); card:SetPoint("TOPRIGHT", 0, -y)
        card:SetHeight(ry + 6)
        return y + ry + 6
    end,

    -- Objectifs de la Warband (maquette D, Modules/CharGoals.lua) : un objectif par ligne, jauge et temps
    -- restant, du plus proche au plus lointain ; « + Objectif » ouvre la ligne d'ajout
    BuildGoals = function(self, child)
        local CG = WK.modules.CharGoals
        local head = _G.CreateFrame("Frame", nil, child)
        head:SetHeight(30)
        head.t = UI:Text(head, 14); head.t:SetPoint("LEFT", 4, 0); head.t:SetText(T("Objectifs de la Warband"))
        head.n = UI:Text(head, 11, C.muted); head.n:SetPoint("LEFT", head.t, "RIGHT", 10, 0)
        head.add = UI:Button(head, "+ Objectif", nil, 26, "secondary")
        head.add:SetPoint("RIGHT", 0, 0)
        self.goalHead = head
        -- ligne d'ajout : perso, genre, métier (si métier), cible, Ajouter
        local form = _G.CreateFrame("Frame", nil, child)
        form:SetHeight(46)
        UI:Panel(form, 10, C.surface2, C.border)
        form:Hide()
        self.goalForm = form
        local st = { kind = "level" }
        form.who = UI:Dropdown(form, 160, 28, {}, function(v) st.key = v; self:FillGoalProfs(st) end)
        form.who:SetPoint("LEFT", 10, 0)
        local kinds = {}
        for _, k in ipairs(CG.KINDS) do kinds[#kinds + 1] = { k, T(CG.LABELS[k]) } end
        form.kind = UI:Dropdown(form, 120, 28, kinds, function(v)
            st.kind = v
            form.prof:SetShown(v == "prof")
            form.target:SetShown(v ~= "bis")
        end)
        form.kind:SetPoint("LEFT", form.who, "RIGHT", 8, 0)
        form.prof = UI:Dropdown(form, 140, 28, {}, function(v) st.prof = v end)
        form.prof:SetPoint("LEFT", form.kind, "RIGHT", 8, 0)
        form.prof:Hide()
        form.target = UI:Input(form, 110, 28, T("cible"))
        form.target:SetPoint("LEFT", form.kind, "RIGHT", 156, 0)
        form.ok = UI:Button(form, "Ajouter", nil, 28, "primary")
        form.ok:SetPoint("RIGHT", -10, 0)
        form.msg = UI:Text(form, 10, C.negative)
        form.msg:SetPoint("RIGHT", form.ok, "LEFT", -10, 0)
        form.ok:SetScript("OnClick", function()
            local g, err = CG:Add(st.key, st.kind, form.target.edit:GetText(), st.kind == "prof" and st.prof or nil)
            if not g then form.msg:SetText(err or ""); return end
            form.msg:SetText("")
            form.target.edit:SetText("")
            form:Hide()
            self:Refresh()
        end)
        self.goalState = st
        head.add:SetScript("OnClick", function()
            form:SetShown(not form:IsShown())
            if form:IsShown() then
                local opts = {}
                for _, e in ipairs(UI:SortedCharacters()) do opts[#opts + 1] = { e.key, WK:CharName(e.c, e.key) } end
                form.who:SetOptions(opts)
                st.key = st.key or WK:CharKey()
                form.who:Select(st.key)
                form.kind:Select(st.kind)
                self:FillGoalProfs(st)
                form.msg:SetText("")
            end
            self:Refresh()
        end)
        self.goalRows = UI:Pool(function()
            local r = _G.CreateFrame("Button", nil, child)
            r:SetHeight(40)
            UI:Panel(r, 10, C.surface, C.border)
            r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 14, 0); r.name:SetWidth(130); r.name:SetJustifyH("LEFT")
            r.title = UI:Text(r, 12); r.title:SetPoint("LEFT", 150, 7); r.title:SetJustifyH("LEFT")
            r.eta = UI:Text(r, 10, C.muted); r.eta:SetPoint("LEFT", 150, -8); r.eta:SetJustifyH("LEFT")
            r.del = UI:IconButton(r, "trash", 22, "Retirer cet objectif", true)
            r.del:SetPoint("RIGHT", -10, 0)
            r.del:SetScript("OnClick", function(b) if b.key then CG:Remove(b.key, b.i); self:Refresh() end end)
            r.val = UI:Text(r, 11, C.muted); r.val:SetPoint("RIGHT", r.del, "LEFT", -12, 0); r.val:SetJustifyH("RIGHT")
            r.bar = UI:Progress(r, 6)
            r.bar:SetPoint("RIGHT", r.val, "LEFT", -12, 0); r.bar:SetWidth(160)
            return r
        end)
        self.goalEmpty = UI:Text(child, 11, C.muted)
        self.goalEmpty:SetText(T("Aucun objectif : « + Objectif » pour viser un niveau, une somme d'or, "
            .. "un palier de métier ou ta liste BiS."))
    end,

    FillGoalProfs = function(self, st)
        local c = WK.DB.global.characters[st.key or ""]
        local opts = {}
        for prof, pp in pairs(c and c.professions or {}) do
            if type(pp) == "table" then opts[#opts + 1] = { prof, T(prof) .. " (" .. (pp.rank or 0) .. ")" } end
        end
        table.sort(opts, function(a, b) return a[1] < b[1] end)
        self.goalForm.prof:SetOptions(opts)
        st.prof = opts[1] and opts[1][1] or nil
        if st.prof then self.goalForm.prof:Select(st.prof) end
    end,

    RefreshGoals = function(self, y)
        local CG = WK.modules.CharGoals
        local all = CG:All()
        local head, form = self.goalHead, self.goalForm
        y = y + 14
        head:ClearAllPoints(); head:SetPoint("TOPLEFT", 0, -y); head:SetPoint("TOPRIGHT", 0, -y)
        local open = 0
        for _, e in ipairs(all) do if not e.p.done then open = open + 1 end end
        head.n:SetText(string.format(T("%d en cours"), open))
        y = y + 36
        if form:IsShown() then
            form:ClearAllPoints(); form:SetPoint("TOPLEFT", 0, -y); form:SetPoint("TOPRIGHT", 0, -y)
            y = y + 52
        end
        self.goalRows:Reset()
        for _, e in ipairs(all) do
            local r = self.goalRows:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -y); r:SetPoint("TOPRIGHT", 0, -y)
            local c = WK.DB.global.characters[e.key]
            r.name:SetText(WK:CharName(c, e.key)); r.name:SetTextColor(UI:ClassColor(c.class))
            r.title:SetText(e.p.title)
            r.eta:SetText(e.p.eta or "")
            r.eta:SetTextColor(unpack(e.p.done and C.positive or C.muted))
            r.val:SetText(e.p.value or "")
            r.bar.color = e.p.done and { C.positive[1], C.positive[2], C.positive[3], 1 } or nil
            r.bar:SetValue(e.p.pct or 0)
            r.del.key, r.del.i = e.key, e.i
            r:Show()
            y = y + 46
        end
        self.goalEmpty:ClearAllPoints(); self.goalEmpty:SetPoint("TOPLEFT", 4, -y)
        self.goalEmpty:SetShown(#all == 0)
        if #all == 0 then y = y + 24 end
        return y
    end,

    -- Colonnes proportionnelles à la largeur (prévues pour 924 px).
    PlaceColumns = function(self, w)
        local k = (w or UI.PAGE_W) / 924
        for i, c in ipairs(BASE_COLS) do COLS[i] = { c[1], math.floor(c[2] * k), c[3] } end
        for i, t in ipairs(self.colHeaders) do
            t:ClearAllPoints()
            if COLS[i][3] == "RIGHT" then
                t:SetPoint("TOPRIGHT", self.page, "TOPLEFT", COLS[i][2], -4)
            else
                t:SetPoint("TOPLEFT", self.page, "TOPLEFT", COLS[i][2], -4)
            end
        end
        for _, r in ipairs(self.rows.items) do self:PlaceRow(r) end
    end,

    PlaceRow = function(self, r)
        r.realm:SetWidth(math.max(60, COLS[2][2] - 52 - 10))
        local cells = { { r.level, 2 }, { r.played, 4 }, { r.bank, 5 }, { r.mail, 6 }, { r.seen, 7 } }
        for _, c in ipairs(cells) do
            c[1]:ClearAllPoints()
            c[1]:SetPoint("LEFT", r, "LEFT", COLS[c[2]][2], 0)
        end
        r.gold:ClearAllPoints()
        r.gold:SetPoint("RIGHT", r, "LEFT", COLS[3][2], 0)
    end,

    Refresh = function(self)
        if self.xp and self.xp:IsOpen() then self.xp:Refresh() end
        self.rows:Reset()
        local me = WK:CharKey()
        local y = 0
        for _, e in ipairs(UI:SortedCharacters()) do
            local r = self.rows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local c = e.c
            UI:SetCharIcon(r.icon, c, e.key)
            r.key = e.key
            r.name:SetText(WK:CharName(c, e.key))
            -- Nom long : borné à sa colonne (place gardée pour le badge « connecté »).
            local aw = r.alerts:Set(e.key)
            local maxW = COLS[2][2] - 52 - 12 - (e.key == me and (r.badge:GetWidth() + 8) or 0) - (aw > 0 and aw + 8 or 0)
            r.name:SetWidth(math.max(40, math.min(maxW, r.name:GetStringWidth() + 2)))
            r.name:SetTextColor(UI:ClassColor(c.class))
            r.realm:SetText(UI:FactionRealm(c))
            r.badge:SetShown(e.key == me)
            r.alerts:ClearAllPoints()
            r.alerts:SetPoint("LEFT", e.key == me and r.badge or r.name, "RIGHT", 6, 0)
            r.level:SetText(tostring(c.level or "-"))
            r.gold:SetText(UI:GoldText(c.money))
            r.played:SetText(WK:FormatTime(c.played))

            -- Banque et courrier, en orange quand une alerte les concerne.
            local warnBank, warnMail = false, false
            for _, a in ipairs(WK.modules.Alerts:For(c, e.key)) do
                if a.kind == "bank" then warnBank = true else warnMail = true end
            end
            r.bank:SetText(c.bankScanned and UI:Ago(c.bankScanned) or T("jamais"))
            r.bank:SetTextColor(unpack(warnBank and C.warning or C.muted))
            local box = c.mailbox
            if box and (box.count or 0) > 0 then
                local txt = string.format((box.count > 1) and T("%d lettres") or T("%d lettre"), box.count)
                if box.expiresAt then
                    local d = math.max(0, math.floor((box.expiresAt - time()) / 86400))
                    txt = txt .. " · " .. string.format(T("%d j"), d)
                end
                r.mail:SetText(txt)
            else
                r.mail:SetText(box and T("vide") or "-")
            end
            r.mail:SetTextColor(unpack(warnMail and C.warning or C.muted))

            r.seen:SetText(e.key == me and T("maintenant") or UI:Ago(c.lastSeen))
            r.del.key = e.key
            r:PaintHover()
            r.del:SetShown(e.key ~= me)
            y = y + 56
        end
        y = self:RefreshGoals(y)
        y = self:RefreshMoney(y)
        self.scroll:SetContentHeight(y)
    end,
})

---------------------------------------------------------------------------
-- Fenêtre « Carte de la Warband » (maquette A) : options à gauche, texte prêt à copier à droite.
-- Le jeu n'écrit pas dans le presse-papiers : « Tout sélectionner » puis Ctrl+C. Guilde : le message est posé
-- dans la boîte de discussion du chat de guilde, le joueur appuie sur Entrée (jamais envoyé tout seul).
---------------------------------------------------------------------------
local card
local function buildCard()
    local Ch = WK.modules.Characters
    local f = _G.CreateFrame("Frame", "WarbandKeeperWarbandCard", _G.UIParent)
    f:SetSize(640, 330); f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI:HudBackground(f, "window")
    f.title = UI:Text(f, 14); f.title:SetPoint("TOPLEFT", 16, -14); f.title:SetText(T("Carte de la Warband"))
    f.close = UI:IconButton(f, "close", 22, T("Fermer"))
    f.close:SetPoint("TOPRIGHT", -10, -10)
    f.close:SetScript("OnClick", function() f:Hide() end)
    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "WarbandKeeperWarbandCard") end

    local y = -48
    local function label(text)
        local t = UI:Text(f, 11, C.muted); t:SetPoint("TOPLEFT", 16, y); t:SetText(T(text))
        y = y - 20
    end
    local function chips(items, isOn, onClick)
        local x, row = 16, {}
        for _, it in ipairs(items) do
            local b = UI:Button(f, T(it[2]), nil, 24, "ghost")
            if x + b:GetWidth() > 216 then x = 16; y = y - 28 end
            b:SetPoint("TOPLEFT", x, y)
            x = x + b:GetWidth() + 5
            b:SetScript("OnClick", function() onClick(it[1]); f:Refresh() end)
            row[it[1]] = b
        end
        y = y - 36
        table.insert(f.chipRows, function()
            for k, b in pairs(row) do b:SetStyle(isOn(k) and "primary" or "ghost") end
        end)
    end
    f.chipRows = {}
    local cfg = Ch.CardConfig
    label("Format")
    chips({ { "discord", "Discord" }, { "guild", "Guilde" } }, function(k) return cfg().fmt == k end,
        function(k) cfg().fmt = k end)
    label("Montrer")
    chips({ { "level", "Niveaux" }, { "prof", "Métiers" }, { "gold", "Or" }, { "ilvl", "Niv. objet" },
        { "rest", "Repos" } },
        function(k) return cfg().show[k] end, function(k) local sh = cfg().show; sh[k] = not sh[k] end)
    label("Persos")
    chips({ { "all", "Tous" }, { "max", "Niveau max" } }, function(k) return cfg().who == k end,
        function(k) cfg().who = k end)

    -- texte : zone qui défile, éditable (on peut retoucher avant de copier)
    local box = _G.CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 236, -48); box:SetPoint("BOTTOMRIGHT", -16, 52)
    UI:Panel(box, 8, C.bg, C.border)
    local sc = _G.CreateFrame("ScrollFrame", nil, box)
    sc:SetPoint("TOPLEFT", 8, -8); sc:SetPoint("BOTTOMRIGHT", -8, 8)
    local eb = _G.CreateFrame("EditBox", nil, sc)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetWidth(370)
    eb:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlight)
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    eb:SetScript("OnCursorChanged", function(_, _, cy, _, h)
        local off = sc:GetVerticalScroll()
        if -cy < off then sc:SetVerticalScroll(-cy)
        elseif -cy + h > off + sc:GetHeight() then sc:SetVerticalScroll(math.max(0, -cy + h - sc:GetHeight())) end
    end)
    sc:SetScrollChild(eb)
    sc:EnableMouseWheel(true)
    sc:SetScript("OnMouseWheel", function(s, d)
        local maxS = math.max(0, eb:GetHeight() - s:GetHeight())
        s:SetVerticalScroll(math.min(maxS, math.max(0, s:GetVerticalScroll() - d * 30)))
    end)
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)
    f.eb = eb

    f.select = UI:Button(f, T("Tout sélectionner"), nil, 28, "primary")
    f.select:SetPoint("BOTTOMLEFT", 236, 14)
    f.select:SetScript("OnClick", function() eb:SetFocus(); eb:HighlightText() end)
    f.hint = UI:Text(f, 11, C.muted)
    f.hint:SetPoint("LEFT", f.select, "RIGHT", 10, 0)
    f.toChat = UI:Button(f, T("Mettre dans le chat de guilde"), nil, 28, "primary")
    f.toChat:SetPoint("BOTTOMLEFT", 236, 14)
    f.toChat:SetScript("OnClick", function()
        local msgs = f.msgs or {}
        local i = f.part or 1
        local text = msgs[i]
        if not text then return end
        if _G.IsInGuild and not _G.IsInGuild() then WK:Print(T("Tu n'es pas dans une guilde.")) return end
        if _G.ChatFrame_OpenChat then
            _G.ChatFrame_OpenChat(text)
            local ceb = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow()
            if ceb and ceb.SetAttribute then
                ceb:SetAttribute("chatType", "GUILD")
                if _G.ChatEdit_UpdateHeader then pcall(_G.ChatEdit_UpdateHeader, ceb) end
            end
        end
        f.part = (i % #msgs) + 1
        f:PaintChat()
    end)

    function f:PaintChat()
        local n = #(self.msgs or {})
        local lbl = T("Mettre dans le chat de guilde")
        if n > 1 then lbl = lbl .. string.format(" (%d/%d)", self.part or 1, n) end
        self.toChat.label:SetText(lbl)
        if self.toChat.Fit then self.toChat:Fit() end
    end
    function f:Refresh()
        for _, fn in ipairs(self.chipRows) do fn() end
        local c = cfg()
        local out = Ch:CardText(c, UI.AverageIlvl)
        if type(out) == "table" then
            self.msgs, self.part = out, 1
            self.eb:SetText(table.concat(out, "\n\n"))
            self.select:Hide(); self.toChat:Show()
            self.hint:ClearAllPoints(); self.hint:SetPoint("LEFT", self.toChat, "RIGHT", 10, 0)
            self.hint:SetText(T("puis Entrée pour l'envoyer"))
            self:PaintChat()
        else
            self.msgs = nil
            self.eb:SetText(out)
            self.toChat:Hide(); self.select:Show()
            self.hint:ClearAllPoints(); self.hint:SetPoint("LEFT", self.select, "RIGHT", 10, 0)
            self.hint:SetText(T("puis Ctrl+C · colle dans Discord"))
        end
        self.eb:SetCursorPosition(0)
    end
    f:SetScript("OnShow", function(s) s:Refresh() end)
    return f
end
function UI.ShowWarbandCard()
    card = card or buildCard()
    if card:IsShown() then card:Refresh() else card:Show() end
    return card
end
