Parser = require 'parser'
plist = require 'plist'
fs = require 'fs'
_ = require 'underscore'

fdescribe "Parser", ->
  parser = null

  beforeEach ->
    coffee_plist = fs.read(require.resolve 'CoffeeScriptBundle.tmbundle/Syntaxes/CoffeeScript.tmLanguage')
    plist.parseString coffee_plist, (err, grammar) ->
      parser = new Parser(grammar[0])

  describe ".getLineTokens(line, currentRule)", ->
    describe "when the entire line matches a single pattern with no capture groups", ->
      it "returns a single token with the correct scope", ->
        {tokens} = parser.getLineTokens("return")

        expect(tokens.length).toBe 1
        [token] = tokens
        expect(token.scopes).toEqual ['source.coffee', 'keyword.control.coffee']

    describe "when the entire line matches a single pattern with capture groups", ->
      it "returns a single token with the correct scope", ->
        {tokens} = parser.getLineTokens("new foo.bar.Baz")

        expect(tokens.length).toBe 3
        [newOperator, whitespace, className] = tokens
        expect(newOperator).toEqual value: 'new', scopes: ['source.coffee', 'meta.class.instance.constructor', 'keyword.operator.new.coffee']
        expect(whitespace).toEqual value: ' ', scopes: ['source.coffee', 'meta.class.instance.constructor']
        expect(className).toEqual value: 'foo.bar.Baz', scopes: ['source.coffee', 'meta.class.instance.constructor', 'entity.name.type.instance.coffee']

    describe "when the line matches multiple patterns", ->
      it "returns multiple tokens, filling in regions that don't match patterns with tokens in the grammar's global scope", ->
        {tokens} = parser.getLineTokens(" return new foo.bar.Baz ")

        expect(tokens.length).toBe 7

        expect(tokens[0]).toEqual value: ' ', scopes: ['source.coffee']
        expect(tokens[1]).toEqual value: 'return', scopes: ['source.coffee', 'keyword.control.coffee']
        expect(tokens[2]).toEqual value: ' ', scopes: ['source.coffee']
        expect(tokens[3]).toEqual value: 'new', scopes: ['source.coffee', 'meta.class.instance.constructor', 'keyword.operator.new.coffee']
        expect(tokens[4]).toEqual value: ' ', scopes: ['source.coffee', 'meta.class.instance.constructor']
        expect(tokens[5]).toEqual value: 'foo.bar.Baz', scopes: ['source.coffee', 'meta.class.instance.constructor', 'entity.name.type.instance.coffee']
        expect(tokens[6]).toEqual value: ' ', scopes: ['source.coffee']

    describe "when the line matches a begin/end pattern", ->
      it "returns tokens based on the beginCaptures, endCaptures and the child scope", ->
        {tokens} = parser.getLineTokens("'''single-quoted heredoc'''")

        expect(tokens.length).toBe 3

        expect(tokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
        expect(tokens[1]).toEqual value: "single-quoted heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
        expect(tokens[2]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

    describe "when begin/end pattern spans multiple lines", ->
      it "uses the currentRule returned by the first line to parse the second line", ->
        {tokens: firstTokens, stack} = parser.getLineTokens("'''single-quoted")
        {tokens: secondTokens, stack} = parser.getLineTokens("heredoc'''", stack)

        expect(firstTokens.length).toBe 2
        expect(secondTokens.length).toBe 2

        expect(firstTokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
        expect(firstTokens[1]).toEqual value: "single-quoted", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']

        expect(secondTokens[0]).toEqual value: "heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
        expect(secondTokens[1]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

   describe "when the line matches a begin/end pattern that contains sub-patterns", ->
     it "returns tokens within the begin/end scope based on the sub-patterns", ->
       {tokens} = parser.getLineTokens('"""heredoc with character escape \\t"""')

       expect(tokens.length).toBe 4

       expect(tokens[0]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
       expect(tokens[1]).toEqual value: "heredoc with character escape ", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee']
       expect(tokens[2]).toEqual value: "\\t", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'constant.character.escape.coffee']
       expect(tokens[3]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.end.coffee']