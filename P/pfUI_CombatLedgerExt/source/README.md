# pfUI_CombatLedgerExt (CombatLedger pfUI Threat)

Threat glow, threat-percentage badge, and an aggro warning (sound + screen-edge
flash) for the **pfUI target frame**, powered by **CombatLedger**'s threat data.
Behaves like TWThreat's pfUI integration, without needing TWThreat.

Client: WoW 1.12 (Turtle WoW). Tested design target: pfUI (brues-code fork),
CombatLedger, Nampower, optionally pfUI-eliteoverlay.

## Requirements

| Addon | Needed | Notes |
|---|---|---|
| CombatLedger | yes | folder must be named exactly `CombatLedger` |
| Nampower | yes (for CombatLedger) | |
| pfUI | for glow/% | the warning sound + edge flash work without it |
| pfUI-eliteoverlay | optional | badge automatically moves away from the dragon |
| SuperWoW | **yes, for the aggro ring and edge dots** | nameplate GUIDs, unit positions |
| UnitXP SP3 | **yes, for the aggro ring and edge dots** | exact distance |

> **Important:** the aggro ring and the off-screen edge dots need **both SuperWoW and
> UnitXP SP3** to work properly. Without SuperWoW neither appears. Without UnitXP SP3
> the ring only moves in coarse steps and the edge dots are turned off.

## Install

