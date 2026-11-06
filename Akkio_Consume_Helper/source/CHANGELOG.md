# Changelog - Akkio's Consume Helper

## [1.1.3] - 2025-08-06 - TURTLE WOW CONSUMABLES EXPANSION

### Major Content Addition
- **First-Time User Welcome Window**: Professional onboarding experience for new users
  - **Interactive Tutorial**: Welcome window appears automatically on first addon use
  - **Quick Settings Access**: One-click button to open main settings panel
  - **Feature Overview**: Comprehensive introduction to addon capabilities and key features
  - **User Choice**: "Don't show again" checkbox for returning users
  - **Manual Access**: New `/actwelcome` command to view welcome window anytime
  - **Streamlined Design**: Clean, focused interface that guides users to the main settings hub
- **Turtle WoW Custom Consumables**: Massive expansion with 20+ new Turtle WoW-specific consumables
  - **Enhanced Database**: Added comprehensive Turtle WoW consumables from official Turtle WoW wiki
  - **Complete Integration**: All new consumables properly categorized and integrated into existing addon structure
  - **Organized Categories**: Clean reorganization of all consumables into logical, easy-to-navigate sections

### New Consumables Added

#### **Elixirs & Juju**
- **Elixir of Frost Power** (Item ID: 17708) - 30-minute frost damage enhancement
- **Elixir of Greater Intellect** (Item ID: 9179) - 20-minute intellect boost
- **Juju Flurry** (Item ID: 12450) - 20-second attack speed enhancement

#### **Special Potions & Consumables**
- **Ground Scorpok Assay** (Item ID: 8412) - 1-hour agility enhancement
- **R.O.I.D.S.** (Item ID: 8410) - 1-hour strength enhancement  
- **Cerebral Cortex Compound** (Item ID: 8423) - 1-hour intellect enhancement
- **Dreamtonic** (Item ID: 61423) - 20-minute spirit enhancement

#### **Food & Drinks**
- **Le Fishe Au Chocolat** (Item ID: 84040) - 15-minute stamina food
- **Sweet Mountain Berry** (Item ID: 51714) - 10-minute stamina food
- **Danonzo's Tel'Abim Medley** (Item ID: 60978) - 15-minute stamina food
- **Danonzo's Tel'Abim Surprise** (Item ID: 60976) - 15-minute stamina food
- **Danonzo's Tel'Abim Delight** (Item ID: 60977) - 15-minute stamina food
- **Gurubashi Gumbo** (Item ID: 53015) - 15-minute stamina food
- **Dragonbreath Chili** (Item ID: 12217) - 10-minute fire proc effect

#### **Alcoholic Beverages** (NEW CATEGORY)
- **Rumsey Rum Black Label** (Item ID: 21151) - 15-minute stamina beverage
- **Medivh's Merlot** (Item ID: 61174) - 15-minute stamina beverage
- **Medivh's Merlot Blue** (Item ID: 61175) - 15-minute spirit beverage

#### **Weapon Enchants**
- **Consecrated Sharpening Stone** (Item ID: 23122) - Enhanced sharpening stone for both weapon slots
- **Blessed Wizard Oil** (Item ID: 23123) - Enhanced wizard oil for main hand
- **Frost Oil** (Item ID: 3829) - Frost damage weapon enchant for both slots

#### **Combat Potions** (NEW CATEGORY)
- **Nordanaar Herbal Tea** (Item ID: 61675) - Instant health/mana restoration (no buff tracking needed)
- **Potion of Quickness** (Item ID: 61181) - 30-second haste enhancement
- **Mighty Rage Potion** (Item ID: 13442) - Instant rage boost (no buff tracking needed)

### Enhanced Organization
- **Reorganized Consumable Categories**: Complete restructure for better user experience
  - **Elixirs & Juju**: Now contains only actual elixirs and juju items
  - **Special Potions & Consumables**: Separated unique potions that don't fit standard elixir categories
  - **Alcoholic Beverages**: New dedicated section for alcohol-based consumables
  - **Combat Potions**: New section for instant-effect and short-duration combat consumables
