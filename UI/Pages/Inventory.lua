local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local MAX_ROWS = 150

UI:RegisterPage({
    key = "inventory", order = 3, section = "compte", icon = "bag",
    title = "Inventaire",
    subtitle = "Sacs et banques de tous tes personnages. Maj + clic sur une ligne pour lier l'objet.",

    Build = function(self, p)
        self.where = "all"
        self.query = ""

        local search = UI:Input(p, 300, 34, "Rechercher un objet...", "search")
        search:SetPoint("TOPLEFT")
        search.onChange = function(text) self.query = string.lower(text or ""); self:Refresh() end

        local seg = UI:Segmented(p, { { "all", "Tout" }, { "bags", "Sacs" }, { "bank", "Banque" } },
            function(key) self.where = key; self:Refresh() end, 34)
        seg:SetPoint("TOPRIGHT")
        seg:Select("all")

        self.info = UI:Text(p, 11, C.muted)
        self.info:SetPoint("TOPLEFT", 4, -48)

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", 0, -68)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll

        self.rows = UI:Pool(function()
            local r = CreateFrame("Button", nil, scroll.child)
            r:SetHeight(46)
            UI:Panel(r, 12, C.surface, C.border)
            r.icon = UI:RoundIcon(r, 28)
            r.icon:SetPoint("LEFT", 12, 0)
            r.name = UI:Text(r, 12)
            r.name:SetPoint("TOPLEFT", 52, -9)
            r.name:SetPoint("RIGHT", -90, 0)
            r.detail = UI:Text(r, 10, C.muted)
            r.detail:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -4)
            r.detail:SetPoint("RIGHT", -90, 0)
            r.total = UI:Text(r, 15)
            r.total:SetPoint("RIGHT", -16, 0)
            r.total:SetJustifyH("RIGHT")
            r:SetScript("OnEnter", function(self)
                self.bg:SetColor(unpack(C.surface2))
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function(self)
                self.bg:SetColor(unpack(C.surface))
                GameTooltip:Hide()
            end)
            r:SetScript("OnClick", function(self)
                local _, _, _, _, _, link = UI:ItemInfo(self.itemID)
                if IsModifiedClick("CHATLINK") and link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
            end)
            return r
        end)
    end,

    Refresh = function(self)
        -- Agrégation sur le compte : [itemID] = { total, per = { [nom] = n } }
        local items = {}
        for key, c in pairs(WK.DB.global.characters) do
            local name = c.name or key
            for _, where in ipairs({ "bags", "bank" }) do
                if self.where == "all" or self.where == where then
                    for id, n in pairs(c[where] or {}) do
                        local it = items[id]
                        if not it then it = { id = id, total = 0, per = {} }; items[id] = it end
                        it.total = it.total + n
                        it.per[name] = (it.per[name] or 0) + n
                    end
                end
            end
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
        local y = 0
        for i, it in ipairs(list) do
            if i > MAX_ROWS then break end
            local r = self.rows:Get()
            r.itemID = it.id
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            r.icon:SetTexture(it.icon)
            r.name:SetText(it.name)
            r.name:SetTextColor(unpack(it.color))
            local parts = {}
            for who, n in pairs(it.per) do table.insert(parts, { who, n }) end
            table.sort(parts, function(a, b) return a[2] > b[2] end)
            for k, v in ipairs(parts) do parts[k] = v[1] .. " " .. v[2] end
            r.detail:SetText(table.concat(parts, "  ·  "))
            r.total:SetText(tostring(it.total))
            y = y + 52
        end
        self.scroll:SetContentHeight(y)

        if #list > MAX_ROWS then
            self.info:SetText(string.format("%d objets (affichage limité à %d, affine ta recherche)", #list, MAX_ROWS))
        else
            self.info:SetText(string.format("%d objet%s", #list, #list > 1 and "s" or ""))
        end
    end,
})
