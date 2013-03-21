AtomPackage = require 'atom-package'
TextMatePackage = require 'text-mate-package'

fs = require 'fs'

describe "PEGjs grammar", ->
  grammar = null
  tmGrammar = null

  beforeEach ->
    pack = new AtomPackage(require.resolve("pegjs.atom"))
    pack.load()
    pack.loadGrammars()
    grammar = pack.grammars[0]

    tmPack = new TextMatePackage(require.resolve("pegjs.atom"))
    tmPack.load()
    tmGrammar = tmPack.grammars[0]

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.pegjs"

  describe "tokenize strings", ->

    it "parses whitespace", ->
      {tokens} = grammar.tokenizeLine(" ", 0)

      expect(tokens).toBeTruthy()
      expect(tokens[0]).toEqual value: " ", scopes: ["source.pegjs"]

      {tokens} = grammar.tokenizeLine("\n", 0)

      expect(tokens[0]).toEqual value: "\n", scopes: ["source.pegjs"]

    it "parses comments", ->
      {tokens} = grammar.tokenizeLine("//this is a comment", 0)

      expect(tokens[0]).toEqual value: "//", scopes: ["source.pegjs", "comment.line.double-slash.js", "punctuation.definition.comment.js"]
      expect(tokens[1]).toEqual value: "this is a comment", scopes: ["source.pegjs", "punctuation.definition.comment.js"]

    it "parses strings", ->
      {tokens} = grammar.tokenizeLine("'single quoted string'", 0)

      expect(tokens[0]).toEqual value: "'", scopes: ["source.pegjs", "string.quoted.single.js", "punctuation.definition.string.begin.pegjs"]
      expect(tokens[1]).toEqual value: "single quoted string", scopes: ["source.pegjs", "string.quoted.single.js"]
      expect(tokens[2]).toEqual value: "'", scopes: ["source.pegjs", "string.quoted.single.js", "punctuation.definition.string.end.pegjs"]

      {tokens} = grammar.tokenizeLine('"double quoted string"', 0)

      expect(tokens[0]).toEqual value: '"', scopes: ["source.pegjs", "string.quoted.double.js", "punctuation.definition.string.begin.pegjs"]
      expect(tokens[1]).toEqual value: "double quoted string", scopes: ["source.pegjs", "string.quoted.double.js"]
      expect(tokens[2]).toEqual value: '"', scopes: ["source.pegjs", "string.quoted.double.js", "punctuation.definition.string.end.pegjs"]

    it "parses actions", ->
      {tokens} = grammar.tokenizeLine("{ var embedded = 'JavaScript'; }", 0)

      expect(tokens[0]).toEqual value: "{", scopes: ["source.pegjs", "source.js.embedded.pegjs"]
      expect(tokens[1]).toEqual value: " var embedded = 'JavaScript'; ", scopes: ["source.pegjs"]
      expect(tokens[2]).toEqual value: "}", scopes: ["source.pegjs", "source.js.embedded.pegjs"]

      {tokens: tmTokens} = tmGrammar.tokenizeLine("{ var embedded = 'JavaScript'; }")

      expect(tokens[0]).toEqual tmTokens[0]
      # Can't do embedded grammars :(
      expect(tokens[2]).toEqual tmTokens[11]

    it "parses the same as the textmate grammar", ->
      {tokens} = grammar.tokenizeLine(" ", 0)
      tmTokens = tmGrammar.tokenizeLine(" ").tokens

      expect(tokens).toEqual tmTokens

      {tokens} = grammar.tokenizeLine("//this is a comment", 0)
      {tokens: tmTokens} = tmGrammar.tokenizeLine("//this is a comment")

      expect(tokens.value).toEqual tmTokens.value
      expect(tokens.scopes).toEqual tmTokens.scopes

      {tokens} = grammar.tokenizeLine("'single quoted string'", 0)
      {tokens: tmTokens} = tmGrammar.tokenizeLine("'single quoted string'")

      expect(tokens.value).toEqual tmTokens.value
      expect(tokens.scopes).toEqual tmTokens.scopes

      {tokens} = grammar.tokenizeLine('"double quoted string"', 0)
      {tokens: tmTokens} = tmGrammar.tokenizeLine('"double quoted string"')

      expect(tokens.value).toEqual tmTokens.value
      expect(tokens.scopes).toEqual tmTokens.scopes
