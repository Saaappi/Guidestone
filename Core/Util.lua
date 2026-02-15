local Addon = _G.Guidestone
local Localization = Addon.modules.Localization
local Logger = Addon.modules.Logger

local type = type
local pcall = pcall
local tonumber = tonumber
local C_Item = C_Item
local C_AddOns = C_AddOns
local C_Map = C_Map
local C_TooltipInfo = C_TooltipInfo
local C_TradeSkillUI = C_TradeSkillUI
local C_SuperTrack = C_SuperTrack
local UiMapPoint = UiMapPoint

---@class GuidestoneUtil
local Util = {}
Addon.modules.Util = Util

local function L(key, ...)
  return Localization:Get(key, ...)
end

function Util:SafeCall(fn, ...)
  if type(fn) ~= "function" then
    return
  end

  local ok, err = pcall(fn, ...)
  if not ok then
    if Logger and Logger.Warn then
      Logger:Warn("Error:", err)
    end
  end
end

function Util:GetItemCount(itemID)
  if not itemID then
    return 0
  end

  -- Prefer C_Item on Retail. I'll add GetItemCount in case
  -- I choose to expand to Classic.
  if C_Item and C_Item.GetItemCount then
    -- includeBank = true; includeReagentsBank = true when supported
    local ok, count = pcall(C_Item.GetItemCount, itemID, true)
    if ok and type(count) == "number" then
      return count
    end
  end
  return 0
end

-- Returns the best available count for an item that may have aliases.
-- This is useful for tools where an alternative item can satisfy the
-- requirement.
---@param itemID number|nil
---@param aliasItems number[]|nil
---@return number count
---@return number matchedItemID
function Util:GetBestItemCount(itemID, aliasItems)
  local primaryID = tonumber(itemID)
  if not primaryID or primaryID <= 0 then
    return 0, 0
  end

  local bestID = primaryID
  local bestCount = Util:GetItemCount(primaryID) or 0

  if type(aliasItems) == "table" then
    for _, v in ipairs(aliasItems) do
      local id = tonumber(v)
      if id and id > 0 then
        local count = Util.GetItemCount(id) or 0
        if count > bestCount then
          bestCount = count
          bestID = id
        end
      end
    end
  end

  return bestCount, bestID
end

function Util:GetWowheadItemUrl(itemID)
  return ("https://www.wowhead.com/item=%d"):format(tonumber(itemID) or 0)
end

function Util:SetDesaturatedAndAlpha(region, desaturated, alpha)
  if region and region.SetDesaturated then
    region:SetDesaturated(desaturated and true or false)
  end

  if region and region.SetAlpha then
    region:SetAlpha(alpha or 1)
  end
end

function Util:SetFontStringGreyed(fs, greyed)
  if not fs then
    return
  end

  if greyed then
    fs:SetTextColor(0.55, 0.55, 0.55, 1)
  else
    fs:SetTextColor(1, 1, 1, 1)
  end
end

---@param t table
---@return nil
function Util:WipeTable(t)
  if type(t) ~= "table" then
    return
  end

  for k in pairs(t) do
    t[k] = nil
  end
end

-- -----------------------------------------------------------------------------
-- Waypoints / Navigation
-- -----------------------------------------------------------------------------

---@alias GuidestoneFactionFlag 0|1|2

---Returns the player's faction in the guide's flag foramt.
---0 = Neutral | 1 = Alliance | 2 = Horde
---@return GuidestoneFactionFlag
function Util:GetPlayerFactionFlag()
  local faction = (UnitFactionGroup and UnitFactionGroup("player")) or nil
  if faction == "Alliance" then
    return 1
  elseif faction == "Horde" then
    return 2
  end

  return 0
end

---Whether TomTom is available and provides the AddWaypoint method.
---@return boolean
function Util:IsTomTomAvailable()
  if not C_AddOns or not C_AddOns.IsAddOnLoaded then
    return false
  end

  if not C_AddOns.IsAddOnLoaded("TomTom") then
    return false
  end

  return type(_G.TomTom) == "table" and type(_G.TomTom.AddWaypoint) == "function"
end

---Whether TomTom is enabled for the current character.
---TomTom can be enabled but not yet loaded (LoD).
---@return boolean
function Util:IsTomTomEnabled()
  if not C_AddOns or not C_AddOns.GetAddOnEnableState then
    return false
  end

  -- C_AddOns.GetAddOnEnableState accepts an optional character GUID.
  local characterGUID = (UnitGUID and UnitGUID("player")) or nil
  local ok, state = pcall(C_AddOns.GetAddOnEnableState, "TomTom", characterGUID)
  if ok and type (state) == "number" then
    return state > 0
  end

  return false
end

---Attempt to load TomTom if it is enabled but not yet loaded.
---@return boolean loaded
function Util:TryLoadTomTom()
  if not (C_AddOns and C_AddOns.LoadAddOn and C_AddOns.IsAddOnLoaded) then
    return false
  end

  if not self:IsTomTomEnabled() then
    return false
  end

  if C_AddOns.IsAddOnLoaded("TomTom") then
    return true
  end

  local ok, loaded = pcall(C_AddOns.LoadAddOn, "TomTom")
  return ok and loaded and true or false
