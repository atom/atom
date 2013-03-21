grammar
  = tokens:( action / string / __)

/* "Lexical" elements */

action "action"
  = ("{" { return token({type: "source.js.embedded.pegjs"}) })
    (braced / nonBraceCharacters)*
    ("}" { return token({type: "source.js.embedded.pegjs"}) })

braced
  = $("{" (braced / nonBraceCharacters)* "}")

nonBraceCharacters
  = nonBraceCharacter+

nonBraceCharacter
  = [^{}]

equals    = "=" __
colon     = ":" __
semicolon = ";" __
slash     = "/" __
and       = "&" __
not       = "!" __
dollar    = "$" __
question  = "?" __
star      = "*" __
plus      = "+" __
lparen    = "(" __
rparen    = ")" __
dot       = "." __

/*
 * Modeled after ECMA-262, 5th ed., 7.6, but much simplified:
 *
 * * no Unicode escape sequences
 *
 * * "Unicode combining marks" and "Unicode connection punctuation" can't be
 *   part of the identifier
 *
 * * only [a-zA-Z] is considered a "Unicode letter"
 *
 * * only [0-9] is considered a "Unicode digit"
 *
 * The simplifications were made just to make the implementation little bit
 * easier, there is no "philosophical" reason behind them.
 *
 * Contrary to ECMA 262, the "$" character is not valid because it serves other
 * purpose in the grammar.
 */
identifier "identifier"
  = chars:$((letter / "_") (letter / digit / "_")*) __

/*
 * Modeled after ECMA-262, 5th ed., 7.8.4. (syntax & semantics, rules only
 * vaguely).
 */
literal "literal"
  = value:(doubleQuotedString / singleQuotedString) flags:"i"? __

string "string"
  = string:(doubleQuotedString / singleQuotedString) __

doubleQuotedString
  = ('"' { return token({type: ["string.quoted.double.js", "punctuation.definition.string.begin.pegjs"]}) })
    (doubleQuotedCharacter* { return token({type: "string.quoted.double.js"}) })
    ('"' { return token({type: ["string.quoted.double.js", "punctuation.definition.string.end.pegjs"]}) })

doubleQuotedCharacter
  = simpleDoubleQuotedCharacter
  / simpleEscapeSequence
  / zeroEscapeSequence
  / hexEscapeSequence
  / unicodeEscapeSequence
  / eolEscapeSequence

simpleDoubleQuotedCharacter
  = !('"' / "\\" / eolChar) char_:.

singleQuotedString
  = ("'" { return token({type: ["string.quoted.single.js", "punctuation.definition.string.begin.pegjs"]}) })
    (singleQuotedCharacter* { return token({type: "string.quoted.single.js"}) })
    ("'" { return token({type: ["string.quoted.single.js", "punctuation.definition.string.end.pegjs"]}) })

singleQuotedCharacter
  = simpleSingleQuotedCharacter
  / simpleEscapeSequence
  / zeroEscapeSequence
  / hexEscapeSequence
  / unicodeEscapeSequence
  / eolEscapeSequence

simpleSingleQuotedCharacter
  = !("'" / "\\" / eolChar) char_:.

class "character class"
  = "[" inverted:"^"? parts:(classCharacterRange / classCharacter)* "]" flags:"i"? __

classCharacterRange
  = begin:classCharacter "-" end:classCharacter

classCharacter
  = char_:bracketDelimitedCharacter

bracketDelimitedCharacter
  = simpleBracketDelimitedCharacter
  / simpleEscapeSequence
  / zeroEscapeSequence
  / hexEscapeSequence
  / unicodeEscapeSequence
  / eolEscapeSequence

simpleBracketDelimitedCharacter
  = !("]" / "\\" / eolChar) char_:.

simpleEscapeSequence
  = "\\" !(digit / "x" / "u" / eolChar) char_:.

zeroEscapeSequence
  = "\\0" !digit

hexEscapeSequence
  = "\\x" digits:$(hexDigit hexDigit)

unicodeEscapeSequence
  = "\\u" digits:$(hexDigit hexDigit hexDigit hexDigit)

eolEscapeSequence
  = "\\" eol:eol

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

__ = tokens:(whitespace / eol / comment)*

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
