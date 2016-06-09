@echo off
set maybe_node_gyp_path=%~dp0\..\node_modules\.bin\node-gyp
if exist %maybe_node_gyp_path% (
  set npm_config_node_gyp=%maybe_node_gyp_path%
)

@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe" "%~dp0/../lib/cli.js" %*
) ELSE (
  node.exe "%~dp0/../lib/cli.js" %*
)
