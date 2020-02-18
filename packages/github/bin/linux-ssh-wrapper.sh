#!/bin/sh
#
# On Linux: Attempt to detach this process from the controlling terminal that
# owns Atom. Otherwise, ssh will insist on prompting for key passphrases on
# the tty that you originally used to launch Atom.
#
# Fail gracefully if `setsid` is not present. Respect `core.sshCommand` and
# `GIT_SSH_COMMAND` if either are set.

set -eu

log() {
  [ -n "${GIT_TRACE:-}" ] && return;
  printf "linux-ssh: %s\n" "$1" >&2
}

log "Linux ssh wrapper invoked with arguments: [${@:-}]"

SSH_CMD=${ATOM_GITHUB_ORIGINAL_GIT_SSH_COMMAND:-}
[ -z "${SSH_CMD}" ] && SSH_CMD=$(git config core.sshCommand || printf '')
[ -z "${SSH_CMD}" ] && SSH_CMD='ssh'

log "using SSH command [${SSH_CMD}]"

if type setsid >/dev/null 2>&1; then
  setsid ${SSH_CMD} "${@:-}"
else
  log "no setsid available. SSH prompts may appear on a tty."
  sh -c "${SSH_CMD} ${@:-}"
fi
