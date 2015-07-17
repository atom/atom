LineHtmlBuilder = require './line-html-builder'
AcceptFilter = {acceptNode: -> NodeFilter.FILTER_ACCEPT}
rangeForMeasurement = document.createRange()
{Emitter} = require 'event-kit'
{last} = require 'underscore-plus'

module.exports =
class LinesYardstick
  constructor: (@editor, @presenter, hostElement, @syntaxStyleElement) ->
    @initialized = false
    @emitter = new Emitter
    @linesBuilder = new LineHtmlBuilder(true)
    @stylesNode = document.createElement("style")
    @iframe = document.createElement("iframe")
    @iframe.style.display = "none"
    @iframe.onload = @setupIframe
    @lineNodesByScreenRow = {}
    @screenRowsByLineId = {}

    hostElement.appendChild(@iframe)

  setFont: (fontFamily, fontSize) ->
    @stylesNode.innerHTML = "body { margin: 0; padding: 0; font-size: #{fontSize}; font-family: #{fontFamily}; white-space: pre; }"

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
    @headNode.appendChild(@stylesNode)
    @headNode.appendChild(@syntaxStyleElement)

    @emitter.emit "did-initialize"

  buildDomNodesForScreenRows: (screenRows) ->
    @ensureInitialized()

    visibleLines = {}
    html = ""

    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      visibleLines[line.id] = true

      unless @screenRowsByLineId.hasOwnProperty(line.id)
        lineState = @presenter.buildLineState(0, screenRow, line)
        html += @linesBuilder.buildLineHTML(false, 1000, lineState)
        @screenRowsByLineId[line.id] = screenRow

    for lineId, screenRow of @screenRowsByLineId
      continue if visibleLines.hasOwnProperty(lineId)

      @lineNodesByScreenRow[screenRow].remove()
      delete @screenRowsByLineId[lineId]

    @domNode.insertAdjacentHTML("beforeend", html)

    @lineNodesByScreenRow = {}
    for lineNode in @domNode.children
      screenRow = lineNode.dataset.screenRow
      @lineNodesByScreenRow[screenRow] = lineNode

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByScreenRow[screenRow]

  leftPixelPositionForScreenPosition: (position) ->
    @ensureInitialized()

    lineNode = @lineNodeForScreenRow(position.row)

    unless lineNode?
      console.log "#{position.row} not found. This wasn't expected."
      return 0

    tokens = lineNode.getElementsByClassName("token")

    return 0 if tokens.length is 0

    if foundToken = @findTokenByColumn(position.column, tokens)
      textNode = foundToken.childNodes[0]
      positionWithinToken = position.column - parseInt(foundToken.dataset.start)
    else
      textNode = last(tokens).childNodes[0]
      positionWithinToken = textNode.textContent.length

    @leftPixelPositionForCharInTextNode(textNode, positionWithinToken)

  findTokenByColumn: (column, tokens, startIndex = 0, endIndex = tokens.length) ->
    index = Math.floor((startIndex + endIndex) / 2)

    return if startIndex > endIndex or index is tokens.length

    element = tokens[index]

    rangeStart = parseInt(element.dataset.start)
    rangeEnd = parseInt(element.dataset.end)

    if rangeStart > column
      @findTokenByColumn(column, tokens, startIndex, index - 1)
    else if rangeEnd < column
      @findTokenByColumn(column, tokens, index + 1, endIndex)
    else
      element

  leftPixelPositionForCharInTextNode: (textNode, charIndex = textNode.textContent.length) ->
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
