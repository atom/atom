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

if [ $EXPECT_OUTPUT ]; then
  "$0/../../../atom.exe" "$@"
else
  "$0/../../app/apm/bin/node.exe" "$0/../atom.js" "$@"
fi
