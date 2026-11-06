# Project Depreciated.
## So long, and thanks for the Turtles.
This will still work on probably any 1.12 client but I will no longer be supporting it. Viva la Turtle.
Check out my 3.3.5 addons.

## Turtle RP 2

Turtle's RP scene has been an integral party of the community since the earliest days of the network. This addon was forked and made official after numerous community requests for assistance moderating and growing the roleplay community.

Many thanks from the team and community to those who will contribute to this addon, and those who did prior. Their notes are below.

## TurtleRP

An RP addon custom-made for Vanilla WoW.

For more information, visit https://github.com/bratmage/TurtleRP.

## Version 2.0.0
Thank you for all of the lovely support and feedback as I've worked on this. Viva la Turtle 🐢
Please note that this *is* a forced update, though I have made as many attempts as I can to future proof it so that there is never another required update again- maybe at 3.0!

### Account-wide Profiles
- Character profiles now use a new account-wide profile system instead of the old per-character slot model.
- Instant Profile switching!!
- Added a profile management tab. Features:
-- Profile select dropdown
-- New profile, profile duplication, profile deletion, profile renaming buttons
-- Import/Export profiles buttons as codes. Use this for backups or.. whatever else. Idk it was requested.
- Existing legacy profiles are automatically migrated to the new system
- If using multiple of the previous profiles, they will all be migrated as seperate profiles. Might wanna rename them though.
### Pet Profiles
- Pet Profile support for Hunter & Warlock pets. No companions due to vanilla 1.12 limitations.
- Not SPECIFICALLY required to have them so you MIGHT be able to get some weird gimmick but like.. Companions dont have a GUID lol.
- Target a pet and go to the new profile tab, then to the pet tab on the bottom.
- Create pet profiles, assign them to multiple pets, rename the profiles, delete them, same import and export feature. Yay.
- Pets have their own profiles, descriptions, at a glance, tooltips, and targetting windows.
### Alt-Identifier for Chat
- Optional feature to set a custom identifier prefix and enable it for sleected chat types and channels.
- Might've seen someone in /rp talking with (Takoy) every time they speak? Yeah, this is that for everyone. 
- On the profiles tab. 
- Supports Guild, Officer, Party, Raid, Yell, and selected numbered channels. Certain exclusions are present, however.
- Includes an otion to automatically disable the identifier when it matches your current character name.
### Faction Identity!
- Added a Faction selection to profiles.
- Added faction visuals in the profile, tooltip, and world map markets.
- Currently 5 fations: Neutral, Alliance, Horde, Scarlet, and Scourge.
- Small icon next to faction on the profile editting page to see how your icon appears on the map.
- IC/OOC map display works with this faction system, too! Go dark grey when you're OOC.
### Icon System Expansions!
- Around 3,500 icons now! Pretty much every icon in Turtle!
- Added an alias-aware icon searching system. Got an item you like the icon of, but don't know what the icon is called? You can now search for the name of that item if you want.
- Icon selection window much bigger. And laggier. And no longer has a 200 icon limit. And it's laggy. So slow. Sorry.
- Icon additions are going to be possible going forward without breaking everyone else's addons. Yay future-proofing!
### Guild Presentation
- Added a Guild Override field so profiles can display a custom guild tag in profile and tooltip.
- Added support for marking your actual guild as IC or OOC membership.
### Target Frame & Current Mood/Status
- Added a short "currently" status line to the target display.
- When targetting yourself, this can be edited directly on the frame.
- Other players see it when they target you. Good for mood, health, etc!
### Description Upgrades
- Link support has been added to the description tab. Add a custom button to link. Art, music, carrd, etc! Be creative!
-- Note that linking to NSFW content on your profile violates ToS, even if profile is marked as NSFW.
- Description formatted expanded and polished a bit. Actual line breaks now, yay!
### New RP Preference Options
- Added a new Combat selection to your rp preference tab.
- Expanded options for the others as well.
- If you select do not show, it will actually not show on your profile instead of just saying "Do not show". That was a weird one. Why have both no and do not show? 
### Tooltip Controls
- Added asetting to disable all TurtleRP Tooltips.
- Added a setting to automatically disable TurtleRP tooltips in battlegrounds. Didn't test in the arena but the others work!
- You can now also **hold the Alt key** to temporarily supress the TurtleRP tooltip. Cool!
### Map Improvements
- Left click a map icon to view a profile, or right click to open the chat menu. Neat.
- If two+ icons are overlapping, right click will let you pick which you want to select.
### Fixes and Polish
-Tons of things I noticed that I didn't even write down. Whatever.
- Actual addon version detection and outdated-version warnings.
- Fixed multiple tooltip issues, like some lingering/duplicate visuals and stability. Much more consistent now 
- Titles field is much, much longer. Enjoy.
- In preparation for the above, there's a ton of text wraps built into the tooltips now so they dont get as wide as your screen.
- Also wraps on profiles. So pretty and readable..
- Status bars on tooltips that match class_color!
- Fixed several frame/state issues around profile switching, admin UI behavior, and save-state handling.
- Fixed a ton of nil/blank data cases.
- Minimap Icon is much more stable now too.
- General hardening and cleanup. 
- Lots of little easter eggs!

