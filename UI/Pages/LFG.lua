local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Onglet LFG (Modules/LFG.lua) : la page part du perso.
--   bandeau : qui je suis, mes rôles, ce que je cherche, Actualiser ;
--   à gauche : l'échelle des donjons, par niveau, avec un trait « toi » ;
--   au centre : les groupes en cartes (« Une place pour toi » d'abord), puis les joueurs seuls ;
--   à droite : mes demandes et mon message.
local LFG = WK.modules.LFG
local LEFT_W, RIGHT_W, GAP, BANNER_H = 230, 270, 12, 62
local CARD_W, CARD_H = 286, 100
local ROLES = { "tank", "heal", "dps" }
local ROLE_LABEL = { tank = "Tank", heal = "Soin", dps = "Dégâts" }
local ROLE_LETTER = { tank = "T", heal = "S", dps = "D" }

local function classColor(class) return UI:ClassColor(class) end

local function ago(sec)
    if not sec then return "" end
    if sec < 60 then return T("à l'instant") end
    if sec < 3600 then return string.format(T("%d min"), math.floor(sec / 60)) end
    return string.format(T("%d h"), math.floor(sec / 3600))
end

UI:RegisterPage({
    key = "lfg", order = 7, nav = "LFG",

    Build = function(self, p)
        local cfg = LFG:Config()
        self.sel = nil -- activité choisie dans l'échelle (nil : toutes)

        -----------------------------------------------------------------------
        -- Bandeau
        -----------------------------------------------------------------------
        local banner = UI:Card(p)
        banner:SetPoint("TOPLEFT")
        banner:SetPoint("TOPRIGHT")
        banner:SetHeight(BANNER_H)
        self.portrait = UI:RoundIcon(banner, 36)
        self.portrait:SetPoint("LEFT", 14, 0)
        self.meName = UI:Text(banner, 14)
        self.meName:SetPoint("TOPLEFT", 60, -14)
        self.meSub = UI:Text(banner, 11, C.muted)
        self.meSub:SetPoint("TOPLEFT", self.meName, "BOTTOMLEFT", 0, -3)

        local playHd = UI:Text(banner, 10, C.dim)
        playHd:SetPoint("TOPLEFT", 250, -10)
        playHd:SetText(T("JE JOUE"))
        self.roleBtns = {}
        local x = 250
        for _, role in ipairs(ROLES) do
            local b = CreateFrame("Button", nil, banner)
            b:SetSize(84, 24)
            b:SetPoint("TOPLEFT", x, -26)
            b.edge = UI:Rounded(b, 12, 0, "BACKGROUND", 0)
            b.bg = UI:Rounded(b, 11, 1, "BACKGROUND", 1)
            b.dot = UI:Icon(b, "circle", 9, nil, "ARTWORK")
            b.dot:SetPoint("LEFT", 12, 0)
            b.label = UI:Text(b, 12)
            b.label:SetPoint("LEFT", 26, 0)
            b.label:SetText(T(ROLE_LABEL[role]))
            function b:Paint()
                local on = cfg.roles[role]
                local col = C[role]
                self.edge:SetColor(unpack(on and col or C.border))
                self.bg:SetColor(unpack(C.surface))
                self.dot:SetVertexColor(unpack(col))
                self.label:SetTextColor(unpack(on and C.text or C.muted))
            end
            b:SetScript("OnClick", function(s)
                cfg.roles[role] = not cfg.roles[role]
                s:Paint()
                self:Refresh()
            end)
            self.roleBtns[role] = b
            x = x + 90
        end

        local lookHd = UI:Text(banner, 10, C.dim)
        lookHd:SetPoint("TOPLEFT", x + 14, -10)
        lookHd:SetText(T("JE CHERCHE"))
        self.modeSeg = UI:Segmented(banner, { { "group", "Un groupe" }, { "players", "Des joueurs" } },
            function(v) cfg.mode = v; self:Refresh() end, 24)
        self.modeSeg:SetPoint("TOPLEFT", x + 14, -26)
        self.modeSeg:Select(cfg.mode)

        self.searchBtn = UI:Button(banner, "Actualiser", 110, 26, "primary", "refresh")
        self.searchBtn:SetPoint("TOPRIGHT", -14, -8)
        self.searchBtn:SetScript("OnClick", function() self:DoSearch() end)
        self.status = UI:Text(banner, 11, C.muted)
        self.status:SetPoint("TOPRIGHT", self.searchBtn, "BOTTOMRIGHT", -4, -4)
        self.status:SetJustifyH("RIGHT")

        -----------------------------------------------------------------------
        -- Échelle des donjons (gauche)
        -----------------------------------------------------------------------
        local left = UI:Card(p)
        left:SetPoint("TOPLEFT", 0, -(BANNER_H + GAP))
        left:SetPoint("BOTTOMLEFT")
        left:SetWidth(LEFT_W)
        local cats = LFG:Categories()
        self.category = cfg.category or LFG:DefaultCategory()
        local catOpts = {}
        for _, c in ipairs(cats) do table.insert(catOpts, { c.id, c.name }) end
        self.catDd = UI:Dropdown(left, LEFT_W - 20, 28, catOpts, function(v)
            self.category = v; cfg.category = v; self.sel = nil; self:Refresh()
        end)
        self.catDd:SetPoint("TOPLEFT", 10, -10)
        if self.category then self.catDd:Select(self.category) end
        self.ladder = UI:Scroll(left)
        self.ladder:SetPoint("TOPLEFT", 6, -46)
        self.ladder:SetPoint("BOTTOMRIGHT", -6, 8)
        self.rungs = UI:Pool(function()
            local b = CreateFrame("Button", nil, self.ladder.child)
            b:SetHeight(34)
            b.bg = UI:Rounded(b, 8, 0, "BACKGROUND", 1)
            b.lv = UI:Text(b, 10, C.dim)
            b.lv:SetPoint("TOPRIGHT", b, "TOPLEFT", 26, -7)
            b.lv:SetJustifyH("RIGHT")
            b.name = UI:Text(b, 12)
            b.name:SetPoint("TOPLEFT", 32, -6)
            b.name:SetPoint("RIGHT", -6, 0)
            b.name:SetJustifyH("LEFT")
            b.bar = b:CreateTexture(nil, "ARTWORK")
            b.bar:SetPoint("TOPLEFT", 32, -24)
            b.bar:SetHeight(3)
            b:SetScript("OnClick", function(s)
                self.sel = (self.sel == s.act) and nil or s.act
                self:Refresh()
            end)
            return b
        end)
        self.meLine = self.ladder.child:CreateTexture(nil, "ARTWORK")
        self.meLine:SetHeight(1)
        self.meLv = UI:Text(self.ladder.child, 10)
        self.meTxt = UI:Text(self.ladder.child, 10)
        self.meTxt:SetText(T("toi"))

        -----------------------------------------------------------------------
        -- Mes demandes (droite)
        -----------------------------------------------------------------------
        local right = UI:Card(p)
        right:SetPoint("TOPRIGHT", 0, -(BANNER_H + GAP))
        right:SetPoint("BOTTOMRIGHT")
        right:SetWidth(RIGHT_W)
        local rqHd = UI:Text(right, 10, C.dim)
        rqHd:SetPoint("TOPLEFT", 14, -14)
        rqHd:SetText(T("MES DEMANDES"))
        self.reqs = UI:Pool(function()
            local r = CreateFrame("Frame", nil, right)
            r:SetSize(RIGHT_W - 28, 50)
            r.dot = UI:Icon(r, "circle", 8, nil, "ARTWORK")
            r.dot:SetPoint("TOPLEFT", 0, -5)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 16, 0)
            r.l1 = UI:Text(r, 11, C.muted)
            r.l1:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.l1:SetPoint("RIGHT")
            r.l1:SetJustifyH("LEFT")
            r.l1:SetWordWrap(false)
            r.l2 = UI:Text(r, 10, C.dim)
            r.l2:SetPoint("TOPLEFT", r.l1, "BOTTOMLEFT", 0, -2)
            return r
        end)
        self.noReq = UI:Text(right, 11, C.dim)
        self.noReq:SetPoint("TOPLEFT", 14, -36)
        self.noReq:SetPoint("RIGHT", -14, 0)
        self.noReq:SetJustifyH("LEFT")
        self.noReq:SetText(T("Aucune demande pour l'instant."))
        local msgHd = UI:Text(right, 10, C.dim)
        msgHd:SetPoint("BOTTOMLEFT", 14, 130)
        msgHd:SetText(T("MON MESSAGE"))
        self.msgBox = UI:Input(right, RIGHT_W - 28, 30)
        self.msgBox:SetPoint("BOTTOMLEFT", 14, 92)
        self.msgBox:SetText(cfg.message)
        self.msgBox.edit:SetScript("OnEditFocusLost", function() cfg.message = self.msgBox:GetText(); self:Refresh() end)
        self.msgPreview = UI:Text(right, 11, C.text)
        self.msgPreview:SetPoint("TOPLEFT", self.msgBox, "BOTTOMLEFT", 0, -8)
        self.msgPreview:SetPoint("RIGHT", -14, 0)
        self.msgPreview:SetJustifyH("LEFT")
        self.msgPreview:SetWordWrap(true)
        local msgHelp = UI:Text(right, 10, C.dim)
        msgHelp:SetPoint("BOTTOMLEFT", 14, 12)
        msgHelp:SetText("%class% %level% %role% %dungeon%")
        local reset = UI:Button(right, "Défaut", 60, 20, "ghost")
        reset:SetPoint("BOTTOMRIGHT", -10, 126)
        reset:SetScript("OnClick", function() cfg.message = LFG.DEFAULT_MSG; self.msgBox:SetText(cfg.message); self:Refresh() end)

        -----------------------------------------------------------------------
        -- Groupes (centre)
        -----------------------------------------------------------------------
        local center = CreateFrame("Frame", nil, p)
        center:SetPoint("TOPLEFT", LEFT_W + GAP, -(BANNER_H + GAP))
        center:SetPoint("BOTTOMRIGHT", -(RIGHT_W + GAP), 0)
        self.center = center
        self.scroll = UI:Scroll(center)
        self.scroll:SetAllPoints()
        local root = self.scroll.child
        self.heads = UI:Pool(function()
            local h = CreateFrame("Frame", nil, root)
            h:SetHeight(24)
            h.title = UI:Text(h, 14)
            h.title:SetPoint("LEFT", 0, 0)
            h.sub = UI:Text(h, 11, C.muted)
            h.sub:SetPoint("LEFT", h.title, "RIGHT", 10, 0)
            h.sub:SetPoint("RIGHT", h, "RIGHT", 0, 0)
            h.sub:SetJustifyH("LEFT")
            h.sub:SetWordWrap(false)
            return h
        end)
        self.cards = UI:Pool(function()
            local c = CreateFrame("Frame", nil, root)
            c:SetSize(CARD_W, CARD_H)
            c.edge = UI:Rounded(c, 12, 0, "BACKGROUND", 0)
            c.bg = UI:Rounded(c, 11, 1, "BACKGROUND", 1)
            c.name = UI:Text(c, 13)
            c.name:SetPoint("TOPLEFT", 14, -12)
            c.name:SetPoint("RIGHT", -70, 0)
            c.name:SetJustifyH("LEFT")
            c.name:SetWordWrap(false)
            c.age = UI:Text(c, 10, C.muted)
            c.age:SetPoint("TOPRIGHT", -14, -14)
            c.slots = {}
            for i = 1, 5 do
                local s = CreateFrame("Frame", nil, c)
                s:SetSize(26, 26)
                s:SetPoint("TOPLEFT", 14 + (i - 1) * 32 + (i >= 3 and 8 or 0), -36)
                s.fill = UI:Icon(s, "circle", 26, nil, "ARTWORK")
                s.fill:SetPoint("CENTER")
                s.ring = UI:Icon(s, "ring", 26, nil, "OVERLAY")
                s.ring:SetPoint("CENTER")
                s.txt = UI:Text(s, 9)
                s.txt:SetPoint("CENTER")
                s.txt:SetFont(UI.FONT, 9, "")
                c.slots[i] = s
            end
            c.note = UI:Text(c, 11, C.muted)
            c.note:SetPoint("BOTTOMLEFT", 14, 12)
            c.note:SetPoint("RIGHT", -110, 0)
            c.note:SetJustifyH("LEFT")
            c.note:SetWordWrap(false)
            c.btn = UI:Button(c, "", 96, 24, "primary")
            c.btn:SetPoint("BOTTOMRIGHT", -12, 9)
            c.state = UI:Text(c, 11, C.dim)
            c.state:SetPoint("BOTTOMRIGHT", -14, 14)
            c:EnableMouse(true)
            c:SetScript("OnEnter", function(s)
                if not s.r then return end
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(s.r.leader or "?", 1, 1, 1)
                local act = LFG:Activity(s.r.activity)
                if act then GameTooltip:AddLine(act, 0.8, 0.8, 0.8) end
                if s.r.comment and s.r.comment ~= "" then GameTooltip:AddLine("« " .. s.r.comment .. " »", 0.9, 0.85, 0.7, true) end
                GameTooltip:Show()
            end)
            c:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return c
        end)
        self.solos = UI:Pool(function()
            local b = CreateFrame("Frame", nil, root)
            b:SetHeight(30)
            b.edge = UI:Rounded(b, 15, 0, "BACKGROUND", 0)
            b.bg = UI:Rounded(b, 14, 1, "BACKGROUND", 1)
            b.dot = UI:Icon(b, "circle", 9, nil, "ARTWORK")
            b.dot:SetPoint("LEFT", 12, 0)
            b.name = UI:Text(b, 12)
            b.name:SetPoint("LEFT", 28, 0)
            b.sub = UI:Text(b, 11, C.muted)
            b.sub:SetPoint("LEFT", b.name, "RIGHT", 6, 0)
            b.btn = UI:Button(b, "Inviter", 64, 22, "primary")
            b.btn:SetPoint("RIGHT", -4, 0)
            return b
        end)
        self.empty = UI:Text(root, 12, C.muted)
        self.empty:SetJustifyH("LEFT")
        UI:OnResize(center, function() self:Refresh() end)
    end,

    -- Lance la recherche : l'activité choisie, ou toutes celles de la catégorie.
    DoSearch = function(self)
        if not LFG:Available() then return end
        local acts = self.sel and { self.sel } or nil
        LFG:Search(self.category, acts)
        self:Refresh()
    end,

    -- Une carte de groupe
    PaintCard = function(self, c, r, fit)
        c.r = r
        local r1, g1, b1 = UI:Accent()
        c.edge:SetColor(unpack(fit and { r1, g1, b1, 1 } or C.border))
        c.bg:SetColor(unpack(C.surface))
        local name = r.leader or "?"
        local nr, ng, nb = classColor(r.class)
        if r.friend or r.guild then nr, ng, nb = C.tank[1], C.tank[2], C.tank[3] end
        if r.delisted then nr, ng, nb = C.dim[1], C.dim[2], C.dim[3] end
        c.name:SetText(name .. (r.level and ("  |cff999999" .. r.level .. "|r") or ""))
        c.name:SetTextColor(nr, ng, nb)
        local tag = r.friend and T("ami") or (r.guild and T("guilde") or nil)
        c.age:SetText((tag and (tag .. " · ") or "") .. ago(r.age))
        -- places : tank, soin, trois dégâts
        local cnt = r.counts or {}
        local order = { "tank", "heal", "dps", "dps", "dps" }
        local seen = { tank = 0, heal = 0, dps = 0 }
        local youPlaced = false
        for i, role in ipairs(order) do
            seen[role] = seen[role] + 1
            local s = c.slots[i]
            local col = C[role]
            local taken = r.counts and seen[role] <= (cnt[role] or 0)
            if taken then
                s.fill:Show(); s.ring:Hide()
                s.fill:SetVertexColor(unpack(col))
                s.txt:SetText(ROLE_LETTER[role]); s.txt:SetTextColor(unpack(C.onAccent))
            elseif fit == role and not youPlaced then
                youPlaced = true
                s.fill:Hide(); s.ring:Show()
                s.ring:SetTexture(UI.MEDIA .. "ring")
                s.ring:SetVertexColor(r1, g1, b1, 1)
                s.txt:SetText(T("toi")); s.txt:SetTextColor(r1, g1, b1)
            else
                s.fill:Hide(); s.ring:Show()
                s.ring:SetTexture(UI.MEDIA .. "ring_dash")
                s.ring:SetVertexColor(col[1], col[2], col[3], r.counts and 0.9 or 0.35)
                s.txt:SetText(r.counts and ROLE_LETTER[role] or "?"); s.txt:SetTextColor(col[1], col[2], col[3])
            end
        end
        local note = r.comment ~= "" and ("« " .. r.comment .. " »") or (LFG:Activity(r.activity) or "")
        c.note:SetText(note)
        -- bouton : Demander, Demandé, ou un état
        local q = r.leader and LFG.requests[r.leader]
        c.btn:Hide(); c.state:SetText("")
        if r.delisted then c.state:SetText(T("retiré"))
        elseif r.self then c.state:SetText(T("ton groupe"))
        elseif q then
            c.btn:Show(); c.btn.label:SetText(T("Demandé")); c.btn:SetStyle("secondary")
            c.btn:SetScript("OnClick", function() LFG:Ask(r); self:Refresh() end)
        elseif fit then
            c.btn:Show(); c.btn.label:SetText(T("Demander")); c.btn:SetStyle("primary")
            c.btn:SetScript("OnClick", function() LFG:Ask(r); self:Refresh() end)
        else
            c.state:SetText(LFG:Full(r) and T("complet") or T("pas de place"))
        end
        c:SetAlpha(r.delisted and 0.55 or 1)
    end,

    Refresh = function(self)
        local cfg = LFG:Config()
        local me = WK.DB:Me()
        -- bandeau
        UI:SetClassIcon(self.portrait, me.class)
        self.meName:SetText(WK:CharName(me))
        self.meSub:SetText(T(WK.modules.QoL.CLASS_LABEL[me.class or ""] or "?") .. " · " .. string.format(T("niveau %s"), tostring(UnitLevel("player") or me.level or "?")))
        for _, b in pairs(self.roleBtns) do b:Paint() end
        if not LFG:Available() then
            self.status:SetText(T("Recherche de groupe indisponible sur ce client"))
            self.searchBtn:Hide()
        elseif LFG.searching then
            self.status:SetText(T("recherche en cours…"))
        elseif LFG.searchedAt then
            local d = time() - LFG.searchedAt
            self.status:SetText(d < 60 and T("actualisé à l'instant") or string.format(T("actualisé il y a %s"), ago(d)))
        else
            self.status:SetText(T("clique Actualiser pour chercher"))
        end

        -- échelle des donjons
        self.rungs:Reset()
        local level = UnitLevel("player") or 1
        local counts = LFG:ActivityCounts()
        local maxN = 1
        for _, n in pairs(counts) do maxN = math.max(maxN, n) end
        local y, meDrawn = 4, false
        local lw = LEFT_W - 24
        local function drawMe()
            meDrawn = true
            local r, g, b = UI:Accent()
            self.meLv:ClearAllPoints(); self.meLv:SetPoint("TOPLEFT", 4, -(y))
            self.meLv:SetText(tostring(level)); self.meLv:SetTextColor(r, g, b)
            self.meLine:ClearAllPoints()
            self.meLine:SetPoint("TOPLEFT", 28, -(y + 6)); self.meLine:SetWidth(lw - 56)
            self.meLine:SetColorTexture(r, g, b, 1)
            self.meTxt:ClearAllPoints(); self.meTxt:SetPoint("TOPLEFT", lw - 22, -(y))
            self.meTxt:SetTextColor(r, g, b)
            y = y + 18
        end
        for _, a in ipairs(self.category and LFG:Activities(self.category) or {}) do
            if not meDrawn and a.min > level then drawMe() end
            local b = self.rungs:Get()
            b.act = a.id
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", 0, -y); b:SetWidth(lw)
            local n = counts[a.id] or 0
            b.lv:SetText(a.min > 0 and tostring(a.min) or "")
            b.name:SetText(a.name .. (n > 0 and ("  |cff999999· " .. n .. "|r") or ""))
            local far = a.min > 0 and (a.min > level + 5 or (a.max > 0 and a.max < level - 3))
            b:SetAlpha(far and 0.45 or 1)
            local sel = self.sel == a.id
            b.bg:SetColor(unpack(C.surface2)); b.bg:SetShown(sel)
            b.name:SetTextColor(unpack(sel and C.text or C.text))
            local r, g, bl = UI:Accent()
            b.bar:SetColorTexture(r, g, bl, 1)
            b.bar:SetWidth(math.max(1, (lw - 40) * n / maxN)); b.bar:SetShown(n > 0)
            y = y + 36
        end
        if not meDrawn then drawMe() end
        self.ladder.child:SetSize(lw, y)
        if self.ladder.UpdateBar then self.ladder:UpdateBar() end

        -- groupes
        self.heads:Reset(); self.cards:Reset(); self.solos:Reset(); self.empty:Hide()
        local W = self.center:GetWidth() or 600
        if W < 100 then W = 600 end
        local cols = math.max(1, math.floor((W - 14 + GAP) / (CARD_W + GAP)))
        local cw = math.floor((W - 14 - (cols - 1) * GAP) / cols)
        local mine, others, solos = {}, {}, {}
        for _, r in ipairs(LFG.results) do
            if not self.sel or r.activity == self.sel then
                if r.solo then table.insert(solos, r)
                else
                    local fit = LFG:FitRole(r)
                    if fit then table.insert(mine, { r, fit }) else table.insert(others, { r }) end
                end
            end
        end
        local cy = 0
        local function head(title, sub)
            local h = self.heads:Get()
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -cy); h:SetWidth(W - 14)
            h.title:SetText(title); h.sub:SetText(sub or "")
            cy = cy + 30
        end
        local function grid(list, dim)
            for i, it in ipairs(list) do
                local c = self.cards:Get()
                local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
                c:SetWidth(cw)
                c:ClearAllPoints(); c:SetPoint("TOPLEFT", col * (cw + GAP), -(cy + row * (CARD_H + GAP)))
                self:PaintCard(c, it[1], it[2])
                if dim then c:SetAlpha(0.7) end
            end
            if #list > 0 then cy = cy + math.ceil(#list / cols) * (CARD_H + GAP) + 6 end
        end
        local function soloRow()
            local x = 0
            for _, r in ipairs(solos) do
                local b = self.solos:Get()
                local cr, cg, cb = classColor(r.class)
                b.dot:SetVertexColor(cr, cg, cb)
                b.name:SetText(r.leader or "?")
                local rl = {}
                for _, k in ipairs(ROLES) do if r.roles and r.roles[k] then table.insert(rl, T(LFG.ROLE_WORD[k])) end end
                b.sub:SetText((r.level and (r.level .. " · ") or "") .. table.concat(rl, ", "))
                local w = 28 + (b.name:GetStringWidth() or 60) + 6 + (b.sub:GetStringWidth() or 60) + 76
                if x > 0 and x + w > W - 14 then x = 0; cy = cy + 36 end
                b:SetWidth(w)
                b.edge:SetColor(unpack(C.border)); b.bg:SetColor(unpack(C.surface))
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, -cy)
                local q = r.leader and LFG.requests[r.leader]
                b.btn.label:SetText(q and T("Invité") or T("Inviter"))
                b.btn:SetScript("OnClick", function() LFG:Invite(r); self:Refresh() end)
                x = x + w + 6
            end
            if #solos > 0 then cy = cy + 40 end
        end
        local act = self.sel and LFG:Activity(self.sel)
        local where = act or T("tous les donjons")
        if #LFG.results == 0 then
            self.empty:Show()
            self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 0, -4); self.empty:SetWidth(W - 14)
            self.empty:SetText(LFG.searching and T("Recherche en cours…") or T("Choisis un donjon à gauche (ou aucun pour tous), puis clique Actualiser."))
            cy = 40
        elseif cfg.mode == "players" then
            head(T("Joueurs seuls"), string.format(T("%d pour %s"), #solos, where))
            soloRow()
            head(T("Groupes"), string.format(T("%d groupes"), #mine + #others))
            local all = {}
            for _, it in ipairs(mine) do table.insert(all, it) end
            for _, it in ipairs(others) do table.insert(all, it) end
            grid(all, true)
        else
            local roleTxt = {}
            for _, k in ipairs(ROLES) do if cfg.roles[k] then table.insert(roleTxt, T(LFG.ROLE_WORD[k])) end end
            head(T("Une place pour toi"), #mine > 0 and string.format(T("%d groupes cherchent %s · %s"), #mine, table.concat(roleTxt, " / "), where)
                or T("aucun groupe ne cherche tes rôles pour l'instant"))
            grid(mine)
            if #others > 0 then head(T("Autres groupes"), T("complets ou sans place pour ton rôle")); grid(others, true) end
            if #solos > 0 then head(T("Joueurs seuls"), T("pour monter ton propre groupe")); soloRow() end
        end
        self.scroll.child:SetSize(W, cy + 10)
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end

        -- mes demandes
        self.reqs:Reset()
        local list = {}
        for name, q in pairs(LFG.requests) do table.insert(list, { name = name, q = q }) end
        table.sort(list, function(a, b) return a.q.t > b.q.t end)
        local ry = 36
        for i, e in ipairs(list) do
            if i > 6 then break end
            local row = self.reqs:Get()
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 14, -ry)
            local q = e.q
            local col = (q.state == "answer" and C.positive) or (q.state == "closed" and C.dim) or C.gold
            row.dot:SetVertexColor(unpack(col))
            row.name:SetText(e.name .. "  |cff999999" .. ago(time() - q.t) .. "|r")
            if q.state == "answer" then row.l1:SetText("« " .. (q.reply or "") .. " »"); row.l1:SetTextColor(unpack(C.positive))
            elseif q.state == "closed" then row.l1:SetText(T("groupe retiré depuis")); row.l1:SetTextColor(unpack(C.muted))
            elseif q.state == "invited" then row.l1:SetText(T("invité dans ton groupe")); row.l1:SetTextColor(unpack(C.muted))
            else row.l1:SetText(T("en attente de réponse")); row.l1:SetTextColor(unpack(C.muted)) end
            row.l2:SetText(q.activity or "")
            ry = ry + 54
        end
        self.noReq:SetShown(#list == 0)
        local fitName = act or nil
        self.msgPreview:SetText("|cff999999" .. T("Envoyé :") .. "|r " .. LFG:Message(fitName))
    end,
})

-- Résultats et réponses : la page se met à jour d'elle-même (WK:NotifyChanged).
