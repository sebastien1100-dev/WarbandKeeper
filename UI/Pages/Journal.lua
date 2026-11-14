local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

local FILTERS = { { "all", "Tout" }, { "gold", "Or" }, { "mail", "Courrier" }, { "skill", "Métiers" } }
local ICONS = { gold = "coin", mail = "mail", skill = "hammer", level = "chart", bank = "bag", farm = "play" }
local MAX_ROWS = 200

local function charLabel(key)
    local c = WK.DB.global.characters[key]
    local name = c and c.name or (key and key:match("^[^%-]+")) or "?"
    local r, g, b = UI:ClassColor(c and c.class)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, name)
end

local function recipientLabel(name)
    local c = WK.modules.Mail:FindCharacter(name)
    if not c then return name end
    local r, g, b = UI:ClassColor(c.class)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, c.name)
end

-- Texte d'une entrée du journal.
local function describe(e)
    local who = charLabel(e.char)
    if e.kind == "gold" then
        local col = e.delta >= 0 and "|cff9ed17a+" or "|cffe86a6a"
        return string.format("%s  %s%s|r", who, col, UI:ShortGold(e.delta)),
            e.delta >= 0 and T("or gagné") or T("or dépensé")
    elseif e.kind == "mail" then
        local parts = {}
        for id, n in pairs(e.items or {}) do table.insert(parts, { n, (UI:ItemInfo(id)) }) end
        table.sort(parts, function(a, b) return a[1] > b[1] end)
        for i, p in ipairs(parts) do parts[i] = p[1] .. " " .. p[2] end
        local letters = e.letters or 1
        return string.format("%s → %s : %s", who, recipientLabel(e.to), table.concat(parts, ", ")),
            string.format(letters > 1 and T("%d courriers envoyés") or T("%d courrier envoyé"), letters)
    elseif e.kind == "skill" then
        return string.format("%s : %s %d → %d", who, e.prof, e.from or 0, e.to or 0), T("progrès de métier")
    elseif e.kind == "bank" then
        local parts = {}
        for id, n in pairs(e.items or {}) do table.insert(parts, n .. " " .. (UI:ItemInfo(id))) end
        local where = e.target == "warband" and T("banque de bataillon") or T("banque")
        return string.format("%s → %s : %s", who, where, table.concat(parts, ", ")), T("dépôt en banque")
    elseif e.kind == "farm" then
        return string.format(T("%s : session à %s, %s, %d objet(s)"), who, (e.zone ~= "" and e.zone or "?"),
            UI:ShortGold(e.gold or 0), e.count or 0), string.format(T("session de farm · %s"), WK:FormatTime(e.duration))
    elseif e.kind == "level" then
        return string.format(T("%s atteint le niveau %d"), who, e.level or 0), T("niveau")
    end
    return who, ""
end

local function dayLabel(t)
    local today = date("%Y%m%d", time())
    local d = date("%Y%m%d", t)
    if d == today then return T("Aujourd'hui") end
    if d == date("%Y%m%d", time() - 86400) then return T("Hier") end
    return date("%d/%m/%Y", t)
end

UI:RegisterPage({
    key = "journal", order = 6, nav = "Journal",
    title = "Journal",
    subtitle = "Ce qui s'est passé sur ton compte : or, courriers envoyés, métiers et niveaux.",

    Build = function(self, p)
        self.filter = "all"
        local seg = UI:Segmented(p, FILTERS, function(k) self.filter = k; self:Refresh() end, 32)
        seg:SetPoint("TOPLEFT")
        seg:Select("all")
        self.info = UI:Text(p, 11, C.muted)
        self.info:SetPoint("TOPRIGHT", -4, -10)
        self.info:SetJustifyH("RIGHT")

        local scroll = UI:Scroll(p)
        scroll:SetPoint("TOPLEFT", 0, -46)
        scroll:SetPoint("BOTTOMRIGHT")
        self.scroll = scroll
        self.empty = UI:Text(p, 12, C.muted)
        self.empty:SetPoint("CENTER", scroll, "CENTER")
        self.empty:SetText("Rien pour l'instant : joue un peu, tout s'inscrira ici.")

        self.headers = UI:Pool(function()
            local h = UI:Text(scroll.child, 11, C.dim)
            return h
        end)
        self.rows = UI:Pool(function()
            local r = CreateFrame("Frame", nil, scroll.child)
            r:SetHeight(44)
            r.border = UI:Rounded(r, 12, 0, "BACKGROUND", 0)
            r.border:SetColor(unpack(C.border))
            r.bg = UI:Rounded(r, 11, 1, "BACKGROUND", 1)
            r.bg:SetColor(unpack(C.surface))
            r.iconBg = CreateFrame("Frame", nil, r)
            r.iconBg:SetSize(28, 28)
            r.iconBg:SetPoint("LEFT", 10, 0)
            r.iconRound = UI:Rounded(r.iconBg, 14, 0, "BACKGROUND", 2)
            r.icon = UI:Icon(r.iconBg, "coin", 14)
            r.icon:SetPoint("CENTER")
            r.text = UI:Text(r, 12)
            r.text:SetPoint("TOPLEFT", 50, -8)
            r.text:SetPoint("TOPRIGHT", -70, -8)
            r.sub = UI:Text(r, 10, C.muted)
            r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
            r.time = UI:Text(r, 11, C.dim)
            r.time:SetPoint("RIGHT", -14, 0)
            r.time:SetJustifyH("RIGHT")
            return r
        end)
    end,

    Refresh = function(self)
        local entries = WK.modules.Journal:Entries(self.filter)
        self.headers:Reset()
        self.rows:Reset()
        local y, lastDay = 0, nil
        for i, e in ipairs(entries) do
            if i > MAX_ROWS then break end
            local day = dayLabel(e.t)
            if day ~= lastDay then
                local h = self.headers:Get()
                h:ClearAllPoints()
                h:SetPoint("TOPLEFT", 4, -y - (lastDay and 10 or 0))
                h:SetText(string.upper(day))
                y = y + (lastDay and 30 or 20)
                lastDay = day
            end
            local r = self.rows:Get()
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", 0, -y)
            local text, sub = describe(e)
            r.text:SetText(text)
            r.sub:SetText(sub)
            r.time:SetText(date("%H:%M", e.t))
            r.icon:SetTexture(UI.MEDIA .. (ICONS[e.kind] or "coin"))
            local col
            if e.kind == "gold" then col = e.delta >= 0 and C.positive or C.negative
            elseif e.kind == "level" then col = { 0.70, 0.56, 1.0 }
            else col = { UI:Accent() } end
            r.icon:SetVertexColor(col[1], col[2], col[3], 1)
            r.iconRound:SetColor(col[1], col[2], col[3], 0.16)
            y = y + 50
        end
        self.scroll:SetContentHeight(y)
        self.empty:SetShown(#entries == 0)
        self.info:SetText(string.format(#entries > 1 and T("%d événements") or T("%d événement"), #entries))
    end,
})
