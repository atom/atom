LineHtmlBuilder = require './line-html-builder'
TokenIterator = require './token-iterator'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()
{Emitter} = require 'event-kit'

module.exports =
class LinesYardstick
  constructor: (@editor, @presenter, @syntaxStyleElement) ->
    @initialized = false
    @emitter = new Emitter
    @linesBuilder = new LineHtmlBuilder(true)
    @defaultStyleNode = document.createElement("style")
    @skinnyStyleNode = document.createElement("style")
    @iframe = document.createElement("iframe")
    @iframe.style.display = "none"
    @iframe.onload = @setupIframe
    @lineNodesByLineId = {}
    @tokenIterator = new TokenIterator

  getDomNode: -> @iframe

  setFont: (fontFamily, fontSize) ->
    @defaultStyleNode.innerHTML = "body { margin: 0; padding: 0; font-size: #{fontSize}; font-family: #{fontFamily}; white-space: pre; }"

  onDidInitialize: (callback) ->
    @emitter.on "did-initialize", callback

  canMeasure: ->
    @initialized

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

    for style in @syntaxStyleElement.children
      for cssRule in style.sheet.cssRules when @hasFontStyling(cssRule)
        skinnyCss += cssRule.cssText

    @skinnyStyleNode.innerHTML = skinnyCss

  hasFontStyling: (cssRule) ->
    for styleProperty in cssRule.style
      return true if styleProperty.indexOf("font") isnt -1

    return false

  buildDomNodesForScreenRows: (screenRows) ->
    visibleLines = {}
    html = ""
    newLinesIds = []
    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return unless line?
      visibleLines[line.id] = true

      unless @lineNodesByLineId.hasOwnProperty(line.id)
        lineState = @presenter.buildLineState(0, screenRow, line)
        html += @linesBuilder.buildLineHTML(@indentGuidesVisible, 0, lineState)
        newLinesIds.push(line.id)

    for lineId, lineNode of @lineNodesByLineId
      continue if visibleLines.hasOwnProperty(lineId)

      lineNode.remove()
      delete @lineNodesByLineId[lineId]

    @domNode.insertAdjacentHTML("beforeend", html)
    index = @domNode.children.length - 1
    while lineId = newLinesIds.pop()
      lineNode = @domNode.children[index--]
      @lineNodesByLineId[lineId] = lineNode

  lineNodeForScreenRow: (screenRow) ->
    line = @editor.tokenizedLineForScreenRow(screenRow)
    lineNode = @lineNodesByLineId[line.id]
    lineNode

  leftPixelPositionForScreenPosition: ({row, column}) ->
    lineNode = @lineNodeForScreenRow(row)
    return 0 unless lineNode?

    tokenizedLine = @editor.tokenizedLineForScreenRow(row)
    iterator = document.createNodeIterator(lineNode, NodeFilter.SHOW_TEXT, AcceptFilter)
    charIndex = 0

    @tokenIterator.reset(tokenizedLine)
    while @tokenIterator.next()
      text = @tokenIterator.getText()

      textIndex = 0
      while textIndex < text.length
        if @tokenIterator.isPairedCharacter()
          char = text
          charLength = 2
          textIndex += 2
        else
          char = text[textIndex]
          charLength = 1
          textIndex++

        continue if char is '\0'

        unless textNode?
          textNode = iterator.nextNode()
          textNodeLength = textNode.textContent.length
          textNodeIndex = 0
          nextTextNodeIndex = textNodeLength

        while nextTextNodeIndex <= charIndex
          textNode = iterator.nextNode()
          textNodeLength = textNode.textContent.length
          textNodeIndex = nextTextNodeIndex
          nextTextNodeIndex = textNodeIndex + textNodeLength

        if charIndex is column
          indexWithinToken = charIndex - textNodeIndex
          return @leftPixelPositionForCharInTextNode(textNode, indexWithinToken)

        charIndex += charLength

    if textNode?
      @leftPixelPositionForCharInTextNode(textNode, textNode.textContent.length)
    else
      0

  leftPixelPositionForCharInTextNode: (textNode, charIndex) ->
    rangeForMeasurement.setEnd(textNode, textNode.textContent.length)

    if charIndex is 0
      rangeForMeasurement.setStart(textNode, 0)
      rangeForMeasurement.getBoundingClientRect().left
    else if charIndex is textNode.textContent.length
      rangeForMeasurement.setStart(textNode, 0)
      rangeForMeasurement.getBoundingClientRect().right
    else
      rangeForMeasurement.setStart(textNode, charIndex)
      rangeForMeasurement.getBoundingClientRect().left
