local Addon = _G.Guidestone
local Localization = Addon.modules.Localization

Localization:RegisterLocale("enUS", {
  -- Generic
  CHAT_PREFIX = Addon.name,
  CMD_COMMANDS = "Commands:",

  ERR_PROF_API_UNAVAILABLE = "Professions API is unavailable.",
  ERR_NO_PROF_INFO = "No profession info. Open a profession window first.",

  -- Main UI
  TAB_LEVELING_GUIDE = "Leveling Guide",
  HEADER_LEVELING_GUIDE = "Leveling Guide",
  HEADER_MATERIALS_REQUIRED = "Materials Required",
  HEADER_TRAINERS = "Trainers",
  DROPDOWN_SELECT_EXPANSION = "Select Expansion",

  TEXT_NO_GUIDE_AVAILABLE = "No guide available for this profession.",
  TEXT_NO_TRAINERS_AVAILABLE = "No trainers available in this guide.",

  TOOLTIP_VENDOR = "Vendor",
  TOOLTIP_TRAINER = "Trainer",
  TOOLTIP_MATERIAL = "Material",

  -- Trainer Button
  BUTTON_TRAIN_NEEDED = "Train Needed",
  BUTTON_TRAIN_NEEDED_FMT = "Train Needed (%d)",

  -- Link Popup
  LINKPOPUP_TITLE_LINK = "Link",
  LINKPOPUP_TITLE_LINKS = "Links",
  LINKPOPUP_DESC = "Copy the link below and paste it into your browser.",
  LINKPOPUP_SELECT_ALL = "Select All",

  -- Settings
  SETTINGS_SECTION_TRAINER = "Trainer"
})