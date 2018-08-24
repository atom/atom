@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\publish-release" %*
) ELSE (
  node  "%~dp0\publish-release" %*
)
