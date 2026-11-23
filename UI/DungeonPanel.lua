local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Panneau « donjon » : en donjon, ancré à droite de la carte du monde (ou seul, avec /wk donjon).
-- Boss dans l'ordre (tués pendant ce passage marqués « tué »), butin de chacun (un boss déplié à la
-- fois), filtres Pour moi / Tout / Envies, étoile pour la liste d'envies.
-- UI:DungeonLootRow(parent) fabrique la ligne d'objet, reprise par la page Donjons.
local D = WK.modules.Dungeons
local panel
local W, ITEM_H, BOSS_H = 300, 22, 26

local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, { 1, 1, 1 }, { 0.12, 1, 0 }, { 0, 0.44, 0.87 }, { 0.64, 0.21, 0.93 }, { 1, 0.5, 0 } }
local function quality(id)
    local q
    if C_Item and C_Item.GetItemQualityByID then
        local ok, v = pcall(C_Item.GetItemQualityByID, id)
        if ok then q = v end
    end
    if not q then q = select(3, WK.GetItemInfo(id)) end
    if not q then local i = D:ItemInfo(id); q = i and i.quality end
    return QUALITY[q or 1] or QUALITY[1]
end
UI.DungeonQuality = quality

-- Ligne d'objet : icône, nom (couleur de qualité), étiquettes « pour toi » / « sur le compte », étoile
function UI:DungeonLootRow(parent)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(ITEM_H)
    r.icon = UI:RoundIcon(r, 18)
    r.icon:SetPoint("LEFT", 6, 0)
    r.star = CreateFrame("Button", nil, r)
    r.star:SetSize(20, 20)
    r.star:SetPoint("RIGHT", -4, 0)
    r.star.t = UI:Icon(r.star, "star", 13, nil, "ARTWORK")
    r.star.t:SetPoint("CENTER")
    r.tag = UI:Badge(r, "", nil)
    r.tag:SetPoint("RIGHT", r.star, "LEFT", -4, 0)
    -- taux de drop, toujours affiché (colonne à droite du nom)
    r.drop = UI:Text(r, 11, C.muted)
    r.drop:SetJustifyH("RIGHT")
    r.name = UI:Text(r, 11)
    r.name:SetPoint("LEFT", 30, 0)
    r.name:SetPoint("RIGHT", r.tag, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r:SetScript("OnEnter", function(s)
        UI:TooltipOwner(s, "ANCHOR_RIGHT")
        if GameTooltip.SetItemByID then GameTooltip:SetItemByID(s.id) else GameTooltip:SetText((UI:ItemInfo(s.id))) end
        local info = D:ItemInfo(s.id)
        if info and info.undiscovered then GameTooltip:AddLine(T("Pas encore vu tomber sur WoW Forever (table de butin en cours de relevé)."), 1, 0.6, 0.3, true)
        elseif info and info.drop and info.observed then
            GameTooltip:AddLine(string.format(T("Chance de drop observée : %s %% (%d butins relevés, Everloot)"), tostring(info.drop), info.observed), 0.8, 0.8, 0.8)
        elseif info and info.drop then GameTooltip:AddLine(string.format(T("Chance de drop : %s %%"), tostring(info.drop)), 0.8, 0.8, 0.8) end
        GameTooltip:AddLine(T("Maj + clic : lien dans le chat · étoile : liste d'envies"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(s)
        if IsShiftKeyDown() then
            local link = select(6, UI:ItemInfo(s.id))
            if link then WK.InsertChatLink(link) end
        end
    end)
    r.star:SetScript("OnClick", function() D:ToggleWish(r.id, r.dkey, r.charKey); r:Paint() end)
    -- hideMine : liste déjà filtrée « pour ce perso » : l'étiquette « pour toi » n'apprendrait rien
    function r:Set(id, dkey, c, charKey, hideMine)
        self.id, self.dkey, self.c, self.charKey, self.hideMine = id, dkey, c, charKey, hideMine
        self:Paint()
    end
    function r:Paint()
        local name, icon = UI:ItemInfo(self.id)
        self.icon:SetTexture(icon)
        self.name:SetText(name)
        self.name:SetTextColor(unpack(quality(self.id)))
        local usable = self.c and D:Usable(self.id, self.c)
        local info = D:ItemInfo(self.id)
        if D:Owned(self.id) then self.tag:Set(T("sur le compte"), C.positive); self.tag:Show()
        elseif usable and not self.hideMine then self.tag:Set(T("pour toi")); self.tag:Show()
        elseif info and info.undiscovered then self.tag:Set(T("non découvert"), C.dim); self.tag:Show()
        else self.tag:Hide() end
        if name == nil or name == "" then self.name:SetText("#" .. tostring(self.id)) end
        -- taux de drop : vert à 25 % et plus, gris clair en dessous, pâle sous 5 % ; « ~ » = observé par les joueurs
        local drop = info and info.drop
        self.drop:SetShown(drop ~= nil)
        if drop then
            local txt = (drop >= 10 and string.format("%d %%", math.floor(drop + 0.5)) or string.format("%.1f %%", drop)):gsub("%.", ",")
            self.drop:SetText((info.observed and T("env. ") or "") .. txt)
            local col = drop >= 25 and C.positive or (drop >= 5 and C.muted or C.dim)
            self.drop:SetTextColor(col[1], col[2], col[3])
        end
        local right = self.tag:IsShown() and self.tag or self.star
        self.drop:ClearAllPoints(); self.drop:SetPoint("RIGHT", right, "LEFT", -8, 0)
        self.name:ClearAllPoints(); self.name:SetPoint("LEFT", 30, 0)
        self.name:SetPoint("RIGHT", drop and self.drop or right, "LEFT", -6, 0)
        local wished = D:IsWished(self.id, self.charKey)
        local r1, g1, b1 = UI:Accent()
        if wished then self.star.t:SetVertexColor(r1, g1, b1, 1) else self.star.t:SetVertexColor(C.dim[1], C.dim[2], C.dim[3], 1) end
    end
    return r
end

-- Butin d'un boss filtré : "me" (ce que le perso peut porter, ou inconnu), "all", "wish"
function UI:DungeonLoot(b, filter, c, charKey)
    local out = {}
    for _, id in ipairs(b.loot) do
        local ok = true
        if filter == "me" then ok = D:Usable(id, c) ~= false
        elseif filter == "wish" then ok = D:IsWished(id, charKey) end
        if ok then table.insert(out, id) end
    end
    return out
end

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperDungeonPanel", UIParent)
    f:SetSize(W, 200)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.94 }, C.border)
    f.title = UI:Text(f, 13)
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetPoint("TOPRIGHT", -34, -12)
    f.title:SetJustifyH("LEFT")
    f.sub = UI:Text(f, 10, C.muted)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -8, -8)
    -- fermé à la croix : ne se recolle plus tout seul à la carte jusqu'à /wk donjon (ou le bouton
    -- de la page Donjons), ou jusqu'à la prochaine session
    f.close:SetScript("OnClick", function() f.userHidden = true; f:Hide() end)
    -- glisser le titre pour déplacer quand le panneau est seul (pas collé à la carte)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not s.docked then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    f.seg = UI:Segmented(f, { { "me", "Pour moi" }, { "all", "Tout" }, { "wish", "Envies" } }, function(v)
        D:Config().filter = v; f:Refresh()
    end, 22)
    f.seg:SetPoint("TOPLEFT", 12, -46)
    f.scroll = UI:Scroll(f)
    f.scroll:SetPoint("TOPLEFT", 6, -76)
    f.scroll:SetPoint("BOTTOMRIGHT", -6, 8)
    f.heads = UI:Pool(function()
        local h = CreateFrame("Button", nil, f.scroll.child)
        h:SetHeight(BOSS_H)
        h.bg = UI:Rounded(h, 7, 0, "BACKGROUND", 1)
        h.name = UI:Text(h, 12)
        h.name:SetPoint("LEFT", 10, 0)
        h.right = UI:Text(h, 10, C.muted)
        h.right:SetPoint("RIGHT", -10, 0)
        h:SetScript("OnClick", function(s) f.open = (f.open == s.bossID) and 0 or s.bossID; f:Refresh() end)
        return h
    end)
    f.items = UI:Pool(function() return UI:DungeonLootRow(f.scroll.child) end)
    f.empty = UI:Text(f.scroll.child, 11, C.muted)

    function f:Refresh()
        local d = self.dungeon
        if not d then return end
        local c = WK.DB:Me()
        local me = WK:CharKey()
        local cfg = D:Config()
        self.seg:Select(cfg.filter)
        self.title:SetText(D:Name(d))
        local killed, n = 0, 0
        -- boss facultatifs (D:Optional) hors du compte : avant, le donjon restait à 5/6 une fois fini
        for _, b in ipairs(D:Bosses(d)) do
            if not D:Optional(d, b) then n = n + 1; if D:Killed(d, b.id) then killed = killed + 1 end end
        end
        self.sub:SetText(string.format(T("niv. %d-%d · %d/%d boss"), d.min, d.max, killed, n))
        self.heads:Reset(); self.items:Reset()
        local y, LW = 0, W - 22
        local r1, g1, b1 = UI:Accent()
        -- boss déplié : celui choisi, sinon le premier pas encore tué
        if not self.open then
            for _, b in ipairs(D:Bosses(d)) do if not D:Killed(d, b.id) then self.open = b.id break end end
        end
        local shown = 0
        for _, b in ipairs(D:LootGroups(d)) do
            local loot = UI:DungeonLoot(b, cfg.filter, c, me)
            if cfg.filter ~= "wish" or #loot > 0 then
                shown = shown + 1
                local h = self.heads:Get()
                h.bossID = b.id
                h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y); h:SetWidth(LW)
                local dead = D:Killed(d, b.id)
                h.name:SetText(D:BossName(b))
                h.name:SetTextColor(unpack(dead and C.dim or C.text))
                h.right:SetText(dead and (UI:Hex(C.positive) .. T("tué") .. "|r") or string.format(#loot > 1 and T("%d objets") or T("%d objet"), #loot))
                if b.wing then h.name:SetText(D:BossName(b) .. "  " .. UI:Hex(C.muted) .. T(b.wing) .. "|r") end
                local open = self.open == b.id
                h.bg:SetColor(C.surface2[1], C.surface2[2], C.surface2[3], open and 1 or 0.6)
                y = y + BOSS_H + 2
                if open then
                    for _, id in ipairs(loot) do
                        local it = self.items:Get()
                        it:ClearAllPoints(); it:SetPoint("TOPLEFT", 4, -y); it:SetWidth(LW - 4)
                        it:Set(id, d.key, c, me, cfg.filter == "me")
                        y = y + ITEM_H
                    end
                    if #loot == 0 then y = y + 2 end
                    y = y + 4
                end
            end
        end
        self.empty:SetShown(shown == 0)
        self.empty:ClearAllPoints(); self.empty:SetPoint("TOPLEFT", 8, -4)
        self.empty:SetText(T("Aucun objet de ta liste d'envies dans ce donjon."))
        self.scroll.child:SetSize(LW, math.max(y, 20))
        if self.scroll.UpdateBar then self.scroll:UpdateBar() end
        if not self.docked then self:SetHeight(math.min(520, 76 + math.max(y, 24) + 10)) end
        self.title:SetTextColor(r1, g1, b1)
    end
    return f
end

-- Affiche le panneau pour un donjon ; docked = collé à la carte du monde
local function showFor(d, docked)
    if not d or not WK:FeatureOn("dungeons") then return end
    panel = panel or build()
    if panel.dungeon ~= d then panel.open = nil end
    panel.dungeon, panel.docked = d, docked
    panel:ClearAllPoints()
    if docked and WorldMapFrame then
        panel:SetPoint("TOPLEFT", WorldMapFrame, "TOPRIGHT", 4, 0)
        panel:SetPoint("BOTTOMLEFT", WorldMapFrame, "BOTTOMRIGHT", 4, 0)
        UI:MatchHost(panel, WorldMapFrame)
    else
        panel:SetPoint("RIGHT", UIParent, "RIGHT", -60, 40)
        panel:SetFrameStrata("MEDIUM")
    end
    panel:Show()
    panel:Refresh()
end

-- /wk donjon : le donjon en cours (ou le dernier choisi dans la page)
function UI:ToggleDungeonPanel(d)
    if panel and panel:IsShown() and not panel.docked and not d then panel:Hide() return end
    d = d or D:Current() or (panel and panel.dungeon)
    if not d then WK:Print(T("Tu n'es pas dans un donjon : choisis-en un dans la page Donjons.")) return end
    if panel then panel.userHidden = nil end
    showFor(d, false)
end

local function onMap()
    local d = D:Current()
    -- donjon avec carte : notre carte remplace celle du monde (UI/DungeonMap.lua), pas de panneau
    local mapped = d and UI.DungeonMapData and UI.DungeonMapData(d) and D:Config().worldMap ~= false
    if mapped and panel and panel.docked then panel:Hide() end
    if d and not mapped and D:Config().panel and WorldMapFrame and WorldMapFrame:IsShown() and not (panel and panel.userHidden) then
        showFor(d, true)
    elseif panel and panel.docked then
        panel:Hide()
    end
end
local hooked
local function hook()
    if hooked or not WorldMapFrame then return end
    hooked = true
    WorldMapFrame:HookScript("OnShow", onMap)
    WorldMapFrame:HookScript("OnHide", function() if panel and panel.docked then panel:Hide() end end)
end
WK:On("PLAYER_LOGIN", hook)
WK:On("ADDON_LOADED", function(name) if name == "Blizzard_WorldMap" then hook() end end)
D.OnChange = function()
    if panel and panel:IsShown() then panel:Refresh() end
    if UI.RefreshDungeonWorldMap then UI.RefreshDungeonWorldMap() end
end
WK:On("GET_ITEM_INFO_RECEIVED", function()
    if panel and panel:IsShown() and not panel.pending then
        panel.pending = true
        C_Timer.After(0.5, function() panel.pending = nil; if panel:IsShown() then panel:Refresh() end end)
    end
end)
