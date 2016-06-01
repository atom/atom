#!/bin/bash

set -e

cd build
echo ">> Installing build dependencies with Node $(node -v)"
npm install

cd ..
echo
echo ">> Installing apm dependencies with bundled Node $(./bin/node -v)"
./bin/npm install
