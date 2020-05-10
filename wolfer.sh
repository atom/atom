#!/bin/bash

if [ "$(uname)" == 'Darwin' ]; then
  OS='Mac'
elif [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]; then
  OS='Linux'
else
  echo "Your platform ($(uname -a)) is not supported."
  exit 1
fi

case $(basename $0) in
  wolfer-alpha)
    CHANNEL=alpha
    ;;
  wolfer-nightly)
    CHANNEL=nightly
    ;;
  wolfer-dev)
    CHANNEL=dev
    ;;
  *)
    CHANNEL=stable
    ;;
esac

# Only set the WOLFER_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT env var if it hasn't been set.
if [ -z "$WOLFER_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT" ]
then
  export WOLFER_DISABLE_SHELLING_OUT_FOR_ENVIRONMENT=true
fi

WOLFER_ADD=false
WOLFER_NEW_WINDOW=false
EXIT_CODE_OVERRIDE=

while getopts ":anwtfvh-:" opt; do
  case "$opt" in
    -)
      case "${OPTARG}" in
        add)
          WOLFER_ADD=true
          ;;
        new-window)
          WOLFER_NEW_WINDOW=true
          ;;
        wait)
          WAIT=1
          ;;
        help|version)
          REDIRECT_STDERR=1
          EXPECT_OUTPUT=1
          ;;
        foreground|benchmark|benchmark-test|test)
          EXPECT_OUTPUT=1
          ;;
        enable-electron-logging)
          export ELECTRON_ENABLE_LOGGING=1
          ;;
      esac
      ;;
    a)
      WOLFER_ADD=true
      ;;
    n)
      WOLFER_NEW_WINDOW=true
      ;;
    w)
      WAIT=1
      ;;
    h|v)
      REDIRECT_STDERR=1
      EXPECT_OUTPUT=1
      ;;
    f|t)
      EXPECT_OUTPUT=1
      ;;
  esac
done

if [ "${WOLFER_ADD}" = "true" ] && [ "${WOLFER_NEW_WINDOW}" = "true" ]; then
  EXPECT_OUTPUT=1
  EXIT_CODE_OVERRIDE=1
fi

if [ $REDIRECT_STDERR ]; then
  exec 2> /dev/null
fi

WOLFER_HOME="${WOLFER_HOME:-$HOME/.wolfer}"
mkdir -p "$WOLFER_HOME"

