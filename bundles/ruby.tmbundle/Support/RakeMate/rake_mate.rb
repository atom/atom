#!/usr/bin/env ruby

require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/ui"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/web_preview"

require "run_rake_task"

require "erb"
include ERB::Util
require "pstore"

RAKEMATE_VERSION = "2.0.0".freeze
DEFAULT_TASK     = "(default task)".freeze
RAKEFILE_DIR     = (ENV["TM_PROJECT_DIRECTORY"] || ENV["TM_DIRECTORY"]).freeze

def html_error(error)
  puts error
  puts "</pre>"
  html_footer
  exit
end

html_header("RakeMate", "Rake")
puts <<-HTML
<pre>RakeMate v#{RAKEMATE_VERSION} running on Ruby v#{RUBY_VERSION} (#{ENV["TM_RUBY"].strip})
&gt;&gt;&gt; #{RAKEFILE_DIR}/Rakefile

HTML

rake = ENV["TM_RAKE"]
if rake.nil? or not File.exist? rake
  html_error("Rake not found.  Please set TM_RAKE.")
end

prefs = PStore.new( File.expand_path( "~/Library/Preferences/" +
                                      "com.macromates.textmate.run_rake" ) )

Dir.chdir(RAKEFILE_DIR)
tasks = fetch_rake_tasks

unless $?.exited?
  html_error("Could not fetch task list.")
end
if tasks.include? "No Rakefile found"
  html_error("Could not locate a Rakefile in #{RAKEFILE_DIR}.")
end

tasks = [DEFAULT_TASK] + tasks.grep(/^rake\s+(\S+)/) { |t| t.split[1] }
if last_task = tasks.index(prefs.transaction(true) { prefs[RAKEFILE_DIR] })
  tasks.unshift(tasks.slice!(last_task))
end

if task = TextMate::UI.request_item( :title   => "Rake Tasks",
                               :prompt  => "Select a task to execute:",
                               :items   => tasks,
                               :button1 => "Run Task")
  prefs.transaction { prefs[RAKEFILE_DIR] = task }

  testing = task =~ /test/i || task == DEFAULT_TASK
  run_rake_task(task == DEFAULT_TASK ? nil : task) do |line, mode|
    if testing and line =~ /^\d+ tests, \d+ assertions, (\d+) failures, (\d+) errors/
      print "<span style=\"color: ",
            ($1 + $2 == "00" ? "green" : "red"),
            "\">#{line.chomp}</span><br />"
    elsif testing and line =~ /^(\s+)(\S.*?):(\d+)(?::in\s*`(.*?)')?/ and File.exist? $2
      indent, file, line, method = $1, $2, $3, $4

      url, display_name = '', 'untitled document';
      unless file == "-"
        url = '&url=file://' + e_url(File.expand_path(file))
        display_name = File.basename(file)
      end

      print "#{indent}<a class='near' href='txmt://open?line=#{line + url}'>" +
            (method ? "method #{h method}" : '<em>at top level</em>') +
            "</a> in <strong>#{h display_name}</strong> at line #{line}<br/>"
    elsif mode == :char_by_char
      if %w[. E F].include? line
        print line.sub(/^[EF]$/, "<span style=\"color: red\">\\&</span>"),
              "<br style=\"display: none\"/>"
      else
        print htmlize(line)
        $stdout.flush
        next :line_by_line
      end
    else
      print htmlize(line)
    end
    $stdout.flush
    if mode == :char_by_char or (testing and line =~ /^Started\s*/)
      :char_by_char
    else
      :line_by_line
    end
  end
end

puts "</pre>"
html_footer
