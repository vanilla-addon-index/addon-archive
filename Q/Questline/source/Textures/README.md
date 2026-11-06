# Map artwork

Quest pickup and turn-in markers use unchanged 32x32 BLP copies from the
installed Questie-Octo addon:

- `quest-available.blp`: `Questie-Octo/UI/Icons/available.blp`, SHA-256
  `6846ce024c0dfaabbcbfcb4911904653d1c9d6b4c35ac8582903a34c3bae36af`.
- `quest-complete.blp`: `Questie-Octo/UI/Icons/complete.blp`, SHA-256
  `8e86e8f510bf9957b14c1ae22224fec02624ea5e5518ce1621854878a0bd41b5`.

Both render at 16 pixels, matching Questie-Octo's default marker size, with
world-map zoom compensation. They are shipped locally and are not overwritten
by the generated-texture build; Questie-Octo is not required at runtime.

The source audit records `available.blp` as unresolved in its reference set and
`complete.blp` as historically attributed to Questie 3.3.5, without an available
archive for hash verification. This copy retains those qualifications and does
not assert a new license for the artwork. The original asset audit is preserved
in `../licenses/Questie-Octo-ASSET-PROVENANCE.md`; upstream notices, Questie
license metadata, and GPLv3 text are also retained in `../licenses/`.

## Objective actions

These files are unchanged copies from the installed pfQuest artwork:

- `action-loot.tga`: `pfQuest/img/cluster_item.tga`
- `action-kill.tga`: `pfQuest/img/cluster_mob.tga`
- `action-interact.tga`: `pfQuest/img/cluster_misc.tga`

pfQuest's notice is retained in `../licenses/pfQuest-MIT.txt`.
These shipped assets do not require pfQuest at runtime and are not overwritten
by Questline's generated-texture build. Talk objectives use the client's native
`Interface\GossipFrame\GossipGossipIcon`.

Bag markers now use the client's native `Interface\GossipFrame\VendorGossipIcon`
instead of `action-loot.tga`. Precise map bags render at 14 pixels; spawn bags
render at 12 pixels on both maps, compensating for world-map zoom.
