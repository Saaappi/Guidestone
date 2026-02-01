local _, ns = ...

local Logger = ns.Logger

ns.TrainerLearner = ns.TrainerLearner or {}
local TrainerLearner = ns.TrainerLearner

-- Cache globals (perf + avoids accidental globals)
local CreateFrame = CreateFrame
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown

local GetProfessions = GetProfessions
local GetProfessionInfo = GetProfessionInfo

local GetNumTrainerServices = GetNumTrainerServices
local GetTrainerServiceInfo = GetTrainerServiceInfo
local GetTrainerServiceSkillLine = GetTrainerServiceSkillLine
local BuyTrainerService = BuyTrainerService
local GetTrainerServiceTypeFilter = GetTrainerServiceTypeFilter
local SetTrainerServiceTypeFilter = SetTrainerServiceTypeFilter
local GetTrainerServiceSkillReq = GetTrainerServiceSkillReq

local ExpandTrainerSkillLine = ExpandTrainerSkillLine

TrainerLearner._frame = TrainerLearner._frame or nil
TrainerLearner._active = false
TrainerLearner._attempts = 0
TrainerLearner._maxAttempts = 60
TrainerLearner._lastRun = 0
TrainerLearner._playerProfSet = nil
TrainerLearner._trainerProf = nil

---@param num number
---@return nil
local function DebugDumpTrainerRows(num)
  if not (Logger and Logger.Debug) then
    return
  end

  -- Only dump once per trainer session.
  if TrainerLearner._didDump then
    return
  end
  TrainerLearner._didDump = true

  local maxRows = math.min(num, 12)
  for i = 1, maxRows do
    local name, rank, category = GetTrainerServiceInfo(i)
    local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i) or nil
    local reqSkill = GetTrainerServiceSkillReq and GetTrainerServiceSkillReq(i) or nil
    Logger:Debug("TrainerLearner: row", i,
      "cat", tostring(category),
      "skillLine", tostring(skillLine),
      "reqSkill", tostring(reqSkill),
      "name", tostring(name))
  end
end

---@return table<string, boolean>
local function GetPlayerProfessionNameSet()
  local set = {}

  if not (GetProfessions and GetProfessionInfo) then
    return set
  end

  local p1, p2, p3, p4, p5, p6 = GetProfessions()
  local profs = { p1, p2, p3, p4, p5, p6 }

  for i = 1, #profs do
    local profIndex = profs[i]
    if profIndex then
      local name = GetProfessionInfo(profIndex)
      if type(name) == "string" and name ~= "" then
        set[name] = true
      end
    end
  end

  return set
end

---@return nil
local function EnsureTrainerShowsAvailable()
  if not (GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter) then
    return
  end

  -- If the user has "Available" toggled off, we will never see anything learnable.
  local ok, enabled = pcall(GetTrainerServiceTypeFilter, "available")
  if not ok then
    return
  end

  if enabled then
    return
  end

  -- Correct signature: (type, enable [, exclusive]) — enable is boolean. :contentReference[oaicite:4]{index=4}
  pcall(SetTrainerServiceTypeFilter, "available", true)
end

---@param num number
---@return nil
local function ExpandAllTrainerHeaders(num)
  if not (ExpandTrainerSkillLine and GetTrainerServiceInfo) then
    return
  end

  -- Expand headers first so skills are visible.
  for i = 1, num do
    local name, rank, category, expanded = GetTrainerServiceInfo(i)
    if category == "header" and not expanded then
      -- Defensive: only call on headers.
      ExpandTrainerSkillLine(i)
    end
  end
end

---@param playerProfSet table<string, boolean>
---@param num number
---@return string|nil trainerProfession
local function DetectTrainerProfession(playerProfSet, num)
  if type(playerProfSet) ~= "table" then
    return nil
  end

  local found = nil

  -- Fast path: skill line name per row. :contentReference[oaicite:5]{index=5}
  if GetTrainerServiceSkillLine then
    for i = 1, num do
      local skillLine = GetTrainerServiceSkillLine(i)
      if type(skillLine) == "string" and skillLine ~= "" and playerProfSet[skillLine] then
        if found and found ~= skillLine then
          return nil -- ambiguous
        end
        found = skillLine
      end
    end
    if found then
      return found
    end
  end

  -- Fallback: required skill name per row. :contentReference[oaicite:6]{index=6}
  if GetTrainerServiceSkillReq then
    for i = 1, num do
      local skillName = GetTrainerServiceSkillReq(i)
      if type(skillName) == "string" and skillName ~= "" and playerProfSet[skillName] then
        if found and found ~= skillName then
          return nil -- ambiguous
        end
        found = skillName
      end
    end
  end

  return found
