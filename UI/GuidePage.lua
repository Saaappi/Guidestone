local ADDON, ns = ...

ns.GuidePage = ns.GuidePage or {}

local Item = _G.Item

local GuidePage = ns.GuidePage

local WOWPROF_ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\WoWProfessions.png"
local WOWHEAD_ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Wowhead.png"

GuidePage.frame = nil
GuidePage.scrollFrame = nil
GuidePage.scrollChild = nil

GuidePage.currentGuide = nil
GuidePage.materialRows = GuidePage.materialRows or {}
GuidePage.stepRows = GuidePage.stepRows or {}
GuidePage.trainerRows = GuidePage.trainerRows or {}

GuidePage._pendingItemLoads = GuidePage._pendingItemLoads or {}

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
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then
    return "Unknown Item"
  end

  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then
      return name
    end
  end

  return ("Item %d"):format(tonumber(itemID) or 0)
end

local function GetItemIcon(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then
    return "Interface\\Icons\\INV_Misc_QuestionMark"
  end

  if C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
    if ok and icon then
      return icon
    end
  end

  -- GetItemInfoInstant is synchronous and normally will return an icon immediately.
  if C_Item and C_Item.GetItemInfoInstant then
    local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, itemID)
    if ok and icon then
      return icon
    end
  end

  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function ComputeBufferedRequired(required)
  required = tonumber(required) or 0
  if required <= 0 then
    return 0
  end

  -- 20% buffer, rounded up to nearest multiple of 5.
  local withBuffer = math.ceil(required * 1.2)
  local rem = withBuffer % 5
  if rem ~= 0 then
    withBuffer = withBuffer + (5 - rem)
  end
  return withBuffer
end

local function MakeIconButtonWithStates(parent, texturePath, tooltipText)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(18, 18)

  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  t:SetTexture(texturePath)
  b._tex = t

  -- Highlight (hover)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetTexture(texturePath)
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.35)
  b:SetHighlightTexture(hl)

  -- Pushed
  local pushed = b:CreateTexture(nil, "ARTWORK")
  pushed:SetAllPoints()
  pushed:SetTexture(texturePath)
  pushed:SetAlpha(0.90)
  pushed:SetVertexColor(0.80, 0.80, 0.80)
  b:SetPushedTexture(pushed)

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

local function ClearRows(rows)
  for _, row in ipairs(rows) do
    row:Hide()
  end

  wipe(rows)
end

local function IsNonEmptyString(s)
  return type(s) == "string" and s:gsub("%s+", "") ~= ""
end

function GuidePage:Create(parent)
  if self.frame then
    return self.frame
  end

  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)
  page:Hide()
  self.frame = page

  page.GetDesiredPageWidth = function()
    -- Match Blizzard profession tab widths so ProfessionsFrame:SetTab can resize safely.
    if ProfessionsUtil and ProfessionsUtil.IsCraftingMinimized and ProfessionsUtil.IsCraftingMinimized() then
      return 404
    end

    local compact = (C_TradeSkillUI and (C_TradeSkillUI.IsNPCCrafting() or C_TradeSkillUI.IsRuneforging()))
    return compact and 786 or 942
  end

  -- Scroll frame
  local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", 56, -44)
  scroll:SetPoint("BOTTOMRIGHT", -34, 28)
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

  -- Trainers header and container
  local trainersHeader = MakeHeader(child, "Trainers")
  trainersHeader:SetPoint("TOPLEFT", materialsContainer, "BOTTOMLEFT", 0, -20)
  self.trainersHeader = trainersHeader

  local trainersContainer = CreateFrame("Frame", nil, child)
  trainersContainer:SetPoint("TOPLEFT", trainersHeader, "BOTTOMLEFT", 0, -10)
  trainersContainer:SetPoint("TOPRIGHT", -18, 0)
  trainersContainer:SetHeight(1)
  self.trainersContainer = trainersContainer

  -- Steps header and container
  local stepsHeader = MakeHeader(child, "Leveling Guide")
  stepsHeader:SetPoint("TOPLEFT", trainersContainer, "BOTTOMLEFT", 0, -20)
  self.stepsHeader = stepsHeader

  local stepsContainer = CreateFrame("Frame", nil, child)
  stepsContainer:SetPoint("TOPLEFT", stepsHeader, "BOTTOMLEFT", 0, -10)
  stepsContainer:SetPoint("TOPRIGHT", -18, 0)
  stepsContainer:SetHeight(1)
  self.stepsContainer = stepsContainer

  page:RegisterEvent("BAG_UPDATE_DELAYED")
  page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  page:SetScript("OnEvent", function(_, event, arg1)
    if event == "BAG_UPDATE_DELAYED" then
      GuidePage:RefreshMaterialsState()
      return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
      local itemID = tonumber(arg1)
      if itemID and GuidePage._pendingItemLoads[itemID] then
        GuidePage._pendingItemLoads[itemID] = nil
        GuidePage:RefreshMaterialsState()
      end
    end
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

function GuidePage:RequestItemData(itemID)
  itemID = tonumber(itemID)
  if not itemID or itemID <= 0 then
    return
  end

  -- Check if the name is already available.
  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then
      return
    end
  end

  -- Avoid spamming
  if self._pendingItemLoads[itemID] then
    return
  end
  self._pendingItemLoads[itemID] = true

  if Item and Item.CreateFromItemID then
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
      -- Mark complete and refresh visible rows.
      GuidePage._pendingItemLoads[itemID] = nil
      GuidePage:RefreshMaterialsState()
    end)
  end
