-- Loreseeker: namespace, saved variables, events, a tiny message bus and a coroutine runner.
local ADDON, LW = ...
Loreseeker = LW -- global for /dump debugging

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
LW.name = ADDON
LW.version = GetMeta and GetMeta(ADDON, "Version") or "?"
LW.ISSUES = "github.com/manolof/Loreseeker/issues"

---------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------

LW.defaults = {
  categories = {
    general = true,     -- normal world quests
    dungeon = true,     -- dungeon quests (offered as "group up" tasks)
    raid = false,       -- raid and attunement quests
    class = true,       -- your class quests
    profession = true,  -- quests for professions you know
    donation = false,   -- cloth/material donation turn-ins
    repeatable = false, -- repeatable / daily turn-ins
    event = false,      -- seasonal events
    pvp = false,        -- battleground quests
  },
  dungeonRange = 3,  -- dungeon quests count as "now" within this many levels above you
  deferAt = 3,       -- quest level minus your level at which a quest goes to Later (3 = orange, 5 = red)
  loreWeight = 2,    -- 0 (ignore lore) .. 3 (lore first)
  usePlanner = true, -- follow the lookahead plan (off: always take the single best next step)
  useTravel = true,  -- route by travel time (flight paths, boats, tram) instead of straight lines
  showArrow = true,
  showStep = true,
  pvpZones = {},     -- [areaId] = true : contested zones skipped by the PvP preset
}

local charDefaults = {
  skips = {},    -- see Engine\Skips.lua
  journal = {},  -- [questId] = { title, zone, detail, objective, progress, complete, t }
  pinned = {},   -- [dungeon areaId] = true : group-up quests promoted to the main route
  flights = { known = {}, scanned = {} }, -- flight points you know; continents whose flight map was read
  crafts = {},   -- [itemId] = profession : recipes you know (read from your profession window)
  starred = {},  -- [chain root questId] = true : storylines the player marked notable
  notOffered = {}, -- [questId] = { npc, level, t } : the NPC didn't offer it (see Engine\Offers.lua)
  frames = {},   -- saved positions
}

local function fillDefaults(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      fillDefaults(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function LW:InitDB()
  LoreseekerDB = LoreseekerDB or {}
  LoreseekerDB.profile = LoreseekerDB.profile or {}
  fillDefaults(LoreseekerDB.profile, self.defaults)
  self.db = LoreseekerDB.profile

  LoreseekerCharDB = LoreseekerCharDB or {}
  fillDefaults(LoreseekerCharDB, charDefaults)
  self.char = LoreseekerCharDB
end

---------------------------------------------------------------------------------------------
-- Output
---------------------------------------------------------------------------------------------

function LW:Print(...)
  local parts = { ... }
  for i = 1, select("#", ...) do parts[i] = tostring(parts[i]) end
  DEFAULT_CHAT_FRAME:AddMessage(NORMAL_FONT_COLOR_CODE .. "Loreseeker:|r " .. table.concat(parts, " "))
end

---------------------------------------------------------------------------------------------
-- Game events and internal messages
---------------------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local eventHandlers = {}
eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = eventHandlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok then geterrorhandler()(err) end
  end
end)

function LW:OnEvent(event, fn)
  if not eventHandlers[event] then
    eventHandlers[event] = {}
    eventFrame:RegisterEvent(event)
  end
  table.insert(eventHandlers[event], fn)
end

local listeners = {}
function LW:Listen(message, fn)
  listeners[message] = listeners[message] or {}
  table.insert(listeners[message], fn)
end

function LW:Fire(message, ...)
  local list = listeners[message]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok then geterrorhandler()(err) end
  end
end

---------------------------------------------------------------------------------------------
-- Coroutine runner: long scans spread over frames so the client never freezes.
---------------------------------------------------------------------------------------------

local DEFAULT_BUDGET_MS = 8
local BUDGET_MS = DEFAULT_BUDGET_MS
local jobs = {}
local runner = CreateFrame("Frame")
local sliceStart = 0

--- Call inside a job; yields when this frame's time budget is used up.
--- Safe to call outside a job too (it then does nothing).
function LW.Yield()
  if debugprofilestop() - sliceStart > BUDGET_MS then
    local co, isMain = coroutine.running()
    if co and not isMain then coroutine.yield() end
  end
end

local function step()
  local job = jobs[1]
  if not job then
    runner:SetScript("OnUpdate", nil)
    return
  end
  sliceStart = debugprofilestop()
  BUDGET_MS = job.budget or DEFAULT_BUDGET_MS
  local ok, err = coroutine.resume(job.co)
  if not ok then
    table.remove(jobs, 1)
    geterrorhandler()(err)
  elseif coroutine.status(job.co) == "dead" then
    table.remove(jobs, 1)
    if job.done then
      local ok2, err2 = pcall(job.done)
      if not ok2 then geterrorhandler()(err2) end
    end
  end
end

--- Run fn as a background job (jobs run one at a time, in order). `key` names it for IsBusy.
--- `budget` is the milliseconds of work allowed per frame (default 8; gameplay-time jobs
--- pass less so they are invisible).
function LW:RunAsync(key, fn, done, budget)
  table.insert(jobs, { key = key, co = coroutine.create(fn), done = done, budget = budget })
  runner:SetScript("OnUpdate", step)
end

function LW:IsBusy(key)
  for i = 1, #jobs do
    if jobs[i].key == key then return true end
  end
  return false
end

---------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------

--- Bit test with arithmetic: race masks use bits 32/33 (Skyborne), beyond bit.band's 32 bits.
function LW.HasBit(mask, flag)
  if not mask or mask == 0 or not flag then return false end
  return (mask % (flag * 2)) >= flag
end

--- Forever hands addons some values as "secrets" (in combat/instances). Storing one in
--- SavedVariables can stop the whole file from being written, so read every game string
--- through this: a secret becomes nil.
function LW.NotSecret(v)
  local isSecret = rawget(_G, "issecretvalue")
  if isSecret and isSecret(v) then return nil end
  return v
end

function LW.Trim(s)
  return (s and s:gsub("^%s+", ""):gsub("%s+$", "")) or ""
end

--- Parse "some note @30" into ("some note", 30).
function LW.ParseNote(text)
  text = text or ""
  local level = tonumber(text:match("@%s*(%d+)"))
  local note = LW.Trim(text:gsub("@%s*%d+", ""))
  return note, level
end

function LW.ZoneName(areaId)
  if not areaId then return "?" end
  local name = C_Map.GetAreaInfo and C_Map.GetAreaInfo(areaId)
  if (not name or name == "") and LW.Adapter then name = LW.Adapter:DungeonName(areaId) end
  return name or ("Area " .. areaId)
end

function LW.MapName(uiMap)
  local info = uiMap and C_Map.GetMapInfo(uiMap)
  return info and info.name or "?"
end

--- The player's zone-level uiMap (walks up from dungeon/micro maps).
function LW.PlayerZoneMap()
  local map = C_Map.GetBestMapForUnit("player")
  local guard = 0
  while map and guard < 6 do
    local info = C_Map.GetMapInfo(map)
    -- mapType: 3 = zone; 4+ = dungeon/micro/orphan maps that sit below a zone
    if not info or info.mapType <= 3 or not info.parentMapID or info.parentMapID == 0 then break end
    map = info.parentMapID
    guard = guard + 1
  end
  return map
end
