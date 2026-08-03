local raw_cache = {}
local resolving = {}

local recipes_by_result = {}


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
