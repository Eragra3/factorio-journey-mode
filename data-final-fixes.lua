local raw_cache = {}
local resolving = {}

local recipes_by_result = {}


--------------------------------------------------
-- Keep ingredient-free recipes out of furnaces
--------------------------------------------------

local furnace_categories = {}

for _, furnace in pairs(data.raw.furnace or {}) do
  for _, category in pairs(furnace.crafting_categories or {}) do
    furnace_categories[category] = true
  end
end


for name, recipe in pairs(data.raw.recipe) do
  if string.sub(name, 1, 13) == "journey-free-"
      and furnace_categories[recipe.category]
  then
    -- Furnaces select recipes from their ingredients. The free clone has no
    -- ingredients, so leave the original recipe available for normal smelting.
    recipe.category = "crafting"
  end
end


--------------------------------------------------
-- Build recipe index
--------------------------------------------------

for _, recipe in pairs(data.raw.recipe) do
  if not string.find(recipe.name, "journey") and recipe.results then
    for _, result in pairs(recipe.results) do
      recipes_by_result[result.name] =
          recipes_by_result[result.name] or {}

      table.insert(
        recipes_by_result[result.name],
        recipe
      )
    end
  end
end


--------------------------------------------------
-- Helpers
--------------------------------------------------

local function get_recipe_ingredients(recipe)
  if recipe.ingredients then
    return recipe.ingredients
  end

  if recipe.normal and recipe.normal.ingredients then
    return recipe.normal.ingredients
  end

  return {}
end


local function get_recipe_results(recipe)
  if recipe.results then
    return recipe.results
  end

  if recipe.normal and recipe.normal.results then
    return recipe.normal.results
  end

  return {}
end


--------------------------------------------------
-- Give items without recipes a free crafting recipe
--------------------------------------------------

local items_with_free_recipes = {}
local fluids_with_free_recipes = {}

local function mark_free_recipe_products(recipe)
  local result_sets = {
    recipe.results,
    recipe.normal and recipe.normal.results,
    recipe.expensive and recipe.expensive.results
  }

  for _, results in pairs(result_sets) do
    for _, result in pairs(results or {}) do
      local product_type = result.type or "item"

      if product_type == "item" then
        items_with_free_recipes[result.name] = true
      elseif product_type == "fluid" then
        fluids_with_free_recipes[result.name] = true
      end
    end
  end


  local singular_results = {
    recipe.result,
    recipe.normal and recipe.normal.result,
    recipe.expensive and recipe.expensive.result
  }

  for _, result in pairs(singular_results) do
    if result then
      items_with_free_recipes[result] = true
    end
  end
end


for name, recipe in pairs(data.raw.recipe) do
  if string.sub(name, 1, 13) == "journey-free-" then
    mark_free_recipe_products(recipe)
  end
end


for item_name, item in pairs(data.raw.item) do
  if not items_with_free_recipes[item_name] then
    local recipe_name = "journey-free-item-" .. item_name

    while data.raw.recipe[recipe_name] do
      recipe_name = recipe_name .. "-fallback"
    end


    local free_recipe = {
      type = "recipe",
      name = recipe_name,
      category = "crafting",
      enabled = false,
      ingredients = {},
      results = {
        { type = "item", name = item_name, amount = 1 }
      },
      localised_name = {
        "",
        "Free ",
        item.localised_name or item_name
      }
    }


    local icons = nil

    if item.icons then
      icons = table.deepcopy(item.icons)
    elseif item.icon then
      icons = {
        {
          icon = item.icon,
          icon_size = item.icon_size or 64
        }
      }
    end


    if icons then
      for _, layer in pairs(icons) do
        layer.tint = { r = 0, g = 1, b = 1, a = 0.6 }
      end

      free_recipe.icons = icons
    end


    data:extend({ free_recipe })
    items_with_free_recipes[item_name] = true
  end
end


--------------------------------------------------
-- Give fluids without recipes a free refinery recipe
--------------------------------------------------

