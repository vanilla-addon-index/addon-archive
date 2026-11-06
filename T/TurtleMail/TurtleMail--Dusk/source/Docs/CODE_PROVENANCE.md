# TurtleMail code provenance

Audit date: 2026-08-31

## Known fork chain

1. `shirsig/Mail`
   - https://github.com/shirsig/Mail
   - original known Vanilla mail addon source
2. `sica42/TurtleMail`
   - https://github.com/sica42/TurtleMail
   - immediate upstream fork with TurtleMail features and later maintenance
3. `Dusk-92/TurtleMail`
   - https://github.com/Dusk-92/TurtleMail
   - current maintained compatibility fork

GitHub repository metadata confirms that `sica42/TurtleMail` is a fork of
`shirsig/Mail`, and `Dusk-92/TurtleMail` is a fork of
`sica42/TurtleMail`.

## Immediate-upstream identity

The following current files are byte-identical at Git blob level to
`sica42/TurtleMail`:

| File | Git blob SHA-1 |
| --- | --- |
| `Calendar.lua` | `1a5e918bd4b6bf74f1c4a3372a60e944c5e1dcb8` |
| `TurtleMail.lua` | `009463c946c47f9fbf44c666005c5b95468cba97` |
| `TurtleMail.xml` | `e0ccb3ca6db13f999468a0eef9a91c564c8adae8` |
| `localization.lua` | `2ff7c48bd9c8ee555c7e2e0111bedce86e3e01bc` |
| `localization.de.lua` | `40227ed5306eafd43b97189967459a65487b32a9` |
| `localization.es.lua` | `3f181ba3dc36d8539e8eb6adb91b68f30ec37b75` |
| `localization.fr.lua` | `a72708fd39c212f4478779fa9e73200347495d51` |
| `localization.ru.lua` | `732e204b50c88eb410f48a835da3f5874d48c312` |

The three visual assets are documented separately in
`Docs/ASSET_PROVENANCE.md`.

## Dusk-92-specific maintenance

The current fork adds an isolated compatibility layer in
`TurtleMailFix.lua` and updates addon metadata/documentation around the
1.4.6 maintenance release.

The current `TurtleMail.toc` differs from the immediate upstream version and
includes the compatibility layer.

`AUDIT.md` documents the technical compatibility pass.

## Calendar provenance

`Calendar.lua` is unchanged from the immediate upstream.

Relevant upstream history:

- commit `91142ac27c8fabd651b8e8db6c3d30baa31a604e`
  ("New logging feature", 2025-03-23)
- commit `2a8cc7204c93dd83b54ea95009fbc6c6075d7573`
  ("Fix bug in calendar dropdown", 2025-04-02)

This establishes the immediate development history without asserting a license
that is not present in the upstream repository.

## Licensing boundary

Neither `shirsig/Mail` nor `sica42/TurtleMail` exposed an explicit
project-wide LICENSE file during this audit.

A public GitHub repository or fork relationship is not, by itself, proof of a
permissive license.

For that reason, the current fork records provenance rather than assigning an
invented license to inherited code.
