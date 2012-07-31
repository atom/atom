Parser = require 'parser'
plist = require 'plist'
fs = require 'fs'

describe "Parser", ->
  parser = null

  beforeEach ->
    coffee_plist = fs.read(require.resolve 'CoffeeScriptBundle.tmbundle/Syntaxes/CoffeeScript.tmLanguage')
    plist.parseString coffee_plist, (err, grammar) ->
      parser = new Parser(grammar[0])

  describe ".getLineTokens(line, state)", ->
    describe "when the state is omitted (start state)", ->
      describe "when the entire line matches a single pattern with no capture groups", ->
        it "returns a single token with the correct scope", ->
          {tokens, state} = parser.getLineTokens("return")

          console.log tokens

          expect(tokens.length).toBe 1
          [token] = tokens
          expect(token.scopes).toEqual ['source.coffee', 'keyword.control.coffee']

      describe "when the entire line matches a single pattern with capture groups", ->
        it "returns a single token with the correct scope", ->
          {tokens, state} = parser.getLineTokens("new foo.bar.Baz")

          expect(tokens.length).toBe 3
          [newOperator, whitespace, className] = tokens
          expect(newOperator).toEqual value: 'new', scopes: ['source.coffee', 'meta.class.instance.constructor', 'keyword.operator.new.coffee']
          expect(whitespace).toEqual value: ' ', scopes: ['source.coffee', 'meta.class.instance.constructor']
          expect(className).toEqual value: 'foo.bar.Baz', scopes: ['source.coffee', 'meta.class.instance.constructor', 'entity.name.type.instance.coffee']

