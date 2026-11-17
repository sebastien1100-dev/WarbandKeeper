local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Trois couleurs fixes, douces et accordées aux thèmes chauds, indépendantes de l'accent :
-- vert sauge (ajouts), ambre (modifications), vieux rose (corrections).
local SECTIONS = {
    { "added", "+  AJOUTS", { 0.66, 0.79, 0.50, 1 } },
    { "changed", "~  MODIFICATIONS", { 0.88, 0.66, 0.35, 1 } },
    { "fixed", "!  CORRECTIONS", { 0.85, 0.53, 0.53, 1 } },
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
    card:SetPoint("TOPRIGHT", 0, -y)

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
    if not entry.roadmap then
        local r = entry.restart and UI:Badge(card, T("redémarrer le jeu"), C.warning) or UI:Badge(card, T("/reload suffit"), C.muted)
        r:SetPoint("LEFT", after, "RIGHT", 6, 0)
        after = r
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
    local textW = width - 18 - 34 - 18
    local function bullets(list, color)
        for _, line in ipairs(list) do
            local dot = UI:Icon(card, "circle", 5, color or C.muted, "ARTWORK")
            dot:SetPoint("TOPLEFT", 30, -h - 6)
            local th = wrapped(card, line, 44, -h, textW, C.text, 12)
            h = h + th + 7
        end
    end

    if entry.roadmap then
        bullets(entry.items, C.dim)
    else
        for _, sec in ipairs(SECTIONS) do
            local list = entry[sec[1]]
            if list and #list > 0 then
                local top = h
                local badge = UI:Badge(card, sec[2], sec[3])
                badge:SetPoint("TOPLEFT", 26, -h)
                h = h + 26
                bullets(list, sec[3])
                -- Liseré de la couleur de la rubrique, sur toute sa hauteur
                local stripe = card:CreateTexture(nil, "ARTWORK")
                stripe:SetColorTexture(unpack(sec[3]))
                stripe:SetPoint("TOPLEFT", 16, -top)
                stripe:SetSize(3, h - top - 2)
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
    title = "Patch notes",
    subtitle = "Tout ce qui a été ajouté, modifié et corrigé, version par version.",
    count = function() return notesSeen() and "" or "•" end,

    Build = function(self, p)
        local scroll = UI:Scroll(p)
        scroll:SetAllPoints()
        local width = UI.PAGE_W - 12
        local y = 0
        -- « À venir » toujours en haut, puis les versions de la plus récente à la plus ancienne.
        if #WK.Roadmap > 0 then
            y = y + VersionCard(scroll.child, y, { roadmap = true, items = WK.Roadmap }, false, width) + 12
        end
        for i, entry in ipairs(WK.Changelog) do
            y = y + VersionCard(scroll.child, y, entry, i == 1 and entry.version == WK.version, width) + 12
        end
        scroll:SetContentHeight(y)
    end,

    Refresh = function()
        WK.DB.global.settings.notesSeenVersion = WK.version
    end,
})
