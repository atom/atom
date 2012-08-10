#!/bin/bash

if [ -z "$1" ]; then
  echo "ERROR: Please specify a build target: Debug or Release"
else
  if [ -z "$2" ]; then
    PROJECT_NAME='cefclient'
  else
    PROJECT_NAME=$2
  fi
  if [ `uname` = "Linux" ]; then
    pushd ../../
    make BUILDTYPE=$1 -j 16
    popd
  else
    xcodebuild -project ../cef.xcodeproj -configuration $1 -target "$PROJECT_NAME"
  fi
fi
