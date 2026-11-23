local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local MAX_ROWS = 150
local TOP_TABS = { { "all", "Tout le compte" }, { "stash", "Rangement" }, { "spread", "À regrouper" },
    { "old", "Oubliés en banque" }, { "locks", "Verrouillés" } }
local SWITCH_H, UNDER_H = 36, 30 -- interrupteur Objets / Courrier, onglets soulignés
local TOP_H = SWITCH_H + 8 + UNDER_H + 12 -- hauteur de la bande du haut
-- onglets du groupe COURRIER : page Courrier (UI/Pages/Mail.lua) posée dans Inventaire
local MAIL_TABS = { { "m:send", "Envoi", "send" }, { "m:bank", "Dépôt banque", "bank" },
    { "m:receive", "Réception", "receive" } }
local MAIL_OF = {}
for _, t in ipairs(MAIL_TABS) do MAIL_OF[t[1]] = t[3] end
local GAP = 12
local WHERE = { "bags", "bank", "mailbox" }
local WHERE_LABEL = { bags = "Sacs", bank = "Banque", mailbox = "Courrier" }

-- Contenu d'un emplacement ("bags", "bank", "mailbox") d'un personnage.
local function listOf(c, where)
    if where == "mailbox" then return c.mailbox and c.mailbox.items end
    return c[where]
end

local function countItems(t)
    local n, kinds = 0, 0
    for _, k in pairs(t or {}) do n = n + k; kinds = kinds + 1 end
    return n, kinds
end

-- Sacs par catégorie (vue principale) : { clé, libellé } dans l'ordre d'affichage
local CATS = {
    { "ammo", "Munitions" }, { "metal", "Métaux et pierres" }, { "cook", "Viande et poisson" },
    { "cloth", "Étoffes et cuir" }, { "herb", "Herbes" }, { "ench", "Enchantement" }, { "parts", "Autres composants" },
    { "cons", "Consommables" }, { "gear", "Équipement" }, { "recipe", "Recettes" }, { "quest", "Objets de quête" },
    { "misc", "Divers" },
}
local function catOf(id)
    local f = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local classID, subID
    if f then
        local ok, _, _, _, _, _, cl, sub = pcall(f, id)
        if ok then classID, subID = cl, sub end
    end
    if classID == 6 or classID == 11 then return "ammo" end
    if classID == 7 then
        if subID == 7 then return "metal" elseif subID == 8 then return "cook" elseif subID == 5 or subID == 6 then return "cloth"
        elseif subID == 9 then return "herb" elseif subID == 12 then return "ench" end
        return "parts"
    end
    if classID == 5 then return "parts" end
    if classID == 0 then return "cons" end
    if classID == 2 or classID == 4 then return "gear" end
    if classID == 9 then return "recipe" end
    if classID == 12 then return "quest" end
    return "misc"
end
local SLOT, SGAP = 40, 4

---------------------------------------------------------------------------
-- Répartition (maquette B) : menu flottant d'une case (famille × perso) ou d'un objet. Choix radio (titre +
-- explication), lignes de pastilles (plafond, stocks voulus), séparateurs ; un clic ailleurs le ferme.
---------------------------------------------------------------------------
-- exception qui a décidé d'un envoi (Stash:Compute, champ exc) : libellé et couleur de la pastille
local EXC_TAG = { prio = { "prioritaire", "rule" }, always = { "toujours", "rule" }, cap = { "plafond", "info" },
    stock = { "stock", "gold" }, main = { "perso principal", "accent" }, cons = { "stock voulu", "info" },
    gear = { "équipement", "muted" }, bank = { "perso banque", "info" } }
UI.STASH_EXC_TAG = EXC_TAG
local stashPop
local function popMenu()
    if stashPop then return stashPop end
    local blocker = _G.CreateFrame("Button", nil, _G.UIParent)
    blocker:SetAllPoints(_G.UIParent); blocker:SetFrameStrata("DIALOG"); blocker:SetFrameLevel(1)
    blocker:RegisterForClicks("AnyUp")
    blocker:Hide()
    local f = _G.CreateFrame("Frame", "WarbandKeeperStashMenu", _G.UIParent)
    f:SetFrameStrata("DIALOG"); f:SetFrameLevel(20); f:SetWidth(360); f:EnableMouse(true)
    f:SetClampedToScreen(true)
    UI:HudBackground(f, "window")
    f.title = UI:Text(f, 13); f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetPoint("TOPRIGHT", -14, -12)
    f.title:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 10, C.muted); f.sub:SetPoint("TOPLEFT", 14, -30); f.sub:SetPoint("TOPRIGHT", -14, -30)
    f.sub:SetJustifyH("LEFT")
    f.items = {}
    blocker:SetScript("OnClick", function() f:Hide() end)
    f:SetScript("OnHide", function() blocker:Hide() end)
    f:SetScript("OnShow", function() blocker:Show() end)
    if _G.UISpecialFrames then table.insert(_G.UISpecialFrames, "WarbandKeeperStashMenu") end
    local function choice(i)
        local b = f.items[i]
        if b and b.kind == "choice" then return b end
        if b then b:Hide() end
        b = _G.CreateFrame("Button", nil, f)
        b.kind = "choice"
        b.dot = UI:Icon(b, "circle", 12, nil, "ARTWORK"); b.dot:SetPoint("TOPLEFT", 10, -10)
        b.t = UI:Text(b, 12); b.t:SetPoint("TOPLEFT", 30, -7); b.t:SetPoint("TOPRIGHT", -8, -7); b.t:SetJustifyH("LEFT")
        b.d = UI:Text(b, 10, C.muted); b.d:SetPoint("TOPLEFT", 30, -23); b.d:SetPoint("TOPRIGHT", -8, -23)
        b.d:SetJustifyH("LEFT")
        b.bg = UI:Rounded(b, 8, 0, "BACKGROUND", 1)
        b:SetScript("OnClick", function(s) if s.fn then s.fn() end f:Hide() end)
        f.items[i] = b
        return b
    end
    -- liste : { { label, desc, on, col, fn } | { sep = true }
    --          | { seg = { label, opts = { { clé, libellé } }, sel, fn } } }
    function f:Open(anchor, title, sub, list)
        self.title:SetText(title or ""); self.sub:SetText(sub or "")
        for _, it in ipairs(self.items) do it:Hide() end
        local y = (sub and sub ~= "") and 50 or 36
        local W = self:GetWidth()
        for i, it in ipairs(list) do
            if it.sep then
                local b = self.items[i]
                if not (b and b.kind == "sep") then
                    if b then b:Hide() end
                    b = _G.CreateFrame("Frame", nil, self); b.kind = "sep"
                    b.l = b:CreateTexture(nil, "ARTWORK"); b.l:SetTexture("Interface\\Buttons\\WHITE8X8")
                    b.l:SetVertexColor(C.border[1], C.border[2], C.border[3], 1); b.l:SetAllPoints()
                    self.items[i] = b
                end
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 12, -(y + 4)); b:SetSize(W - 24, 1); b:Show()
                y = y + 10
            elseif it.seg then
                local b = self.items[i]
                if b then b:Hide() end
                b = _G.CreateFrame("Frame", nil, self); b.kind = "seg"
                b.t = UI:Text(b, 11, C.muted); b.t:SetPoint("LEFT", 2, 0); b.t:SetText(it.seg.label)
                b.s = UI:Segmented(b, it.seg.opts, function(v) it.seg.fn(v) end, 24)
                b.s:SetPoint("RIGHT", 0, 0); b.s:Select(it.seg.sel)
                self.items[i] = b
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 14, -y); b:SetSize(W - 28, 28); b:Show()
                y = y + 32
            else
                local b = choice(i)
                local col = it.col or { UI:Accent() }
                b.t:SetText(it.label); b.d:SetText(it.desc or "")
                b.dot:SetVertexColor(col[1], col[2], col[3], it.on and 1 or 0.25)
                b.bg:SetColor(col[1], col[2], col[3], it.on and 0.14 or 0)
                b.fn = it.fn
                local h = (it.desc and it.desc ~= "") and 40 or 28
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 6, -y); b:SetSize(W - 12, h); b:Show()
                y = y + h + 2
            end
        end
        self:SetHeight(y + 10)
        self:ClearAllPoints()
        if anchor then self:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4) else self:SetPoint("CENTER") end
        self:Show()
    end
    stashPop = f
    return f
end
UI.StashPopMenu = popMenu

-- menu « où va cet objet » (envois, fiche des sacs) : automatique, toujours à un perso, jamais, toujours à l'HV
function UI.StashItemMenu(_, id, anchor)
    local St = WK.modules.Stash
    if not (St and id) then return end
    local rule = St:ItemRule(id)
    local name = UI:ItemInfo(id)
    local list = {
        { label = T("Automatique"), desc = T("Suit la répartition par famille et les besoins des métiers."),
          on = rule == nil, fn = function() St:SetItemRule(id, nil) end },
        { label = T("Ne bouge jamais"), desc = T("Reste chez le perso qui l'a."), on = rule and rule.never,
          col = C.negative, fn = function() St:SetItemRule(id, { never = true }) end },
        { label = T("Toujours à l'HV"), desc = T("Part au perso HV pour être vendu."), on = rule and rule.ah,
          col = C.gold, fn = function() St:SetItemRule(id, { ah = true }) end },
        { sep = true },
    }
    for _, e in ipairs(UI:SortedCharacters()) do
        list[#list + 1] = { label = string.format(T("Toujours à %s"), WK:CharName(e.c, e.key)),
            on = rule and rule.to == e.key, col = C.rule, fn = function() St:SetItemRule(id, { to = e.key }) end }
    end
    popMenu():Open(anchor, name or ("#" .. id), T("Exception pour cet objet"), list)
end


