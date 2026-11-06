# HasteDisplay

Displays your current haste percentage with color-coded consumable indicators.

![HasteDisplay Screenshot](image.png)

## Requirements

- Latest version of [nampower](https://gitea.com/avitasia/nampower) and its dependencies.

## Features

- Lightweight addon that updates haste when appropriate
- Draggable frame with saved position
- Color-coded consumable indicators:
  - **Juju Flurry** (3% multiplicative)
  - **Potion of Quickness** (5% multiplicative)

## Color Coding

- **Green** - Using the consumable will keep you below 58% haste (Above this haste value is when the cast time of Arcane Rupture goes below GCD)
- **Yellow** - Using the consumable will put you between 58-100% haste  
- **Red** - Using the consumable will exceed 100% haste

## Commands

`/haste` or `/hastedisplay` - Toggle visibility
