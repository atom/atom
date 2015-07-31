{Emitter} = require 'event-kit'
TokenIterator = require '../src/token-iterator'
EmptyLineHTML = "<div></div>"

module.exports=
class StyleSamplerComponent
  constructor: (@editor) ->
    @tokenIterator = new TokenIterator
    @emitter = new Emitter
    # Assign a bunch of properties to make this node a relayout boundary.
    @layoutBoundary = document.createElement("div")
    @layoutBoundary.style.visibility = "hidden"
    @layoutBoundary.style.width = "100px"
    @layoutBoundary.style.height = "100px"
    @layoutBoundary.style.overflow = "hidden"
    @layoutBoundary.style.position = "absolute"

    @scopesToSample = []
    @sampledScopes = {}
    @sampledLines = {}

  invalidateStyles: ->
    @sampledScopes = {}
    @sampledLines = {}
    @emitter.emit "did-invalidate-styles"

  getDomNode: ->
    @layoutBoundary

  sampleScreenRows: (screenRows) ->
    @scopesToSample = []

    html = ""
    newLines = []
    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return if not line?
      return if @sampledLines[line.id]

      lineHTML = @buildLineHTML(line)
      if lineHTML isnt EmptyLineHTML
        html += lineHTML
        newLines.push(line)

      @sampledLines[line.id] = true

    @layoutBoundary.innerHTML = html if html isnt ""

    for line, lineIndex in newLines
      lineNode = @layoutBoundary.children[lineIndex]
      for tokenNode in lineNode.children
        tokenLeafNode = @getLeafNode(tokenNode)
        samplingEvent =
          scopes: @scopesToSample.shift()
          font: getComputedStyle(tokenLeafNode).font
        @emitter.emit "did-sample-scopes-style", samplingEvent

  onDidSampleScopesStyle: (callback) ->
    @emitter.on "did-sample-scopes-style", callback

  onDidInvalidateStyles: (callback) ->
    @emitter.on "did-invalidate-styles", callback

  buildLineHTML: (line) ->
    html = "<div>"

    @tokenIterator.reset(line)
    while @tokenIterator.next()
      tokenScopes = @tokenIterator.getScopes()
      continue if @sampledScopes[tokenScopes]

      for scope in tokenScopes
        html += "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

      for scope in tokenScopes
        html += "</span>"

      @scopesToSample.push(tokenScopes.slice())
      @sampledScopes[tokenScopes] = true

    html += "</div>"
    html

  getLeafNode: (node) ->
    if node.firstChild?
      @getLeafNode(node.firstChild)
    else
      node
