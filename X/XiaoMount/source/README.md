## XiaoMount - TurtleWoW Edition

XiaoMount is an auto-equipper for riding speed and swim speed gear that will detect the best available riding equipment and equip it when you are mounted.
When you dismount it will restore your original gear setup. It works out of the box without any configuration necessary. It has been made for TurtleWoW specific riding equipment.

For the Classic WoW version see https://www.curseforge.com/wow/addons/xiaomount

## Commands

You may want to disable XiaoMount in some scenarios, such as when clearing trash in a raid or a boss pull that involves mounting. You can use these commands to disable/enable the autoequip:

```
/xm enabled - get current enabled status
/xm enabled 1 - enable autoequipping
/xm enabled 0 - disable autoequipping
```

## Updates

- (1.2.5) Added fallback for item links with unique IDs (e.g. SWV trinket) to ensure correct equipment restoration
- (1.2.4) Fixed issue where Feign Death would trigger swim equipment
- (1.2.3) Boots with relevant enchants are now kept equipped and not swapped out
- (1.2.2) Fixed Rethress Tide Crest trinket ID
- (1.2.1) Added autoequip for swimming speed gear - items are equipped when you first start holding breath
