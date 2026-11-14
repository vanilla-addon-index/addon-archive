# AdeTalents

Talent data for World of Warcraft 1.12 addons (OctoWoW, Turtle WoW). Other addons use it to read:

- which talents the player has, and at what rank (read live from the game)
- what each talent does at each rank (static data for all 9 classes)

It needs no other mod. It only stores talent information, not spell data (proc chances, internal cooldowns, mana costs, cooldowns).

## Install

Put the folder in `Interface\AddOns\` and name it exactly `AdeTalents`
(the path must end in `AdeTalents\AdeTalents.toc`; a GitHub ZIP unpacks as `AdeTalents-main`, so rename it).

Addons that use it list it as a dependency:

```
## Dependencies: AdeTalents
```

## API

Talents are always looked up by their English name, on any client language: AdeTalents matches the talents
of your class by their position (tab, row, column), which is the same in every language. Right after login the client may not give the talents yet,
so check `IsReady()` or register a callback.

```lua
-- live ranks, read from the game
AdeTalents.IsReady()                -- talents have been read
AdeTalents.GetRank("Ironclad")      -- current rank, 0 if not learned
AdeTalents.GetMaxRank("Ironclad")   -- nil if the class has no such talent
AdeTalents.Has("Ironclad")          -- rank > 0
AdeTalents.GetInfo("Ironclad")      -- { tab, tabName, index, tier, column }
AdeTalents.GetLocalName("Ironclad") -- the name your client shows for it (same as the English name on an English client)
AdeTalents.GetSpellName("Holy Light") -- the spell name your client shows (the English name if unknown)
AdeTalents.RegisterCallback(fn)     -- fn() runs when talents were read and changed

-- what a talent does (current class only)
AdeTalents.GetEffect("Ironclad")
  -- nil if you have no points in it, otherwise:
  -- { rank = 2, max = 2, values = { 2 }, confidence = "exact",
  --   text = "Increases healing done by spells and effects by up to 2% of your Armor from items." }

AdeTalents.GetValues("Ironclad", 1) -- numbers at a given rank (default: current rank): { 1 }, "exact"
AdeTalents.GetText("Ironclad", 1)   -- description with the numbers of that rank
AdeTalents.GetData("Ironclad")      -- raw data row
```

`values[i]` is the number written as `{i}` in the description. `GetValues`, `GetText` and `GetEffect`
return `nil` for rank 0, a rank above the maximum, or a talent without data.

### Confidence

| Value | Meaning |
|---|---|
| `exact` | Read from the talent tooltip with every rank shown, or the talent has only one rank |
| `assumed` | A number was guessed or fixed by hand, do not rely on it |

474 of 476 talents are `exact`. The 2 `assumed` ones are the mana number of Wand Specialization (Mage and Priest),
which depends on the player level and is stored as a fixed value. Ignore it.

On a Russian client the talent tooltips are fixed: English spell names (Flash of Light, Holy Shock, Rip...) are shown in Russian,
and the descriptions that the game has wrong or too long are replaced by our own text. Only spells that talent texts mention are translated.

## Commands

| Command | What it does |
|---|---|
| `/adet list` | Lists the talents you have points in |
| `/adet effect <talent>` | What the talent does at your current rank (English name or the name your client shows) |
| `/adet check` | Russian client: lists English words that are still left in the tooltips of your class |
| `/adet dump` | Saves the tooltip text of every talent of this class to the saved variables file |

`/adetalents` works as an alias.

## Notes

- Data is from https://octowow.st/db/ 12.11.2026
- Shaman talents are unchecked on the Russian client.
- Code must stay Lua 5.0: no `#` operator, no `select`, no `string.gmatch`.
