#!/System/Library/Frameworks/Ruby.framework/Versions/1.8/usr/bin/ruby
require 'pp'
Dir.chdir(File.join((ENV["R_HOME"] || "/Library/Frameworks/R.framework/Resources"), "library"))
resources = Dir.glob("*/latex/*.tex")
# puts resources
results = ""
resources.each do |file|
  tex = File.read(file)
  terms = tex.scan(/\\begin\{verbatim\}\n(.*)\\end\{verbatim\}/m)
#.split(/\n+(?=[\w.]+\()/)
  results << terms[0][0] unless terms.empty?
  #.map{|line| line.gsub(/\n|(  )/,"")}
end
results.gsub!(/\s*#+(\s.*|)$/,"")   # Removes comments. Need to watch out for something like "#"
results.gsub!(/^\s*[\w.:]+\s*\n/,"") # Removes stupid lines like a:b
results.gsub!(/^(\.|<)\w.*|.*(\?topic|@name|survexp\.uswhite).*/,"") # removes function names starting with a dot, as well as other random stuff
results.gsub!(/.*value\n/,"") # Removes lines like: tsp(x) <- value
results.gsub!(/^\w\s+.*\n/,"") # Removes lines like: R CMD ...
results.gsub!(/^[\w.]*(?:\[|\$).*\n/,"")  # Removes lines starting with: x[[...]] or x$name
results.gsub!(/^[\w.:+-\/><\s;!&|"]*\n/,"") # Removes things like: time1 + time2
results.gsub!(/^(?:if|for|while|function)\(.*\n/,"") # Removes definitions of if/for/while/function
results.gsub!(/\n(?![\w.]+\()/," ") # Brings together arguments on different lines
results.gsub!(/[\t ]+/," ")
results.gsub!(/\s+$/,"")
# puts "Suspicious lines:"   # UNCOMMENT FOR DEBUGGIN
# pp results.scan(/^(.*[^ \w\(].\)) +(\w.*)/) #,"\\1\n\\2" # Try to fix some lines that got together
puts "=" * 40
puts results.split("\n").sort.uniq.join("\n")
