#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby
require File.join(ENV['TM_SUPPORT_PATH'], "lib/exit_codes.rb")
require File.join(ENV['TM_SUPPORT_PATH'], "lib/ui.rb")
require File.join(ENV['TM_SUPPORT_PATH'], 'lib/current_word.rb')

require File.join(ENV['TM_BUNDLE_SUPPORT'], 'lib/popen3.rb')

word = Word.current_word('\w\.')

stdin, stdout, stderr = popen3("R", "--vanilla", "--no-readline", "--slave", "--encoding=UTF-8")

stdin.write(File.read(File.join(ENV['TM_BUNDLE_SUPPORT'], 'getSig.R')))

wordEsc = word.gsub("\\|'", "\\\\\\0")
wordReg = Regexp.escape(word).gsub("\\|'", "\\\\\\0")
stdin.puts("cat(paste(getSig(if ('#{wordEsc}' %in% (ary <- sort(apropos('^#{wordReg}', mode='function')))) '#{wordEsc}' else ary), collapse='\\n'))")
stdin.close

text = stdout.read()

TextMate.exit_show_tool_tip("No function signature known for `#{word}'") if text.empty?

functions = text.split("\n")
if functions.size == 1
  function = functions.first
else
  # term = TextMate::UI.request_item :title => "Snippet for Command", :prompt => "There were more than one matching commands found", :items => functions.collect { |f| f[0...f.index("(")] }
  idx = TextMate::UI.menu functions.collect { |f| f[0...f.index("(")] }
  TextMate.exit_discard if idx.nil?
  function = functions[idx]
  # function = functions.find("") { |f| f[0..term.length] == term + "(" }
end

TextMate.exit_discard if function.empty?

if ENV['TM_SELECTED_TEXT'].nil? or ENV['TM_SELECTED_TEXT'].empty?
  # we didn't use selected text but instead pulled the word from the line
  # so lets only insert everything after the term
  print function[word.length..-1]
NameError
else
  print function
end
