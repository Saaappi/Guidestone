local _, ns = ...

ns.ProfessionMemory = ns.ProfessionMemory or {}
local ProfessionMemory = ns.ProfessionMemory

local C_Timer = _G.C_Timer

ProfessionMemory._installed = ProfessionMemory._installed or false
ProfessionMemory._db = ProfessionMemory._db or nil

ProfessionMemory._restoreQueued = ProfessionMemory._restoreQueued or false
ProfessionMemory._logoutInProgress = ProfessionMemory._logoutInProgress or false

-- Pending user-chosen values. We commit these at PLAYER_LOGOUT so late UI churn
-- during reload/logout cannot overwrite the correct choice.
ProfessionMemory._pendingChildByParentID = ProfessionMemory._pendingChildByParentID or {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---@param professionInfo table|nil
---@return number|nil
local function GetBaseProfessionKey(professionInfo)
  if type(professionInfo) ~= "table" then
    return nil
  end

  local parentID = tonumber(professionInfo.parentProfessionID)
  if parentID and parentID > 0 then
    return parentID
  end

  local childID = tonumber(professionInfo.professionID)
  if childID and childID > 0 then
    return childID
  end

  return nil
end

---@param skillLineID number|nil
---@return table|nil
local function GetChildProfessionInfoBySkillLineID(skillLineID)
  skillLineID = tonumber(skillLineID)
  if not skillLineID or skillLineID <= 0 then
    return nil
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
    if type(info) == "table" then
      return info
    end
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfos then
    local children = C_TradeSkillUI.GetChildProfessionInfos()
    if type(children) == "table" then
      for i = 1, #children do
        local c = children[i]
        if tonumber(c and c.professionID) == skillLineID then
          return c
        end
      end
    end
  end

  return nil
end

---@return table|nil
local function GetActiveProfessionInfo()
  if Professions and Professions.GetProfessionInfo then
    return Professions.GetProfessionInfo()
  end
  return nil
end

---@return table|nil
local function GetRankBarDropdownButton()
  if not ProfessionsFrame then
    return nil
  end

  local craftingPage = ProfessionsFrame.CraftingPage
  local dropdown = craftingPage and craftingPage.RankBar and craftingPage.RankBar.ExpansionDropdownButton or nil
  if dropdown then
    return dropdown
  end

  local ordersPage = ProfessionsFrame.OrdersPage
  dropdown = ordersPage and ordersPage.RankBar and ordersPage.RankBar.ExpansionDropdownButton or nil
  if dropdown then
    return dropdown
  end

  return nil
end

---@return boolean
local function IsUserSelectingExpansion()
  local dropdown = GetRankBarDropdownButton()
  if not (dropdown and dropdown.IsMenuOpen) then
    return false
  end

  -- When the player picks an expansion, the dropdown menu is open.
  return dropdown:IsMenuOpen() == true
end

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
  if type(map) ~= "table" then
    return nil
  end

  local id = tonumber(map[baseProfessionID])
  if not id or id <= 0 then
    return nil
  end

  return id
end

---@param baseProfessionID number
---@param childSkillLineID number
---@return nil
function ProfessionMemory:SetPending(baseProfessionID, childSkillLineID)
  baseProfessionID = tonumber(baseProfessionID)
  childSkillLineID = tonumber(childSkillLineID)
  if not baseProfessionID or baseProfessionID <= 0 then
    return
  end
  if not childSkillLineID or childSkillLineID <= 0 then
    return
  end

  self._pendingChildByParentID[baseProfessionID] = childSkillLineID

  -- Write through to the database immediately so I can restore the choice
  -- after closing or reopening the Professions frame.
  if self._db then
    self._db.lastProfessionChildSkillLineByParentID = self._db.lastProfessionChildSkillLineByParentID or {}
    if type(self._db.lastProfessionChildSkillLineByParentID) == "table" then
      self._db.lastProfessionChildSkillLineByParentID[baseProfessionID] = childSkillLineID
    end
  end
end

---@param professionInfo table|nil
---@param force boolean|nil
---@return nil
function ProfessionMemory:RememberUserSelection(professionInfo, force)
  if self._logoutInProgress then
    return
  end
  if not self._db then
    return
  end
  if type(professionInfo) ~= "table" then
    return
  end

  -- Only accept Blizzard's event when the player is actively using Blizzard's dropdown,
  -- unless the caller is explicitly forcing the save (via the dropdown in the Leveling Guide tab).
  if not force and not IsUserSelectingExpansion() then
    return
  end

  local baseID = GetBaseProfessionKey(professionInfo)
  local childID = tonumber(professionInfo.professionID)
  if not baseID or not childID or childID <= 0 then
    return
  end

  -- Only mark pending here; we commit at PLAYER_LOGOUT to avoid reload/login churn
  -- overwriting the desired value.
  self:SetPending(baseID, childID)
end

---@return nil
function ProfessionMemory:CommitPendingToDB()
  if not self._db then
    return
  end

  local map = self._db.lastProfessionChildSkillLineByParentID
  if type(map) ~= "table" then
    map = {}
    self._db.lastProfessionChildSkillLineByParentID = map
  end

  for baseID, childID in pairs(self._pendingChildByParentID) do
    if tonumber(baseID) and tonumber(childID) then
      map[baseID] = childID
    end
  end
end

-- ---------------------------------------------------------------------------
-- Restore
-- ---------------------------------------------------------------------------

---@param desiredChildSkillLineID number
---@return nil
function ProfessionMemory:SelectChildSkillLine(desiredChildSkillLineID)
  desiredChildSkillLineID = tonumber(desiredChildSkillLineID)
  if not desiredChildSkillLineID or desiredChildSkillLineID <= 0 then
    return
  end

  -- Always prefer a full professionInfo payload.
  local fullInfo = nil
  if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
    fullInfo = C_TradeSkillUI.GetProfessionInfoBySkillLineID(desiredChildSkillLineID)
  end
  if type(fullInfo) ~= "table" then
    return
  end

  -- IMPORTANT:
  -- This is what Blizzard’s own RankBar dropdown ultimately does.
  -- It updates the Professions UI controller state (which RankBar reads),
  -- and it will call into TradeSkillUI as needed.
  if Professions and Professions.SelectSkillLine then
    Professions.SelectSkillLine(fullInfo)
    return
  end

  -- Fallback (older/odd clients): do the raw API call.
  if C_TradeSkillUI and C_TradeSkillUI.SetProfessionChildSkillLineID then
    C_TradeSkillUI.SetProfessionChildSkillLineID(desiredChildSkillLineID)
  end
end

---@return nil
function ProfessionMemory:QueueRestore()
  if self._restoreQueued then
    return
  end
  self._restoreQueued = true

  local attempts = 0

  ---@return nil
  local function TryRestore()
    attempts = attempts + 1

    if not (ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()) then
      ProfessionMemory._restoreQueued = false
      return
    end

    local info = GetActiveProfessionInfo()
    local baseID = info and GetBaseProfessionKey(info) or nil
    if baseID then
      local desiredChild = ProfessionMemory:GetSavedChildSkillLineID(baseID)
      local currentChild = tonumber(info.professionID)

      if desiredChild and currentChild and desiredChild ~= currentChild then
        -- If child infos aren't ready yet, GetChildProfessionInfoBySkillLineID may return nil.
        -- Retry a bit before giving up.
        local childInfo = GetChildProfessionInfoBySkillLineID(desiredChild)
        if childInfo then
          ProfessionMemory:SelectChildSkillLine(desiredChild)
          ProfessionMemory._restoreQueued = false
          return
        end
      end

      -- No saved value, or already correct.
      if desiredChild and currentChild and desiredChild == currentChild then
        ProfessionMemory._restoreQueued = false
        return
      end
    end

    if attempts < 25 and C_Timer and C_Timer.After then
      C_Timer.After(0.10, TryRestore)
      return
    end

    ProfessionMemory._restoreQueued = false
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0, TryRestore)
  else
    TryRestore()
  end
