local _, ns = ...

local ok, err = ns.Guides:RegisterGuide({
  id = "classic_jewelcrafting",
  title = "Classic Jewelcrafting 1-300",
  expansionKey = "CLASSIC",
  professionKey = "JEWELCRAFTING",
  professionName = "Jewelcrafting",

  skillLineID = 2524,

  guideUrl = "https://www.wow-professions.com/guides/vanilla-jewelcrafting-leveling",

  materials = {
    { itemID = 20815, required = 1, noBuffer = true }, -- Jeweler's Toolset
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
        { title = "Copper Ore", url = "https://www.wow-professions.com/farming/copper-ore-farming" },
        { title = "Tin Ore", url = "https://www.wow-professions.com/farming/tin-ore-farming" }
      },
      note = "Smelted from Copper and Tin ore."
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
    { itemID = 12359,  required = 50, wowProfessionsUrl = "https://www.wow-professions.com/farming/thorium-ore-farming" }, -- Thorium Bar
    { itemID = 7910,  required = 10 }, -- Star Ruby
    { itemID = 12799,  required = 20 }, -- Large Opal
    { itemID = 12800,  required = 7 }, -- Azerothian Diamond
    { itemID = 12361,  required = 3 }, -- Blue Sapphire
    { itemID = 12808,  required = 3 }, -- Essence of Undeath
    { itemID = 12364,  required = 20 }, -- Huge Emerald
  },

  trainers = {
    -- Alliance
    { name = "Lilyssia Nightbreeze",  uiMapID = 84,  zone = "Stormwind City",  x = 46.40,  y = 79.60, faction = 1 },
    { name = "Tally Berryfizz",       uiMapID = 87,  zone = "Ironforge",       x = 67.20,  y = 54.20, faction = 1 },
    { name = "Ainethil",              uiMapID = 89,  zone = "Darnassus",       x = 55.00,  y = 23.80, faction = 1 },
    { name = "Lucc",                  uiMapID = 103, zone = "The Exodar",      x = 27.80,  y = 60.20, faction = 1 },

    -- Horde
    { name = "Yelmak",                uiMapID = 85,  zone = "Orgrimmar",        x = 55.56, y = 46.74, faction = 2 },
    { name = "Doctor Herbert Halsey", uiMapID = 90,  zone = "Undercity",        x = 47.60, y = 73.00, faction = 2 },
    { name = "Bena Winterhoof",       uiMapID = 88,  zone = "Thunder Bluff",    x = 46.80, y = 33.60, faction = 2 },
    { name = "Camberon",              uiMapID = 110, zone = "Silvermoon City",  x = 66.40, y = 16.40, faction = 2 },
  },

  steps = {
    {
      fromSkill = 1,
      toSkill = 30,
      recipeName = "Delicate Copper Wire",
      maxCrafts = 30,
      note = "Save these, you'll need them for the next craft."
    },
    {
      fromSkill = 30,
      toSkill = 50,
      recipeName = "Tigerseye Band",
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_30_50 = "tigerseye" }
    },
    {
      fromSkill = 30,
      toSkill = 50,
      recipeName = "Malachite Pendant",
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_30_50 = "malachite" }
    },
    {
      fromSkill = 50,
      toSkill = 80,
      recipeName = "Bronze Setting",
      maxCrafts = 50,
      note = "Save these, you'll need them for the next craft."
    },
    {
      fromSkill = 80,
      toSkill = 100,
      recipeName = "Gloom Band",
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_80_100 = "shadowgem" }
    },
    {
      fromSkill = 80,
      toSkill = 100,
      recipeName = "Simple Pearl Ring",
      maxCrafts = 20,
      requiresChoices = { classicJewelcrafting_80_100 = "shadowgem_lustrouspearl" }
    },
    {
      fromSkill = 100,
      toSkill = 110,
      recipeName = "Ring of Twilight Shadows",
      maxCrafts = 10
    },
    {
      fromSkill = 110,
      toSkill = 120,
      recipeName = "Heavy Stone Statue",
      maxCrafts = 10
    },
    {
      fromSkill = 120,
      toSkill = 150,
      recipeName = "Pendant of the Agate Shield",
      maxCrafts = 30
    },
    {
      fromSkill = 150,
      toSkill = 180,
      recipeName = "Mithril Filigree",
      maxCrafts = 45
    },
    {
      fromSkill = 180,
      toSkill = 185,
      recipeName = "Solid Stone Statue",
      maxCrafts = 8
    },
    {
      fromSkill = 185,
      toSkill = 200,
      recipeName = "Engraved Truesilver Ring",
      maxCrafts = 15
    },
    {
      fromSkill = 200,
      toSkill = 220,
      recipeName = "Citrine Ring of Rapid Healing",
      maxCrafts = 25
    },
    {
      fromSkill = 220,
      toSkill = 225,
      recipeName = "Aquamarine Pendant of the Warrior",
      maxCrafts = 5
    },
    {
      fromSkill = 225,
      toSkill = 250,
      recipeName = "Thorium Setting",
      maxCrafts = 50,
      note = "Save these, you'll need them for future crafts. Craft more as you need them."
    },
    {
      fromSkill = 250,
      toSkill = 260,
      recipeName = "Ruby Pendant of Fire",
      maxCrafts = 10
    },
    {
      fromSkill = 260,
      toSkill = 280,
      recipeName = "Simple Opal Ring",
      maxCrafts = 20
    },
    {
      fromSkill = 280,
      toSkill = 287,
      recipeName = "Diamond Focus Ring",
      maxCrafts = 7
    },
    {
      fromSkill = 287,
      toSkill = 290,
      recipeName = "Sapphire Pendant of Winter Night",
      maxCrafts = 3
    },
    {
      fromSkill = 290,
      toSkill = 300,
      recipeName = "Emerald Lion Ring",
      maxCrafts = 10
    },
  },
})

if not ok then
  ns.Logger.Warn("Failed to register guide classic_jewelcrafting:", err)
end
