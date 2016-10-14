@echo off

SET EXPECT_OUTPUT=
SET WAIT=
SET PSARGS=%*

FOR %%a IN (%*) DO (
  IF /I "%%a"=="-f"               SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--foreground"     SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-h"               SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--help"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-t"               SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--test"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--benchmark"      SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--benchmark-test" SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-v"               SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--version"        SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-w"           (
    SET EXPECT_OUTPUT=YES
    SET WAIT=YES
  )
  IF /I "%%a"=="--wait"       (
    SET EXPECT_OUTPUT=YES
    SET WAIT=YES
  )
)

IF "%EXPECT_OUTPUT%"=="YES" (
  SET ELECTRON_ENABLE_LOGGING=YES
  IF "%WAIT%"=="YES" (
    powershell -noexit "Start-Process -FilePath \"%~dp0\..\..\atom.exe\" -ArgumentList \"--pid=$pid $env:PSARGS\" ; wait-event"
    exit 0
  ) ELSE (
    "%~dp0\..\..\atom.exe" %*
  )
) ELSE (
  "%~dp0\..\app\apm\bin\node.exe" "%~dp0\atom.js" %*
)
