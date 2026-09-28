local Research = require("lib.research")


commands.add_command(
  "journey_research",
  "Add research progress. Parameters: <item-or-fluid> <integer-amount>",
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
        "Usage: /journey_research <item-or-fluid> <integer-amount>"
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
  "journey_difficulty",
  "Show current difficulty or set it with [Fast|Regular|Chore|Endgame]",
  function(command)
    local player =
        game.get_player(command.player_index)

    if not player then
      return
    end


    local requested =
        command.parameter
        and command.parameter:match("^%s*(%S+)")

    if not requested then
      local difficulty, multiplier =
          Research.get_difficulty(player.force)

      player.print(
        "Journey difficulty: "
        .. difficulty
        .. " (x"
        .. multiplier
        .. "). Usage: /journey_difficulty [Fast|Regular|Chore|Endgame]"
      )

      return
    end


    local changed, difficulty, multiplier =
        Research.set_difficulty(player.force, requested)

    if not changed then
      player.print(
        "Usage: /journey_difficulty [Fast|Regular|Chore|Endgame]"
      )

      return
    end


    local data =
        Research.get_force_data(player.force)

    for item, progress in pairs(data.progress) do
      if not Research.is_unlocked(player.force, item)
          and progress >= Research.get_required_count(item, player.force)
      then
        Research.unlock_item(player.force, item)
        Research.print_unlocked(item)
      end
    end


    player.print(
      "Journey difficulty set to "
      .. difficulty
      .. " (x"
      .. multiplier
      .. ")."
    )
  end
)


