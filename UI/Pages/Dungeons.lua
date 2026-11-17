local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Page « Donjons » (groupe Exploration) : tuiles des donjons par niveau (couleur selon le niveau du perso
-- choisi, barre = boss tués au moins une fois), puis les boss du donjon choisi et leur butin, filtré
-- « Pour <perso> » ou « Tout », avec la liste d'envies (étoile). Le détail a trois onglets : « Parcours » (carte
-- du prochain boss, puis la frise des boss dans l'ordre du jeu, par aile), « Butin » (boss et monstres du
-- donjon) et « Quêtes » (quêtes du donjon pour le perso, filtre À faire / Toutes).
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
        self.dtab = "route"    -- onglet du détail : parcours, butin ou quêtes
        self.focus = nil       -- parcours : boss montré dans la carte du haut (nil = le prochain)
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
            b:SetScript("OnClick", function() self.dtab = key; self.focus = nil; self:Refresh() end)
            det.tabs[key] = b
            return b
        end
        tab("route", "Parcours"):SetPoint("TOPLEFT", 14, -42)
        tab("loot", "Butin"):SetPoint("LEFT", det.tabs.route, "RIGHT", 8, 0)
        det.live = UI:Badge(det, "Tu es dedans", C.positive)
        det.live:SetPoint("LEFT", det.sub, "RIGHT", 10, 0)
        self:BuildRoute(det)
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
        self.steps:Reset(); self.wheads:Reset(); self.ficons:Reset()
        self.det.focus:Hide()
        -- entrée dans un donjon : la page se place dessus, onglet Parcours
        local cur = D:Current()
        local curKey = cur and cur.key or nil
        if curKey ~= self.lastCur then
            if curKey then self.sel, self.dtab, self.focus = curKey, "route", nil end
            self.lastCur = curKey
        end
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
        local inRun = D:InRun(d)
        if inRun then
            local k, m = 0, 0
            for _, b in ipairs(D:Bosses(d)) do
                if not D:Optional(d, b) then m = m + 1; if D.run.killed[b.id] then k = k + 1 end end
            end
            det.sub:SetText(string.format(T("niv. %d-%d · %d/%d boss ce passage"), d.min, d.max, k, m))
        else
            det.sub:SetText(string.format(T("niv. %d-%d · %d/%d boss déjà tués par ce perso"), d.min, d.max, done, n))
        end
        det.live:SetShown(inRun and curKey == d.key)
        det.filter:Select(self.filter)
        det.qfilter:Select(self.qfilter)
        local onLoot = self.dtab == "loot"
        local onRoute = self.dtab == "route"
        det.filter:SetShown(not (self.dtab == "quests"))
        det.qfilter:SetShown(self.dtab == "quests")
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
        det.tabs.quests:Paint(self.dtab == "quests", qBadge, todo > 0 and C.warning or C.positive, todo > 0)
        local nb = D:Next(d, key)
        det.tabs.route:Paint(onRoute, inRun and (nb and T("en cours") or T("terminé")) or nil, inRun and C.positive or nil, inRun)
        self.questTodo = todo
        if onRoute then
            self.none:Hide()
            return self:RefreshRoute(d, c, key, y, W)
        end
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

    -- onglet Parcours : carte du boss en vedette (le prochain, ou celui qu'on a cliqué) et frise des boss
    BuildRoute = function(self, det)
        local f = CreateFrame("Frame", nil, det)
        det.focus = f
        f.edge = UI:Rounded(f, 11, 0, "BACKGROUND", 2)
        f.bg = UI:Rounded(f, 10, 1, "BACKGROUND", 3)
        f.kick = UI:Text(f, 10)
        f.kick:SetPoint("TOPLEFT", 14, -12)
        f.name = UI:Text(f, 16)
        f.name:SetPoint("TOPLEFT", f.kick, "BOTTOMLEFT", 0, -5)
        f.sub = UI:Text(f, 11, C.muted)
        f.sub:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", 0, -4)
        f.none = UI:Text(f, 11, C.muted)
        -- colonne de droite : envies du perso sur ce boss, qui d'autre les veut, quêtes du donjon
        f.sep = f:CreateTexture(nil, "ARTWORK")
        f.sep:SetWidth(1)
        f.right = UI:Text(f, 11, C.text)
        f.right:SetJustifyH("LEFT")
        f.right:SetJustifyV("TOP")
        if f.right.SetWordWrap then f.right:SetWordWrap(true) end
        f.right:SetSpacing(3)
        f.all = UI:Button(f, "Tout le butin", nil, 24, "primary")
        f.all:SetScript("OnClick", function() self.dtab = "loot"; self.focus = nil; self:Refresh() end)
        f.skip = UI:Button(f, "Passer", nil, 24, "secondary")
        f.skip:SetPoint("LEFT", f.all, "RIGHT", 8, 0)
        f.skip:SetScript("OnClick", function()
            local d = D:Get(self.sel)
            if d and f.boss then D:Skip(d, f.boss); self.focus = nil; self:Refresh() end
        end)
        -- icônes du butin (bord à la couleur de qualité, étoile = envie, pâle = déjà sur le compte)
        self.ficons = UI:Pool(function()
            local b = CreateFrame("Button", nil, f)
            b:SetSize(32, 32)
            b.edge = UI:Rounded(b, 7, 0, "BACKGROUND", 4)
            b.bg = UI:Rounded(b, 6, 1, "BACKGROUND", 5)
            b.icon = UI:RoundIcon(b, 26)
            b.icon:SetPoint("CENTER")
            b.star = UI:Icon(b, "star", 12, nil, "OVERLAY")
            b.star:SetPoint("TOPRIGHT", 4, 4)
            b:SetScript("OnEnter", function(s)
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText((UI:ItemInfo(s.id))) end
                GameTooltip:AddLine(T("Clic : liste d'envies · Maj + clic : lien dans le chat"), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(s)
                if IsShiftKeyDown() then
                    local link = select(6, UI:ItemInfo(s.id))
                    if link then WK.InsertChatLink(link) end
                else
                    D:ToggleWish(s.id, self.sel, self.viewKey); self:Refresh()
                end
            end)
            return b
        end)
        -- étapes de la frise
        self.steps = UI:Pool(function()
            local r = CreateFrame("Button", nil, det)
            r:SetHeight(28)
            r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 1)
            r.bar = r:CreateTexture(nil, "ARTWORK")
            r.bar:SetWidth(3)
            r.bar:SetPoint("TOPLEFT", 0, -3); r.bar:SetPoint("BOTTOMLEFT", 0, 3)
            r.ring = UI:Icon(r, "ring", 20, nil, "ARTWORK")
            r.ring:SetPoint("LEFT", 6, 0)
            r.num = UI:Text(r, 10)
            r.num:SetPoint("CENTER", r.ring, "CENTER", 0, 0)
            r.line = r:CreateTexture(nil, "BACKGROUND", nil, 2)
            r.line:SetWidth(2)
            r.line:SetPoint("TOP", r.ring, "BOTTOM", 0, 0)
            r.line:SetHeight(10)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 36, 0)
            r.lvl = UI:Text(r, 10, C.dim)
            r.lvl:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
            r.right = UI:Text(r, 11, C.muted)
            r.right:SetPoint("RIGHT", -10, 0)
            r.right:SetJustifyH("RIGHT")
            r.star = UI:Icon(r, "star", 12, nil, "ARTWORK")
            r.wn = UI:Text(r, 10)
            r:SetScript("OnEnter", function(s) s.hover = true; if not s.on then s.bg:SetColor(unpack(C.hover)) end end)
            r:SetScript("OnLeave", function(s) s.hover = false; if not s.on then s.bg:SetColor(0, 0, 0, 0) end end)
            r:SetScript("OnClick", function(s)
                self.focus = (self.focus ~= s.boss.id) and s.boss.id or nil
                self:Refresh()
            end)
            return r
        end)
        self.wheads = UI:Pool(function()
            local h = CreateFrame("Frame", nil, det)
            h:SetHeight(20)
            h.name = UI:Text(h, 10, C.dim)
            h.name:SetPoint("BOTTOMLEFT", 2, 3)
            h.count = UI:Text(h, 10, C.muted)
            h.count:SetPoint("BOTTOMRIGHT", -10, 3)
            return h
        end)
    end,

    RefreshRoute = function(self, d, c, key, y, W)
        local det = self.det
        local f = det.focus
        local r1, g1, b1 = UI:Accent()
        local inRun = D:InRun(d)
        local run = D.run
        local bosses = D:Bosses(d)
        local nextB = D:Next(d, key)
        local function find(id) for _, b in ipairs(bosses) do if b.id == id then return b end end end
        local boss = (self.focus and find(self.focus)) or nextB
        local main, mainIdx = 0, {}
        for _, b in ipairs(bosses) do
            if not D:Optional(d, b) then main = main + 1; mainIdx[b.id] = main end
        end
        local function wishes(b)
            local n = 0
            for _, id in ipairs(b.loot) do if D:IsWished(id, key) then n = n + 1 end end
            return n
        end
        -- carte du haut
        f:Show()
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", 14, -84); f:SetPoint("TOPRIGHT", -14, -84)
        f.edge:SetColor(r1, g1, b1, 0.45)
        f.bg:SetColor(C.surface2[1] * 0.85 + r1 * 0.15, C.surface2[2] * 0.85 + g1 * 0.15, C.surface2[3] * 0.85 + b1 * 0.15, 1)
        f.boss = boss
        local FH = 128
        if not boss then
            f.kick:SetText(""); f.name:SetText(T("Parcours terminé")); f.sub:SetText(T("Tous les boss de ce passage sont tués ou passés."))
            f.all:Hide(); f.skip:Hide(); f.right:SetText(""); f.sep:Hide()
            FH = 74
        else
            local isNext = boss == nextB
            local killedAt = inRun and run.killed[boss.id]
            local parts = {}
            if killedAt then table.insert(parts, string.format(T("tué à %s"), date("%H:%M", killedAt)))
            elseif isNext then table.insert(parts, T("prochain"))
            else table.insert(parts, T("boss")) end
            if boss.wing then table.insert(parts, T(boss.wing)) end
            if mainIdx[boss.id] then table.insert(parts, mainIdx[boss.id] .. " / " .. main) end
            f.kick:SetText(UI:Upper(table.concat(parts, "  ·  ")))
            f.kick:SetTextColor(r1, g1, b1)
            f.name:SetText(D:BossName(boss))
            local sub = (boss.level or 0) > 0 and string.format(T("Niveau %d"), boss.level) or ""
            if D:Optional(d, boss) then sub = sub .. (sub ~= "" and "  ·  " or "") .. T("facultatif") end
            if D:Skipped(d, boss) then sub = sub .. (sub ~= "" and "  ·  " or "") .. T("passé") end
            f.sub:SetText(sub)
            -- butin (filtre de la page)
            local loot = UI:DungeonLoot(boss, self.filter, c, key)
            local rightW = W >= 640 and 230 or 0
            local maxIcons = math.max(1, math.floor((W - 28 - 28 - rightW - 20) / 38))
            for i, id in ipairs(loot) do
                if i > maxIcons then break end
                local ic = self.ficons:Get()
                ic.id = id
                ic:ClearAllPoints(); ic:SetPoint("TOPLEFT", f, "TOPLEFT", 14 + (i - 1) * 38, -66)
                local _, tex = UI:ItemInfo(id)
                ic.icon:SetTexture(tex)
                local q = UI.DungeonQuality and UI.DungeonQuality(id) or C.border
                ic.edge:SetColor(q[1], q[2], q[3], 1)
                ic.bg:SetColor(unpack(C.surface))
                local owned = D:Owned(id)
                ic.icon:SetAlpha(owned and 0.35 or 1)
                local wished = D:IsWished(id, key)
                ic.star:SetShown(wished)
                ic.star:SetVertexColor(r1, g1, b1, 1)
            end
            f.none:SetShown(#loot == 0)
            f.none:ClearAllPoints(); f.none:SetPoint("TOPLEFT", 14, -74)
            f.none:SetText(T("Rien que ce perso puisse porter (essaie « Tout »)."))
            f.all:Show()
            f.all:ClearAllPoints(); f.all:SetPoint("TOPLEFT", 14, -(FH - 34))
            local canSkip = inRun and not killedAt and not D:Optional(d, boss)
            f.skip:SetShown(canSkip)
            if canSkip then f.skip:SetLabel(D:Skipped(d, boss) and T("Reprendre") or T("Passer")) end
            -- colonne de droite
            if rightW > 0 then
                f.sep:Show(); f.sep:SetColorTexture(r1, g1, b1, 0.25)
                f.sep:ClearAllPoints(); f.sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -(rightW + 12), -12); f.sep:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(rightW + 12), 12)
                f.right:ClearAllPoints(); f.right:SetPoint("TOPLEFT", f, "TOPRIGHT", -rightW, -12); f.right:SetWidth(rightW - 12)
                local lines = {}
                local acc = string.format("|cff%02x%02x%02x", r1 * 255, g1 * 255, b1 * 255)
                table.insert(lines, "|cff8a8f98" .. T("TES ENVIES") .. "|r")
                local mine, others = {}, {}
                for _, id in ipairs(boss.loot) do
                    if D:IsWished(id, key) then table.insert(mine, (UI:ItemInfo(id)) or ("#" .. id)) end
                    for ck in pairs(WK.DB.global.dungeons and WK.DB.global.dungeons.wish or {}) do
                        if ck ~= key and D:IsWished(id, ck) then
                            local oc = WK.DB.global.characters[ck]
                            others[oc and WK:CharName(oc, ck) or ck] = true
                        end
                    end
                end
                if #mine == 0 then table.insert(lines, "|cff8a8f98" .. T("aucune sur ce boss") .. "|r") end
                for i, n in ipairs(mine) do if i <= 3 then table.insert(lines, acc .. "*|r " .. n) end end
                local on = {}
                for n in pairs(others) do table.insert(on, n) end
                table.sort(on)
                if #on > 0 then table.insert(lines, "|cff8a8f98" .. string.format(T("voulu aussi par %s"), table.concat(on, ", ")) .. "|r") end
                if self.questTodo and self.questTodo > 0 then
                    table.insert(lines, " ")
                    table.insert(lines, "|cff8a8f98" .. T("QUÊTES DU DONJON") .. "|r")
                    table.insert(lines, string.format(self.questTodo > 1 and T("%d à faire") or T("%d à faire"), self.questTodo))
                end
                f.right:SetText(table.concat(lines, "\n"))
            else
                f.sep:Hide(); f.right:SetText("")
            end
        end
        f:SetHeight(FH)
        -- frise
        local fy = 84 + FH + 6
        local lastWing, wingHead = false, nil
        local wingCount = {}
        for _, b in ipairs(bosses) do
            local w = b.wing or ""
            wingCount[w] = wingCount[w] or { 0, 0 }
            if not D:Optional(d, b) then
                wingCount[w][2] = wingCount[w][2] + 1
                local k = inRun and run.killed[b.id] or (not inRun and D:KilledEver(d, b.id, key))
                if k then wingCount[w][1] = wingCount[w][1] + 1 end
            end
        end
        local prev
        for _, b in ipairs(bosses) do
            local w = b.wing or ""
            if w ~= lastWing then
                lastWing = w
                prev = nil
                if w ~= "" then
                    local h = self.wheads:Get()
                    h:ClearAllPoints(); h:SetPoint("TOPLEFT", 16, -fy); h:SetPoint("TOPRIGHT", -14, -fy)
                    h.name:SetText(UI:Upper(T(w)))
                    local wc = wingCount[w]
                    h.count:SetText(wc[1] .. "/" .. wc[2])
                    h.count:SetTextColor(unpack((wc[2] > 0 and wc[1] == wc[2]) and C.positive or C.muted))
                    fy = fy + 22
                else
                    fy = fy + 6
                end
            end
            local r = self.steps:Get()
            r.boss = b
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 14, -fy); r:SetPoint("TOPRIGHT", -14, -fy)
            local opt = D:Optional(d, b)
            local killedAt = inRun and run.killed[b.id]
            local ever = not inRun and D:KilledEver(d, b.id, key)
            local isNext = b == nextB
            local skipped = D:Skipped(d, b)
            local sel = self.focus == b.id and not isNext
            r.on = isNext or sel
            r.bg:SetColor(unpack((isNext or sel) and C.surface2 or { 0, 0, 0, 0 }))
            if r.hover and not r.on then r.bg:SetColor(unpack(C.hover)) end
            r.bar:SetShown(isNext)
            r.bar:SetColorTexture(r1, g1, b1, 1)
            r.ring:SetTexture(UI.MEDIA .. (opt and "ring_dash" or "ring"))
            local green = C.positive
            if killedAt then r.ring:SetVertexColor(green[1], green[2], green[3], 1)
            elseif ever then r.ring:SetVertexColor(green[1], green[2], green[3], 0.45)
            elseif isNext then r.ring:SetVertexColor(r1, g1, b1, 1)
            else r.ring:SetVertexColor(unpack(C.dim)) end
            r.num:SetText(opt and "" or tostring(mainIdx[b.id] or ""))
            r.num:SetTextColor(unpack(killedAt and green or isNext and { r1, g1, b1, 1 } or C.muted))
            r.name:SetText(D:BossName(b))
            r.name:SetTextColor(unpack((killedAt or skipped) and C.dim or opt and C.muted or C.text))
            r.lvl:SetText((b.level or 0) > 0 and tostring(b.level) or "")
            -- à droite : heure du kill, déjà tué, passé, facultatif, prochain ; étoile = envies
            local txt, col = "", C.muted
            if killedAt then txt, col = date("%H:%M", killedAt), C.muted
            elseif skipped then txt = T("passé")
            elseif isNext then txt, col = T("prochain"), { r1, g1, b1, 1 }
            elseif ever then txt, col = T("déjà tué"), C.dim
            elseif opt then txt, col = T("facultatif"), C.dim end
            r.right:SetText(txt); r.right:SetTextColor(unpack(col))
            local wn = wishes(b)
            r.star:SetShown(wn > 0); r.wn:SetShown(wn > 0)
            if wn > 0 then
                r.wn:SetText(tostring(wn)); r.wn:SetTextColor(r1, g1, b1)
                r.star:SetVertexColor(r1, g1, b1, 1)
                r.wn:ClearAllPoints()
                if txt ~= "" then r.wn:SetPoint("RIGHT", r.right, "LEFT", -12, 0) else r.wn:SetPoint("RIGHT", -10, 0) end
                r.star:ClearAllPoints(); r.star:SetPoint("RIGHT", r.wn, "LEFT", -3, 0)
            end
            -- trait vers l'étape suivante de la même aile (vert si ce boss est tué)
            r.line:Hide()
            if prev then
                prev.line:Show()
                prev.line:SetHeight(10)
                local pk = prev.killedAt or prev.ever
                if pk then prev.line:SetColorTexture(green[1], green[2], green[3], prev.killedAt and 0.8 or 0.35)
                else prev.line:SetColorTexture(unpack(C.border)) end
            end
            r.killedAt, r.ever = killedAt, ever
            prev = r
            fy = fy + 30
        end
        -- bas de carte : depuis quand dure le passage
        local msg = ""
        if inRun and run.start then
            msg = string.format(T("Passage commencé à %s  ·  %d min"), date("%H:%M", run.start), math.floor((time() - run.start) / 60))
        elseif not inRun then
            msg = T("Hors du donjon : coches pâles = boss déjà tués par ce perso.")
        end
        local bottom = fy + 6
        self:PlaceButtons(d, bottom, msg)
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
