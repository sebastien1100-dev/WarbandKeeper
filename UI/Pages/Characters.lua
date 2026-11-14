local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end
local WARN = { 0.95, 0.66, 0.30, 1 }

-- Colonnes : { libellé, x, alignement }
-- Positions prévues pour 924 px de large, mises à l'échelle à la construction.
local BASE_COLS = {
    { "Personnage", 52, "LEFT" },
    { "Niveau", 262, "LEFT" },
    { "Or", 430, "RIGHT" },
    { "Temps de jeu", 462, "LEFT" },
    { "Banque", 582, "LEFT" },
    { "Courrier", 700, "LEFT" },
    { "Vu", 802, "LEFT" },
}
local COLS = {}

UI:RegisterPage({
    key = "characters", order = 2, nav = "Persos",
    title = "Personnages",
    subtitle = "Tous tes personnages enregistrés. Maj + clic sur la corbeille pour en oublier un.",
    count = function()
        local n = 0
        for _ in pairs(WK.DB.global.characters) do n = n + 1 end
        return tostring(n)
    end,

    Build = function(self, p)
        local k = UI.PAGE_W / 924
        for i, c in ipairs(BASE_COLS) do COLS[i] = { c[1], math.floor(c[2] * k), c[3] } end
        for _, col in ipairs(COLS) do
            local t = UI:Text(p, 10, C.dim)
            if col[3] == "RIGHT" then
                t:SetPoint("TOPRIGHT", p, "TOPLEFT", col[2], -4)
                t:SetJustifyH("RIGHT")
            else
                t:SetPoint("TOPLEFT", col[2], -4)
            end
            t:SetText(UI:Upper(T(col[1])))
        end

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", 0, -24)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll
        local child = scroll.child

        local function cell(r, x, color)
            local fs = UI:Text(r, 12, color)
            fs:SetPoint("LEFT", x, 0)
            return fs
        end

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
            r.realm:SetWidth(COLS[2][2] - 52 - 10)
            r.badge = UI:Badge(r, "connecté")
            r.badge:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
            r.level = cell(r, COLS[2][2])
            r.gold = UI:Text(r, 12)
            r.gold:SetPoint("RIGHT", r, "LEFT", COLS[3][2], 0)
            r.gold:SetJustifyH("RIGHT")
            r.played = cell(r, COLS[4][2], C.muted)
            r.bank = cell(r, COLS[5][2], C.muted)
            r.mail = cell(r, COLS[6][2], C.muted)
            r.seen = cell(r, COLS[7][2], C.muted)
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

            -- Banque et courrier, en orange quand une alerte les concerne.
            local warnBank, warnMail = false, false
            for _, a in ipairs(WK.modules.Alerts:For(c, e.key)) do
                if a.kind == "bank" then warnBank = true else warnMail = true end
            end
            r.bank:SetText(c.bankScanned and UI:Ago(c.bankScanned) or T("jamais"))
            r.bank:SetTextColor(unpack(warnBank and WARN or C.muted))
            local box = c.mailbox
            if box and (box.count or 0) > 0 then
                local txt = string.format((box.count > 1) and T("%d lettres") or T("%d lettre"), box.count)
                if box.expiresAt then
                    local d = math.max(0, math.floor((box.expiresAt - time()) / 86400))
                    txt = txt .. " · " .. string.format(T("%d j"), d)
                end
                r.mail:SetText(txt)
            else
                r.mail:SetText(box and T("vide") or "-")
            end
            r.mail:SetTextColor(unpack(warnMail and WARN or C.muted))

            r.seen:SetText(e.key == me and T("maintenant") or UI:Ago(c.lastSeen))
            r.del.key = e.key
            r.del:SetShown(e.key ~= me)
            y = y + 56
        end
        self.scroll:SetContentHeight(y)
    end,
})
