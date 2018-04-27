@echo off

IF "%ATOM_HOME%"=="" SET ATOM_HOME=%USERPROFILE%\.pros-atom
"%~dp0\..\app\apm\bin\apm.cmd" %*
