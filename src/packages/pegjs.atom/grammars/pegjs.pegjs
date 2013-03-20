grammar
  = tokens:( __ / digit* / hexDigit* / letter*) { return token({tokens: tokens}) }

__ = tokens:(whitespace / eol / comment)*

digit
  = [0-9]

hexDigit
  = [0-9a-fA-F]

letter
  = lowerCaseLetter
  / upperCaseLetter

lowerCaseLetter
  = [a-z]

upperCaseLetter
  = [A-Z]

/* Modeled after ECMA-262, 5th ed., 7.4. */
comment "comment"
  = comment:(singleLineComment / multiLineComment)
    { return token({type: "comment", tokens: comment}) }

singleLineComment
  = doubleSlash singleLineCommentText

singleLineCommentText
  = (!eolChar .)* { return token({type: 'punctuation.definition.comment.js'}) }

doubleSlash
  = "//"
  {
    var types = ['comment.line.double-slash.js',
                 'punctuation.definition.comment.js']

    return token({type: types})
  }

multiLineComment
  = "/*" (!"*/" .)* "*/" { return token({type: 'comment.block'}) }

/* Modeled after ECMA-262, 5th ed., 7.3. */
eol "end of line"
  = "\n"
  / "\r\n"
  / "\r"
  / "\u2028"
  / "\u2029"

eolChar
  = [\n\r\u2028\u2029]

/* Modeled after ECMA-262, 5th ed., 7.2. */
whitespace "whitespace"
  = [ \t\v\f\u00A0\uFEFF\u1680\u180E\u2000-\u200A\u202F\u205F\u3000]
