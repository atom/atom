#!/bin/sh

SOURCE_SCRIPTS_DIR="$PROJECT_DIR/html"
DESTINATION_SCRIPTS_DIR="$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/"

PATH="$PATH:/usr/local/bin/"
hash coffee 2>&- || { echo >&2 "error: Coffee is required but it's not installed (http://jashkenas.github.com/coffee-script/)."; exit 1; }
coffee -o "$DESTINATION_SCRIPTS_DIR/HTML/lib/" HTML/lib/*.coffee

cp -r "$SOURCE_SCRIPTS_DIR" "$DESTINATION_SCRIPTS_DIR"
