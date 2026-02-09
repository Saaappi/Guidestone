local Addon = _G.Guidestone

local tostring = tostring
local format = string.format




local ADDON, ns = ...

ns.Settings = ns.Settings or {}
local SettingsModule = ns.Settings

local CATEGORY_NAME = "Guidestone"

SettingsModule._inited = false
SettingsModule.categoryID = nil
SettingsModule.db = nil

---@param db table
---@return nil
local function EnsureTrainerDefaults(db)
  if type(db) ~= "table" then
    return
  end

  if db.trainerEnableButton == nil then
    db.trainerEnableButton = true
  else
    db.trainerEnableButton = db.trainerEnableButton == true
  end

  if db.trainerAutoLearn == nil then
    db.trainerAutoLearn = false
  else
    db.trainerAutoLearn = db.trainerAutoLearn == true
  end
end

---@param value boolean
---@return boolean
local function ToBool(value)
  return value == true
end

---@param Settings table
---@param defaultValue boolean
---@return any
local function GetBooleanDefault(Settings, defaultValue)
  if Settings and Settings.Default then
    if defaultValue == true and Settings.Default.True ~= nil then
      return Settings.Default.True
    end
    if defaultValue == false and Settings.Default.False ~= nil then
      return Settings.Default.False
    end
  end
  return defaultValue
end

---@param db table
---@return nil
function SettingsModule:Init(db)
  if self._inited then
    return
  end
  self._inited = true

  if type(db) ~= "table" then
    return
  end

  self.db = db

  local Settings = _G.Settings
  if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
    return
  end

  EnsureTrainerDefaults(db)

  local category, layout = Settings.RegisterVerticalLayoutCategory(CATEGORY_NAME)
  self.categoryID = category and category.GetID and category:GetID() or nil

  local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
  if type(CreateCheckbox) ~= "function" then
    return
  end

  -- Optional: add a section header like EventQ (only if layout supports it)
  if layout and layout.AddInitializer and _G.CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(_G.CreateSettingsListSectionHeaderInitializer("Trainer"))
  end

  -- trainerEnableButton
  local function GetTrainerEnableButton()
    EnsureTrainerDefaults(db)
    return ToBool(db.trainerEnableButton)
  end

  local function SetTrainerEnableButton(value)
    EnsureTrainerDefaults(db)
    db.trainerEnableButton = ToBool(value)
  end

  local trainerEnableButtonSetting = Settings.RegisterProxySetting(
    category,
    "GUIDESTONE_TRAINER_ENABLE_BUTTON",
    Settings.VarType and Settings.VarType.Boolean or "boolean",
    "Show trainer 'Train Needed' button",
    GetBooleanDefault(Settings, true),
    GetTrainerEnableButton,
    SetTrainerEnableButton
  )

  CreateCheckbox(category, trainerEnableButtonSetting,
    "Adds a button to the trainer window that trains only the recipes required by the active Guidestone guide."
  )

  -- trainerAutoLearn
  local function GetTrainerAutoLearn()
    EnsureTrainerDefaults(db)
    return ToBool(db.trainerAutoLearn)
  end

  local function SetTrainerAutoLearn(value)
    EnsureTrainerDefaults(db)
    db.trainerAutoLearn = ToBool(value)
  end

  local trainerAutoLearnSetting = Settings.RegisterProxySetting(
    category,
    "GUIDESTONE_TRAINER_AUTO_LEARN",
    Settings.VarType and Settings.VarType.Boolean or "boolean",
    "Auto-train guide-required recipes",
    GetBooleanDefault(Settings, false),
    GetTrainerAutoLearn,
    SetTrainerAutoLearn
  )

  CreateCheckbox(category, trainerAutoLearnSetting,
    "When you open a trainer, automatically buys trainer services that match the active guide. Only trains what the guide needs."
  )

  Settings.RegisterAddOnCategory(category)
end

---@return nil
function SettingsModule:Open()
  local Settings = _G.Settings
  if not (Settings and Settings.OpenToCategory) then
    return
  end

  if not self._inited and type(GuidestoneDB) == "table" then
    self:Init(GuidestoneDB)
  end

  if self.categoryID then
    Settings.OpenToCategory(self.categoryID)
  end
end
