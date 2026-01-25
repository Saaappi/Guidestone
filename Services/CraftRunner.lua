local _, ns = ...

ns.CraftRunner = ns.CraftRunner or {}
local CraftRunner = ns.CraftRunner

CraftRunner._frame = CraftRunner._frame or nil
CraftRunner._running = false

CraftRunner._step = nil
CraftRunner._onDone = nil

CraftRunner._targetSkill = 0
CraftRunner._lastSkill = 0
CraftRunner._noSkillupCasts = 0
CraftRunner._maxNoSkillupCasts = 8

CraftRunner._recipeID = nil
CraftRunner._recipeSpellID = nil

local function GetCurrentSkillLevel()
  if Professions and Professions.GetProfessionInfo then
    local info = Professions.GetProfessionInfo()
    return (info and info.skillLevel) or 0
  end
  return 0
end