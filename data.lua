-- KelnMaar's Multiplayer Statistics - Custom GUI Styles
-- This file defines custom styles for our statistics and charts system

local styles = data.raw["gui-style"].default

-- === CHART STYLES ===

-- Chart frame style
styles.kelnmaar_chart_frame = {
    type = "frame_style",
    parent = "frame",
    padding = 8,
    margin = 4,
    minimal_width = 300,
    maximal_width = 400
}

-- Chart bar style (progress bar for charts)
styles.kelnmaar_chart_bar = {
    type = "progressbar_style",
    parent = "progressbar",
    bar_background = {
        base = {position = {0, 0}, corner_size = 8},
        shadow = {position = {0, 8}, corner_size = 8}
    }
}

-- Different colored chart bars
styles.kelnmaar_chart_bar_green = {
    type = "progressbar_style",
    parent = "kelnmaar_chart_bar",
    color = {r=0.2, g=0.8, b=0.2, a=1}
}

styles.kelnmaar_chart_bar_blue = {
    type = "progressbar_style",
    parent = "kelnmaar_chart_bar",
    color = {r=0.1, g=0.6, b=0.8, a=1}
}

styles.kelnmaar_chart_bar_red = {
    type = "progressbar_style",
    parent = "kelnmaar_chart_bar",
    color = {r=0.8, g=0.2, b=0.2, a=1}
}

styles.kelnmaar_chart_bar_yellow = {
    type = "progressbar_style",
    parent = "kelnmaar_chart_bar",
    color = {r=0.8, g=0.6, b=0.1, a=1}
}

styles.kelnmaar_chart_bar_purple = {
    type = "progressbar_style",
    parent = "kelnmaar_chart_bar",
    color = {r=0.6, g=0.2, b=0.8, a=1}
}

-- === RANK PROGRESS STYLES ===

-- Custom progress bar for rank progression
styles.kelnmaar_rank_progress = {
    type = "progressbar_style",
    parent = "progressbar",
    height = 24,
    color = {r=0.2, g=0.8, b=0.2, a=1},
    bar_background = {
        base = {
            corner_size = 8,
            position = {0, 0},
            size = {1, 1},
            color = {r=0.15, g=0.15, b=0.15, a=0.9}
        }
    },
    bar = {
        base = {
            corner_size = 8,
            position = {0, 0},
            size = {1, 1}
        }
    }
}

-- === LABEL STYLES ===

-- Chart title style
styles.kelnmaar_chart_title = {
    type = "label_style",
    parent = "frame_title",
    horizontal_align = "center",
    font_color = {r=0.9, g=0.9, b=1.0, a=1}
}

-- Chart value label style
styles.kelnmaar_chart_value = {
    type = "label_style",
    parent = "label",
    font = "default-bold",
    font_color = {r=1.0, g=1.0, b=1.0, a=1}
}

-- Statistics overview label
styles.kelnmaar_stats_label = {
    type = "label_style",
    parent = "bold_label",
    font_color = {r=0.7, g=0.9, b=1.0, a=1}
}

-- Achievement completed style
styles.kelnmaar_achievement_completed = {
    type = "label_style",
    parent = "bold_label",
    font_color = {r=0.2, g=0.8, b=0.2, a=1}
}

-- Achievement pending style
styles.kelnmaar_achievement_pending = {
    type = "label_style",
    parent = "label",
    font_color = {r=0.6, g=0.6, b=0.6, a=1}
}

-- === BUTTON STYLES ===

-- Chart window navigation buttons
styles.kelnmaar_nav_button = {
    type = "button_style",
    parent = "button",
    font = "default",
    padding = 6,
    margin = 2,
    minimal_width = 120,
    maximal_width = 150,
    height = 28,
    default_font_color = {r=0.9, g=0.9, b=1.0, a=1},
    hovered_font_color = {r=1.0, g=1.0, b=1.0, a=1},
    clicked_font_color = {r=0.8, g=0.8, b=0.9, a=1}
}

-- === TABLE STYLES ===

-- Custom table style for charts grid
styles.kelnmaar_charts_table = {
    type = "table_style",
    parent = "table",
    horizontal_spacing = 16,
    vertical_spacing = 16,
    cell_padding = 8
}

