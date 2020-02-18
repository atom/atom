#!/bin/sh

if [ "${1:-}" != "get" ]; then
  exit 0
fi

PROTOCOL=
HOST=

while read LINE; do
  case "${LINE}" in
    host=*)
      HOST="${LINE##host=}"
      ;;
    protocol=*)
      PROTOCOL="${LINE##protocol=}"
      ;;
  esac
done

printf 'protocol=%s\n' "${PROTOCOL}"
printf 'host=%s\n' "${HOST}"
