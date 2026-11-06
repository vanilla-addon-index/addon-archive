# TurtleMail third-party notices

Audit date: 2026-08-31

This file records known upstream sources, inherited code, assets, compatibility
references, and unresolved licensing for the Dusk-92 TurtleMail fork.

Existing source comments, Git history, upstream repository metadata, and README
credits remain part of the provenance trail.

## Historical source: shirsig/Mail

The original known source repository is:

- https://github.com/shirsig/Mail

It provides the earlier Vanilla WoW mail addon from which TurtleMail ultimately
descends.

No explicit project-wide LICENSE file was present in that repository during
this audit.

## Immediate upstream: sica42/TurtleMail

The immediate upstream repository is:

- https://github.com/sica42/TurtleMail

That repository is itself a fork of `shirsig/Mail`.

No explicit project-wide LICENSE file was present in the immediate upstream
repository during this audit.

Accordingly, this fork does **not** claim that inherited TurtleMail or Mail code
is MIT, GPL, public domain, or otherwise freely relicensed. The root `LICENSE`
notice is intentionally limited in scope and does not override upstream rights.

## Dusk-92 compatibility layer

The current fork adds and maintains Turtle WoW / Octo-like compatibility and
safety work.

Notably:

- `TurtleMailFix.lua` is maintained in this fork as an isolated compatibility
  layer.
- `AUDIT.md` documents the compatibility/stability audit.
- `TurtleMail.toc` and `README.md` include fork-specific maintenance and
  compatibility changes.

Historical Git commits remain the authoritative record for individual changes.

## Unchanged immediate-upstream files

At the time of this audit, the following runtime files in the Dusk-92 fork were
byte-identical at Git blob level to `sica42/TurtleMail`:

- `Calendar.lua`
- `TurtleMail.lua`
- `TurtleMail.xml`
- `localization.lua`
- `localization.de.lua`
- `localization.es.lua`
- `localization.fr.lua`
- `localization.ru.lua`
- `TurtleMail-AH.blp`
- `TurtleMail-RetArrow.blp`
- `TurtleMail-DownArrow.tga`

This establishes immediate provenance, not a new license grant.

## Calendar

`Calendar.lua` is inherited unchanged from `sica42/TurtleMail`.

The immediate upstream history shows the calendar as part of the 2025 logging
work, with a later calendar dropdown bug fix by Sica.

No separate license for that file was identified, so it remains documented as
upstream-derived material under unresolved project-wide licensing.

## Visual assets

The three bundled visual assets are tracked in
`Docs/ASSET_PROVENANCE.md`.

Their immediate upstream source is verified, but their ultimate artistic source
or underlying asset license was not established during this audit.

No additional ownership or relicensing claim is made.

## pfUI integration

TurtleMail includes optional compatibility/integration behavior for pfUI.

Compatibility or API integration does not imply that pfUI is bundled, nor does
it imply affiliation or endorsement.

## Turtle WoW / Octo-like compatibility

This fork targets Turtle WoW 1.18.x and Octo-like Vanilla environments.

Compatibility, naming, testing, or behavioral reference does not create an
affiliation, endorsement, partnership, or ownership relationship with those
projects or their maintainers.

## Project identity and trademarks

Canonical maintained fork:

- https://github.com/Dusk-92/TurtleMail

World of Warcraft, Warcraft, Blizzard Entertainment, and associated names,
marks, artwork, and game assets remain the property of their respective rights
holders.

See `PROJECT_IDENTITY.md`.

## Preservation rule

Do not remove historical attribution, source comments, upstream references, or
provenance records merely because inherited code is later modified.

When replacing or substantially rewriting inherited material, update the
provenance record rather than erasing the historical chain.
