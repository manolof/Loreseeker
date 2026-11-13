-- Shared widgets built only from stock Blizzard templates, textures and fonts.
local _, LW = ...
local L = LW.L

local UI = {}
LW.UI = UI

UI.ICONS = {
  accept = "Interface\\GossipFrame\\AvailableQuestIcon",
  turnin = "Interface\\GossipFrame\\ActiveQuestIcon",
  kill = "Interface\\Icons\\Ability_Hunter_SniperShot",
  loot = "Interface\\Icons\\INV_Misc_Bag_10",
  object = "Interface\\Icons\\INV_Misc_Gear_01",
  buy = "Interface\\Icons\\INV_Misc_Coin_01",
  auction = "Interface\\Icons\\INV_Misc_Coin_02",
  craft = "Interface\\Icons\\Trade_BlackSmithing",
  flightpoint = "Interface\\Icons\\INV_Misc_Feather_01",
  hearth = "Interface\\Icons\\INV_Misc_Rune_01",
  explore = "Interface\\Icons\\INV_Misc_Map_01",
  generic = "Interface\\Icons\\INV_Misc_Note_01",
  story = "Interface\\Icons\\INV_Misc_Book_09",
  zone = "Interface\\Icons\\INV_Misc_Map02",
  dungeon = "Interface\\Icons\\INV_Misc_Key_03",
  skip = "Interface\\Icons\\Ability_Rogue_Sprint",
  done = "Interface\\RaidFrame\\ReadyCheck-Ready",
  locked = "Interface\\RaidFrame\\ReadyCheck-NotReady",
  waiting = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}

UI.STATUS_ICON = {
  done = UI.ICONS.done, active = UI.ICONS.turnin, now = UI.ICONS.accept, group = UI.ICONS.dungeon,
  later = UI.ICONS.waiting, locked = UI.ICONS.locked, skipped = UI.ICONS.skip, excluded = UI.ICONS.locked,
}

UI.STATUS_LABEL = {
  done = L["Done"], active = L["In your log"], now = L["Available"], group = L["Group up"], later = L["Later"],
  locked = L["Locked"], skipped = L["Skipped"], excluded = L["Alternative done"], off = L["Off"],
}

--- Blizzard's own difficulty color for a quest level.
function UI.LevelColor(level)
  local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level or UnitLevel("player"))
  if not c then return "|cffffd100" end
  return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
end

function UI.QuestLabel(e)
  local lvl = LW.Eligibility:Level(e)
  return string.format("%s[%d] %s|r", UI.LevelColor(lvl), lvl, e.name)
end

