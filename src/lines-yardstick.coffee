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
    @lineNodesByLineId = {}
    @lineNodesByContextIndexAndLineId = {}
    @activeContextIndex = -1

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

  createMeasurementContext: ->
    context = document.createElement("div")
    context.style.overflow = "hidden"
    context.style.width = "600px"
    context.style.height = "600px"
    context.style.display = "block"
    context

  setupIframe: =>
    @initialized = true
    @domNode = @iframe.contentDocument.body
    @headNode = @iframe.contentDocument.head
    @headNode.appendChild(@stylesNode)
    @headNode.appendChild(@syntaxStyleElement)

    @contexts = []
    @contexts.push(@createMeasurementContext()) for i in [0..8] by 1
    @domNode.appendChild(context) for context in @contexts

    @emitter.emit "did-initialize"

  getNextContextNode: ->
    @activeContextIndex = (@activeContextIndex + 1) % @contexts.length

    [@activeContextIndex, @contexts[@activeContextIndex]]

  lineNodesForContextIndex: (contextIndex) ->
    @lineNodesByContextIndex[contextIndex] ? []

  buildDomNodesForScreenRows: (screenRows) ->
    @ensureInitialized()

    visibleLines = {}
    html = ""
    [contextIndex, contextNode] = @getNextContextNode()

    screenRows.forEach (screenRow) =>
      line = @editor.tokenizedLineForScreenRow(screenRow)
      return unless line?
      visibleLines[line.id] = true

      unless @lineNodesByLineId.hasOwnProperty(line.id)
        lineState = @presenter.buildLineState(0, screenRow, line)
        html += @linesBuilder.buildLineHTML(false, 1000, lineState)

    for lineId, lineNode of @lineNodesByContextIndexAndLineId[contextIndex]
      continue if visibleLines.hasOwnProperty(lineId)

      lineNode.remove()

      delete @lineNodesByLineId[lineId]
      delete @lineNodesByContextIndexAndLineId[contextIndex][lineId]

    contextNode.insertAdjacentHTML("beforeend", html)

    @storeLineNodesInContextIndex(contextIndex)

  storeLineNodesInContextIndex: (contextIndex) ->
    contextNode = @contexts[contextIndex]
    @lineNodesByContextIndexAndLineId[contextIndex] ?= {}

    for lineNode in contextNode.querySelectorAll("div.line")
      screenRow = lineNode.dataset.screenRow
      line = @editor.tokenizedLineForScreenRow(screenRow)
      @lineNodesByLineId[line.id] = lineNode
      @lineNodesByContextIndexAndLineId[contextIndex][line.id] = lineNode

  lineNodeForScreenRow: (screenRow) ->
    line = @editor.tokenizedLineForScreenRow(screenRow)
    lineNode = @lineNodesByLineId[line.id]
    lineNode

  leftPixelPositionForScreenPosition: (position) ->
    @ensureInitialized()

    lineNode = @lineNodeForScreenRow(position.row)

    unless lineNode?
      # console.log "#{position.row} not found. This wasn't expected."
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
