local _, ns = ...

ns.GuidePage = ns.GuidePage or {}

local GuidePage = ns.GuidePage

local WOWPROF_ICON = "Interface\\Common\\Help-i"
local WOWHEAD_ICON = "Interface\\FriendsFrame\\InformationIcon"

GuidePage.frame = nil
GuidePage.scrollFrame = nil
GuidePage.scrollChild = nil

GuidePage.currentGuide = nil
GuidePage.materialRows = GuidePage.materialRows or {}
GuidePage.stepRows = GuidePage.stepRows or {}

local function MakeHeader(parent, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")

  return fs
end

local function MakeText(parent, template, width)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")

  if width then
    fs:SetWidth(width)
  end

  return fs
end

local function MakeIconButton(parent, texturePath, tooltipText)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(18, 18)

  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  t:SetTexture(texturePath)
  b._tex = t

  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetText(tooltipText or "")
    GameTooltip:Show()
  end)

  b:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  return b
end

local function GetItemName(itemID)
  if not itemID then
    return nil
  end

  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then
      return name
    end
  end

  return ("Item %d"):format(tonumber(itemID) or 0)
end

local function ClearRows(rows)
  for _, row in ipairs(rows) do
    row:Hide()
  end

  wipe(rows)
end

function GuidePage:Create(parent)
  if self.frame then
    return self.frame
  end

  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)
  page:Hide()
  self.frame = page

  -- Scroll frame
  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -12)
  scroll:SetPoint("BOTTOMRIGHT", -30, 12)
  self.scrollFrame = scroll

  local child = CreateFrame("Frame", nil, scroll)
  child:SetPoint("TOPLEFT", 0, 0)
  child:SetPoint("TOPRIGHT", 0, 0)
  child:SetWidth(1)
  child:SetHeight(1)
  scroll:SetScrollChild(child)
  self.scrollChild = child

  -- Title
  local title = MakeHeader(child, "Leveling Guide")
  title:SetPoint("TOPLEFT", 18, -8)
  title:SetPoint("TOPRIGHT", -18, -8)
  self.titleText = title

  -- Materials header and container
  local materialsHeader = MakeHeader(child, "Materials Required")
  materialsHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
  self.materialsHeader = materialsHeader

  local materialsContainer = CreateFrame("Frame", nil, child)
  materialsContainer:SetPoint("TOPLEFT", materialsHeader, "BOTTOMLEFT", 0, -10)
  materialsContainer:SetPoint("TOPRIGHT", -18, 0)
  materialsContainer:SetHeight(1)
  self.materialsContainer = materialsContainer

  -- Steps header and container
  local stepsHeader = MakeHeader(child, "Leveling Guide")
  stepsHeader:SetPoint("TOPLEFT", materialsContainer, "BOTTOMLEFT", 0, -20)
  self.stepsHeader = stepsHeader

  local stepsContainer = CreateFrame("Frame", nil, child)
  stepsContainer:SetPoint("TOPLEFT", stepsHeader, "BOTTOMLEFT", 0, -10)
  stepsContainer:SetPoint("TOPRIGHT", -18, 0)
  stepsContainer:SetHeight(1)
  self.stepsContainer = stepsContainer

  page:RegisterEvent("BAG_UPDATE_DELAYED")
  page:SetScript("OnEvent", function()
    GuidePage:RefreshMaterialsState()
  end)

  return page
end

function GuidePage:LoadForProfession(professionInfo)
  if not (self.frame and self.frame:IsShown()) then
    -- Still allow data to be prepared even if the tab is not currently visible
  end

  local guide = ns.Guides and ns.Guides.GetBestGuide and ns.Guides:GetBestGuide(professionInfo) or nil
  self.currentGuide = guide

  self:RenderGuide(guide)
end

