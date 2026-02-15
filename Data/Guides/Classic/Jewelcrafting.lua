local Addon = _G.Guidestone
local Guides = Addon.modules.Guides
local Logger = Addon.modules.Logger
local Localization = Addon.modules.Localization

local function L(key, ...)
  return Localization:Get(key, ...)
end

local ok, err = Guides:RegisterGuide({
  id = "classic_jewelcrafting",
  title = "Classic Jewelcrafting 1-300",
  expansionKey = "CLASSIC",
  professionKey = "JEWELCRAFTING",
  professionName = "Jewelcrafting",

  skillLineID = 2524,

  guideUrl = "https://www.wow-professions.com/guides/vanilla-jewelcrafting-leveling",

  materials = {
    { itemID = 20815, required = 1,   ignoreAuctionPricing = true }, -- Jeweler's Toolset
    { itemID = 2840,  required = 100, wowProfessionsUrl = "https://www.wow-professions.com/farming/copper-ore-farming" }, -- Copper Ore
    { -- Tigerseye / Malachite
      type = "group",
      mode = "choiceSets",
      label = "Pick one:",
      key = "classicJewelcrafting_30_50",
      choices = {
        {
          id = "tigerseye",
          label = "Tigerseye",
          items = {
            { itemID = 818, required = 20 }
          }
        },
        {
          id = "malachite",
          label = "Malachite",
          items = {
            { itemID = 774, required = 20 }
          }
        }
      },
    },
    { -- Bronze Bar
      itemID = 2841,
      required = 120,
      links = {
        { itemID = 2770, url = "https://www.wow-professions.com/farming/copper-ore-farming" },
        { itemID = 2771, url = "https://www.wow-professions.com/farming/tin-ore-farming" }
      },
      wowheadLinks = {
        { itemID = 2770 },
        { itemID = 2771 },
      }
    },
    { -- Shadowgem or Shadowgem/Small Lustrous Pearl
      type = "group",
      mode = "choiceSets",
      label = "Pick one:",
      key = "classicJewelcrafting_80_100",
      choices = {
        {
          id = "shadowgem",
          label = "Shadowgem",
          items = {
            { itemID = 1210, required = 60 }
          }
        },
        {
          id = "shadowgem_lustrouspearl",
          label = "Shadowgem + Small Lustrous Pearl",
          items = {
            { itemID = 1210, required = 20 },
            { itemID = 5498, required = 20 }
          }
        }
      }
    },
    { itemID = 2838,  required = 80 }, -- Heavy Stone
    { -- Moss Agate / Lesser Moonstone
      type = "group",
      mode = "choiceSets",
      label = "Pick one:",
      key = "classicJewelcrafting_120_150",
      choices = {
        {
          id = "mossAgate",
          label = "Moss Agate",
          items = {
            { itemID = 1206, required = 30 }
          }
        },
        {
          id = "lesserMoonstone",
          label = "Lesser Moonstone",
          items = {
            { itemID = 1705, required = 60 }
          }
        }
      }
    },
    { itemID = 3860,  required = 140, wowProfessionsUrl = "https://www.wow-professions.com/farming/mithril-ore-farming" }, -- Mithril Bar
    { itemID = 7912,  required = 80 }, -- Solid Stone
    { itemID = 3864,  required = 25 }, -- Citrine
    { itemID = 6037,  required = 15 }, -- Truesilver Bar
    { itemID = 7909,  required = 5 }, -- Aquamarine
    { itemID = 12359, required = 50, wowProfessionsUrl = "https://www.wow-professions.com/farming/thorium-ore-farming" }, -- Thorium Bar
    { itemID = 7910,  required = 10 }, -- Star Ruby
    { itemID = 12799, required = 20 }, -- Large Opal
    { itemID = 12800, required = 7 }, -- Azerothian Diamond
    { itemID = 12361, required = 3 }, -- Blue Sapphire
    { itemID = 12808, required = 3 }, -- Essence of Undeath
    { itemID = 12364, required = 20 }, -- Huge Emerald
  },

  trainers = {
    -- Alliance
    { npcId = 44582, name = "Theresa Denman",  uiMapID = 84,  x = 63.60,  y = 61.60, faction = 1 },
    { npcId = 52586, name = "Hanner Gembold",  uiMapID = 87,  x = 50.60,  y = 27.20, faction = 1 },
    { npcId = 19778, name = "Farii",           uiMapID = 103, x = 45.60,  y = 25.00, faction = 1 },

    -- Horde
    { npcId = 46675, name = "Lugrah",             uiMapID = 85,   x = 72.48,   y = 34.34,   faction = 2 },
    { npcId = 52657, name = "Nahari Cloudchaser", uiMapID = 88,   x = 35.02,   y = 53.92,   faction = 2 },
    { npcId = 52587, name = "Neller Fayne",       uiMapID = 90,   x = 55.80,   y = 35.40,   faction = 2 },
    --{ npcId = 19775, name = "Kalinda",            uiMapID = 110,  x = 90.80,   y = 73.40,   faction = 2 }, -- Disabled until Blizzard fixes the map
  },

  steps = {
    { -- Delicate Copper Wire
      fromSkill = 1,
      toSkill = 30,
      recipeID = 25255,
      outputItemID = 20816,
      maxCrafts = 30,
      note = L("TEXT_SAVE_THESE_FOR_LATER_CRAFT")
    },
    { -- Tigerseye Band
      fromSkill = 30,
      toSkill = 50,
      recipeID = 32179,
      outputItemID = 25439,
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_30_50 = "tigerseye" }
    },
    { -- Malachite Pendant
      fromSkill = 30,
      toSkill = 50,
      recipeID = 32178,
      outputItemID = 25438,
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_30_50 = "malachite" }
    },
    { -- Bronze Setting
      fromSkill = 50,
      toSkill = 80,
      recipeID = 25278,
      outputItemID = 20817,
      maxCrafts = 50,
      note = L("TEXT_SAVE_THESE_FOR_LATER_CRAFT")
    },
    { -- Gloom Band
      fromSkill = 80,
      toSkill = 100,
      recipeID = 25287,
      outputItemID = 20823,
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_80_100 = "shadowgem" }
    },
    { -- Simple Pearl Ring
      fromSkill = 80,
      toSkill = 100,
      recipeID = 25284,
      outputItemID = 20820,
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_80_100 = "shadowgem_lustrouspearl" }
    },
    { -- Ring of Twilight Shadows
      fromSkill = 100,
      toSkill = 110,
      recipeID = 25318,
      outputItemID = 20828,
      maxCrafts = 10
    },
    { -- Heavy Stone Statue
      fromSkill = 110,
      toSkill = 120,
      recipeID = 32807,
      outputItemID = 25881,
      maxCrafts = 10
    },
    { -- Pendant of the Agate Shield
      fromSkill = 120,
      toSkill = 150,
      recipeID = 25610,
      outputItemID = 20950,
      maxCrafts = 30,
      requiresChoices = { classicJewelcrafting_120_150 = "mossAgate" }
    },
    { -- Amulet of the Moon
      fromSkill = 120,
      toSkill = 150,
      recipeID = 25339,
      outputItemID = 20830,
      maxCrafts = 30,
      requiresChoices = { classicJewelcrafting_120_150 = "lesserMoonstone" },
      learn = {
        type = "vendor",
        vendors = {
          { npcId = 4229,  name = "Mythrin'dir",     uiMapID = 89,  x = 58.00, y = 34.00, faction = 1 },
          { npcId = 17512, name = "Arred",           uiMapID = 103, x = 45.00, y = 25.60, faction = 1 },
          { npcId = 4561,  name = "Daniel Bartlett", uiMapID = 90,  x = 64.80, y = 38.20, faction = 2 },
          { npcId = 16624, name = "Gelanthis",       uiMapID = 110, x = 90.80, y = 73.60, faction = 2 },
        }
      }
    },
    { -- Mithril Filigree
      fromSkill = 150,
      toSkill = 180,
      recipeID = 25615,
      outputItemID = 20963,
      maxCrafts = 45
    },
    { -- Solid Stone Statue
      fromSkill = 180,
      toSkill = 185,
      recipeID = 32808,
      outputItemID = 25882,
      maxCrafts = 8
    },
    { -- Engraved Truesilver Ring
      fromSkill = 185,
      toSkill = 200,
      recipeID = 25620,
      outputItemID = 20960,
      maxCrafts = 15
    },
    { -- Citrine Ring of Rapid Healing
      fromSkill = 200,
      toSkill = 220,
      recipeID = 25621,
      outputItemID = 20961,
      maxCrafts = 25
    },
    { -- Aquamarine Pendant of the Warrior
      fromSkill = 220,
      toSkill = 225,
      recipeID = 26876,
      outputItemID = 21755,
      maxCrafts = 5
    },
    { -- Thorium Setting
      fromSkill = 225,
      toSkill = 250,
      recipeID = 26880,
      outputItemID = 21752,
      maxCrafts = 50,
      note = L("TEXT_SAVE_THESE_FOR_LATER_CRAFT")
    },
    { -- Ruby Pendant of Fire
      fromSkill = 250,
      toSkill = 260,
      recipeID = 26883,
      outputItemID = 21764,
      maxCrafts = 10
    },
    { -- Simple Opal Ring
      fromSkill = 260,
      toSkill = 280,
      recipeID = 26902,
      outputItemID = 21767,
      maxCrafts = 20
    },
    { -- Diamond Focus Ring
      fromSkill = 280,
      toSkill = 287,
      recipeID = 36526,
      outputItemID = 30422,
      maxCrafts = 7
    },
    { -- Sapphire Pendant of Winter Night
      fromSkill = 287,
      toSkill = 290,
      recipeID = 26908,
      outputItemID = 21790,
      maxCrafts = 3
    },
    { -- Emerald Lion Ring
      fromSkill = 290,
      toSkill = 300,
      recipeID = 34961,
      outputItemID = 29160,
      maxCrafts = 10
    },
  },
})

if not ok then
  Logger.Warn("Failed to register guide classic_jewelcrafting:", err)
end
