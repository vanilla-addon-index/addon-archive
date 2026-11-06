# AdePet

Lightweight hunter pet addon for OctoWoW.

## Features

- Small movable window: `Pet_Name: Loyalty_Level (Loyalty_Name)`
- Window size follows the text length
- "Pet is hungry" warning under the name when the pet is no longer Happy
  (yellow = Content, red = Unhappy)
- Hunger is re-checked every 15 seconds (configurable), after combat, on pet
  change and when feeding ends
- At max loyalty (Level 6) the window is hidden unless the pet is hungry
- Hunters only
- Makes no pet queries while you are AFK (keeps the AFK flag from flickering)

## Installation

1. Download the latest `AdePet-v1.0.2.zip` from the Releases page.
2. Extract it so the folder `AdePet` sits directly in
   `<WoW folder>\Interface\AddOns\` (the path must be
   `Interface\AddOns\AdePet\AdePet.toc`), remove -main from folder name.
3. Enable AdePet in the AddOns list on the character select screen.


## Commands

| Command | Description |
| --- | --- |
| `/hungry X` | Set the hunger check interval to X seconds (minimum 1, default 15) |
| `/hungry` | Show the current interval |
| `/adepet lock` | Lock the window position |
| `/adepet unlock` | Unlock the window so it can be dragged |
| `/adepet reset` | Reset the window position |

`/adepet debug` prints the raw pet happiness and loyalty values (useful for bug reports).
`/ap` works as a short alias for `/adepet`. Drag the window with the left mouse
button; the position and interval are saved per character.

## Notes

- Hunger detection reads the pet's happiness level (Happy / Content / Unhappy).
  The 1.12 API does not expose a numeric satiety value, so there is no bar.
- Feeding is detected through the "Feed Pet Effect" buff. The check matches the
  English buff name (this check will not work if using any other language).
- Not checking pet state while player have "afk" status. Can cause stange 
  flicker with afk/nonafk status shows in chat, but no longer keeps you online,
  which can't consider as boting, and I'm to lazy to looking which cause it.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
