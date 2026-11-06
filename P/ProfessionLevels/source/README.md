# Profession Levels

## 🌿 A colorful profession tracker for Turtle WoW

<p>
  <span style="color:#f5c542;"><strong>Profession Levels</strong></span> is a lightweight Turtle WoW addon that helps you track the professions of the
  <strong>character you're currently playing</strong> with cleaner visuals, smarter display options, and quick access settings.
</p>

---

## ✨ Highlights

- 🎯 Track profession levels on your current character
- 📈 See real-time progress while you level professions
- 🔥 Show session gains like `225/300 (+7)`
- 🧮 Show remaining points to cap like `225/300 (75 left)`
- 🗂️ Group rows into `Primary`, `Secondary`, and `Class Skills`
- 🔀 Sort by default order, name, skill, or remaining points
- 🎨 Use progress-based color tiers for easier scanning
- 🪶 Switch between normal and compact layouts
- 🧭 Save frame position, visibility, sort mode, and display settings per character
- 🛠️ Toggle individual professions on or off in the settings panel
- 🗡️ Includes Rogue lockpicking support
- 📍 Minimap button for quick access

---

## 🖼️ What It Looks Like

The addon is designed to feel clean, readable, and a little more lively than the default skill list:

- Gold-tinted section headers separate profession groups
- Progress colors make low, mid, near-cap, and maxed skills easier to read
- Hovering a row shows a tooltip with current rank, session gain, and remaining points
- Compact mode keeps the footprint small while still showing useful values

---

## 🎮 Commands

| Command | What it does |
|---------|---------------|
| `/pl config` | Open the settings window |
| `/pl compact` | Switch to compact mode |
| `/pl normal` | Switch to normal mode |
| `/pl lock` | Lock frame position |
| `/pl unlock` | Unlock frame position |
| `/pl primary` | Show only primary professions |
| `/pl secondary` | Show only secondary skills |
| `/pl both` | Show both profession groups |
| `/pl show` | Show the frame |
| `/pl hide` | Hide the frame |
| `/pl remaining` | Toggle remaining-to-cap text |
| `/pl sort default` | Sort by in-game/default order |
| `/pl sort name` | Sort alphabetically |
| `/pl sort rank` | Sort by highest skill |
| `/pl sort remaining` | Sort by fewest points left to cap |
| `/pl reset` | Reset all settings |

---

## 🧰 Minimap Button

- 👆 **Click** - Toggle the main frame
- ⇧ **Shift+Click** - Open settings
- 🖱️ **Drag** - Reposition the minimap button

---

## 🚀 Installation

1. Clone or download this repository.
2. Place the `ProfessionLevels` folder in your World of Warcraft `AddOns` directory.
   - `World of Warcraft\Interface\AddOns\`
3. Restart World of Warcraft or reload the UI with `/reload`.

---

## 🧪 Usage

Once installed:

1. Log into a character on Turtle WoW.
2. Open the frame with the minimap button or `/pl show`.
3. Use `/pl config` to adjust display options.
4. Pick a sort mode if you want a different view of your skills.
5. Hover rows for extra detail while you level.

---

## 🧱 Features In Detail

### 🎯 Smart Progress Display

- Shows current rank and cap
- Shows session gains when you've made progress this login
- Shows remaining points to cap when there are no session gains to display

### 🗂️ Better Organization

- Separates professions into clear section headers
- Supports individual profession toggles
- Supports primary-only, secondary-only, or combined views

### 🪶 Flexible Layout

- Normal mode for full bars and detailed values
- Compact mode for a tighter footprint
- Saved visibility and frame position per character

### 🧠 Helpful Extras

- Tooltips with current rank, session gain, and remaining points
- Progress-based text and bar coloring
- Rogue lockpicking support

---

## 📁 Files

- `ProfessionLevels.lua` - Main addon code
- `ProfessionLevels.toc` - Addon table of contents file
- `README.md` - Documentation

---

## ✅ Requirements

- 🐢 Turtle WoW
- 💿 World of Warcraft client `1.12.x`

---

## 💬 Contributing

Ideas, tweaks, and quality-of-life improvements are welcome.

---

## 📜 License

This project is open source and available under the MIT License.

---

## 👤 Author

**gregdeichler**  
[GitHub Profile](https://github.com/gregdeichler)
