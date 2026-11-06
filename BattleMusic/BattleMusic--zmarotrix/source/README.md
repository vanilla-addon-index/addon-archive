# BattleMusic
A Vanilla (1.12) addon to play music in combat. Automatically starts and stops with combat. Any mp3 should be supported. 

Music will be randomized at the start of combat. Put your .mp3 files into th `Interface\AddOns\BattleMusic\music\` folder and run the `Update Playlist.bat`. 
By default, this addon will do nothing but remind you to add music. 

### Video of the addon in action  (Outdated)
https://www.youtube.com/watch?v=YXQPcDtmPDo

## Instructions:

### Config Menu (Open by typing "/bmusic")
![image](https://github.com/user-attachments/assets/7964eee1-bb7d-4ed5-92aa-38b0b912add3)

Open by typing "/bmusic"  

  
### Install AddOn:
- [Download the addon](https://github.com/zmarotrix/BattleMusic/releases/tag/Publish)
- Unpack the file into `World of Warcraft\Interface\AddOns`
- Rename the folder "BattleMusic-master" to "BattleMusic" if needed

### Add music:
- Go into the AddOn's folder "BattleMusic" and then into "music"
- Place your .mp3 files here. No renaming required
- Run `Update Playlist.bat` in the music folder
- Launch World of Warcraft

### Change linger timer [DISABLED]:
- Type "/script battleMusic.linger=NUMBER" and replace NUMBER with the lingering you want in seconds.  
Example: /script battleMusic.linger=15.5

## My Changes
I've rewritten most of the functionality of this addon to make it more relaible and fix some bugs. I've focused on making this addon as easy to setup as possible with the new Batch file included.

Song lingering has been disabled for the moment because I could not get it working. I've left my attempt in the main lua file for review. If someone wants to submit a PR to fix it, be my guest. 
