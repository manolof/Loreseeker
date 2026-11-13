-- Turns quest statuses into concrete, located tasks:
--   accept  - pick the quest up (NPC, object, or an item that starts it)
--   turnin  - hand it in
--   kill / loot / object / explore - objective work
--   buy     - an objective item sold by a vendor (often the "go away and come back" errand)
--   generic - in your log, but nothing to locate
-- Points are { map = uiMapID, x = 0..1, y = 0..1, area = areaId }.
local _, LW = ...
local L = LW.L

local T = {
  list = {},     -- routable tasks
  groups = {},   -- [dungeon areaId] = { area, tasks = {}, quests = {} } : group-up work
  blocked = {},  -- tasks whose every location is inside a skipped zone/area
}
LW.Tasks = T

local MAX_POINTS = 40

local Npc, Obj, Item = function(id, f) return LibQuestieDB.Npc.Get(id, f) end,
  function(id, f) return LibQuestieDB.Object.Get(id, f) end,
  function(id, f) return LibQuestieDB.Item.Get(id, f) end

local function safe(fn, id, field)
  local ok, v = pcall(fn, id, field)
  return ok and v or nil
end

---------------------------------------------------------------------------------------------
-- Points
---------------------------------------------------------------------------------------------

local function newPoints() return { skippedBy = nil, inDungeon = false } end

