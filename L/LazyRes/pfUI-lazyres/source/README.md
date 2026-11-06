# LazyRes for pfUI

This addon is an external module for [pfUI](https://gitlab.com/shagu/pfUI) addon that makes resurrecting the raid after a wipe easy.

Type `/pflr` (or add that command to a macro) to quickly res someone near you.

Classes that can also res will be ressed before classes with mana, followed by classes without mana. The class ress order is Shaman > Paladin > Priest > Druid > Mage > Hunter > Warlock > Warrior > Rogue.

Players that are already being ressed will be skipped over, if the other resser uses a healcomm compatible addon.

If you have a friendly dead target selected, /pflr will work just like a normal res spell and cast res on that target.

If you have no target selected and no dead raid member is within range, /pflr will cast the Resurrect spell awaiting target selection. That way you can still select targets manually.

## Improvements of this fork

* Works in raids and parties
* Does only require pfUI, but no other external libraries
* Adds a config for chat-notifications