end

function GuidePage:RenderGuide(guide)
  if not self.scrollChild then
    return
  end

  ClearRows(self.materialRows)
  ClearRows(self.trainerRows)
  ClearRows(self.stepRows)

  if not guide then
    self.titleText:SetText("Leveling Guide")
    self.materialsHeader:SetText("Materials Required")
    self.trainersHeader:SetText("Trainers")
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

    -- Keep the main material line (icon/name/buttons) vertically stable
    -- even when the row grows to account for notes.
    local line = CreateFrame("Frame", nil, row)
    line:SetPoint("TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", 0, 0)
    line:SetHeight(18)
    row._line = line

    if not prev then
      row:SetPoint("TOPLEFT", 0, 0)
      row:SetPoint("TOPRIGHT", 0, 0)
    else
      row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -6)
      row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -6)
    end
    prev = row

    local icon = line:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("LEFT", 0, 0)
    icon:SetTexture(GetItemIcon(mat.itemID))
    row._icon = icon

    local fs = MakeText(line, "GameFontHighlight")
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    fs:SetWordWrap(false)
    row._text = fs
    row._mat = mat

    -- WoW-Professions link button
    local wp = MakeIconButtonWithStates(line, WOWPROF_ICON, "WoW-Professions")
    wp:SetPoint("RIGHT", line, "RIGHT", -24, 0)
    wp:SetScript("OnClick", function()
      if ns.LinkPopup and ns.LinkPopup.Show and mat.wowProfessionsUrl then
        ns.LinkPopup:Show("WoW-Professions", mat.wowProfessionsUrl)
      end
    end)
    row._wpBtn = wp

    -- Constrain text width
    if row._text then
      row._text:SetPoint("RIGHT", wp, "LEFT", -8, 0)
    end

    -- Wowhead link button
    local wh = MakeIconButtonWithStates(line, WOWHEAD_ICON, "Wowhead")
    wh:SetPoint("LEFT", wp, "RIGHT", 6, 0)
    wh:SetScript("OnClick", function()
      if ns.LinkPopup and ns.LinkPopup.Show and mat.itemID then
        ns.LinkPopup:Show("Wowhead", ns.Util.GetWowheadItemUrl(mat.itemID))
      end
    end)
    row._whBtn = wh

    -- Material note, when present, should not affect main line alignment.
    if IsNonEmptyString(mat.note) then
      local note = MakeText(row, "GameFontHighlightSmall")
      note:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
      note:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -2)
      note:SetText(mat.note)
      row._note = note

      -- Expand the row to fit the note without shifting the main line.
      row:SetHeight(18 + 2 + math.ceil(note:GetStringHeight() or 0))
    end

    table.insert(self.materialRows, row)
  end

  -- Apply initial counts/grey-out state for materials
  self:RefreshMaterialsState()

  -- Trainers
  local trainers = guide.trainers or {}
  local playerFaction = ns.Util.GetPlayerFactionFlag and ns.Util.GetPlayerFactionFlag() or 0
  local isTomTomEnabled = ns.Util.IsTomTomAvailable and ns.Util.IsTomTomAvailable() or false

  prev = nil
  local anyTrainer = false

  for _, trainer in ipairs(trainers) do
    local trainerFaction = tonumber(trainer.faction) or 0
    if trainerFaction == 0 or trainerFaction == playerFaction then
      anyTrainer = true

      local row = CreateFrame("Frame", nil, self.trainersContainer)

      if not prev then
        row:SetPoint("TOPLEFT", 0, 0)
        row:SetPoint("TOPRIGHT", 0, 0)
      else
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
        row:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -8)
      end
      prev = row

      row._trainer = trainer

      local name = MakeText(row, "GameFontNormal")
      name:SetPoint("TOPLEFT", 0, 0)
      name:SetPoint("TOPRIGHT", -120, 0)
      name:SetWordWrap(false)
      name:SetText(trainer.name or "Trainer")
      row._name = name

      local details = MakeText(row, "GameFontHighlightSmall")
      details:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
      details:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -2)

      local zone = trainer.zone or trainer.location or ""
      local x = tonumber(trainer.x)
      local y = tonumber(trainer.y)
      if zone ~= "" and x and y then
        details:SetText(("%s (%.1f, %.1f)"):format(zone, x, y))
      elseif zone ~= "" then
        details:SetText(zone)
      elseif x and y then
        details:SetText(("(%.1f, %.1f)"):format(x, y))
      else
        details:SetText("")
      end
      row._details = details

      local waypointBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      waypointBtn:SetSize(110, 20)
      waypointBtn:SetPoint("TOPRIGHT", 0, 0)
      waypointBtn:SetText(isTomTomEnabled and "TomTom" or "Waypoint")
      waypointBtn:SetScript("OnClick", function()
        if ns.Util and ns.Util.AddWaypoint then
          ns.Util.AddWaypoint(trainer.uiMapID, trainer.x, trainer.y, trainer.name)
        end
      end)
      row._waypointBtn = waypointBtn

      table.insert(self.trainerRows, row)
    end
  end

  if not anyTrainer then
    local row = CreateFrame("Frame", nil, self.trainersContainer)
    row:SetPoint("TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", 0, 0)
    row:SetHeight(18)

    local fs = MakeText(row, "GameFontHighlight")
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText("No trainers available in this guide.")
    row._details = fs

    table.insert(self.trainerRows, row)
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

    if IsNonEmptyString(step.note) then
      local note = MakeText(row, "GameFontHighlightSmall")
      note:SetPoint("TOPLEFT", craftBtn, "BOTTOMLEFT", 0, -4)
      note:SetText(step.note)
      row._note = note
    end

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
      local required = ComputeBufferedRequired(tonumber(mat.required) or 0)
      local have = ns.Util.GetItemCount(itemID)

      self:RequestItemData(itemID)

      local name = GetItemName(itemID)
      if not name or name == "" then
        name = ("Item %d"):format(tonumber(itemID) or 0)
      end
      row._text:SetText(("%s  |cffFFFFFF%d|r / |cffFFFFFF%d|r"):format(name, have, required))

      local done = required > 0 and have >= required

      -- Once the row is marked complete, avoid inline color codes so SetTextColor can desaturate
      -- the entire string.
      if done then
        row._text:SetText(("%s  %d / %d"):format(name, have, required))
      else
        row._text:SetText(("%s  |cffFFFFFF%d|r / |cffFFFFFF%d|r"):format(name, have, required))
      end
      ns.Util.SetFontStringGreyed(row._text, done)

      if row._icon then
        row._icon:SetTexture(GetItemIcon(itemID))
        ns.Util.SetDesaturatedAndAlpha(row._icon, done, done and 0.35 or 1)
      end

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

  self:Layout()
