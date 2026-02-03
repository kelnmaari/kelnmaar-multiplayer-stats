-- lib/gui.lua
-- Интерфейс и GUI функции

local gui = {}
local charts = require("__factorio-charts__.charts")


-- Render a professional line chart using factorio-charts
function gui.render_professional_chart(parent, timeseries, series_to_show, title, height)
    local chart_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "inside_deep_frame"
    }
    chart_frame.style.horizontally_stretchable = true
    chart_frame.style.padding = 8

    -- Add title if provided
    if title then
        local title_label = chart_frame.add{
            type = "label",
            caption = title,
            style = "frame_title"
        }
        title_label.style.bottom_margin = 4
        title_label.style.horizontal_align = "center"
    end

    -- Use the 30s interval for display (index 1)
    local interval_index = 1
    local interval = timeseries[interval_index]

    -- Ensure chart surface exists (safety check)
    if not storage.charts_surface then
        storage.charts_surface = charts.create_surface("kelnmaar-stats-charts")
    end

    -- Ensure chunk is allocated for the interval we're going to render
    if not interval.chunk then
        interval.chunk = charts.allocate_chunk(storage.charts_surface)
    end
    
    -- Define series configuration (colors and labels)
    local series_config = {
        distance = {color = {r=0.0, g=0.5, b=1.0}, label = "Distance Traveled"}, -- Blue
        score = {color = {r=1.0, g=0.8, b=0.0}, label = "Rank Score"},      -- Gold
        crafted = {color = {r=0.2, g=0.8, b=0.2}, label = "Items Crafted"},   -- Green
        combat = {color = {r=1.0, g=0.3, b=0.3}, label = "Enemies Killed"},   -- Red
        playtime = {color = {r=0.6, g=0.2, b=0.8}, label = "Playtime (Hours)"} -- Purple
    }

    -- Convert config to series filter for charts library
    -- If series_to_show is specified, only show those series
    local selected = nil
    if series_to_show then
        selected = {}
        for _, name in ipairs(series_to_show) do
            selected[name] = true
        end
    end

    -- Viewport dimensions for consistent layout
    local viewport_width = 900
    local viewport_height = 600

    -- Render the time series
    local ordered_sums, hit_regions = charts.render_time_series(
        storage.charts_surface.surface,
        timeseries,
        interval_index,
        {
            selected_series = selected,
            y_range = nil,  -- Auto-scale Y axis
            label_format = "time",
            viewport_width = viewport_width,
            viewport_height = viewport_height,
        }
    )

    -- Debug: Check if data was rendered
    if not ordered_sums then
        local series_names = {}
        if interval.counts then
            for name, count in pairs(interval.counts) do
                table.insert(series_names, string.format("%s(%d)", name, count))
            end
        end
        local debug_info = string.format(
            "No data rendered. Data points: %d/%d, Index: %d, Series: %s",
            #interval.data,
            interval.length,
            interval.index,
            #series_names > 0 and table.concat(series_names, ", ") or "none"
        )
        chart_frame.add{
            type = "label",
            caption = debug_info,
            style = "caption_label"
        }
    end

    -- Add camera widget
    -- Use fixed dimensions matching viewport for consistent appearance
    local widget_width = 600
    local widget_height = height or 400

    local camera_params = charts.get_camera_params(interval.chunk, {
        viewport_width = viewport_width,
        viewport_height = viewport_height,
        widget_width = widget_width,
        widget_height = widget_height,
        fit_mode = "fit"
    })

    local camera = chart_frame.add{
        type = "camera",
        position = camera_params.position,
        surface_index = storage.charts_surface.surface.index,
        zoom = camera_params.zoom
    }
    camera.style.minimal_width = widget_width
    camera.style.height = widget_height
    camera.style.horizontally_stretchable = true
    camera.style.top_margin = 4

    -- Add Legend - use library colors and ordered series
    local legend_flow = chart_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    legend_flow.style.top_margin = 4
    legend_flow.style.bottom_margin = 4
    legend_flow.style.horizontal_spacing = 16
    legend_flow.style.horizontal_align = "center"
    legend_flow.style.horizontally_stretchable = true

    -- Create legend items based on ordered_sums (if available)
    if ordered_sums then
        for _, entry in ipairs(ordered_sums) do
            local series_name = entry.name
            local color_index = entry.color_index
            local color = charts.get_series_color(color_index)

            -- Get display label
            local display_label = series_config[series_name] and series_config[series_name].label or series_name

            local item_flow = legend_flow.add{type="flow", direction="horizontal"}
            item_flow.style.vertical_align = "center"

            local label = item_flow.add{
                type = "label",
                caption = "◼ " .. display_label,
                style = "caption_label"
            }
            label.style.font_color = color
            label.style.font = "default-bold"
        end
    end
    
    return chart_frame
