-- lib/rankings.lua
-- Система рангов и достижений

local rankings = {}
local String = require("__stdlib2__/stdlib/utils/string")

-- Achievement definitions (перенесено из control.lua)
rankings.ACHIEVEMENTS = {
    -- Distance achievements (увеличены в 10 раз)
    {id = "distance_10k", type = "distance", threshold = 10000, name = "first-steps"},
    {id = "distance_100k", type = "distance", threshold = 100000, name = "explorer"},
    {id = "distance_500k", type = "distance", threshold = 500000, name = "wanderer"},
    {id = "distance_1m", type = "distance", threshold = 1000000, name = "nomad"},
    {id = "distance_10m", type = "distance", threshold = 10000000, name = "cosmic-wanderer"},
    
    -- Crafting achievements (увеличены в 10 раз)
    {id = "craft_1k", type = "crafted", threshold = 1000, name = "apprentice-crafter"},
    {id = "craft_10k", type = "crafted", threshold = 10000, name = "skilled-crafter"},
    {id = "craft_100k", type = "crafted", threshold = 100000, name = "master-crafter"},
    {id = "craft_1m", type = "crafted", threshold = 1000000, name = "legendary-crafter"},
    {id = "craft_10m", type = "crafted", threshold = 10000000, name = "industrial-god"},
    
    -- Combat achievements (увеличены в 100 раз)
    {id = "kills_1k", type = "combat", threshold = 1000, name = "first-blood"},
    {id = "kills_10k", type = "combat", threshold = 10000, name = "soldier"},
    {id = "kills_100k", type = "combat", threshold = 100000, name = "warrior"},
    {id = "kills_500k", type = "combat", threshold = 500000, name = "slayer"},
    {id = "kills_1m", type = "combat", threshold = 1000000, name = "exterminator"},
    
    -- Building achievements (увеличены в 20 раз)
    {id = "build_1k", type = "building", threshold = 1000, name = "builder"},
    {id = "build_10k", type = "building", threshold = 10000, name = "architect"},
    {id = "build_40k", type = "building", threshold = 40000, name = "engineer"},
    {id = "build_200k", type = "building", threshold = 200000, name = "industrial-master"},
    {id = "build_1m", type = "building", threshold = 1000000, name = "megastructure-builder"},
    
    -- Survival achievements (5 новых уровней)
    {id = "survive_1h", type = "survival", threshold = 216000, name = "survivor-1h"},         -- 1 час
    {id = "survive_10h", type = "survival", threshold = 2160000, name = "survivor-10h"},       -- 10 часов  
    {id = "survive_50h", type = "survival", threshold = 10800000, name = "survivor-50h"},      -- 50 часов
    {id = "survive_100h", type = "survival", threshold = 21600000, name = "survivor-100h"},    -- 100 часов
    {id = "survive_1000h", type = "survival", threshold = 216000000, name = "survivor-1000h"}, -- 1000 часов
    
    -- No Deaths achievements (5 новых уровней)
    {id = "no_deaths_1h", type = "no_deaths", threshold = 216000, name = "deathless-1h"},         -- 1 час
    {id = "no_deaths_10h", type = "no_deaths", threshold = 2160000, name = "deathless-10h"},       -- 10 часов
    {id = "no_deaths_50h", type = "no_deaths", threshold = 10800000, name = "deathless-50h"},      -- 50 часов
    {id = "no_deaths_100h", type = "no_deaths", threshold = 21600000, name = "deathless-100h"},    -- 100 часов
    {id = "no_deaths_1000h", type = "no_deaths", threshold = 216000000, name = "deathless-1000h"}, -- 1000 часов
    
    -- Space Age achievements (планеты + дальний космос)
    {id = "planets_1", type = "planets", threshold = 1, name = "space-pioneer"},        -- 1 планета
    {id = "planets_2", type = "planets", threshold = 2, name = "space-explorer"},       -- 2 планеты
    {id = "planets_3", type = "planets", threshold = 3, name = "interplanetary"},       -- 3 планеты
    {id = "planets_4", type = "planets", threshold = 4, name = "galactic-explorer"},    -- 4 планеты
    {id = "planets_5", type = "planets", threshold = 5, name = "universe-master"},      -- 5 планет
    {id = "deep_space", type = "deep_space", threshold = 1, name = "deep-space-explorer"} -- Дальний космос
}

