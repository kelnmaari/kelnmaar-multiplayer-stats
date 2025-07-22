-- Multiplayer Statistics Mod
-- Tracking distance, crafted items and active crafts for players

-- No init function needed in Factorio 2.0 with storage table

-- Achievement definitions
local ACHIEVEMENTS = {
    -- Distance achievements
    {id = "distance_1k", type = "distance", threshold = 1000, name = "first-steps"},
    {id = "distance_10k", type = "distance", threshold = 10000, name = "explorer"},
    {id = "distance_50k", type = "distance", threshold = 50000, name = "wanderer"},
    {id = "distance_100k", type = "distance", threshold = 100000, name = "nomad"},
    
    -- Crafting achievements
    {id = "craft_100", type = "crafted", threshold = 100, name = "apprentice-crafter"},
    {id = "craft_1k", type = "crafted", threshold = 1000, name = "skilled-crafter"},
    {id = "craft_10k", type = "crafted", threshold = 10000, name = "master-crafter"},
    {id = "craft_100k", type = "crafted", threshold = 100000, name = "legendary-crafter"},
    
    -- Combat achievements
    {id = "kills_10", type = "combat", threshold = 10, name = "first-blood"},
    {id = "kills_100", type = "combat", threshold = 100, name = "soldier"},
    {id = "kills_1k", type = "combat", threshold = 1000, name = "warrior"},
    {id = "kills_5k", type = "combat", threshold = 5000, name = "slayer"},
    
    -- Building achievements
    {id = "build_50", type = "building", threshold = 50, name = "builder"},
    {id = "build_500", type = "building", threshold = 500, name = "architect"},
    {id = "build_2k", type = "building", threshold = 2000, name = "engineer"},
    {id = "build_10k", type = "building", threshold = 10000, name = "industrial-master"},
    
    -- Survival achievements
    {id = "no_deaths_1h", type = "survival", threshold = 216000, name = "survivor"},
    {id = "no_deaths_10h", type = "survival", threshold = 2160000, name = "hardcore"},
    
    -- Space Age achievements  
    {id = "space_explorer", type = "planets", threshold = 2, name = "space-explorer"},
    {id = "galactic_explorer", type = "planets", threshold = 4, name = "galactic-explorer"},
    {id = "universe_master", type = "planets", threshold = 5, name = "universe-master"}
}

-- Initialize player data
local function init_player(player_index)
    if not storage.players[player_index] then
        storage.players[player_index] = {
            distance_traveled = 0,
            last_position = nil,
            crafted_items = {},
            total_crafted = 0,
            -- Combat stats
            enemies_killed = 0,
            deaths = 0,
            damage_taken = 0,
            -- Building stats
            buildings_built = 0,
            buildings_destroyed = 0,
            -- Mining stats
            resources_mined = {
                ["iron-ore"] = 0,
                ["copper-ore"] = 0,
                ["coal"] = 0,
                ["stone"] = 0,
                ["crude-oil"] = 0,
                ["uranium-ore"] = 0,
                ["wood"] = 0
            },
            -- Playtime stats
            playtime_ticks = 0,
            last_active_tick = 0,
            -- Space Age stats
            planets_visited = {},
            space_travel_distance = 0,
            current_surface = nil,
            last_space_position = nil,
            -- Achievement tracking
            achievements = {},
            last_rank = "recruit",
            last_survivor_tick = 0
        }
    end
    
    if not storage.gui_state[player_index] then
        storage.gui_state[player_index] = {
            gui_open = false,
            gui_collapsed = false
        }
    end
end

-- Calculate distance between two positions
local function calculate_distance(pos1, pos2)
    local dx = pos1.x - pos2.x
    local dy = pos1.y - pos2.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Rank system configuration
local RANKS = {
    -- Начальные звания
    {name = "recruit", min_score = 0, icon = "🟫"},
    {name = "private", min_score = 150, icon = "🟫"},
    {name = "private-first-class", min_score = 350, icon = "🟫"},
    
    -- Сержантские звания
    {name = "corporal", min_score = 600, icon = "🟨"},
    {name = "sergeant", min_score = 900, icon = "🟨"},
    {name = "staff-sergeant", min_score = 1300, icon = "🟨"},
    {name = "sergeant-major", min_score = 1800, icon = "🟨"},
    
    -- Офицерские звания
    {name = "second-lieutenant", min_score = 2500, icon = "🟩"},
    {name = "lieutenant", min_score = 3300, icon = "🟩"},
    {name = "captain", min_score = 4300, icon = "🟩"},
    {name = "major", min_score = 5500, icon = "🟩"},
    
    -- Старшие офицеры
    {name = "lieutenant-colonel", min_score = 7000, icon = "🟦"},
    {name = "colonel", min_score = 8800, icon = "🟦"},
    {name = "brigadier", min_score = 10800, icon = "🟦"},
    
    -- Генералы
    {name = "major-general", min_score = 13200, icon = "🟪"},
    {name = "lieutenant-general", min_score = 16000, icon = "🟪"},
    {name = "general", min_score = 19200, icon = "🟪"},
    {name = "field-marshal", min_score = 23000, icon = "🟪"},
    
    -- Легендарные звания
    {name = "war-hero", min_score = 27500, icon = "🟥"},
    {name = "legend", min_score = 32500, icon = "🟥"},
    {name = "myth", min_score = 38000, icon = "⭐"},
    {name = "godlike", min_score = 45000, icon = "👑"}
}

