#!/bin/bash

# This script wraps the `Atom` binary, allowing the `chromedriver` server to
# execute it with positional arguments and environment variables. `chromedriver`
# only allows 'switches' to be specified when starting a browser, not positional
# arguments, so this script accepts the following special switches:
#
# * `atom-path`: The path to the `Atom` binary.
# * `atom-arg`:  A positional argument to pass to Atom. This flag can be specified
#                multiple times.
# * `atom-env`:  A key=value environment variable to set for Atom. This flag can
#                be specified multiple times.
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

    --atom-arg=*)
      atom_args+=(${arg#*=})
      ;;

    --atom-env=*)
      export ${arg#*=}
      ;;

    *)
      atom_switches+=($arg)
      ;;
  esac
done

echo "Launching Atom" >&2
echo ${atom_path} ${atom_args[@]} ${atom_switches[@]} >&2

exec ${atom_path} ${atom_args[@]} ${atom_switches[@]}
