-- lib/planet_stats.lua
-- Статистика планет и космических платформ

local planet_stats = {}

-- Константы
local BATCH_SIZE = 200  -- Объектов за один тик
local PROCESSING_INTERVAL = 3  -- Каждые 3 тика

-- ============================================
-- АСИНХРОННАЯ СИСТЕМА СБОРА СТАТИСТИКИ
-- ============================================

-- Инициализировать асинхронный сбор для игрока
function planet_stats.start_async_collection(player)
    if not player or not player.valid then return nil end
    
    local surface = player.surface
    if not surface or not surface.valid then return nil end
    
    -- Инициализация storage
    if not storage.planet_stats_processing then
        storage.planet_stats_processing = {}
    end
    
    -- Базовые категории для обеспечения полноты охвата
    local production_base_types = {
        ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true, 
        ["chemical-plant"] = true, ["oil-refinery"] = true, ["agricultural-tower"] = true, 
        ["biochamber"] = true, ["foundry"] = true, ["electromagnetic-plant"] = true, 
        ["cryogenic-plant"] = true, ["rocket-silo"] = true
    }
    
    local power_base_types = {
        ["solar-panel"] = true, ["generator"] = true, ["burner-generator"] = true, 
        ["fusion-generator"] = true, ["fusion-reactor"] = true, ["reactor"] = true,
        ["nuclear-reactor"] = true, ["accumulator"] = true, ["electric-energy-interface"] = true, 
        ["radar"] = true, ["beacon"] = true, ["roboport"] = true, ["lamp"] = true, 
        ["inserter"] = true, ["pump"] = true, ["electric-turret"] = true, 
        ["laser-turret"] = true, ["lab"] = true, ["arithmetic-combinator"] = true,
        ["decider-combinator"] = true, ["constant-combinator"] = true
    }
    
    -- Динамически собираем все типы
    local electric_types = {}
    for t, _ in pairs(production_base_types) do electric_types[t] = true end
    for t, _ in pairs(power_base_types) do electric_types[t] = true end
    
    for name, proto in pairs(prototypes.entity) do
        local p_type = proto.type
        if not electric_types[p_type] then
            -- Проверяем наличие электрической энергосистемы (Factorio 2.0 API)
            local success, es = pcall(function() return proto.electric_energy_source_prototype end)
            if success and es then
                electric_types[p_type] = true
            end
        end
    end
    
    -- Формируем список типов для поиска (массив)
    local types_to_scan = {}
    for t, _ in pairs(electric_types) do
        types_to_scan[#types_to_scan + 1] = t
    end
    
    -- Ищем все сущности на поверхности
    local entities = surface.find_entities_filtered{type = types_to_scan}
    
    -- Собираем все объекты
    local all_entities = {}
    for _, entity in pairs(entities) do
        local category = production_base_types[entity.type] and "production" or "power"
        all_entities[#all_entities + 1] = {entity = entity, category = category}
    end
    
    -- Создаём состояние обработки
    storage.planet_stats_processing[player.index] = {
        surface_name = surface.name,
        force = player.force,
        all_entities = all_entities,
        current_index = 1,
        total_count = #all_entities,
        in_progress = true,
        stats = {
            surface_name = surface.name,
            production = {},
            power_generation = 0,
            power_consumption = 0,
            entity_shortages = {},
            total_entities = #all_entities,
            working_entities = 0,
            processed_entities = 0,
            power_producers = 0,
            power_consumers = 0,
            debug_power_info = {
                producers = {},
                consumers = {}
            },
            network_power = nil  -- Будет заполнено из electric_network_statistics
        }
    }
    
    -- Сразу собираем статистику электросетей (она быстрая)
    planet_stats.collect_network_power_stats(player, storage.planet_stats_processing[player.index].stats)
    
    return storage.planet_stats_processing[player.index]
end

-- Обработать пачку объектов для игрока
function planet_stats.process_batch(player_index)
    local state = storage.planet_stats_processing and storage.planet_stats_processing[player_index]
    if not state or not state.in_progress then return false end
    
    local processed_this_batch = 0
    
    while processed_this_batch < BATCH_SIZE and state.current_index <= state.total_count do
        local item = state.all_entities[state.current_index]
        state.current_index = state.current_index + 1
        
        if item and item.entity and item.entity.valid then
            if item.category == "production" then
                planet_stats.collect_production_stats(item.entity, state.stats)
                planet_stats.collect_power_stats(item.entity, state.stats)
                planet_stats.check_entity_shortages(item.entity, state.stats)
            else
                planet_stats.collect_power_stats(item.entity, state.stats)
            end
            processed_this_batch = processed_this_batch + 1
            state.stats.processed_entities = state.stats.processed_entities + 1
        end
    end
    
    -- Проверяем завершение
    if state.current_index > state.total_count then
        state.in_progress = false
    end
    
    -- Обновляем статистику энергии каждый батч для актуальности
    local player = game.players[player_index]
    if player and player.valid then
        planet_stats.collect_network_power_stats(player, state.stats)
    end
    
    return state.in_progress
end

-- Получить текущую статистику (даже если сбор не завершён)
function planet_stats.get_current_stats(player_index)
    local state = storage.planet_stats_processing and storage.planet_stats_processing[player_index]
    if not state then return nil end
    
    return state.stats, state.in_progress, state.current_index, state.total_count
end

-- Остановить асинхронный сбор
function planet_stats.stop_async_collection(player_index)
    if storage.planet_stats_processing then
        storage.planet_stats_processing[player_index] = nil
    end
end

-- Получить интервал обработки
function planet_stats.get_processing_interval()
    return PROCESSING_INTERVAL
end

-- ============================================
-- СБОР СТАТИСТИКИ ЭЛЕКТРОСЕТЕЙ (БЫСТРЫЙ)
-- ============================================

-- Собрать статистику электросетей через API
function planet_stats.collect_network_power_stats(player, stats)
    if not player or not player.valid then return end
    
    local surface = player.surface
    local force = player.force
    
    if not surface or not surface.valid or not force then return end
    
    -- Пробуем получить статистику электросетей через LuaSurface API (Factorio 2.0)
    local success, net_stats = pcall(function()
        return surface.get_electric_network_statistics()
    end)
    
    if success and net_stats then
        local input_total = 0
        local output_total = 0
        
        -- Используем 1-минутное усреднение
        local precision = defines.flow_precision_index.one_minute
        
        -- Потребление
        local success_in, result_in = pcall(function() return net_stats.input_counts end)
        if success_in and result_in then
            for name, current_val in pairs(result_in or {}) do
                local flow = 0
                pcall(function() flow = net_stats.get_flow_count(name, "input", precision) end)
                
                -- Если flow по какой-то причине 0 (например, баг API 2.0 или новосозданная сеть), 
                -- используем текущее значение за тик
                if flow and flow > 0 then
                    input_total = input_total + (flow / 60)
                elseif current_val then
                    input_total = input_total + (current_val * 60)
                end
            end
        end
        
        -- Производство
        local success_out, result_out = pcall(function() return net_stats.output_counts end)
        if success_out and result_out then
            for name, current_val in pairs(result_out or {}) do
                local flow = 0
                pcall(function() flow = net_stats.get_flow_count(name, "output", precision) end)
                
                if flow and flow > 0 then
                    output_total = output_total + (flow / 60)
                elseif current_val then
                    output_total = output_total + (current_val * 60)
                end
            end
        end
        
        stats.network_power = {
            consumption = input_total,
            production = output_total,
            available = (input_total > 0 or output_total > 0)
        }
    else
        stats.network_power = {
            consumption = 0,
            production = 0,
            available = false
        }
    end
end

-- ============================================
-- СИНХРОННЫЙ СБОР (для совместимости)
-- ============================================

-- Собрать статистику текущей поверхности (синхронно, ограничено 1000 объектов)
function planet_stats.collect_surface_stats(surface)
    if not surface or not surface.valid then
        return nil
    end
    
    local stats = {
        surface_name = surface.name,
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
    }
    
    -- Типы объектов
    local production_types = {
        ["assembling-machine"] = true, ["furnace"] = true, ["mining-drill"] = true,
        ["chemical-plant"] = true, ["oil-refinery"] = true, ["agricultural-tower"] = true,
        ["biochamber"] = true, ["foundry"] = true, ["electromagnetic-plant"] = true,
        ["cryogenic-plant"] = true
    }
    
    local power_types = {
        ["solar-panel"] = true, ["steam-engine"] = true, ["steam-turbine"] = true,
        ["nuclear-reactor"] = true, ["generator"] = true, ["burner-generator"] = true,
        ["fusion-generator"] = true, ["fusion-reactor"] = true, ["accumulator"] = true,
        ["electric-energy-interface"] = true, ["lab"] = true, ["radar"] = true,
        ["pump"] = true, ["inserter"] = true, ["beacon"] = true, ["roboport"] = true,
        ["lamp"] = true, ["electric-turret"] = true, ["laser-turret"] = true
    }
    
    local all_entities = {}
    
    for entity_type, _ in pairs(production_types) do
        local entities = surface.find_entities_filtered{type = entity_type}
        for _, entity in pairs(entities) do
            table.insert(all_entities, {entity = entity, category = "production"})
        end
    end
    
    for entity_type, _ in pairs(power_types) do
        local entities = surface.find_entities_filtered{type = entity_type}
        for _, entity in pairs(entities) do
            table.insert(all_entities, {entity = entity, category = "power"})
        end
    end
    
    stats.total_entities = #all_entities
    
    -- Ограничение
    local MAX_ENTITIES = 1000
    local count = 0
    
    for _, item in pairs(all_entities) do
        if count >= MAX_ENTITIES then break end
        if item.entity and item.entity.valid then
            if item.category == "production" then
                planet_stats.collect_production_stats(item.entity, stats)
                planet_stats.collect_power_stats(item.entity, stats)
                planet_stats.check_entity_shortages(item.entity, stats)
            else
                planet_stats.collect_power_stats(item.entity, stats)
            end
            count = count + 1
        end
    end
    
    stats.processed_entities = count
    
    return stats
end

-- Собрать статистику производства для объекта
-- Следует принципам безопасного программирования Factorio API:
-- - Использует pcall для безопасного доступа к свойствам прототипа
-- - Валидирует типы данных
-- - Проверяет существование методов перед вызовом
function planet_stats.collect_production_stats(entity, stats)
    if not entity.valid then return end
    
    -- Проверяем работает ли объект
    local is_working = false
    local recipe_name = "unknown"
    
    if entity.type == "assembling-machine" or 
       entity.type == "furnace" or
       entity.type == "foundry" or
       entity.type == "electromagnetic-plant" or
       entity.type == "cryogenic-plant" then
        -- Безопасная проверка существования метода и рецепта
        if entity.get_recipe and entity.get_recipe() then
            local recipe = entity.get_recipe()
            if recipe and recipe.name then
                recipe_name = recipe.name
                is_working = entity.status == defines.entity_status.working
            end
        end
    elseif entity.type == "mining-drill" or entity.type == "agricultural-tower" then
        recipe_name = entity.type == "agricultural-tower" and "farming" or "mining"
        is_working = entity.status == defines.entity_status.working
    elseif entity.type == "chemical-plant" or 
           entity.type == "oil-refinery" or
           entity.type == "biochamber" then
        -- Безопасная проверка существования метода и рецепта
        if entity.get_recipe and entity.get_recipe() then
            local recipe = entity.get_recipe()
            if recipe and recipe.name then
                recipe_name = recipe.name
                is_working = entity.status == defines.entity_status.working
            end
        end
    end
    
    if is_working then
        stats.working_entities = stats.working_entities + 1
        
        if not stats.production[recipe_name] then
            stats.production[recipe_name] = {
                count = 0,
                productivity = 0
            }
        end
        
        stats.production[recipe_name].count = stats.production[recipe_name].count + 1
        
        -- Приблизительная производительность (базовая + модули)
        -- Согласно документации API: используем безопасный доступ к свойствам
        local base_speed = 1
        
        -- Безопасный способ получения скорости крафта через pcall
        local function get_crafting_speed()
            local success, speed = pcall(function() return entity.prototype.crafting_speed end)
            return success and speed or nil
        end
        
        local function get_smelting_speed()
            local success, speed = pcall(function() return entity.prototype.smelting_speed end)
            return success and speed or nil
        end
        
        local function get_mining_speed()
            local success, speed = pcall(function() return entity.prototype.mining_speed end)
            return success and speed or nil
        end
        
        if entity.type == "assembling-machine" or 
           entity.type == "chemical-plant" or 
           entity.type == "oil-refinery" or
           entity.type == "biochamber" or
           entity.type == "electromagnetic-plant" or
           entity.type == "cryogenic-plant" then
            local speed = get_crafting_speed()
            if speed then base_speed = speed end
        elseif entity.type == "furnace" or entity.type == "foundry" then
            local speed = get_smelting_speed()
            if speed then base_speed = speed end
        elseif entity.type == "mining-drill" or entity.type == "agricultural-tower" then
            local speed = get_mining_speed()
            if speed then base_speed = speed end
        end
        
        local productivity = base_speed
        -- Учитываем эффекты модулей (включая качество в Factorio 2.0+)
        -- Безопасная проверка существования и валидности effects
        if entity.effects and type(entity.effects) == "table" then
            local productivity_bonus = 1
            local speed_bonus = 1
            
            -- Безопасная проверка каждого эффекта
            if entity.effects.productivity and type(entity.effects.productivity) == "number" then
                productivity_bonus = entity.effects.productivity
            end
            if entity.effects.speed and type(entity.effects.speed) == "number" then
                speed_bonus = entity.effects.speed
            end
            
            productivity = productivity * productivity_bonus * speed_bonus
        end
        stats.production[recipe_name].productivity = 
            stats.production[recipe_name].productivity + productivity
    end
end

-- Собрать статистику электроэнергии
-- Следует рекомендациям документации Factorio 2.0+ Energy API
-- Использует безопасный доступ через pcall для предотвращения ошибок с несуществующими свойствами
-- Логика: производители только производят, потребители только потребляют, аккумуляторы - и то и другое
function planet_stats.collect_power_stats(entity, stats)
    if not entity.valid then return end
    
    local energy_production = 0
    local energy_consumption = 0
    local is_producer = false
    local is_consumer = false
    
    -- Получаем данные из прототипа (Factorio 2.0 API)
    local proto = entity.prototype
    local es_proto = proto.electric_energy_source_prototype
    
    -- 1. Расчет генерации (универсальный для любых генераторов)
    local max_prod = 0
    local ent_type = entity.type
    
    -- Принудительно считаем эти типы производителями
    if ent_type == "generator" or ent_type == "burner-generator" or 
       ent_type == "solar-panel" or ent_type == "fusion-generator" or
       ent_type == "reactor" or ent_type == "nuclear-reactor" then
        is_producer = true
    end
    
    -- Ищем максимальную мощность в прототипе (Factorio 2.0 каскад)
    
    -- Приоритет 1: Метод get_max_power_output() - Новинка 2.0
    if max_prod <= 0 then
        local s, r = pcall(function() return proto.get_max_power_output() end)
        if s and r and r > 0 then max_prod = r end
    end
    
    -- Приоритет 2: Свойство max_power_output (Топливные генераторы Bob's)
    if max_prod <= 0 then
        local s, r = pcall(function() return proto.max_power_output end)
        if s and r and r > 0 then max_prod = r end
    end
    
    -- Приоритет 3: Свойство max_energy_production (Паровые двигатели)
    if max_prod <= 0 then
        local s, r = pcall(function() return proto.max_energy_production end)
        if s and r and r > 0 then max_prod = r end
    end
    
    -- Приоритет 4: Свойство production (Солнечные панели)
    if max_prod <= 0 then
        local s, r = pcall(function() return proto.production end)
        if s and r and r > 0 then max_prod = r end
    end
    
    -- Приоритет 5: Свойство production_capacity (EEI интерфейсы)
    if max_prod <= 0 then
        local s, r = pcall(function() return proto.production_capacity end)
        if s and r and r > 0 then max_prod = r end
    end
    
    if max_prod > 0 then
        energy_production = max_prod * 60
        is_producer = true
    else
        -- Резервный вариант (фактическая генерация)
        local success_prod, result_prod = pcall(function() return entity.energy_generated_last_tick end)
        if success_prod and result_prod and result_prod > 0 then
            energy_production = result_prod * 60
            is_producer = true
        end
    end
    
    -- 2. Расчет потребления (Factorio 2.0: energy_usage_last_tick больше нет, используем статусы)
    if es_proto then
        is_consumer = true
        
        local drain = 0
        local success_dr, res_dr = pcall(function() return es_proto.drain end)
        if success_dr and res_dr then drain = res_dr end
        
        local max_usage = 0
        local success_us, res_us = pcall(function() return proto.energy_usage end)
        if success_us and res_us then 
            max_usage = res_us 
        else
            -- Запасной вариант для некоторых типов объектов
            local success_us2, res_us2 = pcall(function() return proto.max_energy_usage end)
            if success_us2 and res_us2 then max_usage = res_us2 end
        end
        
        if entity.status == defines.entity_status.working or 
           entity.status == defines.entity_status.normal then
            energy_consumption = max_usage * 60
        else
            energy_consumption = drain * 60
        end
    end
    
    -- Обновляем глобальную статистику
    if is_producer or energy_production > 0 then
        stats.power_generation = stats.power_generation + energy_production
        stats.power_producers = stats.power_producers + 1
        
        -- Дебаг информация для производителей
        if not stats.debug_power_info.producers[entity.name] then
            stats.debug_power_info.producers[entity.name] = {name = entity.name, count = 0, power = 0}
        end
        local di = stats.debug_power_info.producers[entity.name]
        di.count = di.count + 1
        di.power = di.power + energy_production
    end
    
    if is_consumer then
        stats.power_consumption = stats.power_consumption + energy_consumption
        stats.power_consumers = stats.power_consumers + 1
        
        -- Дебаг информация для потребителей
        if not stats.debug_power_info.consumers[entity.name] then
            stats.debug_power_info.consumers[entity.name] = {name = entity.name, count = 0, power = 0}
        end
        local di = stats.debug_power_info.consumers[entity.name]
        di.count = di.count + 1
        di.power = di.power + energy_consumption
    end
end

-- Проверить нехватку ресурсов в объектах
function planet_stats.check_entity_shortages(entity, stats)
    if not entity.valid then return end
    
    local has_shortage = false
    local shortage_items = {}
    
    -- Проверяем объекты с инвентарем (включая новые типы Space Age)
    if entity.type == "assembling-machine" or 
       entity.type == "furnace" or
       entity.type == "foundry" or
       entity.type == "chemical-plant" or
       entity.type == "oil-refinery" or
       entity.type == "biochamber" or
       entity.type == "electromagnetic-plant" or
       entity.type == "cryogenic-plant" then
        
        -- Проверяем статус простоя из-за нехватки материалов
        if entity.status == defines.entity_status.no_ingredients_1 or
           entity.status == defines.entity_status.no_ingredients_2 or
           entity.status == defines.entity_status.no_input_fluid then
            
            has_shortage = true
            
            -- Получаем рецепт и недостающие ингредиенты
            -- Безопасная проверка существования метода и рецепта
            if entity.get_recipe and entity.get_recipe() then
                local recipe = entity.get_recipe()
                if recipe and recipe.ingredients then
                    for _, ingredient in pairs(recipe.ingredients) do
                        if ingredient and ingredient.name and ingredient.amount then
                            local inventory = entity.get_inventory(defines.inventory.assembling_machine_input)
                            if inventory then
                                local available = inventory.get_item_count(ingredient.name)
                                if available < ingredient.amount then
                                    table.insert(shortage_items, {
                                        item = ingredient.name,
                                        needed = ingredient.amount,
                                        available = available
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if has_shortage then
        table.insert(stats.entity_shortages, {
            entity = entity,
            position = entity.position,
            name = entity.name,
            surface = entity.surface.name,
            shortage_items = shortage_items
        })
    end
end

-- Создать GUI для отображения планетарной статистики
function planet_stats.create_planet_stats_gui(player, surface_stats)
    local player_index = player.index
    
    -- Инициализируем state если нужно
    if not storage.planet_stats_state then
        storage.planet_stats_state = {}
    end
    if not storage.planet_stats_state[player_index] then
        storage.planet_stats_state[player_index] = {}
    end
    
    -- Сохраняем текущую позицию окна перед удалением в storage
    if player.gui.screen.planet_stats_frame then
        storage.planet_stats_state[player_index].gui_position = player.gui.screen.planet_stats_frame.location
        player.gui.screen.planet_stats_frame.destroy()
    end
    
    -- Создаем главную рамку
    local frame = player.gui.screen.add{
        type = "frame",
        name = "planet_stats_frame",
        direction = "vertical",
        caption = {
            "gui.planet-stats-title", 
            surface_stats.surface_name, 
            surface_stats.processed_entities or 0, 
            surface_stats.total_entities or 0
        }
    }
    frame.style.width = 750  -- Значительно увеличиваем ширину
    frame.style.height = 700
    
    -- Восстанавливаем сохраненную позицию из storage или ставим по центру
    local saved_location = storage.planet_stats_state[player_index].gui_position
    if saved_location then
        frame.location = saved_location
    else
        -- Центрируем окно
        local scale = player.display_scale
        local res = player.display_resolution
        frame.location = {
            (res.width / scale - 750) / 2,
            (res.height / scale - 700) / 2
        }
    end
    
    -- Заголовок с кнопкой закрытия
    local titlebar = frame.add{
        type = "flow",
        direction = "horizontal"
    }
    
    local spacer = titlebar.add{type = "empty-widget"}
    spacer.style.horizontally_stretchable = true
    
    titlebar.add{
        type = "sprite-button",
        name = "close_planet_stats",
        sprite = "utility/close_black",
        style = "frame_action_button",
        tooltip = {"gui.close"}
    }
    
    -- Контент - двухколоночный layout
    local content = frame.add{
        type = "flow",
        name = "planet_stats_content",
        direction = "vertical"
    }
    
    -- 1. Информация о полноте статистики (сверху на всю ширину)
    -- 1. Прогресс-бар для асинхронной загрузки (показываем в заголовке окна)
    -- Не добавляем info_section - прогресс показывается в title окна
    
    -- 2. Двухколоночный layout с прокруткой для основного контента
    local scroll_pane = content.add{
        type = "scroll-pane",
        name = "planet_stats_scroll",
        direction = "vertical",
        horizontal_scroll_policy = "never",
        vertical_scroll_policy = "auto"
    }
    scroll_pane.style.maximal_height = 750 -- Ограничиваем высоту для маленьких экранов
    scroll_pane.style.horizontally_stretchable = true
    
    local columns = scroll_pane.add{
        type = "flow",
        name = "planet_stats_columns",
        direction = "horizontal"
    }
    columns.style.horizontal_spacing = 8
    
    -- Левая колонка - производство
    local left_column = columns.add{
        type = "flow",
        name = "left_column",
        direction = "vertical"
    }
    left_column.style.width = 360
    left_column.style.vertical_spacing = 4
    
    -- Правая колонка - энергия и нехватки
    local right_column = columns.add{
        type = "flow",
        name = "right_column",
        direction = "vertical"
    }
    right_column.style.width = 360
    right_column.style.vertical_spacing = 4
    
    -- Добавляем секции в колонки
    planet_stats.add_production_section(left_column, surface_stats)
    
    planet_stats.add_power_section(right_column, surface_stats)
    planet_stats.add_debug_power_section(right_column, surface_stats)
    planet_stats.add_shortages_section(right_column, surface_stats, player)
    
    return frame
end

-- Добавить информационную секцию о полноте статистики
function planet_stats.add_info_section(parent, stats)
    local info_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_info_frame"
    }
    
    info_frame.add{
        type = "label",
        caption = {"gui.info-title"},
        style = "kelnmaar_chart_title"
    }
    
    local info_label = info_frame.add{
        type = "label",
        caption = {"gui.stats-incomplete", stats.processed_entities, stats.total_entities}
    }
    info_label.style.font_color = {r = 1, g = 0.8, b = 0}  -- Желтый цвет для предупреждения
end

-- Добавить секцию производства
function planet_stats.add_production_section(parent, stats)
    local production_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_info_frame"
    }
    
    production_frame.add{
        type = "label",
        caption = {"gui.planet-production"},
        style = "kelnmaar_chart_title"
    }
    
    if next(stats.production) then
        local production_table = production_frame.add{
            type = "table",
            column_count = 3
        }
        production_table.style.horizontally_stretchable = true
        production_table.style.width = 345 -- Соответствует новой ширине колонки
        production_table.style.column_alignments[1] = "left"
        production_table.style.column_alignments[2] = "right"
        production_table.style.column_alignments[3] = "right"
        production_table.style.horizontal_spacing = 12
        
        -- Заголовки
        local h1 = production_table.add{type = "label", caption = {"gui.recipe"}, style = "bold_label"}
        h1.style.minimal_width = 180
        local h2 = production_table.add{type = "label", caption = {"gui.count"}, style = "bold_label"}
        h2.style.minimal_width = 60
        local h3 = production_table.add{type = "label", caption = {"gui.productivity"}, style = "bold_label"}
        h3.style.minimal_width = 60
        
        -- Сортируем по количеству объектов
        local sorted_production = {}
        for recipe, data in pairs(stats.production) do
            table.insert(sorted_production, {recipe = recipe, data = data})
        end
        table.sort(sorted_production, function(a, b) return a.data.count > b.data.count end)
        
        -- Отображаем топ-10 рецептов
        for i, item in ipairs(sorted_production) do
            if i > 10 then break end
            
            -- Название рецепта с ограничением ширины и враппингом
            local lbl = production_table.add{
                type = "label", 
                caption = item.recipe
            }
            lbl.style.maximal_width = 190
            lbl.style.single_line = false -- Разрешаем перенос, если название слишком длинное
            
            production_table.add{type = "label", caption = tostring(item.data.count)}
            production_table.add{type = "label", caption = string.format("%.1f", item.data.productivity)}
        end
    else
        production_frame.add{
            type = "label",
            caption = {"gui.no-production"}
        }
    end
end

-- Добавить секцию электроэнергии
function planet_stats.add_power_section(parent, stats)
    local power_frame = parent.add{
        type = "frame", 
        direction = "vertical",
        style = "kelnmaar_info_frame"
    }
    
    power_frame.add{
        type = "label",
        caption = {"gui.planet-power"},
        style = "kelnmaar_chart_title"
    }
    
    local power_table = power_frame.add{
        type = "table",
        column_count = 2
    }
    power_table.style.horizontally_stretchable = true
    power_table.style.width = 345
    power_table.style.column_alignments[1] = "left"
    power_table.style.column_alignments[2] = "right"
    
    -- Определяем какие данные использовать
    local generation = stats.power_generation or 0
    local consumption = stats.power_consumption or 0
    local data_source = "calc"  -- calculated from entities
    
    -- Если есть данные из network_power API - используем их
    if stats.network_power and stats.network_power.available then
        if stats.network_power.production > 0 or stats.network_power.consumption > 0 then
            generation = stats.network_power.production
            consumption = stats.network_power.consumption
            data_source = "api"
        end
    end
    
    -- Генерация
    power_table.add{type = "label", caption = {"gui.power-generation"}, style = "bold_label"}
    power_table.add{type = "label", caption = string.format("%.1f MW", generation / 1000000)}
    
    -- Потребление
    power_table.add{type = "label", caption = {"gui.power-consumption"}, style = "bold_label"}
    power_table.add{type = "label", caption = string.format("%.1f MW", consumption / 1000000)}
    
    -- Баланс
    local balance = generation - consumption
    local balance_color = balance >= 0 and "green" or "red"
    
    power_table.add{type = "label", caption = {"gui.power-balance"}, style = "bold_label"}
    local balance_label = power_table.add{
        type = "label", 
        caption = string.format("%.1f MW", balance / 1000000)
    }
    balance_label.style.font_color = {r = balance_color == "green" and 0 or 1, g = balance_color == "green" and 1 or 0, b = 0}
    
    -- Количество объектов
    power_table.add{type = "label", caption = {"gui.power-producers"}, style = "bold_label"}
    power_table.add{type = "label", caption = tostring(stats.power_producers or 0)}

    power_table.add{type = "label", caption = {"gui.power-consumers"}, style = "bold_label"}
    power_table.add{type = "label", caption = tostring(stats.power_consumers or 0)}
    
    -- Индикатор источника данных
    local source_lbl = power_frame.add{
        type = "label",
        caption = {"gui.data-source-" .. data_source},
        tooltip = {"gui.data-source-" .. data_source .. "-tooltip"}
    }
    source_lbl.style.font_color = {r = 0.5, g = 0.8, b = 1}
    source_lbl.style.top_margin = 8
end

-- Добавить отладочную секцию энергии
function planet_stats.add_debug_power_section(parent, stats)
    local debug_frame = parent.add{
        type = "frame",
        direction = "vertical",
        style = "kelnmaar_info_frame"
    }
    
    debug_frame.add{
        type = "label",
        caption = {"gui.debug-power-title"},
        style = "kelnmaar_chart_title"
    }
    
    -- Подсчитываем общие теоретические значения
    local total_prod = 0
    for _, data in pairs(stats.debug_power_info.producers) do
        total_prod = total_prod + data.power
    end
    
    local total_cons = 0
    for _, data in pairs(stats.debug_power_info.consumers) do
        total_cons = total_cons + data.power
    end
    
    local summary_table = debug_frame.add{
        type = "table",
        column_count = 2
    }
    summary_table.style.horizontally_stretchable = true
    summary_table.style.width = 345
    summary_table.style.column_alignments[1] = "left"
    summary_table.style.column_alignments[2] = "right"
    summary_table.add{type = "label", caption = {"gui.theor-production"}, style = "bold_label"}
    summary_table.add{type = "label", caption = string.format("%.1f MW", total_prod / 1000000)}
    summary_table.add{type = "label", caption = {"gui.theor-consumption"}, style = "bold_label"}
    summary_table.add{type = "label", caption = string.format("%.1f MW", total_cons / 1000000)}

    -- Функция для отрисовки топ-10
    local function add_top_table(title_key, data_source)
        debug_frame.add{type = "label", caption = {title_key}, style = "bold_label"}
        local gui_table = debug_frame.add{type = "table", column_count = 2}
        gui_table.style.horizontally_stretchable = true
        gui_table.style.width = 345
        gui_table.style.column_alignments[1] = "left"
        gui_table.style.column_alignments[2] = "right"
        
        local sorted = {}
        for _, d in pairs(data_source) do 
            _G.table.insert(sorted, d) 
        end
        _G.table.sort(sorted, function(a, b) return a.power > b.power end)
        
        for i, item in ipairs(sorted) do
            if i > 10 then break end
            
            -- Название объекта
            gui_table.add{type = "label", caption = item.name}
            gui_table.add{type = "label", caption = string.format("%.1f MW", item.power / 1000000)}
        end
    end

    if next(stats.debug_power_info.producers) then
        add_top_table("gui.top-producers", stats.debug_power_info.producers)
    end
    
    if next(stats.debug_power_info.consumers) then
        add_top_table("gui.top-consumers", stats.debug_power_info.consumers)
    end
end

-- Добавить секцию объектов с нехваткой ресурсов
function planet_stats.add_shortages_section(parent, stats, player)
    local shortages_frame = parent.add{
        type = "frame",
        direction = "vertical", 
        style = "kelnmaar_info_frame"
    }
    
    shortages_frame.add{
        type = "label",
        caption = {"gui.planet-shortages"},
        style = "kelnmaar_chart_title"
    }
    
    if #stats.entity_shortages > 0 then
        local shortages_table = shortages_frame.add{
            type = "table",
            column_count = 3
        }
        
        -- Заголовки
        shortages_table.add{type = "label", caption = {"gui.entity"}, style = "bold_label"}
        shortages_table.add{type = "label", caption = {"gui.missing-items"}, style = "bold_label"}
        shortages_table.add{type = "label", caption = {"gui.actions"}, style = "bold_label"}
        
        -- Ограничиваем до 15 объектов
        for i, shortage in ipairs(stats.entity_shortages) do
            if i > 15 then break end
            
            -- Название объекта
            shortages_table.add{type = "label", caption = shortage.name}
            
            -- Недостающие предметы
            local items_text = ""
            for j, item in ipairs(shortage.shortage_items) do
                if j > 1 then items_text = items_text .. ", " end
                items_text = items_text .. item.item .. " (" .. (item.needed - item.available) .. ")"
            end
            shortages_table.add{type = "label", caption = items_text}
            
            -- Кнопка пинга
            shortages_table.add{
                type = "button",
                name = "ping_entity_" .. i,
                caption = {"gui.ping"},
                style = "kelnmaar_nav_button"
            }
        end
    else
        shortages_frame.add{
            type = "label",
            caption = {"gui.no-shortages"}
        }
    end
end

-- Обновить только содержимое GUI без пересоздания окна
function planet_stats.update_planet_stats_content(player, surface_stats)
    local frame = player.gui.screen.planet_stats_frame
    if not frame then return false end
    
    -- Обновляем заголовок окна
    frame.caption = {
        "gui.planet-stats-title", 
        surface_stats.surface_name, 
        surface_stats.processed_entities or 0, 
        surface_stats.total_entities or 0
    }
    
    -- Находим контент по имени (не по типу!)
    local content = frame.planet_stats_content
    if not content then return false end
    
    -- Очищаем содержимое
    content.clear()
    
    -- Прогресс виден в заголовке, info_section больше не нужна для асинхронного режима
    
    -- Двухколоночный layout
    local columns = content.add{
        type = "flow",
        name = "planet_stats_columns",
        direction = "horizontal"
    }
    columns.style.horizontal_spacing = 8
    
    local left_column = columns.add{
        type = "flow",
        name = "left_column",
        direction = "vertical"
    }
    left_column.style.width = 360
    left_column.style.vertical_spacing = 4
    
    local right_column = columns.add{
        type = "flow",
        name = "right_column",
        direction = "vertical"
    }
    right_column.style.width = 360
    right_column.style.vertical_spacing = 4
    
    planet_stats.add_production_section(left_column, surface_stats)
    planet_stats.add_power_section(right_column, surface_stats)
    planet_stats.add_debug_power_section(right_column, surface_stats)
    planet_stats.add_shortages_section(right_column, surface_stats, player)
    return true
end

-- Обновить статистику планеты
function planet_stats.update_planet_stats_gui(player)
    if not player or not player.valid or not player.connected then return end
    
    if player.gui.screen.planet_stats_frame then
        -- Проверяем, запущен ли уже асинхронный сбор
        local state = storage.planet_stats_processing and storage.planet_stats_processing[player.index]
        
        if state and state.in_progress then
            -- Если уже идет сбор, просто обновляем контент тем что есть
            planet_stats.update_planet_stats_content(player, state.stats)
        else
            -- Если сбор не идет или завершен, запускаем новый асинхронный сбор
            -- Это обновит данные полностью без лимитов
            local new_state = planet_stats.start_async_collection(player)
            if new_state then
                planet_stats.update_planet_stats_content(player, new_state.stats)
            end
        end
    end
end

return planet_stats 