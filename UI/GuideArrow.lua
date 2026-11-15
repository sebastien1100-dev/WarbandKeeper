local ADDON_NAME, WK = ...
local UI = WK.UI
local C = UI.colors
local T = function(s) return WK.T(s) end

-- Flèche de guidage (Modules/Guide.lua) : petit cadre déplaçable en haut de l'écran, flèche
-- tournée vers le lieu visé, nom du lieu et distance. Clic droit ou croix : arrêter.
local frame
local refresh

local function build()
    local f = CreateFrame("Frame", "WarbandKeeperGuideArrow", UIParent)
    f:SetSize(180, 96)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s) if not UI.editing then s:StartMoving() end end)
    f:SetScript("OnDragStop", function(s) s:StopMovingOrSizing(); UI:HUDCapture("arrow") end)
    f:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then WK.modules.Guide:Stop() end end)
    f.arrow = f:CreateTexture(nil, "ARTWORK")
    f.arrow:SetTexture(UI.MEDIA .. "guide")
    f.arrow:SetSize(40, 40)
    f.arrow:SetPoint("TOP", 0, -6)
    -- ligne 1 : le nom ; ligne 2 : le rôle et la distance dans une pastille à la couleur du thème
    f.name = UI:Text(f, 13, C.text)
    f.name:SetPoint("TOP", f.arrow, "BOTTOM", 0, -3)
    f.name:SetJustifyH("CENTER")
    f.line2 = CreateFrame("Frame", nil, f)
    f.line2:SetSize(100, 16)
    f.line2:SetPoint("TOP", f.name, "BOTTOM", 0, -4)
    f.role = UI:Text(f.line2, 11, C.muted)
    f.role:SetPoint("LEFT", 0, 0)
    f.pill = CreateFrame("Frame", nil, f.line2)
    f.pill:SetHeight(16)
    f.pill.bg = UI:Rounded(f.pill, 8, 0, "BACKGROUND", 2)
    f.dist = UI:Text(f.pill, 11)
    f.dist:SetPoint("CENTER", 0, 0)
    f.dist:SetJustifyH("CENTER")
    -- pose la distance (ou un état) dans la pastille et recentre la ligne 2
    function f:SetDist(text, col)
        local r, g, b = UI:Accent()
        col = col or { r, g, b }
        self.dist:SetText(text)
        self.dist:SetTextColor(C.bg[1], C.bg[2], C.bg[3], 1)
        self.pill.bg:SetColor(col[1], col[2], col[3], 1)
        local pw = (self.dist:GetStringWidth() or 20) + 12
        self.pill:SetWidth(pw)
        local rw = (self.role:GetText() or "") ~= "" and (self.role:GetStringWidth() or 0) + 6 or 0
        self.pill:ClearAllPoints()
        self.pill:SetPoint("LEFT", self.line2, "LEFT", rw, 0)
        self.line2:SetWidth(rw + pw)
        local w = math.max(150, (self.name:GetStringWidth() or 0) + 36, rw + pw + 36)
        if math.abs((self:GetWidth() or 0) - w) > 1 then self:SetWidth(w) end
    end
    f.close = UI:IconButton(f, "close", 16, nil, "accent")
    f.close:SetPoint("TOPRIGHT", -2, -2)
    f.close:SetScript("OnClick", function() WK.modules.Guide:Stop() end)
    f:SetScript("OnEnter", function(s)
        WK.UI:TooltipOwner(s, "ANCHOR_BOTTOM")
        local t = WK.modules.Guide.target
        GameTooltip:SetText(T("Guidage Warband Keeper"), 1, 1, 1)
        if t and t.reason then GameTooltip:AddLine(T(t.reason), 0.8, 0.8, 0.8) end
        GameTooltip:AddLine(T("Glisser pour déplacer · clic droit pour arrêter"), 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.elapsed = 0
    f:SetScript("OnUpdate", function(s, el)
        s.elapsed = s.elapsed + el
        if s.elapsed < 0.05 then return end
        s.elapsed = 0
        if s.sample then return end
        local G = WK.modules.Guide
        local t = G.target
        if not t then s:Hide() return end
        local p = G:PlayerPos()
        local d, bearing = nil, nil
        if p then d, bearing = G:Vector(p, t) end
        if not d then
            s.arrow:SetRotation(0)
            s.arrow:SetVertexColor(unpack(C.dim))
            s:SetDist(T("Autre zone : ouvre la carte"), C.dim)
            return
        end
        if d < 8 then
            s.arrow:SetRotation(0)
            s.arrow:SetVertexColor(unpack(C.positive))
            s:SetDist(T("Arrivé"), C.positive)
            return
        end
        local facing = GetPlayerFacing and GetPlayerFacing() or 0
        s.arrow:SetRotation(bearing - (facing or 0))
        -- couleur : de l'accent (loin) au vert (tout près)
        local r, g, b = UI:Accent()
        local k = math.max(0, math.min(1, 1 - d / 300))
        local pc = C.positive
        s.arrow:SetVertexColor(r + (pc[1] - r) * k, g + (pc[2] - g) * k, b + (pc[3] - b) * k)
        s:SetDist(string.format(T("%d m"), math.floor(d)))
    end)
    UI:Panel(f, 12, { C.bg[1], C.bg[2], C.bg[3], 0.82 }, C.border)
    f:Hide()
    UI:RegisterHUD("arrow", f, {
        label = T("Flèche de guidage"),
        default = { 0, UIParent:GetHeight() / 2 - 172 },
        legacy = function()
            local pos = WK.modules.Guide:Config().point -- position des versions précédentes
            if not pos then return false end
            f:ClearAllPoints()
            f:SetPoint(pos[1], UIParent, pos[1], pos[2], pos[3])
            return true
        end,
        sample = function(on)
            f.sample = on or nil
            if on then
                f.name:SetText(T("Exemple : banque"))
                f.role:SetText(T("Banquier"))
                f:SetDist(string.format(T("%d m"), 120))
                f.arrow:SetRotation(0.6)
                f.arrow:SetVertexColor(UI:Accent())
                f:Show()
            else
                refresh()
            end
        end,
    })
    return f
end

refresh = function()
    local G = WK.modules.Guide
    local t = G.target
    if not t or not G:Config().arrow then
        if frame then frame:Hide() end
        return
    end
    frame = frame or build()
    local name, role = G:PlaceParts(t)
    frame.name:SetText(name)
    frame.role:SetText(role or "")
    frame:SetDist(frame.dist:GetText() or "")
    frame:Show()
end

WK.modules.Guide.OnTarget = function() refresh() end

-- La flèche existe dès la connexion (cachée), pour pouvoir la placer en mode édition.
WK:On("PLAYER_LOGIN", function() frame = frame or build() end)
