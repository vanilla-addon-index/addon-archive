# Class Item

**Inherits [Object](Object.md)**

Base class for all visuals types in EmeraldFramework. It wraps around a native frame.

It exposes common functionalities of visuals like anchoring, width, height, ...


# Property Documentation

## implicitWidth
## implicitHeight

They define the natural width and height of the `Item` when width and height are not set.

It can be useful to store the preferred size of the `Item` when its actual size is controlled by anchors or layout.


## width
## height

The actual width and height of the `Item`.


## anchorTop
## anchorBottom
## anchorLeft
## anchorRight
## anchorTopLeft
## anchorTopRight
## anchorBottomLeft
## anchorBottomRight
## anchorCenter
## anchorFill
## margins
## marginTop
## marginBottom
## marginLeft
## marginRight
## hoffset
## voffset

Above properties can be used to place and size a frame relative to another's.
Note that setting an anchor to nil has no effect whatsoever.

```lua
local icon = Image()
local text = Label()

icon.source = "texture\\path"
icon.width = 50
icon.height = 50
icon.anchorCenter = root.center -- middle of the screen

text.text = "text1"
text.anchorTop = icon.bottom
text.marginTop = 4

--[[
  ┏━┓
  ┗━┛
 text1
]]
```

Note that margins are relative to the center of the item, for instance a positive `marginRight` moves the item to the left (away from its anchor), while a negative value moves it towards the right.

`margins` can be used to set all margins at once.

```lua
local r1 = Rectangle()
r1.width = 40
r1.height = 40
r1.anchorCenter = root.center -- middle of the screen
r1.color = {0,0,0} -- black

local r2 = Rectangle(r1)
r2.anchorFill = r1
r2.margins = 10

--[[
████
█  █
████
]]
```

`hoffset` and `voffset` can be used in combination with `anchorCenter`. Positive `hoffset` will move to the right, positive `voffset` will move upward.

## z

The level of the frame. Frames with higher `z` will cover frames with lower one.

## opacity

Controls the alpha of the frame, an opacity of `0` will make the frame completely transparent, `1` completely opaque.

## visible

`visible` is true when the Item is shown on the screen, false otherwise. It can be set to `false` to hide the Item and all its children, if set to `true` the Item will be shown as soon as its parent becomes visible.

## scale

Set the scale of the item. Using a non-pixelperfect scale will result in 1 pixel error on sizes and distances. Note that text can break or behave unexpectedly as it doesn't scale linearly.

## childrenItems

The list of children items of the Item.

## visibleChildren

The list of the visible children items of the Item.

## backdrop

The table describing the backdrop of the Item.

## backdropColor

An {r,g,b\[,a\]} table describing the color of the backdrop. Values in \[0,1\].

## keyboardEnabled

Can be used to enable keyboard events on the frame. Values: `true`|`false`


Constructors
------------------------------------------------

1. `([parent[, wrap[, own]]])`

### Arguments
- `1.`:
    * `parent`: parent item. Must be an `Item` or its derivate.
    * `wrap`: a native frame to wrap.
    * `own`: whether to take ownership of the frame.
    
### Description
- `1.`:  
    Creates an `Item` having `parent` as parent. If `wrap` is set, the item will control it, otherwise a new frame or recycled is wrapped instead. If `own` is `false` the wrapped frame will not be recycled when the Item is destroyed.

`:clearAnchors()`
------------------------------------------------

Removes all anchors from the Item.


# root

`root` is the default parent for all other items. It's scaled to be pixelperfect and covers the entire screen. `root.height / root.scale` and `root.width / root.scale` give the size of the game window.


