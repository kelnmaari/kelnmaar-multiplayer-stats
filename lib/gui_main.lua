-- lib/gui_main.lua
-- Основные GUI функции - главное окно статистики и детальные окна

local gui_main = {}

-- Create the main statistics GUI
function gui_main.create_stats_gui(player, utils, rankings)
    local player_index = player.index
    
    -- Initialize gui_state if needed
    if not storage.gui_state then
        storage.gui_state = {}
    end
    if not storage.gui_state[player_index] then
        storage.gui_state[player_index] = {
            gui_open = false,
            gui_collapsed = false,
            gui_position = nil  -- Will store {x, y} for each player
        }
    end
    
    -- Save current position before destroying
    if player.gui.screen.multiplayer_stats_frame then
        storage.gui_state[player_index].gui_position = player.gui.screen.multiplayer_stats_frame.location
        player.gui.screen.multiplayer_stats_frame.destroy()
    end
    -- Also check old top location for migration
    if player.gui.top.multiplayer_stats_frame then
        player.gui.top.multiplayer_stats_frame.destroy()
    end
    
    -- Main frame in screen (allows dragging)
    local frame = player.gui.screen.add{
        type = "frame",
        name = "multiplayer_stats_frame",
        direction = "vertical"
    }
    
    -- Restore saved position or set default
    local saved_pos = storage.gui_state[player_index].gui_position
    if saved_pos then
        frame.location = saved_pos
    else
        -- Default position: top-left area
        frame.location = {x = 300, y = 50}
    end
    
    -- Draggable title bar
    local titlebar = frame.add{
        type = "flow",
        name = "stats_titlebar",
        direction = "horizontal"
    }
    titlebar.style.horizontal_spacing = 8
    titlebar.style.vertical_align = "center"
    
    -- Full-width drag handle with title inside
    local drag_handle = titlebar.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    drag_handle.style.height = 24
    drag_handle.style.minimal_width = 150
    drag_handle.style.horizontally_stretchable = true
    drag_handle.drag_target = frame
    
    -- Title (overlaid on drag handle - positioned absolutely would be ideal but we use flow)
    local title_label = titlebar.add{
        type = "label",
        caption = {"gui.stats-title"},
        style = "frame_title"
    }
    title_label.drag_target = frame  -- Make title also draggable
    
    -- Add another drag space after title for balance
    local spacer = titlebar.add{
        type = "empty-widget",
        style = "draggable_space_header"
    }
    spacer.style.height = 24
    spacer.style.minimal_width = 30
    spacer.style.horizontally_stretchable = true
    spacer.drag_target = frame
    
    -- Collapse/expand button
    local collapse_sprite = storage.gui_state[player_index].gui_collapsed and "utility/expand" or "utility/collapse"
    titlebar.add{
        type = "sprite-button",
        name = "toggle_collapse_stats_gui",
        sprite = collapse_sprite,
        style = "frame_action_button",
        tooltip = {"gui.toggle-collapse"}
    }
    
    -- Achievements button
    titlebar.add{
        type = "sprite-button",
        name = "show_achievements",
        sprite = "utility/check_mark",
        style = "frame_action_button",
        tooltip = {"gui.show-achievements"}
    }
    
    -- Rankings button
    titlebar.add{
        type = "sprite-button",
        name = "show_rankings",
        sprite = "utility/status_working",
        style = "frame_action_button",
        tooltip = {"gui.show-rankings"}
    }
    
    -- Close button
    titlebar.add{
        type = "sprite-button",
        name = "close_stats_gui",
        sprite = "utility/close",
        style = "frame_action_button",
        tooltip = {"gui.close"}
    }
    
    -- Content area (only if not collapsed)
    if not storage.gui_state[player_index].gui_collapsed then
        local content = frame.add{
            type = "scroll-pane",
            name = "stats_content"
        }
        content.style.minimal_width = 600
        content.style.maximal_width = 900
        content.style.maximal_height = 400
        
        -- Player list
        local player_table = content.add{
            type = "table",
            name = "player_stats_table",
            column_count = 9  -- Добавили столбец с планетами
        }
        player_table.style.horizontal_spacing = 8
        player_table.style.vertical_spacing = 4
        
        -- Headers with fixed widths (важные колонки для обзора)
        local h1 = player_table.add{type = "label", caption = {"gui.player-name"}, style = "bold_label"}
        h1.style.width = 90
        local h2 = player_table.add{type = "label", caption = {"gui.rank"}, style = "bold_label"}
        h2.style.width = 80
        local h3 = player_table.add{type = "label", caption = {"gui.score"}, style = "bold_label"}
        h3.style.width = 50
        local h4 = player_table.add{type = "label", caption = {"gui.distance"}, style = "bold_label"}
        h4.style.width = 70
        local h5 = player_table.add{type = "label", caption = {"gui.total-crafted"}, style = "bold_label"}
        h5.style.width = 60
        local h6 = player_table.add{type = "label", caption = {"gui.enemies-killed"}, style = "bold_label"}
        h6.style.width = 60
        local h7 = player_table.add{type = "label", caption = {"gui.planets"}, style = "bold_label"}
        h7.style.width = 50
        local h8 = player_table.add{type = "label", caption = {"gui.playtime"}, style = "bold_label"}
        h8.style.width = 70
        local h9 = player_table.add{type = "label", caption = {"gui.actions"}, style = "bold_label"}
        h9.style.width = 90
        
        -- Fill player data
        for _, game_player in pairs(game.players) do
            if game_player.connected then
                utils.init_player(game_player.index)
                local stats = storage.players[game_player.index]
                
                -- Player name
                player_table.add{
                    type = "label", 
                    caption = game_player.name
                }
                
                -- Player rank
                local rank, score = rankings.calculate_player_rank(stats)
                local rank_flow = player_table.add{
                    type = "flow",
                    direction = "horizontal"
                }
                rank_flow.add{
                    type = "label",
                    caption = rank.icon,
                    tooltip = {"gui.rank-tooltip", {"gui.rank-" .. rank.name}, score}
                }
                rank_flow.add{
                    type = "label",
                    caption = {"gui.rank-" .. rank.name},
                    style = "bold_label"
                }
                
                -- Player Score
                player_table.add{
                    type = "label",
                    caption = tostring(score)
                }
                
                -- Distance (rounded to 1 decimal place)
                player_table.add{
                    type = "label",
                    caption = string.format("%.1f", stats.distance_traveled)
                }
                
                -- Total crafted items
                player_table.add{
                    type = "label",
                    caption = tostring(stats.total_crafted)
                }
                
                -- Enemies killed
                player_table.add{
                    type = "label",
                    caption = tostring(stats.enemies_killed or 0)
                }
                
                -- Planets (icons)
                utils.create_planets_flow(player_table, stats.planets_visited)
                
                -- Playtime
                player_table.add{
                    type = "label",
                    caption = utils.format_playtime(stats.playtime_ticks or 0)
                }
                
                -- Action buttons flow (горизонтально, компактные)
                local actions_flow = player_table.add{
                    type = "flow",
                    direction = "horizontal"
                }
                actions_flow.style.horizontal_spacing = 4
                
                actions_flow.add{
                    type = "sprite-button",
                    name = "show_player_details_" .. game_player.index,
                    sprite = "utility/search",
                    style = "frame_action_button",
                    tooltip = {"gui.details"}
                }

                actions_flow.add{
                    type = "sprite-button",
                    name = "show_crafting_history_" .. game_player.index,
                    sprite = "utility/clock",
                    style = "frame_action_button",
                    tooltip = {"gui.history"}
                }

                actions_flow.add{
                    type = "sprite-button",
                    name = "compare_with_" .. game_player.index,
                    sprite = "utility/side_menu_production_icon",
                    style = "frame_action_button",
                    tooltip = {"gui.compare"}
                }

                actions_flow.add{
                    type = "sprite-button",
                    name = "show_charts_" .. game_player.index,
                    sprite = "utility/change_recipe",
                    style = "frame_action_button",
                    tooltip = {"gui.charts"}
                }
            end
        end
    end -- End of collapsed check
    
    if storage.gui_state and storage.gui_state[player_index] then
        storage.gui_state[player_index].gui_open = true
    end
