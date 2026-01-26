-- Commit: feat: add Vanilla Alchemy leveling guide (1-300)
local _, ns = ...

local ok, err = ns.Guides:RegisterGuide({
  id = "vanilla_alchemy",
  title = "Vanilla Alchemy 1-300",
  expansionKey = "VANILLA",
  professionKey = "ALCHEMY",
  professionName = "Alchemy",

  -- Vanilla Alchemy (Retail) child skill line ID
  skillLineID = 2485,

  guideUrl = "https://www.wow-professions.com/guides/vanilla-alchemy-leveling",

  materials = {
    { itemID = 2447,  required = 60,  wowProfessionsUrl = "https://www.wow-professions.com/farming/peacebloom-silverleaf-farming" }, -- Peacebloom
    { itemID = 765,   required = 60,  wowProfessionsUrl = "https://www.wow-professions.com/farming/peacebloom-silverleaf-farming" }, -- Silverleaf
    { itemID = 2450,  required = 105, wowProfessionsUrl = "https://www.wow-professions.com/farming/briarthorn-farming" },            -- Briarthorn
    { itemID = 785,   required = 30,  wowProfessionsUrl = "https://www.wow-professions.com/farming/mageroyal-farming" },             -- Mageroyal
    { itemID = 2453,  required = 35,  wowProfessionsUrl = "https://www.wow-professions.com/farming/bruiseweed-farming" },            -- Bruiseweed
    { itemID = 3820,  required = 50,  wowProfessionsUrl = "https://www.wow-professions.com/farming/stranglekelp-farming" },          -- Stranglekelp
    { itemID = 3357,  required = 20,  wowProfessionsUrl = "https://www.wow-professions.com/farming/liferoot-farming" },              -- Liferoot
    { itemID = 3356,  required = 30,  wowProfessionsUrl = "https://www.wow-professions.com/farming/kingsblood-farming" },            -- Kingsblood
    { itemID = 3821,  required = 30,  wowProfessionsUrl = "https://www.wow-professions.com/farming/goldthorn-farming" },             -- Goldthorn
    { itemID = 3355,  required = 10,  wowProfessionsUrl = "https://www.wow-professions.com/farming/wild-steelbloom-farming" },       -- Wild Steelbloom
    { itemID = 8838,  required = 30,  wowProfessionsUrl = "https://www.wow-professions.com/farming/sungrass-farming" },              -- Sungrass
    { itemID = 3358,  required = 40,  wowProfessionsUrl = "https://www.wow-professions.com/farming/khadgars-whisker-farming" },      -- Khadgar's Whisker
    { itemID = 8839,  required = 10,  wowProfessionsUrl = "https://www.wow-professions.com/farming/blindweed-farming" },             -- Blindweed
    { itemID = 8846,  required = 40,  wowProfessionsUrl = "https://www.wow-professions.com/farming/gromsblood-farming" },            -- Gromsblood
    { itemID = 13466, required = 40,  wowProfessionsUrl = "https://www.wow-professions.com/farming/sorrowmoss-farming" },            -- Sorrowmoss
    { itemID = 13463, required = 15,  wowProfessionsUrl = "https://www.wow-professions.com/farming/dreamfoil-farming" },             -- Dreamfoil
    { itemID = 13464, required = 28,  wowProfessionsUrl = "https://www.wow-professions.com/farming/golden-sansam-farming" },         -- Golden Sansam
    { itemID = 13465, required = 14,  wowProfessionsUrl = "https://www.wow-professions.com/farming/mountain-silversage-farming" },   -- Mountain Silversage
    { itemID = 13467, required = 10,  wowProfessionsUrl = "https://www.wow-professions.com/farming/icecap-farming" },                -- Icecap
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
  ns.Logger.Warn("Failed to register guide vanilla_alchemy:", err)
end