end

-- Create visual rank progress with all ranks displayed
function gui.create_rank_progress_visual(parent, current_rank, current_score, next_rank, rankings)
    local progress_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    progress_frame.style.padding = 12

    -- Title
    local title_label = progress_frame.add{
        type = "label",
        caption = "Rank Progress",
        style = "frame_title"
    }
    title_label.style.bottom_margin = 8

    -- Current rank display (large and prominent)
    local current_flow = progress_frame.add{
        type = "flow",
        direction = "horizontal"
    }
    current_flow.style.vertical_align = "center"
    current_flow.style.bottom_margin = 12

    local current_icon = current_flow.add{
        type = "label",
        caption = current_rank.icon,
        style = "bold_label"
    }
    current_icon.style.font = "default-large-bold"
    current_icon.style.font_color = current_rank.color or {r=1, g=1, b=0}
    current_icon.style.right_margin = 8

    local current_name = current_flow.add{
        type = "label",
        caption = current_rank.name,
        style = "bold_label"
    }
    current_name.style.font = "default-large-bold"

    current_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true

    current_flow.add{
        type = "label",
        caption = "Score: " .. current_score,
        style = "label"
    }

    -- Progress bar and next rank info
    if next_rank then
        local progress = math.min(1.0, current_score / next_rank.min_score)

        -- Next rank info
        local next_flow = progress_frame.add{
            type = "flow",
            direction = "horizontal"
        }
        next_flow.style.bottom_margin = 4

        next_flow.add{
            type = "label",
            caption = "Next Rank: " .. next_rank.icon .. " " .. next_rank.name,
            style = "label"
        }

        next_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true

        local points_needed = next_rank.min_score - current_score
        next_flow.add{
            type = "label",
            caption = points_needed .. " points needed",
            style = "caption_label"
        }

        -- Progress bar
        local progress_bar = progress_frame.add{
            type = "progressbar",
            value = progress,
            style = "kelnmaar_rank_progress"
        }
        progress_bar.style.horizontally_stretchable = true
        progress_bar.style.height = 24

        -- Progress percentage
        local percent_label = progress_frame.add{
            type = "label",
            caption = string.format("%.1f%% to next rank", progress * 100),
            style = "caption_label"
        }
        percent_label.style.top_margin = 4
    else
        -- Max rank achieved
        progress_frame.add{
            type = "label",
            caption = "🎉 Maximum Rank Achieved! 🎉",
            style = "bold_label"
        }
    end

    return progress_frame
end

-- Create pie chart visualization using flows and colors
function gui.create_pie_chart(parent, data, title)
    local chart_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_chart_frame"
    }
    
    chart_frame.add{
        type = "label",
        caption = title,
        style = "kelnmaar_chart_title"
    }
    
    if not data or not next(data) then
        chart_frame.add{
            type = "label",
            caption = "No data available",
            style = "caption_label"
        }
        return chart_frame
    end
    
    -- Calculate total for percentages
    local total = 0
    for _, value in pairs(data) do
        total = total + value
    end
    
    if total == 0 then
        chart_frame.add{
            type = "label",
            caption = "No data available",
            style = "caption_label"
        }
        return chart_frame
    end
    
    -- Create legend with colored boxes
    local legend_flow = chart_frame.add{
        type = "flow",
        direction = "vertical"
    }
    
    local colors = {
        {r=0.2, g=0.8, b=0.2},  -- Green
        {r=0.8, g=0.2, b=0.2},  -- Red  
        {r=0.2, g=0.2, b=0.8},  -- Blue
        {r=0.8, g=0.8, b=0.2},  -- Yellow
        {r=0.8, g=0.2, b=0.8},  -- Magenta
        {r=0.2, g=0.8, b=0.8}   -- Cyan
    }
    
    local color_index = 1
    for name, value in pairs(data) do
        local percentage = math.floor((value / total) * 100)
        
        local legend_item = legend_flow.add{
            type = "flow",
            direction = "horizontal"
        }
        
        -- Use colored square symbol instead of background_color
        local color_label = legend_item.add{
            type = "label",
            caption = "■"
        }
        color_label.style.font_color = colors[color_index] or {r=0.5, g=0.5, b=0.5}
        color_label.style.font = "default-large-bold"
        
        legend_item.add{
            type = "label",
            caption = " " .. name .. ": " .. percentage .. "%"
        }
        
        color_index = color_index + 1
    end
    
    return chart_frame
