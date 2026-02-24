-- Multiplayer Statistics Mod
-- Modular version with lib/ structure

-- Planet Stats Feature Toggle (controlled by startup setting)
-- To enable planet stats:
-- 1. Set the setting "multiplayer-stats-enable-planet-stats" to true in settings.lua
-- 2. Uncomment the hotkey registration in data.lua (search for "toggle-planet-stats")
-- 3. Restart the game
local PLANET_STATS_ENABLED = settings.startup["multiplayer-stats-enable-planet-stats"] and 
                             settings.startup["multiplayer-stats-enable-planet-stats"].value or false

-- Import modules
local utils = require("lib.utils")
local rankings = require("lib.rankings")
local stats_module = require("lib.stats")
local gui = require("lib.gui")
local gui_main = require("lib.gui_main")
local planet_stats = PLANET_STATS_ENABLED and require("lib.planet_stats") or nil
local charts = require("__factorio-charts__.charts")

-- Stdlib2 modules
local Gui = require("__stdlib2__/stdlib/event/gui")

-- Performance optimization: Player update queue
local player_update_queue = {}
local queue_index = 1

-- CRITICAL: Fixed nth_tick intervals - NEVER change these values!
-- Changing these values between mod versions causes multiplayer desyncs
-- These must remain constant for the entire lifetime of the mod
local UPDATE_FREQUENCY = 1800       -- Main stats update - FIXED VALUE
local CLEANUP_FREQUENCY = 36000     -- Cleanup every 10 minutes - FIXED VALUE
local GUI_REFRESH_FREQUENCY = 600   -- GUI refresh every 10 seconds - FIXED VALUE
local ENERGY_CHART_FREQUENCY = 300  -- Energy chart update every 5 seconds - FIXED VALUE

-- Get update frequency for event registration - always returns same value
local function get_update_frequency()
    return UPDATE_FREQUENCY
end

-- Get cleanup frequency for event registration - always returns same value
local function get_cleanup_frequency()
    return CLEANUP_FREQUENCY
end

-- Get GUI refresh frequency for event registration - always returns same value
local function get_gui_refresh_frequency()
    return GUI_REFRESH_FREQUENCY
end

-- Initialize player update queue
local function rebuild_player_queue()
    player_update_queue = {}
    for player_index, player in pairs(game.players) do
        if player.connected then
            table.insert(player_update_queue, player_index)
        end
    end
    queue_index = 1
end