- **Data Structure Optimization**: Cleaned up unnecessary buffIcon fields for instant-effect items
- **Logical Categorization**: Items now properly grouped by type and function rather than arbitrary groupings

### Technical Improvements
- **Complete Item ID Integration**: All new consumables include proper item IDs for shopping list compatibility
- **Buff Icon Optimization**: Removed unnecessary buff tracking for instant-effect consumables
- **Duration Accuracy**: Proper duration values for all trackable buffs
- **Icon Integration**: Custom icons for Turtle WoW-specific items where available

### User Experience
- **Better Navigation**: Improved category organization makes finding specific consumables easier
- **Consistent Naming**: All items follow consistent naming conventions
- **Enhanced Shopping List**: New consumables automatically integrate with existing shopping list functionality
- **Tooltip Support**: Rich tooltips available for all new consumables

### Data Integrity
- **Wiki-Sourced Data**: All new consumables verified against official Turtle WoW wiki
- **Accurate Metadata**: Correct item IDs, durations, and buff icons for all additions
- **Testing Ready**: All items marked for in-game verification with clear testing comments

## [1.1.2] - 2025-08-01 - TIMER DRIFT FIX

### Bug Fixes
- **Timer Drift Detection**: Fixed critical timer accuracy issue where buff timers could show incorrect remaining time
  - **Dual Detection System**: Comprehensive timer drift protection with both active and passive detection
  - **Active Drift Detection**: When buffs are reapplied/refreshed, detects if timer has drifted beyond 60-second threshold and resets timestamp
  - **Passive Drift Detection**: During regular UI updates, detects phantom timers showing significant negative time and auto-clears them
  - **Automatic Correction**: Timers automatically reset to accurate time when drift is detected
  - **Problem Resolution**: Fixes cases where addon showed "35 minutes remaining" when actual buff had only "19 minutes left"
  - **No User Action Required**: Timer corrections happen automatically in background during normal addon operation

### Technical Details
- Enhanced `updateBuffTracker()` function with drift detection when buffs are actively detected
- Enhanced `getBuffRemainingTime()` function with phantom timer cleanup for passive drift detection
- 60-second tolerance threshold prevents false positives while catching significant drift issues
- Automatic tracker cleanup prevents accumulation of invalid timer data

## [1.1.1] - 2025-07-22 - BUG FIX UPDATE

### Bug Fixes
- **UI Interaction Fix**: Fixed keyboard input capture issue that prevented other UI elements (auction house, etc.) from receiving keystrokes when addon frames were open
  - Removed problematic frame-level EnableKeyboard(true) calls from settings frame, reset confirmation frame, and shopping list frame
  - Preserved necessary keyboard input for EditBox text fields (threshold editing)
  - Addon frames no longer interfere with global keyboard input to other game interface elements

## [1.1.0] - 2025-07-20 - MAJOR UPDATE

### New Features - ENHANCED TOOLTIPS
- **Rich Tooltip System**: Complete overhaul of tooltip functionality for professional WoW-style information display
  - **Three-Tier Tooltip System**: 
    1. Bag scanning for items in inventory (most accurate)
    2. Rich item/spell tooltips using IDs (works without items in inventory)
    3. Enhanced custom tooltips with detailed descriptions as fallback
  - **Item ID Integration**: Added comprehensive item IDs for all consumables (flasks, elixirs, food, weapon enchants)
  - **Spell ID Integration**: Added spell IDs for all class buffs (Power Word: Fortitude, Divine Spirit, Arcane Intellect, Mark of the Wild, all Paladin blessings)
  - **Rich Item Tooltips**: Shows vendor prices, item descriptions, requirements, stats, and full WoW item information
  - **Enhanced Class Buff Tooltips**: Detailed spell descriptions with mana costs, cast times, duration, and spell effects
  - **Weapon Enchant Rich Tooltips**: Full item information plus weapon slot context ("Weapon enchant for: Main Hand/Off Hand")

