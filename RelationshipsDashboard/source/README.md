<img src="https://i.postimg.cc/2SkTz66N/l.gif"/>ㅤ<img src="https://i.postimg.cc/FsgD5c9R/ll.gif"/>



# Relationships Dashboard

A lightweight Character Statistics Dashboard for **OctoWoW** that adds an expandable information panel to the Character Window.

RelationshipsDashboard provides detailed character statistics, GearScore, average item level, durability tracking, repair cost estimation, combat attributes, resistances, and inspect support—all in a clean, Vanilla-style interface.

---

## Features

### Character Dashboard

* Integrated panel beside the default Character Window
* Clean Vanilla-inspired UI
* Automatic class-specific layout
* Scrollable statistics panel
* Alternating row styling for readability

### Gear & Equipment

* GearScore calculation
* Average Item Level
* Equipment analysis
* Inspect support for other players
* Large built-in Vanilla/Turtle item level database

### Character Statistics

#### General

* Health
* Mana / Energy / Rage
* Armor
* Movement Speed
* Estimated Equipment Durability
* Estimated Repair Cost

#### Attributes

* Strength
* Agility
* Stamina
* Intellect
* Spirit

#### Offensive Stats

* Melee Damage
* Attack Power
* Weapon Speed
* Weapon DPS
* Weapon Skill
* Hit Chance
* Critical Strike Chance

#### Ranged Stats

(Shown only for applicable classes)

* Ranged Attack Power
* Ranged Damage
* Ranged Speed
* Ranged Critical Chance

#### Spell Statistics

(Shown only for mana-using classes)

* Spell Power
* Healing Power
* Spell Hit
* Spell Critical Chance
* Mana Regeneration

#### Defensive Stats

* Defense Skill
* Dodge
* Parry
* Block
* Total Avoidance

#### Resistances

* Arcane
* Fire
* Frost
* Nature
* Shadow

---

## Smart Class Layout

Relationships Dashboard automatically hides statistics that are not relevant to your class.

Examples:

* Warriors won't see caster-only statistics.
* Mages won't see melee weapon information.
* Druids display both Mana and their current shapeshift resource when appropriate.
* Shield-only statistics are only shown for classes that can use shields.

This keeps the panel compact and easy to read.

---

## Durability Tracking

Turtle WoW often do not expose durability information unless interacting with a repair NPC.

Relationships Dashboard includes its own durability tracking system that:

* Tracks durability across sessions
* Estimates durability loss from deaths and combat
* Detects repairs automatically
* Restores accurate values when game data becomes available
* Ignores battleground durability loss where appropriate
* Supports spirit healer durability penalties

This allows the durability display to remain useful even when Blizzard API functions are unavailable.

---

## Repair Cost Estimation

The addon includes a dynamic repair cost estimator that:

* Learns repair values over time
* Automatically calibrates itself using real repair costs
* Provides reliable repair estimates away from vendors
* Updates using actual merchant repair information whenever available

---

## Inspect Support

When inspecting another player, the dashboard automatically switches to display:

* GearScore
* Average Item Level
* Estimated Equipment statistics
* Estimated Relevant character attributes

without replacing or modifying Blizzard's Inspect Window.

---

## Installation

1. Download the latest release.
2. Extract the folder.
3. Place the `RelationshipsDashboard` folder into:

```
World of Warcraft\Interface\AddOns\
```

4. Restart the game or reload the UI.

---
