#!/bin/sh
ATOM_PATH=${ATOM_PATH-/Applications/Atom.app}
ATOM_BINARY=$ATOM_PATH/Contents/MacOS/Atom

if [ ! -d $ATOM_PATH ]; then sleep 5; fi # Wait for Atom to reappear, Sparkle may be replacing it.

if [ ! -d $ATOM_PATH ]; then
  echo "Atom application not found at '$ATOM_PATH'" >&2
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
  $ATOM_BINARY --executed-from="$(pwd)" --pid=$$ $@
  exit $?
else
  open -a $ATOM_PATH -n --args --executed-from="$(pwd)" --pid=$$ $@
fi

# Used to exit process when atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