### New Features - SHOPPING LIST
- **Smart Shopping List Module**: Comprehensive consumable tracking system accessible via `/actshopping` or `/actshop`
  - **Intelligent Item Detection**: Only shows enabled buffs that are below configurable thresholds
  - **Category-Based Organization**: Items sorted by priority (Flasks → Elixirs → Weapon Enchants → Food → Other)
  - **Configurable Thresholds**: Different minimum amounts for different consumable types:
    - Flasks: Default 2 minimum
    - Elixirs: Default 5 minimum  
    - Food: Default 10 minimum
    - Weapon Enchants: Default 3 minimum
    - Other: Default 5 minimum
  - **Charge-Aware Detection**: Correctly counts charged items (oils, stones) vs stacked items
  - **Weapon Enchant Intelligence**: Properly tracks mainhand vs offhand enchants separately
  - **Visual Indicators**: Color-coded categories and clear "need X more" messaging
  - **Stock Status Display**: Shows "✓ All consumables well stocked!" when everything is sufficient

### Technical Improvements
- **WowHead Research Integration**: Used WowHead Classic database to source accurate item and spell IDs
- **Classic WoW Compatibility**: All tooltip functions use Classic WoW compatible API calls
- **Modular Architecture**: Shopping list implemented as separate module for clean code organization
- **Enhanced Data Structure**: All consumables now include both itemID and comprehensive metadata
- **Cross-Addon Compatibility**: Fixed tooltip conflicts with other addons (AtlasLoot, etc.)

### Enhanced User Experience
- **Professional Tooltips**: Users now see complete WoW-style tooltips with rich information even without items in inventory
- **Effortless Shopping**: No more guessing what consumables you need - the shopping list tells you exactly what's low
- **Smart Categorization**: Shopping list prioritizes important items (flasks) over common items (food)
- **Seamless Integration**: Shopping list uses same item detection logic as main addon for consistency

### Bug Fixes
- **Shopping List Close Button**: Fixed close button conflicts with other addons by using consistent implementation pattern
- **Tooltip Error Resolution**: Resolved "unknown link type" errors when hovering over icons
- **Cross-Addon Compatibility**: Eliminated tooltip conflicts that could affect other addons like AtlasLoot

### Data Enhancements
- **Complete Item ID Database**: Added item IDs for all 37+ consumables in the addon
- **Comprehensive Spell Database**: Added spell IDs for all 9 class buffs
- **Accurate Classic Data**: All IDs verified against WowHead Classic database for authenticity

## [1.0.7] - 2025-07-19

### Fixed - CRITICAL
- **Combat Pause Setting Conflict**: Fixed critical issue where "Pause UI updates in combat" setting completely broke hover-to-show functionality
  - **Root Cause**: When `pauseUpdatesInCombat` was enabled, entering combat would completely disable the OnUpdate timer with `SetScript("OnUpdate", nil)`
  - **Missing Timer Logic**: The restored OnUpdate handler after combat was missing the crucial hover-to-show hide timer logic
  - **Complete Fix**: Hover-to-show timer now continues running even when combat updates are paused
  - **Proper Restoration**: Post-combat OnUpdate handler now includes all necessary timer logic (hide timer, cleanup, etc.)
- **Timer Display Freeze During Combat**: Fixed critical issue where consumable and weapon enchant timer displays would freeze during combat when "Pause UI updates in combat" was enabled
  - **Root Cause**: Combat pause was completely disabling OnUpdate timer, stopping all timer display updates
  - **Timer Continuation**: Timer displays for consumables and weapon enchants now continue updating during combat pause
  - **Visual Accuracy**: Players can now see accurate countdown timers even during combat when updates are paused
  - **Complete Functionality**: Hover-to-show, timer displays, and essential updates all work during combat pause
- **Enhanced Combat Pause Logic**: Improved combat pause to maintain essential visual updates while still reducing performance load
  - **Selective Updates**: Only intensive operations (buff scanning, icon color changes) are paused during combat
  - **Essential Timers**: Timer display updates continue for accurate visual feedback
  - **Performance Balance**: Maintains combat performance benefits while preserving user experience
