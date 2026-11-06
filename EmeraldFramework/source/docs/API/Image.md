# Class Image

**Inherits [Item](Item.md)**

Display a texture.

# Property Documentation

## color

An {r,g,b\[,a\]} table (values in \[0,1\]) representing the vertex color of the texture.

## source

The path or id of the texture.

## layer

The layer of the image's native textures.

## blendMode

The blend mode of the image's native textures.

## rotation

Rotation of the texture. It uses texture coordinates.

# Member Functions


setCoords(left, right, top, bottom)
------------------------------------------------
setCoords(ULx,ULy,LLx,LLy,URx,URy,LRx,LRy)
------------------------------------------------

### Arguments

- `left`, `right`, `top`, `bottom`: positions of each edge, in fractions (0 is top/leftmost, 1 is bottom/rightmost)
- `ULx`,`ULy`,`LLx`,`LLy`,`URx`,`URy`,`LRx`,`LRy`: x and y coordinates of the corners, in fractions (0 is top/leftmost, 1 is bottom/rightmost)

### Description

Set the texture coordinates. It can be used to crop, rotate or do other transformations on the texture.
