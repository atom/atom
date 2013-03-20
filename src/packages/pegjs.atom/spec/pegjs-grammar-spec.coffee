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
