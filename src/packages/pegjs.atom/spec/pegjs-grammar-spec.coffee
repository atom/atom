AtomPackage = require 'atom-package'
TextMatePackage = require 'text-mate-package'

fs = require 'fs'

fdescribe "PEGjs grammar", ->
  grammar = null
  tmGrammar = null

  beforeEach ->
    pack = new AtomPackage(require.resolve("pegjs.atom"))
    pack.load()
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

    it "parses the same as the textmate grammar", ->
      {tokens} = grammar.tokenizeLine(" ", 0)
      tmTokens = tmGrammar.tokenizeLine(" ").tokens

      expect(tokens).toEqual tmTokens

      {tokens} = grammar.tokenizeLine("//this is a comment", 0)
      {tokens: tmTokens} = tmGrammar.tokenizeLine("//this is a comment")

      expect(tokens.value).toEqual tmTokens.value
      expect(tokens.scopes).toEqual tmTokens.scopes
