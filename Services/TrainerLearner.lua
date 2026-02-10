local Addon = _G.Guidestone
local Guides = Addon.modules.Guides
local GuidePage = Addon.modules.GuidePage
local Util = Addon.modules.Util
local Logger = Addon.modules.Logger
local Localization = Addon.modules.Localization

---@class GuidestoneTrainerLearner
local TrainerLearner = {}
Addon.modules.TrainerLearner = TrainerLearner

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local GetNumTrainerServices = GetNumTrainerServices
local GetTrainerServiceInfo = GetTrainerServiceInfo
local SelectTrainerService = SelectTrainerService
local GetTrainerSelectionIndex = GetTrainerSelectionIndex
local GetTrainerServiceItemLink = GetTrainerServiceItemLink
local GetTrainerServiceCost = GetTrainerServiceCost
local BuyTrainerService = BuyTrainerService
local type = type
local tonumber = tonumber
local tostring = tostring
local C_Spell = C_Spell
local C_Timer = C_Timer
local C_TradeSkillUI = C_TradeSkillUI

local function L(key, ...)
  return Localization:Get(key, ...)
end

TrainerLearner._frame = TrainerLearner._frame or nil
TrainerLearner._button = TrainerLearner._button or nil
TrainerLearner._matches = TrainerLearner._matches or {}
TrainerLearner._totalCost = 0
TrainerLearner._autoLearnPending = TrainerLearner._autoLearnPending or false
TrainerLearner._serviceItemIdCache = TrainerLearner._serviceItemIdCache or {}
TrainerLearner._serviceSpellIdCache = TrainerLearner._serviceSpellIdCache or {}

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

---@param index number
---@return string|nil
function TrainerLearner:GetTrainerServiceLinkSafe(index)
  if type(GetTrainerServiceItemLink) ~= "function" then
    return nil
  end

  local link = GetTrainerServiceItemLink(index)
  if link then
    return link
  end

  if type(SelectTrainerService) ~= "function" then
    return nil
  end

  local prevIndex = nil
  if type(GetTrainerSelectionIndex) == "function" then
    prevIndex = GetTrainerSelectionIndex()
  end

  SelectTrainerService(index)
  link = GetTrainerServiceItemLink(index)

  if prevIndex and prevIndex ~= index then
    SelectTrainerService(prevIndex)
  end

  return link
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
  if GuidePage and GuidePage.currentGuide then
    return GuidePage.currentGuide
  end

  -- Fallback: the user may be at a trainer with the Professions UI closed.
  -- In that case, use the last guide selected in the profession UI.
  local lastSkillLineID = Addon.db and tonumber(Addon.db.lastGuideSkillLineID) or nil
  if lastSkillLineID and Guides and Guides.GetBySkillLineID then
    return Guides:GetBySkillLineID(lastSkillLineID)
  end
  return nil
end

---@param link string|nil
---@return number|nil itemID
---@return number|nil spellID
local function ExtractTrainerIDsFromLink(link)
  if type(link) ~= "string" or link == "" then
    return nil, nil
  end

  local itemStr = link:match("Hitem:(%d+)")
  if itemStr then
    return tonumber(itemStr), nil
  end

  local spellStr = link:match("Hspell:(%d+)")
  if spellStr then
    return nil, tonumber(spellStr)
  end

  local enchantStr = link:match("Henchant:(%d+)")
  if enchantStr then
    return nil, tonumber(enchantStr)
  end

  return nil, nil
end

---@param guide table|nil
---@return number
function TrainerLearner:GetCurrentSkill(guide)
  local skillLineID = (type(guide) == "table") and tonumber(guide.skillLineID) or nil
  return GetSkillLevelBySkillLineID(skillLineID)
end

---@return number
function TrainerLearner:GetLookahead()
  return (Addon.db and tonumber(Addon.db.trainerLookahead)) or 25
end

---@return number
function TrainerLearner:GetMaxSpendCopper()
  return (Addon.db and tonumber(Addon.db.trainerMaxSpendCopper)) or 0
end

---@return boolean|nil
function TrainerLearner:IsAutoLearnEnabled()
  return (Addon.db and Addon.db.trainerAutoLearn == true)
end

