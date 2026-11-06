# WowRadio-Vanilla code provenance

Audit date: 2026-08-31

## Provenance chain

### Historical addon

The addon metadata and surviving historical documentation credit:

- Tormentor @ Mannoroth
- belthazor
- jack.e for initial GUI and ideas

### Vanilla backport

Repository:
- https://github.com/Daribon/WowRadio

Its README identifies:
- WowRadio v0.4 — 2006-12-25
- WowRadio v0.4a — 2015-08-30
- v0.4a as "Backported to vanilla"

No project-wide LICENSE file was present when checked during this audit.

### 2026 Vanilla maintenance

Repository:
- https://github.com/paokkerkir/WowRadio-Vanilla

This repository updated the addon substantially in 2026 and is the immediate
upstream source for the current fork's early history.

No project-wide LICENSE file was present when checked during this audit.

### Current maintained fork

Repository:
- https://github.com/Dusk-92/WowRadio-Vanilla

Dusk-92 maintains later changes including station updates, UI changes,
stability fixes, and optimization work.

## Ace2 provenance

The complete current `Libs/` Git tree SHA-1 is:

`c29ef4a8a5c3b390f7fb968cb8f0f1917670170c`

The same tree SHA appears in:

- `Dusk-92/WowRadio-Vanilla`
- `paokkerkir/WowRadio-Vanilla`
- `Daribon/WowRadio`

This establishes that the embedded Ace2 library tree was inherited unchanged
through that known chain.

The official WowAce project page identifies Ace2 as LGPL v2.1, with AceOO-2.0
under MIT.

## Licensing boundary

A public Git repository or historical addon archive is not, by itself, proof of
a permissive software license.

Because no explicit project-wide license was identified for the historical
WowRadio code, this project records provenance rather than inventing a license.

Dusk-92's original modifications remain distinct from inherited code, Ace2
libraries, station names/URLs, and visual assets.
