LineHtmlBuilder = require './line-html-builder'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()
{Emitter} = require 'event-kit'
{last} = require 'underscore-plus'
TokenIterator = require './token-iterator'

module.exports =
class LinesYardstick
  constructor: (@editor, @presenter, hostElement, @syntaxStyleElement) ->
    @context = document.createElement("canvas").getContext("2d")
    @tokenIterator = new TokenIterator
    @initialized = false
    @emitter = new Emitter
    @scopesStylesCache = {}
    @defaultStyleNode = document.createElement("style")
    @skinnyStyleNode = document.createElement("style")
    @iframe = document.createElement("iframe")
    @iframe.style.display = "none"
    @iframe.onload = @setupIframe
    @processedLines = {}

    hostElement.appendChild(@iframe)

  setFontInformation: (fontFamily, fontSize, lineHeight) ->
    @scopesStylesCache = {}
    @processedLines = {}
    @defaultStyleNode.innerHTML = """
    body {
      font-size: #{fontSize};
      font-family: #{fontFamily};
      line-height: #{lineHeight};
    }
    """

  onDidInitialize: (callback) ->
    @emitter.on "did-initialize", callback

  canMeasure: ->
    @initialized

  ensureInitialized: ->
    return if @canMeasure()

    throw new Error("This instance of LinesYardstick hasn't been initialized!")

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @headNode = @iframe.contentDocument.head

    @rebuildSkinnyStyleNode()
    @headNode.appendChild(@defaultStyleNode)
    @headNode.appendChild(@skinnyStyleNode)

    @emitter.emit "did-initialize"

  rebuildSkinnyStyleNode: ->
    skinnyCss = ""
    @scopesStylesCache = {}

    for style in @syntaxStyleElement.children
      for cssRule in style.sheet.cssRules when @hasFontStyling(cssRule)
        skinnyCss += cssRule.cssText

    @skinnyStyleNode.innerHTML = skinnyCss

  hasFontStyling: (cssRule) ->
    for styleProperty in cssRule.style
      return true if styleProperty.indexOf("font") isnt -1

    return false

  buildLineHTML: (line) ->
    @tokenIterator.reset(line)
    html = ""
    while @tokenIterator.next()
      scopes = @tokenIterator.getScopes()
      continue if @scopesStylesCache.hasOwnProperty(scopes.join())

      for scope in @tokenIterator.getScopes()
        html += "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

      for scope in @tokenIterator.getScopes()
        html += "</span>"

    html

  buildDomNodesForScreenRows: (screenRows) ->
    @ensureInitialized()

    newLines = []
    html = ""
    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return if not line?
      return if @processedLines.hasOwnProperty(line.id)

      lineHTML = @buildLineHTML(line)
      html += lineHTML
      newLines.push(line) unless lineHTML is ""
      @processedLines[line.id] = true

    @domNode.innerHTML = html if html isnt ""
    @collectStylingInformationForLines(newLines)

  collectStylingInformationForLines: (lines) ->
    nodeIndex = 0
    for line in lines
      lineNode = @domNode.children[nodeIndex++]

      @tokenIterator.reset(line)
      while @tokenIterator.next()
        scopes = @tokenIterator.getScopes()

        continue if @scopesStylesCache.hasOwnProperty(scopes.join())

        currentNode = lineNode

        for scope in scopes
          currentNode = currentNode.firstChild if currentNode.firstChild?

        @scopesStylesCache[scopes.join()] = getComputedStyle(currentNode).font

  leftPixelPositionForScreenPosition: (position) ->
    @ensureInitialized()

    line = @editor.tokenizedLineForScreenRow(position.row)
    @tokenIterator.reset(line)

    font = @context.font
    text = ""
    width = 0
    while @tokenIterator.next()
      scopes = @tokenIterator.getScopes().join()
      if font isnt @scopesStylesCache[scopes]
        font = @context.font = @scopesStylesCache[scopes]
        width += @context.measureText(text).width
        text = ""

      screenStart = @tokenIterator.getScreenStart()
      screenEnd = @tokenIterator.getScreenEnd()
      if screenStart <= position.column < screenEnd
        text += @tokenIterator.getText().substring(
          0,
          position.column - screenStart
        )
        break
      else
        text += @tokenIterator.getText()

    width += @context.measureText(text).width if text isnt ""
    width
