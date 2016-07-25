# If you want an example of language specs, check out:
# https://github.com/atom/language-gfm/blob/master/spec/gfm-spec.coffee

describe "PackageName grammar", ->
  grammar = null

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage("language-__package-name__")

    runs ->
      grammar = atom.syntax.grammarForScopeName("source.__package-name__")

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.__package-name__"