-- Update a limited number of players per tick for better performance
local function update_players_batch()
    if #player_update_queue == 0 then
        rebuild_player_queue()
        return
    end
    
    -- Process max players per update cycle based on setting
    local max_setting = settings.startup["multiplayer-stats-max-players-per-update"] and 
                       settings.startup["multiplayer-stats-max-players-per-update"].value or 5
    local max_players_per_update = math.min(max_setting, #player_update_queue)
    local updated_count = 0
    
    while updated_count < max_players_per_update and #player_update_queue > 0 do
        local player_index = player_update_queue[queue_index]
        local player = game.players[player_index]
        
        if player and player.connected then
            utils.init_player(player_index)
            stats_module.update_player_distance(player_index)
            stats_module.update_player_status(player)
            stats_module.update_chart_history(player_index, rankings, utils)
            rankings.check_achievements(player_index, utils)
            
            -- Update planet stats GUI if open
            if PLANET_STATS_ENABLED and planet_stats then
                planet_stats.update_planet_stats_gui(player)
            end
            
            updated_count = updated_count + 1
        end
        
        queue_index = queue_index + 1
        if queue_index > #player_update_queue then
            queue_index = 1
            break -- Full cycle completed
        end
    end
end

-- Function to register periodic event handlers
local function register_periodic_handlers()
    -- CRITICAL: Get all tick frequencies from module constants to prevent desync
    local update_frequency = get_update_frequency()
    local cleanup_frequency = get_cleanup_frequency() 
    local gui_refresh_frequency = get_gui_refresh_frequency()
    
    -- Clear any existing handlers to prevent double registration
    script.on_nth_tick(nil)
    
    -- Main stats update handler (optimized with player queue)
    script.on_nth_tick(update_frequency, function(event)
        -- Wrap in pcall for error safety
        local success, error_msg = pcall(function()
            gui_main.update_stats_gui(utils, rankings)
            update_players_batch()
            
            -- Update and record history for each unique surface players are on
            local processed_surfaces = {}
            for _, player in pairs(game.players) do
                if player.connected and player.surface and not processed_surfaces[player.surface.name] then
                    local s_name = player.surface.name
                    processed_surfaces[s_name] = true
                    
                    -- We use the quick API data if available, otherwise skip history update to avoid lag
                    -- collect_surface_stats is sync but it might be heavy, so we might want to optimize this.
                    if PLANET_STATS_ENABLED and planet_stats then
                        -- Get quick network stats without scanning every entity
                        local quick_stats = {surface_name = s_name}
                        planet_stats.collect_network_power_stats(player.surface, player.force, quick_stats)
                        if quick_stats.network_power and quick_stats.network_power.available then
                            stats_module.update_planet_power_history(
                                s_name, 
                                quick_stats.network_power.production, 
                                quick_stats.network_power.consumption,
                                utils
                            )
                        end
                    end
                end
            end
            
            -- Flush buffered damage data
            stats_module.flush_damage_buffer()
        end)
        if not success then
            game.print("[Multiplayer Stats] Error in main update: " .. tostring(error_msg))
        end
    end)
    
    -- Register periodic cleanup
    script.on_nth_tick(cleanup_frequency, function(event)
        local success, error_msg = pcall(utils.periodic_cleanup)
        if not success then
            game.print("[Multiplayer Stats] Error in cleanup: " .. tostring(error_msg))
        end
    end)
    
    -- Auto-refresh dashboards every 10 seconds
    script.on_nth_tick(gui_refresh_frequency, function(event)
        -- Wrap in pcall for error safety
        local success, error_msg = pcall(function()
            if not storage.dashboard_data then return end
            
            for player_index, data in pairs(storage.dashboard_data) do
                local player = game.players[player_index]
                if player and player.valid and player.connected then
                    local frame = player.gui.screen.stats_charts_frame
                    if frame and frame.valid then
                        local content = frame.charts_content
                        if content and content.valid then
                            gui.create_dashboard_content(content, data.target_player_index, utils, rankings)
                        end
                    else
                        -- Remove data if frame is gone
                        storage.dashboard_data[player_index] = nil
                    end
                else
                    -- Remove data for invalid/disconnected players
                    storage.dashboard_data[player_index] = nil
                end
            end
        end)
        if not success then
            game.print("[Multiplayer Stats] Error in GUI refresh: " .. tostring(error_msg))
        end
    end)
    
    -- Planet stats async processing handler
    if PLANET_STATS_ENABLED and planet_stats then
        local planet_stats_interval = planet_stats.get_processing_interval()
        script.on_nth_tick(planet_stats_interval, function(event)
            local success, error_msg = pcall(function()
                if not storage.planet_stats_processing then return end
                
                for player_index, state in pairs(storage.planet_stats_processing) do
                    if state.in_progress then
                        -- Process batch
                        local still_processing = planet_stats.process_batch(player_index)
                        
                        -- Update GUI with current stats
                        local player = game.players[player_index]
                        if player and player.valid and player.connected then
                            local stats, in_progress, current, total = planet_stats.get_current_stats(player_index)
                            if stats then
                                planet_stats.update_planet_stats_content(player, stats)
                            end
                        end
                    end
                end
            end)
            if not success then
                game.print("[Multiplayer Stats] Error in planet stats processing: " .. tostring(error_msg))
            end
        end)

        -- Energy chart data collection every 5 seconds
        script.on_nth_tick(ENERGY_CHART_FREQUENCY, function(event)
            local success, error_msg = pcall(function()
                local processed_surfaces = {}
                for _, player in pairs(game.players) do
                    if player.connected and player.surface and not processed_surfaces[player.surface.name] then
                        local s_name = player.surface.name
                        processed_surfaces[s_name] = true

                        local quick_stats = {surface_name = s_name}
                        planet_stats.collect_network_power_stats(player.surface, player.force, quick_stats)

                        local production = 0
                        local consumption = 0
                        local has_data = false

                        if quick_stats.network_power and quick_stats.network_power.available then
                            production = quick_stats.network_power.production
                            consumption = quick_stats.network_power.consumption
                            has_data = true
                        else
                            -- Fallback: use last known calculated stats from async collection
                            local state = storage.planet_stats_processing and storage.planet_stats_processing[player.index]
                            if state and state.stats then
                                local s = state.stats
                                production = s.power_generation or 0
                                consumption = s.power_consumption or 0
                                has_data = (production > 0 or consumption > 0)
                            end
                        end

                        if has_data then
                            stats_module.update_planet_energy_history(
                                s_name,
                                production,
                                consumption,
                                utils
                            )
                        end
                    end
                end
            end)
            if not success then
                game.print("[Multiplayer Stats] Error in energy chart update: " .. tostring(error_msg))
            end
        end)
    end
end

-- Event handlers
script.on_init(function()
    storage.players = {}
    storage.gui_state = {}
    if PLANET_STATS_ENABLED then
        storage.planet_stats_state = {}
        storage.planet_stats_processing = {}
    end
    
    -- Register periodic handlers (using fixed constants only)
    register_periodic_handlers()
    
    -- Initialize factorio-charts surface
    if not storage.charts_surface then
        storage.charts_surface = charts.create_surface("kelnmaar-stats-charts")
    end
    
    -- Register factorio-charts events
    charts.register_events()
end)

script.on_load(function()
    -- Register periodic handlers on load to avoid desync
    register_periodic_handlers()

    -- Register factorio-charts events (required for animations and interaction)
    charts.register_events()

    -- NOTE: We can't restore chunks here because on_load() cannot modify storage
    -- Chunks will be recreated automatically when GUI is opened (see gui.lua line 36-38)
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}
    storage.gui_state = storage.gui_state or {}
    storage.chart_history = storage.chart_history or {}
    storage.player_timeseries = storage.player_timeseries or {}

    -- Note: script.on_nth_tick handlers are automatically cleared on configuration change
    -- So we just need to re-register them (using fixed constants only)
    register_periodic_handlers()

    -- Initialize factorio-charts surface if missing (for existing saves)
    if not storage.charts_surface then
        storage.charts_surface = charts.create_surface("kelnmaar-stats-charts")
    end

    -- Restore chunks for all timeseries after configuration change
    utils.restore_all_timeseries_chunks()
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    utils.init_player(event.player_index)
    
    -- Auto-open GUI if setting is enabled
    local player = game.players[event.player_index]
    local user_settings = settings.get_player_settings(event.player_index)
    
    if user_settings["multiplayer-stats-auto-open-gui"] and 
       user_settings["multiplayer-stats-auto-open-gui"].value then
        gui_main.create_stats_gui(player, utils, rankings)
    end
    
    -- Rebuild player queue for performance optimization
    rebuild_player_queue()
end)

