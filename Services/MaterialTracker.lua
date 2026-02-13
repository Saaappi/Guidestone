local Addon = _G.Guidestone
local Util = Addon.modules.Util
local Logger = Addon.modules.Logger

---@class GuidestoneMaterialTracker
local MaterialTracker = {}
Addon.modules.MaterialTracker = MaterialTracker

local type = type
local tonumber = tonumber
local tostring = tostring
local max = math.max
local floor = math.floor

--
-- Persisted progress structure:
-- db.materialProgress[guideID] = {
--   sig = "<snapshot signature>",
--   remaining = { [itemID] = remainingNumber, ... },
--   steps = {
--     [stepKey] = { crafts = 0, completed = false },
--   },
-- }
--

MaterialTracker._db = nil
MaterialTracker._activeGuide = nil

---@param step table
---@param index number
---@return string
local function MakeStepKey(step, index)
  if type(step) ~= "table" then
    return tostring(index or 0)
  end

  local recipeID = tonumber(step.recipeID) or 0
  local fromSkill = tonumber(step.fromSkill) or 0
  local toSkill = tonumber(step.toSkill) or 0
  return ("%d:%d:%d:%d"):format(index or 0, recipeID, fromSkill, toSkill)
end

---@param guide table
---@return string
local function BuildGuideSignature(guide)
  local parts = {}
  parts[#parts + 1] = tostring(guide and guide.id or "")

  local mats = (guide and guide.materials) or {}
  for _, mat in ipairs(mats) do
    if type(mat) == "table" and mat.itemID and mat.required then
      parts[#parts + 1] = ("%d=%d"):format(floor(tonumber(mat.itemID) or 0), floor(tonumber(mat.required) or 0))
    end
  end

  table.sort(parts)
  return table.concat(parts, "|")
end

---@param db table
function MaterialTarcker:Init(db)
  self._db = db
  if type(self._db) ~= "table" then
    self._db = {}
  end

  self._db.materialProgress = self._db.materialProgress or {}
end

---@param guide table
---@return table|nil
function MaterialTracker:EnsureGuideState(guide)
  if not (self._db and self._db.materialProgress) then
    return nil
  end

  if not (guide and guide.id) then
    return nil
  end

  local guideID = tostring(guide.id)
  local sig = BuildGuideSignature(guide)

  local state = self._db.materialProgress[guideID]
  if type(state) ~= "table" or state.sig ~= sig then
    state = { sig = sig, remaining = {}, steps = {} }

    -- Initialize remaining required counts from the guide totals.
    for _, mat in ipairs(guide.materials or {}) do
      if type(mat) == "table" then
        local itemID = floor(tonumber(mat.itemID) or 0)
        local required = floor(tonumber(mat.required) or 0)
        if itemID > 0 and required > 0 then
          state.remaining[itemID] = required
        end
      end
    end

    self._db.materialProgress[guideID] = state
  end

  return state
end

---@param guide table
---@param itemID number
---@param amount number
function MaterialTracker:DecrementRemaining(guide, itemID, amount)
  itemID = floor(tonumber(itemID) or 0)
  amount = floor(tonumber(amount) or 0)
  if itemID <= 0 or amount <= 0 then
    return
  end

  local state = self:EnsureGuideState(guide)
  if not state then
    return
  end

  local current = floor(tonumber(state.remaining[itemID]) or 0)
  state.remaining[itemID] = max(0, current - amount)
end

---@param guide table
---@param itemID number
---@param defaultRequired number
---@return number
function MaterialTracker:GetRemainingRequired(guide, itemID, defaultRequired)
  itemID = floor(tonumber(itemID) or 0)
  if not (guide and itemID > 0) then
    return floor(tonumber(defaultRequired) or 0)
  end

  local state = self:EnsureGuideState(guide)
  if not state then
    return floor(tonumber(defaultRequired) or 0)
  end

  local remainingValue = state.remaining and state.remaining[itemID]
  if remainingValue == nil then
    return floor(tonumber(defaultRequired) or 0)
  end

  return max(0, floor(tonumber(remainingValue) or 0))
end
