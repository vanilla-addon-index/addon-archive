# Action Bars

ConsoleExperienceClassic provides a gamepad-style action bar layout designed for controller use.

## Layout

The action bar uses a "star" layout with two groups of buttons:

```
    [LT]                              [RT]
[LB] 🎮 [RB]                      [RB] 🎮 [LB]
    [A]                               [A]
    
 Left Star                        Right Star
(D-Pad + Triggers)            (Face Buttons + Triggers)
```

### Button Mapping

**Left Star (D-Pad):**
- Up, Down, Left, Right
- With LT modifier
- With LB modifier

**Right Star (Face Buttons):**
- A, B, X, Y (A defaults to Jump via System Bindings)
- With RT modifier  
- With RB modifier

> **Note:** Any button slot can be assigned to a System Binding (like Jump, Auto Run, etc.) instead of an action bar slot. See [Keybindings](../Keybindings.md) for details.

## Appearance Styles

### Classic
Traditional button style with clear borders and standard textures.

### Modern
Cleaner, more minimalist appearance.

## Customization

### Size & Position
- **Button Size**: 20-80 pixels
- **Padding**: Space between buttons in each star
- **Star Padding**: Distance between left and right star groups
- **X/Y Offset**: Position adjustment from bottom center
- **Scale**: Overall size multiplier

### Changing Layout

1. Open config with `/ce`
2. Go to "Action Bars" section
3. Adjust sliders/values
4. Changes apply immediately

## Button Prompts

The addon shows controller button icons based on your selected controller type:
- **Xbox**: A, B, X, Y, LB, RB, LT, RT
- **PlayStation**: Cross, Circle, Square, Triangle, L1, R1, L2, R2

Change this in Interface settings.

## Side Action Bars (Touch Screen)

Two optional vertical action bars designed for touch screen input. These bars can be tapped directly on a touch-enabled display or assigned system bindings for keyboard/controller use.

### Position
- **Left Bar**: Left edge of screen, vertically centered
- **Right Bar**: Right edge of screen, vertically centered

### Configuration

| Setting | Description | Default |
|---------|-------------|---------|
| Enable Left Side Bar | Show left touch bar | Off |
| Enable Right Side Bar | Show right touch bar | Off |
| Left Buttons (1-5) | Number of buttons on left bar | 3 |
| Right Buttons (1-5) | Number of buttons on right bar | 3 |

### Action Slots
- Left bar uses action slots 41-45
- Right bar uses action slots 46-50

### Bindings

Side bar slots can be assigned system bindings (like Jump, Auto Run, etc.) in the **Bindings** section of `/ce`:

- **Left Side Bar**: Slots 41-45 (labeled as "Left 1" through "Left 5")
- **Right Side Bar**: Slots 46-50 (labeled as "Right 1" through "Right 5")

Each slot can be set to:
- **None (Action Bar)** - Uses the action bar slot normally (click/touch to activate)
- **A system action** - Binds directly to that WoW action (can be keybound)

> **Note:** Side bar bindings only appear in the Bindings config when the corresponding side bar is enabled and has at least one button configured.

### Features
- Same visual style as main action bars (button size, padding, scale)
- Supports drag & drop (Shift+click to pick up)
- Full functionality: cooldowns, range checking, usability colors
- Appears in Placement Frame when enabled for easy setup
- Can be assigned system bindings for keyboard/controller access

### Use Cases
- Touch screen devices (tablets, touch monitors)
- Frequently used abilities that don't need keybinds
- Consumables, mounts, or utility spells
- Secondary rotation abilities
- System actions (Jump, Auto Run, etc.) when assigned via bindings

## Druid Forms

Druids automatically get form-specific action bars that switch based on your current form:

| Form | Bonus Bar | Action Slots |
|------|-----------|--------------|
| Caster Form | None | 1-10 |
| Cat Form | 1 | 73-82 |
| Aquatic Form | 2 | 85-94 |
| Bear Form | 3 | 97-106 |
| Travel Form | 4 | 109-118 |
| Moonkin Form | 5 | 121-130 |

### Druid Stealth Feature

When enabled in the Action Bars config, druids in cat form will automatically use the travel form action bar (slots 109-118) when prowl/stealth is active. This allows you to have separate keybinds for prowl abilities.

**To enable:**
1. Open config with `/ce`
2. Go to "Action Bars" section
3. Check "Use travel form bar in prowl" (only visible to druids)

> **Note:** This feature is only available to druids and only appears in the config UI when playing a druid character.

## Tips

- Use the placement mode to fine-tune button positions
- The right star typically holds your most-used abilities
- Modifier buttons (triggers/bumpers) give you 3x the slots per star
- Use System Bindings for common actions like Jump, Auto Run, etc.
- Side bars share size/padding settings with main action bars
- Druids: Use the placement frame to set up abilities for each form
- Druids: Enable stealth feature to have separate prowl keybinds