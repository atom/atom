AtomPackage = require 'atom-package'
TextMatePackage = require 'text-mate-package'
Buffer = require 'text-buffer'

fs = require 'fs-utils'

fdescribe "PEGjs grammar", ->
  grammar = null
  tmGrammar = null

  beforeEach ->
    pack = new AtomPackage(fs.resolveOnLoadPath("pegjs.atom"))
    pack.load()
    pack.loadGrammars()
    grammar = pack.grammars[0]

    tmPack = new TextMatePackage(fs.resolveOnLoadPath("pegjs.atom"))
    tmPack.load()
    tmGrammar = tmPack.grammars[0]

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.pegjs"

  describe "tokenizeLine", ->

    it "parses comments", ->
      {tokens} = grammar.tokenizeLine("_=''//this is a comment", 0)

      expect(tokens[4]).toEqual value: "//", scopes: ["source.pegjs", "comment.line.double-slash.js", "punctuation.definition.comment.js"]
      expect(tokens[5]).toEqual value: "this is a comment", scopes: ["source.pegjs", "comment.line.double-slash.js"]

      {tokens:tmTokens} = tmGrammar.tokenizeLine("_=''//this is a comment")

      expect(tokens[4]).toEqual tmTokens[4]
      expect(tokens[5]).toEqual tmTokens[5]

      {tokens} = grammar.tokenizeLine("/*comment*/_=''")

      expect(tokens[0]).toEqual value: "/*", scopes: ['source.pegjs', 'comment.block', 'punctuation.definition.comment.pegjs']
      expect(tokens[1]).toEqual value: "comment", scopes: ['source.pegjs', 'comment.block']
      expect(tokens[2]).toEqual value: "*/", scopes: ['source.pegjs', 'comment.block', 'punctuation.definition.comment.pegjs']

      {tokens:tmTokens} = tmGrammar.tokenizeLine("/*comment*/")

      expect(tokens[0]).toEqual tmTokens[0]
      expect(tokens[1]).toEqual tmTokens[1]
      expect(tokens[2]).toEqual tmTokens[2]

    it "parses strings", ->
      {tokens} = grammar.tokenizeLine("_='single quoted string'", 0)

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

    it "parses rules", ->
      {tokens} = grammar.tokenizeLine("a='a'", 0)

      expect(tokens[0]).toEqual value: "a", scopes: ["source.pegjs", "source.pegjs.ruleDefinition", "entity.name.type"]
      expect(tokens[1]).toEqual value: "=", scopes: ["source.pegjs", "source.pegjs.ruleDefinition"]

      {tokens: tmTokens} = tmGrammar.tokenizeLine("a='a'")

      expect(tokens).toEqual tmTokens

    it "parses labels", ->
      {tokens} = grammar.tokenizeLine("a=label:'a'", 0)

      expect(tokens[2]).toEqual value: "label", scopes: ["source.pegjs", "variable.parameter"]
      expect(tokens[3]).toEqual value: ":", scopes: ["source.pegjs", "keyword.operator"]

  describe "batchTokenizeLine", ->
    buffer = null

    beforeEach ->
      buffer = new Buffer("")

    it "parses a simple file", ->
      buffer.append("a = b\n")
      buffer.append("b = c\n")
      buffer.append("c = '.'\n")

      {tokens} = grammar.batchTokenizeLine(buffer, 0)

      expect(tokens[0]).toEqual value: "a ", scopes: ["source.pegjs", "source.pegjs.ruleDefinition", "entity.name.type"]
      expect(tokens[1]).toEqual value: "=", scopes: ["source.pegjs", "source.pegjs.ruleDefinition"]
      expect(tokens[2]).toEqual value: " b\n", scopes: ["source.pegjs"]

      {tokens} = grammar.batchTokenizeLine(buffer, 1)

      expect(tokens[0]).toEqual value: "b ", scopes: ["source.pegjs", "source.pegjs.ruleDefinition", "entity.name.type"]
      expect(tokens[1]).toEqual value: "=", scopes: ["source.pegjs", "source.pegjs.ruleDefinition"]
      expect(tokens[2]).toEqual value: " c\n", scopes: ["source.pegjs"]

      {tokens} = grammar.batchTokenizeLine(buffer, 2)

      expect(tokens[0]).toEqual value: "c ", scopes: ["source.pegjs", "source.pegjs.ruleDefinition", "entity.name.type"]
      expect(tokens[1]).toEqual value: "=", scopes: ["source.pegjs", "source.pegjs.ruleDefinition"]
      expect(tokens[2]).toEqual value: " ", scopes: ["source.pegjs"]
      expect(tokens[3]).toEqual value: "'", scopes: ["source.pegjs", "string.quoted.single.js", "punctuation.definition.string.begin.pegjs"]
      expect(tokens[4]).toEqual value: ".", scopes: ["source.pegjs", "string.quoted.single.js"]
      expect(tokens[5]).toEqual value: "'", scopes: ["source.pegjs", "string.quoted.single.js", "punctuation.definition.string.end.pegjs"]
      expect(tokens[6]).toEqual value: "\n", scopes: ["source.pegjs"]

    it "parses it's own pegjs file", ->
      buffer.append(fs.read(fs.resolveOnLoadPath("pegjs.atom/grammars/pegjs.pegjs")))

      {tokens} = grammar.batchTokenizeLine(buffer, 0)

      expect(tokens[0]).toEqual value: "grammar\n", scopes: ["source.pegjs", "source.pegjs.ruleDefinition", "entity.name.type"]
