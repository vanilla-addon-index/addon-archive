# TargetFrameBuff v0.9.6 validation

23 simulated Lua 5.1 regression scenarios passed, plus XML parsing. These cover
old/native clients, aura reordering, overflow, settings, sweep lifecycle, delta
refreshes and full updates, the Debuff Timer overlap warning, test mode, buff/debuff limits, target/pet/spellbook changes, reused delta payloads,
no polling in delta mode, and native-number/flash suppression.

ClassicAPI 1.17.10+ is detected through GetAuraDataByAuraInstanceID, introduced with
UNIT_AURA_DELTA. Each relevant delta triggers a full display snapshot rather than
retaining event tables or maintaining a second aura cache. This preserves sorted
indices for icon/tooltip alignment. Older ClassicAPI polls every 0.5 seconds.
Countdown text remains on its existing 0.2-second active-only updater.

The native countdown is explicitly hidden per sweep; no global CVar is changed.
New Clear and SetDrawBling methods are optional, preserving older versions.

Not tested inside a running WoW client. Verify recasts, target switches, auras
expiring, and sweeps with countdownForCooldowns enabled. Keep ShaguTweaks Debuff
Timer disabled to prevent overlapping addon countdowns (a chat warning appears
if it is detected). No FPS gain is claimed.
