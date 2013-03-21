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
      {tokens} = grammar.tokenizeLine("_=''//this is a comment", 0)

      console.log(tokens)
      expect(tokens[4]).toEqual value: "//", scopes: ["source.pegjs", "comment.line.double-slash.js", "punctuation.definition.comment.js"]
      expect(tokens[5]).toEqual value: "this is a comment", scopes: ["source.pegjs", "punctuation.definition.comment.js"]

      {tokens:tmTokens} = tmGrammar.tokenizeLine("_=''//this is a comment")

      expect(tokens[4]).toEqual tmTokens[4]
      # the tmbundle builds a comment.line.double-slash.js instead of the
      # equivalent punctuation.definition.comment
      expect(tokens[5].value).toEqual tmTokens[5].value

    it "parses strings", ->
      {tokens} = grammar.tokenizeLine("_='single quoted string'", 0)

      console.log(tokens)
      expect(tokens[2]).toEqual value: "'", scopes: ["source.pegjs", "string.quoted.single.js", "punctuation.definition.string.begin.pegjs"]
      expect(tokens[3]).toEqual value: "single quoted string", scopes: ["source.pegjs", "string.quoted.single.js"]
      expect(tokens[4]).toEqual value: "'", scopes: ["source.pegjs", "string.quoted.single.js", "punctuation.definition.string.end.pegjs"]

      {tokens:tmTokens} = tmGrammar.tokenizeLine("_='single quoted string'")

      expect(tokens[2]).toEqual tmTokens[2]
      expect(tokens[3]).toEqual tmTokens[3]
      expect(tokens[4]).toEqual tmTokens[4]

      {tokens} = grammar.tokenizeLine('_="double quoted string"', 0)

      expect(tokens[2]).toEqual value: '"', scopes: ["source.pegjs", "string.quoted.double.pegjs", "punctuation.definition.string.begin.pegjs"]
      expect(tokens[3]).toEqual value: "double quoted string", scopes: ["source.pegjs", "string.quoted.double.pegjs"]
      expect(tokens[4]).toEqual value: '"', scopes: ["source.pegjs", "string.quoted.double.pegjs", "punctuation.definition.string.end.pegjs"]

      {tokens:tmTokens} = tmGrammar.tokenizeLine('_="double quoted string"')

      expect(tokens[2]).toEqual tmTokens[2]
      expect(tokens[3]).toEqual tmTokens[3]
      expect(tokens[4]).toEqual tmTokens[4]

    it "parses actions", ->
      {tokens} = grammar.tokenizeLine("{ var embedded = 'JavaScript'; };_=''", 0)

      expect(tokens[0]).toEqual value: "{", scopes: ["source.pegjs", "source.js.embedded.pegjs"]
      expect(tokens[1]).toEqual value: " var embedded = 'JavaScript'; ", scopes: ["source.pegjs"]
      expect(tokens[2]).toEqual value: "}", scopes: ["source.pegjs", "source.js.embedded.pegjs"]

      {tokens: tmTokens} = tmGrammar.tokenizeLine("{ var embedded = 'JavaScript'; }")

      expect(tokens[0]).toEqual tmTokens[0]
      # Can't do embedded grammars :(
      expect(tokens[2]).toEqual tmTokens[11]

    it "parses operators", ->
      {tokens} = grammar.tokenizeLine("_='a'/'b'", 0)

      expect(tokens[5]).toEqual value: "/", scopes: ["source.pegjs", "keyword.operator"]

      {tokens: tmTokens} = tmGrammar.tokenizeLine("_='a'/'b")

      expect(tokens[5]).toEqual tmTokens[5]
