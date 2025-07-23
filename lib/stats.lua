-- lib/stats.lua
-- Сбор и обработка статистики игроков

local stats = {}

-- Update player distance
function stats.update_player_distance(player_index)
    local player = game.players[player_index]
    if not player or not player.valid or not player.character then
        return
    end
    
    local current_pos = player.position
    if not current_pos then return end
    
    -- Ensure player is initialized
    if not storage.players[player_index] then
        return
    end
    
    local stats_data = storage.players[player_index]
    
    if stats_data.last_position then
        local distance = math.sqrt(
            (current_pos.x - stats_data.last_position.x)^2 + 
            (current_pos.y - stats_data.last_position.y)^2
        )
        stats_data.distance_traveled = stats_data.distance_traveled + distance
        
        -- Separate space travel tracking
        if string.find(player.surface.name:lower(), "space") or 
           string.find(player.surface.name:lower(), "platform") then
            stats_data.space_travel_distance = (stats_data.space_travel_distance or 0) + distance
        end
    end
    
    storage.players[player_index].last_position = current_pos
end

-- Update player playtime and surface tracking
function stats.update_player_status(player)
    local player_index = player.index
    
    -- Ensure player is initialized
    if not storage.players[player_index] then
        return
    end
    
    local stats_data = storage.players[player_index]
    local current_tick = game.tick
    
    -- Update playtime if player was active
    if stats_data.last_active_tick > 0 then
        stats_data.playtime_ticks = stats_data.playtime_ticks + (current_tick - stats_data.last_active_tick)
    end
    stats_data.last_active_tick = current_tick
    
    -- Track visited planets
    local surface_name = player.surface.name
    if not stats_data.planets_visited[surface_name] then
        stats_data.planets_visited[surface_name] = current_tick
    end
    
    -- Track deep space exploration (space platforms, asteroid fields, etc.)
    if not stats_data.deep_space_visited then
        if string.find(surface_name, "platform") or 
           string.find(surface_name, "asteroid") or
           string.find(surface_name, "space") or
           surface_name == "shattered-planet" or
           surface_name == "space-location" then
            stats_data.deep_space_visited = true
        end
    end
    
    -- Update current surface
    stats_data.current_surface = surface_name
end

-- Create simple data visualization
function stats.create_stats_visualization(stats_data)
    local viz = {
        activity_breakdown = nil,
        mining_breakdown = nil,
        rank_progress = nil
    }
    
    -- Activity breakdown (crafting vs combat vs building)
    local total_activity = (stats_data.total_crafted or 0) + (stats_data.enemies_killed or 0) + (stats_data.buildings_built or 0)
    
    if total_activity > 0 then
        viz.activity_breakdown = {
            crafting = math.floor(((stats_data.total_crafted or 0) / total_activity) * 100),
            combat = math.floor(((stats_data.enemies_killed or 0) / total_activity) * 100),
            building = math.floor(((stats_data.buildings_built or 0) / total_activity) * 100)
        }
    end
    
    -- Mining breakdown by resource type
    if stats_data.resources_mined then
        local total_mined = 0
        for _, count in pairs(stats_data.resources_mined) do
            total_mined = total_mined + count
        end
        
        if total_mined > 0 then
            viz.mining_breakdown = {}
            for resource, count in pairs(stats_data.resources_mined) do
                if count > 0 then
                    viz.mining_breakdown[resource] = math.floor((count / total_mined) * 100)
                end
            end
        end
    end
    
    return viz
end

