-- Journal tab: every quest story you've read, by zone, on a parchment page.
local _, LW = ...
local UI = LW.UI

local tab = { key = "journal", label = "Journal" }

local TEXT_COLOR = { 0.18, 0.12, 0.06 } -- Blizzard's quest-text brown on parchment

function tab:Build(panel)
  self.list = UI.List(panel)
  self.list.scroll:SetPoint("TOPLEFT", 0, 0)
  self.list.scroll:SetPoint("BOTTOMLEFT", 0, 0)
  self.list.scroll:SetWidth(250)

  local page = CreateFrame("Frame", nil, panel)
  page:SetPoint("TOPLEFT", self.list.scroll, "TOPRIGHT", 30, 0)
  page:SetPoint("BOTTOMRIGHT", 0, 30)
  local bg = page:CreateTexture(nil, "BACKGROUND")
  bg:SetTexture("Interface\\Stationery\\StationeryTest1")
  bg:SetAllPoints()
  bg:SetTexCoord(0, 1, 0, 0.75)

  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -12)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(10, 10)
  scroll:SetScrollChild(content)
  local text = content:CreateFontString(nil, "ARTWORK", "QuestFont")
  text:SetPoint("TOPLEFT")
  text:SetJustifyH("LEFT")
  text:SetJustifyV("TOP")
  text:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
  text:SetSpacing(2)
  self.scroll, self.content, self.text = scroll, content, text

  self.listenOffer = UI.Button(panel, "Listen: offer", 110, 22)
  self.listenOffer:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, -28)
  self.listenOffer:SetScript("OnClick", function() if tab.selected then LW.Voice:Toggle(tab.selected, "accept") end end)
  self.listenDone = UI.Button(panel, "Listen: turn-in", 120, 22)
  self.listenDone:SetPoint("LEFT", self.listenOffer, "RIGHT", 6, 0)
  self.listenDone:SetScript("OnClick", function() if tab.selected then LW.Voice:Toggle(tab.selected, "complete") end end)
  LW:Listen("VOICE_STATE", function() tab:UpdateListen() end)
  self.storyBtn = UI.Button(panel, "Storyline", 90, 22)
  self.storyBtn:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, -28)
  self.storyBtn:SetScript("OnClick", function() if tab.selected then LW.Main:ShowStory(tab.selected) end end)

  self.text:SetText("Pick a quest on the left. Every quest you read from now on is saved here.")
end

local function section(title, body)
  if not body or body == "" then return "" end
  return "|cff000000" .. title .. "|r\n" .. body .. "\n\n"
end

function tab:Show(questId)
  self.selected = questId
  local p = LW.Journal:Get(questId)
  if not p then
    self.text:SetText("Nothing recorded for this quest yet.")
  else
    local body = section("Description", p.detail) .. section("Objectives", p.objective) ..
      section("Progress", p.progress) .. section("Completion", p.complete)
    if not p.captured then body = body .. "|cff555555(Text from Spoken's library; your own copy is saved the next time you read it.)|r" end
    self.text:SetText(p.title .. "\n\n" .. body)
  end
  local w = self.scroll:GetWidth()
  self.text:SetWidth(w > 50 and w or 380)
  self.content:SetWidth(w > 50 and w or 380)
  self.content:SetHeight(self.text:GetStringHeight() + 20)
  self.scroll:SetVerticalScroll(0)
  local e = LW.Index:Get(questId)
  if e and LW.Chains:Get(e.chain) then self.storyBtn:Enable() else self.storyBtn:Disable() end
  self:UpdateListen()
end

function tab:UpdateListen()
  local id = self.selected
  if not id then return end
  for _, b in ipairs({ { self.listenOffer, "accept", "Listen: offer" }, { self.listenDone, "complete", "Listen: turn-in" } }) do
    local button, event, label = b[1], b[2], b[3]
    if LW.Voice:IsPlaying(id, event) then
      button:SetText("Stop")
      button:Enable()
    else
      button:SetText(label)
      if LW.Voice:CanPlay(id, event) then button:Enable() else button:Disable() end
    end
  end
end

function tab:Refresh()
  local ids = LW.Journal:Entries()
  local rows = {}
  for _, id in ipairs(ids) do
    local title, zone = LW.Journal:Head(id)
    rows[#rows + 1] = { id = id, title = title, zone = zone and LW.ZoneName(zone) or "Unknown" }
  end
  table.sort(rows, function(a, b)
    if a.zone ~= b.zone then return a.zone < b.zone end
    return a.title < b.title
  end)
  local items, lastZone = {}, nil
  for _, r in ipairs(rows) do
    if r.zone ~= lastZone then
      items[#items + 1] = { header = true, text = r.zone }
      lastZone = r.zone
    end
    items[#items + 1] = { indent = 1, text = r.title, onClick = function() tab:Show(r.id) end }
  end
  if #items == 0 then items[1] = { dim = true, text = "No stories yet. Go read some quests!" } end
  self.list:SetItems(items)
  if self.selected then self:Show(self.selected) else
    self.listenOffer:Disable(); self.listenDone:Disable()
  end
end

function LW.Main:ShowJournal(questId)
  self:SelectKey("journal")
  tab:Show(questId)
end

LW.Main:AddTab(tab)
