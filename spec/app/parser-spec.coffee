Parser = require 'parser'
plist = require 'plist'
fs = require 'fs'
_ = require 'underscore'

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

      describe "when the line matches multiple patterns", ->
        it "returns multiple tokens, filling in regions that don't match patterns with tokens in the grammar's global scope", ->
          {tokens, state} = parser.getLineTokens(" return new foo.bar.Baz ")

          expect(tokens.length).toBe 7

          expect(tokens[0]).toEqual value: ' ', scopes: ['source.coffee']
          expect(tokens[1]).toEqual value: 'return', scopes: ['source.coffee', 'keyword.control.coffee']
          expect(tokens[2]).toEqual value: ' ', scopes: ['source.coffee']
          expect(tokens[3]).toEqual value: 'new', scopes: ['source.coffee', 'meta.class.instance.constructor', 'keyword.operator.new.coffee']
          expect(tokens[4]).toEqual value: ' ', scopes: ['source.coffee', 'meta.class.instance.constructor']
          expect(tokens[5]).toEqual value: 'foo.bar.Baz', scopes: ['source.coffee', 'meta.class.instance.constructor', 'entity.name.type.instance.coffee']
          expect(tokens[6]).toEqual value: ' ', scopes: ['source.coffee']
