#!/bin/sh

while getopts ":fhtvw-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        wait)
          WAIT=1
          EXPECT_OUTPUT=1
          ;;
        help|version)
          REDIRECT_STDERR=1
          EXPECT_OUTPUT=1
          ;;
        foreground|test)
          EXPECT_OUTPUT=1
          ;;
      esac
      ;;
    w)
      WAIT=1
      EXPECT_OUTPUT=1
      ;;
    h|v)
      REDIRECT_STDERR=1
      EXPECT_OUTPUT=1
      ;;
    f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

directory=$(dirname "$0")

if [ $EXPECT_OUTPUT ]; then
  export ELECTRON_ENABLE_LOGGING=1
  if [ $WAIT == 'YES' ]; then
    powershell -noexit "%~dp0\..\..\atom.exe" --pid=$pid "$@" ; 
wait-event
  else
    "$directory/../../atom.exe" "$@"
  fi
else
  "$directory/../app/apm/bin/node.exe" "$directory/atom.js" "$@"
fi
