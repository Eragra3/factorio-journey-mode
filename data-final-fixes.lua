local raw_cache = {}
local resolving = {}
local chosen_recipes = {}

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
-- Recipe helpers and index
--------------------------------------------------

local function get_recipe_ingredients(recipe)
  if recipe.ingredients then
    return recipe.ingredients
  end

  if recipe.normal and recipe.normal.ingredients then
    return recipe.normal.ingredients
  end

  if recipe.expensive and recipe.expensive.ingredients then
    return recipe.expensive.ingredients
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

  if recipe.expensive and recipe.expensive.results then
    return recipe.expensive.results
  end

  local result_name =
      recipe.result
      or (recipe.normal and recipe.normal.result)
      or (recipe.expensive and recipe.expensive.result)

  if result_name then
    return {
      {
        type = "item",
        name = result_name,
        amount = recipe.result_count
            or (recipe.normal and recipe.normal.result_count)
            or (recipe.expensive and recipe.expensive.result_count)
            or 1
      }
    }
  end

  return {}
end


for _, recipe in pairs(data.raw.recipe) do
  if not string.find(recipe.name, "journey") then
    for _, result in pairs(get_recipe_results(recipe)) do
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
      if result.amount then
        return result.amount
      end

      if result.amount_min and result.amount_max then
        return (result.amount_min + result.amount_max) / 2
      end

      return 1
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
    elseif item == "water" then
      multiplier = 0.1
    elseif item == "steam" then
      multiplier = 0.2
    end

    value = value + amount * multiplier
  end

  return value
end


local function get_recipe_energy(recipe)
  return recipe.energy_required
      or (recipe.normal and recipe.normal.energy_required)
      or (recipe.expensive and recipe.expensive.energy_required)
      or 0.5
end


local function get_recipe_categories(recipe)
  if recipe.categories then
    return recipe.categories
  end

  return { recipe.category or "crafting" }
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
    chosen_recipes[item_name] = nil
    resolving[item_name] = nil

    return result
  end


  local best_cost = nil
  local best_value = math.huge
  local best_recipe = nil


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
      best_recipe = recipe
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
  chosen_recipes[item_name] = best_recipe

  return best_cost
end


--------------------------------------------------
-- Calculate material, time, and structure requirements
--------------------------------------------------

local item_prototypes = {}


for _, prototypes in pairs(data.raw) do
  if type(prototypes) == "table" then
    for item_name, prototype in pairs(prototypes) do
      if type(prototype) == "table"
          and prototype.stack_size ~= nil
      then
        item_prototypes[item_name] = prototype
      end
    end
  end
end


local material_values = {}
local machine_items = {}

for item_name, prototype in pairs(item_prototypes) do
  local raw = calculate_raw(item_name)
  material_values[item_name] = cost_value(raw)

  if prototype.place_result then
    local previous = machine_items[prototype.place_result]

    if not previous or material_values[item_name] < previous then
      machine_items[prototype.place_result] = material_values[item_name]
    end
  end
end


for fluid_name in pairs(data.raw.fluid) do
  local raw = calculate_raw(fluid_name)
  material_values[fluid_name] = cost_value(raw)
end


local machine_cost_by_category = {
  crafting = 0
}

for _, prototypes in pairs(data.raw) do
  if type(prototypes) == "table" then
    for entity_name, machine in pairs(prototypes) do
      if type(machine) == "table" and machine.crafting_categories then
        local machine_cost = machine_items[entity_name]

        if machine_cost then
          for _, category in pairs(machine.crafting_categories) do
            local previous = machine_cost_by_category[category]

            if not previous or machine_cost < previous then
              machine_cost_by_category[category] = machine_cost
            end
          end
        end
      end
    end
  end
end


local function get_structure_cost(recipe)
  local best_cost = math.huge

  for _, category in pairs(get_recipe_categories(recipe)) do
    local cost = machine_cost_by_category[category]

    if cost and cost < best_cost then
      best_cost = cost
    end
  end

  if best_cost == math.huge then
    return 0
  end

  return best_cost
end


local structure_cost_cache = {}
local structure_cost_resolving = {}

local function calculate_structure_cost(item_name)
  if structure_cost_cache[item_name] ~= nil then
    return structure_cost_cache[item_name]
  end


  if structure_cost_resolving[item_name] then
    return 0
  end


  local recipe = chosen_recipes[item_name]

  if not recipe then
    structure_cost_cache[item_name] = 0
    return 0
  end


  structure_cost_resolving[item_name] = true

  local output = math.max(0.001, get_output_amount(recipe, item_name))
  local cost = get_structure_cost(recipe)

  for _, ingredient in pairs(get_recipe_ingredients(recipe)) do
    cost = cost
        + ingredient.amount / output
        * calculate_structure_cost(ingredient.name)
  end


  structure_cost_resolving[item_name] = nil
  structure_cost_cache[item_name] = cost

  return cost
end


local crafting_time_cache = {}
local crafting_time_resolving = {}

local function calculate_crafting_time(item_name)
  if crafting_time_cache[item_name] ~= nil then
    return crafting_time_cache[item_name]
  end


  if crafting_time_resolving[item_name] then
    return 0
  end


  local recipe = chosen_recipes[item_name]

  if not recipe then
    crafting_time_cache[item_name] = 0
    return 0
  end


  crafting_time_resolving[item_name] = true

  local output = math.max(0.001, get_output_amount(recipe, item_name))
  local time = get_recipe_energy(recipe) / output

  for _, ingredient in pairs(get_recipe_ingredients(recipe)) do
    time = time
        + ingredient.amount / output
        * calculate_crafting_time(ingredient.name)
  end


  crafting_time_resolving[item_name] = nil
  crafting_time_cache[item_name] = time

  return time
end


local function get_raw_amount(raw)
  local amount = 0

  for _, count in pairs(raw) do
    amount = amount + count
  end

  return amount
end


local function calculate_item_cost(item_name)
  local raw = calculate_raw(item_name)
  local material_value = cost_value(raw)
  local recipe = chosen_recipes[item_name]

  if not recipe then
    return {
      value = material_value,
      complexity = 1,
      raw = raw,
      ingredient_amount = get_raw_amount(raw),
      crafting_time = 0,
      structure_cost = 0
    }
  end


  local ingredient_amount =
      get_raw_amount(raw)
  local crafting_time =
      calculate_crafting_time(item_name)
  local structure_cost =
      calculate_structure_cost(item_name)

  local score =
      material_value
      + ingredient_amount * 0.05
      + crafting_time * 0.25
      + structure_cost * 0.1

  local complexity =
      math.max(
        1,
        math.log(1 + score) / math.log(2)
      )


  return {
    value = material_value,
    complexity = complexity,
    raw = raw,
    ingredient_amount = ingredient_amount,
    crafting_time = crafting_time,
    structure_cost = structure_cost
  }
end


local journey_costs = {}

for item_name in pairs(item_prototypes) do
  journey_costs[item_name] =
      calculate_item_cost(item_name)
end


for fluid_name in pairs(data.raw.fluid) do
  journey_costs[fluid_name] =
      calculate_item_cost(fluid_name)
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
