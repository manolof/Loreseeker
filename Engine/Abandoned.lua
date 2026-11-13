-- A quest that leaves your quest log without being handed in was abandoned (or failed). Loreseeker
-- would offer it again at once, since the database says it is available. So an abandoned quest
-- is skipped automatically, with a note; unskip it in the Revisit tab if you change your mind.
--
-- Safeguards, because a wrong "abandoned" hides a real quest:
--   * it is judged a few seconds AFTER the quest left the log, when turn-in flags have settled;
--   * a quest that is flagged completed, or is back in the log, is never skipped;
--   * a quest that had FAILED (timed escorts) is not skipped: you will want to retry it.
local _, LW = ...
local L = LW.L

local AB = {}
LW.Abandoned = AB

local SETTLE_SECONDS = 3

local function onQuest(id)
  if C_QuestLog and C_QuestLog.IsOnQuest then return C_QuestLog.IsOnQuest(id) and true or false end
  if GetQuestLogIndexByID then return (GetQuestLogIndexByID(id) or 0) > 0 end
  return LW.Eligibility.log[id] ~= nil
end

local function completed(id)
  if LW.Adapter:IsCompleted(id) then return true end
  return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) and true or false
end

--- Called after a refresh that found quests gone from the log (ids: list of quest ids).
function AB:Schedule(ids)
  if not LW.db.skipAbandoned or #ids == 0 then return end
  local copy = {}
  for i, id in ipairs(ids) do copy[i] = id end
  C_Timer.After(SETTLE_SECONDS, function() AB:Check(copy) end)
end

function AB:Check(ids)
  if not LW.db.skipAbandoned then return end
  for _, id in ipairs(ids) do
    local e = LW.Index:Get(id)
    if e and not onQuest(id) and not completed(id) and not LW.Skips:ForQuest(e) then
      LW.Skips:AddQuest(id, L["abandoned"], nil)
      LW:Log("abandoned", "%d %s left the log without a turn-in: skipped", id, e.name)
      LW:Notify(string.format(L["You abandoned [%s]: it is skipped now. Unskip it in the Revisit tab if you change your mind."], e.name))
    end
  end
end
