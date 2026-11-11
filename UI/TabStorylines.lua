-- Storylines tab: curated stories first, then every other long chain, with progress.
local _, LW = ...
local L = LW.L
local UI = LW.UI

local tab = { key = "stories", label = L["Storylines"], open = {} }

function tab:Build(panel)
  self.list = UI.List(panel)
  self.list.scroll:SetPoint("TOPLEFT", 0, 0)
  self.list.scroll:SetPoint("BOTTOMRIGHT", -26, 0)
end

local function chainRow(chain, items, open, indent)
  indent = indent or 0
  local done, total = LW.Chains:Progress(chain)
  if total == 0 then return end
  local curated = chain.curated
  local zone = chain.root.zone and LW.ZoneName(chain.root.zone) or ""
  items[#items + 1] = {
    icon = curated and UI.ICONS.story or UI.ICONS.generic,
    indent = indent,
    text = string.format(L["%s  |cffffffff%d/%d|r"], LW.Chains:Name(chain), done, total),
    right = string.format(L["%s - lvl %d"], zone, chain.minLevel or 0),
    bar = { done, total },
    tooltip = UI.Lines(LW.Chains:Name(chain), curated and curated.blurb and L[curated.blurb], string.format(L["Starts with: %s"], chain.root.name),
      L["Click to show its quests."]),
    onClick = function() open[chain.id] = not open[chain.id]; tab:Refresh() end,
    dim = done == total,
    -- built-in storylines are fixed; any other chain can be starred (and unstarred) by you
    button = (not curated or curated.user) and {
      text = LW.Storylines:IsStarred(chain) and L["Unstar"] or L["Star"],
      onClick = function() LW.Storylines:ToggleStar(chain); tab:Refresh() end,
    } or nil,
  }
  if open[chain.id] then
    for _, e in ipairs(chain.members) do
      local s = LW.Eligibility:Status(e.id)
      if s ~= "off" then
        local here = tab.focusQuest == e.id
        items[#items + 1] = {
          indent = indent + 1 + math.min((e.depth or 1) - 1, 3), icon = UI.STATUS_ICON[s],
          text = (here and "|cff00ff00>>|r " or "") .. UI.QuestLabel(e) .. (here and " |cff00ff00<<|r" or ""),
          right = UI.STATUS_LABEL[s], dim = s == "done" and not here,
          tooltip = UI.Lines(e.name, LW.ZoneName(e.zone), UI.STATUS_LABEL[s]),
          onClick = function() LW.Main:ShowJournal(e.id) end,
        }
      end
    end
  end
end

function tab:Refresh()
  local focus = self.focusChain and LW.Chains:Get(self.focusChain)
  local curated, other = {}, {}
  for _, chain in ipairs(LW.Chains.list) do
    if chain == focus then -- shown on top instead
    elseif chain.part then -- listed under its storyline's main chain
    elseif chain.curated then curated[#curated + 1] = chain
    elseif chain.size >= LW.Chains.STORY_MIN then other[#other + 1] = chain end
  end
  local byLevel = function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end
  table.sort(curated, byLevel)
  table.sort(other, byLevel)

  local items = {}
  if focus then
    items[#items + 1] = { header = true, text = L["Selected storyline"], right = L["click to clear"],
      onClick = function() tab.focusChain, tab.focusQuest = nil, nil; tab:Refresh() end }
    chainRow(focus, items, self.open)
  end
  -- Notable storylines, grouped by zone; zones ordered by their lowest-level story.
  local zones, order = {}, {}
  for _, chain in ipairs(curated) do
    local zone = chain.curated.zone or L["Other"]
    if not zones[zone] then zones[zone] = {}; order[#order + 1] = zone end
    table.insert(zones[zone], chain)
  end
  items[#items + 1] = { header = true, text = string.format(L["Notable storylines (%d)"], #curated) }
  for _, zone in ipairs(order) do
    items[#items + 1] = { indent = 1, header = true, text = LW.LocalZone(zone) }
    for _, chain in ipairs(zones[zone]) do
      chainRow(chain, items, self.open, 1)
      -- a storyline's side chains appear under it once it is opened
      if self.open[chain.id] and chain.curated.parts then
        for _, part in ipairs(chain.curated.parts) do
          if part ~= focus then chainRow(part, items, self.open, 2) end
        end
      end
    end
  end
  items[#items + 1] = { header = true, text = string.format(L["Other quest chains (%d+ quests)"], LW.Chains.STORY_MIN) }
  for _, chain in ipairs(other) do chainRow(chain, items, self.open) end
  self.list:SetItems(items)
end

--- Open the storyline a quest belongs to, expanded at the top with the quest marked.
--- Quests without a chain open their journal page instead.
function LW.Main:ShowStory(questId)
  local e = questId and LW.Index:Get(questId)
  local chain = e and LW.Chains:Get(e.chain)
  if not chain then
    if questId and LW.Journal:Get(questId) then
      self:ShowJournal(questId)
    else
      LW:Print(string.format(L["%s is a standalone quest, not part of a storyline."], e and e.name or L["This quest"]))
    end
    return
  end
  tab.focusChain, tab.focusQuest = chain.id, questId
  tab.open[chain.id] = true
  self:SelectKey("stories")
  tab.list.scroll:SetVerticalScroll(0)
end

LW.Main:AddTab(tab)
