# Keybindings

ConsoleExperienceClassic uses custom keybindings for controller support.

## Default Bindings

### Action Bar - Right Star (Face Buttons)
| Button | Key | Default Action |
|--------|-----|----------------|
| A | 1 | Jump (System Binding) |
| X | 2 | Action Slot 2 |
| Y | 3 | Action Slot 3 |
| B | 4 | Action Slot 4 |

### Action Bar - Left Star (D-Pad)
| Button | Key | Default Action |
|--------|-----|----------------|
| D-Down | 5 | Action Slot 5 |
| D-Left | 6 | Action Slot 6 |
| D-Up | 7 | Action Slot 7 |
| D-Right | 8 | Action Slot 8 |

### Bumpers
| Button | Key | Default Action |
|--------|-----|----------------|
| RB | 9 | Action Slot 9 |
| LB | 0 | Action Slot 10 |

### With LT Modifier (Shift)
| Button | Key | Default Action |
|--------|-----|----------------|
| LT + A | Shift-1 | Action Slot 11 |
| LT + X | Shift-2 | Action Slot 12 |
| LT + Y | Shift-3 | Action Slot 13 |
| LT + B | Shift-4 | Action Slot 14 |
| LT + D-Down | Shift-5 | Action Slot 15 |
| LT + D-Left | Shift-6 | Action Slot 16 |
| LT + D-Up | Shift-7 | Action Slot 17 |
| LT + D-Right | Shift-8 | Action Slot 18 |
| LT + RB | Shift-9 | Action Slot 19 |
| LT + LB | Shift-0 | Action Slot 20 |

### With RT Modifier (Ctrl)
| Button | Key | Default Action |
|--------|-----|----------------|
| RT + A | Ctrl-1 | Action Slot 21 |
| RT + X | Ctrl-2 | Action Slot 22 |
| RT + Y | Ctrl-3 | Action Slot 23 |
| RT + B | Ctrl-4 | Action Slot 24 |
| RT + D-Down | Ctrl-5 | Action Slot 25 |
| RT + D-Left | Ctrl-6 | Action Slot 26 |
| RT + D-Up | Ctrl-7 | Action Slot 27 |
| RT + D-Right | Ctrl-8 | Action Slot 28 |
| RT + RB | Ctrl-9 | Action Slot 29 |
| RT + LB | Ctrl-0 | Interact (System Binding) |

### With LT+RT Modifier (Ctrl+Shift)
| Button | Key | Default Action |
|--------|-----|----------------|
| LT + RT + A | Ctrl-Shift-1 | Action Slot 31 |
| LT + RT + X | Ctrl-Shift-2 | Action Slot 32 |
| LT + RT + Y | Ctrl-Shift-3 | Action Slot 33 |
| LT + RT + B | Ctrl-Shift-4 | Action Slot 34 |
| LT + RT + D-Down | Ctrl-Shift-5 | Action Slot 35 |
| LT + RT + D-Left | Ctrl-Shift-6 | Action Slot 36 |
| LT + RT + D-Up | Ctrl-Shift-7 | Action Slot 37 |
| LT + RT + D-Right | Ctrl-Shift-8 | Action Slot 38 |
| LT + RT + RB | Ctrl-Shift-9 | Action Slot 39 |
| LT + RT + LB | Ctrl-Shift-0 | Action Slot 40 |

### Navigation
| Button | Action |
|--------|--------|
| D-Pad | Move cursor / Navigate menus |
| A | Select / Confirm |
| B | Back / Cancel |
| Start | Open radial menu |
| Select | Toggle map |

## System Bindings

System Bindings allow you to assign controller buttons to system actions (like Jump, Auto Run, etc.) instead of action bar slots. Configure these in the **Bindings** section of `/ce`.

![Bindings Configuration](images/bindings.png)

### Side Bar Bindings

Side bar slots (touch screen bars) can also be assigned system bindings:

- **Left Side Bar** (slots 41-45): Labeled as "Left 1" through "Left 5"
- **Right Side Bar** (slots 46-50): Labeled as "Right 1" through "Right 5"

These bindings only appear in the config when the corresponding side bar is enabled and has at least one button configured. Side bar slots can be:
- Assigned system actions (like Jump, Auto Run, etc.)
- Left as action bar slots (click/touch to activate)
- Keybound in the standard WoW keybindings menu (Escape → Key Bindings → ConsoleExperience → CELEFTBAR / CERIGHTBAR)

### Available System Actions

| Category | Action | Description |
|----------|--------|-------------|
| **Custom** | Interact | Interact with target (requires Interact.dll) |
| **Movement** | Jump | Jump |
| | Toggle Auto Run | Toggle auto-run on/off |
| | Sit/Stand | Sit down or stand up |
| **Targeting** | Target Nearest Enemy | Target nearest hostile |
| | Target Previous Enemy | Target previous hostile |
| | Target Nearest Friend | Target nearest friendly |
| | Assist Target | Assist current target |
| | Target Pet | Target your pet |
| | Clear Target | Clear current target |
| **Interface** | Toggle Map | Open/close world map |
| | Open All Bags | Open all bags |
| | Toggle Character | Open character panel |
| | Toggle Spellbook | Open spellbook |
| | Toggle Talents | Open talent panel |
| **Camera** | Zoom In | Zoom camera in |
| | Zoom Out | Zoom camera out |
| **Combat** | Attack | Start auto-attack |
| | Pet Attack | Command pet to attack |
| | Stop Attack | Stop attacking |

### Default System Bindings

| Button | System Action |
|--------|---------------|
| A (Slot 1) | Jump |
| RT + LB (Slot 30) | Interact |

## Configuring Keybindings

### In-Game Key Bindings Menu
1. Press Escape → Key Bindings
2. Scroll to "ConsoleExperience" section
3. Set your preferred keys

### System Bindings Configuration
1. Type `/ce` to open configuration
2. Go to the **Bindings** tab
3. For each controller button slot, select either:
   - **None (Action Bar)** - Uses the action bar slot normally
   - **A system action** - Binds directly to that WoW action

## Controller Setup

### Xbox Controller
The addon is designed for Xbox-style controllers:
- A/B/X/Y face buttons
- LB/RB bumpers
- LT/RT triggers
- D-Pad
- Start/Select

### PlayStation Controller
Select "PlayStation" in Interface settings to show PS button icons:
- Cross/Circle/Square/Triangle
- L1/R1
- L2/R2
- D-Pad
- Options/Share

### Mapping Physical Controllers

Use external software to map your controller:

**Windows:**
- Xbox controllers work natively
- DS4Windows for PlayStation controllers
- JoyToKey or AntiMicro for custom mapping

**Third-Party Tools:**
- ConsolePort addon (separate addon)
- reWASD
- Steam Input

## Tips

- Triggers (LT/RT) and bumpers (LB/RB) act as modifiers
- Hold the modifier, then press the main button
- Practice the button combinations in a safe area
- Customize bindings if the defaults don't feel right
