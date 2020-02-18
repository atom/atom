#!/bin/sh

PASSWORD=$(${SSH_ASKPASS} 'Speak friend and enter')
if [ "${PASSWORD}" != 'friend' ]; then
  printf "Invalid password: [${PASSWORD}]\n" >&2
  exit 1
fi

printf '005a66d11860af6d28eb38349ef83de475597cb0e8b4 HEAD\0multi_ack symref=HEAD:refs/heads/master\n'
printf '003f66d11860af6d28eb38349ef83de475597cb0e8b4 refs/heads/master\n'
printf '0000'

# Consume the git process' 0000 response
read UNUSED || true
