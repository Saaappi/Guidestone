local Addon = _G.Guidestone
local Logger = Addon.modules.Logger
local Guides = Addon.modules.Guides

local ok, err = Guides:RegisterGuide({
  id = "cataclysm_alchemy",
  title = "Cataclysm Alchemy 1-75",
  expansionKey = "CATA",
  professionKey = "ALCHEMY",
  professionName = "Alchemy",

  -- Cataclysm Alchemy
  skillLineID = 2482,

  guideUrl = "https://www.wow-professions.com/guides/cataclysm-alchemy-leveling",

  materials = {
    { itemID = 3371,  required = 80, ignoreAuctionPricing = true }, -- Crystal Vial
    { itemID = 44322, required = 1,  aliasItems = { 9149, 44324 }, ignoreAuctionPricing = true }, -- Mercurial Alchemist Stone
    { itemID = 52983, required = 85, wowProfessionsUrl = "https://www.wow-professions.com/farming/cinderbloom-farming" },
    { itemID = 52985, required = 15, wowProfessionsUrl = "https://www.wow-professions.com/farming/azsharas-veil-farming" },
    { itemID = 52986, required = 25, wowProfessionsUrl = "https://www.wow-professions.com/farming/heartblossom-farming" },
    { itemID = 52987, required = 27, wowProfessionsUrl = "https://www.wow-professions.com/farming/twilight-jasmine-farming" },
    { itemID = 52988, required = 60, wowProfessionsUrl = "https://www.wow-professions.com/farming/whiptail-farming" },
    { itemID = 52329, required = 45 }, -- Volatile Life
    { itemID = 52179, required = 15 }, -- Alicite
    {
      type = "group",
      mode = "choiceSets",
      label = "Pick one:",
      key = "cataclysmAlchemy_001",
      choices = {
        {
          id = "001",
          label = "Zephyrite, Azshara's Veil",
          items = {
            { itemID = 52178, required = 15 },
            { itemID = 52985, required = 15 }
          }
        },
        {
          id = "002",
          label = "Nightstone, Twilight Jasmine",
          items = {
            { itemID = 52180, required = 15 },
            { itemID = 52987, required = 15 }
          }
        }
      }
    },
  },

  trainers = {
    -- Alliance
    { npcId = 5499, name = "Lilyssia Nightbreeze",   uiMapID = 84,  x = 46.40,  y = 79.60, faction = 1 },
    { npcId = 5177, name = "Tally Berryfizz",        uiMapID = 87,  x = 67.20,  y = 54.20, faction = 1 },
    { npcId = 4160, name = "Ainethil",               uiMapID = 89,  x = 55.00,  y = 23.80, faction = 1 },
    { npcId = 16723, name = "Lucc",                  uiMapID = 103, x = 27.80,  y = 60.20, faction = 1 },

    -- Horde
    { npcId = 3347, name = "Yelmak",                 uiMapID = 85,  x = 55.56, y = 46.74,  faction = 2 },
    { npcId = 4611, name = "Doctor Herbert Halsey",  uiMapID = 90,  x = 47.60, y = 73.00,  faction = 2 },
    { npcId = 3009, name = "Bena Winterhoof",        uiMapID = 88,  x = 46.80, y = 33.60,  faction = 2 },
    --{ npcId = 16642, name = "Camberon",              uiMapID = 110, x = 66.40, y = 16.40, faction = 2 }, -- Disabled until Blizzard fixes the map
  },

  steps = {
    { -- Draught of War
      fromSkill = 1,
      toSkill = 5,
      recipeID = 93935,
      outputItemID = 67415,
      maxCrafts = 5
    },
    { -- Ghost Elixir
      fromSkill = 5,
      toSkill = 10,
      recipeID = 80477,
      outputItemID = 58084,
      maxCrafts = 5
    },
    { -- Volcanic Potion
      fromSkill = 10,
      toSkill = 15,
      recipeID = 80481,
      outputItemID = 58091,
      maxCrafts = 5
    },
    { -- Elixir of the Cobra
      fromSkill = 15,
      toSkill = 25,
      recipeID = 80484,
      outputItemID = 58092,
      maxCrafts = 10
    },
    { -- Elixir of Deep Earth
      fromSkill = 25,
      toSkill = 30,
      recipeID = 80488,
      outputItemID = 58093,
      maxCrafts = 5
    },
    { -- Elixir of Impossible Accuracy
      fromSkill = 30,
      toSkill = 35,
      recipeID = 80491,
      outputItemID = 58094,
      maxCrafts = 5
    },
    { -- Mythical Mana Potion
      fromSkill = 35,
      toSkill = 40,
      recipeID = 80494,
      outputItemID = 57192,
      maxCrafts = 5
    },
    { -- Golemblood Potion
      fromSkill = 40,
      toSkill = 45,
      recipeID = 80496,
      outputItemID = 58146,
      maxCrafts = 5
    },
    { -- Mythical Healing Potion
      fromSkill = 45,
      toSkill = 60,
      recipeID = 80498,
      outputItemID = 57191,
      maxCrafts = 27
    },
    { -- Flask of Titanic Strength
      fromSkill = 60,
      toSkill = 65,
      recipeID = 80723,
      outputItemID = 58088,
      maxCrafts = 5
    },
    { -- Transmute: Demonseye
      fromSkill = 65,
      toSkill = 70,
      recipeID = 80248,
      outputItemID = 52194,
      maxCrafts = 5,
      requiresChoices = { cataclysmAlchemy_001 = "002" }
    },
    { -- Transmute: Ocean Sapphire
      fromSkill = 65,
      toSkill = 70,
      recipeID = 80246,
      outputItemID = 52191,
      maxCrafts = 5,
      requiresChoices = { cataclysmAlchemy_001 = "001" }
    },
    { -- Transmute: Amberjewel
      fromSkill = 70,
      toSkill = 75,
      recipeID = 80247,
      outputItemID = 52195,
      maxCrafts = 5
    },
  },
})

if not ok then
  Logger.Warn("Failed to register guide cataclysm_alchemy:", err)
end
