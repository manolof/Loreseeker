-- A small book button on the game's own quest log details: opens that quest's storyline.
-- Forever uses the map-attached log (QuestMapFrame.DetailsFrame); Classic-style clients use
-- QuestLogFrame. Spoken puts its buttons at the right of the header, so ours sits on the left.
local _, LW = ...
local L = LW.L

local QL = {}
LW.QuestLogLink = QL

local function makeButton(parent)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(22, 22)
  b:SetNormalTexture("Interface\\Icons\\INV_Misc_Book_09")
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetPushedTexture("Interface\\Icons\\INV_Misc_Book_09")
  b:GetPushedTexture():SetVertexColor(0.7, 0.7, 0.7)
  b:SetScript("OnClick", function(self) if self.questID then LW.Main:ShowStory(self.questID) end end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Loreseeker"])
    GameTooltip:AddLine(L["Open this quest's storyline."], 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function update(b, id)
  b.questID = (id and id > 0) and id or nil
  b:SetShown(b.questID ~= nil and LW.Index.ready)
end

function QL:SetupMap()
  local details = _G.QuestMapFrame and QuestMapFrame.DetailsFrame
  if self.mapButton or type(details) ~= "table" or not _G.QuestMapFrame_ShowQuestDetails then return end
  local header = details.BackFrame or details
  local b = makeButton(header)
  b:SetFrameLevel(header:GetFrameLevel() + 3)
  local back = header.BackButton
  if back then b:SetPoint("LEFT", back, "RIGHT", 6, 0) else b:SetPoint("TOPLEFT", header, "TOPLEFT", 4, -2) end
  self.mapButton = b
  hooksecurefunc("QuestMapFrame_ShowQuestDetails", function(questID)
    update(b, questID or details.questID or (C_QuestLog.GetSelectedQuest and C_QuestLog.GetSelectedQuest()))
  end)
  b:Hide()
end

function QL:SetupClassicLog()
  local frame, details = _G.QuestLogFrame, _G.QuestLogDetailScrollFrame
  if self.logButton or type(frame) ~= "table" or type(details) ~= "table" or not GetQuestLogSelection then return end
  local b = makeButton(frame)
  b:SetFrameLevel(details:GetFrameLevel() + 5)
  b:SetPoint("TOPRIGHT", details, "TOPRIGHT", -30, -2) -- left of Spoken's button
  self.logButton = b
  local function refresh()
    local index = GetQuestLogSelection()
    local id = index and index > 0 and GetQuestLogTitle and select(8, GetQuestLogTitle(index)) or nil
    update(b, id)
  end
  for _, name in ipairs({ "QuestLog_UpdateQuestDetails", "QuestLog_Update" }) do
    if type(_G[name]) == "function" then hooksecurefunc(name, refresh) end
  end
  frame:HookScript("OnShow", refresh)
end

function QL:Setup()
  pcall(self.SetupMap, self)
  pcall(self.SetupClassicLog, self)
end

-- The map (and its quest log) can load on demand: try again whenever a Blizzard UI loads.
LW:OnEvent("ADDON_LOADED", function(_, name)
  if LW.Main.frame and type(name) == "string" and name:find("^Blizzard_") then QL:Setup() end
end)