---
### To Do

Bugs
- There will CERTAINLY be bugs with such a massive update. Please report them on github, or on discord.

Minor Bugs
- Color pick is sometimes connected to other color picker instances
- Admin screen looks kinda funny on non 16:9
- Dev: There are pretty much no devnotes in any of my commitments besides my notes in the actual code. If you had anything you wanted to contribute anyways, so much of the base addon has changed that it probably isn't even compatible. lol. sorry. Message me on discord though!

To Do
- Companions profiles, if I can ever figure them out.
- Color compatability for descriptions.

---

### Recently Done

2.0.3
Mainly some adjustments to chat throttling issues.
- Renamed **Neutral** to **Independent** in faction selection.
- Not ever single beast/critter/etc sends a data request to /ttrp now. 
- Cooldowns on requesting the same information from the same player. 
- No more requesting information from yourself.
- Adjusting formatting on Admin panel for non 16:9 formats.
- Changed color of link button in description to make it more obvious when someone has one.

2.0.2
- Tooltips are fixed. No more yellow names or pfquest funny business.
- Minimap Icon no longer jumps around. new command to reset position, /ttrp minimapreset (or /ttrp mmreset)
- Chatbox is back. Oops, it was deleted entirely last time.
- NSFW Warning is more forgiving now. Apparently not everyone on the internet uses the word 'feet' in inappropriate ways. Blame the imperials.
- Profiles can now be opened from the map screen on Non-PFUI setups
- Player name on emotes without RP color or name on are properly orange instead of white

2.0.1
- Fixed bug causing chat windows to load incorrectly due to addon loading before blizzard chat.
- Fixed bug with the icon scroll window getting stuck. Ever so slightly less laggy too.

1.3.4
This is almost entirely under-the-hood stuff.
- **Syntax errors not allowing the addon to load based on your other addons has been properly fixed. I hope.**
- More improvements to the directory system to reduce lag.
- Cleaned up how icon previews work in the admin panel, and the at a glance icons.
- Some small internal improves on tooltip handling.
- **Properly detects when you're running an outdated version now.**
- You'll receive a message if a newer version is detected. Only sends once per session to avoid spam.
- Removed duplicate and redundant logic all of the place. Too many cooks.
- Improved some internal consistency to make my job easier in the future.
- Cleaned up RP Mode stuff. Does anyone even use this feature?

**Known Issues**
- (1.3.2) Very niche case: If you previously used both old note systems on yourself, in admin and in the saved profile, it may appear that the saved profile one has "overwritten" the old notes. The old notes are still saved in your profile lua. I have a data migration set up to sync everything, but if both fields were filled, it does not "replace" one, only changes which is displayed. You may want to manually clean it up if you really care.

1.3.3

- **Added a Disable RP Color setting**
- This has been seperated into RP Names and RP Color in the settings menu now.
- You can ALSO disable it for individual characters by opening their profile and going to the notes section. Sorry scarlet RPers, everyone complained about your dark red names.
-- **Massive Directory Rework!**
- Almost the entire directory has been rewritten.
- New internal sorting flow.
- **Hide offline toggle at the botom.**
- Live filtered results with an accurate counter on the bottom
- Better handling for sorting as a whole.
- Automatic database cleaning on load- I have no lag issues but please report any to me.
-- **Several various "emergency" bug fixes - thank you for the feedback!**
- Fixed the emote override with | note removing names after a /e
- Fixed login error popup when logging in without pfui
- Added class token (blizzard_raid_colors) for when RP colors are off
- Cleaned up several nil/state edge cases.

1.3.2

