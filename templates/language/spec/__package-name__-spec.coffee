# If you want an example of language specs, check out:
#   - https://raw.githubusercontent.com/atom/language-coffee-script/master/spec/coffee-script-spec.coffee

describe "Language grammar", ->
  grammar = null

  beforeEach ->
    waitsForPromise ->
      atom.packages.activatePackage("__package-name__")

    runs ->
      grammar = atom.syntax.grammarForScopeName("source.language")

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.language"
