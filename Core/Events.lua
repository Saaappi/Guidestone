local Addon = _G.Guidestone
local Logger = Addon.modules.Logger
local Database = Addon.modules.Database
local SettingsModule = Addon.modules.Settings
local ProfessionMemory = Addon.modules.ProfessionMemory
local TrainerLearner = Addon.modules.TrainerLearner
local GuidePage = Addon.modules.GuidePage

---@class GuidestoneEvents
local Events = {}

Addon.modules.Events = Events

---@param event string
function Events:OnEvent(event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == Addon.name then
      Database:Init()

      -- Settings
      if SettingsModule and SettingsModule.Init then
        SettingsModule:Init(Addon.db)
      end

      -- Initialize profession expansion memory.
      if ProfessionMemory and ProfessionMemory.Init then
        ProfessionMemory:Init(Addon.db)
      end

      -- Initialize Trainer auto-learning service.
      if TrainerLearner and TrainerLearner.Init then
        TrainerLearner:Init(Addon.db)
      end

      Logger:Debug("ADDON_LOADED: Core initialization has completed successfully.")
      return
    end

    if name == "Blizzard_Professions" then
      if GuidePage and GuidePage.TryInitProfessionsTab then
        GuidePage:TryInitProfessionsTab()
      end
      return
    end
  end

  if event == "PLAYER_LOGIN" then
    if GuidePage and GuidePage.TryInitProfessionsTab then
      GuidePage:TryInitProfessionsTab()
    end
    return
  end
end

---@return Frame
function Events:Init()
  if Addon.events then
    return Addon.events
  end

  local f = CreateFrame("Frame")
  Addon.events = f

  f:SetScript("OnEvent", function(_, event, ...)
    Events:OnEvent(event, ...)
  end)

  f:RegisterEvent("ADDON_LOADED")
  f:RegisterEvent("PLAYER_LOGIN")

  Logger:Debug("Events initialized successfully.")
  return f
end

Events:Init()
