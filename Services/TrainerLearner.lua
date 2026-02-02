local ADDON, ns = ...

ns.TrainerLearner = ns.TrainerLearner or {}
local TrainerLearner = ns.TrainerLearner

local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local GetNumTrainerServices = _G.GetNumTrainerServices
local GetTrainerServiceInfo = _G.GetTrainerServiceInfo
local SelectTrainerService = _G.SelectTrainerService
local BuyTrainerService = _G.BuyTrainerService
local C_Spell = _G.C_Spell
local C_Timer = _G.C_Timer
local Settings = _G.Settings

TrainerLearner._frame = TrainerLearner._frame or nil
TrainerLearner._button = TrainerLearner._button or nil
TrainerLearner._matches = TrainerLearner._matches or {}
TrainerLearner._totalCost = 0
TrainerLearner._autoLearnPending = TrainerLearner._autoLearnPending or false

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---@param name string|nil
---@return string|nil normalized
local function NormalizeName(name)
  if type(name) ~= "string" then
    return nil
  end

  -- Normalize for matching: lowercase + remove all whitespace
  name = name:lower()
  name = name:gsub("[^%w]", "")

  if name == "" then
    return nil
  end
  return name
end

---@param spellID number|nil
---@return string|nil
local function GetSpellNameByID(spellID)
  spellID = tonumber(spellID)
  if not spellID or spellID <= 0 then
    return nil
  end

  -- Retail: C_Spell.GetSpellInfo returns a table
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellID)
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      return info.name
    end
    if type(info) == "string" and info ~= "" then
      return info
    end
  end

  -- Classic/other: GetSpellInfo returns name
  if _G.GetSpellInfo then
    local name = _G.GetSpellInfo(spellID)
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  return nil
end

---@param skillLineID number|nil
---@return number
local function GetSkillLevelBySkillLineID(skillLineID)
  skillLineID = tonumber(skillLineID)
  if not skillLineID or skillLineID <= 0 then
    return 0
  end

  if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
    local info = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLineID)
    if type(info) == "table" then
      local skillLevel = tonumber(info.skillLevel or info.skillRank or info.rank or info.level)
      if skillLevel then
        return skillLevel
      end
    end

    return 0
  end
end

---@return table|nil
function TrainerLearner:GetActiveGuide()
  if ns.GuidePage and ns.GuidePage.currentGuide then
    return ns.GuidePage.currentGuide
  end

  -- Fallback: the user may be at a trainer with the Professions UI closed.
  -- In that case, use the last guide selected in the profession UI.
  local lastSkillLineID = GuidestoneDB and tonumber(GuidestoneDB.lastGuideSkillLineID) or nil
  if lastSkillLineID and ns.Guides and ns.Guides.GetBySkillLineID then
    return ns.Guides:GetBySkillLineID(lastSkillLineID)
  end
  return nil
end

---@param guide table|nil
---@return number
function TrainerLearner:GetCurrentSkill(guide)
  local skillLineID = (type(guide) == "table") and tonumber(guide.skillLineID) or nil
  return GetSkillLevelBySkillLineID(skillLineID)
end

---@return number
function TrainerLearner:GetLookahead()
  return (GuidestoneDB and tonumber(GuidestoneDB.trainerLookahead)) or 25
end

---@return number
function TrainerLearner:GetMaxSpendCopper()
  return (GuidestoneDB and tonumber(GuidestoneDB.trainerMaxSpendCopper)) or 0
end

---@return boolean
function TrainerLearner:IsAutoLearnEnabled()
  return (GuidestoneDB and GuidestoneDB.trainerAutoLearn == true)
end

---@return boolean
function TrainerLearner:IsButtonEnabled()
  return (GuidestoneDB and GuidestoneDB.trainerEnableButton == true)
end

---@param msg string
---@return nil
function TrainerLearner:Debug(msg)
  if ns.Logger and ns.Logger.Debug then
    ns.Logger:Debug(msg)
  end
end

---@param msg string
---@return nil
function TrainerLearner:Info(msg)
  if ns.Logger and ns.Logger.Info then
    ns.Logger:Info(msg)
  else
    print("|cff9AD6FFGuidestone|r", msg)
  end
end

---@param msg string
---@return nil
function TrainerLearner:Warn(msg)
  if ns.Logger and ns.Logger.Warn then
    ns.Logger:Warn(msg)
  else
    print("|cff9AD6FFGuidestone|r", "|cffFFB020WARN|r", msg)
  end
end

-- ---------------------------------------------------------------------------
-- Needed recipes computation
-- ---------------------------------------------------------------------------

