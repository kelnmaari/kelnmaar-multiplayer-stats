# KelnMaar's Multiplayer Statistics - FAQ

## Getting Started

### Q: How do I install this mod?
**A:** Download the latest `.zip` file from the mod portal or releases page. Place it in your Factorio mods folder:
- **Windows:** `%APPDATA%\Factorio\mods\`
- **macOS:** `~/Library/Application Support/factorio/mods/`
- **Linux:** `~/.factorio/mods/`

Alternatively, install directly through Factorio's in-game mod manager.

### Q: What are the system requirements?
**A:** 
- **Factorio version:** 2.0 or higher
- **Space Age DLC:** Required
- **Multiplayer:** Fully supported
- **Memory:** Minimal impact on performance

### Q: How do I open the statistics window?
**A:** Use the hotkey `Shift + Alt + S` or type the command `/stats` in chat.

### Q: I don't see any statistics. What's wrong?
**A:** Make sure:
1. The mod is enabled in your mod settings
2. You've moved around or crafted items (statistics update in real-time)
3. The GUI isn't collapsed (click the arrow button to expand)

## Basic Usage

### Q: What statistics does this mod track?
**A:** The mod tracks:
- **Distance traveled** (including space travel)
- **Items crafted** (with detailed history)
- **Combat statistics** (enemies killed, deaths, damage taken)
- **Building activity** (structures built/destroyed)
- **Resource mining** (by type)
- **Playtime** (active time in-game)
- **Space Age content** (planets visited)

### Q: How does the ranking system work?
**A:** Players earn ranks from **Recruit** to **Godlike** (22 tiers total) based on:
- Distance traveled with scaling difficulty
- Items crafted with diminishing returns
- Combat efficiency (K/D ratio matters)
- Building activity
- Resource mining diversity
- Planet exploration
- Playtime

### Q: What are achievements and how do I unlock them?
**A:** There are 36 achievements across 8 categories:
- **Distance:** Travel 10K, 100K, 500K, 1M, 10M tiles
- **Crafting:** Craft 1K, 10K, 100K, 1M, 10M items
- **Combat:** Kill 1K, 10K, 100K, 500K, 1M enemies
- **Building:** Build 1K, 10K, 40K, 200K, 1M structures
- **Survival:** Play for 1, 10, 50, 100, or 1000 hours
- **No Deaths:** Play 1, 10, 50, 100, or 1000 hours without dying
- **Space Age:** Visit 1, 2, 3, 4, or 5 planets
- **Deep Space:** Reach deep space

### Q: How do I view my achievements?
**A:** Click the checkmark (✓) button in the statistics window title bar to open the achievements panel.

## Interface & Controls

### Q: How do I navigate the interface?
**A:** 
- **Main window:** Shows all players' statistics in a table
- **Achievements button (✓):** View your achievement progress
- **Rankings button (📊):** See top 5 players in different categories
- **Compare button:** Compare your stats with another player
- **Details button:** View detailed statistics for any player
- **Collapse/Expand (⟵/⟶):** Minimize the window
- **Close (✕):** Hide the statistics window

### Q: Can I customize the interface?
**A:** Yes! Access mod settings in:
- **Main Menu → Settings → Mod Settings**
- **In-game → Settings → Mod Settings**

Available options include:
- Auto-open GUI when joining
- Notification preferences
- Achievement system toggle
- Ranking mode selection
- Notification sounds and duration

### Q: The window is too big/small. Can I resize it?
**A:** The window automatically adjusts based on the number of players. You can:
- Collapse it using the arrow button for minimal space
- Scroll within the content area if there are many players

## Multiplayer Features

### Q: Do I need to be an admin to use this mod?
**A:** No! Regular players can:
- View all statistics
- Open achievements and rankings
- Compare with other players
- Access their detailed stats

Admins have additional privileges:
- Reset all statistics (`/reset-stats`)
- Modify global mod settings

### Q: Will this mod slow down the server?
**A:** No, the mod is optimized for performance:
- Minimal memory usage with automatic cleanup
- Efficient data storage with batch player updates
- Fixed update intervals optimized for large servers (30 seconds)
- Configurable max players per update cycle
- No impact on game mechanics

### Q: What happens when players leave the server?
**A:** The mod automatically:
- Preserves player data when they temporarily disconnect
- Cleans up data when players are permanently removed
- Prevents memory leaks through periodic cleanup

## Notifications & Messages

### Q: I'm getting too many notifications. How do I disable them?
**A:** In **Mod Settings → Runtime - per user**:
- Turn off **"Show Notifications"**
- Disable **"Auto-open GUI"**
- Adjust **"Notification Duration"**

### Q: What do the colored messages in chat mean?
**A:** Green messages indicate:
- **Achievement unlocked** (personal or broadcast)
- **Rank promotion** (personal or broadcast)

### Q: Can I disable chat broadcasts?
**A:** Yes! Admins can disable in **Mod Settings → Runtime - global**:
- **"Broadcast Rank Promotions"**
- **"Broadcast Achievement Unlocks"**

## Troubleshooting

### Q: The mod crashed with an error. What should I do?
**A:**
1. **Check mod version:** Ensure you have the latest version (5.8.6+)
2. **Verify dependencies:** Confirm Space Age DLC is installed
3. **Restart Factorio:** Some settings require a restart
4. **Report the bug:** Include the full error message

### Q: My statistics seem incorrect or reset unexpectedly.
**A:** This might happen if:
- An admin used `/reset-stats` command
- The mod was updated (data migration issues)
- Server had significant downtime

### Q: The GUI doesn't update in real-time.
**A:** The mod updates statistics every 30 seconds (1800 ticks) by default to ensure optimal multiplayer performance. The GUI refresh happens every 10 seconds (600 ticks). These values are fixed to prevent multiplayer desync issues. If you have many players, you can adjust **"Max Players Per Update Cycle"** in Startup Settings.

### Q: Some achievements aren't unlocking.
**A:** Verify in **Mod Settings → Runtime - global**:
- **"Enable Achievement System"** is ON
- **"Enable Survival Achievements"** is ON (for survival-based achievements)

## Advanced Features

### Q: How does the player comparison work?
**A:** Click **"Compare"** next to any player to see:
- Side-by-side statistics comparison
- Highlighted better values (in bold)
- Overall rank and score differences

### Q: What's the difference between "Details" and "Crafting History"?
**A:** 
- **Details:** Shows comprehensive stats including rank, active crafts, combat, building, mining, and space exploration
- **Crafting History:** Focuses specifically on items crafted with counts and totals

### Q: Can I see statistics for offline players?
**A:** The mod only shows currently connected players in the main table, but their data is preserved and will reappear when they reconnect.

## Performance & Optimization

### Q: How much memory does this mod use?
**A:** Very little! The mod includes automatic cleanup:
- Limits crafted items to top 500 per player
- Removes data from permanently deleted players
- Periodic cleanup every 10 minutes
- No memory leaks

### Q: Can I change how often the mod updates?
**A:** The update frequency is fixed at 30 seconds (1800 ticks) to prevent multiplayer desync issues. However, you can configure:
- **"Max Players Per Update Cycle"**: 1-20 (default: 5)
- Lower values = better performance for large servers but slower individual updates
- Recommended: 3-5 for servers with 50+ players

## Getting Help

### Q: Where can I report bugs or request features?
**A:** 
- Check this FAQ first
- Look for similar issues in the mod portal discussions
- Report bugs with full error messages and steps to reproduce
- Include your mod version and Factorio version

### Q: Is this mod compatible with other mods?
**A:** Yes! This mod only tracks statistics and doesn't modify game mechanics, making it compatible with most other mods.

### Q: Can I use this mod in single-player?
**A:** While designed for multiplayer, it works in single-player too. You'll see your own statistics and can track achievements and rank progression.

---

**Mod Version:** 5.8.6
**Last Updated:** February 2026
**Author:** KelnMaar 