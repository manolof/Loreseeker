-- Revisit tab: your skips (with notes and revisit levels) and the Later queue.
local _, LW = ...
local L = LW.L
local UI = LW.UI

local tab = { key = "revisit", label = L["Revisit"], openLater = false }

function tab:Build(panel)
  self.list = UI.List(panel)
  self.list.scroll:SetPoint("TOPLEFT", 0, 0)
  self.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
end

local KIND = { zone = L["Zone"], area = L["Area"], quest = L["Quest"], chain = L["Storyline"] }

function tab:Refresh()
  local items = { { header = true, text = L["Your skips"] } }
  local skips = LW.Skips:All()
  for _, r in ipairs(skips) do
    items[#items + 1] = {
      indent = 1, icon = UI.ICONS.skip,
      text = (KIND[r.kind] or r.kind) .. ": " .. (r.label or "?"),
      right = (r.note and r.note ~= "" and ("\"" .. r.note .. "\"") or "") .. (r.level and ("  @" .. r.level) or ""),
      tooltip = UI.Lines(LW.Skips:Describe(r), r.created and string.format(L["Since %s"], date("%Y-%m-%d", r.created))),
      button = { text = L["Unskip"], onClick = function() LW.Skips:Remove(r) end },
    }
  end
  for area in pairs(LW.db.pvpZones) do
    items[#items + 1] = { indent = 1, icon = UI.ICONS.skip, text = string.format(L["Zone: %s"], LW.ZoneName(area)), right = L["PvP preset"],
      button = { text = L["Unskip"], onClick = function()
        LW.db.pvpZones[area] = nil
        LW:RequestRefresh("pvp preset")
        LW:Fire("SKIPS_CHANGED")
      end } }
  end
  if #items == 1 then items[#items + 1] = { indent = 1, dim = true, text = L["Nothing skipped. Use Skip... on the step panel."] } end

  -- Quests an NPC didn't offer although the database says it should
  local missing = {}
  for qid, rec in pairs(LW.char.notOffered) do
    local e = LW.Index:Get(qid)
    if e then missing[#missing + 1] = { e = e, rec = rec } end
  end
  if #missing > 0 then
    table.sort(missing, function(a, b) return a.e.name < b.e.name end)
    items[#items + 1] = { header = true, text = string.format(L["Not offered by the NPC (%d)"], #missing) }
    for _, m in ipairs(missing) do
      local npcName = LibQuestieDB.Npc.Get(m.rec.npc, "name") or string.format(L["NPC %d"], m.rec.npc)
      items[#items + 1] = {
        indent = 1, icon = UI.STATUS_ICON.locked, text = UI.QuestLabel(m.e),
        right = string.format(L["%s at level %d"], npcName, m.rec.level),
        tooltip = UI.Lines(m.e.name, string.format(L["%s didn't offer it when you talked to them."], npcName),
          L["The quest data says it should be available: Forever probably changed it."],
          L["It comes back on its own if the NPC offers it, or when you level up."]),
        button = { text = L["Retry"], onClick = function() LW.Offers:Clear(m.e.id) end },
      }
    end
  end

  -- Later queue, by level
  local later = {}
  for _, e in ipairs(LW.Index.list) do
    if LW.Eligibility:Status(e.id) == "later" then later[#later + 1] = e end
  end
  table.sort(later, function(a, b)
    local la, lb = math.max(a.req or 0, a.level or 0), math.max(b.req or 0, b.level or 0)
    if la ~= lb then return la < lb end
    return a.name < b.name
  end)
  items[#items + 1] = { header = true, text = string.format(L["Later: %d quests waiting for you to level up"], #later),
    right = self.openLater and L["click to hide"] or L["click to show"],
    onClick = function() tab.openLater = not tab.openLater; tab:Refresh() end }
  if self.openLater then
    for _, e in ipairs(later) do
      items[#items + 1] = { indent = 1, icon = UI.STATUS_ICON.later, text = UI.QuestLabel(e),
        right = LW.ZoneName(e.zone) .. (e.req and e.req > UnitLevel("player") and ("  " .. string.format(L["(requires %d)"], e.req)) or ""),
        tooltip = UI.Lines(e.name, UI.STORY_HINT),
        onClick = function() LW.Main:ShowStory(e.id) end }
    end
  end
  self.list:SetItems(items)
end

LW.Main:AddTab(tab)
