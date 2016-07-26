
USE=$(cat | egrep -A 10 "\b${1//./\\.}\b *<\-[ 	]*\bfunction\b[ 	]*\(" | perl -e '
	undef($/);
	$a=<>;
	$a=~s/.*?<\-\s*\bfunction\b\s*(\(.*?\))\s*[\t\n\{\w].*/$1/gms;
	$a=~s/"\n"/"\\n"/g;
	$a=~s/\x27\n\x27/\x27\\n\x27/g;
	$a=~s/[\n\t]/ /g;
	$a=~s/ {2,}/ /g;
	$a=~s/^\(\s*/(/g;
	$a=~s/\s*\)$/)/g;
	$a=~s/\s*=\s*/ = /g;
	$a=~s/\s*,\s*/, /g;
	print $a
')

# If Rhelper doesn't work, use the following line only
# echo $USE | fmt | perl -e 'undef($/);$a=<>;$a=~s/\n/\n\t/g;$a=~s/\n\t$//;print $a'
if [ ! -z "$USE" ]; then
	"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "TM_Rdaemona<-function $USE {};args(TM_Rdaemona)"
	# sleep 0.01
	OUT=$(cat /tmp/textmate_Rhelper_out | sed '$d' | perl -pe 's/^function //;s/"\n"/"\\n"/g;s/"\t"/"\\t"/g')
	if [ -z "$OUT" -a ! -z "$USE" ]; then
		echo " declaration possibly erroneous:
	$USE"
	else
		echo -n "$OUT"
	fi
fi