-- Waypoint arrow (stock minimap arrow art) plus the native map pin via C_Map.SetUserWaypoint.
local _, LW = ...

local AR = {}
LW.Arrow = AR

local HBD = LibStub and LibStub("HereBeDragons-2.0", true)
local ARRIVED_YARDS = 10

function AR:Create()
  local f = CreateFrame("Button", "LorewalkerArrow", UIParent)
  f:SetSize(64, 80)
  f:SetFrameStrata("MEDIUM")
  LW.UI.MakeMovable(f, "arrow")
  LW.UI.RestorePosition(f, "arrow", "TOP", UIParent, "TOP", 0, -160)

  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetTexture("Interface\\Minimap\\MinimapArrow")
  f.tex:SetSize(48, 48)
  f.tex:SetPoint("TOP")

  f.dist = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.dist:SetPoint("TOP", f.tex, "BOTTOM", 0, 2)
  f.label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.label:SetPoint("TOP", f.dist, "BOTTOM", 0, -1)
  f.label:SetWidth(220)

  f:SetScript("OnEnter", function(self)
    if not AR.point then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(AR.title or "Lorewalker")
    GameTooltip:AddLine(string.format("%s %.1f, %.1f", LW.MapName(AR.point.map), AR.point.x * 100, AR.point.y * 100), 1, 1, 1)
    GameTooltip:AddLine("Drag to move.", 0.6, 0.6, 0.6)
    GameTooltip:Show()
  end)
  f:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local elapsed = 0
  f:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.05 then return end
    elapsed = 0
    AR:Update()
  end)
  self.frame = f
  f:Hide()
end

function AR:SetTarget(point, title)
  if point == self.point then return end
  self.point, self.title = point, title
  if not self.frame then return end
  if point and LW.db.showArrow then self.frame:Show() else self.frame:Hide() end
  -- native map pin
  if point and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(point.map) then
      local ok = pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(point.map, point.x, point.y))
      if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
      end
    end
  end
end

-- Runs 20 times a second: only touch a font string when its text actually changes.
local shownDist, shownLabel
local function setDist(f, text)
  if text ~= shownDist then shownDist = text; f.dist:SetText(text) end
end

function AR:Update()
  local f, p = self.frame, self.point
  if not p then return end
  if self.title ~= shownLabel then shownLabel = self.title; f.label:SetText(self.title or "") end
  local px, py, pinst = nil, nil, nil
  if HBD then px, py, pinst = HBD:GetPlayerWorldPosition() end
  local wx, wy, inst = p.wx, p.wy, p.inst
  if wx == nil and HBD then wx, wy, inst = HBD:GetWorldCoordinatesFromZone(p.x, p.y, p.map) end
  if not (px and wx) or inst ~= pinst then
    f.tex:SetRotation(0)
    f.tex:SetVertexColor(0.6, 0.6, 0.6)
    setDist(f, "Travel to " .. LW.MapName(p.map))
    return
  end
  local angle, dist = HBD:GetWorldVector(pinst, px, py, wx, wy)
  local facing = GetPlayerFacing and GetPlayerFacing()
  if not angle or not facing then
    setDist(f, dist and (math.floor(dist) .. " yd") or "")
    return
  end
  f.tex:SetVertexColor(1, 1, 1)
  f.tex:SetRotation(angle - facing)
  if dist < ARRIVED_YARDS then
    setDist(f, "You're here")
  else
    setDist(f, math.floor(dist) .. " yd")
  end
end
