-- Lookahead planner. The router scores one step at a time; this plans a whole trip.
--
-- It simulates walking the route: take a step, move to where that step happens, see what
-- that changes (accepting a quest adds its objectives; finishing a quest's last objective
-- adds its turn-in), and choose again from there. It tries each of the router's best few
-- first steps this way and keeps the one whose next several steps cost the least in total,
-- then extends that into a plan of up to 16 steps.
--
-- The plan is what the guide follows and shows. Steps close together form a "stop", which
-- is how "on the way" appears: everything to do at one place is listed together.
--
-- Runs as a background job (a few milliseconds spread over frames), after each refresh and
-- when you have moved well away from where the last plan was made.
local _, LW = ...

local P = { plan = {}, stamp = 0 }
LW.Planner = P

local PLAN_STEPS = 16      -- length of the plan shown
local ROLLOUT_STEPS = 8    -- how far each candidate first step is looked ahead
local CANDIDATES = 3       -- how many first steps are tried
local POOL = 60            -- only the router's best tasks take part (the rest are far away)
local STOP_YARDS = 80      -- steps this close together are one stop
local REPLAN_YARDS = 120   -- moved this far from where the plan was made: plan again
local WALK = 7
local FAR = 100000
local ZONE_PENALTY, ERRAND_PENALTY, ERRAND_BATCHED = 600, 4000, 800
local HERE_YARDS, HERE_BONUS = 25, 400
local OBJECTIVE = { kill = true, loot = true, object = true, buy = true, auction = true, craft = true,
  explore = true, generic = true }

local function nearestTo(task, pos)
  local best, bestD
  local points = task.points
  for i = 1, #points do
    local p = points[i]
    local wx, wy, inst = LW.Router.WorldOf(p)
    if wx and inst == pos.inst then
      local dx, dy = wx - pos.wx, wy - pos.wy
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then best, bestD = p, d end
    elseif not best then
      best = p
    end
  end
  return best, bestD and math.sqrt(bestD)
end

-- One "slot" per thing a quest asks for: the ways to get one item (drop, vendor, auction
-- house, craft) share a slot, and doing one settles them all.
local function slotOf(t) return t.slot or t.key end