- **Combat State Management**: Enhanced combat event handlers to preserve hover-to-show functionality
  - **Minimal Combat Timer**: During combat pause, a lightweight timer handles hover-to-show hide logic and timer display updates
  - **Full Restoration**: After combat, complete OnUpdate handler is restored with all features intact

### Technical
- **Timer Separation**: Separated critical hover-to-show timer from general buff update logic
- **State Preservation**: Hover functionality now immune to combat setting changes
- **Timer Accuracy**: Consumable and weapon enchant timers remain visually accurate during combat
- **Performance Optimization**: Selective pausing reduces load while maintaining critical functionality
- **Comprehensive Testing**: Verified fix works with all combinations of combat and hover settings

## [1.0.6] - 2025-07-19

### Fixed - CRITICAL
- **Hover-to-Show Timer Logic**: Fixed critical issue where frames could get stuck visible even after hover timer expired
  - **Force Hide on Timer Expiry**: OnUpdate handler now immediately hides frame when hide timer expires, regardless of hover count state
  - **State Corruption Prevention**: Eliminates race conditions that could cause frame to remain visible with expired timers
  - **Automatic Recovery**: Frame now properly recovers from timer/state mismatches without manual intervention
- **Enhanced Debug Detection**: Improved `/actdebug` command to specifically detect expired timer situations
  - **Timer Expiry Detection**: Shows how long ago hide timer expired when frame is stuck visible
  - **Better Error Reporting**: More precise identification of the specific type of hover-to-show malfunction

### Technical
- **Robust Timer Handling**: Simplified hide timer logic to prevent state mismatch scenarios
- **Emergency Recovery**: Enhanced `/acthoverfix` command provides reliable recovery from any hover-related stuck state

## [1.0.5] - 2025-07-19

### Enhanced
- **Frame Position Persistence**: Lock frame now properly saves and restores position
  - **Automatic Position Saving**: Frame position is automatically saved when dragging the frame
  - **Position Restoration**: Saved position is restored when reloading UI or restarting the game
  - **Lock Frame Enhancement**: When lock frame is enabled, the frame maintains its custom position
  - **Smart Defaults**: New installations start with centered position, existing users keep their layout
  - **Migration Support**: Existing users automatically receive the framePosition setting

### Fixed
- **Hover-to-Show Stability**: Comprehensive improvements to prevent frame getting stuck visible/hidden
  - **Race Condition Prevention**: Improved OnEnter/OnLeave event handling to prevent hover count drift
  - **State Validation**: Enhanced hide timer logic with double-checking before hiding frame
  - **Boundary Protection**: Prevents hover count from going negative or getting out of sync
  - **Consistent Initialization**: Ensures hoverCount is always properly initialized

### Added
- **Advanced Debug Command**: Enhanced `/actdebug` with comprehensive hover-to-show diagnostics
  - **State Analysis**: Shows current alpha, hover count, hide timer status, and frame visibility
  - **Issue Detection**: Automatically detects when frame is stuck visible or hidden
  - **Troubleshooting Guidance**: Provides specific suggestions when state mismatches are detected
  - **Real-time Monitoring**: Displays expected vs actual frame states for debugging
- **Emergency Fix Command**: New `/acthoverfix` command to reset stuck hover-to-show state
  - **Instant Recovery**: Immediately resets hover count and hide timers
  - **Safe Reset**: Forces frame to proper hidden state when hover count is 0
  - **User-Friendly**: Clear instructions and feedback on what the command does

### Technical
- **Robust Event Handling**: Improved OnEnter/OnLeave handlers with proper state management
- **Safety Checks**: Added multiple validation layers to prevent hover state corruption
- **Enhanced Logging**: Better debug output for troubleshooting hover-to-show issues

## [1.0.4] - 2025-01-18

### Enhanced
- **Icon Spacing Configuration**: Improved icon layout customization
  - Reduced minimum icon spacing from 20 to 30 pixels for border-to-border icon placement
  - Updated icon spacing range to 30-64 pixels with clear label indication
  - Enhanced validation to ensure proper spacing values within acceptable range
