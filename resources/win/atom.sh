#!/bin/sh

while getopts ":fhtvw-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        foreground|help|test|version|wait)
          EXPECT_OUTPUT=1
        ;;
      esac
      ;;
    f|h|t|v|w)
      EXPECT_OUTPUT=1
      ;;
  esac
done

directory=$(dirname "$0")

if [ $EXPECT_OUTPUT ]; then
  "$directory/../../atom.exe" "$@"
else
  "$directory/../app/apm/bin/node.exe" "$directory/atom.js" "$@"
fi
