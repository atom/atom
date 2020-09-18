module.exports =
  unescapeEscapeSequence: (string) ->
    string.replace /\\(.)/gm, (match, char) ->
      if char is 't'
        '\t'
      else if char is 'n'
        '\n'
      else if char is 'r'
        '\r'
      else if char is '\\'
        '\\'
      else
        match