-- MEMORY LEAK FIX: Clean up data when players leave
script.on_event(defines.events.on_player_left_game, function(event)
    utils.cleanup_player_on_leave(event.player_index)
    
    -- Rebuild player queue for performance optimization
    rebuild_player_queue()
end)

-- Track crafting
script.on_event(defines.events.on_player_crafted_item, function(event)
    utils.init_player(event.player_index)
    stats_module.on_player_crafted_item(event)
    rankings.check_achievements(event.player_index, utils)
end)

-- Track combat
script.on_event(defines.events.on_entity_died, function(event)
    stats_module.on_entity_died(event)
    
    if event.cause and event.cause.type == "character" and event.cause.player then
        rankings.check_achievements(event.cause.player.index, utils)
    end
end)

-- Track player deaths
script.on_event(defines.events.on_player_died, function(event)
    utils.init_player(event.player_index)
    stats_module.on_player_died(event)
end)

-- Track damage taken by players
script.on_event(defines.events.on_entity_damaged, function(event)
    stats_module.on_entity_damaged(event)
end)

-- Track building statistics
script.on_event(defines.events.on_built_entity, function(event)
    if event.player_index then
        utils.init_player(event.player_index)
        stats_module.on_built_entity(event)
        rankings.check_achievements(event.player_index, utils)
    end
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    utils.init_player(event.player_index)
    stats_module.on_player_mined_entity(event)
end)

-- Track resource mining
script.on_event(defines.events.on_player_mined_item, function(event)
    utils.init_player(event.player_index)
    stats_module.on_player_mined_item(event)
end)

-- Toggle statistics GUI
script.on_event("toggle-multiplayer-stats", function(event)
    local player = game.players[event.player_index]
    
    utils.init_player(event.player_index)
    
    -- Check if GUI is open
    local gui_exists = player.gui.screen.multiplayer_stats_frame ~= nil
    
    if gui_exists then
        -- Save position before closing
        if storage.gui_state and storage.gui_state[event.player_index] then
            storage.gui_state[event.player_index].gui_position = player.gui.screen.multiplayer_stats_frame.location
            storage.gui_state[event.player_index].gui_open = false
        end
        player.gui.screen.multiplayer_stats_frame.destroy()
    else
        gui_main.create_stats_gui(player, utils, rankings)
    end
end)

-- Toggle player rankings GUI
script.on_event("toggle-player-rankings", function(event)
    local player = game.players[event.player_index]
    
    -- Check if rankings window is open
    if player.gui.screen.rankings_frame then
        player.gui.screen.rankings_frame.destroy()
    else
        gui.show_rankings(player, rankings)
    end
end)

