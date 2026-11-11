-- Reality check against the quest database. When you talk to an NPC, compare what it actually
-- offers with what the database says it should offer you right now. A quest it should offer
-- but doesn't is marked "not offered" (Forever changed it, or the data is wrong): it leaves the
-- route and waits in the Revisit tab. It clears itself the moment that NPC offers it, or
-- after you level up (prerequisites may have changed).
local _, LW = ...

local O = {}
LW.Offers = O

local function notOffered() return LW.char.notOffered end

local function npcId()
  local guid = LW.NotSecret(UnitGUID("npc"))
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  if kind ~= "Creature" then return nil end
  return tonumber(id)
end

-- Quest IDs (or titles) the open dialog offers.
local function offeredNow(event)
  local ids, titles = {}, {}
  if event == "QUEST_DETAIL" then
    local id = LW.NotSecret(GetQuestID and GetQuestID())
    if id and id > 0 then ids[id] = true end
    return ids, titles
  end
  if event == "GOSSIP_SHOW" and C_GossipInfo and C_GossipInfo.GetAvailableQuests then
    for _, q in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do
      if q.questID then ids[q.questID] = true end
      if q.title then titles[q.title] = true end
    end
  elseif event == "QUEST_GREETING" and GetNumAvailableQuests then
    for i = 1, GetNumAvailableQuests() do
      local id = GetAvailableQuestInfo and select(5, GetAvailableQuestInfo(i))
      if id then ids[id] = true end
      local title = GetAvailableTitle and GetAvailableTitle(i)
      if title then titles[title] = true end
    end
  end
  return ids, titles
end

local function isTrivial(e)
  -- The game hides grey quests unless "Low-Level Quests" tracking is on: never judge those.
  local c = GetQuestDifficultyColor and GetQuestDifficultyColor(LW.Eligibility:Level(e))
  return c and QuestDifficultyColors and c == QuestDifficultyColors.trivial
end

-- Asked live, not from our last refresh: right after you accept a quest the dialog reopens
-- without it, before Loreseeker has caught up, and that must not read as "not offered".
local recentlyAccepted = {} -- [questId] = GetTime()
local function haveQuest(qid)
  if recentlyAccepted[qid] and GetTime() - recentlyAccepted[qid] < 30 then return true end
  if C_QuestLog and C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(qid) and true or false end
  if GetQuestLogIndexByID then return (GetQuestLogIndexByID(qid) or 0) > 0 end
  return LW.Eligibility.log[qid] ~= nil
end

LW:OnEvent("QUEST_ACCEPTED", function(_, a, b)
  local qid = (type(b) == "number" and b) or (type(a) == "number" and a) or nil
  if not qid then return end
  recentlyAccepted[qid] = GetTime()
  if LW.char and LW.char.notOffered[qid] then
    LW.char.notOffered[qid] = nil
    LW:Log("offers", "%d was accepted after all: cleared", qid)
  end
end)

local function check(event)
  if not LW.Index.ready then return end
  local npc = npcId()
  if not npc then return end
  local starts = LW.NotSecret(LibQuestieDB.Npc.Get(npc, "questStarts"))
  if type(starts) ~= "table" then return end
  local ids, titles = offeredNow(event)
  local changed = false
  for _, qid in ipairs(starts) do
    local e = LW.Index:Get(qid)
    if e then
      local offered = ids[qid] or titles[e.name]
      local status = LW.Eligibility:Status(qid)
      if offered then
        if notOffered()[qid] then
          notOffered()[qid] = nil
          changed = true
          LW:Log("offers", "%d %s is offered again by npc %d", qid, e.name, npc)
        end
      elseif (status == "now" or status == "group") and event ~= "QUEST_DETAIL" and not isTrivial(e)
        and not haveQuest(qid) and not LW.Adapter:IsCompleted(qid) then
        notOffered()[qid] = { npc = npc, level = UnitLevel("player"), t = time() }
        changed = true
        LW:Log("offers", "%d %s NOT offered by npc %d at level %d (database says available)", qid, e.name, npc, UnitLevel("player"))
      end
    end
  end
  if changed then
    LW:RequestRefresh("offers")
    LW:Fire("SKIPS_CHANGED")
  end