- **Settings UI Reorganization**: Complete overhaul of settings interface layout
  - **Streamlined Layout**: Reorganized from scattered right-side layout to clean left-column organization
  - **Layout Settings** (Left): Scale slider, update interval, icons per row, icon spacing
  - **Combat Settings** (Left): Combat-specific options logically grouped below layout settings
  - **Display Settings** (Left): Tooltips, hover-to-show, lock frame features organized below combat settings
  - **Future-Ready**: Right side now available for expansion of additional settings categories
  - Improved visual organization and user experience with logical grouping flow
- **Frame Position Persistence**: Lock frame now properly saves and restores position
  - **Automatic Position Saving**: Frame position is automatically saved when dragging the frame
  - **Position Restoration**: Saved position is restored when reloading UI or restarting the game
  - **Lock Frame Enhancement**: When lock frame is enabled, the frame maintains its custom position
  - **Smart Defaults**: New installations start with centered position, existing users keep their layout
- **Visual Polish**: Enhanced spacing and padding throughout the UI
  - Added 2px padding between "Buffs" title and icon grid for better visual separation
  - Improved timer positioning: moved from very top/bottom edges to more readable positions
  - Normal buff timers positioned 8px from top edge
  - Weapon enchant timers positioned 8px from bottom edge for better slot indicator separation
- **Buff Tracker System**: Comprehensive cleanup and maintenance improvements
  - **Immediate Cleanup**: Enhanced natural buff expiration cleanup in `UpdateBuffStatusOnly()`
  - **Periodic Maintenance**: Added 30-second cleanup cycle to remove any stale tracker entries
  - **Memory Management**: Prevents accumulation of expired buff data in saved variables
  - **Timer Display Fix**: Resolved issue where timers wouldn't show after reapplying expired buffs

### Fixed
- **Buff Timer Display**: Fixed critical bug where buff timers wouldn't display correctly after reapplying buffs
  - Root cause: Stale entries in `buffTracker` and `Akkio_Consume_Helper_Settings.buffTracker`
  - Solution: Multi-layered cleanup system for manual removal, natural expiration, and periodic maintenance
- **Icon Spacing Validation**: Fixed validation ranges and error messages to match new 30-64 pixel range
- **Settings Layout**: Resolved unbalanced UI layout with proper left/right content distribution

### Technical
- **Cleanup Architecture**: Implemented three-tier buff tracker cleanup system
  1. Manual removal cleanup (when buffs are cancelled)
  2. Natural expiration cleanup (during update cycles)
  3. Periodic maintenance cleanup (every 30 seconds)
- **Frame Reference Fixes**: Corrected `this` references in ticker OnUpdate functions to use proper frame references
- **Data Consistency**: Enhanced buff tracker data consistency between active and persistent storage

## [1.0.3] - 2025-01-18

### Added
- **Centralized Duration System**: Moved all buff duration data from separate tables to the main data structure in `Akkio_Consume_Helper_Data.allBuffs`
  - Added duration fields to all consumable buffs (flasks: 7200s, elixirs: 3600s, food: 900s, jujus: 1800s)
  - Duration values now stored alongside buff data for better maintainability
  - Simplified duration lookup with direct data table access
- **New Consumables**: Expanded buff database with additional items
  - **Dreamshard Elixir**: Added Turtle WoW custom elixir with 2-hour duration (7200s)
  - **Hardened Mushroom** and **Power Mushroom**: Added custom food items with 15-minute duration (900s)
- **Extended Weapon Enchant Support**: Added comprehensive weapon enchant tracking
  - **Brilliant Mana Oil** and **Brilliant Wizard Oil**: Caster weapon enchants
  - **Blessed Weapon Coating**: Anti-undead weapon enhancement
  - **Shadowoil**: Shadow damage weapon enchant
  - **Rogue Poisons**: Deadly Poison and Instant Poison for both weapon slots

### Enhanced
- **Smart Timer Display**: Timer labels now only appear on buffs that have duration values defined
  - Class buffs (Power Word: Fortitude, Divine Spirit, etc.) no longer show timer labels
  - Consumable buffs continue to show countdown timers as expected
  - Weapon enchants maintain API-based timer displays using `GetWeaponEnchantInfo()`
