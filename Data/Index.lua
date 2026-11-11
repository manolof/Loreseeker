-- Static quest index for this character: every quest it could ever do, with category, level,
-- zone and chain links. Built once per login in the background from QuestieDB.
local _, LW = ...

local I = {
  quests = {},  -- [questId] = entry
  list = {},    -- array of entries
  byName = {},  -- [name] = { questId, ... }
  ready = false,
}
LW.Index = I

local function Q(id, field)
  return LibQuestieDB.Quest.Get(id, field)
end

local function firstSpawnArea(kind, id)
  local db = kind == 1 and LibQuestieDB.Npc or LibQuestieDB.Object
  local ok, spawns = pcall(db.Get, id, "spawns")
  if not ok or type(spawns) ~= "table" then return nil end
  local best
  for areaId in pairs(spawns) do
    if not best or areaId < best then best = areaId end
  end
  return best
end

local function hasStarter(startedBy)
  if type(startedBy) ~= "table" then return false end
  for i = 1, 3 do
    if type(startedBy[i]) == "table" and #startedBy[i] > 0 then return true end
  end
  return false
end

local function topZone(areaId)
  if not areaId or areaId <= 0 then return nil end
  local guard = 0
  local parent = LW.Adapter:ParentZone(areaId)
  while parent and parent ~= areaId and guard < 4 do
    areaId = parent
    parent = LW.Adapter:ParentZone(areaId)
    guard = guard + 1
  end
  return areaId
end

local function buildEntry(id)
  local name = Q(id, "name")
  if not name or name == "" then return nil end
  local startedBy = Q(id, "startedBy")
  if not hasStarter(startedBy) then return nil end
  if LW.Adapter:IsHidden(id) then return nil end

  local sort = Q(id, "zoneOrSort") or 0
  local f = {
    name = name,
    sort = sort,
    requiredRaces = Q(id, "requiredRaces"),
    requiredClasses = Q(id, "requiredClasses"),
    requiredSkill = Q(id, "requiredSkill"),
    specialFlags = Q(id, "specialFlags"),
    questFlags = Q(id, "questFlags"),
    isDungeon = sort > 0 and LW.Adapter:IsDungeonZone(sort),
  }
  if not LW.Categories:Applies(f) then return nil end
  -- Quests with no race restriction that only the other faction's NPCs give (common among
  -- Forever's added quests): you could never pick them up.
  if not startedBy[2] or #startedBy[2] == 0 then
    local npcs = startedBy[1]
    if type(npcs) == "table" and #npcs > 0 and not (startedBy[3] and #startedBy[3] > 0) then
      local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
      local reachable = false
      for _, npc in ipairs(npcs) do
        local ok, friendly = pcall(LibQuestieDB.Npc.Get, npc, "friendlyToFaction")
        if not ok or type(friendly) ~= "string" or friendly == "" or friendly:find(mine, 1, true) then
          reachable = true
          break
        end
      end
      if not reachable then return nil end
    end
  end

  -- Zone: the quest's own area when it has one, else where its first starter stands.
  local zone = sort > 0 and sort or nil
  if not zone then
    -- prefer a giver of your own faction (lore books have one in each capital)
    local mine = UnitFactionGroup("player") == "Horde" and "H" or "A"
    local pick
    for _, npc in ipairs(startedBy[1] or {}) do
      local ok, friendly = pcall(LibQuestieDB.Npc.Get, npc, "friendlyToFaction")
      if ok and (type(friendly) ~= "string" or friendly == "" or friendly:find(mine, 1, true)) then pick = npc break end
    end
    pick = pick or (startedBy[1] and startedBy[1][1])
    if pick then
      zone = firstSpawnArea(1, pick)
    elseif startedBy[2] and startedBy[2][1] then
      zone = firstSpawnArea(2, startedBy[2][1])
    end
  end
  if zone and not f.isDungeon then zone = topZone(zone) end
  if not LW.Categories:ZoneAllowed(zone) then return nil end

  -- Deliveries / "go talk to X": nothing to fight, so difficulty colour doesn't matter.
  local objectives = Q(id, "objectives")
  local hasObjectives = false
  if type(objectives) == "table" then
    for _, group in pairs(objectives) do
      if type(group) == "table" and next(group) then hasObjectives = true break end
    end
  end
  if Q(id, "triggerEnd") then hasObjectives = true end

  -- For deliveries, who they send you to (breadcrumb detection in Eligibility).
  local finishers
  if not hasObjectives then
    local fb = Q(id, "finishedBy")
    finishers = type(fb) == "table" and fb[1] or nil
  end

  local allFinishers = Q(id, "finishedBy")
  return {
    id = id,
    name = name,
    noCombat = not hasObjectives,
    finishers = finishers,
    startNpcs = startedBy[1],
    finishNpcs = type(allFinishers) == "table" and allFinishers[1] or nil,
    level = Q(id, "questLevel") or 0,
    req = Q(id, "requiredLevel") or 0,
    maxReq = Q(id, "requiredMaxLevel"),
    cat = LW.Categories:Classify(f),
    zone = zone,
    exclusive = Q(id, "exclusiveTo"),
    pre = Q(id, "preQuestSingle"),
    preGroup = Q(id, "preQuestGroup"),
    nextInChain = Q(id, "nextQuestInChain"),
    breadcrumbFor = Q(id, "breadcrumbForQuestId"),
  }
