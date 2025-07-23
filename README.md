# KelnMaar's Multiplayer Statistics Mod for Factorio

Advanced statistics tracking mod for multiplayer Factorio games with Space Age DLC support.

## Features

### 📊 Core Statistics

- **Distance Traveled** - Precise tracking of distance covered by each player
- **Items Crafted** - Total count and detailed breakdown by item types
- **Active Crafts** - Real-time view of any player's current crafting queue

### ⚔️ Combat Statistics

- **Enemies Killed** - Count of destroyed biters, spawners, and other enemies
- **Player Deaths** - Death counter for each player
- **Damage Taken** - Total damage received from enemies

### 🏗️ Building Statistics

- **Structures Built** - Count of placed buildings, belts, and machinery
- **Structures Destroyed** - Count of objects demolished by players

### ⛏️ Resource Mining

- **Iron ore, Copper ore** - Precise tracking of mined resources
- **Coal, Stone, Oil** - Statistics for all major resources
- **Wood** - Count of trees chopped

### ⏱️ Playtime Tracking

- **Active Time** - Accurate tracking of time spent in-game
- **HH:MM:SS Format** - User-friendly time display

### 🚀 Space Age Statistics

- **Planets Visited** - List of all planets the player has been to
- **Space Travel Distance** - Separate tracking of distance traveled in space
- **Interplanetary Travel** - Monitoring movement between worlds

### 🏆 Advanced Features

- **22-Tier Ranking System** - From Recruit to Godlike with complex scoring
- **18 Achievement System** - Unlockable achievements across all categories
- **Player Rankings** - Top 5 leaderboards for different statistics
- **Player Comparison** - Side-by-side stat comparison between players
- **Data Visualization** - Progress bars and activity breakdowns

### 🖱️ User-Friendly Interface

- **Docked to Minimap** - Statistics window positioned in top panel near minimap
- **Collapsible Window** - Minimize/expand button to save screen space
- **Detailed Information** - "Details" button for comprehensive player statistics
- **Multilingual Support** - Russian and English interface
- **Fully Configurable** - Extensive mod settings for customization

## Installation

1. Download the mod from Factorio Mod Portal or copy the mod folder to your Factorio mods directory:

   **Windows:**
   ```
   %APPDATA%/Factorio/mods/
   ```

   **Linux/macOS:**
   ```
   ~/.factorio/mods/
   ```

2. Launch Factorio and enable the mod in the mods menu

## Mod Settings

The mod fully complies with Factorio standards and provides extensive customization options. Settings are available in the main menu: **Settings → Mod Settings**.

### 🔧 Startup Settings (require restart)

- **Enable Statistics Mod** - Completely enables/disables mod functionality
- **Statistics Update Frequency** - How often statistics update (60-600 ticks, default 300)

### 🌐 Global Runtime Settings (admin only)

- **Enable Achievement System** - Enable/disable achievements for all players
- **Broadcast Rank Promotions** - Send chat messages about rank ups
- **Broadcast Achievement Unlocks** - Send chat messages about achievements
- **Default Ranking Mode** - Which ranking to show when opened (score/distance/crafted/combat/building)
- **Enable Survival Achievements** - Enable achievements for time without deaths

### 👤 Per-User Runtime Settings (individual for each player)

- **Show Notifications** - Display popup notifications for achievements
- **Auto-open GUI on Join** - Open statistics window when connecting to server
- **Show Rank Progress** - Display progress bar to next rank
- **Notification Position** - Where on screen to show notifications (center/corners)
- **Notification Duration** - How long to show notifications (3-30 seconds)
- **Enable Notification Sounds** - Play sounds when earning achievements

## Usage

### Hotkeys

- **Shift + Alt + S** - Open/close statistics window

### Console Commands

- `/stats` - Open statistics window
- `/reset-stats` - Reset all statistics (administrators only)

### Interface

#### Main Statistics Window

Displays a table with all connected players and their statistics:

