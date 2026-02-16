local Addon = _G.Guidestone
local Logger = Addon.modules.Logger
local Guides = Addon.modules.Guides

local ok, err = Guides:RegisterGuide({
  id = "northrend_alchemy",
  title = "Northrend Alchemy 1-75",
  expansionKey = "WRATH",
  professionKey = "ALCHEMY",
  professionName = "Alchemy",

  -- Northrend Alchemy
  skillLineID = 2483,

  guideUrl = "https://www.wow-professions.com/guides/northrend-alchemy-leveling",

  materials = {
    { itemID = 44322,  required = 1,   aliasItems = { 9149, 44324 }, ignoreAuctionPricing = true },
    { itemID = 36907,  required = 24,  wowProfessionsUrl = "https://www.wow-professions.com/farming/talandras-rose-farming" },
    { itemID = 36904,  required = 26,  wowProfessionsUrl = "https://www.wow-professions.com/farming/tiger-lily-farming" },
    { itemID = 36901,  required = 60,  wowProfessionsUrl = "https://www.wow-professions.com/farming/goldclover-farming" },
    { itemID = 36903,  required = 24,  wowProfessionsUrl = "https://www.wow-professions.com/farming/adders-tongue-farming" },
    { itemID = 36906,  required = 20,  wowProfessionsUrl = "https://www.wow-professions.com/farming/lichbloom-icethorn-farming" },
    { itemID = 36905,  required = 165, wowProfessionsUrl = "https://www.wow-professions.com/farming/lichbloom-icethorn-farming" },
    {
      type = "group",
      mode = "choiceSets",
      label = "Pick one:",
      key = "northrendAlchemy_001",
      choices = {
        {
          id = "001",
          label = "Dark Jade, Huge Citrine, Eternal Fire",
          items = {
            { itemID = 36932, required = 5 },
            { itemID = 36929, required = 5 },
            { itemID = 36860, required = 5 }
          }
        },
        {
          id = "002",
          label = "Bloodstone, Chalcedony, Eternal Air",
          items = {
            { itemID = 36917, required = 5 },
            { itemID = 36923, required = 5 },
            { itemID = 35623, required = 5 }
          }
        }
      }
    },
    { itemID = 36908, required = 15 }, -- Frost Lotus
    { itemID = 37704, required = 45 } -- Crystallized Life
  },

  trainers = {
    { npcId = 28703, name = "Linzy Blackbolt", uiMapID = 125, x = 42.55, y = 32.09, faction = 0 }
  },

  steps = {
    { -- Icy Mana Potion
      fromSkill = 1,
      toSkill = 5,
      recipeID = 53839,
      outputItemID = 40067,
      maxCrafts = 5
    },
    { -- Potion of Nightmares
      fromSkill = 5,
      toSkill = 10,
      recipeID = 53900,
      outputItemID = 40081,
      maxCrafts = 5
    },
    { -- Elixir of Mighty Strength
      fromSkill = 10,
      toSkill = 20,
      recipeID = 54218,
      outputItemID = 40073,
      maxCrafts = 10
    },
    { -- Elixir of Mighty Agility
      fromSkill = 20,
      toSkill = 30,
      recipeID = 53840,
      outputItemID = 39666,
      maxCrafts = 10
    },
    { -- Indestructible Potion
      fromSkill = 30,
      toSkill = 40,
      recipeID = 53905,
      outputItemID = 40093,
      maxCrafts = 10
    },
    { -- Runic Mana Potion
      fromSkill = 40,
      toSkill = 55,
      recipeID = 53837,
      outputItemID = 33448,
      maxCrafts = 30
    },
    { -- Transmute: Earthsiege Diamond
      fromSkill = 55,
      toSkill = 60,
      recipeID = 57427,
      outputItemID = 41334,
      maxCrafts = 5,
      requiresChoices = { northrendAlchemy_001 = "001" }
    },
    { -- Transmute: Skyflare Diamond
      fromSkill = 55,
      toSkill = 60,
      recipeID = 57425,
      outputItemID = 41266,
      maxCrafts = 5,
      requiresChoices = { northrendAlchemy_001 = "002" }
    },
    { -- Flask of Stoneblood
      fromSkill = 60,
      toSkill = 75,
      recipeID = 53902,
      outputItemID = 46379,
      maxCrafts = 15
    }
  },
})

if not ok then
  Logger.Warn("Failed to register guide northrend_alchemy:", err)
end
