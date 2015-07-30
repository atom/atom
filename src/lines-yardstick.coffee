{Emitter} = require 'event-kit'
TokenIterator = require './token-iterator'
{Point} = require 'text-buffer'

module.exports =
class Something
  constructor: (@editor) ->
    @measuringContext = document.createElement("canvas").getContext("2d")
    @tokenIterator = new TokenIterator

  setDefaultFont: (fontFamily, fontSize) ->
    @defaultFont = "#{fontSize} #{fontFamily}"

  pixelPositionForScreenPosition: (screenPosition, clip=true) ->
    screenPosition = Point.fromObject(screenPosition)
    screenPosition = @editor.clipScreenPosition(screenPosition) if clip


    targetRow = screenPosition.row
    targetColumn = screenPosition.column

    top = targetRow * @editor.getLineHeightInPixels()
    left = @leftPixelPositionForScreenPosition(screenPosition)

    {top, left}

  leftPixelPositionForScreenPosition: (screenPosition) ->
    @measuringContext.font = @defaultFont

    line = @editor.tokenizedLineForScreenRow(screenPosition.row)
    text = ""
    width = 0

    @tokenIterator.reset(line)
    while @tokenIterator.next()
      screenStart = @tokenIterator.getScreenStart()
      screenEnd = @tokenIterator.getScreenEnd()
      if screenStart <= screenPosition.column < screenEnd
        text += @tokenIterator.getText().substring(
          0,
          screenPosition.column - screenStart
        )
        break
      else
        text += @tokenIterator.getText()

    @measuringContext.measureText(text).width

class LinesYardstick
  constructor: (@editor, hostElement, @syntaxStyleElement) ->
    @context = document.createElement("canvas").getContext("2d")
    @currentFont = ""
    @tokenIterator = new TokenIterator
    @initialized = false
    @emitter = new Emitter
    @fontsByTokenScopes = {}
    @defaultStyleNode = document.createElement("style")
    @skinnyStyleNode = document.createElement("style")
    @iframe = document.createElement("iframe")
    @iframe.style.display = "none"
    @iframe.onload = @setupIframe
    @processedLines = {}

    hostElement.appendChild(@iframe)

  setFontInformation: (fontFamily, fontSize, lineHeight) ->
    @fontsByTokenScopes = {}
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
    @fontsByTokenScopes = {}

    for style in @syntaxStyleElement.children
      for cssRule in style.sheet.cssRules when @hasFontStyling(cssRule)
        skinnyCss += cssRule.cssText

    @skinnyStyleNode.innerHTML = skinnyCss

  hasFontStyling: (cssRule) ->
    for styleProperty in cssRule.style
      return true if styleProperty.indexOf("font") isnt -1

    return false

  buildLineHTML: (line) ->
    @newTokenScopesByLineId[line.id] = []
    @tokenIterator.reset(line)
    html = "<div>"
    while @tokenIterator.next()
      tokenScopes = @tokenIterator.getScopes().join()
      continue if @fontsByTokenScopes.hasOwnProperty(tokenScopes)

      for scope in @tokenIterator.getScopes()
        html += "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

      for scope in @tokenIterator.getScopes()
        html += "</span>"

      @newTokenScopesByLineId[line.id].push(tokenScopes)

    html += "</div>"
    html

  buildDomNodesForScreenRows: (screenRows) ->
    @ensureInitialized()

    @newTokenScopesByLineId = {}
    newLines = []
    html = ""
    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return if not line?
      return if @processedLines.hasOwnProperty(line.id)

      lineHTML = @buildLineHTML(line)
      if lineHTML isnt "<div></div>"
        html += lineHTML
        newLines.push(line)

      @processedLines[line.id] = true

    @domNode.innerHTML = html if html isnt ""
    @collectStylingInformationForLines(newLines)

  getLeafNode: (node) ->
    if node.firstChild?
      @getLeafNode(node.firstChild)
    else
      node

  collectStylingInformationForLines: (lines) ->
    for line, lineIndex in lines
      lineNode = @domNode.children[lineIndex]
      for tokenScope, nodeIndex in @newTokenScopesByLineId[line.id]
        continue if @fontsByTokenScopes.hasOwnProperty(tokenScope)

        tokenScopeNode = @getLeafNode(lineNode.children[nodeIndex])
        @fontsByTokenScopes[tokenScope] = getComputedStyle(tokenScopeNode).font

  leftPixelPositionForScreenPosition: (position) ->
    @ensureInitialized()

    line = @editor.tokenizedLineForScreenRow(position.row)
    @tokenIterator.reset(line)

    text = ""
    width = 0
    while @tokenIterator.next()
      tokenScopes = @tokenIterator.getScopes().join()
      if @currentFont isnt @fontsByTokenScopes[tokenScopes]
        width += @context.measureText(text).width
        @context.font = @currentFont = @fontsByTokenScopes[tokenScopes]
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
