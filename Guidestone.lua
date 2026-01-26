local ADDON, ns = ...

local function EnsureDB()
  GuidestoneDB = GuidestoneDB or {}
  if GuidestoneDB.debug == nil then
    GuidestoneDB.debug = false
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
    elseif arg1 == "Blizzard_Professions" then
      TryInitProfessionsTab()
    end
  elseif event == "PLAYER_LOGIN" then
    TryInitProfessionsTab()
  end
end)