end

local function overlap(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for _, x in ipairs(a) do
    for _, y in ipairs(b) do if x == y then return true end end
  end
  return false
end

local function hasPre(e)
  return (type(e.pre) == "table" and #e.pre > 0) or (type(e.preGroup) == "table" and #e.preGroup > 0)
end

-- Missing prerequisites. Forever added follow-up quests that reuse the name of the quest
-- before them ("Return the Statuette": you hand the first one in to Karl Boran, who then
-- gives the second), but the database lists the follow-up with no prerequisite, so it looks
-- available from the start. Rule: two quests share a name, B has no prerequisite, and B is
-- given by the NPC that A is handed in to (and not the other way round) => A comes first.
function I:InferPrerequisites()
  local count = 0
  for _, ids in pairs(self.byName) do
    if #ids >= 2 then
      for _, bId in ipairs(ids) do
        local b = self.quests[bId]
        if b.cat ~= "class" and b.cat ~= "repeatable" and not hasPre(b) then
          for _, aId in ipairs(ids) do
            local a = self.quests[aId]
            if aId ~= bId and overlap(a.finishNpcs, b.startNpcs) and not overlap(b.finishNpcs, a.startNpcs)
              and not overlap(a.startNpcs, b.startNpcs) then
              b.impliedPre = aId
              b.pre = { aId } -- so chains and story order see it too
              count = count + 1
              break
            end
          end
        end
      end
    end
  end
  self.inferred = count
end

---------------------------------------------------------------------------------------------
-- Cache. Reading ~5,700 quests from QuestieDB is the slow part of a login, and the answer
-- only changes when something it depends on changes. The result is saved per character and
-- reused while this key matches: Lorewalker, QuestieDB and Questie versions, race, class,
-- and the skills you know (a new profession changes which quests apply).
---------------------------------------------------------------------------------------------

local CACHE_FORMAT = 2
local FIELDS = { "id", "name", "noCombat", "finishers", "startNpcs", "finishNpcs", "level", "req", "maxReq",
  "cat", "zone", "exclusive", "pre", "preGroup", "nextInChain", "breadcrumbFor" }

local function meta(addon, field)
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  return get and get(addon, field) or "?"
end

local function skillSignature()
  local names = {}
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, isHeader = GetSkillLineInfo(i)
      if name and not isHeader then names[#names + 1] = name end
    end
  end
  table.sort(names)
  return table.concat(names, ",")
end

local function cacheKey()
  local _, _, race = UnitRace("player")
  local _, _, class = UnitClass("player")
  return table.concat({ CACHE_FORMAT, LW.version, meta("QuestieDB", "Version"), meta("Questie", "Version"),
    tostring(race), tostring(class), skillSignature() }, "|")
end

local function saveCache(key, list, scanned)
  local rows = {}
  for i, e in ipairs(list) do
    local row = {}
    for f, field in ipairs(FIELDS) do row[f] = e[field] end
    rows[i] = row
  end
  LW.char.indexCache = { key = key, rows = rows, scanned = scanned, saved = time() }
end

function I:Build(done, force)
  self.ready = false
  local started = debugprofilestop()
  LW:RunAsync("index", function()
    -- Wiped inside the job: a refresh still running ahead of it in the queue keeps valid data.
    wipe(self.quests); wipe(self.list); wipe(self.byName)
    LW.Tasks:Invalidate()
    LW.Categories:InitPlayer()
    local key = cacheKey()
    local cache = LW.char.indexCache
    local function add(e)
      self.quests[e.id] = e
      self.list[#self.list + 1] = e
      local names = self.byName[e.name]
      if not names then names = {}; self.byName[e.name] = names end
      names[#names + 1] = e.id
    end
    if not force and cache and cache.key == key and type(cache.rows) == "table" then
      for _, row in ipairs(cache.rows) do
        local e = {}
        for f, field in ipairs(FIELDS) do e[field] = row[f] end
        add(e)
        LW.Yield()
      end
      self.scanned = cache.scanned
      self.fromCache = true
    else
      local ids = LibQuestieDB.Quest.GetAllIds()
      for i = 1, #ids do
        local ok, e = pcall(buildEntry, ids[i])
        if ok and e then add(e) end
        LW.Yield()
      end
      self.scanned = #ids
      self.fromCache = false
      saveCache(key, self.list, #ids) -- before prerequisites are inferred: that step reruns on load
    end
    self:InferPrerequisites()
    LW.Chains:Build()
    LW.Storylines:Resolve()
    self.buildMs = debugprofilestop() - started
  end, function()
    self.ready = true
    if done then done() end
  end)
end

function I:Get(id) return self.quests[id] end