end

---Add a waypoint to the player's map.
---If TomTom is enabled, this will add a TomTom waypoint.
---If TomTom is disabled, this will set a User Waypoint (super-tracked where possible).
---@param uiMapID number
---@param x number -- percent (0-100)
---@param y number -- percent (0-100)
---@param title string|nil
---@return boolean ok
function Util:AddWaypoint(uiMapID, x, y, title)
  uiMapID = tonumber(uiMapID)
  x = tonumber(x)
  y = tonumber(y)

  if not (uiMapID and x and y) then
    return false
  end

  local nx = x / 100
  local ny = y / 100

  if self:IsTomTomAvailable() then
    -- If TomTom is enabled, never fall back to a Blizzard User Waypoint.
    -- The fallback creates a super-tracked pin, which is not desired when
    -- the user has chosen TomTom.
    if self:IsTomTomAvailable() then
      self:TryLoadTomTom()

      if type(_G.TomTom) ~= "table" or type(_G.TomTom.AddWaypoint) ~= "function" then
        return false
      end
    end

    local opts = {
      title = title or "Waypoint",
      persistent = false,
      minimap = true,
      world = true,
      from = Addon.name,
    }

    local ok = pcall(_G.TomTom.AddWaypoint, _G.TomTom, uiMapID, nx, ny, opts)
    return ok and true or false
  end

  if C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(uiMapID) then
      return false
    end

    local point = UiMapPoint.CreateFromCoordinates(uiMapID, nx, ny)
    local ok = pcall(C_Map.SetUserWaypoint, point)

    if ok and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
      pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end

    return ok and true or false
  end

  return false
end

-- ---------------------------------------------------------------------------
-- Profession helpers (used across UI + services)
-- ---------------------------------------------------------------------------

---@return nil
function Util:DumpProfessionInfo()
  if not (Professions and Professions.GetProfessionInfo) then
    Logger:Warn(L("ERR_PROF_API_UNAVAILABLE"))
    return
  end

  local info = Professions.GetProfessionInfo()
  if not info then
    Logger:Info(L("ERR_NO_PROF_INFO"))
    return
  end

  Logger:Info("Profession dump:")
  Logger:Info("professionName:", info.professionName or "nil")
  Logger:Info("professionID (child):", info.professionID or "nil")
  Logger:Info("parentProfessionName:", info.parentProfessionName or "nil")
  Logger:Info("parentProfessionID:", info.parentProfessionID or "nil")
  Logger:Info("skillLevel:", info.skillLevel or "nil")
  Logger:Info("maxSkillLevel:", info.maxSkillLevel or "nil")

  if C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfos then
    local children = C_TradeSkillUI.GetChildProfessionInfos()
    if type(children) == "table" then
      Logger:Info("Child profession infos:")
      for i = 1, #children do
        local child = children[i]
        Logger:Info("-", child.expansionName or "?", "id:", child.professionID or "nil")
      end
    end
  end

  local db = Addon.db
  if db and type(db.lastProfessionChildSkillLineByParentID) == "table" then
    local key = tonumber(info.parentProfessionID) or tonumber(info.professionID)
    if key then
      Logger:Info("Saved child for base", key, "=>", db.lastProfessionChildSkillLineByParentID[key] or "nil")
    end
  end
end

---@return table|nil
function Util:GetProfessionInfo()
  if Professions and Professions.GetProfessionInfo then
    local ok, info = pcall(Professions.GetProfessionInfo)
    if ok then
      return info
    end
  end
  return nil
end

---@param skillLineID number|nil
---@return number|nil
function Util:GetCurrentSkillLevel(skillLineID)
  local info

  if type(skillLineID) == "number" and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
    info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
  end

  if type(info) ~= "table" then
    info = self:GetProfessionInfo()
  end

  if type(info) ~= "table" then
    return nil
  end

  return info.skillLevel or info.skillLineCurrentLevel or info.skillLineCurrentLevelWithoutBonuses
end

local recipeNameToID = {} ---@type table<string, number>

---@param recipeName string
---@return number|nil
function Util:FindRecipeIDByName(recipeName)
  if type(recipeName) ~= "string" or recipeName == "" then
    return nil
  end

  local cached = recipeNameToID[recipeName]
  if type(cached) == "number" then
    return cached
  end

  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then
    return nil
  end

  local ok, recipeIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
  if not ok or type(recipeIDs) ~= "table" then
    return nil
  end

  for i = 1, #recipeIDs do
    local recipeID = recipeIDs[i]
    if type(recipeID) == "number" then
      local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
      if okInfo and info and info.name == recipeName then
        recipeNameToID[recipeName] = recipeID
        return recipeID
      end
    end
  end

  return nil
end

local recipeSpellIDToID = {} ---@type table<number, number>

