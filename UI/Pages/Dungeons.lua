local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page « Donjons » (groupe Exploration) : tuiles des donjons par niveau (couleur selon le niveau du perso
-- choisi, barre = boss tués au moins une fois), puis les boss du donjon choisi et leur butin, filtré
-- « Pour <perso> » ou « Tout », avec la liste d'envies (étoile). Le détail a deux onglets : « Butin » (boss et
-- monstres du donjon) et « Quêtes » (quêtes du donjon pour le perso, filtre À faire / Toutes).
-- Onglet « Mes envies » : tous les objets voulus, par perso. Boutons : panneau en jeu, Chercher un groupe
-- (LFG), Guider vers l'entrée.
local D = WK.modules.Dungeons
local TILE_W, TILE_H, GAP, ITEM_H = 200, 64, 10, 22

local function levelColor(d, lvl)
    if lvl < d.min - 2 then return C.negative end
    if lvl < d.min then return C.warning end
    if lvl > d.max + 2 then return C.dim end
    return C.positive
end

UI:RegisterPage({
    key = "dungeons", order = 8.95, nav = "Donjons",

    Build = function(self, p)
        self.viewKey = WK:CharKey()
        self.tab = "list"
        self.filter = "me"
        self.dtab = "loot"     -- onglet du détail : butin ou quêtes
        self.qfilter = "todo"  -- quêtes : à faire ou toutes
        local cur = D:Current()
        self.sel = cur and cur.key or nil

        self.tabSeg = UI:Segmented(p, { { "list", "Donjons" }, { "wish", "Mes envies" } },
            function(v) self.tab = v; self:Refresh() end, 30)
        self.tabSeg:SetPoint("TOPLEFT")
        local charOpts = {}
        for key, c in pairs(WK.DB.global.characters) do table.insert(charOpts, { key, WK:CharName(c, key), { UI:ClassColor(c.class) } }) end
        table.sort(charOpts, function(a, b) return a[2] < b[2] end)
        self.charDd = UI:Dropdown(p, 190, 30, charOpts, function(v) self.viewKey = v; self:Refresh() end)
        self.charDd:SetPoint("TOPRIGHT")
        self.charDd:Select(self.viewKey)
        local of = UI:Text(p, 11, C.muted)
        of:SetPoint("RIGHT", self.charDd, "LEFT", -8, 0)
        of:SetText(T("Pour"))

        local sc = UI:Scroll(p)
        sc:SetPoint("TOPLEFT", 0, -42)
        sc:SetPoint("BOTTOMRIGHT")
        self.sc = sc
        local root = sc.child

        -- tuiles
        self.tiles = UI:Pool(function()
            local t = CreateFrame("Button", nil, root)
            t:SetSize(TILE_W, TILE_H)
            t.edge = UI:Rounded(t, 12, 0, "BACKGROUND", 0)
            t.bg = UI:Rounded(t, 11, 1, "BACKGROUND", 1)
            t.name = UI:Text(t, 12)
            t.name:SetPoint("TOPLEFT", 12, -10)
            t.name:SetPoint("RIGHT", -10, 0)
            t.name:SetJustifyH("LEFT")
            t.name:SetWordWrap(false)
            t.sub = UI:Text(t, 10, C.muted)
            t.sub:SetPoint("TOPLEFT", t.name, "BOTTOMLEFT", 0, -3)
            t.bar = UI:Progress(t, 4)
            t.bar:SetPoint("BOTTOMLEFT", 12, 10)
            t.bar:SetPoint("BOTTOMRIGHT", -12, 10)
            t:SetScript("OnClick", function(s) self.sel = s.key; self:Refresh() end)
            return t
        end)

        -- détail du donjon choisi
        local det = UI:Card(root)
        self.det = det
        det.title = UI:Text(det, 15)
        det.title:SetPoint("TOPLEFT", 14, -12)
        det.sub = UI:Text(det, 11, C.muted)
        det.sub:SetPoint("LEFT", det.title, "RIGHT", 10, 0)
        det.filter = UI:Segmented(det, { { "me", "Pour ce perso" }, { "all", "Tout" } }, function(v) self.filter = v; self:Refresh() end, 24)
        det.filter:SetPoint("TOPRIGHT", -12, -10)
        det.qfilter = UI:Segmented(det, { { "todo", "À faire" }, { "all", "Toutes" } }, function(v) self.qfilter = v; self:Refresh() end, 24)
        det.qfilter:SetPoint("TOPRIGHT", -12, -10)
        -- onglets Butin / Quêtes : libellé, pastille (nombre), soulignement de l'onglet choisi
        det.tabLine = det:CreateTexture(nil, "ARTWORK")
        det.tabLine:SetHeight(1)
        det.tabLine:SetPoint("TOPLEFT", 14, -72)
        det.tabLine:SetPoint("TOPRIGHT", -14, -72)
        det.tabs = {}
        local function tab(key, label)
            local b = CreateFrame("Button", nil, det)
            b:SetHeight(30)
            b.label = UI:Text(b, 13)
            b.label:SetPoint("LEFT", 10, 0)
            b.label:SetText(T(label))
            b.badge = UI:Badge(b, "", C.muted)
            b.badge:SetPoint("LEFT", b.label, "RIGHT", 7, 0)
            b.under = CreateFrame("Frame", nil, b)
            b.under:SetHeight(2)
            b.under:SetPoint("BOTTOMLEFT", 0, -1)
            b.under:SetPoint("BOTTOMRIGHT", 0, -1)
            b.underTex = UI:Rounded(b.under, 1, 0, "OVERLAY", 2)
            -- col : couleur de la pastille (nil = couleur de l'addon) ; keep : la garder même onglet pas choisi
            function b:Paint(sel, count, col, keep)
                self.badge:Set(count or "", (sel or keep) and col or (not sel and C.muted or nil))
                self.badge:SetShown(count ~= nil and count ~= "")
                self:SetWidth(self.label:GetStringWidth() + 20 + (self.badge:IsShown() and self.badge:GetWidth() + 7 or 0))
                -- onglet choisi en blanc, l'autre à la couleur de l'apparence (comme les boutons)
                local r, g, bl = UI:Accent()
                if sel then self.label:SetTextColor(unpack(C.text)) else self.label:SetTextColor(r, g, bl, self.hover and 1 or 0.85) end
                self.under:SetShown(sel)
                self.underTex:SetColor(UI:Accent())
            end
            local function recolor(s)
                if s.under:IsShown() then return end
                local r, g, bl = UI:Accent()
                s.label:SetTextColor(r, g, bl, s.hover and 1 or 0.85)
            end
            b:SetScript("OnEnter", function(s) s.hover = true; recolor(s) end)
            b:SetScript("OnLeave", function(s) s.hover = false; recolor(s) end)
            b:SetScript("OnClick", function() self.dtab = key; self:Refresh() end)
            det.tabs[key] = b
            return b
        end
        tab("loot", "Butin"):SetPoint("TOPLEFT", 14, -42)
        tab("quests", "Quêtes"):SetPoint("LEFT", det.tabs.loot, "RIGHT", 8, 0)
        det.quests = UI:Text(det, 11, C.muted)
        det.lfg = UI:Button(det, "Chercher un groupe", nil, 26, "secondary", "lfg")
        det.lfg:SetScript("OnClick", function() UI:ShowPage("lfg") end)
        det.go = UI:Button(det, "Guider vers l'entrée", nil, 26, "ghost", "guide")
        det.go:SetScript("OnClick", function() local d = D:Get(self.sel); if d then D:GuideTo(d) end end)
        det.pnl = UI:Button(det, "Panneau en jeu", nil, 26, "ghost")
        det.pnl:SetScript("OnClick", function() local d = D:Get(self.sel); if d then UI:ToggleDungeonPanel(d) end end)
        self.bheads = UI:Pool(function()
            local h = CreateFrame("Frame", nil, det)
            h:SetHeight(26)
            h.bg = UI:Rounded(h, 7, 0, "BACKGROUND", 1)
            h.name = UI:Text(h, 12)
            h.name:SetPoint("LEFT", 10, 0)
            h.right = UI:Text(h, 10, C.muted)
            h.right:SetPoint("RIGHT", -10, 0)
            return h
        end)
        self.items = UI:Pool(function() return UI:DungeonLootRow(det) end)
        -- quêtes du donjon : état pour le perso et quête à faire avant
        self.qrows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, det)
            r:SetHeight(24)
            r.dot = UI:Icon(r, "circle", 9, nil, "ARTWORK")
            r.dot:SetPoint("LEFT", 6, 0)
            r.lvl = UI:Text(r, 11, C.muted)
            r.lvl:SetPoint("LEFT", 20, 0)
            r.lvl:SetWidth(24)
            r.lvl:SetJustifyH("RIGHT")
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 52, 0)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            r.state = UI:Text(r, 11)
            r.state:SetJustifyH("RIGHT")
            r.state:SetWordWrap(false)
            r.guide = UI:GuideButton(r, 22, "Guider vers le donneur")
            r.guide:SetPoint("RIGHT", -4, 0)
            r.state:SetPoint("RIGHT", r.guide, "LEFT", -8, 0)
            r.state:SetWidth(300)
            r.name:SetPoint("RIGHT", r.state, "LEFT", -8, 0)
            return r
        end)
        self.none = UI:Text(det, 11, C.muted)

        -- onglet Mes envies
        local wcard = UI:Card(root, T("Mes envies"), " ")
        self.wcard = wcard
        self.wrows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, wcard)
            r:SetHeight(ITEM_H + 4)
            r.item = UI:DungeonLootRow(r)
            r.item:SetPoint("TOPLEFT"); r.item:SetPoint("TOPRIGHT", -230, 0)
            r.where = UI:Text(r, 10, C.muted)
            r.where:SetPoint("RIGHT", -10, 0)
            r.where:SetWidth(220)
            r.where:SetJustifyH("RIGHT")
            return r
        end)
        self.wempty = UI:Text(wcard, 11, C.muted)
        self.wempty:SetPoint("TOPLEFT", 16, -44)
        self.wempty:SetText(T("Pas encore d'envie : clique sur l'étoile d'un objet dans un donjon."))

        UI:OnResize(sc, function(w) self.width = w; root:SetWidth(math.max(100, w - 12)); self:Refresh() end)
    end,

    Refresh = function(self)
        if not self.sc then return end
        local W = (self.width or 800) - 12
        local c = WK.DB.global.characters[self.viewKey] or WK.DB:Me()
        local key = self.viewKey
        local lvl = c.level or 1
        self.tabSeg:Select(self.tab)
        self.tiles:Reset(); self.bheads:Reset(); self.items:Reset(); self.wrows:Reset(); self.qrows:Reset()
        local r1, g1, b1 = UI:Accent()
        if self.tab == "wish" then
            self.det:Hide()
            local wc = self.wcard
            wc:Show()
            wc:ClearAllPoints(); wc:SetPoint("TOPLEFT", 0, 0); wc:SetWidth(W)
            local list = D:Wishes(key)
            if wc.subtitle then wc.subtitle:SetText(string.format(T("%d objet(s) pour %s"), #list, WK:CharName(c, key))) end
            local y = -40
            for _, e in ipairs(list) do
                local r = self.wrows:Get()
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, y); r:SetPoint("TOPRIGHT", -10, y)
                r.item:Set(e.id, e.dungeon and e.dungeon.key, c, key)
                local boss
                if e.dungeon then for _, b in ipairs(D:LootGroups(e.dungeon)) do for _, id in ipairs(b.loot) do if id == e.id then boss = b end end end end
                r.where:SetText(e.dungeon and (D:Name(e.dungeon) .. (boss and ("  ·  " .. D:BossName(boss)) or "")) or "")
                y = y - ITEM_H - 4
            end
            self.wempty:SetShown(#list == 0)
            wc:SetHeight(-y + 30)
            self.sc:SetContentHeight(-y + 40)
            return
        end
        self.wcard:Hide()
        -- tuiles
        local cols = math.max(1, math.floor((W + GAP) / (TILE_W + GAP)))
        local tw = (W - (cols - 1) * GAP) / cols
        local list = D:All()
        if not self.sel then
            for _, d in ipairs(list) do if lvl >= d.min - 2 and lvl <= d.max then self.sel = d.key break end end
            self.sel = self.sel or (list[1] and list[1].key)
        end
        for i, d in ipairs(list) do
            local t = self.tiles:Get()
            t.key = d.key
            t:SetSize(tw, TILE_H)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", ((i - 1) % cols) * (tw + GAP), -math.floor((i - 1) / cols) * (TILE_H + GAP))
            local sel = d.key == self.sel
            t.edge:SetColor(unpack(sel and { r1, g1, b1, 1 } or C.border))
            t.bg:SetColor(unpack(sel and C.surface2 or C.surface))
            t.name:SetText(D:Name(d))
            local done, n = D:Progress(d, key)
            if d.raid then
                t.sub:SetText(string.format(T("raid · niv. %d · %d boss"), d.max, n))
            else
                t.sub:SetText(string.format(T("niv. %d-%d · %d boss"), d.min, d.max, n))
            end
            t.sub:SetTextColor(unpack(levelColor(d, lvl)))
            t.bar.color = { r1, g1, b1, 1 }
            t.bar:SetValue(n > 0 and done / n or 0)
        end
        local y = math.ceil(#list / cols) * (TILE_H + GAP) + 4
        -- détail
        local d = D:Get(self.sel)
        local det = self.det
        det:SetShown(d ~= nil)
        if not d then self.sc:SetContentHeight(y) return end
        det:ClearAllPoints(); det:SetPoint("TOPLEFT", 0, -y); det:SetWidth(W)
        det.title:SetText(D:Name(d))
        local done, n = D:Progress(d, key)
        det.sub:SetText(string.format(T("niv. %d-%d · %d/%d boss déjà tués par ce perso"), d.min, d.max, done, n))
        det.filter:Select(self.filter)
        det.qfilter:Select(self.qfilter)
        local onLoot = self.dtab ~= "quests"
        det.filter:SetShown(onLoot)
        det.qfilter:SetShown(not onLoot)
        det.tabLine:SetColorTexture(unpack(C.border))
        -- quêtes du donjon (zone de l'entrée, au niveau du donjon), pour le perso choisi :
        -- faite, en cours, disponible, niveau trop bas, ou quête à faire avant (prérequis)
        local Q = WK.modules.Quests
        local quests = {}
        for _, q in ipairs(D:Quests(d)) do
            local okSide = not q.side or (c.faction == "Alliance" and q.side == 1) or (c.faction == "Horde" and q.side == 2) or not c.faction
            if okSide then table.insert(quests, q) end
        end
        local ORDER = { avail = 1, log = 2, locked = 3, high = 4, done = 5 }
        local states = {}
        local todo = 0
        for _, q in ipairs(quests) do
            states[q] = { Q:State(q, c) }
            if states[q][1] ~= "done" then todo = todo + 1 end
        end
        -- nombre d'objets du butin (filtre en cours) pour l'onglet
        local nLoot = 0
        for _, b in ipairs(D:LootGroups(d)) do nLoot = nLoot + #UI:DungeonLoot(b, self.filter, c, key) end
        det.tabs.loot:Paint(onLoot, tostring(nLoot))
        local qBadge = #quests == 0 and T("aucune") or todo == 0 and T("toutes faites")
            or string.format(todo > 1 and T("%d à faire") or T("%d à faire"), todo)
        det.tabs.quests:Paint(not onLoot, qBadge, todo > 0 and C.warning or C.positive, todo > 0)
        if not onLoot then
            self.none:Hide()
            return self:RefreshQuests(d, c, quests, states, ORDER, y, W)
        end
        -- boss en deux colonnes (une si la page est étroite)
        local ncol = W >= 760 and 2 or 1
        local colW = (W - 28 - (ncol - 1) * 12) / ncol
        local colY = {}
        for k = 1, ncol do colY[k] = 84 end
        local any = false
        for _, b in ipairs(D:LootGroups(d)) do
            local loot = UI:DungeonLoot(b, self.filter, c, key)
            if #loot > 0 then
                any = true
                local k = 1
                for j = 2, ncol do if colY[j] < colY[k] then k = j end end
                local x = 14 + (k - 1) * (colW + 12)
                local h = self.bheads:Get()
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", x, -colY[k]); h:SetWidth(colW)
                h.bg:SetColor(unpack(C.surface2))
                h.name:SetText(D:BossName(b))
                local right = b.wing and T(b.wing) or ""
                if (b.level or 0) > 0 then right = (right ~= "" and (right .. "  ·  ") or "") .. string.format(T("niv. %d"), b.level) end
                h.right:SetText(right)
                colY[k] = colY[k] + 28
                for _, id in ipairs(loot) do
                    local it = self.items:Get()
                    it:ClearAllPoints(); it:SetPoint("TOPLEFT", x, -colY[k]); it:SetWidth(colW)
                    it:Set(id, d.key, c, key, self.filter == "me")
                    colY[k] = colY[k] + ITEM_H
                end
                colY[k] = colY[k] + 10
            end
        end
        local bottom = 84
        for k = 1, ncol do bottom = math.max(bottom, colY[k]) end
        self.none:SetShown(not any)
        self.none:ClearAllPoints(); self.none:SetPoint("TOPLEFT", 16, -88)
        self.none:SetText(T("Rien que ce perso puisse porter ici (essaie « Tout »)."))
        if not any then bottom = 114 end
        self:PlaceButtons(d, bottom, "")
        local h = bottom + 40
        det:SetHeight(h)
        self.sc:SetContentHeight(y + h + 10)
    end,

    -- bas de carte : boutons (et une phrase à gauche)
    PlaceButtons = function(self, d, bottom, msg)
        local det = self.det
        det.quests:ClearAllPoints(); det.quests:SetPoint("TOPLEFT", 16, -(bottom + 8))
        det.quests:SetText(msg or "")
        det.lfg:ClearAllPoints(); det.lfg:SetPoint("TOPRIGHT", -14, -(bottom + 2))
        det.go:ClearAllPoints(); det.go:SetPoint("RIGHT", det.lfg, "LEFT", -8, 0)
        det.go:SetShown(d.entry ~= nil)
        det.pnl:ClearAllPoints(); det.pnl:SetPoint("RIGHT", det.go, "LEFT", -8, 0)
    end,

    -- onglet Quêtes du détail : état de chaque quête pour le perso, guidage vers le donneur
    RefreshQuests = function(self, d, c, quests, states, ORDER, y, W)
        local det = self.det
        local Q = WK.modules.Quests
        table.sort(quests, function(a, b)
            local sa, sb = ORDER[states[a][1]] or 9, ORDER[states[b][1]] or 9
            if sa ~= sb then return sa < sb end
            return (a.lvl or 0) < (b.lvl or 0)
        end)
        local STATE = {
            done = { "faite", C.dim }, log = { "dans le journal", C.positive }, avail = { "disponible", C.gold },
            high = { "niveau %d requis", C.negative }, locked = { "après : %s", C.tank },
        }
        local qy, shown = 82, 0
        for _, q in ipairs(quests) do
            local st, pre = states[q][1], states[q][2]
            if self.qfilter == "all" or st ~= "done" then
                shown = shown + 1
                local r = self.qrows:Get()
                r:ClearAllPoints(); r:SetPoint("TOPLEFT", 10, -qy); r:SetPoint("TOPRIGHT", -10, -qy)
                local def = STATE[st] or { st, C.muted }
                r.dot:SetVertexColor(unpack(def[2]))
                r.lvl:SetText(tostring(q.lvl or "?"))
                r.name:SetText(Q:Name(q))
                r.name:SetTextColor(unpack(st == "done" and C.dim or C.text))
                local txt
                if st == "high" then txt = string.format(T(def[1]), q.req or 0)
                elseif st == "locked" then txt = string.format(T(def[1]), pre and Q:Name(Q:Get(pre)) or "?")
                else txt = T(def[1]) end
                r.state:SetText(txt)
                r.state:SetTextColor(unpack(def[2]))
                -- guidage : vers le donneur, ou vers celui de la quête à faire avant
                local target = (st == "locked" and pre and Q:Get(pre)) or q
                r.guide.tooltip = (st == "locked") and "Guider vers le donneur de la quête à faire avant" or "Guider vers le donneur"
                r.guide:SetShown(st ~= "done" and target and target.x ~= nil)
                r.guide:SetScript("OnClick", function() Q:GuideTo(target) end)
                qy = qy + 26
            end
        end
        local msg = ""
        if #quests == 0 then msg = T("Pas de quête de donjon connue pour ce perso.")
        elseif shown == 0 then msg = T("Toutes les quêtes du donjon sont faites par ce perso (« Toutes » pour les revoir).") end
        if msg ~= "" then
            self.none:Show()
            self.none:ClearAllPoints(); self.none:SetPoint("TOPLEFT", 16, -88)
            self.none:SetText(msg)
            qy = 114
        end
        local bottom = qy + 4
        self:PlaceButtons(d, bottom, "")
        local h = bottom + 40
        det:SetHeight(h)
        self.sc:SetContentHeight(y + h + 10)
    end,
})
