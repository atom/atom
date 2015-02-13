#!/bin/bash

# This script wraps the `Atom` binary, allowing the `chromedriver` server to
# execute it with positional arguments and environment variables. `chromedriver`
# only allows 'switches' to be specified when starting a browser, not positional
# arguments, so this script accepts the following special switches:
#
# * `atom-path`: The path to the `Atom` binary.
# * `atom-args`: A space-separated list of positional arguments to pass to Atom.
# * `atom-env`:  A space-separated list of key=value pairs representing environment
#                variables to set for Atom.
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
      atom_arg_string="${arg#*=}"
      for atom_arg in $atom_arg_string; do
        atom_args+=($atom_arg)
      done
      ;;

    --atom-env=*)
      atom_env_string="${arg#*=}"
      for atom_env_pair in $atom_env_string; do
        export $atom_env_pair
      done
      ;;

    *)
      atom_switches+=($arg)
      ;;
  esac
done

echo "Launching Atom" >&2
echo ${atom_path} ${atom_args[@]} ${atom_switches[@]} >&2

exec ${atom_path} ${atom_args[@]} ${atom_switches[@]}
