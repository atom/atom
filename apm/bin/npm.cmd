@echo off
setlocal EnableDelayedExpansion

set "PATH=%~dp0;%PATH%"
set maybe_node_gyp_path=%~dp0\..\node_modules\node-gyp\bin\node-gyp.js
if exist %maybe_node_gyp_path% (
  set npm_config_node_gyp=%maybe_node_gyp_path%
)
%~dp0\..\node_modules\.bin\npm.cmd %*
