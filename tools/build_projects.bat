@echo off
set RC=
setlocal

if "%1" == "" (
echo ERROR: Please specify a build target: Debug or Release
set ERRORLEVEL=1
goto end
)

if "%2" == "" (
set PROJECT_NAME=cefclient
) else (
set PROJECT_NAME=%2
)

echo Configuring Visual Studio environment...
if "%GYP_MSVS_VERSION%" == "2008" (
call "%VS90COMNTOOLS%vsvars32.bat"
set PROJECT_EXT=.vcproj
) else (
call "%VS100COMNTOOLS%vsvars32.bat"
set PROJECT_EXT=.vcxproj
)

if exist "%DevEnvDir%\devenv.com" (
echo Building %1 target for %PROJECT_NAME% project...
"%DevEnvDir%\devenv.com" /build %1 ..\cef.sln /project %PROJECT_NAME%%PROJECT_EXT%
) else if exist "%VCINSTALLDIR%\vcpackages\vcbuild.exe" (
echo Building %1 target for all projects...
"%VCINSTALLDIR%\vcpackages\vcbuild.exe" ..\cef.sln "%1|Win32"
) else (
echo ERROR: Cannot find Visual Studio builder
set ERRORLEVEL=1
)

:end
endlocal & set RC=%ERRORLEVEL%
goto omega

:returncode
exit /B %RC%

:omega
call :returncode %RC%
