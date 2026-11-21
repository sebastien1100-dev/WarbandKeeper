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
local CARD_W, CARD_H = 286, 108
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
        playHd:SetPoint("TOPLEFT", 222, -10)
        playHd:SetText(T("JE JOUE"))
        self.roleBtns = {}
        local x = 222
        for _, role in ipairs(ROLES) do
            local b = CreateFrame("Button", nil, banner)
            b:SetSize(78, 24)
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
            x = x + 84
        end
        -- Inscrit les rôles pour la recherche des réglages : ligne posée sur l'en-tête et les boutons
        -- (son libellé est masqué, « JE JOUE » reste le titre affiché).
        local roleRow = UI:SettingRow(banner, 0, "Je joue (mes rôles)", nil, nil)
        roleRow.label:Hide()
        roleRow:ClearAllPoints()
        roleRow:SetPoint("TOPLEFT", playHd, "TOPLEFT", -4, 2)
        roleRow:SetPoint("BOTTOMRIGHT", self.roleBtns[ROLES[#ROLES]], "BOTTOMRIGHT", 4, -2)

        local lookHd = UI:Text(banner, 10, C.dim)
        lookHd:SetPoint("TOPLEFT", x + 14, -10)
        lookHd:SetText(T("JE CHERCHE"))
        self.modeSeg = UI:Segmented(banner, { { "group", "Un groupe" }, { "players", "Des joueurs" } },
            function(v) cfg.mode = v; self:Refresh() end, 24)
        self.modeSeg:SetPoint("TOPLEFT", x + 14, -26)
        self.modeSeg:Select(cfg.mode)
        -- Fenêtre étroite : le bandeau se resserre (rôles plus courts, sans la classe sous le nom,
        -- l'état de la recherche passe dans l'infobulle d'Actualiser) pour que rien ne se chevauche.
        self.playHd, self.lookHd = playHd, lookHd
        UI:OnResize(banner, function(w)
            if not w or w <= 0 then return end
            local narrow = w < 1000
            local start = narrow and 196 or 222
            local bw, step = narrow and 70 or 78, narrow and 74 or 84
            self.meSub:SetShown(not narrow)
            playHd:ClearAllPoints(); playHd:SetPoint("TOPLEFT", start, -10)
            local xx = start
            for _, role in ipairs(ROLES) do
                local b = self.roleBtns[role]
                b:SetWidth(bw); b:ClearAllPoints(); b:SetPoint("TOPLEFT", xx, -26)
                xx = xx + step
            end
            lookHd:ClearAllPoints(); lookHd:SetPoint("TOPLEFT", xx + 10, -10)
            self.modeSeg:ClearAllPoints(); self.modeSeg:SetPoint("TOPLEFT", xx + 10, -26)
            self.narrow = narrow
            if self.status then self.status:SetShown(not narrow) end
        end)

        self.searchBtn = UI:Button(banner, "Actualiser", 110, 26, "primary", "refresh")
        self.searchBtn:SetPoint("TOPRIGHT", -14, -8)
        self.searchBtn:SetScript("OnClick", function() self:DoSearch() end)
        self.searchBtn:HookScript("OnEnter", function(s)
            if not self.narrow then return end
            WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.status:GetText() or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        self.searchBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        self.refineBtn = UI:IconButton(banner, "filter", 26)
        self.refineBtn:SetPoint("RIGHT", self.searchBtn, "LEFT", -8, 0)
        self.refineBtn:SetScript("OnClick", function() self:ToggleRefine() end)
        self.refineBtn:SetScript("OnEnter", function(s)
            WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
            GameTooltip:SetText(T("Affiner"), 1, 1, 1)
            GameTooltip:AddLine(T("Classes et niveau des joueurs seuls, style de jeu, langues."), 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        self.refineBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        self.refineDot = UI:Icon(self.refineBtn, "circle", 8, nil, "OVERLAY")
        self.refineDot:SetPoint("TOPRIGHT", 1, 1)
        self.status = UI:Text(banner, 11, C.muted)
        self.status:SetPoint("TOPRIGHT", self.searchBtn, "BOTTOMRIGHT", -4, -4)
        self.status:SetJustifyH("RIGHT")
        if self.narrow then self.status:Hide() end

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
            -- autre catégorie : les groupes de l'ancienne ne sont plus montrés
            if v ~= self.category then LFG:ClearResults() end
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
            -- nombre de groupes : pastille à droite, toujours lisible (le nom se coupe avant)
            b.cnt = CreateFrame("Frame", nil, b)
            b.cnt:SetSize(22, 16); b.cnt:SetPoint("TOPRIGHT", -6, -6)
            b.cnt.bg = UI:Rounded(b.cnt, 8, 0, "ARTWORK", 1)
            b.cnt.t = UI:Text(b.cnt, 10, C.onAccent); b.cnt.t:SetPoint("CENTER", 0, 0)
            b.name = UI:Text(b, 12)
            b.name:SetPoint("TOPLEFT", 32, -6)
            b.name:SetPoint("RIGHT", b.cnt, "LEFT", -6, 0)
            b.name:SetJustifyH("LEFT")
            b.bar = b:CreateTexture(nil, "ARTWORK")
            b.bar:SetPoint("TOPLEFT", 32, -24)
            b.bar:SetHeight(3)
            -- donjon choisi : liseré d'accent à gauche
            b.edge = b:CreateTexture(nil, "ARTWORK", nil, 2)
            b.edge:SetPoint("TOPLEFT", 0, -4); b.edge:SetPoint("BOTTOMLEFT", 0, 4); b.edge:SetWidth(3)
            b.edge:Hide()
            b:SetScript("OnEnter", function(s) if not s.sel then s.bg:SetColor(unpack(C.hover)); s.bg:Show() end end)
            b:SetScript("OnLeave", function(s) if not s.sel then s.bg:Hide() end end)
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
        self.rightTab = "requests"
        self.rightSeg = UI:Segmented(right, { { "requests", "Mes demandes" }, { "recent", "Récents" } },
            function(v) self.rightTab = v; self:Refresh() end, 24)
        self.rightSeg:SetPoint("TOPLEFT", 12, -10)
        self.rightSeg:Select("requests")
        -- liste de droite (demandes ou récents) : zone qui défile, entre les onglets et « MON MESSAGE »
        local rlist = UI:Scroll(right)
        rlist:SetPoint("TOPLEFT", 0, -42)
        rlist:SetPoint("BOTTOMRIGHT", -4, 150)
        rlist.child:SetWidth(RIGHT_W - 16)
        self.rlist = rlist
        -- joueurs croisés en groupe, avec leur note (1 à 3 étoiles)
        self.recents = UI:Pool(function()
            local r = CreateFrame("Frame", nil, rlist.child)
            r:SetSize(RIGHT_W - 28, 40)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 0, 0)
            r.name:SetPoint("RIGHT", -62, 0)
            r.name:SetJustifyH("LEFT")
            r.name:SetWordWrap(false)
            r.sub = UI:Text(r, 10, C.dim)
            r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
            r.sub:SetPoint("RIGHT", -62, 0)
            r.sub:SetJustifyH("LEFT")
            r.sub:SetWordWrap(false)
            r.stars = {}
            for i = 1, 3 do
                local st = CreateFrame("Button", nil, r)
                st:SetSize(18, 18)
                st:SetPoint("TOPRIGHT", -(3 - i) * 20, 0)
                st.tex = UI:Icon(st, "star", 16, nil, "ARTWORK")
                st.tex:SetPoint("CENTER")
                st:SetScript("OnClick", function()
                    if not r.player then return end
                    LFG:SetRating(r.player, LFG:Rating(r.player) == i and 0 or i)
                    self:Refresh()
                end)
                r.stars[i] = st
            end
            return r
        end)
        self.noRecent = UI:Text(right, 11, C.dim)
        self.noRecent:SetPoint("TOPLEFT", 14, -46)
        self.noRecent:SetPoint("RIGHT", -14, 0)
        self.noRecent:SetJustifyH("LEFT")
        self.noRecent:SetText(T("Les joueurs avec qui tu fais un groupe apparaîtront ici. Note-les de 1 à 3 étoiles : 1 étoile les met en bas des listes et tu es prévenu s'ils rejoignent ton groupe."))
        self.reqs = UI:Pool(function()
            local r = CreateFrame("Frame", nil, rlist.child)
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
        self.noReq:SetPoint("TOPLEFT", 14, -46)
        self.noReq:SetPoint("RIGHT", -14, 0)
        self.noReq:SetJustifyH("LEFT")
        self.noReq:SetText(T("Aucune demande pour l'instant."))
        local msgHd = UI:Text(right, 10, C.dim)
        msgHd:SetPoint("BOTTOMLEFT", 14, 130)
        msgHd:SetText(T("MON MESSAGE"))
        self.msgBox = UI:Input(right, RIGHT_W - 28, 30)
        self.msgBox:SetPoint("BOTTOMLEFT", 14, 92)
        self.msgBox:SetText(cfg.message)
        self.msgBox.edit:HookScript("OnEditFocusLost", function() cfg.message = self.msgBox:GetText(); self:Refresh() end)
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
        -- Inscrit le message pour la recherche des réglages (libellé masqué, « MON MESSAGE » reste affiché).
        local msgRow = UI:SettingRow(right, 0, "Mon message (demande de groupe)", nil, nil)
        msgRow.label:Hide()
        msgRow:ClearAllPoints()
        msgRow:SetPoint("TOPLEFT", msgHd, "TOPLEFT", -4, 4)
        msgRow:SetPoint("BOTTOMRIGHT", self.msgBox, "BOTTOMRIGHT", 4, -4)

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
            c.rate = c:CreateTexture(nil, "ARTWORK")
            c.rate:SetPoint("TOPLEFT", 1, -14)
            c.rate:SetPoint("BOTTOMLEFT", 1, 14)
            c.rate:SetWidth(3)
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
                s:SetPoint("TOPLEFT", 14 + (i - 1) * 32 + (i >= 3 and 8 or 0), -42)
                -- membre : logo de sa classe, trait de rôle dessous, couronne du chef posée dessus
                s.cls = UI:RoundIcon(s, 26)
                s.cls:SetPoint("CENTER")
                s.trait = s:CreateTexture(nil, "ARTWORK")
                s.trait:SetSize(20, 3)
                s.trait:SetPoint("TOP", s, "BOTTOM", 0, -3)
                -- couronne penchée, posée de travers sur le haut du logo, avec une ombre
                s.crownShadow = UI:Icon(s, "crown", 18, nil, "OVERLAY")
                s.crownShadow:SetDrawLayer("OVERLAY", 1)
                s.crownShadow:SetPoint("CENTER", s, "TOP", 6, 0)
                s.crown = UI:Icon(s, "crown", 18, nil, "OVERLAY")
                s.crown:SetDrawLayer("OVERLAY", 2)
                s.crown:SetPoint("CENTER", s, "TOP", 5, 2)
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
                self.hoverCard = s
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetText(WK.Latin(s.r.leader) or "?", 1, 1, 1)
                local act = LFG:Activity(s.r.activity)
                if act then GameTooltip:AddLine(act, 0.8, 0.8, 0.8) end
                if s.r.comment and s.r.comment ~= "" then GameTooltip:AddLine("« " .. s.r.comment .. " »", 0.9, 0.85, 0.7, true) end
                -- membres : classe, niveau, rôle
                local RW = { tank = "Tank", heal = "Soin", dps = "Dégâts" }
                for _, m in ipairs(s.r.list or {}) do
                    local cr, cg, cb = UI:ClassColor(m.class)
                    local cls = T(WK.modules.QoL.CLASS_LABEL[m.class or ""] or "?")
                    GameTooltip:AddDoubleLine((m.leader and UI:Hex(C.gold) .. "*|r " or "  ") .. (WK.Latin(m.name) or "?"),
                        cls .. (m.level and (" " .. m.level) or "") .. (m.role and (" · " .. T(RW[m.role])) or ""),
                        cr, cg, cb, 0.8, 0.8, 0.8)
                end
                -- buffs du groupe (classes et niveaux des membres), ce que tu ajoutes, ce qui manque
                if s.r.list and #s.r.list > 0 then
                    local gb = LFG:GroupBuffs(s.r)
                    local dim = C.dim
                    GameTooltip:AddLine(" ")
                    -- icônes des sorts : allumées (groupe), « + » vert (toi), éteintes (manquants) ; Maj = noms
                    local function icon(spell, off)
                        local _, ic = WK.SpellInfo(spell)
                        ic = ic or 134400
                        return "|T" .. ic .. ":18:18:0:0:64:64:5:59:5:59" .. (off and ":70:70:70" or "") .. "|t"
                    end
                    local function rows(list, prefix, off)
                        local line, n = prefix or "", 0
                        for _, b in ipairs(list) do
                            if b.spell then
                                line = line .. icon(b.spell, off) .. " "
                                n = n + 1
                                if n % 10 == 0 then GameTooltip:AddLine(line); line = prefix and "    " or "" end
                            end
                        end
                        if n % 10 ~= 0 then GameTooltip:AddLine(line) end
                    end
                    local nCamp = 0
                    for _ in pairs(gb.camp) do nCamp = nCamp + 1 end
                    if not IsShiftKeyDown() then
                        GameTooltip:AddLine(string.format(T("Buffs du groupe · %d"), #gb.have)
                            .. (#gb.mine > 0 and ("  " .. UI:Hex(C.positive) .. string.format(T("+%d avec toi"), #gb.mine) .. "|r") or ""), 1, 1, 1)
                        if #gb.have > 0 then rows(gb.have) end
                        if #gb.mine > 0 then rows(gb.mine, UI:Hex(C.positive) .. "+|r ") end
                        if #gb.missing > 0 then rows(gb.missing, nil, true) end
                        if nCamp > 0 then
                            GameTooltip:AddLine(string.format(nCamp > 1 and T("Camp : %d de tes objets annulés") or T("Camp : %d de tes objets annulé"), nCamp), C.gold[1], C.gold[2], C.gold[3])
                        end
                        GameTooltip:AddLine(T("Maj : noms des buffs"), dim[1], dim[2], dim[3])
                    else
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(T("Buffs du groupe"), 1, 1, 1)
                        local function buffLine(b, prefix, lr, lg, lb)
                            local cr, cg, cb = UI:ClassColor(b.class)
                            local who = T(WK.modules.QoL.CLASS_LABEL[b.class or ""] or "?")
                            GameTooltip:AddDoubleLine(prefix .. T(b.name) .. (b.talent and (" " .. UI:Hex(C.dim) .. T("(si talent)") .. "|r") or ""),
                                who, lr or 0.92, lg or 0.92, lb or 0.92, cr, cg, cb)
                        end
                        if #gb.have > 0 then
                            GameTooltip:AddLine(UI:Upper(T("Dans le groupe")), dim[1], dim[2], dim[3])
                            for _, b in ipairs(gb.have) do buffLine(b, "") end
                        end
                        if #gb.mine > 0 then
                            GameTooltip:AddLine(UI:Upper(T("Avec toi en plus")), C.positive[1], C.positive[2], C.positive[3])
                            for _, b in ipairs(gb.mine) do buffLine(b, UI:Hex(C.positive) .. "+|r ") end
                        end
                        if #gb.missing > 0 then
                            GameTooltip:AddLine(UI:Upper(T("Manquants")), dim[1], dim[2], dim[3])
                            for _, m in ipairs(gb.missing) do
                                GameTooltip:AddDoubleLine(T(m.label), T(WK.modules.QoL.CLASS_LABEL[m.class] or "?"), dim[1], dim[2], dim[3], dim[1], dim[2], dim[3])
                            end
                        end
                        local camp = {}
                        for name, prof in pairs(gb.camp) do table.insert(camp, string.format(T("%s annule l'objet de camp (%s)"), T(name), T(prof))) end
                        if #camp > 0 then
                            table.sort(camp)
                            GameTooltip:AddLine(T("Camp :") .. " " .. table.concat(camp, " ; "), C.gold[1], C.gold[2], C.gold[3], true)
                        end
                    end
                    end
                local ps = LFG:PlaystyleLabel(s.r.playstyle)
                if ps then GameTooltip:AddLine(T(ps), 0.7, 0.7, 0.7) end
                local rt = LFG:Rating(s.r.leader)
                GameTooltip:AddLine(rt and string.format(T("Ta note : %d étoile(s)"), rt) or T("Pas encore noté"), 0.88, 0.74, 0.45)
                GameTooltip:AddLine(T("Clic droit : noter le chef (1, 2, 3 étoiles, aucune)"), 0.6, 0.6, 0.6)
                GameTooltip:Show()
            end)
            c:SetScript("OnMouseUp", function(s, button)
                if button ~= "RightButton" or not s.r or not s.r.leader then return end
                local cur = LFG:Rating(s.r.leader) or 0
                LFG:SetRating(s.r.leader, (cur + 1) % 4)
                self:Refresh()
                if s:IsMouseOver() then s:GetScript("OnEnter")(s) end
            end)
            c:SetScript("OnLeave", function() self.hoverCard = nil; GameTooltip:Hide() end)
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
        self.empty:SetJustifyV("TOP")
        if self.empty.SetWordWrap then self.empty:SetWordWrap(true) end
        UI:OnResize(center, function() self:Refresh() end)
    end,

    -- Panneau « Affiner » : construit à la première ouverture (les langues du jeu sont alors connues).
    ToggleRefine = function(self)
        if not self.refine then self:BuildRefine() end
        self.refine:SetShown(not self.refine:IsShown())
    end,

    BuildRefine = function(self)
        local f = LFG:Config().filters
        local pnl = CreateFrame("Frame", nil, self.center:GetParent())
        pnl:SetFrameStrata("DIALOG")
        pnl:SetSize(470, 300)
        pnl:SetPoint("TOPRIGHT", self.refineBtn:GetParent(), "BOTTOMRIGHT", 0, -6)
        pnl:EnableMouse(true)
        UI:Panel(pnl, 12, { C.bg[1], C.bg[2], C.bg[3], 0.98 }, C.border)
        self.refine = pnl
        local chips = {}
        local function chip(label, get, set, color)
            local b = CreateFrame("Button", nil, pnl)
            b:SetHeight(22)
            b.edge = UI:Rounded(b, 11, 0, "BACKGROUND", 0)
            b.bg = UI:Rounded(b, 10, 1, "BACKGROUND", 1)
            b.label = UI:Text(b, 11)
            b.label:SetPoint("CENTER", color and 5 or 0, 0)
            b.label:SetText(label)
            if color then
                b.dot = UI:Icon(b, "circle", 8, nil, "ARTWORK")
                b.dot:SetPoint("RIGHT", b.label, "LEFT", -5, 0)
                b.dot:SetVertexColor(unpack(color))
            end
            b:SetWidth((b.label:GetStringWidth() or 40) + (color and 34 or 22))
            function b:Paint()
                local on = get()
                local r, g, bl = UI:Accent()
                self.edge:SetColor(unpack(on and { r, g, bl, 1 } or C.border))
                self.bg:SetColor(unpack(on and C.surface2 or C.surface))
                self.label:SetTextColor(unpack(on and C.text or C.muted))
            end
            b:SetScript("OnClick", function(s) set(not get()); s:Paint(); self:Refresh() end)
            table.insert(chips, b)
            return b
        end
        local y = -14
        local function title(t, sub)
            local h = UI:Text(pnl, 11, C.text)
            h:SetPoint("TOPLEFT", 14, y)
            h:SetText(t)
            if sub then
                local d = UI:Text(pnl, 10, C.dim)
                d:SetPoint("LEFT", h, "RIGHT", 8, 0)
                d:SetText(sub)
            end
            y = y - 22
        end
        local function flow(list)
            local x = 14
            for _, b in ipairs(list) do
                local w = b:GetWidth()
                if x + w > 456 then x = 14; y = y - 28 end
                b:SetPoint("TOPLEFT", x, y)
                x = x + w + 6
            end
            y = y - 36
        end
        -- classes des joueurs seuls
        title(T("Joueurs seuls : classes"), T("aucune cochée = toutes"))
        local cl = {}
        for _, c in ipairs(WK.modules.QoL.CLASSES) do
            local key = c[1]
            local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[key]
            table.insert(cl, chip(T(c[2]), function() return f.classes[key] end,
                function(v) f.classes[key] = v or nil end, cc and { cc.r, cc.g, cc.b, 1 } or nil))
        end
        flow(cl)
        -- niveau des joueurs seuls
        title(T("Joueurs seuls : niveau"))
        local function lvlBox(field, x, ph)
            local box = UI:Input(pnl, 60, 26, ph)
            box:SetPoint("TOPLEFT", x, y + 4)
            box:SetText(f[field] and tostring(f[field]) or "")
            box.edit:HookScript("OnEditFocusLost", function()
                f[field] = tonumber(box:GetText()); self:Refresh()
            end)
            return box
        end
        lvlBox("minLevel", 14, T("min"))
        local to = UI:Text(pnl, 11, C.muted)
        to:SetPoint("TOPLEFT", 82, y - 2)
        to:SetText(T("à"))
        lvlBox("maxLevel", 98, T("max"))
        y = y - 40
        -- style de jeu
        title(T("Style de jeu"), T("aucun coché = tous"))
        local ps = {}
        for _, p in ipairs(LFG.PLAYSTYLES) do
            table.insert(ps, chip(T(p.label), function() return f.playstyles[p.key] end, function(v) f.playstyles[p.key] = v or nil end))
        end
        flow(ps)
        -- langues (prises en compte à la prochaine recherche)
        local langs = LFG:Languages()
        if #langs > 0 then
            title(T("Langues"), T("à la prochaine recherche"))
            local NAMES = { frFR = "Français", enUS = "English", enGB = "English", deDE = "Deutsch", esES = "Español", esMX = "Español (MX)",
                            itIT = "Italiano", ptBR = "Português", ruRU = "Russe", koKR = "Coréen", zhCN = "Chinois", zhTW = "Chinois trad." }
            local lc = {}
            for _, l in ipairs(langs) do
                local b = chip(NAMES[l.code] or l.code, function() return l.locked or f.languages[l.code] end,
                    function(v) if not l.locked then f.languages[l.code] = v or nil end end)
                if l.locked then b:SetAlpha(0.6) end
                table.insert(lc, b)
            end
            flow(lc)
        end
        local reset = UI:Button(pnl, "Réinitialiser", 110, 24, "ghost")
        reset:SetPoint("BOTTOMLEFT", 12, 10)
        reset:SetScript("OnClick", function()
            f.classes, f.playstyles, f.languages, f.minLevel, f.maxLevel = {}, {}, {}, nil, nil
            local cfg = LFG:Config()
            cfg.filters = f
            for _, b in ipairs(chips) do b:Paint() end
            pnl:Hide(); self.refine = nil
            self:Refresh()
        end)
        local close = UI:Button(pnl, "Fermer", 80, 24, "primary")
        close:SetPoint("BOTTOMRIGHT", -12, 10)
        close:SetScript("OnClick", function() pnl:Hide() end)
        pnl:SetHeight(-y + 44)
        for _, b in ipairs(chips) do b:Paint() end
        pnl:Hide()
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
        local name = WK.Latin(r.leader) or "?"
        local nr, ng, nb = classColor(r.class)
        if r.friend or r.guild then nr, ng, nb = C.tank[1], C.tank[2], C.tank[3] end
        if r.delisted then nr, ng, nb = C.dim[1], C.dim[2], C.dim[3] end
        c.name:SetText(name .. (r.level and ("  " .. UI:Hex(C.muted) .. r.level .. "|r") or ""))
        c.name:SetTextColor(nr, ng, nb)
        local tag = r.friend and T("ami") or (r.guild and T("guilde") or nil)
        c.age:SetText((tag and (tag .. " · ") or "") .. ago(r.age))
        -- places : tank, soin, trois dégâts
        local cnt = r.counts or {}
        local order = { "tank", "heal", "dps", "dps", "dps" }
        local seen = { tank = 0, heal = 0, dps = 0 }
        local youPlaced = false
        -- membres à placer : d'abord par rôle connu, sinon dans l'ordre
        local pool = {}
        for _, m in ipairs(r.list or {}) do table.insert(pool, m) end
        local function take(role)
            for k, m in ipairs(pool) do if m.role == role then return table.remove(pool, k) end end
            for k, m in ipairs(pool) do if not m.role then return table.remove(pool, k) end end
        end
        for i, role in ipairs(order) do
            seen[role] = seen[role] + 1
            local s = c.slots[i]
            local col = C[role]
            local taken = r.counts and seen[role] <= (cnt[role] or 0)
            local m = taken and take(role) or nil
            s.cls:Hide(); s.trait:Hide(); s.crown:Hide(); s.crownShadow:Hide()
            if m and m.class then
                s.fill:Hide(); s.ring:Hide(); s.txt:SetText("")
                UI:SetClassIcon(s.cls, m.class); s.cls:Show()
                s.trait:SetColorTexture(unpack(col)); s.trait:Show()
                if m.leader then
                    s.crown:SetVertexColor(unpack(C.gold)); s.crown:Show()
                    s.crownShadow:SetVertexColor(0, 0, 0, 0.6); s.crownShadow:Show()
                end
            elseif taken then
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
        local ps = LFG:PlaystyleLabel(r.playstyle)
        local note = r.comment ~= "" and ("« " .. r.comment .. " »") or (ps and T(ps)) or (LFG:Activity(r.activity) or "")
        local rt = LFG:Rating(r.leader)
        local RC = { C.negative, C.muted, C.positive }
        c.rate:SetShown(rt ~= nil)
        if rt then c.rate:SetColorTexture(unpack(RC[rt])) end
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
        elseif LFG.failed then
            self.status:SetText(UI:Hex(C.negative) .. T("la recherche a échoué : réessaie dans un instant") .. "|r")
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
            b.name:SetText(a.name)
            b.cnt:SetShown(n > 0)
            if n > 0 then
                local ar, ag, ab = UI:Accent()
                b.cnt.bg:SetColor(ar, ag, ab, 1)
                b.cnt.t:SetText(tostring(n))
                b.cnt:SetWidth(math.max(22, (b.cnt.t:GetStringWidth() or 8) + 12))
            end
            b.name:SetPoint("RIGHT", n > 0 and b.cnt or b, n > 0 and "LEFT" or "RIGHT", -6, 0)
            local far = a.min > 0 and (a.min > level + 5 or (a.max > 0 and a.max < level - 3))
            local sel = self.sel == a.id
            b.sel = sel
            b:SetAlpha((far and not sel) and 0.45 or 1)
            local r, g, bl = UI:Accent()
            -- mis en valeur : fond teinté d'accent, liseré, nom et niveau à la couleur d'accent
            if sel then b.bg:SetColor(r, g, bl, 0.18) else b.bg:SetColor(unpack(C.hover)) end
            b.bg:SetShown(sel)
            b.edge:SetColorTexture(r, g, bl, 1); b.edge:SetShown(sel)
            if sel then b.name:SetTextColor(r, g, bl); b.lv:SetTextColor(r, g, bl)
            else b.name:SetTextColor(unpack(C.text)); b.lv:SetTextColor(unpack(C.dim)) end
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
            if (not self.sel or r.activity == self.sel) and LFG:PassFilters(r) then
                if r.solo then table.insert(solos, r)
                else
                    local fit = LFG:FitRole(r)
                    if fit then table.insert(mine, { r, fit }) else table.insert(others, { r }) end
                end
            end
        end
        -- les joueurs notés 1 étoile passent en bas de leur liste
        local function low(r) return LFG:Rating(r.leader) == 1 end
        local function bottomLow(list, get)
            local keep, last = {}, {}
            for _, it in ipairs(list) do if low(get(it)) then table.insert(last, it) else table.insert(keep, it) end end
            for _, it in ipairs(last) do table.insert(keep, it) end
            return keep
        end
        local first = function(it) return it[1] end
        mine, others = bottomLow(mine, first), bottomLow(others, first)
        solos = bottomLow(solos, function(r) return r end)
        local cy = 0
        -- quêtes du donjon choisi : nombre à prendre, et un bouton qui les coche et mène aux donneurs
        do
            local qs = self.questStrip
            if not qs then
                qs = UI:Card(self.scroll.child)
                qs:SetHeight(46)
                qs.icon = UI:Icon(qs, "book", 18, nil, "ARTWORK"); qs.icon:SetPoint("LEFT", 14, 0)
                qs.text = UI:Text(qs, 12); qs.text:SetPoint("LEFT", qs.icon, "RIGHT", 10, 0)
                qs.text:SetPoint("RIGHT", qs, "RIGHT", -210, 0); qs.text:SetJustifyH("LEFT"); qs.text:SetWordWrap(false)
                qs.btn = UI:Button(qs, T("Prendre les quêtes"), 190, 28, "primary", "guide")
                qs.btn:SetPoint("RIGHT", -10, 0)
                qs.btn:SetScript("OnClick", function()
                    local Dg = WK.modules.Dungeons
                    if qs.dungeon and Dg then Dg:PickQuests(qs.dungeon) end
                    self:Refresh()
                end)
                qs.btn:SetScript("OnEnter", function(s)
                    UI:TooltipOwner(s, "ANCHOR_TOP")
                    GameTooltip:SetText(T("Prendre les quêtes du donjon"), 1, 1, 1)
                    local Qm = WK.modules.Quests
                    local s = qs.summary or { avail = {}, pre = {}, waiting = {} }
                    for _, q in ipairs(s.avail) do
                        GameTooltip:AddLine("• " .. Qm:Name(q) .. "  " .. UI:Hex(C.dim) .. "[" .. (q.lvl or "?") .. "]|r", 0.85, 0.85, 0.85)
                    end
                    if #s.pre > 0 then
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddLine(T("Prérequis à faire d'abord :"), C.warning[1], C.warning[2], C.warning[3])
                        for _, e in ipairs(s.pre) do
                            GameTooltip:AddLine("• " .. Qm:Name(e.q) .. "  " .. UI:Hex(C.dim) .. "[" .. (e.q.lvl or "?") .. "] » " .. Qm:Name(e.unlock) .. "|r", 0.85, 0.85, 0.85, true)
                        end
                    end
                    GameTooltip:AddLine(T("Elles sont cochées dans tes quêtes, et la flèche mène au donneur le plus proche, puis au suivant."), 0.6, 0.6, 0.6, true)
                    GameTooltip:Show()
                end)
                qs.btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
                self.questStrip = qs
            end
            local Dg = WK.modules.Dungeons
            local actName = self.sel and LFG:Activity(self.sel)
            local d = Dg and actName and Dg:ByName(actName)
            if d then
                local s = Dg:QuestSummary(d)
                qs.dungeon, qs.summary = d, s
                Dg.questWinLast = d.key -- fenêtre des quêtes en « Toujours » : ce donjon
                local n = Dg:PickCount(s)
                local parts = {}
                table.insert(parts, UI:Hex(#s.avail > 0 and C.gold or C.muted) .. string.format(T("%d à prendre"), #s.avail) .. "|r")
                if #s.pre > 0 or #s.waiting > 0 then
                    table.insert(parts, UI:Hex(C.warning) .. string.format(T("%d après prérequis"), #s.waiting) .. "|r")
                end
                if s.log > 0 then table.insert(parts, UI:Hex(C.positive) .. string.format(T("%d dans ton journal"), s.log) .. "|r") end
                if s.later > 0 then table.insert(parts, UI:Hex(C.muted) .. string.format(T("%d plus tard"), s.later) .. "|r") end
                if s.done > 0 then table.insert(parts, UI:Hex(C.dim) .. string.format(T("%d faites"), s.done) .. "|r") end
                local total = #s.avail + #s.waiting + s.log + s.later + s.done
                qs.text:SetText(total > 0 and (T("Quêtes du donjon :") .. " " .. table.concat(parts, "  ·  "))
                    or T("Aucune quête connue pour ce donjon."))
                local active = Dg.questPick and Dg.questPick.key == d.key
                qs.btn:SetLabel(active and T("Donneur suivant") or string.format(T("Prendre les quêtes (%d)"), n))
                qs.btn:SetShown(n > 0)
                qs:ClearAllPoints(); qs:SetPoint("TOPLEFT", 0, 0); qs:SetWidth(W - 14)
                qs:Show()
                cy = 46 + 12
            else
                qs:Hide(); qs.dungeon, qs.summary = nil, nil
            end
        end
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
                b.name:SetText(WK.Latin(r.leader) or "?")
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
            self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 0, -(cy + 4)); self.empty:SetWidth(W - 14)
            self.empty:SetText(LFG.searching and T("Recherche en cours…")
                or LFG.failed and T("La recherche a échoué (le jeu n'a pas répondu). Clique Actualiser pour réessayer.")
                or T("Choisis un donjon à gauche (ou aucun pour tous), puis clique Actualiser."))
            cy = cy + 40
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

        -- droite : mes demandes ou joueurs récents
        self.reqs:Reset(); self.recents:Reset()
        local showReq = self.rightTab == "requests"
        local _, g = LFG:Config()
        self.noRecent:SetShown(not showReq and #g.recent == 0)
        if not showReq then
            local ry2 = 4
            for i, e in ipairs(g.recent) do
                if i > 30 then break end
                local row = self.recents:Get()
                row.player = e.name
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", 14, -ry2)
                local cr, cg, cb = classColor(e.class)
                row.name:SetText(WK.Latin(e.name) .. (e.level and ("  " .. UI:Hex(C.muted) .. e.level .. "|r") or ""))
                row.name:SetTextColor(cr, cg, cb)
                row.sub:SetText((e.where and (e.where .. " · ") or "") .. ago(time() - (e.t or time())))
                local rt = LFG:Rating(e.name) or 0
                for k, st in ipairs(row.stars) do
                    local on = k <= rt
                    local col = rt == 1 and C.negative or (rt == 3 and C.positive or C.gold)
                    st.tex:SetVertexColor(unpack(on and col or C.border))
                end
                ry2 = ry2 + 42
            end
            self.rlist:SetContentHeight(ry2)
        end
        local list = {}
        for name, q in pairs(LFG.requests) do table.insert(list, { name = name, q = q }) end
        table.sort(list, function(a, b) return a.q.t > b.q.t end)
        local ry = 4
        for i, e in ipairs(list) do
            if i > 30 or not showReq then break end
            local row = self.reqs:Get()
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", 14, -ry)
            local q = e.q
            local col = (q.state == "answer" and C.positive) or (q.state == "closed" and C.dim) or C.gold
            row.dot:SetVertexColor(unpack(col))
            row.name:SetText(WK.Latin(e.name) .. "  " .. UI:Hex(C.muted) .. ago(time() - q.t) .. "|r")
            if q.state == "answer" then row.l1:SetText("« " .. (q.reply or "") .. " »"); row.l1:SetTextColor(unpack(C.positive))
            elseif q.state == "closed" then row.l1:SetText(T("groupe retiré depuis")); row.l1:SetTextColor(unpack(C.muted))
            elseif q.state == "invited" then row.l1:SetText(T("invité dans ton groupe")); row.l1:SetTextColor(unpack(C.muted))
            else row.l1:SetText(T("en attente de réponse")); row.l1:SetTextColor(unpack(C.muted)) end
            row.l2:SetText(q.activity or "")
            ry = ry + 54
        end
        if showReq then self.rlist:SetContentHeight(ry) end
        self.noReq:SetShown(showReq and #list == 0)
        self.refineDot:SetShown(LFG:FiltersActive())
        self.refineDot:SetVertexColor(UI:Accent())
        local fitName = act or nil
        self.msgPreview:SetText(UI:Hex(C.muted) .. T("Envoyé :") .. "|r " .. LFG:Message(fitName))
    end,
})

-- Résultats et réponses : la page se met à jour d'elle-même (WK:NotifyChanged).

-- Maj enfoncée ou relâchée pendant le survol d'un groupe : l'infobulle passe des icônes aux noms des buffs
WK:On("MODIFIER_STATE_CHANGED", function(key)
    local page = WK.UI.pages and WK.UI.pages.lfg
    local c = page and page.hoverCard
    if c and c:IsVisible() and c:IsMouseOver() and type(key) == "string" and key:find("SHIFT") then
        local f = c:GetScript("OnEnter")
        if f then f(c) end
    end
end)
