local Addon = _G.Guidestone
local Util = Addon.modules.Util

local type = type
local tonumber = tonumber
local tostring = tostring
local floor = math.floor
local tinsert = table.insert
local tsort = table.sort

---@class GuidestoneGuides
local Guides = {}
Addon.modules.Guides = Guides

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
--      recipeID = 25255,
--
--      -- Planning + automation constraints:
--      maxCrafts = 30, -- planned maximum crafts for this step
--
--      -- Optional: materials used per craft (for materials aggregation)
--      materials = { { itemID=123, quantity=5 }, ... },
--
--      -- Optional: text
--      note = "...",
--    },
--  },
--
--  -- Materials section
--  -- You can either provide it explicitly, or allow for auto-generation from step.materials.
--  -- Explicit entries allow precise "approximate" totals and custom notes.
--  materials = {
--    { itemID=123, required=60, wowProfessionsUrl="https://www.wow-professions.com/farming/...", note="..." },
--  },
--
--  -- If automatic materials totals is desired but still need farming URLs, provide:
--  farmingUrls = {
--    [123] = "https://www.wow-professions.com/farming/...",
--  },
-- }

-- -----------------------------------------------------------------------------
-- Expansion registry
-- -----------------------------------------------------------------------------
-- Internal stable keys for UI grouping/sorting.
-- Matching still uses skillLineID (professionInfo.professionID)
Guides.Expansions = Guides.Expansions or {
  VANILLA       = { name = EXPANSION_NAME0, order = 10 },
  TBC           = { name = EXPANSION_NAME1, order = 20 },
  WRATH         = { name = EXPANSION_NAME2, order = 30 },
  CATA          = { name = EXPANSION_NAME3, order = 40 },
  MOP           = { name = EXPANSION_NAME4, order = 50 },
  WOD           = { name = EXPANSION_NAME5, order = 60 },
  LEGION        = { name = EXPANSION_NAME6, order = 70 },
  BFA           = { name = EXPANSION_NAME7, order = 80 },
  SHADOWLANDS   = { name = EXPANSION_NAME8, order = 90 },
  DRAGONFLIGHT  = { name = EXPANSION_NAME9, order = 100 },
  THEWARWITHIN  = { name = EXPANSION_NAME10, order = 110 },
  MIDNIGHT      = { name = EXPANSION_NAME11, order = 120 },
}

function Guides:RegisterExpansion(expansionKey, displayName, order)
  if type(expansionKey) ~= "string" or expansionKey == "" then
    return
  end

  self.Expansions[expansionKey] = {
    name = tostring(displayName or expansionKey),
    order = tonumber(order) or 9999,
  }
end

local function GetExpansionMeta(expansionKey)
  local meta = Guides.Expansions and Guides.Expansions[expansionKey]
  if meta then
    return meta
  end

  return { name = tostring(expansionKey or "UNKNOWN"), order = 9999 }
end

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
    return tostring(floor(n))
  end

  return tostring(key)
end

