local ADDON_NAME, WK = ...
local UI = WK.UI

-- Carte sans brouillard : les zones que le perso n'a pas encore découvertes sont dessinées quand même sur
-- la carte du monde (le jeu ne dessine que celles découvertes). Morceaux de carte : Modules/MapRevealDB.lua
-- (généré par tools/gen_reveal.py depuis les tables WorldMapOverlay du jeu) ; zones découvertes lues par
-- C_MapExplorationInfo.GetExploredMapTextures. Réglages MapLayers:Config() : reveal (défaut oui),
-- revealTint (zones pas découvertes plus sombres, défaut oui). Appelé par UI/MapPins.lua (calque « Brouillard »).
local layer, pool, used = nil, {}, 0
local TILE = 256

local function tex()
    used = used + 1
    local t = pool[used]
    if not t then t = layer:CreateTexture(nil, "ARTWORK"); pool[used] = t end
    return t
end

-- côté du fichier d'image : puissance de deux qui contient la partie utile (dernière ligne ou colonne)
local function fileSize(px)
    local f = 16
    while f < px do f = f * 2 end
    return f
end

function UI:HideMapReveal()
    for i = 1, #pool do pool[i]:Hide() end
    used = 0
    UI.mapRevealCount = 0
end

-- niveau du calque des zones découvertes du jeu (on dessine au même niveau), sinon juste au-dessus de la toile
local function gameLevel(cv)
    local wm = WorldMapFrame
    if wm and wm.EnumeratePinsByTemplate then
        -- l'énumération du jeu renvoie un itérateur complet (fonction, table, départ), comme pairs() :
        -- n'en garder que la fonction faisait échouer tout le calque
        local ok, f, st, k0 = pcall(wm.EnumeratePinsByTemplate, wm, "MapExplorationPinTemplate")
        if ok and type(f) == "function" then
            local lv
            pcall(function()
                for k, v in f, st, k0 do
                    local pin = (type(k) == "table" and k.GetFrameLevel and k) or (type(v) == "table" and v.GetFrameLevel and v)
                    if pin then lv = pin:GetFrameLevel() return end
                end
            end)
            if lv then return lv end
        end
    end
    return (cv:GetFrameLevel() or 1) + 1
end

function UI:DrawMapReveal(cv, mapID, cw, ch)
    UI:HideMapReveal()
    local cfg = WK.modules.MapLayers:Config()
    if cfg.reveal == false or not WK.MapRevealDB or not WK:FeatureOn("maplayers") then return end
    local d = WK.MapRevealDB[mapID]
    if not d or not (C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures) then return end
    if not layer then
        layer = CreateFrame("Frame", nil, cv)
        layer.wk = true
        layer:EnableMouse(false)
    end
    layer:SetParent(cv)
    layer:ClearAllPoints(); layer:SetAllPoints(cv)
    layer:SetFrameLevel(gameLevel(cv))
    layer:Show()
    -- zones découvertes : repérées par leur place et leur taille
    local seen = {}
    local ok, explored = pcall(C_MapExplorationInfo.GetExploredMapTextures, mapID)
    for _, e in ipairs(ok and explored or {}) do
        seen[(e.offsetX or 0) .. ":" .. (e.offsetY or 0) .. ":" .. (e.textureWidth or 0)] = true
    end
    local sx, sy = cw / d[1], ch / d[2]
    local shade = cfg.revealTint ~= false and 0.55 or 1
    for k = 3, #d do
        local o = d[k]
        local w, h, ox, oy = o[1], o[2], o[3], o[4]
        if not seen[ox .. ":" .. oy .. ":" .. w] then
            local ids = {}
            for id in o[5]:gmatch("%d+") do ids[#ids + 1] = tonumber(id) end
            local cols, rows = math.ceil(w / TILE), math.ceil(h / TILE)
            for j = 1, rows do
                local ph = (j < rows) and TILE or (h - TILE * (rows - 1))
                local fh = (j < rows) and TILE or fileSize(ph)
                for i = 1, cols do
                    local id = ids[(j - 1) * cols + i]
                    if id and id > 0 then
                        local pw = (i < cols) and TILE or (w - TILE * (cols - 1))
                        local fw = (i < cols) and TILE or fileSize(pw)
                        local t = tex()
                        t:SetTexture(id)
                        t:SetTexCoord(0, pw / fw, 0, ph / fh)
                        t:SetSize(pw * sx, ph * sy)
                        t:ClearAllPoints()
                        t:SetPoint("TOPLEFT", layer, "TOPLEFT", (ox + TILE * (i - 1)) * sx, -(oy + TILE * (j - 1)) * sy)
                        t:SetVertexColor(shade, shade, shade, 1)
                        t:Show()
                    end
                end
            end
        end
    end
    UI.mapRevealCount = used -- /wk carte
end