-- Update chart history (для визуализации) - добавляет только при значительных изменениях
function stats.update_chart_history(player_index, rankings)
    if not storage.chart_history then
        storage.chart_history = {}
    end
    
    if not storage.chart_history[player_index] then
        storage.chart_history[player_index] = {
            distance = {},
            score = {},
            crafted = {},
            combat = {},
            playtime = {}
        }
    end
    
    local history = storage.chart_history[player_index]
    local player_stats = storage.players[player_index]
    
    if not player_stats then return end
    
    local _, score = rankings.calculate_player_rank(player_stats)
    
    -- Current values
    local current_values = {
        distance = player_stats.distance_traveled or 0,
        score = score,
        crafted = player_stats.total_crafted or 0,
        combat = player_stats.enemies_killed or 0,
        playtime = (player_stats.playtime_ticks or 0) / 216000 -- Convert to hours
    }
    
    -- Add values only if they changed significantly (avoid duplicates)
    for category, value in pairs(current_values) do
        local should_add = false
        
        if #history[category] == 0 then
            -- First entry
            should_add = true
        else
            local last_value = history[category][#history[category]]
            local change_threshold = 0
            
            -- Set thresholds for different categories
            if category == "distance" then
                change_threshold = 1.0  -- 1 unit change
            elseif category == "score" then
                change_threshold = 50   -- 50 point change
            elseif category == "crafted" then
                change_threshold = 10   -- 10 items change
            elseif category == "combat" then
                change_threshold = 5    -- 5 kills change
            elseif category == "playtime" then
                change_threshold = 0.1  -- 6 minute change (0.1 hours)
            end
            
            -- Add if change is significant enough
            if math.abs(value - last_value) >= change_threshold then
                should_add = true
            end
        end
        
        if should_add then
            table.insert(history[category], value)
            
            -- Limit history length to prevent memory bloat
            while #history[category] > 30 do  -- Increased from 20 to 30 for better visualization
                table.remove(history[category], 1)
            end
        end
    end
end

-- Handle crafting completion
function stats.on_player_crafted_item(event)
    local player_index = event.player_index
    local item_stack = event.item_stack
    
    if not storage.players[player_index] then
        return
    end
    
    local stats_data = storage.players[player_index]
    local item_name = item_stack.name
    local count = item_stack.count
    
    -- Update crafted items tracking
    stats_data.crafted_items[item_name] = (stats_data.crafted_items[item_name] or 0) + count
    stats_data.total_crafted = stats_data.total_crafted + count
end

-- Handle entity death (combat tracking)
function stats.on_entity_died(event)
    local entity = event.entity
    local cause = event.cause
    
    if cause and cause.type == "character" and cause.player then
        local player_index = cause.player.index
        
        if not storage.players[player_index] then
            return
        end
        
        -- Only count biters, spawners, and other enemies
        if entity.force.name == "enemy" then
            storage.players[player_index].enemies_killed = 
                (storage.players[player_index].enemies_killed or 0) + 1
        end
    end
end

-- Handle player death
function stats.on_player_died(event)
    local player_index = event.player_index
    
    if not storage.players[player_index] then
        return
    end
    
    storage.players[player_index].deaths = 
        (storage.players[player_index].deaths or 0) + 1
    
    -- Reset survivor timer for survival achievements
    storage.players[player_index].last_survivor_tick = game.tick
end

-- Handle damage taken by players
function stats.on_entity_damaged(event)
    if event.entity and event.entity.type == "character" and event.entity.player then
        local player_index = event.entity.player.index
        
        if not storage.players[player_index] then
            return
        end
        
        storage.players[player_index].damage_taken = 
            (storage.players[player_index].damage_taken or 0) + (event.final_damage_amount or 0)
    end
end

-- Handle building construction
function stats.on_built_entity(event)
    local player_index = event.player_index
    if player_index and storage.players[player_index] then
        storage.players[player_index].buildings_built = 
            storage.players[player_index].buildings_built + 1
    end
end

-- Handle building destruction by player
function stats.on_player_mined_entity(event)
    local player_index = event.player_index
    if storage.players[player_index] then
        storage.players[player_index].buildings_destroyed = 
            storage.players[player_index].buildings_destroyed + 1
    end
end

-- Handle resource mining
function stats.on_player_mined_item(event)
    local player_index = event.player_index
    
    if not storage.players[player_index] then
        return
    end
    
    local stats_data = storage.players[player_index]
    local item_name = event.item_stack.name
    local count = event.item_stack.count
    
    -- Track mineable resources
    if stats_data.resources_mined[item_name] then
        stats_data.resources_mined[item_name] = stats_data.resources_mined[item_name] + count
    end
end

return stats 