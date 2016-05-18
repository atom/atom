#!/bin/sh
if command -v "cygpath" > /dev/null; then
  ATOMCMD=""$(cygpath "$(dirname "$0")" -a -w)\\atom.cmd""
else
  pushd "$(dirname "$0")" > /dev/null
  ATOMCMD=""$(pwd -W)/atom.cmd""
  popd > /dev/null
fi
cmd.exe /C "$ATOMCMD" "$@"
