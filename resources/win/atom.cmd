@echo off

SET EXPECTOUTPUT=

FOR %%a IN (%*) DO (
  IF /I "%%a"=="-h"           SET EXPECTOUTPUT=YES
  IF /I "%%a"=="--help"       SET EXPECTOUTPUT=YES
  IF /I "%%a"=="-v"           SET EXPECTOUTPUT=YES
  IF /I "%%a"=="--version"    SET EXPECTOUTPUT=YES
  IF /I "%%a"=="-f"           SET EXPECTOUTPUT=YES
  IF /I "%%a"=="--foreground" SET EXPECTOUTPUT=YES
  IF /I "%%a"=="-w"           SET EXPECTOUTPUT=YES
  IF /I "%%a"=="--wait"       SET EXPECTOUTPUT=YES
)

IF "%EXPECTOUTPUT%"=="YES" (
  "C:\Users\kevin\AppData\Local\atom\app-0.156.0\atom.exe" %*
) ELSE (
  node "%~dp0\atom.js" "C:\Users\kevin\AppData\Local\atom\app-0.156.0\atom.exe" %* --executed-from=%CD%
)
