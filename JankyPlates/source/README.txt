JankyPlates
===========
Version 1.0.39 | Turtle WoW


WHAT IT DOES
------------
JankyPlates recolors enemy nameplate health bars using the best data it can
get from Turtle WoW, SuperWoW, and TWThreat.

In practice it works like this:

1. Crowd control override
   Purple means the mob appears crowd controlled.

2. Threat coloring when real threat data exists
   For supported mobs, JankyPlates uses TWThreat data and shows:
   - Green  = safe
   - Yellow = caution
   - Red    = danger / aggro lost / high threat

3. Aggro fallback when real threat data does not exist
   JankyPlates falls back to "who is this mob attacking right now?"
   This is most useful for non-elites and other unsupported cases.

4. Default backend color when there is not enough trustworthy data
   If JankyPlates cannot make a safe decision, it restores the normal
   pfUI/ShaguPlates color.


SUPPORTED BACKENDS
------------------
JankyPlates needs one of these installed:

- pfUI
- ShaguPlates

JankyPlates hooks the nameplate bars provided by one of those addons.


REQUIRED / RECOMMENDED ADDONS
-----------------------------
Required:

- SuperWoW
  Used for GUID-based unit reads, target tracking, and CC checks.

Recommended:

- TWThreat
  Used for real server threat values and threshold-based coloring.

Important:

- TWThreat coverage is limited by the server. It is strongest on elites and
  bosses.
- Non-elites often fall back to aggro-state logic instead of true threat.
- For group threat coverage, other party members using TWThreat helps.


TANK MODE
---------
Tank Mode changes how colors are interpreted.

Tank Mode ON:
- Green  = mob is on you / threat is healthy
- Yellow = someone else is climbing
- Red    = mob is off you or near pull

Tank Mode OFF:
- Green  = safe, mob is not on you
- Yellow = threat is getting risky
- Red    = danger, you have aggro or are close to it

Auto Tank Mode:
- Druid: form 1 is treated as tank mode
- Warrior: defensive stance is treated as tank mode

When auto mode is on, JankyPlates updates Tank Mode automatically.


DEFAULT THREAT THRESHOLDS
-------------------------
Defaults are now:

- 0-84%   Green
- 85-98%  Yellow
- 99%+    Red

These are configurable in the options window.


NAMEPLATE COLORS
----------------
Purple
  CC detected.

Green
  Safe according to current threat or aggro-state logic.

Yellow
  Threat is getting risky.

Red
  Dangerous. For tanks this usually means the mob is off you or close to it.
  For non-tanks this usually means the mob is on you or close to it.

Default backend color
  JankyPlates did not have enough trustworthy data and left or restored the
  normal nameplate color.


PFUI / SHAGUPLATES NOTES
------------------------
On pfUI, JankyPlates disables pfUI's conflicting SuperWoW nameplate coloring
settings automatically. That is intentional.

On ShaguPlates, JankyPlates uses the same bar-hooking approach but does not
depend on pfUI being installed.


INSTALLATION
------------
1. Put the JankyPlates folder into:
   Interface\\AddOns\\

2. Final structure should be:
   Interface\\AddOns\\JankyPlates\\JankyPlates.toc
   Interface\\AddOns\\JankyPlates\\JankyPlates.lua

3. Enable the addon at character select.

4. Log in and check chat for the load message.


COMMANDS
--------
/jplates
  Open the options window.

/jplates trace on
  Enable SavedVariables tracing.

/jplates trace off
  Disable tracing.

/jplates trace clear
  Clear the in-memory trace log.

Trace logs are written to SavedVariables on reload/logout.


TRACE / DEBUGGING
-----------------
JankyPlates has a verbose trace mode for diagnosing:

- target changes
- combat start/end
- shapeshift / stance changes
- packet attribution
- plate lifecycle and frame reuse
- actual bar color writes

The trace is stored in:

- JankyPlatesTraceLog

Regular settings are stored in:

- JankyPlatesConfig


KNOWN LIMITATIONS
-----------------
- TWThreat does not provide universal threat data for every mob in every
  situation. Some mobs never receive useful threat packets.

- Non-elites are best-effort only. JankyPlates often has to rely on aggro-state
  fallback instead of true threat.

- Same-name mobs are the hardest case. JankyPlates uses GUIDs and targeting
  data where possible, but duplicate-name pulls can still be imperfect.

- When the client gives incomplete or delayed unit data, colors may briefly lag
  behind what you see happening in combat.

- Trace mode is intentionally noisy and can produce large SavedVariables files.


PRACTICAL EXPECTATIONS
----------------------
JankyPlates works best as:

- reliable elite/boss threat plates when TWThreat data exists
- useful aggro-state plates for unsupported mobs
- a debugging-friendly best-effort addon for Turtle WoW's imperfect API surface

It is not a perfect replacement for modern WoW threat APIs, because Turtle,
SuperWoW, and TWThreat do not expose complete information in every case.
