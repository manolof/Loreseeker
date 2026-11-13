-- Picks the next step. Lower score wins. Ingredients:
--   travel   - world distance to the nearest location (other continent = very far)
--   zone     - leaving your current zone costs extra
--   errands  - work in another zone waits until this zone is finished, unless 3+ tasks
--              point the same way (then it's worth the trip: go there, come back)
--   cluster  - tasks near other tasks score better (a Zygor-style "hub")
--   commit   - turn-ins and quests already in your log score better
--   lore     - curated storylines and long chains score better (Options: lore weight)
local _, LW = ...

local R = {
  ranked = {},  -- sorted tasks
  snoozed = {}, -- [task key] = expiry (GetTime)
  pinned = nil, -- task key pinned by the user
}
LW.Router = R

local HBD = LibStub and LibStub("HereBeDragons-2.0", true)

local FAR = 100000
local ZONE_PENALTY = 600
local ERRAND_PENALTY = 4000
local ERRAND_BATCHED = 800
local CLUSTER_RADIUS = 150
local CLUSTER_BONUS = 40
local SNOOZE_SECONDS = 600

local function worldOf(p)
  if p.wx == nil then
    if HBD then
      local x, y, inst = HBD:GetWorldCoordinatesFromZone(p.x, p.y, p.map)
      p.wx, p.wy, p.inst = x or false, y, inst
    else
      p.wx = false
    end
  end
  return p.wx, p.wy, p.inst
end

local function playerWorld()
  if not HBD then return nil end
  return HBD:GetPlayerWorldPosition()
end

--- Nearest point of a task to the player: point, distance in yards (nil if unknown).
local function nearest(task, px, py, pinst)
  local best, bestD
  for _, p in ipairs(task.points) do
    local wx, wy, inst = worldOf(p)
    if wx and px and inst == pinst then
      local dx, dy = wx - px, wy - py
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then best, bestD = p, d end
    elseif not best then
      best = p
    end
  end
  return best, bestD and math.sqrt(bestD)
end

R.WorldOf, R.PlayerWorld = worldOf, playerWorld

function R:Snooze(task)
  if task then
    self.snoozed[task.key] = GetTime() + SNOOZE_SECONDS
    LW:Log("snooze", "%s (%s)", task.key, task.quest.name)
  end
  LW.Planner.plan = {} -- the plan was built around that step
  self:Route()
  LW.Planner:Request()
end

function R:Pin(task)
  self.pinned = task and task.key or nil
  LW.Planner.plan = {}
  self:Route()
  LW.Planner:Request()
end

local DISCOVER_BONUS = 900    -- yards: what a new flight point saves you later (a short detour pays off)
local KILL_SECONDS = 20      -- one kill, loot included
local ASSUMED_DROP = 50      -- percent, when the drop chance is unknown
local AUCTION_SECONDS = 60   -- browsing and buying
local BUY_SECONDS = 10
local CRAFT_SECONDS = 90     -- gathering materials is unknown; assume a little
local WALK_YPS = 7

--- Time the step itself takes once you are there, in walking yards (so it adds to travel).
--- This is what lets "buy it from a vendor nearby" beat "farm a 5% drop".
function R:Effort(t)
  local k = t.kind
  if k == "loot" then
    local need = t.need or 1
    local rate = t.dropRate or ASSUMED_DROP
    if t.dropRate == nil and not t.target then return 0 end -- picked up from objects: no farming
    return need / (rate / 100) * KILL_SECONDS * WALK_YPS
  elseif k == "auction" then
    return AUCTION_SECONDS * WALK_YPS
  elseif k == "buy" then
    return BUY_SECONDS * WALK_YPS
  elseif k == "craft" then
    return CRAFT_SECONDS * WALK_YPS
  end
  return 0
end

--- The part of a task's score that does not depend on where you are: what kind of step it
--- is and how much story it carries. Shared with the planner.
function R:Bonus(t)
  local e = t.quest
  local loreWeight = LW.db.loreWeight or 2
  -- Picking up and handing in weigh the same, so whichever is on your way comes first
  -- (a turn-in bonus used to drag you past quest givers you then had to walk back to).
  -- Objective work ranks slightly behind: gather the hub's quests before heading out.
  local b = (t.kind == "accept" or t.kind == "turnin") and -60 or -30
  b = b + self:Effort(t)
  if t.kind == "flightpoint" then return b - DISCOVER_BONUS end
  if LW.Storylines:For(e) then
    b = b - 80 * loreWeight
  elseif LW.Chains:IsStory(LW.Chains:Get(e.chain)) then
    b = b - 30 * loreWeight
  end
  return b
end

local WALK_YARDS_PER_SECOND = 7
local HERE_YARDS = 40         -- "you are standing next to it" (same building)
local HERE_BONUS = 400        -- finish everything at this spot (turn in, then take the follow-ups) before walking on
local STICKY_BONUS = 75      -- the current step keeps its place unless something is clearly better
local MOVE_THRESHOLD = 12    -- yards moved before the route is re-scored
local LOG_FULL_PENALTY = FAR -- accept steps when your quest log is full

local function byScore(a, b)
  if a.score ~= b.score then return a.score < b.score end
  return a.key < b.key
end

local function logMax()
  return (C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept and C_QuestLog.GetMaxNumQuestsCanAccept())
    or MAX_QUESTS or 20
end
R.LogMax = logMax

local function logIsFull()
  return (LW.Eligibility.logCount or 0) >= logMax()
end

local perMap, grid, byKey, slotBest = {}, {}, {}, {}
local lastX, lastY, lastInst, lastMap

--- Re-score only if you moved, changed zone, or a snooze ran out. Called on a timer.
function R:RouteIfMoved()
  local px, py, pinst = playerWorld()
  local map = LW.PlayerZoneMap()
  if px and lastX and pinst == lastInst and map == lastMap then
    local dx, dy = px - lastX, py - lastY
    if dx * dx + dy * dy < MOVE_THRESHOLD * MOVE_THRESHOLD then
      local expiry = self.nextSnoozeExpiry
      if not (expiry and GetTime() >= expiry) then return end
    end
  end
  if LW.Planner:MovedFar(px, py, pinst) then LW.Planner:Request() end
  self:Route()
end

--- Score and sort the current task list.
--- Nothing to route while you fly or while you are dead: where you are right now is not
--- where you will continue from. The step panel shows what to do instead.
function R:PauseReason()
  if UnitOnTaxi and UnitOnTaxi("player") then return "taxi" end
  if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then return "dead" end
  return nil
end

function R:Route()
  self.paused = self:PauseReason()
  if self.paused then
    LW:Fire("ROUTED", self.current)
    return
  end
  local tasks = LW.Tasks.list
  local px, py, pinst = playerWorld()
  local curMap = LW.PlayerZoneMap()
  lastX, lastY, lastInst, lastMap = px, py, pinst, curMap
  local now = GetTime()
  local fullLog = logIsFull()
  local status = LW.Eligibility.status
  local stickyKey = self.current and self.current.key
  local n = #tasks

  local travel = LW.Travel
  travel:Prepare(px, py, pinst)

  -- Pass 1: nearest point, zone counts, and a grid of where every task is (cell size =
  -- cluster radius), so "how many tasks are near this one" is a 9-cell lookup, not a scan.
  local inZone = 0
  wipe(perMap)
  wipe(grid)
  for i = 1, n do
    local t = tasks[i]
    local point, dist = nearest(t, px, py, pinst)
    t.point, t.dist = point, dist
    t.travel = point and travel:Cost(point) or nil -- seconds, by the fastest way you have
    t.legs = nil
    t.map = point and point.map
    if t.map then
      perMap[t.map] = (perMap[t.map] or 0) + 1
      if t.map == curMap then inZone = inZone + 1 end
    end
    if point and point.wx then
      local cx, cy = math.floor(point.wx / CLUSTER_RADIUS), math.floor(point.wy / CLUSTER_RADIUS)
      local key = (point.inst or 0) * 1e10 + (cx + 50000) * 1e5 + (cy + 50000)
      t.cx, t.cy = cx, cy
      grid[key] = (grid[key] or 0) + 1
    end
  end

  -- Pass 2: score.
  wipe(byKey)
  local pinnedSeen, nextExpiry = false, nil
  for i = 1, n do
    local t = tasks[i]
    local s
    local point = t.point
    if not point then
      -- crafting happens wherever you are; anything else without a location sinks
      s = (t.kind == "craft") and 0 or FAR * 2
    else
      -- travel time, expressed in walking yards so the other weights keep their meaning
      s = (t.travel and t.travel * WALK_YARDS_PER_SECOND) or t.dist or FAR
      t.wTravel, t.wHere, t.wZone, t.wCluster = s, 0, 0, 0
      if t.dist and t.dist <= HERE_YARDS and (t.kind == "accept" or t.kind == "turnin") then
        s = s - HERE_BONUS
        t.wHere = -HERE_BONUS
      end
      if t.map ~= curMap then
        local z = ZONE_PENALTY
        if inZone > 0 then z = z + (((perMap[t.map] or 0) >= 3) and ERRAND_BATCHED or ERRAND_PENALTY) end
        s = s + z
        t.wZone = z
      end
      -- cluster: other tasks close to this one make it a hub worth visiting
      if point.wx then
        local base = (point.inst or 0) * 1e10
        local near = -1 -- don't count this task itself
        for gx = t.cx - 1, t.cx + 1 do
          for gy = t.cy - 1, t.cy + 1 do
            near = near + (grid[base + (gx + 50000) * 1e5 + (gy + 50000)] or 0)
          end
        end
        if near > 6 then near = 6 end
        s = s - near * CLUSTER_BONUS
        t.wCluster = -near * CLUSTER_BONUS
      end
    end
    t.wBonus = self:Bonus(t)
    s = s + t.wBonus
    if t.kind == "accept" and fullLog then s = s + LOG_FULL_PENALTY end
    byKey[t.key] = t
    t.wSticky = 0
    if t.key == stickyKey then s = s - STICKY_BONUS; t.wSticky = -STICKY_BONUS end
    local until_ = self.snoozed[t.key]
    if until_ then
      if until_ > now then
        s = s + FAR * 3
        if not nextExpiry or until_ < nextExpiry then nextExpiry = until_ end
      else
        self.snoozed[t.key] = nil
      end
    end
    if self.pinned == t.key then s = -FAR; pinnedSeen = true end
    t.score = s
  end
  if self.pinned and not pinnedSeen then self.pinned = nil end -- that step is finished
  self.nextSnoozeExpiry = nextExpiry

  -- Ways to get the same item: keep only the cheapest one right now.
  wipe(slotBest)
  for i = 1, n do
    local t = tasks[i]
    if t.slot then
      local b = slotBest[t.slot]
      if not b or t.score < b.score then slotBest[t.slot] = t end
    end
  end
  local ranked = self.ranked
  local m = 0
  for i = 1, n do
    local t = tasks[i]
    if not t.slot or slotBest[t.slot] == t then
      m = m + 1
      ranked[m] = t
    end
  end
  for i = #ranked, m + 1, -1 do ranked[i] = nil end
  table.sort(ranked, byScore)
  self.current = ranked[1]
  -- The lookahead plan decides the step when it has one (and nothing is pinned): it has
  -- already weighed what comes after. Until it does, the single best step stands.
  self.planned = false
  if LW.db.usePlanner and not self.pinned then
    local head = LW.Planner:Head(byKey, self.snoozed)
    local best = ranked[1]
    local atYourFeet = best and best ~= head and best.dist and best.dist <= HERE_YARDS
      and (best.kind == "accept" or best.kind == "turnin")
    if LW.Planner:MovedFar(px, py, pinst) then
      LW.Planner:Request() -- the plan was made somewhere else: don't follow it from here
    elseif atYourFeet then
      LW.Planner:Request() -- something to pick up or hand in right here always comes first
    elseif head and head.point then
      self.current = head
      self.planned = true
    end
  end
  if self.current and self.current.point then self.current.legs = travel:Path(self.current.point) end
  self.logFull = fullLog
  LW:Fire("ROUTED", self.current)
end

--- `/lore why`: why this step? The best few candidates with their score parts, and whether
--- the lookahead plan (not the single best score) chose the current step.
function R:Explain()
  -- Also saved in the diagnostics log, so a /reload afterwards captures it.
  local say = function(...)
    local parts = { ... }
    for i = 1, select("#", ...) do parts[i] = tostring(parts[i]) end
    local text = table.concat(parts, " ")
    LW:Print("|cffffffff[why]|r", text)
    LW:Log("why", "%s", text)
  end
  if self.paused then return say("Routing is paused:", self.paused) end
  local cur = self.current
  if not cur then return say("No current step.") end
  local function parts(t)
    return string.format("score %.0f = travel %.0f (%s yd, %s), zone %+.0f, here %+.0f, cluster %+.0f, bonus/effort %+.0f, sticky %+.0f",
      t.score or 0, t.wTravel or 0, tostring(t.dist and math.floor(t.dist)), LW.Travel.FormatTime(t.travel),
      t.wZone or 0, t.wHere or 0, t.wCluster or 0, t.wBonus or 0, t.wSticky or 0)
  end
  say(string.format("current: %s - %s [%s]", cur.text, cur.quest.name, cur.key))
  say("  " .. parts(cur))
  local best = self.ranked[1]
  if self.planned and best and best ~= cur then
    say(string.format("The lookahead PLAN chose this step. The single best score is: %s - %s [%s]", best.text, best.quest.name, best.key))
    say("  " .. parts(best))
  elseif self.planned then
    say("The plan and the best score agree.")
  else
    say("Planner off or not ready: this is simply the best score.")
  end
  say("next best:")
  for i = 1, math.min(6, #self.ranked) do
    local t = self.ranked[i]
    if t ~= cur then say(string.format("  %d. %s - %s [%s] score %.0f, %s yd", i, t.text, t.quest.name, t.key, t.score or 0, tostring(t.dist and math.floor(t.dist)))) end
  end
  local stops = LW.Planner:Stops()
  if #stops > 0 then
    local first = {}
    for _, st in ipairs(stops[1].steps) do first[#first + 1] = st.task.text .. " [" .. st.task.quest.name .. "]" end
    say("plan, first stop (" .. LW.MapName(stops[1].map) .. "): " .. table.concat(first, "; "))
  end
end

function R:Current() return self.current end

--- Up to n tasks after the current one.
function R:Upcoming(n)
  local out = {}
  for i = 2, math.min(#self.ranked, n + 1) do out[#out + 1] = self.ranked[i] end
  return out
end
