@echo off

SET EXPECT_OUTPUT=

FOR %%a IN (%*) DO (
  IF /I "%%a"=="-h"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--help"       SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-v"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--version"    SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-f"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--foreground" SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-w"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--wait"       SET EXPECT_OUTPUT=YES
)

SET ATOM_COMMAND="%~dp0\..\atom.exe"
SET NODE_COMMAND="%~dp0\..\resources\app\apm\node_modules\atom-package-manager\bin\node.exe"

IF "%EXPECT_OUTPUT%"=="YES" (
  "%ATOM_COMMAND%" %*
) ELSE (
  "%NODE_COMMAND%" "%~dp0\atom.js" "%ATOM_COMMAND%" %* --executed-from=%CD%
)
