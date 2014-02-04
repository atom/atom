RPID=$(ps aw | grep '[0-9] /.*TMRHelperDaemon' | awk '{print $1}' )
#check whether Helper daemon runs if not start it
if [ -z "$RPID" ]; then
	WDIR="$TM_BUNDLE_SUPPORT"/bin
	PIPE="/tmp/textmate_Rhelper_in"
	OUT="/tmp/textmate_Rhelper_console"
	cd "$WDIR"
	if [ ! -e "$PIPE" ]; then
		mkfifo "$PIPE"
	else
		if [ ! -p "$PIPE" ]; then
			rm "$PIPE"
			mkfifo "$PIPE"
		fi
	fi
	/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby RhelperDaemon.rb &> /dev/null &
	SAFECNT=0
	while [ 1 ]
	do
		SAFECNT=$(($SAFECNT+1))
		if [ $SAFECNT -gt 5000 ]; then
			echo -en "Start failed! No response from R Helper server!"
			exit 206
		fi
		RES=$(tail -c 2 "$OUT")
		[[ "$RES" == "> " ]] && break
		sleep 0.03
	done
	sleep 0.3
	cat "<html></html>" > /tmp/textmate_Rhelper_data.html
fi