- **Player Name**
- **Rank** - Current rank with icon and score tooltip
- **Distance Traveled** (in tiles, 2 decimal precision)
- **Total Crafted** (total item count)
- **Active Crafts** (items in crafting queue)
- **Enemies Killed** (biters and spawners destroyed)
- **Deaths** (player death count)
- **Damage Taken** (total damage from enemies)
- **Buildings Built** (structures placed)
- **Playtime** (in HH:MM:SS format)
- **Planets** (number of planets visited)
- **Actions** (Details, History, Compare buttons)

#### Detailed Statistics Window

Shows comprehensive information:

- **Player Rank** - Current rank, score, and progress to next rank
- **Crafted Items** - List of all items with counts
- **Active Crafting Queue** - Current recipes in production
- **Combat Statistics** - Enemies killed, deaths, damage taken
- **Building Statistics** - Built and destroyed objects
- **Resource Mining** - Detailed statistics by resource type
- **Space Age Statistics** - Space travel distance and planets visited
- **Data Visualization** - Activity breakdown and mining distribution

#### Rankings Window

- **Top 5 Rankings** - Leaderboards for Score, Distance, Crafting, Combat, Building
- **Player Comparison** - Compare any two players side-by-side

#### Achievements Window

- **18 Achievements** - Distance, Crafting, Combat, Building, Survival, Space Age
- **Progress Tracking** - Shows current progress toward unearned achievements
- **Completion Status** - Visual indicators for earned achievements

## Technical Features

### Distance Tracking

- Updates every second (60 ticks)
- Precise distance calculation between positions
- Data persistence between sessions
- Separate space travel tracking

### Crafting Tracking

- Automatic counting on craft completion
- Detailed breakdown by item types
- Real-time active crafts viewing
- Memory optimization with item limit (top 500 items)

### GUI System

- Window position saving per player
- Automatic data updates
- Adaptive sizing for player count
- Multiple simultaneous windows support

### Performance & Memory Management

- **Memory Leak Prevention** - Automatic cleanup of disconnected players
- **Data Optimization** - Limits crafted items to prevent bloat
- **Efficient Updates** - Configurable update frequency
- **Minimal Impact** - No effect on game mechanics

## Compatibility

