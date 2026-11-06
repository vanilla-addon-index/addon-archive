# superLazyScript

**superLazyScript** is a fork of [lazyScript](https://github.com/laytya/LazyScript), an **in-game attack scripting language** for Vanilla clients. It is aimed at users who would like to write more complex in-game macros, but who do not want to have to deal with the full blown API or do not want to have to write a separate add-on for every macro over 250 characters<sup>[[wiki]](https://turtle-wow.fandom.com/wiki/LazyScript)</sup>.

superLazyScript incorporates [SuperWoW](https://github.com/balakethelock/SuperWoW), [Quiver](https://github.com/SabineWren/Quiver) (for hunters) and [SP_SwingTimer](https://github.com/MarcelineVQ/SP_SwingTimer) to make existing features better, and add new features too. superLazyScript is developed for ~~TurtleWoW~~ **OctoWoW**.

<img width="1326" height="725" alt="image" src="https://github.com/user-attachments/assets/c35763b7-d8fc-46c2-81b7-1b573aadb17c" />

## Features
- New look & feel
- Modern fonts
- New & improved interrupt mask logic.
  >*Previously, the addon had no way to know the duration of a spellcast, so would have to guess and end up queuing up a kick well after a spell had already been cast. This has been fixed.*
- Fixes and improvements to the `active=echo` command
  >*This feature went undocumented and impractical. Now it's actually big and readable. It's intent is to let you know which script is currently active.*
- Added a new 'Extras' tab to the help menu, noting down undocumented features.

You can use custom abilities not present in the documentation via using the command `action=<Action Name>`. e.g. `action=Aspect of the Viper-ifPlayer<10%mana`. Similarly, you can reference buffs and debuffs by name via `if<UnitId>Has{Buff,Debuff}Title=<Buff Name>`.

### New masks

`-ifAutoShotSafe` requires [Quiver](https://github.com/SabineWren/Quiver) and is a safe way to cast hunter spells without ever clipping the reload timer.

https://github.com/user-attachments/assets/207a64f0-74c5-448a-8080-0ddf2a785ba8

Script used:
```
aimed-ifReloadTimer>1.5s-ifplayerHasBuffTitle=Lock and Load
arcane-ifplayerHasDebuffTitle=Enchanted Ammunition-ifAutoShotSafe-ifGotTalent=Experimental Ammunition
serpent-ifplayerHasDebuffTitle=Poisonous Ammunition-ifAutoShotSafe
multi-ifplayerHasDebuffTitle=Explosive Ammunition-ifAutoShotSafe
aimed-ifReloadTimer>2.5s-ifNotInCombat-ifGotTalent=Aimed Shot
action=Steady Shot-ifReloadTimer>1.5s
```

# LazyScript

Look at [Wiki](https://github.com/laytya/LazyScript/wiki) for more info

## Wider LazyScript Cinematic Universe:

https://www.fengshen.cn/2024/03/lazyscript%e5%ae%9a%e5%88%b6%e7%89%88%e4%b9%8c%e9%be%9f%e6%9c%8d%e9%80%82%e9%85%8d%e5%86%85%e5%ae%b9/

i think this is some chinese paywalled fork and it has like more nampower and superwow integration but i didnt opt to replace the texture based spell identification with a spellid based one because cba anyway thought it was interesting also theres some google code original repo from 20 years ago drifting around somewhere but killed by google ofc hard to find it you find it tell me nice to add here lowk



