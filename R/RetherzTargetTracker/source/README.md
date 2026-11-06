# RetherzTargetTracker version: r5 (Added keybindings)
Raid symbol targeting with debuff tracking.
```/rtt``` or ```/retherztargettracker``` to configure.
![example_image](https://i.imgur.com/uNzq1xa.png)

# Limitations
Vanilla is highly limited with tracking targets. To be able to target these units you must have a raid member targeting it. 
To be able to track debuffs timers accurately the player applying the debuff must have the addon and use a script to cast the spell.

# Usage
To properly utilize the debuff tracking you must use a script to cast your spells.

Example: ```/run RTT_CastSpell("Sunder Armor")``` or ```/run RTT_CastSpell("Curse of Recklessness")```
an exception is Faerie Fire (Feral) which must be cast using ```/run RTT_CastFFFeral()```

# Targeting
The addon provides several commands for targeting.
```/run RTT_TargetNext()``` will loop through the targets from skull to star.

```/run RTT_Target(1-8)``` will target by symbol (8 being skull, 1 being star) 
# Raid Leading Commands
```/run RTT_ClearSymbols()``` will remove all target symbols.

```/run RTT_ClearTarget()``` or ```/run RTT_ClearMO()``` will remove target symbol from your target or mouseover respectively.

```/run RTT_AssignNext()``` or ```/run RTT_AssignNextMO()``` will assign a symbol going from skull to star to your target or mouseover respectively.

```/run RTT_AssignFree()``` or ```/run RTT_AssignFreeMO()``` will assign an unused symbol to your target or mouseover respectively.


# Keybindings
![example_image](https://i.imgur.com/E5kJi64.png)
