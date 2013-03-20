AtomPackage = require 'atom-package'

fs = require 'fs'

describe "PEGjs grammar", ->
  grammar = null

  beforeEach ->
    pack = new AtomPackage(require.resolve("pegjs.atom"))
    pack.load()
    grammar = pack.grammars[0]

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.pegjs"

  fdescribe "tokenize strings", ->

    it "parses whitespace", ->
      {tokens} = grammar.tokenizeLine(" ", 0)

      expect(tokens).toBeTruthy()
      expect(tokens[0]).toEqual value: " ", scopes: ["source.pegjs"]

      {tokens} = grammar.tokenizeLine("\n", 0)

      expect(tokens[0]).toEqual value: "\n", scopes: ["source.pegjs"]

    it "parses comments", ->
      {tokens} = grammar.tokenizeLine("//this is a comment", 0)

      expect(tokens[0]).toEqual value: "//this is a comment", scopes: ["source.pegjs"]

      expect(tokens[0]).toEqual value: "\n", scopes: ["source.pegjs"]