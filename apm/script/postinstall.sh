#!/bin/bash

set -e

echo ">> Downloading bundled Node"
node script/download-node.js

echo
echo ">> Rebuilding apm dependencies with bundled Node $(./bin/node -v)"
./bin/npm rebuild

echo
echo ">> Deduping apm dependencies"
./bin/npm dedupe
