local Research = require("lib.research")

script.on_init(function()
  for name, recipe in pairs(data.raw.recipe) do
    local free_recipe = table.deepcopy(recipe)

    free_recipe.name =
        "journey-free-" .. name

    free_recipe.ingredients = {}
    free_recipe.enabled = false
    free_recipe.localised_name = "Free " .. free_recipe.localised_name

    data:extend({
      free_recipe
    })
  end
end)


commands.add_command(
  "journey_research",
  "Add research progress",
  function(command)
    local player =
        game.get_player(command.player_index)

    if not player then
      return
    end


    local item = command.parameter:match("^(%S+)")

    local amount =
        tonumber(
          command.parameter:match("%S+ (%d+)")
        )


    if not item or not amount then
      player.print(
        "Usage: /journey_research item amount"
      )
      return
    end


    Research.add_progress(
      player.force,
      item,
      amount
    )


    player.print(
      "Researched "
      .. item
      .. " +"
      .. amount
    )
  end
)


-- Chest handler


local function get_research_chests()
  storage.research_chests =
      storage.research_chests or {}

  return storage.research_chests
end


script.on_init(function()
  storage.research_chests = {}
end)


script.on_configuration_changed(function()
  storage.research_chests =
      storage.research_chests or {}
end)


script.on_event(
  defines.events.on_built_entity,
  function(event)
    local entity = event.entity

    if entity.name == "journey-research-chest" then
      local chests = get_research_chests()

      chests[entity.unit_number] = entity
    end
  end
)


script.on_event(
  defines.events.on_entity_died,
  function(event)
    local entity = event.entity

    if entity.name == "journey-research-chest" then
      local chests = get_research_chests()

      chests[entity.unit_number] = nil
    end
  end
)


script.on_nth_tick(
  60,
  function()
    local chests = get_research_chests()

    for id, chest in pairs(chests) do
      if not chest.valid then
        chests[id] = nil
      else
        local inventory =
            chest.get_inventory(
              defines.inventory.chest
            )


        if inventory then
          for _, item in pairs(
            inventory.get_contents()
          ) do
            local removed =
                inventory.remove({
                  name = item.name,
                  count = item.count
                })


            if removed > 0 then
              Research.add_progress(
                chest.force,
                item.name,
                removed
              )
            end
          end
        end
      end
    end
  end
)


-- GUI
local function create_journey_button(player)
  if player.gui.top.journey_button then
    return
  end

  player.gui.top.add({
    type = "button",
    name = "journey_button",
    caption = "Journey"
  })
end


script.on_event(
  defines.events.on_player_created,
  function(event)
    create_journey_button(
      game.get_player(event.player_index)
    )
  end
)


local function open_journey_gui(player)
  if player.gui.screen.journey_window then
    player.gui.screen.journey_window.destroy()
    return
  end


  local window =
      player.gui.screen.add({
        type = "frame",
        name = "journey_window",
        caption = "Journey Research",
        direction = "vertical"
      })


  window.auto_center = true


  local scroll =
      window.add({
        type = "scroll-pane",
        name = "journey_list"
      })


  scroll.style.maximal_height = 500


  local data =
      Research.get_force_data(player.force)


  for item, progress in pairs(data.progress) do
    local required =
        Research.get_required_count(item)


    scroll.add({
      type = "label",
      caption =
          item
          .. ": "
          .. progress
          .. " / "
          .. required
    })
  end


  window.add({
    type = "button",
    name = "journey_close",
    caption = "Close"
  })
end


script.on_event(
  defines.events.on_gui_click,
  function(event)
    local element = event.element

    if not element.valid then
      return
    end


    local player =
        game.get_player(event.player_index)


    if element.name == "journey_button" then
      open_journey_gui(player)
    elseif element.name == "journey_close" then
      if player.gui.screen.journey_window then
        player.gui.screen.journey_window.destroy()
      end
    end
  end
)