end

-- ---------------------------------------------------------------------------
-- Installation
-- ---------------------------------------------------------------------------

---@return nil
function ProfessionMemory:TryInstall()
  if self._installed then
    return
  end

  if not self._db then
    return
  end

  if not (ProfessionsFrame and ProfessionsFrame.HookScript) then
    return
  end

  if not (EventRegistry and EventRegistry.RegisterCallback) then
    return
  end

  -- This event is triggered by the RankBar dropdown (user picking an expansion tier).
  -- Treat this as the authoritative "user selected a tier" signal.
  EventRegistry:RegisterCallback("Professions.SelectSkillLine", function(_, professionInfo)
    ProfessionMemory:RememberUserSelection(professionInfo, false)
  end, ProfessionMemory)

  -- Restore on open.
  ProfessionsFrame:HookScript("OnShow", function()
    ProfessionMemory:QueueRestore()
  end)

  -- Commit at logout/reload and lock writes so late UI churn can't overwrite.
  local logoutFrame = CreateFrame("Frame")
  logoutFrame:RegisterEvent("PLAYER_LOGOUT")
  logoutFrame:SetScript("OnEvent", function()
    ProfessionMemory._logoutInProgress = true
    ProfessionMemory:CommitPendingToDB()
  end)

  self._installed = true
end
