# EzPoison (Fork by Quad Crown)
EzPoison is a World of Warcraft addon that provides a convenient GUI to manage and apply poisons, sharpening stones, and wizard/mana oils to your weapons. This fork includes additional tweaks and quality-of-life improvements.

## Features
- Simple GUI: Quickly apply poisons, stones, or oils to your main-hand and off-hand weapons.
- Profiles: Save up to 7 different configurations (profiles) for your poisons/stones/oils. Switch between them with a single click or slash command.
- Inventory Tracking: Displays how many of each poison/stone/oil remain in your bags.
- Moveable/Scalable Window: Drag to reposition and adjust the scale of the GUI to fit your UI needs.
- Slash Commands: Control the addon through various /ezpoison or /EzPoison commands.

## Installation
Download or clone this repository.
Copy the EzPoison folder into your WoW AddOns directory:
Retail: \World of Warcraft\_retail_\Interface\AddOns\
Classic: \World of Warcraft\_classic_\Interface\AddOns\
Restart (or start) your WoW client and enable EzPoison in the addon list.
Once in-game, use /ezpoison to toggle the GUI or configure as needed.

## Usage
Toggle the EzPoison frame:
Type /ezpoison (or /EzPoison) with no additional arguments to show or hide the configuration frame.

### Apply poisons:

Left-click on the Main-Hand or Off-Hand icon in the EzPoison window to automatically apply the currently selected poison/stone/oil.
Right-click on the icon to open a dropdown where you can pick the type of consumable you want.
Move the EzPoison window:

Click and drag anywhere on the EzPoison window to reposition it on your screen.
Scale the EzPoison window:

Use the Fubar options if you have FuBar installed, or use the slash command (/ezpoison scale <value>) to adjust the scale. (See Slash Commands below.)
Profiles:

You can have 7 different profiles, each storing separate Main-Hand and Off-Hand consumable choices.
Click the small dots (above the main GUI) to switch profiles directly.
Profile names can be changed via FuBar options or by editing the config (EZPcfg in the code).

## Slash Commands
All commands can be used with /ezpoison or /EzPoison:

"/ezpoison"
Toggles the EzPoison configuration window on/off.
Scale

"/ezpoison scale <number>"
Sets the window scale if <number> is between 0.3 and 3.
Example: "/ezpoison scale 1.5"
Apply

"/ezpoison apply"
Automatically applies poisons if either the main-hand or off-hand selection is out of charges (faded).
Profile

"/ezpoison profile <1-7>"
Activates the specified profile number (1 through 7).
Example: "/ezpoison profile 3"

## Advanced Configuration
Renaming Profiles

Through FuBar: In the FuBar menu, navigate to EzPoison’s options. Each profile has a rename field.
Directly in Lua: Edit EZPcfg.Profile[x].Name in your Saved Variables if you’re comfortable editing addon files.
FuBar Integration

EzPoison includes FuBar support (via the Ace2 libraries). An icon will appear on the FuBar minimap area for quick toggling of the config window.
Inventory Counts

Hover over the icons to see details. The count on each button represents the total quantity of that poison/stone/oil in your inventory.
The icon will fade (opacity ~20%) if you have zero items remaining.
Known Limitations / Notes
The addon checks your bags for the selected poison/stone/oil. If it cannot find a match, it will notify you in the chat window.
Item counts update whenever your bags change or you apply a poison. If numbers seem off, try opening/closing your bags or reapplying poison to refresh.

## Contributing
This is a fork of EzPoison by Voidmenull (https://github.com/Voidmenull/EzPoison) edited by Quad Crown. Feel free to open issues or pull requests if you have improvements or suggestions. For major changes, please open an issue first to discuss what you would like to change.

