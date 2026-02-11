local Addon = _G.Guidestone
local Localization = Addon.modules.Localization

Localization:RegisterLocale("enUS", {
  -- Generic
  CHAT_PREFIX = Addon.name,
  CMD_COMMANDS = "Commands:",

  ERR_PROF_API_UNAVAILABLE = "Professions API is unavailable.",
  ERR_NO_PROF_INFO = "No profession info. Open a profession window first.",
  ERR_NO_RECIPE_SELECTED = "No recipe selected. Open a profession, select a recipe, and then run /guidestone recipeInfo.",
  ERR_CANNOT_TRAIN_IN_COMBAT = "Cannot train while in combat.",
  ERR_COST_EXCEEDS_CAP = "Trainer purchase blocked because total cost exceeds your cap.",

  TEXT_TRAINED_N_RECIPES = "Trained %d guide-required recipe(s).",

  -- Main UI
  TAB_LEVELING_GUIDE = "Leveling Guide",
  HEADER_LEVELING_GUIDE = "Leveling Guide",
  HEADER_MATERIALS_REQUIRED = "Materials Required",
  HEADER_TRAINERS = "Trainers",
  DROPDOWN_SELECT_EXPANSION = "Select Expansion",

  TEXT_NO_GUIDE_AVAILABLE = "No guide available for this profession.",
  TEXT_NO_TRAINERS_AVAILABLE = "No trainers available in this guide.",

  TEXT_SAVE_THESE_FOR_LATER_CRAFT = "Save these, you'll need them for a later craft.",
  TEXT_AUCTIONATOR_UNAVAILABLE = "Estimated AH Cost: (Auctionator not loaded)",
  TEXT_AUCTIONATOR_WITH_MISSING_PRICES = "Estimated AH Cost: %s (some prices missing)",
  TEXT_AUCTIONATOR_ABSOLUTE_PRICE = "Estimated AH Cost: %s",

  MENU_LABEL_CHOOSE_A_VENDOR = "Choose a vendor:",

  LABEL_VENDOR = "Vendor",

  TOOLTIP_VENDOR = "Vendor",
  TOOLTIP_TRAINER = "Trainer",
  TOOLTIP_MATERIAL = "Material",

  TOOLTIP_SELECT = "Select",
  TOOLTIP_SET_TOMTOM_WAYPOINT = "Set TomTom Waypoint",
  TOOLTIP_SET_WAYPOINT = "Set Waypoint",

  TOOLTIP_RECIPE_MISSING_TRAINER = "You don't know %s yet. Visit a trainer to learn it.",
  TOOLTIP_RECIPE_MISSING_VENDOR = "You don't know %s yet. Visit a vendor to purchase it.",

  -- Trainer Button
  BUTTON_TRAIN_NEEDED = "Train Needed",
  BUTTON_TRAIN_NEEDED_FMT = "Train Needed (%d)",

  -- Link Popup
  LINKPOPUP_TITLE_LINK = "Link",
  LINKPOPUP_TITLE_LINKS = "Links",
  LINKPOPUP_DESC = "Copy the link below and paste it into your browser.",
  LINKPOPUP_SELECT_ALL = "Select All",

  -- Settings
  SETTINGS_SECTION_TRAINER = "Trainer",
  SETTINGS_LABEL_TRAINER_SHOW_TRAIN_NEEDED_BUTTON = "Show 'Train Needed' Button",
  SETTINGS_DESC_TRAINER_SHOW_TRAIN_NEEDED_BUTTON = "Adds a button to the trainer window that trains only the recipes required by the active guide.",
  SETTINGS_LABEL_TRAINER_AUTO_TRAIN_RECIPES_BUTTON = "Auto-train Guide-required Recipes",
  SETTINGS_DESC_TRAINER_AUTO_TRAIN_RECIPES_BUTTON = "When you open a trainer, automatically buys trainer services that match the active guide.",
})