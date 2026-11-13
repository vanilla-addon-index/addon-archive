# Modern power bars

Modern Class Colors uses precolored retail resource fills, with frame-specific variants of ModernPowerMana.tga, ModernPowerRage.tga, ModernPowerFocus.tga and ModernPowerEnergy.tga. Each bar uses white vertex tint (1, 1, 1), preserving the native artwork's colors and gradient. Flat PowerBarColor tints multiplied by the old grayscale texture made mana too dark.

## Verified source

- Blizzard client build 12.1.5.70448, interface/hud/uiunitframe2x.blp, FileDataID 4642466.
- Download: https://wago.tools/api/casc/4642466?version=12.1.5.70448
- Atlas coordinates: https://github.com/Ketho/BlizzardInterfaceResources/blob/f3b334b33bd19fa6a0250f7922ecfa83db7fe356/Resources/AtlasInfo.lua
- Retail application uses the resource atlas and white tint: https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_UnitFrame/Mainline/UnitFrame.lua

## Frame-specific fitting

Player bars use the player artwork. Warlock mana uses the rectangular ClassResource variant seen in retail warlock frames; rogue/druid energy uses the corresponding energy variant. Other player resources retain the standard player artwork. These are visual choices for the Vanilla client; retail specialization/resource mechanics are not imported.

Target bars use Target artwork. Pet and target-of-target bars use the smaller TargetofTarget artwork. Party bars use Party artwork from interface/hud/uipartyframe.blp (FileDataID 4681512), downloaded from https://wago.tools/api/casc/4681512?version=12.1.5.70448 . Both sheets use the same build and pinned atlas metadata above.

The crops include the native dark edges and endcaps. Bilinear resizing (instead of Lanczos) avoids sharpening overshoot, and export dimensions are closer to the smaller Vanilla bars. White vertex tint is retained. A solid black BACKGROUND texture behind each styled power bar prevents the underlying Vanilla backing from tinting transparent edges and provides a neutral empty portion; it hides for missing units and unknown resource types. Frame sizes, positions, health artwork and gold text are unchanged. Animated retail sparks, retail frame borders and masks are not included, so a pixel-perfect match to every BetterBlizzFrames profile is not promised.

Exact source crops use exclusive right/bottom edges:

| Asset | Sheet | Left | Top | Right | Bottom | Export |
| --- | --- | --- | --- | --- | --- | --- |
| ModernPowerEnergy.tga | uiunitframe2x | 1667 | 479 | 1915 | 499 | 128x16 |
| ModernPowerFocus.tga | uiunitframe2x | 387 | 501 | 635 | 521 | 128x16 |
| ModernPowerMana.tga | uiunitframe2x | 637 | 501 | 885 | 521 | 128x16 |
| ModernPowerRage.tga | uiunitframe2x | 1137 | 501 | 1385 | 521 | 128x16 |
| ModernPowerEnergyClass.tga | uiunitframe2x | 1637 | 501 | 1885 | 521 | 128x16 |
| ModernPowerManaClass.tga | uiunitframe2x | 387 | 523 | 635 | 543 | 128x16 |
| ModernPowerEnergyTarget.tga | uiunitframe2x | 1666 | 415 | 1934 | 435 | 256x16 |
| ModernPowerFocusTarget.tga | uiunitframe2x | 387 | 457 | 655 | 477 | 256x16 |
| ModernPowerManaTarget.tga | uiunitframe2x | 657 | 457 | 925 | 477 | 256x16 |
| ModernPowerRageTarget.tga | uiunitframe2x | 1197 | 457 | 1465 | 477 | 256x16 |
| ModernPowerEnergySmall.tga | uiunitframe2x | 1607 | 151 | 1755 | 165 | 128x16 |
| ModernPowerFocusSmall.tga | uiunitframe2x | 1757 | 151 | 1905 | 165 | 128x16 |
| ModernPowerManaSmall.tga | uiunitframe2x | 1857 | 337 | 2005 | 351 | 128x16 |
| ModernPowerRageSmall.tga | uiunitframe2x | 1163 | 441 | 1311 | 455 | 128x16 |
| ModernPowerEnergyParty.tga | uipartyframe | 70 | 179 | 144 | 186 | 128x8 |
| ModernPowerFocusParty.tga | uipartyframe | 146 | 179 | 220 | 186 | 128x8 |
| ModernPowerManaParty.tga | uipartyframe | 1 | 191 | 75 | 198 | 128x8 |
| ModernPowerRageParty.tga | uipartyframe | 153 | 191 | 227 | 198 | 128x8 |

BetterBlizzFrames can retain the native game artwork when custom power textures are disabled, or replace it with a user-selected SharedMedia texture. These assets reproduce native retail fills, not an arbitrary BetterBlizzFrames saved profile.

Unknown/custom resource types retain their original texture and tint. Shapeshifts and target changes reselect the appropriate resource texture. Disabling Modern and reloading restores stock behavior. Gold numbers are unchanged.

Restart WoW after installation so new texture files are available. Lua 5.1 mock checks cover all four resource transitions, frame-family and class-variant selection, white tint enforcement, pet/party bars, missing-unit and unknown-resource background cleanup, disabled behavior and repeated initialization. Actual in-game rendering remains to be checked.

## Rectangular mana slots

All Modern mana bars now use ModernPowerManaClass.tga, the native rectangular retail mana fill. The regular retail target/small/party art has angled transparent corners that leave wedges inside Vanilla's rectangular mana slots. Sharing the rectangular fill fixes that gap for all classes and supported frames, while preserving white tint, the retail blue gradient, frame dimensions and text. Other resources retain their frame-specific variants.

## Druid secondary mana bar

PlayerFrameAlternatePowerBar uses the same rectangular light-blue mana fill and white tint. Its resource type is fixed to mana while the primary player bar changes to rage or energy. This is independent of the white-number option. The temporary deep-blue tint experiment was reverted.
