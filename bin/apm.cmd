@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\..\apm\bin\apm" %*
) ELSE (
  node  "%~dp0\..\apm\bin\apm" %*
)
