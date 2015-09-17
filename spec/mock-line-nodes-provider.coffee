TokenIterator = require '../src/token-iterator'

module.exports =
class MockLineNodesProvider
  constructor: (@editor) ->
    @defaultFont = ""
    @fontsByScopes = {}
    @tokenIterator = new TokenIterator
    @builtLineNodes = []

  dispose: ->
    node.remove() for node in @builtLineNodes

  setFontForScopes: (scopes, font) -> @fontsByScopes[scopes] = font

  setDefaultFont: (font) -> @defaultFont = font

  lineNodeForLineIdAndScreenRow: (id, screenRow) ->
    lineNode = document.createElement("div")
    lineNode.style.whiteSpace = "pre"
    lineState = @editor.tokenizedLineForScreenRow(screenRow)

    @tokenIterator.reset(lineState)
    while @tokenIterator.next()
      font = @fontsByScopes[@tokenIterator.getScopes()] or @defaultFont
      span = document.createElement("span")
      span.style.font = font
      span.textContent = @tokenIterator.getText()
      lineNode.innerHTML += span.outerHTML

    @builtLineNodes.push(lineNode)
    document.body.appendChild(lineNode)

    lineNode