-- Planet statistics events
if PLANET_STATS_ENABLED then
    script.on_event(defines.events.on_player_changed_surface, function(event)
        local player = game.players[event.player_index]
        
        -- Auto-show planet stats when changing to a new surface
        if storage.planet_stats_state and storage.planet_stats_state[event.player_index] and 
           storage.planet_stats_state[event.player_index].auto_show then
            
            local surface_stats = planet_stats.collect_surface_stats(player.surface)
            if surface_stats then
                planet_stats.create_planet_stats_gui(player, surface_stats)
            end
        end
    end)
end

-- Toggle planet statistics GUI (new custom input)
if PLANET_STATS_ENABLED then
    script.on_event("toggle-planet-stats", function(event)
        local player = game.players[event.player_index]
        
        -- Initialize planet stats state if needed
        if not storage.planet_stats_state then
            storage.planet_stats_state = {}
        end
        
        if not storage.planet_stats_state[event.player_index] then
            storage.planet_stats_state[event.player_index] = {
                auto_show = false
            }
        end
        
        -- Check if planet stats GUI is open
        local planet_gui_exists = player.gui.screen.planet_stats_frame ~= nil
        
        if planet_gui_exists then
            -- Close GUI and stop async processing
            player.gui.screen.planet_stats_frame.destroy()
            planet_stats.stop_async_collection(event.player_index)
            storage.planet_stats_state[event.player_index].auto_show = false
        else
            -- Start async collection and show GUI immediately with initial data
            local state = planet_stats.start_async_collection(player)
            if state then
                -- Create GUI with initial stats (will be updated as processing continues)
                planet_stats.create_planet_stats_gui(player, state.stats)
                storage.planet_stats_state[event.player_index].auto_show = true
            else
                -- Fallback to sync if async fails
                local surface_stats = planet_stats.collect_surface_stats(player.surface)
                planet_stats.create_planet_stats_gui(player, surface_stats or {
                    surface_name = player.surface.name,
                    production = {},
                    power_generation = 0,
                    power_consumption = 0,
                    entity_shortages = {},
                    total_entities = 0,
                    working_entities = 0,
                    processed_entities = 0,
                    power_producers = 0,
                    power_consumers = 0,
                    debug_power_info = {},
                    network_power = nil
                })
                storage.planet_stats_state[event.player_index].auto_show = true
            end
        end
    end)
end

-- GUI click handlers (using stdlib2 Gui.on_click for pattern-matched event routing)

Gui.on_click("^close_stats_gui$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.multiplayer_stats_frame then
        if storage.gui_state and storage.gui_state[event.player_index] then
            storage.gui_state[event.player_index].gui_position = player.gui.screen.multiplayer_stats_frame.location
        end
        player.gui.screen.multiplayer_stats_frame.destroy()
    end
    if storage.gui_state and storage.gui_state[event.player_index] then
        storage.gui_state[event.player_index].gui_open = false
    end
end)

Gui.on_click("^toggle_collapse_stats_gui$", function(event)
    local player = game.players[event.player_index]
    if storage.gui_state and storage.gui_state[event.player_index] then
        storage.gui_state[event.player_index].gui_collapsed = not storage.gui_state[event.player_index].gui_collapsed
    end
    gui_main.create_stats_gui(player, utils, rankings)
end)

Gui.on_click("^close_crafting_details$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.crafting_details_frame then
        player.gui.screen.crafting_details_frame.destroy()
    end
end)

Gui.on_click("^close_crafting_history$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.crafting_history_frame then
        player.gui.screen.crafting_history_frame.destroy()
    end
end)

Gui.on_click("^close_comparison$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.comparison_frame then
        player.gui.screen.comparison_frame.destroy()
    end
end)

Gui.on_click("^show_achievements$", function(event)
    local player = game.players[event.player_index]
    gui.show_achievements(player, rankings, utils)
end)

Gui.on_click("^close_achievements$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.achievements_frame then
        player.gui.screen.achievements_frame.destroy()
    end
end)

Gui.on_click("^show_rankings$", function(event)
    local player = game.players[event.player_index]
    gui.show_rankings(player, rankings)
end)

Gui.on_click("^close_rankings$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.rankings_frame then
        player.gui.screen.rankings_frame.destroy()
    end
end)

Gui.on_click("^close_planet_stats$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.planet_stats_frame then
        if storage.planet_stats_state and storage.planet_stats_state[event.player_index] then
            storage.planet_stats_state[event.player_index].gui_position = player.gui.screen.planet_stats_frame.location
        end
        player.gui.screen.planet_stats_frame.destroy()
        if planet_stats then
            planet_stats.stop_async_collection(event.player_index)
        end
        if storage.planet_stats_state and storage.planet_stats_state[event.player_index] then
            storage.planet_stats_state[event.player_index].auto_show = false
        end
    end
end)

