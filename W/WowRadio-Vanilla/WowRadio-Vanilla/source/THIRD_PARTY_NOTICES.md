# WowRadio-Vanilla third-party notices

Audit date: 2026-08-31

This file records known upstream sources, bundled third-party libraries,
station-directory boundaries, and unresolved provenance.

## Historical WowRadio code

The current repository descends from the historical WowRadio addon.

Known provenance chain:

1. Original WowRadio credited to **Tormentor @ Mannoroth** and **belthazor**.
2. Vanilla-era backport preserved at:
   - https://github.com/Daribon/WowRadio
   - README identifies version 0.4a as "Backported to vanilla" on 2015-08-30.
3. Later Vanilla maintenance/update repository:
   - https://github.com/paokkerkir/WowRadio-Vanilla
4. Current maintained fork:
   - https://github.com/Dusk-92/WowRadio-Vanilla

Neither `Daribon/WowRadio` nor `paokkerkir/WowRadio-Vanilla` exposed an
explicit project-wide `LICENSE` file at the time of this audit.

Accordingly, WowRadio-Vanilla does **not** claim that the historical addon code
is MIT, GPL, public domain, or otherwise freely relicensed. Dusk-92's original
changes and documentation are distinct from inherited material and the root
`LICENSE` notice is intentionally limited in scope.

## Ace2

This repository embeds the following Ace2 components under `Libs/`:

- AceLibrary
- AceOO-2.0
- AceAddon-2.0
- AceDB-2.0
- AceConsole-2.0
- AceEvent-2.0
- AceLocale-2.2

The complete `Libs/` Git tree is byte-identical at Git object level to the
copies present in both `Daribon/WowRadio` and
`paokkerkir/WowRadio-Vanilla`.

Canonical historical/reference project:
- https://github.com/wowace-clone/Ace2
- https://www.wowace.com/projects/ace2

The official WowAce project page identifies the framework license as:

- **LGPL v2.1**
- **MIT for AceOO-2.0**

The current AceLibrary source header also states `License: LGPL v2.1`, while
the current AceOO-2.0 source header states `License: MIT`.

A copy of the GNU LGPL v2.1 license text is preserved at
`LICENSES/Ace2-LGPL-2.1.txt`.

Because the historical AceOO source header does not provide a separate
copyright line in this repository, this project does not fabricate one.
`LICENSES/Ace2-LICENSE-NOTICE.md` records the verified upstream license
designation and source references.

## Radio stations and stream URLs

`Stations.lua` contains station names, descriptions, categories, and remote
stream URLs. The repository does **not** contain or redistribute the audio
content delivered by those streams.

Station names and trademarks remain the property of their respective owners.
Listing a stream URL is for user navigation/interoperability and does not imply
affiliation, sponsorship, endorsement, partnership, or ownership.

Stream availability, programming, licensing, and content can change
independently of this repository.

See `Docs/STATION_DIRECTORY_NOTICE.md`.

## Visual assets

The bundled files:

- `bg_left.tga`
- `bg_right.tga`

are byte-identical to the corresponding files in
`paokkerkir/WowRadio-Vanilla`.

They were introduced in that upstream repository in commit
`6980f90591e1b9c5d1511cc8790e2c8f636839af` ("update to 1.0", 2026-05-04).

Those assets were not present in the older `Daribon/WowRadio` repository.
Their origin beyond the immediate upstream repository was not established
during this audit, so no broader ownership or relicensing claim is made.

See `Docs/ASSET_PROVENANCE.md`.

## Project identity and trademarks

Canonical maintained repository:
- https://github.com/Dusk-92/WowRadio-Vanilla

World of Warcraft, Warcraft, Blizzard Entertainment, and associated names,
marks, artwork, and game assets remain the property of their respective rights
holders.

See `PROJECT_IDENTITY.md`.

## Preservation rule

Do not remove historical credits, upstream source references, license notices,
or provenance records merely because code or assets are later modified.

When replacing inherited material, update the provenance record rather than
erasing the historical chain.
