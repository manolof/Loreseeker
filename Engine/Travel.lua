-- Travel model: how long it really takes to get somewhere, in seconds.
--   walk      straight line with a detour factor, at foot or (level 40+) mount speed
--   fly       walk to the nearest flight master YOU KNOW, fly, walk from the landing point
--   transport boats, zeppelins, the Deeprun Tram (ride time plus an average wait)
-- Each routing pass runs one small shortest-path search from the player over the transport
-- endpoints (about a dozen nodes); every task then costs a handful of arithmetic operations.
--
-- Known flight points are read from the flight map whenever you open one. Until a continent's
-- flight map has been seen once, a flight point counts as known if it is in a capital of
-- your faction or in a zone where you have finished at least three quests.
local _, LW = ...
local L = LW.L

local TR = { version = 1, ready = false }
LW.Travel = TR

local HBD = LibStub and LibStub("HereBeDragons-2.0", true)

local WALK_SPEED, MOUNT_SPEED, FLY_SPEED = 7, 11.2, 32 -- yards per second
local WALK_DETOUR, FLY_DETOUR = 1.25, 1.15             -- roads bend; flight paths bend less
local FLY_OVERHEAD = 20                                -- talk, take off, land
local MOUNT_LEVEL = 40
local CAPITALS = { [1537] = true, [1519] = true, [1657] = true, [1637] = true, [1497] = true, [1638] = true }
local KIND_VERB = { boat = L["Take the boat from %s to %s"], zeppelin = L["Take the zeppelin from %s to %s"], tram = L["Ride the Deeprun Tram from %s to %s"], portal = L["Take the portal from %s to %s"] }

local fms = {}    -- flight masters for this faction: { npc, name, area, map, x, y, wx, wy, inst, zone }
local nodes = {}  -- transport endpoints: { map, x, y, wx, wy, inst, label, partner, transport }
local walkSpeed = WALK_SPEED

local function resolve(area, x, y)
  local map = LW.Adapter:UiMap(area)
  if not (map and HBD) then return nil end
  local wx, wy, inst = HBD:GetWorldCoordinatesFromZone(x / 100, y / 100, map)
  if not wx then return nil end
  return { map = map, x = x / 100, y = y / 100, wx = wx, wy = wy, inst = inst, area = area }
end