end

function O:Is(questId)
  local rec = notOffered()[questId]
  if not rec then return nil end
  if haveQuest(questId) or LW.Adapter:IsCompleted(questId) then -- you got it, so it was offered
    notOffered()[questId] = nil
    return nil
  end
  if not rec.manual and rec.level ~= UnitLevel("player") then -- level changed: give it another chance
    notOffered()[questId] = nil
    return nil
  end
  return rec
end

--- Manual mark, for NPCs that open no dialog at all once they have nothing to give.
function O:Mark(questId)
  local starts = LibQuestieDB.Quest.Get(questId, "startedBy")
  local npc = type(starts) == "table" and starts[1] and starts[1][1] or 0
  notOffered()[questId] = { npc = npc, level = UnitLevel("player"), t = time(), manual = true }
  local e = LW.Index:Get(questId)
  LW:Log("offers", "%d %s marked NOT offered by hand (npc %d, level %d)", questId, e and e.name or "?", npc, UnitLevel("player"))
  LW:RequestRefresh("offer mark")
  LW:Fire("SKIPS_CHANGED")
end

function O:Clear(questId)
  notOffered()[questId] = nil
  LW:RequestRefresh("offer retry")
  LW:Fire("SKIPS_CHANGED")
end

-- NPCs with nothing to give open no dialog at all, so the check above never runs for them.
-- Second net: the current step is "accept X", you target X's giver while standing next to
-- it, and a few seconds later you still don't have the quest and no quest dialog opened.
local WAIT_SECONDS = 8
local watching -- { quest, npc, sawDialog }

local function targetNpcId()
  local guid = LW.NotSecret(UnitGUID("target"))
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-%d+%-%d+%-%d+%-%d+%-(%d+)")
  return kind == "Creature" and tonumber(id) or nil
end

LW:OnEvent("PLAYER_TARGET_CHANGED", function()
  if not LW.Index.ready or (InCombatLockdown and InCombatLockdown()) then return end
  local task = LW.Router.current
  if not (task and task.kind == "accept" and task.dist and task.dist <= 12) then return end
  local npc = targetNpcId()
  local e = task.quest
  if not npc or type(e.startNpcs) ~= "table" then return end
  local gives = false
  for _, id in ipairs(e.startNpcs) do if id == npc then gives = true end end
  if not gives or (watching and watching.quest == e.id) then return end
  local watch = { quest = e.id, npc = npc }
  watching = watch
  C_Timer.After(WAIT_SECONDS, function()
    if watching ~= watch then return end
    watching = nil
    local status = LW.Eligibility:Status(e.id)
    if watch.sawDialog or (status ~= "now" and status ~= "group") or targetNpcId() ~= npc or haveQuest(e.id) then return end
    notOffered()[e.id] = { npc = npc, level = UnitLevel("player"), t = time() }
    LW:Log("offers", "%d %s NOT offered by npc %d (targeted, standing next to it, no quest dialog)", e.id, e.name, npc)
    LW:Print((LibQuestieDB.Npc.Get(npc, "name") or "This NPC") .. " doesn't seem to offer [" .. e.name
      .. "]. Moved to Revisit (press Retry there if that's wrong).")
    LW:RequestRefresh("offers")
    LW:Fire("SKIPS_CHANGED")
  end)
end)
for _, ev in ipairs({ "QUEST_DETAIL", "QUEST_ACCEPTED" }) do
  LW:OnEvent(ev, function() if watching then watching.sawDialog = true end end)
end

for _, ev in ipairs({ "GOSSIP_SHOW", "QUEST_GREETING" }) do
  LW:OnEvent(ev, function(event)
    local ok, err = pcall(check, event)
    if not ok then LW:Log("offers", "check failed: %s", tostring(err)) end
  end)
end