-- Calculate player rank based on statistics
local function calculate_player_rank(stats)
    local score = 0
    
    -- Basic stats with improved scaling
    local distance = stats.distance_traveled or 0
    local crafted = stats.total_crafted or 0
    local enemies = stats.enemies_killed or 0
    local deaths = stats.deaths or 0
    local built = stats.buildings_built or 0
    local playtime_hours = math.floor((stats.playtime_ticks or 0) / 216000)
    
    -- Distance score with scaling (gets harder for high distances)
    if distance <= 1000 then
        score = score + math.floor(distance / 5)  -- 1 point per 5 tiles up to 1000
    elseif distance <= 10000 then
        score = score + 200 + math.floor((distance - 1000) / 10)  -- Slower after 1000
    else
        score = score + 1100 + math.floor((distance - 10000) / 20)  -- Even slower after 10000
    end
    
    -- Crafting score with scaling
    if crafted <= 1000 then
        score = score + math.floor(crafted / 5)  -- 1 point per 5 items up to 1000
    elseif crafted <= 10000 then
        score = score + 200 + math.floor((crafted - 1000) / 15)  -- Slower scaling
    else
        score = score + 800 + math.floor((crafted - 10000) / 25)  -- Much slower after 10k
    end
    
    -- Combat efficiency scoring (K/D ratio matters for high ranks)
    local kill_score = enemies * 8  -- 8 points per enemy
    local death_penalty = deaths * 15  -- -15 points per death
    local combat_ratio = deaths > 0 and (enemies / deaths) or (enemies > 0 and enemies or 1)
    
    -- Bonus for good K/D ratio
    if combat_ratio >= 10 and enemies >= 100 then
        kill_score = kill_score * 1.5  -- 50% bonus for excellent K/D
    elseif combat_ratio >= 5 and enemies >= 50 then
        kill_score = kill_score * 1.25  -- 25% bonus for good K/D
    end
    
    score = score + kill_score - death_penalty
    
    -- Building score with diminishing returns
    if built <= 500 then
        score = score + built * 3  -- 3 points per building up to 500
    elseif built <= 2000 then
        score = score + 1500 + (built - 500) * 2  -- 2 points per building 500-2000
    else
        score = score + 4500 + (built - 2000) * 1  -- 1 point per building after 2000
    end
    
    -- Mining score with resource variety bonus
    local total_mined = 0
    local resource_types = 0
    if stats.resources_mined then
        for _, count in pairs(stats.resources_mined) do
            if count > 0 then
                total_mined = total_mined + count
                resource_types = resource_types + 1
            end
        end
    end
    score = score + math.floor(total_mined / 50)
    score = score + resource_types * 20  -- Bonus for mining variety
    
    -- Playtime scoring with efficiency bonus
    score = score + playtime_hours * 5  -- 5 points per hour
    
    -- Efficiency bonus (high activity per hour)
    if playtime_hours > 0 then
        local activity_per_hour = (crafted + enemies + built) / playtime_hours
        if activity_per_hour >= 1000 then
            score = score + math.floor(activity_per_hour / 10)  -- Efficiency bonus
        end
    end
    
    -- Space Age scoring with exploration bonus
    local planet_count = 0
    if stats.planets_visited then
        for _ in pairs(stats.planets_visited) do
            planet_count = planet_count + 1
        end
    end
    
    -- Progressive planet bonus
    if planet_count >= 1 then score = score + 100 end  -- First planet
    if planet_count >= 2 then score = score + 150 end  -- Second planet  
    if planet_count >= 3 then score = score + 200 end  -- Third planet
    if planet_count >= 4 then score = score + 300 end  -- Fourth planet
    if planet_count >= 5 then score = score + 500 end  -- Fifth+ planets
    
    -- Space travel distance bonus
    local space_distance = stats.space_travel_distance or 0
    score = score + math.floor(space_distance / 50)  -- 1 point per 50 tiles in space
    
    -- Legendary tier requirements (additional criteria for top ranks)
    local legendary_bonus = 0
    if score >= 25000 then  -- Only for very high scores
        -- Must have significant achievements in all areas
        if distance >= 50000 and crafted >= 50000 and enemies >= 1000 and 
           built >= 5000 and planet_count >= 4 and playtime_hours >= 100 then
            legendary_bonus = legendary_bonus + 2000  -- Well-rounded legend bonus
        end
        
        -- Combat mastery bonus
        if enemies >= 2000 and combat_ratio >= 15 then
            legendary_bonus = legendary_bonus + 1500  -- Combat legend
        end
        
        -- Builder mastery bonus  
        if built >= 10000 and crafted >= 100000 then
            legendary_bonus = legendary_bonus + 1500  -- Construction legend
        end
        
        -- Explorer mastery bonus
        if distance >= 100000 and planet_count >= 5 and space_distance >= 20000 then
            legendary_bonus = legendary_bonus + 1500  -- Explorer legend
        end
    end
    
    score = score + legendary_bonus
    
    -- Ensure score is not negative
    score = math.max(0, score)
    
    -- Find appropriate rank
    for i = #RANKS, 1, -1 do
        if score >= RANKS[i].min_score then
            return RANKS[i], score
        end
    end
    
    return RANKS[1], score -- Default to recruit
end

-- Update player distance
local function update_player_distance(player)
    local player_index = player.index
    init_player(player_index)
    
    local current_pos = player.position
    local last_pos = storage.players[player_index].last_position
    
    if last_pos and player.character then
        local distance = calculate_distance(current_pos, last_pos)
        storage.players[player_index].distance_traveled = 
            storage.players[player_index].distance_traveled + distance
        
        -- Track space travel distance if in space
        if player.surface.name:find("space") then
            storage.players[player_index].space_travel_distance = 
                storage.players[player_index].space_travel_distance + distance
        end
    end
    
    storage.players[player_index].last_position = current_pos
end

-- Update player playtime and surface tracking
local function update_player_status(player)
    local player_index = player.index
    init_player(player_index)
    
    local stats = storage.players[player_index]
    local current_tick = game.tick
    
    -- Update playtime if player was active
    if stats.last_active_tick > 0 then
        stats.playtime_ticks = stats.playtime_ticks + (current_tick - stats.last_active_tick)
    end
    stats.last_active_tick = current_tick
    
    -- Track visited planets
    local surface_name = player.surface.name
    if not stats.planets_visited[surface_name] then
        stats.planets_visited[surface_name] = current_tick
    end
    
    -- Update current surface
    stats.current_surface = surface_name
end

-- Format playtime from ticks to readable string
local function format_playtime(ticks)
    local seconds = math.floor(ticks / 60)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    
    seconds = seconds % 60
    minutes = minutes % 60
    
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- Show achievement notification
local function show_achievement_notification(player, achievement_name)
    -- Personal chat message to the player
    local personal_message = {"message.personal-achievement-unlocked", 
        "🏆", 
        {"achievement." .. achievement_name}
    }
    player.print(personal_message, {color = {r = 0, g = 1, b = 0}})
    
    -- Chat message for all players (if enabled)
    if settings.global["multiplayer-stats-broadcast-achievements"] and
       settings.global["multiplayer-stats-broadcast-achievements"].value then
        game.print({"message.achievement-unlocked", player.name, {"achievement." .. achievement_name}}, {color = {r = 0, g = 1, b = 0}})
    end
