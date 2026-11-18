local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Couleurs de sens de la palette (UI/Themes.lua), lues à l'affichage : ajouts en vert (positive),
-- modifications en ambre (warning), corrections en rouge doux (negative).
local SECTIONS = {
    { "added", "+  AJOUTS", "positive" },
    { "changed", "~  MODIFICATIONS", "warning" },
    { "fixed", "!  CORRECTIONS", "negative" },
}

local function notesSeen() return WK.DB.global.settings.notesSeenVersion == WK.version end

-- Texte à la ligne automatique (largeur posée par la mise en page de la carte)
local function wrapped(parent, text, color, size)
    local fs = UI:Text(parent, size or 12, color)
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    fs:SetSpacing(3)
    fs:SetText(text)
    return fs
end

-- Carte d'une version (ou de la feuille de route). Les éléments sont créés une fois ;
-- card:Layout(largeur) les place et renvoie la hauteur (appelé à chaque changement de taille).
local function VersionCard(parent, entry, isCurrent)
    local card = UI:Card(parent, nil, nil, isCurrent)

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

    -- éléments à placer : { kind = "bullet", dot, fs } / { kind = "head", badge, stripe } / { kind = "end", stripe }
    local parts = {}
    local function bullets(list, color)
        for _, line in ipairs(list) do
            table.insert(parts, { kind = "bullet", dot = UI:Icon(card, "circle", 5, color or C.muted, "ARTWORK"),
                fs = wrapped(card, line, C.text, 12) })
        end
    end
    if entry.roadmap then
        bullets(entry.items, C.dim)
    else
        for _, sec in ipairs(SECTIONS) do
            local list = entry[sec[1]]
            if list and #list > 0 then
                -- liseré de la couleur de la rubrique, sur toute sa hauteur
                local stripe = card:CreateTexture(nil, "ARTWORK")
                local col = C[sec[3]]
                stripe:SetColorTexture(unpack(col))
                table.insert(parts, { kind = "head", badge = UI:Badge(card, sec[2], col), stripe = stripe })
                bullets(list, col)
                table.insert(parts, { kind = "end", stripe = stripe })
            end
        end
    end

    function card:Layout(width)
        local h, top = 48, 0
        local textW = width - 18 - 34 - 18
        for _, e in ipairs(parts) do
            if e.kind == "head" then
                top = h
                e.badge:ClearAllPoints(); e.badge:SetPoint("TOPLEFT", 26, -h)
                h = h + 26
            elseif e.kind == "bullet" then
                e.dot:ClearAllPoints(); e.dot:SetPoint("TOPLEFT", 30, -h - 6)
                e.fs:ClearAllPoints(); e.fs:SetPoint("TOPLEFT", 44, -h); e.fs:SetWidth(textW)
                h = h + (e.fs:GetStringHeight() or 16) + 7
            else
                e.stripe:ClearAllPoints(); e.stripe:SetPoint("TOPLEFT", 16, -top)
                e.stripe:SetSize(3, math.max(1, h - top - 2))
                h = h + 6
            end
        end
        h = h + 10
        self:SetHeight(h)
        return h
    end
    return card
end

UI:RegisterPage({
    key = "notes", order = 9, navIcon = "notes",
    title = "Patch notes",
    subtitle = "Tout ce qui a été ajouté, modifié et corrigé, version par version.",
    count = function() return notesSeen() and "" or "•" end,

    Build = function(self, p)
        local scroll = UI:Scroll(p)
        scroll:SetAllPoints()
        -- « À venir » toujours en haut, puis les versions de la plus récente à la plus ancienne.
        local cards = {}
        if #WK.Roadmap > 0 then table.insert(cards, VersionCard(scroll.child, { roadmap = true, items = WK.Roadmap }, false)) end
        for i, entry in ipairs(WK.Changelog) do
            table.insert(cards, VersionCard(scroll.child, entry, i == 1 and entry.version == WK.version))
        end
        -- largeur et hauteurs recalculées quand la fenêtre change de taille
        UI:OnResize(scroll, function(w)
            local width = math.max(400, (w or UI.PAGE_W) - 12)
            local y = 0
            for _, c in ipairs(cards) do
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", 0, -y)
                c:SetPoint("TOPRIGHT", 0, -y)
                y = y + c:Layout(width) + 12
            end
            scroll:SetContentHeight(y)
        end)
    end,

    Refresh = function()
        WK.DB.global.settings.notesSeenVersion = WK.version
    end,
})