end

-- Show statistics charts window
function gui.show_statistics_charts(requesting_player, target_player_index, utils, rankings, stats_module)
    local target_player = game.players[target_player_index]
    
    if requesting_player.gui.screen.stats_charts_frame then
        requesting_player.gui.screen.stats_charts_frame.destroy()
    end
    
    -- Get player rank for title
    utils.init_player(target_player_index)
    local temp_stats = storage.players[target_player_index]
    local temp_rank, temp_score = rankings.calculate_player_rank(temp_stats)
    
    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "stats_charts_frame",
        caption = "📊 Statistics Dashboard: " .. target_player.name .. " [" .. temp_rank.icon .. " " .. temp_rank.name .. " - " .. temp_score .. " pts]",
        direction = "vertical",
        style = "kelnmaar_dashboard_frame"
    }
    
    frame.auto_center = true
    frame.style.minimal_width = 800
    frame.style.maximal_height = 900
    
    local content = frame.add{
        type = "scroll-pane",
        name = "charts_content",
        style = "kelnmaar_charts_scroll"
    }
    
    -- Store data for auto-refresh
    if not storage.dashboard_data then
        storage.dashboard_data = {}
    end
    storage.dashboard_data[requesting_player.index] = {
        target_player_index = target_player_index,
        last_update = game.tick
    }
    
    gui.create_dashboard_content(content, target_player_index, utils, rankings)
    
    -- Close button
    local close_flow = frame.add{type = "flow", direction = "horizontal"}
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_stats_charts",
        caption = "Close"
    }
end