end

-- Show rank promotion notification
local function show_rank_promotion(player, old_rank, new_rank, score)
    -- Personal chat message to the player
    local personal_message = {"message.personal-rank-promotion", 
        new_rank.icon, 
        {"gui.rank-" .. new_rank.name}, 
        score
    }
    player.print(personal_message, {color = {r = 0, g = 1, b = 0}})
    
    -- Chat message for all players (if enabled)
    if settings.global["multiplayer-stats-broadcast-promotions"] and
       settings.global["multiplayer-stats-broadcast-promotions"].value then
        game.print({"message.rank-promotion", player.name, {"gui.rank-" .. old_rank.name}, {"gui.rank-" .. new_rank.name}}, {color = {r = 0, g = 1, b = 0}})
    end
end

-- Check for new achievements
local function check_achievements(player_index)
    local player = game.players[player_index]
    local stats = storage.players[player_index]
    
    for _, achievement in pairs(ACHIEVEMENTS) do
        if not stats.achievements[achievement.id] then
            local unlocked = false
            
            if achievement.type == "distance" and stats.distance_traveled >= achievement.threshold then
                unlocked = true
            elseif achievement.type == "crafted" and stats.total_crafted >= achievement.threshold then
                unlocked = true
            elseif achievement.type == "combat" and stats.enemies_killed >= achievement.threshold then
                unlocked = true
            elseif achievement.type == "building" and stats.buildings_built >= achievement.threshold then
                unlocked = true
            elseif achievement.type == "survival" then
                -- Check if survival achievements are enabled
                if settings.global["multiplayer-stats-enable-survival-achievements"] and
                   settings.global["multiplayer-stats-enable-survival-achievements"].value then
                    local ticks_since_death = game.tick - stats.last_survivor_tick
                    if ticks_since_death >= achievement.threshold then
                        unlocked = true
                    end
                end
            elseif achievement.type == "planets" then
                local planet_count = 0
                for _ in pairs(stats.planets_visited) do
                    planet_count = planet_count + 1
                end
                if planet_count >= achievement.threshold then
                    unlocked = true
                end
            end
            
            if unlocked then
                stats.achievements[achievement.id] = game.tick
                show_achievement_notification(player, achievement.name)
                
                -- Broadcast achievement if enabled
                if settings.global["multiplayer-stats-broadcast-achievements"] and
                   settings.global["multiplayer-stats-broadcast-achievements"].value then
                    game.print({"message.achievement-unlocked", player.name, {"achievement." .. achievement.name}})
                end
            end
        end
    end
    
    -- Check for rank promotion
    local current_rank, score = calculate_player_rank(stats)
    if current_rank.name ~= stats.last_rank then
        local old_rank = nil
        for _, rank in pairs(RANKS) do
            if rank.name == stats.last_rank then
                old_rank = rank
                break
            end
        end
        
        if old_rank then
            show_rank_promotion(player, old_rank, current_rank, score)
        end
        stats.last_rank = current_rank.name
    end
end

