#!/bin/bash
# Get current path in Windows format
if command -v "cygpath" > /dev/null; then
  # We have cygpath to do the conversion
  ATOMCMD=$(cygpath "$(dirname "$0")/atom.cmd" -a -w)
else
  # We don't have cygpath so try pwd -W
  pushd "$(dirname "$0")" > /dev/null
  ATOMCMD="$(pwd -W)/atom.cmd"
  popd > /dev/null
fi
if [ "$(uname -o)" == "Msys" ]; then
  cmd.exe //C "$ATOMCMD" "$@" # Msys thinks /C is a Windows path...
else
  cmd.exe /C "$ATOMCMD" "$@" # Cygwin does not
fi
