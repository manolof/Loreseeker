-- What you can craft. Read from your profession window whenever you open it (the game only
-- tells addons your recipes while that window is open), saved per character.
-- LW.char.crafts[itemId] = profession name
local _, LW = ...

local CR = {}
LW.Crafts = CR

local function itemIdFromLink(link)
  link = LW.NotSecret(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function scanClassic(found)
  if not (GetNumTradeSkills and GetTradeSkillItemLink) then return nil end
  local profession = GetTradeSkillLine and GetTradeSkillLine() or "?"
  local n = 0
  for i = 1, GetNumTradeSkills() do
    local _, kind = GetTradeSkillInfo(i)
    if kind ~= "header" then
      local id = itemIdFromLink(GetTradeSkillItemLink(i))
      if id then found[id] = profession; n = n + 1 end
    end
  end
  return n, profession
end

local function scanModern(found)
  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeSchematic) then return nil end
  local info = C_TradeSkillUI.GetBaseProfessionInfo and C_TradeSkillUI.GetBaseProfessionInfo()
  local profession = info and info.professionName or "?"
  local n = 0
  for _, recipeId in ipairs(C_TradeSkillUI.GetAllRecipeIDs() or {}) do
    local known = true
    if C_TradeSkillUI.GetRecipeInfo then
      local r = C_TradeSkillUI.GetRecipeInfo(recipeId)
      known = r and r.learned
    end
    if known then
      local s = C_TradeSkillUI.GetRecipeSchematic(recipeId, false)
      local id = s and s.outputItemID
      if id then found[id] = profession; n = n + 1 end
    end
  end
  return n, profession
end

function CR:Scan()
  local found = {}
  local ok, n, profession = pcall(scanClassic, found)
  if not (ok and n and n > 0) then ok, n, profession = pcall(scanModern, found) end
  if not (ok and n and n > 0) then
    LW:Log("crafts", "profession window open, but no recipes could be read")
    return
  end
  local crafts, added = LW.char.crafts, 0
  for id, prof in pairs(found) do
    if crafts[id] ~= prof then added = added + 1 end
    crafts[id] = prof
  end
  if added > 0 then
    LW:Log("crafts", "%s: %d recipes known (%d new)", tostring(profession), n, added)
    LW.Tasks:Invalidate()
    LW:RequestRefresh("recipes")
  end
end

function CR:Profession(itemId) return LW.char.crafts[itemId] end

for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_UPDATE" }) do
  pcall(LW.OnEvent, LW, ev, function()
    C_Timer.After(0.2, function() CR:Scan() end) -- the list fills in just after the event
  end)
end
