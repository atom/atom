@echo off
setlocal EnableDelayedExpansion

:: Try to find git.exe in path
for /f "tokens=*" %%G in ('where git') do set "apm_git_path=%%~dpG"
if not defined apm_git_path (
  :: Try to find git.exe in GitHub Desktop, oldest first so we end with newest
  for /f "tokens=*" %%d in ('dir /b /s /a:d /od "%LOCALAPPDATA%\GitHub\PortableGit*"') do (
    if exist %%d\cmd\git.exe set apm_git_path=%%d\cmd
  )
  :: Found one, add it to the path
  if defined apm_git_path set "Path=!apm_git_path!;%PATH%"
)

set "PATH=%~dp0;%PATH%"
set maybe_node_gyp_path=%~dp0\..\node_modules\node-gyp\bin\node-gyp.js
if exist %maybe_node_gyp_path% (
  set npm_config_node_gyp=%maybe_node_gyp_path%
)
%~dp0\..\node_modules\.bin\npm.cmd %*