-- Create rankings window
local function show_rankings(requesting_player)
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
    frame.style.minimal_width = 600
    frame.style.maximal_height = 500
    
    local content = frame.add{
        type = "scroll-pane"
    }
    
    -- Get all player stats for ranking
    local player_stats = {}
    for _, game_player in pairs(game.players) do
        if storage.players[game_player.index] then
            init_player(game_player.index)
            table.insert(player_stats, {
                player = game_player,
                stats = storage.players[game_player.index]
            })
        end
    end
    
    -- Rankings by different categories
    local categories = {
        {name = "score", title = "gui.ranking-score", sort_func = function(a, b) 
            local rank_a = calculate_player_rank(a.stats)
            local rank_b = calculate_player_rank(b.stats)
            local _, score_a = calculate_player_rank(a.stats)
            local _, score_b = calculate_player_rank(b.stats)
            return score_a > score_b
        end},
        {name = "distance", title = "gui.ranking-distance", sort_func = function(a, b) 
            return a.stats.distance_traveled > b.stats.distance_traveled 
        end},
        {name = "crafted", title = "gui.ranking-crafted", sort_func = function(a, b) 
            return a.stats.total_crafted > b.stats.total_crafted 
        end},
        {name = "combat", title = "gui.ranking-combat", sort_func = function(a, b) 
            return a.stats.enemies_killed > b.stats.enemies_killed 
        end},
        {name = "building", title = "gui.ranking-building", sort_func = function(a, b) 
            return a.stats.buildings_built > b.stats.buildings_built 
        end}
    }
    
    for _, category in pairs(categories) do
        content.add{
            type = "label",
            caption = {category.title},
            style = "heading_2_label"
        }
        
        -- Sort players for this category
        local sorted_players = {}
        for _, player_data in pairs(player_stats) do
            table.insert(sorted_players, player_data)
        end
        table.sort(sorted_players, category.sort_func)
        
        local ranking_table = content.add{
            type = "table",
            column_count = 4
        }
        
        -- Headers
        ranking_table.add{type = "label", caption = {"gui.rank-position"}, style = "bold_label"}
        ranking_table.add{type = "label", caption = {"gui.player-name"}, style = "bold_label"}
        ranking_table.add{type = "label", caption = {"gui.player-rank"}, style = "bold_label"}
        ranking_table.add{type = "label", caption = {"gui.value"}, style = "bold_label"}
        
        -- Show top 5
        for i = 1, math.min(5, #sorted_players) do
            local player_data = sorted_players[i]
            local player = player_data.player
            local stats = player_data.stats
            
            -- Position
            ranking_table.add{type = "label", caption = "#" .. i}
            
            -- Player name
            ranking_table.add{type = "label", caption = player.name}
            
            -- Player rank
            local rank = calculate_player_rank(stats)
            local rank_flow = ranking_table.add{type = "flow", direction = "horizontal"}
            rank_flow.add{type = "label", caption = rank.icon}
            rank_flow.add{type = "label", caption = {"gui.rank-" .. rank.name}}
            
            -- Value for this category
            local value = ""
            if category.name == "score" then
                local _, score = calculate_player_rank(stats)
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

-- Show achievements window
local function show_achievements(requesting_player)
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
    frame.style.minimal_width = 500
    frame.style.maximal_height = 600
    
    local content = frame.add{
        type = "scroll-pane"
    }
    
    -- Get player's achievements
    init_player(requesting_player.index)
    local player_achievements = storage.players[requesting_player.index].achievements or {}
    
    local achievements_table = content.add{
        type = "table",
        column_count = 3
    }
    
    -- Headers
    achievements_table.add{type = "label", caption = {"gui.achievement-status"}, style = "bold_label"}
    achievements_table.add{type = "label", caption = {"gui.achievement-name"}, style = "bold_label"}
    achievements_table.add{type = "label", caption = {"gui.achievement-description"}, style = "bold_label"}
    
    -- Show all achievements
    for _, achievement in pairs(ACHIEVEMENTS) do
        local unlocked = player_achievements[achievement.id] or false
        
        -- Status (icon)
        local status_icon = unlocked and "✅" or "❌"
        achievements_table.add{type = "label", caption = status_icon}
        
        -- Achievement name
        local name_label = achievements_table.add{type = "label", caption = {"achievement." .. achievement.name}}
        if unlocked then
            name_label.style = "bold_label"
        end
        
        -- Achievement description (showing progress if not unlocked)
        local description = ""
        local player_stats = storage.players[requesting_player.index]
        
        if achievement.type == "distance" then
            local current = math.floor(player_stats.distance_traveled or 0)
            description = unlocked and {"gui.achievement-completed"} or 
                         string.format("%d / %d", current, achievement.threshold)
        elseif achievement.type == "crafted" then
            local current = player_stats.total_crafted or 0
            description = unlocked and {"gui.achievement-completed"} or 
                         string.format("%d / %d", current, achievement.threshold)
        elseif achievement.type == "combat" then
            local current = player_stats.enemies_killed or 0
            description = unlocked and {"gui.achievement-completed"} or 
                         string.format("%d / %d", current, achievement.threshold)
        elseif achievement.type == "building" then
            local current = player_stats.buildings_built or 0
            description = unlocked and {"gui.achievement-completed"} or 
                         string.format("%d / %d", current, achievement.threshold)
        elseif achievement.type == "playtime" then
            local current_hours = math.floor((player_stats.playtime_ticks or 0) / 216000)
            description = unlocked and {"gui.achievement-completed"} or 
                         string.format("%d / %d ч", current_hours, achievement.threshold)
        elseif achievement.type == "survival" then
            description = unlocked and {"gui.achievement-completed"} or {"gui.achievement-survival-desc"}
        elseif achievement.type == "legendary" then
            local current = 0
            for item_name, counts in pairs(player_stats.crafted_items or {}) do
                for quality, count in pairs(counts) do
                    if quality == "legendary" then
                        current = current + count
                    end
                end
            end
            description = unlocked and {"gui.achievement-completed"} or 
                         string.format("%d / %d", current, achievement.threshold)
        else
            description = unlocked and {"gui.achievement-completed"} or {"gui.achievement-in-progress"}
        end
        
        achievements_table.add{type = "label", caption = description}
    end
    
    -- Stats summary
    local summary_flow = content.add{type = "flow", direction = "horizontal"}
    summary_flow.add{type = "label", caption = {"gui.achievements-summary"}, style = "heading_2_label"}
    
    local unlocked_count = 0
    for _, achievement in pairs(ACHIEVEMENTS) do
        if player_achievements[achievement.id] then
            unlocked_count = unlocked_count + 1
        end
    end
    
    summary_flow.add{type = "label", caption = string.format(" %d / %d", unlocked_count, #ACHIEVEMENTS), style = "bold_label"}
    
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
local function show_player_comparison(requesting_player, target_player_index)
    if requesting_player.gui.screen.comparison_frame then
        requesting_player.gui.screen.comparison_frame.destroy()
    end
    
    local target_player = game.players[target_player_index]
    
    local frame = requesting_player.gui.screen.add{
        type = "frame",
        name = "comparison_frame",
        caption = {"gui.comparison-title", requesting_player.name, target_player.name},
        direction = "vertical"
    }
    
    frame.auto_center = true
    frame.style.minimal_width = 500
    
    local content = frame.add{type = "scroll-pane"}
    content.style.maximal_height = 400
    
    init_player(requesting_player.index)
    init_player(target_player_index)
    
    local stats1 = storage.players[requesting_player.index]
    local stats2 = storage.players[target_player_index]
    local rank1, score1 = calculate_player_rank(stats1)
    local rank2, score2 = calculate_player_rank(stats2)
    
    -- Comparison table
    local comp_table = content.add{
        type = "table",
        column_count = 3
    }
    
    -- Headers
    comp_table.add{type = "label", caption = {"gui.category"}, style = "bold_label"}
    comp_table.add{type = "label", caption = requesting_player.name, style = "bold_label"}
    comp_table.add{type = "label", caption = target_player.name, style = "bold_label"}
    
    -- Overall Score
    comp_table.add{type = "label", caption = {"gui.total-score"}}
    comp_table.add{type = "label", caption = tostring(score1), style = score1 > score2 and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(score2), style = score2 > score1 and "bold_label" or "label"}
    
    -- Rank
    comp_table.add{type = "label", caption = {"gui.current-rank"}}
    local rank1_flow = comp_table.add{type = "flow", direction = "horizontal"}
    rank1_flow.add{type = "label", caption = rank1.icon}
    rank1_flow.add{type = "label", caption = {"gui.rank-" .. rank1.name}}
    
    local rank2_flow = comp_table.add{type = "flow", direction = "horizontal"}
    rank2_flow.add{type = "label", caption = rank2.icon}
    rank2_flow.add{type = "label", caption = {"gui.rank-" .. rank2.name}}
    
    -- Distance
    comp_table.add{type = "label", caption = {"gui.distance"}}
    comp_table.add{type = "label", caption = string.format("%.2f", stats1.distance_traveled), 
        style = stats1.distance_traveled > stats2.distance_traveled and "bold_label" or "label"}
    comp_table.add{type = "label", caption = string.format("%.2f", stats2.distance_traveled),
        style = stats2.distance_traveled > stats1.distance_traveled and "bold_label" or "label"}
    
    -- Crafted items
    comp_table.add{type = "label", caption = {"gui.total-crafted"}}
    comp_table.add{type = "label", caption = tostring(stats1.total_crafted),
        style = stats1.total_crafted > stats2.total_crafted and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.total_crafted),
        style = stats2.total_crafted > stats1.total_crafted and "bold_label" or "label"}
    
    -- Combat
    comp_table.add{type = "label", caption = {"gui.enemies-killed"}}
    comp_table.add{type = "label", caption = tostring(stats1.enemies_killed),
        style = stats1.enemies_killed > stats2.enemies_killed and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.enemies_killed),
        style = stats2.enemies_killed > stats1.enemies_killed and "bold_label" or "label"}
    
    -- Deaths
    comp_table.add{type = "label", caption = {"gui.deaths"}}
    comp_table.add{type = "label", caption = tostring(stats1.deaths),
        style = stats1.deaths < stats2.deaths and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.deaths),
        style = stats2.deaths < stats1.deaths and "bold_label" or "label"}
    
    -- Buildings
    comp_table.add{type = "label", caption = {"gui.buildings-built"}}
    comp_table.add{type = "label", caption = tostring(stats1.buildings_built),
        style = stats1.buildings_built > stats2.buildings_built and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(stats2.buildings_built),
        style = stats2.buildings_built > stats1.buildings_built and "bold_label" or "label"}
    
    -- Playtime
    comp_table.add{type = "label", caption = {"gui.playtime"}}
    comp_table.add{type = "label", caption = format_playtime(stats1.playtime_ticks)}
    comp_table.add{type = "label", caption = format_playtime(stats2.playtime_ticks)}
    
    -- Planets
    local planets1 = 0
    local planets2 = 0
    for _ in pairs(stats1.planets_visited or {}) do planets1 = planets1 + 1 end
    for _ in pairs(stats2.planets_visited or {}) do planets2 = planets2 + 1 end
    
    comp_table.add{type = "label", caption = {"gui.planets"}}
    comp_table.add{type = "label", caption = tostring(planets1),
        style = planets1 > planets2 and "bold_label" or "label"}
    comp_table.add{type = "label", caption = tostring(planets2),
        style = planets2 > planets1 and "bold_label" or "label"}
    
    -- Close button
    local close_flow = frame.add{type = "flow", direction = "horizontal"}
    close_flow.add{type = "empty-widget"}.style.horizontally_stretchable = true
    close_flow.add{
        type = "button",
        name = "close_comparison",
        caption = {"gui.close"}
    }
