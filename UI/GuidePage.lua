local ADDON, ns = ...

ns.GuidePage = ns.GuidePage or {}

local Item = _G.Item

local GuidePage = ns.GuidePage

local WOWPROF_ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\WoWProfessions.png"
local WOWHEAD_ICON = "Interface\\AddOns\\" .. ADDON .. "\\Media\\Wowhead.png"
local TOMTOM_ICON  = "Interface\\AddOns\\" .. ADDON .. "\\Media\\TomTom.png"

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
    if ok and icon and icon ~=0 then
      return icon
    end
  end

  -- GetItemInfoInstant is synchronous and normally will return an icon immediately.
  if C_Item and C_Item.GetItemInfoInstant then
    local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, itemID)
    if ok and icon and icon ~= 0 then
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


local function IsNonEmptyString(s)
  return type(s) == "string" and s:gsub("%s+", "") ~= ""
end

-- Creates a small icon button with hover and pushed states.
-- The icon can either be a file texture path or an atlas name.
---@param parent Frame
---@param icon string
---@param tooltipText string
---@param isAtlas boolean|nil
local function MakeIconButtonWithStates(parent, icon, tooltipText, isAtlas)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(18, 18)

  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  if isAtlas then
    t:SetAtlas(icon)
  else
    t:SetTexture(icon)
  end
  b._tex = t

  -- Highlight (hover)
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  if isAtlas then
    hl:SetAtlas(icon)
  else
    hl:SetTexture(icon)
  end
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.35)
  b:SetHighlightTexture(hl)

  -- Pushed
  local pushed = b:CreateTexture(nil, "ARTWORK")
  pushed:SetAllPoints()
  if isAtlas then
    pushed:SetAtlas(icon)
  else
    pushed:SetTexture(icon)
  end
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

-- Creates a small atlas chevron button.
-- Used by choiceSets to avoid the textureless rectangle.
---@param parent Frame
---@param tooltipText string
---@return Button
local function MakeChoiceChevronButton(parent, tooltipText)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(14, 14)

  local rotation = math.pi / 2

  -- Normal
  local normal = b:CreateTexture(nil, "ARTWORK")
  normal:SetAllPoints()
  normal:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Up", true)
  if normal.SetRotation then
    normal:SetRotation(rotation)
  end
  b:SetNormalTexture(normal)
  b._normalTex = normal

  -- Hover
  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Mouseover", true)
  if hl.SetRotation then
    hl:SetRotation(rotation)
  end
  b:SetHighlightTexture(hl)
  b._highlightTex = hl

  -- Pressed
  local pushed = b:CreateTexture(nil, "HIGHLIGHT")
  pushed:SetAllPoints()
  pushed:SetAtlas("UI-HUD-ActionBar-PageDownArrow-Down", true)
  if pushed.SetRotation then
    pushed:SetRotation(rotation * 2)
  end
  b:SetPushedTexture(pushed)
  b._pushedTex = pushed

  if IsNonEmptyString(tooltipText) then
    b:SetScript("OnEnter", function()
      GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText)
      GameTooltip:Show()
    end)

    b:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  return b
end

local function ClearRows(rows)
  for _, row in ipairs(rows) do
    row:Hide()
  end

  wipe(rows)
end

local function EnsureCraftButtonVisuals(craftBtn)
  if not craftBtn then
    return
  end

  if craftBtn._gsVisuals then
    return
  end
  craftBtn._gsVisuals = true

  do
    local normal = craftBtn:GetNormalTexture()
    if not normal then
      normal = craftBtn:CreateTexture(nil, "BACKGROUND")
      craftBtn:SetNormalTexture(normal)
    end
    normal:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    normal:ClearAllPoints()
    normal:SetPoint("TOPLEFT", craftBtn, "TOPLEFT", -12, 12)
    normal:SetPoint("BOTTOMRIGHT", craftBtn, "BOTTOMRIGHT", 12, -12)
  end

  do
    local pushed = craftBtn:GetPushedTexture()
    if not pushed then
      pushed = craftBtn:CreateTexture(nil, "BACKGROUND")
      craftBtn:SetPushedTexture(pushed)
    end
    pushed:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    pushed:SetAllPoints()
  end

  craftBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  do
    local hl = craftBtn:GetHighlightTexture()
    if hl then
      hl:SetAllPoints()
    end
  end

  if not craftBtn._icon then
    local icon = craftBtn:CreateTexture(nil, "ARTWORK")
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", craftBtn, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", craftBtn, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    craftBtn._icon = icon
  end
