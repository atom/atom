
export WORD=$(/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby -- <<-SCR1
print ENV['TM_CURRENT_LINE'][0...ENV['TM_LINE_INDEX'].to_i].gsub!(/ *$/, "").match(/[\w.:]*$/).to_s
SCR1
)


WORDORG="$WORD"
PKG=""
if [ `echo "$WORD" | grep -Fc ':'` -gt 0 ]; then
	PKG=",package='${WORD%%:*}'"
fi
WORD="${WORD##*:}"

#check whether WORD is defined otherwise quit
[[ -z "$WORD" ]] && exit 200

TEXT=$(cat)

RhelperAnswer="/tmp/textmate_Rhelper_out"

# Rdaemon
RPID=$(ps aw | grep '[0-9] /.*TMRdaemon' | awk '{print $1;}' )
RD=$(echo -n "$TM_SCOPE" | grep -c -F 'source.rd.console')
if [ ! -z "$RPID" -a "$RD" -gt 0 ]; then
	RDHOME="$HOME/Library/Application Support/Rdaemon"
	if [ "$TM_RdaemonRAMDRIVE" == "1" ]; then
		RDRAMDISK="/tmp/TMRramdisk1"
	else
		RDRAMDISK="$RDHOME"
	fi
	[[ -e "$RDRAMDISK"/r_tmp ]] && rm "$RDRAMDISK"/r_tmp

	# execute "args()" in Rdaemon
	TASK="@|sink('$RDRAMDISK/r_tmp');args($WORDORG)"
	echo "$TASK" > "$RDHOME"/r_in
	echo "@|sink(file=NULL)" > "$RDHOME"/r_in
	while [ 1 ]
	do
		RES=$(tail -c 2 "$RDRAMDISK"/r_out)
		[[ "$RES" == "> " ]] && break
		[[ "$RES" == ": " ]] && break
		[[ "$RES" == "+ " ]] && break
		sleep 0.03
	done
	sleep 0.001
	RES=$(cat "$RDRAMDISK"/r_tmp | sed 's/NULL$//;')
	[[ "$RES" == "NULL" ]] && RES=""
	# "args()" did find something
	if [ ! -z "$RES" ]; then
		OUT=$(echo -en "$WORD${RES:9}" | perl -e 'undef($/);$a=<>;$a=~s/"\t"/"\\t"/sg;$a=~s/"\n"/"\\n"/sg;print $a')
		rm -f "$RDRAMDISK"/r_tmp
		TASK="@|sink('$RDRAMDISK/r_tmp');cat(gsub('.*?/library/(.*?)/.*','\\\\1',as.vector(help('$WORD',try.all.packages=F)),perl=T),sep='\n')"
		echo "$TASK" > "$RDHOME"/r_in
		TASK="@|sink(file=NULL)"
		echo "$TASK" > "$RDHOME"/r_in
		while [ 1 ]
		do
			RES=$(tail -c 2 "$RDRAMDISK"/r_out)
			[[ "$RES" == "> " ]] && break
			[[ "$RES" == ": " ]] && break
			[[ "$RES" == "+ " ]] && break
			sleep 0.03
		done
		sleep 0.001
		LIB=$(cat "$RDRAMDISK"/r_tmp)
		if [ -z "$LIB" ]; then
			echo -n "$OUT"
			echo -en "\n• local"
			exit 206
		fi
		CNT=$(echo "$LIB" | wc -l)
		if [ $CNT -eq 1 ]; then
			echo -n "$OUT"
			echo -en "\n•• library: $LIB"
			exit 206
		fi
	# "args()" didn't find anything ergo library isn't yet loaded
	else
		"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getHelpURL('$WORD'$PKG)"
		FILE=$(cat "$RhelperAnswer")
		if [ ! -z "$FILE" -a "$FILE" != "NA" ]; then
			exec<"$RhelperAnswer"
			while read i
			do
			if [ "${i:0:1}" = "/" ]; then
				RES=$(cat "$i")
			else
				RES=$(curl -gsS "$i")
			fi
			echo -n "$RES" | "$TM_BUNDLE_SUPPORT/bin/parseHTMLForUsage.sh" "$WORD" 0
			LIB=$(echo "$i" | perl -pe 's!.*?/library/(.*?)/.*!$1!')
			TASK="@|sink('$RDRAMDISK/r_tmp')"
			echo "$TASK" > "$RDHOME"/r_in
			TASK="@|cat(sum((.packages()) %in% \"$LIB\"),sep='')"
			echo "$TASK" > "$RDHOME"/r_in
			TASK="@|sink(file=NULL)"
			echo "$TASK" > "$RDHOME"/r_in
			while [ 1 ]
			do
				RES=$(tail -c 2 "$RDRAMDISK"/r_out)
				[[ "$RES" == "> " ]] && break
				[[ "$RES" == ": " ]] && break
				[[ "$RES" == "+ " ]] && break
				sleep 0.02
			done
			sleep 0.001
			RES=$(cat "$RDRAMDISK"/r_tmp)
			if [ ! -z "$RES" -a "$RES" == "1" ]; then
				echo -en "\n•• library: $LIB"
			else
				echo -en "\n• library “${LIB}” not loaded [press CTRL+SHIFT+L]"
			fi
			echo
			done
			exit 206
		else
			exit 200
		fi
	fi
fi

# R script
"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getHelpURL('$WORD'$PKG)"
FILE=$(cat "$RhelperAnswer")
if [ ! -z "$FILE" -a "$FILE" != "NA" ]; then
	exec<"$RhelperAnswer"
	while read i
	do
		if [ "${i:0:1}" = "/" ]; then
			RES=$(cat "$i")
		else
			RES=$(curl -gsS "$i")
		fi
		# "$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getPackageFor('$WORD')"
		# LIB=$(cat "$RhelperAnswer")
		LIB=$(echo "$i" | perl -pe 's!.*?/library/(.*?)/.*!$1!')
		RES=$(echo -en "$RES" | "$TM_BUNDLE_SUPPORT/bin/parseHTMLForUsage.sh" "$WORD" 0)
		if [ ! -z "$RES" -a "${RES:0:1}" == "${WORD:0:1}" ]; then
			echo -n "$RES"
			echo -en "\n•• library: $LIB\n"
		fi
	done
	exit 206
else
	[[ `echo -n "$TM_SCOPE" | grep -c -F 'text.tex.latex.rdaemon'` -gt 0 ]] && exit 200
	# Parse R script for functions
	OUT=$(echo -en "$TEXT" | "$TM_BUNDLE_SUPPORT/bin/parseDocForFunctions.sh" "$WORD")
	[[ -z "$OUT" ]] && exit 200
	echo -n "$WORD$OUT
• local"
	exit 206
fi
