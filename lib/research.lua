local Research = {}

local BASE_REQUIREMENT = 10000

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

function Research.is_unlocked(force, recipe_name)
  local recipe = force.recipes["journey-free-" .. recipe_name]

  return recipe and recipe.enabled
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
  local recipe_name =
      "journey-free-" .. item


  local recipe =
      force.recipes[recipe_name]


  if recipe then
    recipe.enabled = true
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


  data.progress[item] =
      (data.progress[item] or 0)
      + amount


  local required =
      Research.get_required_count(item)


  if data.progress[item] >= required then
    Research.unlock_item(force, item)

    game.print(
      "[Journey] "
      .. item
      .. " unlocked"
    )
  end


  if chest and chest.valid then
    local inventory =
        chest.get_inventory(
          defines.inventory.chest
        )

    if inventory then
      inventory.remove({
        name = item,
        count = added
      })
    end
  end
end

return Research
