-- Quest categories (what the Options checkboxes switch on and off) and static applicability
-- (could this character EVER do this quest: race, class, profession).
local _, LW = ...
local L = LW.L

local C = {}
LW.Categories = C

C.order = { "general", "dungeon", "raid", "class", "profession", "donation", "repeatable", "event", "pvp" }
C.labels = {
  donation = L["Donation quests (cloth & material turn-ins)"],
  general = L["World quests"],
  dungeon = L["Dungeon quests"],
  raid = L["Raid & attunement quests"],
  class = L["Class quests"],
  profession = L["Profession quests (ones you know)"],
  repeatable = L["Repeatable & daily quests"],
  event = L["Seasonal event quests"],
  pvp = L["Battleground quests"],
}

-- Negative zoneOrSort values are quest sorts (QuestieDB sortKeys).
local CLASS_SORT = {
  [-61] = "WARLOCK", [-81] = "WARRIOR", [-82] = "SHAMAN", [-141] = "PALADIN", [-161] = "MAGE",
  [-162] = "ROGUE", [-261] = "HUNTER", [-262] = "PRIEST", [-263] = "DRUID",
}
local PROFESSION_SORT = { -- sort -> skill line id
  [-24] = 182, [-101] = 356, [-121] = 164, [-181] = 171, [-182] = 165, [-201] = 202,
  [-264] = 197, [-304] = 185, [-324] = 129,
}
local EVENT_SORT = {
  [-21] = true, [-22] = true, [-41] = true, [-364] = true, [-365] = true, [-366] = true,
  [-368] = true, [-369] = true, [-370] = true, [-374] = true, [-375] = true, [-376] = true,
  [-378] = true,
}
local PVP_SORT = { [-25] = true }
local PVP_ZONES = { [2597] = true, [3277] = true, [3358] = true } -- AV, WSG, AB
local RAID_ZONES = {
  [2717] = true, [2159] = true, [2677] = true, [1977] = true, [3429] = true, [3428] = true,
  [3456] = true,
}

local QUEST_FLAGS_DAILY = 4096

-- Starting zones only one race can reach, although their quests carry no race mask.
-- uiMapID -> { [raceId] = true }
local RACE_LOCKED_MAPS = {
  [2521] = { [95] = true, [96] = true }, -- Zephras Isle: Skyborne (Forever)
}

local playerClassFile, playerClassBit, playerRaceBit, playerRaceId

function C:InitPlayer()
  local _, classFile, classId = UnitClass("player")
  playerClassFile = classFile
  playerClassBit = classId and 2 ^ (classId - 1) or 0
  local _, _, raceId = UnitRace("player")
  playerRaceId = raceId
  local masks = LibQuestieDB and LibQuestieDB.Enum and LibQuestieDB.Enum.raceMaskById
  playerRaceBit = (masks and raceId and masks[raceId]) or (raceId and 2 ^ (raceId - 1)) or 0
end

--- f: { sort, requiredRaces, requiredClasses, requiredSkill, specialFlags, questFlags, isDungeon }
--- Returns the category key.
function C:Classify(f)
  local sort = f.sort or 0
  if PVP_SORT[sort] or PVP_ZONES[sort] then return "pvp" end
  -- (specialFlags bit 2 means "completed by a scripted event", e.g. an escort: NOT a holiday)
  if EVENT_SORT[sort] then return "event" end
  if LW.HasBit(f.specialFlags, 1) or LW.HasBit(f.questFlags, QUEST_FLAGS_DAILY) then return "repeatable" end
  if (f.id and LW.DonationQuests and LW.DonationQuests[f.id]) or (f.name and f.name:find("Donation", 1, true)) then
    return "donation"
  end
  if RAID_ZONES[sort] then return "raid" end
  if f.isDungeon then return "dungeon" end
  if CLASS_SORT[sort] or (f.requiredClasses and f.requiredClasses ~= 0) then return "class" end
  if PROFESSION_SORT[sort] or f.requiredSkill then return "profession" end
  return "general"
end

--- Could this character ever do it? (race, class and known professions)
function C:Applies(f)
  if f.requiredRaces and f.requiredRaces ~= 0 and not LW.HasBit(f.requiredRaces, playerRaceBit) then
    return false
  end
  if f.requiredClasses and f.requiredClasses ~= 0 and not LW.HasBit(f.requiredClasses, playerClassBit) then
    return false
  end
  local classSort = CLASS_SORT[f.sort or 0]
  if classSort and classSort ~= playerClassFile then return false end
  local skill = (f.requiredSkill and f.requiredSkill[1]) or PROFESSION_SORT[f.sort or 0]
  if skill and not LW.Adapter:HasProfession(skill) then return false end
  return true
end

--- False for zones locked to another race (e.g. Zephras Isle for non-Skyborne).
function C:ZoneAllowed(areaId)
  local map = areaId and LW.Adapter:UiMap(areaId)
  local races = map and RACE_LOCKED_MAPS[map]
  return not races or races[playerRaceId] == true
end

function C:Enabled(cat)
  return LW.db.categories[cat] and true or false
end
