local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Repère de navigation à l'écran (style « épingle ») : au-dessus du lieu guidé, une épingle de la
-- couleur d'accent avec l'icône de ce qu'on suit, et dessous le nom et la distance restante (par le
-- trajet de Modules/Nav.lua s'il y en a un). Le jeu place un repère sur le point suivi
-- (C_Map.SetUserWaypoint + C_SuperTrack) et donne sa position à l'écran (C_Navigation.GetFrame) :
-- l'épingle s'y accroche et le repère d'origine du jeu est rendu invisible pendant ce temps.
-- Arrivée (moins de 10 m) : bandeau « Arrivé », son au choix, et le guidage s'arrête.
local G = WK.modules.Guide
local pin, banner
local hiddenGame = false

local KIND_ICON = {
    mail = "mail", bank = "coin", repair = "hammer", vendor = "bag", ammo = "bag", reagent = "bag", bags = "bag",
    trainer = "book", stable = "person", fishing = "fish", quest = "bang", rare = "skull", place = "map", way = "star",
}
local function iconFor(t)
    return KIND_ICON[t.kind or ""] or "guide"
end
-- icône du lieu guidé (épingle à l'écran et sur la carte du monde, UI/MapPins.lua)
function UI:GuideIcon(t) return iconFor(t) end
-- distance restante : par le trajet s'il y en a un, sinon à vol d'oiseau
function UI:GuideDistance(t)
    local p = G:PlayerPos()
    local d = p and G:Vector(p, t)
    local _, _, _, rest = WK.modules.Nav:Waypoint()
    return rest or d, p
end

local function showGameMarker(show)
    if not SuperTrackedFrame then return end
    if show and hiddenGame then
        SuperTrackedFrame:SetAlpha(1); hiddenGame = false
    elseif not show and not hiddenGame then
        SuperTrackedFrame:SetAlpha(0); hiddenGame = true
    end
end

local function navFrame()
    local N = C_Navigation
    if not (N and N.GetFrame) then return nil end
    local ok, f = pcall(N.GetFrame)
    if not ok or not f then return nil end
    local okv, valid = pcall(N.HasValidScreenPosition)
    if okv and valid == false then return nil end
    local okc, clamped = pcall(N.WasClampedToScreen)
    return f, okc and clamped
end

---------------------------------------------------------------------------
-- Bandeau d'arrivée
---------------------------------------------------------------------------
local function showBanner(name)
    if not banner then
        banner = CreateFrame("Frame", "WarbandKeeperArrival", UIParent)
        banner:SetSize(320, 36)
        banner:SetPoint("TOP", 0, -150)
        banner:SetFrameStrata("HIGH")
        banner.edge = UI:Rounded(banner, 18, 0, "BACKGROUND", 0)
        banner.bg = UI:Rounded(banner, 17, 1.5, "BACKGROUND", 1)
        banner.text = UI:Text(banner, 13)
        banner.text:SetPoint("CENTER")
        banner:SetScript("OnUpdate", function(s)
            local left = (s.until_ or 0) - GetTime()
            if left <= 0 then s:Hide() return end
            s:SetAlpha(math.min(1, left / 0.6))
        end)
    end
    local r, g, b = UI:Accent()
    local hex = WK:AccentHex()
    banner.edge:SetColor(r, g, b, 1)
    banner.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.94)
    banner.text:SetText(T("Arrivé") .. " : |cff" .. hex .. name .. "|r  ·  " .. T("le guidage s'arrête"))
    banner:SetWidth((banner.text:GetStringWidth() or 200) + 40)
    banner.until_ = GetTime() + 3.5
    banner:SetAlpha(1)
    banner:Show()
end

local arrivedFor
local function arrive(t)
    if arrivedFor == t then return end
    -- point /way avec d'autres points derrière : la file passe seule au suivant (ni bandeau ni son ni arrêt)
    local W = WK.modules.Waypoints
    if t.kind == "way" and W and W.List and #W:List() > 1 then return end
    arrivedFor = t
    local cfg = G:Config()
    showBanner(G:PlaceName(t))
    if cfg.arriveSound ~= false and PlaySound then
        local kit = SOUNDKIT and (SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON or SOUNDKIT.MAP_PING)
        pcall(PlaySound, kit or 3175)
    end
    -- point /way : la file s'arrête elle-même (Waypoints), ce n'est pas un arrêt à la main
    if t.kind == "way" then return end
    C_Timer.After(0.8, function() if G.target == t then G:Stop() end end)
