# Installation Guide

## Download

### Option 1: GitHub Release
1. Go to the [Releases page](https://github.com/yourusername/ConsoleExperienceClassic/releases)
2. Download the latest `.zip` file
3. Extract the contents

### Option 2: Clone Repository
```bash
git clone https://github.com/yourusername/ConsoleExperienceClassic.git
```

## Installation Steps

### For TurtleWoW / Vanilla WoW 1.12

1. **Locate your WoW AddOns folder:**
   ```
   <WoW Directory>/Interface/AddOns/
   ```
   
   Examples:
   - Windows: `C:\Games\TurtleWoW\Interface\AddOns\`
   - macOS: `/Applications/TurtleWoW/Interface/AddOns/`
   - Linux: `~/TurtleWoW/Interface/AddOns/`

2. **Copy the addon folder:**
   - Copy the `ConsoleExperienceClassic` folder into the `AddOns` directory
   - Make sure the folder structure is correct:
     ```
     Interface/
     └── AddOns/
         └── ConsoleExperienceClassic/
             ├── ConsoleExperienceClassic.toc
             ├── main.lua
             ├── actionbars/
             ├── chat/
             ├── config/
             └── ...
     ```

3. **Restart WoW** (if running)

4. **Enable the addon:**
   - At the character select screen, click "AddOns"
   - Make sure "ConsoleExperienceClassic" is checked
   - Click "Okay"

## Verify Installation

1. Log into the game
2. You should see the gamepad-style action bars at the bottom of the screen
3. Type `/ce` to open the configuration panel

## Updating

1. Delete the old `ConsoleExperienceClassic` folder
2. Copy the new version to the AddOns folder
3. Your settings are saved and will persist

## Uninstallation

1. Delete the `ConsoleExperienceClassic` folder from AddOns
2. (Optional) Delete saved variables:
   - Located in `WTF/Account/<AccountName>/SavedVariables/ConsoleExperienceClassic.lua`

## Troubleshooting Installation

### Addon doesn't appear in the list
- Make sure the folder name is exactly `ConsoleExperienceClassic`
- Check that `ConsoleExperienceClassic.toc` is directly inside the folder (not in a subfolder)

### "Interface out of date" warning
- Click "Load out of date AddOns" at the character select screen
- Or check the box to always load out of date addons

### Addon loads but nothing appears
- Type `/reload` to reload the UI
- Check for Lua errors with `/console scriptErrors 1`

See the [Troubleshooting Guide](Troubleshooting.md) for more help.
