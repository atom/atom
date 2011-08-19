#!/bin/sh

PATH="$PATH:/usr/local/bin/"
coffee -o "$BUILT_PRODUCTS_DIR/$CONTENTS_FOLDER_PATH/Resources/" HTML/*.coffee