function TR:Init()
  local data = LW.TravelData
  if not (data and HBD) then return end
  local faction = UnitFactionGroup("player") == "Horde" and "H" or "A"
  wipe(fms); wipe(nodes)
  for _, f in ipairs(data.flightMasters) do
    if f[6]:find(faction, 1, true) then
      local p = resolve(f[3], f[4], f[5])
      if p then
        p.npc, p.name = f[1], f[2]
        p.zone = C_Map.GetAreaInfo(f[3]) or ""
        fms[#fms + 1] = p
      end
    end
  end
  for _, t in ipairs(data.transports) do
    if t.faction:find(faction, 1, true) then
      local a, b = resolve(t.a[1], t.a[2], t.a[3]), resolve(t.b[1], t.b[2], t.b[3])
      if a and b then
        a.label, b.label = t.a[4], t.b[4]
        a.partner, b.partner = b, a
        a.transport, b.transport = t, t
        nodes[#nodes + 1] = a
        nodes[#nodes + 1] = b
      end
    end
  end
  self.ready = #fms > 0
  LW:Log("travel", "%d flight masters, %d transport endpoints for faction %s", #fms, #nodes, faction)
end

---------------------------------------------------------------------------------------------
-- Known flight points
---------------------------------------------------------------------------------------------

local zoneDone -- [areaId] = finished quests there (for the L["probably known"] guess)

local function store() return LW.char.flights end

function TR:IsKnown(fm)
  local s = store()
  if s.scanned[fm.inst] then return s.known[fm.npc] and true or false end
  if s.known[fm.npc] or CAPITALS[fm.area] then return true end
  return zoneDone and (zoneDone[fm.area] or 0) >= 3 or false
end

local function recountZones()
  zoneDone = {}
  for _, e in ipairs(LW.Index.list) do
    if e.zone and LW.Eligibility:Status(e.id) == "done" then zoneDone[e.zone] = (zoneDone[e.zone] or 0) + 1 end
  end
  TR.version = TR.version + 1
end

-- The flight map's node names look like "Menethil Harbor, Wetlands".
local function matchNode(name, inst)
  name = LW.NotSecret(name)
  if type(name) ~= "string" then return nil end
  local place, zone = name:match("^(.-),%s*(.+)$")
  place = place or name
  local byZone, byPlace
  for _, fm in ipairs(fms) do
    if fm.inst == inst then
      if zone and fm.zone == zone then byZone = fm end
      if fm.zone ~= "" and (fm.zone:find(place, 1, true) or place:find(fm.zone, 1, true)) then byPlace = fm end
    end
  end
  return byPlace or byZone
end

-- The continent map the flight map is drawn on (mapType 2), from where you stand.
local function continentMap()
  local map = C_Map.GetBestMapForUnit("player")
  local guard = 0
  while map and guard < 8 do
    local info = C_Map.GetMapInfo(map)
    if not info then return nil end
    if info.mapType == 2 then return map end
    map = info.parentMapID
    guard = guard + 1
  end
  return nil
end

-- Every node on the open flight map: name, known/current, and its position on the continent
-- map (0-1) when the client tells us. Position works in every language; the name is only a
-- fallback (it is localized, e.g. "Menethil Harbor, Wetlands").
local function taxiNodes()
  local out = {}
  local continent = continentMap()
  if C_TaxiMap and C_TaxiMap.GetAllTaxiNodes and continent then
    for _, n in ipairs(C_TaxiMap.GetAllTaxiNodes(continent) or {}) do
      local x, y
      if n.position then
        if n.position.GetXY then x, y = n.position:GetXY() else x, y = n.position.x, n.position.y end
      end
      out[#out + 1] = { name = n.name, x = x, y = y, map = continent,
        known = n.state == 0 or n.state == 1, current = n.state == 0 }
    end
    if #out > 0 then return out end
  end
  if NumTaxiNodes and TaxiNodeGetType then
    for i = 1, NumTaxiNodes() do
      local kind = TaxiNodeGetType(i)
      local x, y
      if TaxiNodePosition then x, y = TaxiNodePosition(i) end
      out[#out + 1] = { name = TaxiNodeName and TaxiNodeName(i), x = x, y = y, map = continent,
        known = kind == "CURRENT" or kind == "REACHABLE", current = kind == "CURRENT" }
    end
  end
  return out
end

local MATCH_YARDS = 250 -- a flight master within this distance of a map node is that node

-- The flight master at a flight-map node, by position.
local function matchByPosition(n, inst)
  if not (n.x and n.y and n.map and HBD) then return nil end
  local wx, wy, ninst = HBD:GetWorldCoordinatesFromZone(n.x, n.y, n.map)
  if not wx or ninst ~= inst then return nil end
  local best, bestD
  for _, fm in ipairs(fms) do
    if fm.inst == inst then
      local dx, dy = fm.wx - wx, fm.wy - wy
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then best, bestD = fm, d end
    end
  end
  if best and bestD <= MATCH_YARDS * MATCH_YARDS then return best end
  return nil
end

local function nearestFm(wx, wy, inst, knownOnly)
  local best, bestD
  for _, fm in ipairs(fms) do
    if fm.inst == inst and (not knownOnly or TR:IsKnown(fm)) then
      local dx, dy = fm.wx - wx, fm.wy - wy
      local d = dx * dx + dy * dy
      if not bestD or d < bestD then best, bestD = fm, d end
    end
  end
  return best, bestD and math.sqrt(bestD)
end

function TR:ScanTaxiMap()
  if not self.ready then return end
  local px, py, pinst = HBD:GetPlayerWorldPosition()
  if not px then return end
  local found, matched, byPos = {}, 0, 0
  for _, n in ipairs(taxiNodes()) do
    if n.known then
      local fm = n.current and nearestFm(px, py, pinst, false)
      if not fm then
        fm = matchByPosition(n, pinst)
        if fm then byPos = byPos + 1 end
      end
      fm = fm or matchNode(n.name, pinst)
      if fm then found[fm.npc] = true; matched = matched + 1 end
    end
  end
  if matched == 0 then
    LW:Log("travel", "flight map opened but no nodes could be read")
    return
  end
  local s = store()
  for _, fm in ipairs(fms) do
    if fm.inst == pinst then s.known[fm.npc] = found[fm.npc] or nil end
  end
  s.scanned[pinst] = true
  self.version = self.version + 1
  LW:Log("travel", "flight map read: %d known flight points on this continent (%d matched by position)", matched, byPos)
  LW.Router:Route()
end

---------------------------------------------------------------------------------------------
-- Costs
---------------------------------------------------------------------------------------------

local function dist(a, b)
  local dx, dy = a.wx - b.wx, a.wy - b.wy
  return math.sqrt(dx * dx + dy * dy)
end

-- Nearest known flight master to a place, cached on the place until the known set changes.
local function fmOf(p)
  if p.fmv ~= TR.version then
    p.fmv = TR.version
    p.fm, p.fmd = nearestFm(p.wx, p.wy, p.inst, true)
  end
  return p.fm, p.fmd
end

--- Same-continent travel a -> b: seconds, and the flight used (from, to) if flying is faster.
local function localTime(a, b)
  if a.inst ~= b.inst then return nil end
  local walk = dist(a, b) * WALK_DETOUR / walkSpeed
  local af, afd = fmOf(a)
  local bf, bfd = fmOf(b)
  if af and bf and af ~= bf then
    local fly = afd * WALK_DETOUR / walkSpeed + dist(af, bf) * FLY_DETOUR / FLY_SPEED + FLY_OVERHEAD
      + bfd * WALK_DETOUR / walkSpeed
    if fly < walk then return fly, af, bf end
  end
  return walk
end

local source = { wx = 0, wy = 0, inst = -1 }
local cost, how = {}, {} -- per node index: seconds from the player; how = { prev, flyFrom, flyTo, ride }

--- Call once per routing pass with the player's world position.
function TR:Prepare(px, py, pinst)
  self.usable = false
  if not (self.ready and px and LW.db.useTravel) then return end
  local speed = UnitLevel("player") >= MOUNT_LEVEL and MOUNT_SPEED or WALK_SPEED
  if speed ~= walkSpeed then
    walkSpeed = speed
    self.version = self.version + 1 -- cached times were computed at the old speed
  end
  source.wx, source.wy, source.inst, source.fmv = px, py, pinst, nil
  local n = #nodes
  local done = {}
  for i = 1, n do
    local t, ff, ft = localTime(source, nodes[i])
    cost[i] = t or math.huge
    how[i] = { prev = 0, flyFrom = ff, flyTo = ft }
    done[i] = false
  end
  for _ = 1, n do -- Dijkstra over a dozen nodes
    local u, best = nil, math.huge
    for i = 1, n do if not done[i] and cost[i] < best then u, best = i, cost[i] end end
    if not u then break end
    done[u] = true
    local nu = nodes[u]
    for v = 1, n do
      if not done[v] then
        local nv = nodes[v]
        local t, ff, ft, ride
        if nu.partner == nv then
          t, ride = nu.transport.seconds, true
        else
          t, ff, ft = localTime(nu, nv)
        end
        if t and best + t < cost[v] then
          cost[v] = best + t
          how[v] = { prev = u, flyFrom = ff, flyTo = ft, ride = ride }
        end
      end
    end
  end
  self.usable = true
end

--- Seconds from the player to a point (after Prepare). Second result: the transport endpoint
--- you arrive through, or nil when it is reached directly.
function TR:Cost(p)
  if not (self.usable and p and p.wx) then return nil end
  local best = localTime(source, p)
  -- Time from each transport endpoint to this point never changes (until your flight points
  -- or speed do), so it is worked out once per point and then only read.
  local nt = p.nt
  if p.ntv ~= self.version then
    nt = nt or {}
    for i = 1, #nodes do nt[i] = localTime(nodes[i], p) or false end
    p.nt, p.ntv = nt, self.version
  end
  local via
  for i = 1, #nodes do
    local t = nt[i]
    if t then
      local total = cost[i] + t
      if not best or total < best then best, via = total, i end
    end
  end
  return best, via
end

local function flyLeg(from, to)
  return { kind = "fly", at = from, text = string.format(L["Fly from %s to %s"], from.zone, to.zone),
    hint = string.format(L["Talk to %s"], from.name) }
end

--- The travel legs to a point, in order ({} when you simply walk there). Each leg has
--- `at` (where to go to start it: a flight master or a dock) and `text`.
function TR:Path(p)
  local legs = {}
  if not (self.usable and p and p.wx) then return legs end
  local _, via = self:Cost(p)
  local chain = {}
  local i = via
  while i and i > 0 do
    table.insert(chain, 1, i)
    i = how[i].prev
  end
  for _, idx in ipairs(chain) do
    local h, node = how[idx], nodes[idx]
    if h.ride then
      local from = node.partner
      legs[#legs + 1] = { kind = node.transport.kind, at = from,
        text = string.format(KIND_VERB[node.transport.kind] or L["Travel from %s to %s"], from.label, node.label) }
    elseif h.flyFrom then
      legs[#legs + 1] = flyLeg(h.flyFrom, h.flyTo)
    end
  end
  local last = via and nodes[via] or source
  local _, ff, ft = localTime(last, p)
  if ff then legs[#legs + 1] = flyLeg(ff, ft) end
  return legs
end

function TR.FormatTime(seconds)
  if not seconds then return "" end
  if seconds < 90 then return string.format(L["%d sec"], math.floor(seconds + 0.5)) end
  return string.format(L["%d min"], math.floor(seconds / 60 + 0.5))
end

---------------------------------------------------------------------------------------------
-- Wiring and debug
---------------------------------------------------------------------------------------------

LW:OnEvent("TAXIMAP_OPENED", function()
  local ok, err = pcall(TR.ScanTaxiMap, TR)
  if not ok then LW:Log("travel", "scan failed: %s", tostring(err)) end
end)
LW:Listen("UPDATED", function() if TR.ready then recountZones() end end)

--- `/lore travel`: what Loreseeker believes about your flight points, and the current plan.
function TR:Report()
  if not self.ready then return LW:Print(L["Travel model not available."]) end
  local s = store()
  local known, total, exact = {}, 0, 0
  for _, fm in ipairs(fms) do
    total = total + 1
    if self:IsKnown(fm) then known[#known + 1] = fm.zone end
    if s.scanned[fm.inst] then exact = exact + 1 end
  end
  table.sort(known)
  LW:Print(string.format(L["%d of %d flight points count as known (%s): %s"], #known, total,
    exact == total and L["read from your flight maps"] or L["partly guessed until you open a flight map on each continent"],
    table.concat(known, ", ")))
  local cur = LW.Router.current
  if cur and cur.point then
    local t = self:Cost(cur.point)
    local legs = self:Path(cur.point)
    local parts = {}
    for _, leg in ipairs(legs) do parts[#parts + 1] = leg.text end
    LW:Print(string.format(L["Current step: %s away. %s"], self.FormatTime(t), #parts > 0 and table.concat(parts, L[", then "]) or L["Walk there."]))
  end
end