end

---@param guideID string|nil
---@param groupKey string|nil
---@return number|nil
local function GetChoiceSelection(guideID, groupKey)
  if type(guideID) ~= "string" or guideID == "" then
    return nil
  end

  if type(groupKey) ~= "string" or groupKey == "" then
    return nil
  end

  local db = _G.GuidestoneDB
  if type(db) ~= "table" then
    return nil
  end

  db.choiceGroups = db.choiceGroups or {}
  db.choiceGroups[guideID] = db.choiceGroups[guideID] or {}

  local v = tonumber(db.choiceGroups[guideID][groupKey])
  if v and v > 0 then
    return math.floor(v)
  end

  return nil
end

---@param guideID string|nil
---@param groupKey string|nil
---@param choiceIndex number
local function SetChoiceSelection(guideID, groupKey, choiceIndex)
  if type(guideID) ~= "string" or guideID == "" then
    return
  end

  if type(groupKey) ~= "string" or groupKey == "" then
    return
  end

  local db = _G.GuidestoneDB
  if type(db) ~= "table" then
    return
  end

  db.choiceGroups = db.choiceGroups or {}
  db.choiceGroups[guideID] = db.choiceGroups[guideID] or {}
  db.choiceGroups[guideID][groupKey] = math.floor(tonumber(choiceIndex) or 1)
end

local function GetGoldRGB()
  if GOLD_FONT_COLOR and GOLD_FONT_COLOR.GetRGB then
    return GOLD_FONT_COLOR:GetRGB()
  end

  return 1, 0.82, 0
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
      if GuidePage.RefreshAllState then
        GuidePage:RefreshAllState()
      else
        GuidePage:RefreshMaterialsState()
      end
      return
    end

    if event == "GET_ITEM_INFO_RECEIVED" then
      local itemID = tonumber(arg1)
      if itemID and GuidePage._pendingItemLoads[itemID] then
        GuidePage._pendingItemLoads[itemID] = nil
        if GuidePage.RefreshAllState then
          GuidePage:RefreshAllState()
        else
          GuidePage:RefreshMaterialsState()
        end
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
      if GuidePage.RefreshAllState then
        GuidePage:RefreshAllState()
      else
        GuidePage:RefreshMaterialsState()
      end
    end)
  end
end

