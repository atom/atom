TextMateGrammar = require 'text-mate-grammar'
TextMateBundle = require 'text-mate-bundle'
plist = require 'plist'
fs = require 'fs'
_ = require 'underscore'

describe "TextMateGrammar", ->
  grammar = null

  beforeEach ->
    coffeePlist = fs.read(require.resolve 'CoffeeScriptBundle.tmbundle/Syntaxes/CoffeeScript.tmLanguage')
    grammar = TextMateBundle.grammarForFileName("hello.coffee")

  describe ".getLineTokens(line, currentRule)", ->
    describe "when the entire line matches a single pattern with no capture groups", ->
      it "returns a single token with the correct scope", ->
        {tokens} = grammar.getLineTokens("return")

        expect(tokens.length).toBe 1
        [token] = tokens
        expect(token.scopes).toEqual ['source.coffee', 'keyword.control.coffee']

    describe "when the entire line matches a single pattern with capture groups", ->
      it "returns a single token with the correct scope", ->
        {tokens} = grammar.getLineTokens("new foo.bar.Baz")

        expect(tokens.length).toBe 3
        [newOperator, whitespace, className] = tokens
        expect(newOperator).toEqual value: 'new', scopes: ['source.coffee', 'meta.class.instance.constructor', 'keyword.operator.new.coffee']
        expect(whitespace).toEqual value: ' ', scopes: ['source.coffee', 'meta.class.instance.constructor']
        expect(className).toEqual value: 'foo.bar.Baz', scopes: ['source.coffee', 'meta.class.instance.constructor', 'entity.name.type.instance.coffee']

    describe "when the line matches multiple patterns", ->
      it "returns multiple tokens, filling in regions that don't match patterns with tokens in the grammar's global scope", ->
        {tokens} = grammar.getLineTokens(" return new foo.bar.Baz ")

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
        {tokens} = grammar.getLineTokens("'''single-quoted heredoc'''")

        expect(tokens.length).toBe 3

        expect(tokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
        expect(tokens[1]).toEqual value: "single-quoted heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
        expect(tokens[2]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

    describe "when begin/end pattern spans multiple lines", ->
      it "uses the currentRule returned by the first line to parse the second line", ->
        {tokens: firstTokens, stack} = grammar.getLineTokens("'''single-quoted")
        {tokens: secondTokens, stack} = grammar.getLineTokens("heredoc'''", stack)

        expect(firstTokens.length).toBe 2
        expect(secondTokens.length).toBe 2

        expect(firstTokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
        expect(firstTokens[1]).toEqual value: "single-quoted", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']

        expect(secondTokens[0]).toEqual value: "heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
        expect(secondTokens[1]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

    describe "when the line matches a pattern with optional capture groups", ->
      it "only returns tokens for capture groups that matched", ->
        {tokens} = grammar.getLineTokens("class Quicksort")
        expect(tokens.length).toBe 3
        expect(token[0].value).toBe "class"
        expect(token[1].value).toBe " "
        expect(token[2].value).toBe "Quicksort"

    describe "when the line matches a rule with nested capture groups and lookahead capture groups beyond the scope of the overall match", ->
      fit "creates distinct tokens for nested captures and does not return tokens beyond the scope of the overall capture", ->
        {tokens} = grammar.getLineTokens("  destroy: ->")

        for token in tokens
          console.log token.value, token.scopes.join(' ')

        expect(tokens.length).toBe 5

   describe "when the line matches a begin/end pattern that contains sub-patterns", ->
     it "returns tokens within the begin/end scope based on the sub-patterns", ->
       {tokens} = grammar.getLineTokens('"""heredoc with character escape \\t"""')

       expect(tokens.length).toBe 4

       expect(tokens[0]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
       expect(tokens[1]).toEqual value: "heredoc with character escape ", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee']
       expect(tokens[2]).toEqual value: "\\t", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'constant.character.escape.coffee']
       expect(tokens[3]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.end.coffee']

   describe "when the line matches a pattern that includes a rule", ->
     it "returns tokens based on the included rule", ->
       {tokens} = grammar.getLineTokens("7777777")
       expect(tokens.length).toBe 1
       expect(tokens[0]).toEqual value: '7777777', scopes: ['source.coffee', 'constant.numeric.coffee']

    describe "when the line is an interpolated string", ->
      it "returns the correct tokens", ->
        {tokens} = grammar.getLineTokens('"the value is #{@x} my friend"')

        expect(tokens[0]).toEqual value: '"', scopes: ["source.coffee","string.quoted.double.coffee","punctuation.definition.string.begin.coffee"]
        expect(tokens[1]).toEqual value: "the value is ", scopes: ["source.coffee","string.quoted.double.coffee"]
        expect(tokens[2]).toEqual value: '#{', scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[3]).toEqual value: "@x", scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","variable.other.readwrite.instance.coffee"]
        expect(tokens[4]).toEqual value: "}", scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[5]).toEqual value: " my friend", scopes: ["source.coffee","string.quoted.double.coffee"]
        expect(tokens[6]).toEqual value: '"', scopes: ["source.coffee","string.quoted.double.coffee","punctuation.definition.string.end.coffee"]

    describe "when the line has an interpolated string inside an interpolated string", ->
      it "returns the correct tokens", ->
        {tokens} = grammar.getLineTokens('"#{"#{@x}"}"')

        expect(tokens[0]).toEqual value: '"',  scopes: ["source.coffee","string.quoted.double.coffee","punctuation.definition.string.begin.coffee"]
        expect(tokens[1]).toEqual value: '#{', scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[2]).toEqual value: '"',  scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","string.quoted.double.coffee","punctuation.definition.string.begin.coffee"]
        expect(tokens[3]).toEqual value: '#{', scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[4]).toEqual value: '@x', scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","string.quoted.double.coffee","source.coffee.embedded.source","variable.other.readwrite.instance.coffee"]
        expect(tokens[5]).toEqual value: '}',  scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[6]).toEqual value: '"',  scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","string.quoted.double.coffee","punctuation.definition.string.end.coffee"]
        expect(tokens[7]).toEqual value: '}',  scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[8]).toEqual value: '"',  scopes: ["source.coffee","string.quoted.double.coffee","punctuation.definition.string.end.coffee"]

  describe "@buildCaptureTree(captures, startPositions)", ->
    it "converts a match array into a tree based on the nesting of its capture groups", ->
      # The example has multiple nested capture groups, w/ one lookahead group on the end -- [ij] -- that
      # is not included as part of the overall match and therefore excluded from the tree
      # (a((bc)d)e(f(g)(h))[ij]
      match = ["abcdefgh", "bcd", "bc", "fgh", "g", "h", "ij"]
      startPositions = [0, 1, 1, 5, 6, 7, 8]

      tree = TextMateGrammar.buildCaptureTree(match, startPositions)
      expect(tree).toEqual
        text: "abcdefgh"
        index: 0
        position: 0
        captures: [
          {
            text: "bcd"
            index: 1
            position: 1
            captures: [{ text: "bc", index: 2, position: 1 }]
          },
          {
            text: "fgh"
            index: 3
            position: 5
            captures: [
              { text: "g", index: 4, position: 6 }
              { text: "h", index: 5, position: 7 }
            ]
          }
        ]

