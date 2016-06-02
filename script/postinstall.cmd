@echo off
setlocal EnableDelayedExpansion
setlocal EnableExtensions

cd build
for /f "delims=" %%i in ('node.exe -v') do set systemVersion=%%i
echo ^>^> Installing build dependencies with Node !systemVersion!
call npm install

cd ..
echo ""
for /f "delims=" %%i in ('.\bin\node.exe -v') do set bundledVersion=%%i
echo ^>^> Installing apm dependencies with bundled Node !bundledVersion!
call .\bin\npm install