function GuidePage:RenderGuide(guide)
  if not self.scrollChild then
    return
  end

  -- Defer the render until combat ends to avoid taint/errors.
  if InCombatLockdown() then
    self._pendingRenderGuide = guide
    if not self._combatWatcher then
      local f = CreateFrame("Frame")
      f:RegisterEvent("PLAYER_REGEN_DISABLED")
      f:SetScript("OnEvent", function()
        if GuidePage._pendingRenderGuide then
          local pending = GuidePage._pendingRenderGuide
          GuidePage._pendingRenderGuide = nil
          GuidePage:RenderGuide(pending)
        end
      end)
      self._combatWatcher = f
    end
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

  local function OpenWoWProfessionsLinks(mat)
    if not (ns.LinkPopup and ns.LinkPopup.Show) then
      return
    end

    local links = {}

    if type(mat.wowProfessionsUrl) == "string" and mat.wowProfessionsUrl ~= "" then
      links[#links + 1] = { title = "WoW-Professions", url = mat.wowProfessionsUrl }
    end

    if type(mat.links) == "table" then
      for _, l in ipairs(mat.links) do
        if type(l) == "table" and type(l.url) == "string" and l.url ~= "" then
          links[#links + 1] = { title = l.title, url = l.url }
        end
      end
    end

    if #links == 0 then
      return
    end

    if #links == 1 or not (ns.LinkPopup.ShowLinks) then
      ns.LinkPopup:Show(links[1].title or "Link", links[1].url)
      return
    end

    ns.LinkPopup:ShowLinks("Links", links)
  end

  ---@param text string
  ---@param note string|nil
  ---@param indent number|nil
  ---@return Frame
  local function AddHeaderRow(text, note, indent)
    local row = CreateFrame("Frame", nil, self.materialsContainer)
    row:SetHeight(18)
    row._indent = tonumber(indent) or 0
    row._gutter = 10

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

    local fs = MakeText(line, "GameFontNormal")
    fs:SetPoint("LEFT", row._indent, 0)
    fs:SetPoint("RIGHT", 0, 0)
    fs:SetWordWrap(false)
    fs:SetText(text or "")
    row._text = fs

    if IsNonEmptyString(note) then
      local n = MakeText(row, "GameFontHighlightSmall")
      n:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
      n:SetPoint("TOPRIGHT", fs, "BOTTOMRIGHT", 0, -2)
      n:SetText(note)
      row._note = n
      row:SetHeight(18 + 2 + math.ceil(n:GetStringHeight() or 0))
    end

    table.insert(self.materialRows, row)
    return row
  end

  ---@param mat table
  ---@param indent number|nil
  ---@return Frame
  local function AddItemRow(mat, indent)
    local row = CreateFrame("Frame", nil, self.materialsContainer)
    row:SetHeight(18)
    row._indent = tonumber(indent) or 0
    row._gutter = 90

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
    icon:SetPoint("LEFT", row._indent, 0)
    icon:SetTexture(GetItemIcon(mat.itemID))
    row._icon = icon

    local fs = MakeText(line, "GameFontHighlight")
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    fs:SetWordWrap(false)
    row._text = fs
    row._mat = mat

    -- WoW-Professions link button (supports multiple links via mat.links)
    local wp = MakeIconButtonWithStates(line, WOWPROF_ICON, "WoW-Professions")
    wp:SetPoint("RIGHT", line, "RIGHT", -24, 0)
    wp:SetScript("OnClick", function()
      OpenWoWProfessionsLinks(mat)
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
    return row
  end

  for _, mat in ipairs(materials) do
    if type(mat) == "table" and tostring(mat.type) == "group" then
      local mode = tostring(mat.mode or "anyMix")

      if mode == "choiceSets" then
        local sel = GetChoiceSelection(guide.id, mat.key)
        local header = AddHeaderRow(mat.label or "Choose one", mat.note, 0)
        header._matType = "choiceHeader"
        header._group = mat

        for idx, choice in ipairs(mat.choices or {}) do
          local pickText = (idx == sel and "● " or "○ ") .. (choice.label or ("Option " .. idx))
          local pickRow = AddHeaderRow(pickText, nil, 14)
          pickRow._matType = "choicePick"
          pickRow._group = mat
          pickRow._choiceIndex = idx
          pickRow._guideID = guide.id

          do
            local btn = MakeChoiceChevronButton(pickRow._line, "Select")
            btn:SetPoint("LEFT", pickRow._line, "LEFT", pickRow._indent, 0)

            -- Shift the label to the right of the chevron.
            if pickRow._text then
              pickRow._text:ClearAllPoints()
              pickRow._text:SetPoint("LEFT", btn, "RIGHT", 4, 0)
              pickRow._text:SetPoint("RIGHT", 0, 0)
            end

            pickRow._choiceBtn = btn
          end

          local function Choose()
            SetChoiceSelection(guide.id, mat.key, idx)
            -- Rebuild rows to show the selected choice items.
            self:RenderGuide(self.currentGuide)
          end

          pickRow:EnableMouse(true)
          pickRow:SetScript("OnMouseUp", Choose)

          if pickRow._choiceBtn then
            pickRow._choiceBtn:SetScript("OnClick", Choose)
          end

          if idx == sel then
            for _, item in ipairs(choice.items or {}) do
              local itemRow = AddItemRow(item, 28)
              itemRow._matType = "choiceItem"
              itemRow._group = mat
            end
          end
        end
      else
        -- anyMix (default)
        local header = AddHeaderRow(mat.label or "Choose any", mat.note, 0)
        header._matType = "anyMixHeader"
        header._group = mat

        for _, opt in ipairs(mat.options or {}) do
          local itemRow = AddItemRow(opt, 18)
          itemRow._matType = "anyMixOption"
          itemRow._group = mat
        end
      end
    else
      local itemRow = AddItemRow(mat, 0)
      itemRow._matType = "item"
    end
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

      local icon, isAtlas, tooltipText
      if isTomTomEnabled then
        icon = TOMTOM_ICON
        isAtlas = false
        tooltipText = "Set TomTom Waypoint"
      else
        icon = "Waypoint-MapPin-Untracked"
        isAtlas = true
        tooltipText = "Set Waypoint"
      end

      local waypointBtn = MakeIconButtonWithStates(row, icon, tooltipText, isAtlas)
      waypointBtn:SetPoint("TOPRIGHT", 0, 0)
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

    -- I'm hoping that anchoring the button to its parent, and then using numeric
    -- offsets is sufficient to avoid relative-to regions.
    local headerHeight = (header.GetStringHeight and header:GetStringHeight()) or 14

    local craftBtn = CreateFrame("Button", nil, row, "InsecureActionButtonTemplate, ActionButtonTemplate")
    craftBtn:SetSize(32, 32)
    craftBtn:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -(headerHeight + 8))
    craftBtn:SetText(step.recipeName or "Craft")
    craftBtn:RegisterForClicks("AnyUp")
    EnsureCraftButtonVisuals(craftBtn)
    craftBtn:SetScript("PreClick", function(btn)
      if InCombatLockdown() then
        -- Can't reconfigure attributes in combat.
        btn:SetAttribute("*type1", nil)
        return
      end

      local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
      local blizzCreate = craftingPage and craftingPage.CreateButton
      if not (craftingPage and blizzCreate) then
        btn:SetAttribute("*type1", nil)
        return
      end

      -- Prepare the runner state. No crafting.
      if ns.CraftRunner and ns.CraftRunner.Start then
        ns.CraftRunner:Start(step, function()
          if GuidePage.currentGuide then
            GuidePage:RenderGuide(GuidePage.currentGuide)
          end
        end, true) -- Passing a flag to skip the first craft.
      end

      local currentSkill = ns.GetCurrentSkillLevel() or nil

      local remaining = 0
      if currentSkill and step.toSkill then
        remaining = step.toSkill - currentSkill
      end

      if remaining < 1 then
        remaining = 1
      end

      local craftableCount = 1
      if craftingPage.GetCraftableCount then
        craftableCount = craftingPage:GetCraftableCount() or 1
      end

      local desiredCount = remaining
      if craftableCount < desiredCount then
        desiredCount = craftableCount
      end
      if desiredCount < 1 then
        desiredCount = 1
      end

      -- Force the professions UI to craft only 1 (because Create() reads the spinner value).
      if craftingPage.CreateMultipleInputBox and craftingPage.CreateMultipleInputBox.SetValue then
        craftingPage.CreateMultipleInputBox:SetValue(desiredCount)
      end

      if craftingPage.GetCraftableCount and craftingPage:GetCraftableCount() < 1 then
        btn:SetAttribute("*type1", nil) -- Do nothing since the player can't craft.
        return
      end

      -- Establish the secure click.
      btn:SetAttribute("*type1", "click")
      btn:SetAttribute("*clickbutton1", blizzCreate)
    end)

    -- This is here because ActionButtonTemplate overwrites the OnClick.
    -- Since I want to keep ActionButtonTemplate for its visuals/icon behavior,
    -- I restore the OnClick for the insecure template to route it for the
    -- secure button template.
    craftBtn:SetScript("OnClick", function(self, button, down)
      if InCombatLockdown() then
        return
      end
      SecureActionButton_OnClick(self, button, down)
    end)

    craftBtn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(craftBtn, "ANCHOR_RIGHT")
      if row._outputItemID then
        GameTooltip:SetItemByID(row._outputItemID)
      elseif row._outputHyperlink then
        GameTooltip:SetHyperlink(row._outputHyperlink)
      else
        GameTooltip:SetText(step.recipeName or "Craft")
      end
      GameTooltip:Show()
    end)

    craftBtn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
    row._craftBtn = craftBtn

    local craftName = MakeText(row, "GameFontNormal")
    craftName:SetPoint("TOPLEFT", craftBtn, "TOPRIGHT", 8, -2)
    craftName:SetPoint("TOPRIGHT", -10, 0)
    craftName:SetWordWrap(true)
    row._craftName = craftName

    local craftReagents = MakeText(row, "GameFontHighlightSmall")
    craftReagents:SetPoint("TOPLEFT", craftName, "BOTTOMLEFT", 0, -2)
    craftReagents:SetPoint("TOPRIGHT", craftName, "BOTTOMRIGHT", 0, -2)
    craftReagents:SetWordWrap(true)
    row._craftReagents = craftReagents

    self:UpdateStepRow(row)

    if IsNonEmptyString(step.note) then
      local note = MakeText(row, "GameFontHighlightSmall")
      note:SetPoint("TOPLEFT", craftReagents, "BOTTOMLEFT", -(craftBtn:GetWidth() + 8), -4)
      note:SetText(step.note)
      row._note = note
    end

    table.insert(self.stepRows, row)
  end

  self:Layout()
end

function GuidePage:RefreshMaterialsState(skipLayout)
  if not self.currentGuide then
    return
  end

  -- anyMix: group progress by summing option counts
  local anyMixState = {}

  -- choiceSets: completion for selected choice, based on rendered choiceItem rows
  local choiceDoneByGroup = {}

  -- Pass 1: compute anyMix sums and choiceSets completion
  for _, row in ipairs(self.materialRows) do
    if row._matType == "anyMixOption" and row._group and row._mat then
      local g = row._group
      local st = anyMixState[g]
      if not st then
        st = { have = 0, required = ComputeBufferedRequired(tonumber(g.required) or 0) }
        anyMixState[g] = st
      end

      local itemID = tonumber(row._mat.itemID)
      if itemID and itemID > 0 then
        st.have = st.have + (ns.Util.GetItemCount(itemID) or 0)
      end
    end

    if row._matType == "choiceItem" and row._group and row._mat then
      local g = row._group
      local itemID = tonumber(row._mat.itemID)
      local required = ComputeBufferedRequired(tonumber(row._mat.required) or 0)
      local have = itemID and (ns.Util.GetItemCount(itemID) or 0) or 0
      local done = (required <= 0) or (have >= required)

      if choiceDoneByGroup[g] == nil then
        choiceDoneByGroup[g] = true
      end
      if not done then
        choiceDoneByGroup[g] = false
      end
    end
  end

  for _, st in pairs(anyMixState) do
    st.done = st.required > 0 and st.have >= st.required
  end

  -- Pass 2: apply row text + greying/enabled state
  for _, row in ipairs(self.materialRows) do
    if row._mat and row._text and (row._matType == "item" or row._matType == "anyMixOption" or row._matType == "choiceItem") then
      local mat = row._mat
      local itemID = mat.itemID
      local have = ns.Util.GetItemCount(itemID)

      self:RequestItemData(itemID)

      local name = GetItemName(itemID)
      if not name or name == "" then
        name = ("Item %d"):format(tonumber(itemID) or 0)
      end

      local done = false

      if row._matType == "anyMixOption" then
        local gDone = (row._group and anyMixState[row._group] and anyMixState[row._group].done) or false
        row._text:SetText(("%s  |cffFFFFFF%d|r"):format(name, have))
        done = gDone
      else
        local required = ComputeBufferedRequired(tonumber(mat.required) or 0)
        done = required > 0 and have >= required
        if done then
          row._text:SetText(("%s  %d / %d"):format(name, have, required))
        else
          row._text:SetText(("%s  |cffFFFFFF%d|r / |cffFFFFFF%d|r"):format(name, have, required))
        end
      end

      ns.Util.SetFontStringGreyed(row._text, done)

      if row._icon then
        row._icon:SetTexture(GetItemIcon(itemID))
        ns.Util.SetDesaturatedAndAlpha(row._icon, done, done and 0.35 or 1)
      end

      if row._wpBtn and row._wpBtn._tex then
        local hasAnyLink =
          (type(mat.wowProfessionsUrl) == "string" and mat.wowProfessionsUrl ~= "")
          or (type(mat.links) == "table" and #mat.links > 0)

        row._wpBtn:SetEnabled((not done) and hasAnyLink)
        ns.Util.SetDesaturatedAndAlpha(row._wpBtn._tex, done or (not hasAnyLink), (done or (not hasAnyLink)) and 0.35 or 1)
      end

      if row._whBtn and row._whBtn._tex then
        row._whBtn:SetEnabled(not done)
        ns.Util.SetDesaturatedAndAlpha(row._whBtn._tex, done, done and 0.35 or 1)
      end

    elseif row._matType == "anyMixHeader" and row._group and row._text then
      local g = row._group
      local st = anyMixState[g] or { have = 0, required = ComputeBufferedRequired(tonumber(g.required) or 0), done = false }
      local label = g.label or "Choose any"

      row._text:SetText(("%s  |cffFFFFFF%d|r / |cffFFFFFF%d|r"):format(label, st.have or 0, st.required or 0))
      ns.Util.SetFontStringGreyed(row._text, st.done)

    elseif row._matType == "choiceHeader" and row._group and row._text then
      local done = choiceDoneByGroup[row._group] or false
      row._text:SetText(row._group.label or "Choose one")
      ns.Util.SetFontStringGreyed(row._text, done)

    elseif row._matType == "choicePick" and row._group and row._text then
      local done = choiceDoneByGroup[row._group] or false
      ns.Util.SetFontStringGreyed(row._text, done)

      -- Gold highlight for the selected choice (purely visual)
      local sel = GetChoiceSelection(row._guideID, row._group.key)
      if tonumber(row._choiceIndex) == tonumber(sel) then
        row._text:SetTextColor(GetGoldRGB())
      end

      if row._choiceBtn then
        local alpha = done and 0.35 or 1
        ns.Util.SetDesaturatedAndAlpha(row._choiceBtn._normalTex, done, alpha)
        ns.Util.SetDesaturatedAndAlpha(row._choiceBtn.highlightTex, done, alpha)
        ns.Util.SetDesaturatedAndAlpha(row._choiceBtn._pushedTex, done, alpha)
      end
    end
  end

  if not skipLayout then
    self:Layout()
  end
end

local function SafeGetRecipeOutputItemData(recipeID)
  if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData) then
    return nil
  end

  -- I'm not sure if retail accepts {recipeID} or {recipeID, reagents}.
  local ok, info = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID, {})
  if ok and info then
    return info
  end

  ok, info = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
  if ok and info then
    return info
  end

  return nil
