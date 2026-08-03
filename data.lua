local researchChest = table.deepcopy(data.raw["item"]["wooden-chest"])
local activeProviderChest = table.deepcopy(data.raw["logistic-container"]["active-provider-chest"])

researchChest.name = "journey-research-chest"
researchChest.icons = {
  {
    icon = activeProviderChest.icon,
    icon_size = activeProviderChest.icon_size,
    tint = { r = 0, g = 1, b = 1, a = 0.3 },
    place_result = activeProviderChest.name,
  },
}

local researchChestRecipe = {

  type = "recipe",
  name = "journey-research-chest",
  enabled = true,
  energy_required = 8, -- time to craft in seconds (at crafting speed 1)
  ingredients = {
    { type = "item", name = "copper-plate", amount = 1 }
  },
  results = { { type = "item", name = researchChest.name, amount = 1 } }
}

data:extend { researchChest, researchChestRecipe }
