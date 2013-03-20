
__ = tokens:(whitespace / eol / comment)* { return token({tokens: tokens}) }

/* Modeled after ECMA-262, 5th ed., 7.4. */
comment "comment"
  = comment:(singleLineComment / multiLineComment)
    { return token({type: "comment", tokens: comment}) }

singleLineComment
  = "//" (!eolChar .)*
    { return token({type: 'comment.line.double-slash'}) }

multiLineComment
  = "/*" (!"*/" .)* "*/" { return token({type: 'comment.block'}) }

/* Modeled after ECMA-262, 5th ed., 7.3. */
eol "end of line"
  = "\n"
  / "\r\n"
  / "\r"
  / "\u2028"
  / "\u2029"
  { return token() }

eolChar
  = [\n\r\u2028\u2029]
    { return token() }

/* Modeled after ECMA-262, 5th ed., 7.2. */
whitespace "whitespace"
  = [ \t\v\f\u00A0\uFEFF\u1680\u180E\u2000-\u200A\u202F\u205F\u3000] { return token() }