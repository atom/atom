{

}

/*
grammar
  = __ initializer:initializer? rules:rule+ {
      var patterns = rules;
      if (initializer) { patterns.unshift(initializer) }
      return {
        scopeName: 'source.pegjs',
        fileTypes: ['pegjs'],
        foldingStartMarker: '\{*$',
        foldingStopMarker: '^\s*\}',
        rules: [initializer, rules],
      };
    }

rule
  = name:identifier displayName:string? equals expression:expression semicolon? {
      return rule('source.pegjs.ruleDefinition',
                  [name, displayName, equals, expression, semicolon]);
    }
*/

__ = (whitespace / eol / comment)*

/* Modeled after ECMA-262, 5th ed., 7.4. */
comment "comment"
  = singleLineComment
  / multiLineComment

singleLineComment
  = "//" (!eolChar .)*

multiLineComment
  = "/*" (!"*/" .)* "*/"

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