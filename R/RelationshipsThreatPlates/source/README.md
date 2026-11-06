<img src="https://i.postimg.cc/gkqNFRGD/fff.png"/>ㅤㅤ<img src="https://i.postimg.cc/DyKBM536/afsa.png"/>

* It's recommended to use the KUI-NAMEPLATES addon as it's designed to work with that.
* You can find it here.

* https://github.com/Relationship-OctoWoW/KuiNamePlates

----------------------------------------------------------------------
Relationships Threat Plates For OctoWoW
----------------------------------------------------------------------

Threat percentage bars above nameplates
-- Styled after Kui Nameplates

= ThreatPlates =

 * Shows a threat percentage bar above each nameplate's health bar.
 * The bar grows from 0% to 100% based on your threat level against
 * that unit, with colour coding from green (low) to red (aggro).

== Features ==

 * Threat bar above the in-game health bar on nameplates
 * Percentage text displayed inside the bar
 * Smooth colour gradient: green -> yellow -> orange -> red
 * Kui Nameplates-style visuals (dark backgrounds, 1px inset,
 * spark effects, glow/shadow borders, outline fonts)
 * Configuration GUI for all settings
 * Works with Turtle WoW / Octo WoW (Vanilla 1.12 client)

== Commands ==

 *  /tp           - Open the configuration GUI
 *  /tp toggle    - Toggle threat bars on/off
 * /tp reset     - Reset settings to defaults
 * /tp help      - Show help

== Configuration ==

All settings are accessible via the /tp GUI:

  General:
   * Enable Threat Plates (on/off)
   * Show Threat Text (percentage in bar)
   * Smooth Colours (gradient transitions)

  Appearance:
     *- Bar Height (2-12 px)
     *- Bar Offset Y (-20 to 0 px)
     *- Bar Alpha (0.1-1.0)
     *- Font Size (6-14 pt)
     *- Font Outline

  Kui Style Effects:
     *- Show Spark (bright leading edge)
     *- Show Fill Background (dim ghost behind bar)
     *- Fill Alpha (0.05-0.50)
     *- Enable Glow (border glow based on threat)
     *- Glow as Shadow (subtle vs bright)
     *- Glow Size (1-8 px)

  Display Filters:
     *- Show on Hostile units
     *- Show on Neutral units
     *- Show on Friendly units

== Threat Detection ==

ThreatPlates uses a three-tier threat detection system:

   * UnitDetailedThreatSituation (Turtle WoW extension) - most accurate
   * GetThreatPercent API (if available) - precise percentage
   * UnitThreatSituation with heuristics - fallback estimation

 *The addon polls threat every 0.2 seconds and updates nameplate
 *visuals every 0.3 seconds for smooth animation.

== Installation ==
   * Extract anywhere and then rename the RelationshipsThreatPlates-main folder to RelationshipsThreatPlates
   * Move the RelationshipsThreatPlates folder to your Interface/AddOns/ directory
   *Restart WoW or reload the UI (/console reloadui)
   *Type /tp to configure
