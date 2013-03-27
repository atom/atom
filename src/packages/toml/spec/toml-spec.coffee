TextMatePackage = require 'text-mate-package'

describe "TOML grammar", ->
  grammar = null

  beforeEach ->
    spyOn(syntax, "addGrammar")
    atom.activatePackage("toml")
    expect(syntax.addGrammar).toHaveBeenCalled()
    grammar = syntax.addGrammar.argsForCall[0][0]

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.toml"

  it "tokenizes comments", ->
    {tokens} = grammar.tokenizeLine("# I am a comment")
    expect(tokens[0]).toEqual value: "# I am a comment", scopes: ["source.toml", "comment.toml"]

  it "tokenizes strings", ->
    {tokens} = grammar.tokenizeLine('"I am a string"')
    expect(tokens[0]).toEqual value: '"', scopes: ["source.toml", "string.toml", "string.begin.toml"]
    expect(tokens[1]).toEqual value: 'I am a string', scopes: ["source.toml", "string.toml"]
    expect(tokens[2]).toEqual value: '"', scopes: ["source.toml", "string.toml","string.end.toml"]

    {tokens} = grammar.tokenizeLine('"I\'m \\n escaped"')
    expect(tokens[0]).toEqual value: '"', scopes: ["source.toml", "string.toml", "string.begin.toml"]
    expect(tokens[1]).toEqual value: "I'm ", scopes: ["source.toml", "string.toml"]
    expect(tokens[2]).toEqual value: "\\n", scopes: ["source.toml", "string.toml", "constant.character.escape.toml"]
    expect(tokens[3]).toEqual value: " escaped", scopes: ["source.toml", "string.toml"]
    expect(tokens[4]).toEqual value: '"', scopes: ["source.toml", "string.toml", "string.end.toml"]

  it "tokenizes booleans", ->
    {tokens} = grammar.tokenizeLine("true")
    expect(tokens[0]).toEqual value: "true", scopes: ["source.toml", "constant.language.boolean.true.toml"]
    {tokens} = grammar.tokenizeLine("false")
    expect(tokens[0]).toEqual value: "false", scopes: ["source.toml", "constant.language.boolean.false.toml"]

  it "tokenizes numbers", ->
    {tokens} = grammar.tokenizeLine("123")
    expect(tokens[0]).toEqual value: "123", scopes: ["source.toml", "constant.numeric.toml"]

    {tokens} = grammar.tokenizeLine("-1")
    expect(tokens[0]).toEqual value: "-1", scopes: ["source.toml", "constant.numeric.toml"]

    {tokens} = grammar.tokenizeLine("3.14")
    expect(tokens[0]).toEqual value: "3.14", scopes: ["source.toml", "constant.numeric.toml"]

    {tokens} = grammar.tokenizeLine("-123.456")
    expect(tokens[0]).toEqual value: "-123.456", scopes: ["source.toml", "constant.numeric.toml"]

  it "tokenizes dates", ->
    {tokens} = grammar.tokenizeLine("1979-05-27T07:32:00Z")
    expect(tokens[0]).toEqual value: "1979-05-27T07:32:00Z", scopes: ["source.toml", "support.date.toml"]

  it "tokenizes keygroups", ->
    {tokens} = grammar.tokenizeLine("[keygroup]")
    expect(tokens[0]).toEqual value: "[", scopes: ["source.toml", "keygroup.toml"]
    expect(tokens[1]).toEqual value: "keygroup", scopes: ["source.toml", "keygroup.toml", "variable.keygroup.toml"]
    expect(tokens[2]).toEqual value: "]", scopes: ["source.toml", "keygroup.toml"]

  it "tokenizes keys", ->
    {tokens} = grammar.tokenizeLine("key =")
    expect(tokens[0]).toEqual value: "key", scopes: ["source.toml", "key.toml", "entity.key.toml"]
    expect(tokens[1]).toEqual value: " =", scopes: ["source.toml", "key.toml"]