- **Factorio**: 2.0+
- **Space Age DLC**: Required
- **Multiplayer**: Full support
- **Save Games**: Compatible with existing worlds
- **Other Mods**: Highly compatible (doesn't modify game mechanics)

## File Structure

```
kelnmaar-multiplayer-stats/
├── info.json              # Mod metadata
├── control.lua             # Main logic
├── data.lua                # Hotkey registration
├── settings.lua            # Mod settings definitions
├── README.md               # Documentation
├── FAQ.md                  # Frequently Asked Questions
└── locale/
    ├── en/locale.cfg       # English localization
    └── ru/locale.cfg       # Russian localization
```

## Development

The mod is written in Lua using Factorio 2.0 API and fully complies with [official Factorio mod standards](https://wiki.factorio.com/Tutorial:Mod_settings). Key components:

- **Settings System** - settings.lua with startup, runtime-global, and runtime-per-user settings
- **Data Storage System** - Global variables for player statistics
- **GUI System** - Window creation and management
- **Event System** - Handling player movement, crafting, and setting changes
- **Achievement System** - 18 different achievements with notifications
- **Ranking System** - 22 tiers with advanced scoring algorithms
- **Localization** - Full support for Russian and English languages
- **Memory Management** - Automatic cleanup and optimization

## License

This mod is created for the Factorio community and distributed freely.

## Support

For issues or improvement suggestions, please create an issue in the project repository or contact through Factorio Mod Portal.

---

# Russian Version / Русская версия

# Multiplayer Statistics Mod для Factorio

Мод для отслеживания статистики игроков в мультиплеере Factorio + Space Age DLC.

## Возможности

### 📊 Основная статистика

- **Пройденное расстояние** - точный подсчет расстояния, которое прошел каждый игрок
- **Количество скрафченных предметов** - общее количество и детализация по типам предметов
- **Активные крафты** - просмотр текущей очереди крафта любого игрока

### ⚔️ Боевая статистика

- **Убитые враги** - количество уничтоженных биттеров, спор и других врагов
- **Смерти игроков** - счетчик смертей каждого игрока
- **Полученный урон** - общий урон, полученный от врагов

### 🏗️ Статистика строительства

- **Построенные объекты** - количество размещенных зданий, конвейеров и механизмов
- **Снесенные объекты** - количество демонтированных игроком объектов

### ⛏️ Добыча ресурсов

- **Железная руда, медная руда** - точный подсчет добытых ресурсов
- **Уголь, камень, нефть** - статистика по всем основным ресурсам
- **Древесина** - количество срубленных деревьев

### ⏱️ Время в игре

- **Активное время** - точный подсчет времени, проведенного в игре
- **Формат ЧЧ:ММ:СС** - удобное отображение времени

### 🚀 Space Age статистика

- **Посещенные планеты** - список всех планет, на которых побывал игрок
- **Расстояние в космосе** - отдельный подсчет расстояния, пройденного на космических кораблях
- **Межпланетные путешествия** - отслеживание перемещений между мирами

### 🏆 Продвинутые функции

- **22-уровневая система званий** - от Рекрута до Божественного с комплексным подсчетом очков
- **18 достижений** - разблокируемые достижения по всем категориям
- **Рейтинги игроков** - топ-5 лидербордов для разной статистики
- **Сравнение игроков** - сравнение статистики двух игроков бок о бок
- **Визуализация данных** - прогресс-бары и разбивка активности

### 🖱️ Удобный интерфейс

- **Прикрепленное к миникарте** - окно статистики расположено в верхней панели рядом с миникартой
- **Сворачиваемое окно** - кнопка сворачивания/разворачивания для экономии места на экране
- **Детальная информация** - кнопка "Подробности" для просмотра детальной статистики игрока
- **Многоязычная поддержка** - русский и английский интерфейс
- **Полная настраиваемость** - обширные настройки мода для кастомизации

## Установка

1. Скачайте мод с Factorio Mod Portal или скопируйте папку мода в директорию модов Factorio:

   **Windows:**
   ```
   %APPDATA%/Factorio/mods/
   ```

   **Linux/macOS:**
   ```
   ~/.factorio/mods/
   ```

2. Запустите Factorio и включите мод в меню модов

## Настройки мода

Мод полностью соответствует стандартам Factorio и предоставляет множество настроек для кастомизации. Настройки доступны в главном меню: **Настройки → Настройки модов**.

### 🔧 Настройки запуска (требуют перезапуск)

- **Включить мод статистики** - полностью включает/отключает функциональность мода
- **Частота обновления статистики** - как часто обновляется статистика (60-600 тиков, по умолчанию 300)

### 🌐 Глобальные настройки (может изменять только админ)

- **Включить систему достижений** - включает/отключает достижения для всех игроков
- **Транслировать повышения в звании** - отправлять сообщения в чат о повышениях
- **Транслировать получение достижений** - отправлять сообщения в чат о достижениях
- **Режим рейтинга по умолчанию** - какой рейтинг показывать при открытии (очки/расстояние/крафт/бой/строительство)
- **Включить достижения выживания** - включает достижения за время без смертей

### 👤 Персональные настройки (индивидуальные для каждого игрока)

- **Показывать уведомления** - показывать всплывающие уведомления о достижениях
- **Автоматически открывать GUI при входе** - открывать окно статистики при подключении к серверу
- **Показывать прогресс звания** - показывать прогресс-бар до следующего звания
- **Позиция уведомлений** - где на экране показывать уведомления (центр/углы экрана)
- **Длительность уведомлений** - сколько секунд показывать уведомления (3-30 сек)
- **Включить звуки уведомлений** - проигрывать звуки при получении достижений

## Использование

### Горячие клавиши

- **Shift + Alt + S** - открыть/закрыть окно статистики

### Консольные команды

- `/stats` - открыть окно статистики
- `/reset-stats` - сбросить всю статистику (только для администраторов)

### Интерфейс

#### Главное окно статистики

Отображает таблицу со всеми подключенными игроками и их статистикой:

- **Имя игрока**
- **Звание** - текущее звание с иконкой и подсказкой с очками
- **Пройденное расстояние** (в тайлах, с точностью до 2 знаков)
- **Всего скрафчено** (общее количество предметов)
- **Активные крафты** (количество предметов в очереди)
- **Убито врагов** (количество уничтоженных биттеров и спор)
- **Смерти** (количество смертей игрока)
- **Получено урона** (общий урон от врагов)
- **Построено** (количество размещенных объектов)
- **Время в игре** (в формате ЧЧ:ММ:СС)
- **Планеты** (количество посещенных планет)
- **Действия** (кнопки Подробности, История, Сравнить)

#### Окно детальной статистики

Показывает исчерпывающую информацию:

- **Звание игрока** - текущее звание, очки и прогресс до следующего звания
- **Скрафченные предметы** - список всех предметов с количеством
- **Активная очередь крафта** - текущие рецепты в производстве
- **Боевая статистика** - убитые враги, смерти, полученный урон
- **Статистика строительства** - построенные и снесенные объекты
- **Добыча ресурсов** - детальная статистика по каждому типу ресурса
- **Space Age статистика** - расстояние в космосе и список посещенных планет
- **Визуализация данных** - разбивка активности и распределение добычи

#### Окно рейтингов

- **Топ-5 рейтингов** - лидерборды по Очкам, Расстоянию, Крафту, Бою, Строительству
- **Сравнение игроков** - сравнение любых двух игроков бок о бок

#### Окно достижений

- **18 достижений** - Расстояние, Крафт, Бой, Строительство, Выживание, Space Age
- **Отслеживание прогресса** - показывает текущий прогресс к незаработанным достижениям
- **Статус выполнения** - визуальные индикаторы для полученных достижений

## Технические особенности

### Отслеживание расстояния

- Обновление каждую секунду (60 тиков)
- Точный расчет расстояния между позициями
- Сохранение данных между сессиями
- Отдельное отслеживание космических путешествий

### Отслеживание крафта

- Автоматический подсчет при завершении крафта
- Детализация по типам предметов
- Реальное время просмотра активных крафтов
- Оптимизация памяти с лимитом предметов (топ-500 предметов)

### GUI система

- Сохранение позиции окна для каждого игрока
- Автоматическое обновление данных
- Адаптивный размер под количество игроков
- Поддержка множественных одновременных окон

### Производительность и управление памятью

- **Предотвращение утечек памяти** - автоматическая очистка отключившихся игроков
- **Оптимизация данных** - ограничение скрафченных предметов для предотвращения раздувания
- **Эффективные обновления** - настраиваемая частота обновлений
- **Минимальное воздействие** - никакого влияния на игровые механики

## Совместимость

- **Factorio**: 2.0+
- **Space Age DLC**: Обязательно
- **Мультиплеер**: Полная поддержка
- **Сохранения**: Совместимо с существующими мирами
- **Другие моды**: Высокая совместимость (не изменяет игровые механики)

## Файловая структура

```
kelnmaar-multiplayer-stats/
├── info.json              # Метаданные мода
├── control.lua             # Основная логика
├── data.lua                # Регистрация горячих клавиш
├── settings.lua            # Определения настроек мода
├── README.md               # Документация
├── FAQ.md                  # Часто задаваемые вопросы
└── locale/
    ├── en/locale.cfg       # Английская локализация
    └── ru/locale.cfg       # Русская локализация
```

## Разработка

Мод написан на Lua с использованием API Factorio 2.0 и полностью соответствует [официальным стандартам модов Factorio](https://wiki.factorio.com/Tutorial:Mod_settings). Основные компоненты:

- **Система настроек** - settings.lua с startup, runtime-global и runtime-per-user настройками
- **Система хранения данных** - глобальные переменные для статистики игроков  
- **GUI система** - создание и управление окнами интерфейса
- **Система событий** - обработка движения игроков, крафта и изменения настроек
- **Система достижений** - 18 различных достижений с уведомлениями
- **Система званий** - 22 уровня с продвинутой системой подсчета очков
- **Локализация** - полная поддержка русского и английского языков
- **Управление памятью** - автоматическая очистка и оптимизация

## Лицензия

Этот мод создан для сообщества Factorio и распространяется свободно.

## Поддержка

При возникновении проблем или предложений по улучшению, создайте issue в репозитории проекта или обратитесь через Factorio Mod Portal.