end

function GuidePage:UpdateStepRow(row)
  if not (row and row._step and row._craftBtn and row._craftName and row._craftReagents) then
    return
  end

  local step = row._step

  local displayName = (step and step.recipeName) or "Craft"
  local iconTexturePath = "Interface\\Icons\\INV_Misc_QuestionMark"
  row._outputHyperlink = nil
  row._outputItemID = nil

  local recipeID = row._recipeID
  if not recipeID and step and step.recipeName then
    recipeID = ns.FindRecipeIDByName(step.recipeName)
    row._recipeID = recipeID
  end

  if recipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
    local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
    if recipeInfo and type(recipeInfo.name) == "string" and recipeInfo.name ~= "" then
      displayName = recipeInfo.name
    end

    -- Some recipes don't reliably return output item data.
    -- If we have a recipe icon from recipeInfo, use it
    -- as a fallback.
    if recipeInfo and recipeInfo.icon and recipeInfo.icon ~= 0 then
      iconTexturePath = recipeInfo.icon
    end

    local outputItemInfo = SafeGetRecipeOutputItemData(recipeID)
    if outputItemInfo then
      -- Prefer itemID-based icon
      if outputItemInfo.itemID and tonumber(outputItemInfo.itemID) and tonumber(outputItemInfo.itemID) > 0 then
        row._outputItemID = tonumber(outputItemInfo.itemID)
        self:RequestItemData(row._outputItemID)
        iconTexturePath = GetItemIcon(row._outputItemID)
      elseif outputItemInfo.icon and outputItemInfo.icon ~= 0 then
        iconTexturePath = outputItemInfo.icon
      end

      if outputItemInfo.hyperlink then
        row._outputHyperlink = outputItemInfo.hyperlink
        row._outputKey = outputItemInfo.hyperlink
      end
    end

    -- Reagents (basic required only)
    local reagentsText = ""
    -- Multiply reagent quantities by the planned crafts for this step.
    local craftsPlanned = tonumber(step and step.maxCrafts) or 1
    if craftsPlanned < 1 then
      craftsPlanned = 1
    end
    if ProfessionsUtil and ProfessionsUtil.GetRecipeSchematic and ProfessionsUtil.IsReagentSlotBasicRequired then
      local okSchematic, schematic = pcall(ProfessionsUtil.GetRecipeSchematic, recipeID, false)
      if okSchematic and schematic and type(schematic.reagentSlotSchematics) == "table" then
        local parts = {}

        for _, slot in ipairs(schematic.reagentSlotSchematics) do
          if ProfessionsUtil.IsReagentSlotBasicRequired(slot) then
            local options = {}
            for _, reagent in ipairs(slot.reagents or {}) do
              local qty = 0
              if slot.GetQuantityRequired then
                qty = tonumber(slot:GetQuantityRequired(reagent)) or 0
              else
                qty = tonumber(slot.quantityRequired) or 0
              end
              qty = qty * craftsPlanned

              local name = nil
              if reagent.itemID then
                self:RequestItemData(reagent.itemID)
                name = GetItemName(reagent.itemID)
              elseif reagent.currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
                local info = C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
                name = info and info.name
              end

              if name and name ~= "" and qty > 0 then
                table.insert(options, ("%s x%d"):format(name, qty))
              elseif name and name ~= "" then
                table.insert(options, name)
              end
            end

            if #options > 0 then
              table.insert(parts, table.concat(options, " or "))
            end
          end
        end

        reagentsText = table.concat(parts, ", ")
      end
    end

    row._craftReagents:SetText(reagentsText)
  else
    row._craftReagents:SetText("")
  end

  row._craftName:SetText(displayName)
  row._craftName:SetTextColor(GetGoldRGB())

  -- Always drive the texture through the custom icon region so implicit
  -- ItemButton regions are avoided.
  local iconTex = row._craftBtn._icon
  if not iconTex then
    EnsureCraftButtonVisuals(row._craftBtn)
    iconTex = row._craftBtn._icon
  end

  if iconTex then
    iconTex:SetTexture(iconTexturePath)
  end
end

function GuidePage:UpdateRowSizing()
  if not (self.materialsContainer and self.trainersContainer and self.stepsContainer) then
    return
  end

  -- Materials: set widths (to allow wrapping) and then compute row heights.
  local matsWidth = self.materialsContainer:GetWidth() or 1
  for _, row in ipairs(self.materialRows) do
    if row:IsShown() and row._text then
      local gutter = tonumber(row._gutter) or 90
      local indent = tonumber(row._indent) or 0
      local available = math.max(100, matsWidth - gutter - indent)
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

function GuidePage:RefreshStepsState(skipLayout)
  if not self.currentGuide then
    return
  end

  for _, row in ipairs(self.stepRows) do
    self:UpdateStepRow(row)
  end

  if not skipLayout then
    self:Layout()
  end
end

function GuidePage:RefreshAllState()
  -- Refresh item-dependent UI in one pass to avoid double re-layout.
  self:RefreshMaterialsState(true)
  self:RefreshStepsState(true)
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
