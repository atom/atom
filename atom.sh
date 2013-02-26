#!/bin/sh
open -a /Applications/Atom.app -n --args --executed-from="$(pwd)" --pid=$$ $@

# Used to exit process when atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# Don't exit process if we were told to wait.
while [ "$#" -gt "0" ]; do
  case $1 in
    -W|--wait)
      WAIT=1
      ;;
  esac
  shift
done

if [ $WAIT ]; then
  while true; do
    sleep 1
  done
fi
