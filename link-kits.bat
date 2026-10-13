@echo off
rem Links each kit's Libs\KitCore folder to this KitCore folder (a directory
rem junction, no admin rights needed), so every kit loads this one copy.
rem Run it once from the KitCore folder that sits next to the kit folders.
setlocal
set "CORE=%~dp0"
set "CORE=%CORE:~0,-1%"
for %%K in (WarlockKit) do (
  if exist "%CORE%\..\%%K\" (
    if not exist "%CORE%\..\%%K\Libs\" mkdir "%CORE%\..\%%K\Libs"
    if exist "%CORE%\..\%%K\Libs\KitCore\" (
      echo %%K: already linked
    ) else (
      mklink /J "%CORE%\..\%%K\Libs\KitCore" "%CORE%"
    )
  ) else (
    echo %%K: not found next to KitCore, skipped
  )
)
pause