---@param step table
---@return string learnType
local function GetStepLearnType(step)
  if type(step) ~= "table" then
    return "trainer"
  end

  local learn = step.learn
  if type(learn) == "table" then
    local t = tostring(learn.type or ""):lower()
    if t ~= "" then
      return t
    end
  end

  local source = tostring(step.learnSource or ""):lower()
  if source ~= "" then
    return source
  end

  return "trainer"
end

---@param guide table
---@param currentSkill number
---@param lookahead number
---@return table<string, boolean> neededByName
function TrainerLearner:BuildNeededTrainerSet(guide, currentSkill, lookahead)
  local needed = {}

  if type(guide) ~= "table" or type(guide.steps) ~= "table" then
    return needed
  end

  local maxSkill = currentSkill + (tonumber(lookahead) or 0)

  for _, step in ipairs(guide.steps) do
    if type(step) == "table" then
      local learnType = GetStepLearnType(step)
      if learnType == "trainer" then
        local fromSkill = tonumber(step.fromSkill) or 0
        local toSkill = tonumber(step.toSkill) or 999999

        -- Include steps up to the lookahead window (don’t force fromSkill <= currentSkill)
        if fromSkill <= maxSkill and currentSkill < toSkill then
          local spellName
          local spellID = tonumber(step.recipeSpellID)

          if spellID and spellID > 0 then
            spellName = GetSpellNameByID(spellID)
          end

          if not spellName then
            spellName = step.recipeName
          end

          local normalized = NormalizeName(spellName)
          if normalized then
            needed[normalized] = true
          end
        end
      end
    end
  end
  return needed
end

-- ---------------------------------------------------------------------------
-- Trainer scanning / purchasing
-- ---------------------------------------------------------------------------

---@return boolean
function TrainerLearner:IsTrainerAPIAvailable()
  return type(GetNumTrainerServices) == "function"
    and type(GetTrainerServiceInfo) == "function"
    and type(BuyTrainerService) == "function"
end

