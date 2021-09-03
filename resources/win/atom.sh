#!/bin/bash
# Get current path in Windows format
if command -v "cygpath" > /dev/null; then
  # We have cygpath to do the conversion
  ATOMCMD=$(cygpath "$(dirname "$0")/atom.cmd" -a -w)
  ARGS=( $(cygpath -a -w "$@" | tr '\n' ' ') ) 
else
  ARGS=$@
  pushd "$(dirname "$0")" > /dev/null
  if [[ $(uname -r) =~ (M|m)icrosoft ]]; then
    # We are in Windows Subsystem for Linux, map /mnt/drive
    root="/mnt/"
    # If different root mount point defined in /etc/wsl.conf, use that instead
    eval $(grep "^root" /etc/wsl.conf | sed -e "s/ //g")
    root="$(echo $root | sed 's|/|\\/|g')"
    ATOMCMD="$(echo $PWD | sed 's/\/mnt\/\([a-z]*\)\(.*\)/\1:\2/')/atom.cmd"
  else
    # We don't have cygpath or WSL so try pwd -W
    ATOMCMD="$(pwd -W)/atom.cmd"
  fi
  popd > /dev/null
fi

if [ "$(uname -o)" == "Msys" ] || [[ $(uname -r) == *-Microsoft ]]; then
  cmd.exe //C "$ATOMCMD" "$@" # Msys amd WSL think /C is a Windows path...
else
  cmd.exe /C "$ATOMCMD" "${ARGS[@]}" # Cygwin does not
fi
