@echo off
setlocal EnableDelayedExpansion
setlocal EnableExtensions

echo ^>^> Downloading bundled Node
node script/download-node.js

echo ""
for /f "delims=" %%i in ('.\bin\node.exe -v') do set bundledVersion=%%i
echo ^>^> Rebuilding apm dependencies with bundled Node !bundledVersion!
call .\bin\npm.cmd rebuild

echo ""
echo ^>^> Deduping apm dependencies
call .\bin\npm.cmd dedupe