end

-- Create the main statistics GUI
local function create_stats_gui(player)
    local player_index = player.index
    

    
    -- Destroy existing GUI if present
    if player.gui.top.multiplayer_stats_frame then
        player.gui.top.multiplayer_stats_frame.destroy()

    end
    
    -- Main frame attached to top panel (near minimap)
    local frame = player.gui.top.add{
        type = "frame",
        name = "multiplayer_stats_frame",
        direction = "vertical",
        style = "inside_shallow_frame"
    }
    

    
    -- Title bar with controls
    local titlebar = frame.add{
        type = "flow",
        direction = "horizontal",
        style = "horizontal_flow"
    }
    
    -- Title
    titlebar.add{
        type = "label",
        caption = {"gui.stats-title"},
        style = "frame_title"
    }
    
    local spacer = titlebar.add{
        type = "empty-widget"
    }
    spacer.style.horizontally_stretchable = true
    
    -- Collapse/expand button
    local collapse_sprite = storage.gui_state[player_index].gui_collapsed and "utility/forward_arrow" or "utility/backward_arrow"
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
        sprite = "utility/close_black",
        style = "frame_action_button",
        tooltip = {"gui.close"}
    }
    
    -- Content area (only if not collapsed)
    if not storage.gui_state[player_index].gui_collapsed then
        local content = frame.add{
            type = "scroll-pane",
            name = "stats_content"
        }
        content.style.minimal_width = 400
        content.style.maximal_height = 300
        
        -- Player list
        local player_table = content.add{
            type = "table",
            name = "player_stats_table",
            column_count = 12  -- Увеличиваем для колонки звания
        }
    
    -- Headers
    player_table.add{type = "label", caption = {"gui.player-name"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.rank"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.distance"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.total-crafted"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.active-crafts"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.enemies-killed"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.deaths"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.damage-taken"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.buildings-built"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.playtime"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.planets"}, style = "bold_label"}
    player_table.add{type = "label", caption = {"gui.actions"}, style = "bold_label"}
    
    -- Fill player data
    for _, game_player in pairs(game.players) do
        if game_player.connected then
            init_player(game_player.index)
            local stats = storage.players[game_player.index]
            
            -- Player name
            player_table.add{
                type = "label", 
                caption = game_player.name
            }
            
            -- Player rank
            local rank, score = calculate_player_rank(stats)
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
            
            -- Distance (rounded to 2 decimal places)
            player_table.add{
                type = "label",
                caption = string.format("%.2f", stats.distance_traveled)
            }
            
            -- Total crafted items
            player_table.add{
                type = "label",
                caption = tostring(stats.total_crafted)
            }
            
            -- Active crafts with icons and counts (grouped by recipe, max 5 per row)
            local active_crafts = 0
            local recipe_counts = {}
            if game_player.character and game_player.character.crafting_queue then
                for _, recipe in pairs(game_player.character.crafting_queue) do
                    active_crafts = active_crafts + recipe.count
                    recipe_counts[recipe.recipe] = (recipe_counts[recipe.recipe] or 0) + recipe.count
                end
            end
            
            local active_flow = player_table.add{
                type = "flow",
                direction = "vertical"
            }
            
            if next(recipe_counts) then
                local current_row = active_flow.add{type = "flow", direction = "horizontal"}
                local items_in_row = 0
                
                for recipe_name, count in pairs(recipe_counts) do
                    if items_in_row >= 5 then
                        current_row = active_flow.add{type = "flow", direction = "horizontal"}
                        items_in_row = 0
                    end
                    
                    local recipe_flow = current_row.add{type = "flow", direction = "horizontal"}
                    
                    recipe_flow.add{
                        type = "sprite",
                        sprite = "recipe/" .. recipe_name,
                        tooltip = recipe_name .. ": " .. count
                    }
                    
                    recipe_flow.add{
                        type = "label",
                        caption = tostring(count),

                    }
                    
                    items_in_row = items_in_row + 1
                end
            else
                active_flow.add{
                    type = "label",
                    caption = "0"
                }
            end
            
            -- Enemies killed
            player_table.add{
                type = "label",
                caption = tostring(stats.enemies_killed or 0)
            }
            
            -- Deaths
            player_table.add{
                type = "label",
                caption = tostring(stats.deaths or 0)
            }
            
            -- Damage taken
            player_table.add{
                type = "label",
                caption = string.format("%.1f", stats.damage_taken or 0)
            }
            
            -- Buildings built
            player_table.add{
                type = "label",
                caption = tostring(stats.buildings_built or 0)
            }
            
            -- Playtime
            player_table.add{
                type = "label",
                caption = format_playtime(stats.playtime_ticks or 0)
            }
            
            -- Planets visited count
            local planets_count = 0
            if stats.planets_visited then
                for _ in pairs(stats.planets_visited) do
                    planets_count = planets_count + 1
                end
            end
            player_table.add{
                type = "label",
                caption = tostring(planets_count)
            }
            
            -- Action buttons flow
            local actions_flow = player_table.add{
                type = "flow",
                direction = "vertical"
            }
            
            actions_flow.add{
                type = "button",
                name = "show_player_details_" .. game_player.index,
                caption = {"gui.details"},
                style = "button"
            }
            
            actions_flow.add{
                type = "button", 
                name = "show_crafting_history_" .. game_player.index,
                caption = {"gui.crafting-history"},
                style = "button"
            }
            
            actions_flow.add{
                type = "button",
                name = "compare_with_" .. game_player.index,
                caption = {"gui.compare"},
                style = "button"
            }
        end
    end
    end -- End of collapsed check
    
    if storage.gui_state and storage.gui_state[player_index] then
        storage.gui_state[player_index].gui_open = true
    end