function GuidePage:RenderGuide(guide)
  if not self.scrollChild then
    return
  end

  ClearRows(self.materialRows)
  ClearRows(self.stepRows)

  if not guide then
    self.titleText:SetText("Leveling Guide")
    self.materialsHeader:SetText("Materials Required")
    self.stepsHeader:SetText("Leveling Guide")

    local row = CreateFrame("Frame", nil, self.scrollChild)
    row:SetPoint("TOPLEFT", self.materialsHeader, "BOTTOMLEFT", 0, -10)
    row:SetPoint("TOPRIGHT", -18, 0)
    row:SetHeight(20)

    local fs = MakeText(row, "GameFontHighlight", 600)
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText("No guide available for this profession.")
    row._text = fs

    table.insert(self.materialRows, row)

    self:Layout()
    return
  end

  self.titleText:SetText(guide.title or "Leveling Guide")

  -- Materials
  local materials = (ns.Guides and ns.Guides.GetMaterials) and ns.Guides:GetMaterials(guide) or (guide.materials or {})
  local prev = nil

  for _, mat in ipairs(materials) do
    local row = CreateFrame("Frame", nil, self.materialsContainer)
    row:SetHeight(18)

    if not prev then
      row:SetPoint("TOPLEFT", 0, 0)
      row:SetPoint("TOPRIGHT", 0, 0)
    else
      row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
      row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -6)
    end
    prev = row

    row._mat = mat

    local fs = MakeText(row, "GameFontHighlight", 600)
    fs:SetPoint("LEFT", 0, 0)
    row._text = fs

    -- WoW-Professions link button
    local wp = MakeIconButton(row, WOWPROF_ICON, "WoW-Professions")
    wp:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    wp:SetScript("OnClick", function()
      if ns.LinkPopup and ns.LinkPopup.Show and mat.wowProfessionsUrl then
        ns.LinkPopup:Show("WoW-Professions", mat.wowProfessionsUrl)
      end
    end)
    row._wpBtn = wp

    -- Wowhead link button
    local wh = MakeIconButton(row, WOWHEAD_ICON, "Wowhead")
    wh:SetPoint("LEFT", wp, "RIGHT", 6, 0)
    wh:SetScript("OnClick", function()
      if ns.LinkPopup and ns.LinkPopup.Show and mat.itemID then
        ns.LinkPopup:Show("Wowhead", ns.Util.GetWowheadItemUrl(mat.itemID))
      end
    end)
    row._whBtn = wh

    table.insert(self.materialRows, row)
  end

  -- Apply initial counts/grey-out state for materials
  self:RefreshMaterialsState()

  -- Steps
  prev = nil
  for _, step in ipairs(guide.steps or {}) do
    local row = CreateFrame("Frame", nil, self.stepsContainer)
    row:SetHeight(44)

    if not prev then
      row:SetPoint("TOPLEFT", 0, 0)
      row:SetPoint("TOPRIGHT", 0, 0)
    else
      row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -10)
      row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -10)
    end
    prev = row

    row._step = step

    local header = MakeText(row, "GameFontNormal", 600)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(("%d - %d"):format(tonumber(step.fromSkill) or 0, tonumber(step.toSkill) or 0))
    row._header = header

    local craftBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    craftBtn:SetSize(240, 22)
    craftBtn:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -6)
    craftBtn:SetText(step.recipeName or "Craft")
    craftBtn:SetScript("OnClick", function()
      if not (ns.CraftRunner and ns.CraftRunner.Start) then
        return
      end

      ns.CraftRunner:Start(step, function()
        -- Re-render to refresh visible state.
        if GuidePage.currentGuide then
          GuidePage:RenderGuide(GuidePage.currentGuide)
        end
      end)
    end)
    row._craftBtn = craftBtn

    table.insert(self.stepRows, row)
  end

  self:Layout()
end

function GuidePage:RefreshMaterialsState()
  if not self.currentGuide then
    return
  end

  for _, row in ipairs(self.materialRows) do
    if row._mat and row._text then
      local mat = row._mat
      local itemID = mat.itemID
      local required = tonumber(mat.required) or 0
      local have = ns.Util.GetItemCount(itemID)

      local name = GetItemName(itemID)
      row._text:SetText("%s |cffFFFFFF|r / |cffFFFFFF%d|r"):format(name, have, required)

      local done = required > 0 and have >= required
      ns.Util.SetFontStringGreyed(row._text, done)

      if row._wpBtn and row._wpBtn._tex then
        row._wpBtn:SetEnabled(not done)
        ns.Util.SetDesaturatedAndAlpha(row._wpBtn._tex, done, done and 0.35 or 1)
      end

      if row._whBtn and row._whBtn._tex then
        row._whBtn:SetEnabled(not done)
        ns.Util.SetDesaturatedAndAlpha(row._whBtn._tex, done, done and 0.35 or 1)
      end
    end
  end
end

function GuidePage:Layout()
  if not (self.scrollFrame and self.scrollChild) then
    return
  end

  -- Keep child width aligned to scroll frame width for wrapping
  local w = self.scrollFrame:GetWidth()
  if w and w > 60 then
    self.scrollChild:SetWidth(w - 28)
  end

  -- Materials container height
  local matsHeight = 0
  for _, row in ipairs(self.materialRows) do
    if row:IsShown() then
      matsHeight = matsHeight + row:GetHeight() + 6
    end
  end

  if matsHeight > 0 then
    matsHeight = matsHeight - 6
  end
  self.materialsContainer:SetHeight(math.max(1, matsHeight))

  -- Steps container height
  local stepsHeight = 0
  for _, row in ipairs(self.stepRows) do
    if row:IsShown() then
      stepsHeight = stepsHeight + row:GetHeight() + 10
    end
  end

  if stepsHeight > 0 then
    stepsHeight = stepsHeight - 10
  end
  self.stepsContainer:SetHeight(math.max(1, stepsHeight))

  -- Total scroll child height
  local total =
    8 + self.titleText:GetHeight()
    + 16 + self.materialsHeader:GetHeight()
    + 10 + self.materialsContainer:GetHeight()
    + 20 + self.stepsHeader:GetHeight()
    + 10 + self.stepsContainer:GetHeight()
    + 20

  self.scrollChild:SetHeight(math.max(total, self.scrollFrame:GetHeight()))
end
