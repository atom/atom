@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe" "%~dp0/../lib/cli.js" %*
) ELSE (
  node.exe "%~dp0/../lib/cli.js" %*
)
