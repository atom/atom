@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\..\bin\apm" %*
) ELSE (
  node "%~dp0\..\bin\apm" %*
)
