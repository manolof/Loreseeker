-- The ONLY file that touches Questie's internals. Everything is pcall-guarded so a Questie
-- update degrades features instead of breaking the addon. QuestieDB's public API
-- (LibQuestieDB) is used directly elsewhere; this file covers what only Questie knows:
-- availability (IsDoable), completed quests, zones/dungeons, professions.
local _, LW = ...

local A = {}
LW.Adapter = A

local QDB, ZoneDB, Professions, Corrections

local function import(name)
  if not QuestieLoader or not QuestieLoader.ImportModule then return nil end
  local ok, mod = pcall(QuestieLoader.ImportModule, QuestieLoader, name)
  return ok and mod or nil
end

function A:Init()
  QDB = import("QuestieDB")
  ZoneDB = import("ZoneDB")
  Professions = import("QuestieProfessions")
  Corrections = import("QuestieCorrections")
  self.ok = QDB ~= nil and type(QDB.IsDoable) == "function"
  return self.ok
end

function A:OnReady(fn)
  if Questie and Questie.API and Questie.API.RegisterOnReady then
    Questie.API.RegisterOnReady(fn)
  else
    C_Timer.After(5, fn) -- no API: give Questie a moment and go
  end
end

function A:OnQuestUpdate(fn)
  if Questie and Questie.API and Questie.API.RegisterForQuestUpdates then
    pcall(Questie.API.RegisterForQuestUpdates, fn)
  end
end

--- Questie's full availability check (race, class, prerequisites, exclusives, rep, skill,
--- breadcrumbs ...). It does NOT check level; Eligibility does that.
function A:IsDoable(questId)
  if not self.ok then return true end
  local ok, res = pcall(QDB.IsDoable, questId)
  return ok and res and true or false
end

A.turnedIn = {} -- quests handed in this session; Questie's own record can lag a moment

function A:IsCompleted(questId)
  if self.turnedIn[questId] then return true end
  local complete = Questie and Questie.db and Questie.db.char and Questie.db.char.complete
  if complete then return complete[questId] and true or false end
  return C_QuestLog.IsQuestFlaggedCompleted(questId) and true or false
end

--- Drop chance in percent for an item from an NPC (Questie's drop tables), or nil.
function A:DropRate(itemId, npcId)
  if not (QDB and QDB.GetItemDroprate) then return nil end
  local ok, res = pcall(QDB.GetItemDroprate, itemId, npcId)
  if ok and type(res) == "table" and type(res[1]) == "number" and res[1] > 0 then return res[1] end
  return nil
end

function A:IsHidden(questId)
  local hidden = Corrections and Corrections.hiddenQuests
  return hidden and hidden[questId] and true or false
end

local uiMapCache = {}
function A:UiMap(areaId)
  if not areaId or areaId <= 0 then return nil end
  local cached = uiMapCache[areaId]
  if cached ~= nil then return cached or nil end
  local map
  if ZoneDB and ZoneDB.GetUiMapIdByAreaId then
    local ok, res = pcall(ZoneDB.GetUiMapIdByAreaId, ZoneDB, areaId)
    if ok then map = res end
  end
  uiMapCache[areaId] = map or false
  return map
end

local areaCache = {}
function A:AreaForMap(uiMap)
  if not uiMap then return nil end
  local cached = areaCache[uiMap]
  if cached ~= nil then return cached or nil end
  local area
  if ZoneDB and ZoneDB.GetAreaIdByUiMapId then
    local ok, res = pcall(ZoneDB.GetAreaIdByUiMapId, ZoneDB, uiMap)
    if ok then area = res end
  end
  areaCache[uiMap] = area or false
  return area
end

function A:IsDungeonZone(areaId)
  if not (ZoneDB and ZoneDB.IsDungeonZone and areaId) then return false end
  local ok, res = pcall(ZoneDB.IsDungeonZone, areaId)
  return ok and res or false
end

--- Dungeon entrances as { {areaId, x, y}, ... } with x, y in 0-100.
function A:DungeonEntrances(areaId)
  if not (ZoneDB and ZoneDB.GetDungeonLocation) then return nil end
  local ok, res = pcall(ZoneDB.GetDungeonLocation, ZoneDB, areaId)
  return ok and res or nil
end

function A:DungeonName(areaId)
  if not (ZoneDB and ZoneDB.GetLocalizedDungeonName) then return nil end
  local ok, res = pcall(ZoneDB.GetLocalizedDungeonName, ZoneDB, areaId)
  return ok and res or nil
end

--- Top-level zone of a sub-zone or alternative dungeon area (nil when already top level).
function A:ParentZone(areaId)
  if not (ZoneDB and ZoneDB.GetParentZoneId and areaId) then return nil end
  local ok, res = pcall(ZoneDB.GetParentZoneId, ZoneDB, areaId)
  return ok and res or nil
end

--- Does the player know this profession (skillId)?
function A:HasProfession(skillId)
  if not (Professions and Professions.HasProfessionAndSkillLevel) then return true end
  local ok, has = pcall(Professions.HasProfessionAndSkillLevel, Professions, { skillId, 1 })
  if not ok then return true end
  return has and true or false
end
