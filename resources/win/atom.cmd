@echo off

SET EXPECT_OUTPUT=
SET WAIT=

FOR %%a IN (%*) DO (
  IF /I "%%a"=="-f"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--foreground" SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-h"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--help"       SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-t"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--test"       SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-v"           SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="--version"    SET EXPECT_OUTPUT=YES
  IF /I "%%a"=="-w"           (
    SET EXPECT_OUTPUT=YES
    SET WAIT=YES
  )
  IF /I "%%a"=="--wait"       (
    SET EXPECT_OUTPUT=YES
    SET WAIT=YES
  )
)

rem Getting the process ID in cmd of the current cmd process: http://superuser.com/questions/881789/identify-and-kill-batch-script-started-before
set T=%TEMP%\atomCmdProcessId-%time::=%.tmp
wmic process where (Name="WMIC.exe" AND CommandLine LIKE "%%%TIME%%%") get ParentProcessId /value | find "ParentProcessId" >%T%
set /P A=<%T%
set PID=%A:~16%
del %T%

IF "%EXPECT_OUTPUT%"=="YES" (
  SET ELECTRON_ENABLE_LOGGING=YES
  IF "%WAIT%"=="YES" (
    "%~dp0\..\..\atom.exe" --pid=%PID% %*
    rem If the wait flag is set, don't exit this process until Atom tells it to.
    goto waitLoop
  ) ELSE (
    "%~dp0\..\..\atom.exe" %*
  )
) ELSE (
  "%~dp0\..\app\apm\bin\node.exe" "%~dp0\atom.js" %*
)

goto end

:waitLoop
  sleep 1
  goto waitLoop

:end
