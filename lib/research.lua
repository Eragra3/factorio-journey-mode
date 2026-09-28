local Research = {}

local BASE_REQUIREMENT = 10000
local FLUID_REQUIREMENT = 25000 -- One standard storage tank
local DIFFICULTY_MULTIPLIERS = {
  Fast = 0.5,
  Regular = 1,
  Chore = 3,
  Endgame = 10
}

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
        progress = {},
        difficulty = "Regular"
      }

  local force_data = storage.journey.forces[force.index]
  force_data.progress = force_data.progress or {}
  force_data.difficulty = force_data.difficulty or "Regular"

  return force_data
end


function Research.get_difficulty(force)
  local difficulty =
      Research.get_force_data(force).difficulty

  return difficulty, DIFFICULTY_MULTIPLIERS[difficulty] or 1
end


function Research.set_difficulty(force, requested_difficulty)
  local requested =
      string.lower(requested_difficulty or "")

  for difficulty, multiplier in pairs(DIFFICULTY_MULTIPLIERS) do
    if string.lower(difficulty) == requested then
      Research.get_force_data(force).difficulty = difficulty
      return true, difficulty, multiplier
    end
  end

  return false
end


function Research.get_required_count(item_name, force)
  local cost_data =
      prototypes.mod_data["journey-cost-data"]

  local item =
      cost_data.data[item_name]

  local base_requirement =
      prototypes.fluid[item_name]
      and FLUID_REQUIREMENT
      or BASE_REQUIREMENT

  local work_per_item =
      item and item.work_per_item or 1

  local difficulty_multiplier = 1

  if force then
    local _, multiplier = Research.get_difficulty(force)
    difficulty_multiplier = multiplier
  end

  return math.max(
    1,
    math.floor(
      base_requirement
      / work_per_item
      * difficulty_multiplier
    )
  )
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
      Research.get_required_count(item, force)


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