1. Copy the `pfUI_CombatLedgerExt` folder to `Interface\AddOns\`.
2. Make sure the folder names are exactly `CombatLedger` (not `CombatLedger-main`),
   and `pfUI-eliteoverlay` (not `-master`) if you use it.
3. Restart the game (or `/reload`).

## What you get

- **Target glow** - a glow around the pfUI target frame, green -> yellow -> red
  as your threat rises relative to the tank (same colour scale as TWThreat).
- **Threat % badge** - your threat as a percentage of the tank's, in a dark box
  with a threat-coloured border, above (or below) the target frame.
  The badge sits above pfUI-eliteoverlay's dragon and, in `auto` side mode,
  moves to the opposite side of the frame from the dragon so it is never covered.
- **Aggro warning** - when you are **not** the tank and your threat reaches the
  warning threshold (default **85%**):
  - a sound plays once
  - the screen edges pulse red (stronger the closer you get to 100%)
  The warning re-arms after your threat drops 10 points below the threshold, and
  resets on target change or leaving combat. If you are the one holding aggro,
  no warning fires.

- **Aggro ring on nameplates** - every hostile (red) nameplate gets a dotted line
  along its bottom edge as you approach its estimated aggro range. The middle dot
  lights 15 yards before the edge, and the line grows out to both sides until it
  spans the whole bottom of the plate. Each new dot is redder (amber, orange, red)
  and the dots grow and brighten as it fills. When it is complete (you are inside
  the radius, or the mob targets you) every dot turns red and pulses slowly, and
  the name is tinted with it.
  - Radius estimate: about 20 yd at equal level, 1 yd more or less per level of
    difference, 5 to 45 yd. Real aggro ranges vary a little per mob.
  - **Requires SuperWoW and UnitXP SP3** to work properly (see Requirements).
  - Neutral mobs, players and corpses get no ring. Works with pfUI or default
    nameplates, and does not need CombatLedger data.

- **Off-screen edge dots** - when a hostile mob you are approaching is out of
  view (it has no visible nameplate), the same dotted line appears on the screen
  border at the point nearest the mob's direction: bottom for behind, the sides
  for left and right, and the corners for diagonals. The top edge stays empty,
  because a mob in front of you is already on screen. Near a
  corner the line turns diagonally across it, so it stays one continuous line.
  Each line is as long as a nameplate, grows from its middle outwards with the
  same colours, and pulses red once you are inside the mob's aggro radius or it
  targets you. With several mobs, every line is shown separately, pushed apart
  along the border if they would overlap. Up to 6 mobs are shown at once, the
  ones closest to pulling first.
  - **Requires SuperWoW and UnitXP SP3**. Off without UnitXP SP3.
  - Only mobs you have already seen (on a nameplate or as your target) are
    tracked, so keep enemy nameplates turned on. A mob you never had on screen
    cannot be detected.
  - If the mob's nameplate exists but sits outside the screen, the mark is
    placed at the plate's real position, so it is exact.
  - A mob with no nameplate at all (too far away for one, or behind the
    camera) is placed by estimate, from the way your character faces. That
    estimate is rougher, and it is off while you swing the camera away from
    your facing (holding the left mouse button).
    `/clpf ring where` prints the direction of your target.
  - Brightness follows `/clpf strength`.

### Why an edge pulse?
A red pulse at the screen border is visible in peripheral vision without covering
the middle of the screen, where you are watching boss mechanics. If it is still
too much, use `/clpf flash once` (a single 1.5s fade per crossing) or lower
`/clpf strength`.

## Commands (`/clpf`)

| Command | Effect |
|---|---|
| `/clpf glow` | toggle the glow |
| `/clpf top` / `bottom` / `off` | percentage position, or hide it |
| `/clpf side auto / left / right` | badge side. `auto` avoids the elite dragon |
| `/clpf badge` | toggle the dark box behind the % |
| `/clpf warn <20-99>` | aggro warning threshold in % (default 85) |
| `/clpf sound [name / path / off]` | set and preview the warning sound (see below) |
| `/clpf flash pulse / once / off` | screen-edge flash mode |
| `/clpf strength <0.1-1.0>` | screen-edge flash intensity (default 0.6) |
| `/clpf flip` | flip edge gradient if the fade looks inverted |
| `/clpf poll` | toggle forced threat polling (see below) |
| `/clpf ring [on / off]` | toggle the aggro ring on nameplates |
| `/clpf ring <3-40>` | yards before the aggro edge where the ring starts (default 15) |
| `/clpf ring edge [on / off]` | toggle the off-screen edge dots |
| `/clpf ring where` | print which direction your target is in, as the edge dots see it |
| `/clpf test` | simulate 95% threat for 8 seconds (fires sound + flash) |
| `/clpf debug` | print state: frames found, eliteoverlay, CombatLedger snapshot |

Settings are saved per account in `CLpfUIThreatDB`.

### Sounds
`/clpf sound RaidWarning` uses a built-in game sound. Other built-ins that work on
1.12 include `AlarmClockWarning3`, `igQuestFailed` and `TellMessage`.
You can also point it at a file (`.wav` / `.mp3`), for example one from another
addon:

    /clpf sound Interface\AddOns\TWThreat\sounds\<file>.wav

TWThreat ships its own warning sound file; browse its folder and use the path of
the one you like. Sound files are not bundled with this addon. `/clpf sound`
with no argument just replays the current sound, and `/clpf sound off` mutes it.

## Testing

1. Target any mob/NPC (pfUI hides the target frame with no target).
2. `/clpf test` - you should see the glow, the % badge, hear the sound and see the
   red screen-edge pulse for 8 seconds.
3. Real data requires a group and a target that is in combat, on a server that
   answers the threat protocol (Turtle WoW).

## Forced polling (important)

CombatLedger only asks the server for threat data while one of its **Threat**
windows is visible. To make this addon work without keeping a window open, it
wraps `CombatLedger.UI.IsModeVisible` so `"threat"` counts as visible. This is on
by default. If you notice any odd behaviour in CombatLedger, run `/clpf poll` to
turn it off and keep a Threat window open instead.

## Troubleshooting

- **No reply to `/clpf`** - addon not loading. Folder must be
  `Interface\AddOns\pfUI_CombatLedgerExt\` and CombatLedger must be enabled.
- **`/clpf test` shows nothing on the frame** - you have no target.
- **Test works but real fights don't** - run `/clpf debug` during a pull. Check
  `snapshot entries`, that `playerEntry=true`, and that `lastUpdate` is recent.
- **Badge overlaps the dragon** - check `/clpf debug` says `eliteoverlay=true` and
  `side` is `auto`; or force a side with `/clpf side left`.
- **Edge flash fades at the border instead of the centre** - `/clpf flip`.
- **No aggro ring or edge dots** - run `/clpf debug`. It must show
  `SuperWoW=true` and `UnitXP=true`; the edge line must show `ready=true`.
- **No warning when you expect one** - you are probably holding aggro (`tank`),
  or below the threshold. Lower it with `/clpf warn 75`.

## Notes / limits

- The percentage is relative to the tank's threat. It is not scaled by the
  110% (melee) / 130% (ranged) pull thresholds, so the default warning of 85%
  leaves a safety margin before you actually pull.
- Without a server reply, CombatLedger falls back to a local estimate; this addon
  shows it after about 2.5 seconds on a new target.
