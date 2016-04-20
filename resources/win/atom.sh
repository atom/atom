#!/bin/sh
pushd $(dirname "$0") > /dev/null
ATOMCMD=""$(pwd -W)"/atom.cmd"
popd > /dev/null
cmd.exe //c "$ATOMCMD" "$@"
