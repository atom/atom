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
      describe "when line matches a single pattern with no capture groups", ->
        fit "returns a single token with the correct scope", ->
          {tokens, state} = parser.getLineTokens("return")
          expect(token.scopes).toEqual ['source.coffee', 'keyword.control.coffee']
