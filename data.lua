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

local function get_item_prototype(item_name)
  if data.raw.item and data.raw.item[item_name] then
    return data.raw.item[item_name]
  end

  for _, prototypes in pairs(data.raw) do
    if type(prototypes) == "table" then
      local prototype = prototypes[item_name]
      if prototype and prototype.stack_size ~= nil then
        return prototype
      end
    end
  end
end

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


local researchFluidTank =
    table.deepcopy(
      data.raw["storage-tank"]["storage-tank"]
    )

researchFluidTank.name = "journey-research-fluid-tank"
researchFluidTank.minable.result = "journey-research-fluid-tank"


local storageTankItem = get_item_prototype("storage-tank")
local researchFluidTankItem = table.deepcopy(storageTankItem)

researchFluidTankItem.name = "journey-research-fluid-tank"
researchFluidTankItem.place_result = researchFluidTank.name

if researchFluidTankItem.icons then
  for _, layer in pairs(researchFluidTankItem.icons) do
    layer.tint = { r = 0, g = 1, b = 1, a = 0.3 }
  end

  researchFluidTankItem.icon = nil
  researchFluidTankItem.icon_size = nil
elseif researchFluidTankItem.icon then
  researchFluidTankItem.icons = {
    {
      icon = researchFluidTankItem.icon,
      icon_size = researchFluidTankItem.icon_size or 64,
      tint = { r = 0, g = 1, b = 1, a = 0.3 }
    }
  }

  researchFluidTankItem.icon = nil
  researchFluidTankItem.icon_size = nil
end


local researchFluidTankItemRecipe = {
  type = "recipe",
  name = "journey-research-fluid-tank",
  enabled = true,
  energy_required = 8,
  ingredients = {
    { type = "item", name = "copper-plate", amount = 1 }
  },
  results = {
    { type = "item", name = researchFluidTankItem.name, amount = 1 }
  }
}

data:extend {
  researchFluidTank,
  researchFluidTankItem,
  researchFluidTankItemRecipe
}

-- FREE RECIPIES

local FREE_RECIPE_TINT = { r = 0, g = 1, b = 1, a = 0.6 }

local function get_recipe_icons(recipe)
  if recipe.icons then
    return table.deepcopy(recipe.icons)
  end

  if recipe.icon then
    return {
      { icon = recipe.icon, icon_size = recipe.icon_size or 64 }
    }
  end

  -- No icon on the recipe itself: fall back to its main result's icon,
  -- same as the game does by default when a recipe has none.
  local results =
      recipe.results
      or (recipe.normal and recipe.normal.results)
      or (recipe.expensive and recipe.expensive.results)

  local result = results and results[1]


  if not result then
    local result_name =
        recipe.result
        or (recipe.normal and recipe.normal.result)
        or (recipe.expensive and recipe.expensive.result)

    if result_name then
      result = {
        type = "item",
        name = result_name
      }
    else
      return nil
    end
  end

  local result_type = result.type or "item"
  local proto = data.raw[result_type] and data.raw[result_type][result.name]

  if not proto and result_type == "item" then
    proto = get_item_prototype(result.name)
  end

  if not proto then
    return nil
  end

  if proto.icons then
    return table.deepcopy(proto.icons)
  elseif proto.icon then
    return {
      { icon = proto.icon, icon_size = proto.icon_size or 64 }
    }
  end

  return nil
end

local recipe_names = {}

for name in pairs(data.raw.recipe) do
  table.insert(recipe_names, name)
end

for _, name in pairs(recipe_names) do
  local recipe = data.raw.recipe[name]
  local free_recipe = table.deepcopy(recipe)

  free_recipe.name =
      "journey-free-" .. name

  free_recipe.ingredients = {}
  free_recipe.enabled = false
  free_recipe.allow_as_intermediate = true
  free_recipe.allow_intermediates = true
  free_recipe.order = "0[free]-" .. (recipe.order or name)
  free_recipe.localised_name =
      { "", "Free ", free_recipe.localised_name or name }

  local icons = get_recipe_icons(recipe)

  if icons then
    for _, layer in pairs(icons) do
      layer.tint = FREE_RECIPE_TINT
    end

    free_recipe.icons = icons
    free_recipe.icon = nil
    free_recipe.icon_size = nil
  end

  data:extend({
    free_recipe
  })
end
