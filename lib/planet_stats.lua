-- lib/planet_stats.lua
-- Статистика планет и космических платформ

local planet_stats = {}

-- Собрать статистику текущей поверхности
-- Оптимизированная версия для лучшей производительности:
-- - Использует find_entities_filtered вместо find_entities() для конкретных типов
-- - Ограничивает количество обрабатываемых объектов (макс. 1000 за раз)
-- - Предотвращает зависания на больших базах
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
        processed_entities = 0,  -- Количество обработанных объектов
        power_producers = 0,     -- Количество производителей энергии
        power_consumers = 0,     -- Количество потребителей энергии
        debug_power_info = {}    -- Отладочная информация об энергии
    }
    
    -- Определяем типы объектов, которые нас интересуют
    local production_types = {
        ["assembling-machine"] = true,
        ["furnace"] = true,
        ["mining-drill"] = true,
        ["chemical-plant"] = true,
        ["oil-refinery"] = true,
        ["agricultural-tower"] = true,
        ["biochamber"] = true,
        ["foundry"] = true,
        ["electromagnetic-plant"] = true,
        ["cryogenic-plant"] = true
    }
    
    -- Производители энергии
    local power_producer_types = {
        ["solar-panel"] = true,
        ["steam-engine"] = true,
        ["steam-turbine"] = true,
        ["nuclear-reactor"] = true,
        ["generator"] = true,
        ["burner-generator"] = true,
        ["fusion-generator"] = true,
        ["fusion-reactor"] = true,
        ["accumulator"] = true,
        ["electric-energy-interface"] = true
    }
    
    -- Потребители энергии (исключая производственные объекты)
    local power_consumer_types = {
        ["electric-furnace"] = true,
        ["lab"] = true,
        ["radar"] = true,
        ["pump"] = true,
        ["inserter"] = true,
        ["electric-pole"] = true,
        ["beacon"] = true,
        ["roboport"] = true,
        ["lamp"] = true,
        ["electric-turret"] = true,
        ["laser-turret"] = true,
        ["lightning-rod"] = true,        -- Space Age
        ["heating-tower"] = true,        -- Space Age
        ["captive-biter-spawner"] = true -- Space Age
    }
    
    -- Собираем объекты по типам для лучшей производительности
    local all_production_entities = {}
    local all_power_entities = {}
    
    -- Ищем производственные объекты
    for entity_type, _ in pairs(production_types) do
        local entities = surface.find_entities_filtered{type = entity_type}
        for _, entity in pairs(entities) do
            table.insert(all_production_entities, entity)
        end
    end
    
    -- Ищем производители энергии
    for entity_type, _ in pairs(power_producer_types) do
        local entities = surface.find_entities_filtered{type = entity_type}
        for _, entity in pairs(entities) do
            table.insert(all_power_entities, entity)
        end
    end
    
    -- Ищем потребители энергии
    for entity_type, _ in pairs(power_consumer_types) do
        local entities = surface.find_entities_filtered{type = entity_type}
        for _, entity in pairs(entities) do
            table.insert(all_power_entities, entity)
        end
    end
    
    -- Подсчитываем общее количество интересующих нас объектов
    stats.total_entities = #all_production_entities + #all_power_entities
    
    -- Ограничиваем количество объектов для обработки (производительность)
    local MAX_ENTITIES_PER_UPDATE = 1000
    local processed_count = 0
    
    -- Обрабатываем производственные объекты (с ограничением)
    for _, entity in pairs(all_production_entities) do
        if processed_count >= MAX_ENTITIES_PER_UPDATE then break end
        if entity.valid then
            planet_stats.collect_production_stats(entity, stats)
            planet_stats.collect_power_stats(entity, stats)  -- Также собираем энергетическую статистику
            planet_stats.check_entity_shortages(entity, stats)
            processed_count = processed_count + 1
        end
    end
    
    -- Обрабатываем энергетические объекты (с ограничением)
    for _, entity in pairs(all_power_entities) do
        if processed_count >= MAX_ENTITIES_PER_UPDATE then break end
        if entity.valid then
            planet_stats.collect_power_stats(entity, stats)
            processed_count = processed_count + 1
        end
    end
    
    -- Записываем сколько объектов фактически обработано
    stats.processed_entities = processed_count
    
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
    
    -- Получаем качество entity если доступно (Factorio 2.0+)
    -- Согласно документации: всегда проверяем наличие свойства quality
    local quality = nil
    if entity.quality then
        quality = entity.quality
    end
    
    -- Источники энергии - используем API методы Factorio 2.0
    -- Fallback значения для известных типов объектов (если API не работает)
    local fallback_production = {
        ["solar-panel"] = 60000,  -- 60 кВт
        ["steam-engine"] = 900000, -- 900 кВт
        ["steam-turbine"] = 5800000, -- 5.8 МВт
        ["nuclear-reactor"] = 40000000, -- 40 МВт
        ["accumulator"] = 300000, -- 300 кВт (разряд)
    }
    
    -- Базовые значения потребления (могут отличаться в зависимости от модификаций)
    local base_consumption_by_type = {
        ["assembling-machine"] = 150000,    -- Средняя сборочная машина
        ["mining-drill"] = 90000,           -- Бур
        ["electric-furnace"] = 180000,      -- Электропечь
        ["chemical-plant"] = 210000,        -- Химзавод
        ["oil-refinery"] = 420000,          -- Нефтеперерабатывающий завод
        ["lab"] = 60000,                    -- Лаборатория
        ["radar"] = 300000,                 -- Радар
        ["pump"] = 30000,                   -- Насос
        ["beacon"] = 480000,                -- Маяк
        ["roboport"] = 50000,               -- Робопорт
        ["lamp"] = 5000,                    -- Лампа
        ["inserter"] = 13200,               -- Манипулятор (базовый)
        ["electric-pole"] = 0,              -- Электростолбы не потребляют
    }
    
    local fallback_consumption = {
        -- Конкретные названия объектов
        ["assembling-machine-1"] = 90000,
        ["assembling-machine-2"] = 150000,
        ["assembling-machine-3"] = 210000,
        ["electric-mining-drill"] = 90000,
        ["electric-furnace"] = 180000,
        ["steel-furnace"] = 0,  -- Стальная печь не электрическая
        ["stone-furnace"] = 0,  -- Каменная печь не электрическая
        ["chemical-plant"] = 210000,
        ["oil-refinery"] = 420000,
        ["lab"] = 60000,
        ["radar"] = 300000,
        ["pumpjack"] = 90000,
        ["offshore-pump"] = 0,  -- Морской насос не потребляет
        ["pump"] = 30000,
        ["beacon"] = 480000,
        ["roboport"] = 50000,
        ["lamp"] = 5000,
        -- Манипуляторы
        ["inserter"] = 13200,
        ["fast-inserter"] = 46800,
        ["filter-inserter"] = 46800,
        ["stack-inserter"] = 132000,
        ["stack-filter-inserter"] = 132000,
        -- Электростолбы
        ["small-electric-pole"] = 0,
        ["medium-electric-pole"] = 0,
        ["big-electric-pole"] = 0,
        ["substation"] = 0,
    }
    
    -- Безопасные функции для получения энергетических значений
    local function get_max_energy_production()
        -- Попытка 1: API метод с качеством
        local success, result = pcall(function() 
            return entity.prototype.get_max_energy_production and entity.prototype.get_max_energy_production(quality)
        end)
        if success and result and result > 0 then
            return result
        end
        
        -- Попытка 2: API метод без качества
        success, result = pcall(function() 
            return entity.prototype.get_max_energy_production and entity.prototype.get_max_energy_production()
        end)
        if success and result and result > 0 then
            return result
        end
        
        -- Попытка 3: Статические свойства прототипа
        success, result = pcall(function() 
            return entity.prototype.max_energy_production or entity.prototype.electric_energy_source_prototype and entity.prototype.electric_energy_source_prototype.buffer_capacity
        end)
        if success and result and result > 0 then
            return result
        end
        
        -- Fallback на статические значения
        return fallback_production[entity.name] or 0
    end
    
    local function get_max_power_output()
        -- Попытка 1: API метод с качеством
        local success, result = pcall(function() 
            return entity.prototype.get_max_power_output and entity.prototype.get_max_power_output(quality)
        end)
        if success and result and result > 0 then
            return result
        end
        
        -- Попытка 2: API метод без качества
        success, result = pcall(function() 
            return entity.prototype.get_max_power_output and entity.prototype.get_max_power_output()
        end)
        if success and result and result > 0 then
            return result
        end
        
        return 0
    end
    
    -- Безопасная функция для получения потребления энергии
    local function get_max_energy_usage()
        -- Попытка 1: API метод с качеством
        local success, result = pcall(function() 
            return entity.prototype.get_max_energy_usage and entity.prototype.get_max_energy_usage(quality)
        end)
        if success and result and result > 0 then
            return result
        end
        
        -- Попытка 2: API метод без качества
        success, result = pcall(function() 
            return entity.prototype.get_max_energy_usage and entity.prototype.get_max_energy_usage()
        end)
        if success and result and result > 0 then
            return result
        end
        
        -- Попытка 3: Статические свойства прототипа
        success, result = pcall(function() 
            return entity.prototype.electric_energy_source_prototype and entity.prototype.electric_energy_source_prototype.usage_per_tick
        end)
        if success and result and result > 0 then
            return result * 60 -- Конвертируем из тиков в секунды
        end
        
        -- Fallback на статические значения
        -- Сначала ищем по конкретному имени, потом по типу
        return fallback_consumption[entity.name] or base_consumption_by_type[entity.type] or 0
    end
    
    -- Определяем чистые производители энергии
    if entity.type == "solar-panel" or
       entity.type == "steam-engine" or 
       entity.type == "steam-turbine" or
       entity.type == "nuclear-reactor" or
       entity.type == "generator" or
       entity.type == "burner-generator" or
       entity.type == "fusion-generator" or
       entity.type == "fusion-reactor" then
        
        -- Только производство энергии для генераторов
        local production1 = get_max_energy_production()
        local production2 = get_max_power_output()
        energy_production = math.max(production1, production2)
        energy_consumption = 0
        
    elseif entity.type == "accumulator" then
        -- Аккумуляторы: для расчета статистики считаем только максимальную мощность разряда как производство
        -- Потребление не учитываем, так как это зарядка, которая зависит от доступной энергии
        energy_production = get_max_energy_production()
        energy_consumption = 0  -- Не учитываем потребление аккумуляторов для общей статистики
        
    elseif entity.type == "electric-energy-interface" then
        -- Специальные интерфейсы могут быть и производителями и потребителями
        local production1 = get_max_energy_production()
        local production2 = get_max_power_output()
        local production = math.max(production1, production2)
        local consumption = get_max_energy_usage()
        
        -- Если есть производство, считаем производителем, иначе потребителем
        if production > 0 then
            energy_production = production
            energy_consumption = 0
        else
            energy_production = 0
            energy_consumption = consumption
        end
    else
        -- Все остальные объекты - только потребители
        energy_production = 0
        energy_consumption = get_max_energy_usage()
    end
    
    stats.power_generation = stats.power_generation + energy_production
    stats.power_consumption = stats.power_consumption + energy_consumption
    
    -- Подсчитываем производителей и потребителей
    if energy_production > 0 then
        stats.power_producers = stats.power_producers + 1
    end
    if energy_consumption > 0 then
        stats.power_consumers = stats.power_consumers + 1
    end
    
    -- Отладочная информация: собираем примеры для каждого типа
    local entity_key = entity.type .. ":" .. entity.name
    if not stats.debug_power_info[entity_key] then
        stats.debug_power_info[entity_key] = {
            type = entity.type,
            name = entity.name,
            production = energy_production,
            consumption = energy_consumption,
            count = 0
        }
    end
    stats.debug_power_info[entity_key].count = stats.debug_power_info[entity_key].count + 1
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
    
    -- Сохраняем текущую позицию окна перед удалением
    local saved_location = nil
    if player.gui.screen.planet_stats_frame then
        saved_location = player.gui.screen.planet_stats_frame.location
        player.gui.screen.planet_stats_frame.destroy()
    end
    
    -- Создаем главную рамку
    local frame = player.gui.screen.add{
        type = "frame",
        name = "planet_stats_frame",
        direction = "vertical",
        caption = {"gui.planet-stats-title", surface_stats.surface_name}
    }
    frame.style.width = 450
    frame.style.height = 700  -- Увеличена высота для размещения всего контента без скроллинга
    
    -- Восстанавливаем сохраненную позицию или ставим по умолчанию
    if saved_location then
        frame.location = saved_location
    else
        frame.location = {player.display_resolution.width - 470, 50}
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
    
    -- Контент (без скролинга)
    local content = frame.add{
        type = "flow",
        direction = "vertical"
    }
    
    -- 1. Информация о полноте статистики
    if surface_stats.processed_entities < surface_stats.total_entities then
        planet_stats.add_info_section(content, surface_stats)
    end
    
    -- 2. Статистика производства
    planet_stats.add_production_section(content, surface_stats)
    
    -- 3. Статистика электроэнергии  
    planet_stats.add_power_section(content, surface_stats)
    
    -- 4. Отладочная информация по энергии (топ-10)
    planet_stats.add_debug_power_section(content, surface_stats)
    
    -- 5. Список объектов с нехваткой ресурсов
    planet_stats.add_shortages_section(content, surface_stats, player)
    
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
        
        -- Заголовки
        production_table.add{type = "label", caption = {"gui.recipe"}, style = "bold_label"}
        production_table.add{type = "label", caption = {"gui.count"}, style = "bold_label"}
        production_table.add{type = "label", caption = {"gui.productivity"}, style = "bold_label"}
        
        -- Сортируем по количеству объектов
        local sorted_production = {}
        for recipe, data in pairs(stats.production) do
            table.insert(sorted_production, {recipe = recipe, data = data})
        end
        table.sort(sorted_production, function(a, b) return a.data.count > b.data.count end)
        
        -- Отображаем топ-10 рецептов
        for i, item in ipairs(sorted_production) do
            if i > 10 then break end
            
            production_table.add{type = "label", caption = item.recipe}
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
    
    -- Генерация
    power_table.add{type = "label", caption = {"gui.power-generation"}, style = "bold_label"}
    power_table.add{type = "label", caption = string.format("%.0f MW", stats.power_generation / 1000000)}
    
    -- Потребление
    power_table.add{type = "label", caption = {"gui.power-consumption"}, style = "bold_label"}
    power_table.add{type = "label", caption = string.format("%.0f MW", stats.power_consumption / 1000000)}
    
    -- Баланс
    local balance = stats.power_generation - stats.power_consumption
    local balance_color = balance >= 0 and "green" or "red"
    
    power_table.add{type = "label", caption = {"gui.power-balance"}, style = "bold_label"}
    local balance_label = power_table.add{
        type = "label", 
        caption = string.format("%.0f MW", balance / 1000000)
    }
    balance_label.style.font_color = {r = balance_color == "green" and 0 or 1, g = balance_color == "green" and 1 or 0, b = 0}
    
    -- Отладочная информация
    power_table.add{type = "label", caption = {"gui.power-producers"}, style = "bold_label"}
    power_table.add{type = "label", caption = tostring(stats.power_producers or 0)}

    power_table.add{type = "label", caption = {"gui.power-consumers"}, style = "bold_label"}
    power_table.add{type = "label", caption = tostring(stats.power_consumers or 0)}
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
    
    -- Подсчитываем общие значения по всем типам объектов
    local total_debug_production = 0
    local total_debug_consumption = 0
    for _, data in pairs(stats.debug_power_info) do
        total_debug_production = total_debug_production + (data.production * data.count)
        total_debug_consumption = total_debug_consumption + (data.consumption * data.count)
    end
    
    local summary_table = debug_frame.add{
        type = "table",
        column_count = 2
    }
    summary_table.add{type = "label", caption = {"gui.debug-total-production"}, style = "bold_label"}
    summary_table.add{type = "label", caption = string.format("%.1f MW", total_debug_production / 1000000)}
    summary_table.add{type = "label", caption = {"gui.debug-total-consumption"}, style = "bold_label"}
    summary_table.add{type = "label", caption = string.format("%.1f MW", total_debug_consumption / 1000000)}
    
    if next(stats.debug_power_info) then
        local debug_table = debug_frame.add{
            type = "table",
            column_count = 4
        }
        
        -- Заголовки
        debug_table.add{type = "label", caption = {"gui.debug-entity"}, style = "bold_label"}
        debug_table.add{type = "label", caption = {"gui.debug-count"}, style = "bold_label"}
        debug_table.add{type = "label", caption = {"gui.debug-production-w"}, style = "bold_label"}
        debug_table.add{type = "label", caption = {"gui.debug-consumption-w"}, style = "bold_label"}
        
        -- Сортируем по количеству объектов
        local sorted_debug = {}
        for key, data in pairs(stats.debug_power_info) do
            table.insert(sorted_debug, data)
        end
        table.sort(sorted_debug, function(a, b) return a.count > b.count end)
        
        -- Отображаем топ-10
        for i, item in ipairs(sorted_debug) do
            if i > 10 then break end
            
            debug_table.add{type = "label", caption = item.name}
            debug_table.add{type = "label", caption = tostring(item.count)}
            debug_table.add{type = "label", caption = string.format("%.0f", item.production)}
            debug_table.add{type = "label", caption = string.format("%.0f", item.consumption)}
        end
    else
        debug_frame.add{
            type = "label",
            caption = {"gui.debug-no-data"}
        }
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
    
    -- Обновляем заголовок окна (на случай смены планеты) с информацией о количестве объектов
    local title_text = surface_stats.surface_name
    if surface_stats.processed_entities < surface_stats.total_entities then
        title_text = title_text .. string.format(" (%d/%d)", surface_stats.processed_entities, surface_stats.total_entities)
    end
    frame.caption = {"gui.planet-stats-title", title_text}
    
    -- Очищаем содержимое (кроме заголовка)
    for _, child in pairs(frame.children) do
        if child.name ~= "titlebar" and child.type == "flow" then
            child.clear()
            
            -- Пересоздаем содержимое
            if surface_stats.processed_entities < surface_stats.total_entities then
                planet_stats.add_info_section(child, surface_stats)
            end
            planet_stats.add_production_section(child, surface_stats)
            planet_stats.add_power_section(child, surface_stats)
            planet_stats.add_debug_power_section(child, surface_stats)
            planet_stats.add_shortages_section(child, surface_stats, player)
            return true
        end
    end
    return false
end

-- Обновить статистику планеты
function planet_stats.update_planet_stats_gui(player)
    if player.gui.screen.planet_stats_frame then
        local surface_stats = planet_stats.collect_surface_stats(player.surface)
        if surface_stats then
            -- Пытаемся обновить содержимое без пересоздания
            if not planet_stats.update_planet_stats_content(player, surface_stats) then
                -- Если не получилось, пересоздаем полностью
                planet_stats.create_planet_stats_gui(player, surface_stats)
            end
        end
    end
end

return planet_stats 