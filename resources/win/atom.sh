#!/bin/bash
# Get current path in Windows format
if command -v "cygpath" > /dev/null; then
  # We have cygpath to do the conversion
  ATOMCMD=$(cygpath "$(dirname "$0")/atom.cmd" -a -w)
else
  pushd "$(dirname "$0")" > /dev/null
  if [[ $(uname -r) == *-Microsoft ]]; then
    # We are in Windows Subsystem for Linux, map /mnt/drive
    ATOMCMD="$(echo $PWD | sed 's/\/mnt\/\([a-z]*\)\(.*\)/\1:\2/')/atom.cmd"
    ATOMCMD="${ATOMCMD////\\}"
  else
    # We don't have cygpath or WSL so try pwd -W
    ATOMCMD="$(pwd -W)/atom.cmd"
  fi
  popd > /dev/null
fi
if [ "$(uname -o)" == "Msys" ]; then
  cmd.exe //C "$ATOMCMD" "$@" # Msys thinks /C is a Windows path...
else
  cmd.exe /C "$ATOMCMD" "$@" # Cygwin does not
fi