commands.add_command(
  "journey_recheck",
  "Re-check stored progress and unlock completed items. No parameters.",
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
            Research.get_required_count(item, player.force)


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


local function get_research_fluid_tanks()
  storage.research_fluid_tanks =
      storage.research_fluid_tanks or {}

  return storage.research_fluid_tanks
end


script.on_init(function()
  storage.research_chests = {}
  storage.research_fluid_tanks = {}
end)


script.on_configuration_changed(function()
  storage.research_chests =
      storage.research_chests or {}
  storage.research_fluid_tanks =
      storage.research_fluid_tanks or {}


  for _, force in pairs(game.forces) do
    local data = Research.get_force_data(force)

    for item, progress in pairs(data.progress) do
      if progress >= Research.get_required_count(item, force) then
        Research.unlock_item(force, item)
      end
    end
  end
end)


script.on_event(
  {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity
  },
  function(event)
    local entity = event.entity

    if entity.name == "journey-research-chest" then
      local chests = get_research_chests()

      chests[entity.unit_number] = entity
    elseif entity.name == "journey-research-fluid-tank" then
      local tanks = get_research_fluid_tanks()

      tanks[entity.unit_number] = entity
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
    elseif entity.name == "journey-research-fluid-tank" then
      local tanks = get_research_fluid_tanks()

      tanks[entity.unit_number] = nil
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


    local tanks = get_research_fluid_tanks()

    for id, tank in pairs(tanks) do
      if not tank.valid then
        tanks[id] = nil
      else
        local fluid = tank.fluidbox[1]

        if fluid
            and fluid.amount > 0
            and Research.has_recipe(tank.force, fluid.name)
            and not Research.is_unlocked(tank.force, fluid.name)
        then
          local removed =
              tank.remove_fluid({
                name = fluid.name,
                amount = fluid.amount
              })

          if removed > 0 then
            Research.add_progress(
              tank.force,
              fluid.name,
              removed
            )
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
    local prototype =
        prototypes.item[item]
        or prototypes.fluid[item]

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


    if prototypes.fluid[item] then
      return {
        name = "fluids",
        caption = "Fluids",
        order = "zz-fluids"
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


local function get_journey_icon_sprite(item)
  local found_icon, sprite = pcall(function()
    if prototypes.item[item] then
      return "item/" .. item
    elseif prototypes.fluid[item] then
      return "fluid/" .. item
    end
  end)

  if found_icon then
    return sprite
  end

  return nil
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


local function get_journey_items(force, force_data)
  local progress = {}
  local researched = {}

  for item, amount in pairs(force_data.progress) do
    progress[item] = amount
  end


  for name, recipe in pairs(force.recipes) do
    if string.sub(name, 1, 13) == "journey-free-" then
      for _, product in pairs(recipe.products or {}) do
        if (product.type or "item") == "item"
            or product.type == "fluid"
        then
          progress[product.name] = progress[product.name] or 0

          if recipe.enabled then
            researched[product.name] = true
          end
        end
      end
    end
  end


  local todo_items = {}
  local researched_items = {}

  for item in pairs(progress) do
    if researched[item] then
      table.insert(researched_items, item)
    else
      table.insert(todo_items, item)
    end
  end

  table.sort(todo_items)
  table.sort(researched_items)


  return progress, todo_items, researched_items
end


local function update_journey_item_row(row, force, item, progress, researched)
  local required =
      Research.get_required_count(item, force)

  local displayed_progress =
      math.max(0, math.min(progress, required))
  local displayed_count = displayed_progress

  if prototypes.fluid[item] then
    displayed_count = math.floor(displayed_progress + 0.5)
  end


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
      displayed_count .. " / " .. required


  local estimate_ok, estimate_caption = pcall(function()
    if researched then
      return ""
    end


    local estimated_ticks =
        Research.get_estimated_ticks(force, item)

    if not estimated_ticks then
      return "ETA: measuring..."
    end


    local estimated_seconds = math.ceil(estimated_ticks / 60)
    local days = math.floor(estimated_seconds / 86400)
    local hours = math.floor(estimated_seconds % 86400 / 3600)
    local minutes = math.floor(estimated_seconds % 3600 / 60)
    local seconds = estimated_seconds % 60
    local estimate

    if days > 0 then
      estimate = days .. "d " .. hours .. "h"
    elseif hours > 0 then
      estimate = hours .. "h " .. minutes .. "m"
    elseif minutes > 0 then
      estimate = minutes .. "m " .. seconds .. "s"
    else
      estimate = seconds .. "s"
    end

    return "ETA: ~" .. estimate
  end)

  local estimated_time = details.journey_estimated_time

  if not estimated_time then
    local label_added, label = pcall(function()
      return details.add({
        type = "label",
        name = "journey_estimated_time",
        caption = "ETA: ?",
        tooltip = "Estimated from the average progress rate observed since tracking began."
      })
    end)

    if label_added then
      estimated_time = label
      pcall(function()
        estimated_time.style.font_color = {
          r = 0.7,
          g = 0.7,
          b = 0.7
        }
      end)
    end
  end

  if estimated_time then
    local caption = estimate_ok and estimate_caption or "ETA: ?"
    local caption_updated = pcall(function()
      estimated_time.caption = caption
    end)

    if not caption_updated then
      pcall(function()
        estimated_time.caption = "ETA: ?"
      end)
    end
  end
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
      sprite = get_journey_icon_sprite(item),
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


  local estimated_time =
      details.add({
        type = "label",
        name = "journey_estimated_time",
        caption = "ETA: measuring...",
        tooltip = "Estimated from the average progress rate observed since tracking began."
      })

  estimated_time.style.font_color = {
    r = 0.7,
    g = 0.7,
    b = 0.7
  }


  update_journey_item_row(row, force, item, progress, researched)
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


local function update_journey_category_scroll(
    scroll,
    groups,
    force,
    progress,
    researched,
    empty_message_name,
    empty_message
  )
  local rebuild =
      #groups == 0 and not scroll[empty_message_name]

  for _, group in ipairs(groups) do
    local category =
        scroll[get_journey_category_container_name(
          group.name,
          researched
        )]

    if not category then
      rebuild = true
      break
    end


    if #category.children ~= #group.items + 1 then
      rebuild = true
      break
    end


    for _, item in ipairs(group.items) do
      local row = category[get_journey_row_name(item, researched)]

      if not row
          or not row.journey_item_details
          or not row.journey_item_details.journey_estimated_time
      then
        rebuild = true
        break
      end
    end

    if rebuild then
      break
    end
  end


  if rebuild then
    scroll.clear()
    add_journey_category_groups(
      scroll,
      groups,
      force,
      progress,
      researched,
      empty_message_name,
      empty_message
    )

    return
  end


  for _, group in ipairs(groups) do
    local category =
        scroll[get_journey_category_container_name(
          group.name,
          researched
        )]

    for _, item in ipairs(group.items) do
      update_journey_item_row(
        category[get_journey_row_name(item, researched)],
        force,
        item,
        progress[item],
        researched
      )
    end
  end
end


local function get_journey_summary_icon_name(item)
  return "journey_summary_icon_" .. item
end


local function add_journey_summary_icon(grid, item)
  local icon_name = get_journey_summary_icon_name(item)
  local tooltip = get_journey_item_caption(item)

  local icon_added = pcall(function()
    grid.add({
      type = "sprite",
      name = icon_name,
      sprite = get_journey_icon_sprite(item),
      tooltip = tooltip
    })
  end)


  if not icon_added then
    grid.add({
      type = "label",
      name = icon_name,
      caption = "?",
      tooltip = tooltip
    })
  end
end


local function add_journey_summary_icons(grid, items)
  for _, item in ipairs(items) do
    add_journey_summary_icon(grid, item)
  end
end


local function update_journey_summary(scroll, todo_items, researched_items)
  local todo_grid = scroll.journey_summary_todo_icons
  local researched_grid = scroll.journey_summary_researched_icons

  local rebuild =
      not scroll.journey_summary_todo_header
      or not scroll.journey_summary_researched_header
      or not todo_grid
      or not researched_grid


  local function has_icons(grid, items)
    if #grid.children ~= #items then
      return false
    end


    for _, item in ipairs(items) do
      if not grid[get_journey_summary_icon_name(item)] then
        return false
      end
    end

    return true
  end


  if not rebuild
      and (not has_icons(todo_grid, todo_items)
        or not has_icons(researched_grid, researched_items))
  then
    rebuild = true
  end


  if not rebuild then
    return
  end


  scroll.clear()

  scroll.add({
    type = "label",
    name = "journey_summary_todo_header",
    caption = "TODO"
  })

  local new_todo_grid =
      scroll.add({
        type = "table",
        name = "journey_summary_todo_icons",
        column_count = 8
      })

  add_journey_summary_icons(new_todo_grid, todo_items)


  scroll.add({
    type = "label",
    name = "journey_summary_researched_header",
    caption = "Researched"
  })

  local new_researched_grid =
      scroll.add({
        type = "table",
        name = "journey_summary_researched_icons",
        column_count = 8
      })

  add_journey_summary_icons(new_researched_grid, researched_items)
end


local function update_journey_gui(player)
  local window = player.gui.screen.journey_window

  if not window then
    return
  end


  if not window.journey_tabs then
    window.destroy()
    return
  end


  local data =
      Research.get_force_data(player.force)

  local progress, todo_items, researched_items =
      get_journey_items(player.force, data)

  local in_progress_items = {}

  for _, item in ipairs(todo_items) do
    if progress[item] > 0 then
      table.insert(in_progress_items, item)
    end
  end

  local todo_groups =
      get_journey_category_groups(in_progress_items)
  local researched_groups =
      get_journey_category_groups(researched_items)

  local tabs = window.journey_tabs


  update_journey_category_scroll(
    tabs.journey_in_progress,
    todo_groups,
    player.force,
    progress,
    false,
    "journey_no_in_progress",
    "No items in progress."
  )

  update_journey_category_scroll(
    tabs.journey_researched,
    researched_groups,
    player.force,
    progress,
    true,
    "journey_no_researched",
    "No researched recipes yet."
  )

  update_journey_summary(
    tabs.journey_summary,
    todo_items,
    researched_items
  )
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


  local tabs =
      window.add({
        type = "tabbed-pane",
        name = "journey_tabs"
      })

  tabs.style.width = 430


  local in_progress_tab =
      tabs.add({
        type = "tab",
        name = "journey_in_progress_tab",
        caption = "In Progress"
      })

  local in_progress_scroll =
      tabs.add({
        type = "scroll-pane",
        name = "journey_in_progress"
      })

  in_progress_scroll.style.maximal_height = 500
  in_progress_scroll.style.width = 430
  tabs.add_tab(in_progress_tab, in_progress_scroll)


  local researched_tab =
      tabs.add({
        type = "tab",
        name = "journey_researched_tab",
        caption = "Researched"
      })

  local researched_scroll =
      tabs.add({
        type = "scroll-pane",
        name = "journey_researched"
      })

  researched_scroll.style.maximal_height = 500
  researched_scroll.style.width = 430
  tabs.add_tab(researched_tab, researched_scroll)


  local summary_tab =
      tabs.add({
        type = "tab",
        name = "journey_summary_tab",
        caption = "Summary"
      })

  local summary_scroll =
      tabs.add({
        type = "scroll-pane",
        name = "journey_summary"
      })

  summary_scroll.style.maximal_height = 500
  summary_scroll.style.width = 430
  tabs.add_tab(summary_tab, summary_scroll)


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
