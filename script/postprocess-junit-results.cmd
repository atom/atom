@IF EXIST "%~dp0\node.exe" (
  "%~dp0\node.exe"  "%~dp0\postprocess-junit-results" %*
) ELSE (
  node  "%~dp0\postprocess-junit-results" %*
)
