@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\cibuild" %*
) ELSE (
  node  "%~dp0\cibuild" %*
)
