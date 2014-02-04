
[[ -n "$TM_SELECTED_TEXT" ]] && echo "Please unselect first." && exit 206

#look for nested commands and set WORD to the current one
WORD=$(perl -e '
$line=$ENV{"TM_CURRENT_LINE"};
$col=$ENV{"TM_LINE_INDEX"};
$line=substr($line,0,$col);
$line=~s/ //g;
@arr=split(//,$line);$c=0;
for($i=$#arr;$i>-1;$i--){$c-- if($arr[$i] eq ")");$c++ if($arr[$i] eq "(");last if $c>0;}
substr($line,0,$i)=~m/([\w\.:]+)$/;
print $1 if defined($1);
')

PKG=""
if [ `echo "$WORD" | grep -Fc ':'` -gt 0 ]; then
	PKG=",package='${WORD%%:*}'"
fi
WORD="${WORD##*:}"
OUT=""
#check whether WORD is defined otherwise quit
[[ -z "$WORD" ]] && echo "No keyword found" && exit 206

#check for user-defined parameter list
"$TM_BUNDLE_SUPPORT"/bin/initCommandArgsDir.sh
if [ -e "$HOME/Library/Application Support/TextMate/R/help/command_args/$WORD" ]; then
	RES=$(cat "$HOME/Library/Application Support/TextMate/R/help/command_args/$WORD")
else
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
		TASK="@|sink('$RDRAMDISK/r_tmp');args($WORD)"
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
		OUT=$(cat "$RDRAMDISK"/r_tmp | perl -e 'undef($/);$a=<>;$a=~s/NULL$//;$a=~s/^.*?\(/(/;$a=~s/"\t"/"\\t"/sg;$a=~s/"\n"/"\\n"/sg;$a=~s/\n//sg;print $a')
		[[ "$OUT" == "NULL" ]] && OUT=""
	fi

	if [ -z "$OUT" ]; then
		# Get URL for current function
		"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getHelpURL('$WORD'$PKG)"
		FILE=$(cat /tmp/textmate_Rhelper_out)
		if [ `cat /tmp/textmate_Rhelper_out | wc -l` -gt 1 ]; then
			echo -e "Function '$WORD' is ambiguous.\nFound in packages:"
			echo "$FILE" | perl -pe 's!.*?/library/(.*?)/.*?/.*!$1!'
			exit 206
		fi
		if [ ! -z "$FILE" -a "$FILE" != "NA" ]; then
			if [ "${FILE:0:1}" = "/" ]; then
				RES=$(cat "$FILE")
			else
				RES=$(curl -gsS "$FILE")
			fi
			OUT=$(echo -en "$RES" | "$TM_BUNDLE_SUPPORT/bin/parseHTMLForUsage.sh" "$WORD" 1)
		else
			# Parse R script for functions
			OUT=$(cat | "$TM_BUNDLE_SUPPORT/bin/parseDocForFunctions.sh" "$WORD" | perl -e 'undef($/);$a=<>;$a=~s/"\t"/"\\t"/sg;$a=~s/"\n"/"\\n"/sg;$a=~s/\n//sg;print $a')
			# Check for errors
			if [ `echo -n "$OUT" | grep -F 'declaration possibly erroneous:' | wc -l` -gt 0 ]; then
				echo "$WORD$OUT" && exit 206
			fi
		fi

		if [ -z "$OUT" ]; then
			echo "Nothing found"
			exit 206
		fi
	fi
	# Evaluate function arguments and get a list of them
	"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "for (i in names(formals(function $OUT {})->a)) {cat(i);cat(' = ');print(a[[i]])}"
	RES=$(cat /tmp/textmate_Rhelper_out | perl -e 'undef($/);$a=<>;$a=~s/ = \[1\] / = /g;$a=~s/\.\.\..*\n//g;$a=~s/\n +//g;print $a' )

fi

#if no parameter quit
if [ -z "$RES" ]; then
	echo -n "Nothing found"
	exit 206
fi

#show all parameters as inline menu and insert the parameter as snippet (if '=' is found only the value)
/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby -- <<-SCRIPT
# 2> /dev/null
require File.join(ENV["TM_SUPPORT_PATH"], "lib/exit_codes.rb")
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"
word = "$WORD"
text = %q[$RES]
funs = text.split("\n")
TextMate.exit_discard if funs.size < 1

if funs.size == 1
  function = funs.first
else
	funs.unshift("-")
	funs.unshift("All Parameters")
	idx = TextMate::UI.menu(funs)
	TextMate.exit_discard if idx.nil?
	function = funs[idx]
end
TextMate.exit_discard if function.empty?
curword = ENV['TM_CURRENT_WORD']
comma=""
line, col = ENV['TM_CURRENT_LINE'], ENV['TM_LINE_INDEX'].to_i
left  = line[0...col].to_s
sp = left.match(/.$/).to_s
left.gsub!(/ +$/,'')
left = left.match(/.$/).to_s
comma = "\${2:, }" if left != "(" && left != ","
comma = " " + comma if sp == ","
if function == "All Parameters"
	cnt=1
	com=""
	snip=""
	funs.slice!(0)
	funs.slice!(0)
	funs.each do |item|
		com = ", " if cnt > 1
		#if cnt%5 == 0
		#	com = ",\n\t"
		#end
		if item.match("=")
			arr = item.gsub(/ = /, "=").match('([^=]+?)=(.*)')
			if arr[2].match('^\"')
				print "#{com}#{arr[1]} = \"\${"
				print cnt.to_s
				cnt+=1
				print ":#{arr[2].gsub(/^\"|\"$/, "").gsub(/=/, " = ")}}\""
			else
				if arr[2].match('^c\(')
					print "#{com}#{arr[1]} = c(\${"
					print cnt.to_s
					cnt+=1
					print ":#{arr[2].gsub(/^c\(/, "").gsub(/\)\Z/,"").gsub(/=/, " = ")}})"
				else
					print "#{com}#{arr[1]} = \${"
					print cnt.to_s
					cnt+=1
					print ":#{arr[2].gsub(/=/, " = ")}}"
				end
			end
		else
			print "#{com}#{item} = \${"
			print cnt.to_s
			cnt+=1
			print ":}"
		end
	end
	print "\${#{cnt}:}"
else
	if function.match("=")
		arr = function.gsub(/ = /, "=").match('([^=]+?)=(.*)')
		if arr[2].match('^\"')
			print "#{comma}#{arr[1]} = \"\${1:#{arr[2].gsub(/^\"|\"$/, "")}}\"\${3:}"
		else
			if arr[2].match('^c\(')
				subarr = arr[2].gsub(/^c\(/, "").gsub(/\)$/,"").gsub(/ /,"").split(",")
				for i in (0..(subarr.size - 1))
					subarr[i] = "\${#{i+3}:#{subarr[i]}}"
				end
				print "#{comma}#{arr[1]} = \${1:c(#{subarr.join(", ")})}\${300:}"
			else
				print "#{comma}#{arr[1]} = \${1:#{arr[2].gsub(/=/, " = ")}}\${3:}"
			end
		end
	else
		print "#{comma}#{function} = \${1:}\${3:}"
	end
end
SCRIPT
