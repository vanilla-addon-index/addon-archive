# ⚒️ ButtonForge Classic 

**ButtonForge Classic** is a recreation of the original **ButtonForge** addon for **Vanilla World of Warcraft 1.12**, designed for **Turtle WoW** and other Vanilla-based servers.

Create additional fully customizable action bars while keeping the original Vanilla look and feel.

---

## 📥 Download & Installation

1. Click **Code → Download ZIP** on GitHub.
2. Extract the downloaded archive.
3. Rename the folder:

`ButtonForgeClassic-main`

to:

`ButtonForgeClassic`

4. Move the folder into:

`World of Warcraft\Interface\AddOns\`

The final structure should look like:

```text
Interface
└── AddOns
    └── ButtonForgeClassic
        ├── ButtonForgeClassic.toc
        ├── Core.lua
        ├── Bar.lua
        ├── Button.lua
        └── ...
```

Restart the game after installation.

---

# ✨ Features

## 🎯 Action Bars

- Create multiple fully customizable action bars
- Freely move and position bars anywhere on the screen
- Adjustable rows and columns
- Adjustable button scale
- Lock or unlock individual bars
- Optional bar backgrounds
- Automatically hide unused buttons outside configuration mode
- Mouseover mode with configurable fade-in and fade-out
- Native Vanilla-style appearance

---

## 🖱️ Drag & Drop

- Drag spells directly from the spellbook
- Drag items directly from your bags
- Drag macros from the macro window
- Move actions between ButtonForge buttons
- Swap actions between occupied buttons
- Drag actions between ButtonForge and Blizzard action bars
- Empty drop slots automatically appear when needed

---

## ⌨️ Keybindings

- Built-in keybinding mode
- Assign keys directly to ButtonForge buttons
- Keybindings stay attached to the physical button position
- Keybinds are saved with ButtonForge
- Safe runtime bindings without modifying your normal WoW keybinding file

---

## 🖥️ Configuration

ButtonForge can be configured through its built-in interface.

Use:

`/bf`

or:

`/bfc`

You can also use the **ButtonForge minimap button** to access the configuration menu.

---

## 🛠️ Commands

### Create a new bar

`/bf new`

### Delete the selected bar

`/bf delete`

### Toggle configuration mode

`/bf config`

### Toggle keybinding mode

`/bf keybind`

### Set columns

`/bf cols 6`

### Set rows

`/bf rows 2`

### Set columns and rows

`/bf size 6 2`

### Change bar scale

`/bf scale 1.2`

### Lock the active bar

`/bf lock`

### Unlock the active bar

`/bf unlock`

### Toggle active bar background

`/bf bg`

### Toggle all bar backgrounds

`/bf bg all`

### Toggle empty button slots

`/bf grid`

### Reset ButtonForge settings

`/bf reset`

---

## 👁️ Mouseover Mode

Bars can automatically fade out when they are not being used.

When mouseover mode is enabled:

- Bars fade in when you move the mouse over them
- Bars fade out again after leaving them
- The fade delay can be configured
- Bars remain fully visible while configuring, keybinding, or dragging actions

This allows you to keep additional action bars available without permanently filling the screen.

---

## 💾 Per-Character Settings

ButtonForge stores its bar layouts, settings, and keybindings **per character**.

Each character can therefore have its own:

- Action bars
- Positions
- Sizes
- Layouts
- Mouseover settings
- Keybindings

---

## ⚡ Performance

**ButtonForgeClassic** is designed to remain lightweight.

It uses the original Vanilla UI systems wherever possible instead of replacing the complete action bar system with a large framework.

The goal is simple:

> **More action bars without turning the addon into a full UI replacement.**

---

## 🎮 Compatibility

Designed for:

- **World of Warcraft 1.12**
- **Turtle WoW**
- Other Vanilla-based 1.12 clients

**No external addon dependency is required.**

---

## ⚠️ Important

ButtonForge uses available **Vanilla action slots** internally.

Because Vanilla WoW has a limited number of usable action slots, the total number of ButtonForge buttons that can be active at the same time is limited by the client.

---

## 🐛 Bug Reports & Feedback

If you find a bug or something does not behave correctly, please report it on GitHub.

When reporting an issue, please include:

- What happened
- What you expected to happen
- Which Vanilla server/client you are using
- Steps to reproduce the problem

**Suggestions, testing and feedback are always welcome! ❤️**

---

## ❤️ Credits

Inspired by the original **ButtonForge** addon.

Recreated and adapted for **Vanilla WoW 1.12** with a focus on **compatibility, simplicity and performance**.

---

## 🔗 GitHub

**https://github.com/Wurmschwanz/ButtonForge-Classic-Reforged**
