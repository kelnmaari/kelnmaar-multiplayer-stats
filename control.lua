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

-- Performance optimization: Player update queue
local player_update_queue = {}
local queue_index = 1

-- CRITICAL: All nth_tick intervals as module constants for on_load compatibility
-- This prevents nth_tick desync errors in multiplayer
local UPDATE_FREQUENCY = 1800       -- Main stats update (configurable)
local CLEANUP_FREQUENCY = 36000     -- Cleanup every 10 minutes
local GUI_REFRESH_FREQUENCY = 600   -- GUI refresh every 10 seconds

-- Get update frequency for event registration
local function get_update_frequency()
    return UPDATE_FREQUENCY
end

-- Get cleanup frequency for event registration
local function get_cleanup_frequency()
    return CLEANUP_FREQUENCY
end

-- Get GUI refresh frequency for event registration  
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
            stats_module.update_chart_history(player_index, rankings)
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
end

-- Event handlers
script.on_init(function()
    storage.players = {}
    storage.gui_state = {}
    if PLANET_STATS_ENABLED then
        storage.planet_stats_state = {}
    end
    
    -- CRITICAL: Update module constant for nth_tick registration
    UPDATE_FREQUENCY = settings.startup["multiplayer-stats-update-frequency"] and 
                      settings.startup["multiplayer-stats-update-frequency"].value or 1800
    
    -- Register periodic handlers
    register_periodic_handlers()
end)

script.on_load(function()
    -- CRITICAL: Register periodic handlers on load to avoid desync
    -- This prevents the "nth_ticks not re-registered" error in multiplayer
    -- We use module constant UPDATE_FREQUENCY (no storage access allowed in on_load)
    register_periodic_handlers()
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}
    storage.gui_state = storage.gui_state or {}
    
    -- CRITICAL: Update module constant for nth_tick registration
    UPDATE_FREQUENCY = settings.startup["multiplayer-stats-update-frequency"] and 
                      settings.startup["multiplayer-stats-update-frequency"].value or 1800
    
    -- Note: script.on_nth_tick handlers are automatically cleared on configuration change
    -- So we just need to re-register them
    register_periodic_handlers()
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
    local gui_exists = player.gui.top.multiplayer_stats_frame ~= nil
    
    if gui_exists then
        player.gui.top.multiplayer_stats_frame.destroy()
        if storage.gui_state and storage.gui_state[event.player_index] then
            storage.gui_state[event.player_index].gui_open = false
        end
    else
        gui_main.create_stats_gui(player, utils, rankings)
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
            player.gui.screen.planet_stats_frame.destroy()
            storage.planet_stats_state[event.player_index].auto_show = false
        else
            local surface_stats = planet_stats.collect_surface_stats(player.surface)
            if surface_stats then
                planet_stats.create_planet_stats_gui(player, surface_stats)
                storage.planet_stats_state[event.player_index].auto_show = true
            end
        end
    end)
end

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
        gui_main.create_stats_gui(player, utils, rankings) -- Recreate GUI with new state
        
    elseif element.name == "close_crafting_details" then
        if player.gui.screen.crafting_details_frame then
            player.gui.screen.crafting_details_frame.destroy()
        end
        
    elseif element.name == "close_crafting_history" then
        if player.gui.screen.crafting_history_frame then
            player.gui.screen.crafting_history_frame.destroy()
        end
        
    elseif element.name == "close_comparison" then
        if player.gui.screen.comparison_frame then
            player.gui.screen.comparison_frame.destroy()
        end

    elseif element.name == "show_achievements" then
        gui.show_achievements(player, rankings, utils)
        
    elseif element.name == "close_achievements" then
        if player.gui.screen.achievements_frame then
            player.gui.screen.achievements_frame.destroy()
        end
        
    elseif element.name == "show_rankings" then
        gui.show_rankings(player, rankings)
        
    elseif element.name == "close_rankings" then
        if player.gui.screen.rankings_frame then
            player.gui.screen.rankings_frame.destroy()
        end
        
    elseif string.match(element.name, "^show_player_details_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            gui_main.show_crafting_details(player, target_index, utils, rankings, stats_module)
        end
        
    elseif string.match(element.name, "^show_crafting_history_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            gui_main.show_crafting_history(player, target_index, utils)
        end
        
    elseif string.match(element.name, "^compare_with_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            gui.show_player_comparison(player, target_index, utils, rankings)
        end
        
    elseif string.match(element.name, "^show_charts_") then
        local target_index = tonumber(string.match(element.name, "(%d+)$"))
        if target_index then
            gui.show_statistics_charts(player, target_index, utils, rankings, stats_module)
        end
        
    elseif element.name == "close_stats_charts" then
        if player.gui.screen.stats_charts_frame then
            player.gui.screen.stats_charts_frame.destroy()
        end
        -- Clean up dashboard data
        if storage.dashboard_data and storage.dashboard_data[player.index] then
            storage.dashboard_data[player.index] = nil
        end
        
    -- Planet statistics GUI handlers
    elseif PLANET_STATS_ENABLED and element.name == "close_planet_stats" then
        if player.gui.screen.planet_stats_frame then
            player.gui.screen.planet_stats_frame.destroy()
        end
        if storage.planet_stats_state and storage.planet_stats_state[player.index] then
            storage.planet_stats_state[player.index].auto_show = false
        end
        
    elseif PLANET_STATS_ENABLED and string.match(element.name, "^ping_entity_") then
        local entity_index = tonumber(string.match(element.name, "(%d+)$"))
        if entity_index then
            -- Get current surface stats to find the entity
            local surface_stats = planet_stats.collect_surface_stats(player.surface)
            if surface_stats and surface_stats.entity_shortages[entity_index] then
                local shortage = surface_stats.entity_shortages[entity_index]
                
                -- Create ping at entity position
                player.create_local_flying_text{
                    text = {"gui.entity-pinged", shortage.name},
                    position = shortage.position,
                    time_to_live = 180
                }
                
                -- Center camera on entity
                player.zoom_to_world(shortage.position, 1)
                
                -- Create map ping for multiplayer
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
    end
end)

-- Commands
commands.add_command("stats", {"command.stats-help"}, function(command)
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
            if enabled and not player.gui.top.multiplayer_stats_frame then
                gui_main.create_stats_gui(player, utils, rankings)
            elseif not enabled and player.gui.top.multiplayer_stats_frame then
                player.gui.top.multiplayer_stats_frame.destroy()
                storage.gui_state[player_index].gui_open = false
            end
        end
    end
end) 