end

function GuidePage:UpdateRowSizing()
  if not (self.materialsContainer and self.trainersContainer and self.stepsContainer) then
    return
  end

  -- Materials: set widths (to allow wrapping) and then compute row heights.
  local matsWidth = self.materialsContainer:GetWidth() or 1
  for _, row in ipairs(self.materialRows) do
    if row:IsShown() and row._text then
      local available = math.max(100, matsWidth - 90)
      row._text:SetWidth(available)
      if row._note then
        row._note:SetWidth(available)
      end

      -- Main line is always 18px; only notes should expand the row.
      local noteHeight = (row._note and row._note:GetStringHeight()) or 0
      local height = 18 + (noteHeight > 0 and (2 + math.ceil(noteHeight)) or 0)
      row:SetHeight(height)
    end
  end

  -- Trainers: set widths and compute row heights
  local trainersWidth = self.trainersContainer:GetWidth() or 1
  for _, row in ipairs(self.trainerRows) do
    if row:IsShown() then
      if row._name and row._details then
        local available = math.max(160, trainersWidth - 120)
        row._name:SetWidth(available)
        row._details:SetWidth(available)

        local detailsHeight = row._details:GetStringHeight() or 0
        local height = 18 + (detailsHeight > 0 and (2 + math.ceil(detailsHeight)) or 0)
        row:SetHeight(math.max(18, height))
      end
    end
  end

  -- Steps: compute row heights only when notes are present
  local stepsWidth = self.stepsContainer:GetWidth() or 1
  for _, row in ipairs(self.stepRows) do
    if row:IsShown() and row._craftBtn then
      if row._note then
        row._note:SetWidth(math.max(200, stepsWidth - 10))
      end

      local headerHeight = (row._header and row._header:GetStringHeight()) or 0
      local craftHeight = row._craftBtn:GetHeight() or 0
      local noteHeight = (row._note and row._note:GetStringHeight()) or 0
      local computed = headerHeight + 6 + craftHeight + (noteHeight > 0 and (4 + noteHeight) or 0) + 2
      row:SetHeight(math.max(44, math.ceil(computed)))
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

  self:UpdateRowSizing()

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

  -- Trainers container height
  local trainersHeight = 0
  for _, row in ipairs(self.trainerRows) do
    if row:IsShown() then
      trainersHeight = trainersHeight + row:GetHeight() + 8
    end
  end

  if trainersHeight > 0 then
    trainersHeight = trainersHeight - 8
  end
  self.trainersContainer:SetHeight(math.max(1, trainersHeight))

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
    + 20 + self.trainersHeader:GetHeight()
    + 10 + self.trainersContainer:GetHeight()
    + 20 + self.stepsHeader:GetHeight()
    + 10 + self.stepsContainer:GetHeight()
    + 20

  self.scrollChild:SetHeight(math.max(total, self.scrollFrame:GetHeight()))
end
