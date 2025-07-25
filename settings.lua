-- Multiplayer Statistics Mod Settings
-- Settings for customizing mod behavior

data:extend({
    -- Startup settings (require restart)
    {
        type = "bool-setting",
        name = "multiplayer-stats-enable-mod",
        setting_type = "startup", 
        default_value = true,
        order = "a-a"
    },
    {
        type = "int-setting",
        name = "multiplayer-stats-update-frequency",
        setting_type = "startup",
        minimum_value = 60,
        maximum_value = 600,
        default_value = 300,
        order = "a-b"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-enable-planet-stats",
        setting_type = "startup",
        default_value = false,
        order = "a-c"
    },

    -- Runtime global settings (can be changed during game, admin only)
    {
        type = "bool-setting",
        name = "multiplayer-stats-enable-achievements",
        setting_type = "runtime-global",
        default_value = true,
        order = "b-a"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-broadcast-promotions",
        setting_type = "runtime-global",
        default_value = true,
        order = "b-b"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-broadcast-achievements",
        setting_type = "runtime-global",
        default_value = true,
        order = "b-c"
    },
    {
        type = "string-setting",
        name = "multiplayer-stats-ranking-mode",
        setting_type = "runtime-global",
        default_value = "score",
        allowed_values = {"score", "distance", "crafted", "combat", "building"},
        order = "b-d"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-enable-survival-achievements",
        setting_type = "runtime-global",
        default_value = true,
        order = "b-e"
    },

    -- Runtime per-user settings (individual for each player)
    {
        type = "bool-setting",
        name = "multiplayer-stats-show-notifications",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "c-a"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-auto-open-gui",
        setting_type = "runtime-per-user",
        default_value = false,
        order = "c-b"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-show-rank-progress",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "c-c"
    },
    {
        type = "string-setting",
        name = "multiplayer-stats-notification-position",
        setting_type = "runtime-per-user",
        default_value = "center",
        allowed_values = {"center", "top-left", "top-right", "bottom-left", "bottom-right"},
        order = "c-d"
    },
    {
        type = "int-setting",
        name = "multiplayer-stats-notification-duration",
        setting_type = "runtime-per-user",
        minimum_value = 3,
        maximum_value = 30,
        default_value = 10,
        order = "c-e"
    },
    {
        type = "bool-setting",
        name = "multiplayer-stats-enable-sounds",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "c-f"
    }
}) 