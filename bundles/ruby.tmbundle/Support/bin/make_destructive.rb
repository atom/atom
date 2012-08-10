#!/usr/bin/env ruby

require "escape"

CURSOR = [0xFFFC].pack("U").freeze
line   = STDIN.read
begin
  line[ENV["TM_LINE_INDEX"].to_i, 0] = CURSOR
rescue
  exit
end

line.sub!(/\b(chomp|chop|collect|compact|delete|downcase|exit|flatten|gsub|lstrip|map|next|reject|reverse|rstrip|slice|sort|squeeze|strip|sub|succs|swapcase|tr|tr_s|uniq|upcase)\b(?!\!)/, "\\1!")

line = e_sn(line)
line.sub!(CURSOR, "$0")

print line
