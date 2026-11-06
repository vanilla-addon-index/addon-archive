# Arcanum - Mage UI Addon for Turtle WoW (v1.1)

![Arcanum Interface](img.png)

**Arcanum** is a comprehensive mage utility addon for World of Warcraft 1.12 (Vanilla), specifically updated for **Turtle WoW**. It provides an elegant circular interface for managing buffs, portals, conjured items, and more - keeping your action bars clean and organized.

Originally created by **Nausicaa & Pepopo**, now maintained and updated by **Fayz**.

---

## 🔮 Features

### **Circular Button Interface**
- Customizable circular arrangement around a central sphere
- **10 configurable buttons** for quick spell access:
  - Food (Conjure Food / Ritual of Refreshment)
  - Water (Conjure Water)
  - Mana Gems with auto-use priority
  - Buffs (Arcane Intellect / Arcane Brilliance)
  - Hearthstone with 60-minute cooldown timer
  - **4 Portal/Teleport buttons** with 60-second cooldown timers
- **Dual-mode Button 5**: Hearthstone (solo) / Atiesh-Karazhan Portal (group)

### **Turtle WoW Custom Features**
- ✨ **Atiesh Portal to Karazhan** - Special functionality for equipped Atiesh staff
- 🏰 **Alah'Thalas (High Elf) Portals** - Full support for High Elf racial teleports/portals
- ⏱️ **Smart Cooldown Timers** - Visual countdown on portal buttons and Atiesh
- 💬 **Immersive Emotes** - 10 randomized emote messages for portals and Ritual of Refreshment

### **Quality of Life**
- **Auto-reagent purchasing** - Automatically buys Arcane Powder, Runes of Teleportation/Portals
- **Reagent organization** - Sorts reagents into designated bag
- **Cooldown tracking** - Visual timers for portals (60s), Atiesh (60s), Ice Armor (30m)
- **Buff duration display** - See remaining time on Ice Armor inside the sphere
- **Item counters** - Track food, water, mana gems, and reagents
- **Smart conjuring** - Right-click buttons to conjure, left-click to use

### **Customization**
- Rotate and scale the entire interface
- Reorder buttons in any configuration
- Show/hide individual buttons
- Lock positions or enable free movement
- Choose between solo and group spell variants
- Customizable health/mana bar colors on central sphere
- Minimap button for quick access

---

## 📦 Installation

1. Download the latest release
2. Extract to `World of Warcraft/Interface/AddOns/`
3. Ensure the folder is named `Arcanum`
4. Restart WoW or `/reload` if in-game
5. Type `/arcanum` or `/arca` to toggle the interface

---

## ⌨️ Commands

| Command | Description |
|---------|-------------|
| `/arcanum` or `/arca` | Toggle the main interface on/off |
| `/arca options` | Open configuration panel |

---

## ⚙️ Configuration

Access via `/arca options` or clicking the minimap button.

### **Tabs:**

1. **Messages** - Chat output preferences, display options, color customization
2. **Misc** - Evocation threshold, buff scaling, item deletion
3. **Reagent Auto-buy** - Set minimum reagent quantities, configure auto-purchase
4. **Graphical Settings** - Lock/unlock interface, rotation, scaling
5. **Buttons** - Show/hide buttons, reorder layout, configure click actions

---

## 🔧 Turtle WoW Specific Notes

### **High Elf (Alah'Thalas) Support**
- Full portal/teleport support for High Elf starting zone
- Automatic faction detection includes High Elves and Goblins
- Spell IDs updated for Turtle WoW spell variants

### **Atiesh Functionality**
- Detects equipped Atiesh staff
- Uses weapon slot (slot 16) for activation
- 60-second cooldown after use
- Smart UI: Shows Atiesh in group mode, Ice Armor in solo mode

### **Portal Cooldowns**
- Portals trigger 60-second cooldowns **only after successful cast**
- If cast is interrupted, no cooldown applied
- Visual countdown displays on each portal button

---

## 🙏 Credits

- **Original Authors**: Nausicaa (Medivh EU), Pepopo
- **Turtle WoW Updates**: Fayz
- **Inspired by**: Necrosis (Warlock addon)
- **Special Thanks**: Uliss, Solcarlus, Thémys (Medivh EU)

---

## 📜 License

This addon is fan-made content for World of Warcraft and is not affiliated with Blizzard Entertainment.

---

**Enjoy your adventures on Turtle WoW!** 🐢✨
