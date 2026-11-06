# Addon Integrations

ConsoleExperienceClassic integrates with several popular addons to provide a seamless experience. This document describes the supported integrations and any required configuration.

## pfUI Integration

[pfUI](https://github.com/shagu/pfUI) is a full UI replacement for Vanilla WoW and TBC. ConsoleExperienceClassic provides automatic integration with pfUI.

### Automatic Features

When pfUI is detected, ConsoleExperienceClassic will:

- **Automatically disable the Chat module** - pfUI has its own chat system, so ConsoleExperience's chat module is disabled to prevent conflicts
- **Apply pfUI styling** - The ConsoleExperience configuration frame and main menu button will automatically use pfUI's styling system for a consistent look
- **Support pfUI bag frames** - Cursor navigation works seamlessly with pfUI's custom bag frames (`pfBag` and `pfBank`)

### Required Configuration

**Important:** You must manually disable the Action Bar module in pfUI to avoid conflicts with ConsoleExperience's action bars.

1. Open pfUI configuration with `/pfui`
2. Navigate to **Modules** → **Action Bars**
3. Disable the Action Bar module
4. Reload your UI with `/rl`

### Benefits

- Consistent UI styling across all frames
- Full cursor navigation support for pfUI's bag system
- No chat conflicts between the two addons

---

## Bagshui Integration

[Bagshui](https://github.com/Skillkrote/Bagshui) is an all-in-one auto-categorizing and sorting inventory addon for Vanilla WoW 1.12.

### Automatic Features

ConsoleExperienceClassic automatically detects and integrates with Bagshui:

- **Cursor Navigation Support** - Full cursor navigation support for Bagshui's bag and bank frames
- **Item Actions** - All item actions (pickup, use, delete, bind) work correctly with Bagshui's item buttons
- **Tooltip Integration** - Item tooltips display correctly when navigating Bagshui frames

### Frame Names

ConsoleExperienceClassic hooks into the following Bagshui frames:
- `BagshuiBagsFrame` - Main inventory frame
- `BagshuiBankFrame` - Bank frame
- Item buttons: `BagshuiBagsItem{num}` and `BagshuiBankItem{num}`

### No Configuration Required

Bagshui integration works automatically - no additional configuration is needed. Simply have both addons installed and enabled.

---

## Bagnon Integration

[Bagnon](https://github.com/McPewPew/Bagnon) combines all your bags into one big bag for easier inventory management.

### Automatic Features

ConsoleExperienceClassic automatically detects and integrates with Bagnon:

- **Cursor Navigation Support** - Full cursor navigation support for Bagnon's inventory and bank frames
- **Item Actions** - All item actions (pickup, use, delete, bind) work correctly with Bagnon's item buttons
- **Tooltip Integration** - Item tooltips display correctly when navigating Bagnon frames

### Frame Names

ConsoleExperienceClassic hooks into the following Bagnon frames:
- `Bagnon` - Main inventory frame
- `Banknon` - Bank frame
- Item buttons: `BagnonItem{num}` and `BanknonItem{num}`

### No Configuration Required

Bagnon integration works automatically - no additional configuration is needed. Simply have both addons installed and enabled.

---

## Troubleshooting

### Cursor Not Appearing on Bag Frames

If the cursor doesn't appear when navigating bag frames from pfUI, Bagshui, or Bagnon:

1. Make sure both addons are enabled
2. Try reloading your UI with `/rl`
3. Open and close the bag frame once to trigger the hook
4. Check the ConsoleExperience debug messages (if enabled) for hook status

### Conflicts with Other Addons

If you experience conflicts with other bag or UI addons:

1. Check if the addon is in the list of supported integrations
2. Try disabling other bag addons if you're using one of the supported ones
3. Report the issue on the GitHub repository with details about the conflicting addon

---

## Adding New Integrations

If you'd like to request integration with another addon, please open an issue on the GitHub repository with:
- The addon name and repository link
- A description of what integration features would be useful
- Any relevant technical details about the addon's frame structure
