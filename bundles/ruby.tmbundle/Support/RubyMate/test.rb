# encoding: utf-8

# p __FILE__, $PROGRAM_NAME

at_exit { puts "I am <at> the exit!" }
puts "that’s nice"
STDERR.write "this is my important stuff\n"

system("echo '<strong>bad!</strong>' 1>&2")

require "erb"
foo = "bar"
p ERB.new("<%= foo %>").result

def charlie
  sheen
end

charlie
