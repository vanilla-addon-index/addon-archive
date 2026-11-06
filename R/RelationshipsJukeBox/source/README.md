<img src="https://i.postimg.cc/Wb6XLr2N/llll.png"/>

<img src="https://i.postimg.cc/xTytDH96/I.gif"/>


# Relationships Jukebox

**Relationships Jukebox** is a lightweight World of Warcraft music addon that lets you play your own local audio files in-game through a full playlist window, a compact mini player, and simple slash commands.

The addon scans a local `Media` folder, builds a playlist automatically, and lets you search, play, shuffle, skip, stop, and manage tracks without leaving the game.

## Features

- Supports **MP3**, **WAV**, and **OGG** files
- Full in-game playlist browser with paged track list
- **Search** box for quickly filtering tracks
- **Play**, **Play All**, **Shuffle**, **Skip**, **Previous**, and **Stop** controls
- Compact **Mini Player** for use during gameplay
- **Minimap button**
  - **Left-click:** Toggle Mini Player
  - **Right-click:** Toggle Full GUI
- Automatically imports tracks from `AutoPlaylist.lua`
- Stores track names and durations for smoother autoplay and shuffle playback
- Attempts to improve MP3, WAV, and OGG compatibility by sanitizing problematic files during playlist generation
- Works without metadata by falling back to estimated durations

## Installation

1. Extract the addon into your WoW `Interface\AddOns` folder.
2. Make sure the folder name is exactly:

   ```text
   RelationshipsJukeBox
   ```

3. Place your music files inside:

   ```text
   Interface\AddOns\RelationshipsJukeBox\Media
   ```

4. Run:

   ```text
   GeneratePlaylist.bat
   ```

5. Start or reload the game:

   ```text
   /reload
   ```

## Supported Formats

The addon scans the `Media` folder recursively for:

- `.mp3`
- `.wav`
- `.ogg`

## How Playlist Generation Works

The addon does not scan the `Media` folder directly in-game. Instead, it uses a generated file named:

```text
AutoPlaylist.lua
```

`GeneratePlaylist.bat` launches the PowerShell generator, which:

- scans the `Media` folder for supported audio files
- creates or updates `AutoPlaylist.lua`
- captures track names
- tries to determine durations
- checks MP3, WAV, and OGG files for WoW 1.12 compatibility issues
- optionally uses `ffmpeg` / `ffprobe` for better metadata and MP3, WAV, and OGG sanitization

After generating the playlist, use `/reload` so the addon can import the updated track list.

## ffmpeg / 7-Zip / WinRAR Notes

The playlist generator is designed to be friendly on Windows:

- If `ffmpeg` and `ffprobe` are already installed, it will use them
- If not, the script can attempt to **auto-download ffmpeg** into a local `ffmpeg` folder inside the addon
- If `.7z` extraction is needed, it can use **7-Zip** or **WinRAR**
- You can run the batch file with:

  ```text
  GeneratePlaylist.bat -UseWinRAR
  ```

  to prefer WinRAR for archive extraction

If ffmpeg is unavailable, the generator can still build a playlist using estimated durations, but some MP3 files may not play correctly in WoW 1.12.

## In-Game Controls

### Main Window

The main window includes:

- search field
- Search / Clear buttons
- per-track Play and Remove buttons
- playback controls for playlist mode
- page navigation
- status messages

### Mini Player

The mini player provides quick access to:

- Previous
- Stop
- Next
- Open full GUI
- current track display

### Minimap Button

- **Left-click:** Toggle Mini Player
- **Right-click:** Toggle Full GUI

## Slash Commands

```text
/rjukebox play
/rjukebox shuffle
/rjukebox stop
/rjukebox skip
/rjukebox prev
/rjukebox pause
/rjukebox mini
```

Short alias:

```text
/rj
```

## Typical Usage

1. Put music into the `Media` folder
2. Run `GeneratePlaylist.bat`
3. Log in or type `/reload`
4. Open the addon window
5. Search for a song or press **Play All** / **Shuffle**
6. Use the mini player while you play

## Track Names

The addon automatically cleans display names for the UI by removing things like:

- leading track numbers
- file extensions
- extra underscores or separators

This helps filenames display more like song titles in the playlist.

## Remove Button Behavior

The **Remove** button removes a track from the addon's saved playlist database.

Important: if the audio file still exists in the `Media` folder and is still included in `AutoPlaylist.lua`, it can be imported again the next time you regenerate the playlist or reload the addon.

## Troubleshooting

### No tracks appear in-game

- Confirm your files are inside `RelationshipsJukeBox\Media`
- Run `GeneratePlaylist.bat`
- Make sure `AutoPlaylist.lua` was created
- Use `/reload`

### Some MP3, WAV, and OGG files do not play

WoW 1.12 can be picky about MP3, WAV, and OGG encoding. Re-run the generator and let it sanitize files if `ffmpeg` is available.

### Durations seem wrong

If metadata cannot be read, the generator falls back to estimated/default durations.
Installing ffmpeg improves duration detection.

### The generator cannot extract ffmpeg

Install one of the following:

- **7-Zip**
- **WinRAR**
- or manually place `ffmpeg.exe` and `ffprobe.exe` in:

  ```text
  RelationshipsJukeBox\ffmpeg
  ```

## Credits

Author: **Relationship**
