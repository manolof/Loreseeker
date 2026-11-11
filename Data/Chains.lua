-- Story chains: connected groups of quests linked by prerequisites, "next in chain" and
-- breadcrumbs. Each chain gets a root (its first quest), an ordered member list and a depth
-- per quest, so the UI can say "Story: The Defias Brotherhood - 3/7".
local _, LW = ...

local CH = {
  byId = {},   -- [chainId] = { id, root, name, members = {e...}, size, curated }
  list = {},   -- chains with 2+ members
}
LW.Chains = CH

CH.STORY_MIN = 4 -- auto-detected chains this long count as "stories" for lore weighting

function CH:Build()
  wipe(self.byId); wipe(self.list)
  local quests = LW.Index.quests
  local parent = {}
  local preds, succs = {}, {}

  local function find(x)
    while parent[x] and parent[x] ~= x do
      parent[x] = parent[parent[x]] or parent[x]
      x = parent[x]
    end
    return x
  end
  local function link(a, b) -- a comes before b
    if not (quests[a] and quests[b]) or a == b then return end
    preds[b] = preds[b] or {}; table.insert(preds[b], a)
    succs[a] = succs[a] or {}; table.insert(succs[a], b)
    parent[a] = parent[a] or a; parent[b] = parent[b] or b
    local ra, rb = find(a), find(b)
    if ra ~= rb then parent[rb] = ra end
  end

  for _, e in ipairs(LW.Index.list) do
    if type(e.pre) == "table" then for _, p in ipairs(e.pre) do link(math.abs(p), e.id) end end
    if type(e.preGroup) == "table" then for _, p in ipairs(e.preGroup) do link(math.abs(p), e.id) end end
    if e.nextInChain and e.nextInChain ~= 0 then link(e.id, e.nextInChain) end
    if e.breadcrumbFor and e.breadcrumbFor ~= 0 then link(e.id, e.breadcrumbFor) end
    LW.Yield()
  end

  -- Group members per component.
  local groups = {}
  for id in pairs(parent) do
    local r = find(id)
    groups[r] = groups[r] or {}
    table.insert(groups[r], quests[id])
  end

  -- Depth by breadth-first walk from the roots (quests with no predecessor).
  for rootKey, members in pairs(groups) do
    local depth = {}
    local queue = {}
    for _, e in ipairs(members) do
      if not preds[e.id] then depth[e.id] = 1; queue[#queue + 1] = e.id end
    end
    local head = 1
    while head <= #queue do
      local id = queue[head]; head = head + 1
      for _, nxt in ipairs(succs[id] or {}) do
        if not depth[nxt] then depth[nxt] = depth[id] + 1; queue[#queue + 1] = nxt end
      end
    end
    table.sort(members, function(a, b)
      local da, db = depth[a.id] or 99, depth[b.id] or 99
      if da ~= db then return da < db end
      if a.level ~= b.level then return a.level < b.level end
      return a.id < b.id
    end)
    local root = members[1]
    local chain = {
      id = rootKey, root = root, name = root.name, members = members, size = #members,
      minLevel = root.level > 0 and root.level or 99,
    }
    for _, e in ipairs(members) do
      e.chain = rootKey
      e.depth = depth[e.id] or 1
      if e.level > 0 and e.level < chain.minLevel then chain.minLevel = e.level end
    end
    if chain.minLevel == 99 then chain.minLevel = 0 end
    self.byId[rootKey] = chain
    self.list[#self.list + 1] = chain
    LW.Yield()
  end
end

function CH:Get(chainId) return chainId and self.byId[chainId] end

function CH:IsStory(chain)
  return chain and (chain.curated or chain.size >= self.STORY_MIN) and true or false
end

--- Done/total counted over enabled, applicable members.
function CH:Progress(chain)
  local done, total = 0, 0
  for _, e in ipairs(chain.members) do
    local s = LW.Eligibility:Status(e.id)
    if s ~= "off" and s ~= "excluded" then
      total = total + 1
      if s == "done" then done = done + 1 end
    end
  end
  return done, total
end

--- The display name: curated storyline name wins over the root quest's name.
function CH:Name(chain)
  if not chain.curated then return chain.name end
  if chain.part then return chain.curated.name .. ": " .. chain.name end
  return chain.curated.name
end