---@param spellID number
---@return number|nil
function Util:FindRecipeIDBySpellID(spellID)
  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 then
    return nil
  end

  local cached = recipeSpellIDToID[spellID]
  if type(cached) == "number" then
    return cached
  end

  if not (C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then
    return nil
  end

  local ok, recipeIDs = pcall(C_TradeSkillUI.GetAllRecipeIDs)
  if not ok or type(recipeIDs) ~= "table" then
    return nil
  end

  for i = 1, #recipeIDs do
    local recipeID = recipeIDs[i]
    if type(recipeID) == "number" then
      local okInfo, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
      if okInfo and type(info) == "table" and tonumber(info.spellID) == spellID then
        recipeSpellIDToID[spellID] = recipeID
        return recipeID
      end
    end
  end

  return nil
end

local npcNameCache = {} ---@type table<number, string>
local mapNameCache = {} ---@type table<number, string>

---Resolve a localized NPC name from an npcId (Creature ID).
---Uses tooltip hyperlink parsing and caches results.
---@param npcId number|nil
---@param fallback string|nil
---@return string
function Util:ResolveNpcName(npcId, fallback)
  npcId = tonumber(npcId)
  if not npcId or npcId <= 0 then
    return fallback or ""
  end

  local cached = npcNameCache[npcId]
  if cached then
    return cached
  end

  -- Tooltip hyperlink: unit:Creature-0-0-0-0-<npcId>
  if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
    local link = ("unit:Creature-0-0-0-0-%d"):format(npcId)
    local ok, data = pcall(C_TooltipInfo.GetHyperlink, link)

    if ok and type(data) == "table" and type(data.lines) == "table" then
      local first = data.lines[1]
      local name = first and first.leftText
      if type(name) == "string" and name ~= "" then
        npcNameCache[npcId] = name
        return name
      end
    end
  end

  -- Fallback to whatever the guide provided
  return fallback or ("Trainer #%d"):format(npcId)
end

---Resolve a localized vendor name. This is just a semantic wrapper
---around ResolveNpcName to allow code to be explicit.
---@param npcID number|nil
---@param fallback string|nil
---@return string
function Util:ResolveVendorName(npcID, fallback)
  npcID = tonumber(npcID)
  if not npcID or npcID <= 0 then
    return fallback or ""
  end

  local name = self:ResolveNpcName(npcID, fallback)
  if name == "" then
    return fallback or ("Vendor #%d"):format(npcID)
  end

  return name
end

---Resolve a localized map/zone name from a uiMapID.
---@param uiMapID number|nil
---@param fallback string|nil
---@return string
function Util:GetMapName(uiMapID, fallback)
  uiMapID = tonumber(uiMapID)
  if not uiMapID or uiMapID <= 0 then
    return fallback or ""
  end

  local cached = mapNameCache[uiMapID]
  if cached then
    return cached
  end

  if C_Map and C_Map.GetMapInfo then
    local ok, info = pcall(C_Map.GetMapInfo, uiMapID)
    if ok and type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      mapNameCache[uiMapID] = info.name
      return info.name
    end
  end

  return fallback or ("Map #%d"):format(uiMapID)
end

---@return number|nil
function Util:GetSelectedRecipeIDFromUI()
  local professionsFrame = ProfessionsFrame
  if professionsFrame and professionsFrame.CraftingPage then
    local craftingPage = professionsFrame.CraftingPage
    if craftingPage.SchematicForm and craftingPage.SchematicForm.GetRecipeInfo then
      local ok, recipeInfo = pcall(craftingPage.SchematicForm.GetRecipeInfo, craftingPage.SchematicForm)
      if ok and type(recipeInfo) == "table" then
        local recipeID = tonumber(recipeInfo.recipeID)
        if recipeID and recipeID > 0 then
          return recipeID
        end
      end
    end
  end

  return nil
end

---@return table|nil
function Util:GetSelectedRecipeSnapshot()
  local recipeID = self:GetSelectedRecipeIDFromUI()
  if not recipeID then
    return nil
  end

  local snap = { recipeID = recipeID }

  if ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm then
    local okForm, formInfo = pcall(ProfessionsFrame.CraftingPage.SchematicForm.GetRecipeInfo, ProfessionsFrame.CraftingPage.SchematicForm)
    if okForm and type(formInfo) == "table" then
      if type(formInfo.name) == "string" and formInfo.name ~= "" then
        snap.name = formInfo.name
      end
      if type(formInfo.icon) == "number" and formInfo.icon > 0 then
        snap.icon = formInfo.icon
      end
      if type(formInfo.hyperlink) == "string" and formInfo.hyperlink ~= "" then
        snap.hyperlink = formInfo.hyperlink
      end
    end
  end

  return snap
end

---@return boolean ok
function Util:DumpSelectedRecipeSnapshot()
  local snap = self:GetSelectedRecipeSnapshot()
  if not snap then
    Logger:Warn(L("ERR_NO_RECIPE_SELECTED"))
    return false
  end

  Logger:Info("Selected recipe:")
  Logger:Info("  recipeID:", snap.recipeID)
  Logger:Info("  name:", snap.name or "nil")
  Logger:Info("  icon:", snap.icon or "nil")
  Logger:Info("  outputItemID:", (snap.hyperlink):match("Hitem:(%d+)") or "nil")

  if type(snap.spellID) == "number" then
    Logger:Info("Guide data:", "recipeID = " .. snap.recipeID .. ",")
  end

  return true
end
