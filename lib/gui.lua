-- lib/gui.lua
-- Интерфейс и GUI функции

local gui = {}

-- Create visual chart with horizontal progress bars (fixed duplicate data issue)
function gui.create_visual_chart(parent, data, title, color)
    local chart_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_chart_frame"
    }
    
    -- Chart title
    chart_frame.add{
        type = "label",
        caption = title,
        style = "kelnmaar_chart_title"
    }
    
    if not data or #data == 0 then
        chart_frame.add{
            type = "label",
            caption = "No data available",
            style = "caption_label"
        }
        return chart_frame
    end
    
    -- Limit to last 10 unique data points (avoid duplicates)
    local unique_data = {}
    local seen_values = {}
    
    -- Process data from newest to oldest to get latest unique values
    for i = #data, 1, -1 do
        local value = data[i]
        local rounded_value = math.floor(value * 10) / 10  -- Round to 1 decimal
        if not seen_values[rounded_value] and #unique_data < 10 then
            table.insert(unique_data, 1, value)  -- Insert at beginning to maintain order
            seen_values[rounded_value] = true
        end
    end
    
    if #unique_data == 0 then
        chart_frame.add{
            type = "label",
            caption = "No unique data points",
            style = "caption_label"
        }
        return chart_frame
    end
    
    -- Find max value for scaling
    local max_val = 0
    local min_val = unique_data[1]
    for _, value in ipairs(unique_data) do
        if value > max_val then max_val = value end
        if value < min_val then min_val = value end
    end
    
    if max_val == min_val then max_val = min_val + 1 end
    
    -- Create horizontal line chart using progress bars
    local chart_content = chart_frame.add{
        type = "flow",
        direction = "vertical"
    }
    
    -- Show trend with horizontal bars representing progression
    for i, value in ipairs(unique_data) do
        local progress = (value - min_val) / (max_val - min_val)
        if max_val == min_val then progress = 1 end
        
        local point_flow = chart_content.add{
            type = "flow",
            direction = "horizontal"
        }
        point_flow.style.vertical_align = "center"
        
        -- Point number/index
        point_flow.add{
            type = "label",
            caption = string.format("%2d:", i),
            style = "bold_label"
        }
        
        -- Progress bar (horizontal representation)
        local progress_bar = point_flow.add{
            type = "progressbar",
            value = progress,
            style = "kelnmaar_chart_bar"
        }
        progress_bar.style.width = 150
        progress_bar.style.height = 20
        progress_bar.style.color = color
        
        -- Value label
        point_flow.add{
            type = "label",
            caption = string.format(" %.1f", value),
            style = "kelnmaar_chart_value"
        }
        
        -- Trend indicator (if not first point)
        if i > 1 then
            local prev_value = unique_data[i-1]
            local diff = value - prev_value
            local trend_icon = ""
            local trend_color = {r=0.8, g=0.8, b=0.8}
            
            if diff > 0 then
                trend_icon = " ↗"
                trend_color = {r=0.2, g=0.8, b=0.2}
            elseif diff < 0 then
                trend_icon = " ↘"
                trend_color = {r=0.8, g=0.2, b=0.2}
            else
                trend_icon = " →"
            end
            
            local trend_label = point_flow.add{
                type = "label",
                caption = trend_icon,
                style = "bold_label"
            }
            trend_label.style.font_color = trend_color
        end
    end
    
    -- Summary stats
    chart_content.add{type = "line"}
    local stats_flow = chart_content.add{
        type = "flow",
        direction = "horizontal"
    }
    
    stats_flow.add{
        type = "label",
        caption = string.format("Min: %.1f", min_val),
        style = "caption_label"
    }
    
    stats_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    
    stats_flow.add{
        type = "label",
        caption = string.format("Max: %.1f", max_val),
        style = "caption_label"
    }
    
    return chart_frame
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
    utils.init_player(target_player_index)
    local temp_stats = storage.players[target_player_index]
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
    local progress_frame = content.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_info_frame"
    }
    
    progress_frame.add{
        type = "label",
        caption = "Rank Progress",
        style = "kelnmaar_chart_title"
    }
    
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
    
    if next_rank then
        local progress = math.min(1.0, current_score / next_rank.min_score)
        
        local progress_bar = progress_frame.add{
            type = "progressbar",
            value = progress,
            style = "kelnmaar_rank_progress"
        }
        
        local details_flow = progress_frame.add{
            type = "flow",
            direction = "horizontal"
        }
        
        details_flow.add{
            type = "label",
            caption = "Current: " .. current_rank.icon .. " " .. current_rank.name,
            style = "label"
        }
        
        details_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
        
        details_flow.add{
            type = "label",
            caption = "Next: " .. next_rank.icon .. " " .. next_rank.name,
            style = "label"
        }
        
        details_flow.add{
            type = "label",
            caption = "Score: " .. current_score .. " / " .. next_rank.min_score,
            style = "label"
        }
        
        -- Points needed
        local points_needed = next_rank.min_score - current_score
        progress_frame.add{
            type = "label",
            caption = "Points needed: " .. points_needed,
            style = "caption_label"
        }
        
    else
        progress_frame.add{
            type = "label",
            caption = "🎉 Maximum Rank Achieved! 🎉",
            style = "kelnmaar_chart_title"
        }
        
        progress_frame.add{
            type = "label",
            caption = current_rank.icon .. " " .. current_rank.name .. " (Score: " .. current_score .. ")",
            style = "bold_label"
        }
    end
    
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
        local charts_table = content.add{
            type = "table",
            column_count = 2
        }
        
        -- Distance chart
        if #history.distance > 0 then
            gui.create_visual_chart(charts_table, history.distance, "Distance Traveled", {r=0.2, g=0.8, b=0.2})
        end
        
        -- Score chart
        if #history.score > 0 then
            gui.create_visual_chart(charts_table, history.score, "Player Score", {r=0.8, g=0.6, b=0.1})
        end
        
        -- Crafted items chart
        if #history.crafted > 0 then
            gui.create_visual_chart(charts_table, history.crafted, "Items Crafted", {r=0.1, g=0.6, b=0.8})
        end
        
        -- Combat chart
        if #history.combat > 0 then
            gui.create_visual_chart(charts_table, history.combat, "Enemies Killed", {r=0.8, g=0.2, b=0.2})
        end
        
        -- Playtime chart (full width)
        content.add{type = "line"}
        if #history.playtime > 0 then
            gui.create_visual_chart(content, history.playtime, "Playtime (Hours)", {r=0.6, g=0.2, b=0.8})
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
    
    local player_achievements = storage.players[requesting_player.index].achievements or {}
    
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
                    for _ in pairs(stats.planets_visited) do
                        current_value = current_value + 1
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