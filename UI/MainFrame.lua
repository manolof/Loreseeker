-- The main window: a stock Blizzard portrait frame with bottom tabs.
local _, LW = ...
local L = LW.L

local M = { tabs = {} }
LW.Main = M

--- Tab modules call this at load: def = { key, label, Build(self, panel), Refresh(self) }
function M:AddTab(def)
  table.insert(self.tabs, def)
end

local function tryCreate(template)
  local ok, f = pcall(CreateFrame, "Frame", "LoreseekerFrame", UIParent, template)
  return ok and f or nil
end

local function tryTab(parent, i)
  for _, template in ipairs({ "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate", "CharacterFrameTabTemplate" }) do
    local ok, tab = pcall(CreateFrame, "Button", "LoreseekerFrameTab" .. i, parent, template)
    if ok and tab then return tab end
  end
  return CreateFrame("Button", "LoreseekerFrameTab" .. i, parent, "UIPanelButtonTemplate")
end

function M:Create()
  local f = tryCreate("ButtonFrameTemplate") or tryCreate("PortraitFrameTemplate") or tryCreate("BasicFrameTemplateWithInset")
  f:SetSize(720, 520)
  f:SetFrameStrata("HIGH")
  f:SetToplevel(true)
  f:Hide()
  LW.UI.MakeMovable(f, "main")
  LW.UI.RestorePosition(f, "main", "CENTER", UIParent, "CENTER", 0, 40)
  table.insert(UISpecialFrames, "LoreseekerFrame")

  local title = L["Loreseeker"]
  if f.SetTitle then f:SetTitle(title)
  elseif f.TitleText then f.TitleText:SetText(title)
  elseif f.TitleContainer and f.TitleContainer.TitleText then f.TitleContainer.TitleText:SetText(title) end

  local icon = "Interface\\Icons\\INV_Misc_Book_11"
  if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, icon)
  elseif f.portrait then SetPortraitToTexture(f.portrait, icon)
  elseif f.PortraitContainer and f.PortraitContainer.portrait then SetPortraitToTexture(f.PortraitContainer.portrait, icon) end
  if ButtonFrameTemplate_HideButtonBar then pcall(ButtonFrameTemplate_HideButtonBar, f) end

  -- Content area: inside the inset when the template has one.
  local inset = f.Inset
  local body = CreateFrame("Frame", nil, f)
  if inset then
    body:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    body:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -6, 6)
  else
    body:SetPoint("TOPLEFT", 12, -30)
    body:SetPoint("BOTTOMRIGHT", -12, 12)
  end

  f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.summary:SetPoint("TOPRIGHT", -12, -32)
  f.summary:SetJustifyH("RIGHT")
  if inset then
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", -6, 6)
  end

  for i, def in ipairs(self.tabs) do
    local panel = CreateFrame("Frame", nil, body)
    panel:SetAllPoints()
    panel:Hide()
    def.panel = panel
    def:Build(panel)

    local tab = tryTab(f, i)
    tab:SetID(i)
    tab:SetText(def.label)
    if i == 1 then tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
    else tab:SetPoint("LEFT", _G["LoreseekerFrameTab" .. (i - 1)], "RIGHT", -14, 0) end
    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    tab:SetScript("OnClick", function() M:Select(i) end)
    def.tab = tab
  end
  if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(f, #self.tabs) end

  f:SetScript("OnShow", function() M:Select(M.selected or 1) end)
  self.frame = f
  LW:Listen("UPDATED", function() if f:IsShown() then M:RefreshCurrent() end end)
  LW:Listen("PLANNED", function() if f:IsShown() and M.tabs[M.selected or 1].key == "guide" then M:RefreshCurrent() end end)
  LW:Listen("SKIPS_CHANGED", function() if f:IsShown() then M:RefreshCurrent() end end)
end

function M:Select(i)
  self.selected = i
  for j, def in ipairs(self.tabs) do
    if j == i then def.panel:Show() else def.panel:Hide() end
  end
  if PanelTemplates_SetTab then PanelTemplates_SetTab(self.frame, i) end
  self:RefreshCurrent()
end

function M:SelectKey(key)
  for i, def in ipairs(self.tabs) do
    if def.key == key then
      self.frame:Show()
      self:Select(i)
      return
    end
  end
end

function M:RefreshCurrent()
  local c = LW.Eligibility.counts or {}
  self.frame.summary:SetText(string.format(L["%d done  -  %d available  -  %d in log  -  %d later  -  %d skipped"],
    c.done or 0, c.now or 0, c.active or 0, c.later or 0, c.skipped or 0))
  local def = self.tabs[self.selected or 1]
  if def and def.Refresh then
    local ok, err = pcall(def.Refresh, def)
    if not ok then geterrorhandler()(err) end
  end
end

function M:Toggle()
  if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
end