end

---@return nil
function TrainerLearner:Reset()
  self._active = false
  self._attempts = 0
  self._lastRun = 0
  self._playerProfSet = nil
  self._trainerProf = nil
end

---@return nil
function TrainerLearner:RunPass()
  if not self._active then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    self:Reset()
    return
  end

  -- Throttle: TRAINER_UPDATE can spam.
  local now = (GetTime and GetTime()) or 0
  if now > 0 and (now - (self._lastRun or 0)) < 0.10 then
    return
  end
  self._lastRun = now

  if not (GetNumTrainerServices and GetTrainerServiceInfo and BuyTrainerService) then
    self:Reset()
    return
  end

  local num = tonumber(GetNumTrainerServices()) or 0
  if num <= 0 then
    -- Trainer list not ready yet; stay active and wait for TRAINER_UPDATE.
    return
  end

  EnsureTrainerShowsAvailable()
  DebugDumpTrainerRows(num)

  -- Build cached player professions once per session.
  if not self._playerProfSet then
    self._playerProfSet = GetPlayerProfessionNameSet()
  end

  -- Make sure headers are expanded so skills become visible.
  ExpandAllTrainerHeaders(num)

  -- Detect trainer profession once; cache it.
  if not self._trainerProf then
    self._trainerProf = DetectTrainerProfession(self._playerProfSet, num)
    if Logger and Logger.Debug then
      Logger:Debug("TrainerLearner: detected trainer profession:", self._trainerProf or "nil")
    end
  end

  -- Requirement: only learn if trainer is related to a profession the player already has.
  if not self._trainerProf then
    self:Reset()
    return
  end

  -- Buy ONE available skill per pass; rely on TRAINER_UPDATE for the next pass.
  for i = 1, num do
    local skillLine = GetTrainerServiceSkillLine and GetTrainerServiceSkillLine(i) or nil
    if skillLine == self._trainerProf then
      local name, rank, category = GetTrainerServiceInfo(i)
      if category == "available" then
        BuyTrainerService(i)

        self._attempts = (self._attempts or 0) + 1
        if self._attempts >= (self._maxAttempts or 60) then
          self:Reset()
          return
        end

        if Logger and Logger.Debug then
          Logger:Debug("TrainerLearner: bought", name or "?", "index", i, "attempt", self._attempts)
        end

        return
      end
    end
  end

  -- No more available skills for this profession.
  self:Reset()
end

local function EnsureFrame()
  if TrainerLearner._frame then
    return TrainerLearner._frame
  end

  local f = CreateFrame("Frame")
  f:Hide()

  f:RegisterEvent("TRAINER_SHOW")
  f:RegisterEvent("TRAINER_UPDATE")
  f:RegisterEvent("TRAINER_CLOSED")

  f:SetScript("OnEvent", function(_, event)
    if event == "TRAINER_CLOSED" then
      TrainerLearner:Reset()
      return
    end

    if event == "TRAINER_SHOW" then
      TrainerLearner._active = true
      TrainerLearner._attempts = 0
      TrainerLearner._lastRun = 0
      TrainerLearner._playerProfSet = nil
      TrainerLearner._trainerProf = nil

      if Logger and Logger.Debug then
        Logger:Debug("TrainerLearner: TRAINER_SHOW")
      end

      TrainerLearner._didDump = false
      EnsureTrainerShowsAvailable()

      TrainerLearner:RunPass()
      return
    end

    if event == "TRAINER_UPDATE" then
      if not TrainerLearner._active then
        return
      end

      if Logger and Logger.Debug then
        Logger:Debug("TrainerLearner: TRAINER_UPDATE")
      end

      TrainerLearner:RunPass()
      return
    end
  end)

  TrainerLearner._frame = f
  return f
end

EnsureFrame()
