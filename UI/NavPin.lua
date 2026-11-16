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
    trainer = "book", stable = "person", fishing = "fish", quest = "bang", rare = "star", place = "map",
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
    arrivedFor = t
    local cfg = G:Config()
    showBanner(G:PlaceName(t))
    if cfg.arriveSound ~= false and PlaySound then
        local kit = SOUNDKIT and (SOUNDKIT.UI_MAP_WAYPOINT_SUPER_TRACK_ON or SOUNDKIT.MAP_PING)
        pcall(PlaySound, kit or 3175)
    end
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
    f.pill = CreateFrame("Frame", nil, f)
    f.pill:SetHeight(20)
    f.pill:SetPoint("TOP", f, "BOTTOM", 0, -3)
    f.pill.bg = UI:Rounded(f.pill, 10, 0, "BACKGROUND", 1)
    f.label = UI:Text(f.pill, 12)
    f.label:SetPoint("CENTER")
    f:Hide()
    f.acc = 0
    f:SetScript("OnUpdate", function(s, el)
        s.acc = s.acc + el
        if s.acc < 0.03 then return end
        s.acc = 0
        local t = G.target
        if not t or not G:Config().screenPin then s:Hide(); showGameMarker(true) return end
        -- distance : par le trajet si on l'a, sinon à vol d'oiseau
        local d, p = UI:GuideDistance(t)
        if d and d < 10 and p and t.map then arrive(t) end
        local nf, clamped = navFrame()
        if not nf then s:Hide(); return end
        showGameMarker(false)
        s:ClearAllPoints()
        s:SetPoint("BOTTOM", nf, "CENTER", 0, 0)
        local r, g, b = UI:Accent()
        s.body:SetVertexColor(r, g, b, 1)
        s.icon:SetTexture(UI.MEDIA .. iconFor(t))
        s.icon:SetVertexColor(C.bg[1], C.bg[2], C.bg[3], 1)
        local hex = WK:AccentHex()
        local txt = G:PlaceName(t) .. (d and ("  ·  |cff" .. hex .. string.format(T("%d m"), math.floor(d)) .. "|r") or "")
        if s.label:GetText() ~= txt then
            s.label:SetText(txt)
            s.pill:SetWidth((s.label:GetStringWidth() or 60) + 20)
        end
        s.pill.bg:SetColor(C.bg[1], C.bg[2], C.bg[3], 0.82)
        -- au bord de l'écran (lieu derrière toi ou hors champ) : plus discret
        s:SetAlpha(clamped and 0.6 or 1)
        s.pill:SetShown(not clamped)
        s:Show()
    end)
    return f
end

local function sync()
    if G.target and G:Config().screenPin then
        pin = pin or build()
        pin:Show() -- l'OnUpdate décide ensuite (repère du jeu disponible ou non)
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
