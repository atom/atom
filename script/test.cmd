@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\test" %*
) ELSE (
  node  "%~dp0\test" %*
)