---@return nil
function TrainerLearner:ScanTrainer()
  self._matches = {}
  self._totalCost = 0

  if not self:IsTrainerAPIAvailable() then
    return
  end

  local guide = self:GetActiveGuide()
  if not guide then
    return
  end

  local currentSkill = self:GetCurrentSkill(guide)
  local needed = self:BuildNeededTrainerSet(guide, currentSkill, self:GetLookahead())

  local neededCount = 0
  for _ in pairs(needed) do
    neededCount = neededCount + 1
  end

  self:Debug(("Trainer scan: guide=%s skillLineID=%s currentSkill=%s lookahead=%d needed=%d"):format(
    tostring(guide.id),
    tostring(guide.skillLineID),
    currentSkill,
    self:GetLookahead(),
    neededCount
  ))

  local num = tonumber(GetNumTrainerServices()) or 0
  if num <= 0 then
    return
  end
  self:Debug(("Trainer services: num=%d"):format(num))

  local logged = 0
  for i = 1, num do
    local name, rank, category = GetTrainerServiceInfo(i)

    if category == "available" and type(name) == "string" and name ~= "" then
      local normalized = NormalizeName(name)
      local isNeeded = normalized and needed[normalized] or false

      if logged < 10 then
        logged = logged + 1
        self:Debug(("Trainer[%d] %s | norm=%s | needed=%s"):format(
          i,
          name,
          tostring(normalized),
          isNeeded and "YES" or "no"
        ))
      end

      if isNeeded then
        local cost = 0
        if type(GetTrainerServiceCost) == "function" then
          cost = tonumber(GetTrainerServiceCost(i)) or 0
        end

        self._matches[#self._matches + 1] = {
          index = i,
          name = name,
          cost = cost
        }
        self._totalCost = self._totalCost + cost
      end
    end
  end

  self:Debug(("Trainer matches: %d (totalCost=%d)"):format(#self._matches, self._totalCost))
end

---@return Frame|nil
function TrainerLearner:GetTrainerParent()
  local trainerFrame = _G.TrainerFrame
  local classTrainerFrame = _G.ClassTrainerFrame

  if trainerFrame and trainerFrame.IsShown and trainerFrame:IsShown() then
    return trainerFrame
  end
  if classTrainerFrame and classTrainerFrame.IsShown and classTrainerFrame:IsShown() then
    return classTrainerFrame
  end

  return trainerFrame or classTrainerFrame
end

---@return nil
function TrainerLearner:EnsureButton()
  if self._button then
    return
  end

  local parent = self:GetTrainerParent()
  if not parent or not CreateFrame then
    -- Trainer UI can be created after TRAINER_SHOW fires; retry shortly.
    if C_Timer and C_Timer.After then
      C_Timer.After(0.1, function()
        self:RefreshTrainerState()
      end)
    end
    return
  end

  local btn = CreateFrame("Button", nil, ClassTrainerTrainButton, "UIPanelButtonTemplate")
  btn:SetSize(150, 22)
  btn:SetPoint("TOPRIGHT", ClassTrainerTrainButton, "TOPLEFT", -5, 0)
  btn:SetText("Train Needed")
  btn:Hide()

  btn:SetScript("OnClick", function()
    self:TrainNeeded()
  end)

  btn:SetScript("OnEnter", function()
    if not _G.GameTooltip then
      return
    end

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText(ADDON)
    if #self._matches == 0 then
      GameTooltip:AddLine("No guide-required recipes available.", 0.8, 0.8, 0.8, true)
    else
      GameTooltip:AddLine(("Will train %d recipe(s)."):format(#self._matches), 0.9, 0.9, 0.9)
      GameTooltip:AddLine(("Total cost: %s"):format(C_CurrencyInfo.GetCoinTextureString and C_CurrencyInfo.GetCoinTextureString(self._totalCost) or tostring(self._totalCost)), 0.9, 0.9, 0.9)
    end
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  self._button = btn
end

---@return nil
function TrainerLearner:UpdateButton()
  if not self._button then
    return
  end

  if not self:IsButtonEnabled() then
    self._button:Hide()
    return
  end

  if #self._matches <= 0 then
    self._button:Hide()
    return
  end

  self._button:SetText(("Train Needed (%d)"):format(#self._matches))
  self._button:Show()
end

---@return nil
function TrainerLearner:RefreshTrainerState()
  self:EnsureButton()
  self:ScanTrainer()
  self:UpdateButton()
end

---@return nil
function TrainerLearner:TrainNeeded()
  if InCombatLockdown and InCombatLockdown() then
    self:Warn("Cannot train while in combat.")
    return
  end

  if #self._matches <= 0 then
    return
  end

  local maxSpend = self:GetMaxSpendCopper()
  if maxSpend > 0 and self._totalCost > maxSpend then
    self:Warn(("Trainer purchase blocked because total cost exceeds your cap."))
    return
  end

  -- Indices can shift as the player trains. Buy from the highest index down to
  -- reduce the risk.
  table.sort(self._matches, function(a, b)
    return (a.index or 0) > (b.index or 0)
  end)

  local trained = 0
  for _, entry in ipairs(self._matches) do
    local idx = tonumber(entry.index)
    if idx and idx > 0 then
      if type(SelectTrainerService) == "function" then
        pcall(SelectTrainerService, idx)
      end
      pcall(BuyTrainerService, idx)
      trained = trained + 1
    end
  end

  if trained > 0 then
    self:Info(("Trained %d guide-required recipe(s)."):format(trained))
  end

  -- Trainer list updates asynchronously.
  if C_Timer and C_Timer.After then
    C_Timer.After(0.2, function()
      self:RefreshTrainerState()
    end)
  end
end

-- ---------------------------------------------------------------------------
-- Event wiring
-- ---------------------------------------------------------------------------

---@return Frame
function TrainerLearner:EnsureFrame()
  if self._frame then
    return self._frame
  end

  local f = CreateFrame("Frame")
  f:Hide()

  f:RegisterEvent("TRAINER_SHOW")
  f:RegisterEvent("TRAINER_UPDATE")
  f:RegisterEvent("TRAINER_CLOSED")

  f:SetScript("OnEvent", function(_, event)
    if event == "TRAINER_SHOW" then
      -- Mark pending first; trainer services often populate after SHOW.
      self._autoLearnPending = self:IsAutoLearnEnabled()

      self:RefreshTrainerState()

      -- Defer a tick to catch late population of trainer services.
      if self._autoLearnPending and C_Timer and C_Timer.After then
        C_Timer.After(0.10, function()
          if not self._autoLearnPending then
            return
          end

          self:RefreshTrainerState()

          if #self._matches > 0 then
            self._autoLearnPending = false
            self:TrainNeeded()
          end
        end)
      end

      return
    end

    if event == "TRAINER_UPDATE" then
      self:RefreshTrainerState()
      if self._autoLearnPending and #self._matches > 0 then
        self._autoLearnPending = false
        self:TrainNeeded()
      end
      return
    end

    if event == "TRAINER_CLOSED" then
      if self._button then
        self._button:Hide()
      end

      self._matches = {}
      self._totalCost = 0
      self._autoLearnPending = false
      return
    end
  end)

  self._frame = f
  return f
end

---@return nil
function TrainerLearner:Init()
  if not self:IsTrainerAPIAvailable() then
    return
  end

  self:EnsureFrame():Show()
end