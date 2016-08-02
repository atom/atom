@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\grunt" %*
) ELSE (
  node  "%~dp0\grunt" %*
)
