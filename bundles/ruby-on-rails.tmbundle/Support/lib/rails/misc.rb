class String
  # Gets the line number of character +i+ (0-base index)
  def line_from_index(i)
    slice(0..i).count("\n")
  end

  # Gets the index of the beginning of line number +l+ (0-base index)
  def index_from_line(l)
    to_a.slice(0...l).join.length
  end

  # Temporarily replace "strings" with (parens) and :symbols with .notation.
  # Useful before a find_nearest_string_or_symbol search when method calls have
  # special meaning for lists of strings or symbols (e.g. javascript_include_tag)
  def unstringify_hash_arguments
    gsub(/'([^']+?)'(?=\s*=>)/, '(\1)').
    gsub(/"([^"]+?)"(?=\s*=>)/, '(\1)').
    gsub(/:(\w+)(?=\s*=>)/, '.\1').
    gsub(/(=>\s*)'([^']+?)'/, '\1(\2)').
    gsub(/(=>\s*)"([^"]+?)"/, '\1(\2)').
    gsub(/(=>\s*):(\w+)/, '\1.\2')
  end

  # Finds the nearest "string" or :symbol to +column_number+
  def find_nearest_string_or_symbol(column_number)
    re = /'([^']+?)'|"([^"]+)"|:([a-zA-Z0-9_]+)\b/
    matching_tokens = scan(re).flatten.compact
    # Which token is nearest to column_number?
    nearest_token = nearest_index = distance = nil
    matching_tokens.each do |token|
      i = index(token, column_number)
      if i and (distance.nil? or (column_number - i).abs < distance)
        nearest_token = token
        nearest_index = i
        distance = (column_number - i).abs
      end

      i = rindex(token, column_number)
      if i and (distance.nil? or ((column_number - i).abs - token.length) < distance)
        nearest_token = token
        nearest_index = i
        distance = (column_number - i).abs - token.length
      end
    end
    (nearest_token.nil?) ? nil : [nearest_token, nearest_index]
  end

  def underscore
    gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
  end

  def camelize
    gsub(/\/(.?)/) { "::" + $1.upcase }.gsub(/(^|_)(.)/) { $2.upcase }
  end
  alias camelcase camelize
end

