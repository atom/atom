{Emitter} = require 'event-kit'
TokenIterator = require '../src/token-iterator'
EmptyLineHTML = "<div></div>"

module.exports=
class StyleSamplerComponent
  constructor: (@editor) ->
    @tokenIterator = new TokenIterator
    @initialized = false
    @emitter = new Emitter
    @defaultStyleNode = document.createElement("style")
    @styleNodes = []
    @iframe = document.createElement("iframe")
    @iframe.style.display = "none"
    @iframe.onload = @setupIframe

    @scopesToSample = []
    @sampledScopes = {}
    @sampledLines = {}

  invalidateStyles: ->
    @sampledScopes = {}
    @sampledLines = {}
    @emitter.emit "did-invalidate-styles"

  setDefaultFont: (fontFamily, fontSize) ->
    @defaultStyleNode.innerHTML = """
    body {
      font-size: #{fontSize};
      font-family: #{fontFamily};
    }
    """

    @invalidateStyles()

  addStyle: (styleNode) ->
    fontStyleNode = @extractFontStyleNode(styleNode)
    @styleNodes.push(fontStyleNode)
    @headNode.appendChild(fontStyleNode)

    @invalidateStyles()

  addStyles: (styleNodes) ->
    @addStyle(styleNode) for styleNode in styleNodes
    return

  clearStyles: ->
    for styleNode in @styleNodes
      styleNode.remove()
    @styleNodes.length = 0

    @invalidateStyles()

  extractFontStyleNode: (styleNode) ->
    fontStylesElement = document.createElement("style")
    fontCss = ""

    for cssRule in styleNode.sheet.cssRules when @hasFontStyling(cssRule)
      fontCss += cssRule.cssText

    fontStylesElement.innerHTML = fontCss
    fontStylesElement

  hasFontStyling: (cssRule) ->
    for styleProperty in cssRule.style
      return true if styleProperty.indexOf("font") isnt -1

    return false

  getDomNode: ->
    @iframe

  onDidInitialize: (callback) ->
    @emitter.on "did-initialize", callback

  hasLoaded: ->
    @initialized

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @headNode = @iframe.contentDocument.head

    @headNode.appendChild(@defaultStyleNode)

    @emitter.emit "did-initialize"

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

    @domNode.innerHTML = html if html isnt ""

    for line, lineIndex in newLines
      lineNode = @domNode.children[lineIndex]
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
