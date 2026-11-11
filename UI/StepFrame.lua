-- The compact "do this next" panel, styled like a tooltip / quest tracker.
local _, LW = ...
local L = LW.L

local SF = {}
LW.StepFrame = SF

local KIND_VERB = {
  accept = L["Accept"], turnin = L["Turn in"], kill = L["Kill"], loot = L["Collect"], object = L["Use"],
  buy = L["Buy"], auction = L["Buy"], craft = L["Craft"], flightpoint = L["Discover"], explore = L["Explore"], generic = L["Work on"],
}

function SF:Create()
  local f = CreateFrame("Frame", "LoreseekerStepFrame", UIParent, "BackdropTemplate")
  f:SetSize(320, 118)
  f:SetFrameStrata("MEDIUM")
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  f:SetBackdropColor(0, 0, 0, 0.75)
  f:SetBackdropBorderColor(1, 0.82, 0, 0.8)
  LW.UI.MakeMovable(f, "step")
  LW.UI.RestorePosition(f, "step", "RIGHT", UIParent, "RIGHT", -60, 120)

  f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.header:SetPoint("TOPLEFT", 10, -8)
  f.header:SetText(L["Loreseeker"])

  f.icon = f:CreateTexture(nil, "ARTWORK")
  f.icon:SetSize(28, 28)
  f.icon:SetPoint("TOPLEFT", 10, -24)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 8, 0)
  f.title:SetPoint("RIGHT", -10, 0)
  f.title:SetJustifyH("LEFT")
  f.title:SetWordWrap(false)

  f.action = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.action:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -2)
  f.action:SetPoint("RIGHT", -10, 0)
  f.action:SetJustifyH("LEFT")
  f.action:SetWordWrap(false)

  f.where = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.where:SetPoint("TOPLEFT", f.action, "BOTTOMLEFT", 0, -2)
  f.where:SetPoint("RIGHT", -10, 0)
  f.where:SetJustifyH("LEFT")
  f.where:SetTextColor(0.75, 0.75, 0.75)

  f.story = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.story:SetPoint("TOPLEFT", f.icon, "BOTTOMLEFT", 0, -20)
  f.story:SetPoint("RIGHT", -10, 0)
  f.story:SetJustifyH("LEFT")
  f.story:SetWordWrap(false)

  -- Click the quest (title down to the story line) to open its storyline.
  f.link = CreateFrame("Button", nil, f)
  f.link:SetPoint("TOPLEFT", f.icon, "TOPLEFT", 0, 0)
  f.link:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 30)
  f.link:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  f.link:SetScript("OnClick", function() if SF.task then LW.Main:ShowStory(SF.task.quest.id) end end)
  f.link:SetScript("OnEnter", function(self)
    if not SF.task then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(SF.task.quest.name)
    GameTooltip:AddLine(L["Click: open its storyline."], 1, 1, 1)
    GameTooltip:Show()
  end)
  f.link:SetScript("OnLeave", function() GameTooltip:Hide() end)
  f.link:RegisterForDrag("LeftButton") -- dragging on the text still moves the panel
  f.link:SetScript("OnDragStart", function() f:StartMoving() end)
  f.link:SetScript("OnDragStop", function() f:GetScript("OnDragStop")(f) end)

  local function btn(text, w) return LW.UI.Button(f, text, w, 20) end
  f.skip = btn(L["Skip..."], 64)
  f.skip:SetPoint("BOTTOMLEFT", 8, 8)
  f.next = btn(L["Next"], 56)
  f.next:SetPoint("LEFT", f.skip, "RIGHT", 4, 0)
  f.listen = btn(L["Listen"], 62)
  f.listen:SetPoint("LEFT", f.next, "RIGHT", 4, 0)
  f.open = btn(L["Guide"], 62)
  f.open:SetPoint("LEFT", f.listen, "RIGHT", 4, 0)
  -- The panel widens when the buttons grow (longer words in other languages, "Stop").
  local function fitWidth()
    local w = 16 + f.skip:GetWidth() + f.next:GetWidth() + f.listen:GetWidth() + f.open:GetWidth() + 12
    f:SetWidth(math.max(320, w))
  end
  for _, b in ipairs({ f.skip, f.next, f.listen, f.open }) do b.OnResize = fitWidth end
  fitWidth()

  f.skip:SetScript("OnClick", function(self) if SF.task then LW.UI.SkipMenu(self, SF.task) end end)
  f.next:SetScript("OnClick", function() if SF.task then LW.Router:Snooze(SF.task) end end)
  f.listen:SetScript("OnClick", function()
    local t = SF.task
    if t then LW.Voice:Toggle(t.quest.id, t.kind == "turnin" and "complete" or "accept") end
  end)
  LW:Listen("VOICE_STATE", function() SF:UpdateListen() end)
  f.open:SetScript("OnClick", function() LW.Main:Toggle() end)

  f.next:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["Next suggestion"])
    GameTooltip:AddLine(L["Puts this step aside for 10 minutes."], 1, 1, 1, true)
    GameTooltip:Show()
  end)
  f.next:SetScript("OnLeave", function() GameTooltip:Hide() end)

  self.frame = f
  LW:Listen("ROUTED", function(task) SF:Show(task) end)
  if not LW.db.showStep then f:Hide() end
