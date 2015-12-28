@echo off

SET EXPECT_OUTPUT=

FOR %%a IN (%*) DO (
  IF /I "%%a"=="-f"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--foreground" SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-h"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--help"       SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-t"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--test"       SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-v"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--version"    SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-w"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--wait"       SET EXPECT_OUTPUT=YES
)

IF "%EXPECT_OUTPUT%"=="YES" (
  SET ELECTRON_ENABLE_LOGGING=YES
  "%~dp0\..\..\atom.exe" %*
) ELSE (
  "%~dp0\..\app\apm\bin\node.exe" "%~dp0\atom.js" %*
)
