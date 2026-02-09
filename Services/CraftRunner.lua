local Addon = _G.Guidestone

---@class GuidestoneCraftRunner
local CraftRunner = {}
Addon.modules.CraftRunner = CraftRunner

local type = type
local lower = string.lower
local C_TradeSkillUI = C_TradeSkillUI

CraftRunner._frame = CraftRunner._frame or nil
CraftRunner._running = false

CraftRunner._step = nil
CraftRunner._onDone = nil

CraftRunner._targetSkill = 0
CraftRunner._lastSkill = 0
CraftRunner._noSkillupCasts = 0
CraftRunner._maxNoSkillupCasts = 25

CraftRunner._recipeID = nil
CraftRunner._recipeSpellID = nil
CraftRunner._repeatCancelAttempted = false

ns.GetCurrentSkillLevel = function()
  if Professions and Professions.GetProfessionInfo then
    local info = Professions.GetProfessionInfo()
    return (info and info.skillLevel) or 0
  end
  return 0
end

ns.FindRecipeIDByName = function(recipeName)
  if type(recipeName) ~= "string" or recipeName == "" then
    return nil
  end

  if not (C_TradeSkillUI and C_TradeSkillUI.GetFilteredRecipeIDs and C_TradeSkillUI.GetRecipeInfo) then
    return nil
  end

  local ids = C_TradeSkillUI.GetFilteredRecipeIDs()
  if type(ids) ~= "table" then
    return nil
  end

  local target = recipeName:lower()
  local bestExact = nil
  local bestContains = nil

  for _, recipeID in ipairs(ids) do
    local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
    local name = info and info.name
    if type(name) == "string" then
      local n = lower(name)
      if n == target then
        bestExact = recipeID
        break
      end
      if not bestContains and n:find(target, 1, true) then
        bestContains = recipeID
      end
    end
  end

  return bestExact or bestContains
end

local function EnsureFrame()
  if CraftRunner._frame then
    return CraftRunner._frame
  end

  local f = CreateFrame("Frame")
  f:Hide()

  f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
  f:RegisterEvent("SKILL_LINES_CHANGED")
  f:RegisterEvent("TRADE_SKILL_LIST_UPDATE")
  f:RegisterEvent("TRADE_SKILL_CLOSE")
  f:RegisterEvent("GARRISON_TRADESKILL_NPC_CLOSED")

  f:SetScript("OnEvent", function(_, event, ...)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      CraftRunner:OnSpellcastSucceeded(...)
      return
    end

    if event == "SKILL_LINES_CHANGED" then
      CraftRunner:OnSkillLinesChanged()
      return
    end

    if event == "TRADE_SKILL_LIST_UPDATE" then
      CraftRunner:OnTradeSkillListUpdate()
      return
    end

    if event == "TRADE_SKILL_CLOSE" or event == "GARRISON_TRADESKILL_NPC_CLOSED" then
      CraftRunner:Stop("profession_closed")
      return
    end
  end)

  CraftRunner._frame = f
  return f
end

function CraftRunner:IsRunning()
  return self._running == true
end

function CraftRunner:ReachedTargetSkill()
  return ns.GetCurrentSkillLevel() >= (self._targetSkill or 0)
end

---@return nil
function CraftRunner:TryStopRecipeRepeat()
  if self._repeatCancelAttempted then
    return
  end

  if not (C_TradeSkillUI and C_TradeSkillUI.StopRecipeRepeat) then
    self._repeatCancelAttempted = true
    return
  end

  -- Best effort. This is intentionally unconditional.
  C_TradeSkillUI.StopRecipeRepeat()
  self._repeatCancelAttempted = true
end

---@return nil
function CraftRunner:OnSkillLinesChanged()
  if not self._running then
    return
  end

  local currentSkill = ns.GetCurrentSkillLevel()
  if currentSkill > (self._lastSkill or 0) then
    self._lastSkill = currentSkill
    self._noSkillupCasts = 0
  end

  if self:ReachedTargetSkill() then
    self:TryStopRecipeRepeat()
    self:Stop("target_skill_reached")
    return
  end
end