- **Profile Preview Button added!**
- While editting your profile, you may click the preview button to see a 'live' version of it without saving.
- Pressing esc key on a textbox now properly exits the textbox entry.
- **New Unsaved Changes warning popup when attempting to exit or esc from a menu where you can unsaved changes, instead of just silently losing everything.**
- Big HTML system overhaul in the description tab. Should work consistently now, and included formatting buttons for everyone to try out.
-- **Short Notes added!**
- This is a small personal note above the locally saved "notes" section when viewing a profile.
- It's all locally saved only. Recommend like, a tiny description of the character or a relationship to know if you've met them before.
- Short Note appears as a category to view in the directory. Filtering/sorting coming at a later date.
- Notes are properly synced now. Previously, you could have both notes for yourself in your admin/edit window, and in your live profile. Now it is shared and you may edit either field.
-- **Auto Disable Location Sharing while PvP flagged setting.**
- The previous setting of disabled in battlegrounds didn't actually work at all. This replaces that and will automatic stop pinging your location once you are pvp flagged, and will go back to whatever setting you had after you are unflagged.
- I understand the desire for disabling tooltips while in battlegrounds, but at the moment because of how they are saved, it will not be possible. Another thing for a future rewrite.
-- **RP Names and Title added to emotes!**
- /e (also known as /emote or /me) now automatically sends the emote with the Title and Full Name of the emoter.
- You may still do /e | to send without any name preface at all
- Added an "Include Name before Emote" toggle to the emote section of the turtle chatbox. Does what it says on the tin.
-- **Right Click in chat now has a View TurtleRP Profile button.**
- This will return no profile if they do not have TRP.
- Shift clicking the name will also now show the player name/ign in addition to the RP Name.
-- **Various Small System Changes. Much smoother overall now.**
- Fixed the bug where profile tabs would sometimes overlap/double display when receiving new data.
- Fixed several crashes regarding attempting to read blank information.
- Fixed Reset Tray Position button sometimes not appearing.
- Fixed some of the tooltips in the icon tray to properly display.
- Renamed "Open Main Window" in icon tray to "Profile & Settings"
- Implemented a version checker to send a notification when you have an out of date TurtleRP build. Sadly this is only going foward so please help out by informing people to update!
- The goal of the version check is that, with it, we can eventually have enough people on this build that we can start implementing more icons!
- Clean-up of lots of... questionable logic. Making thing smoother.

1.3.1
- Added player name section when shift-clicking a name in chat.
- Debounced search in directory. Updates 1.5 seconds after typing. Much smoother than enter but enter does still work.
- Directory now only refreshes when receiving new data, and only searches for new data every 11 seconds. Should be less laggy but please submit your feedback!
- Fixed bug of directory not searching for player_name and only searching in profiles already downloaded.
- Messages in /rp automatically add the player_name to the local database for the directory, even if they are in the download queue, just to allow for instant searching in the directory.
- Queue system for downloading profiles from /rp. Prevents a small bit of chat throttle, but still an issue. Oh well.

**1.3.0**
-- **Character Name & Color now appear in chat windows!**
- This may be toggled on and off in the settings.
-- **A brand new Title field has been added!**
- No more long names. Titles appear before the name in the profile and the tooltip, but do not appear in chat.
-- **TurtleRP Map Icons now display IC/OOC!**
- Green icons if someone is IC, the old Grey/Purple is they are OOC. Make sure to start using your toggles!
- Upon reaching Level 10, or logging in for the first time, a popup will appear prompting user to join the /rp chat channel.
- Name 'usertag' in /rp (the bot we use in the Nordanaar RP discord!) no longer appears before message, only the discord handle.
- Small bug fix regarding Alah'Thalas map tracking variable
- Restructing of a lot of the Directory. Much smoother experience now, with auto updating when receiving new data.
- Downloads ttrp profiles when someone sends a message in /rp. Gotta be in /rp, of course. If their name comes through as their IGN for the first message, next message should show the actual profile.
- Dev badge added. Say hi if you see me.
1.2.2
- Extended Chatbox that allows messages past the 255 character limit now supports PARTY /p and RAID /r
- Fixed bug where map dots would not appear in Ironforge.

1.1.1

- Directory, when ordered, now snaps user back to the top of the scrollbar
- Descriptions should all be properly scrollable (probably even too long, now)
- Show player name in minimap hover if no full name is present
- Lua error from hovering on players on map solved
- Description tab should always show as active after being clicked
- Descriptions properly fetched when description open after directory click

1.1.0

- Directory layout and scroller
- Showing online/offline status
- Correcting issues with missing line breaks in non-HTML descriptions (?)
- Ability to query mouseover (two second delay between requests required, possible bug as well)
  - Can't show guild
- /ttrp dir or /ttrp directory opens directory
- New buttons added to the tray (directory, helm, cloak)
- Click on header columns to sort
- Type into bottom search to filter by full name or player name
- Selection between Zone and Character Name listing, both sortable
- Sending zone along with ping
- Find other RPers on a map when entering a zone (must be in the zone, updated every 30 sec)
- Permissions for sharing exact location with other players
- Improving chat error catching
  - Confirmation required when sending any emote with odd "s (long or short form)
- Version tracker (chat message and note in admin panel)
- Resetting defaults on tooltip mouseovers (PFUI issue with sticking icon + font size)
- Revised Description window, more in line with WoW interface
- Description panel now Profile window, has Mouseover and Target information as well
- Ability to select and fetch in directory, delete in directory
- Clicking in directory opens new Profile window
- Personal notes now collected in Profile window
- Ability to set RP Style in Admin Profile RP Style tab
- RP style shows in Profile window

