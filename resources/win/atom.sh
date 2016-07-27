#!/bin/sh

while getopts ":fhtvw-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        wait)
          WAIT=1
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

WINPS=`ps | grep -i $$`
PID=`echo $WINPS | cut -d' ' -f 4`

if [ $EXPECT_OUTPUT ]; then
  export ELECTRON_ENABLE_LOGGING=1
  "$directory/../../atom.exe" --executed-from="$(pwd)" --pid=$PID "$@"
else
  cd "$directory"
  "$directory/../app/apm/bin/node.exe" "atom.js" "$@"
fi

# If the wait flag is set, don't exit this process until Atom tells it to.
if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
