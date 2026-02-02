local ADDON, ns = ...

local function EnsureDB()
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
end

local function PrintPrefix(...)
  print("|cff9AD6FFGuidestone|r", ...)
end

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
  PrintPrefix("professionID:", info.professionID or "nil")
  PrintPrefix("skillLevel:", info.skillLevel or "nil")
  PrintPrefix("maxSkillLevel:", info.maxSkillLevel or "nil")
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

local function TryInitProfessionsTab()
  if initialized then
    return
  end

  if not _G.ProfessionsFrame then
    return
  end

  -- UI/GuidePage.lua will define ns.GuidePage. I do not require it here.
  if not (ns.GuidePage and ns.GuidePage.Create and ns.GuidePage.LoadForProfession) then
    -- Not an error; it just means the UI file is not implemented yet.
    return
  end

  -- Create the guide page frmae and add it as a Professions tab page.
  local page = ns.GuidePage:Create(ProfessionsFrame)
  if not page then
    return
  end
  page:Hide()

  local tabID = ProfessionsFrame:AddNamedTab("Leveling Guide", page)
  ProfessionsFrame.guidestoneLevelingGuideTabID = tabID

  ---@param checkTabID number
  ---@return boolean
  local function IsGuideTabSelected(checkTabID)
    if not (ProfessionsFrame and ProfessionsFrame.GetTab) then
      return false
    end
    return ProfessionsFrame:GetTab() == checkTabID
  end

  ---@return boolean
  local function IsOverlayCastBarOwnedByProfessions()
    if not (OverlayPlayerCastingBarFrame and OverlayPlayerCastingBarFrame.GetParent) then
      return false
    end
    if not ProfessionsFrame then
      return false
    end

    local parent = OverlayPlayerCastingBarFrame:GetParent()
    while parent do
      if parent == ProfessionsFrame then
        return true
      end
      parent = parent.GetParent and parent:GetParent() or nil
    end

    return false
  end

  ---@param checkTabID number
  ---@return nil
  local function EnsurePlayerCastBarVisibleOnGuideTab(checkTabID)
    if not IsGuideTabSelected(checkTabID) then
      return
    end

    -- Only tear down the overlay bar if Professions created/owns it.
    if not IsOverlayCastBarOwnedByProfessions() then
      return
    end

    if OverlayPlayerCastingBarFrame and OverlayPlayerCastingBarFrame.EndReplacingPlayerBar then
      OverlayPlayerCastingBarFrame:EndReplacingPlayerBar()
    elseif PlayerCastingBarFrame and PlayerCastingBarFrame.SetAndUpdateShowCastbar then
      PlayerCastingBarFrame:SetAndUpdateShowCastbar(true)
    end

    -- Keep CraftingPage state consistent in case Blizzard thinks the override is still active.
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if craftingPage then
      craftingPage.isOverrideCastBarActive = false
    end
  end

  ---@param checkTabID number
  ---@return nil
  local function InstallGuideTabCastBarFix(checkTabID)
    local craftingPage = ProfessionsFrame and ProfessionsFrame.CraftingPage
    if not (craftingPage and craftingPage.SetOverrideCastBarActive) then
      return
    end

    if craftingPage._gsCastBarFixInstalled then
      return
    end
    craftingPage._gsCastBarFixInstalled = true

    local origSetOverrideCastBarActive = craftingPage.SetOverrideCastBarActive

    -- Prevent the Professions overlay cast bar from being used while the addon's tab
    -- hides CraftingPage.
    craftingPage.SetOverrideCastBarActive = function(self, active)
      if active and IsGuideTabSelected(checkTabID) then
        -- Do NOT call the original: it will disable the real PlayerCastingBarFrame and
        -- attach OverlayPlayerCastingBarFrame to a hidden CraftingPage anchor (forcing
        -- the bar to be invisible.)
        self.isOverrideCastBarActive = false
        return
      end

      return origSetOverrideCastBarActive(self, active)
    end
  end

  -- Install the cast bar fix once the addon's tab is created.
  InstallGuideTabCastBarFix(tabID)

  local function RefreshGuideIfVisible(professionInfo)
    if not (ProfessionsFrame and ProfessionsFrame.IsShown and ProfessionsFrame:IsShown()) then
      return
    end

    if not (ProfessionsFrame.GetTab and ProfessionsFrame:GetTab() == tabID) then
      return
    end

    page:Show()
    ns.GuidePage:LoadForProfession(professionInfo)
  end

  if EventRegistry and EventRegistry.RegisterCallback and not page.professionSelectedCallbackRegistered then
    EventRegistry:RegisterCallback("Professions.ProfessionSelected", function(_, professionInfo)
      RefreshGuideIfVisible(professionInfo)
    end, page)

    page.professionSelectedCallbackRegistered = true
  end

  ProfessionsFrame:SetTabCallback(tabID, function()
    -- If a craft is already in progress, ensure it doesn't lose the cast bar
    -- to a professions overlay anchored to a hidden CraftingPage.
    EnsurePlayerCastBarVisibleOnGuideTab(tabID)

    local info = (Professions and Professions.GetProfessionInfo) and Professions.GetProfessionInfo() or nil
    page:Show()
    ns.GuidePage:LoadForProfession(info)
  end)

  ProfessionsFrame:SetTabDeselectCallback(tabID, function()
    page:Hide()
  end)

  initialized = true
end

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