- **Weapon Enchant Timer System**: Comprehensive real-time timer tracking for weapon enchants
  - Added timer labels to weapon enchant icons showing remaining time
  - Integrated `GetWeaponEnchantInfo()` API for accurate millisecond-precision timing
  - Real-time updates every second through enhanced `UpdateBuffStatusOnly()` function
  - Proper milliseconds-to-seconds conversion for display consistency
- **Enhanced Tooltip System**: Improved tooltip information for all buff types
  - Weapon enchant tooltips now show precise remaining time using WoW API
  - Class buff tooltips no longer display timer information (duration-based filtering)
  - Consumable tooltips continue to show timestamp-based countdown timers
- **Dual Timer Architecture**: Implemented sophisticated timer system handling different buff types
  - Timestamp tracking for consumable buffs with manual duration calculations
  - API-based tracking for weapon enchants using game data
  - Unified `formatTimeRemaining()` function for consistent time display

### Fixed
- **Data Structure Consistency**: Eliminated duplicate duration storage across different files
- **Timer Label Rendering**: Fixed unnecessary timer creation for buffs without duration values
- **Update Function Optimization**: Enhanced `UpdateBuffStatusOnly()` with proper duration checking

### Refactored
- **Duration Lookup Function**: Simplified `getBuffDuration()` to use centralized data table instead of separate duration arrays
- **Timer Update Logic**: Streamlined timer updates to only process buffs with appropriate timer components
- **Memory Management**: Reduced memory overhead by eliminating redundant duration storage

### Technical
- **API Integration**: Full integration of `GetWeaponEnchantInfo()` for weapon enchant timing
- **Data Normalization**: Centralized all duration data in main allBuffs structure for better organization
- **Conditional Rendering**: Smart timer label creation based on buff duration availability
- **Performance Optimization**: Reduced function calls and improved data access patterns

## [1.0.2] - 2025-01-17

### Fixed
- **Charged Item Detection**: Fixed critical bug where charged items (oils, sharpening stones) were not properly detected in bags
  - WoW Classic API returns negative values for charged items (e.g., -5 = 5 charges remaining)
  - Implemented `math.abs()` conversion for both simple and cached bag scanning functions
  - Brilliant Wizard Oil, Mana Oil, Dense Sharpening Stone, and other charged items now properly detected
  - Enhanced debug output to show both raw and corrected count values for troubleshooting
- **ShaguTweaks Compatibility**: Fixed scroll frame functionality when ShaguTweaks addon is enabled
  - Replaced template-based scroll frame with custom implementation to avoid conflicts
  - Added explicit mouse wheel event handling that bypasses ShaguTweaks global hooks
  - Buff selection UI scrolling now works properly with ShaguTweaks installed
- **Icon Corrections**: Fixed incorrect buff icons for several items
  - Gift of Arthas: Corrected buff icon to properly show the actual buff effect
  - Prayer of Spirit: Fixed raid buff icon path for proper detection
  - Arcane Intellect: Corrected raid buff icon reference for improved recognition

### Technical
- **Charged Item API Handling**: Added proper handling for WoW Classic's negative count behavior for charged items
- **Debug Command Improvements**: Reverted `/actdebug` to focus on buff scanning for better troubleshooting capabilities
- **Scroll Frame Compatibility**: Custom scroll bar implementation resistant to addon conflicts
- **Icon Database**: Updated buff icon references to match actual in-game buff icons

## [1.0.1] - 2025-01-17

### Added
- **Hover-to-Show Feature**: New QoL option to show buff status frame only when hovering over individual buff icons
  - Frame becomes completely transparent when not hovering
  - Prevents automatic UI rebuilds during non-hover states to maintain proper visibility control
  - Configurable setting in UI options panel

### Fixed
- **Conditional Rebuild System**: Automatic UI rebuilds now respect hover-to-show settings
  - Fixed issue where frame would unexpectedly become visible during automatic updates
  - Implemented intelligent rebuild prevention when hover-to-show is enabled and no icons are being hovered
- **Settings Application**: Improved immediate response when applying hover-to-show settings
  - Frame now properly hides immediately after enabling the feature via Apply button

