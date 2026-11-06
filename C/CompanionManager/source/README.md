# CompanionManager
**Version:** 1.1  
**Game Version:** Turtle WoW (Interface 11200)

CompanionManager is a lightweight, drag-and-drop companion organizer for Vanilla WoW. Easily summon and categorize your vanity pets, toys, and illusions through an intuitive radial menu.

<img src="https://i.imgur.com/WlKdqNj.gif">

---

## ✨ Features

- 🔘 Circular menu to access companion categories
- ⌨️ Assign a hotkey in key bindings to open the menu
- 🖱️ Menu will appear at your cursor when opened
- 🐾 Drag-and-drop sorting of companions and categories
- 🐢 Custom categories for Cats, Frogs, Flying, Turtles, and more
- 🧸 Optional support for Toys
- 🎲 “Random” summon button for surprise pets
- ⚙️ Minimal configuration via slash commands

---

## 🧰 Slash Commands

Type `/cm` or `/companionmanager` in chat to see all options.
- `/cm show` - Open the radial menu.
- `/cm close` - Close the radial menu.
- `/cm toggle` - Toggle the radial menu.

Optional command-line settings:
- `/cm size <number>` — Set icon size (default: 32)
- `/cm toys on|off` — Show or hide toys in the menu
- `/cm verbose on|off` — Toggle verbose summon messages

---

## 🔄 Controls

- Open radial menu with slash command or key binding
- **Mouseover** a category to view companions
- **Middle-Click** a category or companion to close the menu
- **Drag** companions or categories to rearrange them
- **Drag the center icon** to rotate the whole wheel

---

## 📦 Installation

Using the Turtle Wow Launcher:

Copy and paste https://github.com/sica42/CompanionManager into the launcher.

Manual install:
1. Download or clone the addon into your `Interface\AddOns\` folder.
2. Make sure the folder is named `CompanionManager`.
3. Restart WoW (not just `/reload`) to detect new textures and icons.
4. Log in and type `/cm` or assign a hotkey in key bindings to get started!

---

## 💬 Notes

- Companion data is pulled from the "ZzCompanions" and "ZzzzToys" spell tabs. If your server uses different names, they may need to be adjusted in `CompanionManager.lua`.
- This addon is 100% compatible with WoW Classic (Vanilla 1.12.0, Interface 11200). It does **not** use any TBC or retail-only API features.
- Not all companions have been categorized. If you have a companion that isn't correctly categorized, please create an issue on Github and provide companion name and category it belongs to.


## 📄 License

MIT License — do what you want with it. Credits appreciated but not required.





