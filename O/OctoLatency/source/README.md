## OctoLatency

A lightweight latency monitor for Vanilla WoW (1.12.1). Shows a small, movable,
color-coded latency readout on your screen.

### Requirements

- **ClassicAPI.dll** must be installed before you install this addon. Without
  it, the addon will throw errors and the readout will show as an empty grey
  box with no text/numbers inside it.
  - You'll need to add `ClassicAPI.dll` to your client's `dll.txt` (the entry
    is case-sensitive).

### What it does

- Displays your current world latency (falls back to home latency if world
  isn't available) as `NNN ms` next to your screen.
- Color-codes the number so you can tell your connection quality at a glance:
  - **Green** — under 150 ms (good)
  - **Yellow** — 150-350 ms (moderate)
  - **Red** — over 350 ms (critical)
- Hover the frame for a tooltip with home latency, world latency, and
  bandwidth.
- Updates every 2 seconds (not every frame), so it has no meaningful impact on
  game performance.

### Options

There's no settings panel — the addon is intentionally minimal. The only
"option" is position:

- **Move it**: left-click and drag the frame anywhere on screen. Its position
  is saved automatically and restored on your next login.

### Error reporting

If something inside the addon errors (e.g. an unexpected `GetNetStats()`
response), it's caught instead of spamming a Lua error popup, and logged for
you to report:

- `/octolat errors` — print the last 20 logged errors (with timestamps) to
  chat.
- `/octolat copyerrors` — open a copy-paste window with the same log, since
  vanilla WoW's chat frame doesn't let you select/copy its text. The window
  opens with the text already highlighted, so you can just press Ctrl+C.
- `/octolat clearerrors` — clear the error log.

The log is also saved to your `SavedVariables` file, so it survives
logout/relog.

### Troubleshooting

- **Grey box with no numbers / constant errors**: This almost always means
  `ClassicAPI.dll` isn't installed correctly. Check that:
  - `ClassicAPI.dll` is present in your client folder.
  - It's listed in `dll.txt` exactly as `ClassicAPI.dll` (matching case — the
    entry is case-sensitive).
  - After adding it, fully restart the client (not just `/reload`).
