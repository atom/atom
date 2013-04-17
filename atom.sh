#!/bin/sh
ATOM_PATH=/Applications/Atom.app

if [ ! -d $ATOM_PATH ]; then sleep 5; fi # Wait for Atom to reappear, Sparkle may be replacing it.

if [ ! -d $ATOM_PATH ]; then 
  echo "Atom Application not found at '$ATOM_PATH'" >&2
  exit 1
fi

open -a $ATOM_PATH -n --args --executed-from="$(pwd)" --pid=$$ $@

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