---@return boolean|nil
function TrainerLearner:IsButtonEnabled()
  return (Addon.db and Addon.db.trainerEnableButton == true)
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
---@return table<number, boolean> neededItemIDs
---@return table<number, boolean> neededSpellIDs
---@return table<string, boolean> neededByName
---@return number neededCount
function TrainerLearner:BuildNeededTrainerSets(guide, currentSkill, lookahead)
  local neededItemIDs = self._neededItemIDs or {}
  local neededSpellIDs = self._neededSpellIDs or {}
  local neededByName = self._neededByName or {}

  Util:WipeTable(neededItemIDs)
  Util:WipeTable(neededSpellIDs)
  Util:WipeTable(neededByName)

  if type(guide) ~= "table" or type(guide.steps) ~= "table" then
    self._neededItemIDs = neededItemIDs
    self._neededSpellIDs = neededSpellIDs
    self._neededByName = neededByName
    return neededItemIDs, neededSpellIDs, neededByName, 0
  end

  local maxSkill = currentSkill + (tonumber(lookahead) or 0)
  local neededCount = 0

  for _, step in ipairs(guide.steps) do
    if type(step) == "table" and GetStepLearnType(step) == "trainer" then
      local fromSkill = tonumber(step.fromSkill) or 0
      local toSkill = tonumber(step.toSkill) or 999999

      if fromSkill <= maxSkill and currentSkill < toSkill then
        local itemID = tonumber(step.recipeItemID)
        if itemID and itemID > 0 and not neededItemIDs[itemID] then
          neededItemIDs[itemID] = true
          neededCount = neededCount + 1
        end

        local spellID = tonumber(step.recipeID)
        if spellID and spellID > 0 and not neededSpellIDs[spellID] then
          neededSpellIDs[spellID] = true
          neededCount = neededCount + 1
        end

        -- Back-compat: if no IDs yet, keep the old name matching.
        if not itemID and not spellID then
          local normalized = NormalizeName(step.recipeName)
          if normalized and not neededByName[normalized] then
            neededByName[normalized] = true
            neededCount = neededCount + 1
          end
        end
      end
    end
  end

  self._neededItemIDs = neededItemIDs
  self._neededSpellIDs = neededSpellIDs
  self._neededByName = neededByName

  return neededItemIDs, neededSpellIDs, neededByName, neededCount
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
  self._matches = self._matches or {}
  Util:WipeTable(self._matches)
  self._totalCost = 0

  if not self:IsTrainerAPIAvailable() then
    return
  end

  local guide = self:GetActiveGuide()
  if not guide then
    return
  end

  local currentSkill = self:GetCurrentSkill(guide)
  local neededItemIDs, neededSpellIDs, neededByName, neededCount =
    self:BuildNeededTrainerSets(guide, currentSkill, self:GetLookahead())

  if neededCount <= 0 then
    Logger:Debug(("Trainer scan: guide=%s skillLineID=%s currentSkill=%s lookahead=%d needed=0"):format(
      tostring(guide.id), tostring(guide.skillLineID), currentSkill, self:GetLookahead()
    ))
    return
  end

  Logger:Debug(("Trainer scan: guide=%s skillLineID=%s currentSkill=%s lookahead=%d needed=%d"):format(
    tostring(guide.id), tostring(guide.skillLineID), currentSkill, self:GetLookahead(), neededCount
  ))

  local num = tonumber(GetNumTrainerServices()) or 0
  if num <= 0 then
    return
  end
  Logger:Debug(("Trainer services: num=%d"):format(num))

  local remaining = neededCount
  local itemCache = self._serviceItemIdCache or {}
  local spellCache = self._serviceSpellIdCache or {}
  self._serviceItemIdCache = itemCache
  self._serviceSpellIdCache = spellCache

  local logged = 0
  for i = 1, num do
    if remaining <= 0 then
      break
    end

    local name, category = GetTrainerServiceInfo(i)
    if category == "available" and type(name) == "string" and name ~= "" then
      local itemID = itemCache[i]
      local spellID = spellCache[i]

      -- 0 sentinel means "cached nil"
      if itemID == nil and spellID == nil then
        local link = self:GetTrainerServiceLinkSafe(i)
        itemID, spellID = ExtractTrainerIDsFromLink(link)
        itemCache[i] = itemID or 0
        spellCache[i] = spellID or 0
      else
        if itemID == 0 then itemID = nil end
        if spellID == 0 then spellID = nil end
      end

      local isNeeded = false
      if itemID and neededItemIDs[itemID] then
        isNeeded = true
        neededItemIDs[itemID] = nil
        remaining = remaining - 1
      elseif spellID and neededSpellIDs[spellID] then
        isNeeded = true
        neededSpellIDs[spellID] = nil
        remaining = remaining - 1
      else
        -- Back-compat fallback (not locale-safe, but helps while migrating guides)
        local normalized = NormalizeName(name)
        if normalized and neededByName[normalized] then
          isNeeded = true
          neededByName[normalized] = nil
          remaining = remaining - 1
        end
      end

      if logged < 10 then
        logged = logged + 1
        Logger:Debug(("Trainer[%d] %s | itemID=%s spellID=%s | needed=%s"):format(
          i, name, tostring(itemID), tostring(spellID), isNeeded and "YES" or "no"
        ))
      end

      if isNeeded then
        local cost = 0
        if type(GetTrainerServiceCost) == "function" then
          cost = tonumber(GetTrainerServiceCost(i)) or 0
        end

        self._matches[#self._matches + 1] = { index = i, name = name, cost = cost, itemID = itemID, spellID = spellID }
        self._totalCost = self._totalCost + cost
      end
    end
  end

  Logger:Debug(("Trainer matches: %d (totalCost=%d)"):format(#self._matches, self._totalCost))
end

---@return Frame|nil
function TrainerLearner:GetTrainerParent()
  local trainerFrame = TrainerFrame
  local classTrainerFrame = ClassTrainerFrame

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
  btn:SetText(L("BUTTON_TRAIN_NEEDED"))
  btn:Hide()

  btn:SetScript("OnClick", function()
    self:TrainNeeded()
  end)

  btn:SetScript("OnEnter", function()
    if not _G.GameTooltip then
      return
    end

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    GameTooltip:SetText(Addon.name)
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

  self._button:SetText((L("BUTTON_TRAIN_NEEDED_FMT")):format(#self._matches))
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
    self:Warn(L("ERR_CANNOT_TRAIN_IN_COMBAT"))
    return
  end

  if #self._matches <= 0 then
    return
  end

  local maxSpend = self:GetMaxSpendCopper()
  if maxSpend > 0 and self._totalCost > maxSpend then
    self:Warn(L("ERR_COST_EXCEEDS_CAP"))
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

  Util:WipeTable(self._serviceItemIdCache)
  Util:WipeTable(self._serviceSpellIdCache)

  if trained > 0 then
    self:Info((L("TEXT_TRAINED_N_RECIPES")):format(trained))
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

      Util:WipeTable(self._serviceItemIdCache)
      Util:WipeTable(self._serviceSpellIdCache)

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

      Util:WipeTable(self._serviceItemIdCache)
      Util:WipeTable(self._serviceSpellIdCache)
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