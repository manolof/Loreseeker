-- Startup, refresh pipeline, event wiring and slash commands. Loaded last.
local ADDON, LW = ...

---------------------------------------------------------------------------------------------
-- Refresh pipeline: status -> tasks -> route. Collapses bursts of requests into one job.
---------------------------------------------------------------------------------------------

-- Two depths:
--   full  - recompute every quest's status, rebuild tasks, route (login, turn-in, level-up,
--           skips, options)
--   light - the quest log changed. If a quest was added or removed this becomes a full
--           refresh; if only objective progress changed, just the tasks are rebuilt; if
--           nothing changed (QUEST_LOG_UPDATE fires for no reason all the time), nothing runs.
local REFRESH_BUDGET_MS = 3
local pending, wantFull, pendingReason = false, false, nil

local function runRefresh()
  if LW:IsBusy("refresh") then -- one at a time; keep the request and look again shortly
    C_Timer.After(0.25, runRefresh)
    return
  end
  pending = false
  local full, reason = wantFull, pendingReason
  wantFull, pendingReason = false, nil
  local started = debugprofilestop()
  local did
  LW:RunAsync("refresh", function()
    local questsChanged, anyChanged = LW.Eligibility:ReadLog()
    if full or questsChanged then
      LW.Eligibility:Compute()
      LW.Tasks:Build()
      did = "full"
    elseif anyChanged then
      LW.Tasks:Build()
      did = "light"
    end
  end, function()
    if not did then return end
    LW.Router:Route(true)
    local cur = LW.Router.current
    local curKey = cur and cur.key
    if did == "full" or curKey ~= LW.lastLoggedStep then
      local c = LW.Eligibility.counts
      LW:Log("refresh", "%s (%s): %d tasks, now %d, active %d, later %d, group %d, %.0f ms",
        tostring(reason), did, #LW.Tasks.list, c.now or 0, c.active or 0, c.later or 0, c.group or 0,
        debugprofilestop() - started)
    end
    if curKey ~= LW.lastLoggedStep then
      LW.lastLoggedStep = curKey
      if cur then LW:Log("route", "%s | %s - %s | score %.0f", cur.key, cur.text, cur.quest.name, cur.score or 0) end
    end
    LW:Fire("UPDATED")
  end, REFRESH_BUDGET_MS)
end

function LW:RequestRefresh(reason, delay, light)
  if not (self.Index and self.Index.ready) then return end
  if not light then
    wantFull = true
    pendingReason = reason
  elseif not pendingReason then
    pendingReason = reason
  end
  if pending then return end
  pending = true
  C_Timer.After(delay or 0.5, runRefresh)
end

---------------------------------------------------------------------------------------------
-- Startup
---------------------------------------------------------------------------------------------

local function fail(msg)
  LW:Print("|cffff2020" .. msg .. "|r")
  LW:Log("boot", "FAILED: %s", msg)
end

