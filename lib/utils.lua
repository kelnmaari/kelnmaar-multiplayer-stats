-- lib/utils.lua
-- Вспомогательные функции для мода статистики

local utils = {}

-- Format playtime from ticks to readable string
function utils.format_playtime(ticks)
    local seconds = math.floor(ticks / 60)
    local minutes = math.floor(seconds / 60)
    local hours = math.floor(minutes / 60)
    
    seconds = seconds % 60
    minutes = minutes % 60
    
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- Initialize player data
function utils.init_player(player_index)
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
            deep_space_visited = false,
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

-- Cleanup player data when they leave (MEMORY LEAK FIX)
function utils.cleanup_player_on_leave(player_index)
    if storage.players and storage.players[player_index] then
        -- Keep essential data but clean up temporary items
        -- Limit crafted items to top 500 to prevent bloat
        if storage.players[player_index].crafted_items then
            local sorted_items = {}
            for item_name, count in pairs(storage.players[player_index].crafted_items) do
                table.insert(sorted_items, {name = item_name, count = count})
            end
            
            -- Sort by count and keep only top 500
            table.sort(sorted_items, function(a, b) return a.count > b.count end)
            
            local cleaned_items = {}
            for i = 1, math.min(500, #sorted_items) do
                cleaned_items[sorted_items[i].name] = sorted_items[i].count
            end
            
            storage.players[player_index].crafted_items = cleaned_items
        end
    end
    
    -- Clean up GUI state
    if storage.gui_state and storage.gui_state[player_index] then
        storage.gui_state[player_index].gui_open = false
    end
end

-- Get planet icon sprite based on planet name
function utils.get_planet_icon(planet_name)
    local planet_icons = {
        nauvis = "space-location.nauvis",
        vulcanus = "space-location.vulcanus", 
        fulgora = "space-location.fulgora",
        gleba = "space-location.gleba",
        aquilo = "space-location.aquilo",
        ["space-platform"] = "space-location.space-platform",
        ["shattered-planet"] = "space-location.shattered-planet",
        -- Fallback for unknown planets
        default = "utility/surface_editor_icon"
    }
    
    local lower_name = string.lower(planet_name)
    return planet_icons[lower_name] or planet_icons.default
end

-- Create planets icons flow
function utils.create_planets_flow(parent, planets_visited)
    if not planets_visited or not next(planets_visited) then
        parent.add{
            type = "label",
            caption = "—"
        }
        return
    end
    
    local planets_flow = parent.add{
        type = "flow",
        direction = "horizontal"
    }
    
    -- Sort planets by visit order (earliest first)
    local sorted_planets = {}
    for planet_name, visit_tick in pairs(planets_visited) do
        -- Исключаем платформы (имя начинается с 'platform')
        if not string.match(planet_name, "^platform") then
            table.insert(sorted_planets, {name = planet_name, tick = visit_tick})
        end
    end
    table.sort(sorted_planets, function(a, b) return a.tick < b.tick end)
    
    -- Add planet icons
    for _, planet_data in ipairs(sorted_planets) do
        local icon_sprite = utils.get_planet_icon(planet_data.name)
        planets_flow.add{
            type = "sprite",
            sprite = icon_sprite,
            tooltip = {"", {"gui.planet"}, ": ", planet_data.name}
        }
    end
end

-- Memory cleanup (run periodically)
function utils.periodic_cleanup()
    for player_index, player_data in pairs(storage.players or {}) do
        local player = game.players[player_index]
        if not player or not player.valid then
            -- Remove data for invalid players
            storage.players[player_index] = nil
            if storage.gui_state and storage.gui_state[player_index] then
                storage.gui_state[player_index] = nil
            end
        else
            -- Limit crafted items to prevent memory bloat
            if player_data.crafted_items and next(player_data.crafted_items) then
                local item_count = 0
                for _ in pairs(player_data.crafted_items) do
                    item_count = item_count + 1
                end
                
                if item_count > 1000 then
                    local sorted_items = {}
                    for item_name, count in pairs(player_data.crafted_items) do
                        table.insert(sorted_items, {name = item_name, count = count})
                    end
                    
                    table.sort(sorted_items, function(a, b) return a.count > b.count end)
                    
                    local cleaned_items = {}
                    for i = 1, 500 do
                        if sorted_items[i] then
                            cleaned_items[sorted_items[i].name] = sorted_items[i].count
                        end
                    end
                    
                    storage.players[player_index].crafted_items = cleaned_items
                end
            end
        end
    end
end

-- Initialize chart history for visualization
function utils.init_chart_history(player_index)
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
end

-- Create progress bar visualization
function utils.create_progress_bar(current, max_val, width)
    if max_val == 0 then max_val = 1 end
    local filled = math.floor((current / max_val) * width)
    local empty = width - filled
    local bar = string.rep("█", filled) .. string.rep("░", empty)
    return string.format("%s %d/%d (%.1f%%)", bar, current, max_val, (current/max_val)*100)
end

return utils 