-- Options tab: what counts, how far ahead, lore weight, display, and the PvP preset.
local _, LW = ...
local L = LW.L
local UI = LW.UI

local tab = { key = "options", label = L["Options"], widgets = {} }

local DEFER = { [0] = "+0", [1] = L["+1 (yellow)"], [2] = L["+2 (yellow)"], [3] = L["orange (+3)"], [4] = L["orange (+4)"], [5] = L["red (+5)"], [6] = "+6", [7] = "+7", [8] = "+8", [9] = "+9" }
local LORE = { [0] = "off", [1] = "light", [2] = "normal", [3] = L["lore first"] }

local function changed() LW:RequestRefresh("options") end

function tab:Build(panel)
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -26, 0)
  local c = CreateFrame("Frame", nil, scroll)
  c:SetSize(640, 900)
  scroll:SetScrollChild(c)

  local y = -4
  local function header(text)
    local fs = c:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", 4, y)
    fs:SetText(text)
    y = y - 26
  end
  local function place(w, x)
    w:SetPoint("TOPLEFT", x or 8, y)
    table.insert(self.widgets, w)
    y = y - 26
  end

  header(L["What counts toward \"everything\""])
  for _, cat in ipairs(LW.Categories.order) do
    place(UI.Check(c, LW.Categories.labels[cat],
      function() return LW.db.categories[cat] end,
      function(v) LW.db.categories[cat] = v; changed() end))
  end

  y = y - 8
  header(L["Level band"])
  place(UI.Stepper(c, L["Do quests up to this many levels above you (higher ones wait in Later)"], 0, 9,
    function() return LW.db.maxAbove end, function(v) LW.db.maxAbove = v; changed() end,
    function(v) return DEFER[v] or ("+" .. v) end))
  place(UI.Stepper(c, L["Dungeon quests up to this many levels above you"], 0, 10,
    function() return LW.db.dungeonRange end, function(v) LW.db.dungeonRange = v; changed() end,
    function(v) return "+" .. v end))

  y = y - 8
  header(L["Lore"])
  place(UI.Stepper(c, L["Story priority"], 0, 3,
    function() return LW.db.loreWeight end, function(v) LW.db.loreWeight = v; LW.Router:Route() end,
    function(v) return LORE[v] end))

  y = y - 8
  header(L["Travel"])
  place(UI.Check(c, L["Use flight paths, boats and the tram when choosing the next step"],
    function() return LW.db.useTravel end, function(v) LW.db.useTravel = v; LW.Router:Route() end))

  place(UI.Check(c, L["Plan the trip ahead (up to 16 steps) instead of one step at a time"],
    function() return LW.db.usePlanner end, function(v) LW.db.usePlanner = v; LW.Router:Route(); LW.Planner:Request() end))

  y = y - 8
  header(L["Display"])
  place(UI.Check(c, L["Show the step panel"], function() return LW.db.showStep end,
    function(v) LW.db.showStep = v; if v then LW.StepFrame.frame:Show() else LW.StepFrame.frame:Hide() end end))
  place(UI.Check(c, L["Show notifications at the top of the screen when Loreseeker decides something on its own"],
    function() return LW.db.notify end, function(v) LW.db.notify = v end))
  place(UI.Check(c, L["Show the waypoint arrow"], function() return LW.db.showArrow end,
    function(v) LW.db.showArrow = v; if v and LW.Arrow.point then LW.Arrow.frame:Show() else LW.Arrow.frame:Hide() end end))

  y = y - 8
  header(L["PvP server: skip contested zones"])
  local note = c:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  note:SetPoint("TOPLEFT", 8, y)
  note:SetWidth(600)
  note:SetJustifyH("LEFT")
  note:SetText(L["Ticked zones are skipped entirely; their quests wait in the Revisit tab. For part of a zone, stand there and use Skip... > Skip the area around me."])
  y = y - 30
  local col = 0
  for _, z in ipairs(LW.Skips.contested) do
    local area, name = z[1], (C_Map.GetAreaInfo and C_Map.GetAreaInfo(z[1])) or z[2]
    local w = UI.Check(c, name, function() return LW.db.pvpZones[area] end,
      function(v)
        LW.db.pvpZones[area] = v or nil
        changed()
        LW:Fire("SKIPS_CHANGED")
      end)
    w:SetPoint("TOPLEFT", 8 + col * 210, y)
    table.insert(self.widgets, w)
    col = col + 1
    if col == 3 then col = 0; y = y - 26 end
  end
  if col > 0 then y = y - 26 end
  c:SetHeight(-y + 20)
end

function tab:Refresh()
  for _, w in ipairs(self.widgets) do if w.Refresh then w:Refresh() end end
end

LW.Main:AddTab(tab)