end

function SF:Show(task)
  local f = self.frame
  if not f then return end
  self.task = task
  if not task then
    f.icon:SetTexture(LW.UI.ICONS.done)
    f.title:SetText(L["Nothing to do here right now"])
    f.action:SetText(L["Check the Guide tab for Later and Group-up quests."])
    f.where:SetText("")
    f.story:SetText("")
    LW.Arrow:SetTarget(nil)
    return
  end
  local e = task.quest
  -- header: how much more the plan has for you at this same spot ("on the way")
  local more = LW.Router.planned and LW.Planner:MoreHere() or 0
  f.header:SetText(more > 0 and string.format(L["Loreseeker  -  %d more to do right here"], more) or L["Loreseeker"])
  f.icon:SetTexture(LW.UI.ICONS[task.kind] or LW.UI.ICONS.generic)
  f.title:SetText(LW.UI.QuestLabel(e))

  local action = task.text
  if task.target and task.target ~= "" then
    action = action .. " - " .. task.target
  end
  if task.kind == "accept" and LW.Router.logFull then
    action = L["|cffff2020Your quest log is full.|r Finish or drop a quest first."]
  end
  f.action:SetText(task.detail and (action .. "  |cffffffff(" .. task.detail .. ")|r") or action)

  local p = task.point
  local leg = task.legs and task.legs[1] -- a flight, boat or tram to take first
  if leg then
    local more = #task.legs > 1 and (" " .. string.format(L["(+%d more)"], #task.legs - 1)) or ""
    f.where:SetText(string.format(L["|cffffd100%s|r%s - about %s"], leg.text, more, LW.Travel.FormatTime(task.travel)))
  elseif task.kind == "craft" then
    f.where:SetText(string.format(L["Open your %s window: you know this recipe"], task.target or L["profession"]))
  elseif p then
    local dist = task.dist and " - " .. string.format(L["%d yd"], task.dist) or ""
    f.where:SetText(string.format("%s %.1f, %.1f%s", LW.MapName(p.map), p.x * 100, p.y * 100, dist))
  else
    f.where:SetText(L["No known location"])
  end

  local chain = LW.Chains:Get(e.chain)
  local curated = LW.Storylines:For(e)
  if chain then
    local done, total = LW.Chains:Progress(chain)
    f.story:SetText(string.format("%s" .. L["Story: %s - %d/%d"], curated and "|TInterface\\Icons\\INV_Misc_Book_09:12|t " or "",
      LW.Chains:Name(chain), done, total))
  elseif curated then
    f.story:SetText("|TInterface\\Icons\\INV_Misc_Book_09:12|t " .. string.format(L["Story: %s"], LW.StorylineName(curated)))
  else
    f.story:SetText("")
  end

  self:UpdateListen()
  if leg then
    LW.Arrow:SetTarget(leg.at, leg.hint and (leg.hint .. ": " .. leg.text) or leg.text)
  else
    LW.Arrow:SetTarget(p, (KIND_VERB[task.kind] or "") .. ": " .. e.name)
  end
end

function SF:UpdateListen()
  local f, t = self.frame, self.task
  if not (f and t) then return end
  local event = t.kind == "turnin" and "complete" or "accept"
  if LW.Voice:IsPlaying(t.quest.id, event) then
    f.listen:SetText(L["Stop"])
    f.listen:Enable()
  else
    f.listen:SetText(L["Listen"])
    if LW.Voice:CanPlay(t.quest.id, event) then f.listen:Enable() else f.listen:Disable() end
  end
end

function SF:Toggle()
  LW.db.showStep = not LW.db.showStep
  if LW.db.showStep then self.frame:Show() else self.frame:Hide() end
end
