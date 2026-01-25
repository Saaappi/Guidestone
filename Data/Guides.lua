local _, ns = ...

ns.Guides = ns.Guides or {}

local Guides = ns.Guides

-- -----------------------------------------------------------------------------
-- Data model (expansion-wide)
-- -----------------------------------------------------------------------------
-- A guide is scoped to a single expansion and profession.
--
-- guide = {
--  id = "tww_alchemy",
--  title = "The War Within Alchemy",
--  expansionKey = "TWW",
--  expansionName = "The War Within",
--  professionKey = "ALCHEMY",
--  professionName = "Alchemy",
--
--  -- REQUIRED: child skill line ID (matches Professions.GetProfessionInfo().professionID)
--  skillLineID = 0,
--
--  -- Optional: guide URL (the "leveling guide" page)
--  guideUrl = "https://wow-professions.com/...",
--
--  -- Steps cover the whole expansion skill line 1..max
--  steps = {
--    {
--      fromSkill = 1,
--      toSkill = 25,
--      recipeName = "Foo", -- recipeSpellID is preferred
--      recipeSpellID = nil,
--
--      -- Planning + automation constraints:
--      maxCrafts = 30, -- planned maximum crafts for this step
--
--      -- Optional: reagents used per craft (for reagents aggregation)
--      reagents = { { itemID=123, quantity=5 }, ... },
--
--      -- Optional: text
--      note = "...",
--    },
--  },
--
--  -- Reagents section
--  -- You can either provide it explicitly, or allow for auto-generation from step.reagents.
--  -- Explicit entries allow precise "approximate" totals and custom notes.
--  reagents = {
--    { itemID=123, required=60, wowProfessionsUrl="https://www.wow-professions.com/farming/...", note="..." },
--  },
--
--  -- If automatic reagent totals is desired but still need farming URLs, provide:
--  farmingUrls = {
--    [123] = "https://www.wow-professions.com/farming/...",
--  },
-- }

-- -----------------------------------------------------------------------------
-- Internals
-- -----------------------------------------------------------------------------

local function ShallowCopy(src)
  if type(src) ~= "table" then
    return nil
  end

  local out = {}
  for k, v in pairs(src) do
    out[k] = v
  end

  return out
end

local function NormalizeKey(key)
  if key == nil then
    return nil
  end

  local n = tonumber(key)
  if n then
    return tostring(math.floor(n))
  end

  return tostring(key)
end

local function IsPositiveInt(n)
  n = tonumber(n)

  return n and n > 0 and math.floor(n) == n
end

local function SumReagentsFromSteps(steps)
  -- Returns: totals[itemID] = requiredCount
  local totals = {}
  if type(steps) ~= "table" then
    return totals
  end

  for _, step in ipairs(steps) do
    local crafts = tonumber(step and step.maxCrafts) or 0
    if crafts > 0 and type(step.reagents) == "table" then
      for _, reagent in ipairs(step.reagents) do
        local itemID = tonumber(reagent and reagent.itemID)
        local qty = tonumber(reagent and reagent.quantity) or 0
        if itemID and itemID > 0 and qty > 0 then
          totals[itemID] = (totals[itemID] or 0) + (crafts * qty)
        end
      end
    end
  end

  return totals
end

local function BuildReagentsFromTotals(totals, farmingUrls)
  local list = {}
  for itemID, required in pairs(totals or {}) do
    table.insert(list, {
      itemID = itemID,
      required = required,
      wowProfessionsUrl = farmingUrls and farmingUrls[itemID] or nil,
    })
  end

  table.sort(list, function(a, b)
    return (a.itemID or 0) < (b.itemID or 0)
  end)

  return list
end

