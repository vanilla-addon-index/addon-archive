# Retail navigation HUD texture attribution

`IngameNavigationUI.tga` is an exact, pixel-preserving import of Blizzard's
64x64 `Interface/Navigation/IngameNavigationUI` texture atlas.

Retail FrameXML's `Blizzard_QuestNavigation/SuperTrackedFrame.xml` assigns the
`Navigation-Tracked-Icon` atlas member to the in-world quest marker and the
`Navigation-Tracked-Arrow` member to its clamped off-screen arrow.
`SuperTrackedFrame.lua` confirms that quests select `Navigation-Tracked-Icon`.

PandaQuest uses the gold quest diamond at source pixels x=28..52, y=0..36.
The complete atlas is retained so the retail off-screen arrow remains
available without another asset import.

## Origin

Blizzard Entertainment UI art from the Retail live texture export at
`D:/Development/unrealUI_data/retail-ui-textures-live/Navigation/`.
`tools/import_retail_navigation.py` converts the PNG to the client's proven
RLE-compressed 32-bit TGA form and verifies every decoded pixel is unchanged.

This is imported as interoperability reference for a client-side interface
reimplementation. This is not a licence grant, and this note must stay with
the file.