end

-- Update existing stats GUI with fresh data
local function update_stats_gui()
    for player_index, gui_state in pairs(storage.gui_state or {}) do
        if gui_state.gui_open then
            local player = game.players[player_index]
            if player and player.gui.top.multiplayer_stats_frame then
                local frame = player.gui.top.multiplayer_stats_frame
                local content = frame.stats_content
                if content and not gui_state.gui_collapsed then
                    local player_table = content.player_stats_table
                    if player_table then
                        -- Clear existing data (keep headers)
                        local children = player_table.children
                        for i = #children, 13, -1 do  -- Keep first 12 header elements
                            children[i].destroy()
                        end
                        
                        -- Refill with fresh data
                        for _, game_player in pairs(game.players) do
                            if game_player.connected then
                                init_player(game_player.index)
                                local stats = storage.players[game_player.index]
                                
                                -- Add all the same data as in create_stats_gui
                                -- Player name
                                player_table.add{type = "label", caption = game_player.name}
                                
                                -- Player rank
                                local rank, score = calculate_player_rank(stats)
                                local rank_flow = player_table.add{type = "flow", direction = "horizontal"}
                                rank_flow.add{type = "label", caption = rank.icon, tooltip = {"gui.rank-tooltip", {"gui.rank-" .. rank.name}, score}}
                                rank_flow.add{type = "label", caption = {"gui.rank-" .. rank.name}, style = "bold_label"}
                                
                                -- Distance
                                player_table.add{type = "label", caption = string.format("%.2f", stats.distance_traveled)}
                                
                                -- Total crafted
                                player_table.add{type = "label", caption = tostring(stats.total_crafted)}
                                
                                -- Active crafts with icons and counts (grouped by recipe, max 5 per row)
                                local active_crafts = 0
                                local recipe_counts = {}
                                if game_player.character and game_player.character.crafting_queue then
                                    for _, recipe in pairs(game_player.character.crafting_queue) do
                                        active_crafts = active_crafts + recipe.count
                                        recipe_counts[recipe.recipe] = (recipe_counts[recipe.recipe] or 0) + recipe.count
                                    end
                                end
                                
                                local active_flow = player_table.add{type = "flow", direction = "vertical"}
                                if next(recipe_counts) then
                                    local current_row = active_flow.add{type = "flow", direction = "horizontal"}
                                    local items_in_row = 0
                                    
                                    for recipe_name, count in pairs(recipe_counts) do
                                        if items_in_row >= 5 then
                                            current_row = active_flow.add{type = "flow", direction = "horizontal"}
                                            items_in_row = 0
                                        end
                                        
                                        local recipe_flow = current_row.add{type = "flow", direction = "horizontal"}
                                        recipe_flow.add{type = "sprite", sprite = "recipe/" .. recipe_name, tooltip = recipe_name .. ": " .. count}
                                        recipe_flow.add{type = "label", caption = tostring(count)}
                                        
                                        items_in_row = items_in_row + 1
                                    end
                                else
                                    active_flow.add{type = "label", caption = "0"}
                                end
                                
                                -- Other stats
                                player_table.add{type = "label", caption = tostring(stats.enemies_killed or 0)}
                                player_table.add{type = "label", caption = tostring(stats.deaths or 0)}
                                player_table.add{type = "label", caption = string.format("%.1f", stats.damage_taken or 0)}
                                player_table.add{type = "label", caption = tostring(stats.buildings_built or 0)}
                                player_table.add{type = "label", caption = format_playtime(stats.playtime_ticks or 0)}
                                
                                -- Planets count
                                local planets_count = 0
                                if stats.planets_visited then
                                    for _ in pairs(stats.planets_visited) do
                                        planets_count = planets_count + 1
                                    end
                                end
                                player_table.add{type = "label", caption = tostring(planets_count)}
                                
                                -- Action buttons flow
                                local actions_flow = player_table.add{type = "flow", direction = "vertical"}
                                actions_flow.add{type = "button", name = "show_player_details_" .. game_player.index, caption = {"gui.details"}, style = "button"}
                                actions_flow.add{type = "button", name = "show_crafting_history_" .. game_player.index, caption = {"gui.crafting-history"}, style = "button"}
                                actions_flow.add{type = "button", name = "compare_with_" .. game_player.index, caption = {"gui.compare"}, style = "button"}
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Create progress bar visualization
local function create_progress_bar(current, max_val, width)
    if max_val == 0 then max_val = 1 end
    local filled = math.floor((current / max_val) * width)
    local empty = width - filled
    local bar = string.rep("█", filled) .. string.rep("░", empty)
    return string.format("%s %d/%d (%.1f%%)", bar, current, max_val, (current/max_val)*100)
