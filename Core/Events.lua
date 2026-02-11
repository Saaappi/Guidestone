local Addon = _G.Guidestone
local Util = Addon.modules.Util
local Database = Addon.modules.Database
local SettingsModule = Addon.modules.Settings
local ProfessionMemory = Addon.modules.ProfessionMemory
local TrainerLearner = Addon.modules.TrainerLearner
local GuidePage = Addon.modules.GuidePage
local Logger = Addon.modules.Logger

---@class GuidestoneEvents
local Events = {}
Addon.modules.Events = Events

local strlower = string.lower
local strtrim = string.trim

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
        TrainerLearner:Init()
      end

      SLASH_GUIDESTONE1 = "/guidestone"
      SlashCmdList.GUIDESTONE = function(msg)
        msg = strlower(strtrim(msg or ""))

        if msg == "recipe" then
          Util:DumpSelectedRecipeSnapshot()
          return
        end

        if msg == "dump" then
          Util:DumpProfessionInfo()
          return
        end

        if msg == "debug" then
          Addon.db.debug = not Addon.db.debug
          Logger:Info("Debug:", Addon.db.debug and "ON" or "OFF")
          return
        end

        if msg == "settings" then
          if SettingsModule and SettingsModule.Open then
            SettingsModule:Open()
            return
          end
        end
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

  if event == "AUCTION_HOUSE_SHOW" then
    Addon.auctionHouseOpen = true
    return
  end

  if event == "AUCTION_HOUSE_CLOSED" then
    Addon.auctionHouseOpen = false
    return
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
  f:RegisterEvent("AUCTION_HOUSE_SHOW")
  f:RegisterEvent("AUCTION_HOUSE_CLOSED")
  f:RegisterEvent("PLAYER_LOGIN")

  Logger:Debug("Events initialized successfully.")
  return f
end

Events:Init()
