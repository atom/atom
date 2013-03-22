grammar
  = __ initializer:initializer? rules:rule+

initializer
  = code:action semicolon?

rule
  = (name:identifier { return token({type: ["source.pegjs.ruleDefinition", "entity.name.type"]}) })
    displayName:string? equals expression:expression semicolon?

expression
  = choice

choice
  = head:sequence tail:(slash sequence)*

sequence
  = elements:labeled* code:action
  / elements:labeled*

labeled
  = (label:identifier { return token({type: "variable.parameter"}) })
    colon expression:prefixed
  / prefixed

prefixed
  = dollar expression:suffixed
  / and code:action
  / and expression:suffixed
  / not code:action
  / not expression:suffixed
  / suffixed

suffixed
  = expression:primary question
  / expression:primary star
  / expression:primary plus
  / primary

primary
  = name:identifier !(string? equals)
  / literal
  / class
  / dot
  / lparen expression:expression rparen

/* "Lexical" elements */

action "action"
  = ("{" { return token({type: "source.js.embedded.pegjs"}) })
    (braced / nonBraceCharacters)*
    ("}" { return token({type: "source.js.embedded.pegjs"}) })
    __

braced
  = $("{" (braced / nonBraceCharacters)* "}")

nonBraceCharacters
  = nonBraceCharacter+

nonBraceCharacter
  = [^{}]

equals    = ("=" { return token({type: "source.pegjs.ruleDefinition"}) }) __
colon     = (":" { return token({type: "keyword.operator"}) }) __
semicolon = (";" { return token({type: "keyword.operator"}) }) __
slash     = ("/" { return token({type: "keyword.operator"}) }) __
and       = ("&" { return token({type: "keyword.operator"}) }) __
not       = ("!" { return token({type: "keyword.operator"}) }) __
dollar    = ("$" { return token({type: "keyword.operator"}) }) __
question  = ("?" { return token({type: "keyword.operator"}) }) __
star      = ("*" { return token({type: "keyword.operator"}) }) __
plus      = ("+" { return token({type: "keyword.operator"}) }) __
lparen    = ("(" { return token({type: "keyword.operator"}) }) __
rparen    = (")" { return token({type: "keyword.operator"}) }) __
dot       = ("." { return token({type: "keyword.operator"}) }) __

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
  = string:(
      ('"' { return token({type: "punctuation.definition.string.begin.pegjs"}) })
      doubleQuotedCharacter*
      ('"' { return token({type: "punctuation.definition.string.end.pegjs"}) })
    ) { return token({type: "string.quoted.double.pegjs", tokens: string}) }

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
  = string:(
      ("'" { return token({type: "punctuation.definition.string.begin.pegjs"}) })
      singleQuotedCharacter*
      ("'" { return token({type: "punctuation.definition.string.end.pegjs"}) })
    ) { return token({type: "string.quoted.single.js", tokens: string}) }

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

singleLineComment
  = comment:(doubleSlash singleLineCommentText)
  { return token({type: 'comment.line.double-slash.js', tokens: comment})}

singleLineCommentText
  = (!eolChar .)*

doubleSlash
  = "//" { return token({type: 'punctuation.definition.comment.js'})}

multiLineComment
  = comment:(slashStar multiLineCommentText starSlash)
    { return token({type: 'comment.block', tokens: comment}) }

multiLineCommentText
  = (!starSlash .)*

slashStar
  = "/*" { return token({type: 'punctuation.definition.comment.pegjs'}) }

starSlash
  = "*/" { return token({type: 'punctuation.definition.comment.pegjs'}) }

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
