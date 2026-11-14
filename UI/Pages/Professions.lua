local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local GAP = 12

UI:RegisterPage({
    key = "professions", order = 4, nav = "Métiers",
    title = "Métiers",
    subtitle = "Niveaux de compétence de chaque personnage.",

    Build = function(self, p)
        local scroll = UI:Scroll(p)
        scroll:SetAllPoints()
        self.scroll = scroll
        self.colW = (UI.PAGE_W - 12 - GAP) / 2

        self.cards = UI:Pool(function()
            local card = UI:Card(scroll.child, " ")
            card:SetWidth(self.colW)
            card.icon = UI:RoundIcon(card, 20)
            card.icon:SetPoint("TOPLEFT", 14, -12)
            card.title:ClearAllPoints()
            card.title:SetPoint("LEFT", card.icon, "RIGHT", 8, 0)
            card.empty = UI:Text(card, 11, C.dim)
            card.empty:SetPoint("TOPLEFT", 16, -46)
            card.empty:SetText("Aucun métier enregistré")
            card.lines = {}
            return card
        end)
    end,

    Refresh = function(self)
        self.cards:Reset()
        local colY = { 0, 0 }
        for _, e in ipairs(UI:SortedCharacters()) do
            local card = self.cards:Get()
            local c = e.c
            UI:SetClassIcon(card.icon, c.class)
            card.title:SetText(c.name or e.key)
            card.title:SetTextColor(UI:ClassColor(c.class))

            local names = {}
            for name in pairs(c.professions or {}) do table.insert(names, name) end
            table.sort(names)
            for _, l in ipairs(card.lines) do l:Hide() end
            for i, name in ipairs(names) do
                local l = card.lines[i]
                if not l then
                    l = CreateFrame("Frame", nil, card)
                    l:SetHeight(30)
                    l.name = UI:Text(l, 12)
                    l.name:SetPoint("TOPLEFT")
                    l.rank = UI:Text(l, 11, C.muted)
                    l.rank:SetPoint("TOPRIGHT")
                    l.rank:SetJustifyH("RIGHT")
                    l.bar = UI:Progress(l, 6)
                    l.bar:SetPoint("BOTTOMLEFT", 0, 2)
                    l.bar:SetPoint("BOTTOMRIGHT", 0, 2)
                    card.lines[i] = l
                end
                local pr = c.professions[name]
                l:ClearAllPoints()
                l:SetPoint("TOPLEFT", 16, -44 - (i - 1) * 38)
                l:SetPoint("TOPRIGHT", -16, -44 - (i - 1) * 38)
                l.name:SetText(name)
                l.rank:SetText(string.format("%d / %d", pr.rank or 0, pr.max or 0))
                l.bar:SetValue((pr.max or 0) > 0 and (pr.rank or 0) / pr.max or 0)
                l:Show()
            end
            card.empty:SetShown(#names == 0)
            local h = 52 + math.max(1, #names) * 38 - (#names == 0 and 14 or 0)
            card:SetHeight(h)

            -- Placement en "maçonnerie" : dans la colonne la moins haute.
            local col = colY[1] <= colY[2] and 1 or 2
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", (col - 1) * (self.colW + GAP), -colY[col])
            colY[col] = colY[col] + h + GAP
        end
        self.scroll:SetContentHeight(math.max(colY[1], colY[2]))
    end,
})
