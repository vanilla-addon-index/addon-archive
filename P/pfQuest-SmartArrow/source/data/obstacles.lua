-- pfQuest SmartArrow
-- Copyright (C) 2026 pfQuest SmartArrow contributors
--
-- This program is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option)
-- any later version. It is distributed WITHOUT ANY WARRANTY; see LICENSE.md.

-- pfQuest SmartArrow: obstacles you cannot walk straight through
--
-- Circles in zone map percent with a radius in yards. A structure you can go
-- up or into also has an `area` (yards) holding everything on or in it, and
-- `doors`: the only ways on and off. Paths to or from anything in the area go
-- through a door. Each centre is the
-- centroid of the NPCs pfQuest's own database places inside that tree or
-- building, so it is measured, not guessed. A path never cuts through a
-- circle, except when it starts or ends inside it (you are going into or out
-- of the building), so trainers and innkeepers inside stay reachable.
--
-- Everything else is learned while you play: when you keep sliding along
-- something while facing the arrow, a small circle is added there
-- (pfQuestSmartArrow_config.obstacles).

pfQuestSmartArrowData = pfQuestSmartArrowData or {}

pfQuestSmartArrowData.obstacles = {
  -- Aldrassil, Shadowglen. A staircase spirals up the outside of the trunk
  -- to the trainers, vendors, sentinels and Tenaron Stormgrip's room at the
  -- top. Measured from Questie's spawn data: the 22 NPCs posted on the tree
  -- centre on (59.18, 39.88) and reach out to 54 yards; ground wildlife
  -- (boars, nightsabers, toads) starts at 56. So the base is solid to about
  -- 45 yards and `area` (everything on the tree) is 60. The way on is the
  -- foot of the ramp next to Gilshalan Windwalker (classicdb: "go up the
  -- ramp next to Gilshalan all the way to the top room"), where a Shadowglen
  -- Sentinel guards the entrance at (57.4, 41.6).
  {
    zone = 141, x = 59.18, y = 39.88, r = 45, name = "Aldrassil", area = 60,
    doors = { { x = 57.6, y = 41.6 } },
    up = "On Aldrassil: take the ramp next to Gilshalan Windwalker; it spirals up round the trunk",
    down = "Leave Aldrassil by the ramp (it comes down next to Gilshalan), or jump down",
  },
  -- Northshire Abbey: Brother Sammuel, Llane Beshere, Priestess Anetta,
  -- Khelden Bremen, Jorik Kerridan, Drusilla La Salle
  { zone = 12,  x = 50.05, y = 40.97, r = 28, name = "Northshire Abbey" },
  -- Anvilmar, Coldridge Valley: Thran Khorman, Branstock Khalder, the trainers
  { zone = 1,   x = 28.67, y = 66.90, r = 24, name = "Anvilmar" },
}