local function NormalizeGuide(guide)
  if type(guide) ~= "table" then
    return nil, "guide_not_table"
  end

  if type(guide.id) ~= "string" then
    return nil, "missing_id"
  end

  if not IsPositiveInt(guide.skillLineID) then
    return nil, "missing_skillLineID"
  end

  if type(guide.steps) ~= "table" or #guide.steps == 0 then
    return nil, "missing_steps"
  end

  -- Normalize step fields (minimal validation; don't mutate caller tables unexpectedly)
  local normalized = ShallowCopy(guide)
  normalized.skillLineID = math.floor(tonumber(guide.skillLineID))

  normalized.expansionKey = tostring(guide.expansionKey or "UNKNOWN")
  normalized.expansionName = tostring(guide.expansionName or normalized.expansionKey)

  normalized.professionKey = tostring(guide.professionKey or "UNKNOWN")
  normalized.professionName = guide.professionName and tostring(guide.professionName) or nil

  normalized.title = tostring(guide.title or (normalized.expansionName .. " " .. (normalized.professionName or normalized.professionKey)))

  -- Steps: shallow copy array (keeps per-step tables as-is; guide authors own the payload)
  normalized.steps = guide.steps

  -- Reagents: if explicitly provided, use it. Otherwise, auto-build from reagents.
  if type(guide.reagents) == "table" and #guide.reagents > 0 then
    normalized.reagents = guide.reagents
  else
    local totals = SumReagentsFromSteps(normalized.steps)
    normalized.reagents = BuildReagentsFromTotals(totals, guide.farmingUrls)
  end

  -- Keep optional maps/urls
  normalized.farmingUrls = guide.farmingUrls
  normalized.guideUrl = guide.guideUrl

  return normalized, nil
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

Guides._bySkillLineID = Guides._bySkillLineID or {}
Guides._all = Guides._all or {}

---Register a single expansion-wide guide.
---@param guide table
---@return boolean ok
---@return string|nil err
function Guides:RegisterGuide(guide)
  local normalized, err = NormalizeGuide(guide)
  if not normalized then
    return false, err
  end

  local key = NormalizeKey(normalized.skillLineID)
  if self._bySkillLineID[key] then
    return false, "duplicate_skillLineID"
  end

  self._bySkillLineID[key] = normalized
  table.insert(self._all, normalized)

  return true, nil
end

---Get a guide by the active child skill line ID.
---@param skillLineID number
---@return table|nil
function Guides:GetBySkillLineID(skillLineID)
  local key = NormalizeKey(skillLineID)

  return key and self._bySkillLineID[key] or nil
end

---Convenience selector for the currently opened profession.
---@param professionInfo table|nil -- Professions.GetProfessionInfo()
---@return table|nil
function Guides:GetBestGuide(professionInfo)
  local skillLineID = professionInfo and professionInfo.professionID
  if not skillLineID then
    return nil
  end

  return self:GetBySkillLineID(skillLineID)
end

---List all registered guides (for building selection UIs).
---@return table
function Guides:GetAll()
  return self._all
end

---List guides grouped by expansionKey (for dropdowns).
---@return table<string, table>
function Guides:GetAllGroupedByExpansion()
  local out = {}
  for _, guide in ipairs(self._all) do
    local key = guide.expansionKey or "UNKNOWN"
    out[key] = out[key] or {}
    table.insert(out[key], guide)
  end

  for _, guides in pairs(out) do
    table.sort(guides, function(a, b)
      return tostring(a.professionKey) < tostring(b.professionKey)
    end)
  end

  return out
end

---Helper: compute a reagents table that matches the UI needs, regardless of whether the guide
---was explicit or auto-generated.
---@param guide table
---@return table
function Guides:GetReagents(guide)
  if not guide then
    return {}
  end

  return guide.reagents or {}
end

---Helper: recompute reagents from steps (useful for when I implement dynamic step planning in the future)
---@param guide table
---@return table reagents
function Guides:RebuildReagentsFromSteps(guide)
  if not guide or type(guide.steps) ~= "table" then
    return {}
  end

  local totals = SumReagentsFromSteps(guide.steps)

  return BuildReagentsFromTotals(totals, guide.farmingUrls)
end