-- Live status of every indexed quest for this character, right now:
--   done      completed
--   active    in your quest log
--   now       available and within your level band (grey quests included)
--   group     dungeon/raid quest you could pick up now (kept off the main route)
--   later     too high for now (red/orange, or level requirement not met)
--   locked    prerequisites not met / no longer offered
--   skipped   a skip rule covers it
--   excluded  an alternative (exclusiveTo) was done instead
--   off       its category is switched off in Options
local _, LW = ...

local E = {
  status = {},  -- [questId] = status
  log = {},     -- [questId] = { index, complete, objectives = {{text, finished}} }
  counts = {},
}
LW.Eligibility = E

local function readObjectives(questId, logIndex)
  local out = {}
  if C_QuestLog and C_QuestLog.GetQuestObjectives then
    local ok, objs = pcall(C_QuestLog.GetQuestObjectives, questId)
    if ok and type(objs) == "table" then
      for _, o in ipairs(objs) do
        out[#out + 1] = { text = LW.NotSecret(o.text) or "", finished = o.finished and true or false }
      end
      return out
    end
  end
  local n = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(logIndex) or 0
  for j = 1, n do
    local text, _, finished = GetQuestLogLeaderBoard(j, logIndex)
    out[#out + 1] = { text = LW.NotSecret(text) or "", finished = finished and true or false }
  end
  return out
end

-- The Forever client may only have the modern C_QuestLog API; support both.
local function numEntries()
  if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then return C_QuestLog.GetNumQuestLogEntries() end
  return GetNumQuestLogEntries()
end

local function logTitle(i)
  if C_QuestLog and C_QuestLog.GetInfo then
    local info = C_QuestLog.GetInfo(i)
    if not info then return nil end
    local complete
    if not info.isHeader then
      if C_QuestLog.IsFailed and C_QuestLog.IsFailed(info.questID) then complete = -1
      elseif C_QuestLog.IsComplete and C_QuestLog.IsComplete(info.questID) then complete = 1 end
    end
    return info.title, info.isHeader, complete, info.questID
  end
  local title, _, _, isHeader, _, isComplete, _, questId = GetQuestLogTitle(i)
  return title, isHeader, isComplete, questId
end

--- Read the quest log. Returns two flags comparing it with the previous read:
---   questsChanged - a quest was added or removed (statuses must be recomputed)
---   anyChanged    - anything at all changed (objective progress, completion)
--- QUEST_LOG_UPDATE fires constantly; these let a refresh do only the work that is needed.
local lastIds, lastDetail = "", ""
function E:ReadLog()
  wipe(self.log)
  local n = numEntries() or 0
  local ids, detail = {}, {}
  for i = 1, n do
    local title, isHeader, isComplete, questId = logTitle(i)
    if not isHeader and questId and questId > 0 then
      local objectives = readObjectives(questId, i)
      -- The game's own "complete" flag isn't reliable on every client: also count a quest as
      -- ready when all its objectives are done, or when it has none (deliveries, "talk to").
      local allDone = true
      for j = 1, #objectives do if not objectives[j].finished then allDone = false break end end
      local complete = (isComplete == 1 or isComplete == true or allDone) and isComplete ~= -1
      self.log[questId] = {
        index = i,
        title = title,
        complete = complete,
        failed = isComplete == -1,
        objectives = objectives,
      }
      ids[#ids + 1] = questId
      detail[#detail + 1] = questId .. (complete and "c" or "")
      for j = 1, #objectives do
        detail[#detail + 1] = LW.NotSecret(objectives[j].text) or "?"
      end
    end
  end
  self.logCount = #ids
  table.sort(ids)
  local idSig, detailSig = table.concat(ids, ","), table.concat(detail, "|")
  local questsChanged, anyChanged = idSig ~= lastIds, (idSig ~= lastIds or detailSig ~= lastDetail)
  lastIds, lastDetail = idSig, detailSig
  return questsChanged, anyChanged
end

local function exclusiveDone(e)
  if type(e.exclusive) ~= "table" then return false end
  for _, other in ipairs(e.exclusive) do
    if LW.Adapter:IsCompleted(other) then return true end
  end
  return false
end

--- The quest's effective level for this player (-1 = scales with you).
function E:Level(e, playerLevel)
  playerLevel = playerLevel or UnitLevel("player")
  if not e.level or e.level <= 0 then return math.max(e.req or 0, playerLevel) end
  return e.level
end

-- Unmarked breadcrumbs. A delivery ("take this to X") whose recipient X gives quests you
-- already have or finished is a breadcrumb the game no longer offers (Daily Delivery ->
-- James Halloran's Young Crocolisk Skins). Quests that come AFTER the delivery don't count.
local npcStarts = {}
local function startsOf(npc)
  local s = npcStarts[npc]
  if s == nil then
    local ok, v = pcall(LibQuestieDB.Npc.Get, npc, "questStarts")
    s = (ok and type(v) == "table") and v or false
    npcStarts[npc] = s
  end
  return s or nil
end

local function follows(otherId, e)
  local o = LW.Index:Get(otherId)
  if not o then return false end
  for _, list in ipairs({ o.pre, o.preGroup }) do
    if type(list) == "table" then
      for _, p in ipairs(list) do if math.abs(p) == e.id then return true end end
    end
  end
  return e.nextInChain == otherId
end

local function hasPre(q)
  return (type(q.pre) == "table" and #q.pre > 0) or (type(q.preGroup) == "table" and #q.preGroup > 0)
end

-- Deliberately narrow, because a wrong "yes" hides a real quest. All of these must hold:
--   * the delivery starts a story (no prerequisites, first step of its chain);
--   * the quest you already have from the recipient also has no prerequisites, is in the
--     same zone and within 3 levels (so it is what the delivery was leading you to);
--   * that quest does not come after the delivery in a chain.
local function deadBreadcrumb(e)
  if not (e.noCombat and type(e.finishers) == "table") then return false end
  if hasPre(e) or (e.depth or 1) > 1 then return false end
  for _, npc in ipairs(e.finishers) do
    for _, other in ipairs(startsOf(npc) or {}) do
      local o = other ~= e.id and LW.Index:Get(other)
      if o and o.zone == e.zone and not hasPre(o) and math.abs((o.level or 0) - (e.level or 0)) <= 3
        and (LW.Adapter:IsCompleted(other) or E.log[other]) and not follows(other, e) then
        return true
      end
    end
  end
  return false
end

E.IsDeadBreadcrumb = function(_, e) return deadBreadcrumb(e) end

-- Class quests come in per-race copies (Taming the Beast in Dun Morogh, Elwynn, ...).
-- Once one copy with a given name is done, the others count as "alternative done".
local classNamesDone = {}
local DELIVERY_SLACK = 3

local function compute(e, playerLevel, db)
  if not LW.Categories:Enabled(e.cat) then return "off" end
  if LW.Adapter:IsCompleted(e.id) then return "done" end
  if exclusiveDone(e) then return "excluded" end
  local copy = e.cat == "class" and classNamesDone[e.name]
  if copy and copy ~= e.id then return "excluded" end
  if E.log[e.id] then return "active" end
  if deadBreadcrumb(e) then return "excluded" end
  if LW.Skips:ForQuest(e) then return "skipped" end
  if LW.Offers:Is(e.id) then return "locked" end
  if e.impliedPre and not LW.Adapter:IsCompleted(e.impliedPre) then return "locked" end
  local doable = LW.Adapter:IsDoable(e.id)
  if e.maxReq and e.maxReq > 0 and playerLevel > e.maxReq then return "locked" end
  if (e.req or 0) > playerLevel then return doable and "later" or "locked" end
  if not doable then return "locked" end
  local diff = E:Level(e, playerLevel) - playerLevel
  if e.cat == "dungeon" or e.cat == "raid" then
    return diff > db.dungeonRange and "later" or "group"
  end
  -- Deliveries have nothing to fight, so they get 3 extra levels of slack; far above that
  -- they lead to content you can't do yet, and wait in Later like anything else.
  if diff >= db.deferAt + (e.noCombat and DELIVERY_SLACK or 0) then return "later" end
  return "now"
end

--- Recompute everything. Runs inside a background job (yields).
function E:Compute()
  local playerLevel = UnitLevel("player")
  local db = LW.db
  local status = {}
  local counts = { done = 0, active = 0, now = 0, group = 0, later = 0, locked = 0, skipped = 0, excluded = 0, off = 0 }
  wipe(classNamesDone)
  for _, e in ipairs(LW.Index.list) do
    if e.cat == "class" and (LW.Adapter:IsCompleted(e.id) or self.log[e.id]) then classNamesDone[e.name] = e.id end
  end
  for _, e in ipairs(LW.Index.list) do
    local s = compute(e, playerLevel, db)
    status[e.id] = s
    counts[s] = counts[s] + 1
    LW.Yield()
  end
  self.status = status
  self.counts = counts
end

function E:Status(questId) return self.status[questId] end

--- Per-zone progress: { [zoneId] = { done, total, now, later, skipped } }
function E:ZoneProgress()
  local zones = {}
  for _, e in ipairs(LW.Index.list) do
    local s = self.status[e.id]
    if e.zone and s and s ~= "off" and s ~= "excluded" then
      local z = zones[e.zone]
      if not z then
        z = { zone = e.zone, done = 0, total = 0, now = 0, later = 0, skipped = 0, active = 0, group = 0, locked = 0 }
        zones[e.zone] = z
      end
      z.total = z.total + 1
      if z[s] then z[s] = z[s] + 1 end
    end
  end
  return zones
end
