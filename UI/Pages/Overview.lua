local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local function infoLine(parent, y, label)
    local l = UI:Text(parent, 12, C.muted)
    l:SetPoint("TOPLEFT", 16, y)
    l:SetText(label)
    local v = UI:Text(parent, 12, C.text)
    v:SetPoint("TOPRIGHT", -16, y)
    v:SetJustifyH("RIGHT")
    return v
end

UI:RegisterPage({
    key = "overview", order = 1, section = "compte", icon = "home",
    title = "Vue d'ensemble",
    subtitle = "Un coup d'œil sur tout ton compte : or, personnages et envoi automatique.",

    Build = function(self, p)
        local gap = 12
        local cw = (UI.PAGE_W - 3 * gap) / 4

        -- Cartes de statistiques -------------------------------------------
        self.stats = {}
        local defs = {
            { "coin", "Or du compte" }, { "users", "Personnages" },
            { "clock", "Temps de jeu" }, { "chart", "Sur 7 jours" },
        }
        for i, d in ipairs(defs) do
            local c = UI:Card(p)
            c:SetSize(cw, 88)
            c:SetPoint("TOPLEFT", (i - 1) * (cw + gap), 0)
            local ib = CreateFrame("Frame", nil, c)
            ib:SetSize(30, 30)
            ib:SetPoint("TOPLEFT", 14, -14)
            local ibg = UI:Rounded(ib, 10, 0, "BACKGROUND", 3)
            local ic = UI:Icon(ib, d[1], 16)
            ic:SetPoint("CENTER")
            UI:OnAccent(function()
                local r, g, b = UI:Accent()
                ibg:SetColor(r, g, b, 0.15)
                ic:SetVertexColor(r, g, b, 1)
            end)
            local l = UI:Text(c, 11, C.muted)
            l:SetPoint("LEFT", ib, "RIGHT", 10, 0)
            l:SetText(d[2])
            local v = UI:Text(c, 17)
            v:SetPoint("BOTTOMLEFT", 16, 14)
            v:SetPoint("RIGHT", -12, 0)
            self.stats[i] = v
        end

        local top = -88 - gap
        local h = UI.PAGE_H + top
        local leftW = math.floor(UI.PAGE_W * 0.58)
        local rightW = UI.PAGE_W - leftW - gap

        -- Répartition de l'or ------------------------------------------------
        local dist = UI:Card(p, "Répartition de l'or")
        dist:SetSize(leftW, h)
        dist:SetPoint("TOPLEFT", 0, top)
        local more = UI:Button(dist, "Tout voir", nil, 24, "ghost")
        more:SetPoint("TOPRIGHT", -10, -8)
        more:SetScript("OnClick", function() UI:ShowPage("characters") end)
        self.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, dist)
            r:SetSize(leftW - 32, 40)
            r.icon = UI:RoundIcon(r, 22)
            r.icon:SetPoint("TOPLEFT", 0, -2)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", r.icon, "RIGHT", 10, 0)
            r.value = UI:Text(r, 12)
            r.value:SetPoint("TOPRIGHT", 0, -7)
            r.value:SetJustifyH("RIGHT")
            r.bar = UI:Progress(r, 4)
            r.bar:SetPoint("BOTTOMLEFT", 32, 4)
            r.bar:SetPoint("BOTTOMRIGHT", 0, 4)
            return r
        end)
        self.dist = dist

        -- Envoi automatique --------------------------------------------------
        local mail = UI:Card(p, "Envoi automatique")
        mail:SetSize(rightW, 186)
        mail:SetPoint("TOPRIGHT", 0, top)
        local tog = UI:Toggle(mail,
            function() return WK.DB.global.mail.enabled end,
            function(v) WK.modules.Mail:SetEnabled(v) end)
        tog:SetPoint("TOPRIGHT", -14, -11)
        self.mailToggle = tog
        self.mailRules = infoLine(mail, -50, "Règles actives")
        self.mailPending = infoLine(mail, -76, "Objets à envoyer (ce perso)")
        self.mailState = infoLine(mail, -102, "État")
        local manage = UI:Button(mail, "Gérer les règles", rightW - 32, 32, "secondary", "mail")
        manage:SetPoint("BOTTOM", 0, 14)
        manage:SetScript("OnClick", function() UI:ShowPage("mail") end)

        -- Ce personnage -------------------------------------------------------
        local me = UI:Card(p, "Ce personnage")
        me:SetSize(rightW, h - 186 - gap)
        me:SetPoint("TOPRIGHT", 0, top - 186 - gap)
        self.meName = UI:Text(me, 11, C.muted)
        self.meName:SetPoint("LEFT", me.title, "RIGHT", 8, 0)
        self.meLevel = infoLine(me, -50, "Niveau")
        self.mePlayed = infoLine(me, -76, "Temps de jeu")
        self.meSlots = infoLine(me, -102, "Emplacements libres")
        self.meBank = infoLine(me, -128, "Banque scannée")
        self.meSlotsBar = UI:Progress(me, 6)
        self.meSlotsBar:SetPoint("BOTTOMLEFT", 16, 18)
        self.meSlotsBar:SetPoint("BOTTOMRIGHT", -16, 18)
    end,

    Refresh = function(self)
        local chars = UI:SortedCharacters()
        local gold, played = 0, 0
        for _, e in ipairs(chars) do
            gold = gold + (e.c.money or 0)
            played = played + (e.c.played or 0)
        end
        local S = WK.modules.Statistics
        local now = time()
        local diff = S:AccountGoldAt(now) - S:AccountGoldAt(now - 7 * 86400)

        self.stats[1]:SetText(UI:GoldText(gold))
        self.stats[2]:SetText(tostring(#chars))
        self.stats[3]:SetText(WK:FormatTime(played))
        local col = diff >= 0 and C.positive or C.negative
        self.stats[4]:SetText(UI:ShortGold(diff))
        self.stats[4]:SetTextColor(unpack(col))

        -- Répartition
        self.rows:Reset()
        local maxRows = math.floor((self.dist:GetHeight() - 46) / 44)
        for i, e in ipairs(chars) do
            if i > maxRows then break end
            local r = self.rows:Get()
            r:SetPoint("TOPLEFT", 16, -42 - (i - 1) * 44)
            UI:SetClassIcon(r.icon, e.c.class)
            r.name:SetText(e.c.name or e.key)
            r.name:SetTextColor(UI:ClassColor(e.c.class))
            r.value:SetText(UI:GoldText(e.c.money))
            r.bar:SetValue(gold > 0 and (e.c.money or 0) / gold or 0)
        end

        -- Courrier
        local n = 0
        for _ in pairs(WK.DB.global.mail.rules) do n = n + 1 end
        self.mailToggle:Refresh()
        self.mailRules:SetText(tostring(n))
        self.mailPending:SetText(tostring(WK.modules.Mail:PendingCount()))
        local on = WK.DB.global.mail.enabled
        self.mailState:SetText(on and "Actif" or "Désactivé")
        self.mailState:SetTextColor(unpack(on and C.positive or C.muted))

        -- Personnage courant
        local c = WK.DB:Me()
        self.meName:SetText(WK:CharKey())
        self.meLevel:SetText(tostring(c.level or "-"))
        self.mePlayed:SetText(WK:FormatTime(c.played))
        local free, total = c.freeSlots or 0, c.totalSlots or 0
        self.meSlots:SetText(string.format("%d / %d", free, total))
        self.meBank:SetText(c.bankScanned and UI:Ago(c.bankScanned) or "jamais")
        self.meSlotsBar:SetValue(total > 0 and (total - free) / total or 0)
    end,
})