end

-- Update existing stats GUI with fresh data
function gui_main.update_stats_gui(utils, rankings)
    for player_index, gui_state in pairs(storage.gui_state or {}) do
        if gui_state.gui_open then
            local player = game.players[player_index]
            -- MEMORY LEAK FIX: Check if player exists, is valid and connected
            if player and player.valid and player.connected and player.gui.screen.multiplayer_stats_frame then
                local frame = player.gui.screen.multiplayer_stats_frame
                local content = frame.stats_content
                if content and not gui_state.gui_collapsed then
                    local player_table = content.player_stats_table
                    if player_table then
                        -- Clear existing data (keep headers)
                        local children = player_table.children
                        for i = #children, 10, -1 do  -- Keep first 9 header elements
                            children[i].destroy()
                        end
                        
                        -- Refill with fresh data (matching new 8-column structure)
                        for _, game_player in pairs(game.players) do
                            if game_player.connected then
                                utils.init_player(game_player.index)
                                local stats = storage.players[game_player.index]
                                
                                -- Player name
                                player_table.add{type = "label", caption = game_player.name}
                                
                                -- Player rank
                                local rank, score = rankings.calculate_player_rank(stats)
                                local rank_flow = player_table.add{type = "flow", direction = "horizontal"}
                                rank_flow.add{type = "label", caption = rank.icon, tooltip = {"gui.rank-tooltip", {"gui.rank-" .. rank.name}, score}}
                                rank_flow.add{type = "label", caption = {"gui.rank-" .. rank.name}, style = "bold_label"}
                                
                                -- Player Score
                                player_table.add{type = "label", caption = tostring(score)}
                                
                                -- Distance (rounded to 1 decimal place)
                                player_table.add{type = "label", caption = string.format("%.1f", stats.distance_traveled)}
                                
                                -- Total crafted items
                                player_table.add{type = "label", caption = tostring(stats.total_crafted)}
                                
                                -- Enemies killed
                                player_table.add{type = "label", caption = tostring(stats.enemies_killed or 0)}
                                
                                -- Planets (icons)
                                utils.create_planets_flow(player_table, stats.planets_visited)
                                
                                -- Playtime
                                player_table.add{type = "label", caption = utils.format_playtime(stats.playtime_ticks or 0)}
                                
                                -- Action buttons flow (горизонтально, компактные)
                                local actions_flow = player_table.add{type = "flow", direction = "horizontal"}
                                actions_flow.style.horizontal_spacing = 4
                                
                                actions_flow.add{
                                    type = "sprite-button",
                                    name = "show_player_details_" .. game_player.index,
                                    sprite = "utility/search",
                                    style = "frame_action_button",
                                    tooltip = {"gui.details"}
                                }
                                actions_flow.add{
                                    type = "sprite-button",
                                    name = "show_crafting_history_" .. game_player.index,
                                    sprite = "utility/clock",
                                    style = "frame_action_button",
                                    tooltip = {"gui.history"}
                                }
                                actions_flow.add{
                                    type = "sprite-button",
                                    name = "compare_with_" .. game_player.index,
                                    sprite = "utility/side_menu_production_icon",
                                    style = "frame_action_button",
                                    tooltip = {"gui.compare"}
                                }
                                actions_flow.add{
                                    type = "sprite-button",
                                    name = "show_charts_" .. game_player.index,
                                    sprite = "utility/change_recipe",
                                    style = "frame_action_button",
                                    tooltip = {"gui.charts"}
                                }
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Show crafting details for a player
function gui_main.show_crafting_details(requesting_player, target_player_index, utils, rankings, stats_module)
    local target_player = game.players[target_player_index]
    if not target_player or not target_player.valid then
        return
    end

    if requesting_player.gui.screen.crafting_details_frame then
        requesting_player.gui.screen.crafting_details_frame.destroy()
    end

    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "crafting_details_frame",
        caption = {"gui.crafting-details", target_player.name},
        direction = "vertical"
    }
    
    frame.auto_center = true
    
    local content = frame.add{
        type = "scroll-pane"
    }
    content.style.minimal_width = 300
    content.style.maximal_height = 400
    
    utils.init_player(target_player_index)
    local stats = storage.players[target_player_index]
    
    -- Player rank display
    local rank, score = rankings.calculate_player_rank(stats)
    local rank_header = content.add{
        type = "flow",
        direction = "horizontal"
    }
    rank_header.add{
        type = "label",
        caption = rank.icon,
        style = "bold_label"
    }
    rank_header.add{
        type = "label",
        caption = {"gui.player-rank-display", {"gui.rank-" .. rank.name}, score},
        style = "bold_label"
    }
    content.add{type = "line"}
    
    -- Active crafting queue
    content.add{
        type = "label", 
        caption = {"gui.active-queue"}, 
        style = "bold_label"
    }
    
    local queue_table = content.add{
        type = "table",
        column_count = 3
    }
    
    if target_player.character and target_player.character.crafting_queue then
        for _, recipe in pairs(target_player.character.crafting_queue) do
            local recipe_proto = prototypes.recipe[recipe.recipe]
            if recipe_proto then
                queue_table.add{
                    type = "sprite",
                    sprite = "recipe/" .. recipe.recipe
                }
                queue_table.add{
                    type = "label",
                    caption = recipe_proto.localised_name or recipe.recipe
                }
                queue_table.add{
                    type = "label",
                    caption = "x" .. recipe.count
                }
            end
        end
    else
        queue_table.add{
            type = "label",
            caption = {"gui.no-active-crafts"}
        }
    end
    
    -- Combat statistics
    content.add{type = "line"}
    content.add{
        type = "label", 
        caption = {"gui.combat-stats"}, 
        style = "bold_label"
    }
    
    local combat_flow = content.add{type = "flow", direction = "horizontal"}
    combat_flow.add{
        type = "label",
        caption = {"gui.enemies-killed-detail", tostring(stats.enemies_killed or 0)}
    }
    combat_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    combat_flow.add{
        type = "label",
        caption = {"gui.deaths-detail", tostring(stats.deaths or 0)}
    }
    
    -- Building statistics
    content.add{type = "line"}
    content.add{
        type = "label", 
        caption = {"gui.building-stats"}, 
        style = "bold_label"
    }
    
    local building_flow = content.add{type = "flow", direction = "horizontal"}
    building_flow.add{
        type = "label",
        caption = {"gui.built-detail", tostring(stats.buildings_built or 0)}
    }
    building_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    building_flow.add{
        type = "label",
        caption = {"gui.destroyed-detail", tostring(stats.buildings_destroyed or 0)}
    }
    
    -- Space Age statistics
    content.add{type = "line"}
    content.add{
        type = "label", 
        caption = {"gui.space-age-stats"}, 
        style = "bold_label"
    }
    
    local space_flow = content.add{type = "flow", direction = "horizontal"}
    space_flow.add{
        type = "label",
        caption = {"gui.space-distance-detail", string.format("%.2f", stats.space_travel_distance or 0)}
    }
    
    if stats.planets_visited and next(stats.planets_visited) then
        content.add{
            type = "label",
            caption = {"gui.planets-visited"},
            style = "bold_label"
        }
        
        local planets_flow = content.add{
            type = "flow",
            direction = "horizontal"
        }
        
        -- Sort planets by visit order and add icons with names
        local sorted_planets = {}
        for planet_name, visit_tick in pairs(stats.planets_visited) do
            table.insert(sorted_planets, {name = planet_name, tick = visit_tick})
        end
        table.sort(sorted_planets, function(a, b) return a.tick < b.tick end)
        
        for _, planet_data in ipairs(sorted_planets) do
            local planet_flow = planets_flow.add{
                type = "flow",
                direction = "vertical"
            }
            planet_flow.style.horizontal_align = "center"
            
            local icon_sprite = utils.get_planet_icon(planet_data.name)
            planet_flow.add{
                type = "sprite",
                sprite = icon_sprite,
                tooltip = planet_data.name
            }
            planet_flow.add{
                type = "label",
                caption = planet_data.name,
                style = "caption_label"
            }
        end
    end
    
    -- Playtime
    content.add{type = "line"}
    content.add{
        type = "label",
        caption = {"gui.total-playtime-detail", utils.format_playtime(stats.playtime_ticks or 0)},
        style = "bold_label"
    }
    
    -- Visualization section
    content.add{type = "line"}
    content.add{
        type = "label",
        caption = {"gui.statistics-visualization"},
        style = "bold_label"
    }
    
    local viz_data = stats_module.create_stats_visualization(stats)
    
    -- Progress to next rank (only if user setting enabled)
    local user_settings = settings.get_player_settings(requesting_player.index)
    if viz_data.rank_progress and user_settings["multiplayer-stats-show-rank-progress"] and 
       user_settings["multiplayer-stats-show-rank-progress"].value then
        content.add{
            type = "label",
            caption = {"gui.progress-to-next-rank", {"gui.rank-" .. viz_data.rank_progress.next_rank.name}}
        }
        
        local progress_bar = utils.create_progress_bar(
            viz_data.rank_progress.current, 
            viz_data.rank_progress.needed, 
            20
        )
        
        content.add{
            type = "label",
            caption = progress_bar,
            style = "bold_label"
        }
    end
    
    -- Activity breakdown
    if viz_data.activity_breakdown then
        content.add{
            type = "label",
            caption = {"gui.activity-breakdown"}
        }
        
        local activity_table = content.add{
            type = "table",
            column_count = 2
        }
        
        activity_table.add{type = "label", caption = {"gui.crafting"}}
        activity_table.add{type = "label", caption = viz_data.activity_breakdown.crafting .. "%"}
        
        activity_table.add{type = "label", caption = {"gui.combat"}}
        activity_table.add{type = "label", caption = viz_data.activity_breakdown.combat .. "%"}
        
        activity_table.add{type = "label", caption = {"gui.building"}}
        activity_table.add{type = "label", caption = viz_data.activity_breakdown.building .. "%"}
    end
    
    -- Resource mining visualization
    if viz_data.mining_breakdown and next(viz_data.mining_breakdown) then
        content.add{
            type = "label",
            caption = {"gui.mining-distribution"}
        }
        
        local mining_table = content.add{
            type = "table",
            column_count = 3
        }
        
        for resource, percentage in pairs(viz_data.mining_breakdown) do
            if percentage > 0 and prototypes.item[resource] then
                mining_table.add{
                    type = "sprite",
                    sprite = "item/" .. resource
                }
                mining_table.add{
                    type = "label",
                    caption = prototypes.item[resource].localised_name or resource
                }
                mining_table.add{
                    type = "label",
                    caption = percentage .. "%"
                }
            end
        end
    end
    
    -- Close button
    local close_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_crafting_details",
        caption = {"gui.close"}
    }
