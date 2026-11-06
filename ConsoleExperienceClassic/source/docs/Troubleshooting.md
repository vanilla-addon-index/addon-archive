# Troubleshooting

Common issues and solutions for ConsoleExperienceClassic.

## Installation Issues

### Addon doesn't appear in addon list
**Cause:** Folder structure is incorrect.

**Solution:**
1. Check that the folder is named exactly `ConsoleExperienceClassic`
2. Ensure `ConsoleExperienceClassic.toc` is directly in the folder
3. Not nested like `ConsoleExperienceClassic/ConsoleExperienceClassic/`

### "Interface out of date" warning
**Cause:** TOC version doesn't match game version.

**Solution:**
- Click "Load out of date AddOns" on character select
- Or enable in AddOns menu settings

## Action Bar Issues

### Action bars don't appear
**Cause:** UI error or conflict with other addons.

**Solution:**
1. Type `/reload` to reload UI
2. Disable other action bar addons
3. Check for Lua errors: `/console scriptErrors 1`

### Buttons are in wrong positions
**Solution:**
1. Open `/ce` configuration
2. Go to "Action Bars" section
3. Click "Reset Layout" to restore defaults

### Spells not updating to highest rank
**Solution:**
1. Check that Auto-rank is enabled in config
2. Run `/cerank debug` to see current spell ranks
3. Run `/cerank update` to manually update

## Cast Bar Issues

### Cast bar doesn't appear
**Cause:** Cast bar might be disabled.

**Solution:**
1. Open `/ce` configuration
2. Go to "Cast Bar" section
3. Enable "Enable Cast Bar"

### Cast bar is behind other elements
**Cause:** Frame strata issue.

**Solution:**
- This should be fixed in recent versions
- Try `/reload` to refresh the UI

## Chat Issues

### Chat frame is in wrong position
**Solution:**
1. The addon repositions chat to bottom center
2. This is intentional for controller use
3. Adjust position in Chat settings if needed

### Virtual keyboard doesn't appear
**Cause:** Keyboard might be disabled.

**Solution:**
1. Open `/ce` configuration
2. Go to "Chat" section
3. Enable "Virtual Keyboard"

## XP/Rep Bar Issues

### Bars don't show
**Cause:** Bars may be set to fade out.

**Solution:**
1. Open `/ce` configuration
2. Go to "XP/Rep Bars" section
3. Enable "Always Visible" for the bars you want

### Bars show wrong colors
**Solution:**
- XP bar: Purple (not rested) or Blue (rested)
- Rep bar: Colors based on faction standing
- This is intentional behavior

## Performance Issues

### Low FPS or lag
**Cause:** Too many OnUpdate scripts.

**Solution:**
1. Disable features you don't use
2. Reduce number of enabled bars
3. Check for conflicts with other addons

## Error Messages

### "attempt to call nil value"
**Cause:** Function doesn't exist or addon loaded incorrectly.

**Solution:**
1. Reinstall the addon
2. Make sure all files are present
3. Check for missing dependencies

### "Script ran too long"
**Cause:** Infinite loop or heavy processing.

**Solution:**
1. Report the issue on GitHub with steps to reproduce
2. Try disabling specific features to isolate the problem

## Reporting Bugs

If you encounter a bug:

1. **Enable script errors:** `/console scriptErrors 1`
2. **Note the error message** that appears
3. **Document steps to reproduce** the issue
4. **Check existing issues** on GitHub
5. **Create a new issue** with:
   - Error message
   - Steps to reproduce
   - Your WoW version
   - Other addons installed

## Getting Help

- **GitHub Issues:** Report bugs and feature requests
- **Documentation:** Read through feature docs
- **Debug Mode:** Enable in General settings for more info

## Reset Everything

If all else fails, reset to defaults:

1. Log out of WoW
2. Delete: `WTF/Account/<Account>/SavedVariables/ConsoleExperienceClassic.lua`
3. Log back in
4. Reconfigure settings