-- Rank system (перенесено из control.lua)
rankings.RANKS = {
    {name = "recruit", icon = "🔰", min_score = 0, color = {r=0.8, g=0.8, b=0.8}},
    {name = "private", icon = "🥉", min_score = 500, color = {r=0.8, g=0.6, b=0.4}},
    {name = "specialist", icon = "⚪", min_score = 1500, color = {r=0.9, g=0.9, b=0.9}},
    {name = "corporal", icon = "🥈", min_score = 3000, color = {r=0.8, g=0.8, b=0.9}},
    {name = "sergeant", icon = "⭐", min_score = 6000, color = {r=1.0, g=1.0, b=0.0}},
    {name = "lieutenant", icon = "🔸", min_score = 12000, color = {r=0.0, g=0.8, b=1.0}},
    {name = "captain", icon = "🏅", min_score = 24000, color = {r=1.0, g=0.8, b=0.0}},
    {name = "major", icon = "💎", min_score = 50000, color = {r=0.0, g=1.0, b=1.0}},
    {name = "colonel", icon = "🥇", min_score = 100000, color = {r=1.0, g=0.8, b=0.0}},
    {name = "general", icon = "⚡", min_score = 200000, color = {r=1.0, g=1.0, b=0.0}},
    {name = "marshal", icon = "👑", min_score = 400000, color = {r=1.0, g=0.5, b=0.0}},
    {name = "legend", icon = "🌟", min_score = 800000, color = {r=1.0, g=0.0, b=1.0}},
    {name = "myth", icon = "🔥", min_score = 1600000, color = {r=1.0, g=0.2, b=0.2}},
    {name = "deity", icon = "⚡", min_score = 3200000, color = {r=0.5, g=0.0, b=1.0}},
    {name = "overlord", icon = "😈", min_score = 6400000, color = {r=0.6, g=0.0, b=0.0}},
    {name = "titan", icon = "⚔️", min_score = 12800000, color = {r=0.0, g=0.0, b=1.0}},
    {name = "supreme", icon = "💀", min_score = 25600000, color = {r=0.2, g=0.2, b=0.2}},
    {name = "eternal", icon = "♾️", min_score = 51200000, color = {r=1.0, g=1.0, b=1.0}},
    {name = "cosmic", icon = "🌌", min_score = 102400000, color = {r=0.5, g=0.0, b=0.5}},
    {name = "infinite", icon = "∞", min_score = 204800000, color = {r=1.0, g=0.0, b=0.0}},
    {name = "transcendent", icon = "🚀", min_score = 409600000, color = {r=0.0, g=1.0, b=0.0}},
    {name = "godlike", icon = "👁️", min_score = 819200000, color = {r=1.0, g=1.0, b=0.0}}
}
-- Rank calculation cache for performance optimization
local rank_cache = {}
local RANK_CACHE_TTL = 300 -- 5 seconds (300 ticks)

-- Clear rank cache for a specific player (call when stats change significantly)
function rankings.invalidate_rank_cache(player_index)
    rank_cache[player_index] = nil
end

-- Calculate player rank and score (with optional caching)
function rankings.calculate_player_rank(stats, player_index)
    -- Check cache if player_index provided
    if player_index and rank_cache[player_index] then
        local cached = rank_cache[player_index]
        if game.tick - cached.tick < RANK_CACHE_TTL then
            return cached.rank, cached.score
        end
    end
    
    local score = 0
    
    -- Distance scoring (with diminishing returns)
    local distance = stats.distance_traveled or 0
    if distance > 0 then
        score = score + math.floor(math.log(distance + 1) * 100)
    end
    
    -- Crafting scoring (with diminishing returns) 
    local crafted = stats.total_crafted or 0
    if crafted > 0 then
        score = score + math.floor(math.log(crafted + 1) * 150)
    end
    
    -- Combat scoring (K/D ratio consideration)
    local kills = stats.enemies_killed or 0
    local deaths = math.max(stats.deaths or 0, 1) -- Prevent division by zero
    local kd_ratio = kills / deaths
    score = score + math.floor(kills * kd_ratio * 0.5)
    
    -- Building scoring
    local buildings = stats.buildings_built or 0
    score = score + math.floor(buildings * 2)
    
    -- Resource mining scoring
    if stats.resources_mined then
        local total_mined = 0
        local resource_types = 0
        for resource, count in pairs(stats.resources_mined) do
            if count > 0 then
                total_mined = total_mined + count
                resource_types = resource_types + 1
            end
        end
        score = score + math.floor(total_mined * 0.1) + (resource_types * 50)
    end
    
    -- Planet exploration bonus
    if stats.planets_visited then
        local planet_count = 0
        for planet_name, _ in pairs(stats.planets_visited) do
            -- Исключаем платформы (имя начинается с 'platform')
            if not String.starts_with(planet_name, "platform") then
                planet_count = planet_count + 1
            end
        end
        score = score + (planet_count * 1000)
    end
    
    -- Deep space exploration bonus
    if stats.deep_space_visited then
        score = score + 5000
    end
    
    -- Playtime bonus (small)
    local hours_played = (stats.playtime_ticks or 0) / 216000
    score = score + math.floor(hours_played * 10)
    
    -- Find current rank
    local current_rank = rankings.RANKS[1]
    for _, rank in ipairs(rankings.RANKS) do
        if score >= rank.min_score then
            current_rank = rank
        else
            break
        end
    end
    
    -- Cache the result if player_index provided
    if player_index then
        rank_cache[player_index] = {
            rank = current_rank,
            score = score,
            tick = game.tick
        }
    end
    
    return current_rank, score
