@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\bootstrap" %*
) ELSE (
  node  "%~dp0\bootstrap" %*
)

