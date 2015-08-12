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
    @fontsByScopes = {}

  onDidSampleScopes: (callback) ->
    @emitter.on "did-sample-scopes", callback

  fontForScopes: (scopes) ->
    @fontsByScopes[scopes]

  invalidateStyles: ->
    @sampledScopes = {}
    @sampledLines = {}
    @fontsByScopes = {}

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

    hasNewSamples = @scopesToSample.length > 0

    for line, lineIndex in newLines
      lineNode = @layoutBoundary.children[lineIndex]
      for tokenNode in lineNode.children
        tokenLeafNode = @getLeafNode(tokenNode)
        scopes = @scopesToSample.shift()
        @fontsByScopes[scopes] = getComputedStyle(tokenLeafNode).font

    @emitter.emit "did-sample-scopes" if hasNewSamples

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
