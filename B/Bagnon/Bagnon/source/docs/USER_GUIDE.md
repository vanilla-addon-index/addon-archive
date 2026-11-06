# Bagnon User Guide

Detailed configuration, shortcuts, and features for **Bagnon**.

---

## 1. Frame Controls & Customization

- **Opening Bagnon**: Press your standard bag key (`B`), click your backpack, or type `/bgn bags`.
- **Opening the Bank**: Visit a bank teller or type `/bgn bank` to view your bank anywhere (offline cached view when away from a bank NPC).
- **Customizing Appearance**:
  - Type `/bgn`, or right-click the title bar of the inventory or bank window, to open the settings. The Windows tab sets columns, item spacing, scale, opacity, layer, background colour, position lock, keeping on screen and bag order for each window; the General tab sets when the windows open by themselves and what the header shows.
  - Drag the title bar or the free slots counter to reposition the window on your screen. Positions are saved per character.
- **Toggling Individual Bags**: In the bag bar, Shift-click any bag icon to toggle the visibility of that specific container's slots within the unified grid.

---

## 2. Bag & Bank Sorting

- **Sorting Containers**: Click the broom icon in the top-right header (it can be hidden in the settings), use `/bgn sort`, or bind a key under the game Keybindings menu (`Bagnon`).
- **Sort Order**: Right-click the broom icon to toggle between packing items Top-Left to Bottom-Right or Bottom-Right to Top-Left.
- **Sort Exclusion (Bag Ignore)**:
  - You can keep the backpack out of a sort by Alt-clicking or Right-clicking its icon in the bag bar. ClassicAPI offers this for the backpack only.
  - An ignored container displays a status badge on its bag icon.
  - A sort leaves an excluded container as it is and arranges the rest.
- **Server Timing**: Sorting executes via server-side moves over several updates. The button triggers the request; allow the server a brief moment to finish moving items.

---

## 3. Searching

- Click the search box at the bottom of the inventory or bank window and type. Items that do not match are dimmed; the match covers names, types (Cloth, Bow) and equip slots (Head, Two-Hand). Escape clears the search, and so does closing the window. Search works on your own live bags, not on another character's cached view.

---

## 4. Item & Space Indicators

- **Live Free Slot Counter**: The header displays real-time free space (e.g. `24 / 96 Free`). Hovering over this badge reveals a tooltip breakdown showing free space container by container.
- **Weapon Enchant Badges**: Temporary weapon enchants (poisons, sharpening stones, oils) display an icon badge and duration indication directly on weapons in your bags.
- **Rarity Borders**: Items always feature color-coded rarity borders (Uncommon, Rare, Epic, Legendary). Specialized profession and ammo bags also feature distinct colored backgrounds.

---

## 5. Multi-Character & Suite Features

- **Cross-Character Alt Inventory**: Hover over any item to view a tooltip summary showing how many copies of that item are held across all your characters on the current realm.
- **Realm Gold Tracker**: Hover over the money display in the bottom-right corner to see total gold across all your characters on the realm.
- **GearRack Integration**:
  - Items belonging to saved GearRack sets display their set names directly on the item tooltip.
  - Trinkets with a pending GearRack equipment choice show their queued trinket slot on the tooltip.
