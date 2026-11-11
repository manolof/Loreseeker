-- Guide tab: the current step, what comes after it, and group-up (dungeon) work.
local _, LW = ...
local L = LW.L
local UI = LW.UI

local tab = { key = "guide", label = L["Guide"] }

local function taskItem(t, indent)
  local where = "?"
  if t.point then
    -- nearby: yards; further away: travel time by the fastest way you have
    local far = t.travel and t.travel > 90
    where = LW.MapName(t.point.map) .. ((far and (" - " .. LW.Travel.FormatTime(t.travel)))
      or (t.dist and " - " .. string.format(L["%d yd"], t.dist)) or "")
  end
  local story = LW.Storylines:For(t.quest)
  return {
    icon = UI.ICONS[t.kind] or UI.ICONS.generic,
    indent = indent,
    text = (story and "|TInterface\\Icons\\INV_Misc_Book_09:12|t " or "") .. t.text .. ": " .. UI.QuestLabel(t.quest),
    right = where,
    tooltip = UI.Lines(t.quest.name, t.target and t.target ~= "" and string.format(L["Target: %s"], t.target), t.detail,
      story and string.format(L["Story: %s"], L[story.name]), L["Click: open its storyline. Right-click: do next / skip."]),
    onClick = function(item, mouse)
      if mouse == "RightButton" then
        UI.SkipMenu(LW.Main.frame, t, {
          { text = L["Do this next"], func = function() LW.Router:Pin(t) end },
          { text = L["Open storyline"], func = function() LW.Main:ShowStory(t.quest.id) end },
        })
      else
        LW.Main:ShowStory(t.quest.id)
      end
    end,
    button = { text = L["Skip..."], onClick = function() UI.SkipMenu(LW.Main.frame, t) end },
  }
end

function tab:Build(panel)
  self.list = UI.List(panel)
  self.list.scroll:SetPoint("TOPLEFT", 0, 0)
  self.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
end

function tab:Refresh()
  local items = {}
  local cur = LW.Router:Current()
  items[#items + 1] = { header = true, text = L["Next step"] }
  if cur then items[#items + 1] = taskItem(cur, 1)
  else items[#items + 1] = { indent = 1, dim = true, text = L["Nothing routable right now."] } end

  -- The plan, as stops: everything to do in one place is listed together.
  local stops = LW.db.usePlanner and LW.Router.planned and LW.Planner:Stops() or {}
  if #stops > 0 then
    local total = #LW.Planner.plan
    items[#items + 1] = { header = true, text = string.format(L["Your trip: %d steps in %d stops"], total, #stops) }
    for i, stop in ipairs(stops) do
      local label = (i == 1 and string.format(L["Here / first stop: %s"], LW.MapName(stop.map))
        or string.format(L["Stop %d: %s"], i, LW.MapName(stop.map)))
      local n = #stop.steps
      items[#items + 1] = { indent = 1, header = true, text = label,
        right = (n > 1 and (string.format(L["%d things to do"], n) .. "  -  ") or "") .. (stop.travel and LW.Travel.FormatTime(stop.travel) or "") }
      for _, step in ipairs(stop.steps) do
        local t = step.task
        local story = LW.Storylines:For(t.quest)
        items[#items + 1] = {
          icon = UI.ICONS[t.kind] or UI.ICONS.generic, indent = 2, dim = step.preview and true or false,
          text = (story and "|TInterface\\Icons\\INV_Misc_Book_09:12|t " or "") .. t.text .. ": " .. UI.QuestLabel(t.quest),
          right = step.preview and L["once you have the quest"] or "",
          tooltip = UI.Lines(t.quest.name, t.target and t.target ~= "" and string.format(L["Target: %s"], t.target),
            story and string.format(L["Story: %s"], L[story.name]), L["Click: open its storyline. Right-click: do next / skip."]),
          onClick = function(_, mouse)
            if mouse == "RightButton" and not step.preview then
              UI.SkipMenu(LW.Main.frame, t, {
                { text = L["Do this next"], func = function() LW.Router:Pin(t) end },
                { text = L["Open storyline"], func = function() LW.Main:ShowStory(t.quest.id) end },
              })
            else
              LW.Main:ShowStory(t.quest.id)
            end
          end,
        }
      end
    end
    items[#items + 1] = { header = true, text = L["Other things nearby"] }
    local inPlan = {}
    for _, step in ipairs(LW.Planner.plan) do inPlan[step.key] = true end
    local shown = 0
    for _, t in ipairs(LW.Router.ranked) do
      if not inPlan[t.key] and t ~= cur then
        items[#items + 1] = taskItem(t, 1)
        shown = shown + 1
        if shown >= 8 then break end
      end
    end
  else
    items[#items + 1] = { header = true, text = L["Coming up"] }
    for _, t in ipairs(LW.Router:Upcoming(12)) do items[#items + 1] = taskItem(t, 1) end
  end

  -- Group-up work, per dungeon.
  local groups = {}
  for area, g in pairs(LW.Tasks.groups) do groups[#groups + 1] = g end
  table.sort(groups, function(a, b) return LW.ZoneName(a.area) < LW.ZoneName(b.area) end)
  if #groups > 0 then
    items[#items + 1] = { header = true, text = L["Group up (dungeon quests ready)"] }
    for _, g in ipairs(groups) do
      local n = 0
      for _ in pairs(g.quests) do n = n + 1 end
      local names = {}
      for id in pairs(g.quests) do names[#names + 1] = LW.Index:Get(id).name end
      table.sort(names)
      table.insert(names, 1, LW.ZoneName(g.area))
      names[#names + 1] = L["Click 'Route' to add these to your main route (for when you have a group)."]
      items[#items + 1] = {
        icon = UI.ICONS.dungeon, indent = 1,
        text = LW.ZoneName(g.area), right = string.format(n == 1 and L["%d quest"] or L["%d quests"], n),
        tooltip = names,
        button = { text = L["Route"], onClick = function()
          LW.char.pinned[g.area] = true
          LW:RequestRefresh("pin dungeon")
        end },
      }
    end
  end
  local pinned = {}
  for area in pairs(LW.char.pinned) do pinned[#pinned + 1] = area end
  if #pinned > 0 then
    items[#items + 1] = { header = true, text = L["Dungeons on your route"] }
    for _, area in ipairs(pinned) do
      items[#items + 1] = { icon = UI.ICONS.dungeon, indent = 1, text = LW.ZoneName(area),
        button = { text = L["Unroute"], onClick = function()
          LW.char.pinned[area] = nil
          LW:RequestRefresh("unpin dungeon")
        end } }
    end
  end

  if #LW.Tasks.blocked > 0 then
    items[#items + 1] = { header = true, text = string.format(L["Blocked by your skips (%d)"], #LW.Tasks.blocked) }
    for i = 1, math.min(8, #LW.Tasks.blocked) do
      local t = LW.Tasks.blocked[i]
      items[#items + 1] = { icon = UI.ICONS.skip, indent = 1, dim = true,
        text = t.text .. ": " .. t.quest.name, right = LW.Skips:Describe(t.points.skippedBy) }
    end
  end
  self.list:SetItems(items)
end

LW.Main:AddTab(tab)
