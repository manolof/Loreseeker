-- Skips: zones, areas (a circle around where you stood), single quests and whole chains,
-- each with a note and an optional "revisit at level N". Skipped work never becomes the
-- main step; it waits in the Revisit tab.
local _, LW = ...

local SK = {}
LW.Skips = SK

-- Contested zones for the PvP-server preset (Classic area IDs).
SK.contested = {
  { 331, "Ashenvale" }, { 406, "Stonetalon Mountains" }, { 33, "Stranglethorn Vale" },
  { 267, "Hillsbrad Foothills" }, { 45, "Arathi Highlands" }, { 405, "Desolace" },
  { 400, "Thousand Needles" }, { 36, "Alterac Mountains" }, { 8, "Swamp of Sorrows" },
  { 3, "Badlands" }, { 15, "Dustwallow Marsh" }, { 47, "The Hinterlands" },
  { 440, "Tanaris" }, { 357, "Feralas" }, { 51, "Searing Gorge" }, { 46, "Burning Steppes" },
  { 490, "Un'Goro Crater" }, { 16, "Azshara" }, { 361, "Felwood" }, { 618, "Winterspring" },
  { 1377, "Silithus" }, { 28, "Western Plaguelands" }, { 139, "Eastern Plaguelands" },
  { 4, "Blasted Lands" }, { 17, "The Barrens" }, { 11, "Wetlands" }, { 10, "Duskwood" },
}

SK.DEFAULT_RADIUS = 0.08 -- fraction of the zone map

local function list() return LW.char.skips end

local function add(rule)
  rule.created = time()
  table.insert(list(), rule)
  LW:Log("skip", "%s %s note=%s level=%s", rule.kind, tostring(rule.label), tostring(rule.note), tostring(rule.level))
  LW:RequestRefresh("skip")
  LW:Fire("SKIPS_CHANGED")
  return rule
end

function SK:AddZone(areaId, note, level)
  return add({ kind = "zone", zone = areaId, note = note, level = level, label = LW.ZoneName(areaId) })
end

function SK:AddAreaHere(radius, note, level)
  local map = LW.PlayerZoneMap()
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  if not pos then
    LW:Print("Can't read your position here.")
    return nil
  end
  local x, y = pos:GetXY()
  local sub = GetSubZoneText()
  local label = LW.MapName(map) .. ((sub and sub ~= "") and (" - " .. sub) or "")
  return add({ kind = "area", map = map, x = x, y = y, r = radius or self.DEFAULT_RADIUS,
    note = note, level = level, label = label })
end

function SK:AddQuest(questId, note, level)
  local e = LW.Index:Get(questId)
  return add({ kind = "quest", quest = questId, note = note, level = level,
    label = e and e.name or ("Quest " .. questId) })
end

function SK:AddChain(questId, note, level)
  local e = LW.Index:Get(questId)
  local chain = e and LW.Chains:Get(e.chain)
  if not chain then return self:AddQuest(questId, note, level) end
  return add({ kind = "chain", quest = chain.root.id, note = note, level = level,
    label = "Story: " .. LW.Chains:Name(chain) })
end

function SK:Remove(rule)
  for i, r in ipairs(list()) do
    if r == rule then
      table.remove(list(), i)
      LW:RequestRefresh("unskip")
      LW:Fire("SKIPS_CHANGED")
      return
    end
  end
end

function SK:All() return list() end

local presetRules = {} -- one shared rule object per preset zone (this runs per map point)
local function zoneSkipped(areaId)
  if not areaId then return nil end
  if LW.db.pvpZones[areaId] then
    local rule = presetRules[areaId]
    if not rule then
      rule = { kind = "zone", zone = areaId, note = "Contested (PvP preset)", label = LW.ZoneName(areaId), preset = true }
      presetRules[areaId] = rule
    end
    return rule
  end
  for _, r in ipairs(list()) do
    if r.kind == "zone" and r.zone == areaId then return r end
  end
  return nil
end

--- The rule that skips this quest as a whole (quest, chain or its zone), or nil.
function SK:ForQuest(e)
  for _, r in ipairs(list()) do
    if r.kind == "quest" and r.quest == e.id then return r end
    if r.kind == "chain" then
      local root = LW.Index:Get(r.quest)
      if root and root.chain and root.chain == e.chain then return r end
    end
  end
  return zoneSkipped(e.zone)
end

--- The rule that skips a map point (uiMap, x, y in 0-1), or nil.
function SK:ForPoint(map, x, y)
  local area = LW.Adapter:AreaForMap(map)
  local zr = zoneSkipped(area)
  if zr then return zr end
  for _, r in ipairs(list()) do
    if r.kind == "area" and r.map == map then
      local dx, dy = x - r.x, y - r.y
      if dx * dx + dy * dy <= r.r * r.r then return r end
    end
  end
  return nil
end

function SK:Describe(r)
  local s = r.label or "?"
  if r.note and r.note ~= "" then s = s .. " - \"" .. r.note .. "\"" end
  if r.level then s = s .. " (revisit at " .. r.level .. ")" end
  return s
end

--- On level up: prompt for every skip whose revisit level has been reached.
function SK:CheckRevisits(level)
  for _, r in ipairs(list()) do
    if r.level and level >= r.level and not r.reminded then
      r.reminded = true
      StaticPopup_Show("LORESEEKER_REVISIT", self:Describe(r), nil, r)
    end
  end
end

StaticPopupDialogs["LORESEEKER_REVISIT"] = {
  text = "Loreseeker: time to revisit\n\n%s\n\nRemove this skip?",
  button1 = "Unskip",
  button2 = "Keep skipping",
  OnAccept = function(_, rule) if rule then SK:Remove(rule) end end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

-- Note prompt used by every "Skip ..." action. data = function(note, level).
StaticPopupDialogs["LORESEEKER_SKIP"] = {
  text = "%s\n\nOptional note. Add @level to be reminded, e.g. \"horde camp @40\".",
  button1 = "Skip",
  button2 = CANCEL,
  hasEditBox = 1,
  maxLetters = 120,
  OnShow = function(self)
    local eb = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
    if eb then eb:SetText(""); eb:SetFocus() end
  end,
  OnAccept = function(self, apply)
    local eb = self.editBox or self.EditBox or (self.GetEditBox and self:GetEditBox())
    local note, level = LW.ParseNote(eb and eb:GetText() or "")
    if apply then apply(note, level) end
  end,
  EditBoxOnEnterPressed = function(self)
    local parent = self:GetParent()
    local which = parent.which and StaticPopupDialogs[parent.which]
    if which and which.OnAccept then which.OnAccept(parent, parent.data) end
    parent:Hide()
  end,
  EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
}

function SK:Prompt(title, apply)
  StaticPopup_Show("LORESEEKER_SKIP", title, nil, apply)
end
