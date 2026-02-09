local Addon = _G.Guidestone

local type = type

---@class GuidestoneDatabase
local Database = {}

Addon.modules.Database = Database

---@param db table|nil
---@return table
local function EnsureDefaults(db)
  if type(db) ~= "table" then
    db = {}
  end

  if db.debug == nil then
    db.debug = false
  end

  -- When a craft step needs multiple crafts to reach a target skill,
  -- yellow/green recipes wont' guarantee a skill-up per craft. We normally
  -- queue "craft all" and rely on C_TradeSkillUI.StopRecipeRepeat() to stop
  -- exactly at the target. If StopRecipeRepeat isn't available, I'll fall
  -- back to this multiplier.
  if db.craftBufferWait == nil then
    db.craftBufferWait = 1.5
  end

  -- Persist per-guide choice-group selections.
  db.choiceGroups = db.choiceGroups or {}

  -- Persist the last selected profession expansion (child skill line) per base profession.
  -- Key = parentProfessionID (stable), Value = professionID (child skill line for selected expansion).
  db.lastProfessionChildSkillLineByParentID = db.lastProfessionChildSkillLineByParentID or {}

  -- ---------------------------------------------------------------------------
  -- Trainer learner defaults
  -- ---------------------------------------------------------------------------

  -- Shows a "Train Needed" button on the trainer UI when the addon detects
  -- recipes required by the active guide.
  if db.trainerEnableButton == nil then
    db.trainerEnableButton = true
  end

  -- If enabled, the addon will automatically purchase trainer services that
  -- amtch the active guide's needed recipes when the trainer window opens.
  if db.trainerAutoLearn == nil then
    db.trainerAutoLearn = false
  end

  -- Skill lookahead for selecting needed steps.
  if db.trainerLookahead == nil then
    db.trainerLookahead = 25
  end

  -- Spending cap in copper. (0 = no cap)
  if db.trainerMaxSpendCopper == nil then
    db.trainerMaxSpendCopper = 0
  end

  return db
end

---@return table
function Database:Init()
  _G.GuidestoneDB = EnsureDefaults(_G.GuidestoneDB)
  Addon.db = _G.GuidestoneDB
  return Addon.db
end
