@echo off
setlocal

set PATH=%~dp0;%PATH%
.\node_modules\.bin\npm.cmd %*
