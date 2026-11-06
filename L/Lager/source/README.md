# Lager

Lager is a light-weight addon for World of Warcraft (version 1.12) that reduces lag by pausing superfluous combat logs.


![preview](https://raw.githubusercontent.com/ZenSociety/ProjectImagesVault/refs/heads/main/lager1.png)

## How does 'Lager' work?

You actually don’t need 'Lager' because this addon just automatically executes the following commands, which you can also input one by one manually in-game:
```lua
/run SetCVar("CombatLogRangeParty", 0)
/run SetCVar("CombatLogRangePartyPet", 0)
/run SetCVar("CombatLogRangeFriendlyPlayers", 0)
/run SetCVar("CombatLogRangeFriendlyPlayersPets", 0)
/run SetCVar("CombatLogRangeHostilePlayers", 0)
/run SetCVar("CombatLogRangeHostilePlayersPets", 0)
/run SetCVar("CombatDeathLogRange", 0)
```

The benefit of having this addon is, you can easily toggle it on and off at your convenience. I recommend activating it during intense 40-man raid combat and deactivating it when you're not experiencing lag.

## Side effect
When you activate 'Lager,' other combat-related addons, like the DPS meter, may not function as intended.

## Features

- Toggle combat log distances between minimum and maximum settings.
- Display current combat log status in the chat.
- Minimap button for easy access and control.
- Simple command interface for additional functionality.

## Installation (Vanilla, 1.12)

1. Download **[Latest Version](https://github.com/ZenSociety/Lager/archive/master.zip)**
2. Unpack the Zip file
3. Rename the folder "Lager-main" to "Lager"
4. Copy "Lager" into Wow-Directory\Interface\AddOns
5. Restart WoW game client.

## Usage

Once the addon is installed and enabled, you can use the following commands in the chat:

- `/lager on` - Enables the Lager addon and sets the combat log distance to minimum.
- `/lager off` - Disables the Lager addon and sets the combat log distance to maximum.
- `/lager show` - Displays the current combat log distances in the chat.
- `/lager about` - Shows information about the Lager addon.

### Minimap Button

- click the minimap button to toggle the addon on or off.

## Notes

- The combat log distance settings are crucial for the proper functioning of damage meters and other combat-related addons.

## License
This addon is released under the MIT License.

## Support
For issues or feature requests, please open an issue on the [GitHub repository](https://github.com/ZenSociety/Lager/issues) or contact the author directly.
