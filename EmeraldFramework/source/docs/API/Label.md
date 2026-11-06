# Class Label

**Inherits [Item](Item.md)**

Display a text.

# Property Documentation

## text

The displayed text.

## color

An {r,g,b\[,a\]} table (values in \[0,1\]) representing the color of the text.

## hAlignment
## vAlignment

The horizontal and vertical alignment of the text.

## contentWidth
## contentHeight

The natural, unwrapped width of the text and the height of the constrained text.

## sizeMode

Possible values:
- `Label.NoFit`: uses `fontSize` to size the text.
- `Label.HorizontalFit`: set the size of the font to fill all the available width.
- `Label.VerticalFit`: set the size of the font to fill all the available height.
- `Label.Fit`: set the size of the font to fill all the available space.
