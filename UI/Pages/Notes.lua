local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors

local SECTIONS = {
    { "added", "AJOUTS", C.positive },
    { "changed", "MODIFICATIONS", nil }, -- couleur d'accent
    { "fixed", "CORRECTIONS", C.negative },
}

local function notesSeen() return WK.DB.global.settings.notesSeenVersion == WK.version end

-- Texte à la ligne automatique ; renvoie la hauteur occupée.
local function wrapped(parent, text, x, y, width, color, size)
    local fs = UI:Text(parent, size or 12, color)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(3)
    fs:SetWidth(width)
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs:GetStringHeight() or (size or 12) * 1.3
end

-- Carte d'une version (ou de la feuille de route) ; renvoie sa hauteur.
local function VersionCard(parent, y, entry, isCurrent, width)
    local card = UI:Card(parent, nil, nil, isCurrent)
    card:SetPoint("TOPLEFT", 0, -y)
    card:SetWidth(width)

    local title = UI:Text(card, 16)
    title:SetPoint("TOPLEFT", 18, -16)
    title:SetText(entry.roadmap and "À venir" or ("v" .. entry.version))
    UI:OnAccent(function() title:SetTextColor(UI:Accent()) end)
    local after = title
    if entry.date then
        local d = UI:Badge(card, entry.date, C.muted)
        d:SetPoint("LEFT", after, "RIGHT", 10, 0)
        after = d
    end
    if isCurrent then
        local cur = UI:Badge(card, "version installée")
        cur:SetPoint("LEFT", after, "RIGHT", 6, 0)
    end
    if entry.roadmap then
        local hint = UI:Text(card, 11, C.muted)
        hint:SetPoint("LEFT", title, "RIGHT", 12, 0)
        hint:SetText("prévu, pas encore commencé")
    end

    local h = 48
    local textW = width - 18 - 26 - 18
    local function bullets(list, color)
        for _, line in ipairs(list) do
            local dot = UI:Icon(card, "circle", 5, color or C.muted, "ARTWORK")
            dot:SetPoint("TOPLEFT", 22, -h - 6)
            local th = wrapped(card, line, 36, -h, textW, C.text, 12)
            h = h + th + 7
        end
    end

    if entry.roadmap then
        bullets(entry.items, C.dim)
    else
        for _, sec in ipairs(SECTIONS) do
            local list = entry[sec[1]]
            if list and #list > 0 then
                local badge = UI:Badge(card, sec[2], sec[3])
                badge:SetPoint("TOPLEFT", 18, -h)
                h = h + 26
                bullets(list, sec[3] or { UI:Accent() })
                h = h + 6
            end
        end
    end
    h = h + 10
    card:SetHeight(h)
    return h
end

UI:RegisterPage({
    key = "notes", order = 9, navIcon = "notes",
    title = "Notes de patch",
    subtitle = "Tout ce qui a été ajouté, modifié et corrigé, version par version.",
    count = function() return notesSeen() and "" or "•" end,

    Build = function(self, p)
        local scroll = UI:Scroll(p)
        scroll:SetAllPoints()
        local width = UI.PAGE_W - 12
        local y = 0
        for i, entry in ipairs(WK.Changelog) do
            y = y + VersionCard(scroll.child, y, entry, i == 1 and entry.version == WK.version, width) + 12
            if i == 1 and #WK.Roadmap > 0 then
                y = y + VersionCard(scroll.child, y, { roadmap = true, items = WK.Roadmap }, false, width) + 12
            end
        end
        scroll:SetContentHeight(y)
    end,

    Refresh = function()
        WK.DB.global.settings.notesSeenVersion = WK.version
    end,
})
