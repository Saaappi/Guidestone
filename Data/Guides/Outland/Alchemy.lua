local Addon = _G.Guidestone
local Logger = Addon.modules.Logger
local Guides = Addon.modules.Guides

local ok, err = Guides:RegisterGuide({
  id = "tbc_alchemy",
  title = "Outland Alchemy 1-75",
  expansionKey = "TBC",
  professionKey = "ALCHEMY",
  professionName = "Alchemy",

  -- Outland Alchemy
  skillLineID = 2484,

  guideUrl = "https://www.wow-professions.com/guides/outland-alchemy-leveling",

  materials = {
    { itemID = 3371,   required = 85, ignoreAuctionPricing = true }, -- Crystal Vial
    { itemID = 22785,  required = 40, wowProfessionsUrl = "https://www.wow-professions.com/farming/felweed-farming" },
    { itemID = 13464,  required = 24, wowProfessionsUrl = "https://www.wow-professions.com/farming/golden-sansam-farming" },
    { itemID = 22787,  required = 20, wowProfessionsUrl = "https://www.wow-professions.com/farming/ragveil-farming" },
    { itemID = 22786,  required = 80, wowProfessionsUrl = "https://www.wow-professions.com/farming/dreaming-glory-farming" },
    { itemID = 22791,  required = 10, wowProfessionsUrl = "https://www.wow-professions.com/farming/netherbloom-farming" },
    { itemID = 22792,  required = 40, wowProfessionsUrl = "https://www.wow-professions.com/farming/nightmare-vine-farming" }
  },

  trainers = {
    { npcId = 19052, name = "Lorokeem", uiMapID = 111, x = 45.65, y = 21.54, faction = 0 }
  },

  steps = {
    { -- Volatile Healing Potion
      fromSkill = 1,
      toSkill = 15,
      recipeID = 33732,
      outputItemID = 28100,
      maxCrafts = 14
    },
    { -- Elixir of Healing Power
      fromSkill = 15,
      toSkill = 25,
      recipeID = 28545,
      outputItemID = 22825,
      maxCrafts = 10,
    },
    { -- Mad Alchemist's Potion
      fromSkill = 25,
      toSkill = 35,
      recipeID = 45061,
      outputItemID = 34440,
      maxCrafts = 10,
    },
    { -- Super Healing Potion
      fromSkill = 35,
      toSkill = 40,
      recipeID = 28551,
      outputItemID = 22829,
      maxCrafts = 5,
    },
    { -- Super Mana Potion
      fromSkill = 40,
      toSkill = 55,
      recipeID = 28555,
      outputItemID = 22832,
      maxCrafts = 15,
    },
    { -- Major Dreamless Sleep Potion
      fromSkill = 55,
      toSkill = 75,
      recipeID = 28562,
      outputItemID = 22836,
      maxCrafts = 40,
    }
  },
})

if not ok then
  Logger.Warn("Failed to register guide tbc_alchemy:", err)
end
