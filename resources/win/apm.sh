#!/bin/sh

directory=$(dirname "$0")
"$directory/../app/apm/bin/node.exe" "$directory/../app/apm/lib/cli.js" "$@"
