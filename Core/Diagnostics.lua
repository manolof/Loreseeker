-- Diagnostics recorder ("bug catcher"). Everything lands in LorewalkerDB.diag, which the game
-- writes to WTF\Account\<account>\SavedVariables\Lorewalker.lua on /reload or logout, where
-- it can be read and analysed outside the game.
--   errors  - every Lua error whose stack mentions Lorewalker, with stack and context
--   log     - a rolling log of what the addon decided (refreshes, routes, skips, timings)
--   reports - `/lw bug <what happened>` snapshots of your exact situation
local ADDON, LW = ...

local D = {}
LW.Diag = D

local MAX_LOG, MAX_ERRORS, MAX_REPORTS = 400, 100, 50

local function store()
  LorewalkerDB = LorewalkerDB or {}
  local d = LorewalkerDB.diag
  if type(d) ~= "table" then
    d = { log = {}, errors = {}, reports = {} }
    LorewalkerDB.diag = d
  end
  return d
end

local function push(list, item, max)
  list[#list + 1] = item
  while #list > max do table.remove(list, 1) end
end

local function stamp()
  return date("%Y-%m-%d %H:%M:%S")
end

--- Record a line in the rolling log. LW:Log("route", "picked %s", key)
local function clean(v)
  v = LW.NotSecret(v)
  if v == nil then return "<secret>" end
  return v
end

function LW:Log(category, fmt, ...)
  local args = { ... }
  for i = 1, select("#", ...) do args[i] = clean(args[i]) end
  local ok, msg = pcall(string.format, fmt or "", unpack(args, 1, select("#", ...)))
  msg = ok and LW.NotSecret(msg) or tostring(fmt)
  push(store().log, { t = stamp(), c = category, m = msg }, MAX_LOG)
end

local function context()
  local map = LW.PlayerZoneMap and LW.PlayerZoneMap()
  local pos = map and C_Map.GetPlayerMapPosition(map, "player")
  local x, y = 0, 0
  if pos then x, y = pos:GetXY() end
  local cur = LW.Router and LW.Router.current
  return {
    version = LW.version,
    level = UnitLevel("player"),
    zone = LW.NotSecret(GetRealZoneText()),
    subzone = LW.NotSecret(GetSubZoneText()),
    map = map,
    x = math.floor(x * 1000) / 10,
    y = math.floor(y * 1000) / 10,
    step = cur and cur.key or nil,
    stepText = cur and (cur.text .. " - " .. cur.quest.name) or nil,
    counts = LW.Eligibility and LW.Eligibility.counts or nil,
    indexed = LW.Index and #LW.Index.list or nil,
  }
end

function D:RecordError(msg)
  local d = store()
  local text = tostring(LW.NotSecret(msg) or "<secret error message>")
  -- collapse repeats of the same error
  local last = d.errors[#d.errors]
  if last and last.msg == text then
    last.count = (last.count or 1) + 1
    last.last = stamp()
    return
  end
  push(d.errors, { t = stamp(), msg = text, stack = debugstack and debugstack(3) or nil, ctx = context() }, MAX_ERRORS)
end

function D:Report(text)
  local ctx = context()
  ctx.t = stamp()
  ctx.note = LW.NotSecret(text)
  local upcoming = {}
  if LW.Router then
    for _, t in ipairs(LW.Router:Upcoming(5)) do
      upcoming[#upcoming + 1] = string.format("%s | %s - %s | score %.0f", t.key, t.text, t.quest.name, t.score or 0)
    end
  end
  ctx.upcoming = upcoming
  push(store().reports, ctx, MAX_REPORTS)
  LW:Print("Bug report saved. /reload (or log out) to write it to disk.")
end

function D:Clear()
  LorewalkerDB.diag = nil
  store()
  LW:Print("Diagnostics cleared.")
end

-- Chain into the global error handler: record ours, always pass everything on.
function D:Init()
  local d = store()
  d.session = stamp()
  local previous = geterrorhandler()
  seterrorhandler(function(msg, ...)
    local stack = debugstack and debugstack(2) or ""
    local plain = LW.NotSecret(msg)
    if (plain and tostring(plain):find(ADDON, 1, true)) or stack:find(ADDON, 1, true) then
      pcall(D.RecordError, D, msg)
    end
    if previous then return previous(msg, ...) end
  end)
  LW:Log("session", "login %s, client %s", LW.version, (GetBuildInfo()))
end
