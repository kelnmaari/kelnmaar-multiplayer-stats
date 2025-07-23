-- Multiplayer Statistics Mod
-- Modular version with lib/ structure

-- Import modules
local utils = require("lib.utils")
local rankings = require("lib.rankings")
local stats_module = require("lib.stats")
local gui = require("lib.gui")
local gui_main = require("lib.gui_main")

-- Store update frequency globally to avoid runtime settings access
local update_frequency = 300

-- Function to register periodic event handlers
local function register_periodic_handlers()
    -- Main stats update handler
    script.on_nth_tick(update_frequency, function(event)
        gui_main.update_stats_gui(utils, rankings)
        
        -- Update statistics tracking
        for _, player in pairs(game.players) do
            if player.connected then
                utils.init_player(player.index)
                stats_module.update_player_distance(player.index)
                stats_module.update_player_status(player)
                stats_module.update_chart_history(player.index, rankings)
                rankings.check_achievements(player.index, utils)
            end
        end
    end)
    
    -- Register periodic cleanup
    script.on_nth_tick(36000, utils.periodic_cleanup) -- Every 10 minutes
    
    -- Auto-refresh dashboards every 10 seconds
    script.on_nth_tick(600, function(event)
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
end

-- Event handlers
script.on_init(function()
    storage.players = {}
    storage.gui_state = {}
    
    -- Get update frequency from startup settings once
    update_frequency = settings.startup["multiplayer-stats-update-frequency"] and 
                      settings.startup["multiplayer-stats-update-frequency"].value or 300
    
    -- Register periodic handlers
    register_periodic_handlers()
end)

script.on_configuration_changed(function()
    storage.players = storage.players or {}
    storage.gui_state = storage.gui_state or {}
    
    -- Update frequency from startup settings (only during configuration change)
    update_frequency = settings.startup["multiplayer-stats-update-frequency"] and 
                      settings.startup["multiplayer-stats-update-frequency"].value or 300
    
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
end)

-- MEMORY LEAK FIX: Clean up data when players leave
script.on_event(defines.events.on_player_left_game, function(event)
    utils.cleanup_player_on_leave(event.player_index)
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
    end
end)

-- Commands
commands.add_command("stats", {"command.stats-help"}, function(command)
    local player = game.players[command.player_index]
    gui_main.create_stats_gui(player, utils, rankings)
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
                gui_main.create_stats_gui(player, utils, rankings)
            elseif not enabled and player.gui.top.multiplayer_stats_frame then
                player.gui.top.multiplayer_stats_frame.destroy()
                storage.gui_state[player_index].gui_open = false
            end
        end
    end
end) 

