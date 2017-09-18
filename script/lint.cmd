@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\lint" %*
) ELSE (
  node  "%~dp0\lint" %*
)
