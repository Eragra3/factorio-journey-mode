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


  for _, force in pairs(game.forces) do
    local data = Research.get_force_data(force)

    for item, progress in pairs(data.progress) do
      if progress >= Research.get_required_count(item) then
        Research.unlock_item(force, item)
      end
    end
  end
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


local function get_journey_item_group(item)
  local found_group, group = pcall(function()
    local prototype = prototypes.item[item]
    local item_group = prototype and prototype.group

    if item_group then
      return {
        name = item_group.name,
        caption = item_group.localised_name or item_group.name,
        order = item_group.order or item_group.name
      }
    end
  end)

  if found_group and group then
    return group
  end

  return {
    name = "other",
    caption = "Other",
    order = "zzzz"
  }
end


local function get_journey_category_container_name(group_name, researched)
  local section =
      researched and "journey_researched_category_"
      or "journey_progress_category_"

  return section .. group_name
end


local function get_journey_category_groups(items)
  local groups_by_name = {}
  local groups = {}

  for _, item in ipairs(items) do
    local item_group = get_journey_item_group(item)
    local group = groups_by_name[item_group.name]

    if not group then
      group = {
        name = item_group.name,
        caption = item_group.caption,
        order = item_group.order,
        items = {}
      }

      groups_by_name[group.name] = group
      table.insert(groups, group)
    end

    table.insert(group.items, item)
  end

  table.sort(groups, function(left, right)
    if left.order == right.order then
      return left.name < right.name
    end

    return left.order < right.order
  end)

  return groups
end


local function update_journey_item_row(row, force, item, progress)
  local required =
      Research.get_required_count(item)

  local displayed_progress =
      math.max(0, math.min(progress, required))
  local researched =
      Research.is_unlocked(force, item)

  local details = row.journey_item_details
  local title_row = details.journey_item_title_row
  local progress_row = details.journey_progress_row
  local progress_bar = progress_row.journey_progress_bar

  title_row.journey_item_name.caption =
      get_journey_item_caption(item)

  title_row.journey_item_status.caption =
      researched and "Researched" or ""

  progress_bar.value = displayed_progress / required
  progress_bar.style.color = researched and {
    r = 0.25,
    g = 0.8,
    b = 0.35
  } or {
    r = 0.25,
    g = 0.6,
    b = 0.9
  }

  progress_row.journey_progress_count.caption =
      displayed_progress .. " / " .. required
end


local function get_journey_row_name(item, researched)
  local section =
      researched and "journey_researched_item_row_"
      or "journey_progress_item_row_"

  return section .. item
end


local function add_journey_item_row(scroll, force, item, progress, researched)
  local row =
      scroll.add({
        type = "flow",
        name = get_journey_row_name(item, researched),
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


  local title_row =
      details.add({
        type = "flow",
        name = "journey_item_title_row",
        direction = "horizontal"
      })

  title_row.add({
    type = "label",
    name = "journey_item_name"
  })

  local status =
      title_row.add({
        type = "label",
        name = "journey_item_status"
      })

  status.style.font_color = {
    r = 0.25,
    g = 0.8,
    b = 0.35
  }


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


  update_journey_item_row(row, force, item, progress)
end


local function add_journey_category_groups(
    scroll,
    groups,
    force,
    progress,
    researched,
    empty_message_name,
    empty_message
  )
  if #groups == 0 then
    scroll.add({
      type = "label",
      name = empty_message_name,
      caption = empty_message
    })

    return
  end


  for _, group in ipairs(groups) do
    local category =
        scroll.add({
          type = "flow",
          name = get_journey_category_container_name(
            group.name,
            researched
          ),
          direction = "vertical"
        })

    category.style.vertical_spacing = 4


    category.add({
      type = "label",
      name = "journey_category_header",
      caption = group.caption
    })


    for _, item in ipairs(group.items) do
      add_journey_item_row(
        category,
        force,
        item,
        progress[item],
        researched
      )
    end
  end
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
  local in_progress_items = {}
  local researched_items = {}

  for item in pairs(data.progress) do
    table.insert(items, item)
  end

  table.sort(items)


  for _, item in ipairs(items) do
    if Research.is_unlocked(player.force, item) then
      table.insert(researched_items, item)
    else
      table.insert(in_progress_items, item)
    end
  end


  local in_progress_groups =
      get_journey_category_groups(in_progress_items)
  local researched_groups =
      get_journey_category_groups(researched_items)


  local rebuild =
      not scroll.journey_in_progress_header
      or not scroll.journey_section_divider
      or not scroll.journey_researched_header
      or (#in_progress_groups == 0 and not scroll.journey_no_in_progress)
      or (#researched_groups == 0 and not scroll.journey_no_researched)

  local function has_category_rows(groups, researched)
    for _, group in ipairs(groups) do
      local category =
          scroll[get_journey_category_container_name(
            group.name,
            researched
          )]

      if not category then
        return false
      end


      for _, item in ipairs(group.items) do
        if not category[get_journey_row_name(item, researched)] then
          return false
        end
      end
    end


    return true
  end


  if not has_category_rows(in_progress_groups, false)
      or not has_category_rows(researched_groups, true)
  then
    rebuild = true
  end


  if rebuild then
    scroll.clear()

    scroll.add({
      type = "label",
      name = "journey_in_progress_header",
      caption = "In Progress"
    })

    add_journey_category_groups(
      scroll,
      in_progress_groups,
      player.force,
      data.progress,
      false,
      "journey_no_in_progress",
      "No items in progress."
    )


    scroll.add({
      type = "line",
      name = "journey_section_divider",
      direction = "horizontal"
    })


    scroll.add({
      type = "label",
      name = "journey_researched_header",
      caption = "Researched"
    })

    add_journey_category_groups(
      scroll,
      researched_groups,
      player.force,
      data.progress,
      true,
      "journey_no_researched",
      "No researched items yet."
    )
  else
    local function update_category_rows(groups, researched)
      for _, group in ipairs(groups) do
        local category =
            scroll[get_journey_category_container_name(
              group.name,
              researched
            )]

        for _, item in ipairs(group.items) do
          update_journey_item_row(
            category[get_journey_row_name(item, researched)],
            player.force,
            item,
            data.progress[item]
          )
        end
      end
    end


    update_category_rows(in_progress_groups, false)
    update_category_rows(researched_groups, true)
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
