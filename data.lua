-- function dump(o)
--    if type(o) == 'table' then
--       local s = '{ '
--       for k,v in pairs(o) do
--          if type(k) ~= 'number' then k = '"'..k..'"' end
--          s = s .. '['..k..'] = ' .. dump(v) .. ','
--       end
--       return s .. '} '
--    else
--       return tostring(o)
--    end
-- end

local researchChest = table.deepcopy(data.raw["logistic-container"]["active-provider-chest"])

researchChest.name = "journey-research-chest"
researchChest.minable.result = "journey-research-chest"
researchChest.inventory_size = 48
researchChest.animation.layers[1].tint = {
  r = 0,
  g = 1,
  b = 1,
  a = 0.3
}

local researchChestItem = table.deepcopy(data.raw["item"]["wooden-chest"])
local activeProviderChestItem = table.deepcopy(data.raw["item"]["active-provider-chest"])

researchChestItem.name = "journey-research-chest"
researchChestItem.icons = {
  {
    icon = activeProviderChestItem.icon,
    icon_size = activeProviderChestItem.icon_size,
    tint = { r = 0, g = 1, b = 1, a = 0.3 }
  },
}
researchChestItem.place_result = researchChest.name

local researchChestItemRecipe = {

  type = "recipe",
  name = "journey-research-chest",
  enabled = true,
  energy_required = 8, -- time to craft in seconds (at crafting speed 1)
  ingredients = {
    { type = "item", name = "copper-plate", amount = 1 }
  },
  results = { { type = "item", name = researchChestItem.name, amount = 1 } }
}

data:extend { researchChest, researchChestItem, researchChestItemRecipe }
