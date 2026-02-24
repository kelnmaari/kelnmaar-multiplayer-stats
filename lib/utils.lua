-- lib/utils.lua
-- Вспомогательные функции для мода статистики

local utils = {}
local charts = require("__factorio-charts__.charts")
local Table = require("__stdlib2__/stdlib/utils/table")
local String = require("__stdlib2__/stdlib/utils/string")

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
    
    -- MEMORY LEAK FIX: Clean up dashboard data
    if storage.dashboard_data and storage.dashboard_data[player_index] then
        storage.dashboard_data[player_index] = nil
    end
    
    -- NOTE: chart_history and player_timeseries are preserved across disconnects
    -- so players see their historical data when they reconnect

    -- Clean up transient render resources (chunks, line objects)
    -- The timeseries DATA is kept, only render state is cleared
    if storage.player_timeseries and storage.player_timeseries[player_index] then
        local ts = storage.player_timeseries[player_index]
        for _, interval in ipairs(ts) do
            -- Destroy render objects (lines)
            if interval.line_ids then
                for _, obj in ipairs(interval.line_ids) do
                    if obj.valid then obj.destroy() end
                end
                interval.line_ids = {}
            end
            -- Free main chunk back to pool
            if interval.chunk then
                charts.free_chunk(storage.charts_surface, interval.chunk)
                interval.chunk = nil
            end
            -- Free per-series chunks and line_ids (used by split charts)
            for _, series_name in ipairs({"distance", "score", "crafted", "combat", "playtime"}) do
                local chunk_key = "chunk_" .. series_name
                if interval[chunk_key] then
                    charts.free_chunk(storage.charts_surface, interval[chunk_key])
                    interval[chunk_key] = nil
                end
                local line_ids_key = "line_ids_" .. series_name
                if interval[line_ids_key] then
                    for _, obj in ipairs(interval[line_ids_key]) do
                        if obj.valid then obj.destroy() end
                    end
                    interval[line_ids_key] = nil
                end
            end
            interval.last_rendered_tick = nil
        end
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
        if not String.starts_with(planet_name, "platform") then
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
                local item_count = Table.count_keys(player_data.crafted_items)

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

-- Initialize time-series history for factorio-charts
function utils.init_player_timeseries(player_index)
    if not storage.player_timeseries then
        storage.player_timeseries = {}
    end

    if not storage.player_timeseries[player_index] then
        -- Define intervals: 30s, 5m, 1h
        -- Note: ticks parameter is used for TTL calculation and display labels
        -- Data is added every time add_datapoint is called (every UPDATE_FREQUENCY = 1800 ticks)
        local defs = {
            {name = "30s", ticks = 1800, steps = 10, length = 200}, -- ~100 minutes (200 points * 30s)
            {name = "5m",  ticks = 18000, steps = 12, length = 200}, -- ~16.7 hours (200 points * 5m)
            {name = "1h",  ticks = 216000, steps = nil, length = 200} -- ~8.3 days (200 points * 1h)
        }
        storage.player_timeseries[player_index] = charts.create_time_series(defs)
    end
end

-- Restore chunks for all player timeseries after save load
-- This is needed because light_ids and line_ids are lost on save/load
function utils.restore_all_timeseries_chunks()
    if not storage.charts_surface then
        return
    end

    if storage.player_timeseries then
        for player_index, ts in pairs(storage.player_timeseries) do
            for _, interval in ipairs(ts) do
                -- Clear old chunk data (light_ids are invalid after load)
                interval.chunk = nil
                interval.line_ids = {}
                interval.last_rendered_tick = nil
                -- Clear per-series chunks and line_ids (used by split charts)
                for _, series_name in ipairs({"distance", "score", "crafted", "combat", "playtime"}) do
                    interval["chunk_" .. series_name] = nil
                    interval["line_ids_" .. series_name] = nil
                end
            end
        end
    end

    if storage.planet_timeseries then
        for surface_name, ts in pairs(storage.planet_timeseries) do
            for _, interval in ipairs(ts) do
                -- Clear old chunk data
                interval.chunk = nil
                interval.line_ids = {}
                interval.last_rendered_tick = nil
            end
        end
    end

    if storage.planet_energy_timeseries then
        for surface_name, series_pair in pairs(storage.planet_energy_timeseries) do
            for _, ts in pairs(series_pair) do
                for _, interval in ipairs(ts) do
                    interval.chunk = nil
                    interval.line_ids = {}
                    interval.last_rendered_tick = nil
                end
            end
        end
    end
end

-- Initialize planet power history
function utils.init_planet_timeseries(surface_name)
    if not storage.planet_timeseries then
        storage.planet_timeseries = {}
    end
    
    if not storage.planet_timeseries[surface_name] then
        local defs = {
            {name = "30s", ticks = 1800, steps = 10, length = 60},
            {name = "5m",  ticks = 18000, steps = 12, length = 60},
            {name = "1h",  ticks = 216000, steps = nil, length = 120}
        }
        storage.planet_timeseries[surface_name] = charts.create_time_series(defs)
    end
end

-- Initialize planet energy time series (5s step, 1 hour capacity = 720 points)
-- Two separate time series: one for production, one for consumption
-- Data is stored in MW (divided by 1,000,000 on write)
function utils.init_planet_energy_timeseries(surface_name)
    if not storage.planet_energy_timeseries then
        storage.planet_energy_timeseries = {}
    end

    -- Reset stale data from older versions that stored values in Watts
    local existing = storage.planet_energy_timeseries[surface_name]
    if existing and not existing._version_mw then
        storage.planet_energy_timeseries[surface_name] = nil
    end

    if not storage.planet_energy_timeseries[surface_name] then
        -- Single interval: 5 seconds (300 ticks), 720 points = 1 hour
        local production_defs = {
            {name = "5s", ticks = 300, steps = nil, length = 720}
        }
        local consumption_defs = {
            {name = "5s", ticks = 300, steps = nil, length = 720}
        }
        storage.planet_energy_timeseries[surface_name] = {
            production = charts.create_time_series(production_defs),
            consumption = charts.create_time_series(consumption_defs),
            _version_mw = true
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