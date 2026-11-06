# Database sources and precision (v0.6.5)

Coordinates come from the installed pfQuest/pfQuest-octo database with Octo overwrites. The new encoding retains 0.01 percentage point precision. All 19,810 source coordinate records are retained (duplicates collapse); legacy-only positions bring the total to 22,417. Eight entries for area 5138 use live client name resolution. Legacy rounded points covered by a source point are replaced by that source point.

Zone dimensions prefer the live C_Map.GetMapWorldSize API, with a local Questie-Octo snapshot plus pfQuest-octo overrides as fallback. The tracking radius remains an approximate 200 yards.

Mining textures were verified against https://octowow.st/db/ . Sources: https://github.com/roby-brok/pfQuest-octo and https://github.com/shagu/pfQuest . See PFQUEST-LICENSE.txt.
