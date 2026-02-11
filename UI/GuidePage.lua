local Addon = _G.Guidestone
local Util = Addon.modules.Util
local Guides = Addon.modules.Guides
local ProfessionMemory = Addon.modules.ProfessionMemory
local CraftRunner = Addon.modules.CraftRunner
local LinkPopup = Addon.modules.LinkPopup
local AuctionatorPricing = Addon.modules.AuctionatorPricing
local Localization = Addon.modules.Localization

---@class GuidestoneGuidePage
local GuidePage = {}
Addon.modules.GuidePage = GuidePage

local type = type
local tonumber = tonumber
local tostring = tostring
local Item = Item
local C_Item = C_Item
local C_TradeSkillUI = C_TradeSkillUI

local WOWPROF_ICON = "Interface\\AddOns\\" .. Addon.name .. "\\Media\\WoWProfessions.png"
local WOWHEAD_ICON = "Interface\\AddOns\\" .. Addon.name .. "\\Media\\Wowhead.png"
local TOMTOM_ICON  = "Interface\\AddOns\\" .. Addon.name .. "\\Media\\TomTom.png"
local HEART_ICON = "Interface\\AddOns\\" .. Addon.name .. "\\Media\\Heart.png"

local PROF_BG_ATLAS_BY_ID = {
  [171] = "Professions-Recipe-Background-Alchemy",
  [164] = "Professions-Recipe-Background-Blacksmithing",
  [333] = "Professions-Recipe-Background-Enchanting",
  [202] = "Professions-Recipe-Background-Engineering",
  [182] = "Professions-Recipe-Background-Herbalism",
  [773] = "Professions-Recipe-Background-Inscription",
  [755] = "Professions-Recipe-Background-Jewelcrafting",
  [165] = "Professions-Recipe-Background-Leatherworking",
  [186] = "Professions-Recipe-Background-Mining",
  [393] = "Professions-Recipe-Background-Skinning",
  [197] = "Professions-Recipe-Background-Tailoring",
  [185] = "Professions-Recipe-Background-Cooking",
  [356] = "Professions-Recipe-Background-Fishing"
}

GuidePage.frame = nil
GuidePage.scrollFrame = nil
GuidePage.scrollChild = nil

GuidePage.currentGuide = nil
GuidePage.materialRows = GuidePage.materialRows or {}
GuidePage.stepRows = GuidePage.stepRows or {}
GuidePage.trainerRows = GuidePage.trainerRows or {}

GuidePage._pendingItemLoads = GuidePage._pendingItemLoads or {}

local function L(key, ...)
  return Localization:Get(key, ...)
end

local initialized = false
function GuidePage:TryInitProfessionsTab()
  if not ProfessionsFrame then
    return
  end

  -- Install profession expansion memory even if the guide tab is already initialized.
  if Addon.modules.ProfessionMemory and Addon.modules.ProfessionMemory.TryInstall then
    Addon.modules.ProfessionMemory:TryInstall()
  end

  if initialized then
    return
  end

  -- UI/GuidePage.lua defines Addon.modules.GuidePage.
  if not (GuidePage and GuidePage.Create and GuidePage.LoadForProfession) then
    -- Not an error; it just means the UI file is not implemented yet.
    return
  end

  -- Create the guide page frmae and add it as a Professions tab page.
  local page = GuidePage:Create(ProfessionsFrame)
  if not page then
    return
  end
  page:Hide()

  local tabID = ProfessionsFrame:AddNamedTab(L("TAB_LEVELING_GUIDE"), page)
  ProfessionsFrame.guidestoneLevelingGuideTabID = tabID

  ---@param checkTabID number
  ---@return boolean
  local function IsGuideTabSelected(checkTabID)
    if not (ProfessionsFrame and ProfessionsFrame.GetTab) then
      return false
    end
    return ProfessionsFrame:GetTab() == checkTabID
  end

  ---@return boolean
  local function IsOverlayCastBarOwnedByProfessions()
    if not (OverlayPlayerCastingBarFrame and OverlayPlayerCastingBarFrame.GetParent) then
      return false
    end
    if not ProfessionsFrame then
      return false
    end

    local parent = OverlayPlayerCastingBarFrame:GetParent()
    while parent do
      if parent == ProfessionsFrame then
        return true
      end
      parent = parent.GetParent and parent:GetParent() or nil
    end

    return false
  end

  ---@param checkTabID number
  ---@return nil
  local function EnsurePlayerCastBarVisibleOnGuideTab(checkTabID)
    if not IsGuideTabSelected(checkTabID) then
      return
    end

    -- Only tear down the overlay bar if Professions created/owns it.
    if not IsOverlayCastBarOwnedByProfessions() then
      return
    end

    if OverlayPlayerCastingBarFrame and OverlayPlayerCastingBarFrame.EndReplacingPlayerBar then
      OverlayPlayerCastingBarFrame:EndReplacingPlayerBar()
    elseif PlayerCastingBarFrame and PlayerCastingBarFrame.SetAndUpdateShowCastbar then
      PlayerCastingBarFrame:SetAndUpdateShowCastbar(true)
    end

    -- Keep CraftingPage state consistent in case Blizzard thinks the override is still active.
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if craftingPage then
      craftingPage.isOverrideCastBarActive = false
    end
  end

  ---@param checkTabID number
  ---@return nil
  local function InstallGuideTabCastBarFix(checkTabID)
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not (craftingPage and craftingPage.SetOverrideCastBarActive) then
      return
    end

    if craftingPage._gsCastBarFixInstalled then
      return
    end
    craftingPage._gsCastBarFixInstalled = true

    local origSetOverrideCastBarActive = craftingPage.SetOverrideCastBarActive

    -- Prevent the Professions overlay cast bar from being used while the addon's tab
    -- hides CraftingPage.
    craftingPage.SetOverrideCastBarActive = function(self, active)
      if active and IsGuideTabSelected(checkTabID) then
        -- Do NOT call the original: it will disable the real PlayerCastingBarFrame and
        -- attach OverlayPlayerCastingBarFrame to a hidden CraftingPage anchor (forcing
        -- the bar to be invisible.)
        self.isOverrideCastBarActive = false
        return
      end

      return origSetOverrideCastBarActive(self, active)
    end
  end

  -- Install the cast bar fix once the addon's tab is created.
  InstallGuideTabCastBarFix(tabID)

  local function RefreshGuideIfVisible(professionInfo)
    if not (ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()) then
      return
    end

    if not (ProfessionsFrame.GetTab and ProfessionsFrame:GetTab() == tabID) then
      return
    end

    page:Show()
    if Addon.modules.ProfessionMemory and Addon.modules.ProfessionMemory.GetGuideProfessionInfo then
      professionInfo = Addon.modules.ProfessionMemory:GetGuideProfessionInfo(professionInfo)
    end
    GuidePage:LoadForProfession(professionInfo)
  end

  if EventRegistry and EventRegistry.RegisterCallback and not page.professionSelectedCallbackRegistered then
    EventRegistry:RegisterCallback("Professions.ProfessionSelected", function(_, professionInfo)
      RefreshGuideIfVisible(professionInfo)
    end, page)

    page.professionSelectedCallbackRegistered = true
  end

  ProfessionsFrame:SetTabCallback(tabID, function()
    -- If a craft is already in progress, ensure it doesn't lose the cast bar
    -- to a professions overlay anchored to a hidden CraftingPage.
    EnsurePlayerCastBarVisibleOnGuideTab(tabID)

    local info = (Professions and Professions.GetProfessionInfo) and Professions.GetProfessionInfo() or nil
    if Addon.modules.ProfessionMemory and Addon.modules.ProfessionMemory.GetGuideProfessionInfo then
      info = Addon.modules.ProfessionMemory:GetGuideProfessionInfo(info)
    end

    page:Show()
    GuidePage:LoadForProfession(info)
  end)

  ProfessionsFrame:SetTabDeselectCallback(tabID, function()
    page:Hide()
  end)

  initialized = true
end

