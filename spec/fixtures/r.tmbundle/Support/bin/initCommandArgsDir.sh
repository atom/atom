WDIR="$HOME/Library/Application Support/TextMate/R/help"

if [ ! -e "$WDIR/command_args" ]; then
	mkdir -p "$WDIR/command_args"
	cp -R "$TM_BUNDLE_SUPPORT"/lib/command_args "$WDIR"
fi