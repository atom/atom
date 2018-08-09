@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\dev" %*
) ELSE (
  node  "%~dp0\dev" %*
)
