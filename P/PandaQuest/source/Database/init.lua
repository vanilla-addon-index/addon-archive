-- PandaQuest bundled world data.
-- Vanilla content originates from the VMaNGOS world database and was packaged
-- by pfQuest (MIT, Eric Mauser / Shagu); TBC data excluded. Turtle WoW 1.18.1
-- content comes from pfQuest-turtle 1.0.38 by Rivi (MIT), merged offline by
-- tools/import_turtle_db.py.
-- See Database/CREDITS.md and LICENSE in the addon root.
--
-- Loads before every data file and owns the global they populate. The tables
-- are plain data: they describe the game world, never the client API.
PandaQuestData = PandaQuestData or {}
