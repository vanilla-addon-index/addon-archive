# TankHelper
super lightweight and barebones addon for turtle wow that shows enemy stats. type /tankhelper to get started
![image](https://github.com/balakethelock/TankHelper/assets/111737968/0456e194-d5a4-42d5-a68f-d26b88db0462)
Things it shows:
1. Shows enemy min-max swing damage (updates real time. Disarm reduces it by 60%, some mob self-buffs like some enrages will increase this value, others won't increase it but the mob will still hit for more)
If the enemy is a duel wielder, it'll say that too. Has false positives but no false negatives as far as I know.

2. Shows enemy attack power (the enemy at base attack power does base damage. attack power reductions linearly reduce swing damage from 100% of base to 70% of base). If you're max level, it also warns when your target does not have demo shout/roar applied.

3. Shows enemy attack speed (updates in real time with thunderclap, thunderfury, dream's herald, icy chill, and attack speed increases like enrages and frenzies)
4. Shows enemy dps (just calculated based on their swing damage and attack speed)

5. You can toggle armor mitigation by shift-right clicking the frame, min-max swing damage and dps will be reduced by your armor to find the post-mitigation damage the mob will hit you for.

6. You can move it around by shift-left dragging. Use chat commands (/tankhelper) to change the transparency and scale of the frame.

This addon is good for:
- tanks that want to know how much damage the mob will do before pull, and build their mitigation-threat balance around it.
- healers that want to know how much dps the mob is doing so they can choose the perfect rank.
- anybody in the open world that wants to pick his battles safely, especially hardcore players.
- warriors can disarm the enemy mob and see if their swing damage decreases. This is the best way of testing whether a mob is immune or not, since most of the time the debuff is applied but does nothing.
