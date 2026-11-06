# ArcaneSurgeWarning

**Arcane Surge Warning** is a **World of Warcraft 1.12 addon** that provides a **visual tracker** for the Arcane Surge proc. It features an **icon, cooldown bar, and surge duration bar** to help mages track when Arcane Surge is available and its duration.

## Features
✅ **Automatic Action Slot Detection** – Finds the Arcane Surge ability on the action bar.  
✅ **Cooldown Bar** – Displays the spell cooldown progress.  
✅ **Surge Duration Bar** – Tracks the 4-second duration of Arcane Surge.  
✅ **Real-Time Usability Detection** – Icon updates based on spell availability.  
✅ **Movable UI** – Shift + Drag to reposition the tracker.  
✅ **Slash Command** – `/lockicon` to lock/unlock the icon position.

---

## Installation

1. Download the addon files.
2. Place the `ArcaneSurgeWarning` folder into your World of Warcraft `Interface/AddOns` directory.
3. Make sure the addon is enabled in the character selection screen by clicking "AddOns" and checking `ArcaneSurgeWarning`.

---

## How It Works
### Icon Behavior
- The **Arcane Surge icon** appears **only when the spell is available**.
- The **icon is hidden** if Arcane Surge is not procced or usable.

### Bars
- **Cooldown Bar (Blue)** – Shows the cooldown time left before Arcane Surge can be triggered again.
- **Surge Bar (Red)** – Tracks the **4-second active duration** of Arcane Surge when triggered.

### Activation Triggers
- Arcane Surge **procs on a spell resist**.
- The addon **listens for resists** and automatically updates.
- If **Arcane Surge is used**, the tracker resets.

---

## Commands
| Command        | Function                           |
|---------------|------------------------------------|
| `/lockicon`   | Lock/unlock the position of the icon. |

---

## How It Detects Arcane Surge
- **Finds the correct action bar slot** based on the Arcane Surge spell texture (`Interface\\Icons\\INV_Enchant_EssenceMysticalLarge`).
- Uses **`IsUsableAction(actionSlot)`** to determine if the spell is clickable (procced).
- Listens for **`CHAT_MSG_SPELL_SELF_DAMAGE`** to detect when **your spells are resisted** (which procs Arcane Surge).
- Checks for **`COMBAT_TEXT_UPDATE`** with `"SPELL_ACTIVE"` to confirm activation.
- Tracks **`GetActionCooldown(actionSlot)`** to update cooldown progress.

---

## Customization
If Arcane Surge is **not automatically detected**, manually set the **action bar slot** inside the Lua file:
```lua
local actionSlot = 12 -- Change this to your Arcane Surge slot
```

---

## Known Issues & Future Improvements
- **❗ Icon doesn't track activation if the spell is not placed on the action bar.**
- **🔧 Improve detection for multiple spell resists triggering Arcane Surge.**
- **⚙️ Add an option to customize bar colors and sizes.**

---
