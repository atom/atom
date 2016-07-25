
export WORD="$1"
export FLAG="$2"

# FLAG == 1 remove \n and function name for parameter parsing
# FLAG == 0 show function usage 

cat | perl -e '
undef($/);
$w=$ENV{"WORD"};
$f=$ENV{"FLAG"};
$a=<>;
$a=~s!.*?<h.>Usage</h.>\s*<pre>[^>]*?($w\([^>]*?\)).*?\n.*?</pre>.*!$1!ms;
$a=~s/"\t"/"\\t"/sg;
$a=~s/"\n"/"\\n"/sg;
if($f) {
	$a=~s/\n//sg;
	$a=~s/^$w//ms;
	$a="" if($a!~m/^\(.*\)$/);
}
if($a!~m/^</) {
	print $a;
}
'
