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
function MaterialTracker:Init(db)
  self._db = db
  if type(self._db) ~= "table" then
    self._db = {}
  end

  self._db.materialProgress = self._db.materialProgress or {}
end

---@param guide table|nil
function MaterialTracker:SetActiveGuide(guide)
  self._activeGuide = guide

  -- Prime state so UI can immediately read remaining counts.
  if guide then
    self:EnsureGuideState(guide)
  end
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

---@param step table
---@param stepIndex number
---@return table|nil
local function GetStepMaterials(step, stepIndex)
  if type(step) ~= "table" then
    return nil
  end

  -- Materials are expected to be per craft quantities.
  if type(step.materials) == "table" then
    return step.materials
  end

  return nil
end

---@param guide table
---@param step table
---@param stepIndex number
---@return number
local function GetPlannedCraftsForStep(guide, step, stepIndex)
  local planned = tonumber(step and step.maxCrafts) or nil
  if planned and planned > 0 then
    return floor(planned)
  end

  local fromSkill = tonumber(step and step.fromSkill) or 0
  local toSkill = tonumber(step and step.toSkill) or 0
  local delta = toSkill - fromSkill
  if delta < 0 then
    delta = 0
  end
  return floor(delta)
end

---@param guide table
---@param step table
---@param stepIndex number
function MaterialTracker:CompleteStepIfNeeded(guide, step, stepIndex)
  if not guide then
    return
  end

  local state = self:EnsureGuideState(guide)
  if not state then
    return
  end

  local key = MakeStepKey(step, stepIndex)
  state.steps[key] = state.steps[key] or { crafts = 0, completed = false }
  if state.steps[key].completed then
    return
  end

  local plannedCrafts = GetPlannedCraftsForStep(guide, step, stepIndex)
  local stepMats = GetStepMaterials(step, stepIndex)
  if plannedCrafts <= 0 or type(stepMats) ~= "table" then
    state.steps[key].completed = true
    return
  end

  -- Step completion should remove any remaining planned materials for this step
  -- that have not already been decremented by crafts.
  local craftsSoFar = floor(tonumber(state.steps[key].crafts) or 0)
  local leftoverCrafts = plannedCrafts - craftsSoFar
  if leftoverCrafts < 0 then
    leftoverCrafts = 0
  end

  if leftoverCrafts > 0 then
    for _, row in ipairs(stepMats) do
      if type(row) == "table" then
        local itemID = floor(tonumber(row.itemID) or 0)
        local quantity = floor(tonumber(row.quantity) or 0)
        if itemID > 0 and quantity > 0 then
          self:DecrementRemaining(guide, itemID, quantity * leftoverCrafts)
        end
      end
    end
  end

  state.steps[key].completed = true
end

---@return table|nil
function MaterialTracker:GetActiveGuide()
  return self._activeGuide
end

---@param step table
---@return number|nil
local function GetRecipeIDForStep(step)
  local recipeID = tonumber(step and step.recipeID) or nil

  if recipeID and recipeID > 0 then
    return floor(recipeID)
  end

  return nil
end

---@param guide table
---@param recipeID number
---@return table|nil step
---@return number|nil stepIndex
function MaterialTracker:FindStepByRecipeID(guide, recipeID)
  if not (guide and type(guide.steps) == "table") then
    return nil, nil
  end

  recipeID = floor(tonumber(recipeID) or 0)
  if recipeID <= 0 then
    return nil, nil
  end

  -- Prefer the first step that matches and isn't completed.
  local state = self:EnsureGuideState(guide)
  for idx, step in ipairs(guide.steps) do
    local id = GetRecipeIDForStep(step)
    if id and id == recipeID then
      if state then
        local key = MakeStepKey(step, idx)
        if state.steps[key] and state.steps[key].completed then
          -- continue searching...
        else
          return step, idx
        end
      else
        return step, idx
      end
    end
  end

  -- Fallback: return the first matching step.
  for idx, step in ipairs(guide.steps) do
    local id = GetRecipeIDForStep(step)
    if id and id == recipeID then
      return step, idx
    end
  end

  return nil, nil
end

---@param guide table
---@param step table
---@param stepIndex number
---@param crafts number
function MaterialTracker:OnCraftedStep(guide, step, stepIndex, crafts)
  if not (guide and step) then
    return
  end

  crafts = floor(tonumber(crafts) or 1)
  if crafts < 1 then
    crafts = 1
  end

  local stepMats = GetStepMaterials(step, stepIndex)
  if type(stepMats) ~= "table" then
    return
  end

  local state = self:EnsureGuideState(guide)
  if not state then
    return
  end

  local key = MakeStepKey(step, stepIndex)
  state.steps[key] = state.steps[key] or { crafts = 0, completed = false }
  state.steps[key].crafts = floor(tonumber(state.steps[key].crafts) or 0) + crafts

  for _, row in ipairs(stepMats) do
    if type(row) == "table" then
      local itemID = floor(tonumber(row.itemID) or 0)
      local quantity = floor(tonumber(row.quantity) or 0)
      if itemID > 0 and quantity > 0 then
        self:DecrementRemaining(guide, itemID, quantity * crafts)
      end
    end
  end
end

---@param unit string
---@param spellID number
function MaterialTracker:OnSpellcastSucceeded(unit, spellID)
  if unit ~= "player" then
    return
  end

  local guide = self:GetActiveGuide()
  if not guide then
    return
  end

  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 then
    return
  end

  local step, idx = self:FindStepByRecipeID(guide, spellID)
  if step and idx then
    self:OnCraftedStep(guide, step, idx, 1)
  end
end

function MaterialTracker:OnSkillLinesChanged()
  local guide = self:GetActiveGuide()
  if not guide then
    return
  end

  local currentSkill = Util:GetCurrentSkillLevel(Addon.db and Addon.db.lastGuideSkillLineID) or Util:GetCurrentSkillLevel() or 0
  if type(guide.steps) ~= "table" then
    return
  end

  for idx, step in ipairs(guide.steps) do
    local toSkill = tonumber(step and step.toSkill)
    if toSkill and currentSkill >= toSkill then
      self:CompleteStepIfNeeded(guide, step, idx)
    end
  end
end