Gui.on_click("^close_stats_charts$", function(event)
    local player = game.players[event.player_index]
    if player.gui.screen.stats_charts_frame then
        player.gui.screen.stats_charts_frame.destroy()
    end
    if storage.dashboard_data and storage.dashboard_data[player.index] then
        storage.dashboard_data[player.index] = nil
    end
end)

-- Pattern-matched handlers: event.match contains the captured group
Gui.on_click("^show_player_details_(%d+)$", function(event)
    local player = game.players[event.player_index]
    local target_index = tonumber(event.match)
    if target_index then
        gui_main.show_crafting_details(player, target_index, utils, rankings, stats_module)
    end
end)

Gui.on_click("^show_crafting_history_(%d+)$", function(event)
    local player = game.players[event.player_index]
    local target_index = tonumber(event.match)
    if target_index then
        gui_main.show_crafting_history(player, target_index, utils)
    end
end)

Gui.on_click("^compare_with_(%d+)$", function(event)
    local player = game.players[event.player_index]
    local target_index = tonumber(event.match)
    if target_index then
        gui.show_player_comparison(player, target_index, utils, rankings)
    end
end)

Gui.on_click("^show_charts_(%d+)$", function(event)
    local player = game.players[event.player_index]
    local target_index = tonumber(event.match)
    if target_index then
        gui.show_statistics_charts(player, target_index, utils, rankings, stats_module)
    end
end)

-- Planet statistics: ping entity handler
if PLANET_STATS_ENABLED then
    Gui.on_click("^ping_entity_(%d+)$", function(event)
        local player = game.players[event.player_index]
        local entity_index = tonumber(event.match)
        if entity_index then
            local surface_stats = planet_stats.collect_surface_stats(player.surface)
            if surface_stats and surface_stats.entity_shortages[entity_index] then
                local shortage = surface_stats.entity_shortages[entity_index]

                player.create_local_flying_text{
                    text = {"gui.entity-pinged", shortage.name},
                    position = shortage.position,
                    time_to_live = 180
                }

                player.zoom_to_world(shortage.position, 1)

                if game.players and #game.players > 1 then
                    for _, other_player in pairs(game.players) do
                        if other_player ~= player and other_player.surface == player.surface then
                            other_player.create_local_flying_text{
                                text = {"gui.player-pinged-entity", player.name, shortage.name},
                                position = shortage.position,
                                time_to_live = 180
                            }
                        end
                    end
                end
            end
        end
    end)
end

-- Commands
commands.add_command("mps-stats", {"command.stats-help"}, function(command)
    local player = game.players[command.player_index]
    gui_main.create_stats_gui(player, utils, rankings)
end)

if PLANET_STATS_ENABLED then
    commands.add_command("planet-stats", {"command.planet-stats-help"}, function(command)
        local player = game.players[command.player_index]
        local surface_stats = planet_stats.collect_surface_stats(player.surface)
        if surface_stats then
            planet_stats.create_planet_stats_gui(player, surface_stats)
        end
    end)
end

-- Handle GUI location changes to persist position
script.on_event(defines.events.on_gui_location_changed, function(event)
    local element = event.element
    if not element or not element.valid then return end
    
    local player_index = event.player_index
    
    -- Save planet stats frame position
    if element.name == "planet_stats_frame" then
        if not storage.planet_stats_state then storage.planet_stats_state = {} end
        if not storage.planet_stats_state[player_index] then storage.planet_stats_state[player_index] = {} end
        storage.planet_stats_state[player_index].gui_position = element.location
    
    -- Save main stats frame position
    elseif element.name == "multiplayer_stats_frame" then
        if not storage.gui_state then storage.gui_state = {} end
        if not storage.gui_state[player_index] then storage.gui_state[player_index] = {} end
        storage.gui_state[player_index].gui_position = element.location
    end
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
        if setting_name == "multiplayer-stats-enable-achievements" then
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
            if enabled and not player.gui.screen.multiplayer_stats_frame then
                gui_main.create_stats_gui(player, utils, rankings)
            elseif not enabled and player.gui.screen.multiplayer_stats_frame then
                -- Save position before closing
                if storage.gui_state and storage.gui_state[player_index] then
                    storage.gui_state[player_index].gui_position = player.gui.screen.multiplayer_stats_frame.location
                end
                player.gui.screen.multiplayer_stats_frame.destroy()
                storage.gui_state[player_index].gui_open = false
            end
        end
    end
end) 

