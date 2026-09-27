local Research = {}

local BASE_REQUIREMENT = 10000
local FLUID_REQUIREMENT = 25000 -- One standard storage tank

function Research.print_unlocked(item)
  local icon = ""

  local found_icon, icon_tag = pcall(function()
    if prototypes.item[item] then
      return "[img=item/" .. item .. "] "
    elseif prototypes.fluid[item] then
      return "[img=fluid/" .. item .. "] "
    end
  end)

  if found_icon and icon_tag then
    icon = icon_tag
  end


  game.print(
    "[Journey] "
    .. icon
    .. item
    .. " unlocked"
  )
end


function Research.has_recipe(force, item)
  for name, recipe in pairs(force.recipes) do
    if string.sub(name, 1, 13) == "journey-free-" then
      for _, product in pairs(recipe.products or {}) do
        if product.name == item then
          return true
        end
      end
    end
  end

  return false
end


function Research.get_required_count(item_name)
  if prototypes.fluid[item_name] then
    return FLUID_REQUIREMENT
  end


  local cost_data =
      prototypes.mod_data["journey-cost-data"]


  local item =
      cost_data.data[item_name]


  if not item then
    return BASE_REQUIREMENT
  end


  return math.max(
    1,
    math.floor(
      BASE_REQUIREMENT / item.value
    )
  )
end

function Research.is_unlocked(force, item)
  for name, recipe in pairs(force.recipes) do
    if string.sub(name, 1, 13) == "journey-free-" then
      for _, product in pairs(recipe.products or {}) do
        if product.name == item then
          if recipe.enabled then
            return true
          end
        end
      end
    end
  end

  return false
end

function Research.get_force_data(force)
  storage.journey = storage.journey or {}

  storage.journey.forces =
      storage.journey.forces or {}


  storage.journey.forces[force.index] =
      storage.journey.forces[force.index] or {
        progress = {}
      }

  return storage.journey.forces[force.index]
end

function Research.unlock_item(force, item)
  for name, recipe in pairs(force.recipes) do
    if not recipe.enabled
        and string.sub(name, 1, 13) == "journey-free-"
    then
      for _, product in pairs(recipe.products or {}) do
        if product.name == item then
          recipe.enabled = true
          break
        end
      end
    end
  end


  -- local original =
  --     force.recipes[item]


  -- if original then
  --   original.enabled = false
  -- end
end

function Research.add_progress(force, item, amount)
  local data = Research.get_force_data(force)


  if Research.is_unlocked(force, item) then
    return
  end


  local required =
      Research.get_required_count(item)


  local previous_progress =
      data.progress[item] or 0

  data.progress[item] =
      math.min(previous_progress + amount, required)


  if data.progress[item] >= required then
    Research.unlock_item(force, item)

    if previous_progress < required then
      Research.print_unlocked(item)
    end
  end
end

return Research