local function addPoint(points, areaId, x, y, dungeonArea)
  local map = LW.Adapter:UiMap(areaId)
  if not map or not x or not y or x < 0 or y < 0 then return end
  x, y = x / 100, y / 100
  local rule = LW.Skips:ForPoint(map, x, y)
  if rule then
    points.skippedBy = points.skippedBy or rule
    return
  end
  points[#points + 1] = { map = map, x = x, y = y, area = areaId, dungeon = dungeonArea }
end

local function addSpawns(points, spawns)
  if type(spawns) ~= "table" then return end
  for areaId, coords in pairs(spawns) do
    if LW.Adapter:IsDungeonZone(areaId) then
      points.inDungeon = true
      for _, c in ipairs(LW.Adapter:DungeonEntrances(areaId) or {}) do
        addPoint(points, c[1], c[2], c[3], areaId)
      end
    elseif type(coords) == "table" then
      for _, c in ipairs(coords) do addPoint(points, areaId, c[1], c[2]) end
    end
  end
end

-- Kill/loot targets: keep only spawns in the denser clusters. An item listed for several
-- creature types (Sida's Bag: three kinds of ooze) would otherwise send you to a lone
-- straggler across the zone instead of the camp where the quest actually happens.
local CLUSTER_R2 = 0.04 * 0.04 -- 4% of the map, roughly 100-150 yards
local function denseOnly(points)
  local n = #points
  if n <= 4 then return points end
  local counts, maxCount = {}, 0
  for i = 1, n do
    local a, c = points[i], 0
    for j = 1, n do
      local b = points[j]
      if a.map == b.map then
        local dx, dy = a.x - b.x, a.y - b.y
        if dx * dx + dy * dy <= CLUSTER_R2 then c = c + 1 end
      end
    end
    counts[i] = c
    if c > maxCount then maxCount = c end
  end
  local keep = math.max(2, maxCount * 0.35)
  if maxCount < 3 then return points end -- evenly scattered: nothing to prefer
  local out = newPoints()
  out.skippedBy, out.inDungeon = points.skippedBy, points.inDungeon
  for i = 1, n do
    if counts[i] >= keep then out[#out + 1] = points[i] end
  end
  return out
end

local function downsample(points)
  local n = #points
  if n <= MAX_POINTS then return points end
  local out = newPoints()
  out.skippedBy, out.inDungeon = points.skippedBy, points.inDungeon
  local stepSize = n / MAX_POINTS
  for i = 0, MAX_POINTS - 1 do out[#out + 1] = points[math.floor(i * stepSize) + 1] end
  return out
end

local function npcPoints(points, npcId) addSpawns(points, safe(Npc, npcId, "spawns")) end
local function objPoints(points, objId) addSpawns(points, safe(Obj, objId, "spawns")) end

local function names(fn, ids, limit)
  local out = {}
  for i = 1, math.min(#ids, limit or 2) do
    out[#out + 1] = safe(fn, ids[i], "name") or "?"
  end
  if #ids > (limit or 2) then out[#out + 1] = "..." end
  return table.concat(out, ", ")
end

---------------------------------------------------------------------------------------------
-- Task construction
---------------------------------------------------------------------------------------------

-- Where a task can be done never changes unless your skips change, so the processed point
-- list is built once per task key and reused (decoding spawns and clustering is the
-- expensive part of a refresh). T:Invalidate() drops it.
local pointCache = {}
local acceptCache = {} -- [questId] = { task, ... }

local previewCache, previewTurnin = {}, {}

function T:Invalidate()
  wipe(pointCache)
  wipe(acceptCache)
  wipe(previewCache)
  wipe(previewTurnin)
end

local function taskKey(e, kind, sub)
  return kind .. ":" .. e.id .. ":" .. (sub or "")
end

--- build(points) fills a fresh point list; only called on a cache miss.
local function pointsFor(key, kind, build)
  local p = pointCache[key]
  if not p then
    p = newPoints()
    if build then build(p) end
    if kind == "kill" or kind == "loot" then p = denseOnly(p) end
    p = downsample(p)
    pointCache[key] = p
  end
  return p
end

local function newTask(e, kind, text, build, extra)
  local key = taskKey(e, kind, extra and extra.sub)
  local t = { key = key, quest = e, kind = kind, text = text, points = pointsFor(key, kind, build) }
  if extra then for k, v in pairs(extra) do t[k] = v end end
  return t
end

local function whoNames(npcs, objs)
  local who = {}
  for _, id in ipairs(npcs or {}) do who[#who + 1] = safe(Npc, id, "name") end
  for _, id in ipairs(objs or {}) do who[#who + 1] = safe(Obj, id, "name") end
  return table.concat(who, " / ", 1, math.min(#who, 2)), #who
end

local function acceptTasks(e, out)
  local cached = acceptCache[e.id]
  if cached then
    for i = 1, #cached do out[#out + 1] = cached[i] end
    return
  end
  cached = {}
  local startedBy = LibQuestieDB.Quest.Get(e.id, "startedBy") or {}
  local target, count = whoNames(startedBy[1], startedBy[2])
  if count > 0 then
    cached[#cached + 1] = newTask(e, "accept", L["Accept"], function(p)
      for _, id in ipairs(startedBy[1] or {}) do npcPoints(p, id) end
      for _, id in ipairs(startedBy[2] or {}) do objPoints(p, id) end
    end, { target = target })
  end
  -- Quests started by an item you have to find first.
  for _, itemId in ipairs(startedBy[3] or {}) do
    local drops = safe(Item, itemId, "npcDrops") or {}
    local item = safe(Item, itemId, "name") or "item"
    cached[#cached + 1] = newTask(e, "accept", string.format(L["Find %s (starts the quest)"], item), function(p)
      for _, id in ipairs(drops) do npcPoints(p, id) end
      for _, id in ipairs(safe(Item, itemId, "objectDrops") or {}) do objPoints(p, id) end
    end, { sub = "i" .. itemId, target = #drops > 0 and names(Npc, drops) or nil })
  end
  acceptCache[e.id] = cached
  for i = 1, #cached do out[#out + 1] = cached[i] end
end

local function turninTask(e, out)
  local finishedBy = LibQuestieDB.Quest.Get(e.id, "finishedBy") or {}
  out[#out + 1] = newTask(e, "turnin", L["Turn in"], function(p)
    for _, id in ipairs(finishedBy[1] or {}) do npcPoints(p, id) end
    for _, id in ipairs(finishedBy[2] or {}) do objPoints(p, id) end
  end, { target = (whoNames(finishedBy[1], finishedBy[2])) })
end

-- Match a DB objective to the game's live objective line by name.
local function liveObjective(log, name)
  if not log or not name then return nil end
  local lname = name:lower()
  for _, o in ipairs(log.objectives) do
    if o.text:lower():find(lname, 1, true) then return o end
  end
  return nil
end

local function allFinished(log)
  if not log or #log.objectives == 0 then return false end
  for _, o in ipairs(log.objectives) do if not o.finished then return false end end
  return true
end

local QUEST_ITEM_CLASS = 12
local remainingCount, bestDropRate, auctionPoints, flightPointTask

-- "Sida's Bag: 0/1" -> 1 still needed
remainingCount = function(line)
  local have, want = (line or ""):match("(%d+)%s*/%s*(%d+)")
  if have then return math.max(1, tonumber(want) - tonumber(have)) end
  return 1
end

-- The best drop chance among the creatures that drop an item (percent), or nil if unknown.
bestDropRate = function(itemId, npcs)
  local best
  for _, npc in ipairs(npcs) do
    local r = LW.Adapter:DropRate(itemId, npc)
    if r and (not best or r > best) then best = r end
  end
  return best
end

-- Auction houses your faction can use (Booty Bay, Gadgetzan and Everlook serve everyone).
local auctions
auctionPoints = function()
  if not auctions then
    auctions = {}
    local faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
    for _, a in ipairs(LW.TravelData and LW.TravelData.auctioneers or {}) do
      if a[6]:find(faction, 1, true) then auctions[#auctions + 1] = a end
    end
  end
  return auctions
end

-- The game's own map marker for a quest in your log, on the map you're on or the quest's
-- zone. Only newer clients have it; nil otherwise.
local function questMapPoint(questId)
  if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return nil end
  local maps = {}
  local here = LW.PlayerZoneMap()
  if here then maps[#maps + 1] = here end
  local e = LW.Index:Get(questId)
  local zoneMap = e and e.zone and LW.Adapter:UiMap(e.zone)
  if zoneMap and zoneMap ~= here then maps[#maps + 1] = zoneMap end
  for _, map in ipairs(maps) do
    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, map)
    if ok and type(list) == "table" then
      for _, q in ipairs(list) do
        if q.questID == questId and q.x and q.y and (q.x > 0 or q.y > 0) then
          return { map = map, x = q.x, y = q.y }
        end
      end
    end
  end
  return nil
end

-- "0/1 Attack Plan: Menethil Harbor destroyed" -> "Attack Plan: Menethil Harbor"
local VERBS = { "destroyed", "slain", "killed", "collected", "used", "found", "explored", "burned", "placed",
  "freed", "rescued", "activated", "investigated", "searched" }
local function objectiveName(text)
  text = (text or ""):gsub("^%s*%d+%s*/%s*%d+%s*", ""):gsub("%s*:%s*%d+%s*/%s*%d+%s*$", "")
  for _, v in ipairs(VERBS) do
    local stripped = text:gsub("%s+" .. v .. "$", "")
    if stripped ~= text then return stripped end
  end
  return text
end

-- Objects or NPCs whose name is the objective's. The name index is built the first time it's
-- needed, spread over frames (only possible inside the background job).
local nameIndexReady = false
local function objectiveByName(text)
  local name = objectiveName(text)
  if name == "" then return nil end
  local co, isMain = coroutine.running()
  if not nameIndexReady then
    if not co or isMain then return nil end
    for _, db in ipairs({ LibQuestieDB.Object, LibQuestieDB.Npc }) do
      if db.BuildNameIndexAsync then pcall(db.BuildNameIndexAsync, 250) end
    end
    nameIndexReady = true
  end
  local objects = LibQuestieDB.Object.IdsByName and LibQuestieDB.Object.IdsByName(name)
  local npcs = LibQuestieDB.Npc.IdsByName and LibQuestieDB.Npc.IdsByName(name)
  if (objects and #objects > 0) or (npcs and #npcs > 0) then return { objects = objects, npcs = npcs } end
  return nil
end

local function objectiveTasks(e, log, out)
  local objectives = LibQuestieDB.Quest.Get(e.id, "objectives") or {}
  local made = 0
  local function finished(name)
    local o = liveObjective(log, name)
    if o then return o.finished, o.text end
    return allFinished(log), nil
  end

  for i, o in ipairs(objectives[1] or {}) do -- creatures
    local name = o[2] or safe(Npc, o[1], "name")
    local done, line = finished(name)
    if not done then
      out[#out + 1] = newTask(e, "kill", string.format(L["Kill %s"], name or "?"), function(p) npcPoints(p, o[1]) end,
        { sub = "n" .. i, detail = line })
      made = made + 1
    end
  end
  for i, o in ipairs(objectives[5] or {}) do -- kill credit (any of several creatures)
    local name = o[3] or safe(Npc, o[2], "name")
    local done, line = finished(name)
    if not done then
      out[#out + 1] = newTask(e, "kill", name or L["Objective"], function(p)
        for _, id in ipairs(o[1] or {}) do npcPoints(p, id) end
      end, { sub = "k" .. i, detail = line })
      made = made + 1
    end
  end
  for i, o in ipairs(objectives[2] or {}) do -- objects
    local name = o[2] or safe(Obj, o[1], "name")
    local done, line = finished(name)
    if not done then
      out[#out + 1] = newTask(e, "object", string.format(L["Use %s"], name or "?"), function(p) objPoints(p, o[1]) end,
        { sub = "o" .. i, detail = line })
      made = made + 1
    end
  end
  -- Items: every way to get one is its own task, all sharing one "slot". The router keeps
  -- whichever is cheapest right now (travel + expected farming time) and hides the rest;
  -- the planner treats them as one thing to do.
  for i, o in ipairs(objectives[3] or {}) do -- items
    local itemId = o[1]
    local name = o[2] or safe(Item, itemId, "name")
    local done, line = finished(name)
    if not done then
      local slot = e.id .. ":item:" .. i
      local need = remainingCount(line)
      local before = #out
      local drops = safe(Item, itemId, "npcDrops") or {}
      local objectDrops = safe(Item, itemId, "objectDrops") or {}
      local rate = bestDropRate(itemId, drops)
      local loot = newTask(e, "loot", string.format(L["Collect %s"], name or "?"), function(p)
        for _, id in ipairs(drops) do npcPoints(p, id) end
        for _, id in ipairs(objectDrops) do objPoints(p, id) end
      end, { sub = "i" .. i, detail = line, slot = slot, need = need, dropRate = rate,
        target = #drops > 0 and (names(Npc, drops) .. (rate and " " .. string.format(L["(%d%% drop)"], rate + 0.5) or "")) or nil })
      if #loot.points > 0 or loot.points.skippedBy then out[#out + 1] = loot end
      local vendors = safe(Item, itemId, "vendors") or {}
      if #vendors > 0 then
        out[#out + 1] = newTask(e, "buy", string.format(L["Buy %s"], name or "?"), function(p)
          for _, id in ipairs(vendors) do npcPoints(p, id) end
        end, { sub = "v" .. i, detail = line, slot = slot, target = names(Npc, vendors) })
      end
      -- Tradeable items (not "Quest" class items) can also be bought from players or crafted.
      if safe(Item, itemId, "class") ~= QUEST_ITEM_CLASS then
        if #auctionPoints() > 0 then
          out[#out + 1] = newTask(e, "auction", string.format(L["Buy %s at the Auction House"], name or "?"), function(p)
            for _, a in ipairs(auctionPoints()) do addPoint(p, a[3], a[4], a[5]) end
          end, { sub = "a" .. i, detail = line, slot = slot, target = L["Auctioneer"] })
        end
        local profession = LW.Crafts:Profession(itemId)
        if profession then
          out[#out + 1] = newTask(e, "craft", string.format(L["Craft %s"], name or "?"), nil,
            { sub = "c" .. i, detail = line, slot = slot, target = profession })
        end
      end
      if #out > before then made = made + 1 end
    end
  end
  local trigger = LibQuestieDB.Quest.Get(e.id, "triggerEnd")
  if type(trigger) == "table" and type(trigger[2]) == "table" and not allFinished(log) then
    out[#out + 1] = newTask(e, "explore", trigger[1] or L["Explore"], function(p) addSpawns(p, trigger[2]) end, { sub = "t" })
    made = made + 1
  end
  if made == 0 then
    -- The database doesn't say where this quest's objectives are (common for Forever's own
    -- quests). In order of trust:
    --   1. the game's own map marker for the quest (newer clients, quests in your log)
    --   2. an object or NPC whose name matches the objective ("Attack Plan: Menethil Harbor")
    --   3. no objectives to do at all ("talk to" / escort quests): around the turn-in NPC
    --   4. otherwise: no location. The step says so and doesn't compete with real steps.
    local live = log and log.objectives or {}
    local open
    for _, o in ipairs(live) do if not o.finished then open = o break end end
    local line = (open or live[1] or {}).text
    local poi = questMapPoint(e.id)
    if poi then
      out[#out + 1] = newTask(e, "generic", L["Work on the objectives"], function(p) p[1] = poi end,
        { detail = line, sub = "poi" })
      return
    end
    if open then
      local found = objectiveByName(open.text)
      if found then
        out[#out + 1] = newTask(e, "generic", L["Work on the objectives"], function(p)
          for _, id in ipairs(found.objects or {}) do objPoints(p, id) end
          for _, id in ipairs(found.npcs or {}) do npcPoints(p, id) end
        end, { detail = line, sub = "name" })
        return
      end
      out[#out + 1] = newTask(e, "generic", L["Work on the objectives"], nil,
        { detail = line, unknown = true, sub = "unknown" })
      return
    end
    local finishedBy = LibQuestieDB.Quest.Get(e.id, "finishedBy") or {}
    out[#out + 1] = newTask(e, "generic", L["Work on the objectives"], function(p)
      for _, id in ipairs(finishedBy[1] or {}) do npcPoints(p, id) end
      for _, id in ipairs(finishedBy[2] or {}) do objPoints(p, id) end
    end, { detail = line, sub = "giver", target = (whoNames(finishedBy[1], finishedBy[2])) })
  end

end

---------------------------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------------------------

--- For the planner: the objective tasks a quest would have right after you accept it.
function T:Preview(e)
  local list = previewCache[e.id]
  if not list then
    list = {}
    objectiveTasks(e, nil, list)
    for _, t in ipairs(list) do t.preview = true end
    previewCache[e.id] = list
  end
  return list
end

--- For the planner: the turn-in task a quest will have once its objectives are done.
function T:PreviewTurnin(e)
  local list = previewTurnin[e.id]
  if not list then
    list = {}
    turninTask(e, list)
    for _, t in ipairs(list) do t.preview = true end
    previewTurnin[e.id] = list
  end
  return list
end

local function isGroupWork(e, task)
  if task.kind == "flightpoint" then return false end
  local tagged = not (e.cat == "dungeon" or e.cat == "raid") and LW.Adapter:IsDungeonTagged(e.id)
  if not (e.cat == "dungeon" or e.cat == "raid" or tagged) then return false end
  if e.zone and LW.char.pinned[e.zone] then return false end
  if task.kind == "turnin" then return false end
  -- A quest whose own zone is a dungeon or instance ("Excavation Site: Wetlands"), or that the
  -- game tags as a dungeon quest: ALL its work waits for a group, even after you accepted it
  -- and even when the creature spawns are listed in the outdoor zone around the entrance.
  return true
end

LW:Listen("SKIPS_CHANGED", function() T:Invalidate() end)

local DISCOVER_NEAR_WORK = 1200 -- yards from a quest location
local DISCOVER_MAX = 2         -- at most this many discovery steps at a time

-- A pseudo-quest so the rest of the addon can treat a flight point like any other step.
local fpCache = {}
flightPointTask = function(fm)
  local t = fpCache[fm.npc]
  if not t then
    local text = string.format(L["Discover the flight point at %s"], fm.zone)
    local points = newPoints()
    points[1] = { map = fm.map, x = fm.x, y = fm.y, area = fm.area }
    t = { key = "flightpoint:" .. fm.npc, kind = "flightpoint", text = text, target = fm.name, points = points,
      quest = { id = -fm.npc, name = text, level = 0, req = 0, cat = "travel", flightPoint = true } }
    fpCache[fm.npc] = t
  end
  return t
end

function T:Build()
  local list, groups, blocked = {}, {}, {}
  local status = LW.Eligibility.status
  for _, e in ipairs(LW.Index.list) do
    local s = status[e.id]
    if s == "now" or s == "group" or s == "active" then
      local made = {}
      if s == "active" then
        local log = LW.Eligibility.log[e.id]
        if log and log.complete then turninTask(e, made) else objectiveTasks(e, log, made) end
      else
        acceptTasks(e, made)
      end
      for _, t in ipairs(made) do
        if #t.points == 0 and t.points.skippedBy then
          blocked[#blocked + 1] = t
        elseif isGroupWork(e, t) then
          local gz = e.zone or 0 -- a dungeon quest the game tags, from a zone we don't know
          local g = groups[gz]
          if not g then g = { area = gz, tasks = {}, quests = {} }; groups[gz] = g end
          g.tasks[#g.tasks + 1] = t
          g.quests[e.id] = true
        else
          list[#list + 1] = t
        end
      end
      LW.Yield()
    end
  end
  -- Undiscovered flight points near where you have quests: an optional step, worth a
  -- short detour because every later trip can use it.
  local candidates = {}
  for _, fm in ipairs(LW.Travel:Undiscovered()) do
    local nearWork = false
    for _, t in ipairs(list) do
      for _, p in ipairs(t.points) do
        local wx, wy, inst = LW.Router.WorldOf(p)
        if wx and inst == fm.inst then
          local dx, dy = wx - fm.wx, wy - fm.wy
          if dx * dx + dy * dy < DISCOVER_NEAR_WORK * DISCOVER_NEAR_WORK then nearWork = true break end
        end
      end
      if nearWork then break end
    end
    if nearWork and not LW.Skips:ForPoint(fm.map, fm.x, fm.y) then candidates[#candidates + 1] = fm end
  end
  -- only the closest few, so the guide never fills up with errands
  local px, py, pinst = LW.Router.PlayerWorld()
  local function d2(fm)
    if not px or fm.inst ~= pinst then return math.huge end
    local dx, dy = fm.wx - px, fm.wy - py
    return dx * dx + dy * dy
  end
  table.sort(candidates, function(a, b) return d2(a) < d2(b) end)
  for i = 1, math.min(DISCOVER_MAX, #candidates) do list[#list + 1] = flightPointTask(candidates[i]) end
  self.list, self.groups, self.blocked = list, groups, blocked
end