end

---------------------------------------------------------------------------
-- Épingle
---------------------------------------------------------------------------
local function build()
    local f = CreateFrame("Frame", "WarbandKeeperNavPin", UIParent)
    f:SetSize(34, 34)
    f:SetFrameStrata("BACKGROUND")
    f.shadow = f:CreateTexture(nil, "BACKGROUND")
    f.shadow:SetTexture(UI.MEDIA .. "pin")
    f.shadow:SetPoint("CENTER", 1, -2)
    f.shadow:SetSize(36, 36)
    f.shadow:SetVertexColor(0, 0, 0, 0.45)
    f.body = f:CreateTexture(nil, "ARTWORK")
    f.body:SetTexture(UI.MEDIA .. "pin")
    f.body:SetAllPoints()
    f.icon = f:CreateTexture(nil, "OVERLAY")
    f.icon:SetSize(15, 15)
    f.icon:SetPoint("CENTER", f, "TOP", 0, -13)
    -- étiquette compacte sur trois lignes : nom, rôle, distance
    f.pill = CreateFrame("Frame", nil, f)
    f.pill:SetPoint("TOP", f, "BOTTOM", 0, -3)
    f.pill.bg = UI:Rounded(f.pill, 8, 0, "BACKGROUND", 1)
    f.name = UI:Text(f.pill, 12)
    f.name:SetPoint("TOP", 0, -5)
    f.role = UI:Text(f.pill, 10, C.muted)
    f.role:SetPoint("TOP", f.name, "BOTTOM", 0, -2)
    f.dist = UI:Text(f.pill, 12)
    f.extra = UI:Text(f.pill, 10, C.dim)   -- retour au corps : ce que coûte l'ange gardien
    -- au bord de l'écran : petite flèche tournée vers le lieu
    f.edge = f:CreateTexture(nil, "OVERLAY")
    f.edge:SetTexture(UI.MEDIA .. "guide")
    f.edge:SetSize(18, 18)
    f:Hide()
    return f
end

