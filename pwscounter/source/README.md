# PWSCounter

PWSCounter and addon for vanilla WoW (1.12) which allows to track how many `Power Word: Shield`s are being cast in a raid fight.

## How does it work

`/pwsc` to show PWSCounter's window.

The addon scan combat log for events and will set the following console variables:

```ini
CombatLogRangeParty = 200
CombatLogRangePartyPet = 200
CombatLogRangeFriendlyPlayers = 200
CombatLogRangeFriendlyPlayersPets = 200
CombatLogRangeCreature = 200
```

PWSCounter displays 2 counters:

- Currently active shields count
- Total casted shields count

As both counters relay on combat log (scanning buffs is too hard on performances for raids) any shield being cast outside combat log range will not be counted, players/pets losing the shield outside the combat log range will leave an extra shield lingering in the active shields count.

## About Auto Start/Stop functionality

When Auto Start/Stop is active, PWSCounter will start/stop counting shields when entering/leaving combat. Optionally you can register NPCs names; when a registered NPC name appears in the combat log (at the moment not all events are scanned for simplicity) PWSCounter will start regardless of the player being in combat and will stay active until the NPC's death is registered in the combat log.

## Requirements

PWSCounter requires EmeraldFramework to work https://gitlab.com/woblight/EmeraldFramework

## About PWSCounter and further enhancements

PWSCounter was born out of a (free) request, anyone wishing for additional functionalities or other improvements can open an issue or come say hi on my Discord https://discord.gg/gadedCq

## Thanks

Lazermon and Lezonta

# Author

WobLight