---@param links table|nil
---@return table[]|nil
local function NormalizeLinks(links)
  if type(links) ~= "table" then
    return nil
  end

  local out = {}

  for _, link in ipairs(links) do
    if type(link) == "table" then
      local title = type(link.title) == "string" and link.title ~= "" and link.title or nil
      local url = type(link.url) == "string" and link.url ~= "" and link.url or nil
      if url then
        tinsert(out, { title = title, url = url })
      end
    end
  end

  return (#out > 0) and out or nil
end

---@param aliasItems any
---@return number[]|nil
local function NormalizeAliasItems(aliasItems)
  if aliasItems == nil then
    return nil
  end

  -- Allow a single item.
  if type(aliasItems) == "number" then
    aliasItems = { aliasItems }
  end

  if type(aliasItems) ~= "table" then
    return nil
  end

  local seen = {}
  local out = {}

  for _, v in ipairs(aliasItems) do
    local id = tonumber(v)
    if id and id > 0 then
      id = floor(id)
      if id > 0 and not seen[id] then
        seen[id] = true
        out[#out + 1] = id
      end
    end
  end

  return (#out > 0) and out or nil
end

---@param entry table
---@param farmingUrls table|nil
---@return table|nil
local function NormalizeMaterialItem(entry, farmingUrls)
  if type(entry) ~= "table" then
    return nil
  end

  local itemID = tonumber(entry.itemID)
  if not itemID or itemID <= 0 then
    return nil
  end

  local required = tonumber(entry.required) or 0
  if required < 0 then required = 0 end

  local noBuffer = (entry.noBuffer == true) or (entry.applyBuffer == false) or (tostring(entry.bufferMode) == "none")

  return {
    type = "item",
    itemID = floor(itemID),
    aliasItems = NormalizeAliasItems(entry.aliasItems or entry.aliasItemIDs or entry.alias),
    required = required,
    noBuffer = noBuffer,
    wowProfessionsUrl = entry.wowProfessionsUrl or (farmingUrls and farmingUrls[itemID]) or nil,
    note = entry.note,
    links = NormalizeLinks(entry.links),
  }
end

---@param guideID string
---@param idx number
---@param group table
---@return string
local function ComputeGroupKey(guideID, idx, group)
  if type(group.key) == "string" and group.key ~= "" then
    return group.key
  end
  return ("%s:matGroup:%d"):format(tostring(guideID or "Unknown"), tonumber(idx) or 0)
end

---@param materials table|nil
---@param farmingUrls table|nil
---@param guideID string
---@return table
local function NormalizeMaterials(materials, farmingUrls, guideID)
  if type(materials) ~= "table" then
    return {}
  end

  local out = {}

  for i, entry in ipairs(materials) do
    if type(entry) == "table" and tostring(entry.type) == "group" then
      local mode = tostring(entry.mode or "anyMix")
      local groupKey = ComputeGroupKey(guideID, i, entry)

      if mode == "choiceSets" then
        local choicesOut = {}

        if type(entry.choices) == "table" then
          for _, choice in ipairs(entry.choices) do
            if type(choice) == "table" then
              local itemsOut = {}
              if type(choice.items) == "table" then
                for _, it in ipairs(choice.items) do
                  local normalizedIt = NormalizeMaterialItem(it, farmingUrls)
                  if normalizedIt then
                    itemsOut[#itemsOut + 1] = normalizedIt
                  end
                end
              end

              local choiceID = nil
              if type(choice.id) == "string" and choice.id ~= "" then
                choiceID = choice.id
              end

              if #itemsOut > 0 then
                choicesOut[#choicesOut + 1] = {
                  id = choiceID,
                  label = choice.label,
                  items = itemsOut,
                }
              end
            end
          end
        end

        if #choicesOut > 0 then
          out[#out + 1] = {
            type = "group",
            mode = "choiceSets",
            key = groupKey,
            label = entry.label,
            note = entry.note,
            choices = choicesOut,
          }
        end
      else
        -- anyMix (default)
        local required = tonumber(entry.required) or 0
        if required < 0 then required = 0 end

        local optionsOut = {}
        if type(entry.options) == "table" then
          for _, opt in ipairs(entry.options) do
            local normalizedOpt = NormalizeMaterialItem(opt, farmingUrls)
            if normalizedOpt then
              normalizedOpt.required = nil -- options satisfy group required; not per-option required
              optionsOut[#optionsOut + 1] = normalizedOpt
            end
          end
        end

        if required > 0 and #optionsOut > 0 then
          out[#out + 1] = {
            type = "group",
            mode = "anyMix",
            key = groupKey,
            label = entry.label,
            required = required,
            note = entry.note,
            options = optionsOut,
          }
        end
      end
    else
      local normalizedItem = NormalizeMaterialItem(entry, farmingUrls)
      if normalizedItem then
        out[#out + 1] = normalizedItem
      end
    end
  end

  return out
end

local function IsPositiveInt(n)
  n = tonumber(n)

  return n and n > 0 and floor(n) == n
end

local function SumMaterialsFromSteps(steps)
  -- Returns: totals[itemID] = requiredCount
  local totals = {}
  if type(steps) ~= "table" then
    return totals
  end

  for _, step in ipairs(steps) do
    local crafts = tonumber(step and step.maxCrafts) or 0
    if crafts > 0 and type(step.materials) == "table" then
      for _, reagent in ipairs(step.materials) do
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

local function BuildMaterialsFromTotals(totals, farmingUrls)
  local list = {}
  for itemID, required in pairs(totals or {}) do
    tinsert(list, {
      itemID = itemID,
      required = required,
      wowProfessionsUrl = farmingUrls and farmingUrls[itemID] or nil,
    })
  end

  tsort(list, function(a, b)
    return (a.itemID or 0) < (b.itemID or 0)
  end)

  return list
end

local function NormalizeGuide(guide)
  if type(guide) ~= "table" then
    return nil, "guide_not_table"
  end

  if type(guide.id) ~= "string" or guide.id == "" then
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
  normalized.skillLineID = floor(tonumber(guide.skillLineID))

  normalized.expansionKey = tostring(guide.expansionKey or "UNKNOWN")
  local expansionMeta = GetExpansionMeta(normalized.expansionKey)
  normalized.expansionName = tostring(guide.expansionName or expansionMeta.name)
  normalized.expansionOrder = tonumber(expansionMeta.order) or 9999

  normalized.professionKey = tostring(guide.professionKey or "UNKNOWN")
  normalized.professionName = guide.professionName and tostring(guide.professionName) or nil

  normalized.title = tostring(
    guide.title or (normalized.expansionName .. " " .. (normalized.professionName or normalized.professionKey))
  )

  normalized.steps = guide.steps
  normalized.farmingUrls = guide.farmingUrls
  normalized.guideUrl = guide.guideUrl

  -- Materials: if explicitly provided, use it. Otherwise, auto-build from materials.
  local materialsRaw
  if type(guide.materials) == "table" and #guide.materials > 0 then
    materialsRaw = guide.materials
  else
    local totals = SumMaterialsFromSteps(normalized.steps)
    materialsRaw = BuildMaterialsFromTotals(totals, guide.farmingUrls)
  end

  normalized.materials = NormalizeMaterials(materialsRaw, guide.farmingUrls, normalized.id)

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
  tinsert(self._all, normalized)

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

function Guides:GetExpansionKeysOrdered()
  local seen = {}
  local keys = {}

  -- Known expansions first
  for k in pairs(self.Expansions or {}) do
    keys[#keys + 1] = k
    seen[k] = true
  end

  -- Include any expansion keys referenced by guides.
  for _, g in ipairs(self._all) do
    if g.expansionKey and not seen[g.expansionKey] then
      keys[#keys + 1] = g.expansionKey
      seen[g.expansionKey] = true
    end
  end

  tsort(keys, function(a, b)
    local ma = GetExpansionMeta(a)
    local mb = GetExpansionMeta(b)
    if (ma.order or 9999) ~= (mb.order or 9999) then
      return (ma.order or 9999) < (mb.order or 9999)
    end

    return tostring(a) < tostring(b)
  end)

  return keys
end

---List guides grouped by expansionKey (for dropdowns).
---@return table<string, table>
function Guides:GetAllGroupedByExpansion()
  local out = {}
  for _, guide in ipairs(self._all) do
    local key = guide.expansionKey or "UNKNOWN"
    out[key] = out[key] or {}
    tinsert(out[key], guide)
  end

  for _, guides in pairs(out) do
    tsort(guides, function(a, b)
      return tostring(a.professionKey) < tostring(b.professionKey)
    end)
  end

  return out
end

---Helper: compute a materials table that matches the UI needs, regardless of whether the guide
---was explicit or auto-generated.
---@param guide table
---@return table
function Guides:GetMaterials(guide)
  if not guide then
    return {}
  end

  return guide.materials or {}
end

---Helper: recompute materials from steps (useful for when I implement dynamic step planning in the future)
---@param guide table
---@return table materials
function Guides:RebuildMaterialsFromSteps(guide)
  if not guide or type(guide.steps) ~= "table" then
    return {}
  end

  local totals = SumMaterialsFromSteps(guide.steps)

  return BuildMaterialsFromTotals(totals, guide.farmingUrls)
end