-- Create dashboard content (separate function for auto-refresh)
function gui.create_dashboard_content(content, target_player_index, utils, rankings)
    -- Clear existing content
    content.clear()

    local target_player = game.players[target_player_index]
    if not target_player or not target_player.valid then
        return
    end
    utils.init_player(target_player_index)
    local temp_stats = storage.players[target_player_index]
    if not temp_stats then
        return
    end
    local temp_rank, temp_score = rankings.calculate_player_rank(temp_stats)
    
    -- 1. STATISTICS OVERVIEW (Moved to top)
    local info_frame = content.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_info_frame"
    }
    
    info_frame.add{
        type = "label",
        caption = "Statistics Overview",
        style = "kelnmaar_chart_title"
    }
    
    local info_table = info_frame.add{
        type = "table",
        column_count = 4
    }
    
    -- Current stats summary
    info_table.add{type = "label", caption = "Distance:", style = "bold_label"}
    info_table.add{type = "label", caption = string.format("%.1f tiles", temp_stats.distance_traveled or 0)}
    info_table.add{type = "label", caption = "Score:", style = "bold_label"}
    info_table.add{type = "label", caption = tostring(temp_score)}
    
    info_table.add{type = "label", caption = "Crafted:", style = "bold_label"}
    info_table.add{type = "label", caption = tostring(temp_stats.total_crafted or 0)}
    info_table.add{type = "label", caption = "Combat:", style = "bold_label"}
    info_table.add{type = "label", caption = tostring(temp_stats.enemies_killed or 0)}
    
    info_table.add{type = "label", caption = "Built:", style = "bold_label"}
    info_table.add{type = "label", caption = tostring(temp_stats.buildings_built or 0)}
    info_table.add{type = "label", caption = "Playtime:", style = "bold_label"}
    info_table.add{type = "label", caption = utils.format_playtime(temp_stats.playtime_ticks or 0)}
    
    -- 2. RANK PROGRESS (Moved to second position)
    content.add{type = "line"}

    local current_rank = temp_rank
    local current_score = temp_score

    -- Find next rank
    local next_rank = nil
    for _, rank in ipairs(rankings.RANKS) do
        if rank.min_score > current_score then
            next_rank = rank
            break
        end
    end

    -- Create visual rank progress
    gui.create_rank_progress_visual(content, current_rank, current_score, next_rank, rankings)
    
    -- 3. ACTIVITY BREAKDOWN (Moved to third position)
    local total_activity = (temp_stats.total_crafted or 0) + (temp_stats.enemies_killed or 0) + (temp_stats.buildings_built or 0)
    if total_activity > 0 then
        content.add{type = "line"}
        
        local activity_data = {
            ["Crafting"] = temp_stats.total_crafted or 0,
            ["Combat"] = temp_stats.enemies_killed or 0,
            ["Building"] = temp_stats.buildings_built or 0
        }
        
        gui.create_pie_chart(content, activity_data, "Activity Breakdown")
    end
    
    -- 4. CHARTS (Moved to bottom)
    content.add{type = "line"}
    content.add{
        type = "label",
        caption = "📈 Historical Charts",
        style = "kelnmaar_chart_title"
    }

    utils.init_chart_history(target_player_index)
    local history = storage.chart_history[target_player_index]

    if not history.distance or #history.distance == 0 then
        content.add{
            type = "label",
            caption = "📈 No chart data available yet. Statistics will appear after some game activity.",
            style = "caption_label"
        }
    else
        -- Main charts grid
        local ts = storage.player_timeseries and storage.player_timeseries[target_player_index]
        if ts then
            -- Main large chart with title inside the frame
            gui.render_professional_chart(content, ts, nil, "Overview & Access Statistics", 450)
        else
            content.add{
                type = "label",
                caption = "📈 Initializing time series data...",
                style = "caption_label"
            }
        end
    end
    
    -- Last update info
    content.add{type = "line"}
    content.add{
        type = "label",
        caption = "🔄 Auto-refresh: every 10 seconds | Tick: " .. tostring(game.tick),
        style = "caption_label"
    }
end

-- Show rankings window
function gui.show_rankings(requesting_player, rankings)
    if requesting_player.gui.screen.rankings_frame then
        requesting_player.gui.screen.rankings_frame.destroy()
    end
    
    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "rankings_frame",
        caption = {"gui.rankings-title"},
        direction = "vertical"
    }
    
    frame.auto_center = true
    
    local content = frame.add{
        type = "scroll-pane"
    }
    content.style.minimal_width = 500
    content.style.maximal_height = 600
    
    -- Ranking categories
    local categories = {
        {name = "score", title = {"gui.ranking-score"}},
        {name = "distance", title = {"gui.ranking-distance"}},
        {name = "crafted", title = {"gui.ranking-crafted"}},
        {name = "combat", title = {"gui.ranking-combat"}},
        {name = "building", title = {"gui.ranking-building"}}
    }
    
    for _, category in pairs(categories) do
        content.add{
            type = "label",
            caption = category.title,
            style = "bold_label"
        }
        
        -- Create ranking table
        local ranking_table = content.add{
            type = "table",
            column_count = 4
        }
        
        -- Headers
        ranking_table.add{type = "label", caption = {"gui.rank-position"}, style = "bold_label"}
        ranking_table.add{type = "label", caption = {"gui.player-name"}, style = "bold_label"}
        ranking_table.add{type = "label", caption = {"gui.rank"}, style = "bold_label"}
        ranking_table.add{type = "label", caption = {"gui.value"}, style = "bold_label"}
        
        -- Collect and sort player data
        local players_data = {}
        for _, player in pairs(game.players) do
            if player.connected and storage.players[player.index] then
                local stats = storage.players[player.index]
                table.insert(players_data, {player = player, stats = stats})
            end
        end
        
        -- Sort by category
        if category.name == "score" then
            table.sort(players_data, function(a, b)
                local _, score_a = rankings.calculate_player_rank(a.stats)
                local _, score_b = rankings.calculate_player_rank(b.stats)
                return score_a > score_b
            end)
        elseif category.name == "distance" then
            table.sort(players_data, function(a, b)
                return a.stats.distance_traveled > b.stats.distance_traveled
            end)
        elseif category.name == "crafted" then
            table.sort(players_data, function(a, b)
                return a.stats.total_crafted > b.stats.total_crafted
            end)
        elseif category.name == "combat" then
            table.sort(players_data, function(a, b)
                return a.stats.enemies_killed > b.stats.enemies_killed
            end)
        elseif category.name == "building" then
            table.sort(players_data, function(a, b)
                return a.stats.buildings_built > b.stats.buildings_built
            end)
        end
        
        -- Show top 5
        for i = 1, math.min(5, #players_data) do
            local player_data = players_data[i]
            local player = player_data.player
            local stats = player_data.stats
            
            -- Position
            ranking_table.add{type = "label", caption = "#" .. i}
            
            -- Player name
            ranking_table.add{type = "label", caption = player.name}
            
            -- Player rank
            local rank = rankings.calculate_player_rank(stats)
            local rank_flow = ranking_table.add{type = "flow", direction = "horizontal"}
            rank_flow.add{type = "label", caption = rank.icon}
            rank_flow.add{type = "label", caption = {"gui.rank-" .. rank.name}}
            
            -- Value for this category
            local value = ""
            if category.name == "score" then
                local _, score = rankings.calculate_player_rank(stats)
                value = tostring(score)
            elseif category.name == "distance" then
                value = string.format("%.2f", stats.distance_traveled)
            elseif category.name == "crafted" then
                value = tostring(stats.total_crafted)
            elseif category.name == "combat" then
                value = tostring(stats.enemies_killed)
            elseif category.name == "building" then
                value = tostring(stats.buildings_built)
            end
            ranking_table.add{type = "label", caption = value}
        end
        
        content.add{type = "line"}
    end
    
    -- Close button
    local close_flow = frame.add{type = "flow", direction = "horizontal"}
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_rankings",
        caption = {"gui.close"}
    }
