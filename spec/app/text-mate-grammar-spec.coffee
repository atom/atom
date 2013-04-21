TextMateGrammar = require 'text-mate-grammar'
TextMatePackage = require 'text-mate-package'
plist = require 'plist'
fsUtils = require 'fs-utils'
_ = require 'underscore'

describe "TextMateGrammar", ->
  grammar = null

  beforeEach ->
    atom.activatePackage('text.tmbundle', sync: true)
    atom.activatePackage('javascript.tmbundle', sync: true)
    atom.activatePackage('coffee-script-tmbundle', sync: true)
    atom.activatePackage('ruby.tmbundle', sync: true)
    atom.activatePackage('html.tmbundle', sync: true)
    atom.activatePackage('php.tmbundle', sync: true)
    grammar = syntax.selectGrammar("hello.coffee")

  describe "@loadSync(path)", ->
    it "loads grammars from plists", ->
      grammar = TextMateGrammar.loadSync(fsUtils.resolveOnLoadPath('packages/text.tmbundle/Syntaxes/Plain text.plist'))
      expect(grammar.scopeName).toBe "text.plain"
      {tokens} = grammar.tokenizeLine("this text is so plain. i love it.")
      expect(tokens[0]).toEqual value: "this text is so plain. i love it.", scopes: ["text.plain", "meta.paragraph.text"]

    it "loads grammars from cson files", ->
      grammar = TextMateGrammar.loadSync(fsUtils.resolveOnLoadPath('package-with-grammars/grammars/alot.cson'))
      expect(grammar.scopeName).toBe "source.alot"
      {tokens} = grammar.tokenizeLine("this is alot of code")
      expect(tokens[1]).toEqual value: "alot", scopes: ["source.alot", "keyword.alot"]

  describe ".tokenizeLine(line, ruleStack)", ->
    describe "when the entire line matches a single pattern with no capture groups", ->
      it "returns a single token with the correct scope", ->
        {tokens} = grammar.tokenizeLine("return")

        expect(tokens.length).toBe 1
        [token] = tokens
        expect(token.scopes).toEqual ['source.coffee', 'keyword.control.coffee']

    describe "when the entire line matches a single pattern with capture groups", ->
      it "returns a single token with the correct scope", ->
        {tokens} = grammar.tokenizeLine("new foo.bar.Baz")

        expect(tokens.length).toBe 3
        [newOperator, whitespace, className] = tokens
        expect(newOperator).toEqual value: 'new', scopes: ['source.coffee', 'meta.class.instance.constructor', 'keyword.operator.new.coffee']
        expect(whitespace).toEqual value: ' ', scopes: ['source.coffee', 'meta.class.instance.constructor']
        expect(className).toEqual value: 'foo.bar.Baz', scopes: ['source.coffee', 'meta.class.instance.constructor', 'entity.name.type.instance.coffee']

    describe "when the line doesn't match any patterns", ->
      it "returns the entire line as a single simple token with the grammar's scope", ->
        textGrammar = syntax.selectGrammar('foo.txt')
        {tokens} = textGrammar.tokenizeLine("abc def")
        expect(tokens.length).toBe 1

    describe "when the line matches multiple patterns", ->
      it "returns multiple tokens, filling in regions that don't match patterns with tokens in the grammar's global scope", ->
        {tokens} = grammar.tokenizeLine(" return new foo.bar.Baz ")

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
        {tokens} = grammar.tokenizeLine("class Quicksort")
        expect(tokens.length).toBe 3
        expect(tokens[0].value).toBe "class"
        expect(tokens[1].value).toBe " "
        expect(tokens[2].value).toBe "Quicksort"

    describe "when the line matches a rule with nested capture groups and lookahead capture groups beyond the scope of the overall match", ->
      it "creates distinct tokens for nested captures and does not return tokens beyond the scope of the overall capture", ->
        {tokens} = grammar.tokenizeLine("  destroy: ->")
        expect(tokens.length).toBe 6
        expect(tokens[0]).toEqual(value: '  ', scopes: ["source.coffee"])
        expect(tokens[1]).toEqual(value: 'destro', scopes: ["source.coffee", "meta.function.coffee", "entity.name.function.coffee"])
        # this dangling 'y' with a duplicated scope looks wrong, but textmate yields the same behavior. probably a quirk in the coffee grammar.
        expect(tokens[2]).toEqual(value: 'y', scopes: ["source.coffee", "meta.function.coffee", "entity.name.function.coffee", "entity.name.function.coffee"])
        expect(tokens[3]).toEqual(value: ':', scopes: ["source.coffee", "keyword.operator.coffee"])
        expect(tokens[4]).toEqual(value: ' ', scopes: ["source.coffee"])
        expect(tokens[5]).toEqual(value: '->', scopes: ["source.coffee", "storage.type.function.coffee"])

    describe "when the line matches a pattern that includes a rule", ->
      it "returns tokens based on the included rule", ->
        {tokens} = grammar.tokenizeLine("7777777")
        expect(tokens.length).toBe 1
        expect(tokens[0]).toEqual value: '7777777', scopes: ['source.coffee', 'constant.numeric.coffee']

    describe "when the line is an interpolated string", ->
      it "returns the correct tokens", ->
        {tokens} = grammar.tokenizeLine('"the value is #{@x} my friend"')

        expect(tokens[0]).toEqual value: '"', scopes: ["source.coffee","string.quoted.double.coffee","punctuation.definition.string.begin.coffee"]
        expect(tokens[1]).toEqual value: "the value is ", scopes: ["source.coffee","string.quoted.double.coffee"]
        expect(tokens[2]).toEqual value: '#{', scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[3]).toEqual value: "@x", scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","variable.other.readwrite.instance.coffee"]
        expect(tokens[4]).toEqual value: "}", scopes: ["source.coffee","string.quoted.double.coffee","source.coffee.embedded.source","punctuation.section.embedded.coffee"]
        expect(tokens[5]).toEqual value: " my friend", scopes: ["source.coffee","string.quoted.double.coffee"]
        expect(tokens[6]).toEqual value: '"', scopes: ["source.coffee","string.quoted.double.coffee","punctuation.definition.string.end.coffee"]

    describe "when the line has an interpolated string inside an interpolated string", ->
      it "returns the correct tokens", ->
        {tokens} = grammar.tokenizeLine('"#{"#{@x}"}"')

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
       {tokens} = grammar.tokenizeLine('')
       expect(tokens[0]).toEqual value: '',  scopes: ["source.coffee"]

    describe "when the line matches no patterns", ->
      it "does not infinitely loop", ->
        grammar = syntax.selectGrammar("sample.txt")
        {tokens} = grammar.tokenizeLine('hoo')
        expect(tokens.length).toBe 1
        expect(tokens[0]).toEqual value: 'hoo',  scopes: ["text.plain", "meta.paragraph.text"]

    describe "when the line matches a pattern with a 'contentName'", ->
      it "creates tokens using the content of contentName as the token name", ->
        grammar = syntax.selectGrammar("sample.txt")
        {tokens} = grammar.tokenizeLine('ok, cool')
        expect(tokens[0]).toEqual value: 'ok, cool',  scopes: ["text.plain", "meta.paragraph.text"]

    describe "when the line matches a pattern with no `name` or `contentName`", ->
      it "creates tokens without adding a new scope", ->
        grammar = syntax.selectGrammar('foo.rb')
        {tokens} = grammar.tokenizeLine('%w|oh \\look|')
        expect(tokens.length).toBe 5
        expect(tokens[0]).toEqual value: '%w|',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby", "punctuation.definition.string.begin.ruby"]
        expect(tokens[1]).toEqual value: 'oh ',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]
        expect(tokens[2]).toEqual value: '\\l',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]
        expect(tokens[3]).toEqual value: 'ook',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]

    describe "when the line matches a begin/end pattern", ->
      it "returns tokens based on the beginCaptures, endCaptures and the child scope", ->
        {tokens} = grammar.tokenizeLine("'''single-quoted heredoc'''")

        expect(tokens.length).toBe 3

        expect(tokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
        expect(tokens[1]).toEqual value: "single-quoted heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
        expect(tokens[2]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

      describe "when the pattern spans multiple lines", ->
        it "uses the ruleStack returned by the first line to parse the second line", ->
          {tokens: firstTokens, ruleStack} = grammar.tokenizeLine("'''single-quoted")
          {tokens: secondTokens, ruleStack} = grammar.tokenizeLine("heredoc'''", ruleStack)

          expect(firstTokens.length).toBe 2
          expect(secondTokens.length).toBe 2

          expect(firstTokens[0]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
          expect(firstTokens[1]).toEqual value: "single-quoted", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']

          expect(secondTokens[0]).toEqual value: "heredoc", scopes: ['source.coffee', 'string.quoted.heredoc.coffee']
          expect(secondTokens[1]).toEqual value: "'''", scopes: ['source.coffee', 'string.quoted.heredoc.coffee', 'punctuation.definition.string.end.coffee']

      describe "when the pattern contains sub-patterns", ->
        it "returns tokens within the begin/end scope based on the sub-patterns", ->
          {tokens} = grammar.tokenizeLine('"""heredoc with character escape \\t"""')

          expect(tokens.length).toBe 4

          expect(tokens[0]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.begin.coffee']
          expect(tokens[1]).toEqual value: "heredoc with character escape ", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee']
          expect(tokens[2]).toEqual value: "\\t", scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'constant.character.escape.coffee']
          expect(tokens[3]).toEqual value: '"""', scopes: ['source.coffee', 'string.quoted.double.heredoc.coffee', 'punctuation.definition.string.end.coffee']

      describe "when the end pattern contains a back reference", ->
        it "constructs the end rule based on its back-references to captures in the begin rule", ->
          grammar = syntax.selectGrammar('foo.rb')
          {tokens} = grammar.tokenizeLine('%w|oh|,')
          expect(tokens.length).toBe 4
          expect(tokens[0]).toEqual value: '%w|',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby", "punctuation.definition.string.begin.ruby"]
          expect(tokens[1]).toEqual value: 'oh',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby"]
          expect(tokens[2]).toEqual value: '|',  scopes: ["source.ruby", "string.quoted.other.literal.lower.ruby", "punctuation.definition.string.end.ruby"]
          expect(tokens[3]).toEqual value: ',',  scopes: ["source.ruby", "punctuation.separator.object.ruby"]

        it "allows the rule containing that end pattern to be pushed to the stack multiple times", ->
          grammar = syntax.selectGrammar('foo.rb')
          {tokens} = grammar.tokenizeLine('%Q+matz had some #{%Q-crazy ideas-} for ruby syntax+ # damn.')
          expect(tokens[0]).toEqual value: '%Q+', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","punctuation.definition.string.begin.ruby"]
          expect(tokens[1]).toEqual value: 'matz had some ', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby"]
          expect(tokens[2]).toEqual value: '#{', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","source.ruby.embedded.source","punctuation.section.embedded.ruby"]
          expect(tokens[3]).toEqual value: '%Q-', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","source.ruby.embedded.source","string.quoted.other.literal.upper.ruby","punctuation.definition.string.begin.ruby"]
          expect(tokens[4]).toEqual value: 'crazy ideas', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","source.ruby.embedded.source","string.quoted.other.literal.upper.ruby"]
          expect(tokens[5]).toEqual value: '-', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","source.ruby.embedded.source","string.quoted.other.literal.upper.ruby","punctuation.definition.string.end.ruby"]
          expect(tokens[6]).toEqual value: '}', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","source.ruby.embedded.source","punctuation.section.embedded.ruby"]
          expect(tokens[7]).toEqual value: ' for ruby syntax', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby"]
          expect(tokens[8]).toEqual value: '+', scopes: ["source.ruby","string.quoted.other.literal.upper.ruby","punctuation.definition.string.end.ruby"]
          expect(tokens[9]).toEqual value: ' ', scopes: ["source.ruby"]
          expect(tokens[10]).toEqual value: '#', scopes: ["source.ruby","comment.line.number-sign.ruby","punctuation.definition.comment.ruby"]
          expect(tokens[11]).toEqual value: ' damn.', scopes: ["source.ruby","comment.line.number-sign.ruby"]

      describe "when the pattern includes rules from another grammar", ->
        describe "when a grammar matching the desired scope is available", ->
          it "parses tokens inside the begin/end patterns based on the included grammar's rules", ->
            atom.activatePackage('html.tmbundle', sync: true)
            atom.activatePackage('ruby-on-rails-tmbundle', sync: true)

            grammar = syntax.selectGrammar('foo.html.erb')
            {tokens} = grammar.tokenizeLine("<div class='name'><%= User.find(2).full_name %></div>")

            expect(tokens[0]).toEqual value: '<', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.begin.html"]
            expect(tokens[1]).toEqual value: 'div', scopes: ["text.html.ruby","meta.tag.block.any.html","entity.name.tag.block.any.html"]
            expect(tokens[2]).toEqual value: ' ', scopes: ["text.html.ruby","meta.tag.block.any.html"]
            expect(tokens[3]).toEqual value: 'class', scopes: ["text.html.ruby","meta.tag.block.any.html", "entity.other.attribute-name.html"]
            expect(tokens[4]).toEqual value: '=', scopes: ["text.html.ruby","meta.tag.block.any.html"]
            expect(tokens[5]).toEqual value: '\'', scopes: ["text.html.ruby","meta.tag.block.any.html","string.quoted.single.html","punctuation.definition.string.begin.html"]
            expect(tokens[6]).toEqual value: 'name', scopes: ["text.html.ruby","meta.tag.block.any.html","string.quoted.single.html"]
            expect(tokens[7]).toEqual value: '\'', scopes: ["text.html.ruby","meta.tag.block.any.html","string.quoted.single.html","punctuation.definition.string.end.html"]
            expect(tokens[8]).toEqual value: '>', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.end.html"]
            expect(tokens[9]).toEqual value: '<%=', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.section.embedded.ruby"]
            expect(tokens[10]).toEqual value: ' ', scopes: ["text.html.ruby","source.ruby.rails.embedded.html"]
            expect(tokens[11]).toEqual value: 'User', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","support.class.ruby"]
            expect(tokens[12]).toEqual value: '.', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.separator.method.ruby"]
            expect(tokens[13]).toEqual value: 'find', scopes: ["text.html.ruby","source.ruby.rails.embedded.html"]
            expect(tokens[14]).toEqual value: '(', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.section.function.ruby"]
            expect(tokens[15]).toEqual value: '2', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","constant.numeric.ruby"]
            expect(tokens[16]).toEqual value: ')', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.section.function.ruby"]
            expect(tokens[17]).toEqual value: '.', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.separator.method.ruby"]
            expect(tokens[18]).toEqual value: 'full_name ', scopes: ["text.html.ruby","source.ruby.rails.embedded.html"]
            expect(tokens[19]).toEqual value: '%>', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.section.embedded.ruby"]
            expect(tokens[20]).toEqual value: '</', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.begin.html"]
            expect(tokens[21]).toEqual value: 'div', scopes: ["text.html.ruby","meta.tag.block.any.html","entity.name.tag.block.any.html"]
            expect(tokens[22]).toEqual value: '>', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.end.html"]

        describe "when a grammar matching the desired scope is unavailable", ->
          it "updates the grammar if a matching grammar is added later", ->
            atom.deactivatePackage('html.tmbundle')
            atom.activatePackage('ruby-on-rails-tmbundle', sync: true)

            grammar = syntax.selectGrammar('foo.html.erb')
            {tokens} = grammar.tokenizeLine("<div class='name'><%= User.find(2).full_name %></div>")
            expect(tokens[0]).toEqual value: "<div class='name'>", scopes: ["text.html.ruby"]
            expect(tokens[1]).toEqual value: '<%=', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.section.embedded.ruby"]
            expect(tokens[2]).toEqual value: ' ', scopes: ["text.html.ruby","source.ruby.rails.embedded.html"]
            expect(tokens[3]).toEqual value: 'User', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","support.class.ruby"]

            atom.activatePackage('html.tmbundle', sync: true)
            {tokens} = grammar.tokenizeLine("<div class='name'><%= User.find(2).full_name %></div>")
            expect(tokens[0]).toEqual value: '<', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.begin.html"]
            expect(tokens[1]).toEqual value: 'div', scopes: ["text.html.ruby","meta.tag.block.any.html","entity.name.tag.block.any.html"]
            expect(tokens[2]).toEqual value: ' ', scopes: ["text.html.ruby","meta.tag.block.any.html"]
            expect(tokens[3]).toEqual value: 'class', scopes: ["text.html.ruby","meta.tag.block.any.html", "entity.other.attribute-name.html"]
            expect(tokens[4]).toEqual value: '=', scopes: ["text.html.ruby","meta.tag.block.any.html"]
            expect(tokens[5]).toEqual value: '\'', scopes: ["text.html.ruby","meta.tag.block.any.html","string.quoted.single.html","punctuation.definition.string.begin.html"]
            expect(tokens[6]).toEqual value: 'name', scopes: ["text.html.ruby","meta.tag.block.any.html","string.quoted.single.html"]
            expect(tokens[7]).toEqual value: '\'', scopes: ["text.html.ruby","meta.tag.block.any.html","string.quoted.single.html","punctuation.definition.string.end.html"]
            expect(tokens[8]).toEqual value: '>', scopes: ["text.html.ruby","meta.tag.block.any.html","punctuation.definition.tag.end.html"]
            expect(tokens[9]).toEqual value: '<%=', scopes: ["text.html.ruby","source.ruby.rails.embedded.html","punctuation.section.embedded.ruby"]
            expect(tokens[10]).toEqual value: ' ', scopes: ["text.html.ruby","source.ruby.rails.embedded.html"]

    it "can parse a grammar with newline characters in its regular expressions (regression)", ->
      grammar = new TextMateGrammar
        name: "test"
        scopeName: "source.imaginaryLanguage"
        repository: {}
        patterns: [
          {
            name: "comment-body";
            begin: "//";
            end: "\\n";
            beginCaptures:
              "0": { name: "comment-start" }
          }
        ]

      {tokens, ruleStack} = grammar.tokenizeLine("// a singleLineComment")
      expect(ruleStack.length).toBe 1
      expect(ruleStack[0].scopeName).toBe "source.imaginaryLanguage"

      expect(tokens.length).toBe 2
      expect(tokens[0].value).toBe "//"
      expect(tokens[1].value).toBe " a singleLineComment"

    it "does not loop infinitely (regression)", ->
      grammar = syntax.selectGrammar("hello.js")
      {tokens, ruleStack} = grammar.tokenizeLine("// line comment")
      {tokens, ruleStack} = grammar.tokenizeLine(" // second line comment with a single leading space", ruleStack)

    describe "when inside a C block", ->
      beforeEach ->
        atom.activatePackage('c.tmbundle', sync: true)

      it "correctly parses a method. (regression)", ->
        grammar = syntax.selectGrammar("hello.c")
        {tokens, ruleStack} = grammar.tokenizeLine("if(1){m()}")
        expect(tokens[5]).toEqual value: "m", scopes: ["source.c", "meta.block.c", "meta.function-call.c", "support.function.any-method.c"]

      it "correctly parses nested blocks. (regression)", ->
        grammar = syntax.selectGrammar("hello.c")
        {tokens, ruleStack} = grammar.tokenizeLine("if(1){if(1){m()}}")
        expect(tokens[5]).toEqual value: "if", scopes: ["source.c", "meta.block.c", "keyword.control.c"]
        expect(tokens[10]).toEqual value: "m", scopes: ["source.c", "meta.block.c", "meta.block.c", "meta.function-call.c", "support.function.any-method.c"]

    describe "when the grammar can infinitely loop over a line", ->
      it "aborts tokenization", ->
        spyOn(console, 'error')
        atom.activatePackage("package-with-infinite-loop-grammar")
        grammar = syntax.selectGrammar("something.package-with-infinite-loop-grammar")
        {tokens} = grammar.tokenizeLine("abc")
        expect(tokens[0].value).toBe "a"
        expect(tokens[1].value).toBe "bc"
        expect(console.error).toHaveBeenCalled()

    describe "when a grammar has a pattern that has back references in the match value", ->
      it "does not special handle the back references and instead allows oniguruma to resolve them", ->
        atom.activatePackage('sass.tmbundle', sync: true)
        grammar = syntax.selectGrammar("style.scss")
        {tokens} = grammar.tokenizeLine("@mixin x() { -moz-selector: whatever; }")
        expect(tokens[9]).toEqual value: "-moz-selector", scopes: ["source.css.scss", "meta.property-list.scss", "meta.property-name.scss"]

    describe "when a line has more tokens than `maxTokensPerLine`", ->
      it "creates a final token with the remaining text and resets the ruleStack to match the begining of the line", ->
        grammar = syntax.selectGrammar("hello.js")
        spyOn(grammar, 'getMaxTokensPerLine').andCallFake -> 5
        originalRuleStack = [grammar.initialRule, grammar.initialRule, grammar.initialRule]
        {tokens, ruleStack} = grammar.tokenizeLine("one(two(three(four(five(_param_)))))", originalRuleStack)
        expect(tokens.length).toBe 5
        expect(tokens[4].value).toBe "three(four(five(_param_)))))"
        expect(ruleStack).toEqual originalRuleStack

    describe "when a grammar has a capture with patterns", ->
      it "matches the patterns and includes the scope specified as the pattern's match name", ->
        grammar = syntax.selectGrammar("hello.php")
        {tokens} = grammar.tokenizeLine("<?php public final function meth() {} ?>")

        expect(tokens[2].value).toBe "public"
        expect(tokens[2].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php", "storage.modifier.php"]

        expect(tokens[3].value).toBe " "
        expect(tokens[3].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php"]

        expect(tokens[4].value).toBe "final"
        expect(tokens[4].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php", "storage.modifier.php"]

        expect(tokens[5].value).toBe " "
        expect(tokens[5].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php"]

        expect(tokens[6].value).toBe "function"
        expect(tokens[6].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php", "storage.type.function.php"]

      it "ignores child captures of a capture with patterns", ->
        grammar = new TextMateGrammar
          name: "test"
          scopeName: "source"
          repository: {}
          patterns: [
            {
              name: "text"
              match: "(a(b))"
              captures:
                "1":
                  patterns: [
                    {
                      match: "ab"
                      name: "a"
                    }
                  ]
                "2":
                  name: "b"
            }
          ]
        {tokens} = grammar.tokenizeLine("ab")

        expect(tokens[0].value).toBe "ab"
        expect(tokens[0].scopes).toEqual ["source", "text", "a"]

    describe "when the grammar has injections", ->
      it "correctly includes the injected patterns when tokenizing", ->
        grammar = syntax.selectGrammar("hello.php")
        {tokens} = grammar.tokenizeLine("<div><?php function hello() {} ?></div>")

        expect(tokens[3].value).toBe "<?php"
        expect(tokens[3].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "punctuation.section.embedded.begin.php"]

        expect(tokens[5].value).toBe "function"
        expect(tokens[5].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php", "storage.type.function.php"]

        expect(tokens[7].value).toBe "hello"
        expect(tokens[7].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "meta.function.php", "entity.name.function.php"]

        expect(tokens[14].value).toBe "?"
        expect(tokens[14].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "source.php", "punctuation.section.embedded.end.php", "source.php"]

        expect(tokens[15].value).toBe ">"
        expect(tokens[15].scopes).toEqual ["text.html.php", "meta.embedded.line.php", "punctuation.section.embedded.end.php"]

        expect(tokens[16].value).toBe "</"
        expect(tokens[16].scopes).toEqual ["text.html.php", "meta.tag.block.any.html", "punctuation.definition.tag.begin.html"]

        expect(tokens[17].value).toBe "div"
        expect(tokens[17].scopes).toEqual ["text.html.php", "meta.tag.block.any.html", "entity.name.tag.block.any.html"]