-- Place l'épingle au bord de l'écran, dans la direction du lieu (le jeu ne donne pas de position
-- à l'écran quand le lieu est derrière toi)
local function placeAtEdge(f, t, p)
    local _, bearing = G:Vector(p, t)
    if not bearing then return false end
    local facing = GetPlayerFacing and GetPlayerFacing() or 0
    local rel = bearing - (facing or 0) -- 0 : devant ; positif : vers la gauche
    local dx, dy = -math.sin(rel), math.cos(rel)
    local W, H = UIParent:GetWidth(), UIParent:GetHeight()
    local hx, hy = W / 2 - 60, H / 2 - 90
    local k = math.min(hx / math.max(math.abs(dx), 0.001), hy / math.max(math.abs(dy), 0.001))
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", dx * k, dy * k)
    f.edge:ClearAllPoints()
    f.edge:SetPoint("CENTER", f, "CENTER", dx * 30, dy * 30)
    f.edge:SetRotation(rel)
    return true
end

-- Boucle (cadre toujours actif pendant le guidage : l'épingle peut être cachée sans l'arrêter)
local function update()
    local t = G.target
    -- distance : par le trajet si on l'a, sinon à vol d'oiseau ; l'arrivée (moins de 10 m) arrête le guidage
    -- même quand l'épingle à l'écran est coupée
    local d, p
    if t then
        d, p = UI:GuideDistance(t)
        if d and d < 10 and p and t.map then arrive(t); t = G.target end
    end
    if not t or not G:Config().screenPin then
        if pin then pin:Hide() end
        showGameMarker(true)
        return
    end
    pin = pin or build()
    local f = pin
    local nf, clamped = navFrame()
    showGameMarker(false)
    local atEdge = false
    if nf and not clamped then
        f:ClearAllPoints()
        f:SetPoint("BOTTOM", nf, "CENTER", 0, 0)
    elseif p and placeAtEdge(f, t, p) then
        atEdge = true
    else
        f:Hide()
        return
    end
    local r, g, b = UI:Accent()
    -- retour au corps : tête de mort rouge à la place de l'épingle, conseil, temps du trajet et coût de l'ange
    local corpse = t.kind == "corpse"
    if f.corpse ~= corpse then
        f.corpse = corpse
        f.body:SetTexture(UI.MEDIA .. (corpse and "skull" or "pin"))
        f.shadow:SetTexture(UI.MEDIA .. (corpse and "skull" or "pin"))
        f.icon:SetShown(not corpse)
        f.key = nil
    end
    if corpse then r, g, b = C.negative[1], C.negative[2], C.negative[3] end
    f.body:SetVertexColor(r, g, b, 1)
    f.edge:SetVertexColor(r, g, b, 1)
    f.edge:SetShown(atEdge)
    f.icon:SetTexture(UI.MEDIA .. iconFor(t))
    f.icon:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
    local name, role = G:PlaceParts(t)
    local dist = d and string.format(T("%d m"), math.floor(d)) or ""
    local extra = ""
    if corpse and d then
        local info = UI.CorpsePinInfo and UI:CorpsePinInfo(d)
        if info then
            role = info.advice
            dist = dist .. "  ·  " .. T("env.") .. " " .. info.time
            extra = info.cost or ""
        end
    end
    local key = (atEdge and "e" or "n") .. name .. (role or "") .. dist .. extra
    if f.key ~= key then
        f.key = key
        f.name:SetText(name)
        f.role:SetText(role or "")
        f.dist:SetText(dist)
        f.dist:SetTextColor(r, g, b, 1)
        f.extra:SetText(extra)
        f.extra:ClearAllPoints(); f.extra:SetPoint("TOP", f.dist, "BOTTOM", 0, -2)
        f.extra:SetShown(not atEdge and extra ~= "")
        f.name:SetShown(not atEdge)
        f.role:SetShown(not atEdge and (role or "") ~= "")
        f.dist:ClearAllPoints()
        local h
        if atEdge then
            f.dist:SetPoint("TOP", 0, -4)
            h = 20
        else
            local above = (role or "") ~= "" and f.role or f.name
            f.dist:SetPoint("TOP", above, "BOTTOM", 0, -2)
            h = 10 + (f.name:GetStringHeight() or 12) + ((role or "") ~= "" and (f.role:GetStringHeight() or 10) + 2 or 0) + (f.dist:GetStringHeight() or 12) + 2
                + (extra ~= "" and (f.extra:GetStringHeight() or 10) + 2 or 0)
        end
        local w = math.max(atEdge and 0 or (f.name:GetStringWidth() or 0), atEdge and 0 or (f.role:GetStringWidth() or 0),
            atEdge and 0 or (extra ~= "" and f.extra:GetStringWidth() or 0), f.dist:GetStringWidth() or 0) + 16
        f.pill:SetSize(w, h)
    end
    f.pill.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.82)
    f:SetAlpha(atEdge and 0.75 or 1)
    f:Show()
end
local driver = CreateFrame("Frame")
driver.acc = 0
driver:SetScript("OnUpdate", function(s, el)
    s.acc = s.acc + el
    if s.acc < 0.03 then return end
    s.acc = 0
    if G.target or (pin and pin:IsShown()) or hiddenGame then update() end
end)

local function sync()
    if G.target and G:Config().screenPin then
        update()
    elseif pin then
        pin:Hide()
        showGameMarker(true)
    else
        showGameMarker(true)
    end
    if not G.target then arrivedFor = nil end
end

-- Guide.OnTarget sert déjà à la flèche (UI/GuideArrow.lua) : on s'y ajoute
local prev = G.OnTarget
G.OnTarget = function(...)
    if prev then prev(...) end
    sync()
end
UI.SyncNavPin = sync
