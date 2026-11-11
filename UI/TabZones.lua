-- Zones tab: Loremaster-style progress per zone. Click a zone to see its quests.
local _, LW = ...
local L = LW.L
local UI = LW.UI

local tab = { key = "zones", label = L["Zones"], open = {} }

local ORDER = { active = 1, now = 2, group = 3, later = 4, skipped = 5, locked = 6, done = 7, excluded = 8 }

function tab:Build(panel)
  self.list = UI.List(panel)
  self.list.scroll:SetPoint("TOPLEFT", 0, 0)
  self.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
end

function tab:Refresh()
  local zones = {}
  local doneAll, totalAll = 0, 0
  for _, z in pairs(LW.Eligibility:ZoneProgress()) do
    z.name = LW.ZoneName(z.zone)
    zones[#zones + 1] = z
    doneAll, totalAll = doneAll + z.done, totalAll + z.total
  end
  table.sort(zones, function(a, b) return a.name < b.name end)

  local items = {
    { header = true, text = string.format(L["All zones: %d of %d quests (%d%%)"], doneAll, totalAll,
      totalAll > 0 and math.floor(doneAll * 100 / totalAll) or 0), bar = { doneAll, totalAll } },
  }
  for _, z in ipairs(zones) do
    local zone = z.zone
    items[#items + 1] = {
      icon = LW.Adapter:IsDungeonZone(zone) and UI.ICONS.dungeon or UI.ICONS.zone,
      text = string.format(L["%s  |cffffffff%d/%d|r"], z.name, z.done, z.total),
      right = string.format(L["%d avail - %d later - %d skipped"], z.now + z.active, z.later, z.skipped),
      bar = { z.done, z.total },
      onClick = function() tab.open[zone] = not tab.open[zone]; tab:Refresh() end,
      button = { text = L["Skip..."], onClick = function()
        LW.Skips:Prompt(string.format(L["Skip the zone %s"], z.name), function(n, l) LW.Skips:AddZone(zone, n, l) end)
      end },
    }
    if self.open[zone] then
      local quests = {}
      for _, e in ipairs(LW.Index.list) do
        local s = LW.Eligibility:Status(e.id)
        if e.zone == zone and s and s ~= "off" then quests[#quests + 1] = { e = e, s = s } end
      end
      table.sort(quests, function(a, b)
        local oa, ob = ORDER[a.s] or 9, ORDER[b.s] or 9
        if oa ~= ob then return oa < ob end
        return a.e.level < b.e.level
      end)
      for _, q in ipairs(quests) do
        local story = LW.Storylines:For(q.e)
        items[#items + 1] = {
          indent = 1, icon = UI.STATUS_ICON[q.s], dim = q.s == "done" or q.s == "locked",
          text = (story and "|TInterface\\Icons\\INV_Misc_Book_09:12|t " or "") .. UI.QuestLabel(q.e),
          right = UI.STATUS_LABEL[q.s],
          tooltip = UI.Lines(q.e.name, string.format(L["Category: %s"], L[LW.Categories.labels[q.e.cat] or q.e.cat]), story and string.format(L["Story: %s"], LW.StorylineName(story)),
            string.format(L["Requires level %d"], q.e.req or 0), UI.STORY_HINT),
          onClick = function() LW.Main:ShowStory(q.e.id) end,
        }
      end
    end
  end
  self.list:SetItems(items)
end

LW.Main:AddTab(tab)