end

-- Create simple data visualization
local function create_stats_visualization(stats)
    local viz_data = {}
    
    -- Activity breakdown (pie chart simulation)
    local total_activity = (stats.total_crafted or 0) + (stats.enemies_killed or 0) + (stats.buildings_built or 0)
    if total_activity > 0 then
        local craft_pct = math.floor(((stats.total_crafted or 0) / total_activity) * 100)
        local combat_pct = math.floor(((stats.enemies_killed or 0) / total_activity) * 100)  
        local build_pct = 100 - craft_pct - combat_pct
        
        viz_data.activity_breakdown = {
            crafting = craft_pct,
            combat = combat_pct,
            building = build_pct
        }
    end
    
    -- Resource mining distribution
    local total_mined = 0
    if stats.resources_mined then
        for _, count in pairs(stats.resources_mined) do
            total_mined = total_mined + count
        end
        
        viz_data.mining_breakdown = {}
        for resource, count in pairs(stats.resources_mined) do
            if count > 0 and total_mined > 0 then
                viz_data.mining_breakdown[resource] = math.floor((count / total_mined) * 100)
            end
        end
    end
    
    -- Progress towards next rank
    local current_rank, current_score = calculate_player_rank(stats)
    local next_rank = nil
    for i, rank in pairs(RANKS) do
        if rank.name == current_rank.name and i < #RANKS then
            next_rank = RANKS[i + 1]
            break
        end
    end
    
    if next_rank then
        viz_data.rank_progress = {
            current = current_score,
            needed = next_rank.min_score,
            next_rank = next_rank
        }
    end
    
    return viz_data
end

-- Show detailed crafting info for a player
local function show_crafting_details(requesting_player, target_player_index)
    local target_player = game.players[target_player_index]
    
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
    
    init_player(target_player_index)
    local stats = storage.players[target_player_index]
    
    -- Player rank display
    local rank, score = calculate_player_rank(stats)
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
    
    -- Mining statistics
    content.add{type = "line"}
    content.add{
        type = "label", 
        caption = {"gui.mining-stats"}, 
        style = "bold_label"
    }
    
    local mining_table = content.add{
        type = "table",
        column_count = 4
    }
    
    if stats.resources_mined then
        for resource_name, count in pairs(stats.resources_mined) do
            if count > 0 and prototypes.item[resource_name] then
                mining_table.add{
                    type = "sprite",
                    sprite = "item/" .. resource_name
                }
                mining_table.add{
                    type = "label",
                    caption = string.format("%s: %d", 
                        prototypes.item[resource_name].localised_name or resource_name, 
                        count)
                }
            end
        end
    end
    
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
        
        for planet_name, _ in pairs(stats.planets_visited) do
            content.add{
                type = "label",
                caption = planet_name
            }
        end
    end
    
    -- Playtime
    content.add{type = "line"}
    content.add{
        type = "label",
        caption = {"gui.total-playtime-detail", format_playtime(stats.playtime_ticks or 0)},
        style = "bold_label"
    }
    
    -- Visualization section
    content.add{type = "line"}
    content.add{
        type = "label",
        caption = {"gui.statistics-visualization"},
        style = "bold_label"
    }
    
    local viz_data = create_stats_visualization(stats)
    
    -- Progress to next rank (only if user setting enabled)
    local user_settings = settings.get_player_settings(requesting_player.index)
    if viz_data.rank_progress and user_settings["multiplayer-stats-show-rank-progress"] and 
       user_settings["multiplayer-stats-show-rank-progress"].value then
        content.add{
            type = "label",
            caption = {"gui.progress-to-next-rank", {"gui.rank-" .. viz_data.rank_progress.next_rank.name}}
        }
        
        local progress_bar = create_progress_bar(
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
local function show_crafting_history(requesting_player, target_player_index)
    local target_player = game.players[target_player_index]
    
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
    
    init_player(target_player_index)
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

-- Event handlers
script.on_init(function()
    storage.players = {}
    storage.gui_state = {}
    
    -- Register GUI update frequency based on settings
    local update_freq = settings.startup["multiplayer-stats-update-frequency"] and 
                       settings.startup["multiplayer-stats-update-frequency"].value or 300
    
    script.on_nth_tick(update_freq, function(event)
        -- Check if mod is enabled
        if not (settings.startup["multiplayer-stats-enable-mod"] and 
                settings.startup["multiplayer-stats-enable-mod"].value) then
            return
        end
        
        update_stats_gui()
    end)
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}
    storage.gui_state = storage.gui_state or {}
    
    -- Re-register GUI update frequency based on settings
    local update_freq = settings.startup["multiplayer-stats-update-frequency"] and 
                       settings.startup["multiplayer-stats-update-frequency"].value or 300
    
    script.on_nth_tick(update_freq, function(event)
        -- Check if mod is enabled
        if not (settings.startup["multiplayer-stats-enable-mod"] and 
                settings.startup["multiplayer-stats-enable-mod"].value) then
            return
        end
        
        update_stats_gui()
    end)
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    init_player(event.player_index)
    
    -- Auto-open GUI if setting is enabled
    local player = game.players[event.player_index]
    local user_settings = settings.get_player_settings(event.player_index)
    
    if user_settings["multiplayer-stats-auto-open-gui"] and 
       user_settings["multiplayer-stats-auto-open-gui"].value then
        create_stats_gui(player)
    end
end)

-- Track player movement every 60 ticks (1 second)
script.on_nth_tick(60, function(event)
    -- Check if mod is enabled
    if not (settings.startup["multiplayer-stats-enable-mod"] and 
            settings.startup["multiplayer-stats-enable-mod"].value) then
        return
    end
    
    for _, player in pairs(game.connected_players) do
        if player.character then
            update_player_distance(player)
            update_player_status(player)
            
            -- Check achievements only if enabled
            if settings.global["multiplayer-stats-enable-achievements"] and 
               settings.global["multiplayer-stats-enable-achievements"].value then
                check_achievements(player.index)
            end
        end
    end
end)



-- Track crafted items
script.on_event(defines.events.on_player_crafted_item, function(event)
    local player_index = event.player_index
    init_player(player_index)
    
    local stats = storage.players[player_index]
    local item_name = event.item_stack.name
    local count = event.item_stack.count
    
    stats.crafted_items[item_name] = (stats.crafted_items[item_name] or 0) + count
    stats.total_crafted = stats.total_crafted + count
    
    check_achievements(player_index)
end)