end

-- Helper function to count table elements
local function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Show achievements window
function gui.show_achievements(requesting_player, rankings, utils)
    if requesting_player.gui.screen.achievements_frame then
        requesting_player.gui.screen.achievements_frame.destroy()
    end

    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "achievements_frame",
        caption = {"gui.achievements-title"},
        direction = "vertical"
    }

    frame.auto_center = true

    local content = frame.add{
        type = "scroll-pane"
    }
    content.style.minimal_width = 600
    content.style.maximal_height = 500

    local player_data = storage.players[requesting_player.index]
    if not player_data then
        utils.init_player(requesting_player.index)
        player_data = storage.players[requesting_player.index]
    end
    local player_achievements = player_data and player_data.achievements or {}
    
    -- Debug info
    content.add{
        type = "label",
        caption = {"gui.debug-achievements-found", tostring(table_size(player_achievements))},
        style = "caption_label"
    }
    
    -- Force achievement check
    rankings.check_achievements(requesting_player.index, utils)
    
    -- Refresh player achievements after check
    player_achievements = storage.players[requesting_player.index].achievements or {}
    
    -- Show current stats for debugging
    local stats = storage.players[requesting_player.index]
    content.add{
        type = "label",
        caption = {"gui.debug-current-stats", 
                   string.format("%.1f", stats.distance_traveled or 0),
                   tostring(stats.total_crafted or 0),
                   tostring(stats.enemies_killed or 0),
                   tostring(stats.buildings_built or 0),
                   string.format("%.1f", (stats.playtime_ticks or 0) / 216000)},
        style = "caption_label"
    }
    
    content.add{type = "line"}
    
    local achievements_table = content.add{
        type = "table",
        column_count = 3
    }
    
    -- Headers
    achievements_table.add{type = "label", caption = {"gui.achievement-status"}, style = "bold_label"}
    achievements_table.add{type = "label", caption = {"gui.achievement-name"}, style = "bold_label"}
    achievements_table.add{type = "label", caption = {"gui.achievement-description"}, style = "bold_label"}
    
    -- Show all achievements
    for _, achievement in pairs(rankings.ACHIEVEMENTS) do
        local completed = player_achievements[achievement.id] ~= nil
        
        -- Status
        local status_label = achievements_table.add{type = "label", caption = completed and "✅" or "⏳"}
        if completed then
            status_label.style = "kelnmaar_achievement_completed"
        else
            status_label.style = "kelnmaar_achievement_pending"
        end
        
        -- Name
        local name_label = achievements_table.add{type = "label", caption = {"achievement." .. achievement.name}}
        if completed then
            name_label.style = "kelnmaar_achievement_completed"
        else
            name_label.style = "kelnmaar_achievement_pending"
        end
        
        -- Description/Progress
        local desc_text = {"achievement." .. achievement.name .. "-desc"}
        if not completed then
            -- Show progress for pending achievements
            local current_value = 0
            local stats = storage.players[requesting_player.index]
            
            if achievement.type == "distance" then
                current_value = stats.distance_traveled or 0
            elseif achievement.type == "crafted" then
                current_value = stats.total_crafted or 0
            elseif achievement.type == "combat" then
                current_value = stats.enemies_killed or 0
            elseif achievement.type == "building" then
                current_value = stats.buildings_built or 0
            elseif achievement.type == "survival" or achievement.type == "no_deaths" then
                current_value = stats.playtime_ticks or 0
            elseif achievement.type == "planets" then
                current_value = 0
                if stats.planets_visited then
                    for planet_name, _ in pairs(stats.planets_visited) do
                        -- Исключаем платформы (имя начинается с 'platform')
                        if not string.match(planet_name, "^platform") then
                            current_value = current_value + 1
                        end
                    end
                end
            end
            
            local progress_text = string.format(" (%d/%d)", current_value, achievement.threshold)
            desc_text = {"", {"achievement." .. achievement.name .. "-desc"}, progress_text}
        end
        
        local desc_label = achievements_table.add{type = "label", caption = desc_text}
        if completed then
            desc_label.style = "kelnmaar_achievement_completed"
        else
            desc_label.style = "kelnmaar_achievement_pending"
        end
    end
    
    -- Summary
    content.add{type = "line"}
    local completed_count = 0
    for _ in pairs(player_achievements) do
        completed_count = completed_count + 1
    end
    
    content.add{
        type = "label",
        caption = {"gui.achievements-summary", completed_count, #rankings.ACHIEVEMENTS},
        style = "bold_label"
    }
    
    -- Show earned achievements
    if completed_count > 0 then
        content.add{type = "line"}
        content.add{
            type = "label",
            caption = {"gui.earned-achievements-title"},
            style = "kelnmaar_chart_title"
        }
        
        local earned_table = content.add{
            type = "table",
            column_count = 2
        }
        
        for achievement_id, earned_tick in pairs(player_achievements) do
            -- Find achievement info
            local achievement_info = nil
            for _, ach in pairs(rankings.ACHIEVEMENTS) do
                if ach.id == achievement_id then
                    achievement_info = ach
                    break
                end
            end
            
            if achievement_info then
                earned_table.add{
                    type = "label",
                    caption = {"", "✅ ", {"achievement." .. achievement_info.name}},
                    style = "kelnmaar_achievement_completed"
                }
                
                local ticks_to_hours = math.floor(earned_tick / 216000 * 10) / 10
                earned_table.add{
                    type = "label", 
                    caption = {"gui.achievement-earned-at", string.format("%.1f", ticks_to_hours)},
                    style = "caption_label"
                }
            end
        end
    else
        content.add{type = "line"}
        content.add{
            type = "label",
            caption = {"gui.no-achievements-yet"},
            style = "caption_label"
        }
    end
    
    -- Close button
    local close_flow = frame.add{type = "flow", direction = "horizontal"}
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_achievements",
        caption = {"gui.close"}
    }
