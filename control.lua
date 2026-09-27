local Research = require("lib.research")


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


commands.add_command(
  "journey_recheck",
  "Re-check research progress and unlock anything past threshold",
  function(command)
    local player =
        game.get_player(command.player_index)

    if not player then
      return
    end


    local data =
        Research.get_force_data(player.force)


    local unlocked_count = 0

    for item, progress in pairs(data.progress) do
      if not Research.is_unlocked(player.force, item) then
        local required =
            Research.get_required_count(item)


        if progress >= required then
          Research.unlock_item(player.force, item)

          unlocked_count = unlocked_count + 1

          Research.print_unlocked(item)
        end
      end
    end


    player.print(
      "Journey recheck complete. Unlocked "
      .. unlocked_count
      .. " item(s)."
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


local refresh_open_journey_guis


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
            if not Research.is_unlocked(chest.force, item.name) then
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


    refresh_open_journey_guis()
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


local function get_journey_item_caption(item)
  local found_prototype, caption = pcall(function()
    local prototype = prototypes.item[item]

    return prototype and prototype.localised_name
  end)

  if found_prototype and caption then
    return caption
  end

  return item
end


local function update_journey_item_row(row, item, progress)
  local required =
      Research.get_required_count(item)

  local displayed_progress =
      math.max(0, math.min(progress, required))

  local details = row.journey_item_details
  local progress_row = details.journey_progress_row

  details.journey_item_name.caption =
      get_journey_item_caption(item)

  progress_row.journey_progress_bar.value =
      displayed_progress / required

  progress_row.journey_progress_count.caption =
      displayed_progress .. " / " .. required
end


local function add_journey_item_row(scroll, item, progress)
  local row =
      scroll.add({
        type = "flow",
        name = "journey_item_row_" .. item,
        direction = "horizontal"
      })

  row.style.horizontal_spacing = 8
  row.style.bottom_padding = 6


  local icon_added = pcall(function()
    row.add({
      type = "sprite",
      name = "journey_item_icon",
      sprite = "item/" .. item,
      tooltip = item
    })
  end)


  if not icon_added then
    row.add({
      type = "label",
      caption = "?",
      tooltip = "No icon available for " .. item
    })
  end


  local details =
      row.add({
        type = "flow",
        name = "journey_item_details",
        direction = "vertical"
      })

  details.style.horizontally_stretchable = true
  details.style.vertical_spacing = 4


  details.add({
    type = "label",
    name = "journey_item_name"
  })


  local progress_row =
      details.add({
        type = "flow",
        name = "journey_progress_row",
        direction = "horizontal"
      })

  progress_row.style.horizontal_spacing = 8


  local progress_bar =
      progress_row.add({
        type = "progressbar",
        name = "journey_progress_bar"
      })

  progress_bar.style.width = 250


  progress_row.add({
    type = "label",
    name = "journey_progress_count"
  })


  update_journey_item_row(row, item, progress)
end


local function update_journey_gui(player)
  local window = player.gui.screen.journey_window

  if not window then
    return
  end


  local scroll = window.journey_list
  local data =
      Research.get_force_data(player.force)

  local items = {}

  for item in pairs(data.progress) do
    table.insert(items, item)
  end

  table.sort(items)


  local rebuild =
      #items == 0 and not scroll.journey_empty_message

  for _, item in ipairs(items) do
    if not scroll["journey_item_row_" .. item] then
      rebuild = true
      break
    end
  end


  if rebuild then
    scroll.clear()

    if #items == 0 then
      scroll.add({
        type = "label",
        name = "journey_empty_message",
        caption = "No item progress yet."
      })
    else
      for _, item in ipairs(items) do
        add_journey_item_row(
          scroll,
          item,
          data.progress[item]
        )
      end
    end
  else
    for _, item in ipairs(items) do
      update_journey_item_row(
        scroll["journey_item_row_" .. item],
        item,
        data.progress[item]
      )
    end
  end
end


refresh_open_journey_guis = function()
  for _, player in pairs(game.connected_players) do
    if player.gui.screen.journey_window then
      update_journey_gui(player)
    end
  end
end


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
  window.style.width = 460


  window.add({
    type = "label",
    caption = "Track item unlock progress"
  })


  local scroll =
      window.add({
        type = "scroll-pane",
        name = "journey_list"
      })


  scroll.style.maximal_height = 500
  scroll.style.width = 430


  window.add({
    type = "button",
    name = "journey_close",
    caption = "Close"
  })


  update_journey_gui(player)
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