Beta fixes
- Removing any quotation verification from chat-line emote; only present on chat box emote verification
- Otherwise, chat line emotes are reset with every press so errors do not continue after typos
- No validation error should appear for other players anymore
- NOTE: if a link is included in the text, and you are using Shagu / PFUI, the text will be mis-formatted because Shagu adds a white color after a link
- Validation checking for "~", "°", or "§" in any saved text
- No longer possible to save characters above, so users should never see them in their own profile (requires a new save to validate, will not work if user already has these characters in the profile)
- "%" character now allowed in emotes
- Hiding map icons correctly when changing frames on world map
  - TEST: possible error with characters on different continents, then moving back to your own continent, players misaligned on map
- Removed edges from Dark UI Description
- Titles on descriptions no longer replaced when new "Glances" open
- Data "sends" will now use "p" as the character name (just a placeholder for 'player'); using message sender instead, more reliable
- Mechanisms for cleaning directory (removing players with bad characters)
- Mechanism to delete single player from directory (manually remove characters as desired)

1.0.1 (not released)

- No more drunk texting
- TurtleRP_ChatBox now visible in RP mode
- Longer description
- Longer notes

1.0.0 same as 0.1.4

0.1.4

- Minor fix to highlighted icon when opening admin
- Storing script and redoing on world frame (focus clear)
- Prevent messages sending when under level 5, or when AFK
- Fix to scrolling description frame
- Fix to target and wrong name appearing when message sent in chat bug

0.1.3

- Name fields combined into one
- Custom class color
- Custom class
- Custom race
- Improved communication to allow multiple message chaining in the future for all fields
- New field limits for mouseover responses:
  - Full name : 50
  - IC and OOC info: 75 each
  - Pronouns: 10 each
  - Class : 15
  - Race : 20
  - Class color : 6
  - Icon : 4 (internal)
  - IC/OOC : 1
  - Internal: Prefix 3, name 12, key 5, delimiter 10 (?)
  - TOTAL MAX : just under 300 . Lots of room for more'
- New comms system should allow full lengths on At A Glance descriptions
- Changed IC/OOC from "on" vs "off" to 0 vs 1
- Change delimiter to ~ instead of && (fewer characters) -- breaking change, old versions and new versions can't communicate
- Change validator to prevent use of ~ in saved text
- When minimap icon dragged, no longer pops admin panel
- Pipe character (|), when first character of an emote, will remove the character name from the emote text
- Icon Tray
  - Moveable by drag
  - RP button on/off
  - IC button on/off
  - /c chatbox opener
  - Admin button opener
- Chatbox v1
  - click in box/out for focus management
  - Selection of Yell, Emote, Say
  - Emote never uses username
  - Quotation color retained on long form quotes broken by multiple lines
  - Special emote chat now showing on all frames with SAY
  - Text clears after sending
- Setting to change size of name
- Minimap icon size options
- Open to show/hide tray
- Fix icon placement on PFUI spellbook
- Changing /c to dialog icon
- Removed extra space added to front of | emote (space still required
- Setting to hide/show minimap icon
- Icon for TurtleRP switched to mini turtle
- Issue with item comparison fixed PFUI

0.1.2

- // Description box should no longer get cut off
- // Emotes now show "Quotations in White"
- // When a player is ??, tooltip shows -1
- // Improved pinging system
- // More legit resetting of font sizes in tooltip
- // Integrated with Shagu darkmode
- // Guild rank integrated into tooltip
- // Tooltip layout integrated with PFUI
- // Target removed when targetting a player after targetting self
- // Showing version number in ? section
0.1.1
- // New Spellbook UI
- // Implementing a Test channel for future dev changes
- // Not allowing "&&" characters in any saved text
- // Better validation on recieving data
- // Adding discord link to the About section
- // Having a "clear cache" button or something
- // Manually rejoining channel issue
- // Filter icon bug when scrolled fast to end
- // Tooltip ALL lines need resetting (ie, lines 4-5-6)
- // Tooltip "already equipped" issue of not disappearing
- // Some more validation on chat messages
- // 30s ping and announcement system to prevent chat spam
- // Proper chat throttling via ChatThrottleLib
- // Refactor into components and scripts, using XML more effectively
- // "RP Mode" like IRP, turning off all frames except chat
- // 1000+ character descriptions getting cut off in scrollbar
- // Fix with wrong icons being selected when filtering
- // Refactoring tooltip generation to be robust
- // Tooltips are missing health bar underneath
- // Adding a "notes" section
- // Limiting description to 2000 characters
- // Adding a text input for quickly searching through icons
- // Adding icon to the frame
- // Changing icon on website to Turtle icon, adding link to the Discord
- // Testing channel being joined properly
- // Fixing sometime disappearance of tooltip
- // description autopops when clicked by another
- // adding pronouns and adding that beside the IC / OOC
- // Passing through HTML for the Description
