#!/bin/sh
ATOM_APP_NAME=Atom.app

if [ -z "$ATOM_PATH" ]; then
  for i in /Applications ~/Applications /Applications/Utilities ~/Applications/Utilities/ ~/Downloads ~/Desktop; do
    if [ -x "$i/$ATOM_APP_NAME" ]; then
      ATOM_PATH="$i"
      break
    fi
  done
fi

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
  echo "$ATOM_PATH/$ATOM_APP_NAME"
  open -a "$ATOM_PATH/$ATOM_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ "$@"
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