local function countSlots(tasks, questId)
  local seen, n = {}, 0
  for _, t in ipairs(tasks) do
    if OBJECTIVE[t.kind] and (not questId or t.quest.id == questId) and (#t.points > 0 or t.kind == "craft") then
      local slot = slotOf(t)
      if not seen[slot] then seen[slot] = true; n = n + 1 end
    end
  end
  return n
end

--- Simulate `depth` steps starting from `start` with `first` forced as the first step.
--- Returns the steps and their total score. Yields between steps.
local function simulate(pool, first, depth, start, logCount, logMax, objectivesLeft)
  local travel, router = LW.Travel, LW.Router
  local remaining, inPool = {}, {}
  for i = 1, #pool do remaining[i] = pool[i]; inPool[pool[i].key] = true end
  local left = {}
  for q, n in pairs(objectivesLeft) do left[q] = n end
  local pos = { wx = start.wx, wy = start.wy, inst = start.inst, map = start.map }
  local steps, total = {}, 0
  local perMap = {}

  for stepNo = 1, depth do
    if #remaining == 0 then break end
    travel:Prepare(pos.wx, pos.wy, pos.inst)
    -- where each remaining task would be done from here, and how many are in this zone
    for k in pairs(perMap) do perMap[k] = nil end
    local inZone = 0
    for i = 1, #remaining do
      local t = remaining[i]
      local point, dist = nearestTo(t, pos)
      t.simPoint, t.simDist = point, dist
      if point then
        perMap[point.map] = (perMap[point.map] or 0) + 1
        if point.map == pos.map then inZone = inZone + 1 end
      end
    end
    local pick, pickScore, pickTravel
    for i = 1, #remaining do
      local t = remaining[i]
      local point = t.simPoint
      if point then
        local secs = travel:Cost(point)
        local s = (secs and secs * WALK) or t.simDist or FAR
        if t.simDist and t.simDist <= HERE_YARDS and (t.kind == "accept" or t.kind == "turnin") then s = s - HERE_BONUS end
        if point.map ~= pos.map then
          s = s + ZONE_PENALTY
          if inZone > 0 then s = s + (((perMap[point.map] or 0) >= 3) and ERRAND_BATCHED or ERRAND_PENALTY) end
        end
        s = s + router:Bonus(t)
        if t.kind == "accept" and logCount >= logMax then s = s + FAR end
        if stepNo == 1 and first then
          if t == first then pick, pickScore, pickTravel = t, s, secs end
        elseif not pickScore or s < pickScore then
          pick, pickScore, pickTravel = t, s, secs
        end
      end
    end
    if not pick then break end

    local point = pick.simPoint
    steps[#steps + 1] = { key = pick.key, task = pick, point = point, travel = pickTravel, preview = pick.preview }
    total = total + pickScore
    if point.wx then pos.wx, pos.wy, pos.inst, pos.map = point.wx, point.wy, point.inst, point.map end

    -- remove it (and the other way to get the same item)
    local slot = slotOf(pick)
    for i = #remaining, 1, -1 do
      if remaining[i] == pick or slotOf(remaining[i]) == slot then table.remove(remaining, i) end
    end

    -- what doing it changes
    local e = pick.quest
    local function add(list)
      for _, t in ipairs(list) do
        if not inPool[t.key] and #t.points > 0 then
          inPool[t.key] = true
          remaining[#remaining + 1] = t
        end
      end
    end
    if pick.kind == "accept" then
      logCount = logCount + 1
      local objectives = LW.Tasks:Preview(e)
      local n = countSlots(objectives)
      if n > 0 then
        left[e.id] = n
        add(objectives)
      else
        add(LW.Tasks:PreviewTurnin(e))
      end
    elseif pick.kind == "turnin" then
      logCount = logCount - 1
    elseif OBJECTIVE[pick.kind] and left[e.id] then
      left[e.id] = left[e.id] - 1
      if left[e.id] <= 0 then
        left[e.id] = nil
        add(LW.Tasks:PreviewTurnin(e))
      end
    end
    LW.Yield()
  end
  return steps, total
end

local function buildPlan()
  local router = LW.Router
  local ranked = router.ranked
  local px, py, pinst = router.PlayerWorld()
  if not px or #ranked == 0 then return {} end
  local start = { wx = px, wy = py, inst = pinst, map = LW.PlayerZoneMap() }

  local pool = {}
  for i = 1, #ranked do
    local t = ranked[i]
    if #t.points > 0 and (t.score or FAR) < FAR then pool[#pool + 1] = t end
    if #pool >= POOL then break end
  end
  if #pool == 0 then return {} end

  -- objective tasks still open per quest in your log (all of them, not just the pool: a
  -- turn-in is only planned once every objective has been)
  local objectivesLeft, seen = {}, {}
  for _, t in ipairs(LW.Tasks.list) do
    if OBJECTIVE[t.kind] then
      local slot = slotOf(t)
      if not seen[slot] then
        seen[slot] = true
        -- a located objective counts once; one with no known location can never be planned,
        -- so it keeps the turn-in out of the plan (count it as one that is never done)
        objectivesLeft[t.quest.id] = (objectivesLeft[t.quest.id] or 0) + 1
      end
    end
  end
  local logCount, logMax = LW.Eligibility.logCount or 0, router.LogMax()

  local bestFirst, bestTotal
  for c = 1, math.min(CANDIDATES, #pool) do
    local _, total = simulate(pool, pool[c], ROLLOUT_STEPS, start, logCount, logMax, objectivesLeft)
    if not bestTotal or total < bestTotal then bestFirst, bestTotal = pool[c], total end
    if router.pinned then break end -- a pinned step is the first step; nothing to compare
  end
  local steps = simulate(pool, bestFirst, PLAN_STEPS, start, logCount, logMax, objectivesLeft)
  return steps, start
end

---------------------------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------------------------

local pending = false

function P:Request()
  if pending or not LW.Index.ready then return end
  pending = true
  C_Timer.After(0.1, function()
    if LW:IsBusy("plan") or LW:IsBusy("refresh") then
      pending = false
      C_Timer.After(0.5, function() P:Request() end)
      return
    end
    local started = debugprofilestop()
    local steps, start
    local tasksAtStart = LW.Tasks.list
    LW:RunAsync("plan", function()
      steps, start = buildPlan()
    end, function()
      pending = false
      if LW.Tasks.list ~= tasksAtStart then return P:Request() end -- the world changed meanwhile
      P.plan = steps or {}
      P.origin = start
      P.stamp = P.stamp + 1
      if not P.loggedOnce or P.plan[1] and P.plan[1].key ~= P.lastHead then
        P.loggedOnce, P.lastHead = true, P.plan[1] and P.plan[1].key
        LW:Log("plan", "%d steps in %.0f ms, first %s", #P.plan, debugprofilestop() - started, tostring(P.lastHead))
      end
      LW.Router:Route() -- puts the travel model back on your real position and applies the plan
      LW:Fire("PLANNED")
    end, 3)
  end)
end

function P:Invalidate()
  self.plan = {}
  self:Request()
end

--- Called by the router with the live tasks by key. Drops finished steps from the front of
--- the plan and returns the live task for the first step still to do (or nil).
function P:Head(byKey, snoozed)
  local plan = self.plan
  local dropped = false
  while plan[1] and not plan[1].preview and not byKey[plan[1].key] do
    table.remove(plan, 1) -- done, or no longer on offer
    dropped = true
  end
  -- a simulated step ("after you accept X") became real once its key exists
  if plan[1] and plan[1].preview and byKey[plan[1].key] then plan[1].preview = nil end
  if dropped then self:Request() end
  local head = plan[1]
  if not head or head.preview or (snoozed and snoozed[head.key]) then return nil end
  return byKey[head.key]
end

function P:MovedFar(px, py, pinst)
  local o = self.origin
  if not (o and px) then return false end
  if o.inst ~= pinst then return true end
  local dx, dy = px - o.wx, py - o.wy
  return dx * dx + dy * dy > REPLAN_YARDS * REPLAN_YARDS
end

--- The plan grouped into stops: { { steps = {...}, map = uiMap, travel = seconds to get there } }
function P:Stops()
  local stops = {}
  local last
  for _, step in ipairs(self.plan) do
    local p = step.point
    local sameStop = false
    if last and p.wx and last.wx and p.inst == last.inst then
      local dx, dy = p.wx - last.wx, p.wy - last.wy
      sameStop = dx * dx + dy * dy <= STOP_YARDS * STOP_YARDS
    end
    if sameStop then
      table.insert(stops[#stops].steps, step)
    else
      stops[#stops + 1] = { steps = { step }, map = p.map, travel = step.travel }
    end
    last = p
  end
  return stops
end

--- How many more steps the plan has at the first stop, after the current one.
function P:MoreHere()
  local stops = self:Stops()
  return stops[1] and (#stops[1].steps - 1) or 0
end

-- Plan again only when the set of tasks changed (progress on an objective does not).
local lastSignature
LW:Listen("UPDATED", function()
  local keys = {}
  for i, t in ipairs(LW.Tasks.list) do keys[i] = t.key end
  local signature = table.concat(keys, "|")
  if signature ~= lastSignature or #P.plan == 0 then
    lastSignature = signature
    P:Request()
  end
end)
