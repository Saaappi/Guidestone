local _, ns = ...

ns.GuidePage = ns.GuidePage or {}

local GuidePage = ns.GuidePage

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

    local name = GetItemName(mat.itemID)
    local required = tonumber(mat.required) or 0

    local fs = MakeText(row, "GameFontHighlight", 600)
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText(("%s |cffFFFFFFx%d|r"):format(name, required))

    row._text = fs
    table.insert(self.materialRows, row)
  end

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

    local header = MakeText(row, "GameFontNormal", 600)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText(("%d - %d"):format(tonumber(step.fromSkill) or 0, tonumber(step.toSkill) or 0))

    local line = MakeText(row, "GameFontHighlight", 600)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    line:SetText(step.recipeName or "Unknown Recipe")

    row._header = header
    row._line = line
    table.insert(self.stepRows, row)
  end

  self:Layout()
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
