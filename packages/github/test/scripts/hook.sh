#!/bin/bash
#
# A fake git hook.

set -euo pipefail

printf "my PATH is %s\n" "${PATH:-}"
didirun.sh
exit 0
