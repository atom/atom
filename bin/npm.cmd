@echo off
setlocal

set PATH=%~dp0;%PATH%
set npm_config_node_gyp=%~dp0;\..\node_modules\.bin\node-gyp
.\node_modules\.bin\npm.cmd %*
