#!/bin/sh
ATOM_PATH=${ATOM_PATH:-/Applications} # Set ATOM_PATH unless it is already set
ATOM_APP_NAME=Atom.app

# If ATOM_PATH isn't a executable file, use spotlight to search for Atom
if [ ! -x "$ATOM_PATH/$ATOM_APP_NAME" ]; then
  ATOM_PATH=$(mdfind "kMDItemCFBundleIdentifier == 'com.github.atom'" | head -1 | xargs dirname)
fi

# Exit if Atom can't be found
if [ -z "$ATOM_PATH" ]; then
  echo "Cannot locate Atom.app, it is usually located in /Applications. Set the ATOM_PATH environment variable to the directory containing Atom.app."
  exit 1
fi

while getopts ":wtfvhs-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        wait)
          WAIT=1
          ;;
        help|version|foreground|test)
          EXPECT_OUTPUT=1
          ;;
      esac
      ;;
    w)
      WAIT=1
      ;;
    h|v|f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

if [ $EXPECT_OUTPUT ]; then
  "$ATOM_PATH/$ATOM_APP_NAME/Contents/MacOS/Atom" --executed-from="$(pwd)" --pid=$$ "$@"
  exit $?
else
  open -a "$ATOM_PATH/$ATOM_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ "$@"
fi

# Exits this process when Atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until Atom tells it to.
if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
