local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

-- Colonnes : { libellé, x, alignement }
local COLS = {
    { "Personnage", 52, "LEFT" },
    { "Niveau", 260, "LEFT" },
    { "Or", 450, "RIGHT" },
    { "Temps de jeu", 470, "LEFT" },
    { "Vu", 580, "LEFT" },
}

UI:RegisterPage({
    key = "characters", order = 2, section = "compte", icon = "users",
    title = "Personnages",
    subtitle = "Tous tes personnages enregistrés. Maj + clic sur la corbeille pour en oublier un.",
    count = function()
        local n = 0
        for _ in pairs(WK.DB.global.characters) do n = n + 1 end
        return tostring(n)
    end,

    Build = function(self, p)
        for _, col in ipairs(COLS) do
            local t = UI:Text(p, 10, C.dim)
            if col[3] == "RIGHT" then
                t:SetPoint("TOPRIGHT", p, "TOPLEFT", col[2] + 12, -4)
                t:SetJustifyH("RIGHT")
            else
                t:SetPoint("TOPLEFT", col[2] + 12, -4)
            end
            t:SetText(string.upper(col[1]))
        end

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", 0, -24)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll
        local child = scroll.child

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
            r.level = UI:Text(r, 12)
            r.level:SetPoint("LEFT", COLS[2][2], 0)
            r.gold = UI:Text(r, 12)
            r.gold:SetPoint("RIGHT", r, "LEFT", COLS[3][2], 0)
            r.gold:SetJustifyH("RIGHT")
            r.played = UI:Text(r, 12, C.muted)
            r.played:SetPoint("LEFT", COLS[4][2], 0)
            r.seen = UI:Text(r, 12, C.muted)
            r.seen:SetPoint("LEFT", COLS[5][2], 0)
            r.del = UI:IconButton(r, "trash", 26, "Maj + clic : oublier ce personnage", true)
            r.del:SetPoint("RIGHT", -10, 0)
            r.del:SetScript("OnClick", function(btn)
                if IsShiftKeyDown() and btn.key then WK.modules.Characters:Delete(btn.key) end
            end)
            return r
        end)
    end,

    Refresh = function(self)
        self.rows:Reset()
        local me = WK:CharKey()
        local y = 0
        for _, e in ipairs(UI:SortedCharacters()) do
            local r = self.rows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local c = e.c
            UI:SetClassIcon(r.icon, c.class)
            r.name:SetText(c.name or e.key)
            r.name:SetTextColor(UI:ClassColor(c.class))
            r.realm:SetText((c.realm or "") .. (c.faction and (" · " .. c.faction) or ""))
            r.badge:SetShown(e.key == me)
            r.level:SetText(tostring(c.level or "-"))
            r.gold:SetText(UI:GoldText(c.money))
            r.played:SetText(WK:FormatTime(c.played))
            r.seen:SetText(e.key == me and "maintenant" or UI:Ago(c.lastSeen))
            r.del.key = e.key
            r.del:SetShown(e.key ~= me)
            y = y + 56
        end
        self.scroll:SetContentHeight(y)
    end,
})