---@param step table
---@param onDone function|nil
---@param skipFirstCraft boolean|nil
function CraftRunner:Start(step, onDone, skipFirstCraft)
  if self._running then
    self:Stop("restart")
  end

  if type(step) ~= "table" then
    return
  end

  if type(step.recipeName) ~= "string" or step.recipeName == "" then
    return
  end

  local targetSkill = tonumber(step.toSkill) or 0
  if targetSkill <= 0 then
    return
  end

  if not (_G.ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SelectRecipe) then
    return
  end

  local recipeID = ns.FindRecipeIDByName(step.recipeName)
  if not recipeID then
    return
  end

  local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
  if not recipeInfo then
    return
  end

  self._step = step
  self._onDone = onDone

  self._targetSkill = targetSkill
  self._lastSkill = ns.GetCurrentSkillLevel()
  self._noSkillupCasts = 0

  self._repeatCancelAttempted = false

  self._recipeID = recipeID
  self._recipeSpellID = recipeInfo.spellID

  self._running = true
  EnsureFrame():Show()

  -- Ensure the recipe is selected in the Crafting page so CreateInternal can run.
  local skipRecipeInList = true
  ProfessionsFrame.CraftingPage:SelectRecipe(recipeInfo, skipRecipeInList)

  -- It's imperative that CreateInternal is not called unless the addon is explicitly allowed to.
  if not skipFirstCraft then
    self:TryCraftNext()
  end
end

function CraftRunner:Stop(reason)
  if not self._running then
    return
  end

  -- If a batch craft is in-flight, cancel the remainder so the player doesn't
  -- overshoot the target skill (or waste materials).

  local cb = self._onDone
  local step = self._step

  self._step = nil
  self._onDone = nil

  self._targetSkill = 0
  self._lastSkill = 0
  self._noSkillupCasts = 0

  self._recipeID = nil
  self._recipeSpellID = nil

  if self._frame then
    self._frame:Hide()
  end

  if type(cb) == "function" then
    cb(reason, step)
  end
end

function CraftRunner:TryCraftNext()
  if not self._running then
    return
  end

  if self:ReachedTargetSkill() then
    self:Stop("target_skill_reached")
    return
  end

  local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
  if not craftingPage then
    self:Stop("crafting_page_missing")
    return
  end

  if craftingPage.GetCraftableCount then
    local craftable = craftingPage:GetCraftableCount()
    if not craftable or craftable < 1 then
      self:Stop("not_craftable")
      return
    end
  end

  local recipeLevel = nil
  if craftingPage.SchematicForm and craftingPage.SchematicForm.GetCurrentRecipeLevel then
    recipeLevel = craftingPage.SchematicForm:GetCurrentRecipeLevel()
  end

  -- Craft exactly 1 to preserve stop-at-skill behavior.
  craftingPage:CreateInternal(self._recipeID, 1, recipeLevel)
end

---@param unit string
---@param _ string
---@param spellID number
function CraftRunner:OnSpellcastSucceeded(unit, _, spellID)
  if not self._running then
    return
  end

  if unit ~= "player" then
    return
  end

  -- Prefer matching the recipe spellID to avoid counting unrelated casts.
  -- However, some clients may report a generic tradeskill spellID during
  -- batch crafting, so if we're actively repeating, allow it through.
  if self._recipeSpellID and spellID ~= self._recipeSpellID then
    local repeating = (C_TradeSkillUI and C_TradeSkillUI.IsRecipeRepeating and C_TradeInfo.IsRecipeRepeating()) or false
    if not repeating then
      return
    end
  end

  local currentSkill = ns.GetCurrentSkillLevel()
  if currentSkill > (self._lastSkill or 0) then
    self._lastSkill = currentSkill
    self._noSkillupCasts = 0
  else
    self._noSkillupCasts = (self._noSkillupCasts or 0) + 1
    if self._noSkillupCasts >= (self._maxNoSkillupCasts or 8) then
      self:Stop("no_skillups")
      return
    end
  end
end

function CraftRunner:OnTradeSkillListUpdate()
  if not self._running then
    return
  end

  if self:ReachedTargetSkill() then
    self:TryStopRecipeRepeat()
    self:Stop("target_skill_reached")
    return
  end
end
