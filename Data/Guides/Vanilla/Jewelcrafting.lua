local _, ns = ...

local ok, err = ns.Guides:RegisterGuide({
  id = "vanilla_jewelcrafting",
  title = "Vanilla Jewelcrafting 1-300",
  expansionKey = "VANILLA",
  professionKey = "JEWELCRAFTING",
  professionName = "Jewelcrafting",

  skillLineID = 2524,

  guideUrl = "https://www.wow-professions.com/guides/vanilla-jewelcrafting-leveling",

  materials = {
    { itemID = 2840,  required = 100, wowProfessionsUrl = "https://www.wow-professions.com/farming/copper-ore-farming" }, -- Copper Ore
    { -- Tigerseye / Malachite
      type = "group",
      label = "Pick One",
      required = 20,
      options = {
        { itemID = 818, wowProfessionsUrl = "" },
        { itemID = 774, wowProfessionsUrl = "" },
      }
    },
    { -- Bronze Bar
      itemID = 2841,
      required = 120,
      links = {
        { title = "Copper Ore", url = "https://www.wow-professions.com/farming/copper-ore-farming" },
        { title = "Tin Ore", url = "https://www.wow-professions.com/farming/tin-ore-farming" }
      },
      note = "Smelted from Copper and Tin bars."
    }
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
      toSkill = 60,
      recipeName = "Minor Healing Potion",
      maxCrafts = 60,
    },
    {
      fromSkill = 60,
      toSkill = 100,
      recipeName = "Lesser Healing Potion",
      maxCrafts = 60,
    },
    {
      fromSkill = 100,
      toSkill = 110,
      recipeName = "Elixir of Wisdom",
      maxCrafts = 10,
    },
    {
      fromSkill = 110,
      toSkill = 140,
      recipeName = "Healing Potion",
      maxCrafts = 33,
    },
    {
      fromSkill = 140,
      toSkill = 155,
      recipeName = "Lesser Mana Potion",
      maxCrafts = 18,
    },
    {
      fromSkill = 155,
      toSkill = 175,
      recipeName = "Greater Healing Potion",
      maxCrafts = 20,
    },
    {
      fromSkill = 175,
      toSkill = 185,
      recipeName = "Mana Potion",
      maxCrafts = 10,
    },
    {
      fromSkill = 185,
      toSkill = 205,
      recipeName = "Elixir of Agility",
      maxCrafts = 20,
    },
    {
      fromSkill = 205,
      toSkill = 215,
      recipeName = "Elixir of Greater Defense",
      maxCrafts = 10,
    },
    {
      fromSkill = 215,
      toSkill = 240,
      recipeName = "Superior Healing Potion",
      maxCrafts = 28,
    },
    {
      fromSkill = 240,
      toSkill = 250,
      recipeName = "Elixir of Greater Intellect",
      maxCrafts = 10,
    },
    {
      fromSkill = 250,
      toSkill = 270,
      recipeName = "Elixir of Detect Demon",
      maxCrafts = 20,
    },
    {
      fromSkill = 270,
      toSkill = 285,
      recipeName = "Elixir of the Sages",
      maxCrafts = 15,
    },
    {
      fromSkill = 285,
      toSkill = 295,
      recipeName = "Major Healing Potion",
      maxCrafts = 14,
    },
    {
      fromSkill = 295,
      toSkill = 300,
      recipeName = "Purification Potion",
      maxCrafts = 5,
    },
  },
})

if not ok then
  ns.Logger.Warn("Failed to register guide vanilla_jewelcrafting:", err)
end
