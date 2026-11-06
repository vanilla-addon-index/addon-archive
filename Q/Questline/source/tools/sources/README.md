# Native minimap atlas

`minimap-objecticons.blp` is the unmodified `Interface\Minimap\ObjectIcons.blp`
from the installed OctoWoW client's `Data/interface.MPQ` (Blizzard artwork).
SHA-256: `e8c77616646421d77f3892c3f61678e1c0bbf527db6fa34b0cf7d9fb262c36e7`.

`node tools/minimap-blips.js` generates `Textures/minimap-blips.blp`. It clears
only the alpha of the top-right turn-in cell at every unmixed mip level. All
color data, other sprites, and the tiny mixed 2x2/1x1 mip levels stay byte-identical.
The source hash prevents accidentally patching a different client atlas layout.
