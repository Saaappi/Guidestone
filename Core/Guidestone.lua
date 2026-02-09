local addonName = ...

---@class GuidestoneAddon
---@field name string
---@field db table|nil
---@field events Frame|nil
---@field modules table<string, table>
local Addon = {
  name = addonName,
  db = nil,
  events = nil,
  modules = {}
}

_G.Guidestone = Addon

---@return GuidestoneAddon
function Addon:Get()
  return self
end


local ADDON, ns = ...

--[[local function EnsureDB()
  if type(GuidestoneDB) ~= "table" then
    GuidestoneDB = {}
  end

  if GuidestoneDB.debug == nil then
    GuidestoneDB.debug = false
  end

  -- When a craft step needs multiple crafts to reach a target skill,
  -- yellow/green recipes wont' guarantee a skill-up per craft. We normally
  -- queue "craft all" and rely on C_TradeSkillUI.StopRecipeRepeat() to stop
  -- exactly at the target. If StopRecipeRepeat isn't available, I'll fall
  -- back to this multiplier.
  if GuidestoneDB.craftBufferWait == nil then
    GuidestoneDB.craftBufferWait = 1.5
  end

  -- Persist per-guide choice-group selections.
  GuidestoneDB.choiceGroups = GuidestoneDB.choiceGroups or {}

  -- Persist the last selected profession expansion (child skill line) per base profession.
  -- Key = parentProfessionID (stable), Value = professionID (child skill line for selected expansion).
  GuidestoneDB.lastProfessionChildSkillLineByParentID = GuidestoneDB.lastProfessionChildSkillLineByParentID or {}

  -- ---------------------------------------------------------------------------
  -- Trainer learner defaults
  -- ---------------------------------------------------------------------------

  -- Shows a "Train Needed" button on the trainer UI when the addon detects
  -- recipes required by the active guide.
  if GuidestoneDB.trainerEnableButton == nil then
    GuidestoneDB.trainerEnableButton = true
  end

  -- If enabled, the addon will automatically purchase trainer services that
  -- amtch the active guide's needed recipes when the trainer window opens.
  if GuidestoneDB.trainerAutoLearn == nil then
    GuidestoneDB.trainerAutoLearn = false
  end

  -- Skill lookahead for selecting needed steps.
  if GuidestoneDB.trainerLookahead == nil then
    GuidestoneDB.trainerLookahead = 25
  end

  -- Spending cap in copper. (0 = no cap)
  if GuidestoneDB.trainerMaxSpendCopper == nil then
    GuidestoneDB.trainerMaxSpendCopper = 0
  end
end]]

local function PrintPrefix(...)
  print("|cff9AD6FFGuidestone|r", ...)
end

---@return nil
local function DumpProfessionInfo()
  if not (Professions and Professions.GetProfessionInfo) then
    PrintPrefix("Professions API not available.")
    return
  end

  local info = Professions.GetProfessionInfo()
  if not info then
    PrintPrefix("No profession info. Open a profession window first.")
    return
  end

  PrintPrefix("Profession dump:")
  PrintPrefix("professionName:", info.professionName or "nil")
  PrintPrefix("professionID (child):", info.professionID or "nil")
  PrintPrefix("parentProfessionName:", info.parentProfessionName or "nil")
  PrintPrefix("parentProfessionID (base):", info.parentProfessionID or "nil")
  PrintPrefix("skillLevel:", info.skillLevel or "nil")
  PrintPrefix("maxSkillLevel:", info.maxSkillLevel or "nil")

  if C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfos then
    local children = C_TradeSkillUI.GetChildProfessionInfos()
    if type(children) == "table" then
      PrintPrefix("Child profession infos:")
      for i = 1, #children do
        local c = children[i]
        PrintPrefix("-", c.expansionName or "?", "id:", c.professionID or "nil")
      end
    end
  end

  if GuidestoneDB and type(GuidestoneDB.lastProfessionChildSkillLineByParentID) == "table" then
    local key = tonumber(info.parentProfessionID) or tonumber(info.professionID)
    if key then
      PrintPrefix("Saved child for base", key, "=>", GuidestoneDB.lastProfessionChildSkillLineByParentID[key] or "nil")
    end
  end
end

SLASH_GUIDESTONE1 = "/guidestone"
SlashCmdList["GUIDESTONE"] = function(msg)
  msg = (msg or ""):lower()

  if msg == "dump" then
    DumpProfessionInfo()
    return
  end

  if msg == "debug" then
    GuidestoneDB.debug = not GuidestoneDB.debug
    PrintPrefix("Debug:", GuidestoneDB.debug and "ON" or "OFF")
    return
  end

  PrintPrefix("Commands:")
  PrintPrefix("/guidestone dump - prints active profession info (open a profession first)")
  PrintPrefix("/guidestone debug - toggles debug logging")
end

local initialized = false

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")

f:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 == ADDON then
      EnsureDB()

      -- Register addon settings.
      if ns.Settings and ns.Settings.Init then
        ns.Settings:Init(GuidestoneDB)
      end

      -- Initialize profession skill line memory.
      if ns.ProfessionMemory and ns.ProfessionMemory.Init then
        ns.ProfessionMemory:Init(GuidestoneDB)
      end

      -- Initialize trainer auto-learning service.
      if ns.TrainerLearner and ns.TrainerLearner.Init then
        ns.TrainerLearner:Init()
      end
    elseif arg1 == "Blizzard_Professions" then
      TryInitProfessionsTab()
    end
  elseif event == "PLAYER_LOGIN" then
    TryInitProfessionsTab()
  end
end)