-- Pie chart cell style
styles.kelnmaar_pie_cell = {
    type = "flow_style",
    minimal_width = 12,
    maximal_width = 12,
    minimal_height = 12,
    maximal_height = 12
}

-- === FRAME STYLES ===

-- Statistics dashboard main frame
styles.kelnmaar_dashboard_frame = {
    type = "frame_style",
    parent = "frame",
    background_color = {r=0.08, g=0.08, b=0.12, a=0.95},
    border = {
        border_width = 3,
        color = {r=0.2, g=0.4, b=0.6, a=1}
    },
    padding = 12
}

-- Main statistics window frame (top panel)
styles.kelnmaar_main_stats_frame = {
    type = "frame_style",
    parent = "inside_shallow_frame",
    background_color = {r=0.06, g=0.06, b=0.08, a=0.9},
    border = {
        border_width = 2,
        color = {r=0.2, g=0.3, b=0.4, a=1}
    },
    padding = 8
}

-- Info panel frame
styles.kelnmaar_info_frame = {
    type = "frame_style",
    parent = "inside_shallow_frame_with_padding",
    background_color = {r=0.12, g=0.12, b=0.16, a=0.9},
    border = {
        border_width = 1,
        color = {r=0.3, g=0.5, b=0.7, a=0.8}
    }
}

-- === FLOW STYLES ===

-- Chart legend flow
styles.kelnmaar_legend_flow = {
    type = "horizontal_flow_style",
    horizontal_spacing = 12,
    vertical_align = "center"
}

-- === SCROLL PANE STYLES ===

-- Custom scroll pane for charts window
styles.kelnmaar_charts_scroll = {
    type = "scroll_pane_style",
    parent = "scroll_pane",
    background_color = {r=0.05, g=0.05, b=0.08, a=0.8},
    padding = 8
}

-- === CUSTOM INPUT EVENTS ===

-- Register custom input events and hotkeys
data:extend({
    {
        type = "custom-input",
        name = "toggle-multiplayer-stats",
        key_sequence = "SHIFT + ALT + S",
        consuming = "none"
    },
    -- Planet stats hotkey (feature must be enabled via startup setting "multiplayer-stats-enable-planet-stats")
    {
        type = "custom-input",
        name = "toggle-planet-stats",
        key_sequence = "SHIFT + ALT + P",
        consuming = "none"
    },
    -- Player rankings hotkey
    {
        type = "custom-input",
        name = "toggle-player-rankings",
        key_sequence = "SHIFT + ALT + R",
        consuming = "none"
    }
})

-- === SHORTCUT TOOLBAR BUTTONS ===

data:extend({
    {
        type = "shortcut",
        name = "toggle-multiplayer-stats",
        order = "a[kelnmaar]-a[stats]",
        action = "lua",
        associated_control_input = "toggle-multiplayer-stats",
        icon = "__kelnmaar-multiplayer-stats__/graphics/icons/shortcut-toolbar/stats-x32.png",
        icon_size = 32,
        small_icon = "__kelnmaar-multiplayer-stats__/graphics/icons/shortcut-toolbar/stats-x24.png",
        small_icon_size = 24
    },
    {
        type = "shortcut",
        name = "toggle-player-rankings",
        order = "a[kelnmaar]-b[rankings]",
        action = "lua",
        associated_control_input = "toggle-player-rankings",
        icon = "__kelnmaar-multiplayer-stats__/graphics/icons/shortcut-toolbar/rankings-x32.png",
        icon_size = 32,
        small_icon = "__kelnmaar-multiplayer-stats__/graphics/icons/shortcut-toolbar/rankings-x24.png",
        small_icon_size = 24
    },
    {
        type = "shortcut",
        name = "toggle-planet-stats",
        order = "a[kelnmaar]-c[planet]",
        action = "lua",
        associated_control_input = "toggle-planet-stats",
        icon = "__kelnmaar-multiplayer-stats__/graphics/icons/shortcut-toolbar/planet-x32.png",
        icon_size = 32,
        small_icon = "__kelnmaar-multiplayer-stats__/graphics/icons/shortcut-toolbar/planet-x24.png",
        small_icon_size = 24
    }
})
