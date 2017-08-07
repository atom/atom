@ECHO OFF
IF NOT EXIST C:\sqtemp MKDIR C:\sqtemp
SET SQUIRREL_TEMP=C:\sqtemp
del script\package-lock.json /q
del apm\package-lock.json /q
script\build.cmd --existing-binaries --code-sign --create-windows-installer
