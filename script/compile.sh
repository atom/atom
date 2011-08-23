#!/bin/sh

PATH="$PATH:/usr/local/bin/"
hash coffee 2>&- || { echo >&2 "error: Coffee is required but it's not installed (http://jashkenas.github.com/coffee-script/)."; exit 1; }
coffee -o "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/HTML" HTML/*.coffee
