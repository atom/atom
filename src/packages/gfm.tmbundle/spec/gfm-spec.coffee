TextMatePackage = require 'text-mate-package'

describe "GitHub Flavored Markdown grammar", ->
  grammar = null

  beforeEach ->
    spyOn(syntax, "addGrammar")
    pack = new TextMatePackage(require.resolve("gfm.tmbundle"))
    pack.load()
    grammar = pack.grammars[0]

  it "parses the grammar", ->
    expect(grammar).toBeTruthy()
    expect(grammar.scopeName).toBe "source.gfm"

  it "tokenizes **bold** text", ->
    {tokens} = grammar.tokenizeLine("this is **bold** text")
    expect(tokens[0]).toEqual value: "this is ", scopes: ["source.gfm"]
    expect(tokens[1]).toEqual value: "**bold**", scopes: ["source.gfm", "markup.bold.gfm"]
    expect(tokens[2]).toEqual value: " text", scopes: ["source.gfm"]

  it "tokenizes *italic* text", ->
    {tokens} = grammar.tokenizeLine("this is *italic* text")
    expect(tokens[0]).toEqual value: "this is ", scopes: ["source.gfm"]
    expect(tokens[1]).toEqual value: "*italic*", scopes: ["source.gfm", "markup.italic.gfm"]
    expect(tokens[2]).toEqual value: " text", scopes: ["source.gfm"]

  it "tokenizes a ## Heading", ->
    {tokens} = grammar.tokenizeLine("# Heading 1")
    expect(tokens[0]).toEqual value: "# Heading 1", scopes: ["source.gfm", "markup.heading.gfm"]
    {tokens} = grammar.tokenizeLine("### Heading 3")
    expect(tokens[0]).toEqual value: "### Heading 3", scopes: ["source.gfm", "markup.heading.gfm"]

  it "tokenizies an :emoji:", ->
    {tokens} = grammar.tokenizeLine("this is :no_good:")
    expect(tokens[0]).toEqual value: "this is ", scopes: ["source.gfm"]
    expect(tokens[1]).toEqual value: ":no_good:", scopes: ["source.gfm", "variable.emoji.gfm"]

  it "tokenizes a ``` code block```", ->
    {tokens, ruleStack} = grammar.tokenizeLine("```coffeescript")
    expect(tokens[0]).toEqual value: "```coffeescript", scopes: ["source.gfm"]
    {tokens, ruleStack} = grammar.tokenizeLine("-> 'hello'", ruleStack)
    expect(tokens[0]).toEqual value: "-> 'hello'", scopes: ["source.gfm", "markup.raw.gfm"]
    {tokens} = grammar.tokenizeLine("```", ruleStack)
    expect(tokens[0]).toEqual value: "```", scopes: ["source.gfm"]

  it "tokenizes inline `code` blocks", ->
    {tokens} = grammar.tokenizeLine("`this` is `code`")
    expect(tokens[0]).toEqual value: "`this`", scopes: ["source.gfm", "markup.raw.gfm"]
    expect(tokens[1]).toEqual value: " is ", scopes: ["source.gfm"]
    expect(tokens[2]).toEqual value: "`code`", scopes: ["source.gfm", "markup.raw.gfm"]

  it "tokenizes [links](links)", ->
    {tokens} = grammar.tokenizeLine("please click [this link](website)")
    expect(tokens[0]).toEqual value: "please click ", scopes: ["source.gfm"]
    expect(tokens[1]).toEqual value: "[", scopes: ["source.gfm"]
    expect(tokens[2]).toEqual value: "this link", scopes: ["source.gfm", "entity.gfm"]
    expect(tokens[3]).toEqual value: "](", scopes: ["source.gfm"]
    expect(tokens[4]).toEqual value: "website", scopes: ["source.gfm", "markup.underline.gfm"]
    expect(tokens[5]).toEqual value: ")", scopes: ["source.gfm"]