---@param atlas string|nil
---@return boolean
local function AtlasExists(atlas)
  if type(atlas) ~= "string" or atlas == "" then
    return false
  end

  -- Retail: verify atlas exists. If API isn't present, assume true
  if C_Texture and C_Texture.GetAtlasInfo then
    local ok, info = pcall(C_Texture.GetAtlasInfo, atlas)
    return ok and info ~= nil
  end

  return true
end

---@param professionName string|nil
---@return string|nil
local function CanonicalizeProfessionName(professionName)
  if type(professionName) ~= "string" or professionName == "" then
    return nil
  end

  -- Remove spaces and punctuation, if present.
  local cleaned = professionName:gsub("[%s%p]", "")
  if cleaned == "" then
    return nil
  end

  -- Uppercase the first letter.
  return cleaned:sub(1, 1):upper() .. cleaned:sub(2)
end

---@param professionInfo table|nil
---@return string|nil
local function GetProfessionBackgroundAtlas(professionInfo)
  if type(professionInfo) ~= "table" then
    return nil
  end

  local professionID = tonumber(professionInfo.professionID)
  local byID = professionID and PROF_BG_ATLAS_BY_ID[professionID] or nil
  if AtlasExists(byID) then
    return byID
  end

  local canon = CanonicalizeProfessionName(professionInfo.professionName)
  if canon then
    local guess = "Professions-Recipe-Background-" .. canon
    if AtlasExists(guess) then
      return guess
    end
  end

  return nil
end

---@param tex Texture|nil
---@param atlas string|nil
---@return boolean
local function TrySetAtlas(tex, atlas)
  if not tex or type(atlas) ~= "string" or atlas == "" then
    return false
  end

  if not tex.SetAtlas then
    return false
  end

  local ok = pcall(tex.SetAtlas, tex, atlas, true)
  if not ok then
    return false
  end

  -- Some clients/patches won't have GetAtlas; treat SetAtlas success as success.
  if tex.GetAtlas then
    local current = tex:GetAtlas()
    if current ~= atlas then
      -- Still might be set but normalized; treat mismatch as "unknown"
      -- and allow other fallbacks to run.
      return false
    end
  end

  return true
end

---@return string|nil
local function FindProfessionBackgroundAtlasFromCraftingUI()
  if not (ProfessionsFrame and ProfessionsFrame.CraftingPage) then
    return nil
  end

  local craftingPage = ProfessionsFrame.CraftingPage
  local form = craftingPage.SchematicForm or craftingPage.DetailsFrame or craftingPage
  if not (form and form.GetRegions) then
    return nil
  end

  -- Scan regions for a texture whose atlas name looks like a professions recipe background.
  local regions = { form:GetRegions() }
  for i = 1, #regions do
    local r = regions[i]
    if r and r.GetObjectType and r:GetObjectType() == "Texture" and r.GetAtlas then
      local atlas = r:GetAtlas()
      if type(atlas) == "string" and atlas:find("^Professions%-Recipe%-Background") then
        return atlas
      end
    end
  end

  return nil
end

---@param professionInfo table|nil
---@return nil
function GuidePage:SetProfessionBackground(professionInfo)
  local tex = self._bgTex
  if not tex then
    return
  end

  -- 1) Preferred: our own mapping / canonical guess.
  local atlas = GetProfessionBackgroundAtlas(professionInfo)
  if TrySetAtlas(tex, atlas) then
    tex:Show()
    return
  end

  -- 2) Fallback: sniff Blizzard's crafting UI for the active profession background atlas.
  local sniffed = FindProfessionBackgroundAtlasFromCraftingUI()
  if TrySetAtlas(tex, sniffed) then
    tex:Show()
    return
  end

  -- 3) Nothing found: hide the profession texture, but keep the tint visible.
  tex:Hide()
end


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

---@param required number
---@param meta table|nil -- material or group table (can include noBuffer/bufferMultiplier)
---@return number
local function ComputeBufferedRequired(required, meta)
  required = tonumber(required) or 0
  if required <= 0 then
    return 0
  end

  if type(meta) == "table" then
    if meta.noBuffer or meta.applyBuffer == false or tostring(meta.bufferMode) == "none" then
      return math.ceil(required)
    end
  end

  local multiplier = 1.2
  if type(meta) == "table" then
    local mult = tonumber(meta.bufferMultiplier)
    if mult and mult > 0 then
      multiplier = mult
    end
  end

  -- Includes a buffer, rounded up to nearest multiple of 5.
  local withBuffer = math.ceil(required * multiplier)
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

