#!/usr/bin/env ruby
# encoding: utf-8

# Copyright:
#   (c) 2006 InquiryLabs, Inc.
#   Visit us at http://inquirylabs.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Runs 'rake' and executes a particular task

require 'optparse'
require 'rails_bundle_tools'
require "#{ENV["TM_SUPPORT_PATH"]}/lib/escape"
require "#{ENV["TM_SUPPORT_PATH"]}/lib/web_preview"

$RAKEMATE_VERSION = "$Revision$"

Dir.chdir TextMate.project_directory

options = {}

task = ARGV.shift

OptionParser.new do |opts|
  opts.banner = "Usage: rake_helper.rb [options]"

  opts.separator ""
  opts.separator "Rake helper options:"

  opts.on("-q", "--question [QUESTION TEXT]", "Ask a question before running rake.") do |question|
    options[:question] = question
  end

  opts.on("-a", "--answer [ANSWER TEXT]", "Default answer for the question.") do |answer|
    options[:answer] = answer
  end

  opts.on("-v", "--variable [VARIABLE]", "Variable to assign the ANSWER to.") do |variable|
    options[:variable] = variable
  end

  opts.on("-t", "--title [TITLE TEXT]", "Title of pop-up window.") do |title|
    options[:title] = title
  end
end.parse!

if options[:question]
  unless options[:answer] = TextMate::UI.request_string(
    :title => options[:title] || "Rake", 
    :default => options[:answer] || "",
    :prompt => options[:question],
    :button1 => 'Continue'
  )
    TextMate.exit_discard
  end
end

command = "rake #{task}"
command += " #{options[:variable]}=#{options[:answer]}" if options[:variable] && options[:answer]

# puts "<span style='color:blue; font-size: 1.2em'>#{options.inspect}</span><br>"

reports = {
  "migrate" => "Migration Report",
  "db:migrate" => "Migration Report"
}

puts html_head(:window_title => "#{task} — RakeMate", :page_title => 'RakeMate', :sub_title => 'Rake')
puts <<-HTML
    <div id="report_title">#{reports[task] || "Rake Report"}</div>
    <div id="rake_command">#{command}</div>
    <div><!-- Script output -->
			<pre><strong>RakeMate r#{$RAKEMATE_VERSION[/\d+/]}</strong>

<div style="white-space: normal; -khtml-nbsp-mode: space; -khtml-line-break: after-white-space;"> <!-- Script output -->
HTML

$stdout.flush

output = `#{command}`
lines = output.to_a
# Remove the test output from rake output
lines.pop if lines[-1] =~ /0 tests, 0 assertions, 0 failures, 0 errors/

report = ""

case task
when "db:migrate", "migrate"
  inside_table = false
  lines.each do |line|
    case line
      when /^==\s+/
        # Replace == headings with <h2></h2>
        line.gsub!(/^==\s+([^=]+)[=\s]*$/, "<span class=\"heading\">\\1</span>")
        # Replace parenthetical times with time class
        line.gsub!(/(\([\d\.]+s\))/, "<span class=\"time\">\\1</span>")
        # Show details inside table
        if !inside_table
          line << "<table>"
        else
          line << "</table>"
        end
        inside_table = !inside_table
      when /^--\s+(.+)$/
        # Show command inside table cell
        line = "<tr><td>#{$1}</td>"
      when /^\s+->(.+)$/
        # Show execution time inside table cell
        line = "<td class=\"time\">#{$1}</td></tr>\n"
      else
        line += "<br/>"
    end
    report << line
  end
  report << "</table>" if inside_table
else
  report += lines.join("<br>")
end

report += "<div class='done'>Done</div>"
puts report

puts <<-HTML
      </div>
    </div>
  </body>
</html>
HTML
