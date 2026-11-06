# Bundled font

`PTSansNarrow.ttf` is the face PandaQuest switches a label to when its text
holds Cyrillic or Chinese characters that the client's own font cannot draw
(`PQ.Client.FitFontToText`). Labels with only Latin text keep the client font.

- Family: PT Sans Narrow Bold, version 2.003W OFL, by ParaType Ltd.
  (A. Korolkova, O. Umpeleva, V. Yefimov).
- Copyright (c) 2010, ParaType Ltd., with Reserved Font Names "PT Sans",
  "PT Serif" and "ParaType".
- Licence: SIL Open Font License 1.1, reproduced in full in [OFL.txt](OFL.txt)
  as embedded in the font's own name table.

This copy is the same file pandaUI ships as `media/Fonts/PTSansNarrow.ttf`. It
was extended with FontForge to 22,484 glyphs, including the CJK ideographs that
PT Sans does not cover, and it still carries the PT Sans name. The source of
those added glyphs is not recorded in the file. Replace it with a font of known
provenance before a public release. Change only `Client.LANGUAGE_FONT_PATH`
when you do.

The font is not listed in the TOC; the client loads it by path on first use.
