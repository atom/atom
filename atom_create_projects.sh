#!/bin/sh
python tools/gyp_cef atom.gyp -I cef.gypi --depth=./chromium