local function start()
  if not LibQuestieDB then return fail("QuestieDB is not loaded.") end
  local ok, msg = LibQuestieDB.RequireContract(4)
  if not ok then return fail(msg) end
  if not LW.Adapter:Init() then
    LW:Print("Questie's internals were not found; availability checks are limited.")
    LW:Log("boot", "adapter init failed")
  end

  LW.Travel:Init()
  LW.Journal:Init()
  LW.StepFrame:Create()
  LW.Arrow:Create()
  LW.Main:Create()
  LW.QuestLogLink:Setup()
  LW.StepFrame:Show(nil)
  LW.StepFrame.frame.title:SetText("Reading the quest library...")

  LW.Adapter:OnReady(function()
    LW.Index:Build(function()
      LW:Log("boot", "index%s: %d of %d quests apply, %d chains, %.0f ms, %d storylines unresolved",
        LW.Index.fromCache and " (from cache)" or "", #LW.Index.list, LW.Index.scanned or 0, #LW.Chains.list,
        LW.Index.buildMs or 0, #LW.Storylines.unresolved)
      LW:Log("boot", "%d missing prerequisites inferred from same-name quests", LW.Index.inferred or 0)
      LW:RequestRefresh("login", 0)
      LW.Skips:CheckRevisits(UnitLevel("player"))
    end)
  end)
  LW.Adapter:OnQuestUpdate(function() LW:RequestRefresh("questie update", nil, true) end)

  -- Re-route as you move (cheap: scoring only).
  C_Timer.NewTicker(2, function()
    if LW.Index.ready and not LW:IsBusy("refresh") then LW.Router:RouteIfMoved() end
  end)
end

LW:OnEvent("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  LW:InitDB()
  LW.Diag:Init()
end)

LW:OnEvent("PLAYER_LOGIN", function()
  local ok, err = pcall(start)
  if not ok then
    LW.Diag:RecordError(err)
    fail("Startup error: " .. tostring(err))
  end
end)

for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE" }) do
  LW:OnEvent(ev, function() LW:RequestRefresh(ev, nil, true) end)
end
LW:OnEvent("QUEST_TURNED_IN", function(_, questId)
  LW:Log("quest", "turned in %s", tostring(questId))
  if type(questId) == "number" then LW.Adapter.turnedIn[questId] = true end -- don't wait for Questie
  -- Fast, so the follow-up quest shows while you are still standing at the NPC...
  LW:RequestRefresh("turned in", 0.3)
  -- ...and once more after Questie has settled, in case it was slow to unlock the follow-up.
  C_Timer.After(2, function() LW:RequestRefresh("turned in (settled)") end)
end)
LW:OnEvent("PLAYER_LEVEL_UP", function(_, level)
  LW:Log("level", "reached %s", tostring(level))
  LW:RequestRefresh("level up", 1.0)
  LW.Skips:CheckRevisits(tonumber(level) or UnitLevel("player"))
end)
LW:OnEvent("ZONE_CHANGED_NEW_AREA", function()
  if LW.Index.ready then LW.Router:Route(true) end
end)

---------------------------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------------------------

local function status()
  local c = LW.Eligibility.counts or {}
  LW:Print(string.format("v%s - %d quests apply to you (%d scanned), %d chains.", LW.version,
    #LW.Index.list, LW.Index.scanned or 0, #LW.Chains.list))
  LW:Print(string.format("done %d, in log %d, available %d, group %d, later %d, locked %d, skipped %d, off %d",
    c.done or 0, c.active or 0, c.now or 0, c.group or 0, c.later or 0, c.locked or 0, c.skipped or 0, c.off or 0))
  LW:Print(string.format("%d routable tasks, %d blocked by skips.", #LW.Tasks.list, #LW.Tasks.blocked))
end

local function questInfo(id)
  id = tonumber(id)
  local e = id and LW.Index:Get(id)
  if not e then
    LW:Print("Quest " .. tostring(id) .. " is not in your index (other faction/class, no starter, or hidden).")
    return
  end
  local chain = LW.Chains:Get(e.chain)
  LW:Print(string.format("%d %s - lvl %d (req %d), %s, zone %s", e.id, e.name, e.level, e.req, e.cat, LW.ZoneName(e.zone)))
  LW:Print(string.format("status %s, doable %s, completed %s", tostring(LW.Eligibility:Status(id)),
    tostring(LW.Adapter:IsDoable(id)), tostring(LW.Adapter:IsCompleted(id))))
  local you = UnitLevel("player")
  local diff = LW.Eligibility:Level(e, you) - you
  LW:Print(string.format("you %d, quest %+d levels (Later from %+d)%s, category %s %s", you, diff, LW.db.deferAt,
    e.noCombat and ", delivery/talk only: 3 extra levels allowed" or "", e.cat,
    LW.Categories:Enabled(e.cat) and "(on)" or "(OFF in Options)"))
  if LW.Eligibility:IsDeadBreadcrumb(e) then
    LW:Print("Breadcrumb: you already have or did a quest from the NPC it sends you to, so the game won't offer it.")
  end
  if e.impliedPre then
    local a = LW.Index:Get(e.impliedPre)
    LW:Print(string.format("Follow-up of %d %s (same name; the database lacks the link): needs that one first.",
      e.impliedPre, a and a.name or "?"))
  end
  local rec = LW.char.notOffered[id]
  if rec then LW:Print(string.format("NPC %d didn't offer it to you at level %d (cleared on level-up or when offered).", rec.npc, rec.level)) end
  local skip = LW.Skips:ForQuest(e)
  if skip then LW:Print("skipped by: " .. LW.Skips:Describe(skip)) end
  if chain then
    LW:Print(string.format("chain: %s (%d quests, step %d)%s", LW.Chains:Name(chain), chain.size, e.depth or 0,
      chain.curated and " - curated" or ""))
  end
end

local HELP = {
  "/lw - open or close the window",
  "/lw step | arrow - toggle the step panel / arrow",
  "/lw status - counts",
  "/lw quest <id> - why a quest has its status",
  "/lw bug <what happened> - save a bug report with your situation",
  "/lw plan - print the planned trip, stop by stop",
  "/lw travel - flight points Lorewalker thinks you know, and the plan for the current step",
  "/lw voice [questId] - test voice-over step by step (default: current step)",
  "/lw check - curated storylines not found for this character",
  "/lw rebuild - rebuild the quest index from QuestieDB (normally automatic)",
  "/lw diag clear - wipe saved diagnostics",
}

SLASH_LOREWALKER1 = "/lw"
SLASH_LOREWALKER2 = "/lorewalker"
SlashCmdList.LOREWALKER = function(input)
  local cmd, rest = (input or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if not LW.Main.frame then return fail("Lorewalker did not start; see /lw bug output after /reload.") end
  if cmd == "" then LW.Main:Toggle()
  elseif cmd == "step" then LW.StepFrame:Toggle()
  elseif cmd == "arrow" then
    LW.db.showArrow = not LW.db.showArrow
    if LW.db.showArrow and LW.Arrow.point then LW.Arrow.frame:Show() else LW.Arrow.frame:Hide() end
  elseif cmd == "status" then status()
  elseif cmd == "quest" then questInfo(rest)
  elseif cmd == "bug" then LW.Diag:Report(rest)
  elseif cmd == "plan" then
    local stops = LW.Planner:Stops()
    LW:Print(#LW.Planner.plan .. " planned steps in " .. #stops .. " stops" .. (LW.Router.planned and "" or " (not in use right now)"))
    for i, stop in ipairs(stops) do
      local parts = {}
      for _, step in ipairs(stop.steps) do parts[#parts + 1] = step.task.text .. " [" .. step.task.quest.name .. "]" end
      LW:Print(i .. ". " .. LW.MapName(stop.map) .. " (" .. LW.Travel.FormatTime(stop.travel) .. "): " .. table.concat(parts, "; "))
    end
  elseif cmd == "travel" then LW.Travel:Report()
  elseif cmd == "voice" then LW.Voice:Diagnose(tonumber(rest))
  elseif cmd == "check" then
    if #LW.Storylines.unresolved == 0 then LW:Print("All curated storylines found.")
    else LW:Print("Not found for this character (other faction is normal): " .. table.concat(LW.Storylines.unresolved, ", ")) end
  elseif cmd == "rebuild" then
    LW.Index:Build(function() LW:RequestRefresh("rebuild", 0) end, true)
    LW:Print("Rebuilding the quest index...")
  elseif cmd == "diag" and rest == "clear" then LW.Diag:Clear()
  elseif cmd == "options" then LW.Main:SelectKey("options")
  else for _, line in ipairs(HELP) do LW:Print(line) end end
end