--- Tooltip lines without holes: UI.Lines("a", nil, "b") -> { "a", "b" }
function UI.Lines(...)
  local out = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v and v ~= "" then out[#out + 1] = tostring(v) end
  end
  return out
end

--- A stock button that grows to fit its text (translations are often longer than English),
--- never shrinking below the width asked for. b.OnResize(b) runs when it grows.
function UI.Button(parent, text, width, height)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b.minWidth = width or 90
  b:SetSize(b.minWidth, height or 22)
  local setText = b.SetText
  b.SetText = function(self, t)
    setText(self, t)
    local fs = self:GetFontString()
    local need = fs and (fs:GetStringWidth() + 20) or 0
    local w = math.max(self.minWidth, need)
    if math.abs(w - self:GetWidth()) > 0.5 then
      self:SetWidth(w)
      if self.OnResize then self:OnResize() end
    end
  end
  b:SetText(text)
  return b
end

function UI.Check(parent, label, get, set)
  local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  c:SetSize(26, 26)
  local fs = c.Text or c.text
  if not fs then
    fs = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", c, "RIGHT", 2, 0)
  end
  fs:SetFontObject(GameFontHighlight)
  fs:SetText(label)
  c.label = fs
  c.Refresh = function() c:SetChecked(get() and true or false) end
  c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
  c:Refresh()
  return c
end

--- Label with [-] value [+] steppers.
function UI.Stepper(parent, label, minV, maxV, get, set, fmt)
  local f = CreateFrame("Frame", nil, parent)
  -- Controls on the left, label after them: a long label can never run under the buttons.
  f:SetSize(600, 26)
  local minus = UI.Button(f, "-", 24, 22)
  minus:SetPoint("LEFT", f, "LEFT", 4, 0)
  local value = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
  value:SetWidth(96)
  value:SetJustifyH("CENTER")
  local plus = UI.Button(f, "+", 24, 22)
  plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
  local text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("LEFT", plus, "RIGHT", 10, 0)
  text:SetPoint("RIGHT", f, "RIGHT", -4, 0)
  text:SetJustifyH("LEFT")
  text:SetText(label)
  f.Refresh = function()
    local v = get()
    value:SetText(fmt and fmt(v) or tostring(v))
    value:SetWidth(math.max(96, value:GetStringWidth() + 8)) -- the label after it moves along
  end
  minus:SetScript("OnClick", function() set(math.max(minV, get() - 1)); f.Refresh() end)
  plus:SetScript("OnClick", function() set(math.min(maxV, get() + 1)); f.Refresh() end)
  f:Refresh()
  return f
end

---------------------------------------------------------------------------------------------
-- Scrolling list. items = { { text, right, icon, indent, bar = {value, max}, onClick,
--   button = { text, onClick }, tooltip = { lines... }, header = bool }, ... }
---------------------------------------------------------------------------------------------

local ROW_H = 20

local function makeRow(list)
  local row = CreateFrame("Button", nil, list.content)
  row:SetHeight(ROW_H)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  row.text:SetJustifyH("LEFT")
  row.text:SetWordWrap(false)
  row.right = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  row.right:SetJustifyH("RIGHT")
  row.bar = CreateFrame("StatusBar", nil, row)
  row.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  row.bar:SetStatusBarColor(0.58, 0.0, 0.55) -- the stock experience-bar purple
  row.bar:SetSize(120, 10)
  row.bar.bg = row.bar:CreateTexture(nil, "BACKGROUND")
  row.bar.bg:SetAllPoints()
  row.bar.bg:SetColorTexture(0, 0, 0, 0.5)
  row.btn = UI.Button(row, "", 70, 18)
  row.btn:SetScript("OnClick", function()
    local item = row.item
    if item and item.button then item.button.onClick(item) end
  end)
  row:SetScript("OnClick", function(self, mouse) if self.item and self.item.onClick then self.item.onClick(self.item, mouse) end end)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row:SetScript("OnEnter", function(self)
    local tip = self.item and self.item.tooltip
    if not tip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    for i, line in ipairs(tip) do
      if i == 1 then GameTooltip:SetText(line) else GameTooltip:AddLine(line, 1, 1, 1, true) end
    end
    GameTooltip:Show()
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return row
end

local function layoutRow(row, item, width)
  local indent = (item.indent or 0) * 16
  row:SetWidth(width)
  row.icon:ClearAllPoints()
  row.icon:SetPoint("LEFT", 4 + indent, 0)
  if item.icon then row.icon:SetTexture(item.icon); row.icon:Show() else row.icon:Hide() end
  row.text:ClearAllPoints()
  row.text:SetPoint("LEFT", row.icon, item.icon and "RIGHT" or "LEFT", item.icon and 4 or 0, 0)
  row.text:SetFontObject(item.header and GameFontNormal or (item.dim and GameFontDisable or GameFontHighlight))
  row.text:SetText(item.text or "")

  local rightEdge = -4
  if item.button then
    row.btn:Show()
    row.btn:SetText(item.button.text)
    row.btn:ClearAllPoints()
    row.btn:SetPoint("RIGHT", rightEdge, 0)
    rightEdge = rightEdge - row.btn:GetWidth() - 4 -- the button may have grown to fit its text
  else
    row.btn:Hide()
  end
  if item.bar then
    row.bar:Show()
    row.bar:ClearAllPoints()
    row.bar:SetPoint("RIGHT", rightEdge, 0)
    row.bar:SetMinMaxValues(0, math.max(1, item.bar[2]))
    row.bar:SetValue(item.bar[1])
    rightEdge = rightEdge - 126
  else
    row.bar:Hide()
  end
  row.right:ClearAllPoints()
  row.right:SetPoint("RIGHT", rightEdge, 0)
  row.right:SetText(item.right or "")
  row.text:SetPoint("RIGHT", row.right, "LEFT", -6, 0)
  row.item = item
end

--- A virtual list: only the rows on screen exist (about 25 frames), however long the data
--- is. Rows are re-bound to items as you scroll.
function UI.List(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(10, 10)
  scroll:SetScrollChild(content)
  local list = { scroll = scroll, content = content, rows = {}, items = {} }

  local function render()
    local items = list.items
    local width = scroll:GetWidth()
    if width < 50 then width = 400 end
    content:SetWidth(width)
    local height = scroll:GetHeight()
    if height < ROW_H then height = 440 end
    local first = math.floor(scroll:GetVerticalScroll() / ROW_H) + 1
    if first < 1 then first = 1 end
    local visible = math.ceil(height / ROW_H) + 1
    local used = 0
    for i = first, math.min(#items, first + visible - 1) do
      used = used + 1
      local row = list.rows[used]
      if not row then row = makeRow(list); list.rows[used] = row end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
      layoutRow(row, items[i], width)
      row:Show()
    end
    for i = used + 1, #list.rows do list.rows[i]:Hide(); list.rows[i].item = nil end
  end

  function list:SetItems(items)
    self.items = items
    content:SetHeight(math.max(10, #items * ROW_H))
    local maxScroll = math.max(0, #items * ROW_H - scroll:GetHeight())
    if scroll:GetVerticalScroll() > maxScroll then scroll:SetVerticalScroll(maxScroll) end
    render()
  end

  scroll:HookScript("OnVerticalScroll", render)
  scroll:HookScript("OnSizeChanged", render)
  scroll:HookScript("OnShow", render)
  return list
end

---------------------------------------------------------------------------------------------
-- Context menu: modern MenuUtil, else EasyMenu, else a stock-styled button stack.
-- items = { { text, func }, ... }
---------------------------------------------------------------------------------------------

local fallbackMenu
function UI.Menu(owner, items)
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      for _, it in ipairs(items) do root:CreateButton(it.text, it.func) end
    end)
    return
  end
  if EasyMenu then
    local menu = {}
    for _, it in ipairs(items) do menu[#menu + 1] = { text = it.text, func = it.func, notCheckable = true } end
    menu[#menu + 1] = { text = CANCEL, notCheckable = true }
    local dd = _G.LoreseekerMenuDropDown or CreateFrame("Frame", "LoreseekerMenuDropDown", UIParent, "UIDropDownMenuTemplate")
    EasyMenu(menu, dd, "cursor", 0, 0, "MENU")
    return
  end
  if not fallbackMenu then
    fallbackMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    fallbackMenu:SetFrameStrata("DIALOG")
    fallbackMenu:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    fallbackMenu:SetBackdropColor(0, 0, 0, 0.9)
    fallbackMenu.buttons = {}
  end
  local m = fallbackMenu
  for _, b in ipairs(m.buttons) do b:Hide() end
  local all = {}
  for _, it in ipairs(items) do all[#all + 1] = it end
  all[#all + 1] = { text = CANCEL, func = function() end }
  for i, it in ipairs(all) do
    local b = m.buttons[i] or UI.Button(m, "", 200, 22)
    m.buttons[i] = b
    b:SetText(it.text)
    b:ClearAllPoints()
    b:SetPoint("TOP", 0, -8 - (i - 1) * 24)
    b:SetScript("OnClick", function() m:Hide(); it.func() end)
    b:Show()
  end
  m:SetSize(216, 16 + #all * 24)
  m:ClearAllPoints()
  m:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -2)
  m:Show()
end

---------------------------------------------------------------------------------------------
-- Positions
---------------------------------------------------------------------------------------------

function UI.MakeMovable(frame, key)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    LW.char.frames[key] = { point, relPoint, x, y }
  end)
end

function UI.RestorePosition(frame, key, ...)
  local p = LW.char.frames[key]
  frame:ClearAllPoints()
  if p then frame:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else frame:SetPoint(...) end
end

--- The skip actions offered for a task (used by the step panel and the Guide tab).
function UI.SkipMenu(owner, task, extra)
  local e = task.quest
  local items = {}
  for _, it in ipairs(extra or {}) do items[#items + 1] = it end
  if task.kind == "accept" then
    items[#items + 1] = { text = L["NPC won't offer this"], func = function() LW.Offers:Mark(e.id) end }
  end
  for _, it in ipairs({
    { text = L["Skip this quest"], func = function()
      LW.Skips:Prompt(string.format(L["Skip quest: %s"], e.name), function(n, l) LW.Skips:AddQuest(e.id, n, l) end) end },
    { text = L["Skip this whole storyline"], func = function()
      LW.Skips:Prompt(string.format(L["Skip the storyline of: %s"], e.name), function(n, l) LW.Skips:AddChain(e.id, n, l) end) end },
    { text = L["Skip the area around me"], func = function()
      LW.Skips:Prompt(string.format(L["Skip the area around you (%s)"], GetSubZoneText() or ""), function(n, l) LW.Skips:AddAreaHere(nil, n, l) end) end },
    { text = string.format(L["Skip zone: %s"], LW.MapName(task.map)), func = function()
      local area = LW.Adapter:AreaForMap(task.map)
      if not area then LW:Print(L["Unknown zone."]) return end
      LW.Skips:Prompt(string.format(L["Skip the zone %s"], LW.MapName(task.map)), function(n, l) LW.Skips:AddZone(area, n, l) end) end },
    { text = L["Not now (snooze 10 min)"], func = function() LW.Router:Snooze(task) end },
  }) do items[#items + 1] = it end
  UI.Menu(owner, items)
end

--- Hover hint shared by clickable quest rows.
UI.STORY_HINT = L["Click: open its storyline."]
