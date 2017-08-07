@ECHO OFF
IF NOT EXIST C:\sqtemp MKDIR C:\sqtemp
SET SQUIRREL_TEMP=C:\sqtemp
script\build.cmd --existing-binaries --code-sign --create-windows-installer
