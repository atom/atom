require ENV['TM_SUPPORT_PATH'] + "/lib/escape.rb"
class Lexer
  Token = Struct.new(:name, :pattern)
  
  def initialize
    @tokens = Array.new
  end
  
  def add_token(*args)
    @tokens << Token.new(*args)
  end
  
  def lex(data)
    copy, result = data.dup, Array.new
    until copy.empty?
      @tokens.find { |t|
        copy.sub!(t.pattern, "") && (t.name.nil? || result << [t.name, $&])
      } || raise(ArgumentError, "Malformed data could not be lexed correctly: #{data.inspect}. Copy is: #{copy.inspect.inspect}.   Parsed is:  #{result.inspect}")
    end
    result
  end
end
class CommandParser
  def self.snippet(str)
    self.parse(self.lex(str))
  end
  def self.lex(str)
    lexer = Lexer.new
    [ [ :fun_begin,      /\A(?:\w|\.)*\(/                                     ],
      [ :assignment,     /\A[\w.]+\s*<?=(?!=)\s*/                             ],
      [ :term,           /\A[$\w.]+(?=,|)/                                    ],
      [ :term,           /\A\.\.\./                                           ],
      [ :comma,          /\A,\s*/                                             ],
      [ :fun_end,        /\A\)/                                               ],
      [ :quoted,         /\A"(?:\\.|[^\\"]+)*"/                               ],
      [ :quoted,         /\A'(?:\\.|[^\\']+)*'/                               ],
      [ :operator,       /\A\s*([\+\-\*\/^]|&&|\|\||!=?|<=?|>=?|==|~|%|;)\s*/ ],
      [ :number,         /\A\d+(\.\d+)?/                                      ],
      [ :brace_begin,    /\A\{/                                               ],
      [ :brace_end,      /\A\}/                                               ],
      [ :bracket_begin,  /\A\[/                                               ],
      [ :bracket_end,  /\A\]/                                                 ],
      [ :list_separator, /\A:/                                                ],
      [ nil,             /\A\s+/                                              ] ].each do |name, regex|
      lexer.add_token(name, regex)
    end
    lexer.lex(str)
  end
  def self.parse(data)
    snippet = ""
    snippet_counter = -1
    stack = []
    until data.empty?
      type,match = data.shift
      if !stack.empty? && stack.last == :assignment && type.to_s =~ /comma|end$/ then
        snippet << "}"
        stack.pop
      end
      case type
      when :fun_begin, :brace_begin, :bracket_begin
        stack << :group
        snippet << "${#{snippet_counter+=1}:#{e_sn match}${#{snippet_counter+=1}:"
      when :assignment
        stack << :assignment
        snippet << "#{e_sn match}${#{snippet_counter+=1}:"
      when :comma
        snippet << ("}${#{snippet_counter+=1}:" + e_sn(match))
      when :brace_end, :bracket_end, :fun_end
        snippet << "}#{e_sn match}}"
        stack.pop
      when :quoted
        snippet << "${#{snippet_counter+=1}:#{match[0..0]}${#{snippet_counter+=1}:#{e_sn match[1..-2].gsub("}","\\}")}}#{match[-1..-1]}}"
      else
        snippet << e_sn(match)
      end
    end
    (pp stack;raise "Too many levels: #{snippet}. ") unless stack.length == 0
    snippet[4..-2]
  end
end
# This is for testing
# require 'pp'
# data=DATA.read.split("\n")
# 5.times do
#   d = data[rand(2834)]
#   # i=0
# # data.each do |d|
#   pp [d,CommandParser.snippet(d)]
#   # puts "Checking command no: #{i+=1}"
# end