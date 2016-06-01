@echo off
setlocal

set PATH=%~dp0;%PATH%
.\build\node_modules\.bin\npm.cmd %*