for fluid_name, fluid in pairs(data.raw.fluid) do
  if not fluids_with_free_recipes[fluid_name] then
    local recipe_name = "journey-free-fluid-" .. fluid_name

    while data.raw.recipe[recipe_name] do
      recipe_name = recipe_name .. "-fallback"
    end


    local free_recipe = {
      type = "recipe",
      name = recipe_name,
      category = "oil-processing",
      subgroup = "fluid-recipes",
      order = "0[free-fluid]-" .. (fluid.order or fluid_name),
      enabled = false,
      energy_required = 1,
      allow_as_intermediate = true,
      ingredients = {},
      results = {
        { type = "fluid", name = fluid_name, amount = 100 }
      },
      localised_name = {
        "",
        "Free ",
        fluid.localised_name or fluid_name
      }
    }


    local icons = nil

    if fluid.icons then
      icons = table.deepcopy(fluid.icons)
    elseif fluid.icon then
      icons = {
        {
          icon = fluid.icon,
          icon_size = fluid.icon_size or 64
        }
      }
    end


    if icons then
      for _, layer in pairs(icons) do
        layer.tint = { r = 0, g = 1, b = 1, a = 0.6 }
      end

      free_recipe.icons = icons
    end


    data:extend({ free_recipe })
    fluids_with_free_recipes[fluid_name] = true
  end
end


local function get_output_amount(recipe, item_name)
  for _, result in pairs(get_recipe_results(recipe)) do
    if result.name == item_name then
      return result.amount or 1
    end
  end

  return 1
end


local function add_cost(target, source, multiplier)
  for item, amount in pairs(source) do
    target[item] =
        (target[item] or 0)
        + amount * multiplier
  end
end


local function cost_value(cost)
  local value = 0

  for item, amount in pairs(cost) do
    local multiplier = 1

    if item == "uranium-ore" then
      multiplier = 10
    elseif item == "crude-oil" then
      multiplier = 2
    end

    value = value + amount * multiplier
  end

  return value
end


--------------------------------------------------
-- Recursive raw calculator
--------------------------------------------------

local function calculate_raw(item_name)
  if raw_cache[item_name] then
    return raw_cache[item_name]
  end


  -- Prevent infinite loops
  if resolving[item_name] then
    log(
      "Recipe cycle detected: "
      .. item_name
    )

    return {
      [item_name] = 1
    }
  end


  resolving[item_name] = true


  local recipes =
      recipes_by_result[item_name]


  -- No recipe = raw resource
  if not recipes then
    local result = {
      [item_name] = 1
    }

    raw_cache[item_name] = result
    resolving[item_name] = nil

    return result
  end


  local best_cost = nil
  local best_value = math.huge


  for _, recipe in pairs(recipes) do
    local output =
        get_output_amount(
          recipe,
          item_name
        )


    local current = {}


    for _, ingredient in pairs(
      get_recipe_ingredients(recipe)
    ) do
      local ingredient_cost =
          calculate_raw(
            ingredient.name
          )


      add_cost(
        current,
        ingredient_cost,
        ingredient.amount / output
      )
    end


    local value =
        cost_value(current)


    if value < best_value then
      best_value = value
      best_cost = current
    end
  end


  resolving[item_name] = nil


  -- Fallback for broken recipes
  if not best_cost then
    best_cost = {
      [item_name] = 1
    }
  end


  raw_cache[item_name] = best_cost

  return best_cost
end


--------------------------------------------------
-- Calculate all items
--------------------------------------------------

local journey_costs = {}


for item_name in pairs(data.raw.item) do
  local raw =
      calculate_raw(item_name)


  journey_costs[item_name] = {
    value = cost_value(raw),
    raw = raw
  }
end


--------------------------------------------------
-- Export
--------------------------------------------------

data:extend({
  {
    type = "mod-data",
    name = "journey-cost-data",
    data = journey_costs
  }
})