end

-- Show player comparison window
function gui.show_player_comparison(requesting_player, target_player_index, utils, rankings)
    local target_player = game.players[target_player_index]
    if not target_player or not target_player.valid then
        return
    end
    local requesting_player_index = requesting_player.index

    if requesting_player.gui.screen.comparison_frame then
        requesting_player.gui.screen.comparison_frame.destroy()
    end

    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "comparison_frame",
        caption = {"gui.comparison-title", requesting_player.name, target_player.name},
        direction = "vertical"
    }
    
    frame.auto_center = true
    
    local content = frame.add{
        type = "scroll-pane"
    }
    content.style.minimal_width = 500
    content.style.maximal_height = 600
    
    utils.init_player(requesting_player_index)
    utils.init_player(target_player_index)
    
    local stats1 = storage.players[requesting_player_index]
    local stats2 = storage.players[target_player_index]
    
    local rank1, score1 = rankings.calculate_player_rank(stats1)
    local rank2, score2 = rankings.calculate_player_rank(stats2)
    
    -- Comparison table
    local comp_table = content.add{
        type = "table",
        column_count = 3
    }
    
    -- Headers
    comp_table.add{type = "label", caption = {"gui.category"}, style = "bold_label"}
    comp_table.add{type = "label", caption = requesting_player.name, style = "bold_label"}
    comp_table.add{type = "label", caption = target_player.name, style = "bold_label"}
    
    -- Rank comparison
    comp_table.add{type = "label", caption = {"gui.current-rank"}}
    comp_table.add{type = "label", caption = rank1.icon .. " " .. rank1.name,
        style = score1 > score2 and "bold_label" or "label"}
    comp_table.add{type = "label", caption = rank2.icon .. " " .. rank2.name,
        style = score2 > score1 and "bold_label" or "label"}
    
    -- Score comparison
    comp_table.add{type = "label", caption = {"gui.total-score"}}
    comp_table.add{type = "label", caption = tostring(score1),
        style = score1 > score2 and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(score2),
        style = score2 > score1 and "bold_label" or "label"}
    
    -- Distance comparison
    comp_table.add{type = "label", caption = {"gui.distance"}}
    comp_table.add{type = "label", caption = string.format("%.2f", stats1.distance_traveled),
        style = stats1.distance_traveled > stats2.distance_traveled and "bold_label" or "label"}
    comp_table.add{type = "label", caption = string.format("%.2f", stats2.distance_traveled),
        style = stats2.distance_traveled > stats1.distance_traveled and "bold_label" or "label"}
    
    -- Crafted items comparison
    comp_table.add{type = "label", caption = {"gui.total-crafted"}}
    comp_table.add{type = "label", caption = tostring(stats1.total_crafted),
        style = stats1.total_crafted > stats2.total_crafted and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.total_crafted),
        style = stats2.total_crafted > stats1.total_crafted and "bold_label" or "label"}
    
    -- Combat comparison
    comp_table.add{type = "label", caption = {"gui.enemies-killed"}}
    comp_table.add{type = "label", caption = tostring(stats1.enemies_killed),
        style = stats1.enemies_killed > stats2.enemies_killed and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.enemies_killed),
        style = stats2.enemies_killed > stats1.enemies_killed and "bold_label" or "label"}
    
    -- Deaths comparison (lower is better)
    comp_table.add{type = "label", caption = {"gui.deaths"}}
    comp_table.add{type = "label", caption = tostring(stats1.deaths),
        style = stats1.deaths < stats2.deaths and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.deaths),
        style = stats2.deaths < stats1.deaths and "bold_label" or "label"}
    
    -- Buildings comparison
    comp_table.add{type = "label", caption = {"gui.buildings-built"}}
    comp_table.add{type = "label", caption = tostring(stats1.buildings_built),
        style = stats1.buildings_built > stats2.buildings_built and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.buildings_built),
        style = stats2.buildings_built > stats1.buildings_built and "bold_label" or "label"}
    
    -- Playtime comparison
    comp_table.add{type = "label", caption = {"gui.playtime"}}
    comp_table.add{type = "label", caption = utils.format_playtime(stats1.playtime_ticks)}
    comp_table.add{type = "label", caption = utils.format_playtime(stats2.playtime_ticks)}
    
    -- Planets comparison
    local planets1 = 0
    local planets2 = 0
    if stats1.planets_visited then
        for _ in pairs(stats1.planets_visited) do planets1 = planets1 + 1 end
    end
    if stats2.planets_visited then
        for _ in pairs(stats2.planets_visited) do planets2 = planets2 + 1 end
    end
    
    comp_table.add{type = "label", caption = {"gui.planets"}}
    
    -- Player 1 planets (icons)
    utils.create_planets_flow(comp_table, stats1.planets_visited)
    
    -- Player 2 planets (icons)  
    utils.create_planets_flow(comp_table, stats2.planets_visited)
    
    -- Close button
    local close_flow = frame.add{type = "flow", direction = "horizontal"}
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_comparison",
        caption = {"gui.close"}
    }
end

return gui 