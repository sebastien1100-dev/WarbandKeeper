local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local GAP = 12

UI:RegisterPage({
    key = "mail", order = 6, nav = "Courrier",
    title = "Courrier automatique",
    subtitle = "Assigne tes matériaux de farm à un personnage : ils partent tout seuls à la boîte aux lettres.",
    count = function()
        local n = 0
        for _ in pairs(WK.DB.global.mail.rules) do n = n + 1 end
        return n > 0 and tostring(n) or ""
    end,

    Build = function(self, p)
        -- Activation -----------------------------------------------------------
        local top = UI:Card(p)
        top:SetSize(UI.PAGE_W, 66)
        top:SetPoint("TOPLEFT")
        self.toggle = UI:Toggle(top,
            function() return WK.DB.global.mail.enabled end,
            function(v) WK.modules.Mail:SetEnabled(v) end)
        UI:SettingRow(top, -12, "Envoi automatique",
            "À l'ouverture de la boîte aux lettres, les objets assignés quittent les sacs vers leur destinataire (12 par courrier).",
            self.toggle, 80)

        -- Nouvelle règle -------------------------------------------------------
        local add = UI:Card(p, "Nouvelle règle")
        add:SetSize(UI.PAGE_W, 128)
        add:SetPoint("TOPLEFT", 0, -66 - GAP)

        local item = UI:Input(add, 290, 34, "Maj + clic sur un objet, ou son ID", "bag")
        item:SetPoint("TOPLEFT", 16, -42)
        item.edit.acceptLinks = true
        local arrow = UI:Icon(add, "arrow", 16, C.muted)
        arrow:SetPoint("LEFT", item, "RIGHT", 12, 0)
        local to = UI:Input(add, 180, 34, "Destinataire", "users")
        to:SetPoint("LEFT", arrow, "RIGHT", 12, 0)
        local btn = UI:Button(add, "Ajouter", nil, 34, "primary", "plus")
        btn:SetPoint("TOPRIGHT", -16, -42)
        self.itemInput, self.toInput = item, to

        local function doAdd()
            local name = (to:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if WK.modules.Mail:AddRule(item:GetText(), name) then
                item:SetText("")
                self:Refresh()
            else
                WK:Print("Indique un objet (Maj + clic) et un destinataire.")
            end
        end
        btn:SetScript("OnClick", doAdd)
        to.onEnter = doAdd

        local hint = UI:Text(add, 11, C.dim)
        hint:SetPoint("TOPLEFT", 16, -92)
        hint:SetText("Mes persos :")
        self.hint = hint
        self.picks = UI:Pool(function()
            local b = UI:Button(add, "", nil, 24, "secondary")
            b:SetScript("OnClick", function(s) to:SetText(s.charName) end)
            return b
        end)

        -- Liste des règles -----------------------------------------------------
        local listTop = -66 - GAP - 128 - GAP
        local list = UI:Card(p, "Règles")
        list:SetSize(UI.PAGE_W, UI.PAGE_H + listTop)
        list:SetPoint("TOPLEFT", 0, listTop)
        self.empty = UI:Text(list, 12, C.muted)
        self.empty:SetPoint("CENTER")
        self.empty:SetText("Aucune règle pour l'instant.")

        local scroll = UI:Scroll(list)
        scroll:SetPoint("TOPLEFT", 10, -40)
        scroll:SetPoint("BOTTOMRIGHT", -8, 10)
        self.scroll = scroll

        self.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, scroll.child)
            r:SetHeight(40)
            r.bg = UI:Rounded(r, 10, 0, "BACKGROUND", 1)
            r.bg:SetColor(unpack(C.surface2))
            r.icon = UI:RoundIcon(r, 24)
            r.icon:SetPoint("LEFT", 10, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("LEFT", 44, 0)
            r.name:SetWidth(240)
            r.arrow = UI:Icon(r, "arrow", 14, C.muted)
            r.arrow:SetPoint("LEFT", 296, 0)
            r.to = UI:Text(r, 12)
            r.to:SetPoint("LEFT", r.arrow, "RIGHT", 12, 0)
            r.bags = UI:Text(r, 11, C.muted)
            r.bags:SetPoint("RIGHT", -44, 0)
            r.bags:SetJustifyH("RIGHT")
            r.del = UI:IconButton(r, "trash", 26, "Supprimer la règle", true)
            r.del:SetPoint("RIGHT", -8, 0)
            r.del:SetScript("OnClick", function(b) WK.modules.Mail:RemoveRule(b.itemID); self:Refresh() end)
            return r
        end)
    end,

    Refresh = function(self)
        self.toggle:Refresh()

        -- Raccourcis : personnages du royaume courant
        self.picks:Reset()
        local realm = GetRealmName()
        local x = self.hint:GetStringWidth() + 26
        local maxX = UI.PAGE_W - 16
        for _, e in ipairs(UI:SortedCharacters()) do
            if e.c.realm == realm and e.c.name then
                local b = self.picks:Get()
                b.charName = e.c.name
                b:SetLabel(e.c.name)
                b:SetWidth(b.label:GetStringWidth() + 24)
                b.label:SetTextColor(UI:ClassColor(e.c.class))
                if x + b:GetWidth() > maxX then b:Hide() else
                    b:ClearAllPoints()
                    b:SetPoint("LEFT", self.hint:GetParent(), "TOPLEFT", x, -97)
                    x = x + b:GetWidth() + 6
                end
            end
        end

        -- Règles
        local classOf = {}
        for _, c in pairs(WK.DB.global.characters) do
            if c.name then classOf[string.lower(c.name)] = c.class end
        end
        local me = WK.DB:Me()
        local ids = {}
        for id in pairs(WK.DB.global.mail.rules) do table.insert(ids, id) end
        table.sort(ids, function(a, b) return UI:ItemInfo(a) < UI:ItemInfo(b) end)

        self.rows:Reset()
        local y = 0
        for _, id in ipairs(ids) do
            local r = self.rows:Get()
            local name, icon, qr, qg, qb = UI:ItemInfo(id)
            local dest = WK.DB.global.mail.rules[id]
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r.icon:SetTexture(icon)
            r.name:SetText(name)
            r.name:SetTextColor(qr, qg, qb)
            r.to:SetText(dest)
            r.to:SetTextColor(UI:ClassColor(classOf[string.lower(dest)]))
            local n = (me.bags or {})[id] or 0
            if string.lower(dest) == string.lower(UnitName("player")) then
                r.bags:SetText("c'est ce personnage")
            else
                r.bags:SetText(n > 0 and string.format("x%d dans les sacs", n) or "")
            end
            r.del.itemID = id
            y = y + 46
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(#ids == 0)
    end,
})
