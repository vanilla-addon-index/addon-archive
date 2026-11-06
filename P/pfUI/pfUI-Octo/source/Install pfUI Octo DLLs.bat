@echo off
title pfUI Octo: install / update the client DLLs
echo Installs or updates the newest ClassicAPI, SuperWoW, nampower, UnitXP_SP3 and WeirdUtils (without its performance module)
echo from their authors' release pages. pfUI Octo works without them - they make it better.
echo Close the game first if it is running.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\install_dlls.ps1"
echo.
pause
