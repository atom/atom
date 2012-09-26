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

    describe "when the line doesn't match any patterns", ->
      it "returns the entire line as a single simple token with the grammar's scope", ->
        textGrammar = TextMateBundle.grammarForFileName('foo.txt')
        {tokens} = textGrammar.getLineTokens("abc def")
        expect(tokens.length).toBe 1

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

    describe "when the line matches a pattern with optional capture groups", ->
      it "only returns tokens for capture groups that matched", ->
        {tokens} = grammar.getLineTokens("class Quicksort")
        expect(tokens.length).toBe 3
        expect(tokens[0].value).toBe "class"
        expect(tokens[1].value).toBe " "
        expect(tokens[2].value).toBe "Quicksort"

    describe "when the line matches a rule with nested capture groups and lookahead capture groups beyond the scope of the overall match", ->
      it "creates distinct tokens for nested captures and does not return tokens beyond the scope of the overall capture", ->
        {tokens} = grammar.getLineTokens("  destroy: ->")
        expect(tokens.length).toBe 6
        expect(tokens[0]).toEqual(value: '  ', scopes: ["source.coffee", "meta.function.coffee"])
        expect(tokens[1]).toEqual(value: 'destro', scopes: ["source.coffee", "meta.function.coffee", "entity.name.function.coffee"])
        # this dangling 'y' with a duplicated scope looks wrong, but textmate yields the same behavior. probably a quirk in the coffee grammar.
        expect(tokens[2]).toEqual(value: 'y', scopes: ["source.coffee", "meta.function.coffee", "entity.name.function.coffee", "entity.name.function.coffee"])
        expect(tokens[3]).toEqual(value: ':', scopes: ["source.coffee", "keyword.operator.coffee"])
        expect(tokens[4]).toEqual(value: ' ', scopes: ["source.coffee"])
        expect(tokens[5]).toEqual(value: '->', scopes: ["source.coffee", "storage.type.function.coffee"])

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

    describe "when the line is empty", ->
      it "returns a single token which has the global scope", ->
       {tokens} = grammar.getLineTokens('')
       expect(tokens[0]).toEqual value: '',  scopes: ["source.coffee"]

    describe "when the line matches a pattern with a 'contentName'", ->
      it "creates tokens using the content of contentName as the token name", ->
        grammar = TextMateBundle.grammarForFileName("sample.txt")
        {tokens} = grammar.getLineTokens('ok, cool')
        expect(tokens[0]).toEqual value: 'ok, cool',  scopes: ["text.plain", "meta.paragraph.text"]

    describe "when the line matches a pattern with no `name` or `contentName`", ->
      it "creates tokens without adding a new scope", ->
        grammar = TextMateBundle.grammarsByFileType["rb"]
        {tokens} = grammar.getLineTokens('%w|oh \\look|')
        expect(tokens.length).toBe 5
        expect(tokens[0]).toEqual value: '%w|',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby", "punctuation.definition.string.begin.ruby"]
        expect(tokens[1]).toEqual value: 'oh ',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]
        expect(tokens[2]).toEqual value: '\\l',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]
        expect(tokens[3]).toEqual value: 'ook',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]

    describe "when the line matches a begin/end pattern", ->
      it "returns tokens based on the beginCaptures, endCaptures and the child scope", ->
        {tokens} = grammar.getLineTokens("'''single-quoted heredoc'''")

        expect(tokens.length).toBe 3

        expect(tokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
        expect(tokens[1]).toEqual value: "single-quoted heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
        expect(tokens[2]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

      describe "when the pattern spans multiple lines", ->
        it "uses the currentRule returned by the first line to parse the second line", ->
          {tokens: firstTokens, stack} = grammar.getLineTokens("'''single-quoted")
          {tokens: secondTokens, stack} = grammar.getLineTokens("heredoc'''", stack)

          expect(firstTokens.length).toBe 2
          expect(secondTokens.length).toBe 2

          expect(firstTokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
          expect(firstTokens[1]).toEqual value: "single-quoted", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']

          expect(secondTokens[0]).toEqual value: "heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
          expect(secondTokens[1]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

      describe "when the pattern contains sub-patterns", ->
        it "returns tokens within the begin/end scope based on the sub-patterns", ->
          {tokens} = grammar.getLineTokens('"""heredoc with character escape \\t"""')

          expect(tokens.length).toBe 4

          expect(tokens[0]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
          expect(tokens[1]).toEqual value: "heredoc with character escape ", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee']
          expect(tokens[2]).toEqual value: "\\t", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'constant.character.escape.coffee']
          expect(tokens[3]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.end.coffee']

      describe "when the end pattern contains a back reference", ->
        it "constructs the end rule based on its back-references to captures in the begin rule", ->
          grammar = TextMateBundle.grammarsByFileType["rb"]
          {tokens} = grammar.getLineTokens('%w|oh|,')
          expect(tokens.length).toBe 4
          expect(tokens[0]).toEqual value: '%w|',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby", "punctuation.definition.string.begin.ruby"]
          expect(tokens[1]).toEqual value: 'oh',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]
          expect(tokens[2]).toEqual value: '|',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby", "punctuation.definition.string.end.ruby"]
          expect(tokens[3]).toEqual value: ',',  scopes: ["source.ruby", "punctuation.separator.object.ruby"]

        fit "allows the rule containing that end pattern to be pushed to the stack multiple times", ->
          grammar = TextMateBundle.grammarsByFileType["rb"]
          {tokens} = grammar.getLineTokens('%Q+matz had some #{%Q-crazy ideas-} for ruby syntax+ # damn.')
          console.log tokens
