@echo off
rem Links each kit's Libs\KitCore folder to this KitCore folder (a directory
rem junction, no admin rights needed), so every kit loads this one copy.
rem Run it once from the KitCore folder that sits next to the kit folders.
rem Any folder next to this one whose .toc loads KitCore.lua is linked, so a
rem new kit needs no change here.
setlocal
set "CORE=%~dp0"
set "CORE=%CORE:~0,-1%"
set "FOUND="
for /d %%K in ("%CORE%\..\*") do call :link "%%~fK" "%%~nxK"
if not defined FOUND echo No kits next to KitCore load it.
pause
exit /b

:link
if /i "%~2"=="KitCore" exit /b
findstr /m /i /l /c:"KitCore.lua" "%~1\*.toc" >nul 2>&1 || exit /b
set "FOUND=1"
if not exist "%~1\Libs\" mkdir "%~1\Libs"
if exist "%~1\Libs\KitCore\" (
  echo %~2: already linked
) else (
  mklink /J "%~1\Libs\KitCore" "%CORE%"
)
exit /b