-- Track combat statistics
script.on_event(defines.events.on_entity_died, function(event)
    local cause = event.cause
    if cause and cause.type == "character" then
        local player = cause.player
        if player then
            init_player(player.index)
            
            local entity = event.entity
            
            -- Count enemy kills
            if entity.force.name == "enemy" then
                storage.players[player.index].enemies_killed = 
                    storage.players[player.index].enemies_killed + 1
            end
        end
    end
end)

-- Track player deaths
script.on_event(defines.events.on_player_died, function(event)
    local player_index = event.player_index
    init_player(player_index)
    
    storage.players[player_index].deaths = storage.players[player_index].deaths + 1
    storage.players[player_index].last_survivor_tick = game.tick  -- Reset survival timer
    
    check_achievements(player_index)
end)

-- Track damage taken by players
script.on_event(defines.events.on_entity_damaged, function(event)
    if event.entity and event.entity.type == "character" and event.entity.player then
        local player_index = event.entity.player.index
        init_player(player_index)
        
        storage.players[player_index].damage_taken = 
            (storage.players[player_index].damage_taken or 0) + (event.final_damage_amount or 0)
    end
end)

-- Track building statistics
script.on_event(defines.events.on_built_entity, function(event)
    local player_index = event.player_index
    if player_index then
        init_player(player_index)
        
        storage.players[player_index].buildings_built = 
            storage.players[player_index].buildings_built + 1
            
        check_achievements(player_index)
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    local player_index = event.player_index
    init_player(player_index)
    
    storage.players[player_index].buildings_destroyed = 
        storage.players[player_index].buildings_destroyed + 1
end)

-- Track resource mining
script.on_event(defines.events.on_player_mined_item, function(event)
    local player_index = event.player_index
    init_player(player_index)
    
    local stats = storage.players[player_index]
    local item_name = event.item_stack.name
    local count = event.item_stack.count
    
    -- Track mineable resources
    if stats.resources_mined[item_name] then
        stats.resources_mined[item_name] = stats.resources_mined[item_name] + count
    end
end)

-- Toggle statistics GUI
script.on_event("toggle-multiplayer-stats", function(event)
    local player = game.players[event.player_index]
    
    -- Debug message

    
    init_player(event.player_index)
    
    -- Check if GUI is open
    local gui_exists = player.gui.top.multiplayer_stats_frame ~= nil
    
    if gui_exists then
        player.gui.top.multiplayer_stats_frame.destroy()
        if storage.gui_state and storage.gui_state[event.player_index] then
            storage.gui_state[event.player_index].gui_open = false
        end

    else
        create_stats_gui(player)
    end
end)

-- GUI click handlers
script.on_event(defines.events.on_gui_click, function(event)
    local player = game.players[event.player_index]
    local element = event.element
    if element.name == "close_stats_gui" then
        if player.gui.top.multiplayer_stats_frame then
            player.gui.top.multiplayer_stats_frame.destroy()
        end
        storage.gui_state[event.player_index].gui_open = false
        
    elseif element.name == "toggle_collapse_stats_gui" then
        storage.gui_state[event.player_index].gui_collapsed = not storage.gui_state[event.player_index].gui_collapsed
        create_stats_gui(player) -- Recreate GUI with new state
        
    elseif element.name == "close_crafting_details" then
        if player.gui.screen.crafting_details_frame then
            player.gui.screen.crafting_details_frame.destroy()
        end
        
    elseif element.name == "close_crafting_history" then
        if player.gui.screen.crafting_history_frame then
            player.gui.screen.crafting_history_frame.destroy()
        end
        


    elseif element.name == "show_achievements" then
        show_achievements(player)
        
    elseif element.name == "close_achievements" then
        if player.gui.screen.achievements_frame then
            player.gui.screen.achievements_frame.destroy()
        end
        
    elseif element.name == "show_rankings" then
        show_rankings(player)
        
    elseif element.name == "close_rankings" then
        if player.gui.screen.rankings_frame then
            player.gui.screen.rankings_frame.destroy()
        end
        
    elseif element.name == "close_comparison" then
        if player.gui.screen.comparison_frame then
            player.gui.screen.comparison_frame.destroy()
        end
        
    elseif string.match(element.name, "^compare_with_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            show_player_comparison(player, target_index)
        end
        
    elseif string.match(element.name, "^show_player_details_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            show_crafting_details(player, target_index)
        end
        
    elseif string.match(element.name, "^show_crafting_history_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            show_crafting_history(player, target_index)
        end
    end
end)

-- Commands
commands.add_command("stats", {"command.stats-help"}, function(command)
    local player = game.players[command.player_index]
    create_stats_gui(player)
end)

commands.add_command("reset-stats", {"command.reset-stats-help"}, function(command)
    if command.player_index then
        local player = game.players[command.player_index]
        if player.admin then
            storage.players = {}
            player.print({"message.stats-reset"})
        else
            player.print({"message.no-permission"})
        end
    end
end)

-- Handle runtime mod setting changes
script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    local setting_name = event.setting
    local player_index = event.player_index
    
    -- Handle global settings changes
    if event.setting_type == "runtime-global" then
        if setting_name == "multiplayer-stats-update-frequency" then
            -- Note: startup settings can't be changed at runtime, 
            -- but we'll handle this for future compatibility
            game.print({"message.setting-requires-restart"})
        elseif setting_name == "multiplayer-stats-enable-achievements" then
            local enabled = settings.global[setting_name].value
            if enabled then
                game.print({"message.achievements-enabled"})
            else
                game.print({"message.achievements-disabled"})
            end
        end
    end
    
    -- Handle per-user settings changes
    if event.setting_type == "runtime-per-user" and player_index then
        local player = game.players[player_index]
        if setting_name == "multiplayer-stats-auto-open-gui" then
            local enabled = settings.get_player_settings(player_index)[setting_name].value
            if enabled and not player.gui.top.multiplayer_stats_frame then
                create_stats_gui(player)
            elseif not enabled and player.gui.top.multiplayer_stats_frame then
                player.gui.top.multiplayer_stats_frame.destroy()
                storage.gui_state[player_index].gui_open = false
            end
        end
    end
end) 

