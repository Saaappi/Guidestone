local Addon = _G.Guidestone
local Guides = Addon.modules.Guides
local Logger = Addon.modules.Logger

local ok, err = Guides:RegisterGuide({
  id = "classic_herbalism",
  title = "Classic Herbalism 1-300",
  expansionKey = "VANILLA",
  professionKey = "HERBALISM",
  professionName = "Herbalism",

  skillLineID = 2556,

  guideUrl = "https://www.wow-professions.com/guides/vanilla-herbalism-leveling",

  trainers = {
    { npcId = 46741, name = "Muraga", uiMapID = 85, x = 54.26, y = 50.97, faction = 2 },
  },

  steps = {
    {
      fromSkill = 1,
      toSkill = 70,
      gathering = { 2447, 765, 2449 },
      images = {
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\elwynn-forest-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
          faction = 1,
        },
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\tirisfal-glades-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
          faction = 2,
        },
      },
    },
    {
      fromSkill = 70,
      toSkill = 115,
      gathering = { 785, 2450, 2453 },
      images = {
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\darkshore-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
          faction = 1,
        },
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\hillsbrad-foothills-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
          faction = 2,
        },
      },
    },
    {
      fromSkill = 115,
      toSkill = 185,
      gathering = { 3356, 3818, 3358, {3821, 69} },
      images = {
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\western-plaguelands-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
        },
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\feralas-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
        },
      },
    },
    {
      fromSkill = 185,
      toSkill = 255,
      gathering = { 8838, 3358 },
      images = {
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\thousand-needles-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
        },
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\eastern-plaguelands-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
        },
      },
    },
    {
      fromSkill = 255,
      toSkill = 300,
      gathering = { {13464, 51}, {13466, 51}, {8846, 77}, {8831, 77}, {13463, 77} },
      images = {
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\swamp-of-sorrows-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
        },
        {
          texture = "Interface\\AddOns\\Guidestone\\Media\\Routes\\Classic\\Herbalism\\felwood-herbalism.jpg",
          caption = "courtesy of WoW-Professions.com",
          width = 550,
          height = 367,
        },
      },
    },
  },
})

if not ok then
  Logger.Warn("Failed to register guide classic_herbalism:", err)
end