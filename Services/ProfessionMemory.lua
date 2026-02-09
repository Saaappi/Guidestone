local Addon = _G.Guidestone

---@class GuidestoneProfessionMemory
local ProfessionMemory = {}
Addon.modules.ProfessionMemory = ProfessionMemory

local type = type
local tonumber = tonumber
local C_TradeSkillUI = C_TradeSkillUI

ProfessionMemory._db = ProfessionMemory._db or nil

-- ---------------------------------------------------------------------------
-- DB
-- ---------------------------------------------------------------------------

---@param db table|nil
---@return nil
function ProfessionMemory:Init(db)
  if type(db) ~= "table" then
    return
  end

  self._db = db
  db.lastProfessionChildSkillLineByParentID = db.lastProfessionChildSkillLineByParentID or {}
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---@param info table|nil
---@return number|nil
local function GetBaseProfessionID(info)
  if type(info) ~= "table" then
    return nil
  end

  local parentID = tonumber(info.parentProfessionID)
  if parentID and parentID > 0 then
    return parentID
  end

  local childID = tonumber(info.professionID)
  if childID and childID > 0 then
    return childID
  end

  return nil
end

---@param skillLineID number|nil
---@return table|nil
local function GetFullProfessionInfo(skillLineID)
  skillLineID = tonumber(skillLineID)
  if not skillLineID or skillLineID <= 0 then
    return nil
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
    local full = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
    return type(full) == "table" and full or nil
  end

  return nil
end

-- ---------------------------------------------------------------------------
-- Public API (Guide-only)
-- ---------------------------------------------------------------------------

---@param baseProfessionID number
---@return number|nil
function ProfessionMemory:GetSavedChildSkillLineID(baseProfessionID)
  if not self._db then
    return nil
  end

  baseProfessionID = tonumber(baseProfessionID)
  if not baseProfessionID or baseProfessionID <= 0 then
    return nil
  end

  local map = self._db.lastProfessionChildSkillLineByParentID
  local id = tonumber(type(map) == "table" and map[baseProfessionID] or nil)
  return (id and id > 0) and id or nil
end

---Save the user's *guide dropdown* choice. This must NOT be called from Blizzard callbacks.
---@param professionInfo table|nil -- child info (professionID is the tier skillLineID)
---@return nil
function ProfessionMemory:RememberGuideSelection(professionInfo)
  if not self._db or type(professionInfo) ~= "table" then
    return
  end

  local baseID = GetBaseProfessionID(professionInfo)
  local childID = tonumber(professionInfo.professionID)

  if not baseID or not childID or childID <= 0 then
    return
  end

  self._db.lastProfessionChildSkillLineByParentID[baseID] = childID
end

---Given the currently-opened Blizzard profession info, return the professionInfo
---that the guide should use (remembered tier if available, otherwise current).
---@param activeProfessionInfo table|nil
---@return table|nil
function ProfessionMemory:GetGuideProfessionInfo(activeProfessionInfo)
  local active = type(activeProfessionInfo) == "table" and activeProfessionInfo or nil

  if not active and Professions and Professions.GetProfessionInfo then
    active = Professions.GetProfessionInfo()
  end

  if not active then
    return nil
  end

  local baseID = GetBaseProfessionID(active)
  if not baseID then
    return active
  end

  local savedChild = self:GetSavedChildSkillLineID(baseID)
  if not savedChild then
    return active
  end

  -- IMPORTANT: do NOT change Blizzard selection; we only return info for the guide to use.
  local fullSaved = GetFullProfessionInfo(savedChild)
  return fullSaved or active
end

-- Legacy no-op (some code calls this)
---@return nil
function ProfessionMemory:TryInstall()
  -- Intentionally empty: guide memory is driven by our dropdown + tab loading only.
end
