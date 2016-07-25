#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby -KU

###################################
#
# R daemon for as Helper
#
# written by Hans-Jörg Bibiko - bibiko@eva.mpg.de
###################################

require 'pty'
require 'fileutils'

$pipe_in = "/tmp/textmate_Rhelper_in"
$pipe_out = "/tmp/textmate_Rhelper_out"
$pipe_status = "/tmp/textmate_Rhelper_status"
$pipe_console = "/tmp/textmate_Rhelper_console"

# check for valid TM_REXEC; if not use "R"
if ENV['TM_REXEC'] != nil
	check = %x{which #{ENV['TM_REXEC']}}
	if check == ""
		%x{osascript -e 'tell app "TextMate" to display dialog "Please check TM_REXEC shell variable! “#{ENV['TM_REXEC']}” in PATH not found! Using “R” instead." buttons "OK" default button "OK"'}
		ENV['TM_REXEC'] = nil
	end
end

cmd = "#{(ENV['TM_REXEC']==nil) ? 'R' : ENV['TM_REXEC']} -q --vanilla --encoding=UTF-8 --TMRHelperDaemon 2&> '#{$pipe_console}'"

FileUtils.rm_f($pipe_out)
FileUtils.rm_f($pipe_status)
FileUtils.rm_f($pipe_console)

%x{echo -en "TM_RHelper" > /tmp/textmate_Rhelper_status}
%x{echo -en "TM_RHelper" > /tmp/textmate_Rhelper_out}

PTY.spawn(cmd) { |r,w,pid|

	r.sync = FALSE

	# write r to the nirvana
	Thread.new {
		r.read
	}

	# Thread to destroy daemon after quitting TextMate
	Thread.new do
		# Check if TextMate is still running; if not terminate Help Daemon
		while TRUE
			sleep 10
			break if %x{ps -ax | grep "[0-9] /.*app.*/TextMate" | cut -d ' ' -f2}.empty?
		end
		w.puts("q('no')")
		FileUtils.rm_f($pipe_in)
		FileUtils.rm_f($pipe_out)
		FileUtils.rm_f($pipe_status)
		FileUtils.rm_f($pipe_console)
		FileUtils.rm_f("/tmp/textmate_Rhelper_head.html")
		FileUtils.rm_f("/tmp/textmate_Rhelper_data.html")
		FileUtils.rm_f("/tmp/textmate_Rhelper_search.html")
	end

	$fin = File.open($pipe_in, "r+")
	
	w.puts "source('RhelperScript.R')"

	%x{echo -en "STARTED" > '#{$pipe_status}'}

	while TRUE
		task = $fin.gets.chomp
		%x{echo -en "BUSY" > '#{$pipe_status}'}
		if task[0,1] == "@"
			w.puts "sink('/tmp/textmate_Rhelper_out');TM_Rdaemon#{task[1..-1]};sink(file=NULL);cat('READY',file='#{$pipe_status}',sep='')"
		else
			w.puts "sink('/tmp/textmate_Rhelper_out');#{task};sink(file=NULL);cat('READY',file='#{$pipe_status}',sep='')"
		end
    w.puts "cat('READY',file='#{$pipe_status}',sep='');while(sink.number()>0){sink(file=NULL)}"
	end
}
