{Emitter} = require 'event-kit'
TokenIterator = require '../src/token-iterator'

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

  setDefaultFont: (fontFamily, fontSize) ->
    @defaultStyleNode.innerHTML = """
    body {
      font-size: #{fontSize};
      font-family: #{fontFamily};
    }
    """

    @emitter.emit "did-invalidate-styles"

  addStyle: (styleNode) ->
    fontStyleNode = @extractFontStyleNode(styleNode)
    @styleNodes.push(fontStyleNode)
    @headNode.appendChild(fontStyleNode)

    @emitter.emit "did-invalidate-styles"

  addStyles: (styleNodes) ->
    @addStyle(styleNode) for styleNode in styleNodes
    return

  clearStyles: ->
    for styleNode in @styleNodes
      styleNode.remove()
    @styleNodes.length = 0

    @emitter.emit "did-invalidate-styles"

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

  canMeasure: ->
    @initialized

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @headNode = @iframe.contentDocument.head

    @headNode.appendChild(@defaultStyleNode)

    @emitter.emit "did-initialize"

  sampleScreenRows: (screenRows) ->
    html = ""
    newLines = []
    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return if not line?

      lineHTML = @buildLineHTML(line)
      html += lineHTML
      newLines.push(line)

    @domNode.innerHTML = html if html isnt ""

    for line, lineIndex in newLines
      @tokenIterator.reset(line)
      lineNode = @domNode.children[lineIndex]
      nodeIndex = 0
      while @tokenIterator.next()
        tokenScopeNode = @getLeafNode(lineNode.children[nodeIndex])
        samplingEvent =
          scopes: @tokenIterator.getScopes()
          font: getComputedStyle(tokenScopeNode).font
        @emitter.emit "did-sample-scopes-style", samplingEvent

        nodeIndex++

  onDidSampleScopesStyle: (callback) ->
    @emitter.on "did-sample-scopes-style", callback

  onDidInvalidateStyles: (callback) ->
    @emitter.on "did-invalidate-styles", callback

  buildLineHTML: (line) ->
    html = "<div>"

    @tokenIterator.reset(line)
    while @tokenIterator.next()
      for scope in @tokenIterator.getScopes()
        html += "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

      for scope in @tokenIterator.getScopes()
        html += "</span>"

    html += "</div>"
    html

  getLeafNode: (node) ->
    if node.firstChild?
      @getLeafNode(node.firstChild)
    else
      node