---@param entries table|nil
---@return table|nil
local function GetAvailableVendorEntries(entries)
  local results = {}

  if type(entries) ~= "table" then
    return results
  end

  local playerFaction = Util.GetPlayerFactionFlag and Util:GetPlayerFactionFlag() or 0

  -- Single table form.
  if entries.uiMapID or entries.name then
    local f = tonumber(entries.faction) or 0
    if f == 0 or f == playerFaction then
      results[1] = entries
    end
    return results
  end

  -- Array form.
  for _, v in ipairs(entries) do
    if type(v) == "table" then
      local f = tonumber(v.faction) or 0
      if f == 0 or f == playerFaction then
        results[#results + 1] = v
      end
    end
  end

  return results
end

---@param row Frame
---@param craftBtn Button
---@return Button
local function CreateLearnSourceIcon(row, craftBtn)
  local b = CreateFrame("Button", nil, row)
  b:SetSize(16, 16)
  b:SetPoint("TOPLEFT", craftBtn, "TOPRIGHT", 8, -2)
  b:SetFrameLevel((craftBtn:GetFrameLevel() or 0) + 1)
  b:RegisterForClicks("LeftButtonUp")

  local t = b:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints()
  b._tex = t

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetBlendMode("ADD")
  hl:SetAlpha(0.35)
  b._hl = hl

  b:Hide()

  b:SetScript("OnMouseDown", function(self)
    if self._tex then
      self._tex:SetVertexColor(0.65, 0.65, 0.65, 1)
    end
  end)

  b:SetScript("OnMouseUp", function(self)
    if self._tex then
      self._tex:SetVertexColor(1, 1, 1, 1)
    end
  end)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    local r = self._row
    local name = (r and r._craftName and r._craftName.GetText and r._craftName:GetText()) or "this recipe"

    if self._kind == "vendor" then
      GameTooltip:SetText(L("TOOLTIP_VENDOR"))
      GameTooltip:AddLine((L("TOOLTIP_RECIPE_MISSING_VENDOR")):format(name), 1, 1, 1, true)

      local v = self._vendor
      local vendors = self._vendors
      if vendors and #vendors > 0 then
        GameTooltip:AddLine("\nVendor(s):", 0.85, 0.85, 0.85)
        for i = 1, #vendors do
          local vendor = vendors[i]
          local label = Util:ResolveVendorName(vendor.npcId, vendor.name)
          if not IsNonEmptyString(label) then
            label = IsNonEmptyString(vendor.name) and vendor.name or (L("LABEL_VENDOR") .. i)
          end
          GameTooltip:AddLine(("- %s"):format(label), 0.85, 0.85, 0.85, true)
        end
      end

      if vendors and #vendors > 0 then
        local clickHint = (Util and Util.IsTomTomEnabled and Util:IsTomTomEnabled())
          and L("TOOLTIP_SET_TOMTOM_WAYPOINT")
          or L("TOOLTIP_SET_WAYPOINT")
        GameTooltip:AddLine("\n"..clickHint, 0.25, 1, 0.25, true)
      end
    else
      GameTooltip:SetText(L("TOOLTIP_TRAINER"))
      GameTooltip:AddLine((L("TOOLTIP_RECIPE_MISSING_TRAINER")):format(name), 1, 1, 1, true)
    end

    GameTooltip:Show()
  end)

  b:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  b:SetScript("OnClick", function(self)
    if self._kind ~= "vendor" then
      return
    end

    local vendors = self._vendors
    if (not vendors and #vendors > 0) then
      return
    end

    -- One vendor? JUST DO IT!
    if #vendors == 1 then
      local vendor = vendors[1]
      local wpLabel = Util:ResolveVendorName(vendor.npcId, vendor.name) or (vendor.name or L("LABEL_VENDOR"))
      if vendor and vendor.uiMapID and vendor.x and vendor.y and Util and Util.AddWaypoint then
        Util:AddWaypoint(vendor.uiMapID, vendor.x, vendor.y, wpLabel)
      end
      return
    end

    -- Multiple vendors: show a context menu instead.
    if MenuUtil and MenuUtil.CreateContextMenu then
      MenuUtil.CreateContextMenu(self, function(_, root)
        root:CreateTitle(L("MENU_LABEL_CHOOSE_A_VENDOR"))

        for i = 1, #vendors do
          local vendor = vendors[i]
          local label = Util:ResolveVendorName(vendor.npcId, vendor.name)
          if not IsNonEmptyString(label) then
            label = IsNonEmptyString(vendor.name) and vendor.name or (L("LABEL_VENDOR") .. i)
          end
          root:CreateButton(label, function()
            local wpLabel = Util:ResolveVendorName(vendor.npcId, vendor.name) or (vendor.name or L("LABEL_VENDOR"))
            if vendor and vendor.uiMapID and vendor.x and vendor.y and Util and Util.AddWaypoint then
              Util:AddWaypoint(vendor.uiMapID, vendor.x, vendor.y, wpLabel)
            end
          end)
        end
      end)
      return
    end

    -- Fallback if MenuUtil isn't available for some reason.
    local vendor = vendors[1]
    local wpLabel = Util:ResolveVendorName(vendor.npcId, vendor.name) or (vendor.name or L("LABEL_VENDOR"))
    if vendor and vendor.uiMapID and vendor.x and vendor.y and Util and Util.AddWaypoint then
      Util:AddWaypoint(vendor.uiMapID, vendor.x, vendor.y, wpLabel)
    end
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
    pushed:SetRotation(rotation)
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

local function SetChoiceChevronExpanded(btn, isExpanded)
  if not btn then
    return
  end

  -- Atlas is the "down" arrow by default. Rotation:
  -- 0 = down
  -- 90deg = right
  local rotation = isExpanded and 0 or (math.pi / 2)

  local normal = btn._normalTex
  local highlight = btn._highlightTex
  local pushed = btn._pushedTex

  if normal and normal.SetRotation then normal:SetRotation(rotation) end
  if highlight and highlight.SetRotation then highlight:SetRotation(rotation) end
  if pushed and pushed.SetRotation then pushed:SetRotation(rotation) end
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
---@param groupDef table|nil Optional choiceSets group definition (to resolve choiceID <-> index)
---@return number|nil choiceIndex
---@return string|nil choiceID
local function GetChoiceSelection(guideID, groupKey, groupDef)
  if type(guideID) ~= "string" or guideID == "" then
    return nil
  end

  if type(groupKey) ~= "string" or groupKey == "" then
    return nil
  end

  local db = Addon.db
  if type(db) ~= "table" then
    return nil
  end

  db.choiceGroups = db.choiceGroups or {}
  db.choiceGroups[guideID] = db.choiceGroups[guideID] or {}

  local raw = db.choiceGroups[guideID][groupKey]

  -- Stable ID format
  if type(raw) == "string" and raw ~= "" then
    -- If it's a numeric string, treat it like a legacy index.
    local asNum = tonumber(raw)
    if asNum and asNum > 0 then
      local idx = math.floor(asNum)
      local id = nil
      if type(groupDef) == "table" and type(groupDef.choices) == "table" then
        local choices = groupDef.choices[idx]
        if type(choices) == "table" and type(choices.id) == "string" and choices.id ~= "" then
          id = choices.id
        end
      end
      return idx, id
    end

    -- Resolve id -> index if we have the group definition.
    if type(groupDef) == "table" and type(groupDef.choices) == "table" then
      for i, choice in ipairs(groupDef.choices) do
        if type(choice) == "table" and choice.id == raw then
          return i, raw
        end
      end

      -- Stored id no longer exists; treat as unselected.
      return nil, nil
    end

    -- If I don't have groupDef, I can still return the id for callers who only
    -- care about id.
    return nil, raw
  end

  -- Legacy format: numeric index.
  local v = tonumber(raw)
  if v and v > 0 then
    local idx = math.floor(v)
    local id = nil

    if type(groupDef) == "table" and type(groupDef.choices) == "table" then
      local choices = groupDef.choices[idx]
      if type(choices) == "table" and type(choices.id) == "string" and choices.id ~= "" then
        id = choices.id

        -- Rewrite numeric to stable ID once it's resolvable.
        db.choiceGroups[guideID][groupKey] = id
      end
    end

    return idx, id
  end

  return nil, nil
end

---@param guideID string|nil
---@param groupKey string|nil
---@param choiceValue number|string
local function SetChoiceSelection(guideID, groupKey, choiceValue)
  if type(guideID) ~= "string" or guideID == "" then
    return
  end

  if type(groupKey) ~= "string" or groupKey == "" then
    return
  end

  local db = Addon.db
  if type(db) ~= "table" then
    return
  end

  db.choiceGroups = db.choiceGroups or {}
  db.choiceGroups[guideID] = db.choiceGroups[guideID] or {}

  -- Store stable ids whenever possible.
  if type(choiceValue) == "string" and choiceValue ~= "" then
    db.choiceGroups[guideID][groupKey] = choiceValue
    return
  end

  -- Fallback legacy behavior: numeric selection.
  db.choiceGroups[guideID][groupKey] = math.floor(tonumber(choiceValue) or 1)
end

local function GetGoldRGB()
  if GOLD_FONT_COLOR and GOLD_FONT_COLOR.GetRGB then
    return GOLD_FONT_COLOR:GetRGB()
  end

  return 1, 0.82, 0
end

-- ---------------------------------------------------------------------------
-- Expansion dropdown (Leveling Guide tab)
-- ---------------------------------------------------------------------------

---@param professionInfo table|nil
---@return number|nil
local function GetBaseProfessionID(professionInfo)
  if type(professionInfo) ~= "table" then
    return nil
  end

  local parentID = tonumber(professionInfo.parentProfessionID)
  if parentID and parentID > 0 then
    return parentID
  end

  local childID = tonumber(professionInfo.professionID)
  if childID and childID > 0 then
    return childID
  end

  return nil
end

---@return table<string, table>
local function GetKnownChildInfosByExpansionName()
  local map = {}

  if not (C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfos) then
    return map
  end

  local children = C_TradeSkillUI.GetChildProfessionInfos()
  if type(children) ~= "table" then
    return map
  end

  for i = 1, #children do
    local info = children[i]
    local name = info and info.expansionName
    if type(name) == "string" and name ~= "" then
      map[name] = info
    end
  end

  return map
end

---@param professionInfo table|nil
---@return string|nil
local function ResolveExpansionName(professionInfo)
  if type(professionInfo) ~= "table" then
    return nil
  end

  -- An expansion name is available, so use it.
  local expansionName = professionInfo.expansionName
  if type(expansionName) == "string" and expansionName ~= "" then
    return expansionName
  end

  -- Match the active child skill line to a child information record.
  local childID = tonumber(professionInfo.professionID)
  if childID and childID > 0 and C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfos then
    local children = C_TradeSkillUI.GetChildProfessionInfos()
    if type(children) == "table" then
      for i = 1, #children do
        local child = children[i]
        if tonumber(child and child.professionID) == childID then
          local name = child and child.expansionName
          if type(name) == "string" and name ~= "" then
            return name
          end
        end
      end
    end
  end

  -- Last ditch effort...
  local parentName = professionInfo.parentProfessionName
  local fullName = professionInfo.professionName
  if type(parentName) == "string" and parentName ~= "" and type(fullName) == "string" and fullName ~= "" then
    local prefix = fullName:gsub("%s*" .. parentName .. "%s*$", "")
    prefix = prefix:gsub("%s+$", "")
    if prefix ~= "" and prefix ~= fullName then
      return prefix
    end
  end

  return nil
end

---@return string[]
local function GetSortedExpansionKeys()
  local keys = {}
  local expansions = Guides and Guides.Expansions

  if type(expansions) ~= "table" then
    return keys
  end

  for k in pairs(expansions) do
    keys[#keys + 1] = k
  end

  table.sort(keys, function(a, b)
    local ma = expansions[a] or {}
    local mb = expansions[b] or {}
    local oa = tonumber(ma.order) or 9999
    local ob = tonumber(mb.order) or 9999
    if oa == ob then
      return tostring(ma.name or a) < tostring(mb.name or b)
    end
    return oa < ob
  end)

  return keys
end

function GuidePage:Create(parent)
  if self.frame then
    return self.frame
  end

  local page = CreateFrame("Frame", nil, parent)
  page:SetAllPoints(parent)
  page:Hide()
  self.frame = page

  -- Profession-themed background (behind everything).
  -- We also keep a subtle tint behind it so the guide never looks "unstyled"
  -- even if we can't resolve the profession atlas.
  local tint = page:CreateTexture(nil, "BACKGROUND")
  tint:SetAllPoints(page)
  tint:SetTexture("Interface\\Buttons\\WHITE8x8")
  tint:SetVertexColor(0, 0, 0)
  tint:SetAlpha(0.15)
  tint:Show()
  self._bgTint = tint

  local bg = page:CreateTexture(nil, "BORDER")
  bg:SetAllPoints(page)
  bg:SetAlpha(0.35)
  bg:Hide()
  self._bgTex = bg

  -- Pinned credit line
  local credit = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  credit:SetJustifyH("CENTER")
  credit:SetPoint("TOP", page, "TOP", 0, -30)
  credit:SetText(("Crafted with |T%s:14:14:0:0|t by LightskyGG"):format(HEART_ICON))
  credit:SetAlpha(0.75)
  self._creditText = credit

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

  -- Expansion selector
  do
    local dropdown = CreateFrame("DropdownButton", nil, page, "WowStyle1DropdownTemplate")
    dropdown:SetSize(170, 25)
    dropdown:SetPoint("TOPRIGHT", page, "TOPRIGHT", -35, -25)
    dropdown:SetDefaultText(L("DROPDOWN_SELECT_EXPANSION"))

    -- Keep a consistent height and avoid truncation surprises.
    if dropdown.Text and dropdown.Text.SetMaxLines then
      dropdown.Text:SetMaxLines(1)
    end

    dropdown:SetupMenu(function(_, rootDescription)
      rootDescription:SetTag("MENU_GUIDESTONE_EXPANSION")

      local activeInfo = (Professions and Professions.GetProfessionInfo) and Professions.GetProfessionInfo() or nil
      local baseID = GetBaseProfessionID(activeInfo)
      local activeChildID = tonumber(activeInfo and activeInfo.professionID) or nil

      if baseID and ProfessionMemory and ProfessionMemory.GetSavedChildSkillLineID then
        activeChildID = ProfessionMemory:GetSavedChildSkillLineID(baseID) or activeChildID
      end

      local titleText = (activeInfo and activeInfo.parentProfessionName) or (activeInfo and activeInfo.professionName) or "Profession"
      rootDescription:CreateTitle(titleText)

      local expansions = Guides and Guides.Expansions or nil
      local byName = GetKnownChildInfosByExpansionName()
      local sortedKeys = GetSortedExpansionKeys()

      ---@param professionInfo table
      local function IsSelected(professionInfo)
        return tonumber(professionInfo and professionInfo.professionID) == activeChildID
      end

      ---@param professionInfo table
      local function SetSelected(professionInfo)
        if type(professionInfo) ~= "table" then
          return
        end

        local childID = tonumber(professionInfo.professionID)
        if not childID or childID <= 0 then
          return
        end

        local fullInfo =
          (C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionInfoBySkillLineID(childID))
          or professionInfo

        -- Save ONLY the guide dropdown choice (do not change Blizzard's active tier).
        if ProfessionMemory and ProfessionMemory.RememberGuideSelection then
          ProfessionMemory:RememberGuideSelection(fullInfo)
        end

        -- Update visible dropdown label immediately.
        if self.expansionDropdown then
          local label = fullInfo.expansionName or professionInfo.expansionName or L("DROPDOWN_SELECT_EXPANSION")
          if self.expansionDropdown.SetDefaultText then
            self.expansionDropdown:SetDefaultText(label)
          end
          if self.expansionDropdown.Text and self.expansionDropdown.Text.SetText then
            self.expansionDropdown.Text:SetText(label)
          end
          if self.expansionDropdown.CloseMenu then
            self.expansionDropdown:CloseMenu()
          end
        end

        -- Reload guide content for the selected tier.
        self:LoadForProfession(fullInfo)
      end

      for i = 1, #sortedKeys do
        local expansionKey = sortedKeys[i]
        local meta = expansions and expansions[expansionKey] or nil
        local name = meta and meta.name or tostring(expansionKey)
        local childInfo = byName[name]

        if childInfo then
          local radio = rootDescription:CreateRadio(name, IsSelected, SetSelected, childInfo)
          radio:AddInitializer(function(frame)
            local fs = frame.fontString
            if fs and fs.SetFontObject then
              fs:SetFontObject("GameFontHighlightOutline")
            end

            -- Right-aligned skill text (i.e. 1/100)
            local fs2 = frame._gsSkillText
            if not fs2 and frame.AttachFontString then
              fs2 = frame:AttachFontString()
              fs2:SetHeight(20)
              fs2:SetPoint("RIGHT")
              fs2:SetFontObject("GameFontHighlightOutline")
              frame._gsSkillText = fs2
            end
            if fs2 then
              fs2:SetTextToFit(string.format("%d/%d", tonumber(childInfo.skillLevel) or 0, tonumber(childInfo.maxSkillLevel) or 0))
            end
          end)
        else
          -- Expansion exists, but the player doesn't have a learned profession skill line for it.
          -- Show the expansion but disabled.
          local dummy = { expansionName = name, professionID = 0 }
          local radio = rootDescription:CreateRadio(name, function() return false end, function() end, dummy)
          radio:SetEnabled(false)
          radio:AddInitializer(function(frame)local fs = frame.fontString
            if fs and fs.SetFontObject then
              fs:SetFontObject("GameFontDisable")
            end

            local fs2 = frame._gsSkillText
            if not fs2 and frame.AttachFontString then
              fs2 = frame:AttachFontString()
              fs2:SetHeight(20)
              fs2:SetPoint("RIGHT")
              fs2:SetFontObject("GameFontDisable")
              frame._gsSkillText = fs2
            end
            if fs2 then
              fs2:SetText("--")
            end
          end)
        end
      end

      rootDescription:SetMinimumWidth(260)
    end)

    self.expansionDropdown = dropdown
  end

  -- Materials header and container
  local materialsHeader = MakeHeader(child, L("HEADER_MATERIALS_REQUIRED"))
  materialsHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
  self.materialsHeader = materialsHeader

  -- Auctionator cost line
  local materialsCostText = MakeText(child, "GameFontHighlightSmall")
  materialsCostText:SetPoint("TOPLEFT", materialsHeader, "BOTTOMLEFT", 0, -3)
  materialsCostText:SetPoint("TOPRIGHT", -15, 0)
  materialsCostText:SetWordWrap(false)
  materialsCostText:SetText("") -- RefreshMaterialsState() populates this
  self.materialsCostText = materialsCostText

  local materialsContainer = CreateFrame("Frame", nil, child)
  materialsContainer:SetPoint("TOPLEFT", self.materialsCostText, "BOTTOMLEFT", 0, -8)
  materialsContainer:SetPoint("TOPRIGHT", -18, 0)
  materialsContainer:SetHeight(1)
  self.materialsContainer = materialsContainer

  -- Trainers header and container
  local trainersHeader = MakeHeader(child, L("HEADER_TRAINERS"))
  trainersHeader:SetPoint("TOPLEFT", materialsContainer, "BOTTOMLEFT", 0, -20)
  self.trainersHeader = trainersHeader

  local trainersContainer = CreateFrame("Frame", nil, child)
  trainersContainer:SetPoint("TOPLEFT", trainersHeader, "BOTTOMLEFT", 0, -10)
  trainersContainer:SetPoint("TOPRIGHT", -18, 0)
  trainersContainer:SetHeight(1)
  self.trainersContainer = trainersContainer

  -- Steps header and container
  local stepsHeader = MakeHeader(child, L("HEADER_LEVELING_GUIDE"))
  stepsHeader:SetPoint("TOPLEFT", trainersContainer, "BOTTOMLEFT", 0, -20)
  self.stepsHeader = stepsHeader

  local stepsContainer = CreateFrame("Frame", nil, child)
  stepsContainer:SetPoint("TOPLEFT", stepsHeader, "BOTTOMLEFT", 0, -10)
  stepsContainer:SetPoint("TOPRIGHT", -18, 0)
  stepsContainer:SetHeight(1)
  self.stepsContainer = stepsContainer

  page:RegisterEvent("BAG_UPDATE_DELAYED")
  page:RegisterEvent("GET_ITEM_INFO_RECEIVED")
  page:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
  page:RegisterEvent("SKILL_LINES_CHANGED")
  page:RegisterEvent("CHAT_MSG_SKILL")
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

    if event == "TRADE_SKILL_LIST_UPDATE" or event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
      if GuidePage.RefreshStepsState then
        GuidePage:RefreshStepsState()
      end
      return
    end
  end)

  return page
end

function GuidePage:LoadForProfession(professionInfo)
  if not (self.frame and self.frame:IsShown()) then
    -- Still allow data to be prepared even if the tab is not currently visible
  end

  -- Callers may pass child info (from SelectSkillLine) or nil.
  local activeInfo = type(professionInfo) == "table" and professionInfo or nil
  if not activeInfo and Professions and Professions.GetProfessionInfo then
    activeInfo = Professions.GetProfessionInfo()
  end

  -- Keep the dropdown in sync with the active profession.
  if self.expansionDropdown and self.expansionDropdown.SetDefaultText then
    local expansionName = ResolveExpansionName(activeInfo)
    if type(expansionName) == "string" and expansionName ~= "" then
      self.expansionDropdown:SetDefaultText(expansionName)
      if self.expansionDropdown.Text and self.expansionDropdown.Text.SetText then
        self.expansionDropdown.Text:SetText(expansionName)
      end
      self.expansionDropdown:Enable()
    else
      self.expansionDropdown:SetDefaultText(L("DROPDOWN_SELECT_EXPANSION"))
      if self.expansionDropdown.Text and self.expansionDropdown.Text.SetText then
        self.expansionDropdown.Text:SetText(L("DROPDOWN_SELECT_EXPANSION"))
      end
      if activeInfo then
        self.expansionDropdown:Enable()
      else
        self.expansionDropdown:Disable()
      end
    end
  end

  -- Update profession background whenever the profession changes.
  if self.SetProfessionBackground then
    self:SetProfessionBackground(professionInfo)
  end

  local guide = Guides and Guides.GetBestGuide and Guides:GetBestGuide(professionInfo) or nil
  self.currentGuide = guide

  -- Remember the last active guide so other services can function even when the
  -- professions UI isn't open.
  if Addon.db then
    Addon.db.lastGuideSkillLineID = guide and guide.skillLineID or nil
  end

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
    self.titleText:SetText(L("HEADER_LEVELING_GUIDE"))
    self.materialsHeader:SetText(L("HEADER_MATERIALS_REQUIRED"))
    self.trainersHeader:SetText(L("HEADER_TRAINERS"))
    self.stepsHeader:SetText(L("HEADER_LEVELING_GUIDE"))

    local row = CreateFrame("Frame", nil, self.scrollChild)
    row:SetPoint("TOPLEFT", self.materialsHeader, "BOTTOMLEFT", 0, -10)
    row:SetPoint("TOPRIGHT", -18, 0)
    row:SetHeight(20)

    local fs = MakeText(row, "GameFontHighlight", 600)
    fs:SetPoint("LEFT", 0, 0)
    fs:SetText(L("TEXT_NO_GUIDE_AVAILABLE"))
    row._text = fs

    table.insert(self.materialRows, row)

    self:Layout()
    return
  end

  self.titleText:SetText(guide.title or L("HEADER_LEVELING_GUIDE"))

  -- Materials
  local materials = (Guides and Guides.GetMaterials) and Guides:GetMaterials(guide) or (guide.materials or {})
  local prev = nil

  local function OpenWoWProfessionsLinks(mat)
    if not (LinkPopup and LinkPopup.Show) then
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

    if #links == 1 or not (LinkPopup.ShowLinks) then
      LinkPopup:Show(links[1].title or "Link", links[1].url)
      return
    end

    LinkPopup:ShowLinks("Links", links)
  end

  ---@return EditBox|nil searchBox
  ---@return Button|nil searchButton
  local function GetAuctionHouseSearchWidgets()
    local ah = _G.AuctionHouseFrame
    if not (ah and ah.IsShown and ah:IsShown()) then
      return nil, nil
    end

    -- Only treat the AH as searchable when the search box itself is visible.
    local bar = ah.SearchBar
      or (ah.BrowseResultsFrame and ah.BrowseResultsFrame.SearchBar)
      or (ah.CommoditiesBuyFrame and ah.CommoditiesBuyFrame.SearchBar)
      or (ah.BuyItemFrame and ah.BuyItemFrame.SearchBar)

    local box = bar and (bar.SearchBox or (bar.SearchBar and bar.SearchBar.SearchBox)) or nil
    if not (box and box.IsShown and box:IsShown() and box.SetText) then
      return nil, nil
    end

    local btn = bar and (bar.SearchButton or bar.Search) or nil
    return box, btn
  end

  ---@param query string
  ---@return boolean
  local function TriggerAuctionHouseSearch(query)
    local box, btn = GetAuctionHouseSearchWidgets()
    if not box then
      return false
    end

    query = tostring(query or "")
    box:SetText(query)

    -- Prefer clicking the search button; fall back to using the enter handler.
    if btn and btn.Click then
      btn:Click()
      return true
    end

    local onEnter = box.GetScript and box:GetScript("OnEnterPressed")
    if type(onEnter) == "function" then
      if Util and Util.SafeCall then
        Util:SafeCall(onEnter, box)
      else
        pcall(onEnter, box)
      end
      return true
    end

    return true
  end

  ---@return EditBox|nil
  local function EnsureChatEditBox()
    local editBox = nil

    if ChatEdit_ChooseBoxForSend then
      editBox = ChatEdit_ChooseBoxForSend()
    end

    if not editBox and DEFAULT_CHAT_FRAME then
      editBox = DEFAULT_CHAT_FRAME.editBox
    end

    if editBox and ChatEdit_ActivateChat then
      ChatEdit_ActivateChat(editBox)
    elseif editBox and editBox.Show then
      editBox:Show()
    end

    return editBox
  end

  ---@param text string
  ---@return boolean
  local function InsertIntoChat(text)
    local editBox = EnsureChatEditBox()
    if not editBox then
      return false
    end

    text = tostring(text or "")

    if _G.ChatEdit_InsertLink then
      _G.ChatEdit_InsertLink(text)
    elseif editBox.Insert then
      editBox:Insert(text)
    end

    return true
  end

  ---@param mat table
  ---@return nil
  local function HandleMaterialShiftClick(mat)
    local itemID = mat and tonumber(mat.itemID) or nil
    if not (itemID and itemID > 0) then
      return
    end

    -- If the Auction House is open and the search box is visible, search it.
    local ahBox = GetAuctionHouseSearchWidgets()
    if ahBox then
      TriggerAuctionHouseSearch(GetItemName(itemID))
      return
    end

    -- Otherwise, open chat and insert the item link.
    local link = nil
    if _G.C_Item.GetItemInfo then
      link = select(2, _G.C_Item.GetItemInfo(itemID))
    end

    if link and link ~= "" then
      InsertIntoChat(link)
      return
    end

    -- If the link isn't cached yet, load it asynchronously and insert once available.
    if _G.Item and _G.Item.CreateFromItemID then
      local item = _G.Item:CreateFromItemID(itemID)
      item:ContinueOnItemLoad(function()
        local itemLink = (item.GetItemLink and item:GetItemLink()) or (select(2, _G.C_Item.GetItemInfo and _G.C_Item.GetItemInfo(itemID)))
        if itemLink and itemLink ~= "" then
          InsertIntoChat(itemLink)
        else
          InsertIntoChat(("item:%d"):format(itemID))
        end
      end)
    else
      InsertIntoChat(("item:%d"):format(itemID))
    end
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
      if LinkPopup and LinkPopup.Show and mat.itemID then
        LinkPopup:Show("Wowhead", Util:GetWowheadItemUrl(mat.itemID))
      end
    end)
    row._whBtn = wh

    -- Hover region for item tooltip.
    -- This avoids fighting with the icon button tooltips.
    local hit = CreateFrame("Frame", nil, line)
    hit:SetPoint("TOPLEFT", line, "TOPLEFT", row._indent, 0)
    hit:SetPoint("BOTTOMRIGHT", wp, "BOTTOMRIGHT", -6, 0)
    hit:EnableMouse(true)
    row._hit = hit

    local function GetSafeItemName(itemID)
      local name = GetItemName(itemID)
      if not name or name == "" then
        return ("Item %d"):format(tonumber(itemID) or 0)
      end
      return name
    end

    hit:SetScript("OnEnter", function()
      GameTooltip:SetOwner(hit, "ANCHOR_RIGHT")

      local itemID = tonumber(mat.itemID)
      if itemID and itemID > 0 then
        GameTooltip:SetItemByID(itemID)

        -- Alias items section
        if type(mat.aliasItems) == "table" and #mat.aliasItems > 0 then
          GameTooltip:AddLine(" ")
          GameTooltip:AddLine("Also satisfied by:")

          local bestCount, matchedItemID = 0, 0
          if Util and Util.GetBestItemCount then
            bestCount, matchedItemID = Util:GetBestItemCount(itemID, mat.aliasItems)
          end

          for _, aliasID in ipairs(mat.aliasItems) do
            aliasID = tonumber(aliasID)
            if aliasID and aliasID > 0 then
              local aliasName = GetSafeItemName(aliasID)

              local count = 0
              if Util and Util.GetItemCount then
                count = Util:GetItemCount(aliasID) or 0
              end

              local prefix = ""
              if matchedItemID == aliasID and bestCount and bestCount > 0 then
                prefix = CreateAtlasMarkup("achievementcompare-GreenCheckmark") .. " "
              end

              if count > 0 then
                GameTooltip:AddLine(("%s%s (have %d)"):format(prefix, aliasName, count))
              else
                GameTooltip:AddLine(prefix .. aliasName)
              end
            end
          end
        end
      else
        GameTooltip:SetText(L("TOOLTIP_MATERIAL"))
      end

      GameTooltip:Show()
    end)

    hit:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)

    hit:SetScript("OnMouseUp", function(_, button)
      if button ~= "LeftButton" then
        return
      end

      if not (_G.IsShiftKeyDown and _G.IsShiftKeyDown()) then
        return
      end

      HandleMaterialShiftClick(mat)
    end)

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
        local selIndex = GetChoiceSelection(guide.id, mat.key, mat)
        local header = AddHeaderRow(mat.label or "Choose one", mat.note, 0)
        header._matType = "choiceHeader"
        header._group = mat

        for idx, choice in ipairs(mat.choices or {}) do
          local pickText = choice.label or ("Option " .. idx)
          local pickRow = AddHeaderRow(pickText, nil, 14)
          pickRow._matType = "choicePick"
          pickRow._group = mat
          pickRow._choiceIndex = idx
          pickRow._guideID = guide.id

          do
            local btn = MakeChoiceChevronButton(pickRow._line, L("TOOLTIP_SELECT"))
            btn:SetPoint("LEFT", pickRow._line, "LEFT", pickRow._indent, 0)

            -- Shift the label to the right of the chevron.
            if pickRow._text then
              pickRow._text:ClearAllPoints()
              pickRow._text:SetPoint("LEFT", btn, "RIGHT", 4, 0)
              pickRow._text:SetPoint("RIGHT", 0, 0)
            end

            pickRow._choiceBtn = btn
            SetChoiceChevronExpanded(pickRow._choiceBtn, idx == selIndex)
          end

          local function Choose()
            -- Prefer stable ids when provided; fall back to numeric index.
            local choiceID = (type(choice) == "table" and type(choice.id) == "string" and choice.id ~= "") and choice.id or nil
            SetChoiceSelection(guide.id, mat.key, choiceID or idx)

            -- Rebuild rows to show the selected choice items.
            self:RenderGuide(self.currentGuide)
          end

          pickRow:EnableMouse(true)
          pickRow:SetScript("OnMouseUp", Choose)

          if pickRow._choiceBtn then
            pickRow._choiceBtn:SetScript("OnClick", Choose)
          end

          if idx == selIndex then
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
  local playerFaction = Util.GetPlayerFactionFlag and Util.GetPlayerFactionFlag() or 0
  local isTomTomEnabled = Util.IsTomTomEnabled and Util:IsTomTomEnabled() or false

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
      local displayName = trainer.name or "Trainer"
      if Util and Util.ResolveNpcName and trainer.npcId then
        displayName = Util:ResolveNpcName(trainer.npcId, displayName)
      end
      name:SetText(displayName)

      local details = MakeText(row, "GameFontHighlightSmall")
      details:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
      details:SetPoint("TOPRIGHT", name, "BOTTOMRIGHT", 0, -2)

      local zone = trainer.zone or trainer.location or ""
      if (zone == "" or zone == nil) and trainer.uiMapID then
        zone = Util:GetMapName(trainer.uiMapID, "")
      end

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
      row._name = name

      local icon, isAtlas, tooltipText
      if isTomTomEnabled then
        icon = TOMTOM_ICON
        isAtlas = false
        tooltipText = L("TOOLTIP_SET_TOMTOM_WAYPOINT")
      else
        icon = "Waypoint-MapPin-Untracked"
        isAtlas = true
        tooltipText = L("TOOLTIP_SET_WAYPOINT")
      end

      -- Waypoint button: pass localized name
      local waypointBtn = MakeIconButtonWithStates(row, icon, tooltipText, isAtlas)
      waypointBtn:SetPoint("TOPRIGHT", 0, 0)
      waypointBtn:SetScript("OnClick", function()
        if Util and Util.AddWaypoint then
          Util:AddWaypoint(trainer.uiMapID, trainer.x, trainer.y, displayName)
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
    fs:SetText(L("TEXT_NO_TRAINERS_AVAILABLE"))
    row._details = fs

    table.insert(self.trainerRows, row)
  end

  -- Steps
  -- Pre-index any choiceSets groups by key so steps can reference them.
  local choiceGroupsByKey = {}
  for _, mat in ipairs(materials or {}) do
    if type(mat) == "table" and tostring(mat.type) == "group" and tostring(mat.mode or "") == "choiceSets" then
      local key = type(mat.key) == "string" and mat.key or nil
      if key and key ~= "" then
        choiceGroupsByKey[key] = material
      end
    end
  end

  ---@param step table|nil
  ---@return boolean
  local function StepPassesChoiceFilters(step)
    if type(step) ~= "table" then
      return false
    end

    local req = step.requiresChoices
    if type(req) ~= "table" then
      return true
    end

    for groupKey, wanted in pairs(req) do
      if type(groupKey) == "string" and groupKey ~= "" and wanted ~= nil then
        local groupDef = choiceGroupsByKey[groupKey]
        local selIndex, selID = GetChoiceSelection(guide.id, groupKey, groupDef)

        -- If the player hasn't selected an option yet, don't hide anything.
        if selIndex ~= nil or selID ~= nil then
          if type(wanted) == "number" then
            if tonumber(selIndex) ~= tonumber(wanted) then
              return false
            end
          else
            if tostring(selID or "") ~= tostring(wanted) then
              return false
            end
          end
        end
      end
    end

    return true
  end

  prev = nil
  for _, step in ipairs(guide.steps or {}) do
    if StepPassesChoiceFilters(step) then
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

        local currentSkill = (Util.GetCurrentSkillLevel and Util:GetCurrentSkillLevel(Addon.db.lastGuideSkillLineID)) or nil
        local toSkill = tonumber(step and step.toSkill)

        -- If the player has reached or exceeded the target skill, do not allow them
        -- to craft items below that level.
        if toSkill and currentSkill and currentSkill >= toSkill then
          btn:SetAttribute("*type1", nil)
          btn:SetAttribute("*clickbutton1", nil)
          return
        end

        -- Prepare the runner state. No crafting.
        if CraftRunner and CraftRunner.Start then
          CraftRunner:Start(step, function()
            if GuidePage.currentGuide then
              GuidePage:RenderGuide(GuidePage.currentGuide)
            end
          end, true) -- Passing a flag to skip the first craft.
        end

        local remaining = 0
        if currentSkill and step.toSkill then
          remaining = (tonumber(step.toSkill) or 0) - currentSkill
        end

        if remaining < 1 then
          remaining = 1
        end

        local craftableCount = 1
        if craftingPage.GetCraftableCount then
          craftableCount = craftingPage:GetCraftableCount() or 1
        end

        if craftableCount < 1 then
          craftableCount = 1
        end

        -- Force the professions UI to craft only 1 (because Create() reads the spinner value).
        if craftingPage.CreateMultipleInputBox and craftingPage.CreateMultipleInputBox.SetValue then
          craftingPage.CreateMultipleInputBox:SetValue(craftableCount)
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
          GameTooltip:SetText(row._displayName or (step and step.recipeName) or "Craft")
        end
        GameTooltip:Show()
      end)

      craftBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
      row._craftBtn = craftBtn

      -- Optional "trainer required" icon lives in the gutter between the craft button
      -- and the craft name. I'll reserve this space always so reagents never shift when
      -- the icon becomes visible.
      local learnIcon = CreateLearnSourceIcon(row, craftBtn)
      learnIcon._row = row
      row._learnIcon = learnIcon

      local craftName = MakeText(row, "GameFontNormal")
      craftName:SetPoint("TOPLEFT", craftBtn, "TOPRIGHT", 28, -2)
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
        note:SetPoint("TOPLEFT", craftReagents, "BOTTOMLEFT", 0, -4)
        note:SetPoint("TOPRIGHT", craftReagents, "BOTTOMRIGHT", 0, -4)
        note:SetWordWrap(true)
        note:SetText(step.note)
        row._note = note
      end

      table.insert(self.stepRows, row)

      self:Layout()
    end
  end
end

function GuidePage:RefreshMaterialsState(skipLayout)
  if not self.currentGuide then
    return
  end

  local function GetHaveForMaterial(mat)
    if not mat then
      return 0, 0
    end

    local itemID = tonumber(mat.itemID)
    if not itemID or itemID <= 0 then
      return 0, 0
    end

    if Util and Util.GetBestItemCount then
      return Util:GetBestItemCount(itemID, mat.aliasItems)
    end

    return (Util and Util.GetItemCount and Util:GetItemCount(itemID)) or 0, itemID
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
        st = { have = 0, required = ComputeBufferedRequired(tonumber(g.required) or 0, row._mat) }
        anyMixState[g] = st
      end

      local itemID = tonumber(row._mat.itemID)
      if itemID and itemID > 0 then
        st.have = st.have + (Util:GetItemCount(itemID) or 0)
      end
    end

    if row._matType == "choiceItem" and row._group and row._mat then
      local g = row._group
      local itemID = tonumber(row._mat.itemID)
      local required = ComputeBufferedRequired(tonumber(row._mat.required) or 0, row._mat)
      local have = itemID and (Util:GetItemCount(itemID) or 0) or 0
      local done = (required <= 0) or (have >= required)

      if choiceDoneByGroup[g] == nil then
        choiceDoneByGroup[g] = true
      end
      if not done then
        choiceDoneByGroup[g] = false
      end
    end
  end

  for _, state in pairs(anyMixState) do
    state.done = state.required > 0 and state.have >= state.required
  end

  -- ---------------------------------------------------------------------------
  -- Auctionator: compute the total cost to buy the missing material quantities
  -- ---------------------------------------------------------------------------
  do
    local missingIDs = {}
    local costText = self.materialsCostText
    if costText then
      local totalInCopper = 0
      local missingAnyPrice = false

      local function AddCostForItem(mat, required, have)
        local need = (required or 0) - (have or 0)
        if need <= 0 then
          return
        end

        local unit = AuctionatorPricing and AuctionatorPricing.GetUnitPrice and AuctionatorPricing:GetUnitPrice(mat.itemID) or nil
        if unit == nil then
          missingIDs[#missingIDs + 1] = mat.itemID
          missingAnyPrice = true
          return
        end

        totalInCopper = totalInCopper + (unit * need)
      end

      if not (AuctionatorPricing and AuctionatorPricing:IsAvailable()) then
        costText:SetText(L("TEXT_AUCTIONATOR_UNAVAILABLE"))
      else
        -- I price:
        --   * normal items + selected choiceSet items individually
        --   * anyMix groups as "remaining needed * cheapest option unit price"
        --     (best-effort estimate; avoids double-counting options)
        for _, row in ipairs(self.materialRows) do
          if row._matType == "item" or row._matType == "choiceItem" then
            local mat = row._mat
            if mat then
              local have = GetHaveForMaterial(mat)
              local required = ComputeBufferedRequired(tonumber(mat.required) or 0, mat)
              AddCostForItem(mat, required, have)
            end
          elseif row._matType == "anyMixHeader" and row._group then
            local group = row._group
            local state = anyMixState[group]
            if state then
              local remaining = (state.required or 0) - (state.have or 0)
              if remaining > 0 then
                local cheapest = nil

                -- get the cheapest priced option in the group
                for _, optRow in ipairs(self.materialRows) do
                  if optRow._matType == "anyMixOption" and optRow._group == group and optRow._mat then
                    local unit = AuctionatorPricing:GetUnitPrice(optRow._mat.itemID)
                    if unit ~= nil then
                      if cheapest == nil or unit < cheapest then
                        cheapest = unit
                      end
                    end
                  end
                end

                if cheapest == nil then
                  missingAnyPrice = true
                else
                  totalInCopper = totalInCopper + (cheapest * remaining)
                end
              end
            end
          end
        end

        if missingAnyPrice and Addon.auctionHouseOpen then
          -- Throttle so as not to spam MultiSearch every refresh.
          local now = GetTime() or 0
          self._lastAuctionatorScanAt = self._lastAuctionatorScanAt or 0
          if now - self._lastAuctionatorScanAt > 2 then
            self._lastAuctionatorScanAt = now
            AuctionatorPricing:MultiSearchForItemIDs(missingIDs)
          end
        end

        local money = AuctionatorPricing:FormatMoney(totalInCopper)
        if missingAnyPrice then
          costText:SetText(L("TEXT_AUCTIONATOR_WITH_MISSING_PRICES"):format(money))
        else
          costText:SetText(L("TEXT_AUCTIONATOR_ABSOLUTE_PRICE"):format(money))
        end
      end
    end
  end

  -- Pass 2: apply row text + greying/enabled state
  for _, row in ipairs(self.materialRows) do
    if row._mat and row._text and (row._matType == "item" or row._matType == "anyMixOption" or row._matType == "choiceItem") then
      local mat = row._mat
      local itemID = mat.itemID
      local have, matchedItemID = GetHaveForMaterial(mat)

      self:RequestItemData(itemID)

      -- If this material has aliases, request their item data too so names are resolved.
      if type(mat.aliasItems) == "table" then
        for _, aliasID in ipairs(mat.aliasItems) do
          self:RequestItemData(aliasID)
        end
      end

      local name = GetItemName(itemID)
      if not name or name == "" then
        name = ("Item %d"):format(tonumber(itemID) or 0)
      end

      -- Show which alias item satisfied the requirement.
      local aliasSuffix = ""
      if matchedItemID and matchedItemID > 0 and matchedItemID ~= tonumber(itemID) and have and have > 0 then
        local aliasName = GetItemName(matchedItemID)
        if aliasName and aliasName ~= "" then
          aliasSuffix = (" (as %s)"):format(aliasName)
        end
      end

      local done = false

      if row._matType == "anyMixOption" then
        local gDone = (row._group and anyMixState[row._group] and anyMixState[row._group].done) or false
        row._text:SetText(("%s  |cffFFFFFF%d|r"):format(name, have))
        done = gDone
      else
        local required = ComputeBufferedRequired(tonumber(mat.required) or 0, row._mat)
        done = required > 0 and have >= required
        if done then
          row._text:SetText(("%s  %d / %d"):format(name, have, required))
        else
          row._text:SetText(("%s  |cffFFFFFF%d|r / |cffFFFFFF%d|r"):format(name, have, required))
        end
      end

      Util:SetFontStringGreyed(row._text, done)

      if row._icon then
        row._icon:SetTexture(GetItemIcon(itemID))
        Util:SetDesaturatedAndAlpha(row._icon, done, done and 0.35 or 1)
      end

      if row._wpBtn and row._wpBtn._tex then
        local hasAnyLink =
          (type(mat.wowProfessionsUrl) == "string" and mat.wowProfessionsUrl ~= "")
          or (type(mat.links) == "table" and #mat.links > 0)

        row._wpBtn:SetEnabled((not done) and hasAnyLink)
        Util:SetDesaturatedAndAlpha(row._wpBtn._tex, done or (not hasAnyLink), (done or (not hasAnyLink)) and 0.35 or 1)
      end

      if row._whBtn and row._whBtn._tex then
        row._whBtn:SetEnabled(not done)
        Util:SetDesaturatedAndAlpha(row._whBtn._tex, done, done and 0.35 or 1)
      end

    elseif row._matType == "anyMixHeader" and row._group and row._text then
      local g = row._group
      local st = anyMixState[g] or { have = 0, required = ComputeBufferedRequired(tonumber(g.required) or 0, row._mat), done = false }
      local label = g.label or "Choose any"

      row._text:SetText(("%s  |cffFFFFFF%d|r / |cffFFFFFF%d|r"):format(label, st.have or 0, st.required or 0))
      Util:SetFontStringGreyed(row._text, st.done)

    elseif row._matType == "choiceHeader" and row._group and row._text then
      local done = choiceDoneByGroup[row._group] or false
      row._text:SetText(row._group.label or "Choose one")
      Util:SetFontStringGreyed(row._text, done)

    elseif row._matType == "choicePick" and row._group and row._text then
      local done = choiceDoneByGroup[row._group] or false
      Util:SetFontStringGreyed(row._text, done)

      -- Gold highlight for the selected choice (purely visual)
      local sel = GetChoiceSelection(row._guideID, row._group.key, row._group)
      if tonumber(row._choiceIndex) == tonumber(sel) then
        row._text:SetTextColor(GetGoldRGB())
      end

      if row._choiceBtn then
        local alpha = done and 0.35 or 1
        Util:SetDesaturatedAndAlpha(row._choiceBtn._normalTex, done, alpha)
        Util:SetDesaturatedAndAlpha(row._choiceBtn.highlightTex, done, alpha)
        Util:SetDesaturatedAndAlpha(row._choiceBtn._pushedTex, done, alpha)
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
  row._displayName = displayName

  local iconTexturePath = "Interface\\Icons\\INV_Misc_QuestionMark"
  row._outputHyperlink = nil
  row._outputItemID = nil

  local recipeID = row._recipeID
  if not recipeID and step then
    recipeID = tonumber(step.recipeID)

    -- Backward compatibility fallback during migration.
    if (not recipeID or recipeID <= 0) and step.recipeName then
      recipeID = Util:FindRecipeIDByName(step.recipeName)
    end

    row._recipeID = recipeID
  end

  local recipeInfo
  if recipeID and C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
    recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
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

  -- Disable the craft button once the player reaches or exceeds the target skill.
  do
    local btn = row._craftBtn
    local currentSkill = (Util.GetCurrentSkillLevel and Util:GetCurrentSkillLevel(Addon.db.lastGuideSkillLineID)) or nil
    local toSkill = tonumber(step and step.toSkill)

    local reachedTarget = (toSkill and currentSkill and currentSkill >= toSkill) and true or false

    if reachedTarget then
      btn:Disable()
      btn:SetAlpha(0.35)
      if iconTex then
        iconTex:SetDesaturated(true)
      end

      -- Extra precaution: clear secure routing out of combat
      if not InCombatLockdown() then
        btn:SetAttribute("*type1", nil)
        btn:SetAttribute("*clickbutton1", nil)
      end
    else
      btn:Enable()
      btn:SetAlpha(1)
      if iconTex then
        iconTex:SetDesaturated(false)
      end
    end
  end

  -- Show "trainer required" icon once the player is at or above this step's skill band,
  -- but the recipe hasn't been learned yet.
  do
    local icon = row._learnIcon
    if icon then
      local currentSkill = (Util.GetCurrentSkillLevel and Util:GetCurrentSkillLevel(Addon.db.lastGuideSkillLineID)) or nil
      local fromSkill = tonumber(step and step.fromSkill)

      local shouldShowLearnIcon = false
      if currentSkill and fromSkill and currentSkill >= fromSkill and recipeInfo and not recipeInfo.learned then
        shouldShowLearnIcon = true
      end

      if not shouldShowLearnIcon then
        icon:Hide()
      else
        -- Default to trainer unless the step explicitly says otherwise.
        local learn = step and step.learn
        local learnType = nil
        local vendorEntries = nil

        if type(learn) == "table" then
          learnType = tostring(learn.type or "")
          vendorEntries = learn.vendor or learn.vendors
        else
          learnType = tostring(step and step.learnSource or "")
          vendorEntries = step and (step.vendor or step.vendors) or nil
        end

        if learnType == "" then
          learnType = "trainer"
        end

        if learnType == "vendor" then
          icon._kind = "vendor"
          icon._vendors = GetAvailableVendorEntries(vendorEntries)
          if icon._tex then
            icon._tex:SetAtlas("Levelup-Icon-Bag", true)
          end
          if icon._hl then
            icon._hl:SetAtlas("Levelup-Icon-Bag", true)
          end
          icon:Show()
        else
          icon._kind = "trainer"
          icon._vendors = nil
          if icon._tex then
            icon._tex:SetAtlas("LevelUp-Icon-Book", true)
          end
          if icon._hl then
            icon._hl:SetAtlas("LevelUp-Icon-Book", true)
          end
          icon:Show()
        end
      end
    end
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
        local craftBtnWidth = (row._craftBn and row._craftBtn:GetWidth()) or 32
        local available = math.max(200, stepsWidth - craftBtnWidth - 8 - 10)
        row._note:SetWidth(available)
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
    + 2 + self.materialsCostText:GetHeight()
    + 10 + self.materialsContainer:GetHeight()
    + 20 + self.trainersHeader:GetHeight()
    + 10 + self.trainersContainer:GetHeight()
    + 20 + self.stepsHeader:GetHeight()
    + 10 + self.stepsContainer:GetHeight()
    + 20

  self.scrollChild:SetHeight(math.max(total, self.scrollFrame:GetHeight()))
end