end

-- Check for new achievements
function rankings.check_achievements(player_index, utils)
    local player = game.players[player_index]
    local stats = storage.players[player_index]
    
    for _, achievement in pairs(rankings.ACHIEVEMENTS) do
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
                -- Проверка достижений выживания - просто по времени игры
                if stats.playtime_ticks >= achievement.threshold then
                    unlocked = true
                end
            elseif achievement.type == "no_deaths" then
                -- Проверка достижений без смертей - время игры БЕЗ смертей
                if (stats.deaths or 0) == 0 and stats.playtime_ticks >= achievement.threshold then
                    unlocked = true
                end
            elseif achievement.type == "planets" then
                local planet_count = 0
                if stats.planets_visited then
                    for planet_name, _ in pairs(stats.planets_visited) do
                        -- Исключаем платформы (имя начинается с 'platform')
                        if not String.starts_with(planet_name, "platform") then
                            planet_count = planet_count + 1
                        end
                    end
                end
                if planet_count >= achievement.threshold then
                    unlocked = true
                end
            elseif achievement.type == "deep_space" then
                -- Проверка достижения дальнего космоса - посещение специальной планеты/локации
                if stats.deep_space_visited then
                    unlocked = true
                end
            end
            
            if unlocked then
                stats.achievements[achievement.id] = game.tick
                rankings.show_achievement_notification(player, achievement.name, utils)
                
                -- Broadcast achievement if enabled
                if settings.global["multiplayer-stats-broadcast-achievements"] and
                   settings.global["multiplayer-stats-broadcast-achievements"].value then
                    game.print({"message.achievement-unlocked", player.name, {"achievement." .. achievement.name}})
                end
            end
        end
    end
    
    -- Check for rank promotion
    local current_rank, score = rankings.calculate_player_rank(stats)
    if current_rank.name ~= stats.last_rank then
        local old_rank = nil
        for _, rank in pairs(rankings.RANKS) do
            if rank.name == stats.last_rank then
                old_rank = rank
                break
            end
        end
        
        if old_rank then
            -- Show rank up notification
            rankings.show_rank_notification(player, current_rank, utils)
            
            -- Broadcast rank promotion if enabled
            if settings.global["multiplayer-stats-broadcast-promotions"] and
               settings.global["multiplayer-stats-broadcast-promotions"].value then
                game.print({"message.rank-promotion", player.name, current_rank.icon, {"gui.rank-" .. current_rank.name}})
            end
        end
        
        stats.last_rank = current_rank.name
    end
end

-- Show achievement notification
function rankings.show_achievement_notification(player, achievement_name, utils)
    local user_settings = settings.get_player_settings(player.index)
    
    if user_settings["multiplayer-stats-show-notifications"] and
       user_settings["multiplayer-stats-show-notifications"].value then
        
        player.create_local_flying_text{
            text = {"achievement.achievement-unlocked"},
            position = player.position,
            color = {r=0.2, g=0.8, b=0.2},
            time_to_live = 120
        }
        
        player.create_local_flying_text{
            text = {"achievement." .. achievement_name},
            position = {player.position.x, player.position.y + 1},
            color = {r=1.0, g=1.0, b=0.0},
            time_to_live = 180
        }
        
        if user_settings["multiplayer-stats-enable-sounds"] and
           user_settings["multiplayer-stats-enable-sounds"].value then
            player.play_sound{path = "utility/achievement_unlocked"}
        end
    end
end

-- Show rank promotion notification
function rankings.show_rank_notification(player, new_rank, utils)
    local user_settings = settings.get_player_settings(player.index)
    
    if user_settings["multiplayer-stats-show-notifications"] and
       user_settings["multiplayer-stats-show-notifications"].value then
        
        player.create_local_flying_text{
            text = {"message.rank-up"},
            position = player.position,
            color = {r=0.8, g=0.2, b=0.8},
            time_to_live = 120
        }
        
        player.create_local_flying_text{
            text = {"", new_rank.icon, " ", {"gui.rank-" .. new_rank.name}},
            position = {player.position.x, player.position.y + 1},
            color = new_rank.color or {r=1.0, g=1.0, b=1.0},
            time_to_live = 180
        }
        
        if user_settings["multiplayer-stats-enable-sounds"] and
           user_settings["multiplayer-stats-enable-sounds"].value then
            player.play_sound{path = "utility/new_objective"}
        end
    end
end

return rankings 