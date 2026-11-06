@echo off
echo ============================================================
echo  Relationships Jukebox - Playlist Generator
echo ============================================================
echo.

REM Pass any command-line arguments (e.g. -UseWinRAR) to the PS1 script
powershell -ExecutionPolicy Bypass -File "%~dp0GeneratePlaylist.ps1" %*

echo.
pause