if [ $OS == 'Mac' ]; then
  if [ -L "$0" ]; then
    SCRIPT="$(readlink "$0")"
  else
    SCRIPT="$0"
  fi
  WOLFER_APP="$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT")")")")"
  if [ "$WOLFER_APP" == . ]; then
    unset WOLFER_APP
  else
    WOLFER_PATH="$(dirname "$WOLFER_APP")"
    WOLFER_APP_NAME="$(basename "$WOLFER_APP")"
  fi

  if [ ! -z "${WOLFER_APP_NAME}" ]; then
    # If WOLFER_APP_NAME is known, use it as the executable name
    WOLFER_EXECUTABLE_NAME="${WOLFER_APP_NAME%.*}"
  else
    # Else choose it from the inferred channel name
    if [ "$CHANNEL" == 'alpha' ]; then
      WOLFER_EXECUTABLE_NAME="Wolfer Alpha"
    elif [ "$CHANNEL" == 'nightly' ]; then
      WOLFER_EXECUTABLE_NAME="Wolfer Nightly"
    elif [ "$CHANNEL" == 'dev' ]; then
      WOLFER_EXECUTABLE_NAME="Wolfer Dev"
    else
      WOLFER_EXECUTABLE_NAME="Wolfer"
    fi
  fi

  if [ -z "${WOLFER_PATH}" ]; then
    # If WOLFER_PATH isn't set, check /Applications and then ~/Applications for Wolfer.app
    if [ -x "/Applications/$WOLFER_APP_NAME" ]; then
      WOLFER_PATH="/Applications"
    elif [ -x "$HOME/Applications/$WOLFER_APP_NAME" ]; then
      WOLFER_PATH="$HOME/Applications"
    else
      # We haven't found a Wolfer.app, use spotlight to search for Wolfer
      WOLFER_PATH="$(mdfind "kMDItemCFBundleIdentifier == 'com.wolfer.wolfer'" | grep -v ShipIt | head -1 | xargs -0 dirname)"

      # Exit if Wolfer can't be found
      if [ ! -x "$WOLFER_PATH/$WOLFER_APP_NAME" ]; then
        echo "Cannot locate ${WOLFER_APP_NAME}, it is usually located in /Applications. Set the WOLFER_PATH environment variable to the directory containing ${WOLFER_APP_NAME}."
        exit 1
      fi
    fi
  fi

  if [ $EXPECT_OUTPUT ]; then
    "$WOLFER_PATH/$WOLFER_APP_NAME/Contents/MacOS/$WOLFER_EXECUTABLE_NAME" --executed-from="$(pwd)" --pid=$$ "$@"
    WOLFER_EXIT=$?
    if [ ${WOLFER_EXIT} -eq 0 ] && [ -n "${EXIT_CODE_OVERRIDE}" ]; then
      exit "${EXIT_CODE_OVERRIDE}"
    else
      exit ${WOLFER_EXIT}
    fi
  else
    open -a "$WOLFER_PATH/$WOLFER_APP_NAME" -n --args --executed-from="$(pwd)" --pid=$$ --path-environment="$PATH" "$@"
  fi
elif [ $OS == 'Linux' ]; then
  SCRIPT=$(readlink -f "$0")
  USR_DIRECTORY=$(readlink -f $(dirname $SCRIPT)/..)

  case $CHANNEL in
    beta)
      ATOM_PATH="$USR_DIRECTORY/share/atom-beta/atom"
      ;;
    nightly)
      ATOM_PATH="$USR_DIRECTORY/share/atom-nightly/atom"
      ;;
    dev)
      ATOM_PATH="$USR_DIRECTORY/share/atom-dev/atom"
      ;;
    *)
      ATOM_PATH="$USR_DIRECTORY/share/atom/atom"
      ;;
  esac

  : ${TMPDIR:=/tmp}

  [ -x "$ATOM_PATH" ] || ATOM_PATH="$TMPDIR/atom-build/Atom/atom"

  if [ $EXPECT_OUTPUT ]; then
    "$ATOM_PATH" --executed-from="$(pwd)" --pid=$$ "$@"
    ATOM_EXIT=$?
    if [ ${ATOM_EXIT} -eq 0 ] && [ -n "${EXIT_CODE_OVERRIDE}" ]; then
      exit "${EXIT_CODE_OVERRIDE}"
    else
      exit ${ATOM_EXIT}
    fi
  else
    (
    nohup "$ATOM_PATH" --executed-from="$(pwd)" --pid=$$ "$@" > "$ATOM_HOME/nohup.out" 2>&1
    if [ $? -ne 0 ]; then
      cat "$ATOM_HOME/nohup.out"
      exit $?
    fi
    ) &
  fi
fi

# Exits this process when Atom is used as $EDITOR
on_die() {
  exit 0
}
trap 'on_die' SIGQUIT SIGTERM

# If the wait flag is set, don't exit this process until Atom kills it.
if [ $WAIT ]; then
  WAIT_FIFO="$ATOM_HOME/.wait_fifo"

  if [ ! -p "$WAIT_FIFO" ]; then
    rm -f "$WAIT_FIFO"
    mkfifo "$WAIT_FIFO"
  fi

  # Block endlessly by reading from a named pipe.
  exec 2>/dev/null
  read < "$WAIT_FIFO"

  # If the read completes for some reason, fall back to sleeping in a loop.
  while true; do
    sleep 1
  done
fi
