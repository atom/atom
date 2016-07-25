#!/bin/sh
TERM="$1"
AS="$2"

HEAD=/tmp/textmate_Rhelper_head.html
DATA=/tmp/textmate_Rhelper_data.html
SEARCH=/tmp/textmate_Rhelper_search.html
RhelperAnswer=/tmp/textmate_Rhelper_out

"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "cat(getRversion()>='2.10.0',sep='')"
sleep 0.05
IS_HELPSERVER=$(cat "$RhelperAnswer")
"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getHttpPort()"
sleep 0.05
PORT=$(cat "$RhelperAnswer")

echo "<html><body style='margin-top:5mm'><table style='border-collapse:collapse'><tr><td style='padding-right:1cm;border-bottom:1px solid black'><b>Package</b></td><td style='border-bottom:1px solid black'><b>Topic</b></td></tr>" > "$HEAD"


if [ "$AS" == "1" ]; then
	"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getSearchHelp('^$TERM')"
	AS="checked"
else
	"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getSearchHelp('$TERM')"
	AS=""
fi
sleep 0.05

CNT=`cat "$RhelperAnswer" | wc -l`
if [ $CNT -gt 500 ]; then
	echo "<tr colspan=2><td><i>too much matches...</i></td></tr>" >> "$HEAD"
else
	exec<"$RhelperAnswer"
	if [ "$IS_HELPSERVER" == "TRUE" ]; then
		while read i
		do
			lib=$(echo -e "$i" | cut -d '	' -f1)
			fun=$(echo -e "$i" | cut -d '	' -f2)
			link=$(echo -e "$i" | cut -d '	' -f3)
			echo "<tr><td>$lib</td><td><a href='$link' target='data'>$fun</a></td></tr>" >> "$HEAD"
		done
		if [ $CNT -eq 1 ]; then
			echo "<base href=\"$link\">" > "$DATA"
			curl -gsS "$link" >> "$DATA"
		fi
	else
		while read i
		do
			lib=$(echo -e "$i" | cut -d '	' -f1)
			fun=$(echo -e "$i" | cut -d '	' -f2)
			link=$(echo -e "$i" | cut -d '	' -f3)
			echo "<tr><td>$lib</td><td><a href='file://$link' target='data'>$fun</a></td></tr>" >> "$HEAD"
		done
		if [ $CNT -eq 1 ]; then
			echo "<base href=\"file://$link\">"
			cat "$link" | iconv -s -f ISO8859-1 -t UTF-8
		fi
	fi
fi
echo "</table></body></html>" >> "$HEAD"

cat <<-HFS > "$SEARCH"
<html>
	<head>
	<script type='text/javascript' charset='utf-8'>
		function SearchServer(term) {
			if (term.length > 0) {
				TextMate.isBusy = true;
				if(document.sform.where.checked == true) {
					TextMate.system('"$TM_BUNDLE_SUPPORT/bin/Rsearch.sh" "' + term + '" 1', null);
				} else {
					TextMate.system('"$TM_BUNDLE_SUPPORT/bin/Rsearch.sh" "' + term + '" 0', null);
				}
				TextMate.system('sleep 0.3', null);
				parent.head.location.reload();
				parent.data.location.reload();
				TextMate.isBusy = false;
				parent.search.sform.search.value = term;
			}
		}

HFS

if [ "$IS_HELPSERVER" != "TRUE" ]; then
			echo "function Rdoc() {TextMate.system('open \"${R_HOME:=/Library/Frameworks/R.framework/Versions/Current/Resources}/doc/html/index.html\"', null);}" >> "$SEARCH"
else
			echo "function Rdoc() {TextMate.system('open \"http://127.0.0.1:$PORT/doc/html/index.html\"', null);}" >> "$SEARCH"
fi

cat <<-HFS2 >> "$SEARCH"

	</script>
	</head>
	<body bgcolor='#ECECEC''>
	<table>
		<tr>
			<td>
			<form name='sform' onsubmit='SearchServer(document.sform.search.value)'>
			<small><small><i>Search for</i><br /></small></small>
			<input tabindex='0' id='search' type='search' placeholder='regexp' results='20' onsearch='SearchServer(this.value)' value="$TERM">
			</td>
			<td>
			<font style='font-size:7pt'>
			<br /><button onclick='SearchServer(document.sform.search.value)'>Search</button>
			<br /><input type='checkbox' name='where' value='key' $AS><i>&nbsp;begins&nbsp;with</i>
			</font>
			</td>
			</form>
			</td>
		</tr>
		<tr>
			<td align=center colspan=3>
			<input onclick='Rdoc()' type=button value='R documentation'>
			</td>
		</tr>
	</table>
	</body>
</html>
HFS2

sleep 0.05
