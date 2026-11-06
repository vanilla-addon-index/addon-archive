@echo off

:: Clear the existing playlist.txt 
type nul > playlist.txt

:: Loop through all MP3 files in the current directory
for %%f in (*.mp3) do (
    :: Append the filename enclosed in quotes to playlist.txt 
    echo "%%~nxf">> playlist.txt

    :: Check if this is the last file in the loop
    if not "%%f" == "" (
        :: If not the last file, add a comma and newline
        echo ,>> playlist.txt
    )
)

:: Generate Lua code to populate the 'playlist' array
echo local playlist = { > ..\BattleMusic.lua.tmp
type playlist.txt >> ..\BattleMusic.lua.tmp
echo } >> ..\BattleMusic.lua.tmp

:: Find and replace the existing 'playlist' array definition in BattleMusic.lua, preserving formatting and using UTF-8 without BOM
powershell -Command "$content = (gc ..\BattleMusic.lua -Encoding UTF8) -join \"`r`n\"; $newContent = $content -replace 'local playlist[\s]*=[\s]*{[^}]*}', ((gc ..\BattleMusic.lua.tmp)); [System.IO.File]::WriteAllText('..\BattleMusic.lua', $newContent, [System.Text.Encoding]::UTF8)"

:: Clean up the temporary file
del ..\BattleMusic.lua.tmp
del playlist.txt

echo Playlist updated in BattleMusic.lua!
pause