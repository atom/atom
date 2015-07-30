{Emitter} = require 'event-kit'
TokenIterator = require '../src/token-iterator'

module.exports=
class StyleSamplerComponent
  constructor: (@editor) ->
    @tokenIterator = new TokenIterator
    @initialized = false
    @emitter = new Emitter
    @defaultStyleNode = document.createElement("style")
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

  addStyleElement: (styleElement) ->
    skinnyStyleElement = @extractFontStyles(styleElement)
    @headNode.appendChild(skinnyStyleElement)

  extractFontStyles: (styleElement) ->
    fontStylesElement = document.createElement("style")
    fontCss = ""

    for cssRule in styleElement.sheet.cssRules when @hasFontStyling(cssRule)
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
        @emitter.emit "scopes-style-sampled", samplingEvent

        nodeIndex++

  onScopesStyleSampled: (callback) ->
    @emitter.on "scopes-style-sampled", callback

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