end

-- Show crafting history for a player
function gui_main.show_crafting_history(requesting_player, target_player_index, utils)
    local target_player = game.players[target_player_index]
    if not target_player or not target_player.valid then
        return
    end

    if requesting_player.gui.screen.crafting_history_frame then
        requesting_player.gui.screen.crafting_history_frame.destroy()
    end

    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "crafting_history_frame",
        caption = {"gui.crafting-history-title", target_player.name},
        direction = "vertical"
    }
    
    frame.auto_center = true
    
    local content = frame.add{
        type = "scroll-pane"
    }
    content.style.minimal_width = 400
    content.style.maximal_height = 500
    
    -- Total crafted items label
    content.add{
        type = "label",
        caption = {"gui.total-crafted-items"},
        style = "bold_label"
    }
    
    utils.init_player(target_player_index)
    local stats = storage.players[target_player_index]
    
    -- Crafted items history table
    local crafted_table = content.add{
        type = "table",
        column_count = 3
    }
    
    if next(stats.crafted_items) then
        -- Sort items by count (highest first)
        local sorted_items = {}
        for item_name, count in pairs(stats.crafted_items) do
            table.insert(sorted_items, {name = item_name, count = count})
        end
        table.sort(sorted_items, function(a, b) return a.count > b.count end)
        
        -- Display sorted items
        for _, item_data in ipairs(sorted_items) do
            local item_name = item_data.name
            local count = item_data.count
            
            if prototypes.item[item_name] then
                crafted_table.add{
                    type = "sprite",
                    sprite = "item/" .. item_name,
                    tooltip = item_name
                }
                crafted_table.add{
                    type = "label",
                    caption = prototypes.item[item_name].localised_name or item_name
                }
                crafted_table.add{
                    type = "label",
                    caption = string.format("×%d", count),
                    style = "bold_label"
                }
            end
        end
        
        -- Total summary
        content.add{type = "line"}
        content.add{
            type = "label",
            caption = {"gui.total-items-crafted", stats.total_crafted},
            style = "bold_label"
        }
    else
        crafted_table.add{
            type = "label",
            caption = {"gui.no-crafted-items"},
            colspan = 3
        }
    end
    
    -- Close button
    local close_flow = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_crafting_history",
        caption = {"gui.close"}
    }
end

return gui_main 