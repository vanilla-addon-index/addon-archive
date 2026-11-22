# Gimmetbarbie Addon Manager

An in-game addon manager for **OctoWoW / TurtleWoW 1.18.1** and other WoW 1.12 clients (Interface 11200). Enable or disable installed addons, launch their slash commands, review Lua errors, and collect minimap buttons in a drawer.

**Fork version 1.3.0** · [Fork changelog](CHANGELOG.md)

## Features

### Enable and disable addons

- Browse installed addons in the **Enabled** and **Disabled** tabs. Click an addon's state button to toggle it, then click **Reload UI** to apply the change.
- Pending changes show a reload reminder. Addons that fail to load show the reason when the client provides one.

### Profiles

- Four numbered slots beside **Reload UI** save your enabled and disabled addons. **Shift+click** to save, **click** to load, or **Ctrl+click** to load and reload immediately.
- A green number marks a matching profile. An empty slot is gray. Hover over a slot to see its name and how many addons it enables.
- Use `/am profile name 1 Raid` to name a slot. Loading a profile preserves the manager and the state of addons installed after the profile was saved.

### Quick-launch commands

- The manager discovers slash commands registered during addon loading and adds quick-launch buttons to the addon list.
- A small set of overrides supplies preferred commands for some addons. Use `/am commands` to see the discovery counts.

### Error log

- The error log keeps timestamped Lua errors across sessions and passes them to the previously installed error handler.
- Click inside the log and use **Ctrl+A**, then **Ctrl+C**, to copy its text.

### Minimap button drawer

- **Left-click** the manager button to toggle the drawer. **Right-click** to open or close the addon list.
- **Ctrl+left-drag** moves the button anywhere on screen and saves its position. `/am resetbutton` returns it beside the minimap.
- The drawer opens toward the center of the screen and sizes its grid to the collected buttons. It closes after five seconds away from the drawer and its button by default.
- Use **Release** in **Settings** to return a button to the minimap, or **Recollect** to put it back in the drawer. You can also drag a collected button out of the drawer. Released buttons stay out across reloads.

## Slash commands

| Command | Action |
| --- | --- |
| `/am` | Toggle the addon list. |
| `/am reload` | Reload the UI to apply pending changes. |
| `/am rescan` | Scan for minimap buttons again. |
| `/am resetbutton` | Return the manager button beside the minimap. |
| `/am autoclose` | Show the current drawer timeout. |
| `/am autoclose 5` | Set the timeout to five seconds. |
| `/am autoclose off` | Disable drawer auto-close. |
| `/am profile` | List profile slots. |
| `/am profile 1` | Load slot 1. Reload the UI to apply changes. |
| `/am profile save 1` | Save the current setup to slot 1. |
| `/am profile name 1 Raid` | Rename slot 1 to Raid. |
| `/am profile clear 1` | Empty slot 1. |
| `/am commands` | List discovered slash-command counts by addon. |
| `/am probe` | Print the client's raw `GetAddOnInfo(1)` return values for troubleshooting. |

## Installation

1. Extract or clone the addon into `Interface/AddOns/`.
2. Check that the path is `Interface/AddOns/GimmetbarbieAddonManager/GimmetbarbieAddonManager.toc`. If your ZIP adds a branch suffix to the folder name, rename the folder to `GimmetbarbieAddonManager`.
3. Run `/reloadui` or restart the client.

## Known limitations

- Addon enable and disable changes take effect after a UI reload.
- The fields returned by `GetAddOnInfo` can vary by client build. If the addon list shows unexpected states, use `/am probe` to inspect the values.
- Minimap button detection uses frame names, sizes, and parentage. Use **Release** if the drawer collects a button you want to keep on the minimap.
- ShaguTweaks' **Minimap Clean** also manages minimap button visibility and can affect buttons you release back to the minimap.

## Credits

- [Salahaja](https://github.com/Salahaja) created the original addon and did most of the work, including addon management, command discovery, error logging, and the minimap drawer. [Original repository](https://github.com/Salahaja/GimmetbarbieAddonManager)