### Technical
- **Ticker Optimization**: Enhanced both main and combat handler tickers with conditional rebuild logic
- **Alpha State Management**: Improved frame transparency handling during UI rebuilds

## [1.0.0] - 2025-01-17

### Added
- **Weapon Enchant Tracking**: Full support for main hand and off hand weapon enchants
- **Smart Caching System**: Optimized bag scanning with 2-second cache refresh
- **Performance Optimization**: Dual-update system (fast visual updates + full rebuilds)
- **Combat Awareness**: Optional UI hiding and update pausing during combat
- **Advanced Settings Panel**: Comprehensive configuration options
- **Color-Coded Feedback**: Professional message styling with status colors
- **Instant UI Refresh**: Immediate feedback for user actions
- **Weapon Slot Indicators**: Visual MH/OH labels for enchant tracking
- **UI Polish**: Enhanced tooltips, labels, and visual design
- **Minimap Integration**: Quick access button with informative tooltip
- **Draggable Minimap Button**: Reposition button anywhere around minimap edge
- **Persistent Button Position**: Saves minimap button location between sessions
- **Flexible Layout**: Configurable icons per row (1-10)
- **Scalable Interface**: UI scaling from 0.5x to 2.0x
- **Slash Commands**: Multiple command options for different functions (`/act`, `/actsettings`, `/actbuffstatus`, `/actreset`)
- **Automatic Announcements**: Smart group/raid buff request announcements
- **Version Migration System**: Automatic settings upgrade for future updates
- **Emergency Reset Function**: Recovery system for corrupted settings
- **Settings Validation**: Data integrity checks and automatic cleanup
- **Interactive Tooltips**: Comprehensive tooltip system showing buff status, item counts, and action hints with color coding
- **Tooltip Settings**: Optional tooltip display with user-configurable enable/disable setting

### Enhanced
- **Buff Selection UI**: Improved organization and visual clarity
- **Error Handling**: User-friendly error messages and validation
- **Memory Management**: Efficient cleanup and resource management
- **Update Cycles**: Smart timing for optimal performance
- **User Experience**: Intuitive interface with clear visual feedback

### Technical
- **Function Order Resolution**: Fixed all startup dependency issues
- **Caching Architecture**: Implemented efficient bag and buff caching
- **Event Management**: Proper combat state and addon lifecycle handling
- **Code Organization**: Clean separation of concerns and modular design
- **Performance Monitoring**: Built-in optimization for extended play sessions
- **Version Control**: Automatic migration system for seamless updates
- **Data Integrity**: Robust validation and corruption recovery systems

### UI/UX Improvements
- **Visual Theme**: blue-gray color scheme
- **Message Styling**: Consistent color coding across all feedback
- **Tooltip Enhancement**: Multi-line tooltips with context information
- **Button Labels**: Descriptive and action-oriented text
- **Status Indicators**: Clear visual representation of buff states
- **Layout Options**: Flexible positioning and sizing controls
- **Minimap Button**: Smooth drag functionality with angle-based positioning

### Compatibility
- **WoW Classic 1.12**: Full compatibility with original turtle client
- **Settings Persistence**: Character-specific saved variables
- **Performance Scaling**: Optimized for both solo and raid environments
- **Cross-Character**: Individual settings per character

---

## Development Notes

### Architecture Highlights
- **Modular Design**: Separated concerns for maintainability
- **Performance First**: Caching and optimization built-in from start
- **User-Centric**: Extensive focus on user experience and feedback
- **Robust Error Handling**:handling of edge cases

### Future Considerations
- Additional weapon enchant types based on community feedback
- Enhanced customization options for power users
- Potential integration with other Classic addons
- Community-driven feature requests and improvements

### Technical Debt
- Function definition order resolved
- Memory leaks eliminated
- Performance bottlenecks optimized
- UI responsiveness enhanced

---

*Version 1.0.0 represents a complete, addon with polish and robust functionality Tho some bugs may occur in this version since not all buffs has currently been tested, if u find any none working icons/buffs tracking please let me know on discord:#akkio*
