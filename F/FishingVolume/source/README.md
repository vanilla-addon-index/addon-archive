# FishingVolume (WoW 1.12.1)

**FishingVolume** is a utility for WoW 1.12.1 designed to automatically handle your volume levels and adds a few quality-of-life shortcuts to make long fishing sessions less of a chore.

---

<table>
<tr>
<td><img width="502" height="830" alt="image" src="https://github.com/user-attachments/assets/0b6c9a8c-185c-4089-b83f-aaf6b9c4259c" /></td>
<td><img width="439" height="578" alt="image" src="https://github.com/user-attachments/assets/f021e9a0-ac33-4ec6-b734-0110359e5959" /></td>
</tr>
</table>

<br>

<table>
<tr>
<td><img width="308" height="173" alt="image" src="https://github.com/user-attachments/assets/f2fd7aea-78eb-4854-8133-2ceed9dc02c1" /></td>
<td><img width="304" height="174" alt="image" src="https://github.com/user-attachments/assets/5e6ce63f-1629-4907-bf2c-3b6a258608df" /></td>
</tr>
</table>



---

## Features

* **Auto-Boost**: When you start fishing, the addon kicks your Sound Volume up to your preferred level.
* **Auto-Restore**: As soon as you catch a fish or stop the cast, it puts the volume back exactly where it was.
* **Mute Delay**: If you have high latency, set a delay so the volume stays up for a few seconds after the cast ends to make sure you hear the catch.
* **Click-to-Fish Overlay**: A large, transparent button appears on your screen after a catch. Left-click to cast immediately, right-click to dismiss. Disappears automatically after 10 seconds.
* **Quick Gear Swap**: Dedicated buttons to equip your fishing pole and swap back to your weapons. Remembers your gear automatically.
* **Smart Lures**: One-click to scan your bags for the best available lure and apply it to your pole.
* **Session Stats**: Tracks how many fish and chests/trunks you've caught since you logged in.
* **Lifetime Totals**: Keeps a permanent record of your character's total catches.

---

## Installation

1. Download this repository and move the `FishingVolume` folder into your `Interface/AddOns/` directory.
2. The addon includes a cleaner, louder splash sound file. To use it, move the `Sound` folder provided in this download into your main WoW game folder (the one containing `WoW.exe`).

   Correct path: `WoW/Sound/Spells/FishingBobberSplash.wav`

   **Note:** This doesn't replace your game files — it tells the game to use this file instead of the default one.

---

## Commands

* **`/fv`**: Opens the main settings and stats window.
* **`/fv mini`**: Toggles the compact, draggable utility bar.
* **`/fv zones`**: Opens the fishing zones skill browser.
* **`/fv reset`**: Wipes your lifetime stats (requires a second confirmation within 10 seconds).

---

## Helpful Macros

**Equip Pole and Fish**

Works like the Fishing button from the addon, but as an in-game macro.
```lua
/run local n=FishingVolume.GetItemName(GetInventoryItemLink("player",16)) if not (n and string.find(n,"Pole")) then FishingVolume:EquipPole() else CastSpellByName("Fishing") end
```
<br>

**Equip Weapons**

Works like the Weapons button from the addon, but as an in-game macro.
```lua
/run FishingVolume:EquipWeapons()
```

---

Credits

Built specifically for the 1.12.1 WoW client.
Happy fishing!
