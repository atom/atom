

################################
##  NOT YET USED !!!!!
################################


WDIR="$TM_BUNDLE_SUPPORT"/bin
HTMLROOTPATH="$HOME/Library/Application Support/TextMate/R/help/HTML"

[[ ! -e "$HTMLROOTPATH" ]] && mkdir -p "$HTMLROOTPATH"

cd "$WDIR"

if [ ! -e /tmp/r_helper_dummy ]; then
	mkfifo /tmp/r_helper_dummy
else
	if [ ! -p /tmp/r_helper_dummy ]; then
		rm /tmp/r_helper_dummy
		mkfifo /tmp/r_helper_dummy
	fi
fi

/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby Rhelperbuilder.rb &> /dev/null &

### wait for Rhelper
#safety counter
SAFECNT=0
while [ ! -f /tmp/r_helper_dummy_out ]
do
	SAFECNT=$(($SAFECNT+1))
	if [ $SAFECNT -gt 50000 ]; then
		echo -en "Start failed! No response from Rhelper!"
		exit 206
	fi
	sleep 0.01
done

#wait for Rdaemon's output is ready
SAFECNT=0
while [ 1 ]
do
	ST=$(tail -n 1 /tmp/r_helper_dummy_out )
	[[ "$ST" == "> " ]] && break
	SAFECNT=$(($SAFECNT+1))
	if [ $SAFECNT -gt 50000 ]; then
		echo -en "Start failed! No response from Rhelper!"
		exit 206
	fi
	sleep 0.05
done

exec<"$TM_BUNDLE_SUPPORT/helpshort.index"
# SAFECNT=0
export token=$("$DIALOG" -a ProgressDialog -p "{title=Rdaemon;isIndeterminate=1;summary='R Documentation';details='Create HTML help pages…';}")
while read line
do
	OLDIFS="$IFS"
	IFS="/"
	data=( $line )
	# fun=$(echo -n $line | cut -d '/' -f2)
	# lib=$(echo -n $line | cut -d '/' -f1)
	[[ ! -e "$HTMLROOTPATH/${data[0]}" ]] && mkdir -p "$HTMLROOTPATH/${data[0]}"
	file="$HTMLROOTPATH/${data[0]}/${data[1]}.html"
	if [ ! -e "$file" ]; then
		curl -sS "http://127.0.0.1:30815/library/${data[0]}/html/${data[1]}.html" > "$file"
	fi
	# SAFECNT=$(($SAFECNT+1))
	# [[ $SAFECNT -gt 50 ]] && break
done
"$DIALOG" -x $token 2&>/dev/null


sleep .1
echo "q('no')" > /tmp/r_helper_dummy
rm /tmp/r_helper_dummy
rm /tmp/r_helper_dummy_out