UI:RegisterPage({
    key = "inventory", order = 3, nav = "Inventaire",
    -- pastille de la barre latérale : celle du courrier (ses onglets sont ici)
    count = function()
        local md = UI.pages.mail
        return md and md.count and WK:PageOn("mail") and md.count() or ""
    end,
    title = "Inventaire",
    subtitle = "Sacs, banques et courrier, par personnage ou pour tout le compte. Maj + clic sur une ligne pour lier l'objet.",

    Build = function(self, p)
        self.where = "all"
        self.query = ""
        local cfg = WK.DB.global.settings.ui
        self.char = cfg.invChar or "all"

        -- En haut (maquette B) : interrupteur Objets / Courrier, puis les onglets du groupe choisi, soulignés
        -- (la liste des persos est dans l'onglet « Tout le compte », à gauche de la recherche)
        local bar = _G.CreateFrame("Frame", nil, p)
        bar:SetHeight(SWITCH_H)
        bar:SetPoint("TOPLEFT", 0, 0)
        UI:Panel(bar, SWITCH_H / 2, C.surface, C.border)
        self.tabBar = bar
        bar.btns = {}
        for i, g in ipairs({ { "obj", "Objets", "bag" }, { "mail", "Courrier", "mail" } }) do
            local b = _G.CreateFrame("Button", nil, bar)
            b:SetHeight(SWITCH_H - 6)
            b.group = g[1]
            b.bg = UI:Rounded(b, (SWITCH_H - 6) / 2, 0, "BACKGROUND", 1)
            b.icon = UI:Icon(b, g[3], 15); b.icon:SetPoint("LEFT", 16, 0)
            b.name = UI:Text(b, 13); b.name:SetPoint("LEFT", b.icon, "RIGHT", 8, 0); b.name:SetText(T(g[2]))
            b.pill = _G.CreateFrame("Frame", nil, b); b.pill:SetSize(26, 20)
            b.pill:SetPoint("LEFT", b.name, "RIGHT", 8, 0)
            b.pillBg = UI:Rounded(b.pill, 10, 0, "BACKGROUND", 2)
            b.pillT = UI:Text(b.pill, 12, C.text); b.pillT:SetPoint("CENTER", 0, 0)
            function b:SetCount(n, warn)
                self.warn = warn
                self.pillT:SetText(tostring(n or 0))
                self.pill:SetWidth(math.max(26, (self.pillT:GetStringWidth() or 10) + 14))
                self:SetWidth(16 + 15 + 8 + (self.name:GetStringWidth() or 60) + 8 + self.pill:GetWidth() + 16)
            end
            function b:Paint()
                local r, g2, bb = UI:Accent()
                local sel = self.selected
                self.bg:SetColor(r, g2, bb, 1); self.bg:SetShown(sel)
                local tc = sel and C.onAccent or { r, g2, bb }
                self.name:SetTextColor(tc[1], tc[2], tc[3]); self.icon:SetVertexColor(tc[1], tc[2], tc[3])
                -- chiffres bien lisibles : pastille pleine et contrastée
                if sel then
                    self.pillBg:SetColor(C.bg[1], C.bg[2], C.bg[3], 1)
                    self.pillT:SetTextColor(C.text[1], C.text[2], C.text[3])
                elseif self.warn then
                    self.pillBg:SetColor(C.gold[1], C.gold[2], C.gold[3], 1)
                    self.pillT:SetTextColor(C.bg[1], C.bg[2], C.bg[3])
                else
                    self.pillBg:SetColor(r, g2, bb, 0.3)
                    self.pillT:SetTextColor(C.text[1], C.text[2], C.text[3])
                end
            end
            b:SetScript("OnClick", function(s2)
                -- chaque groupe retrouve son dernier onglet
                local ui = WK.DB.global.settings.ui
                local key = s2.group == "mail" and (ui.invLastMail or "m:send") or (ui.invLastObj or ui.invWho or "all")
                self.char = key; ui.invChar = key
                if self.gp and self.gp:IsOpen() then self.gp:Open(false) end
                self:Refresh()
            end)
            UI:OnAccent(function() b:Paint() end)
            bar.btns[i] = b
        end
        -- onglets soulignés (2e niveau), trait sur toute la largeur
        local under = _G.CreateFrame("Frame", nil, p)
        under:SetPoint("TOPLEFT", 0, -(SWITCH_H + 8)); under:SetPoint("TOPRIGHT", 0, -(SWITCH_H + 8))
        under:SetHeight(UNDER_H)
        under.line = under:CreateTexture(nil, "BACKGROUND")
        under.line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        under.line:SetHeight(1); under.line:SetPoint("BOTTOMLEFT"); under.line:SetPoint("BOTTOMRIGHT")
        self.underBar = under
        local band = _G.CreateFrame("Frame", nil, p)
        band:SetPoint("TOPLEFT"); band:SetPoint("TOPRIGHT"); band:SetHeight(TOP_H)
        self.band = band
        self.tabBtns = {}
        local allTabs = {}
        for _, tk in ipairs(TOP_TABS) do allTabs[#allTabs + 1] = tk end
        for _, tk in ipairs(MAIL_TABS) do allTabs[#allTabs + 1] = { tk[1], tk[2], mail = true } end
        for _, tk in ipairs(allTabs) do
            local b = _G.CreateFrame("Button", nil, under)
            b:SetHeight(UNDER_H)
            b.key = tk[1]
            b.mail = tk.mail
            b.name = UI:Text(b, 12)
            b.name:SetPoint("LEFT", 2, 1)
            b.name:SetText(T(tk[2]))
            b.pill = _G.CreateFrame("Frame", nil, b)
            b.pill:SetSize(22, 16)
            b.pill:SetPoint("LEFT", b.name, "RIGHT", 6, 0)
            b.pillBg = UI:Rounded(b.pill, 8, 0, "BACKGROUND", 2)
            b.pillT = UI:Text(b.pill, 10, C.muted); b.pillT:SetPoint("CENTER", 0, 0)
            b.bar = b:CreateTexture(nil, "ARTWORK")
            b.bar:SetHeight(2); b.bar:SetPoint("BOTTOMLEFT"); b.bar:SetPoint("BOTTOMRIGHT")
            function b:SetCount(n, warn)
                self.count, self.warn = n, warn
                self.pillT:SetText(n and tostring(n) or "")
                self.pill:SetShown(n ~= nil)
                self.pill:SetWidth(math.max(22, (self.pillT:GetStringWidth() or 10) + 12))
                self:SetWidth(2 + (self.name:GetStringWidth() or 60) + (n and (6 + self.pill:GetWidth()) or 0) + 2)
            end
            function b:Paint()
                local sel = self.selected
                local r, g, bb = UI:Accent()
                b.bar:SetColorTexture(r, g, bb, 1); b.bar:SetShown(sel)
                local tc = (sel or self.hover) and C.text or C.muted
                self.name:SetTextColor(tc[1], tc[2], tc[3])
                if self.warn then
                    self.pillBg:SetColor(C.gold[1], C.gold[2], C.gold[3], 0.2)
                    self.pillT:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
                else
                    self.pillBg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], 1)
                    self.pillT:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
                end
            end
            b:SetScript("OnEnter", function(s2)
                s2.hover = true; s2:Paint()
                if s2.tip and s2.tip ~= "" then
                    WK.UI:TooltipOwner(s2, "ANCHOR_BOTTOM")
                    _G.GameTooltip:SetText(s2.name:GetText() or "", 1, 1, 1)
                    _G.GameTooltip:AddLine(s2.tip, 0.75, 0.75, 0.75)
                    _G.GameTooltip:Show()
                end
            end)
            b:SetScript("OnLeave", function(s2) s2.hover = false; s2:Paint(); _G.GameTooltip:Hide() end)
            b:SetScript("OnClick", function(s2)
                -- « Tout le compte » : retrouve le perso choisi dans sa liste
                local ui = WK.DB.global.settings.ui
                local key = s2.key
                if key == "all" then key = ui.invWho or "all" end
                self.char = key
                ui.invChar = key
                if self.gp and self.gp:IsOpen() then self.gp:Open(false) end
                self:Refresh()
            end)
            UI:OnAccent(function() b:Paint() end)
            self.tabBtns[#self.tabBtns + 1] = b
        end

        -- Liste PERSO (onglet « Tout le compte ») ------------------------------------
        local who = _G.CreateFrame("Button", nil, p)
        who:SetSize(230, 34)
        who:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 0)
        UI:Panel(who, 17, C.surface, C.border)
        who.cap = UI:Text(who, 10, C.dim); who.cap:SetPoint("LEFT", 14, 0); who.cap:SetText(UI:Upper(T("Perso")))
        who.label = UI:Text(who, 12)
        who.label:SetPoint("LEFT", who.cap, "RIGHT", 8, 0); who.label:SetPoint("RIGHT", -28, 0)
        who.label:SetJustifyH("LEFT")
        if who.label.SetWordWrap then who.label:SetWordWrap(false) end
        who.arrow = UI:Icon(who, "chevron", 14, C.muted); who.arrow:SetPoint("RIGHT", -12, 0)
        self.whoBtn = who
        local menu = _G.CreateFrame("Frame", nil, who)
        menu:SetFrameStrata("DIALOG")
        menu:SetPoint("TOPLEFT", who, "BOTTOMLEFT", 0, -4)
        menu:SetWidth(250)
        UI:Panel(menu, 10, C.surface, C.border)
        menu:Hide()
        self.whoMenu = menu
        menu.rows = UI:Pool(function()
            local r = _G.CreateFrame("Button", nil, menu)
            r:SetHeight(28)
            r.bg = UI:Rounded(r, 7, 0, "BACKGROUND", 2)
            r.name = UI:Text(r, 12); r.name:SetPoint("LEFT", 10, 0)
            r.n = UI:Text(r, 11, C.muted); r.n:SetPoint("RIGHT", -10, 0); r.n:SetJustifyH("RIGHT")
            r:SetScript("OnEnter", function(s2) s2.hover = true; s2:Paint() end)
            r:SetScript("OnLeave", function(s2) s2.hover = false; s2:Paint() end)
            r.Paint = function(rr)
                rr.bg:SetColor(unpack(C.surface2))
                rr.bg:SetShown(rr.selected or rr.hover)
            end
            r:SetScript("OnClick", function(s2)
                menu:Hide()
                local ui = WK.DB.global.settings.ui
                ui.invWho = s2.key ~= "all" and s2.key or nil
                self.char = s2.key
                ui.invChar = s2.key
                self:Refresh()
            end)
            return r
        end)
        menu.head = UI:Text(menu, 9, C.dim); menu.head:SetText(UI:Upper(T("Persos")))
        menu.sep = menu:CreateTexture(nil, "ARTWORK"); menu.sep:SetHeight(1)
        menu.sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
        who:SetScript("OnClick", function()
            if menu:IsShown() then menu:Hide() else self:FillWhoMenu(); menu:Show() end
        end)
        who:SetScript("OnHide", function() menu:Hide() end)
        who:SetScript("OnEnter", function(s2) s2.border:SetColor(UI:Accent()) end)
        who:SetScript("OnLeave", function() self:PaintWho() end)

        -- Barre d'outils (droite) ----------------------------------------------------
        local x0 = 0
        local search = UI:Input(p, 280, 34, "Rechercher un objet...", "search")
        search:SetPoint("TOPLEFT", who, "TOPRIGHT", 10, 0)
        self.search = search
        search.onChange = function(text) self.query = string.lower(text or ""); self:Refresh() end

        self.whereSeg = UI:Segmented(p, { { "all", "Tout" }, { "bags", "Sacs" }, { "bank", "Banque" }, { "mailbox", "Courrier" } },
            function(key) self.where = key; self:Refresh() end, 34)
        self.whereSeg:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
        self.whereSeg:Select("all")
        -- Objets oubliés : depuis combien de jours
        self.oldDays = 14
        self.oldSeg = UI:Segmented(p, { { 7, "7 j" }, { 14, "14 j" }, { 30, "30 j" } },
            function(d) self.oldDays = d; self:Refresh() end, 34)
        self.oldSeg:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", 0, 0)
        self.oldSeg:Select(14)
        self.oldSeg:Hide()

        self.header = UI:Text(p, 14)
        self.header:SetPoint("TOPLEFT", band, "BOTTOMLEFT", x0 + 2, -48)
        self.info = UI:Text(p, 11, C.muted)
        self.info:SetPoint("BOTTOMLEFT", self.header, "BOTTOMRIGHT", 10, 1)
        self.countText = UI:Text(p, 11, C.muted)
        self.countText:SetPoint("TOPRIGHT", band, "BOTTOMRIGHT", -4, -50)
        self.countText:SetJustifyH("RIGHT")

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", band, "BOTTOMLEFT", x0, -74)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll
        self.empty = UI:Text(p, 12, C.muted)
        self.empty:SetPoint("CENTER", scroll, "CENTER")
        self:BuildLocks(p, x0)
        self:BuildStash(p, x0)
        -- Roue dentée : réglages des objets verrouillés (règles, protection) et du rangement (perso HV)
        -- onglets par catégorie (retenu dans settings.ui.invSetTab) : une catégorie à la fois dans le volet
        local SET_TABS = { { "rules", "Verrous auto" }, { "protect", "Protection" }, { "bags", "Sacs et marchand" }, { "stash", "Rangement" } }
        local function tabCards()
            return { rules = { self.lockRules }, protect = { self.lockSets }, bags = { self.bagSets }, stash = { self.stashSets } }
        end
        local function curTab()
            local t = WK.DB.global.settings.ui.invSetTab
            return tabCards()[t or ""] and t or "rules"
        end
        self.gp = UI:PageGear(p, { title = "Réglages de l'inventaire", top = 0, columns = 1, seeThrough = true,
            cards = function()
                local all, cur = tabCards(), curTab()
                for k, list in pairs(all) do
                    for _, c in ipairs(list) do if c and k ~= cur then c:Hide() end end
                end
                return all[cur]
            end }, self)
        -- recherche : un réglage d'une autre catégorie ouvre d'abord son onglet
        local prevReveal = self.RevealSetting
        self.RevealSetting = function(d, row)
            for k, list in pairs(tabCards()) do
                for _, c in ipairs(list) do
                    local f = row
                    while f do
                        if f == c then
                            WK.DB.global.settings.ui.invSetTab = k
                            if self.setSeg then self.setSeg:Select(k) end
                        end
                        f = f:GetParent()
                    end
                end
            end
            if prevReveal then return prevReveal(d, row) end
        end
        self.gp.gear:SetPoint("TOPRIGHT", 0, -2) -- sur la ligne de l'interrupteur
        -- au-dessus des vues (Rangement, verrous) qui la couvraient
        self.gp.gear:SetFrameLevel((p:GetFrameLevel() or 1) + 60)
        -- le volet couvre tout le contenu (rien ne dépasse au-dessus) ; ses cartes commencent sous la roue dentée
        self.gp.overlay:ClearAllPoints()
        self.gp.overlay:SetPoint("TOPLEFT", x0, 0)
        self.gp.overlay:SetPoint("BOTTOMRIGHT")
        self.gp.scroll:ClearAllPoints()
        self.gp.scroll:SetPoint("TOPLEFT", 0, -42)
        self.gp.scroll:SetPoint("BOTTOMRIGHT")
        -- la bande au-dessus des cartes (à hauteur de la roue dentée) porte le titre du volet, au lieu de rester vide
        self.gp.overlay.title = UI:Text(self.gp.overlay, 15, C.text)
        self.gp.overlay.title:SetPoint("TOPLEFT", 4, -9)
        self.gp.overlay.title:SetText(T("Réglages de l'inventaire"))
        self.gp.overlay.sub = UI:Text(self.gp.overlay, 11, C.muted)
        self.gp.overlay.sub:SetPoint("BOTTOMLEFT", self.gp.overlay.title, "BOTTOMRIGHT", 10, 1)
        self.gp.overlay.sub:SetText("")
        self.setSeg = UI:Segmented(self.gp.overlay, SET_TABS, function(v)
            WK.DB.global.settings.ui.invSetTab = v
            self.gp:Refresh()
            if self.gp.scroll.SetVerticalScroll then self.gp.scroll:SetVerticalScroll(0) end
        end, 26)
        self.setSeg:SetPoint("LEFT", self.gp.overlay.title, "RIGHT", 18, 0)
        self.setSeg:Select(curTab())
        -- Courrier (onglets du groupe COURRIER) : la page Courrier est construite ici, sous la barre d'onglets
        local host = _G.CreateFrame("Frame", nil, p)
        host:SetPoint("TOPLEFT", band, "BOTTOMLEFT", 0, 12)
        host:SetPoint("BOTTOMRIGHT")
        host:Hide()
        self.mailHost = host
        local md = UI.pages.mail
        if md and not md.frame then
            md.frame = host
            md.hosted = true
            local ok, err = pcall(md.Build, md, host)
            if not ok and WK.HandlerError then WK.HandlerError("page mail", err) end
            -- ses onglets sont dans la barre d'Inventaire ; sa roue dentée va sur la ligne des onglets
            if md.seg then md.seg:Hide() end
            if md.gp and md.gp.gear then
                md.gp.gear:ClearAllPoints(); md.gp.gear:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -2)
            end
            if md.status then md.status:ClearAllPoints(); md.status:SetPoint("TOPRIGHT", host, "TOPRIGHT", -4, -16) end
        end

        -- sacs par catégorie et leurs cases
        self.bags = UI:Pool(function()
            local b = CreateFrame("Frame", nil, scroll.child)
            UI:Panel(b, 10, C.surface, C.border)
            b.title = UI:Text(b, 12)
            b.title:SetPoint("TOPLEFT", 12, -10)
            b.sub = UI:Text(b, 10, C.muted)
            b.sub:SetPoint("TOPRIGHT", -12, -11)
            b.sub:SetJustifyH("RIGHT")
            return b
        end)
        self.slots = UI:Pool(function()
            local b = CreateFrame("Button", nil, scroll.child)
            b:SetSize(SLOT, SLOT)
            b:SetFrameLevel(scroll.child:GetFrameLevel() + 5)
            b.edge = b:CreateTexture(nil, "BACKGROUND")
            b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.edge:SetAllPoints()
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.hl:SetAllPoints(b.icon)
            b.hl:SetVertexColor(1, 1, 1, 0.15)
            b.n = b:CreateFontString(nil, "OVERLAY")
            b.n:SetFont(UI.FONT, 11, "OUTLINE")
            b.n:SetPoint("BOTTOMRIGHT", -2, 3)
            -- repère BiS : étoile en bas à gauche (or : liste du perso connecté, gris : autre perso)
            b.bisRing = b:CreateTexture(nil, "OVERLAY", nil, 5)
            b.bisRing:SetTexture(UI.MEDIA .. "circle"); b.bisRing:SetSize(17, 17); b.bisRing:SetPoint("BOTTOMLEFT", -3, -3)
            b.bisRing:SetVertexColor(0, 0, 0, 0.9)
            b.bisBadge = b:CreateTexture(nil, "OVERLAY", nil, 6)
            b.bisBadge:SetTexture(UI.MEDIA .. "circle"); b.bisBadge:SetSize(15, 15); b.bisBadge:SetPoint("CENTER", b.bisRing, "CENTER")
            b.bisStar = b:CreateTexture(nil, "OVERLAY", nil, 7)
            b.bisStar:SetTexture(UI.MEDIA .. "star"); b.bisStar:SetSize(10, 10); b.bisStar:SetPoint("CENTER", b.bisRing, "CENTER")
            b.bisStar:SetVertexColor(0.08, 0.06, 0.07, 1)
            b:SetScript("OnEnter", function(s)
                local it = s.it
                if not it then return end
                WK.UI:TooltipOwner(s, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(it.id)
                GameTooltip:AddLine(" ")
                GameTooltip:AddDoubleLine(T("Total"), tostring(it.total), 0.8, 0.8, 0.8, 1, 1, 1)
                local parts = {}
                for who, n in pairs(it.per) do table.insert(parts, { who, n }) end
                table.sort(parts, function(a, c) return a[2] > c[2] end)
                for i, v in ipairs(parts) do
                    if i > 8 then GameTooltip:AddLine(string.format(T("+ %d autre(s)"), #parts - 8), 0.6, 0.6, 0.6) break end
                    GameTooltip:AddDoubleLine(v[1], tostring(v[2]), 0.62, 0.64, 0.67, 1, 1, 1)
                end
                local price = WK.modules.Value:Price(it.id)
                if price > 0 then
                    GameTooltip:AddDoubleLine(T("Valeur"), string.format(T("%s l'unité · %s"), UI:GoldText(price), UI:GoldText(price * it.total)), 0.8, 0.8, 0.8, 1, 0.82, 0.3)
                end
                GameTooltip:AddLine(T("Maj+clic : lien dans le chat"), 0.5, 0.5, 0.5)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(s)
                local _, _, _, _, _, link = UI:ItemInfo(s.it and s.it.id)
                if IsModifiedClick("CHATLINK") and link then WK.InsertChatLink(link) end
            end)
            return b
        end)
        UI:OnResize(scroll, function() if self.lastList and scroll:IsVisible() then self:LayoutBags() end end)

        self.rows = UI:Pool(function()
            local r = CreateFrame("Button", nil, scroll.child)
            r:SetHeight(46)
            UI:Panel(r, 12, C.surface, C.border)
            r.icon = UI:RoundIcon(r, 28)
            r.icon:SetPoint("LEFT", 12, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 52, -9)
            r.name:SetPoint("TOPRIGHT", -210, -9)
            r.detail = UI:Text(r, 10, C.muted)
            r.detail:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
            r.detail:SetPoint("TOPRIGHT", r.name, "BOTTOMRIGHT", 0, -4)
            r.total = UI:Text(r, 15)
            r.total:SetPoint("TOPRIGHT", -16, -8)
            r.total:SetJustifyH("RIGHT")
            r.value = UI:Text(r, 10, C.muted)
            r.value:SetPoint("TOPRIGHT", r.total, "BOTTOMRIGHT", 0, -3)
            r.value:SetJustifyH("RIGHT")
            -- « Regrouper » (vue des objets dispersés)
            r.action = UI:Button(r, "Regrouper", nil, 26, "secondary", "mail")
            r.action:SetPoint("TOPRIGHT", -96, -10)
            r.action:Hide()
            r.action:SetScript("OnClick", function(b)
                local e = b.entry
                if not e then return end
                local tc = WK.DB.global.characters[e.target]
                if WK.modules.Mail:AddRule(e.itemID, WK.modules.Mail:MailName(tc), 0) then self:Refresh() end
            end)
            r:SetScript("OnEnter", function(row)
                row.bg:SetColor(unpack(C.surface2))
                WK.UI:TooltipOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(row.itemID)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(row)
                row.bg:SetColor(unpack(C.surface))
                GameTooltip:Hide()
            end)
            r:SetScript("OnClick", function(row)
                local _, _, _, _, _, link = UI:ItemInfo(row.itemID)
                if IsModifiedClick("CHATLINK") and link then WK.InsertChatLink(link) end
            end)
            return r
        end)
    end,

    -- Vues d'aide au rangement : objets dispersés (à regrouper) et objets oubliés en banque.
    RefreshHelp = function(self, sel)
        local Inv = WK.modules.Inventory
        local chars = WK.DB.global.characters
        local function who(key)
            if key == "warband" then return T("Bataillon") end
            local c = chars[key]
            local r, g, b = UI:ClassColor(c and c.class)
            return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, WK:CharName(c, key))
        end
        local list, trackedSince
        if sel == "spread" then
            list = Inv:Spread()
            self.header:SetText(T("À regrouper"))
            self.info:SetText(T("le même objet chez plusieurs persos"))
        else
            list, trackedSince = Inv:Forgotten(self.oldDays)
            self.header:SetText(T("Oubliés en banque"))
            self.info:SetText(trackedSince and string.format(T("suivi depuis le %s"), date("%d/%m", trackedSince))
                or T("suivi à partir de la prochaine ouverture des banques"))
        end
        self.header:SetTextColor(unpack(C.text))
        self.rows:Reset()
        local y, total = 0, 0
        for i, e in ipairs(list) do
            if i > MAX_ROWS then break end
            if self.query == "" or string.find(string.lower((UI:ItemInfo(e.itemID)) or ""), self.query, 1, true) then
                local r = self.rows:Get()
                r.itemID = e.itemID
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", 0, -y)
                r:SetPoint("TOPRIGHT", 0, -y)
                local name, icon, qr, qg, qb = UI:ItemInfo(e.itemID)
                r.icon:SetTexture(icon)
                r.name:SetText(name)
                r.name:SetTextColor(qr, qg, qb)
                r.name:SetPoint("TOPRIGHT", -210, -9) -- largeur d'origine (élargie à côté de « Regrouper »)
                if sel == "spread" then
                    local parts = {}
                    for _, h in ipairs(e.holders) do table.insert(parts, who(h.key) .. " " .. h.n) end
                    r.detail:SetText(table.concat(parts, "  ·  "))
                    r.total:SetText(tostring(e.total))
                    if e.rule then
                        r.value:SetText(string.format(T("déjà envoyé à %s"), who(e.target)))
                        r.action:Hide()
                    else
                        r.value:SetText(string.format(T("vers %s"), who(e.target)))
                        r.action.entry = e
                        r.action.tooltip = string.format(T("Crée une règle d'envoi : tes autres persos posteront cet objet à %s."), WK:CharName(chars[e.target], e.target))
                        -- bouton à gauche de la colonne de droite (nombre et « vers … »), jamais dessus
                        local wR = math.max(r.total:GetStringWidth() or 0, r.value:GetStringWidth() or 0)
                        r.action:ClearAllPoints(); r.action:SetPoint("TOPRIGHT", -(16 + wR + 14), -10)
                        r.name:SetPoint("TOPRIGHT", -(16 + wR + 14 + r.action:GetWidth() + 10), -9)
                        r.action:Show()
                    end
                else
                    r.action:Hide()
                    r.detail:SetText(string.format(T("%s · depuis %s"), who(e.key), UI:Ago(e.since)))
                    r.total:SetText(tostring(e.n))
                    r.value:SetText(T("env.") .. " " .. UI:GoldText(e.value))
                    total = total + e.value
                end
                y = y + 52
            end
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(y == 0)
        self.empty:SetText(sel == "spread" and T("Rien à regrouper : chaque objet est chez un seul perso.")
            or T("Rien d'oublié : aucun objet de valeur ne dort en banque depuis aussi longtemps."))
        if sel == "old" and total > 0 then
            self.countText:SetText(string.format(T("%d objets · env. %s à revendre"), #list, UI:GoldText(total)))
        else
            self.countText:SetText(string.format(#list > 1 and T("%d objets") or T("%d objet"), #list))
        end
    end,

    -- Objets verrouillés (Modules/ItemLock.lua) : liste, règles automatiques, réglages
    BuildLocks = function(self, p, x0)
        local IL = WK.modules.ItemLock
        local cfg = IL:Config()
        local pane = UI:Scroll(p)
        pane:SetPoint("TOPLEFT", self.band, "BOTTOMLEFT", x0, 0)
        pane:SetPoint("BOTTOMRIGHT")
        pane:Hide()
        self.lockPane = pane
        local root = pane.child
        -- liste
        local list = UI:Card(root, T("Objets verrouillés"), " ")
        self.lockList = list
        local all = UI:Button(list, "Tout déverrouiller", nil, 24, "ghost")
        all:SetPoint("TOPRIGHT", -10, -9)
        all.tooltip = "Maj + clic : enlève tous les verrous posés à la main (les règles restent)."
        all:SetScript("OnClick", function() if IsShiftKeyDown() then IL:UnlockAll() else WK:Print(T("Maj + clic pour tout déverrouiller.")) end end)
        -- une icône par objet (quantité, pastille : couleur d'accent = à la main, turquoise = règle) ;
        -- survol = détail, clic droit = déverrouiller (verrou à la main)
        local LS = 34
        self.lockIcons = UI:Pool(function()
            local b = CreateFrame("Button", nil, list)
            b:SetSize(LS, LS)
            b:RegisterForClicks("RightButtonUp")
            b.edge = b:CreateTexture(nil, "BACKGROUND")
            b.edge:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.edge:SetAllPoints()
            b.icon = b:CreateTexture(nil, "ARTWORK")
            b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
            b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            b.hl = b:CreateTexture(nil, "HIGHLIGHT")
            b.hl:SetTexture("Interface\\Buttons\\WHITE8X8")
            b.hl:SetAllPoints(b.icon)
            b.hl:SetVertexColor(1, 1, 1, 0.15)
            b.ring = b:CreateTexture(nil, "OVERLAY", nil, 5)
            b.ring:SetTexture(UI.MEDIA .. "circle"); b.ring:SetSize(13, 13); b.ring:SetPoint("TOPRIGHT", 4, 4)
            b.ring:SetVertexColor(0, 0, 0, 0.9)
            b.dot = b:CreateTexture(nil, "OVERLAY", nil, 6)
            b.dot:SetTexture(UI.MEDIA .. "circle"); b.dot:SetSize(10, 10); b.dot:SetPoint("CENTER", b.ring, "CENTER")
            b.n = b:CreateFontString(nil, "OVERLAY")
            b.n:SetFont(UI.FONT, 10, "OUTLINE")
            b.n:SetPoint("BOTTOMRIGHT", -2, 2)
            b:SetScript("OnEnter", function(sb)
                local e = sb.e
                if not e then return end
                WK.UI:TooltipOwner(sb, "ANCHOR_RIGHT")
                -- l'infobulle de l'objet dit déjà le verrou et les persos qui l'ont : seulement l'action ici
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(e.id) end
                if e.reason == "manual" then GameTooltip:AddLine(T("Clic droit : déverrouiller"), 0.6, 0.6, 0.6)
                else GameTooltip:AddLine(T("Coupe la règle plus bas pour l'enlever."), 0.6, 0.6, 0.6) end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(sb) if sb.e and sb.e.reason == "manual" then GameTooltip:Hide(); IL:Unlock(sb.e.id) end end)
            return b
        end)
        self.lockHeads = UI:Pool(function()
            local h = CreateFrame("Frame", nil, list)
            h:SetHeight(16)
            h.t = UI:Text(h, 10, C.dim); h.t:SetPoint("LEFT")
            h.n = UI:Text(h, 10, C.muted); h.n:SetPoint("RIGHT")
            return h
        end)
        self.lockLS = LS
        self.lockEmpty = UI:Text(list, 11, C.muted)
        self.lockEmpty:SetPoint("TOPLEFT", 16, -46)
        self.lockEmpty:SetText(string.format(T("Aucun objet verrouillé. %s sur un objet dans tes sacs pour le verrouiller."),
            UI.ItemLockKeyLabel and UI.ItemLockKeyLabel() or T("Alt + clic")))
        -- règles
        local rules = UI:Card(root, T("Règles automatiques"))
        self.lockRules = rules
        local y = -40
        local function rule(label, desc, key)
            UI:SettingRow(rules, y, label, desc, UI:Toggle(rules, function() return cfg.rules[key] end,
                function(v) cfg.rules[key] = v; IL:RuleChanged() end), 80)
            y = y - 46
        end
        rule("Objets épiques et plus", nil, "epic")
        rule("Objets de ma liste d'envies", "Donjons > Mes envies et listes BiS, tous les persos.", "wish")
        rule("Recettes", "Celles d'un métier qu'un de tes persos a appris, et qu'aucun de tes persos n'a encore apprises.", "recipes")
        rule("Objets de quête", "Et les objets que demande une quête de ton journal (jusqu'à ce qu'elle soit rendue).", "quest")
        rule("Valeur HV au-dessus d'un seuil", "Prix relevé par le scan de l'hôtel des ventes.", "value")
        UI:SettingRow(rules, y, "Seuil de valeur HV", nil, UI:Slider(rules, 220, 1, 100, 1,
            function() return math.floor((cfg.valueMin or 50000) / 10000) end,
            function(v) cfg.valueMin = v * 10000; IL:RuleChanged() end, "%d po"), 240)
        y = y - 46
        rules:SetHeight(-y + 8)
        -- réglages
        local sets = UI:Card(root, T("Protection"))
        self.lockSets = sets
        local keyOpts = {}
        for i, o in ipairs(IL.KEY_OPTIONS) do keyOpts[i] = { o[1], T(o[2]) } end
        local keyDd = UI:Dropdown(sets, 200, 30, keyOpts,
            function(v)
                cfg.key = v
                if self.lockEmpty and UI.ItemLockKeyLabel then
                    self.lockEmpty:SetText(string.format(T("Aucun objet verrouillé. %s sur un objet dans tes sacs pour le verrouiller."), UI.ItemLockKeyLabel()))
                end
            end)
        keyDd:Select(cfg.key or "altmid")
        self.lockKeyDd = keyDd
        UI:SettingRow(sets, -40, "Touche pour verrouiller", "Sur un objet dans les sacs du jeu.", keyDd, 200)
        UI:SettingRow(sets, -86, "Racheter un objet verrouillé vendu par erreur", "Aussitôt ; seulement les objets verrouillés à la main.",
            UI:Toggle(sets, function() return cfg.rebuy end, function(v) cfg.rebuy = v end), 80)
        UI:SettingRow(sets, -132, "Confirmer une vente chère", "Objet non verrouillé qui vaut bien plus à l'HV qu'au marchand.",
            UI:Toggle(sets, function() return cfg.confirm end, function(v) cfg.confirm = v end), 80)
        UI:SettingRow(sets, -178, "Écart HV / marchand", "Demander si le prix HV vaut au moins ce multiple du prix marchand.",
            UI:Slider(sets, 220, 2, 20, 1, function() return cfg.ratio or 5 end, function(v) cfg.ratio = v end, "x %d"), 240)
        sets:SetHeight(232)
        -- place dans les sacs, réassort, amélioration à porter (UI/BagHelp.lua)
        self.bagSets = UI:BuildBagHelpCard(root)
        UI:OnResize(pane, function() if self.char == "locks" then self:RefreshLocks() end end)
    end,

    -- Rangement (Modules/Stash.lua) : qui a besoin de quoi, ce qui part au perso HV ou chez le marchand, réglages
    BuildStash = function(self, p, x0)
        local S = WK.modules.Stash
        local cfg = S:Config()
        local pane = UI:Scroll(p)
        pane:SetPoint("TOPLEFT", self.band, "BOTTOMLEFT", x0, 0)
        pane:SetPoint("BOTTOMRIGHT")
        pane:Hide()
        self.stashPane = pane
        local root = pane.child
        -- sous-onglets : Envois (la liste par perso, la place, le perso HV) / Répartition (maquettes A + B)
        self.stashTab = self.stashTab or "send"
        self.stashSeg = UI:Segmented(root, { { "send", T("Envois") }, { "dist", T("Répartition") } }, function(v)
            self.stashTab = v; self:RefreshStash()
        end, 26)
        self.stashSeg:SetPoint("TOPLEFT", 4, -4)
        self.stashSeg:Select(self.stashTab)
        self:BuildDist(root)
        -- titre au-dessus du cadre (la roue dentée de la page reste à droite, sans rien chevaucher)
        local head = UI:Text(root, 13, C.text); head:SetPoint("LEFT", self.stashSeg, "RIGHT", 14, 0)
        head:SetText(T("Rangement par perso"))
        self.stashHead = head
        local headSub = UI:Text(root, 11, C.muted); headSub:SetPoint("LEFT", head, "RIGHT", 8, 0)
        local list = UI:Card(root)
        list.subtitle = headSub
        self.stashList = list
        local note = UI:Text(root, 11, C.muted)
        self.stashNote = note
        note:SetPoint("LEFT", headSub, "RIGHT", 16, 0)
        note:SetJustifyH("RIGHT")
        note:SetText(T("les envois se font à la boîte aux lettres de chaque perso"))
        -- variante A : 3 chiffres en haut (à tes persos, HV, marchand), puis une colonne par destination
        self.stashChips = {}
        for i = 1, 3 do
            local ch = CreateFrame("Frame", nil, list)
            ch:SetHeight(48)
            UI:Panel(ch, 9, C.surface2, C.border)
            ch.n = UI:Text(ch, 22); ch.n:SetPoint("LEFT", 12, 0); ch.n:SetWidth(34); ch.n:SetJustifyH("CENTER")
            ch.t = UI:Text(ch, 12); ch.t:SetPoint("TOPLEFT", 54, -9); ch.t:SetPoint("TOPRIGHT", -10, -9)
            ch.s = UI:Text(ch, 10, C.muted); ch.s:SetPoint("TOPLEFT", 54, -27); ch.s:SetPoint("TOPRIGHT", -10, -27)
            self.stashChips[i] = ch
        end
        self.stashOpen = {}
        self.stashCols = UI:Pool(function()
            local c = CreateFrame("Frame", nil, list)
            UI:Panel(c, 9, C.surface2, C.border)
            c.bar = c:CreateTexture(nil, "ARTWORK"); c.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
            c.bar:SetSize(3, 20); c.bar:SetPoint("TOPLEFT", 10, -9)
            c.name = UI:Text(c, 13); c.name:SetPoint("TOPLEFT", 20, -12)
            c.badge = UI:Badge(c, T("perso HV"), C.gold); c.badge:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
            c.badge2 = UI:Badge(c, T("perso principal"), { UI:Accent() })
            c.badge2:SetPoint("LEFT", c.name, "RIGHT", 8, 0)
            -- métiers du perso sur une 2e ligne, toute la largeur (plus de texte coupé par la pastille « perso HV »)
            c.right = UI:Text(c, 10, C.muted)
            c.right:SetPoint("TOPLEFT", 20, -31); c.right:SetPoint("TOPRIGHT", -12, -31)
            c.right:SetJustifyH("LEFT")
            if c.right.SetWordWrap then c.right:SetWordWrap(false) end
            c.line = c:CreateTexture(nil, "ARTWORK"); c.line:SetTexture("Interface\\Buttons\\WHITE8X8")
            c.line:SetVertexColor(C.border[1], C.border[2], C.border[3], 1); c.line:SetHeight(1)
            c.line:SetPoint("TOPLEFT", 0, -49); c.line:SetPoint("TOPRIGHT", 0, -49)
            c.more = CreateFrame("Button", nil, c); c.more:SetHeight(22)
            c.more.t = UI:Text(c.more, 11); c.more.t:SetPoint("LEFT", 12, 0)
            c.more:SetScript("OnClick", function(b) self.stashOpen[b.key] = not self.stashOpen[b.key]; self:RefreshStash() end)
            return c
        end)
        self.stashRows = UI:Pool(function()
            local r = CreateFrame("Button", nil, list)
            r:SetHeight(34)
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 12, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.qty = UI:Text(r, 11, C.muted); r.qty:SetPoint("RIGHT", -12, 0); r.qty:SetJustifyH("RIGHT")
            r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 40, -4); r.name:SetPoint("TOPRIGHT", -60, -4); r.name:SetJustifyH("LEFT")
            if r.name.SetWordWrap then r.name:SetWordWrap(false) end
            r.why = UI:Text(r, 10, C.dim); r.why:SetPoint("TOPLEFT", 40, -19); r.why:SetPoint("TOPRIGHT", -60, -19); r.why:SetJustifyH("LEFT")
            if r.why.SetWordWrap then r.why:SetWordWrap(false) end
            r.sep = r:CreateTexture(nil, "ARTWORK"); r.sep:SetTexture("Interface\\Buttons\\WHITE8X8")
            r.sep:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.6); r.sep:SetHeight(1)
            r.sep:SetPoint("TOPLEFT", 0, 0); r.sep:SetPoint("TOPRIGHT", 0, 0)
            r:RegisterForClicks("AnyUp")
            r:SetScript("OnClick", function(sb, btn)
                if btn == "RightButton" and sb.e then UI:StashItemMenu(sb.e.id, sb) end
            end)
            r:SetScript("OnEnter", function(sb)
                if not sb.e then return end
                WK.UI:TooltipOwner(sb, "ANCHOR_RIGHT")
                if GameTooltip.SetItemByID then GameTooltip:SetItemByID(sb.e.id) end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(sb.e.why or "", 0.8, 0.8, 0.8, true)
                _G.GameTooltip:AddLine(T("Clic droit : exception pour cet objet"), 0.5, 0.5, 0.5)
                if sb.e.unit then GameTooltip:AddDoubleLine(T("Valeur"), WK:FormatMoney(sb.e.unit * sb.e.count), 0.6, 0.6, 0.6, 1, 1, 1) end
                local chars = WK.DB.global.characters
                for key, n in pairs(sb.e.from or {}) do
                    local c = chars[key]
                    if c then
                        local cr, cg, cb = UI:ClassColor(c.class)
                        GameTooltip:AddDoubleLine(string.format(T("chez %s"), WK:CharName(c, key)), "x" .. n, cr, cg, cb, 1, 1, 1)
                    end
                end
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            return r
        end)
        self.stashEmpty = UI:Text(list, 11, C.muted)
        self.stashEmpty:SetPoint("TOPLEFT", 16, -16)
        self.stashEmpty:SetText(T("Rien à ranger : chaque composant est déjà chez le perso qui s'en sert."))
        -- place libre par perso et ce qui en libèrerait le plus (Stash:Space)
        local space = UI:Card(root, T("Place dans les sacs"), T("du perso le plus plein au plus libre"))
        self.spaceCard = space
        self.spaceRows = UI:Pool(function()
            local r = _G.CreateFrame("Button", nil, space)
            r:SetHeight(46)
            UI:Panel(r, 8, C.surface2, C.border)
            r.name = UI:Text(r, 12); r.name:SetPoint("TOPLEFT", 12, -8)
            r.free = UI:Text(r, 11); r.free:SetPoint("TOPRIGHT", -12, -8); r.free:SetJustifyH("RIGHT")
            r.bar = UI:Progress(r, 5); r.bar:SetPoint("TOPLEFT", 12, -26); r.bar:SetPoint("TOPRIGHT", -12, -26)
            r.gain = UI:Text(r, 10, C.muted); r.gain:SetPoint("TOPLEFT", 12, -34); r.gain:SetPoint("TOPRIGHT", -12, -34)
            r.gain:SetJustifyH("LEFT")
            if r.gain.SetWordWrap then r.gain:SetWordWrap(false) end
            r:SetScript("OnEnter", function(b)
                local e = b.e
                if not e then return end
                UI:TooltipOwner(b, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(WK:CharName(e.c, e.key), 1, 1, 1)
                _G.GameTooltip:AddDoubleLine(T("Sacs"), string.format(T("%d libres sur %d"), e.free, e.total),
                    0.7, 0.7, 0.7, 1, 1, 1)
                if e.bankSlots and e.bankSlots > 0 then
                    local bt = string.format(T("%d libres sur %d"), e.bankFree or 0, e.bankSlots)
                    _G.GameTooltip:AddDoubleLine(T("Banque"), bt,
                        0.7, 0.7, 0.7, 1, 1, 1)
                end
                _G.GameTooltip:AddLine(" ")
                _G.GameTooltip:AddLine(T("Ce qui libèrerait de la place (env.) :"), 0.85, 0.85, 0.85)
                local function line(label, n, extra)
                    if n and n > 0 then
                        _G.GameTooltip:AddDoubleLine(label, string.format(T("%d case(s)"), n) .. (extra or ""),
                            0.7, 0.7, 0.7, 1, 1, 1)
                    end
                end
                line(T("Vendre la camelote"), e.junk,
                    e.junkValue > 0 and ("  · " .. WK:FormatMoney(e.junkValue)) or nil)
                line(T("Envoyer à tes persos et au perso HV"), e.send)
                line(T("Vendre les inutiles au marchand"), e.sell)
                line(T("Réunir les piles"), e.merge)
                if e.merge == nil then
                    local mt = T("Piles à réunir : connecte ce perso pour les voir.")
                    _G.GameTooltip:AddLine(mt, 0.5, 0.5, 0.5, true)
                end
                if (e.gain or 0) == 0 then
                    _G.GameTooltip:AddLine(T("Rien à libérer pour l'instant."), 0.5, 0.5, 0.5)
                end
                _G.GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
            return r
        end)
        -- réglages du perso HV
        local sets = UI:Card(root, T("Vente à l'HV et courrier"),
            T("le perso HV se choisit en haut de l'onglet Répartition"))
        self.stashSets = sets
        UI:SettingRow(sets, -40, "Vendre à l'HV à partir de",
            "Valeur du lot au prix du scan de l'HV ; en dessous, il est proposé au marchand.",
            UI:Slider(sets, 220, 0, 500, 10, function() return math.floor((cfg.minAH or 5000) / 100) end,
                function(v) cfg.minAH = v * 100; S:Invalidate(); WK:NotifyChanged() end, "%d pa"), 240)
        -- (« Prix proposé » et « Durée des enchères » retirés : jamais lus ; la vente à l'HV suit les réglages de la
        -- fenêtre de l'HV, page Vendre)
        UI:SettingRow(sets, -86, "Garder une réserve",
            "Quantité de chaque objet laissée sur le compte au lieu de la vendre.",
            UI:Slider(sets, 220, 0, 100, 5, function() return cfg.reserve or 0 end, function(v) cfg.reserve = v; S:Invalidate(); WK:NotifyChanged() end, "%d"), 240)
        UI:SettingRow(sets, -132, "Proposer les envois à la boîte aux lettres",
            "Un panneau à côté du courrier liste ce que ce perso doit envoyer, coché par défaut.",
            UI:Toggle(sets, function() return cfg.mailPanel end, function(v) cfg.mailPanel = v end), 80)
        sets:SetHeight(40 + 3 * 46 + 8)
        UI:OnResize(pane, function() if self.char == "stash" then self:RefreshStash() end end)
    end,

    -- Répartition (maquette A) : perso principal, tableau familles × persos (clic = menu de la case), exceptions
    -- des persos et des objets
    BuildDist = function(self, root)
        local S = WK.modules.Stash
        local f = _G.CreateFrame("Frame", nil, root)
        f:SetPoint("TOPLEFT", 0, -38)
        f:Hide()
        self.distFrame = f
        -- trois rôles côte à côte : perso principal (consommables), perso banque (surplus), perso HV (vente)
        f.roles = {}
        local ROLES = {
            { "main", "Perso principal", "Nourriture, boisson, bandages et potions de son niveau tant qu'il monte." },
            { "bank", "Perso banque",
                "Garde le surplus de chaque famille et ce qui ne vaut pas la vente à l'HV (au lieu du marchand)." },
            { "ahChar", "Perso HV", "Reçoit ce dont personne n'a besoin et qui vaut la vente, pour le mettre à l'HV." },
        }
        for i, ro in ipairs(ROLES) do
            local box = _G.CreateFrame("Frame", nil, f)
            box:SetHeight(46)
            box.l = UI:Text(box, 11, C.muted); box.l:SetPoint("TOPLEFT", 2, 0); box.l:SetText(T(ro[2]))
            box.dd = UI:Dropdown(box, 180, 26, {}, function(v)
                S:Config()[ro[1]] = (v ~= "none") and v or nil; S:Invalidate(); WK:NotifyChanged(); self:RefreshStash()
            end)
            box.dd:SetPoint("TOPLEFT", 0, -16)
            box.key, box.tip = ro[1], ro[3]
            box:EnableMouse(true)
            box:SetScript("OnEnter", function(b)
                UI:TooltipOwner(b, "ANCHOR_BOTTOM")
                _G.GameTooltip:SetText(T(ro[2]), 1, 1, 1)
                _G.GameTooltip:AddLine(T(b.tip), 0.8, 0.8, 0.8, true)
                _G.GameTooltip:Show()
            end)
            box:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
            f.roles[i] = box
        end
        f.legend = UI:Text(f, 10, C.muted); f.legend:SetPoint("TOPLEFT", 4, -56)
        f.table = UI:Card(f)
        f.heads = UI:Pool(function()
            local h = _G.CreateFrame("Frame", nil, f.table)
            h.n = UI:Text(h, 12)
            h.n:SetPoint("TOPLEFT", 8, -8)
            h.n:SetPoint("TOPRIGHT", -4, -8)
            h.n:SetJustifyH("LEFT")
            if h.n.SetWordWrap then h.n:SetWordWrap(false) end
            h.p = UI:Text(h, 10, C.muted); h.p:SetPoint("TOPLEFT", 8, -24); h.p:SetPoint("TOPRIGHT", -4, -24)
            h.p:SetJustifyH("LEFT")
            if h.p.SetWordWrap then h.p:SetWordWrap(false) end
            return h
        end)
        f.fams = UI:Pool(function()
            local r = _G.CreateFrame("Frame", nil, f.table)
            r.l = r:CreateTexture(nil, "ARTWORK"); r.l:SetTexture("Interface\\Buttons\\WHITE8X8")
            r.l:SetVertexColor(C.border[1], C.border[2], C.border[3], 1); r.l:SetHeight(1)
            r.l:SetPoint("TOPLEFT"); r.l:SetPoint("TOPRIGHT")
            r.n = UI:Text(r, 12); r.n:SetPoint("TOPLEFT", 12, -8)
            r.s = UI:Text(r, 10, C.dim); r.s:SetPoint("TOPLEFT", 12, -24); r.s:SetWidth(200); r.s:SetJustifyH("LEFT")
            if r.s.SetWordWrap then r.s:SetWordWrap(false) end
            return r
        end)
        f.cells = UI:Pool(function()
            local b = _G.CreateFrame("Button", nil, f.table)
            b.bg = UI:Rounded(b, 9, 0, "BACKGROUND", 1)
            b.t = UI:Text(b, 10); b.t:SetPoint("LEFT", 8, 0); b.t:SetPoint("RIGHT", -6, 0); b.t:SetJustifyH("LEFT")
            if b.t.SetWordWrap then b.t:SetWordWrap(false) end
            b:SetScript("OnClick", function(s) self:DistCellMenu(s.fam, s.key, s) end)
            b:SetScript("OnEnter", function(s)
                UI:TooltipOwner(s, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(s.full or "", 1, 1, 1, 1, true)
                _G.GameTooltip:AddLine(T("Clic : changer la règle de cette case"), 0.6, 0.6, 0.6)
                _G.GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() _G.GameTooltip:Hide() end)
            return b
        end)
        -- exceptions des persos et des objets
        f.chars = UI:Card(f, T("Exceptions des persos"), T("prioritaires sur le tableau"))
        f.charRows = UI:Pool(function()
            local r = _G.CreateFrame("Frame", nil, f.chars)
            r:SetHeight(30)
            r.n = UI:Text(r, 12); r.n:SetPoint("LEFT", 4, 0)
            r.keep = UI:Toggle(r, function() return S:CharFlags(r.key).keep end,
                function(v) S:SetCharFlag(r.key, "keep", v); self:RefreshStash() end)
            r.keepT = UI:Text(r, 11, C.muted); r.keepT:SetText(T("Garde ses récoltes"))
            r.none = UI:Toggle(r, function() return S:CharFlags(r.key).none end,
                function(v) S:SetCharFlag(r.key, "none", v); self:RefreshStash() end)
            r.noneT = UI:Text(r, 11, C.muted); r.noneT:SetText(T("Ne reçoit rien"))
            r.none:SetPoint("RIGHT", -4, 0); r.noneT:SetPoint("RIGHT", r.none, "LEFT", -8, 0)
            r.keep:SetPoint("RIGHT", r.noneT, "LEFT", -24, 0); r.keepT:SetPoint("RIGHT", r.keep, "LEFT", -8, 0)
            return r
        end)
        f.items = UI:Card(f, T("Exceptions par objet"),
            T("clic droit sur un envoi, ou « Destination » dans la fiche des sacs"))
        f.itemRows = UI:Pool(function()
            local r = _G.CreateFrame("Button", nil, f.items)
            r:SetHeight(28)
            r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(20, 20); r.icon:SetPoint("LEFT", 4, 0)
            r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            r.n = UI:Text(r, 12); r.n:SetPoint("LEFT", 30, 0)
            r.del = UI:IconButton(r, "close", 18, T("Retirer l'exception"), true); r.del:SetPoint("RIGHT", -4, 0)
            r.del:SetScript("OnClick", function(b) S:SetItemRule(b:GetParent().id, nil); self:RefreshStash() end)
            r.rule = UI:Text(r, 11); r.rule:SetPoint("RIGHT", r.del, "LEFT", -10, 0)
            r:SetScript("OnClick", function(b) UI:StashItemMenu(b.id, b) end)
            return r
        end)
        f.itemsEmpty = UI:Text(f.items, 11, C.muted); f.itemsEmpty:SetPoint("TOPLEFT", 16, -44)
        f.itemsEmpty:SetText(T("Aucune exception pour l'instant."))
    end,

    DistCellMenu = function(self, fam, key, anchor)
        local S = WK.modules.Stash
        local fdef
        for _, d in ipairs(S.FAMILIES) do if d.key == fam then fdef = d end end
        local c = WK.DB.global.characters[key]
        if not (fdef and c) then return end
        local title = T(fdef.label) .. " » " .. WK:CharName(c, key)
        local r = S:FamRule(fam, key) or {}
        local list = {}
        local function set(mode) return function() S:SetFamRule(fam, key, mode, r.cap); self:RefreshStash() end end
        if fdef.cons then
            local t = S:ConsTargets(key) or {}
            local OPTS = { food = { 0, 20, 40, 60, 80 }, drink = { 0, 20, 40, 60, 80 },
                bandage = { 0, 10, 20, 40 }, potion = { 0, 5, 10, 20 } }
            for _, k in ipairs(fdef.cons) do
                local opts = {}
                for _, v in ipairs(OPTS[k]) do opts[#opts + 1] = { v, tostring(v) } end
                list[#list + 1] = { seg = { label = T(S.CONS_LABEL[k]), opts = opts, sel = t[k] or 0,
                    fn = function(v) S:SetCons(key, k, v); self:RefreshStash() end } }
            end
            list[#list + 1] = { sep = true }
            list[#list + 1] = { label = T("Pause"), desc = T("Ne reçoit plus rien de cette famille."),
                on = r.mode == "pause",
                col = C.negative, fn = set(r.mode == "pause" and nil or "pause") }
            local sub = key == S:Config().main and T("perso principal : stocks voulus de son niveau")
                or T("stocks voulus : les autres persos lui envoient ce qui lui manque")
            return UI.StashPopMenu():Open(anchor, title, sub, list)
        end
        local cell = S:Cell(fam, key)
        local auto = cell.mode == "auto" or cell.mode == "guide"
        list[#list + 1] = { label = auto and T("Reçoit (d'office)") or T("Rien (d'office)"),
            desc = auto and T("D'après ses métiers et le palier visé de son guide.")
                or T("Aucun de ses métiers ne s'en sert."),
            on = r.mode == nil, fn = set(nil) }
        if not auto then
            list[#list + 1] = { label = T("Reçoit"), desc = T("Comme s'il avait le métier."), on = r.mode == "recv",
                col = C.positive, fn = set("recv") }
        end
        if fam ~= "gear" then
            list[#list + 1] = { label = T("Prioritaire"), desc = T("Passe avant les autres persos pour cette famille."),
                on = r.mode == "prio", col = C.rule, fn = set("prio") }
            list[#list + 1] = { label = T("Stock de la famille"), desc = T("Reçoit aussi le surplus des autres."),
                on = r.mode == "stock", col = C.gold, fn = set("stock") }
        end
        list[#list + 1] = { label = T("Pause"), desc = T("Ne reçoit plus rien : la famille va au suivant ou au stock."),
            on = r.mode == "pause", col = C.negative, fn = set("pause") }
        if fam ~= "gear" then
            list[#list + 1] = { sep = true }
            local capOpts = { { 0, T("aucun") }, { 1, "1" }, { 2, "2" }, { 5, "5" }, { 10, "10" } }
            list[#list + 1] = { seg = { label = T("Plafond (piles)"), opts = capOpts,
                sel = r.cap or 0, fn = function(v)
                    S:SetFamRule(fam, key, r.mode, v > 0 and v or nil)
                    r = S:FamRule(fam, key) or {}
                    self:RefreshStash()
                end } }
        end
        UI.StashPopMenu():Open(anchor, title, cell.text, list)
    end,

    RefreshDist = function(self, W)
        local S = WK.modules.Stash
        local cfg = S:Config()
        local f = self.distFrame
        f:SetWidth(W)
        local opts = { { "none", T("Aucun") } }
        local list = UI:SortedCharacters()
        -- noms à la couleur de leur classe
        for _, e in ipairs(list) do
            opts[#opts + 1] = { e.key, UI:Hex({ UI:ClassColor(e.c.class) }) .. WK:CharName(e.c, e.key) .. "|r" }
        end
        local bw = math.floor((W - 24) / 3)
        for i, box in ipairs(f.roles) do
            box:ClearAllPoints(); box:SetPoint("TOPLEFT", (i - 1) * (bw + 12), -4); box:SetWidth(bw)
            box.dd:SetOptions(opts); box.dd:Select(cfg[box.key] or "none")
        end
        local function hx(col) return UI:Hex(col) end
        local ar, ag, ab = UI:Accent()
        f.legend:SetText(hx(C.positive) .. T("Reçoit") .. "|r " .. T("d'office, d'après ses métiers") .. "   "
            .. hx(C.rule) .. T("Prioritaire") .. "|r   " .. hx(C.negative) .. T("Pause") .. "|r   "
            .. hx(C.gold) .. T("Stock") .. "|r " .. T("surplus") .. "   "
            .. hx({ ar, ag, ab }) .. T("Perso principal") .. "|r "
            .. T("consommables") .. "   ·   " .. T("clic sur une case = menu"))
        -- tableau
        f.heads:Reset(); f.fams:Reset(); f.cells:Reset()
        local FAMW, HEADH, ROWH = 220, 44, 42
        local n = #list
        local cw = n > 0 and math.max(110, (W - 8 - FAMW) / n) or 120
        for i, e in ipairs(list) do
            local h = f.heads:Get()
            h:ClearAllPoints(); h:SetPoint("TOPLEFT", f.table, "TOPLEFT", FAMW + (i - 1) * cw, 0); h:SetSize(cw, HEADH)
            local nm = WK:CharName(e.c, e.key)
            if e.key == cfg.main then nm = nm .. "  " .. hx({ ar, ag, ab }) .. T("principal") .. "|r" end
            if e.key == cfg.bank then nm = nm .. "  " .. hx(C.info) .. T("banque") .. "|r" end
            if e.key == cfg.ahChar then nm = nm .. "  " .. hx(C.gold) .. T("HV") .. "|r" end
            h.n:SetText(nm); h.n:SetTextColor(UI:ClassColor(e.c.class))
            local parts = {}
            for prof, pp in pairs(e.c.professions or {}) do
                if type(pp) == "table" and pp.rank then parts[#parts + 1] = { T(prof), pp.rank } end
            end
            table.sort(parts, function(x, z) return x[2] > z[2] end)
            local txt = {}
            for k = 1, math.min(3, #parts) do txt[k] = parts[k][1] .. " " .. parts[k][2] end
            local lvTxt = string.format(T("niv. %d"), e.c.level or 1)
            h.p:SetText(lvTxt .. (#txt > 0 and (" · " .. table.concat(txt, ", ")) or ""))
            h:Show()
        end
        local y = HEADH
        for _, fd in ipairs(S.FAMILIES) do
            local r = f.fams:Get()
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", f.table, "TOPLEFT", 0, -y); r:SetSize(W, ROWH)
            r.n:SetText(T(fd.label)); r.s:SetText(fd.sub and T(fd.sub) or "")
            r:Show()
            for i, e in ipairs(list) do
                local cell = S:Cell(fd.key, e.key)
                local b = f.cells:Get()
                b.fam, b.key = fd.key, e.key
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", f.table, "TOPLEFT", FAMW + (i - 1) * cw + 4, -(y + 9))
                b:SetSize(cw - 10, ROWH - 18)
                local col = cell.col == "accent" and { ar, ag, ab } or C[cell.col] or C.dim
                b.t:SetText(cell.text); b.full = cell.text
                if cell.col == "dim" then
                    b.t:SetTextColor(C.dim[1], C.dim[2], C.dim[3]); b.bg:SetColor(0, 0, 0, 0)
                elseif cell.fill then
                    b.t:SetTextColor(C.bg[1], C.bg[2], C.bg[3]); b.bg:SetColor(col[1], col[2], col[3], 1)
                else
                    b.t:SetTextColor(col[1], col[2], col[3]); b.bg:SetColor(col[1], col[2], col[3], 0.16)
                end
                b:Show()
            end
            y = y + ROWH
        end
        f.table:ClearAllPoints(); f.table:SetPoint("TOPLEFT", 0, -76); f.table:SetSize(W, y + 6)
        local ty = 76 + y + 6 + 12
        -- exceptions des persos
        f.charRows:Reset()
        local cy = 44
        for _, e in ipairs(list) do
            local r = f.charRows:Get()
            r.key = e.key
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f.chars, "TOPLEFT", 14, -cy)
            r:SetPoint("RIGHT", f.chars, "RIGHT", -14, 0)
            r.n:SetText(WK:CharName(e.c, e.key)); r.n:SetTextColor(UI:ClassColor(e.c.class))
            r.keep:Refresh(); r.none:Refresh()
            r:Show()
            cy = cy + 32
        end
        local half = (W - 12) / 2
        f.chars:ClearAllPoints(); f.chars:SetPoint("TOPLEFT", 0, -ty); f.chars:SetSize(half, cy + 8)
        -- exceptions par objet
        f.itemRows:Reset()
        local ids = {}
        for id in pairs(cfg.items) do ids[#ids + 1] = id end
        table.sort(ids, function(x, z) return (WK.GetItemInfo(x) or "") < (WK.GetItemInfo(z) or "") end)
        local iy = 44
        local chars = WK.DB.global.characters
        for _, id in ipairs(ids) do
            local rule = cfg.items[id]
            local r = f.itemRows:Get()
            r.id = id; r.del.id = id
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", f.items, "TOPLEFT", 14, -iy)
            r:SetPoint("RIGHT", f.items, "RIGHT", -14, 0)
            local name, icon, qr, qg, qb = UI:ItemInfo(id)
            r.icon:SetTexture(icon); r.n:SetText(name or ("#" .. id)); r.n:SetTextColor(qr or 1, qg or 1, qb or 1)
            local txt, col
            if rule.never then txt, col = T("Ne bouge jamais"), C.negative
            elseif rule.ah then txt, col = T("Toujours à l'HV"), C.gold
            elseif rule.to then
                local c = chars[rule.to]
                txt, col = string.format(T("Toujours » %s"), c and WK:CharName(c, rule.to) or rule.to), C.rule
            end
            r.rule:SetText(txt or ""); r.rule:SetTextColor(unpack(col or C.muted))
            r:Show()
            iy = iy + 30
        end
        f.itemsEmpty:SetShown(#ids == 0)
        if #ids == 0 then iy = iy + 24 end
        f.items:ClearAllPoints(); f.items:SetPoint("TOPLEFT", half + 12, -ty); f.items:SetSize(half, iy + 8)
        local hBottom = ty + math.max(cy, iy) + 8
        f:SetHeight(hBottom)
        self.stashPane:SetContentHeight(38 + hBottom + 20)
    end,

    RefreshStash = function(self)
        local S = WK.modules.Stash
        local cfg = S:Config()
        local chars = WK.DB.global.characters
        local W = math.max(400, (self.stashPane:GetWidth() or 600) - 14)
        self.stashPane.child:SetWidth(W)
        local dist = self.stashTab == "dist"
        self.stashSeg:Select(self.stashTab)
        for _, w in ipairs({ self.stashList, self.spaceCard, self.stashSets, self.stashHead, self.stashNote,
            self.stashList and self.stashList.subtitle }) do
            if w then w:SetShown(not dist) end
        end
        self.distFrame:SetShown(dist)
        if dist then return self:RefreshDist(W) end
        local r = S:Route()
        self.stashCols:Reset(); self.stashRows:Reset()
        local total = 0
        local function profs(c)
            local parts = {}
            for prof, pp in pairs(c.professions or {}) do
                if type(pp) == "table" and pp.rank then table.insert(parts, { T(prof), pp.rank }) end
            end
            table.sort(parts, function(x, z) return x[2] > z[2] end)
            local out = {}
            for i = 1, math.min(2, #parts) do out[i] = parts[i][1] .. " " .. parts[i][2] end
            return table.concat(out, " · ")
        end
        local function fromText(e)
            local n, one = 0, nil
            for key in pairs(e.from or {}) do n = n + 1; one = key end
            if n == 0 then return nil end
            if n > 1 then return string.format(T("de %d persos"), n) end
            local c = chars[one]
            return string.format(T("de %s"), c and WK:CharName(c, one) or one)
        end
        -- colonnes : { key, name, color, right, hv, rows = { { e, sub } } }
        local cols = {}
        local nDest, nAH, nVendor = 0, 0, 0
        for _, ce in ipairs(UI:SortedCharacters()) do
            local d = r.dest[ce.key]
            if d and #d.list > 0 then
                local rows = {}
                for _, e in ipairs(d.list) do
                    local f = fromText(e)
                    local ex = e.exc and EXC_TAG[e.exc]
                    local tcol = ex and (ex[2] == "accent" and { UI:Accent() } or C[ex[2]])
                    local tag = ex and (UI:Hex(tcol) .. T(ex[1]) .. "|r  ") or ""
                    table.insert(rows, { e = e, sub = tag .. (e.why or "") .. (f and (" · " .. f) or "") })
                end
                nDest = nDest + #rows
                table.insert(cols, { key = ce.key, name = WK:CharName(ce.c, ce.key), color = { UI:ClassColor(ce.c.class) },
                    right = profs(ce.c), hv = ce.key == cfg.ahChar, rows = rows })
            end
        end
        local hvc = cfg.ahChar and chars[cfg.ahChar]
        if #r.ah.list > 0 or #r.sell.list > 0 then
            local rows = {}
            for _, e in ipairs(r.ah.list) do
                local f = fromText(e)
                table.insert(rows, { e = e, sub = T("à lui envoyer") .. (f and (" · " .. f) or "") })
            end
            for _, e in ipairs(r.sell.list) do table.insert(rows, { e = e, sub = T("déjà sur lui : à mettre en vente") }) end
            nAH = #rows
            table.insert(cols, { key = "ah", name = string.format(T("HV · %s"), hvc and WK:CharName(hvc, cfg.ahChar) or "?"), color = C.gold,
                right = T("env.") .. " " .. WK:FormatMoney((r.ah.value or 0) + (r.sell.value or 0)), rows = rows })
        end
        if #r.vendor.list > 0 then
            local rows = {}
            for _, e in ipairs(r.vendor.list) do table.insert(rows, { e = e, sub = e.why }) end
            nVendor = #rows
            table.insert(cols, { key = "vendor", name = T("Au marchand"), color = C.text, bar = C.dim,
                right = WK:FormatMoney(r.vendor.value or 0), rows = rows })
        end
        total = nDest + nAH + nVendor
        -- les 3 chiffres
        local ar, ag, ab = UI:Accent()
        local chipData = {
            { nDest, { ar, ag, ab }, T("à envoyer à tes persos"), T("ils s'en servent pour leurs métiers") },
            { nAH, C.gold, T("pour l'HV"), cfg.ahChar and (T("env.") .. " " .. WK:FormatMoney((r.ah.value or 0) + (r.sell.value or 0))) or T("aucun perso HV choisi") },
            { nVendor, C.muted, T("au marchand"), cfg.ahChar and string.format(T("moins de %s à l'HV · %s"), WK:FormatMoney(cfg.minAH or 0), WK:FormatMoney(r.vendor.value or 0))
                or WK:FormatMoney(r.vendor.value or 0) },
        }
        local GAP = 10
        local cw3 = (W - 28 - 2 * GAP) / 3
        for i, ch in ipairs(self.stashChips) do
            local dta = chipData[i]
            ch:ClearAllPoints(); ch:SetPoint("TOPLEFT", 14 + (i - 1) * (cw3 + GAP), -14); ch:SetWidth(cw3)
            ch.n:SetText(tostring(dta[1])); ch.n:SetTextColor(dta[2][1], dta[2][2], dta[2][3])
            ch.t:SetText(dta[3]); ch.s:SetText(dta[4])
            ch:SetShown(total > 0)
        end
        -- colonnes en grille (3 par ligne, 2 en fenêtre étroite) ; au plus MAXR objets, « + N autres » déplie
        local MAXR, RH, HEAD = 6, 34, 50
        local ncol = W >= 900 and 3 or 2
        local cw = (W - 28 - (ncol - 1) * GAP) / ncol
        local y = 14 + 48 + GAP
        local rowH = 0
        for i, col in ipairs(cols) do
            local ci = (i - 1) % ncol
            if ci == 0 and i > 1 then y = y + rowH + GAP; rowH = 0 end
            local c = self.stashCols:Get()
            c:ClearAllPoints(); c:SetPoint("TOPLEFT", 14 + ci * (cw + GAP), -y); c:SetWidth(cw)
            local bc = col.bar or col.color
            c.bar:SetVertexColor(bc[1], bc[2], bc[3], 1)
            c.name:SetText(col.name); c.name:SetTextColor(col.color[1], col.color[2], col.color[3])
            c.badge:SetShown(col.hv and true or false)
            c.badge2:SetShown(col.key == cfg.main and not col.hv)
            c.right:SetText(col.right or "")
            local open = self.stashOpen[col.key]
            local shown = open and #col.rows or math.min(#col.rows, MAXR)
            local ry = HEAD
            for k = 1, shown do
                local rw, it = self.stashRows:Get(), col.rows[k]
                rw.e = it.e
                rw:SetParent(c)
                rw:ClearAllPoints(); rw:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -ry); rw:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -ry)
                local name, icon, qr, qg, qb = UI:ItemInfo(it.e.id)
                rw.icon:SetTexture(icon)
                rw.name:SetText(name or "?"); rw.name:SetTextColor(qr or 1, qg or 1, qb or 1)
                rw.why:SetText(it.sub or "")
                rw.qty:SetText("x" .. it.e.count)
                rw.sep:SetShown(k > 1)
                rw:Show()
                ry = ry + RH
            end
            c.more.key = col.key
            if #col.rows > MAXR then
                c.more:ClearAllPoints(); c.more:SetPoint("TOPLEFT", 0, -ry); c.more:SetPoint("TOPRIGHT", 0, -ry)
                c.more.t:SetText(open and T("Replier") or (#col.rows - MAXR == 1 and T("+ 1 autre") or string.format(T("+ %d autres"), #col.rows - MAXR)))
                c.more.t:SetTextColor(ar, ag, ab)
                c.more:Show()
                ry = ry + 24
            else
                c.more:Hide()
            end
            c.h = ry + 6
            rowH = math.max(rowH, c.h)
        end
        -- chaque colonne à la hauteur de son contenu (la ligne suivante part sous la plus haute)
        local used = self.stashCols.used or 0
        for i = 1, used do
            local c = self.stashCols.items[i]
            c:SetHeight(c.h or 40)
        end
        if #cols > 0 then y = y + rowH + 4 else y = 14 end
        if self.stashList.subtitle then self.stashList.subtitle:SetText(string.format(T("%d objets à ranger"), total)) end
        self.stashEmpty:SetShown(total == 0)
        if total == 0 then y = y + 24 end
        self.stashList:ClearAllPoints(); self.stashList:SetPoint("TOPLEFT", 0, -34); self.stashList:SetSize(W, y + 10)
        local ly = 34 + y + 10 + 12
        -- place libre par perso (2 colonnes, 3 en fenêtre large)
        self.spaceRows:Reset()
        local okS, spaceList = pcall(S.Space, S)
        local space = okS and spaceList or {}
        local sc = self.spaceCard
        if #space > 0 then
            local ncs = W >= 900 and 3 or 2
            local sw = (W - 28 - (ncs - 1) * 10) / ncs
            for i, e in ipairs(space) do
                local rr = self.spaceRows:Get()
                rr.e = e
                local ci, ri = (i - 1) % ncs, math.floor((i - 1) / ncs)
                rr:ClearAllPoints(); rr:SetPoint("TOPLEFT", sc, "TOPLEFT", 14 + ci * (sw + 10), -(44 + ri * 54))
                rr:SetWidth(sw)
                rr.name:SetText(WK:CharName(e.c, e.key)); rr.name:SetTextColor(UI:ClassColor(e.c.class))
                local full = 1 - e.free / math.max(1, e.total)
                local col = e.free == 0 and C.negative or (e.free <= 4 and C.warning) or nil
                rr.free:SetText(string.format(T("%d libres / %d"), e.free, e.total))
                rr.free:SetTextColor(unpack(col or C.text))
                rr.bar.color = col and { col[1], col[2], col[3], 1 } or nil
                rr.bar:SetValue(full)
                local parts = {}
                if (e.gain or 0) > 0 then parts[1] = string.format(T("libérable : env. %d case(s)"), e.gain) end
                if e.bankSlots and e.bankSlots > 0 then
                    parts[#parts + 1] = string.format(T("banque : %d libres"), e.bankFree or 0)
                end
                rr.gain:SetText(table.concat(parts, "  ·  "))
                rr:Show()
            end
            local rows = math.ceil(#space / ncs)
            sc:ClearAllPoints(); sc:SetPoint("TOPLEFT", 0, -ly); sc:SetSize(W, 44 + rows * 54 + 6)
            sc:Show()
            ly = ly + 44 + rows * 54 + 6 + 12
        else
            sc:Hide()
        end
        -- (réglages « Perso HV » : roue dentée de la page)
        self.stashPane:SetContentHeight(ly)
    end,

    RefreshLocks = function(self)
        local IL = WK.modules.ItemLock
        local W = math.max(400, (self.lockPane:GetWidth() or 600) - 14)
        self.lockPane.child:SetWidth(W)
        local list = IL:List()
        local n = 0
        for _, e in ipairs(list) do if e.reason == "manual" then n = n + 1 end end
        if self.lockList.subtitle then self.lockList.subtitle:SetText(string.format(T("%d objets · %d à la main"), #list, n)) end
        self.lockIcons:Reset(); self.lockHeads:Reset()
        -- groupes : à la main, objets de quête, recettes (détail par métier), autres règles
        local groups, order = {}, {}
        local function grp(key, label)
            if not groups[key] then groups[key] = { label = label, items = {}, profs = {} }; table.insert(order, key) end
            return groups[key]
        end
        grp("manual", T("À la main")); grp("quest", T("Objets de quête")); grp("recipe", T("Recettes"))
        for _, e in ipairs(list) do
            local g = e.cat == "other" and grp("r:" .. e.reason, e.reason) or groups[e.cat]
            table.insert(g.items, e)
            if e.cat == "recipe" and e.prof then g.profs[e.prof] = (g.profs[e.prof] or 0) + 1 end
        end
        local LS, IG = self.lockLS, 6
        local per = math.max(4, math.floor((W - 24 + IG) / (LS + IG)))
        local y = 44
        local r1, g1, b1 = UI:Accent()
        for _, key in ipairs(order) do
            local g = groups[key]
            if #g.items > 0 then
                local label = g.label
                if key == "recipe" then
                    local parts = {}
                    for prof, k in pairs(g.profs) do table.insert(parts, { T(prof), k }) end
                    table.sort(parts, function(a, b) return a[2] > b[2] end)
                    for i, pp in ipairs(parts) do parts[i] = pp[1] .. " " .. pp[2] end
                    if #parts > 0 then label = label .. "  ·  " .. table.concat(parts, "  ·  ") end
                end
                local h = self.lockHeads:Get()
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 14, -y); h:SetPoint("TOPRIGHT", -14, -y)
                h.t:SetText(UI:Upper(label)); h.n:SetText(#g.items)
                y = y + 20
                for i, e in ipairs(g.items) do
                    local b = self.lockIcons:Get()
                    b.e = e
                    local c, rr = (i - 1) % per, math.floor((i - 1) / per)
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 14 + c * (LS + IG), -(y + rr * (LS + IG)))
                    local _, icon, qr, qg, qb = UI:ItemInfo(e.id)
                    b.icon:SetTexture(icon)
                    local plain = qr > 0.95 and qg > 0.95 and qb > 0.95
                    b.edge:SetVertexColor(plain and C.border[1] or qr, plain and C.border[2] or qg, plain and C.border[3] or qb, 1)
                    if e.reason == "manual" then b.dot:SetVertexColor(r1, g1, b1, 1) else b.dot:SetVertexColor(C.rule[1], C.rule[2], C.rule[3], 1) end
                    b.n:SetText(e.count > 1 and (e.count > 999 and "999+" or tostring(e.count)) or "")
                end
                y = y + math.ceil(#g.items / per) * (LS + IG) + 6
            end
        end
        if self.lockKeyDd then self.lockKeyDd:Select(IL:Config().key or "altmid") end
        if UI.ItemLockKeyLabel then
            self.lockEmpty:SetText(string.format(T("Aucun objet verrouillé. %s sur un objet dans tes sacs pour le verrouiller."), UI.ItemLockKeyLabel()))
        end
        self.lockEmpty:SetShown(#list == 0)
        if #list == 0 then y = y + 24 end
        self.lockList:ClearAllPoints(); self.lockList:SetPoint("TOPLEFT", 0, 0); self.lockList:SetSize(W, y + 10)
        local ly = y + 10 + 12
        -- (règles automatiques et protection : roue dentée de la page)
        self.lockPane:SetContentHeight(ly)
    end,

    -- Onglets du haut (tout le compte, vues d'aide) et liste PERSO de l'onglet « Tout le compte ».
    RefreshTabs = function(self)
        local chars = WK.DB.global.characters
        local cfg = WK.DB.global.settings.ui
        local special = { spread = true, old = true, locks = true, stash = true }
        if self.char ~= "all" and self.char ~= "warband" and not special[self.char] and not MAIL_OF[self.char]
            and not chars[self.char] then self.char = "all" end
        if cfg.invWho and cfg.invWho ~= "warband" and not chars[cfg.invWho] then cfg.invWho = nil end
        local wb = WK.DB.global.warbank
        if cfg.invWho == "warband" and not wb then cfg.invWho = nil end
        local mailOn = WK:PageOn("mail") and self.mailHost ~= nil
        if MAIL_OF[self.char] and not mailOn then self.char = "all" end
        local tab = (special[self.char] or MAIL_OF[self.char]) and self.char or "all"
        local bar = self.tabBar
        local group = MAIL_OF[tab] and "mail" or "obj"
        -- dernier onglet de chaque groupe (l'interrupteur y revient)
        if group == "mail" then cfg.invLastMail = tab else cfg.invLastObj = (tab == "all") and nil or tab end
        local m, bk = WK.DB.global.mail, WK.DB.global.bank
        local function cnt(t) local c = 0; for _ in pairs(t or {}) do c = c + 1 end return c end
        local letters = self:WaitingLetters()
        -- interrupteur
        local sx = 3
        for _, sb in ipairs(bar.btns) do
            local isMail = sb.group == "mail"
            sb:SetShown(not isMail or mailOn)
            if isMail then sb:SetCount(letters, letters > 0) else sb:SetCount(self:WhoCount("all")) end
            sb.selected = sb.group == group; sb:Paint()
            if not isMail or mailOn then
                sb:ClearAllPoints(); sb:SetPoint("LEFT", bar, "LEFT", sx, 0); sx = sx + sb:GetWidth() + 2
            end
        end
        bar:SetWidth(sx + 1)
        -- onglets du groupe choisi
        local x = 4
        for _, b in ipairs(self.tabBtns) do
            local k = b.key
            local n, warn, tip
            if b.mail then
                local mk = MAIL_OF[k]
                if mk == "send" then n = cnt(m.rules) + cnt(m.cats); tip = string.format(T("%d règle(s) d'envoi"), n)
                elseif mk == "bank" then
                    n = cnt(bk.items) + cnt(bk.cats); tip = string.format(T("%d règle(s) de dépôt"), n)
                else
                    n = letters; warn = n > 0
                    tip = string.format(T("%d lettre(s) en attente"), n)
                end
            elseif k == "all" then
                n = self:WhoCount("all")
                tip = string.format(T("%d objets"), n)
            elseif k == "spread" then
                n = #WK.modules.Inventory:Spread(); warn = n > 0
                tip = string.format(T("%d objets dispersés"), n)
            elseif k == "stash" then
                local r = WK.modules.Stash:Route()
                n = #r.ah.list + #r.vendor.list
                for _, d in pairs(r.dest) do n = n + #d.list end
                warn = n > 0
                tip = string.format(T("%d objets à ranger"), n)
            elseif k == "locks" then
                local mm = 0
                for _ in pairs(WK.modules.ItemLock:Manual()) do mm = mm + 1 end
                n = #WK.modules.ItemLock:List()
                tip = string.format(T("%d à la main"), mm)
            elseif k == "old" then
                n = #WK.modules.Inventory:Forgotten(self.oldDays); warn = n > 0
                tip = string.format(T("%d depuis %d j"), n, self.oldDays)
            end
            b.tip = tip
            b:SetCount(n, warn)
            b.selected = (tab == k)
            b:Paint()
            local show = (b.mail and "mail" or "obj") == group
            b:SetShown(show)
            if show then
                b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", self.underBar, "BOTTOMLEFT", x, 0)
                x = x + b:GetWidth() + 22
            end
        end
        -- liste PERSO : seulement dans « Tout le compte »
        self.whoBtn:SetShown(tab == "all")
        self.curTab = tab
        if tab ~= "all" then self.whoMenu:Hide() end
        self.search:ClearAllPoints()
        if tab == "all" then
            self.search:SetPoint("TOPLEFT", self.whoBtn, "TOPRIGHT", 10, 0)
        else
            self.search:SetPoint("TOPLEFT", self.band, "BOTTOMLEFT", 0, 0)
        end
        self:PaintWho()
    end,

    -- Lettres en attente sur tous les persos (boîte aux lettres relevée)
    WaitingLetters = function()
        local n = 0
        for _, c in pairs(WK.DB.global.characters) do
            local box = c.mailbox
            if box and (box.count or 0) > 0 then n = n + box.count end
        end
        return n
    end,

    -- Onglet de courrier affiché (« send », « bank », « receive ») ou nil
    MailTab = function(self) return MAIL_OF[self.char or ""] end,

    -- Ouvre un onglet du courrier (raccourcis du Résumé, pastilles de l'en-tête)
    OpenMail = function(self, k)
        self.char = "m:" .. (k or "send")
        WK.DB.global.settings.ui.invChar = self.char
        self:Refresh()
    end,

    -- Nombre d'objets d'un perso, de la banque de bataillon (« warband ») ou du compte (« all »)
    WhoCount = function(_, key)
        local chars = WK.DB.global.characters
        local wb = WK.DB.global.warbank
        local function one(c)
            local n = 0
            for _, where in ipairs(WHERE) do n = n + countItems(listOf(c, where)) end
            return n
        end
        if key == "warband" then return wb and countItems(wb.items) or 0 end
        if key ~= "all" then return chars[key] and one(chars[key]) or 0 end
        local n = wb and countItems(wb.items) or 0
        for _, c in pairs(chars) do n = n + one(c) end
        return n
    end,

    PaintWho = function(self)
        local who = self.whoBtn
        local chars = WK.DB.global.characters
        local sel = self.char
        local on = sel ~= "all" and (sel == "warband" or chars[sel] ~= nil)
        if on and sel == "warband" then
            who.label:SetText(T("Banque de bataillon")); who.label:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
        elseif on then
            who.label:SetText(WK:CharName(chars[sel], sel)); who.label:SetTextColor(UI:ClassColor(chars[sel].class))
        else
            who.label:SetText(T("Tout le compte")); who.label:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        end
        -- un perso choisi : la liste s'allume
        if on then who.border:SetColor(UI:Accent()) else who.border:SetColor(unpack(C.border)) end
    end,

    -- Liste ouverte : Tout le compte, PERSOS (couleur de classe), puis la banque de bataillon
    FillWhoMenu = function(self)
        local menu = self.whoMenu
        menu.rows:Reset()
        local y = 6
        local function row(key, text, col, n)
            local r = menu.rows:Get()
            r.key = key
            r:ClearAllPoints(); r:SetPoint("TOPLEFT", 6, -y); r:SetPoint("TOPRIGHT", -6, -y)
            r.name:SetText(text); r.name:SetTextColor(col[1], col[2], col[3])
            r.n:SetText(tostring(n))
            r.selected = (self.char == key); r:Paint()
            y = y + 28
        end
        row("all", T("Tout le compte"), C.muted, self:WhoCount("all"))
        menu.head:ClearAllPoints(); menu.head:SetPoint("TOPLEFT", 16, -(y + 6))
        y = y + 20
        for _, e in ipairs(UI:SortedCharacters()) do
            row(e.key, WK:CharName(e.c, e.key), { UI:ClassColor(e.c.class) }, self:WhoCount(e.key))
        end
        local wb = WK.DB.global.warbank
        menu.sep:SetShown(wb ~= nil)
        if wb then
            menu.sep:ClearAllPoints()
            menu.sep:SetPoint("TOPLEFT", 12, -(y + 4)); menu.sep:SetPoint("TOPRIGHT", -12, -(y + 4))
            y = y + 9
            row("warband", T("Banque de bataillon"), C.gold, self:WhoCount("warband"))
        end
        menu:SetHeight(y + 6)
    end,

    Refresh = function(self)
        if self.gp and self.gp:IsOpen() then self.gp:Refresh() end
        self:RefreshTabs()
        self.bags:Reset(); self.slots:Reset(); self.lastList = nil
        local chars = WK.DB.global.characters
        local sel = self.char
        -- onglets du COURRIER : la page Courrier à la place du contenu d'Inventaire
        local mk = MAIL_OF[sel]
        self.mailHost:SetShown(mk ~= nil)
        self.gp.gear:SetShown(mk == nil)
        if mk then
            if self.gp:IsOpen() then self.gp:Open(false) end
            for _, w in ipairs({ self.search, self.scroll, self.header, self.info, self.countText, self.whereSeg,
                self.oldSeg,
                self.whoBtn, self.lockPane, self.stashPane, self.empty }) do w:Hide() end
            local md = UI.pages.mail
            if md and md.frame == self.mailHost then
                if md.tab ~= mk and md.SetTab then md:SetTab(mk) elseif md.Refresh then md:Refresh() end
            end
            return
        end
        self.oldSeg:SetShown(sel == "old")
        -- objets verrouillés : leur propre panneau à la place de la liste
        local locks, stash = sel == "locks", sel == "stash"
        self.lockPane:SetShown(locks)
        self.stashPane:SetShown(stash)
        local pane = locks or stash
        for _, w in ipairs({ self.search, self.scroll, self.header, self.info, self.countText }) do w:SetShown(not pane) end
        if pane then
            self.whereSeg:Hide(); self.empty:Hide()
            if stash then return self:RefreshStash() end
            return self:RefreshLocks()
        end
        if sel == "spread" or sel == "old" then
            self.whereSeg:Hide()
            return self:RefreshHelp(sel)
        end
        for _, r in ipairs(self.rows.items) do r.action:Hide() end
        local items = {}
        local function add(id, n, label)
            local it = items[id]
            if not it then it = { id = id, total = 0, per = {} }; items[id] = it end
            it.total = it.total + n
            it.per[label] = (it.per[label] or 0) + n
        end

        -- Filtres d'emplacement : pas de sacs ni de courrier pour la banque de bataillon.
        self.whereSeg:SetShown(sel ~= "warband")
        local wb = WK.DB.global.warbank
        if sel == "warband" then
            for id, n in pairs(wb and wb.items or {}) do add(id, n, T("Bataillon")) end
        elseif sel == "all" then
            for key, c in pairs(chars) do
                for _, where in ipairs(WHERE) do
                    if self.where == "all" or self.where == where then
                        for id, n in pairs(listOf(c, where) or {}) do add(id, n, WK:CharName(c, key)) end
                    end
                end
            end
            if wb and (self.where == "all" or self.where == "bank") then
                for id, n in pairs(wb.items) do add(id, n, T("Bataillon")) end
            end
        else
            -- Un personnage : le détail indique où se trouve l'objet.
            local c = chars[sel]
            for _, where in ipairs(WHERE) do
                if self.where == "all" or self.where == where then
                    for id, n in pairs(listOf(c, where) or {}) do add(id, n, T(WHERE_LABEL[where])) end
                end
            end
        end

        -- En-tête de l'onglet
        if sel == "all" then
            self.header:SetText(T("Tout le compte"))
            self.header:SetTextColor(unpack(C.text))
            self.info:SetText("")
        elseif sel == "warband" then
            self.header:SetText(T("Banque de bataillon"))
            self.header:SetTextColor(unpack(C.text))
            self.info:SetText(wb and wb.scanned and UI:Ago(wb.scanned) or "")
        else
            local c = chars[sel]
            self.header:SetText(WK:CharName(c, sel))
            self.header:SetTextColor(UI:ClassColor(c.class))
            local parts = {}
            if c.totalSlots and c.totalSlots > 0 then
                table.insert(parts, string.format(T("sacs %d / %d"), c.totalSlots - (c.freeSlots or 0), c.totalSlots))
            end
            table.insert(parts, c.bankScanned and (T("banque") .. " " .. UI:Ago(c.bankScanned)) or T("banque jamais ouverte"))
            local box = c.mailbox
            if box and (box.count or 0) > 0 then
                table.insert(parts, string.format(box.count > 1 and T("%d lettres") or T("%d lettre"), box.count))
            end
            self.info:SetText(table.concat(parts, "  ·  "))
        end

        local list = {}
        for id, it in pairs(items) do
            local name, icon, r, g, b = UI:ItemInfo(id)
            if self.query == "" or string.find(string.lower(name), self.query, 1, true) then
                it.name, it.icon, it.color = name, icon, { r, g, b }
                table.insert(list, it)
            end
        end
        table.sort(list, function(a, b)
            if a.total ~= b.total then return a.total > b.total end
            return a.name < b.name
        end)

        self.rows:Reset()
        local listValue = 0
        for _, it in ipairs(list) do listValue = listValue + WK.modules.Value:Price(it.id) * it.total end
        self.lastList = list
        self:LayoutBags()
        self.empty:SetShown(#list == 0)
        self.empty:SetText(self.query ~= "" and T("Aucun objet ne correspond à la recherche.") or T("Rien ici pour l'instant."))

        self.countText:SetText(string.format(#list > 1 and T("%d objets") or T("%d objet"), #list)
            .. (listValue > 0 and ("  ·  " .. T("env.") .. " " .. UI:GoldText(listValue)) or ""))
    end,

    -- Sacs par catégorie, posés en colonnes (le sac va dans la colonne la moins haute)
    LayoutBags = function(self)
        local list = self.lastList
        if not list then return end
        self.bags:Reset(); self.slots:Reset()
        local groups = {}
        for _, it in ipairs(list) do
            local k = catOf(it.id)
            groups[k] = groups[k] or {}
            table.insert(groups[k], it)
        end
        local W = math.max(400, self.scroll:GetWidth() or 800)
        self.scroll.child:SetWidth(W)
        local ncol = W >= 1150 and 4 or (W >= 860 and 3 or 2)
        local bw = math.floor((W - (ncol - 1) * GAP) / ncol)
        local per = math.max(4, math.floor((bw - 24 + SGAP) / (SLOT + SGAP)))
        local heights = {}
        for i = 1, ncol do heights[i] = 0 end
        local V = WK.modules.Value
        for _, cat in ipairs(CATS) do
            local g = groups[cat[1]]
            if g then
                local rows = math.ceil(#g / per)
                local h = 36 + rows * SLOT + (rows - 1) * SGAP + 12
                local col = 1
                for i = 2, ncol do if heights[i] < heights[col] then col = i end end
                local x, y = (col - 1) * (bw + GAP), heights[col]
                heights[col] = y + h + GAP
                local bag = self.bags:Get()
                bag:ClearAllPoints(); bag:SetPoint("TOPLEFT", x, -y); bag:SetSize(bw, h)
                bag.title:SetText(T(cat[2]))
                local val = 0
                for _, it in ipairs(g) do val = val + V:Price(it.id) * it.total end
                bag.sub:SetText(#g .. (val > 0 and ("  ·  " .. T("env.") .. " " .. UI:GoldText(val)) or ""))
                for i, it in ipairs(g) do
                    local sl = self.slots:Get()
                    local r, c = math.floor((i - 1) / per), (i - 1) % per
                    sl:ClearAllPoints()
                    sl:SetPoint("TOPLEFT", x + 12 + c * (SLOT + SGAP), -(y + 36 + r * (SLOT + SGAP)))
                    sl.it = it
                    sl.icon:SetTexture(it.icon)
                    local q = it.color or { 0.4, 0.4, 0.4 }
                    local plain = q[1] > 0.95 and q[2] > 0.95 and q[3] > 0.95
                    sl.edge:SetVertexColor(plain and C.border[1] or q[1], plain and C.border[2] or q[2], plain and C.border[3] or q[3], 1)
                    local mark = WK:FeatureOn("characters") and WK.modules.BiS and WK.modules.BiS:Mark(it.id)
                    sl.bisRing:SetShown(mark and true or false); sl.bisBadge:SetShown(mark and true or false); sl.bisStar:SetShown(mark and true or false)
                    if mark == "mine" then sl.bisBadge:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 1) elseif mark then sl.bisBadge:SetVertexColor(C.silver[1], C.silver[2], C.silver[3], 1) end
                    sl.n:SetText(it.total > 1 and (it.total > 9999 and "9999+" or tostring(it.total)) or "")
                end
            end
        end
        local maxH = 0
        for i = 1, ncol do maxH = math.max(maxH, heights[i]) end
        self.scroll:SetContentHeight(maxH)
    end,
})
