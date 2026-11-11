-- Lore journal capture: saves every quest's text as you read it (offer, objectives, progress
-- and completion), so the story can be reread later by zone or storyline. For quests done
-- before Loreseeker was installed, the Journal falls back to Spoken's text corpus when present.
local _, LW = ...

local J = {}
LW.Journal = J

local function entry(questId)
  local j = LW.char.journal[questId]
  if not j then
    j = {}
    LW.char.journal[questId] = j
  end
  j.t = time()
  return j
end

local function questId()
  local id = GetQuestID and GetQuestID()
  if id and id > 0 then return id end
  return nil
end

local function stamp(j)
  local e = LW.Index:Get(j.id)
  j.zone = j.zone or (e and e.zone) or LW.Adapter:AreaForMap(LW.PlayerZoneMap())
end

local S = function(v) return LW.NotSecret(v) end

function J:Init()
  LW:OnEvent("QUEST_DETAIL", function()
    local id = S(questId()); if not id then return end
    local j = entry(id)
    j.id = id
    j.title = S(GetTitleText())
    j.detail = S(GetQuestText())
    j.objective = S(GetObjectiveText())
    stamp(j)
  end)
  LW:OnEvent("QUEST_PROGRESS", function()
    local id = S(questId()); if not id then return end
    local j = entry(id)
    j.id = id
    j.title = j.title or S(GetTitleText())
    j.progress = S(GetProgressText())
    stamp(j)
  end)
  LW:OnEvent("QUEST_COMPLETE", function()
    local id = S(questId()); if not id then return end
    local j = entry(id)
    j.id = id
    j.title = j.title or S(GetTitleText())
    j.complete = S(GetRewardText())
    stamp(j)
    LW:Fire("JOURNAL_CHANGED", id)
  end)
end

---------------------------------------------------------------------------------------------
-- Spoken's text corpus fallback ($N, $C, $R, $G male:female; and $B placeholders)
---------------------------------------------------------------------------------------------

local function fill(text)
  if not text then return nil end
  local name = UnitName("player") or ""
  local class = UnitClass("player") or ""
  local race = UnitRace("player") or ""
  local female = UnitSex("player") == 3
  text = text:gsub("%$[Gg]%s*([^:;]*):([^;]*);", function(m, f) return female and f or m end)
  text = text:gsub("%$[Nn]", name):gsub("%$[Cc]", class):gsub("%$[Rr]", race):gsub("%$[Bb]", "\n")
  return text
end

function J:SpokenText(questId)
  local data = rawget(_G, "SpokenQuestsText")
  local t = data and data[questId]
  if not t then return nil end
  return fill(t.accept), fill(t.complete)
end

--- Everything we know about a quest's story, for the journal page.
function J:Get(questId)
  local j = LW.char.journal[questId]
  local accept, complete = self:SpokenText(questId)
  local e = LW.Index:Get(questId)
  if not j and not accept and not complete then return nil end
  return {
    id = questId,
    title = (j and j.title) or (e and e.name) or ("Quest " .. questId),
    zone = (j and j.zone) or (e and e.zone),
    detail = (j and j.detail) or accept,
    objective = j and j.objective,
    progress = j and j.progress,
    complete = (j and j.complete) or complete,
    captured = j ~= nil,
  }
end

--- Title and zone only, for list rows (J:Get fills in the full text, which is costly).
function J:Head(questId)
  local j = LW.char.journal[questId]
  local e = LW.Index:Get(questId)
  return (j and j.title) or (e and e.name) or ("Quest " .. questId), (j and j.zone) or (e and e.zone)
end

--- Journal listing: captured quests plus completed quests Spoken has text for.
function J:Entries()
  local seen, out = {}, {}
  for id in pairs(LW.char.journal) do
    seen[id] = true
    out[#out + 1] = id
  end
  if rawget(_G, "SpokenQuestsText") then
    for _, e in ipairs(LW.Index.list) do
      if not seen[e.id] and LW.Eligibility:Status(e.id) == "done" and SpokenQuestsText[e.id] then
        out[#out + 1] = e.id
      end
    end
  end
  return out
end
