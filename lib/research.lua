local Research = {}

local BASE_REQUIREMENT = 10000

function Research.print_unlocked(item)
  local icon = ""

  local found_icon, icon_tag = pcall(function()
    if prototypes.item[item] then
      return "[img=item/" .. item .. "] "
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

function Research.get_required_count(item_name)
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
      for _, product in pairs(recipe.products) do
        if product.name == item then
          return recipe.enabled
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
      for _, product in pairs(recipe.products) do
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


  data.progress[item] =
      math.min(
        (data.progress[item] or 0)
        + amount,
        required
      )


  if data.progress[item] >= required then
    Research.unlock_item(force, item)

    Research.print_unlocked(item)
  end
end

return Research
