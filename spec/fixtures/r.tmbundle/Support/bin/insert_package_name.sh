
"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getInstalledPackages()"

cat "/tmp/textmate_Rhelper_out" | sort -f | /System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby -e '
	isDIALOG2 = ! ENV["DIALOG"].match(/2$/).nil?
	require File.join(ENV["TM_SUPPORT_PATH"], "lib/ui.rb")
	require File.join(ENV["TM_SUPPORT_PATH"], "lib/exit_codes.rb")
	words = STDIN.read().split("\n")
	if isDIALOG2
		TextMate::UI.complete(words)
	else
		index=TextMate::UI.menu(words)
	end
		if index != nil
			print words[index]
		else
			TextMate.exit_discard()
		end
	exit 203
'