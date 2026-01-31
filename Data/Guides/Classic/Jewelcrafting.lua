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
  },
})

if not ok then
  ns.Logger.Warn("Failed to register guide classic_jewelcrafting:", err)
end
