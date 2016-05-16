#!/bin/sh
pushd "$(dirname "$0")" > /dev/null
if command -v "cygpath" > /dev/null; then
  ATOMCMD=""$(cygpath . -a -w)atom.cmd""
else
  ATOMCMD=""$(pwd -W)/atom.cmd""
fi
popd > /dev/null
cmd.exe //c "$ATOMCMD" "$@"
