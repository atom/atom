#!/bin/bash

# This script wraps the `Atom` binary, allowing the `chromedriver` server to
# execute it with positional arguments. `chromedriver` only allows 'switches'
# to be specified when starting a browser, not positional arguments, so this
# script accepts two special switches:
#
# * `atom-path` The path to the `Atom` binary
# * `atom-args` A space-separated list of positional arguments to pass to Atom.
#
# Any other switches will be passed through to `Atom`.

atom_path=""
atom_switches=()
atom_args=()

for arg in "$@"; do
  case $arg in
    --atom-path=*)
      atom_path="${arg#*=}"
      ;;

    --atom-args=*)
      atom_args_string="${arg#*=}"
      for atom_arg in $atom_args_string; do
        atom_args+=($atom_arg)
      done
      ;;

    *)
      atom_switches+=($arg)
      ;;
  esac
done

exec $atom_path "${atom_switches[@]}" "${atom_args[@]}"
