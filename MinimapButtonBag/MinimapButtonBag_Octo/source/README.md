# MinimapButtonBag_Octo

MinimapButtonBag_Octo cleans up your Minimap and relocates the buttons in a menu bar.

![screenshot](https://user-images.githubusercontent.com/98543024/155025699-12b30d8d-92c3-41c4-80ab-959cd68b7de4.png)

[A fork of MBB, all credit to Tunhadil, LaYt ([MinimapButtonBag-vanilla](https://github.com/laytya/MinimapButtonBag-vanilla)), and McPewPew ([MinimapButtonBag-TurtleWoW](https://github.com/McPewPew/MinimapButtonBag-TurtleWoW))]

## Instructions
* Unzip into `WoW\Interface\AddOns`
* Make sure the resulting folder is named exactly `MinimapButtonBag_Octo`

## Usage

* While attached to the minimap (default state):

* Left-click the bag icon — expand/collapse the button bag.
* Shift + Left-drag — slide the bag icon around the rim of the minimap (angle-locked, stays orbiting the minimap edge).
* Ctrl + Right-click — detach the bag icon from the minimap; it jumps to wherever your cursor is and switches to free-floating mode.
* Right-click (without Ctrl) — open the MBB options panel.

### Once detached (free-floating):

* Shift + Left-drag — move the icon anywhere on screen.
* Ctrl + Right-click — reattach it back to the minimap (snaps to default position).

## Changelog (Octo fork - V1.0)
* Original addon was causing crashes with OctoWoW., forked to get it working without issues.
* Fixed a bug in `MBB_RestoreButton` where right-click-restoring a button to the minimap set its width equal to its height instead of its original width, distorting non-square buttons.
* Hardened the pfUI drag-position check (`pfUI_config["disabled"]["minimap"]`) with proper nil-guards, so it can no longer throw a Lua error every frame while dragging if `pfUI_config` isn't shaped as expected.
* Replaced the custom `icon.tga` with the stock in-game bag icon `Interface\Icons\INV_Misc_Bag_08` — no more bundled icon file, and it sidesteps the RLE-compressed TGA loading issue on the 1.12.1 client entirely.
* Cleaned up a malformed `## X-Date` line in the `.toc` (missing colon).
* Fixed Ctrl+Right-click "detach from minimap" positioning: it was converting the cursor position using the icon's own display scale (`MBB_Options.Scale/100`) instead of the UI's actual effective scale (`UIParent:GetEffectiveScale()`), so the button would land in the wrong spot instead of following your cursor away from the minimap.




-Olzon
