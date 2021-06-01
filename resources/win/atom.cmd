@echo off

SET EXPECT_OUTPUT=
SET WAIT=
SET PSARGS=%*
SET ELECTRON_ENABLE_LOGGING=
SET ATOM_ADD=
SET ATOM_NEW_WINDOW=

FOR %%a IN (%*) DO (
  IF /I "%%a"=="-f"                         SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--foreground"               SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-h"                         SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--help"                     SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-t"                         SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--test"                     SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--benchmark"                SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--benchmark-test"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-v"                         SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--version"                  SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--enable-electron-logging"  SET ELECTRON_ENABLE_LOGGING=YES
  IF /I "%%a"=="-a"                         SET ATOM_ADD=YES
  IF /I "%%a"=="--add"                      SET ATOM_ADD=YES
  IF /I "%%a"=="-n"                         SET ATOM_NEW_WINDOW=YES
  IF /I "%%a"=="--new-window"               SET ATOM_NEW_WINDOW=YES
  IF /I "%%a"=="-w"           (
    SET EXPECT_OUTPUT=YES
    SET WAIT=YES
  )
  IF /I "%%a"=="--wait"       (
    SET EXPECT_OUTPUT=YES
    SET WAIT=YES
  )
)

IF "%ATOM_ADD%"=="YES" (
  IF "%ATOM_NEW_WINDOW%"=="YES" (
    SET EXPECT_OUTPUT=YES
  )
)

IF "%EXPECT_OUTPUT%"=="YES" (
  IF "%WAIT%"=="YES" (
    powershell -noexit "Start-Process -FilePath \"%~dp0\..\..\<%= atomExeName %>\" -ArgumentList \"--pid=$pid $env:PSARGS\" ; wait-event"
    exit 0
  ) ELSE (
    "%~dp0\..\..\<%= atomExeName %>" %*
  )
) ELSE (
  "%~dp0\..\app\apm\bin\node.exe" "%~dp0\atom.js" "<%= atomExeName %>" %*
)
